select
    inventory_item_id,
    organization_id,
    {{ hnh_str('item_number') }}            as item_number,
    {{ hnh_str('item_description') }}       as item_description,
    {{ hnh_code('primary_uom_code') }}      as primary_uom_code,
    {{ hnh_code('item_type') }}             as item_type,
    {{ hnh_str('item_status_code') }}       as item_status,
    toUInt8(ifNull(lot_control_code, 1) = 2) as is_lot_controlled
from {{ hnh_fusion_source('dim_item') }} final
