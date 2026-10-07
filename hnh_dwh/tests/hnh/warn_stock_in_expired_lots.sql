{{ config(severity='warn') }}
-- Positive stock in expired lots or batches at the latest month-end of each branch.
select branch_key, month_end, count() as rows, round(sum(stock_value), 2) as stock_value
from {{ ref('fact_stock_monthly') }}
where has_expired_lot = 1 and quantity > 0
  and (branch_key, month_end) in (select branch_key, max(month_end) from {{ ref('fact_stock_monthly') }} group by branch_key)
group by branch_key, month_end
