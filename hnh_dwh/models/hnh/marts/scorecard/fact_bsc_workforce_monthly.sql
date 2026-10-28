{{ config(order_by='(branch_key, month_date_key, row_type, person_id)') }}

-- The bsc.vw_work_force rules at person level, for the scorecard measures (bsc ssas spec 6.2): one row per branch,
-- month end, person and row type, for closed months from hnh_history_start_date. Summed per branch-month it equals
-- vw_work_force (assert_bsc_workforce_matches_vw_work_force).
--   head:        Fusion month-end headcount (employees, not contingent) from hnh_hr_snapshot_start, paid people
--                (gross pay > 0, no parallel run) before it. fte = Fusion FTE or 1 per paid person.
--   pt_doctor:   a doctor with revenue in the month who is neither in that month's headcount nor paid. Counted as
--                a head and a doctor, 0.5 FTE, never Saudi (user decision of 2026-10-13).
-- is_medical marks clinical staff for the clinical staff to doctors ratio: staff category NURSE, NURSE IN OTHER DEPT,
-- NURSE W/O LICENSE, PARAMEDICAL DEPT or PHYSICAL THERAPY (user decision of 2026-10-28; doctors are not included).
--   resignation: Oasis staff termination with reason Resignation (branches 1-5, and every branch before Fusion HR),
--                Fusion voluntary leavers for branches 6-8 from hnh_hr_snapshot_start. headcount 0.
with
    ifNull(toDateOrNull('{{ var('hnh_bsc_as_of') }}'), today()) as today_,
    toDate('{{ var('hnh_history_start_date') }}') as from_date_,
    toDate('{{ var('hnh_hr_snapshot_start') }}') as fusion_start_,
