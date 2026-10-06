{{ config(order_by='(branch_key, store_id)') }}

-- The Fusion store (organisation + subinventory) each Oasis store maps to through the integration (spec 5.2): the pair
-- with the most integration transactions (ties: the lower organisation id, then subinventory code). A null or empty
-- subinventory is the organisation level '*', as in hnh_fusion_store_key.
with pairs as (
    select f.branch_key as branch_key, assumeNotNull(l.store_id) as oasis_store_id, f.organization_id as fusion_organization_id,
           ifNull(nullIf(f.subinventory_code, ''), '*') as fusion_subinventory_code, count() as pair_lines
    from {{ ref('int_fusion_stock_line') }} as f
    inner join (select branch_id, line_id, store_id from {{ ref('stg_oasis__stock_document_lines') }}
                where store_id is not null and line_date >= toDate32('{{ var("hnh_fusion_inventory_start") }}') - 92) as l
        on l.branch_id = f.branch_key and l.line_id = f.oasis_line_id
    where f.reference_status = 'oasis_line' and f.organization_id is not null
    group by f.branch_key, l.store_id, f.organization_id, fusion_subinventory_code
)

select
    branch_key                          as branch_key,
    oasis_store_id                      as store_id,
    assumeNotNull(fusion_organization_id) as organization_id,
    fusion_subinventory_code            as subinventory_code,
    pair_lines                          as pair_lines
from pairs
order by branch_key, oasis_store_id, pair_lines desc, fusion_organization_id, fusion_subinventory_code
limit 1 by branch_key, oasis_store_id
