{{ config(order_by='(branch_key, visit_date_key, survey_response_key)') }}

-- One row per Press Ganey survey invitation (spec 6.1). response_status: Submitted = submitted with at least one
-- answer; Partial = answers but not submitted; Not started = no answer (also the few 'submitted' surveys that carry no
-- answer). survey_date is the answer date only on submitted surveys; on partial and not-started ones it is the
-- survey's close (expiry) date, a median 15 days after the visit, so survey_date_key and days_visit_to_answer are kept
-- for submitted surveys only. is_primary_for_encounter marks one invitation per branch + encounter id: a submitted one,
-- else a partial one, else any, latest survey date first (tie-break highest surveycode). The NPS columns come from the
-- service's Hospital NPS and Physician NPS answers (spec X1).
{%- set attributes = ['respondent_type', 'first_visit', 'booking_channel', 'admitted_via_er', 'used_lab',
    'used_radiology', 'used_pharmacy', 'used_insurance_office', 'used_physio', 'used_speech', 'treatment_complete',
    'meds_delivered', 'tele_spared_visit', 'tele_channel', 'hhc_service', 'dental_service', 'dialysis_done',
    'contact_consent'] %}
with answer_stats as (
    select a.surveycode as st_surveycode, count() as k_answers, countIf(q.is_scored = 1) as k_scored_answered
    from {{ ref('stg_pg__survey_answer') }} as a
    left join (select service_code, question_code, is_scored from {{ ref('stg_pg__survey_question') }}) as q
        on q.service_code = a.service_code and q.question_code = a.question_code
    group by a.surveycode
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
),

offered as (
    select service_code as of_service_code, toUInt32(countIf(is_scored = 1)) as k_offered
    from {{ ref('stg_pg__survey_question') }}
    group by service_code
),

nps_answers as (
    select a.surveycode as n_surveycode,
           maxIf(o.score, r.role = 'Hospital NPS')          as k_nps_score,
           anyIf(q.scale_type, r.role = 'Hospital NPS')     as k_nps_scale,
           maxIf(o.score, r.role = 'Physician NPS')         as k_physician_score,
           anyIf(q.scale_type, r.role = 'Physician NPS')    as k_physician_scale
    from {{ ref('stg_pg__survey_answer') }} as a
    inner join (select service_code, question_code, role from {{ ref('stg_ref__pg_question_role') }}
                where role in ('Hospital NPS', 'Physician NPS')) as r
        on r.service_code = a.service_code and r.question_code = a.question_code
    left join (select service_code, question_code, scale_type from {{ ref('stg_pg__survey_question') }}) as q
        on q.service_code = a.service_code and q.question_code = a.question_code
    left join (select service_code, question_code, answer_code, score from {{ ref('stg_pg__answer_option') }}) as o
        on o.service_code = a.service_code and o.question_code = a.question_code and o.answer_code = a.answer_code
    group by a.surveycode
    {{ hnh_settings() }}  -- left joins in a CTE: settings must sit here
),

base as (
    select
        r.surveycode                                        as surveycode,
        l.branch_key                                        as branch_key,
        r.service_code                                      as service_code,
        r.encounter_id                                      as encounter_id,
        r.visit_date                                        as visit_date,
        r.sms_send_date                                     as sms_send_date,
        r.survey_date                                       as survey_date,
        r.source_status                                     as source_status,
        l.encounter_key                                     as encounter_key,
        l.episode_key                                       as episode_key,
        l.patient_key                                       as patient_key,
        l.staff_key                                         as staff_key,
        l.department_key                                    as department_key,
        l.payer_key                                         as payer_key,
        l.care_type_key                                     as care_type_key,
        l.link_status                                       as link_status,
        toUInt32(ifNull(st.k_answers, 0))                   as answers_count,
        toUInt32(ifNull(st.k_scored_answered, 0))           as scored_questions_answered,
        ifNull(ofr.k_offered, toUInt32(0))                  as scored_questions_offered,
        n.k_nps_score                                       as nps_score,
        n.k_nps_scale                                       as nps_scale,
        n.k_physician_score                                 as physician_nps_score,
        n.k_physician_scale                                 as physician_nps_scale,
{%- for a in attributes %}
        ifNull(bg.{{ a }}, 'Not answered')                  as {{ a }},
{%- endfor %}
        toUInt8(ifNull(st.k_answers, 0) > 0)                as is_responded
    from {{ ref('stg_pg__survey_response') }} as r
    inner join {{ ref('int_survey_encounter_link') }} as l on l.surveycode = r.surveycode
    left join answer_stats as st on st.st_surveycode = r.surveycode
    left join offered as ofr on ofr.of_service_code = r.service_code
    left join nps_answers as n on n.n_surveycode = r.surveycode
    left join {{ ref('int_survey_background') }} as bg on bg.surveycode = r.surveycode
    {{ hnh_settings() }}  -- left joins in a CTE: settings must sit here
)

select
    {{ hnh_surrogate_key(['surveycode']) }}                 as survey_response_key,
    surveycode,
    branch_key,
    service_code                                            as survey_service_key,
    care_type_key,
    encounter_key,
    episode_key,
    patient_key,
    staff_key,
    department_key,
    payer_key,
    {{ hnh_date_key('assumeNotNull(visit_date)') }}         as visit_date_key,
    {{ hnh_date_key_in_range('sms_send_date') }}            as sms_sent_date_key,
    if(is_responded = 1 and source_status = 'submitted', {{ hnh_date_key_in_range('survey_date') }}, null) as survey_date_key,
    encounter_id,
    source_status,
    multiIf(is_responded = 1 and source_status = 'submitted', 'Submitted',
            is_responded = 1, 'Partial', 'Not started')     as response_status,
    toUInt8(sms_send_date is not null)                      as is_sms_sent,
    is_responded,
    toUInt8(is_responded = 1 and source_status = 'submitted') as is_submitted,
    toUInt8(row_number() over (partition by branch_key, encounter_id
                               order by (is_responded = 1 and source_status = 'submitted') desc, is_responded desc,
                                        survey_date desc, surveycode desc) = 1) as is_primary_for_encounter,
    answers_count,
    scored_questions_offered,
    scored_questions_answered,
    if(sms_send_date is null, null, dateDiff('day', visit_date, sms_send_date)) as days_visit_to_sms,
    if(is_responded = 1 and source_status = 'submitted', dateDiff('day', visit_date, survey_date), null) as days_visit_to_answer,
    link_status,
{%- for a in attributes %}
    {{ a }},
{%- endfor %}
    nps_score,
    {{ hnh_survey_band('nps_scale', 'nps_score') }}         as nps_band,
    physician_nps_score,
    {{ hnh_survey_band('physician_nps_scale', 'physician_nps_score') }} as physician_nps_band,
    now()                                                   as _loaded_at
from base