staff as (
    select staff_key, branch_key, ifNull(classification, '') as classification, ifNull(category, '') as category,
           termination_date, ifNull(termination_reason, '') as termination_reason, is_saudi
    from {{ ref('dim_staff') }}
),
paid as (
    select branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(month_date_key))) as period, paid_person_key,
           any(staff_key) as paid_staff_key
    from {{ ref('fact_payroll_monthly') }}
    where ifNull(is_parallel_run, 0) = 0
    group by branch_key, period, paid_person_key
    having sum(gross_pay) > 0
),
people as (
    select h.branch_key as branch_key, toStartOfMonth(h.month_end) as period, toString(h.employee_key) as person_id,
           h.staff_key as staff_key, h.employee_key as employee_key, h.fte as fte, toUInt8(h.is_saudi) as saudi,
           'fusion' as source_, h.hr_department_key as hr_department_key, h.job_key as job_key, h.grade_key as grade_key,
           h.position_key as position_key, h.location_key as location_key
    from {{ ref('fact_headcount_monthly') }} as h
    where h.is_contingent = 0 and h.headcount > 0 and toStartOfMonth(h.month_end) >= fusion_start_
    union all
    select pd.branch_key, pd.period, concat('paid-', toString(pd.paid_person_key)), pd.paid_staff_key, toInt64(-1),
           toFloat64(1), toUInt8(ifNull(ps.is_saudi, 0)), 'oasis', toInt64(-1), toInt64(-1), toInt64(-1), toInt64(-1), toInt64(-1)
    from paid as pd
    left join staff as ps on ps.staff_key = pd.paid_staff_key
    where pd.period < fusion_start_
),
heads as (
    select
        p.branch_key                                                  as branch_key,
        p.period                                                      as period,
        p.person_id                                                   as person_id,
        any(p.staff_key)                                              as staff_key_,
        any(p.employee_key)                                           as employee_key_,
        sum(p.fte)                                                    as fte_,
        max(toUInt8(ifNull(s.category = 'DOCTORS', 0)))              as doctor_,
        max(toUInt8(ifNull(s.category in ('NURSE', 'NURSE IN OTHER DEPT', 'NURSE W/O LICENSE', 'PARAMEDICAL DEPT',
                                          'PHYSICAL THERAPY'), 0)))           as medical_,
        max(ifNull(p.saudi, 0))                                       as saudi_,
        any(p.source_)                                                as source__,
        any(p.hr_department_key)                                      as hr_department_key_,
        any(p.job_key)                                                as job_key_,
        any(p.grade_key)                                              as grade_key_,
        any(p.position_key)                                           as position_key_,
        any(p.location_key)                                           as location_key_
    from people as p
    left join staff as s on s.staff_key = p.staff_key
    group by branch_key, period, person_id
),
covered as (
    select staff_key, period from people where staff_key != -1
    union distinct
    select paid_staff_key as staff_key, period from paid where paid_staff_key != -1
),
revenue_doctors as (
    select c.branch_key as branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(c.delivery_date_key))) as period,
           c.staff_key as staff_key
    from {{ ref('fact_charge_line') }} as c
    where c.staff_key != -1 and c.branch_key between 1 and 8 and c.delivery_date_key >= toInt32(toYYYYMMDD(from_date_))
    group by branch_key, period, staff_key
    having sum(c.revenue_amount) > 0
),
part_time as (
    select r.branch_key as branch_key, r.period as period, r.staff_key as staff_key
    from revenue_doctors as r
    inner join staff as s on s.staff_key = r.staff_key
    left anti join covered as v on v.staff_key = r.staff_key and v.period = r.period
    where s.category = 'DOCTORS'
),
resignations as (
    select branch_key, toDate(toStartOfMonth(termination_date)) as period,
           concat('staff-', toString(staff_key)) as person_id, staff_key as staff_key_, toInt64(-1) as employee_key_,
           toUInt8(count()) as resigned, 'oasis' as source__, toInt64(-1) as hr_department_key_, toInt64(-1) as job_key_,
           toInt64(-1) as grade_key_, toInt64(-1) as position_key_, toInt64(-1) as location_key_, toInt64(-1) as worker_action_key_
    from staff
    where termination_reason = 'Resignation' and termination_date is not null
      and (branch_key between 1 and 5 or toDate(toStartOfMonth(termination_date)) < fusion_start_)
    group by branch_key, period, staff_key
    union all
    select branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(action_date_key))) as period,
           concat('emp-', toString(employee_key)), any(staff_key), employee_key, toUInt8(count()), 'fusion',
           any(hr_department_key), any(job_key), any(grade_key), any(position_key), any(location_key), any(worker_action_key)
    from {{ ref('hnh_fact_worker_movement') }}
    where is_voluntary_leaver = 1 and branch_key between 6 and 8
      and toStartOfMonth(YYYYMMDDToDate(toUInt32(action_date_key))) >= fusion_start_
    group by branch_key, period, employee_key
),
all_rows as (
    select branch_key, period, person_id, 'head' as row_type, staff_key_ as staff_key, employee_key_ as employee_key,
           toUInt8(1) as headcount, toFloat64(fte_) as fte, doctor_ as is_doctor, medical_ as is_medical,
           saudi_ as is_saudi, toUInt8(0) as resignations, source__ as data_source, hr_department_key_ as hr_department_key,
           job_key_ as job_key, grade_key_ as grade_key, position_key_ as position_key, location_key_ as location_key,
           toInt64(-1) as worker_action_key
    from heads
    union all
    select branch_key, period, concat('pt-', toString(staff_key)), 'pt_doctor', staff_key, toInt64(-1),
           toUInt8(1), toFloat64(0.5), toUInt8(1), toUInt8(0), toUInt8(0), toUInt8(0), 'oasis',
           toInt64(-1), toInt64(-1), toInt64(-1), toInt64(-1), toInt64(-1), toInt64(-1)
    from part_time
    union all
    select branch_key, period, person_id, 'resignation', staff_key_, employee_key_,
           toUInt8(0), toFloat64(0), toUInt8(0), toUInt8(0), toUInt8(0), resigned, source__,
           hr_department_key_, job_key_, grade_key_, position_key_, location_key_, worker_action_key_
    from resignations
)

select
    toUInt8(branch_key)                                       as branch_key,
    toInt32(toYYYYMMDD(toLastDayOfMonth(assumeNotNull(period)))) as month_date_key,
    person_id                                                 as person_id,
    row_type                                                  as row_type,
    toInt64(staff_key)                                        as staff_key,
    toInt64(employee_key)                                     as employee_key,
    headcount                                                 as headcount,
    fte                                                       as fte,
    is_doctor                                                 as is_doctor,
    is_medical                                                as is_medical,
    is_saudi                                                  as is_saudi,
    resignations                                              as resignations,
    data_source                                               as data_source,
    -- HR attributes of the person (Fusion heads and leavers), -1 for Oasis, paid and part-time rows, so the workforce
    -- measures built on this fact stay sliceable by HR department, job, grade, position, location and action
    toInt64(ifNull(hr_department_key, -1))                    as hr_department_key,
    toInt64(ifNull(job_key, -1))                              as job_key,
    toInt64(ifNull(grade_key, -1))                            as grade_key,
    toInt64(ifNull(position_key, -1))                         as position_key,
    toInt64(ifNull(location_key, -1))                         as location_key,
    toInt64(ifNull(worker_action_key, -1))                    as worker_action_key
from all_rows
where branch_key between 1 and 8 and period >= from_date_ and period < toStartOfMonth(today_)
{{ hnh_settings() }}
