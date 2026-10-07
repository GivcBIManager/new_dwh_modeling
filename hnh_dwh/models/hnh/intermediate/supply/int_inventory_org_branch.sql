{{ config(order_by='organization_id') }}

-- Inventory organisation -> business unit -> primary ledger -> branch (spec 4.1, F3). An organisation that does not
-- resolve gets branch 0, which the facts' tests reject. org_type_code is the two-digit organisation type
-- (01-03 warehouses, 04-12 department organisations, 00 the item master).
select
    o.organization_id                                   as organization_id,
    ifNull(o.organization_code, '')                     as organization_code,
    ifNull(o.organization_name, '')                     as organization_name,
    ifNull(b.branch_key, toUInt8(0))                    as branch_key,
    {{ hnh_org_type_code('o.organization_code') }}      as org_type_code
from {{ ref('stg_fusion__inventory_orgs') }} as o
left join (select business_unit_id, primary_ledger_id from {{ ref('stg_fusion__business_units') }}) as bu
    on bu.business_unit_id = o.business_unit_id
left join (select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null) as b
    on b.fusion_ledger_id = bu.primary_ledger_id
{{ hnh_settings() }}
