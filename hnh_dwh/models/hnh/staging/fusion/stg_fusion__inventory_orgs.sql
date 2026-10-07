select
    organization_id,
    {{ hnh_code('organization_code') }}     as organization_code,
    {{ hnh_str('organization_name') }}      as organization_name,
    business_unit_id
from {{ hnh_fusion_source('dim_inventory_org') }} final
