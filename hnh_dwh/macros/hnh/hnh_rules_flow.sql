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

{# Oasis order line status. P, Q and X are pending/queued/excluded states the old report left out;
   anything else unrecognised (e.g. A) is Unknown and stays out of leak scope. #}
{% macro hnh_order_line_status(status_code) -%}
multiIf({{ status_code }} = 'D', 'Delivered',
        {{ status_code }} in ('R', 'O'), 'Ordered',
        {{ status_code }} = 'C', 'Cancelled',
        {{ status_code }} in ('P', 'Q', 'X'), 'Not applicable',
        'Unknown')
{%- endmacro %}

{# Category of an ordered product, as the old Order Fulfillment report grouped it. #}
{% macro hnh_order_category(product_category_code) -%}
multiIf(ifNull({{ product_category_code }}, '') = 'PK', 'Package',
        ifNull({{ product_category_code }}, '') = 'LAB', 'Lab',
        ifNull({{ product_category_code }}, '') = 'RAD', 'Radiology',
        ifNull({{ product_category_code }}, '') = 'CON', 'Consultation',
        {{ hnh_is_medication(product_category_code, "cast(null as Nullable(String))") }} = 1, 'Pharmacy',
        'Others')
{%- endmacro %}

{# Fulfilment of an order line: its own live charge first, then a charged alternative, then a
   charged same-generic substitute in the same episode (pharmacy). #}
{% macro hnh_order_fulfilment_status(line_status, has_live_charge, has_charged_alternative, has_charged_substitute) -%}
multiIf({{ line_status }} = 'Cancelled', 'Cancelled',
        {{ line_status }} in ('Not applicable', 'Unknown'), 'Not applicable',
        {{ has_live_charge }} = 1, 'Delivered',
        {{ has_charged_alternative }} = 1, 'Delivered by alternative',
        {{ has_charged_substitute }} = 1, 'Delivered by substitute',
        'Undelivered')
{%- endmacro %}
