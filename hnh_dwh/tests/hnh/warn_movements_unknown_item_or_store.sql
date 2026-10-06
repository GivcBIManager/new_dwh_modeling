{{ config(severity='warn') }}
-- Movements with the Unknown item (-1) or a store without a map_store_department row, by branch and source.
select m.branch_key, m.source_system, countIf(m.item_key = -1) as unknown_item_rows,
       countIf(m.store_key = -1 or s.store_type = 'Unmapped') as unmapped_store_rows
from {{ ref('fact_stock_movement') }} as m
left join (select store_key, store_type from {{ ref('dim_store') }}) as s on s.store_key = m.store_key
group by m.branch_key, m.source_system
having unknown_item_rows > 0 or unmapped_store_rows > 0
{{ hnh_settings() }}
