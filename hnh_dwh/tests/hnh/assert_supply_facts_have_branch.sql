-- Supply-chain facts never fall back to the Group member (branch 0), and no Fusion inventory organisation is unresolved.
select 'fact_stock_movement' as fact, count() as rows_without_branch from {{ ref('fact_stock_movement') }} where branch_key = 0 having count() > 0
union all
select 'fact_patient_consumption', count() from {{ ref('fact_patient_consumption') }} where branch_key = 0 having count() > 0
union all
select 'fact_stock_monthly', count() from {{ ref('fact_stock_monthly') }} where branch_key = 0 having count() > 0
union all
select 'fact_purchase_line', count() from {{ ref('fact_purchase_line') }} where branch_key = 0 having count() > 0
union all
select 'fact_goods_receipt', count() from {{ ref('fact_goods_receipt') }} where branch_key = 0 having count() > 0
union all
select 'int_inventory_org_branch', count() from {{ ref('int_inventory_org_branch') }} where branch_key = 0 having count() > 0
