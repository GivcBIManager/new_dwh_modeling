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

{# Whole years between two dates (365.25-day years). #}
{% macro hnh_years_between(start_date, ref_date) -%}
toInt32(floor(dateDiff('day', {{ start_date }}, {{ ref_date }}) / 365.25))
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

{# Fusion FTE work measures are sparse and often 0: use a value only when it lies in (0, 1.5]. #}
{% macro hnh_fte(value) -%}
toFloat64(if(ifNull({{ value }}, 0) > 0 and ifNull({{ value }}, 0) <= 1.5, ifNull({{ value }}, 0), 1))
{%- endmacro %}

{# Branch of a Fusion HR department from its name prefix (H6). #}
{% macro hnh_hr_dept_prefix_branch(prefix) -%}
toUInt8(multiIf(ifNull({{ prefix }}, '') = 'RBW', 1, ifNull({{ prefix }}, '') = 'KHM', 2, ifNull({{ prefix }}, '') = 'JAZ', 3,
                ifNull({{ prefix }}, '') = 'UNI', 4, ifNull({{ prefix }}, '') = 'MAD', 5, ifNull({{ prefix }}, '') = 'ABH', 6,
                ifNull({{ prefix }}, '') = 'GHI', 7, ifNull({{ prefix }}, '') = 'MHL', 8, ifNull({{ prefix }}, '') = 'HQ', 100, 0))
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
