{{ config(order_by='(branch_key, month_end, store_key, item_key)') }}

-- Month-end stock per branch, store and item (spec 6.4, S5). The source of a branch's month-end is the first that applies:
--   1 fusion_valuation: the branch is live on Fusion inventory (go-live on or before the month-end);
--   2 snapshot: an old-warehouse snapshot (bal_product_base) exists in the month (its last snapshot day);
--   3 oasis_batch: an Oasis batch snapshot exists in the month (its last snapshot day);
--   4 derived: a month after the branch's last old snapshot and before its first Oasis batch month, rolled back from
--     that first batch month-end by reversing every in-scope Oasis stock line (int_oasis_stock_line, also lines that
--     fact_stock_movement takes from Fusion and post-go-live batch postings: all changed Oasis on-hand) dated after
--     the month-end and up to the anchor day. Nothing before the first snapshot.
-- Oasis quantities are converted to the item's primary unit. Values: snapshot qty x its average cost; batch and derived
-- qty x the product's current Oasis average cost; Fusion the cumulative valuation layers per organisation and item, split
-- across subinventories by the Fusion on-hand snapshot of the same month where one exists, else at organisation level '*'.
-- Oasis batch expiry dates before 2000-01-01 are "no expiry" (1900-era values) and never make a lot expired.
{% set last_month_end = hnh_stock_last_month_end() %}

with cutover as (
    select branch_id, assumeNotNull(inventory_go_live_date) as go_live_date
    from {{ ref('stg_ref__scm_cutover') }}
    where inventory_go_live_date is not null
),

crosswalk as (
    select branch_key, product_code, inventory_item_id, units_per_primary from {{ ref('int_item_crosswalk') }}
),

average_cost as (
    select branch_id, product_code, ifNotFinite(avgIf(average_cost, average_cost > 0), 0) as product_average_cost
    from {{ ref('stg_oasis__products') }}
    group by branch_id, product_code
),

snapshot_days as (
    select branch_id, toDate(toLastDayOfMonth(snapshot_date)) as month_end, max(snapshot_date) as snapshot_day
    from {{ ref('stg_ref__stock_snapshot') }}
    where snapshot_date <= {{ last_month_end }}
    group by branch_id, month_end
),

batch_days as (
    select branch_id, toDate(toLastDayOfMonth(snapshot_date)) as month_end, max(snapshot_date) as snapshot_day
    from {{ ref('stg_oasis__stock_batch_snapshots') }}
    where snapshot_date <= {{ last_month_end }}
    group by branch_id, month_end
),

fusion_month_ends as (
    select c.branch_id as branch_id,
           toDate(toLastDayOfMonth(addMonths(toStartOfMonth(c.go_live_date), toInt32(n.number)))) as month_end
    from cutover as c
    cross join numbers(240) as n
    where month_end <= {{ last_month_end }}
),

derived_month_ends as (
    select s.branch_id as branch_id,
           toDate(toLastDayOfMonth(addMonths(toStartOfMonth(s.last_snapshot_month_end), toInt32(n.number) + 1))) as month_end
    from (select branch_id, max(month_end) as last_snapshot_month_end from snapshot_days group by branch_id) as s
    inner join (select branch_id, min(month_end) as first_batch_month_end from batch_days group by branch_id) as b
        on b.branch_id = s.branch_id
    cross join numbers(240) as n
    where month_end < b.first_batch_month_end
),

candidates as (
    select branch_id, month_end, 'fusion_valuation' as stock_source, toUInt8(1) as priority from fusion_month_ends
    union all
    select branch_id, month_end, 'snapshot', toUInt8(2) from snapshot_days
    union all
    select branch_id, month_end, 'oasis_batch', toUInt8(3) from batch_days
    union all
    select branch_id, month_end, 'derived', toUInt8(4) from derived_month_ends
),

chosen as (
    select branch_id, month_end, argMin(stock_source, priority) as chosen_source
    from candidates
    group by branch_id, month_end
),

