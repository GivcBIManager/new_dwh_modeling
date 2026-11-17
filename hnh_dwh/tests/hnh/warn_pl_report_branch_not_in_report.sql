{{ config(severity='warn') }}
-- Branches the P&L report leaves out: a branch (not 0) with income-statement movement in fact_gl_balance_monthly
-- (including unposted) and no row in fact_pl_report_monthly. The report takes Head Office (100) and branches 1-8
-- (hnh_pl_report_fusion_details, Oasis for 1-8), so a new Fusion branch would otherwise drop out silently.
-- One row per missing branch with its first and last month and its movement, credit positive.
select f.branch_key as branch_key, min(p.month_start) as first_month, max(p.month_start) as last_month,
       round(-sum(f.period_movement), 2) as is_movement
from {{ ref('fact_gl_balance_monthly') }} as f
inner join {{ ref('hnh_dim_gl_period') }} as p on p.period_key = f.period_key
inner join {{ ref('hnh_dim_gl_account') }} as a on a.gl_account_key = f.gl_account_key
where f.balance_view = 'including_unposted' and a.balance_side = 'IS' and f.branch_key != 0
  and f.period_movement != 0
  and f.branch_key not in (select distinct branch_key from {{ ref('fact_pl_report_monthly') }})
group by f.branch_key
