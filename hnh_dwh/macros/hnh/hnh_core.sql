{# Deterministic non-null Int64 key. Components are compared as strings so the
   key does not depend on the numeric type of an id. A null component gives -1. #}
{% macro hnh_surrogate_key(columns) -%}
if(
    {% for c in columns %}isNull({{ c }}){% if not loop.last %} or {% endif %}{% endfor %},
    toInt64(-1),
    toInt64(bitShiftRight(cityHash64(concat(
        {% for c in columns %}toString(assumeNotNull({{ c }})), '|'{% if not loop.last %}, {% endif %}{% endfor %}
    )), 1))
)
{%- endmacro %}

{# Optional numeric reference: Float64 / Decimal / Int to Nullable(Int64); 0 means "none". #}
{% macro hnh_id(col) -%}
nullIf(toInt64({{ col }}), 0)
{%- endmacro %}

{# Trimmed text; empty becomes null. #}
{% macro hnh_str(col) -%}
nullIf(trimBoth(ifNull(toString({{ col }}), '')), '')
{%- endmacro %}

{# Text identifier (staff ids, type letters): trimmed and upper-cased. #}
{% macro hnh_code(col) -%}
nullIf(upper(trimBoth(ifNull(toString({{ col }}), ''))), '')
{%- endmacro %}

{% macro hnh_flag(col) -%}
toUInt8(ifNull(toString({{ col }}), '') = 'Y')
{%- endmacro %}

{# Oasis timestamps are KSA wall-clock values labelled UTC. Keep the wall-clock
   value and give it its true zone. KSA has no daylight saving, so the offset is fixed. #}
{% macro hnh_ksa_wall_clock(col) -%}
toDateTime({{ col }} - toIntervalHour(3), 'Asia/Riyadh')
{%- endmacro %}

{# Oracle Julian day number to Date. Julian day 2440588 is 1970-01-01. #}
{% macro hnh_julian_to_date(col) -%}
(toDate('1970-01-01') + toInt32({{ col }} - 2440588))
{%- endmacro %}

{% macro hnh_date_key(col) -%}
toInt32(toYYYYMMDD({{ col }}))
{%- endmacro %}

{% macro hnh_time_key(col) -%}
toInt16(toHour({{ col }}) * 60 + toMinute({{ col }}))
{%- endmacro %}

{# Whole minutes from start to end; null when negative or longer than a day. #}
{% macro hnh_minutes_between(start_col, end_col) -%}
if(dateDiff('minute', {{ start_col }}, {{ end_col }}) between 0 and 1440,
   dateDiff('minute', {{ start_col }}, {{ end_col }}), null)
{%- endmacro %}

{# Unmatched left-join rows must be NULL, not 0 or ''. #}
{% macro hnh_settings() -%}
settings join_use_nulls = 1
{%- endmacro %}
