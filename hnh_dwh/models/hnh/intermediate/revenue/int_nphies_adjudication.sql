{{ config(order_by='(branch_id, response_id, item_sequence)') }}

with responses as (
    select branch_id, response_id, about_api_trans_id, response_type, res_status, responded_at, response_bundle
    from {{ ref('stg_oasis__pull_responses') }}
    where response_type in ('claim-response', 'priorauth-response', 'advanced-authorization')
),

claim_responses as (
    -- Only ClaimResponse resources are read; Patient, Coverage and Organization entries are skipped.
    select
        branch_id, response_id, about_api_trans_id, response_type, res_status, responded_at,
        arrayJoin(arrayFilter(e -> JSONExtractString(e, 'resource', 'resourceType') = 'ClaimResponse',
                              JSONExtractArrayRaw(response_bundle, 'entry'))) as entry
    from responses
),

items as (
    select
        branch_id, response_id, about_api_trans_id, response_type, res_status, responded_at,
        nullIf(JSONExtractString(entry, 'resource', 'preAuthRef'), '')                       as preauth_reference,
        toDateOrNull(substring(JSONExtractString(entry, 'resource', 'preAuthPeriod', 'start'), 1, 10)) as preauth_valid_from,
        toDateOrNull(substring(JSONExtractString(entry, 'resource', 'preAuthPeriod', 'end'), 1, 10)) as preauth_valid_to,
        -- Fallback for responses whose pull row has no about_api_trans_id: the request identifier.
        toInt64OrNull(JSONExtractString(entry, 'resource', 'request', 'identifier', 'value'))  as request_trans_id,
        arrayJoin(JSONExtractArrayRaw(entry, 'resource', 'item'))                             as item
    from claim_responses
),

parsed as (
    select
        branch_id, response_id, about_api_trans_id, response_type, res_status, responded_at,
        preauth_reference, preauth_valid_from, preauth_valid_to, request_trans_id,
        toInt64(JSONExtractInt(item, 'itemSequence'))                                        as item_sequence,
        JSONExtractArrayRaw(item, 'adjudication')                                            as adjudications,
        arrayMap(a -> JSONExtractString(a, 'category', 'coding', 1, 'code'), adjudications)  as categories,
        arrayFirst(x -> x != '',
            arrayMap(e -> if(position(JSONExtractString(e, 'url'), 'adjudication-outcome') > 0,
                             JSONExtractString(e, 'valueCodeableConcept', 'coding', 1, 'code'), ''),
                     JSONExtractArrayRaw(item, 'extension')))                                as outcome_code,
        arrayFlatten(arrayMap(a -> arrayMap(c -> JSONExtractString(c, 'code'),
                                            JSONExtractArrayRaw(a, 'reason', 'coding')),
                              adjudications))                                                as reason_codes,
        arrayFirst(a -> length(JSONExtractArrayRaw(a, 'reason', 'coding')) > 0, adjudications) as first_reason_adjudication
    from items
)

select
    branch_id,
    response_id,
    item_sequence,
    if(response_type = 'claim-response', 'Claim', 'Pre-authorisation')                  as response_kind,
    response_type,
    coalesce(about_api_trans_id, request_trans_id)                                      as about_api_trans_id,
    res_status,
    responded_at,
    {{ hnh_nphies_outcome('outcome_code') }}                                            as outcome,
    {{ hnh_adjudication_amount('categories', 'adjudications', "'submitted'") }}         as submitted,
    {{ hnh_adjudication_amount('categories', 'adjudications', "'eligible'") }}          as eligible,
    {{ hnh_adjudication_amount('categories', 'adjudications', "'benefit'") }}           as benefit,
    {{ hnh_adjudication_amount('categories', 'adjudications', "'copay'") }}             as copay,
    {{ hnh_adjudication_amount('categories', 'adjudications', "'deductible'") }}        as deductible,
    {{ hnh_adjudication_amount('categories', 'adjudications', "'tax'") }}               as tax,
    {{ hnh_adjudication_amount('categories', 'adjudications', "'patientShare'") }}      as patient_share,
    if(has(categories, 'approved-quantity'),
       JSONExtractFloat(arrayElement(adjudications, indexOf(categories, 'approved-quantity')), 'value'),
       cast(null as Nullable(Float64)))                                                 as approved_qty,
    reason_codes,
    if(empty(reason_codes), cast(null as Nullable(String)), reason_codes[1])            as primary_reason_code,
    if(first_reason_adjudication = '', cast(null as Nullable(Float64)),
       JSONExtractFloat(first_reason_adjudication, 'amount', 'value'))                  as legacy_reason_amount,
    preauth_reference,
    preauth_valid_from,
    preauth_valid_to
from parsed