snapshot_rows as (
    select s.branch_id as branch_id, d.month_end as month_end, toDate(d.snapshot_day) as snapshot_date, s.store_id as store_id,
           s.product_code as product_code, s.qty_on_hand as base_quantity, s.qty_on_hand * s.average_cost as snapshot_value,
           toUInt8(0) as has_expired_lot
    from {{ ref('stg_ref__stock_snapshot') }} as s
    inner join snapshot_days as d on d.branch_id = s.branch_id and d.snapshot_day = s.snapshot_date
    inner join (select branch_id, month_end from chosen where chosen_source = 'snapshot') as k
        on k.branch_id = d.branch_id and k.month_end = d.month_end
),

batch_rows as (
    -- an expiry before 2000-01-01 is Oasis "no expiry"
    select b.branch_id as branch_id, d.month_end as month_end, toDate(d.snapshot_day) as snapshot_date, b.store_id as store_id,
           b.product_code as product_code, sum(b.quantity) as base_quantity,
           max(toUInt8(b.expiry_date is not null and b.expiry_date >= toDate32('2000-01-01')
                       and b.expiry_date < d.month_end and b.quantity > 0)) as has_expired_lot
    from {{ ref('stg_oasis__stock_batch_snapshots') }} as b
    inner join batch_days as d on d.branch_id = b.branch_id and d.snapshot_day = b.snapshot_date
    group by b.branch_id, d.month_end, d.snapshot_day, b.store_id, b.product_code
),

anchor as (
    -- the first Oasis batch month-end of each branch: the known balance the derived months roll back from
    select branch_id, min(month_end) as anchor_month_end, argMin(snapshot_day, month_end) as anchor_day
    from batch_days
    group by branch_id
),

derived_range as (
    -- the first derived month-end of each branch: lines on or before it change no derived month
    select branch_id, min(month_end) as first_derived_month_end
    from chosen
    where chosen_source = 'derived'
    group by branch_id
),

derived_parts as (
    -- anchor stock, plus each later in-scope Oasis line with its sign reversed; a derived month sums the parts dated
    -- after it
    select r.branch_id as branch_id, r.month_end as part_month_end,
           {{ hnh_surrogate_key(["'oasis'", 'r.branch_id', 'r.store_id']) }} as part_store_key,
           {{ hnh_stock_item_key('x.inventory_item_id', 'r.branch_id', 'r.product_code') }} as part_item_key,
           toNullable(r.product_code) as part_product_code,
           {{ hnh_primary_qty('r.base_quantity', 'x.units_per_primary') }} as part_quantity
    from batch_rows as r
    inner join anchor as a on a.branch_id = r.branch_id and a.anchor_month_end = r.month_end
    left join crosswalk as x on x.branch_key = r.branch_id and x.product_code = r.product_code
    where r.branch_id in (select branch_id from derived_range)
    {{ hnh_settings() }}  -- left join in a CTE that feeds a union: settings must sit here

    union all

    select m.branch_key, toDate(toLastDayOfMonth(m.line_date)),
           {{ hnh_surrogate_key(["'oasis'", 'm.branch_key', 'm.store_id']) }},
           m.item_key, m.product_code, 0 - m.primary_quantity
    from {{ ref('int_oasis_stock_line') }} as m
    inner join anchor as a on a.branch_id = m.branch_key
    inner join derived_range as g on g.branch_id = m.branch_key
    where m.line_date > g.first_derived_month_end and m.line_date <= a.anchor_day
),

derived_month_parts as (
    -- the parts summed per month first, so the rollback join below meets one row per store, item and month
    select branch_id as pm_branch_id, part_month_end as pm_month_end, part_store_key as pm_store_key,
           part_item_key as pm_item_key, anyIf(part_product_code, part_product_code is not null) as pm_product_code,
           sum(part_quantity) as pm_quantity
    from derived_parts
    group by branch_id, part_month_end, part_store_key, part_item_key
),

