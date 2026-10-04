{{ config(severity='warn') }}
-- Approval statuses with no row in default.map_claim_status; they report submission status New.
select branch_key, approval_status, count() as invoices
from {{ ref('fact_invoice') }}
where is_submission_status_mapped = 0
group by branch_key, approval_status
