{{ config(severity='warn') }}
-- Category codes on charges with no row in default.map_product_category.
select branch_key, count() as unmapped_categories
from {{ ref('dim_product_category') }}
where unified_category = 'Not Mapped' and product_category_key != -1
group by branch_key
