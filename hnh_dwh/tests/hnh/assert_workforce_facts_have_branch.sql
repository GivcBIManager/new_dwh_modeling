-- Workforce facts never fall back to the Group member (branch 0).
select 'fact_headcount_monthly' as fact, count() as rows_without_branch from {{ ref('fact_headcount_monthly') }} where branch_key = 0 having count() > 0
union all
select 'fact_worker_movement', count() from {{ ref('hnh_fact_worker_movement') }} where branch_key = 0 having count() > 0
union all
select 'fact_payroll_monthly', count() from {{ ref('fact_payroll_monthly') }} where branch_key = 0 having count() > 0
