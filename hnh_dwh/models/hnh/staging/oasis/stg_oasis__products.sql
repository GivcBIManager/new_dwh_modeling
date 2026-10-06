-- Product per store, current state only (spec F10): average cost per base unit and on-hand quantity.
select
    toUInt8(branch_id)                      as branch_id,
    trimBoth(product_code)                  as product_code,
    toInt64(c_id)                           as store_id,
    {{ hnh_str('product_description') }}    as product_description,
    {{ hnh_code('product_category_code') }} as product_category_code,
    toFloat64(ifNull(qty_on_hand, 0))       as qty_on_hand,
    toFloat64(ifNull(average_cost, 0))      as average_cost,
    {{ hnh_code('stocked_uom_code') }}      as stocked_uom_code,
    {{ hnh_code('write_down_indicator') }}  as item_type_code
from {{ hnh_oasis_source('product_base') }} final
