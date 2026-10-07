select
    transaction_id,
    assumeNotNull({{ hnh_str('lot_number') }}) as lot_number,
    inventory_item_id,
    organization_id,
    toFloat64(ifNull(primary_quantity, 0))  as primary_quantity
from {{ hnh_fusion_source('fact_inventory_transaction_lot') }} final
where {{ hnh_str('lot_number') }} is not null
