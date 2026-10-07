{{ config(order_by='(branch_id, line_natural_id)') }}

{#- Payer-initiated advance authorisations (spec Phase 2B section 12): one row per (branch, payer licence, preAuthRef),
    from the latest pull. The bundle has a MessageHeader, one ClaimResponse (use = preauthorization, never item[];
    addItem[] when the payer lists services), a Patient and Organizations. -#}

{#- Sum of one adjudication category (CAT) over every addItem; null when the bundle has no addItem. -#}
{%- set add_item_sum -%}
if(length(add_items) = 0, cast(null as Nullable(Float64)),
   arraySum(arrayMap(i -> arraySum(arrayMap(a -> if(JSONExtractString(a, 'category', 'coding', 1, 'code') = 'CAT',
                                                    JSONExtractFloat(a, 'amount', 'value'), 0),
                                            JSONExtractArrayRaw(i, 'adjudication'))),
                     add_items)))
{%- endset -%}

{#- Amount of one category (CAT) in ClaimResponse.total[]; null when absent. -#}
{%- set total_amount -%}
if(arrayExists(x -> JSONExtractString(x, 'category', 'coding', 1, 'code') = 'CAT', totals),
   JSONExtractFloat(arrayFirst(x -> JSONExtractString(x, 'category', 'coding', 1, 'code') = 'CAT', totals), 'amount', 'value'),
   cast(null as Nullable(Float64)))
{%- endset -%}

{#- Value at PATH of the first extension in EXTS whose url contains URL_PART; null when none. -#}
{%- set extension_value -%}
nullIf(arrayFirst(x -> x != '', arrayMap(e -> if(position(JSONExtractString(e, 'url'), 'URL_PART') > 0,
                                                 JSONExtractString(e, PATH), ''), EXTS)), '')
{%- endset -%}
{%- set coded = "'valueCodeableConcept', 'coding', 1, 'code'" -%}
{%- set header_outcome = extension_value.replace('EXTS', 'cr_ext').replace('URL_PART', 'adjudication-outcome').replace('PATH', coded) -%}
{%- set item_outcome = extension_value.replace('EXTS', "JSONExtractArrayRaw(i, 'extension')").replace('URL_PART', 'adjudication-outcome').replace('PATH', coded) -%}
{%- set advance_reason = extension_value.replace('EXTS', 'cr_ext').replace('URL_PART', 'advancedAuth-reason').replace('PATH', coded) -%}
{%- set referring_provider = extension_value.replace('EXTS', 'cr_ext').replace('URL_PART', 'referringProvider').replace('PATH', "'valueReference', 'display'") -%}

with pulls as (
    select
        branch_id, response_id, res_status, responded_at,
        JSONExtractArrayRaw(response_bundle, 'entry')                                                  as entries,
        arrayFirst(x -> JSONExtractString(x, 'resource', 'resourceType') = 'MessageHeader', entries)  as mh,
        arrayFirst(x -> JSONExtractString(x, 'resource', 'resourceType') = 'ClaimResponse', entries)  as cr,
        JSONExtractArrayRaw(cr, 'resource', 'extension')                                              as cr_ext,
        JSONExtractArrayRaw(cr, 'resource', 'addItem')                                                as add_items,
        JSONExtractArrayRaw(cr, 'resource', 'total')                                                  as totals,
        arrayFirst(x -> JSONExtractString(x, 'fullUrl') = JSONExtractString(cr, 'resource', 'patient', 'reference'), entries) as patient_entry,
        arrayFirst(x -> JSONExtractString(x, 'fullUrl') = JSONExtractString(cr, 'resource', 'insurer', 'reference'), entries) as insurer_entry
    from {{ ref('stg_oasis__pull_responses') }}
    where response_type = 'advanced-authorization'
),

parsed as (
    select
        branch_id, response_id, res_status, responded_at,
        -- payer licence: the insurer Organization's identifier, else the MessageHeader sender
        coalesce(nullIf(JSONExtractString(insurer_entry, 'resource', 'identifier', 1, 'value'), ''),
                 JSONExtractString(mh, 'resource', 'sender', 'identifier', 'value'))               as payer_license,
        trimBoth(JSONExtractString(cr, 'resource', 'preAuthRef'))                                   as preauth_reference,
        nullIf(JSONExtractString(cr, 'resource', 'identifier', 1, 'value'), '')                     as claim_response_identifier,
        -- payer timestamps carry odd offsets (+03:03): the first 19 characters are the KSA wall clock
        parseDateTimeBestEffortOrNull(substring(JSONExtractString(cr, 'resource', 'created'), 1, 19), 'Asia/Riyadh') as created_at,
        toDateOrNull(substring(JSONExtractString(cr, 'resource', 'preAuthPeriod', 'start'), 1, 10))  as preauth_valid_from,
        toDateOrNull(substring(JSONExtractString(cr, 'resource', 'preAuthPeriod', 'end'), 1, 10))    as preauth_valid_to,
        nullIf(JSONExtractString(cr, 'resource', 'type', 'coding', 1, 'code'), '')                  as claim_type,
        nullIf(JSONExtractString(cr, 'resource', 'subType', 'coding', 1, 'code'), '')               as claim_subtype,
        nullIf(JSONExtractString(cr, 'resource', 'disposition'), '')                                as disposition,
        {{ header_outcome }}                                                                        as header_outcome_code,
        -- without a header outcome: the addItem outcome when all agree, partial when they differ
        arrayDistinct(arrayFilter(x -> x != '', arrayMap(i ->
            ifNull({{ item_outcome }}, ''), add_items)))                                    as item_outcome_codes,
        coalesce(header_outcome_code,
                 multiIf(length(item_outcome_codes) = 1, item_outcome_codes[1],
                         length(item_outcome_codes) > 1, 'partial', null))                          as outcome_code,
        {{ advance_reason }}                                                                        as advance_reason,
        {{ referring_provider }}                                                                    as referring_provider_name,
        -- used for the patient join only; never selected into the output
        trimBoth(JSONExtractString(patient_entry, 'resource', 'identifier', 1, 'value'))            as patient_identifier_value,
        nullIf(JSONExtractString(patient_entry, 'resource', 'identifier', 1, 'type', 'coding', 1, 'code'), '') as patient_identifier_type,
        toUInt32(length(add_items))                                                                 as add_item_count,
        {{ total_amount.replace('CAT', 'benefit') }}                                                as total_benefit,
        {{ total_amount.replace('CAT', 'submitted') }}                                              as total_submitted,
        {{ total_amount.replace('CAT', 'eligible') }}                                               as total_eligible,
        {{ add_item_sum.replace('CAT', 'benefit') }}                                                as add_item_benefit,
        {{ add_item_sum.replace('CAT', 'submitted') }}                                              as add_item_submitted,
        {{ add_item_sum.replace('CAT', 'eligible') }}                                               as add_item_eligible
    from pulls
),

latest as (
    -- one authorisation per (branch, payer licence, preAuthRef): the latest pull wins
    select
        *,
        assumeNotNull(concat('V', payer_license, '-', preauth_reference)) as line_natural_id
    from (
        select
            *,
            count() over (partition by branch_id, payer_license, preauth_reference)              as pull_count,
            min(responded_at) over (partition by branch_id, payer_license, preauth_reference)    as first_pulled_at
        from parsed
    )
    order by ifNull(responded_at, toDateTime(0, 'Asia/Riyadh')) desc, response_id desc
    limit 1 by branch_id, payer_license, preauth_reference
),

patient_ids as (
    -- unique match only: an identity value held by more than one patient of the branch links to none
    select branch_id, trimBoth(id_number) as id_value, uniqExact(patient_id) as patient_count, any(patient_id) as any_patient_id
    from {{ ref('stg_oasis__patient_ids') }}
    where id_number is not null and patient_id is not null
    group by branch_id, id_value
),

linked as (
    select
        l.* except (patient_identifier_value),
        toUInt32(ifNull(p.patient_count, 0))                                 as patient_match_count,
        if(p.patient_count = 1, p.any_patient_id, cast(null as Nullable(Int64))) as patient_id
    from latest as l
    left join patient_ids as p
        on p.branch_id = l.branch_id and p.id_value = l.patient_identifier_value
),

episodes as (
    select branch_id, patient_id, episode_no, started_at, purchaser_code
    from {{ ref('int_episode') }}
),

reference_candidates as (
    -- episodes that carry the authorisation number: a claim line's pre_auth_id or an Oasis request's referral reference
    select distinct v.branch_id as branch_id, trimBoth(cs.pre_auth_id) as preauth_reference,
           v.patient_id as patient_id, v.episode_no as episode_no
    from {{ ref('stg_oasis__claim_services') }} as cs
    inner join {{ ref('stg_oasis__claim_visits') }} as v
        on v.branch_id = cs.branch_id and v.visit_id = cs.visit_id
    where cs.pre_auth_id is not null and v.patient_id is not null and v.episode_no is not null

    union distinct

    select branch_id, trimBoth(referral_pre_auth_ref), patient_id, episode_no
    from {{ ref('stg_oasis__preauth_api_requests') }}
    where referral_pre_auth_ref is not null and patient_id is not null and episode_no is not null
),

reference_link as (
    -- only candidates of the linked patient (preAuthRef values repeat across payers and patients)
    select
        l.branch_id as branch_id, l.line_natural_id as line_natural_id,
        uniqExact(e.episode_no)                                                      as match_count,
        argMin(tuple(e.episode_no, e.purchaser_code), tuple(ifNull(e.started_at, toDateTime(0, 'Asia/Riyadh')), e.episode_no)) as chosen
    from linked as l
    inner join reference_candidates as rc
        on rc.branch_id = l.branch_id and rc.preauth_reference = l.preauth_reference and rc.patient_id = l.patient_id
    inner join episodes as e
        on e.branch_id = rc.branch_id and e.patient_id = rc.patient_id and e.episode_no = rc.episode_no
    group by l.branch_id, l.line_natural_id
),

validity_link as (
    -- the patient's episodes that start inside the validity period; the first one is linked
    select
        l.branch_id as branch_id, l.line_natural_id as line_natural_id,
        uniqExact(e.episode_no)                                                      as match_count,
        argMin(tuple(e.episode_no, e.purchaser_code), tuple(e.started_at, e.episode_no)) as chosen
    from linked as l
    inner join episodes as e
        on e.branch_id = l.branch_id and e.patient_id = l.patient_id
    where e.started_at is not null
      and toDate(e.started_at) between l.preauth_valid_from and ifNull(l.preauth_valid_to, l.preauth_valid_from)
    group by l.branch_id, l.line_natural_id
)

select
    l.branch_id                                                                      as branch_id,
    l.line_natural_id                                                                as line_natural_id,
    l.response_id                                                                    as response_id,
    toUInt64(l.pull_count)                                                           as pull_count,
    l.first_pulled_at                                                                as first_pulled_at,
    l.responded_at                                                                   as responded_at,
    l.res_status                                                                     as res_status,
    l.payer_license                                                                  as payer_license,
    l.claim_response_identifier                                                      as claim_response_identifier,
    l.preauth_reference                                                              as preauth_reference,
    l.preauth_valid_from                                                             as preauth_valid_from,
    l.preauth_valid_to                                                               as preauth_valid_to,
    l.created_at                                                                     as created_at,
    l.claim_type                                                                     as claim_type,
    l.claim_subtype                                                                  as claim_subtype,
    multiIf(l.claim_subtype = 'op', 'OP', l.claim_subtype = 'ip', 'IP', l.claim_subtype = 'emr', 'ER',
            cast(null as Nullable(String)))                                          as care_type,
    l.disposition                                                                    as disposition,
    l.outcome_code                                                                   as outcome_code,
    -- the status vocabulary of int_preauth_line (APPROVED, PARTIAL, REJECTED, NOT-REQUIRED)
    if(l.outcome_code is null, cast(null as Nullable(String)), upper(l.outcome_code)) as nphies_status,
    {{ hnh_nphies_outcome('l.outcome_code') }}                                       as outcome,
    l.advance_reason                                                                 as advance_reason,
    l.referring_provider_name                                                        as referring_provider_name,
    l.patient_identifier_type                                                        as patient_identifier_type,
    l.patient_match_count                                                            as patient_match_count,
    l.patient_id                                                                     as patient_id,
    if(rl.match_count > 0, tupleElement(rl.chosen, 1), tupleElement(vl.chosen, 1))   as episode_no,
    toUInt32(if(rl.match_count > 0, rl.match_count, ifNull(vl.match_count, 0)))      as episode_match_count,
    multiIf(rl.match_count > 0, 'Reference', vl.match_count > 0, 'Validity period',
            cast(null as Nullable(String)))                                          as episode_link_method,
    if(rl.match_count > 0, tupleElement(rl.chosen, 2), tupleElement(vl.chosen, 2))   as purchaser_code,
    l.add_item_count                                                                 as add_item_count,
    -- amounts as sent (0 and 1-SAR placeholders kept): total[] first, else the sum over addItem[]
    coalesce(l.total_benefit, l.add_item_benefit)                                    as approved_amount,
    coalesce(l.total_submitted, l.add_item_submitted)                                as submitted_amount,
    coalesce(l.total_eligible, l.add_item_eligible)                                  as eligible_amount
from linked as l
left join reference_link as rl
    on rl.branch_id = l.branch_id and rl.line_natural_id = l.line_natural_id
left join validity_link as vl
    on vl.branch_id = l.branch_id and vl.line_natural_id = l.line_natural_id
{{ hnh_settings() }}
