{{ config(severity='warn') }}
select branch_key, count() as payment_lines, sum(payment_amount) as amount
from {{ ref('fact_claim_payment') }}
where visit_id is null
group by branch_key
