{{ config(alias='dim_item', order_by='item_key') }}

-- Fusion master items (the MST organisation holds every item) and Oasis products that have no Fusion item (spec 5.1).
-- Fusion items carry the Oasis products they map to per branch ("branch:product", through the crosswalk).
{% set master_org = var('hnh_fusion_item_master_org_id') %}
{% set first_day = "toDate32('" ~ var('hnh_history_start_date') ~ "')" %}

with categories as (
    select inventory_item_id, any(category_code) as master_category_code
    from {{ ref('stg_fusion__item_categories') }}
    where organization_id = {{ master_org }} and category_set_name = 'HNH Catalog' and category_code is not null
    group by inventory_item_id
),

products as (
    select branch_id, product_code, any(product_description) as product_name, any(product_category_code) as product_category
    from {{ ref('stg_oasis__products') }}
    group by branch_id, product_code
),

product_groups as (
    select branch_key, assumeNotNull(category_code) as category_code, product_group
    from {{ ref('dim_product_category') }}
    where category_code is not null
),

mapped_products as (
    select x.inventory_item_id as inventory_item_id,
           arrayStringConcat(arraySort(groupUniqArray(concat(toString(x.branch_key), ':', x.product_code))), ', ') as oasis_product_codes,
           topKIf(1)(p.product_category, p.product_category is not null)[1] as mapped_category,
           topKIf(1)(g.product_group, g.product_group is not null)[1] as mapped_product_group
    from {{ ref('int_item_crosswalk') }} as x
    left join products as p on p.branch_id = x.branch_key and p.product_code = x.product_code
    left join product_groups as g on g.branch_key = x.branch_key and g.category_code = p.product_category
    group by x.inventory_item_id
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
),

fusion_items as (
    select
        {{ hnh_stock_item_key('i.inventory_item_id', 'toUInt8(0)', "''") }}               as item_key,
        'fusion'                                                       as source_system,
        toUInt8(0)                                                     as branch_key,
        toNullable(i.inventory_item_id)                                as inventory_item_id,
        i.item_number                                                  as item_number,
        i.item_description                                             as item_description,
        i.primary_uom_code                                             as primary_uom_code,
        i.item_type                                                    as item_type,
        i.item_status                                                  as item_status,
        i.is_lot_controlled                                            as is_lot_controlled,
        c.master_category_code                                         as category_code,
        ifNull(ig.item_group, 'Other')                                 as item_group,
        toUInt8(ifNull(i.item_number, '') like 'Deleted-%')            as is_deleted,
        cast(null as Nullable(String))                                 as oasis_product_code,
        nullIf(m.oasis_product_codes, '')                              as oasis_product_codes,
        nullIf(m.mapped_category, '')                                  as oasis_product_category,
        if(ifNull(m.mapped_product_group, '') = '', 'Not Mapped', m.mapped_product_group) as product_group
    from {{ ref('stg_fusion__items') }} as i
    left join categories as c on c.inventory_item_id = i.inventory_item_id
    left join {{ ref('stg_ref__item_group') }} as ig on ig.category_code = c.master_category_code
    left join mapped_products as m on m.inventory_item_id = i.inventory_item_id
    where i.organization_id = {{ master_org }}
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
),

oasis_used as (
    -- Oasis products that occur in stock lines, purchase orders or stock snapshots and have no Fusion item
    select distinct branch_id, product_code from (
        select branch_key as branch_id, assumeNotNull(product_code) as product_code
        from {{ ref('int_oasis_stock_line') }} where inventory_item_id is null and product_code is not null
        union all
        select branch_id, assumeNotNull(product_code)
        from {{ ref('stg_oasis__stock_document_lines') }}
        where doc_type = 'PORDER' and product_code is not null and line_date >= {{ first_day }}
        union all
        select branch_id, product_code from {{ ref('stg_oasis__stock_batch_snapshots') }}
        union all
        select branch_id, product_code from {{ ref('stg_ref__stock_snapshot') }}
    )
    where (branch_id, product_code) not in (select branch_key, product_code from {{ ref('int_item_crosswalk') }})
),

oasis_items as (
    select
        {{ hnh_stock_item_key('cast(null as Nullable(Int64))', 'u.branch_id', 'u.product_code') }}     as item_key,
        'oasis'                                                        as source_system,
        u.branch_id                                                    as branch_key,
        cast(null as Nullable(Int64))                                  as inventory_item_id,
        toNullable(u.product_code)                                     as item_number,
        p.product_name                                                 as item_description,
        cast(null as Nullable(String))                                 as primary_uom_code,
        cast(null as Nullable(String))                                 as item_type,
        cast(null as Nullable(String))                                 as item_status,
        toUInt8(0)                                                     as is_lot_controlled,
        cast(null as Nullable(String))                                 as category_code,
        multiIf(g.product_group = 'medication', 'Medication', g.product_group = 'medical', 'Medical consumable',
                g.product_group = 'non medical', 'General', 'Other')   as item_group,
        toUInt8(0)                                                     as is_deleted,
        toNullable(u.product_code)                                     as oasis_product_code,
        cast(null as Nullable(String))                                 as oasis_product_codes,
        p.product_category                                             as oasis_product_category,
        ifNull(g.product_group, 'Not Mapped')                          as product_group
    from oasis_used as u
    left join products as p on p.branch_id = u.branch_id and p.product_code = u.product_code
    left join product_groups as g on g.branch_key = u.branch_id and g.category_code = p.product_category
    {{ hnh_settings() }}  -- left joins in a CTE that feeds a union: settings must sit here
)

select * from fusion_items
union all
select * from oasis_items
union all
select toInt64(-1), 'unknown', toUInt8(0), null, null, 'Unknown', null, null, null, toUInt8(0), null, 'Other', toUInt8(0),
       null, null, null, 'Unknown'
{{ hnh_settings() }}
