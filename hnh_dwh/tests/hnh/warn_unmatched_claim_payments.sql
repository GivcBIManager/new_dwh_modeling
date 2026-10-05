{{ config(severity='warn') }}
-- Remittance lines whose claim transaction matches no claim visit, by branch; advance lines (payer prepayments) are excluded.
select branch_key, count() as payment_lines, sum(payment_amount) as amount
from {{ ref('fact_claim_payment') }}
where visit_id is null and detail_type != 'advance'
group by branch_key
