{{ config(severity='warn') }}
-- Closed months where more than 1% of a branch's Fusion-sourced movement rows have a Fusion cost that differs from the
-- Oasis cost (Task 6 ruling: Fusion pack-item costs in five branches equal one base unit's Oasis cost).
select branch_key, toStartOfMonth(toDate(toString(date_key))) as month_start,
       countIf(is_cost_mismatch = 1) as mismatch_rows, countIf(source_system = 'fusion') as fusion_rows,
       round(sumIf(cost_amount, is_cost_mismatch = 1), 2) as fusion_cost_amount,
       round(sumIf(oasis_cost_amount, is_cost_mismatch = 1), 2) as oasis_cost_amount
from {{ ref('fact_stock_movement') }}
group by branch_key, month_start
having month_start < toStartOfMonth(today()) and mismatch_rows > 0.01 * fusion_rows
