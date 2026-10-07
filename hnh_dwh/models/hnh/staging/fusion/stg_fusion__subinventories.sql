select
    organization_id,
    assumeNotNull({{ hnh_code('secondary_inventory_name') }}) as subinventory_code,
    {{ hnh_str('description') }}            as subinventory_description,
    toUInt8(disable_date is not null and disable_date <= now()) as is_disabled
from {{ hnh_fusion_source('dim_subinventory') }} final
where {{ hnh_code('secondary_inventory_name') }} is not null  -- a nameless subinventory would collide with the org-level '*' store key
