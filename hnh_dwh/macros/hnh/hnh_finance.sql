{# Balance sheet grouping of the finance report (ssas_fact_gl_fs_monthly). Each macro takes the column expressions of
   fs_type, fs_element, fs_category (and fs_caption) as quoted strings and returns one expression. Plain macros (no Jinja
   statements) so scripts/render_model_sql.py can expand them for the offline checks. The FS labels of the mart are
   lower case; the title-casing repeats hnh_title (the renderer takes no nested call).
   Income statement rows join the balance sheet as current year profit under Liabilities & equity / Equity. A balance
   sheet row whose element is not assets, liabilities or equity, or whose category is 'not mapped', is 'Not mapped' on
   every level, so a mapping gap shows instead of unbalancing a side. #}

{% macro hnh_bs_side(fs_type, fs_element, fs_category) -%}
toString(multiIf({{ fs_type }} = 'is', 'Liabilities & equity',
    {{ fs_element }} not in ('assets', 'liabilities', 'equity') or {{ fs_category }} = 'not mapped', 'Not mapped',
    {{ fs_element }} = 'assets', 'Assets', 'Liabilities & equity'))
{%- endmacro %}

{% macro hnh_bs_element(fs_type, fs_element, fs_category) -%}
toString(multiIf({{ fs_type }} = 'is', 'Equity',
    {{ fs_element }} not in ('assets', 'liabilities', 'equity') or {{ fs_category }} = 'not mapped', 'Not mapped',
    {{ fs_element }} = 'assets', 'Assets', {{ fs_element }} = 'liabilities', 'Liabilities', 'Equity'))
{%- endmacro %}

{% macro hnh_bs_category(fs_type, fs_element, fs_category) -%}
toString(multiIf({{ fs_type }} = 'is', 'Equity',
    {{ fs_element }} not in ('assets', 'liabilities', 'equity') or {{ fs_category }} = 'not mapped', 'Not mapped',
    if(match({{ fs_category }}, '[a-z]') and match({{ fs_category }}, '[A-Z]'), {{ fs_category }}, initcap({{ fs_category }}))))
{%- endmacro %}

{% macro hnh_bs_caption(fs_type, fs_element, fs_category, fs_caption) -%}
toString(multiIf({{ fs_type }} = 'is', 'Current year profit',
    {{ fs_element }} not in ('assets', 'liabilities', 'equity') or {{ fs_category }} = 'not mapped', 'Not mapped',
    if(match({{ fs_caption }}, '[a-z]') and match({{ fs_caption }}, '[A-Z]'), {{ fs_caption }}, initcap({{ fs_caption }}))))
{%- endmacro %}

{% macro hnh_bs_element_order(fs_type, fs_element, fs_category) -%}
toInt64(multiIf({{ fs_type }} = 'is', 3,
    {{ fs_element }} not in ('assets', 'liabilities', 'equity') or {{ fs_category }} = 'not mapped', 4,
    {{ fs_element }} = 'assets', 1, {{ fs_element }} = 'liabilities', 2, 3))
{%- endmacro %}

{% macro hnh_bs_category_order(fs_type, fs_element, fs_category) -%}
toInt64(multiIf({{ fs_type }} = 'is', 5,
    {{ fs_element }} not in ('assets', 'liabilities', 'equity') or {{ fs_category }} = 'not mapped', 9,
    {{ fs_category }} = 'current assets', 1, {{ fs_category }} = 'non current assets', 2,
    {{ fs_category }} = 'current liabilities', 3, {{ fs_category }} = 'non current liabilities', 4,
    {{ fs_category }} = 'equity', 5, 8))
{%- endmacro %}

{# Sign that turns the debit-positive GL amount into the report's: assets +1, liabilities, equity and the income
   statement -1 (credit positive, so profit is positive). A not mapped balance sheet row keeps the debit sign. #}
{% macro hnh_bs_display_sign(fs_type, fs_element, fs_category) -%}
toInt64(multiIf({{ fs_type }} = 'is', -1,
    {{ fs_element }} not in ('assets', 'liabilities', 'equity') or {{ fs_category }} = 'not mapped', 1,
    {{ fs_element }} = 'assets', 1, -1))
{%- endmacro %}

{# Top level of the trial balance: the repo label of the statement; any other fs_type value keeps its own text. #}
{% macro hnh_fs_type_label(fs_type) -%}
toString(multiIf({{ fs_type }} = 'bs', 'Balance sheet', {{ fs_type }} = 'is', 'Income statement', {{ fs_type }}))
{%- endmacro %}
