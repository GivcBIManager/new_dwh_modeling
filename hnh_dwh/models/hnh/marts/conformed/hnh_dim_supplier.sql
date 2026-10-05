{{ config(alias='dim_supplier', order_by='supplier_key') }}

select
    {{ hnh_surrogate_key(['vendor_id', 'vendor_site_id']) }} as supplier_key,
    toNullable(vendor_id)       as vendor_id,
    toNullable(vendor_site_id)  as vendor_site_id,
    supplier_number,
    supplier_name,
    supplier_type,
    supplier_status,
    site_code,
    business_unit_id,
    country
from {{ ref('stg_fusion__suppliers') }}

union all

select toInt64(-1), null, null, null, 'Unknown', null, null, null, null, null
