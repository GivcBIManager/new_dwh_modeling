{{ config(order_by='claim_status_key') }}

-- One row per detailed status and each submission channel it can have (claim status spec 4.1, 5.2). New is added
-- even when the mapping has no New row (invoices with no approval status use it); Unknown is for codes the mapping
-- does not know. The channel comes from the same macro as int_invoice_claim_status, over both manual flags.
with statuses as (
    select detailed_status, submission_status, validation_status from {{ ref('stg_ref__claim_status') }}
    union distinct
    select 'New' as detailed_status, 'New' as submission_status, 'New' as validation_status
    union distinct
    select 'Unknown' as detailed_status, 'Unknown' as submission_status, 'Unknown' as validation_status
),

channels as (
    select distinct
        s.detailed_status                                                       as detailed_status,
        s.submission_status                                                     as submission_status,
        s.validation_status                                                     as validation_status,
        {{ hnh_claim_submission_channel('s.submission_status', 'f.flag') }}     as submission_channel
    from statuses as s
    cross join (select arrayJoin(['Y', 'N']) as flag) as f
)

select
    {{ hnh_claim_status_key('detailed_status', 'submission_channel') }}  as claim_status_key,
    validation_status,
    submission_status,
    detailed_status,
    submission_channel,
    toUInt8(submission_channel in ('NPHIES', 'Manual'))                  as is_submitted
from channels
