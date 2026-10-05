{{ config(severity='warn') }}
-- Order lines whose ordered quantity is above 1,000 units (usually ordered in ml or mg while delivered
-- in packs). They are flagged is_unit_outlier and left out of Lost value; this lists them by month.
select branch_key, intDiv(order_date_key, 100) as order_month, order_category,
       count() as lines, sum(ordered_value) as ordered_value
from {{ ref('fact_order_line') }}
where is_unit_outlier = 1
group by branch_key, order_month, order_category
