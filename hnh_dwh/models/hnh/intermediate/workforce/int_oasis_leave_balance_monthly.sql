{{ config(order_by='(branch_key, month_end, employee_key)') }}

-- Oasis annual-leave balance at each month-end of the headcount (user request 2026-11-05: leave balances from Fusion
-- and Oasis; Oasis keeps no balance table). Per employee in the month's headcount who has an Oasis staff record:
--   current contract = the staff's latest Oasis contract started on or before the month-end;
--   earned           = days served in that contract up to the month-end (or its termination) x no_of_days_leave / 365
--                      (days_work_for_leave is 365 or empty on almost every contract; its other values, 21 to 120,
--                      look like leave days typed in the wrong field and gave balances of over 1,000 days);
--   taken            = annual-leave vacations booked against that contract (vacation type named "annual"), counted up to
--                      the month-end; status O entries are left out;
--   balance          = earned - taken.
-- Leave not taken by the end of a contract is settled with it, so a new contract starts at zero (on average within a
-- few days of Fusion's balances where both exist, October 2026). Contracts without leave days get no row.
-- fact_leave_balance_monthly uses these rows only where Fusion has no annual-leave balance for the employee and month.

with months as (
    select h.employee_key as employee_key, h.branch_key as branch_key, h.month_end as month_end,
           toDate32(h.month_end) as asof, toDate32(toStartOfMonth(h.month_end)) - 1 as prev_end,
           s.branch_key as staff_branch, s.staff_id as staff_id
    from {{ ref('fact_headcount_monthly') }} as h
    inner join (select staff_key, toUInt8(branch_key) as branch_key, staff_id from {{ ref('dim_staff') }}
                where staff_id is not null) as s
        on s.staff_key = h.staff_key
    where h.staff_key != -1
    {{ hnh_settings() }}
),

contract as (
    select m.employee_key as employee_key, m.branch_key as branch_key, m.month_end as month_end, m.asof as asof,
           m.prev_end as prev_end, c.branch_id as branch_id, c.staff_contract_no as staff_contract_no,
           assumeNotNull(c.started_at) as started_at, coalesce(c.terminated_at, toDate32('2149-06-06')) as stop_at,
           c.leave_days / 365 as daily_accrual
    from months as m
    inner join (select branch_id, staff_id, staff_contract_no, started_at, terminated_at, leave_days
                from {{ ref('stg_oasis__staff_contracts') }}
                where staff_id is not null and started_at is not null) as c
        on c.branch_id = m.staff_branch and c.staff_id = m.staff_id
    where c.started_at <= m.asof
    order by m.employee_key, m.month_end, c.started_at desc, c.staff_contract_no desc
    limit 1 by m.employee_key, m.month_end
    {{ hnh_settings() }}
),

taken as (
    select c.employee_key as employee_key, c.month_end as month_end,
           sumIf(least(v.days, toFloat64(dateDiff('day', v.from_date, c.asof) + 1)), v.from_date <= c.asof)         as taken_to_end,
           sumIf(least(v.days, toFloat64(dateDiff('day', v.from_date, c.prev_end) + 1)), v.from_date <= c.prev_end) as taken_to_prev
    from contract as c
    inner join (select v.branch_id as branch_id, v.staff_contract_no as staff_contract_no, v.from_date as from_date, v.days as days
                from {{ ref('stg_oasis__staff_vacations') }} as v
                inner join (select branch_id, vacation_type_id from {{ ref('stg_oasis__vacation_types') }}
                            where is_annual_leave = 1) as t
                    on t.branch_id = v.branch_id and t.vacation_type_id = v.vacation_type_id
                where v.from_date is not null and v.staff_contract_no is not null and ifNull(v.status, '') != 'O') as v
        on v.branch_id = c.branch_id and v.staff_contract_no = c.staff_contract_no
    group by c.employee_key, c.month_end
    {{ hnh_settings() }}
),

balance as (
    select c.employee_key as employee_key, c.branch_key as branch_key, c.month_end as month_end,
           c.staff_contract_no as staff_contract_no,
           toFloat64(greatest(0, dateDiff('day', c.started_at, least(c.asof, c.stop_at)) + 1)) * c.daily_accrual     as earned_to_end,
           toFloat64(greatest(0, dateDiff('day', c.started_at, least(c.prev_end, c.stop_at)) + 1)) * c.daily_accrual as earned_to_prev,
           ifNull(t.taken_to_end, 0)  as taken_to_end,
           ifNull(t.taken_to_prev, 0) as taken_to_prev
    from contract as c
    left join taken as t on t.employee_key = c.employee_key and t.month_end = c.month_end
    where c.daily_accrual > 0
    {{ hnh_settings() }}
)

select
    employee_key,
    branch_key,
    month_end,
    staff_contract_no,
    round(earned_to_prev - taken_to_prev, 4)    as begin_balance,
    round(earned_to_end - earned_to_prev, 4)    as accrued,
    round(taken_to_end - taken_to_prev, 4)      as used,
    round(earned_to_end - taken_to_end, 4)      as end_balance
from balance
