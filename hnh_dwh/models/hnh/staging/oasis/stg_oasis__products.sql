-- Product per store, current state only (spec F10): average cost per base unit and on-hand quantity.
-- A few raw codes differ only by leading blanks (22 rows); one row is kept per trimmed code, preferring the row whose
-- raw code is already trimmed, then the larger on-hand quantity.
with base as (
    select
        toUInt8(branch_id)                      as branch_id,
        trimBoth(product_code)                  as product_code,
        product_code = trimBoth(product_code)   as is_trimmed,
        toInt64(c_id)                           as store_id,
        {{ hnh_str('product_description') }}    as product_description,
        {{ hnh_code('product_category_code') }} as product_category_code,
        toFloat64(ifNull(qty_on_hand, 0))       as qty_on_hand,
        toFloat64(ifNull(average_cost, 0))      as average_cost,
        {{ hnh_code('stocked_uom_code') }}      as stocked_uom_code,
        {{ hnh_code('write_down_indicator') }}  as item_type_code
    from {{ hnh_oasis_source('product_base') }} final
)

select
    branch_id, product_code, store_id, product_description, product_category_code,
    qty_on_hand, average_cost, stocked_uom_code, item_type_code
from base
order by is_trimmed desc, qty_on_hand desc
limit 1 by branch_id, store_id, product_code
