{{ config(alias='dim_supplier', order_by='supplier_key') }}

-- Fusion supplier sites (Phase 3, keys unchanged) and Oasis supplier accounts (account type S) per branch (spec 5.4).
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
    country,
    'fusion'                    as source_system,
    toString(supplier_number)   as supplier_code,
    cast(null as Nullable(UInt8)) as oasis_branch_key
from {{ ref('stg_fusion__suppliers') }}

union all

select
    {{ hnh_surrogate_key(["'oasis'", 'branch_id', 'account_code']) }},
    null, null, null, account_name, 'Oasis supplier', null, null, null, null,
    'oasis', account_code, toNullable(branch_id)
from {{ ref('stg_oasis__external_accounts') }}
where account_type = 'S' and account_code is not null

union all

select toInt64(-1), null, null, null, 'Unknown', null, null, null, null, null, 'unknown', null, null
