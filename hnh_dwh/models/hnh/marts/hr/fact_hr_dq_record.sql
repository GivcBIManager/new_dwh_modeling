{{ config(order_by='(hr_dq_issue_key, branch_key, employee_key, staff_key)') }}

-- HR data quality records (HR dashboard spec, "Data quality page"): one row per issue x affected record, one CTE per
-- issue code of the catalogue (dim_hr_dq_issue); only issues whose status is 'active' are kept. No names, no amounts.
--   branch_key: the record's hospital; 100 (Head Office, admins only) when the source has no hospital or hospital 0.
--   employee_key / staff_key: -1 when none; a record with an employee and no staff takes the employee's staff link.
--   record_date: a plain date with no date key, so the Month slicer does not filter the records.
-- The warn tests that held these rules (warn_employees_without_staff_link and seven more) now read this model, so the
-- test and the page cannot drift. "Today" is var hnh_bsc_as_of (empty = today()).
with
    ifNull(toDateOrNull('{{ var('hnh_bsc_as_of') }}'), today())  as as_of_,
    toInt32(toYYYYMM(addMonths(toStartOfMonth(as_of_), -1)))     as last_closed_month_,
    toInt32(toYYYYMMDD(addMonths(as_of_, 12)))                   as future_limit_key_,

emp as (
    select employee_key, person_id, branch_key, worker_number, worker_type_code, is_terminated, termination_date,
           gender, nationality, birth_date, hr_department_key, job_key, grade_key, staff_key
    from {{ ref('hnh_dim_employee') }}
    where employee_key != -1
),

staff as (select staff_key, branch_key, staff_id, contract_status, termination_date from {{ ref('dim_staff') }} where staff_key != -1),
bridge as (select employee_key, staff_key, branch_key, worker_number from {{ ref('bridge_employee_staff') }}),
leave_balance as (
    select branch_key, employee_key, absence_plan_id, accrual_period_date_key, is_closed_period, is_current_balance, is_annual_plan, monthly_salary,
           if(accrual_period_date_key = 0, null,
              makeDate(intDiv(accrual_period_date_key, 10000), intDiv(accrual_period_date_key, 100) % 100, accrual_period_date_key % 100)) as accrual_date
    from {{ ref('fact_leave_balance_monthly') }}
),
payroll as (
    select branch_key, source, payee_key, employee_key, staff_key, payroll_month, pay_category, amount,
           makeDate(intDiv(payroll_month, 100), payroll_month % 100, 1) as month_date
    from {{ ref('fact_payroll_monthly') }}
),

-- DQ_EMP_NO_STAFF (warn_employees_without_staff_link): active hospital EMP employee whose worker number matches no
-- Oasis staff in the branch.
emp_no_staff as (
    select 'DQ_EMP_NO_STAFF' as issue_code, branch_key, employee_key, staff_key, worker_number, null as staff_id,
           'worker_number' as field_name, worker_number as value_found, null as record_date
    from emp
    where staff_key = -1 and branch_key between 1 and 8 and worker_type_code = 'EMP' and is_terminated = 0
),

-- DQ_STAFF_NO_EMP: hospital Oasis staff with an open contract and no Fusion employee. "Open" = dim_staff contract_status
-- 'Active' (a latest contract with no termination date); 'No contract' and 'Terminated' staff are not expected in Fusion.
staff_no_emp as (
    select 'DQ_STAFF_NO_EMP' as issue_code, branch_key, toInt64(-1) as employee_key, staff_key, null as worker_number, staff_id,
           'staff_id' as field_name, staff_id as value_found, null as record_date
    from staff
    where branch_key between 1 and 8 and contract_status = 'Active' and termination_date is null
      and staff_key not in (select staff_key from bridge)
),

