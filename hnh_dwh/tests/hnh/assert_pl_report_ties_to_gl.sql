-- Total Comprehensive Income of the P&L report per branch-month equals the income-statement accounts it is built from,
-- credit positive: fact_gl_fs_monthly for branches 1-8 (Oasis before the cutover, Fusion from it), the Head Office (100)
-- accounts of fact_gl_balance_monthly including unposted, opening-balance journals left out. One row per branch-month
-- off by 0.01 or more.
with report as (
    select branch_key, month_start, sum(amount) as amount
    from {{ ref('fact_pl_report_monthly') }}
    where pl_line_code = 'TOTAL_COMPREHENSIVE_INCOME'
    group by branch_key, month_start
),

gl as (
    select branch_key, month_start, -sum(movement) as amount
    from {{ ref('fact_gl_fs_monthly') }}
    where fs_type = 'is'
    group by branch_key, month_start
    union all
    select f.branch_key, p.month_start, -sum(f.period_movement_excl_opening)
    from {{ ref('fact_gl_balance_monthly') }} as f
    inner join {{ ref('hnh_dim_gl_period') }} as p on p.period_key = f.period_key
    inner join {{ ref('hnh_dim_gl_account') }} as a on a.gl_account_key = f.gl_account_key
    where f.balance_view = 'including_unposted' and f.branch_key = 100 and a.balance_side = 'IS'
    group by f.branch_key, p.month_start
),

both_sides as (
    select branch_key, month_start, amount as report_amount, toFloat64(0) as gl_amount from report
    union all
    select branch_key, month_start, toFloat64(0), amount from gl
)

select branch_key, month_start, round(report_total, 2) as report_tci, round(gl_total, 2) as gl_result,
       round(report_total - gl_total, 2) as difference
from (
    select branch_key, month_start, sum(report_amount) as report_total, sum(gl_amount) as gl_total
    from both_sides
    group by branch_key, month_start
)
where abs(report_total - gl_total) >= 0.01
