{{ config(severity='warn') }}
-- The same remittance detail (claim transaction, payer claim response, payment reference, payment date and amount)
-- in more than one kept reconciliation, by branch: lines and amount beyond the first occurrence.
select branch_key, count() as duplicated_details, sum(copies - 1) as extra_lines, sum((copies - 1) * payment_amount) as extra_amount
from (
    select branch_key, claim_api_trans_id, payer_claim_response_id, payment_reference, payment_date_key, payment_amount,
           uniqExact(reconciliation_id) as copies
    from {{ ref('fact_claim_payment') }}
    group by branch_key, claim_api_trans_id, payer_claim_response_id, payment_reference, payment_date_key, payment_amount
    having copies > 1
)
group by branch_key
