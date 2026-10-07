{{ config(severity='warn') }}
-- Fusion valuation layers with posted_flag E (spec F14); they are kept in costs and stock values.
select o.branch_key, toStartOfMonth(v.cost_date) as month_start, count() as layers, round(sum(v.quantity * v.unit_cost), 2) as layer_value
from {{ ref('stg_fusion__inventory_valuation') }} as v
inner join {{ ref('int_inventory_org_branch') }} as o on o.organization_id = v.inventory_org_id
where v.posted_flag = 'E'
group by o.branch_key, month_start
