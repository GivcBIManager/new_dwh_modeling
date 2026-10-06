{{ config(order_by='(branch_key, month_start)') }}

-- Per branch and month from the first Fusion inventory month (spec 8): Fusion valuation stock value at the month-end
-- (all organisations of the branch), the GL balance of the inventory accounts (natural account 115*) at the last
-- period of the month, the accounted share of the month's cost distributions, and the difference. Not expected to tie
-- from July 2026 (cost accounting backlog, spec F11); Abha carries CEFODOX as recorded.
{% set start = "toDate('" ~ var('hnh_fusion_inventory_start') ~ "')" %}

with months as (
    select toStartOfMonth(addMonths({{ start }}, toInt32(number))) as month_start
    from numbers(toUInt64(dateDiff('month', {{ start }}, today()) + 1))
),

layers as (
    select o.branch_key as branch_key, v.cost_date as cost_date, v.quantity * v.unit_cost as layer_value
    from {{ ref('stg_fusion__inventory_valuation') }} as v
    inner join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = v.inventory_org_id
    where v.posted_flag in ('Y', 'E')
),

valuation as (
    select l.branch_key as branch_key, m.month_start as month_start, sum(l.layer_value) as fusion_stock_value
    from months as m
    inner join layers as l on l.cost_date <= toLastDayOfMonth(m.month_start)
    group by l.branch_key, m.month_start
),

gl as (
    select b.branch_key as branch_key, p.month_start as month_start,
           sumIf(b.closing_balance, b.balance_view = 'posted') as gl_inventory_posted,
           sumIf(b.closing_balance, b.balance_view = 'including_unposted') as gl_inventory_including_unposted
    from {{ ref('fact_gl_balance_monthly') }} as b
    inner join (select gl_account_key from {{ ref('hnh_dim_gl_account') }}
                where toString(ifNull(natural_account, 0)) like '115%') as a on a.gl_account_key = b.gl_account_key
    inner join (select month_start, max(period_key) as last_period_key from {{ ref('hnh_dim_gl_period') }}
                group by month_start) as p on p.last_period_key = b.period_key
    group by b.branch_key, p.month_start
),

distributions as (
    select br.branch_key as branch_key, toStartOfMonth(assumeNotNull(d.gl_date)) as month_start, count() as cost_distribution_lines,
           countIf(d.accounted_flag = 'F') as accounted_lines
    from {{ ref('stg_fusion__cost_distributions') }} as d
    inner join (select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null) as br
        on br.fusion_ledger_id = d.ledger_id
    where d.gl_date is not null
    group by br.branch_key, month_start
),

spine as (
    select branch_key, month_start from valuation
    union distinct select branch_key, month_start from gl where month_start between {{ start }} and toStartOfMonth(today())
    union distinct select branch_key, month_start from distributions
)

select
    s.branch_key                                            as branch_key,
    s.month_start                                           as month_start,
    ifNull(v.fusion_stock_value, 0)                         as fusion_stock_value,
    ifNull(g.gl_inventory_posted, 0)                        as gl_inventory_posted,
    ifNull(g.gl_inventory_including_unposted, 0)            as gl_inventory_including_unposted,
    ifNull(d.cost_distribution_lines, 0)                    as cost_distribution_lines,
    ifNull(d.accounted_lines, 0)                            as accounted_lines,
    if(ifNull(d.cost_distribution_lines, 0) = 0, cast(null as Nullable(Float64)),
       d.accounted_lines / d.cost_distribution_lines)       as accounted_share,
    ifNull(v.fusion_stock_value, 0) - ifNull(g.gl_inventory_posted, 0) as difference_posted
from spine as s
left join valuation as v on v.branch_key = s.branch_key and v.month_start = s.month_start
left join gl as g on g.branch_key = s.branch_key and g.month_start = s.month_start
left join distributions as d on d.branch_key = s.branch_key and d.month_start = s.month_start
{{ hnh_settings() }}