-- DQ_STAFF_MANY_EMP (warn_staff_linked_to_many_employees): one row per employee of a staff record linked to several,
-- less the employees DQ_EMP_DUP_WORKER_NO already flags: two Fusion employees with one worker number link to the same
-- staff record, and the fix is in Fusion (that issue), so they are not listed twice with a different "fix in" (HR
-- dashboard final review M1). This also narrows warn_staff_linked_to_many_employees, which reads these records: it no
-- longer counts those employees (they stay under DQ_EMP_DUP_WORKER_NO on the Data quality page).
staff_many_emp as (
    select 'DQ_STAFF_MANY_EMP' as issue_code, branch_key, employee_key, staff_key, worker_number, worker_number as staff_id,
           'staff_id' as field_name, worker_number as value_found, null as record_date
    from (select *, count() over (partition by staff_key, branch_key) as employees from bridge)
    where employees > 1
      and employee_key not in (select employee_key from emp_dup_worker_no)
),

-- DQ_STAFF_ID_FORMAT (warn_staff_id_collisions): each raw Oasis staff id of a branch whose ids are equal once trimmed and
-- upper-cased (staging keeps one of them).
staff_id_format as (
    select 'DQ_STAFF_ID_FORMAT' as issue_code, c.branch_key as branch_key, toInt64(-1) as employee_key, ifNull(s.staff_key, toInt64(-1)) as staff_key,
           null as worker_number, c.raw_id as staff_id, 'staff_id' as field_name, c.raw_id as value_found, null as record_date
    from (
        select branch_key, raw_id, normalised_id, uniqExact(raw_id) over (partition by branch_key, normalised_id) as ids
        from (select distinct toUInt8(branch_id) as branch_key, staff_id as raw_id, {{ hnh_code('staff_id') }} as normalised_id
              from {{ hnh_oasis_source('staff_master_data') }} final)
    ) as c
    left join staff as s on s.branch_key = c.branch_key and s.staff_id = c.normalised_id
    where c.ids > 1
),

-- DQ_EMP_DUP_WORKER_NO: Fusion employees sharing a worker number within a branch.
emp_dup_worker_no as (
    select 'DQ_EMP_DUP_WORKER_NO' as issue_code, branch_key, employee_key, staff_key, worker_number, null as staff_id,
           'worker_number' as field_name, worker_number as value_found, null as record_date
    from (select *, count() over (partition by branch_key, worker_number) as employees from emp where worker_number is not null)
    where employees > 1
),

-- DQ_FTE_ZERO (warn_fte_out_of_range): FTE work measure outside (0, 1.5], replaced by 1 in the snapshot; on the
-- assignment's employee (Head Office when the assignment has none).
fte_zero as (
    select 'DQ_FTE_ZERO' as issue_code, ifNull(e.branch_key, toUInt8(0)) as branch_key, ifNull(e.employee_key, toInt64(-1)) as employee_key,
           toInt64(-1) as staff_key, null as worker_number, null as staff_id, 'fte' as field_name, toString(w.value) as value_found,
           w.effective_start_date as record_date
    from {{ ref('stg_fusion__work_measures') }} as w
    left join (select assignment_id, any(person_id) as assignment_person_id from {{ ref('stg_fusion__assignments') }} group by assignment_id) as a
        on a.assignment_id = w.assignment_id
    left join emp as e on e.person_id = a.assignment_person_id
    where w.unit = 'FTE' and not (w.value > 0 and w.value <= 1.5)
),

-- DQ_LEAVE_DUP_PERIOD (assert_leave_balance_single_entry_per_period): more than one balance entry for an employee, plan and period.
leave_dup_period as (
    select 'DQ_LEAVE_DUP_PERIOD' as issue_code, any(l.branch_key) as branch_key, l.employee_key as employee_key, toInt64(-1) as staff_key,
           null as worker_number, null as staff_id, 'balance_entries' as field_name, toString(count()) as value_found, any(l.accrual_date) as record_date
    from leave_balance as l
    group by l.employee_key, l.absence_plan_id, l.accrual_period_date_key
    having count() > 1
),

-- DQ_ABSENCE_OVERLAP (assert_absence_daily_no_overlap): more than one counted absence day row for an employee and day.
absence_overlap as (
    select 'DQ_ABSENCE_OVERLAP' as issue_code, any(a.branch_key) as branch_key, a.employee_key as employee_key, any(a.staff_key) as staff_key,
           null as worker_number, null as staff_id, 'absence_entries' as field_name, toString(count()) as value_found,
           makeDate(intDiv(a.date_key, 10000), intDiv(a.date_key, 100) % 100, a.date_key % 100) as record_date
    from {{ ref('fact_absence_daily') }} as a
    group by a.employee_key, a.date_key
    having count() > 1
),

