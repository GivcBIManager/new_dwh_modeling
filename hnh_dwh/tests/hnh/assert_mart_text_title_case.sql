-- Source names and text in the marts are title-cased through hnh_title (rule in CLAUDE.md).
-- Checked: every text column named *description*, *_desc, *_name, *_name_en/_ar or full_name* in a built
-- mart model (new models are picked up without listing them), plus `extra`; minus `excluded`.
-- marts/ssas (pass-through views) and marts/bsc (keeps the old server's values) are skipped.
-- One row per offending value, at most 10 per column.
{%- set extra = [
    'dim_bed.bed_class', 'dim_bed.current_ward', 'dim_bed.current_slot_status',
    'dim_er_priority.colour', 'dim_staff.staff_grade', 'hnh_dim_location.town_or_city',
    'fact_surgery.operation_type', 'fact_surgery.anaesthesia_type', 'fact_surgery.operation_status', 'fact_surgery.cancel_reason',
] -%}
{#- Name-like columns that are not source text, or whose all-caps values are acronyms and codes. #}
{%- set excluded = [
    'dim_budget_line.budget_line_name',
    'hnh_dim_department.short_name',
    'hnh_dim_gl_account.natural_account_name', 'hnh_dim_gl_account.specialty_name', 'hnh_dim_gl_account.service_location_name',
    'hnh_dim_job.job_name', 'hnh_dim_position.position_name',
    'hnh_dim_hr_department.department_name', 'hnh_dim_hr_department.department_base_name',
    'sec_user_access.user_name', 'sec_user_access.source_user_name', 'sec_user_access.login_name',
] -%}
{%- set checks = [] -%}
{%- if execute -%}
    {%- for node in graph.nodes.values() if node.resource_type == 'model' and 'marts' in node.fqn
            and 'ssas' not in node.fqn and 'bsc' not in node.fqn and node.config.materialized != 'ephemeral' -%}
        {%- set relation = adapter.get_relation(database=node.database, schema=node.schema, identifier=node.alias) -%}
        {%- if relation -%}
            {%- for column in adapter.get_columns_in_relation(relation) -%}
                {%- set name = column.name | lower -%}
                {%- set qualified = node.name ~ '.' ~ name -%}
                {%- set name_like = 'description' in name or name.endswith('_desc') or name.endswith('_name')
                        or name.endswith('_name_en') or name.endswith('_name_ar') or name.startswith('full_name') -%}
                {%- if (name_like or qualified in extra) and qualified not in excluded
                        and 'String' in column.data_type and 'Array' not in column.data_type -%}
                    {%- do checks.append({'relation': relation, 'model': node.name, 'column': column.name}) -%}
                {%- endif -%}
            {%- endfor -%}
        {%- endif -%}
    {%- endfor -%}
{%- endif %}

{% for c in checks -%}
select '{{ c.model }}' as model, '{{ c.column }}' as column_name, toString({{ c.column }}) as value
from {{ c.relation }}
where {{ c.column }} != {{ hnh_title(c.column) }}
limit 10
{% if not loop.last %}union all
{% endif %}
{%- else -%}
select '' as model, '' as column_name, '' as value where 0
{%- endfor %}
