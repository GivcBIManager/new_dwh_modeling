-- Claim status spec 4.2: a line's approved + rejected is 0 (no NPHIES decision) or its net amount, except a partially
-- approved line whose benefit exceeds net (approved = benefit, rejected = 0). Nets can be negative (credit lines).
select claim_line_key, item_outcome, adjudication_status, claimed_amount, approved_amount, rejected_amount
from {{ ref('fact_claim_line') }}
where not (
    abs(approved_amount + rejected_amount) < 0.01
    or abs(approved_amount + rejected_amount - claimed_amount) < 0.01
    or (item_outcome = 'Partially approved' and rejected_amount = 0 and approved_amount > claimed_amount)
)
