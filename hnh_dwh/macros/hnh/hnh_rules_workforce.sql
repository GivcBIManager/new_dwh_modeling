{# Fusion assignment action code to a movement group (spec 4.4). #}
{% macro hnh_movement_group(action_code) -%}
multiIf(ifNull({{ action_code }}, '') in ('HIRE', 'ADD_CWK'), 'Hire',
        ifNull({{ action_code }}, '') = 'REHIRE', 'Rehire',
        ifNull({{ action_code }}, '') in ('GLB_TRANSFER', 'TRANSFER'), 'Transfer',
        ifNull({{ action_code }}, '') in ('POSITION_CHANGE', 'PROMOTION', 'ASG_CHANGE'), 'Position change',
        ifNull({{ action_code }}, '') = 'RESIGNATION', 'Voluntary leaver',
        ifNull({{ action_code }}, '') in ('TERMINATION_ARTICLE_80', 'TERMINATION_ARTICLE_74', 'END_OF_CONTRACT', 'END_CONTRACT_IN_PROB_PERIOD')
            or ifNull({{ action_code }}, '') like 'TERMINAT%', 'Involuntary leaver',
        ifNull({{ action_code }}, '') = 'CONTRACT_EXTENSION', 'Contract extension',
        'Other')
{%- endmacro %}

{% macro hnh_absence_status(status_code, approval_code) -%}
multiIf(ifNull({{ status_code }}, '') = 'ORA_WITHDRAWN', 'Withdrawn',
        ifNull({{ status_code }}, '') = 'SAVED', 'Saved',
        ifNull({{ approval_code }}, '') = 'APPROVED', 'Approved',
        ifNull({{ approval_code }}, '') = 'DENIED', 'Denied',
        ifNull({{ approval_code }}, '') = 'AWAITING', 'Awaiting',
        'Other')
{%- endmacro %}

{# Counted absence: submitted and approved, not withdrawn or saved. #}
{% macro hnh_is_counted_absence(status_code, approval_code) -%}
toUInt8(ifNull({{ status_code }}, '') = 'SUBMITTED' and ifNull({{ approval_code }}, '') = 'APPROVED')
{%- endmacro %}

{% macro hnh_absence_category(type_name) -%}
multiIf(lower(ifNull({{ type_name }}, '')) like '%sick%', 'Sick',
        lower(ifNull({{ type_name }}, '')) like '%annual%', 'Annual',
        lower(ifNull({{ type_name }}, '')) like '%unpaid%', 'Unpaid',
        lower(ifNull({{ type_name }}, '')) like '%permission%', 'Permission',
        lower(ifNull({{ type_name }}, '')) like '%time back%', 'Time back',
        'Other')
{%- endmacro %}

{# Exact whole years between two dates (anniversary-aware). #}
{% macro hnh_years_between(start_date, ref_date) -%}
toInt32(dateDiff('year', {{ start_date }}, {{ ref_date }}) - if(addYears({{ start_date }}, dateDiff('year', {{ start_date }}, {{ ref_date }})) > {{ ref_date }}, 1, 0))
{%- endmacro %}

{% macro hnh_age_band(birth_date, ref_date) -%}
if({{ birth_date }} is null, 'Unknown',
   multiIf({{ hnh_years_between(birth_date, ref_date) }} < 25, '<25',
           {{ hnh_years_between(birth_date, ref_date) }} < 35, '25-34',
           {{ hnh_years_between(birth_date, ref_date) }} < 45, '35-44',
           {{ hnh_years_between(birth_date, ref_date) }} < 55, '45-54', '55+'))
{%- endmacro %}

{% macro hnh_tenure_band(start_date, ref_date) -%}
if({{ start_date }} is null, 'Unknown',
   multiIf({{ hnh_years_between(start_date, ref_date) }} < 1, '<1',
           {{ hnh_years_between(start_date, ref_date) }} < 3, '1-3',
           {{ hnh_years_between(start_date, ref_date) }} < 5, '3-5',
           {{ hnh_years_between(start_date, ref_date) }} < 10, '5-10', '10+'))
{%- endmacro %}

{# The order of an age or tenure band in reports (youngest / shortest first, Unknown last): the sort-by column of the
   band in the SSAS model (HR report, user request 2026-11-05). #}
{% macro hnh_age_band_order(band) -%}
multiIf({{ band }} = '<25', 1, {{ band }} = '25-34', 2, {{ band }} = '35-44', 3, {{ band }} = '45-54', 4, {{ band }} = '55+', 5, 9)
{%- endmacro %}

{% macro hnh_tenure_band_order(band) -%}
multiIf({{ band }} = '<1', 1, {{ band }} = '1-3', 2, {{ band }} = '3-5', 3, {{ band }} = '5-10', 4, {{ band }} = '10+', 5, 9)
{%- endmacro %}

{# Fusion FTE work measures are sparse and often 0: use a value only when it lies in (0, 1.5]. Otherwise 1, or 0.5
   for a part-time assignment (the 0.5 the BSC workforce view gives part-time doctors). #}
{% macro hnh_fte(value, part_time='0') -%}
toFloat64(if(ifNull({{ value }}, 0) > 0 and ifNull({{ value }}, 0) <= 1.5, ifNull({{ value }}, 0), if({{ part_time }} = 1, 0.5, 1)))
{%- endmacro %}

{# Part-time Fusion assignment: assignment category (EMPLOYMENT_CATEGORY) PR or PT; FULL_PART_TIME only when the
   category is not set (a few PR assignments say FULL_TIME there). #}
{% macro hnh_is_part_time(category, full_part_time) -%}
toUInt8(if({{ category }} is not null, {{ category }} in ('PR', 'PT'), ifNull({{ full_part_time }}, '') = 'PART_TIME'))
{%- endmacro %}

{# Branch of a Fusion HR department from its name prefix (H6). #}
{% macro hnh_hr_dept_prefix_branch(prefix) -%}
toUInt8(multiIf(ifNull({{ prefix }}, '') = 'RBW', 1, ifNull({{ prefix }}, '') = 'KHM', 2, ifNull({{ prefix }}, '') = 'JAZ', 3,
                ifNull({{ prefix }}, '') = 'UNI', 4, ifNull({{ prefix }}, '') = 'MAD', 5, ifNull({{ prefix }}, '') = 'ABH', 6,
                ifNull({{ prefix }}, '') = 'GHI', 7, ifNull({{ prefix }}, '') = 'MHL', 8, ifNull({{ prefix }}, '') = 'HQ', 100, 0))
{%- endmacro %}

{# Contingent worker: Fusion worker type CWK (contingent worker) or CON (contractor). They are counted apart: out of the
   headcount and every other HR measure, kept only for the contingent count (user decision 2026-11-19). No one has
   changed between contingent and employee (gold, 2026-11-19), so the current worker type holds for every row. #}
{% macro hnh_is_contingent(code) -%}
toUInt8(ifNull({{ code }}, '') in ('CWK', 'CON'))
{%- endmacro %}

{# The employee keys of contingent workers, as a subquery: `employee_key not in ({{ hnh_contingent_employee_keys() }})`. #}
{% macro hnh_contingent_employee_keys() -%}
select employee_key from {{ ref('hnh_dim_employee') }} where {{ hnh_is_contingent('worker_type_code') }} = 1
{%- endmacro %}

{% macro hnh_worker_type_label(code) -%}
multiIf(ifNull({{ code }}, '') = 'EMP', 'Employee', ifNull({{ code }}, '') = 'EX_EMP', 'Ex-employee',
        ifNull({{ code }}, '') = 'CWK', 'Contingent worker', ifNull({{ code }}, '') = 'CON', 'Contractor',
        ifNull({{ code }}, '') = 'CANCELED_HIRE', 'Cancelled hire', 'Unknown')
{%- endmacro %}

{# Month-ends of the headcount snapshot as a subquery: from var hnh_hr_snapshot_start to var hnh_hr_snapshot_end (empty = today). #}
{% macro hnh_hr_month_ends() -%}
{%- set end_var = var('hnh_hr_snapshot_end', '') -%}
{%- set end_expr = "toDate('" ~ end_var ~ "')" if end_var else "today()" -%}
select toLastDayOfMonth(addMonths(toDate('{{ var("hnh_hr_snapshot_start") }}'), toInt32(number))) as month_end
from numbers(toUInt64(greatest(dateDiff('month', toDate('{{ var("hnh_hr_snapshot_start") }}'), {{ end_expr }}) + 1, 0)))
{%- endmacro %}
