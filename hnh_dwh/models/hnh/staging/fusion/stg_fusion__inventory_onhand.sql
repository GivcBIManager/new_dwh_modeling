select
    onhand_quantities_id,
    toDate(snapshot_date)                   as snapshot_date,
    inventory_item_id,
    organization_id,
    {{ hnh_code('subinventory_code') }}     as subinventory_code,
    {{ hnh_str('lot_number') }}             as lot_number,
    toFloat64(ifNull(primary_transaction_quantity, 0)) as primary_quantity
from {{ hnh_fusion_source('fact_inventory_onhand') }} final
