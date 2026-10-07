-- Cost layers (spec F6). unit_cost is text in the source; quantity is signed (issues negative).
select
    layer_cost_id,
    inventory_org_id,
    inventory_item_id,
    base_txn_type_id,
    {{ hnh_code('cost_transaction_type') }} as cost_transaction_type,
    {{ hnh_code('posted_flag') }}           as posted_flag,
    assumeNotNull(toDate(cost_date))        as cost_date,
    toFloat64(ifNull(quantity, 0))          as quantity,
    ifNull(toFloat64OrNull(trimBoth(ifNull(unit_cost, ''))), 0) as unit_cost
from {{ hnh_fusion_source('fact_inventory_valuation') }} final
where cost_date is not null
