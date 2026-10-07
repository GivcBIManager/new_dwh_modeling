{{ config(order_by='(branch_key, month_start)') }}

with claims as (
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(statement_end_date_key)))                         as month_start,
        -- the old models' scope: invoice and NPHIES transaction on an AR statement (O-P2B-5)
        sumIf(legacy_submitted_amount, legacy_in_scope = 1)                                       as legacy_submitted,
        sumIf(legacy_approved_amount, legacy_in_scope = 1)                                        as legacy_approved,
        sumIf(legacy_rejected_amount, legacy_in_scope = 1)                                        as legacy_rejected,
        sumIf(claimed_amount, is_sent = 1 and is_latest_submission = 1 and is_cancelled_claim = 0) as submitted,
        sumIf(ifNull(approved_amount, 0), is_latest_submission = 1 and is_cancelled_claim = 0)   as approved,
        sumIf(ifNull(rejected_amount, 0), is_latest_submission = 1 and is_cancelled_claim = 0)   as rejected,
        sumIf(ifNull(submitted_amount, 0), is_latest_submission = 1 and is_cancelled_claim = 0
                                           and adjudication_status = 'Adjudicated')              as adjudicated_submitted,
        sumIf(ifNull(rejected_amount, 0), submission_number = 1)                                 as first_pass_rejected,
        sumIf(ifNull(submitted_amount, 0), submission_number = 1 and adjudication_status = 'Adjudicated') as first_pass_adjudicated_submitted,
        -- latest submission of a resubmitted claim only, so an invoice sent three times counts once
        sumIf(ifNull(approved_amount, 0), submission_number > 1 and is_latest_submission = 1
                                          and is_cancelled_claim = 0)                            as resubmission_recovery,
        sumIf(claimed_amount, is_sent = 1 and is_latest_submission = 1 and is_cancelled_claim = 0
                              and adjudication_status in ('No response', 'Pended'))              as pending
    from {{ ref('fact_claim_line') }}
    group by branch_key, month_start
),

remittance as (
    -- remittance by the statement month of the claim it pays
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(assumeNotNull(statement_end_date_key))))          as month_start,
        sum(payment_amount)                                                                       as remitted,
        -- signed as received: payment_amount = payment component + early fee + nphies fee
        sum(early_fee)                                                                            as remitted_early_fee,
        sum(nphies_fee)                                                                           as remitted_nphies_fee
    from {{ ref('fact_claim_payment') }}
    where statement_end_date_key is not null
    group by branch_key, month_start
)

select
    c.branch_key                        as branch_key,
    c.month_start                       as month_start,
    c.legacy_submitted                  as legacy_submitted,
    c.legacy_approved                   as legacy_approved,
    c.legacy_rejected                   as legacy_rejected,
    c.submitted                         as submitted,
    c.approved                          as approved,
    c.rejected                          as rejected,
    c.adjudicated_submitted             as adjudicated_submitted,
    c.first_pass_rejected               as first_pass_rejected,
    c.first_pass_adjudicated_submitted  as first_pass_adjudicated_submitted,
    c.resubmission_recovery             as resubmission_recovery,
    c.pending                           as pending,
    ifNull(r.remitted, 0)               as remitted,
    ifNull(r.remitted_early_fee, 0)     as remitted_early_fee,
    ifNull(r.remitted_nphies_fee, 0)    as remitted_nphies_fee
from claims as c
left join remittance as r on r.branch_key = c.branch_key and r.month_start = c.month_start
{{ hnh_settings() }}