-- DQ_ABSENCE_ZERO_DAYS (warn_absence_zero_days): counted day-unit absence with zero or missing days.
absence_zero_days as (
    select 'DQ_ABSENCE_ZERO_DAYS' as issue_code, branch_key, employee_key, staff_key, null as worker_number, null as staff_id,
           'absence_days' as field_name, toString(absence_days) as value_found,
           if(start_date_key = 0, null, makeDate(intDiv(start_date_key, 10000), intDiv(start_date_key, 100) % 100, start_date_key % 100)) as record_date
    from {{ ref('fact_absence') }}
    where is_counted = 1 and duration_uom = 'C' and absence_days <= 0
),

-- DQ_LEAVE_NO_SALARY (warn_leave_without_salary): current annual-leave balance with no monthly salary, so no liability.
leave_no_salary as (
    select 'DQ_LEAVE_NO_SALARY' as issue_code, branch_key, employee_key, toInt64(-1) as staff_key, null as worker_number, null as staff_id,
           'monthly_salary' as field_name, null as value_found, accrual_date as record_date
    from leave_balance
    where is_annual_plan = 1 and monthly_salary is null and is_current_balance = 1
),

-- DQ_PAY_CODE_UNMAPPED (warn_unmapped_pay_codes): payroll row whose pay code has no pay category.
pay_code_unmapped as (
    select 'DQ_PAY_CODE_UNMAPPED' as issue_code, branch_key, employee_key, staff_key, null as worker_number, null as staff_id,
           'pay_category' as field_name, 'Unmapped' as value_found, month_date as record_date
    from payroll
    where pay_category = 'Unmapped'
),

-- DQ_B8_PAYROLL_COPY (warn_branch8_payroll_copies_branch7): a month where branch 8's Oasis payroll equals branch 7's in
-- paid staff and amount (source duplication, spec H11). The record is branch 8 and the month.
b8_month as (
    select p.branch_key as branch_key, p.payroll_month as payroll_month, any(p.month_date) as month_date,
           uniqExact(p.payee_key) as payees, round(sum(p.amount), 0) as amount_
    from payroll as p
    where p.source = 'oasis' and p.branch_key in (7, 8)
    group by p.branch_key, p.payroll_month
),
b8_payroll_copy as (
    select 'DQ_B8_PAYROLL_COPY' as issue_code, a.branch_key as branch_key, toInt64(-1) as employee_key, toInt64(-1) as staff_key,
           null as worker_number, null as staff_id, 'payroll_month' as field_name, toString(a.payroll_month) as value_found, a.month_date as record_date
    from b8_month as a
    inner join b8_month as b on b.payroll_month = a.payroll_month and b.branch_key = 7
    where a.branch_key = 8 and a.payees = b.payees and a.amount_ = b.amount_
),

-- DQ_PAYROLL_MONTH_MISSING: for each hospital, a month from its first payroll month to the last closed month (the
-- month before today's) with no payroll row, while at least one other hospital has payroll for that month (so a month
-- whose payroll no hospital has loaded yet, early in the next month, is not a gap). The record is the hospital and month.
payroll_month_seen as (select branch_key, payroll_month from payroll where branch_key between 1 and 8 group by branch_key, payroll_month),
payroll_month_missing as (
    select 'DQ_PAYROLL_MONTH_MISSING' as issue_code, g.branch_key as branch_key, toInt64(-1) as employee_key, toInt64(-1) as staff_key,
           null as worker_number, null as staff_id, 'payroll_month' as field_name, toString(g.payroll_month) as value_found, g.month_date as record_date
    from (
        select branch_key, month_date, toInt32(toYYYYMM(month_date)) as payroll_month
        from (select branch_key, min(payroll_month) as first_month from payroll_month_seen group by branch_key)
        array join arrayMap(i -> addMonths(makeDate(intDiv(first_month, 100), first_month % 100, 1), i),
                            range(toUInt32(greatest(0, intDiv(last_closed_month_, 100) * 12 + last_closed_month_ % 100
                                                       - intDiv(first_month, 100) * 12 - first_month % 100 + 1)))) as month_date
    ) as g
    where (g.branch_key, g.payroll_month) not in (select branch_key, payroll_month from payroll_month_seen)
      and g.payroll_month in (select payroll_month from payroll_month_seen)
),

