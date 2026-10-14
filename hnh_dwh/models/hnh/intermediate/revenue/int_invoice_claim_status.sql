{{ config(order_by='(branch_id, invoice_no)') }}

-- Claim status and submission channel of every invoice, all history (claim status spec 4.1, 5.1). fact_invoice and
-- fact_claim_line take claim_status_key from here, so a claim line finds its invoice's status whatever the invoice date.
with approval_codes as (
    -- Code type 5116 is matched on user_code; identical in all eight branches (as fact_invoice).
    select branch_id, assumeNotNull(user_code) as user_code, any(description) as code_description
    from {{ ref('int_code_decode') }}
    where code_type = 5116 and user_code is not null
    group by branch_id, user_code
),

joined as (
    select
        i.branch_id              as branch_id,
        i.invoice_no             as invoice_no,
        i.approval_status_code   as approval_status_code,
        py.purchaser_code        as purchaser_code,
        cs.detailed_status       as mapped_detailed,
        cs.submission_status     as mapped_submission,
        cs.validation_status     as mapped_validation,
        pm.manual_submission     as manual_submission
    from {{ ref('stg_oasis__episode_invoices') }} as i
    left join approval_codes as ac
        on ac.branch_id = i.branch_id and ac.user_code = i.approval_status_code
    left join {{ ref('stg_ref__claim_status') }} as cs
        on lower(cs.detailed_status) = lower(ac.code_description)
    left join {{ ref('int_invoice_payer') }} as py
        on py.branch_id = i.branch_id and py.account_code = i.account_code
    left join {{ ref('stg_ref__purchaser_mapping') }} as pm
        on pm.branch_id = i.branch_id and pm.purchaser_code = py.purchaser_code
),

classified as (
    -- no approval status = New (rule R2); a code the mapping does not know = Unknown
    select
        branch_id, invoice_no, purchaser_code, manual_submission,
        toUInt8(approval_status_code is null or mapped_detailed is not null)                                       as is_status_mapped,
        multiIf(approval_status_code is null, 'New', mapped_detailed is null, 'Unknown', assumeNotNull(mapped_detailed))   as detailed_status,
        multiIf(approval_status_code is null, 'New', mapped_detailed is null, 'Unknown', assumeNotNull(mapped_submission)) as submission_status,
        multiIf(approval_status_code is null, 'New', mapped_detailed is null, 'Unknown', assumeNotNull(mapped_validation)) as validation_status
    from joined
)

select
    branch_id,
    invoice_no,
    purchaser_code,
    manual_submission,
    is_status_mapped,
    detailed_status,
    submission_status,
    validation_status,
    {{ hnh_claim_submission_channel('submission_status', 'manual_submission') }}   as submission_channel,
    {{ hnh_claim_status_key('detailed_status', 'submission_channel') }}           as claim_status_key
from classified
{{ hnh_settings() }}
