-- No branch-month carries cost from both sources (parallel-run Oasis rows carry no cost).
select branch_key, payroll_month
from {{ ref('fact_payroll_monthly') }}
where cost_amount != 0 or gross_pay != 0
group by branch_key, payroll_month
having uniqExact(source) > 1
