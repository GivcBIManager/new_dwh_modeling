{{ config(severity='warn') }}
-- Lines whose first live delivery is earlier than their order time, by branch and order month.
select branch_key, intDiv(order_date_key, 100) as order_month, count() as lines
from {{ ref('fact_order_line') }}
where order_to_delivery_minutes < 0
group by branch_key, order_month
