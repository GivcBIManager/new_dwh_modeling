{{ config(severity='warn') }}
-- Movements on Fusion items whose number starts with Deleted- (spec F7).
select m.branch_key, count() as rows, uniqExact(m.item_key) as items
from {{ ref('fact_stock_movement') }} as m
inner join (select item_key from {{ ref('hnh_dim_item') }} where is_deleted = 1) as i on i.item_key = m.item_key
group by m.branch_key
