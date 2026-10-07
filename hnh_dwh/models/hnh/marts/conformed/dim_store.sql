{{ config(order_by='store_key') }}

-- One row per Oasis store (branch + c_id) and per Fusion store (organisation + subinventory) (spec 5.2). Every Fusion
-- organisation also has an organisation-level member, subinventory '*', for stock valued without a subinventory split.
-- Type and unified department come from map_store_department; a store with no mapping row is 'Unmapped'. An Oasis store
-- and the Fusion store it maps to through the integration share store_group_key.
with oasis_ids as (
    select branch_id, store_id, any(store_name) as known_name from (
        select branch_id, store_id, toNullable(store_name) as store_name from {{ ref('stg_oasis__stores') }}
        union all
        select branch_key, assumeNotNull(store_id), cast(null as Nullable(String))
        from {{ ref('int_oasis_stock_line') }} where store_id is not null group by branch_key, store_id
        union all
        select branch_key, assumeNotNull(transfer_store_id), cast(null as Nullable(String))
        from {{ ref('int_oasis_stock_line') }} where transfer_store_id is not null group by branch_key, transfer_store_id
        union all
        select branch_id, assumeNotNull(store_id), cast(null as Nullable(String))
        from {{ ref('stg_oasis__stock_document_lines') }} where doc_type = 'PORDER' and store_id is not null group by branch_id, store_id
        union all
        select branch_id, store_id, cast(null as Nullable(String)) from {{ ref('stg_oasis__stock_batch_snapshots') }} group by branch_id, store_id
        union all
        select branch_id, store_id, cast(null as Nullable(String)) from {{ ref('stg_ref__stock_snapshot') }} group by branch_id, store_id
    )
    group by branch_id, store_id
),

fusion_ids as (
    select organization_id, subinventory_code, any(description) as known_description from (
        select organization_id, subinventory_code, subinventory_description as description from {{ ref('stg_fusion__subinventories') }}
        union all
        select organization_id, '*', cast(null as Nullable(String)) from {{ ref('stg_fusion__inventory_orgs') }}
        union all
        select assumeNotNull(organization_id), ifNull(subinventory_code, '*'), cast(null as Nullable(String))
        from {{ ref('int_fusion_stock_line') }} where organization_id is not null group by organization_id, subinventory_code
        union all
        select assumeNotNull(transfer_organization_id), ifNull(transfer_subinventory, '*'), cast(null as Nullable(String))
        from {{ ref('int_fusion_stock_line') }} where transfer_organization_id is not null
        group by transfer_organization_id, transfer_subinventory
        union all
        select assumeNotNull(organization_id), ifNull(subinventory_code, '*'), cast(null as Nullable(String))
        from {{ ref('stg_fusion__inventory_onhand') }} where organization_id is not null group by organization_id, subinventory_code
        union all
        select assumeNotNull(organization_id), ifNull(subinventory_code, '*'), cast(null as Nullable(String))
        from {{ ref('stg_fusion__receipt_transactions') }} where organization_id is not null group by organization_id, subinventory_code
    )
    group by organization_id, subinventory_code
),

oasis_stores as (
    select
        {{ hnh_surrogate_key(["'oasis'", 'o.branch_id', 'o.store_id']) }}  as store_key,
        'oasis'                                                            as source_system,
        o.branch_id                                                        as branch_key,
        toString(o.store_id)                                               as store_code,
        coalesce(m.store_name, o.known_name, concat('Store ', toString(o.store_id))) as store_name,
        cast(null as Nullable(Int64))                                      as organization_id,
        cast(null as Nullable(String))                                     as subinventory_code,
        toNullable(o.store_id)                                             as oasis_store_id,
        ifNull(m.store_type, 'Unmapped')                                   as store_type,
        ifNull(m.unified_department, 'Not Mapped')                         as unified_department,
        if(x.organization_id is null, {{ hnh_surrogate_key(["'oasis'", 'o.branch_id', 'o.store_id']) }},
           {{ hnh_fusion_store_key('x.organization_id', 'x.subinventory_code') }}) as store_group_key
    from oasis_ids as o
    left join (select branch_id, store_code, store_name, store_type, unified_department
               from {{ ref('stg_ref__store_department') }} where source = 'oasis') as m
        on m.branch_id = o.branch_id and m.store_code = toString(o.store_id)
    left join {{ ref('int_store_crosswalk') }} as x on x.branch_key = o.branch_id and x.store_id = o.store_id
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
),

fusion_stores as (
    select
        {{ hnh_fusion_store_key('f.organization_id', 'f.subinventory_code') }} as store_key,
        'fusion'                                                           as source_system,
        ifNull(g.branch_key, toUInt8(0))                                   as branch_key,
        concat(ifNull(g.organization_code, toString(f.organization_id)), '/', f.subinventory_code) as store_code,
        coalesce(m.store_name, f.known_description,
                 if(f.subinventory_code = '*', g.organization_name, f.subinventory_code)) as store_name,
        toNullable(f.organization_id)                                      as organization_id,
        toNullable(f.subinventory_code)                                    as subinventory_code,
        cast(null as Nullable(Int64))                                      as oasis_store_id,
        ifNull(m.store_type, 'Unmapped')                                   as store_type,
        ifNull(m.unified_department, 'Not Mapped')                         as unified_department,
        {{ hnh_fusion_store_key('f.organization_id', 'f.subinventory_code') }} as store_group_key
    from fusion_ids as f
    left join {{ ref('int_inventory_org_branch') }} as g on g.organization_id = f.organization_id
    left join (select store_code, store_name, store_type, unified_department
               from {{ ref('stg_ref__store_department') }} where source = 'fusion') as m
        on m.store_code = concat(ifNull(g.organization_code, toString(f.organization_id)), '/', f.subinventory_code)
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
)

select *, toUInt8(store_type = 'Expiry/damaged/recall') as is_expiry_store from oasis_stores
union all
select *, toUInt8(store_type = 'Expiry/damaged/recall') from fusion_stores
union all
select toInt64(-1), 'unknown', toUInt8(0), '', 'Unknown', null, null, null, 'Unmapped', 'Not Mapped', toInt64(-1), toUInt8(0)
{{ hnh_settings() }}