-- DQ_LEAVE_BALANCE_STOPS: a hospital whose leave balances stop. Its latest month is the month that holds most of its
-- active employees' current balances (a handful of later stragglers must not hide the stop, as on Branch 1 after
-- 2026-08); it is flagged when that month is two or more months before the network's latest closed accrual month.
leave_hospital_month as (
    select l.branch_key as branch_key, intDiv(l.accrual_period_date_key, 100) as accrual_month, count() as balances
    from leave_balance as l
    inner join emp as e on e.employee_key = l.employee_key
    where l.is_current_balance = 1 and e.is_terminated = 0 and l.branch_key between 1 and 8
    group by l.branch_key, accrual_month
),
leave_balance_stops as (
    select 'DQ_LEAVE_BALANCE_STOPS' as issue_code, h.branch_key as branch_key, toInt64(-1) as employee_key, toInt64(-1) as staff_key,
           null as worker_number, null as staff_id, 'accrual_period' as field_name, toString(h.main_month) as value_found,
           makeDate(intDiv(h.main_month, 100), h.main_month % 100, 1) as record_date
    from (select branch_key, argMax(accrual_month, (balances, accrual_month)) as main_month from leave_hospital_month group by branch_key) as h
    cross join (select max(intDiv(accrual_period_date_key, 100)) as network_month from leave_balance where is_closed_period = 1) as n
    where intDiv(n.network_month, 100) * 12 + n.network_month % 100 - (intDiv(h.main_month, 100) * 12 + h.main_month % 100) >= 2
),

-- DQ_TERMINATED_WITH_BALANCE (reconciliation section 5): current leave balance of a terminated employee.
terminated_with_balance as (
    select 'DQ_TERMINATED_WITH_BALANCE' as issue_code, l.branch_key as branch_key, l.employee_key as employee_key, toInt64(-1) as staff_key,
           null as worker_number, null as staff_id, 'termination_date' as field_name, toString(e.termination_date) as value_found,
           l.accrual_date as record_date
    from leave_balance as l
    inner join emp as e on e.employee_key = l.employee_key
    where l.is_current_balance = 1 and e.is_terminated = 1
),

-- DQ_FUTURE_DATED (reconciliation section 5): worker movements, and counted absences, dated more than 12 months after
-- today. Planned leave and pending actions within the next year are normal and not flagged.
future_dated as (
    select 'DQ_FUTURE_DATED' as issue_code, branch_key, employee_key, staff_key, null as worker_number, null as staff_id,
           'action_date' as field_name, toString(record_date) as value_found,
           makeDate(intDiv(action_date_key, 10000), intDiv(action_date_key, 100) % 100, action_date_key % 100) as record_date
    from {{ ref('hnh_fact_worker_movement') }}
    where action_date_key > future_limit_key_
    union all
    select 'DQ_FUTURE_DATED', branch_key, employee_key, staff_key, null, null, 'start_date', toString(start_date_),
           makeDate(intDiv(start_date_key, 10000), intDiv(start_date_key, 100) % 100, start_date_key % 100) as start_date_
    from {{ ref('fact_absence') }}
    where is_counted = 1 and start_date_key > future_limit_key_
),

-- DQ_NO_HOSPITAL: active employee with no hospital (branch 0; the CON contractors). Shown under Head Office.
no_hospital as (
    select 'DQ_NO_HOSPITAL' as issue_code, branch_key, employee_key, staff_key, worker_number, null as staff_id,
           'branch' as field_name, toString(branch_key) as value_found, null as record_date
    from emp
    where branch_key = 0 and is_terminated = 0
),

