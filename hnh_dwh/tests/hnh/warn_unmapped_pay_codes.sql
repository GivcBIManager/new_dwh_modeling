{{ config(severity='warn') }}
-- Pay codes with no pay category (not counted in cost), by source and branch, with their amounts.
select source, branch_key, count() as rows, round(sum(amount), 2) as amount
from {{ ref('fact_payroll_monthly') }}
where pay_category = 'Unmapped'
group by source, branch_key
