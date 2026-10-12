{{ config(alias='vw_rcm') }}

-- Old bsc.vw_rcm (bsc spec 7.4) with the SSAS claim and pre-authorisation measures. Claims by statement month,
-- latest not cancelled submission; not_submitted_claims is the amount pending adjudication (every gold line is sent,
-- F9); rates are over adjudicated submitted. Pre-authorisation by request month, payer advances left out.
with
    ifNull(toDateOrNull('{{ var('hnh_bsc_as_of') }}'), today()) as today_,
    today_ - 1 as yesterday_,
    toInt32(toYYYYMMDD(subtractYears(toStartOfYear(yesterday_), 1))) as from_key_,
claims as (
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(statement_end_date_key)))                         as period,
        sumIf(claimed_amount, is_sent = 1 and is_latest_submission = 1 and is_cancelled_claim = 0) as submitted,
        sumIf(claimed_amount, is_sent = 1 and is_latest_submission = 1 and is_cancelled_claim = 0
                              and adjudication_status in ('No response', 'Pended'))                as pending,
        sumIf(ifNull(approved_amount, 0), is_latest_submission = 1 and is_cancelled_claim = 0)   as approved,
        sumIf(ifNull(rejected_amount, 0), is_latest_submission = 1 and is_cancelled_claim = 0)   as rejected,
        sumIf(ifNull(submitted_amount, 0), is_latest_submission = 1 and is_cancelled_claim = 0
                                           and adjudication_status = 'Adjudicated')              as adjudicated_submitted
    from {{ ref('fact_claim_line') }}
    where branch_key between 1 and 8 and statement_end_date_key >= from_key_
    group by branch_key, period
),
preauth as (
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(request_date_key)))                                as period,
        countIf(line_source != 'Payer advance')                                                   as services,
        countIf(line_source != 'Payer advance' and is_approved = 1 and has_final_response = 1)    as approved_final,
        countIf(line_source != 'Payer advance' and is_approved_not_delivered = 1)                 as unutilised,
        avgIf(sent_to_response_minutes, line_source != 'Payer advance')                           as sent_to_response
    from {{ ref('fact_preauth_line') }}
    where branch_key between 1 and 8 and request_date_key between from_key_ and toInt32(toYYYYMMDD(yesterday_))
    group by branch_key, period
),
keys as (
    select branch_key, period from claims
    union distinct
    select branch_key, period from preauth
)
select
    toUInt64(k.branch_key)                                                      as hospital_id,
    toNullable(toDate(k.period))                                                as period,
    toFloat64(c.submitted)                                                      as total_submitted_claims,
    toFloat64(c.pending)                                                        as not_submitted_claims,
    CAST(c.approved AS Nullable(Float64))                                       as approved_amount,
    CAST(c.rejected AS Nullable(Float64))                                       as rejections,
    round(100 * c.rejected / nullIf(c.adjudicated_submitted, 0), 2)             as rejection_rate_pct,
    round(100 * c.approved / nullIf(c.adjudicated_submitted, 0), 2)             as approval_rate_pct,
    toUInt64(p.services)                                                        as total_orders,
    toUInt64(p.approved_final)                                                  as approved_orders,
    toUInt64(p.unutilised)                                                      as approved_not_done,
    round(100 * p.unutilised / nullIf(p.services, 0), 2)                        as approved_not_done_pct,
    CAST(round(p.sent_to_response, 1) AS Nullable(Float64))                     as avg_tat_minutes
from keys as k
left join claims as c on c.branch_key = k.branch_key and c.period = k.period
left join preauth as p on p.branch_key = k.branch_key and p.period = k.period
settings join_use_nulls = 0
