-- fact_headcount_monthly holds exactly one row per ACTIVE or SUSPENDED month-end assignment of int_assignment_month_end
-- (the model's filter): no fan-out from the period join and no rows lost in the employee join.
select 'fact_headcount_monthly row count differs from admitted month-end assignments' as failure, f.n as fact_rows, a.n as assignment_rows
from (select count() as n from {{ ref('fact_headcount_monthly') }}) as f
cross join (
    select count() as n
    from {{ ref('int_assignment_month_end') }}
    where ifNull(assignment_status, '') in ('ACTIVE', 'SUSPENDED')
) as a
where f.n != a.n
