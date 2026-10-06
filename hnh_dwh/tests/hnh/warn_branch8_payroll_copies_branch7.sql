{{ config(severity='warn') }}
-- Months where branch 8's Oasis payroll equals branch 7's in paid staff and amount (source duplication, spec H11).
with m as (
    select branch_key, payroll_month, uniqExact(payee_key) as payees, round(sum(amount), 0) as amount
    from {{ ref('fact_payroll_monthly') }}
    where source = 'oasis' and branch_key in (7, 8)
    group by branch_key, payroll_month
)
select a.payroll_month, a.payees, a.amount
from m as a inner join m as b on b.payroll_month = a.payroll_month and b.branch_key = 7
where a.branch_key = 8 and a.payees = b.payees and a.amount = b.amount
