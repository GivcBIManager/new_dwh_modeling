{{ config(order_by='(branch_id, visit_id)') }}

with visits as (
    select
        branch_id, visit_id, request_at, statement_end_at, claim_invoice_no, stat_invoice_no,
        patient_id, episode_no, purchaser_code, claim_type, api_trans_id, is_cancelled,
        -- a visit without an invoice number is its own claim
        ifNull(claim_invoice_no, -visit_id) as claim_group
    from {{ ref('stg_oasis__claim_visits') }}
),

numbered as (
    select
        v.*,
        row_number() over (partition by branch_id, claim_group
                           order by ifNull(request_at, toDateTime(0, 'Asia/Riyadh')), visit_id)       as submission_number,
        count() over (partition by branch_id, claim_group)                                           as submission_count
    from visits as v
),

claim_responses as (
    -- The transaction a response answers: the pull row's own reference, else the ClaimResponse request identifier,
    -- as int_nphies_adjudication does. The status: the pull row's own, else (2022 pulls without one) the decision in
    -- the ClaimResponse: its adjudication-outcome extension, then its outcome (queued, error). The bundle is parsed
    -- only for rows missing one of the two.
    select
        branch_id, response_id, responded_at,
        coalesce(about_api_trans_id,
                 toInt64OrNull(JSONExtractString(claim_response, 'resource', 'request', 'identifier', 'value'))) as answered_trans_id,
        coalesce(res_status,
                 multiIf(lower(bundle_outcome_code) in ('approved', 'partial', 'rejected', 'pended'), upper(bundle_outcome_code),
                         lower(JSONExtractString(claim_response, 'resource', 'outcome')) = 'queued', 'QUEUED',
                         lower(JSONExtractString(claim_response, 'resource', 'outcome')) = 'error', 'ERROR',
                         cast(null as Nullable(String))))                                             as effective_status
    from (
        select
            branch_id, response_id, about_api_trans_id, res_status, responded_at, claim_response,
            JSONExtractString(
                arrayFirst(x -> position(JSONExtractString(x, 'url'), 'extension-adjudication-outcome') > 0,
                           JSONExtractArrayRaw(claim_response, 'resource', 'extension')),
                'valueCodeableConcept', 'coding', 1, 'code')                                                  as bundle_outcome_code
        from (
            select
                branch_id, response_id, about_api_trans_id, res_status, responded_at,
                if(about_api_trans_id is null or res_status is null,
                   arrayFirst(e -> JSONExtractString(e, 'resource', 'resourceType') = 'ClaimResponse',
                              JSONExtractArrayRaw(response_bundle, 'entry')),
                   '')                                                                                        as claim_response
            from {{ ref('stg_oasis__pull_responses') }}
            where response_type = 'claim-response'
        )
    )
),

final_responses as (
    -- final answer: the latest decision (approved, partial, rejected); else the latest of any status
    select
        branch_id, answered_trans_id,
        count()                                                                                       as response_count,
        argMax(tuple(response_id, effective_status, responded_at),
               tuple({{ hnh_is_decision_status('effective_status') }},
                     ifNull(responded_at, toDateTime(0, 'Asia/Riyadh')), response_id))               as final_answer
    from claim_responses
    where answered_trans_id is not null
    group by branch_id, answered_trans_id
)

select
    n.branch_id                                                as branch_id,
    n.visit_id                                                 as visit_id,
    n.claim_invoice_no                                         as claim_invoice_no,
    n.stat_invoice_no                                          as stat_invoice_no,
    n.patient_id                                               as patient_id,
    n.episode_no                                               as episode_no,
    n.purchaser_code                                           as purchaser_code,
    n.claim_type                                               as claim_type,
    n.api_trans_id                                             as api_trans_id,
    n.request_at                                               as request_at,
    n.statement_end_at                                         as statement_end_at,
    n.is_cancelled                                             as is_cancelled,
    toUInt64(n.submission_number)                              as submission_number,
    toUInt64(n.submission_count)                               as submission_count,
    toUInt8(n.submission_number = n.submission_count)          as is_latest_submission,
    toUInt8(n.api_trans_id is not null)                        as is_sent,
    if(fr.answered_trans_id is null, cast(null as Nullable(Int64)), tupleElement(fr.final_answer, 1))   as final_response_id,
    if(fr.answered_trans_id is null, cast(null as Nullable(String)), tupleElement(fr.final_answer, 2))  as final_status,
    if(fr.answered_trans_id is null, cast(null as Nullable(DateTime('Asia/Riyadh'))), tupleElement(fr.final_answer, 3)) as final_responded_at,
    toUInt64(ifNull(fr.response_count, 0))                     as response_count,
    {{ hnh_claim_adjudication_status('toUInt8(n.api_trans_id is not null)',
                                     'toUInt8(fr.answered_trans_id is not null)',
                                     'if(fr.answered_trans_id is null, cast(null as Nullable(String)), tupleElement(fr.final_answer, 2))') }} as adjudication_status
from numbered as n
left join final_responses as fr
    on fr.branch_id = n.branch_id and fr.answered_trans_id = n.api_trans_id
{{ hnh_settings() }}
