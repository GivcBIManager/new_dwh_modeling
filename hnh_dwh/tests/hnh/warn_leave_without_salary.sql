{{ config(severity='warn') }}
-- Annual-leave balances with no monthly salary, so no liability (spec 6.6), by branch at the latest closed balance.
select branch_key, count() as balances, round(sum(end_balance), 1) as days
from {{ ref('fact_leave_balance_monthly') }}
where is_annual_plan = 1 and monthly_salary is null and is_current_balance = 1
group by branch_key
