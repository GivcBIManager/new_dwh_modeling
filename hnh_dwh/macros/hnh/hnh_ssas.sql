{#
  SSAS spec 4.2 and planning decisions P2/P3. Select list of a gold.ssas_* view over ref(model_name):
  - legacy_* and _loaded_at are always dropped, `drop` lists more; an Array column must be dropped;
  - every Float column must be named in `decimals` (cast to Decimal(18, 4)) or `floats` (kept as Float64);
  - an is_*/has_* UInt8 flag becomes 'Yes'/'No' unless named in `int_flags` (flags that measures sum);
  - every other integer becomes Int64, and a nullable non-date *_key becomes -1 when null;
  - LowCardinality text becomes String, Date32 becomes Date;
  - `extra` appends select expressions; `joins` follows `from <model> as t`.
  A name in drop/decimals/floats/int_flags that is not a column fails compilation (typo guard).
#}
{% macro hnh_ssas_view(model_name, drop=[], decimals=[], floats=[], int_flags=[], extra=[], joins='') -%}
{%- set relation = ref(model_name) -%}
{%- if execute -%}
    {%- set columns = adapter.get_columns_in_relation(relation) -%}
    {%- set names = columns | map(attribute='name') | list -%}
    {%- for listed in drop + decimals + floats + int_flags -%}
        {%- if listed not in names -%}
            {{ exceptions.raise_compiler_error('hnh_ssas_view(' ~ model_name ~ '): unknown column ' ~ listed) }}
        {%- endif -%}
    {%- endfor -%}
    {%- set expressions = [] -%}
    {%- for c in columns -%}
        {%- if c.name not in drop and not c.name.startswith('legacy_') and c.name != '_loaded_at' -%}
            {%- do expressions.append(hnh_ssas_column(model_name, c.name, c.data_type, decimals, floats, int_flags) ~ ' as ' ~ c.name) -%}
        {%- endif -%}
    {%- endfor %}
select
    {{ (expressions + extra) | join(',\n    ') }}
from {{ relation }} as t
{{ joins }}
{%- else %}
select 1 as compile_placeholder from {{ relation }}
{%- endif -%}
{%- endmacro %}

{% macro hnh_ssas_column(model_name, name, data_type, decimals, floats, int_flags) -%}
{%- set ns = namespace(t=data_type, nullable=false, lowcard=false) -%}
{%- if ns.t.startswith('LowCardinality(') -%}{%- set ns.t = ns.t[15:-1] -%}{%- set ns.lowcard = true -%}{%- endif -%}
{%- if ns.t.startswith('Nullable(') -%}{%- set ns.t = ns.t[9:-1] -%}{%- set ns.nullable = true -%}{%- endif -%}
{%- if ns.t.startswith('LowCardinality(') -%}{%- set ns.t = ns.t[15:-1] -%}{%- set ns.lowcard = true -%}{%- endif -%}
{%- set col = 't.' ~ name -%}
{%- if ns.t.startswith('Array(') -%}
    {{ exceptions.raise_compiler_error('hnh_ssas_view(' ~ model_name ~ '): drop array column ' ~ name) }}
{%- elif ns.t.startswith('Float') -%}
    {%- if name in decimals -%}toDecimal64({{ col }}, 4)
    {%- elif name in floats -%}toFloat64({{ col }})
    {%- else -%}{{ exceptions.raise_compiler_error('hnh_ssas_view(' ~ model_name ~ '): list float column ' ~ name ~ ' in decimals or floats') }}
    {%- endif -%}
{%- elif ns.t.startswith('Int') or ns.t.startswith('UInt') -%}
    {%- if name in int_flags -%}toInt64({{ col }})
    {%- elif ns.t == 'UInt8' and (name.startswith('is_') or name.startswith('has_')) -%}if({{ col }} = 1, 'Yes', 'No')
    {%- elif ns.nullable and name.endswith('_key') and not name.endswith('date_key') and not name.endswith('time_key') -%}toInt64(ifNull({{ col }}, -1))
    {%- else -%}toInt64({{ col }})
    {%- endif -%}
{%- elif ns.t == 'Date32' -%}toDate({{ col }})
{%- elif ns.lowcard -%}cast({{ col }} as {{ 'Nullable(String)' if ns.nullable else 'String' }})
{%- else -%}{{ col }}
{%- endif -%}
{%- endmacro %}