-- DQ_LEGAL_EMPLOYER_MISMATCH (SSAS spec P15): the legal employer of the latest period of service (which gives the
-- employee's branch) differs from that of the current primary assignment, chosen as hnh_dim_employee chooses it.
current_assignment as (
    select person_id, legal_employer_id
    from {{ ref('stg_fusion__assignments') }}
    where is_current = 1 and is_primary = 1 and person_id is not null
    order by person_id,
             multiIf(ifNull(assignment_status, '') = 'ACTIVE', 1, ifNull(assignment_status, '') = 'SUSPENDED', 2, 3),
             valid_from desc, assignment_id desc
    limit 1 by person_id
),
legal_employer_mismatch as (
    select 'DQ_LEGAL_EMPLOYER_MISMATCH' as issue_code, e.branch_key as branch_key, e.employee_key as employee_key, e.staff_key as staff_key,
           e.worker_number as worker_number, null as staff_id, 'legal_employer' as field_name,
           ifNull({{ hnh_title('le.legal_employer_name') }}, toString(a.legal_employer_id)) as value_found, null as record_date
    from {{ ref('int_employee_period') }} as p
    inner join current_assignment as a on a.person_id = p.person_id
    inner join emp as e on e.person_id = p.person_id
    left join {{ ref('int_legal_employer_branch') }} as le on le.legal_employer_id = a.legal_employer_id
    where p.legal_employer_id != a.legal_employer_id
),

-- DQ_MISSING_ATTRIBUTE: active EMP employee missing gender, nationality, birth date, HR department, job or grade; one
-- row per missing field.
missing_attribute as (
    select 'DQ_MISSING_ATTRIBUTE' as issue_code, branch_key, employee_key, staff_key, worker_number, null as staff_id,
           missing_field as field_name, null as value_found, null as record_date
    from emp
    array join arrayFilter(f -> f != '', [
        if(ifNull(gender, '') = '', 'gender', ''), if(ifNull(nationality, '') = '', 'nationality', ''),
        if(birth_date is null, 'birth_date', ''), if(hr_department_key = -1, 'hr_department_key', ''),
        if(job_key = -1, 'job_key', ''), if(grade_key = -1, 'grade_key', '')]) as missing_field
    where worker_type_code = 'EMP' and is_terminated = 0
),

records as (
    select * from emp_no_staff
    union all select * from staff_no_emp
    union all select * from staff_many_emp
    union all select * from staff_id_format
    union all select * from emp_dup_worker_no
    union all select * from fte_zero
    union all select * from leave_dup_period
    union all select * from absence_overlap
    union all select * from absence_zero_days
    union all select * from leave_no_salary
    union all select * from pay_code_unmapped
    union all select * from b8_payroll_copy
    union all select * from payroll_month_missing
    union all select * from leave_balance_stops
    union all select * from terminated_with_balance
    union all select * from future_dated
    union all select * from no_hospital
    union all select * from legal_employer_mismatch
    union all select * from missing_attribute
),

resolved as (
    select r.issue_code as issue_code, r.branch_key as branch_key, r.employee_key as employee_key,
           if(ifNull(r.staff_key, -1) != -1, r.staff_key, ifNull(e.staff_key, -1)) as resolved_staff_key,
           coalesce(r.worker_number, e.worker_number) as resolved_worker_number, r.staff_id as staff_id,
           r.field_name as field_name, r.value_found as value_found, r.record_date as record_date
    from records as r
    left join emp as e on e.employee_key = r.employee_key
)

select
    i.hr_dq_issue_key                                                         as hr_dq_issue_key,
    d.issue_code                                                              as issue_code,
    toUInt8(if(ifNull(d.branch_key, 0) = 0, 100, d.branch_key))               as branch_key,
    toInt64(ifNull(d.employee_key, -1))                                       as employee_key,
    toInt64(d.resolved_staff_key)                                             as staff_key,
    cast(d.resolved_worker_number as Nullable(String))                        as worker_number,
    cast(coalesce(d.staff_id, s.staff_id) as Nullable(String))                as staff_id,
    toString(d.field_name)                                                    as field_name,
    cast(d.value_found as Nullable(String))                                   as value_found,
    cast(d.record_date as Nullable(Date))                                     as record_date
from resolved as d
inner join (select hr_dq_issue_key, issue_code from {{ ref('dim_hr_dq_issue') }} where status = 'active') as i
    on i.issue_code = d.issue_code
left join staff as s on s.staff_key = d.resolved_staff_key
{{ hnh_settings() }}
