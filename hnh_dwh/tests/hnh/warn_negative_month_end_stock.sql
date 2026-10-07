{{ config(severity='warn') }}
-- Negative month-end stock (spec F14: Muhayil's opening balance after its first sales, Unaizah on-hand).
select branch_key, month_end, stock_source, count() as rows, round(sum(quantity), 2) as total_quantity
from {{ ref('fact_stock_monthly') }}
where quantity < 0
group by branch_key, month_end, stock_source
