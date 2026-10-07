select
    inventory_item_id,
    organization_id,
    {{ hnh_str('category_set_name') }}      as category_set_name,
    {{ hnh_str('category_code') }}          as category_code,
    {{ hnh_str('category_description') }}   as category_description
from {{ hnh_fusion_source('dim_item_category') }} final
