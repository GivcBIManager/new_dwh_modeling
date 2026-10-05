{{ config(severity='warn') }}
-- AP rows whose supplier site is not in dim_supplier.
select 'invoice line' as source, branch_key, count() as rows, round(sum(amount), 2) as amount
from {{ ref('fact_ap_invoice_line') }} where supplier_key = -1 group by branch_key
union all
select 'payment', branch_key, count(), round(sum(amount), 2)
from {{ ref('hnh_fact_ap_payment') }} where supplier_key = -1 group by branch_key