derived_rows as (
    select d.branch_id as branch_id, d.month_end as month_end, p.pm_store_key as store_key, p.pm_item_key as item_key,
           anyIf(p.pm_product_code, p.pm_product_code is not null) as product_code, sum(p.pm_quantity) as derived_quantity
    from (select branch_id, month_end from chosen where chosen_source = 'derived') as d
    inner join derived_month_parts as p on p.pm_branch_id = d.branch_id and p.pm_month_end > d.month_end
    group by d.branch_id, d.month_end, p.pm_store_key, p.pm_item_key
),

oasis_rows as (
    select s.branch_id as branch_id, s.month_end as month_end, s.snapshot_date as snapshot_date,
           {{ hnh_surrogate_key(["'oasis'", 's.branch_id', 's.store_id']) }} as store_key,
           {{ hnh_stock_item_key('x.inventory_item_id', 's.branch_id', 's.product_code') }} as item_key,
           toNullable(s.product_code) as oasis_product_code,
           {{ hnh_primary_qty('s.base_quantity', 'x.units_per_primary') }} as quantity,
           s.snapshot_value as stock_value, 'snapshot' as stock_source, s.has_expired_lot as has_expired_lot
    from snapshot_rows as s
    left join crosswalk as x on x.branch_key = s.branch_id and x.product_code = s.product_code
    {{ hnh_settings() }}  -- left join in a CTE that feeds a union: settings must sit here

    union all

    select b.branch_id, b.month_end, b.snapshot_date,
           {{ hnh_surrogate_key(["'oasis'", 'b.branch_id', 'b.store_id']) }},
           {{ hnh_stock_item_key('x.inventory_item_id', 'b.branch_id', 'b.product_code') }},
           toNullable(b.product_code),
           {{ hnh_primary_qty('b.base_quantity', 'x.units_per_primary') }},
           b.base_quantity * ifNull(c.product_average_cost, 0), 'oasis_batch', b.has_expired_lot
    from batch_rows as b
    inner join (select branch_id, month_end from chosen where chosen_source = 'oasis_batch') as k
        on k.branch_id = b.branch_id and k.month_end = b.month_end
    left join crosswalk as x on x.branch_key = b.branch_id and x.product_code = b.product_code
    left join average_cost as c on c.branch_id = b.branch_id and c.product_code = b.product_code
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here

    union all

    select r.branch_id, r.month_end, r.month_end, r.store_key, r.item_key, r.product_code, r.derived_quantity,
           r.derived_quantity * ifNull(x.units_per_primary, 1) * ifNull(c.product_average_cost, 0), 'derived', toUInt8(0)
    from derived_rows as r
    left join crosswalk as x on x.branch_key = r.branch_id and x.product_code = r.product_code
    left join average_cost as c on c.branch_id = r.branch_id and c.product_code = r.product_code
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
),

layers as (
    select o.branch_key as branch_id, v.inventory_org_id as organization_id, v.inventory_item_id as inventory_item_id,
           v.cost_date as cost_date, v.quantity as layer_quantity, v.quantity * v.unit_cost as layer_value
    from {{ ref('stg_fusion__inventory_valuation') }} as v
    inner join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = v.inventory_org_id
    where v.posted_flag in ('Y', 'E')
),

org_balances as (
    select k.branch_id as branch_id, k.month_end as month_end, l.organization_id as organization_id,
           l.inventory_item_id as inventory_item_id, sum(l.layer_quantity) as org_quantity, sum(l.layer_value) as org_value
    from (select branch_id, month_end from chosen where chosen_source = 'fusion_valuation') as k
    inner join layers as l on l.branch_id = k.branch_id and l.cost_date <= k.month_end
    group by k.branch_id, k.month_end, l.organization_id, l.inventory_item_id
    having abs(org_quantity) > 0.000001 or abs(org_value) > 0.01
),

