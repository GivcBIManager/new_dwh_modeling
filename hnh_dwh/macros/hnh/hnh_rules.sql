{# Episode attendance type to care type. Anything unrecognised is Unknown, never IP. #}
{% macro hnh_care_type(col) -%}
multiIf({{ col }} = 'O', 'OP', {{ col }} = 'E', 'ER', {{ col }} = 'I', 'IP', {{ col }} = 'D', 'DAYCASE', 'Unknown')
{%- endmacro %}

{% macro hnh_care_type_key(expr) -%}
toInt8(multiIf({{ expr }} = 'OP', 1, {{ expr }} = 'ER', 2, {{ expr }} = 'IP', 3, {{ expr }} = 'DAYCASE', 4, -1))
{%- endmacro %}

{# Appointment / ER outcome description (upper-cased, trimmed) to a group label.
   Codes differ by branch; descriptions are what is shared. #}
{% macro hnh_outcome_group(col) -%}
multiIf(
    startsWith(ifNull({{ col }}, ''), 'CANCELLED') or startsWith(ifNull({{ col }}, ''), 'EPISODE CLOSED-CANCEL'), 'Cancelled',
    startsWith(ifNull({{ col }}, ''), 'RESCHEDULED'), 'Rescheduled',
    ifNull({{ col }}, '') in ('DNA', 'NOSHOW') or startsWith(ifNull({{ col }}, ''), 'CARE LESS'), 'No-show recorded',
    startsWith(ifNull({{ col }}, ''), 'LEFT WITHOUT BEING SEEN'), 'Left without being seen',
    startsWith(ifNull({{ col }}, ''), 'ADMISSION TO') or startsWith(ifNull({{ col }}, ''), 'ADMITTED TO')
        or startsWith(ifNull({{ col }}, ''), 'PATIENT ADMITTED') or startsWith(ifNull({{ col }}, ''), 'DIRECT TO OR')
        or startsWith(ifNull({{ col }}, ''), 'CATH LAB'), 'Admitted',
    startsWith(ifNull({{ col }}, ''), 'REFER') or startsWith(ifNull({{ col }}, ''), 'TRANSFERRED TO')
        or startsWith(ifNull({{ col }}, ''), 'EHALA'), 'Referred',
    startsWith(ifNull({{ col }}, ''), 'DAMA') or startsWith(ifNull({{ col }}, ''), 'LAMA'), 'Left against advice',
    ifNull({{ col }}, '') = 'DIED', 'Died',
    ifNull({{ col }}, '') in ('FOLLOW-UP BOOKED', 'CONDITION CURED', 'DISCHARGED', 'ER DISCHARGE (CURED)',
        'FOLLOW-UP RECOMMENDED IN OPD (IMPROVED)', 'RETURN AT WILL', 'IMPROVEMENT IN CONDITION',
        'DISCHARGE AND CLOSE FUTURE APPT', 'CLOSE EPISODE'), 'Attended',
    'Other'
)
{%- endmacro %}

{# Inpatient discharge outcome description (upper-cased, trimmed) to a group label. #}
{% macro hnh_discharge_outcome_group(col) -%}
multiIf(
    ifNull({{ col }}, '') = 'NORMAL DISCHARGE', 'Normal discharge',
    ifNull({{ col }}, '') in ('DAMA', 'LAMA'), 'Left against advice',
    ifNull({{ col }}, '') = 'DIED', 'Died',
    ifNull({{ col }}, '') like '%ANOTHER HOSPITAL%', 'Transferred out',
    ifNull({{ col }}, '') like '%ANOTHER EPISODE%', 'Transferred to another episode',
    ifNull({{ col }}, '') = 'WRONG ADMISSION', 'Wrong admission',
    ifNull({{ col }}, '') = 'ESCAPED', 'Absconded',
    'Other'
)
{%- endmacro %}

{# Work-entity type letter to care setting. #}
{% macro hnh_care_setting(col) -%}
multiIf(
    ifNull({{ col }}, '') in ('C', '1'), 'OP',
    ifNull({{ col }}, '') = 'W', 'IP',
    ifNull({{ col }}, '') = 'E', 'ER',
    ifNull({{ col }}, '') in ('D', 'Z', 'J', 'F', 'O'), 'Theatre',
    ifNull({{ col }}, '') in ('B', 'X', 'P', 'Y', 'R', 'K'), 'Ancillary',
    'Support'
)
{%- endmacro %}

{# Letters and digits only, upper-cased, leading zeros removed. #}
{% macro hnh_normalise_identifier(col) -%}
replaceRegexpOne(upper(replaceRegexpAll(ifNull(toString({{ col }}), ''), '[^0-9A-Za-z]', '')), '^0+', '')
{%- endmacro %}

{# The identifier a person is known by across branches. The type prefix stops a
   passport number colliding with a national id. Falls back to the local patient. #}
{% macro hnh_person_identifier(national_id, passport_no, border_no, branch_id, patient_id) -%}
multiIf(
    {{ hnh_normalise_identifier(national_id) }} != '', concat('N:', {{ hnh_normalise_identifier(national_id) }}),
    {{ hnh_normalise_identifier(passport_no) }} != '', concat('P:', {{ hnh_normalise_identifier(passport_no) }}),
    {{ hnh_normalise_identifier(border_no) }} != '', concat('B:', {{ hnh_normalise_identifier(border_no) }}),
    concat('L:', toString({{ branch_id }}), '|', toString({{ patient_id }}))
)
{%- endmacro %}

{% macro hnh_person_identifier_source(national_id, passport_no, border_no) -%}
multiIf(
    {{ hnh_normalise_identifier(national_id) }} != '', 'National id or iqama',
    {{ hnh_normalise_identifier(passport_no) }} != '', 'Passport',
    {{ hnh_normalise_identifier(border_no) }} != '', 'Border number',
    'Local'
)
{%- endmacro %}

{# The four shifts used by the existing reports. #}
{% macro hnh_shift(col) -%}
multiIf(
    toHour({{ col }}) < 8, '00:00-08:00',
    toHour({{ col }}) < 12, '08:00-12:00',
    toHour({{ col }}) * 60 + toMinute({{ col }}) < 990, '12:00-16:30',
    '16:30-24:00'
)
{%- endmacro %}

{# Patient id types that carry a Saudi national id or iqama number. #}
{% macro hnh_is_national_id_type(description_upper_col) -%}
ifNull({{ description_upper_col }}, '') in ('IQAMA', 'NATIONAL NUMBER', 'NATIONAL ID', 'NATIONAL ID CARD',
    'NATIONAL IDENTITY CARD', 'SAUDI ID CARD', 'I.D. CARD')
{%- endmacro %}

{# A Saudi citizen (1...) or resident (2...) number: exactly 10 digits after normalisation. #}
{% macro hnh_is_valid_national_id(col) -%}
match({{ hnh_normalise_identifier(col) }}, '^[12][0-9]{9}$')
{%- endmacro %}
