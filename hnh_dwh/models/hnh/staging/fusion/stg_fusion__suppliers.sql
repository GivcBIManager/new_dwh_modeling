select
    vendor_id,
    vendor_site_id,
    vendor_number                           as supplier_number,
    {{ hnh_str('vendor_name') }}            as supplier_name,
    {{ hnh_str('vendor_type_code') }}       as supplier_type,
    {{ hnh_str('supplier_status') }}        as supplier_status,
    {{ hnh_str('vendor_site_code') }}       as site_code,
    business_unit_id,
    {{ hnh_str('country') }}                as country
from {{ hnh_fusion_source('dim_supplier') }} final
