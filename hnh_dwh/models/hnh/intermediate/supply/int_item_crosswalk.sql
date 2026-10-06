{{ config(order_by='(branch_key, product_code)') }}

-- Fusion item per Oasis product and branch, derived from the integration (spec 4.3): a Fusion integration transaction
-- whose reference resolves to an Oasis line of the posting organisation's branch pairs the Fusion item with that line's
-- product. Per product the pair with the most lines wins (ties: the lower item id). units_per_primary is the most
-- frequent ratio of the Oasis base-unit quantity to the Fusion primary quantity over the winning pair's lines
-- (plan refinement: Fusion primary units are packs for about a third of the products).
with refs as (
    select o.branch_key as branch_key, assumeNotNull(t.inventory_item_id) as inventory_item_id,
           {{ hnh_oasis_line_ref('t.transaction_reference') }} as oasis_line_id, abs(t.primary_quantity) as fusion_quantity
    from {{ ref('stg_fusion__inventory_transactions') }} as t
    inner join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = t.organization_id
    where t.transaction_type_id in {{ hnh_fusion_integration_type_ids() }}
      and t.inventory_item_id is not null and t.primary_quantity != 0
),

oasis_lines as (
    select branch_id, line_id, assumeNotNull(product_code) as product_code, abs(quantity) as oasis_quantity
    from {{ ref('stg_oasis__stock_document_lines') }}
    where line_date >= toDate32('{{ var("hnh_fusion_inventory_start") }}') and product_code is not null and quantity != 0
),

pairs as (
    select r.branch_key as branch_key, l.product_code as product_code, r.inventory_item_id as inventory_item_id,
           round(l.oasis_quantity / r.fusion_quantity, 4) as ratio
    from refs as r
    inner join oasis_lines as l on l.branch_id = r.branch_key and l.line_id = r.oasis_line_id
    where r.oasis_line_id is not null
),

pair_counts as (
    select branch_key, product_code, inventory_item_id, count() as pair_lines
    from pairs
    group by branch_key, product_code, inventory_item_id
),

best as (
    select branch_key, product_code, inventory_item_id, pair_lines
    from pair_counts
    order by branch_key, product_code, pair_lines desc, inventory_item_id
    limit 1 by branch_key, product_code
),

ratio_counts as (
    select p.branch_key as branch_key, p.product_code as product_code, p.ratio as ratio, count() as ratio_lines
    from pairs as p
    inner join best as b
        on b.branch_key = p.branch_key and b.product_code = p.product_code and b.inventory_item_id = p.inventory_item_id
    group by p.branch_key, p.product_code, p.ratio
),

modal as (
    select branch_key, product_code, ratio as units_per_primary
    from ratio_counts
    order by branch_key, product_code, ratio_lines desc, ratio
    limit 1 by branch_key, product_code
)

select
    b.branch_key                as branch_key,
    b.product_code              as product_code,
    b.inventory_item_id         as inventory_item_id,
    b.pair_lines                as pair_lines,
    m.units_per_primary         as units_per_primary
from best as b
inner join modal as m on m.branch_key = b.branch_key and m.product_code = b.product_code
