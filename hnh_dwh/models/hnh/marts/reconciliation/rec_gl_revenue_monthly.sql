{{ config(order_by='(branch_key, month_start)') }}

-- GL revenue (Oasis feed and manual, including unposted, opening-balance journals excluded) against Oasis
-- recognised revenue, per branch and month. Revenue is credit-positive; contractual discounts debit-positive.
with gl as (
    select
        j.branch_key                                    as branch_key,
        toStartOfMonth(p.end_date)                      as month_start,
        sumIf(-j.amount, f.statement_group = 'Revenue' and a.revenue_care_type = 'OP')          as gl_revenue_op,
        sumIf(-j.amount, f.statement_group = 'Revenue' and a.revenue_care_type = 'IP')          as gl_revenue_ip,
        sumIf(-j.amount, f.statement_group = 'Revenue' and a.revenue_care_type = 'ER')          as gl_revenue_er,
        sumIf(-j.amount, f.statement_group = 'Revenue' and a.revenue_care_type = 'Other')       as gl_revenue_other,
        sumIf(-j.amount, f.statement_group = 'Revenue' and a.revenue_care_type = 'Unallocated') as gl_revenue_unallocated,
        sumIf(j.amount, f.fs_caption = 'Revenue - Contractual Discounts')                       as gl_contractual_discount
    from {{ ref('hnh_fact_gl_journal_line') }} as j
    inner join (select gl_account_key, revenue_care_type, fs_line_key from {{ ref('hnh_dim_gl_account') }}) as a
        on a.gl_account_key = j.gl_account_key
    inner join (select fs_line_key, statement_group, fs_caption from {{ ref('dim_fs_line') }}) as f on f.fs_line_key = a.fs_line_key
    inner join (select period_key, end_date from {{ ref('hnh_dim_gl_period') }}) as p on p.period_key = j.period_key
    where j.is_opening_balance_journal = 0
      and (f.statement_group = 'Revenue' or f.fs_caption = 'Revenue - Contractual Discounts')
    group by j.branch_key, month_start
),

first_gl as (
    select branch_key, min(month_start) as first_month from gl group by branch_key
),

oasis as (
    select
        c.branch_key                                            as branch_key,
        toStartOfMonth(toDate(toString(c.delivery_date_key)))   as month_start,
        sumIf(c.revenue_amount, ct.care_type = 'OP')            as oasis_revenue_op,
        sumIf(c.revenue_amount, ct.care_type = 'IP')            as oasis_revenue_ip,
        sumIf(c.revenue_amount, ct.care_type = 'ER')            as oasis_revenue_er,
        sumIf(c.revenue_amount, ct.care_type = 'DAYCASE')       as oasis_revenue_daycase,
        sumIf(c.revenue_amount, ifNull(ct.care_type, 'Unknown') = 'Unknown') as oasis_revenue_unknown,
        sum(c.revenue_amount)                                   as oasis_revenue_total
    from {{ ref('fact_charge_line') }} as c
    inner join first_gl as fg on fg.branch_key = c.branch_key
    left join (select care_type_key, care_type from {{ ref('dim_care_type') }}) as ct on ct.care_type_key = c.care_type_key
    where toStartOfMonth(toDate(toString(c.delivery_date_key))) >= fg.first_month
    group by c.branch_key, month_start
    {{ hnh_settings() }} -- CTE-level setting: an unmatched care type must be NULL so ifNull maps it to 'Unknown'
),

spine as (
    select branch_key, month_start from gl
    union distinct
    select branch_key, month_start from oasis
)

select
    s.branch_key as branch_key, s.month_start as month_start,
    ifNull(g.gl_revenue_op, 0)           as gl_revenue_op,
    ifNull(g.gl_revenue_ip, 0)           as gl_revenue_ip,
    ifNull(g.gl_revenue_er, 0)           as gl_revenue_er,
    ifNull(g.gl_revenue_other, 0)        as gl_revenue_other,
    ifNull(g.gl_revenue_unallocated, 0)  as gl_revenue_unallocated,
    ifNull(g.gl_contractual_discount, 0) as gl_contractual_discount,
    gl_revenue_op + gl_revenue_ip + gl_revenue_er + gl_revenue_other + gl_revenue_unallocated - gl_contractual_discount as gl_net_revenue,
    ifNull(o.oasis_revenue_op, 0)      as oasis_revenue_op,
    ifNull(o.oasis_revenue_ip, 0)      as oasis_revenue_ip,
    ifNull(o.oasis_revenue_er, 0)      as oasis_revenue_er,
    ifNull(o.oasis_revenue_daycase, 0) as oasis_revenue_daycase,
    ifNull(o.oasis_revenue_unknown, 0) as oasis_revenue_unknown,
    ifNull(o.oasis_revenue_total, 0)   as oasis_revenue_total,
    gl_net_revenue - oasis_revenue_total                                            as difference,
    if(oasis_revenue_total = 0, cast(null as Nullable(Float64)), gl_net_revenue / oasis_revenue_total) as ratio
from spine as s
left join gl as g on g.branch_key = s.branch_key and g.month_start = s.month_start
left join oasis as o on o.branch_key = s.branch_key and o.month_start = s.month_start
{{ hnh_settings() }}
