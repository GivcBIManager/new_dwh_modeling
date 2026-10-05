{{ config(severity='warn') }}
-- Order lines Oasis marks delivered (D) that have no live charge, by branch and order month.
select branch_key, intDiv(order_date_key, 100) as order_month, count() as lines
from {{ ref('fact_order_line') }}
where line_status = 'Delivered' and live_charge_count = 0
group by branch_key, order_month