onhand_days as (
    select toDate(toLastDayOfMonth(snapshot_date)) as month_end, max(snapshot_date) as onhand_day
    from {{ ref('stg_fusion__inventory_onhand') }}
    where snapshot_date is not null
    group by month_end
),

onhand as (
    select d.month_end as month_end, h.organization_id as organization_id, h.inventory_item_id as inventory_item_id,
           ifNull(h.subinventory_code, '*') as onhand_subinventory, sum(h.primary_quantity) as sub_quantity,
           max(toUInt8(lt.expiration_date is not null and lt.expiration_date < d.month_end and h.primary_quantity > 0)) as sub_expired
    from {{ ref('stg_fusion__inventory_onhand') }} as h
    inner join onhand_days as d on d.onhand_day = h.snapshot_date
    left join {{ ref('stg_fusion__lots') }} as lt
        on lt.inventory_item_id = h.inventory_item_id and lt.organization_id = h.organization_id and lt.lot_number = h.lot_number
    group by d.month_end, h.organization_id, h.inventory_item_id, h.subinventory_code
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

onhand_shares as (
    select o.month_end as month_end, o.organization_id as organization_id, o.inventory_item_id as inventory_item_id,
           o.onhand_subinventory as onhand_subinventory, o.sub_quantity / t.total_quantity as share, o.sub_expired as sub_expired
    from onhand as o
    inner join (select month_end, organization_id, inventory_item_id, sum(sub_quantity) as total_quantity
                from onhand group by month_end, organization_id, inventory_item_id having total_quantity > 0) as t
        on t.month_end = o.month_end and t.organization_id = o.organization_id and t.inventory_item_id = o.inventory_item_id
),

fusion_rows as (
    select b.branch_id as branch_id, b.month_end as month_end, least(b.month_end, today()) as snapshot_date,
           {{ hnh_fusion_store_key('b.organization_id', 's.onhand_subinventory') }} as store_key,
           {{ hnh_surrogate_key(['b.inventory_item_id']) }} as item_key,
           cast(null as Nullable(String)) as oasis_product_code,
           b.org_quantity * ifNull(s.share, 1) as quantity,
           b.org_value * ifNull(s.share, 1) as stock_value,
           'fusion_valuation' as stock_source,
           ifNull(s.sub_expired, toUInt8(0)) as has_expired_lot
    from org_balances as b
    left join onhand_shares as s
        on s.month_end = b.month_end and s.organization_id = b.organization_id and s.inventory_item_id = b.inventory_item_id
    {{ hnh_settings() }}  -- left join in a CTE that feeds a union: settings must sit here
),

all_rows as (
    select branch_id as r_branch_key, month_end as r_month_end, snapshot_date as r_snapshot_date, store_key as r_store_key,
           item_key as r_item_key, oasis_product_code as r_product_code, quantity as r_quantity, stock_value as r_value,
           stock_source as r_stock_source, 'oasis' as r_source_system, has_expired_lot as r_expired
    from oasis_rows
    union all
    select branch_id, month_end, snapshot_date, store_key, item_key, oasis_product_code, quantity, stock_value,
           stock_source, 'fusion', has_expired_lot
    from fusion_rows
)

-- one row per branch, month-end, store and item (two Oasis products can map to one Fusion item)
select
    r_branch_key                                            as branch_key,
    r_month_end                                             as month_end,
    max(r_snapshot_date)                                    as snapshot_date,
    r_store_key                                             as store_key,
    r_item_key                                              as item_key,
    anyIf(r_product_code, r_product_code is not null)       as oasis_product_code,
    sum(r_quantity)                                         as quantity,
    sum(r_value)                                            as stock_value,
    any(r_stock_source)                                     as stock_source,
    any(r_source_system)                                    as source_system,
    max(r_expired)                                          as has_expired_lot
from all_rows
group by r_branch_key, r_month_end, r_store_key, r_item_key
{{ hnh_settings() }}
