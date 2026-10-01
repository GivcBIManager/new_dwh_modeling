{# A closed stay shorter than one hour. An open stay is never a short stay. #}
{% macro hnh_is_short_stay(admitted_col, discharged_col) -%}
toUInt8(ifNull(dateDiff('minute', {{ admitted_col }}, {{ discharged_col }}) < 60, 0))
{%- endmacro %}

{# Long-term care: longer than 30 days, or referred as LTC. #}
{% macro hnh_is_ltc(los_days_expr, referred_upper_col) -%}
toUInt8(ifNull({{ los_days_expr }} > 30, 0) or ifNull({{ referred_upper_col }}, '') = 'LTC')
{%- endmacro %}

{# Where an admission came from: the request's admission department first,
   then the care type of the patient's previous episode. #}
{% macro hnh_admission_source(admission_department_upper_col, previous_care_type_col) -%}
multiIf(
    ifNull({{ admission_department_upper_col }}, '') in ('OUTPATIENT CLINICS', 'OPD'), 'OP',
    ifNull({{ admission_department_upper_col }}, '') in ('ACCIDENT & EMERGENCY', 'ER', 'EMERGENCY'), 'ER',
    ifNull({{ previous_care_type_col }}, '') in ('OP', 'ER'), ifNull({{ previous_care_type_col }}, ''),
    'Direct'
)
{%- endmacro %}

{% macro hnh_admission_source_key(expr) -%}
toInt8(multiIf({{ expr }} = 'OP', 1, {{ expr }} = 'ER', 2, {{ expr }} = 'Direct', 3, -1))
{%- endmacro %}

{% macro hnh_visit_type(is_first_episode_col, is_follow_up_col) -%}
multiIf({{ is_first_episode_col }} = 1, 'New patient', {{ is_follow_up_col }} = 1, 'Free follow-up', 'Paid visit')
{%- endmacro %}

{# Procedure type: Cesarean by description, otherwise by the theatre's entity type. #}
{% macro hnh_procedure_type(description_upper_col, entity_type_col) -%}
multiIf(
    multiSearchAny(ifNull({{ description_upper_col }}, ''), ['C.S ', 'C.S.', 'CESARIAN', 'CESAREAN']), 'Cesarean',
    ifNull({{ entity_type_col }}, '') = 'J', 'Cath Lab',
    ifNull({{ entity_type_col }}, '') = 'F', 'Endoscopy',
    ifNull({{ entity_type_col }}, '') = 'Z', 'L&D',
    'Surgery'
)
{%- endmacro %}

{% macro hnh_procedure_type_key(expr) -%}
toInt8(multiIf({{ expr }} = 'Surgery', 1, {{ expr }} = 'Cesarean', 2, {{ expr }} = 'Cath Lab', 3,
               {{ expr }} = 'Endoscopy', 4, {{ expr }} = 'L&D', 5, -1))
{%- endmacro %}
