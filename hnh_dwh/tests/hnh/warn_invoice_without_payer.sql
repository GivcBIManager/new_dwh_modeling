{{ config(severity='warn') }}
select branch_key, uniqExact(account_code) as accounts_without_payer, count() as invoices
from {{ ref('fact_invoice') }}
where payer_key = -1
group by branch_key
