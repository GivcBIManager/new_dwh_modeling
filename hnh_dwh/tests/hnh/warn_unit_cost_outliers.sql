{{ config(severity='warn') }}
-- Movements whose unit cost is above 20 x the item's median unit cost (listed, never changed: spec S6, e.g. CEFODOX).
-- Only rows of at least 10,000 SAR and not transfers, so the list stays reviewable.
with medians as (
    select item_key, median(unit_cost) as median_unit_cost
    from {{ ref('fact_stock_movement') }}
    where unit_cost > 0 and item_key != -1
    group by item_key
)
select m.branch_key, m.date_key, m.item_key, m.movement_type, m.source_system, m.unit_cost, d.median_unit_cost, m.cost_amount
from {{ ref('fact_stock_movement') }} as m
inner join medians as d on d.item_key = m.item_key
where d.median_unit_cost > 0 and m.unit_cost > 20 * d.median_unit_cost
  and abs(m.cost_amount) >= 10000 and m.movement_type not in ('Transfer in', 'Transfer out')
