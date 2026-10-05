{# FS label as shown: trimmed, inner spaces collapsed, the source spelling "Deprecition" corrected. Case is kept. #}
{% macro hnh_fs_label(col) -%}
replaceRegexpAll(replaceAll(trimBoth(ifNull({{ col }}, '')), 'Deprecition', 'Depreciation'), ' +', ' ')
{%- endmacro %}

{# One key per FS position, independent of case and spacing. #}
{% macro hnh_fs_line_key(fs_type, fs_element, fs_category, fs_caption, fs_line) -%}
{{ hnh_surrogate_key(["lower(" ~ hnh_fs_label(fs_type) ~ ")", "lower(" ~ hnh_fs_label(fs_element) ~ ")",
                      "lower(" ~ hnh_fs_label(fs_category) ~ ")", "lower(" ~ hnh_fs_label(fs_caption) ~ ")",
                      "lower(" ~ hnh_fs_label(fs_line) ~ ")"]) }}
{%- endmacro %}

{# Care type of a GL line from the Fusion service location (segment 4). Endoscopy, Cath and Kidney Dialysis are
   outpatient day procedures (spec open item O-P3-6). #}
{% macro hnh_gl_care_type(location_code) -%}
multiIf(ifNull({{ location_code }}, '') in ('01', '04', '07', '08', '09', '10', '11'), 'OP',
        ifNull({{ location_code }}, '') in ('02', '03', '05'), 'IP',
        ifNull({{ location_code }}, '') = '06', 'ER',
        ifNull({{ location_code }}, '') in ('12', '13'), 'Other',
        'Unallocated')
{%- endmacro %}

{# Multiply debit-positive amounts by this to read a statement naturally. #}
{% macro hnh_fs_display_sign(fs_element) -%}
toInt8(if(lower(ifNull({{ fs_element }}, '')) in ('revenue', 'other income', 'liabilities', 'equity'), -1, 1))
{%- endmacro %}

{# Balance sheet or income statement: the FS mapping decides; unmapped accounts follow the Fusion account type. #}
{% macro hnh_gl_balance_side(fs_type, account_type) -%}
if({{ fs_type }} is not null, upper({{ fs_type }}), if(ifNull({{ account_type }}, '') in ('A', 'L', 'O'), 'BS', 'IS'))
{%- endmacro %}

{% macro hnh_not_mapped_element(account_type) -%}
multiIf(ifNull({{ account_type }}, '') = 'A', 'Assets', ifNull({{ account_type }}, '') = 'L', 'Liabilities',
        ifNull({{ account_type }}, '') = 'O', 'Equity', ifNull({{ account_type }}, '') = 'R', 'Revenue', 'Expenses')
{%- endmacro %}

{# Fusion calendar "Monthly 12 4": a quarterly adjustment period follows every third month, so month m is period
   m + floor((m - 1) / 3) (Jan 1 ... Mar 3, Apr 5 ... Dec 15). #}
{% macro hnh_gl_period_key_for_date(d) -%}
toInt32(toYear({{ d }}) * 100 + toMonth({{ d }}) + intDiv(toMonth({{ d }}) - 1, 3))
{%- endmacro %}

{# The side on which a budget code is normally positive. UNBUDGETED takes its statement group's side. #}
{% macro hnh_budget_natural_side(code, statement_group) -%}
if({{ code }} in ('REV_OP', 'REV_IP', 'REV_ER', 'REV_UNALLOCATED', 'OTHER_INCOME', 'OCI')
   or ({{ code }} = 'UNBUDGETED' and {{ statement_group }} in ('Revenue', 'Other income', 'OCI')), 'credit', 'debit')
{%- endmacro %}

{% macro hnh_ageing_bucket(days_overdue) -%}
multiIf({{ days_overdue }} <= 0, 'Not due', {{ days_overdue }} <= 30, '1-30', {{ days_overdue }} <= 60, '31-60',
        {{ days_overdue }} <= 90, '61-90', {{ days_overdue }} <= 180, '91-180', 'Over 180')
{%- endmacro %}

{# The synthetic account of a branch that carries the income-statement result of earlier fiscal years. #}
{% macro hnh_prior_year_results_key(branch_key) -%}
{{ hnh_surrogate_key(["'prior-year-results'", branch_key]) }}
{%- endmacro %}

{# Budget subtotals as weights over detail codes (spec G12). A component is a budget code, or UNBUDGETED with the
   statement group of its FS line; component_group '' matches any group. Subtotals are expanded at compile time. #}
{% macro hnh_budget_subtotal_weights() -%}
{%- set dc = ['DC_EMPLOYEE', 'DC_DOCTORS_FEE', 'DC_MEDICINES', 'DC_CONSUMABLES', 'DC_GOVT_FEES', 'DC_INSURANCE',
              'DC_MAINTENANCE', 'DC_UTILITIES', 'DC_RENTAL', 'DC_REFERRAL', 'DC_KITCHEN', 'DC_TRAVEL', 'DC_TRAINING', 'DC_OTHER'] -%}
{%- set ga = ['GA_EMPLOYEE', 'GA_PROFESSIONAL', 'GA_AUDIT', 'GA_COMMUNICATION', 'GA_POSTAGE', 'GA_SECURITY',
              'GA_GOVT_FEE', 'GA_TRAINING', 'GA_ECL', 'GA_MARKETING', 'GA_HO_CHARGES', 'GA_OTHER'] -%}
{%- set dc_parts = [('UNBUDGETED', 'Direct cost', 1)] -%}
{%- for c in dc %}{% do dc_parts.append((c, '', 1)) %}{% endfor -%}
{%- set ga_parts = [('UNBUDGETED', 'G&A', 1), ('UNBUDGETED', 'Selling and marketing', 1),
                    ('UNBUDGETED', 'Charges from head office', 1), ('UNBUDGETED', 'Not mapped expenses', 1)] -%}
{%- for c in ga %}{% do ga_parts.append((c, '', 1)) %}{% endfor -%}
{%- set formulas = [
    ('REV_SUB', [('REV_OP', '', 1), ('REV_IP', '', 1), ('REV_ER', '', 1), ('REV_UNALLOCATED', '', 1), ('UNBUDGETED', 'Revenue', 1)]),
    ('DIS_REJECTION', [('DIS_REJECTION_INS', '', 1), ('DIS_REJECTION_MOH', '', 1)]),
    ('DIS_SETTLEMENT', [('DIS_REJECTION', '', 1), ('DIS_EARLY_PAY', '', 1), ('DIS_VOLUME', '', 1), ('UNBUDGETED', 'Revenue discounts', 1)]),
    ('REV_NET', [('REV_SUB', '', 1), ('DIS_SETTLEMENT', '', -1)]),
    ('TOTAL_DC', dc_parts),
    ('TOTAL_GA', ga_parts),
    ('GROSS_PROFIT', [('REV_NET', '', 1), ('TOTAL_DC', '', -1)]),
    ('EBITDA', [('GROSS_PROFIT', '', 1), ('TOTAL_GA', '', -1), ('OTHER_INCOME', '', 1), ('UNBUDGETED', 'Other income', 1)]),
    ('NET_PROFIT', [('EBITDA', '', 1), ('DEPRECIATION', '', -1), ('FINANCE_COST', '', -1), ('ZAKAT', '', -1),
                    ('UNBUDGETED', 'Depreciation and amortisation', -1), ('UNBUDGETED', 'Finance cost', -1), ('UNBUDGETED', 'Zakat', -1)]),
    ('TOTAL_COMP_INCOME', [('NET_PROFIT', '', 1), ('OCI', '', 1), ('UNBUDGETED', 'OCI', 1)])
] -%}
{%- set expanded = {} -%}
{%- set rows = [] -%}
{%- for code, parts in formulas -%}
  {%- set acc = {} -%}
  {%- for comp, grp, w in parts -%}
    {%- if comp in expanded -%}
      {%- for k, v in expanded[comp].items() -%}{%- do acc.update({k: acc.get(k, 0) + v * w}) -%}{%- endfor -%}
    {%- else -%}
      {%- set k = comp ~ '|' ~ grp -%}
      {%- do acc.update({k: acc.get(k, 0) + w}) -%}
    {%- endif -%}
  {%- endfor -%}
  {%- do expanded.update({code: acc}) -%}
  {%- for k in acc | sort -%}
    {%- if acc[k] != 0 -%}
      {%- set kp = k.split('|') -%}
      {%- do rows.append("('" ~ code ~ "', '" ~ kp[0] ~ "', '" ~ kp[1] ~ "', " ~ acc[k] ~ ")") -%}
    {%- endif -%}
  {%- endfor -%}
{%- endfor -%}
select subtotal_code, component_code, component_group, weight
from values('subtotal_code String, component_code String, component_group String, weight Int8',
    {{ rows | join(',\n    ') }})
{%- endmacro %}
