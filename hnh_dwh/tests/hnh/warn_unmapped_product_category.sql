{{ config(severity='warn') }}
-- Category codes that appear on live charges but have no row in default.map_product_category,
-- with the revenue they carry.
select c.branch_key as branch_key,
       uniqExact(c.product_category_key) as unmapped_categories,
       sum(c.revenue_amount) as revenue
from {{ ref('fact_charge_line') }} as c
inner join {{ ref('dim_product_category') }} as p on p.product_category_key = c.product_category_key
where c.charge_status = 'Live'
  and p.unified_category = 'Not Mapped' and p.product_category_key != -1
group by c.branch_key
