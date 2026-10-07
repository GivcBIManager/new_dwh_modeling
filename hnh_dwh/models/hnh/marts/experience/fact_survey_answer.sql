{{ config(order_by='(branch_key, visit_date_key, survey_response_key, question_key)') }}

-- One row per survey and answered question, scored or not (spec 6.2). The response's keys are copied so that NPS by
-- domain, doctor and clinic reads this table alone. answer_score is the option score (never the raw code, spec P4);
-- band is the NPS-style band of a scored answer (hnh_survey_band). A code with no option row is flagged
-- is_option_unknown (LTC csurvey 2, spec O-P6-7); a question missing from the master gets question_key '-1'.
select
    r.survey_response_key                                   as survey_response_key,
    a.surveycode                                            as surveycode,
    if(q.question_code is null, '-1', concat(a.service_code, '|', a.question_code)) as question_key,
    a.question_code                                         as question_code,
    r.branch_key                                            as branch_key,
    r.survey_service_key                                    as survey_service_key,
    r.care_type_key                                         as care_type_key,
    r.encounter_key                                         as encounter_key,
    r.staff_key                                             as staff_key,
    r.department_key                                        as department_key,
    r.patient_key                                           as patient_key,
    r.payer_key                                             as payer_key,
    r.visit_date_key                                        as visit_date_key,
    r.response_status                                       as response_status,
    r.is_primary_for_encounter                              as is_primary_for_encounter,
    r.link_status                                           as link_status,
    a.answer_code                                           as answer_code,
    o.label_en                                              as answer_label_en,
    o.label_ar                                              as answer_label_ar,
    if(ifNull(q.is_scored, 0) = 1, o.score, null)           as answer_score,
    ifNull(q.is_scored, toUInt8(0))                         as is_scored,
    multiIf(q.question_code is null, 'Background', q.is_scored = 1, 'Scored',
            q.item_type = 'Routing', 'Routing', 'Background') as question_class,
    ifNull(q.scale_type, '')                                as scale_type,
    if(ifNull(q.is_scored, 0) = 1, {{ hnh_survey_band('q.scale_type', 'o.score') }}, null) as band,
    toUInt8(ifNull(q.is_scored, 0) = 1 and o.score is not null
            and {{ hnh_survey_band('q.scale_type', 'o.score') }} = 'Promoter')  as is_promoter,
    toUInt8(ifNull(q.is_scored, 0) = 1 and o.score is not null
            and {{ hnh_survey_band('q.scale_type', 'o.score') }} = 'Passive')   as is_passive,
    toUInt8(ifNull(q.is_scored, 0) = 1 and o.score is not null
            and {{ hnh_survey_band('q.scale_type', 'o.score') }} = 'Detractor') as is_detractor,
    if(ifNull(nr.role, '') in ('Hospital NPS', 'Physician NPS'), assumeNotNull(nr.role), '') as nps_role,
    toUInt8(o.answer_code is null)                          as is_option_unknown,
    now()                                                   as _loaded_at
from {{ ref('stg_pg__survey_answer') }} as a
inner join (select survey_response_key, surveycode, branch_key, survey_service_key, care_type_key, encounter_key,
                   staff_key, department_key, patient_key, payer_key, visit_date_key, response_status,
                   is_primary_for_encounter, link_status
            from {{ ref('fact_survey_response') }}) as r
    on r.surveycode = a.surveycode
left join {{ ref('stg_pg__survey_question') }} as q
    on q.service_code = a.service_code and q.question_code = a.question_code
left join {{ ref('stg_pg__answer_option') }} as o
    on o.service_code = a.service_code and o.question_code = a.question_code and o.answer_code = a.answer_code
left join {{ ref('stg_ref__pg_question_role') }} as nr
    on nr.service_code = a.service_code and nr.question_code = a.question_code
{{ hnh_settings() }}
