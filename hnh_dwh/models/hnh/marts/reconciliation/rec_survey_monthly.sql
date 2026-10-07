{{ config(order_by='(branch_key, survey_service_key, month_start)') }}

-- Source against gold per branch, survey service and visit month (spec 6.3, 8): invitations and non-null answers must
-- match exactly (answers counted on the raw JSON); link rate is monitored. Branch from dim_branch.pg_branch_code (0 when
-- the code is unknown).
with branches as (
    select branch_key, pg_branch_code from {{ ref('hnh_dim_branch') }} where pg_branch_code is not null
),

source_invitations as (
    select ifNull(b.branch_key, toUInt8(0)) as s_branch_key, r.service_code as s_service, toStartOfMonth(assumeNotNull(r.visit_date)) as s_month,
           count() as k_source_invitations
    from {{ ref('stg_pg__survey_response') }} as r
    left join branches as b on b.pg_branch_code = r.pg_branch_code
    group by s_branch_key, s_service, s_month
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

source_answers as (
    -- counted on the raw responses JSON, independently of the expansion in stg_pg__survey_answer: non-null, non-blank
    -- values, except the comments key and the stray initial_response array (spec P2)
    select ifNull(b.branch_key, toUInt8(0)) as a_branch_key, r.service_code as a_service, toStartOfMonth(assumeNotNull(r.visit_date)) as a_month,
           sum(arrayCount(kv -> kv.2 is not null and trimBoth(ifNull(kv.2, '')) != '' and kv.1 not in ('comments', 'initial_response'),
                          JSONExtractKeysAndValues(r.responses_json, 'Nullable(String)'))) as k_source_answers
    from {{ ref('stg_pg__survey_response') }} as r
    left join branches as b on b.pg_branch_code = r.pg_branch_code
    group by a_branch_key, a_service, a_month
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

gold_responses as (
    select branch_key as g_branch_key, survey_service_key as g_service,
           toStartOfMonth(YYYYMMDDToDate(toUInt32(visit_date_key))) as g_month,
           count() as k_gold_invitations, countIf(link_status = 'Linked') as k_linked,
           countIf(is_responded = 1) as k_responded, countIf(is_responded = 1 and staff_key != -1) as k_responded_with_doctor
    from {{ ref('fact_survey_response') }}
    group by g_branch_key, g_service, g_month
),

gold_answers as (
    select branch_key as ga_branch_key, survey_service_key as ga_service,
           toStartOfMonth(YYYYMMDDToDate(toUInt32(visit_date_key))) as ga_month, count() as k_gold_answers
    from {{ ref('fact_survey_answer') }}
    group by ga_branch_key, ga_service, ga_month
)

select
    s.s_branch_key                                          as branch_key,
    s.s_service                                             as survey_service_key,
    s.s_month                                               as month_start,
    s.k_source_invitations                                  as source_invitations,
    ifNull(g.k_gold_invitations, 0)                         as gold_invitations,
    toInt64(s.k_source_invitations) - toInt64(ifNull(g.k_gold_invitations, 0)) as invitation_difference,
    ifNull(sa.k_source_answers, 0)                          as source_answers,
    ifNull(ga.k_gold_answers, 0)                            as gold_answers,
    toInt64(ifNull(sa.k_source_answers, 0)) - toInt64(ifNull(ga.k_gold_answers, 0)) as answer_difference,
    ifNull(g.k_linked, 0)                                   as linked_invitations,
    round(ifNull(g.k_linked, 0) / s.k_source_invitations, 4) as link_rate,
    ifNull(g.k_responded, 0)                                as responded,
    ifNull(g.k_responded_with_doctor, 0)                    as responded_with_doctor
from source_invitations as s
left join gold_responses as g on g.g_branch_key = s.s_branch_key and g.g_service = s.s_service and g.g_month = s.s_month
left join source_answers as sa on sa.a_branch_key = s.s_branch_key and sa.a_service = s.s_service and sa.a_month = s.s_month
left join gold_answers as ga on ga.ga_branch_key = s.s_branch_key and ga.ga_service = s.s_service and ga.ga_month = s.s_month
{{ hnh_settings() }}
