{{ config(severity='warn') }}
-- PO lines whose supplier is not in hnh_dim_supplier.
select branch_key, source_system, count() as lines, round(sum(ordered_value), 2) as ordered_value
from {{ ref('fact_purchase_line') }}
where supplier_key = -1
group by branch_key, source_system
