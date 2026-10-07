{{ config(order_by='surveycode') }}

-- One row per survey with at least one background or routing answer: the conformed value of each attribute
-- (spec 4.1, 4.2, 6.1). A survey without an answer for an attribute gets 'Not answered'; an answer code with no row in
-- map_pg_background_value gets 'Unmapped'.
{%- set attributes = {
    'respondent_type': 'respondent', 'first_visit': 'first_visit', 'booking_channel': 'booking_channel',
    'admitted_via_er': 'admitted_via_er', 'used_lab': 'used_lab', 'used_radiology': 'used_radiology',
    'used_pharmacy': 'used_pharmacy', 'used_insurance_office': 'used_insurance_office', 'used_physio': 'used_physio',
    'used_speech': 'used_speech', 'treatment_complete': 'treatment_complete', 'meds_delivered': 'meds_delivered',
    'tele_spared_visit': 'tele_spared_visit', 'tele_channel': 'tele_channel', 'hhc_service': 'hhc_service',
    'dental_service': 'dental_service', 'dialysis_done': 'dialysis_done', 'contact_consent': 'contact_consent'
} %}
with answers as (
    select a.surveycode as surveycode, q.role as role, ifNull(v.conformed_value, 'Unmapped') as conformed_value
    from {{ ref('stg_pg__survey_answer') }} as a
    inner join (select service_code, question_code, role from {{ ref('stg_ref__pg_question_role') }}
                where role not in ('Hospital NPS', 'Physician NPS')) as q
        on q.service_code = a.service_code and q.question_code = a.question_code
    left join {{ ref('stg_ref__pg_background_value') }} as v
        on v.service_code = a.service_code and v.question_code = a.question_code and v.answer_code = a.answer_code
    {{ hnh_settings() }}  -- left join in a CTE: settings must sit here
)

select
    surveycode,
{%- for column, role in attributes.items() %}
    if(countIf(role = '{{ role }}') > 0, anyIf(conformed_value, role = '{{ role }}'), 'Not answered') as {{ column }}{{ ',' if not loop.last }}
{%- endfor %}
from answers
group by surveycode
