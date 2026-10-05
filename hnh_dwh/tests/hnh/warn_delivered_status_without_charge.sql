{{ config(severity='warn') }}
-- Order lines Oasis marks delivered (D) with a positive ordered quantity that have no live charge,
-- by branch and order month. Reversal lines (non-positive units) are left out.
select branch_key, intDiv(order_date_key, 100) as order_month, count() as lines
from {{ ref('fact_order_line') }}
where line_status = 'Delivered' and live_charge_count = 0
  and units_ordered > 0
group by branch_key, order_month
