{{ config(order_by='(branch_key, statement_end_date_key, claim_line_key)') }}

{% set first_at = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with statement_invoices as (
    -- Invoices on an AR statement with the NPHIES transaction they were sent under: the scope of the old claims model and
    -- bsc.vw_rcm (their inner join to tr_ar_statements on branch, API_TRANS_ID and invoice), used by the legacy_* columns.
    select distinct i.branch_id as si_branch_id, i.invoice_no as si_invoice_no, assumeNotNull(i.api_trans_id) as si_api_trans_id
    from {{ ref('stg_oasis__episode_invoices') }} as i
    inner join (select branch_id, stat_invoice_no from {{ ref('stg_oasis__invoice_statements') }}) as s
        on s.branch_id = i.branch_id and s.stat_invoice_no = i.stat_invoice_no
    where i.api_trans_id is not null
),

lines as (
    select
        s.branch_id                 as branch_id,
        s.visit_id                  as visit_id,
        s.sequence_no               as sequence_no,
        s.ios                       as ios,
        s.service_code              as service_code,
        s.net_amount                as net_amount,
        s.outcome                   as line_outcome,
        s.notes                     as notes,
        sub.claim_invoice_no        as claim_invoice_no,
        sub.stat_invoice_no         as stat_invoice_no,
        sub.patient_id              as patient_id,
        sub.episode_no              as episode_no,
        sub.purchaser_code          as purchaser_code,
        sub.claim_type              as claim_type,
        sub.api_trans_id            as api_trans_id,
        sub.request_at              as request_at,
        sub.statement_end_at        as statement_end_at,
        sub.is_cancelled            as is_cancelled,
        sub.submission_number       as submission_number,
        sub.is_latest_submission    as is_latest_submission,
        sub.is_sent                 as is_sent,
        sub.final_response_id       as final_response_id,
        sub.final_responded_at      as final_responded_at,
        sub.adjudication_status     as adjudication_status,
        toUInt8((s.branch_id, ifNull(sub.claim_invoice_no, toInt64(0)), ifNull(sub.api_trans_id, toInt64(0)))
                in (select si_branch_id, si_invoice_no, si_api_trans_id from statement_invoices)) as legacy_in_scope
    from {{ ref('stg_oasis__claim_services') }} as s
    inner join {{ ref('int_claim_submission') }} as sub
        on sub.branch_id = s.branch_id and sub.visit_id = s.visit_id
    where sub.statement_end_at >= {{ first_at }} and toDate(sub.statement_end_at) <= {{ last_day }}
),

items as (
    select branch_id, response_id, item_sequence, outcome, submitted, eligible, benefit, copay, deductible, tax,
           patient_share, approved_qty, reason_codes, primary_reason_code, legacy_reason_amount
    from {{ ref('int_nphies_adjudication') }}
    where response_kind = 'Claim'
),

adjudicated as (
    select
        l.*,
        toUInt8(l.adjudication_status = 'Adjudicated' and a.response_id is not null)        as has_adjudication,
        a.outcome                    as response_outcome,
        a.submitted                  as response_submitted,
        a.eligible                   as response_eligible,
        a.benefit                    as response_benefit,
        a.copay                      as response_copay,
        a.deductible                 as response_deductible,
        a.tax                        as response_tax,
        a.patient_share              as response_patient_share,
        a.approved_qty               as response_approved_qty,
        a.reason_codes               as response_reason_codes,
        a.primary_reason_code        as response_reason_code,
        a.legacy_reason_amount       as legacy_reason_amount,
        {{ hnh_reason_from_notes('l.notes') }}                                             as notes_reason_code
    from lines as l
    left join items as a
        on a.branch_id = l.branch_id and a.response_id = l.final_response_id and a.item_sequence = l.sequence_no
),

keyed as (
    select
        d.*,
        if(d.has_adjudication = 1, d.response_reason_code, cast(null as Nullable(String)))   as gated_response_reason_code,
        coalesce(gated_response_reason_code, d.notes_reason_code)                            as primary_reason_code,
        {{ hnh_surrogate_key(['d.branch_id', 'd.visit_id', 'd.sequence_no']) }}             as claim_line_key,
        {{ hnh_surrogate_key(['d.branch_id', 'd.patient_id', 'd.episode_no']) }}             as episode_key,
        {{ hnh_surrogate_key(['d.branch_id', 'd.claim_invoice_no']) }}                       as invoice_key,
        {{ hnh_surrogate_key(['d.branch_id', 'd.patient_id']) }}                             as patient_key_raw,
        {{ hnh_surrogate_key(['d.branch_id', 'd.ios']) }}                                    as service_key_raw,
        {{ hnh_surrogate_key(['d.branch_id', 'ifNull(d.purchaser_code, toInt64(9999))']) }}  as payer_key_raw,
        if(ifNull(ep.care_type, 'Unknown') != 'Unknown', ifNull(ep.care_type, 'Unknown'),
           {{ hnh_care_type('d.claim_type') }})                                              as care_type
    from adjudicated as d
    left join (select branch_id, patient_id, episode_no, care_type from {{ ref('int_episode') }}) as ep
        on ep.branch_id = d.branch_id and ep.patient_id = d.patient_id and ep.episode_no = d.episode_no
)

select
    k.claim_line_key                                                        as claim_line_key,
    k.branch_id                                                             as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(k.statement_end_at)))                  as statement_end_date_key,
    {{ hnh_date_key_in_range('k.request_at') }}                             as submitted_date_key,
    {{ hnh_date_key_in_range('k.final_responded_at') }}                     as response_date_key,
    ifNull(dp.patient_key, toInt64(-1))                                     as patient_key,
    k.episode_key                                                           as episode_key,
    ifNull(dpy.payer_key, toInt64(-1))                                      as payer_key,
    ifNull(dsv.service_key, toInt64(-1))                                    as service_key,
    {{ hnh_care_type_key('k.care_type') }}                                  as care_type_key,
    k.invoice_key                                                           as invoice_key,
    if(k.primary_reason_code is null, toInt64(0), ifNull(dr.nphies_reason_key, toInt64(-1))) as nphies_reason_key,
    k.visit_id                                                              as visit_id,
    k.sequence_no                                                           as sequence_no,
    k.claim_invoice_no                                                      as claim_invoice_no,
    k.stat_invoice_no                                                       as stat_invoice_no,
    k.service_code                                                          as service_code,
    k.submission_number                                                     as submission_number,
    k.is_latest_submission                                                  as is_latest_submission,
    k.is_sent                                                               as is_sent,
    k.is_cancelled                                                          as is_cancelled_claim,
    k.adjudication_status                                                   as adjudication_status,
    multiIf(k.has_adjudication = 1, k.response_outcome,
            k.line_outcome is not null, {{ hnh_nphies_outcome('k.line_outcome') }},
            'Not adjudicated')                                              as item_outcome,
    if(k.has_adjudication = 1, k.response_reason_codes, cast([] as Array(String))) as reason_codes,
    k.primary_reason_code                                                   as primary_reason_code,
    multiIf(k.gated_response_reason_code is not null, 'NPHIES response',
            k.notes_reason_code is not null, 'Claim notes', 'Not given')    as reason_source,
    k.net_amount                                                            as claimed_amount,
    if(k.has_adjudication = 1, ifNull(k.response_submitted, k.net_amount), null) as submitted_amount,
    if(k.has_adjudication = 1, k.response_eligible, null)                   as eligible_amount,
    if(k.has_adjudication = 1, ifNull(k.response_benefit, 0), null)         as approved_amount,
    if(k.has_adjudication = 1, k.response_copay, null)                      as copay_amount,
    if(k.has_adjudication = 1, k.response_deductible, null)                 as deductible_amount,
    if(k.has_adjudication = 1, k.response_patient_share, null)              as patient_share_amount,
    if(k.has_adjudication = 1, k.response_tax, null)                        as tax_amount,
    if(k.has_adjudication = 1, k.response_approved_qty, null)               as approved_qty,
    -- payers omit eligible on approved items and send eligible = submitted on rejected ones, so go by outcome;
    -- submitted includes VAT while eligible and benefit exclude it (the payer returns it as tax), so tax is not rejected
    if(k.has_adjudication = 1,
       multiIf(k.response_outcome = 'Rejected', ifNull(k.response_submitted, k.net_amount),
               k.response_outcome = 'Approved', 0,
               greatest(ifNull(k.response_submitted, k.net_amount) - ifNull(k.response_tax, 0)
                        - coalesce(nullIf(k.response_eligible, 0),
                                   ifNull(k.response_benefit, 0) + coalesce(k.response_patient_share, k.response_copay, 0)), 0)),
       null)                                                                as rejected_amount,
    -- old claims model and bsc.vw_rcm; their scope is legacy_in_scope = 1 (invoice and transaction on an AR statement)
    k.legacy_in_scope                                                       as legacy_in_scope,
    k.net_amount                                                            as legacy_submitted_amount,
    multiIf(ifNull(k.line_outcome, '') = 'REJECTED', 0,
            ifNull(k.line_outcome, '') = 'PARTIAL', ifNull(k.legacy_reason_amount, 0),
            k.net_amount)                                                   as legacy_approved_amount,
    greatest(k.net_amount - legacy_approved_amount, 0)                      as legacy_rejected_amount,
    now()                                                                   as _loaded_at
from keyed as k
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = k.patient_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dpy on dpy.payer_key = k.payer_key_raw
left join (select service_key from {{ ref('dim_service') }}) as dsv on dsv.service_key = k.service_key_raw
left join (select nphies_reason_key from {{ ref('dim_nphies_reason') }}) as dr
    on dr.nphies_reason_key = {{ hnh_surrogate_key(['k.primary_reason_code']) }}
{{ hnh_settings() }}
