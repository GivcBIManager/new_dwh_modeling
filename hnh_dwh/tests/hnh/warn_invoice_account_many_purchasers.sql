{{ config(severity='warn') }}
-- The lowest policy code decides the payer of these accounts; review if the list grows.
select branch_id, account_code, purchaser_count
from {{ ref('int_invoice_payer') }}
where purchaser_count > 1
