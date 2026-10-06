{{ config(order_by='(branch_key, month_date_key, store_key, item_key)') }}

-- Month-end stock per branch, store and item (spec 6.4) with the month's consumption from fact_stock_movement for
-- turnover and days of stock. A store and item with consumption but no stock that month gets a row with quantity 0.
-- Keys are resolved against dim_store and hnh_dim_item first (unknown = -1); the grain and the row key use the
-- resolved keys, so two unresolved stores or items of one month fold into one -1 row.
-- A snapshot: never sum quantity or stock_value across months.
with stock as (
    select branch_key, month_end, store_key, item_key, quantity as part_quantity, stock_value as part_value,
           stock_source as part_stock_source, source_system as part_source_system, has_expired_lot as part_expired,
           toFloat64(0) as part_consumption_quantity, toFloat64(0) as part_consumption_cost
    from {{ ref('int_stock_month_end') }}
),

branch_months as (
    select branch_key, month_end, any(part_stock_source) as month_stock_source, any(part_source_system) as month_source_system
    from stock
    group by branch_key, month_end
),

consumption as (
    select m.branch_key as branch_key, toDate(toLastDayOfMonth(toDate(toString(m.date_key)))) as month_end,
           m.store_key as store_key, m.item_key as item_key, toFloat64(0) as part_quantity, toFloat64(0) as part_value,
           b.month_stock_source as part_stock_source, b.month_source_system as part_source_system, toUInt8(0) as part_expired,
           sum(m.consumption_quantity) as part_consumption_quantity, sum(m.consumption_cost) as part_consumption_cost
    from {{ ref('fact_stock_movement') }} as m
    inner join branch_months as b
        on b.branch_key = m.branch_key and b.month_end = toDate(toLastDayOfMonth(toDate(toString(m.date_key))))
    where m.is_consumption = 1
    group by m.branch_key, month_end, m.store_key, m.item_key, b.month_stock_source, b.month_source_system
),

combined as (
    select * from stock
    union all
    select * from consumption
),

resolved as (
    select c.branch_key as k_branch_key, c.month_end as k_month_end,
           ifNull(s.store_key, toInt64(-1)) as k_store_key, ifNull(i.item_key, toInt64(-1)) as k_item_key,
           ifNull(s.is_expiry_store, toUInt8(0)) as k_expiry_store,
           c.part_quantity as k_quantity, c.part_value as k_value, c.part_stock_source as k_stock_source,
           c.part_source_system as k_source_system, c.part_expired as k_expired,
           c.part_consumption_quantity as k_consumption_quantity, c.part_consumption_cost as k_consumption_cost
    from combined as c
    left join (select store_key, is_expiry_store from {{ ref('dim_store') }}) as s on s.store_key = c.store_key
    left join (select item_key from {{ ref('hnh_dim_item') }}) as i on i.item_key = c.item_key
    {{ hnh_settings() }}  -- left joins in a CTE: settings must sit here
)

select
    {{ hnh_surrogate_key(['k_branch_key', 'k_month_end', 'k_store_key', 'k_item_key']) }} as stock_monthly_key,
    k_branch_key                                            as branch_key,
    {{ hnh_date_key('k_month_end') }}                       as month_date_key,
    k_month_end                                             as month_end,
    k_store_key                                             as store_key,
    k_item_key                                              as item_key,
    sum(k_quantity)                                         as quantity,
    sum(k_value)                                            as stock_value,
    any(k_stock_source)                                     as stock_source,
    any(k_source_system)                                    as source_system,
    max(k_expiry_store)                                     as is_expiry_store,
    toUInt8(k_month_end < today())                          as is_closed_month,
    max(k_expired)                                          as has_expired_lot,
    sum(k_consumption_quantity)                             as consumption_quantity,
    sum(k_consumption_cost)                                 as consumption_cost,
    now()                                                   as _loaded_at
from resolved
group by k_branch_key, k_month_end, k_store_key, k_item_key
{{ hnh_settings() }}
