{{ config(severity='warn') }}

-- Parallel enrolments can give two balance entries for one employee, plan and period; the flags tie-break them.
select employee_key, absence_plan_id, accrual_period_date_key, count() as entries
from {{ ref('fact_leave_balance_monthly') }}
group by employee_key, absence_plan_id, accrual_period_date_key
having count() > 1
