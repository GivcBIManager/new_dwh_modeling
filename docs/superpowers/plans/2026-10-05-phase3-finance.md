# Phase 3 — Finance: General Ledger, Budget and Payables Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Fusion general ledger (journal lines, monthly balances), the income statement against budget, and payables in the hnh gold layer, on the group-wide Oracle FS mapping, with reconciliation to Fusion's own balances and to Oasis revenue.

**Architecture:** Fusion tables are staged as views through `hnh_fusion_source()` (source locally, `ref()` in the receiving project) read with `final`. Conformed dimensions carry the FS hierarchy (`dim_fs_line`), the account with its FS line, care type and budget code (`hnh_dim_gl_account`), periods, suppliers and budget lines. The journal fact feeds a dbt-derived monthly balance fact (opening and closing stored, posted and including-unposted views) and an income-statement fact where budget and actual meet on one grain with subtotals computed from one expanded formula macro. AP facts read Fusion AP directly. Rules are `hnh_` macros tested with literal inputs; multi-row rules are dbt unit tests with SQL fixtures.

**Tech Stack:** ClickHouse 26.5, dbt-core 1.11.12, dbt-clickhouse 1.9.8, Python 3.13 with `clickhouse_connect` and `openpyxl`.

**Spec:** `docs/superpowers/specs/2026-10-05-hnh-dwh-phase3-finance-design.md` (parent: `2026-10-01-hnh-dwh-gold-layer-design.md`)

**Prerequisite:** Phases 1, 2A, 2B and order fulfilment are on `main` and `python scripts/run_dbt.py build --select tag:hnh` passes. Work happens on branch `phase3-finance` (already created; the spec and the `map_fs_account` / `map_oasis_fs_account` loader entries are committed there, and both tables are loaded).

## Global Constraints

- All earlier-phase constraints apply: databases `stg` / `int` / `gold`; never write to `oasis`, `fusion`, `press_ganey`; models, macros and tests only under `hnh/` folders; macros prefixed `hnh_`; no packages, no seeds; `branch_id` / `branch_key` are `UInt8`; keys through `hnh_surrogate_key`; every model with a `left join` ends with `{{ hnh_settings() }}`; YAML uses the `tests:` key.
- Run dbt only through `python scripts/run_dbt.py <dbt args>` from the repository root; add `--no-partial-parse` when new YAML or unit tests are not picked up. Ad hoc reads through `scripts/ch_env.py` (`from ch_env import client`); never the machine-wide `CLICKHOUSE_PASSWORD`.
- Fusion tables are read only with `{{ hnh_fusion_source('<table>') }} final` (ReplacingMergeTree; the journal table holds 10.29M rows for 9.72M lines before merge).
- Amounts are Fusion **accounted** amounts in SAR, cast to `Float64`; `amount = debit − credit` (debit positive). Display signs are applied only through `dim_fs_line.display_sign` or the budget code's `natural_side`.
- Model names that exist in the receiving project's own Fusion models carry the `hnh_` prefix and an alias: `hnh_dim_gl_period` → `dim_gl_period`, `hnh_dim_gl_account` → `dim_gl_account`, `hnh_dim_supplier` → `dim_supplier`, `hnh_fact_gl_journal_line` → `fact_gl_journal_line`, `hnh_fact_ap_payment` → `fact_ap_payment`. Always `ref()` the `hnh_` name.
- Reference data lives in ClickHouse `default`, loaded by `scripts/load_reference_data.py`, which never overwrites a table that has rows; CSVs under `static_mappings/` and the spreadsheet are git-ignored and are never committed.
- Every fact has `_loaded_at` (`now()`), engine `MergeTree`, and an `order_by` starting with `branch_key`; sort-key columns must be non-Nullable.
- Fact dimension keys are never null (missing → `-1`, or `0` for `period_key` so the relationship test fails loudly); optional date keys use `hnh_date_key_in_range`.
- dbt unit tests live in `*_unit_tests.yml`, use `format: sql`, and mock every `ref()` of the model (only the columns the model reads).
- ClickHouse cautions met before: an alias that shadows a source column inside an aggregate raises error 184 (rename the intermediate); `x.*` after several joins can come out with qualified names (list columns); `final` is a keyword (never an alias); `union all` branches must have matching types (cast literals).

### Spec refinements made while planning

| Spec says | Plan does | Why |
|---|---|---|
| `int_gl_journal_line`, `int_gl_balance_monthly` | Not built; `fact_gl_balance_monthly` reads `hnh_fact_gl_journal_line` | The journal fact is already the clean grain; an intermediate copy of 9.7M rows adds nothing. |
| Journal branch from account segment 1 | Branch from the journal's ledger through `hnh_dim_branch.fusion_ledger_id` | Measured identical for all 9,722,782 lines; works even if an account is missing from `dim_gl_account`. |
| `intercompany_branch_key` `-1` for 000 | `Nullable(UInt8)` attribute, null for 000 | `branch_key` is `UInt8`; it is an attribute, not a relationship key. |
| `map_fs_line_order` for every level including line | Rows for type, element, category, caption; lines sort by their lowest natural account within the caption | 109 line rows would duplicate what the chart's numbering already gives. |
| Labels "capitalised consistently" | Trimmed, spaces collapsed, `Deprecition` → `Depreciation`; case kept | The Oracle text is already consistent; re-capitalising breaks VAT, PPE, ROU, SCR, ECL. |
| Test "every subtotal equals its formula" | Macro test of the expanded weights (Task 1) and `rec_income_statement_budget` (Task 10) | Subtotals are produced by one formula macro, so a per-row re-check is tautological; the file's own subtotals are the independent check. |
| Retained-earnings roll onto account 36101101 | Onto one synthetic account per branch (`hnh_prior_year_results_key`), FS line Retained earnings, `fs_mapping_source = 'prior-year roll'` | A ledger may have none or several 36101101 code combinations. |
| `dim_gl_period.month_date_key` (end date) | `end_date_key` plus `month_start` | Clearer for statements that fold adjustment periods into their quarter-end month. |
| AP period from the accounting date | `hnh_gl_period_key_for_date`: month m → period m + ⌊(m−1)/3⌋ | Calendar `Monthly 12 4` numbers months 1,2,3,5,6,7,9,…,15; a range join is not available. Relationship test catches drift. |
| Budget code assignment in the income-statement model | `hnh_dim_gl_account.budget_line_code` | Shown in SSAS too; one place for the precedence rule. |

## Review Focus

1. **A posting in a future period** (Abha has posted lines in October–December 2026; a January-2027 posting will follow): the balance grid extends to it, balance-sheet accounts carry their balance forward, income-statement accounts restart at 2027 and the branch's prior-year result appears once on the roll account. Pinned in Task 7 (`fact_gl_balance_monthly` unit test, period 202701).
2. **An account posted in January only**: February and March still have rows with the January closing balance (no gaps in the statement). Pinned in Task 7 (account 10, periods 202602–202603).
3. **A contractual discount (debit) on an outpatient revenue account**: it reduces REV_OP rather than adding to it, and the subtotals follow. Pinned in Task 8 (`fact_income_statement_monthly` unit test, accounts 1 and 2).
4. **Head Office**: its lines land on branch 100 (never Group 0), admins see branch 100, a non-admin without the grant does not. Pinned in Task 4 (`assert_sec_admins_see_head_office`, `assert_dim_branch_head_office`) and Task 6 (journal unit test, header 1).
5. **An account with no FS line** (Head Office loans, an unmapped expense): it stays on a Not mapped line of its type so totals balance; an unmapped expense is `UNBUDGETED` inside TOTAL_GA, so net profit still equals the statement. Pinned in Task 5 (`hnh_dim_gl_account` unit test, accounts 4 and 5) and Task 8 (UNBUDGETED row).

## File Structure

```
scripts/load_reference_data.py                    + map_fs_line_order, map_budget_fs_line, map_fusion_specialty_unified
scripts/draft_fusion_specialty_map.py             draft of specialty → unified department (keyword rules)
static_mappings/ (git-ignored)                    fs_line_order.csv, budget_fs_line_mapping.csv, fusion_specialty_unified.csv
hnh_dwh/dbt_project.yml                           + vars hnh_fusion_as_ref, hnh_head_office_*, hnh_fusion_oasis_feed_source
hnh_dwh/macros/hnh/hnh_core.sql                   + hnh_fusion_source
hnh_dwh/macros/hnh/hnh_rules_finance.sql          labels, FS key, care type, signs, balance side, period key, ageing, subtotal weights
hnh_dwh/tests/hnh/assert_hnh_finance_macros.sql
hnh_dwh/tests/hnh/assert_dim_branch_head_office.sql, assert_sec_admins_see_head_office.sql
hnh_dwh/tests/hnh/assert_fact_gl_journal_line_matches_staging.sql, assert_gl_trial_balance_zero.sql,
                  assert_finance_facts_have_branch.sql
hnh_dwh/tests/hnh/warn_unmapped_fs_accounts.sql, warn_unposted_gl_batches.sql, warn_unbalanced_journals.sql,
                  warn_intercompany_mismatch.sql, warn_revenue_without_location.sql, warn_gl_revenue_gap.sql,
                  warn_ap_without_supplier.sql, warn_fs_levels_without_order.sql
hnh_dwh/models/hnh/staging/fusion/                _fusion__sources.yml, _fusion__models.yml, stg_fusion__*.sql (11)
hnh_dwh/models/hnh/staging/reference/             + stg_ref__fs_account, stg_ref__oasis_fs_account, stg_ref__fs_line_order,
                                                    stg_ref__budget_fs_line, stg_ref__fusion_specialty_unified,
                                                    stg_ref__income_statement_budget
hnh_dwh/models/hnh/marts/conformed/               hnh_dim_branch, sec_user_access (changed); hnh_dim_gl_period, hnh_dim_supplier,
                                                    dim_fs_line, dim_budget_line, hnh_dim_gl_account; _finance_conformed_unit_tests.yml
hnh_dwh/models/hnh/marts/finance/                 _finance_marts__models.yml, _finance_marts_unit_tests.yml, hnh_fact_gl_journal_line,
                                                    fact_gl_balance_monthly, fact_budget_monthly, fact_income_statement_monthly,
                                                    fact_ap_invoice_line, hnh_fact_ap_payment, fact_ap_open_item
hnh_dwh/models/hnh/marts/reconciliation/          + rec_gl_balance_monthly, rec_gl_revenue_monthly, rec_income_statement_budget
docs/reconciliation_phase3.md, docs/receiving_project_config.md
```

---

### Task 1: Finance macros and the Fusion source switch

**Files:**
- Modify: `hnh_dwh/macros/hnh/hnh_core.sql` (append), `hnh_dwh/dbt_project.yml` (vars)
- Create: `hnh_dwh/macros/hnh/hnh_rules_finance.sql`, `hnh_dwh/tests/hnh/assert_hnh_finance_macros.sql`

**Interfaces:**
- Produces (all macros return SQL expressions unless noted):
  - `hnh_fusion_source(table_name)` → relation (`source('fusion', t)` or `ref(t)` when `var('hnh_fusion_as_ref')`)
  - `hnh_fs_label(col)` → String; `hnh_fs_line_key(type, element, category, caption, line)` → Int64
  - `hnh_gl_care_type(location_code)` → 'OP' | 'IP' | 'ER' | 'Other' | 'Unallocated'
  - `hnh_fs_display_sign(element)` → Int8; `hnh_gl_balance_side(fs_type, account_type)` → 'BS' | 'IS'
  - `hnh_not_mapped_element(account_type)` → String; `hnh_gl_period_key_for_date(d)` → Int32
  - `hnh_budget_natural_side(code, statement_group)` → 'credit' | 'debit'; `hnh_ageing_bucket(days)` → String
  - `hnh_prior_year_results_key(branch_key)` → Int64
  - `hnh_budget_subtotal_weights()` → a full `select subtotal_code, component_code, component_group, weight from values(...)` statement
  - vars `hnh_fusion_as_ref` (false), `hnh_head_office_fusion_branch_code` (101), `hnh_head_office_ledger_id` (300000005003375), `hnh_fusion_oasis_feed_source` ('300000007046804')

- [ ] **Step 1: Write the failing macro test**

`hnh_dwh/tests/hnh/assert_hnh_finance_macros.sql`:

```sql
{% set null_s = "cast(null as Nullable(String))" %}

select 'fs label wrong' as failure
where not ifNull({{ hnh_fs_label("'  Deprecition   and Amortization '") }} = 'Depreciation and Amortization', 0)
   or not ifNull({{ hnh_fs_label("'Trade receivables, net'") }} = 'Trade receivables, net', 0)

union all
select 'fs line key wrong'
where {{ hnh_fs_line_key("'BS'", "'Assets'", "'Current Assets'", "'Cash and bank balances'", "'Bank'") }}
   != {{ hnh_fs_line_key("'bs'", "' assets '", "'CURRENT ASSETS'", "'Cash and  bank balances'", "'bank'") }}
   or {{ hnh_fs_line_key("'BS'", "'Assets'", "'Current Assets'", "'Cash and bank balances'", "'Bank'") }}
   = {{ hnh_fs_line_key("'BS'", "'Assets'", "'Current Assets'", "'Cash and bank balances'", "'Cash'") }}

union all
select 'gl care type wrong'
where not ({{ hnh_gl_care_type("'01'") }} = 'OP' and {{ hnh_gl_care_type("'04'") }} = 'OP' and {{ hnh_gl_care_type("'07'") }} = 'OP'
       and {{ hnh_gl_care_type("'08'") }} = 'OP' and {{ hnh_gl_care_type("'09'") }} = 'OP' and {{ hnh_gl_care_type("'10'") }} = 'OP'
       and {{ hnh_gl_care_type("'11'") }} = 'OP' and {{ hnh_gl_care_type("'02'") }} = 'IP' and {{ hnh_gl_care_type("'03'") }} = 'IP'
       and {{ hnh_gl_care_type("'05'") }} = 'IP' and {{ hnh_gl_care_type("'06'") }} = 'ER' and {{ hnh_gl_care_type("'12'") }} = 'Other'
       and {{ hnh_gl_care_type("'13'") }} = 'Other' and {{ hnh_gl_care_type("'00'") }} = 'Unallocated'
       and {{ hnh_gl_care_type("'99'") }} = 'Unallocated' and {{ hnh_gl_care_type(null_s) }} = 'Unallocated')

union all
select 'display sign wrong'
where not ({{ hnh_fs_display_sign("'Revenue'") }} = -1 and {{ hnh_fs_display_sign("'Other income'") }} = -1
       and {{ hnh_fs_display_sign("'Liabilities'") }} = -1 and {{ hnh_fs_display_sign("'Equity'") }} = -1
       and {{ hnh_fs_display_sign("'Assets'") }} = 1 and {{ hnh_fs_display_sign("'Expenses'") }} = 1)

union all
select 'balance side wrong'
where not ({{ hnh_gl_balance_side("'IS'", "'L'") }} = 'IS' and {{ hnh_gl_balance_side(null_s, "'A'") }} = 'BS'
       and {{ hnh_gl_balance_side(null_s, "'L'") }} = 'BS' and {{ hnh_gl_balance_side(null_s, "'O'") }} = 'BS'
       and {{ hnh_gl_balance_side(null_s, "'R'") }} = 'IS' and {{ hnh_gl_balance_side(null_s, "'E'") }} = 'IS'
       and {{ hnh_gl_balance_side(null_s, null_s) }} = 'IS')

union all
select 'not mapped element wrong'
where not ({{ hnh_not_mapped_element("'A'") }} = 'Assets' and {{ hnh_not_mapped_element("'L'") }} = 'Liabilities'
       and {{ hnh_not_mapped_element("'O'") }} = 'Equity' and {{ hnh_not_mapped_element("'R'") }} = 'Revenue'
       and {{ hnh_not_mapped_element("'E'") }} = 'Expenses' and {{ hnh_not_mapped_element(null_s) }} = 'Expenses')

union all
select 'period key for date wrong'
where not ({{ hnh_gl_period_key_for_date("toDate('2026-01-15')") }} = 202601 and {{ hnh_gl_period_key_for_date("toDate('2026-03-31')") }} = 202603
       and {{ hnh_gl_period_key_for_date("toDate('2026-04-01')") }} = 202605 and {{ hnh_gl_period_key_for_date("toDate('2026-06-30')") }} = 202607
       and {{ hnh_gl_period_key_for_date("toDate('2026-07-01')") }} = 202609 and {{ hnh_gl_period_key_for_date("toDate('2026-12-31')") }} = 202615)

union all
select 'natural side wrong'
where not ({{ hnh_budget_natural_side("'REV_OP'", "''") }} = 'credit' and {{ hnh_budget_natural_side("'REV_UNALLOCATED'", "''") }} = 'credit'
       and {{ hnh_budget_natural_side("'OTHER_INCOME'", "''") }} = 'credit' and {{ hnh_budget_natural_side("'OCI'", "''") }} = 'credit'
       and {{ hnh_budget_natural_side("'DC_EMPLOYEE'", "''") }} = 'debit' and {{ hnh_budget_natural_side("'DIS_EARLY_PAY'", "''") }} = 'debit'
       and {{ hnh_budget_natural_side("'UNBUDGETED'", "'Other income'") }} = 'credit'
       and {{ hnh_budget_natural_side("'UNBUDGETED'", "'Revenue'") }} = 'credit'
       and {{ hnh_budget_natural_side("'UNBUDGETED'", "'Direct cost'") }} = 'debit')

union all
select 'ageing bucket wrong'
where not ({{ hnh_ageing_bucket('-5') }} = 'Not due' and {{ hnh_ageing_bucket('0') }} = 'Not due' and {{ hnh_ageing_bucket('1') }} = '1-30'
       and {{ hnh_ageing_bucket('30') }} = '1-30' and {{ hnh_ageing_bucket('31') }} = '31-60' and {{ hnh_ageing_bucket('61') }} = '61-90'
       and {{ hnh_ageing_bucket('91') }} = '91-180' and {{ hnh_ageing_bucket('181') }} = 'Over 180')

union all
select 'prior year results key wrong'
where {{ hnh_prior_year_results_key('toUInt8(6)') }} != toInt64(8342949216454285929)

union all
select 'subtotal weights wrong'
where (select count() from ({{ hnh_budget_subtotal_weights() }})
       where (subtotal_code, component_code, component_group, weight) in (
           ('EBITDA', 'DC_EMPLOYEE', '', -1), ('EBITDA', 'OTHER_INCOME', '', 1), ('EBITDA', 'UNBUDGETED', 'Other income', 1),
           ('EBITDA', 'DIS_EARLY_PAY', '', -1), ('EBITDA', 'REV_OP', '', 1), ('NET_PROFIT', 'DEPRECIATION', '', -1),
           ('DIS_SETTLEMENT', 'DIS_REJECTION_INS', '', 1), ('TOTAL_GA', 'UNBUDGETED', 'Not mapped expenses', 1))) != 8
   or (select count() from ({{ hnh_budget_subtotal_weights() }})
       where component_code in ('REV_SUB', 'DIS_REJECTION', 'DIS_SETTLEMENT', 'REV_NET', 'TOTAL_DC', 'TOTAL_GA',
                                'GROSS_PROFIT', 'EBITDA', 'NET_PROFIT', 'TOTAL_COMP_INCOME')) != 0
   or (select uniqExact(subtotal_code) from ({{ hnh_budget_subtotal_weights() }})) != 10
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python scripts/run_dbt.py test --select assert_hnh_finance_macros`
Expected: compilation error — `'hnh_fs_label' is undefined`.

- [ ] **Step 3: Add the vars and the source switch**

In `hnh_dwh/dbt_project.yml` under `vars:` add:

```yaml
  hnh_fusion_as_ref: false
  hnh_head_office_fusion_branch_code: 101
  hnh_head_office_ledger_id: 300000005003375
  hnh_fusion_oasis_feed_source: "300000007046804"
```

Append to `hnh_dwh/macros/hnh/hnh_core.sql`:

```sql
{# Read a Fusion table. In this project it is a source; in the receiving project the fusion database is built by
   dbt models of the same names, so set var hnh_fusion_as_ref: true there. #}
{% macro hnh_fusion_source(table_name) -%}
{%- if var('hnh_fusion_as_ref', false) -%}{{ ref(table_name) }}{%- else -%}{{ source('fusion', table_name) }}{%- endif -%}
{%- endmacro %}
```

- [ ] **Step 4: Write the finance macros**

`hnh_dwh/macros/hnh/hnh_rules_finance.sql`:

```sql
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
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `python scripts/run_dbt.py test --select assert_hnh_finance_macros`
Expected: `PASS=1`. If the prior-year key differs, the surrogate-key macro changed: recompute with `select {{ hnh_prior_year_results_key('toUInt8(6)') }}` and stop — the Task 7 unit test uses the same literal.

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/macros/hnh/hnh_rules_finance.sql hnh_dwh/macros/hnh/hnh_core.sql hnh_dwh/dbt_project.yml hnh_dwh/tests/hnh/assert_hnh_finance_macros.sql
git commit -m "Add finance rule macros and the Fusion source switch"
```

---

### Task 2: Reference data for the statements

**Files:**
- Create: `scripts/draft_fusion_specialty_map.py`; git-ignored data `static_mappings/fs_line_order.csv`, `static_mappings/budget_fs_line_mapping.csv`, `static_mappings/fusion_specialty_unified.csv`
- Modify: `scripts/load_reference_data.py`, `hnh_dwh/models/hnh/staging/reference/_reference__sources.yml`, `_reference__models.yml`
- Create: `hnh_dwh/models/hnh/staging/reference/stg_ref__fs_account.sql`, `stg_ref__oasis_fs_account.sql`, `stg_ref__fs_line_order.sql`, `stg_ref__budget_fs_line.sql`, `stg_ref__fusion_specialty_unified.sql`, `stg_ref__income_statement_budget.sql`

**Interfaces:**
- Consumes: `hnh_fs_label`, `hnh_str` (Task 1, core).
- Produces:
  - `stg_ref__fs_account(natural_account UInt32, fs_type, fs_element, fs_category, fs_caption, fs_line, mapped_in)` — labels through `hnh_fs_label`
  - `stg_ref__oasis_fs_account(branch_id UInt8, code String, fs_type, fs_element, fs_category, fs_caption, fs_line)`
  - `stg_ref__fs_line_order(level, value_lower, sort_order UInt16, statement_group Nullable(String))`
  - `stg_ref__budget_fs_line(line_item_code, match_level, match_value_lower, care_type Nullable(String))`
  - `stg_ref__fusion_specialty_unified(specialty_code String, specialty_name, unified_department Nullable(String))`
  - `stg_ref__income_statement_budget(branch_id UInt8, fiscal_year UInt16, scenario, line_item_code, month_1 … month_12 Float64, is_latest UInt8)`

- [ ] **Step 1: Write the failing staging tests**

Append to the `reference` source `tables:` in `_reference__sources.yml`:

```yaml
      - name: map_fs_account
      - name: map_oasis_fs_account
      - name: map_fs_line_order
      - name: map_budget_fs_line
      - name: map_fusion_specialty_unified
      - name: income_statement_budget
```

Append to `_reference__models.yml`:

```yaml
  - name: stg_ref__fs_account
    columns:
      - name: natural_account
        tests: [unique, not_null]
      - name: fs_type
        tests:
          - accepted_values:
              values: ['BS', 'IS']
  - name: stg_ref__oasis_fs_account
    tests:
      - hnh_unique_combination:
          columns: [branch_id, code]
          config: {severity: warn}
  - name: stg_ref__fs_line_order
    tests:
      - hnh_unique_combination:
          columns: [level, value_lower]
    columns:
      - name: level
        tests:
          - accepted_values:
              values: ['type', 'element', 'category', 'caption']
      - name: statement_group
        tests:
          - accepted_values:
              values: ['Balance sheet', 'Revenue', 'Revenue discounts', 'Direct cost', 'G&A', 'Selling and marketing',
                       'Charges from head office', 'Other income', 'Depreciation and amortisation', 'Finance cost', 'Zakat', 'OCI']
  - name: stg_ref__budget_fs_line
    tests:
      - hnh_unique_combination:
          columns: [match_level, match_value_lower, care_type]
    columns:
      - name: match_level
        tests:
          - accepted_values:
              values: ['account', 'line', 'caption', 'category']
  - name: stg_ref__fusion_specialty_unified
    columns:
      - name: specialty_code
        tests: [unique, not_null]
  - name: stg_ref__income_statement_budget
    tests:
      - hnh_unique_combination:
          columns: [branch_id, fiscal_year, scenario, line_item_code, id]
```

Run: `python scripts/run_dbt.py build --select stg_ref__fs_account stg_ref__oasis_fs_account stg_ref__fs_line_order stg_ref__budget_fs_line stg_ref__fusion_specialty_unified stg_ref__income_statement_budget`
Expected: FAIL — models do not exist.

- [ ] **Step 2: Write the two drafted mapping files**

`static_mappings/fs_line_order.csv` (labels as `hnh_fs_label` shows them):

```csv
LEVEL,VALUE,SORT_ORDER,STATEMENT_GROUP
type,BS,1,
type,IS,2,
element,Assets,1,
element,Liabilities,2,
element,Equity,3,
element,Revenue,4,
element,Expenses,5,
element,Other income,6,
category,Current Assets,1,Balance sheet
category,Non Current Assets,2,Balance sheet
category,Current Liabilities,3,Balance sheet
category,Non Current Liabilities,4,Balance sheet
category,Equity,5,Balance sheet
category,Revenue,10,Revenue
category,Revenue - Discounts,11,Revenue discounts
category,Direct Cost,12,Direct cost
category,General and administrative expenses,13,G&A
category,Selling and Marketing expenses,14,Selling and marketing
category,Charges from head office,15,Charges from head office
category,"Other income, net",16,Other income
category,Depreciation and Amortization,17,Depreciation and amortisation
category,Finance Cost,18,Finance cost
category,Zakat,19,Zakat
caption,Cash and bank balances,1,
caption,"Trade receivables, net",2,
caption,"Inventories, net",3,
caption,Prepaid expenses and other assets,4,
caption,Due from related parties,5,
caption,Due from / ( Due to) Branch,6,
caption,PPE Cost,10,
caption,PPE Accm Depreciation,11,
caption,Right of use - Asset,12,
caption,Work In progress,13,
caption,Intangible assets,14,
caption,Trade payables,20,
caption,Accrued expenses and other liabilities,21,
caption,Due to related parties,22,
caption,Zakat payable,23,
caption,Lease liability,30,
caption,End-of-service indemnities,31,
caption,Additional Capital Contributions,40,
caption,Retained earnings,41,
caption,Revenue Cash,50,
caption,Revenue Insurance Companies,51,
caption,"Revenue Government, Embassies",52,
caption,Revenue Regular Companies,53,
caption,Revenue SCR Others,54,
caption,Revenue - Contractual Discounts,60,
caption,Revenue - Settlement Discount,61,
caption,Employee Costs,70,
caption,Doctors Fee and Commission,71,
caption,Cost of Medicines,72,
caption,Employee Govt Fees,73,
caption,Insurance Expenses,74,
caption,Maintenance Expense,75,
caption,Utilities Expenses,76,
caption,Rental Cost,77,
caption,Referral Cost,78,
caption,Kitchen Expenses,79,
caption,Travelling Expenses,80,
caption,Staff training and recruitments,81,
caption,Other Direct expenses,82,
caption,Employee Cost,90,
caption,General and administrative expenses,91,
caption,Selling and Marketing expenses,100,
caption,Charges from head office,110,
caption,"Other income, net",120,
caption,Depreciation Expense,130,
caption,Depreciation on ROU,131,
caption,Amortization Expense,132,
caption,Finance Cost,140,
caption,Zakat,150,
```

`static_mappings/budget_fs_line_mapping.csv` (most specific match wins: account, line, caption, category; revenue codes also require the account's care type; contractual discounts reduce care-type revenue, spec O-P3-7; DC_CONSUMABLES has no Oracle caption, O-P3-8):

```csv
LINE_ITEM_CODE,MATCH_LEVEL,MATCH_VALUE,CARE_TYPE
REV_OP,category,Revenue,OP
REV_OP,caption,Revenue - Contractual Discounts,OP
REV_IP,category,Revenue,IP
REV_IP,caption,Revenue - Contractual Discounts,IP
REV_ER,category,Revenue,ER
REV_ER,caption,Revenue - Contractual Discounts,ER
REV_UNALLOCATED,category,Revenue,Unallocated
REV_UNALLOCATED,category,Revenue,Other
REV_UNALLOCATED,caption,Revenue - Contractual Discounts,Unallocated
REV_UNALLOCATED,caption,Revenue - Contractual Discounts,Other
DIS_REJECTION_INS,account,41504101,
DIS_REJECTION_MOH,account,41504102,
DIS_EARLY_PAY,line,Early Payment Discount,
DIS_VOLUME,line,Volume Discount,
DC_EMPLOYEE,caption,Employee Costs,
DC_DOCTORS_FEE,caption,Doctors Fee and Commission,
DC_MEDICINES,caption,Cost of Medicines,
DC_GOVT_FEES,caption,Employee Govt Fees,
DC_INSURANCE,caption,Insurance Expenses,
DC_MAINTENANCE,caption,Maintenance Expense,
DC_UTILITIES,caption,Utilities Expenses,
DC_RENTAL,caption,Rental Cost,
DC_REFERRAL,caption,Referral Cost,
DC_KITCHEN,caption,Kitchen Expenses,
DC_TRAVEL,caption,Travelling Expenses,
DC_TRAINING,caption,Staff training and recruitments,
DC_OTHER,caption,Other Direct expenses,
GA_EMPLOYEE,caption,Employee Cost,
GA_AUDIT,line,Audit fee,
GA_COMMUNICATION,line,Communication Expense,
GA_ECL,line,Expected credit loss,
GA_GOVT_FEE,line,Government Fee,
GA_OTHER,line,Other indirect Expenses,
GA_POSTAGE,line,Postage printing and stationary,
GA_PROFESSIONAL,line,Professional Fee and subscription,
GA_SECURITY,line,Security and cleaning Expenses,
GA_TRAINING,line,Staff training and recruitment,
GA_MARKETING,category,Selling and Marketing expenses,
GA_HO_CHARGES,category,Charges from head office,
DEPRECIATION,category,Depreciation and Amortization,
FINANCE_COST,category,Finance Cost,
ZAKAT,category,Zakat,
OTHER_INCOME,category,"Other income, net",
```

- [ ] **Step 3: Write the specialty draft script and run it**

`scripts/draft_fusion_specialty_map.py`:

```python
"""Draft static_mappings/fusion_specialty_unified.csv: Fusion GL specialty (COA segment 3) to unified department.

Keyword rules, first match wins, on the lower-cased specialty name. Values without a match stay blank (Unknown in
gold) for the BI manager to complete. Every proposed value must exist in default.map_unified_department_v2.

Usage:  python scripts/draft_fusion_specialty_map.py
"""
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ch_env import client  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "static_mappings" / "fusion_specialty_unified.csv"

RULES = [
    (r"nicu|picu|neonat|nursery", "NICU/PICU"),
    (r"\bicu\b|critical care|\bhdu\b|high dependency|\bccu\b|step-down", "ICU"),
    (r"emergency", "EMERGENCY ROOM"),
    (r"\bhome\b", "HOME CARE"),
    (r"maxillofacial", "MAXILOFACIAL"),
    (r"dent|orthodont|periodont|prosthodont|endodont|implant", "DENTAL"),
    (r"interventional radiology", "INTERVENTIONAL RADIOLOGY"),
    (r"cardiothoracic", "CARDIOTHORACIC"),
    (r"pediatric|paediatric", "PAEDIATRIC"),
    (r"cardio|echocardio|stress testing|holter|\bcath\b", "CARDIOLOGY"),
    (r"vascular", "VASCULAR SURGERY"),
    (r"neurosurg", "NEUROSURGERY"),
    (r"neuro|stroke|epilep|\beeg\b|\bemg\b|evoked", "NEUROLOGY"),
    (r"bariatric", "BARIATRIC"),
    (r"plastic", "PLASTIC SURGERY"),
    (r"orthop|trauma", "ORTHOPEDIC"),
    (r"urolog|cystoscopy|androl", "UROLOGY"),
    (r"^ent$", "ENT"),
    (r"ophthalm", "OPTHALMOLOGY"),
    (r"oncolog|palliative", "ONCOLOGY"),
    (r"labor|delivery|maternity", "DELIVERY"),
    (r"obstetric|gyn|maternal|ivf|reproductive|women", "OBSTETRICS & GYNA"),
    (r"gastro|endoscopy", "GIT"),
    (r"pulmon|respiratory|bronchoscopy|sleep", "PULMONOLGY"),
    (r"nephrol|dialysis", "NEPHROLOGY"),
    (r"endocrin", "ENDOCRINOLOGY"),
    (r"rheumat", "RHEUMATOLOGY"),
    (r"infectious|infection control", "INFECTIOUS DISEASES"),
    (r"allergy", "ALLERGY & IMMUNOLOGY"),
    (r"blood bank", "BLOOD BANK"),
    (r"hematology", "HEMATOLOGY"),
    (r"radiolog|imaging|x-ray|\bct\b|nuclear", "RADIOLOGY"),
    (r"laborator|patholog|chemistry|microbiology|serology|molecular", "LABORATORY"),
    (r"pharmac|narcotic|iv room|drug warehouse", "PHARMACY"),
    (r"\bfood\b", "CAFETERIA"),
    (r"nutrition|dietet", "DIETITIAN"),
    (r"physiotherapy|rehabilitation|occupational therapy|speech", "PHYSIOTHERAPY"),
    (r"psychiat|psycholog|behavio|addiction|mental", "PSYCHIATRY"),
    (r"dermatolog|laser", "DERMATOLOGY"),
    (r"family|preventive|occupational health|geriatric", "FAMILY MED"),
    (r"long.?stay", "LONG STAY"),
    (r"anesth|\bpain\b|sedation", "ANATHESIA / PAIN MANAGEMENT"),
    (r"general surgery|surgical services|operating room|^or$", "GEN. SURGERY"),
    (r"internal medicine|medicine services", "INTERNAL MEDICINE"),
    (r"audiolog", "AUDIOLOGY DEPT"),
    (r"\bopd\b|outpatient", "OPD SERVICES"),
    (r"inpatient|\bward\b", "INPATIENTS SERVICES"),
]


def main():
    c = client()
    known = {r[0] for r in c.query("select distinct UNIFIED_DEPARTMENT from default.map_unified_department_v2").result_rows}
    for _, value in RULES:
        if value not in known:
            raise SystemExit(f"rule target not in map_unified_department_v2: {value}")
    rows = c.query(
        "select segment_value, ifNull(segment_value_description, '') from fusion.dim_coa_segment_value final "
        "where segment_column_name = 'SEGMENT3' order by segment_value"
    ).result_rows
    out, mapped = [], 0
    for code, name in rows:
        text = " ".join(name.lower().split())
        target = next((v for pattern, v in RULES if re.search(pattern, text)), "")
        mapped += bool(target)
        out.append((code, name.strip(), target))
    with open(OUT, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["SPECIALTY_CODE", "SPECIALTY_NAME", "UNIFIED_DEPARTMENT"])
        w.writerows(out)
    print(f"{len(out)} specialties, {mapped} with a proposed unified department -> {OUT}")


if __name__ == "__main__":
    sys.exit(main())
```

Run: `python scripts/draft_fusion_specialty_map.py`
Expected: `324 specialties, <n> with a proposed unified department` with n between 150 and 230 (administrative departments stay blank).

- [ ] **Step 4: Add the loader entries and load**

In `scripts/load_reference_data.py`, add to `SMALL_TABLES` (after `map_oasis_fs_account`):

```python
    # FS presentation order and the statement group of each income-statement category (drafted 2026-10-05).
    "map_fs_line_order": (
        "fs_line_order.csv",
        [("LEVEL", "LowCardinality(String)", s), ("VALUE", "String", s), ("SORT_ORDER", "UInt16", i),
         ("STATEMENT_GROUP", "String", s)],
        "(LEVEL, VALUE)",
    ),
    # Budget line code -> FS position (account, line, caption or category), revenue codes also by care type.
    "map_budget_fs_line": (
        "budget_fs_line_mapping.csv",
        [("LINE_ITEM_CODE", "LowCardinality(String)", s), ("MATCH_LEVEL", "LowCardinality(String)", s),
         ("MATCH_VALUE", "String", s), ("CARE_TYPE", "String", s)],
        "(LINE_ITEM_CODE, MATCH_LEVEL, MATCH_VALUE, CARE_TYPE)",
    ),
    # Fusion GL specialty (COA segment 3) -> unified department; drafted by scripts/draft_fusion_specialty_map.py.
    "map_fusion_specialty_unified": (
        "fusion_specialty_unified.csv",
        [("SPECIALTY_CODE", "String", s), ("SPECIALTY_NAME", "String", s), ("UNIFIED_DEPARTMENT", "String", s)],
        "SPECIALTY_CODE",
    ),
```

Run: `cd scripts && python load_reference_data.py --only map_fs_line_order map_budget_fs_line map_fusion_specialty_unified`
Expected: `loaded 72`, `loaded 43`, `loaded 324` (row counts of the three files).

- [ ] **Step 5: Write the six staging views**

`stg_ref__fs_account.sql`:

```sql
select
    toUInt32(ORACLE_CODE)             as natural_account,
    upper({{ hnh_fs_label('FS_TYPE') }}) as fs_type,
    {{ hnh_fs_label('FS_ELEMENT') }}  as fs_element,
    {{ hnh_fs_label('FS_CATEGORY') }} as fs_category,
    {{ hnh_fs_label('FS_CAPTION') }}  as fs_caption,
    {{ hnh_fs_label('FS_LINE') }}     as fs_line,
    MAPPED_IN                         as mapped_in
from {{ source('reference', 'map_fs_account') }}
```

`stg_ref__oasis_fs_account.sql`:

```sql
select
    toUInt8(BRANCH_ID)                as branch_id,
    trimBoth(CODE)                    as code,
    upper({{ hnh_fs_label('TYPE') }}) as fs_type,
    {{ hnh_fs_label('FS_ELEMENT') }}  as fs_element,
    {{ hnh_fs_label('FS_CATEGORY') }} as fs_category,
    {{ hnh_fs_label('FS_CAPTION') }}  as fs_caption,
    {{ hnh_fs_label('FS_LINE') }}     as fs_line
from {{ source('reference', 'map_oasis_fs_account') }}
```

`stg_ref__fs_line_order.sql`:

```sql
select
    lower(trimBoth(LEVEL))                    as level,
    lower({{ hnh_fs_label('VALUE') }})        as value_lower,
    toUInt16(SORT_ORDER)                      as sort_order,
    {{ hnh_str('STATEMENT_GROUP') }}          as statement_group
from {{ source('reference', 'map_fs_line_order') }}
```

`stg_ref__budget_fs_line.sql`:

```sql
select
    upper(trimBoth(LINE_ITEM_CODE))           as line_item_code,
    lower(trimBoth(MATCH_LEVEL))              as match_level,
    lower({{ hnh_fs_label('MATCH_VALUE') }})  as match_value_lower,
    {{ hnh_str('CARE_TYPE') }}                as care_type
from {{ source('reference', 'map_budget_fs_line') }}
```

`stg_ref__fusion_specialty_unified.sql`:

```sql
select
    trimBoth(SPECIALTY_CODE)                  as specialty_code,
    {{ hnh_str('SPECIALTY_NAME') }}           as specialty_name,
    {{ hnh_str('UNIFIED_DEPARTMENT') }}       as unified_department
from {{ source('reference', 'map_fusion_specialty_unified') }}
```

`stg_ref__income_statement_budget.sql`:

```sql
select
    toUInt32(id)                    as id,
    toUInt8(branch_id)              as branch_id,
    toUInt16(fiscal_year)           as fiscal_year,
    toString(scenario)              as scenario,
    upper(toString(line_item_code)) as line_item_code,
    {% for m in range(1, 13) %}toFloat64(month_{{ m }}) as month_{{ m }},
    {% endfor %}toUInt8(is_latest)  as is_latest
from {{ source('reference', 'income_statement_budget') }}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `python scripts/run_dbt.py build --no-partial-parse --select stg_ref__fs_account stg_ref__oasis_fs_account stg_ref__fs_line_order stg_ref__budget_fs_line stg_ref__fusion_specialty_unified stg_ref__income_statement_budget`
Expected: all PASS, one WARN (`stg_ref__oasis_fs_account` duplicate key: branch 5 code `1`, spec O-P3-5).

- [ ] **Step 7: Commit**

```bash
git add scripts/load_reference_data.py scripts/draft_fusion_specialty_map.py hnh_dwh/models/hnh/staging/reference/
git commit -m "Load FS order, budget-to-FS and specialty mappings and stage the finance reference tables"
```

---

### Task 3: Fusion staging

**Files:**
- Create: `hnh_dwh/models/hnh/staging/fusion/_fusion__sources.yml`, `_fusion__models.yml`, and `stg_fusion__gl_journal_lines.sql`, `stg_fusion__gl_accounts.sql`, `stg_fusion__coa_segment_values.sql`, `stg_fusion__gl_periods.sql`, `stg_fusion__gl_balances.sql`, `stg_fusion__ap_invoice_distributions.sql`, `stg_fusion__ap_payments.sql`, `stg_fusion__ap_payment_schedules.sql`, `stg_fusion__suppliers.sql`, `stg_fusion__business_units.sql`

**Interfaces:**
- Consumes: `hnh_fusion_source`, `hnh_str`, `hnh_code`, `hnh_flag`.
- Produces:
  - `stg_fusion__gl_journal_lines(je_header_id, je_line_num, je_batch_id, journal_name, doc_sequence_value, ledger_id, code_combination_id, period_name, accounting_date Nullable(Date), posted_date Nullable(Date), je_source, je_category, actual_flag, header_status, debit Float64, credit Float64, line_description)`
  - `stg_fusion__gl_accounts(code_combination_id, branch_segment Nullable(Int64), natural_account Nullable(UInt32), specialty_code, service_location_code, service_group_code, intercompany_segment, account_type, is_enabled, is_summary)`
  - `stg_fusion__coa_segment_values(segment_column_name, segment_value, segment_value_name)`
  - `stg_fusion__gl_periods(period_name, period_year, period_num, quarter_num, start_date Date, end_date Date, is_adjustment)`
  - `stg_fusion__gl_balances(ledger_id, code_combination_id, period_name, actual_flag, currency_balance_type, period_debit, period_credit, begin_debit, begin_credit)`
  - `stg_fusion__ap_invoice_distributions(invoice_distribution_id, invoice_id, invoice_num, line_type, po_distribution_id, is_posted, is_cancelled, is_reversal, invoice_type_code, vendor_id, vendor_site_id, ledger_id, code_combination_id, invoice_date, accounting_date, amount)`
  - `stg_fusion__ap_payments(invoice_payment_id, invoice_id, payment_num, check_number, payment_method, payment_status, is_posted, vendor_id, vendor_site_id, ledger_id, bank_account_id, payment_date, amount)`
  - `stg_fusion__ap_payment_schedules(invoice_id, payment_num, vendor_id, vendor_site_id, invoice_num, invoice_type_code, approval_status, payment_status_flag, is_on_hold, invoice_date, cancelled_date, business_unit_id, due_date, currency_code, gross_amount, amount_remaining)`
  - `stg_fusion__suppliers(vendor_id, vendor_site_id, supplier_number, supplier_name, supplier_type, supplier_status, site_code, business_unit_id, country)`
  - `stg_fusion__business_units(business_unit_id, business_unit_name, primary_ledger_id)`

- [ ] **Step 1: Declare the source and write the failing tests**

`_fusion__sources.yml`:

```yaml
version: 2

sources:
  - name: fusion
    schema: fusion
    description: >
      Oracle Fusion star (dim_, fact_), ReplacingMergeTree on last_update_date. In the receiving project these are dbt
      models of the same names (set var hnh_fusion_as_ref: true). last_update_date is the Fusion record time, not a load
      time, so no freshness is declared.
    tables:
      - name: fact_gl_journal_line
      - name: dim_gl_account
      - name: dim_coa_segment_value
      - name: dim_gl_period
      - name: fact_gl_balance
      - name: fact_ap_invoice_distribution
      - name: fact_ap_payment
      - name: fact_ap_payment_schedule
      - name: dim_supplier
      - name: dim_business_unit
```

`_fusion__models.yml`:

```yaml
version: 2

models:
  - name: stg_fusion__gl_journal_lines
    tests:
      - hnh_unique_combination:
          columns: [je_header_id, je_line_num]
  - name: stg_fusion__gl_accounts
    columns:
      - name: code_combination_id
        tests: [unique, not_null]
  - name: stg_fusion__coa_segment_values
    tests:
      - hnh_unique_combination:
          columns: [segment_column_name, segment_value]
  - name: stg_fusion__gl_periods
    columns:
      - name: period_name
        tests: [unique, not_null]
  - name: stg_fusion__gl_balances
    tests:
      - hnh_unique_combination:
          columns: [code_combination_id, period_name]
  - name: stg_fusion__ap_invoice_distributions
    columns:
      - name: invoice_distribution_id
        tests: [unique, not_null]
  - name: stg_fusion__ap_payments
    columns:
      - name: invoice_payment_id
        tests: [unique, not_null]
  - name: stg_fusion__ap_payment_schedules
    columns:
      - name: invoice_id
        tests: [unique, not_null]
      - name: currency_code
        tests:
          - accepted_values:
              values: ['SAR']
              config: {severity: warn}
  - name: stg_fusion__suppliers
    tests:
      - hnh_unique_combination:
          columns: [vendor_id, vendor_site_id]
  - name: stg_fusion__business_units
    columns:
      - name: business_unit_id
        tests: [unique, not_null]
```

Run: `python scripts/run_dbt.py build --select path:models/hnh/staging/fusion`
Expected: FAIL — models do not exist.

- [ ] **Step 2: Write the ten views**

`stg_fusion__gl_journal_lines.sql`:

```sql
select
    je_header_id,
    je_line_num,
    je_batch_id,
    {{ hnh_str('journal_name') }}           as journal_name,
    {{ hnh_str('doc_sequence_value') }}     as doc_sequence_value,
    ledger_id,
    code_combination_id,
    {{ hnh_str('period_name') }}            as period_name,
    toDate(accounting_date)                 as accounting_date,
    toDate(posted_date)                     as posted_date,
    {{ hnh_str('je_source') }}              as je_source,
    {{ hnh_str('je_category') }}            as je_category,
    {{ hnh_code('actual_flag') }}           as actual_flag,
    {{ hnh_code('header_status') }}         as header_status,
    toFloat64(ifNull(accounted_dr, 0))      as debit,
    toFloat64(ifNull(accounted_cr, 0))      as credit,
    {{ hnh_str('line_description') }}       as line_description
from {{ hnh_fusion_source('fact_gl_journal_line') }} final
```

`stg_fusion__gl_accounts.sql`:

```sql
select
    code_combination_id,
    segment1                                as branch_segment,
    toUInt32OrNull(toString(segment2))      as natural_account,
    {{ hnh_str('segment3') }}               as specialty_code,
    {{ hnh_str('segment4') }}               as service_location_code,
    {{ hnh_str('segment5') }}               as service_group_code,
    {{ hnh_str('segment6') }}               as intercompany_segment,
    {{ hnh_code('account_type') }}          as account_type,
    {{ hnh_flag('enabled_flag') }}          as is_enabled,
    {{ hnh_flag('summary_flag') }}          as is_summary
from {{ hnh_fusion_source('dim_gl_account') }} final
```

`stg_fusion__coa_segment_values.sql`:

```sql
select
    {{ hnh_code('segment_column_name') }}       as segment_column_name,
    trimBoth(segment_value)                     as segment_value,
    {{ hnh_str('segment_value_description') }}  as segment_value_name
from {{ hnh_fusion_source('dim_coa_segment_value') }} final
```

`stg_fusion__gl_periods.sql`:

```sql
select
    period_name,
    period_year,
    period_num,
    quarter_num,
    toDate(start_date)                          as start_date,
    toDate(end_date)                            as end_date,
    {{ hnh_flag('adjustment_period_flag') }}    as is_adjustment
from {{ hnh_fusion_source('dim_gl_period') }} final
```

`stg_fusion__gl_balances.sql`:

```sql
select
    ledger_id,
    code_combination_id,
    period_name,
    {{ hnh_code('actual_flag') }}               as actual_flag,
    {{ hnh_code('currency_balance_type') }}     as currency_balance_type,
    toFloat64(ifNull(accounted_dr, 0))          as period_debit,
    toFloat64(ifNull(accounted_cr, 0))          as period_credit,
    toFloat64(ifNull(accounted_begin_dr, 0))    as begin_debit,
    toFloat64(ifNull(accounted_begin_cr, 0))    as begin_credit
from {{ hnh_fusion_source('fact_gl_balance') }} final
```

`stg_fusion__ap_invoice_distributions.sql`:

```sql
select
    invoice_distribution_id,
    invoice_id,
    {{ hnh_str('invoice_num') }}                as invoice_num,
    {{ hnh_code('line_type_lookup_code') }}     as line_type,
    po_distribution_id,
    {{ hnh_flag('posted_flag') }}               as is_posted,
    {{ hnh_flag('cancellation_flag') }}         as is_cancelled,
    {{ hnh_flag('reversal_flag') }}             as is_reversal,
    {{ hnh_code('invoice_type_lookup_code') }}  as invoice_type_code,
    vendor_id,
    vendor_site_id,
    ledger_id,
    code_combination_id,
    toDate(invoice_date)                        as invoice_date,
    toDate(accounting_date)                     as accounting_date,
    toFloat64(ifNull(accounted_amount, 0))      as amount
from {{ hnh_fusion_source('fact_ap_invoice_distribution') }} final
```

`stg_fusion__ap_payments.sql`:

```sql
select
    invoice_payment_id,
    invoice_id,
    payment_num,
    check_number,
    {{ hnh_code('payment_method_code') }}       as payment_method,
    {{ hnh_code('payment_status') }}            as payment_status,
    {{ hnh_flag('posted_flag') }}               as is_posted,
    vendor_id,
    vendor_site_id,
    ledger_id,
    bank_account_id,
    toDate(accounting_date)                     as payment_date,
    toFloat64(ifNull(accounted_amount, 0))      as amount
from {{ hnh_fusion_source('fact_ap_payment') }} final
```

`stg_fusion__ap_payment_schedules.sql`:

```sql
select
    invoice_id,
    payment_num,
    vendor_id,
    vendor_site_id,
    {{ hnh_str('invoice_num') }}                as invoice_num,
    {{ hnh_code('invoice_type_lookup_code') }}  as invoice_type_code,
    {{ hnh_code('invoice_approval_status') }}   as approval_status,
    {{ hnh_code('payment_status_flag') }}       as payment_status_flag,
    {{ hnh_flag('hold_flag') }}                 as is_on_hold,
    toDate(invoice_date)                        as invoice_date,
    toDate(cancelled_date)                      as cancelled_date,
    business_unit_id,
    toDate(due_date)                            as due_date,
    {{ hnh_code('invoice_currency_code') }}     as currency_code,
    toFloat64(ifNull(entered_gross_amount, 0))      as gross_amount,
    toFloat64(ifNull(entered_amount_remaining, 0))  as amount_remaining
from {{ hnh_fusion_source('fact_ap_payment_schedule') }} final
```

`stg_fusion__suppliers.sql`:

```sql
select
    vendor_id,
    vendor_site_id,
    vendor_number                           as supplier_number,
    {{ hnh_str('vendor_name') }}            as supplier_name,
    {{ hnh_str('vendor_type_code') }}       as supplier_type,
    {{ hnh_str('supplier_status') }}        as supplier_status,
    {{ hnh_str('vendor_site_code') }}       as site_code,
    business_unit_id,
    {{ hnh_str('country') }}                as country
from {{ hnh_fusion_source('dim_supplier') }} final
```

`stg_fusion__business_units.sql`:

```sql
select
    business_unit_id,
    {{ hnh_str('business_unit_name') }}     as business_unit_name,
    primary_ledger_id
from {{ hnh_fusion_source('dim_business_unit') }} final
```

- [ ] **Step 3: Run the tests to verify they pass**

Run: `python scripts/run_dbt.py build --no-partial-parse --select path:models/hnh/staging/fusion`
Expected: all PASS (11 views, 13 tests).

Spot-check: `python -c "import sys; sys.path.insert(0,'scripts'); from ch_env import client; print(client().query('select count(), countIf(header_status = \'P\') from stg.stg_fusion__gl_journal_lines where actual_flag = \'A\'').result_rows)"`
Expected: about `[(9722782, 1766863)]` (more if Fusion loaded since 2026-10-05).

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/staging/fusion/
git commit -m "Stage Fusion GL, AP, supplier and period tables"
```

---

### Task 4: Head Office branch, periods and suppliers

**Files:**
- Modify: `hnh_dwh/models/hnh/marts/conformed/hnh_dim_branch.sql`, `sec_user_access.sql`, `_conformed__models.yml`
- Create: `hnh_dwh/models/hnh/marts/conformed/hnh_dim_gl_period.sql`, `hnh_dim_supplier.sql`, `hnh_dwh/tests/hnh/assert_dim_branch_head_office.sql`, `assert_sec_admins_see_head_office.sql`

**Interfaces:**
- Consumes: `stg_fusion__gl_periods`, `stg_fusion__suppliers`, vars `hnh_head_office_*`.
- Produces:
  - `hnh_dim_branch` gains row `branch_key = 100` ('Head Office', fusion_branch_code 101, fusion_ledger_id 300000005003375)
  - `sec_user_access`: every admin has a row for branch 100
  - `hnh_dim_gl_period(period_key Int32, period_name, fiscal_year UInt16, period_num UInt8, quarter_num UInt8, start_date Date, end_date Date, end_date_key Int32, month_start Date, is_adjustment UInt8)` alias `dim_gl_period`
  - `hnh_dim_supplier(supplier_key Int64, vendor_id, vendor_site_id, supplier_number, supplier_name, supplier_type, supplier_status, site_code, business_unit_id, country)` alias `dim_supplier`, Unknown `-1`

- [ ] **Step 1: Write the failing tests**

`hnh_dwh/tests/hnh/assert_dim_branch_head_office.sql`:

```sql
-- Head Office is branch 100 on Fusion entity 101 and its ledger; it never replaces the Group row.
select 'head office member missing or wrong' as failure
where (select count() from {{ ref('hnh_dim_branch') }}
       where branch_key = 100 and branch_name = 'Head Office'
         and fusion_branch_code = {{ var('hnh_head_office_fusion_branch_code') }}
         and fusion_ledger_id = {{ var('hnh_head_office_ledger_id') }}) != 1
   or (select count() from {{ ref('hnh_dim_branch') }} where branch_key = 0) != 1
```

`hnh_dwh/tests/hnh/assert_sec_admins_see_head_office.sql`:

```sql
-- Admins see Head Office; nobody else gets it unless a source row grants branch 100.
select a.user_name
from (select distinct user_name from {{ ref('sec_user_access') }} where is_admin = 1) as a
left join (select user_name from {{ ref('sec_user_access') }} where branch_key = 100) as h on h.user_name = a.user_name
where h.user_name is null
{{ hnh_settings() }}
```

Add to `_conformed__models.yml`:

```yaml
  - name: hnh_dim_gl_period
    columns:
      - name: period_key
        tests: [unique, not_null]
      - name: period_name
        tests: [unique, not_null]
  - name: hnh_dim_supplier
    columns:
      - name: supplier_key
        tests: [unique, not_null]
```

Run: `python scripts/run_dbt.py build --select hnh_dim_branch sec_user_access hnh_dim_gl_period hnh_dim_supplier assert_dim_branch_head_office assert_sec_admins_see_head_office`
Expected: FAIL — `hnh_dim_gl_period` does not exist; the two singular tests fail.

- [ ] **Step 2: Add Head Office to the branch dimension and the security table**

In `hnh_dim_branch.sql`, after the Group `union all select … ` block and before the closing `)`, add:

```sql
union all

select
    toUInt8(100), 'Head Office', 'Riyadh', toInt32(0), toInt32(0),
    toNullable(toInt64({{ var('hnh_head_office_fusion_branch_code') }})),
    toNullable(toInt64({{ var('hnh_head_office_ledger_id') }})),
    null,
    toUInt64(0)
```

In `sec_user_access.sql`, change the `admins` CTE's cross join from `cross join {{ ref('stg_ref__branch') }} as b` to:

```sql
    cross join (
        select branch_id from {{ ref('stg_ref__branch') }}
        union all
        select toUInt8(100)              -- Head Office (Phase 3): admins only, unless a source row grants it
    ) as b
```

- [ ] **Step 3: Write the period and supplier dimensions**

`hnh_dim_gl_period.sql`:

```sql
{{ config(alias='dim_gl_period', order_by='period_key') }}

-- Monthly and quarterly adjustment periods of calendar "Monthly 12 4"; the stray yearly period (period_year 1) is left out.
-- period_key = year * 100 + period number, so it also gives the running order (an adjustment period follows its quarter).
select
    toInt32(assumeNotNull(period_year) * 100 + assumeNotNull(period_num))  as period_key,
    period_name,
    toUInt16(assumeNotNull(period_year))                                   as fiscal_year,
    toUInt8(assumeNotNull(period_num))                                     as period_num,
    toUInt8(ifNull(quarter_num, 0))                                        as quarter_num,
    assumeNotNull(start_date)                                              as start_date,
    assumeNotNull(end_date)                                                as end_date,
    {{ hnh_date_key('assumeNotNull(end_date)') }}                          as end_date_key,
    toStartOfMonth(assumeNotNull(end_date))                                as month_start,
    is_adjustment
from {{ ref('stg_fusion__gl_periods') }}
where ifNull(period_year, 0) >= 1900 and start_date is not null and end_date is not null
```

`hnh_dim_supplier.sql`:

```sql
{{ config(alias='dim_supplier', order_by='supplier_key') }}

select
    {{ hnh_surrogate_key(['vendor_id', 'vendor_site_id']) }} as supplier_key,
    toNullable(vendor_id)       as vendor_id,
    toNullable(vendor_site_id)  as vendor_site_id,
    supplier_number,
    supplier_name,
    supplier_type,
    supplier_status,
    site_code,
    business_unit_id,
    country
from {{ ref('stg_fusion__suppliers') }}

union all

select toInt64(-1), null, null, null, 'Unknown', null, null, null, null, null
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python scripts/run_dbt.py build --no-partial-parse --select hnh_dim_branch sec_user_access hnh_dim_gl_period hnh_dim_supplier assert_dim_branch_head_office assert_sec_admins_see_head_office assert_sec_no_access_without_branch warn_branches_without_targets`
Expected: all PASS (`warn_branches_without_targets` keeps its earlier row count; it filters branches 1–8).

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/marts/conformed/ hnh_dwh/tests/hnh/assert_dim_branch_head_office.sql hnh_dwh/tests/hnh/assert_sec_admins_see_head_office.sql
git commit -m "Add Head Office as branch 100 and the GL period and supplier dimensions"
```

---

### Task 5: FS hierarchy, budget lines and the GL account dimension

**Files:**
- Create: `hnh_dwh/models/hnh/marts/conformed/dim_fs_line.sql`, `dim_budget_line.sql`, `hnh_dim_gl_account.sql`, `_finance_conformed_unit_tests.yml`, `hnh_dwh/tests/hnh/warn_fs_levels_without_order.sql`
- Modify: `hnh_dwh/models/hnh/marts/conformed/_conformed__models.yml`

**Interfaces:**
- Consumes: `stg_ref__fs_account`, `stg_ref__fs_line_order`, `stg_ref__budget_fs_line`, `stg_ref__fusion_specialty_unified`, `stg_fusion__gl_accounts`, `stg_fusion__coa_segment_values`, `hnh_dim_branch`; macros from Task 1.
- Produces:
  - `dim_fs_line(fs_line_key, fs_type, fs_element, fs_category, fs_caption, fs_line, type_sort, element_sort, category_sort, caption_sort, line_sort, statement_group, display_sign Int8, is_not_mapped UInt8)`
  - `dim_budget_line(budget_line_key, budget_line_code, budget_line_name, sort_order, is_subtotal, natural_side)` — 50 rows
  - `hnh_dim_gl_account(gl_account_key, code_combination_id Nullable(Int64), branch_key UInt8, branch_segment, natural_account, natural_account_name, specialty_code, specialty_name, service_location_code, service_location_name, service_group_code, service_group_name, intercompany_segment, intercompany_branch_key Nullable(UInt8), account_type, balance_side, fs_line_key, fs_mapping_source, revenue_care_type, budget_line_code Nullable(String), unified_department Nullable(String), is_enabled, is_summary)` alias `dim_gl_account`; Unknown `-1`; one `prior-year roll` row per branch (except 0)

- [ ] **Step 1: Write the YAML tests and the failing unit test**

Add to `_conformed__models.yml`:

```yaml
  - name: dim_fs_line
    columns:
      - name: fs_line_key
        tests: [unique, not_null]
      - name: statement_group
        tests:
          - not_null
          - accepted_values:
              values: ['Balance sheet', 'Revenue', 'Revenue discounts', 'Direct cost', 'G&A', 'Selling and marketing',
                       'Charges from head office', 'Other income', 'Depreciation and amortisation', 'Finance cost',
                       'Zakat', 'OCI', 'Not mapped expenses']
  - name: dim_budget_line
    columns:
      - name: budget_line_key
        tests: [unique, not_null]
      - name: budget_line_code
        tests: [unique, not_null]
  - name: hnh_dim_gl_account
    columns:
      - name: gl_account_key
        tests: [unique, not_null]
      - name: fs_line_key
        tests:
          - not_null
          - relationships: {to: ref('dim_fs_line'), field: fs_line_key}
      - name: budget_line_code
        tests:
          - relationships: {to: ref('dim_budget_line'), field: budget_line_code}
      - name: fs_mapping_source
        tests:
          - accepted_values:
              values: ['supplied', 'inferred', 'not mapped', 'prior-year roll']
```

`_finance_conformed_unit_tests.yml`:

```yaml
version: 2

unit_tests:
  - name: hnh_dim_gl_account_maps_fs_and_budget_lines
    description: >
      1: Abha OP revenue account, REV_OP by category and care type. 2: contractual discount on an IP location, REV_IP
      by caption. 3: government rejection, the account rule beats a caption rule for the same account. 4: Head Office
      loan with no FS line: balance sheet, Not mapped, no budget code, branch 100. 5: unmapped expense: income
      statement, UNBUDGETED. 6: inferred revenue account without location: REV_UNALLOCATED. 7: Ghirnata bank account
      with an intercompany segment. Plus one prior-year roll row per branch and the Unknown member.
    model: hnh_dim_gl_account
    given:
      - input: ref('stg_fusion__gl_accounts')
        format: sql
        rows: |
          select toInt64(c) as code_combination_id, toNullable(toInt64(b)) as branch_segment, toNullable(toUInt32(n)) as natural_account,
                 toNullable('010000001') as specialty_code, toNullable(loc) as service_location_code, toNullable('00') as service_group_code,
                 toNullable(ic) as intercompany_segment, toNullable(t) as account_type, toUInt8(1) as is_enabled, toUInt8(0) as is_summary
          from values('c UInt32, b UInt32, n UInt32, loc String, ic String, t String',
              (1, 104, 41110101, '01', '000', 'R'), (2, 104, 41310101, '02', '000', 'R'), (3, 104, 41504102, '00', '000', 'R'),
              (4, 101, 22101101, '00', '000', 'L'), (5, 105, 53101203, '01', '000', 'E'), (6, 105, 41110102, '00', '000', 'R'),
              (7, 103, 11103107, '00', '105', 'A'))
      - input: ref('stg_fusion__coa_segment_values')
        format: sql
        rows: |
          select 'SEGMENT2' as segment_column_name, '41110101' as segment_value, toNullable('Revenue Cash') as segment_value_name
      - input: ref('stg_ref__fs_account')
        format: sql
        rows: |
          select toUInt32(n) as natural_account, t as fs_type, e as fs_element, cat as fs_category, cap as fs_caption, l as fs_line, m as mapped_in
          from values('n UInt32, t String, e String, cat String, cap String, l String, m String',
              (41110101, 'IS', 'Revenue', 'Revenue', 'Revenue Cash', 'Revenue Cash', 'abha'),
              (41310101, 'IS', 'Revenue', 'Revenue - Discounts', 'Revenue - Contractual Discounts', 'Cash Discount', 'abha'),
              (41504102, 'IS', 'Revenue', 'Revenue - Discounts', 'Revenue - Settlement Discount', 'Rejection', 'abha'),
              (41110102, 'IS', 'Revenue', 'Revenue', 'Revenue Insurance Companies', 'Revenue Insurance Companies', 'inferred'),
              (11103107, 'BS', 'Assets', 'Current Assets', 'Cash and bank balances', 'Bank', 'ghirnata'))
      - input: ref('stg_ref__budget_fs_line')
        format: sql
        rows: |
          select code as line_item_code, lvl as match_level, v as match_value_lower, if(ct = '', cast(null as Nullable(String)), toNullable(ct)) as care_type
          from values('code String, lvl String, v String, ct String',
              ('REV_OP', 'category', 'revenue', 'OP'), ('REV_IP', 'caption', 'revenue - contractual discounts', 'IP'),
              ('REV_UNALLOCATED', 'category', 'revenue', 'Unallocated'), ('DIS_REJECTION_MOH', 'account', '41504102', ''),
              ('DIS_EARLY_PAY', 'caption', 'revenue - settlement discount', ''))
      - input: ref('stg_ref__fusion_specialty_unified')
        format: sql
        rows: |
          select '010000001' as specialty_code, toNullable('INTERNAL MEDICINE') as unified_department
      - input: ref('hnh_dim_branch')
        format: sql
        rows: |
          select toUInt8(k) as branch_key, toNullable(toInt64(f)) as fusion_branch_code
          from values('k UInt8, f UInt32', (6, 104), (7, 103), (3, 105), (100, 101))
    expect:
      rows:
        - {code_combination_id: 1, branch_key: 6, balance_side: IS, fs_mapping_source: supplied, revenue_care_type: OP, budget_line_code: REV_OP, intercompany_branch_key: null}
        - {code_combination_id: 2, branch_key: 6, balance_side: IS, fs_mapping_source: supplied, revenue_care_type: IP, budget_line_code: REV_IP, intercompany_branch_key: null}
        - {code_combination_id: 3, branch_key: 6, balance_side: IS, fs_mapping_source: supplied, revenue_care_type: Unallocated, budget_line_code: DIS_REJECTION_MOH, intercompany_branch_key: null}
        - {code_combination_id: 4, branch_key: 100, balance_side: BS, fs_mapping_source: not mapped, revenue_care_type: Unallocated, budget_line_code: null, intercompany_branch_key: null}
        - {code_combination_id: 5, branch_key: 3, balance_side: IS, fs_mapping_source: not mapped, revenue_care_type: OP, budget_line_code: UNBUDGETED, intercompany_branch_key: null}
        - {code_combination_id: 6, branch_key: 3, balance_side: IS, fs_mapping_source: inferred, revenue_care_type: Unallocated, budget_line_code: REV_UNALLOCATED, intercompany_branch_key: null}
        - {code_combination_id: 7, branch_key: 7, balance_side: BS, fs_mapping_source: supplied, revenue_care_type: Unallocated, budget_line_code: null, intercompany_branch_key: 3}
        - {code_combination_id: null, branch_key: 6, balance_side: BS, fs_mapping_source: prior-year roll, revenue_care_type: Unallocated, budget_line_code: null, intercompany_branch_key: null}
        - {code_combination_id: null, branch_key: 7, balance_side: BS, fs_mapping_source: prior-year roll, revenue_care_type: Unallocated, budget_line_code: null, intercompany_branch_key: null}
        - {code_combination_id: null, branch_key: 3, balance_side: BS, fs_mapping_source: prior-year roll, revenue_care_type: Unallocated, budget_line_code: null, intercompany_branch_key: null}
        - {code_combination_id: null, branch_key: 100, balance_side: BS, fs_mapping_source: prior-year roll, revenue_care_type: Unallocated, budget_line_code: null, intercompany_branch_key: null}
        - {code_combination_id: null, branch_key: 0, balance_side: BS, fs_mapping_source: not mapped, revenue_care_type: Unallocated, budget_line_code: null, intercompany_branch_key: null}
```

Run: `python scripts/run_dbt.py test --select hnh_dim_gl_account_maps_fs_and_budget_lines`
Expected: FAIL — model `hnh_dim_gl_account` not found.

- [ ] **Step 2: Write `dim_fs_line`**

```sql
{{ config(order_by='fs_line_key') }}

with mapped as (
    select fs_type, fs_element, fs_category, fs_caption, fs_line, min(natural_account) as first_account, toUInt8(0) as is_not_mapped
    from {{ ref('stg_ref__fs_account') }}
    group by fs_type, fs_element, fs_category, fs_caption, fs_line
),

not_mapped as (
    -- one Not mapped line per account-type element, so unmapped accounts keep the statements balanced
    select t as fs_type, e as fs_element, 'Not mapped' as fs_category, 'Not mapped' as fs_caption, 'Not mapped' as fs_line,
           toUInt32(4294967295) as first_account, toUInt8(1) as is_not_mapped
    from values('t String, e String', ('BS', 'Assets'), ('BS', 'Liabilities'), ('BS', 'Equity'), ('IS', 'Revenue'), ('IS', 'Expenses'))
),

lines as (
    select * from mapped
    union all
    select * from not_mapped
),

ord as (select level, value_lower, sort_order, statement_group from {{ ref('stg_ref__fs_line_order') }})

select
    {{ hnh_fs_line_key('l.fs_type', 'l.fs_element', 'l.fs_category', 'l.fs_caption', 'l.fs_line') }} as fs_line_key,
    l.fs_type                                                               as fs_type,
    l.fs_element                                                            as fs_element,
    l.fs_category                                                           as fs_category,
    l.fs_caption                                                            as fs_caption,
    l.fs_line                                                               as fs_line,
    ifNull(ot.sort_order, toUInt16(999))                                    as type_sort,
    ifNull(oe.sort_order, toUInt16(999))                                    as element_sort,
    if(l.is_not_mapped = 1, toUInt16(99), ifNull(oc.sort_order, toUInt16(999)))  as category_sort,
    if(l.is_not_mapped = 1, toUInt16(99), ifNull(op.sort_order, toUInt16(999)))  as caption_sort,
    toUInt16(row_number() over (partition by l.fs_type, l.fs_element, l.fs_category, l.fs_caption order by l.first_account, l.fs_line)) as line_sort,
    if(l.is_not_mapped = 1,
       multiIf(l.fs_element = 'Revenue', 'Revenue', l.fs_type = 'IS', 'Not mapped expenses', 'Balance sheet'),
       if(l.fs_type = 'BS', 'Balance sheet', oc.statement_group))           as statement_group,
    {{ hnh_fs_display_sign('l.fs_element') }}                               as display_sign,
    l.is_not_mapped                                                         as is_not_mapped
from lines as l
left join (select value_lower, sort_order from ord where level = 'type') as ot on ot.value_lower = lower(l.fs_type)
left join (select value_lower, sort_order from ord where level = 'element') as oe on oe.value_lower = lower(l.fs_element)
left join (select value_lower, sort_order, statement_group from ord where level = 'category') as oc on oc.value_lower = lower(l.fs_category)
left join (select value_lower, sort_order from ord where level = 'caption') as op on op.value_lower = lower(l.fs_caption)
{{ hnh_settings() }}
```

- [ ] **Step 3: Write `dim_budget_line`**

```sql
{{ config(order_by='budget_line_key') }}

-- The 48 codes of default.income_statement_budget plus REV_UNALLOCATED and UNBUDGETED (spec 5.5).
select
    {{ hnh_surrogate_key(['code']) }}            as budget_line_key,
    code                                         as budget_line_code,
    name                                         as budget_line_name,
    toUInt16(sort_order)                         as sort_order,
    toUInt8(is_subtotal)                         as is_subtotal,
    {{ hnh_budget_natural_side('code', "''") }}  as natural_side
from values('code String, name String, sort_order UInt16, is_subtotal UInt8',
    ('REV_OP', 'Revenue - outpatient', 10, 0), ('REV_IP', 'Revenue - inpatient', 20, 0), ('REV_ER', 'Revenue - emergency', 30, 0),
    ('REV_UNALLOCATED', 'Revenue - unallocated', 40, 0), ('REV_SUB', 'Gross revenue', 50, 1),
    ('DIS_REJECTION_INS', 'Rejections - insurance', 60, 0), ('DIS_REJECTION_MOH', 'Rejections - MOH', 70, 0),
    ('DIS_REJECTION', 'Rejections', 80, 1), ('DIS_EARLY_PAY', 'Early payment discount', 90, 0),
    ('DIS_VOLUME', 'Volume discount', 100, 0), ('DIS_SETTLEMENT', 'Settlement discounts', 110, 1), ('REV_NET', 'Net revenue', 120, 1),
    ('DC_EMPLOYEE', 'Employee costs', 130, 0), ('DC_DOCTORS_FEE', 'Doctors fee and commission', 140, 0),
    ('DC_MEDICINES', 'Cost of medicines', 150, 0), ('DC_CONSUMABLES', 'Consumables', 160, 0),
    ('DC_GOVT_FEES', 'Employee government fees', 170, 0), ('DC_INSURANCE', 'Insurance', 180, 0),
    ('DC_MAINTENANCE', 'Maintenance', 190, 0), ('DC_UTILITIES', 'Utilities', 200, 0), ('DC_RENTAL', 'Rental', 210, 0),
    ('DC_REFERRAL', 'Referral cost', 220, 0), ('DC_KITCHEN', 'Kitchen', 230, 0), ('DC_TRAVEL', 'Travel and transport', 240, 0),
    ('DC_TRAINING', 'Training and recruitment', 250, 0), ('DC_OTHER', 'Other direct expenses', 260, 0),
    ('TOTAL_DC', 'Total direct cost', 270, 1), ('GROSS_PROFIT', 'Gross profit', 280, 1),
    ('GA_EMPLOYEE', 'G&A employee cost', 290, 0), ('GA_PROFESSIONAL', 'Professional fees and subscriptions', 300, 0),
    ('GA_AUDIT', 'Audit fee', 310, 0), ('GA_COMMUNICATION', 'Communication', 320, 0), ('GA_POSTAGE', 'Postage and stationery', 330, 0),
    ('GA_SECURITY', 'Security and cleaning', 340, 0), ('GA_GOVT_FEE', 'Government fees', 350, 0),
    ('GA_TRAINING', 'G&A training and recruitment', 360, 0), ('GA_ECL', 'Expected credit loss', 370, 0),
    ('GA_MARKETING', 'Selling and marketing', 380, 0), ('GA_HO_CHARGES', 'Head office charges', 390, 0),
    ('GA_OTHER', 'Other indirect expenses', 400, 0), ('TOTAL_GA', 'Total G&A', 410, 1), ('OTHER_INCOME', 'Other income', 420, 0),
    ('EBITDA', 'EBITDA', 430, 1), ('DEPRECIATION', 'Depreciation and amortisation', 440, 0), ('FINANCE_COST', 'Finance cost', 450, 0),
    ('ZAKAT', 'Zakat', 460, 0), ('NET_PROFIT', 'Net profit', 470, 1), ('OCI', 'Other comprehensive income', 480, 0),
    ('TOTAL_COMP_INCOME', 'Total comprehensive income', 490, 1), ('UNBUDGETED', 'Not in budget', 500, 0))
```

- [ ] **Step 4: Write `hnh_dim_gl_account`**

```sql
{{ config(alias='dim_gl_account', order_by='gl_account_key') }}

with branches as (
    select branch_key, fusion_branch_code from {{ ref('hnh_dim_branch') }} where fusion_branch_code is not null
),

seg as (select segment_column_name, segment_value, segment_value_name from {{ ref('stg_fusion__coa_segment_values') }}),

base as (
    select
        a.code_combination_id                                               as code_combination_id,
        a.branch_segment                                                    as branch_segment,
        a.natural_account                                                   as natural_account,
        a.specialty_code                                                    as specialty_code,
        a.service_location_code                                             as service_location_code,
        a.service_group_code                                                as service_group_code,
        a.intercompany_segment                                              as intercompany_segment,
        a.account_type                                                      as account_type,
        a.is_enabled                                                        as is_enabled,
        a.is_summary                                                        as is_summary,
        {{ hnh_gl_care_type('a.service_location_code') }}                   as revenue_care_type,
        {{ hnh_gl_balance_side('f.fs_type', 'a.account_type') }}            as balance_side,
        multiIf(f.natural_account is null, 'not mapped', f.mapped_in = 'inferred', 'inferred', 'supplied') as fs_mapping_source,
        ifNull(f.fs_element, {{ hnh_not_mapped_element('a.account_type') }}) as fs_element_r,
        ifNull(f.fs_category, 'Not mapped')                                 as fs_category_r,
        ifNull(f.fs_caption, 'Not mapped')                                  as fs_caption_r,
        ifNull(f.fs_line, 'Not mapped')                                     as fs_line_r
    from {{ ref('stg_fusion__gl_accounts') }} as a
    left join {{ ref('stg_ref__fs_account') }} as f on f.natural_account = a.natural_account
),

candidates as (
    -- every budget rule that matches an income-statement account; the most specific level wins
    select b.code_combination_id as code_combination_id, m.line_item_code as line_item_code,
           multiIf(m.match_level = 'account', 1, m.match_level = 'line', 2, m.match_level = 'caption', 3, 4) as match_rank
    from base as b
    cross join {{ ref('stg_ref__budget_fs_line') }} as m
    where b.balance_side = 'IS'
      and (m.care_type is null or m.care_type = b.revenue_care_type)
      and ((m.match_level = 'account' and m.match_value_lower = toString(b.natural_account))
        or (m.match_level = 'line' and m.match_value_lower = lower(b.fs_line_r))
        or (m.match_level = 'caption' and m.match_value_lower = lower(b.fs_caption_r))
        or (m.match_level = 'category' and m.match_value_lower = lower(b.fs_category_r)))
),

picked as (
    select code_combination_id, argMin(line_item_code, match_rank) as picked_code
    from candidates
    group by code_combination_id
)

select
    {{ hnh_surrogate_key(['b.code_combination_id']) }}                      as gl_account_key,
    toNullable(b.code_combination_id)                                       as code_combination_id,
    ifNull(br.branch_key, toUInt8(0))                                       as branch_key,
    b.branch_segment                                                        as branch_segment,
    b.natural_account                                                       as natural_account,
    s2.segment_value_name                                                   as natural_account_name,
    b.specialty_code                                                        as specialty_code,
    s3.segment_value_name                                                   as specialty_name,
    b.service_location_code                                                 as service_location_code,
    s4.segment_value_name                                                   as service_location_name,
    b.service_group_code                                                    as service_group_code,
    s5.segment_value_name                                                   as service_group_name,
    b.intercompany_segment                                                  as intercompany_segment,
    ic.branch_key                                                           as intercompany_branch_key,
    b.account_type                                                          as account_type,
    b.balance_side                                                          as balance_side,
    {{ hnh_fs_line_key('b.balance_side', 'b.fs_element_r', 'b.fs_category_r', 'b.fs_caption_r', 'b.fs_line_r') }} as fs_line_key,
    b.fs_mapping_source                                                     as fs_mapping_source,
    b.revenue_care_type                                                     as revenue_care_type,
    if(b.balance_side = 'IS', ifNull(p.picked_code, 'UNBUDGETED'), cast(null as Nullable(String))) as budget_line_code,
    sp.unified_department                                                   as unified_department,
    b.is_enabled                                                            as is_enabled,
    b.is_summary                                                            as is_summary
from base as b
left join picked as p on p.code_combination_id = b.code_combination_id
left join branches as br on br.fusion_branch_code = b.branch_segment
left join branches as ic on ic.fusion_branch_code = toInt64OrNull(b.intercompany_segment)
left join (select segment_value, segment_value_name from seg where segment_column_name = 'SEGMENT2') as s2 on s2.segment_value = toString(b.natural_account)
left join (select segment_value, segment_value_name from seg where segment_column_name = 'SEGMENT3') as s3 on s3.segment_value = b.specialty_code
left join (select segment_value, segment_value_name from seg where segment_column_name = 'SEGMENT4') as s4 on s4.segment_value = b.service_location_code
left join (select segment_value, segment_value_name from seg where segment_column_name = 'SEGMENT5') as s5 on s5.segment_value = b.service_group_code
left join {{ ref('stg_ref__fusion_specialty_unified') }} as sp on sp.specialty_code = b.specialty_code

union all

-- one account per branch that carries the income-statement result of earlier fiscal years (spec 6.2)
select
    {{ hnh_prior_year_results_key('branch_key') }}, cast(null as Nullable(Int64)), branch_key,
    toNullable(fusion_branch_code), toNullable(toUInt32(36101101)), toNullable('Prior-year results'),
    null, null, null, null, null, null, null, cast(null as Nullable(UInt8)), toNullable('O'), 'BS',
    {{ hnh_fs_line_key("'BS'", "'Equity'", "'Equity'", "'Retained earnings'", "'Retained earnings'") }},
    'prior-year roll', 'Unallocated', cast(null as Nullable(String)), cast(null as Nullable(String)), toUInt8(1), toUInt8(0)
from branches

union all

select
    toInt64(-1), cast(null as Nullable(Int64)), toUInt8(0), null, null, toNullable('Unknown'),
    null, null, null, null, null, null, null, cast(null as Nullable(UInt8)), null, 'BS',
    {{ hnh_fs_line_key("'BS'", "'Assets'", "'Not mapped'", "'Not mapped'", "'Not mapped'") }},
    'not mapped', 'Unallocated', cast(null as Nullable(String)), cast(null as Nullable(String)), toUInt8(0), toUInt8(0)
{{ hnh_settings() }}
```

`hnh_dwh/tests/hnh/warn_fs_levels_without_order.sql`:

```sql
{{ config(severity='warn') }}
-- FS levels used by the mapping that have no row in map_fs_line_order (they sort last).
select fs_type, fs_element, fs_category, fs_caption
from {{ ref('dim_fs_line') }}
where is_not_mapped = 0 and 999 in (type_sort, element_sort, category_sort, caption_sort)
```

- [ ] **Step 5: Run the unit test and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select dim_fs_line dim_budget_line hnh_dim_gl_account warn_fs_levels_without_order`
Expected: unit test PASS, all models and tests PASS, `warn_fs_levels_without_order` 0 rows.

Spot-check coverage: `select fs_mapping_source, count() from gold.dim_gl_account group by 1` — expect `supplied` and `inferred` together near 7,800 of 9,500 combinations, plus 9 `prior-year roll` rows (eight hospitals and Head Office).

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/models/hnh/marts/conformed/ hnh_dwh/tests/hnh/warn_fs_levels_without_order.sql
git commit -m "Add the FS line hierarchy, budget lines and the GL account dimension"
```

---

### Task 6: GL journal-line fact

**Files:**
- Create: `hnh_dwh/models/hnh/marts/finance/hnh_fact_gl_journal_line.sql`, `_finance_marts__models.yml`, `_finance_marts_unit_tests.yml`, `hnh_dwh/tests/hnh/assert_fact_gl_journal_line_matches_staging.sql`

**Interfaces:**
- Consumes: `stg_fusion__gl_journal_lines`, `hnh_dim_gl_account`, `hnh_dim_branch`, `hnh_dim_gl_period`; var `hnh_fusion_oasis_feed_source`.
- Produces: `hnh_fact_gl_journal_line` (alias `fact_gl_journal_line`): `gl_journal_line_key, je_header_id, je_line_num, branch_key UInt8, gl_account_key Int64, period_key Int32, accounting_date_key, posted_date_key, intercompany_branch_key, ledger_id, je_batch_id, journal_name, doc_sequence_value, je_source, je_source_label, je_category, header_status, line_description, is_posted, is_opening_balance_journal, is_oasis_feed, debit, credit, amount, _loaded_at`

- [ ] **Step 1: Write the YAML tests, the conservation test and the failing unit test**

`_finance_marts__models.yml`:

```yaml
version: 2

models:
  - name: hnh_fact_gl_journal_line
    description: One Fusion actual journal line, posted or not (is_posted). Rebuilt in full every night.
    columns:
      - name: gl_journal_line_key
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
      - name: gl_account_key
        tests:
          - relationships: {to: ref('hnh_dim_gl_account'), field: gl_account_key}
      - name: period_key
        tests:
          - relationships: {to: ref('hnh_dim_gl_period'), field: period_key}
      - name: accounting_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
```

`hnh_dwh/tests/hnh/assert_fact_gl_journal_line_matches_staging.sql`:

```sql
-- Every staged actual line reaches the fact once, with the same debits and credits, on a real branch and period.
select 'fact_gl_journal_line differs from staging' as failure
from (select count() as n, round(sum(debit), 2) as dr, round(sum(credit), 2) as cr,
             countIf(branch_key = 0) as no_branch, countIf(period_key = 0) as no_period
      from {{ ref('hnh_fact_gl_journal_line') }}) as f
cross join (select count() as n, round(sum(debit), 2) as dr, round(sum(credit), 2) as cr
            from {{ ref('stg_fusion__gl_journal_lines') }} where actual_flag = 'A') as s
where f.n != s.n or abs(f.dr - s.dr) > 0.01 or abs(f.cr - s.cr) > 0.01 or f.no_branch > 0 or f.no_period > 0
```

`_finance_marts_unit_tests.yml`:

```yaml
version: 2

unit_tests:
  - name: hnh_fact_gl_journal_line_flags_lines
    description: >
      Header 1 is a posted Head Office opening-balance journal (branch 100, never Group 0). Header 2 is an unposted
      Oasis-feed line at Abha. Header 3 is a budget line (actual flag B) and is left out.
    model: hnh_fact_gl_journal_line
    given:
      - input: ref('stg_fusion__gl_journal_lines')
        format: sql
        rows: |
          select toInt64(h) as je_header_id, toInt64(n) as je_line_num, toNullable(toInt64(1)) as je_batch_id,
                 toNullable('J') as journal_name, cast(null as Nullable(String)) as doc_sequence_value,
                 toNullable(toInt64(lg)) as ledger_id, toNullable(toInt64(10)) as code_combination_id, toNullable(p) as period_name,
                 toNullable(toDate('2026-01-31')) as accounting_date, cast(null as Nullable(Date)) as posted_date,
                 toNullable(src) as je_source, toNullable(cat) as je_category, toNullable(af) as actual_flag, toNullable(hs) as header_status,
                 toFloat64(dr) as debit, toFloat64(cr) as credit, cast(null as Nullable(String)) as line_description
          from values('h UInt32, n UInt32, lg UInt64, p String, src String, cat String, af String, hs String, dr Float64, cr Float64',
              (1, 1, 300000005003375, 'Jan-26', 'Spreadsheet', 'MRC Open Balances', 'A', 'P', 100, 0),
              (1, 2, 300000005003375, 'Jan-26', 'Spreadsheet', 'MRC Open Balances', 'A', 'P', 0, 100),
              (2, 1, 300000005003384, 'Jan-26', '300000007046804', '300000005338519', 'A', 'U', 50, 0),
              (3, 1, 300000005003384, 'Jan-26', 'Manual', 'Manual', 'B', 'P', 70, 0))
      - input: ref('hnh_dim_gl_account')
        format: sql
        rows: |
          select toInt64(555) as gl_account_key, toNullable(toInt64(10)) as code_combination_id, cast(null as Nullable(UInt8)) as intercompany_branch_key
      - input: ref('hnh_dim_branch')
        format: sql
        rows: |
          select toUInt8(k) as branch_key, toNullable(toInt64(l)) as fusion_ledger_id
          from values('k UInt8, l UInt64', (100, 300000005003375), (6, 300000005003384))
      - input: ref('hnh_dim_gl_period')
        format: sql
        rows: |
          select toInt32(202601) as period_key, 'Jan-26' as period_name
    expect:
      rows:
        - {je_header_id: 1, je_line_num: 1, branch_key: 100, gl_account_key: 555, period_key: 202601, is_posted: 1, is_opening_balance_journal: 1, is_oasis_feed: 0, je_source_label: Spreadsheet, amount: 100}
        - {je_header_id: 1, je_line_num: 2, branch_key: 100, gl_account_key: 555, period_key: 202601, is_posted: 1, is_opening_balance_journal: 1, is_oasis_feed: 0, je_source_label: Spreadsheet, amount: -100}
        - {je_header_id: 2, je_line_num: 1, branch_key: 6, gl_account_key: 555, period_key: 202601, is_posted: 0, is_opening_balance_journal: 0, is_oasis_feed: 1, je_source_label: Oasis feed, amount: 50}
```

Run: `python scripts/run_dbt.py test --no-partial-parse --select hnh_fact_gl_journal_line_flags_lines`
Expected: FAIL — model not found.

- [ ] **Step 2: Write the fact**

`hnh_fact_gl_journal_line.sql`:

```sql
{{ config(alias='fact_gl_journal_line', order_by='(branch_key, period_key, gl_account_key, gl_journal_line_key)') }}

{% set oasis_feed = "'" ~ var('hnh_fusion_oasis_feed_source') ~ "'" %}

select
    {{ hnh_surrogate_key(['j.je_header_id', 'j.je_line_num']) }}         as gl_journal_line_key,
    j.je_header_id                                                      as je_header_id,
    j.je_line_num                                                       as je_line_num,
    ifNull(b.branch_key, toUInt8(0))                                    as branch_key,
    ifNull(a.gl_account_key, toInt64(-1))                               as gl_account_key,
    ifNull(p.period_key, toInt32(0))                                    as period_key,
    {{ hnh_date_key_in_range('j.accounting_date') }}                    as accounting_date_key,
    {{ hnh_date_key_in_range('j.posted_date') }}                        as posted_date_key,
    a.intercompany_branch_key                                           as intercompany_branch_key,
    j.ledger_id                                                         as ledger_id,
    j.je_batch_id                                                       as je_batch_id,
    j.journal_name                                                      as journal_name,
    j.doc_sequence_value                                                as doc_sequence_value,
    j.je_source                                                         as je_source,
    if(ifNull(j.je_source, '') = {{ oasis_feed }}, 'Oasis feed', ifNull(j.je_source, 'Unknown')) as je_source_label,
    j.je_category                                                       as je_category,
    j.header_status                                                     as header_status,
    j.line_description                                                  as line_description,
    toUInt8(ifNull(j.header_status, '') = 'P')                          as is_posted,
    toUInt8(ifNull(j.je_category, '') = 'MRC Open Balances')            as is_opening_balance_journal,
    toUInt8(ifNull(j.je_source, '') = {{ oasis_feed }})                 as is_oasis_feed,
    j.debit                                                             as debit,
    j.credit                                                            as credit,
    j.debit - j.credit                                                  as amount,
    now()                                                               as _loaded_at
from {{ ref('stg_fusion__gl_journal_lines') }} as j
left join (
    select gl_account_key, code_combination_id, intercompany_branch_key
    from {{ ref('hnh_dim_gl_account') }} where code_combination_id is not null
) as a on a.code_combination_id = j.code_combination_id
left join (
    select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null
) as b on b.fusion_ledger_id = j.ledger_id
left join (select period_key, period_name from {{ ref('hnh_dim_gl_period') }}) as p on p.period_name = j.period_name
where j.actual_flag = 'A'
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the unit test and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select hnh_fact_gl_journal_line assert_fact_gl_journal_line_matches_staging`
Expected: unit test PASS, model built (about 9.7M rows), relationships and conservation PASS.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/finance/ hnh_dwh/tests/hnh/assert_fact_gl_journal_line_matches_staging.sql
git commit -m "Add the GL journal-line fact with posting and opening-balance flags"
```

---

### Task 7: Monthly balance fact

**Files:**
- Create: `hnh_dwh/models/hnh/marts/finance/fact_gl_balance_monthly.sql`, `hnh_dwh/tests/hnh/assert_gl_trial_balance_zero.sql`
- Modify: `_finance_marts__models.yml`, `_finance_marts_unit_tests.yml`

**Interfaces:**
- Consumes: `hnh_fact_gl_journal_line` (branch_key, gl_account_key, period_key, is_posted, is_opening_balance_journal, debit, credit), `hnh_dim_gl_account` (gl_account_key, balance_side), `hnh_dim_gl_period` (period_key, fiscal_year, start_date); `hnh_prior_year_results_key`.
- Produces: `fact_gl_balance_monthly(balance_view, branch_key, gl_account_key, period_key, fiscal_year, is_prior_year_roll, opening_balance, period_debit, period_credit, period_movement, period_movement_excl_opening, closing_balance, _loaded_at)`

- [ ] **Step 1: Write the failing unit test and the trial-balance test**

Append to `_finance_marts_unit_tests.yml`:

```yaml
  - name: fact_gl_balance_monthly_densifies_and_rolls_years
    description: >
      Account 10 (balance sheet) is posted only in January, with an unposted credit in March: it has a row in every
      period, and March differs between the views. Account 20 (revenue) has a January opening-balance credit, a
      February credit and a posting in January 2027, a period not yet started: the grid extends to 2027, the
      income-statement balance restarts at 2027 and the 2026 result appears once on branch 6's prior-year roll account.
    model: fact_gl_balance_monthly
    given:
      - input: ref('hnh_fact_gl_journal_line')
        format: sql
        rows: |
          select toUInt8(6) as branch_key, toInt64(a) as gl_account_key, toInt32(p) as period_key, toUInt8(ps) as is_posted,
                 toUInt8(ob) as is_opening_balance_journal, toFloat64(dr) as debit, toFloat64(cr) as credit
          from values('a UInt32, p UInt32, ps UInt8, ob UInt8, dr Float64, cr Float64',
              (10, 202601, 1, 0, 100, 0), (10, 202603, 0, 0, 0, 30),
              (20, 202601, 1, 1, 0, 100), (20, 202602, 1, 0, 0, 50), (20, 202701, 1, 0, 0, 10))
      - input: ref('hnh_dim_gl_account')
        format: sql
        rows: |
          select toInt64(a) as gl_account_key, s as balance_side from values('a UInt32, s String', (10, 'BS'), (20, 'IS'))
      - input: ref('hnh_dim_gl_period')
        format: sql
        rows: |
          select toInt32(p) as period_key, toUInt16(y) as fiscal_year, toDate(d) as start_date
          from values('p UInt32, y UInt16, d String', (202601, 2026, '2026-01-01'), (202602, 2026, '2026-02-01'),
                      (202603, 2026, '2026-03-01'), (202701, 2027, '2027-01-01'))
    expect:
      rows:
        - {balance_view: posted, gl_account_key: 10, period_key: 202601, period_movement: 100, period_movement_excl_opening: 100, opening_balance: 0, closing_balance: 100}
        - {balance_view: posted, gl_account_key: 10, period_key: 202602, period_movement: 0, period_movement_excl_opening: 0, opening_balance: 100, closing_balance: 100}
        - {balance_view: posted, gl_account_key: 10, period_key: 202603, period_movement: 0, period_movement_excl_opening: 0, opening_balance: 100, closing_balance: 100}
        - {balance_view: posted, gl_account_key: 10, period_key: 202701, period_movement: 0, period_movement_excl_opening: 0, opening_balance: 100, closing_balance: 100}
        - {balance_view: posted, gl_account_key: 20, period_key: 202601, period_movement: -100, period_movement_excl_opening: 0, opening_balance: 0, closing_balance: -100}
        - {balance_view: posted, gl_account_key: 20, period_key: 202602, period_movement: -50, period_movement_excl_opening: -50, opening_balance: -100, closing_balance: -150}
        - {balance_view: posted, gl_account_key: 20, period_key: 202603, period_movement: 0, period_movement_excl_opening: 0, opening_balance: -150, closing_balance: -150}
        - {balance_view: posted, gl_account_key: 20, period_key: 202701, period_movement: -10, period_movement_excl_opening: -10, opening_balance: 0, closing_balance: -10}
        - {balance_view: posted, gl_account_key: 8342949216454285929, period_key: 202701, period_movement: 0, period_movement_excl_opening: 0, opening_balance: -150, closing_balance: -150}
        - {balance_view: including_unposted, gl_account_key: 10, period_key: 202601, period_movement: 100, period_movement_excl_opening: 100, opening_balance: 0, closing_balance: 100}
        - {balance_view: including_unposted, gl_account_key: 10, period_key: 202602, period_movement: 0, period_movement_excl_opening: 0, opening_balance: 100, closing_balance: 100}
        - {balance_view: including_unposted, gl_account_key: 10, period_key: 202603, period_movement: -30, period_movement_excl_opening: -30, opening_balance: 100, closing_balance: 70}
        - {balance_view: including_unposted, gl_account_key: 10, period_key: 202701, period_movement: 0, period_movement_excl_opening: 0, opening_balance: 70, closing_balance: 70}
        - {balance_view: including_unposted, gl_account_key: 20, period_key: 202601, period_movement: -100, period_movement_excl_opening: 0, opening_balance: 0, closing_balance: -100}
        - {balance_view: including_unposted, gl_account_key: 20, period_key: 202602, period_movement: -50, period_movement_excl_opening: -50, opening_balance: -100, closing_balance: -150}
        - {balance_view: including_unposted, gl_account_key: 20, period_key: 202603, period_movement: 0, period_movement_excl_opening: 0, opening_balance: -150, closing_balance: -150}
        - {balance_view: including_unposted, gl_account_key: 20, period_key: 202701, period_movement: -10, period_movement_excl_opening: -10, opening_balance: 0, closing_balance: -10}
        - {balance_view: including_unposted, gl_account_key: 8342949216454285929, period_key: 202701, period_movement: 0, period_movement_excl_opening: 0, opening_balance: -150, closing_balance: -150}
```

`hnh_dwh/tests/hnh/assert_gl_trial_balance_zero.sql`:

```sql
-- Posted balances of a branch sum to zero in every period (prior-year roll included).
select branch_key, period_key, round(sum(closing_balance), 2) as out_of_balance
from {{ ref('fact_gl_balance_monthly') }}
where balance_view = 'posted'
group by branch_key, period_key
having abs(sum(closing_balance)) > 0.01
```

Append to `_finance_marts__models.yml`:

```yaml
  - name: fact_gl_balance_monthly
    description: >
      Code combination × period × balance view (posted, including_unposted), densified from the account's first
      posting to the latest period with a posting or already started. Opening and closing balances stored.
    tests:
      - hnh_unique_combination:
          columns: [balance_view, gl_account_key, period_key]
    columns:
      - name: balance_view
        tests:
          - accepted_values:
              values: ['posted', 'including_unposted']
      - name: gl_account_key
        tests:
          - relationships: {to: ref('hnh_dim_gl_account'), field: gl_account_key}
      - name: period_key
        tests:
          - relationships: {to: ref('hnh_dim_gl_period'), field: period_key}
```

Run: `python scripts/run_dbt.py test --no-partial-parse --select fact_gl_balance_monthly_densifies_and_rolls_years`
Expected: FAIL — model not found.

- [ ] **Step 2: Write the model**

`fact_gl_balance_monthly.sql`:

```sql
{{ config(order_by='(branch_key, gl_account_key, period_key, balance_view)') }}

with lines as (
    select branch_key, gl_account_key, period_key, is_posted, is_opening_balance_journal, debit, credit
    from {{ ref('hnh_fact_gl_journal_line') }}
),

viewed as (
    select 'posted' as balance_view, branch_key, gl_account_key, period_key, is_opening_balance_journal, debit, credit
    from lines where is_posted = 1
    union all
    select 'including_unposted' as balance_view, branch_key, gl_account_key, period_key, is_opening_balance_journal, debit, credit
    from lines
),

movement as (
    select balance_view, branch_key, gl_account_key, period_key,
           sum(debit)                                           as m_debit,
           sum(credit)                                          as m_credit,
           sum(debit - credit)                                  as m_movement,
           sumIf(debit - credit, is_opening_balance_journal = 0) as m_movement_excl_opening
    from viewed
    group by balance_view, branch_key, gl_account_key, period_key
),

periods as (
    -- up to the latest period that has a posting or has already started
    select period_key, fiscal_year
    from {{ ref('hnh_dim_gl_period') }}
    where period_key <= greatest(
        (select max(period_key) from movement),
        (select max(period_key) from {{ ref('hnh_dim_gl_period') }} where start_date <= today()))
),

first_seen as (
    select balance_view, branch_key, gl_account_key, min(period_key) as first_period_key
    from movement
    group by balance_view, branch_key, gl_account_key
),

grid as (
    select f.balance_view as balance_view, f.branch_key as branch_key, f.gl_account_key as gl_account_key,
           p.period_key as period_key, p.fiscal_year as fiscal_year
    from first_seen as f
    cross join periods as p
    where p.period_key >= f.first_period_key
),

filled as (
    select g.balance_view as balance_view, g.branch_key as branch_key, g.gl_account_key as gl_account_key,
           g.period_key as period_key, g.fiscal_year as fiscal_year, ifNull(a.balance_side, 'IS') as balance_side,
           ifNull(m.m_debit, 0) as period_debit, ifNull(m.m_credit, 0) as period_credit,
           ifNull(m.m_movement, 0) as period_movement, ifNull(m.m_movement_excl_opening, 0) as period_movement_excl_opening
    from grid as g
    left join movement as m
        on m.balance_view = g.balance_view and m.gl_account_key = g.gl_account_key and m.period_key = g.period_key
    left join (select gl_account_key, balance_side from {{ ref('hnh_dim_gl_account') }}) as a on a.gl_account_key = g.gl_account_key
),

balances as (
    select *,
           sum(period_movement) over (
               partition by balance_view, gl_account_key, if(balance_side = 'IS', fiscal_year, 0)
               order by period_key rows between unbounded preceding and current row) as closing_balance
    from filled
),

branch_years as (
    select balance_view, branch_key, fiscal_year,
           sumIf(period_movement, balance_side = 'IS') as year_result
    from filled
    group by balance_view, branch_key, fiscal_year
),

prior_results as (
    select balance_view, branch_key, fiscal_year,
           sum(year_result) over (partition by balance_view, branch_key order by fiscal_year
                                  rows between unbounded preceding and 1 preceding) as prior_result
    from branch_years
),

roll as (
    -- the income-statement result of earlier years, carried on the branch's prior-year roll account
    select bp.balance_view as balance_view, bp.branch_key as branch_key, bp.period_key as period_key,
           bp.fiscal_year as fiscal_year, r.prior_result as prior_result
    from (select distinct balance_view, branch_key, period_key, fiscal_year from grid) as bp
    inner join prior_results as r
        on r.balance_view = bp.balance_view and r.branch_key = bp.branch_key and r.fiscal_year = bp.fiscal_year
    where abs(r.prior_result) > 0.000001
)

select balance_view, branch_key, gl_account_key, period_key, fiscal_year, toUInt8(0) as is_prior_year_roll,
       closing_balance - period_movement as opening_balance, period_debit, period_credit, period_movement,
       period_movement_excl_opening, closing_balance, now() as _loaded_at
from balances

union all

select balance_view, branch_key, {{ hnh_prior_year_results_key('branch_key') }} as gl_account_key, period_key, fiscal_year,
       toUInt8(1), prior_result, toFloat64(0), toFloat64(0), toFloat64(0), toFloat64(0), prior_result, now()
from roll
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the unit test and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select fact_gl_balance_monthly assert_gl_trial_balance_zero`
Expected: unit test PASS, model built (under 0.5M rows), relationships, uniqueness and trial balance PASS.

If the trial balance fails for a branch, list the period: posted journals were measured balanced per ledger on 2026-10-05; a failure means a posted journal line reached the wrong branch or period — check `assert_fact_gl_journal_line_matches_staging` first.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/finance/ hnh_dwh/tests/hnh/assert_gl_trial_balance_zero.sql
git commit -m "Add monthly GL balances with posted and unposted views and the prior-year roll"
```

---

### Task 8: Budget and the income statement against budget

**Files:**
- Create: `hnh_dwh/models/hnh/marts/finance/fact_budget_monthly.sql`, `fact_income_statement_monthly.sql`
- Modify: `_finance_marts__models.yml`, `_finance_marts_unit_tests.yml`

**Interfaces:**
- Consumes: `stg_ref__income_statement_budget`, `dim_budget_line` (budget_line_code, is_subtotal), `hnh_fact_gl_journal_line` (branch_key, gl_account_key, period_key, is_posted, is_opening_balance_journal, amount), `hnh_dim_gl_account` (gl_account_key, balance_side, budget_line_code, revenue_care_type, fs_line_key), `dim_fs_line` (fs_line_key, statement_group), `hnh_dim_gl_period` (period_key, end_date); macros `hnh_budget_natural_side`, `hnh_budget_subtotal_weights`.
- Produces:
  - `fact_budget_monthly(budget_month_key, branch_key, budget_line_key, budget_line_code, is_subtotal, scenario, month_start, month_date_key, budget_amount, _loaded_at)`
  - `fact_income_statement_monthly(income_statement_key, branch_key, month_start, month_date_key, budget_line_key, budget_line_code, revenue_care_type, statement_group, actual_posted, actual_including_unposted, actual_excl_opening, budget_most_likely, budget_worst_case, _loaded_at)`

- [ ] **Step 1: Write the failing unit test and YAML tests**

Append to `_finance_marts_unit_tests.yml`:

```yaml
  - name: fact_income_statement_monthly_matches_budget_and_subtotals
    description: >
      Branch 1, January 2026. Account 1: OP revenue credit 1,000. Account 2: contractual discount (debit 100) on an
      OP revenue code, so REV_OP actual is 900. Account 3: employee cost debit 300, unposted (0 posted, 300 including
      unposted). Account 4: unbudgeted other income credit 50, inside EBITDA. Budget: REV_OP 800, DC_EMPLOYEE 200; the
      file's own EBITDA row and a superseded REV_OP version are ignored. Subtotals follow the G12 formulas.
    model: fact_income_statement_monthly
    given:
      - input: ref('hnh_fact_gl_journal_line')
        format: sql
        rows: |
          select toUInt8(1) as branch_key, toInt64(a) as gl_account_key, toInt32(202601) as period_key, toUInt8(ps) as is_posted,
                 toUInt8(0) as is_opening_balance_journal, toFloat64(amt) as amount
          from values('a UInt32, ps UInt8, amt Float64', (1, 1, -1000), (2, 1, 100), (3, 0, 300), (4, 1, -50))
      - input: ref('hnh_dim_gl_account')
        format: sql
        rows: |
          select toInt64(a) as gl_account_key, 'IS' as balance_side, toNullable(c) as budget_line_code, ct as revenue_care_type, toInt64(f) as fs_line_key
          from values('a UInt32, c String, ct String, f UInt32', (1, 'REV_OP', 'OP', 91), (2, 'REV_OP', 'OP', 92),
                      (3, 'DC_EMPLOYEE', 'Unallocated', 93), (4, 'UNBUDGETED', 'Unallocated', 94))
      - input: ref('dim_fs_line')
        format: sql
        rows: |
          select toInt64(f) as fs_line_key, g as statement_group
          from values('f UInt32, g String', (91, 'Revenue'), (92, 'Revenue discounts'), (93, 'Direct cost'), (94, 'Other income'))
      - input: ref('hnh_dim_gl_period')
        format: sql
        rows: |
          select toInt32(202601) as period_key, toDate('2026-01-31') as end_date
      - input: ref('stg_ref__income_statement_budget')
        format: sql
        rows: |
          select toUInt32(id) as id, toUInt8(1) as branch_id, toUInt16(2026) as fiscal_year, 'most_likely' as scenario, code as line_item_code,
                 toFloat64(m1) as month_1, toFloat64(0) as month_2, toFloat64(0) as month_3, toFloat64(0) as month_4,
                 toFloat64(0) as month_5, toFloat64(0) as month_6, toFloat64(0) as month_7, toFloat64(0) as month_8, toFloat64(0) as month_9,
                 toFloat64(0) as month_10, toFloat64(0) as month_11, toFloat64(0) as month_12, toUInt8(lt) as is_latest
          from values('id UInt32, code String, m1 Float64, lt UInt8', (1, 'REV_OP', 800, 1), (2, 'DC_EMPLOYEE', 200, 1),
                      (3, 'EBITDA', 999, 1), (4, 'REV_OP', 5000, 0))
      - input: ref('dim_budget_line')
        format: sql
        rows: |
          select c as budget_line_code, toUInt8(s) as is_subtotal
          from values('c String, s UInt8', ('REV_OP', 0), ('DC_EMPLOYEE', 0), ('EBITDA', 1), ('UNBUDGETED', 0))
    expect:
      rows:
        - {budget_line_code: REV_OP, revenue_care_type: OP, actual_posted: 900, actual_including_unposted: 900, budget_most_likely: 800}
        - {budget_line_code: DC_EMPLOYEE, revenue_care_type: All, actual_posted: 0, actual_including_unposted: 300, budget_most_likely: 200}
        - {budget_line_code: UNBUDGETED, revenue_care_type: All, actual_posted: 50, actual_including_unposted: 50, budget_most_likely: 0}
        - {budget_line_code: REV_SUB, revenue_care_type: All, actual_posted: 900, actual_including_unposted: 900, budget_most_likely: 800}
        - {budget_line_code: REV_NET, revenue_care_type: All, actual_posted: 900, actual_including_unposted: 900, budget_most_likely: 800}
        - {budget_line_code: TOTAL_DC, revenue_care_type: All, actual_posted: 0, actual_including_unposted: 300, budget_most_likely: 200}
        - {budget_line_code: GROSS_PROFIT, revenue_care_type: All, actual_posted: 900, actual_including_unposted: 600, budget_most_likely: 600}
        - {budget_line_code: EBITDA, revenue_care_type: All, actual_posted: 950, actual_including_unposted: 650, budget_most_likely: 600}
        - {budget_line_code: NET_PROFIT, revenue_care_type: All, actual_posted: 950, actual_including_unposted: 650, budget_most_likely: 600}
        - {budget_line_code: TOTAL_COMP_INCOME, revenue_care_type: All, actual_posted: 950, actual_including_unposted: 650, budget_most_likely: 600}
```

Append to `_finance_marts__models.yml`:

```yaml
  - name: fact_budget_monthly
    tests:
      - hnh_unique_combination:
          columns: [branch_key, budget_line_code, scenario, month_start]
    columns:
      - name: budget_line_key
        tests:
          - relationships: {to: ref('dim_budget_line'), field: budget_line_key}
  - name: fact_income_statement_monthly
    tests:
      - hnh_unique_combination:
          columns: [branch_key, month_start, budget_line_code, revenue_care_type, statement_group]
    columns:
      - name: budget_line_key
        tests:
          - relationships: {to: ref('dim_budget_line'), field: budget_line_key}
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
```

Run: `python scripts/run_dbt.py test --no-partial-parse --select fact_income_statement_monthly_matches_budget_and_subtotals`
Expected: FAIL — model not found.

- [ ] **Step 2: Write `fact_budget_monthly`**

```sql
{{ config(order_by='(branch_key, month_start, budget_line_code, scenario)') }}

with unpivoted as (
    select
        b.branch_id as branch_id, b.fiscal_year as fiscal_year, b.scenario as scenario, b.line_item_code as line_item_code,
        toUInt8(tupleElement(m_t, 1)) as month_no, tupleElement(m_t, 2) as amount
    from {{ ref('stg_ref__income_statement_budget') }} as b
    array join arrayMap(i -> tuple(i, [b.month_1, b.month_2, b.month_3, b.month_4, b.month_5, b.month_6, b.month_7, b.month_8,
                                       b.month_9, b.month_10, b.month_11, b.month_12][i]), range(1, 13)) as m_t
    where b.is_latest = 1
)

select
    {{ hnh_surrogate_key(['u.branch_id', 'u.line_item_code', 'u.scenario', 'u.fiscal_year', 'u.month_no']) }} as budget_month_key,
    u.branch_id                                         as branch_key,
    {{ hnh_surrogate_key(['u.line_item_code']) }}       as budget_line_key,
    u.line_item_code                                    as budget_line_code,
    ifNull(l.is_subtotal, toUInt8(0))                   as is_subtotal,
    u.scenario                                          as scenario,
    makeDate(u.fiscal_year, u.month_no, 1)              as month_start,
    {{ hnh_date_key('makeDate(u.fiscal_year, u.month_no, 1)') }} as month_date_key,
    u.amount                                            as budget_amount,
    now()                                               as _loaded_at
from unpivoted as u
left join (select budget_line_code, is_subtotal from {{ ref('dim_budget_line') }}) as l on l.budget_line_code = u.line_item_code
{{ hnh_settings() }}
```


- [ ] **Step 3: Write `fact_income_statement_monthly`**

```sql
{{ config(order_by='(branch_key, month_start, budget_line_code, revenue_care_type, statement_group)') }}

with actual_lines as (
    select
        j.branch_key                                                        as branch_key,
        toStartOfMonth(p.end_date)                                          as month_start,
        ifNull(a.budget_line_code, 'UNBUDGETED')                            as budget_line_code,
        if(ifNull(a.budget_line_code, '') in ('REV_OP', 'REV_IP', 'REV_ER', 'REV_UNALLOCATED'), a.revenue_care_type, 'All') as revenue_care_type,
        if(ifNull(a.budget_line_code, 'UNBUDGETED') = 'UNBUDGETED', ifNull(f.statement_group, 'Not mapped expenses'), '') as statement_group,
        j.is_posted                                                         as is_posted,
        j.is_opening_balance_journal                                        as is_opening_balance_journal,
        j.amount                                                            as amount
    from {{ ref('hnh_fact_gl_journal_line') }} as j
    inner join (
        select gl_account_key, balance_side, budget_line_code, revenue_care_type, fs_line_key
        from {{ ref('hnh_dim_gl_account') }} where balance_side = 'IS'
    ) as a on a.gl_account_key = j.gl_account_key
    left join (select fs_line_key, statement_group from {{ ref('dim_fs_line') }}) as f on f.fs_line_key = a.fs_line_key
    inner join (select period_key, end_date from {{ ref('hnh_dim_gl_period') }}) as p on p.period_key = j.period_key
),

actuals as (
    select branch_key, month_start, budget_line_code, revenue_care_type, statement_group,
           -- natural side: credit codes are credit - debit, debit codes debit - credit
           sumIf(if({{ hnh_budget_natural_side('budget_line_code', 'statement_group') }} = 'credit', -amount, amount), is_posted = 1) as actual_posted,
           sum(if({{ hnh_budget_natural_side('budget_line_code', 'statement_group') }} = 'credit', -amount, amount))                  as actual_including_unposted,
           sumIf(if({{ hnh_budget_natural_side('budget_line_code', 'statement_group') }} = 'credit', -amount, amount), is_opening_balance_journal = 0) as actual_excl_opening,
           toFloat64(0) as budget_most_likely, toFloat64(0) as budget_worst_case
    from actual_lines
    group by branch_key, month_start, budget_line_code, revenue_care_type, statement_group
),

budget_months as (
    select
        b.branch_id as branch_key, b.scenario as scenario, b.line_item_code as budget_line_code,
        makeDate(b.fiscal_year, toUInt8(tupleElement(m_t, 1)), 1) as month_start, tupleElement(m_t, 2) as amount
    from {{ ref('stg_ref__income_statement_budget') }} as b
    array join arrayMap(i -> tuple(i, [b.month_1, b.month_2, b.month_3, b.month_4, b.month_5, b.month_6, b.month_7, b.month_8,
                                       b.month_9, b.month_10, b.month_11, b.month_12][i]), range(1, 13)) as m_t
    where b.is_latest = 1
      and b.line_item_code in (select budget_line_code from {{ ref('dim_budget_line') }} where is_subtotal = 0)
),

budgets as (
    select branch_key, month_start, budget_line_code,
           if(budget_line_code in ('REV_OP', 'REV_IP', 'REV_ER'), replaceOne(budget_line_code, 'REV_', ''), 'All') as revenue_care_type,
           '' as statement_group,
           toFloat64(0) as actual_posted, toFloat64(0) as actual_including_unposted, toFloat64(0) as actual_excl_opening,
           sumIf(amount, scenario = 'most_likely') as budget_most_likely,
           sumIf(amount, scenario = 'worst_case')  as budget_worst_case
    from budget_months
    where amount != 0
    group by branch_key, month_start, budget_line_code
),

detail as (
    select branch_key, month_start, budget_line_code, revenue_care_type, statement_group,
           sum(actual_posted) as actual_posted, sum(actual_including_unposted) as actual_including_unposted,
           sum(actual_excl_opening) as actual_excl_opening, sum(budget_most_likely) as budget_most_likely,
           sum(budget_worst_case) as budget_worst_case
    from (select * from actuals union all select * from budgets)
    group by branch_key, month_start, budget_line_code, revenue_care_type, statement_group
),

weights as ({{ hnh_budget_subtotal_weights() }}),

subtotals as (
    select d.branch_key as branch_key, d.month_start as month_start, w.subtotal_code as budget_line_code,
           'All' as revenue_care_type, '' as statement_group,
           sum(d.actual_posted * w.weight)             as actual_posted,
           sum(d.actual_including_unposted * w.weight) as actual_including_unposted,
           sum(d.actual_excl_opening * w.weight)       as actual_excl_opening,
           sum(d.budget_most_likely * w.weight)        as budget_most_likely,
           sum(d.budget_worst_case * w.weight)         as budget_worst_case
    from detail as d
    inner join weights as w on w.component_code = d.budget_line_code
    where w.component_group = '' or w.component_group = d.statement_group
    group by d.branch_key, d.month_start, w.subtotal_code
),

all_rows as (
    select * from detail
    union all
    select * from subtotals
)

select
    {{ hnh_surrogate_key(['branch_key', 'month_start', 'budget_line_code', 'revenue_care_type', 'statement_group']) }} as income_statement_key,
    branch_key,
    month_start,
    {{ hnh_date_key('month_start') }}               as month_date_key,
    {{ hnh_surrogate_key(['budget_line_code']) }}   as budget_line_key,
    budget_line_code,
    revenue_care_type,
    statement_group,
    actual_posted,
    actual_including_unposted,
    actual_excl_opening,
    budget_most_likely,
    budget_worst_case,
    now()                                           as _loaded_at
from all_rows
{{ hnh_settings() }}
```

- [ ] **Step 4: Run the unit test and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select fact_budget_monthly fact_income_statement_monthly`
Expected: unit test PASS, both models built, uniqueness and relationships PASS.

Spot-check against the file (branch 1, most likely, FY2026): `select budget_line_code, round(sum(budget_most_likely)/1e6, 3) from gold.fact_income_statement_monthly where branch_key = 1 and budget_line_code in ('REV_NET','EBITDA','NET_PROFIT') group by 1` — expect 346.464, 96.317, 61.982.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/marts/finance/
git commit -m "Add the budget fact and the income statement against budget with one subtotal rule set"
```

---

### Task 9: Payables facts

**Files:**
- Create: `hnh_dwh/models/hnh/marts/finance/fact_ap_invoice_line.sql`, `hnh_fact_ap_payment.sql`, `fact_ap_open_item.sql`
- Modify: `_finance_marts__models.yml`, `_finance_marts_unit_tests.yml`

**Interfaces:**
- Consumes: `stg_fusion__ap_invoice_distributions`, `stg_fusion__ap_payments`, `stg_fusion__ap_payment_schedules`, `stg_fusion__business_units`, `hnh_dim_gl_account` (gl_account_key, code_combination_id), `hnh_dim_branch` (branch_key, fusion_ledger_id), `hnh_dim_supplier` (supplier_key); `hnh_gl_period_key_for_date`, `hnh_ageing_bucket`.
- Produces:
  - `fact_ap_invoice_line(ap_invoice_line_key, branch_key, supplier_key, gl_account_key, invoice_date_key, accounting_date_key, period_key, invoice_id, invoice_num, invoice_type, line_type, is_posted, is_cancelled, is_reversal, is_po_matched, amount, spend_amount, tax_amount, prepayment_amount, _loaded_at)`
  - `hnh_fact_ap_payment` (alias `fact_ap_payment`): `ap_payment_key, branch_key, supplier_key, payment_date_key, bank_account_id, invoice_id, payment_num, check_number, payment_method, payment_status, is_voided, is_posted, amount, days_invoice_to_payment, days_after_due, _loaded_at`
  - `fact_ap_open_item(ap_open_item_key, branch_key, supplier_key, invoice_date_key, due_date_key, invoice_id, invoice_num, invoice_type, approval_status, payment_status, is_on_hold, is_cancelled, ageing_bucket, snapshot_date, gross_amount, amount_remaining, days_overdue, _loaded_at)`

- [ ] **Step 1: Write the failing unit tests and YAML tests**

Append to `_finance_marts_unit_tests.yml`:

```yaml
  - name: fact_ap_invoice_line_splits_spend_and_tax
    description: >
      Invoice 10: an item line of 100, its cancelling reversal of -100 and a recoverable tax line of 15 (spend nets
      to zero, tax stays). Invoice 11: a prepayment application of -40. The supplier site 9 is unknown (-1).
    model: fact_ap_invoice_line
    given:
      - input: ref('stg_fusion__ap_invoice_distributions')
        format: sql
        rows: |
          select toInt64(d) as invoice_distribution_id, toNullable(toInt64(inv)) as invoice_id, toNullable(toString(inv)) as invoice_num,
                 toNullable(lt) as line_type, cast(null as Nullable(Int64)) as po_distribution_id, toUInt8(1) as is_posted,
                 toUInt8(c) as is_cancelled, toUInt8(c) as is_reversal, toNullable(it) as invoice_type_code,
                 toNullable(toInt64(5)) as vendor_id, toNullable(toInt64(vs)) as vendor_site_id,
                 toNullable(toInt64(300000005003384)) as ledger_id, toNullable(toInt64(10)) as code_combination_id,
                 toNullable(toDate('2026-05-01')) as invoice_date, toNullable(toDate('2026-05-03')) as accounting_date, toFloat64(amt) as amount
          from values('d UInt32, inv UInt32, lt String, c UInt8, it String, vs UInt32, amt Float64',
              (1, 10, 'ITEM', 0, 'STANDARD', 7, 100), (2, 10, 'ITEM', 1, 'STANDARD', 7, -100), (3, 10, 'REC_TAX', 0, 'STANDARD', 7, 15),
              (4, 11, 'PREPAY', 0, 'STANDARD', 9, -40))
      - input: ref('hnh_dim_gl_account')
        format: sql
        rows: |
          select toInt64(555) as gl_account_key, toNullable(toInt64(10)) as code_combination_id
      - input: ref('hnh_dim_branch')
        format: sql
        rows: |
          select toUInt8(6) as branch_key, toNullable(toInt64(300000005003384)) as fusion_ledger_id
      - input: ref('hnh_dim_supplier')
        format: sql
        rows: |
          select toInt64(8962314910422976638) as supplier_key  -- hnh_surrogate_key of vendor 5, site 7
    expect:
      rows:
        - {invoice_id: 10, line_type: ITEM, branch_key: 6, gl_account_key: 555, period_key: 202606, invoice_type: Standard, spend_amount: 100, tax_amount: 0, prepayment_amount: 0, is_cancelled: 0}
        - {invoice_id: 10, line_type: ITEM, branch_key: 6, gl_account_key: 555, period_key: 202606, invoice_type: Standard, spend_amount: -100, tax_amount: 0, prepayment_amount: 0, is_cancelled: 1}
        - {invoice_id: 10, line_type: REC_TAX, branch_key: 6, gl_account_key: 555, period_key: 202606, invoice_type: Standard, spend_amount: 0, tax_amount: 15, prepayment_amount: 0, is_cancelled: 0}
        - {invoice_id: 11, line_type: PREPAY, branch_key: 6, gl_account_key: 555, period_key: 202606, invoice_type: Standard, spend_amount: 0, tax_amount: 0, prepayment_amount: -40, is_cancelled: 0}

  - name: fact_ap_open_item_ages_open_invoices
    description: >
      Invoice 1 is 45 days past due (31-60). Invoice 2 is paid (Settled, 0 days). Invoice 3 is due in 10 days
      (Not due). Invoice 4 is cancelled (Settled). Dates are relative to today, as the snapshot is.
    model: fact_ap_open_item
    given:
      - input: ref('stg_fusion__ap_payment_schedules')
        format: sql
        rows: |
          select toInt64(inv) as invoice_id, toNullable(toInt64(1)) as payment_num, toNullable(toInt64(5)) as vendor_id,
                 toNullable(toInt64(7)) as vendor_site_id, toNullable(toString(inv)) as invoice_num, toNullable('STANDARD') as invoice_type_code,
                 toNullable('APPROVED') as approval_status, toNullable(ps) as payment_status_flag, toUInt8(0) as is_on_hold,
                 toNullable(today() - 60) as invoice_date, if(cx = 1, toNullable(today() - 5), cast(null as Nullable(Date))) as cancelled_date,
                 toNullable(toInt64(300000005006010)) as business_unit_id, toNullable(today() + toIntervalDay(due)) as due_date,
                 toNullable('SAR') as currency_code, toFloat64(100) as gross_amount, toFloat64(rem) as amount_remaining
          from values('inv UInt32, ps String, cx UInt8, due Int32, rem Float64',
              (1, 'N', 0, -45, 100), (2, 'Y', 0, -45, 0), (3, 'N', 0, 10, 50), (4, 'N', 1, -45, 100))
      - input: ref('stg_fusion__business_units')
        format: sql
        rows: |
          select toInt64(300000005006010) as business_unit_id, toNullable(toInt64(300000005003384)) as primary_ledger_id
      - input: ref('hnh_dim_branch')
        format: sql
        rows: |
          select toUInt8(6) as branch_key, toNullable(toInt64(300000005003384)) as fusion_ledger_id
      - input: ref('hnh_dim_supplier')
        format: sql
        rows: |
          select toInt64(8962314910422976638) as supplier_key  -- hnh_surrogate_key of vendor 5, site 7
    expect:
      rows:
        - {invoice_id: 1, branch_key: 6, ageing_bucket: 31-60, days_overdue: 45, payment_status: Unpaid, is_cancelled: 0}
        - {invoice_id: 2, branch_key: 6, ageing_bucket: Settled, days_overdue: 0, payment_status: Paid, is_cancelled: 0}
        - {invoice_id: 3, branch_key: 6, ageing_bucket: Not due, days_overdue: 0, payment_status: Unpaid, is_cancelled: 0}
        - {invoice_id: 4, branch_key: 6, ageing_bucket: Settled, days_overdue: 0, payment_status: Unpaid, is_cancelled: 1}

  - name: hnh_fact_ap_payment_measures_days
    description: Paid on 2026-06-10 an invoice of 2026-05-01 due on 2026-06-01 (40 days, 9 days late). A voided payment is flagged.
    model: hnh_fact_ap_payment
    given:
      - input: ref('stg_fusion__ap_payments')
        format: sql
        rows: |
          select toInt64(p) as invoice_payment_id, toNullable(toInt64(1)) as invoice_id, toNullable(toInt64(1)) as payment_num,
                 toNullable(toInt64(9001)) as check_number, toNullable('CHECK') as payment_method, toNullable(st) as payment_status,
                 toUInt8(1) as is_posted, toNullable(toInt64(5)) as vendor_id, toNullable(toInt64(7)) as vendor_site_id,
                 toNullable(toInt64(300000005003384)) as ledger_id, toNullable(toInt64(44)) as bank_account_id,
                 toNullable(toDate('2026-06-10')) as payment_date, toFloat64(250) as amount
          from values('p UInt32, st String', (1, 'NEGOTIABLE'), (2, 'VOIDED'))
      - input: ref('stg_fusion__ap_payment_schedules')
        format: sql
        rows: |
          select toInt64(1) as invoice_id, toNullable(toDate('2026-05-01')) as invoice_date, toNullable(toDate('2026-06-01')) as due_date
      - input: ref('hnh_dim_branch')
        format: sql
        rows: |
          select toUInt8(6) as branch_key, toNullable(toInt64(300000005003384)) as fusion_ledger_id
      - input: ref('hnh_dim_supplier')
        format: sql
        rows: |
          select toInt64(8962314910422976638) as supplier_key  -- hnh_surrogate_key of vendor 5, site 7
    expect:
      rows:
        - {invoice_payment_id: 1, branch_key: 6, is_voided: 0, days_invoice_to_payment: 40, days_after_due: 9}
        - {invoice_payment_id: 2, branch_key: 6, is_voided: 1, days_invoice_to_payment: 40, days_after_due: 9}
```

(The payment fact keeps `invoice_payment_id` as an attribute for this test and drill-through.)

Append to `_finance_marts__models.yml`:

```yaml
  - name: fact_ap_invoice_line
    columns:
      - name: ap_invoice_line_key
        tests: [unique, not_null]
      - name: supplier_key
        tests:
          - relationships: {to: ref('hnh_dim_supplier'), field: supplier_key}
      - name: gl_account_key
        tests:
          - relationships: {to: ref('hnh_dim_gl_account'), field: gl_account_key}
      - name: period_key
        tests:
          - relationships: {to: ref('hnh_dim_gl_period'), field: period_key}
  - name: hnh_fact_ap_payment
    columns:
      - name: ap_payment_key
        tests: [unique, not_null]
      - name: supplier_key
        tests:
          - relationships: {to: ref('hnh_dim_supplier'), field: supplier_key}
  - name: fact_ap_open_item
    columns:
      - name: ap_open_item_key
        tests: [unique, not_null]
      - name: ageing_bucket
        tests:
          - accepted_values:
              values: ['Settled', 'Not due', '1-30', '31-60', '61-90', '91-180', 'Over 180']
```

Run: `python scripts/run_dbt.py test --no-partial-parse --select fact_ap_invoice_line_splits_spend_and_tax fact_ap_open_item_ages_open_invoices hnh_fact_ap_payment_measures_days`
Expected: FAIL — models not found.

- [ ] **Step 2: Write the three facts**

`fact_ap_invoice_line.sql`:

```sql
{{ config(order_by='(branch_key, accounting_date_key_nn, ap_invoice_line_key)') }}

select
    {{ hnh_surrogate_key(['d.invoice_distribution_id']) }}      as ap_invoice_line_key,
    ifNull(b.branch_key, toUInt8(0))                            as branch_key,
    ifNull(s.supplier_key, toInt64(-1))                         as supplier_key,
    ifNull(a.gl_account_key, toInt64(-1))                       as gl_account_key,
    {{ hnh_date_key_in_range('d.invoice_date') }}               as invoice_date_key,
    {{ hnh_date_key_in_range('d.accounting_date') }}            as accounting_date_key,
    ifNull({{ hnh_date_key_in_range('d.accounting_date') }}, 0) as accounting_date_key_nn,
    ifNull({{ hnh_gl_period_key_for_date('d.accounting_date') }}, toInt32(0)) as period_key,
    d.invoice_id                                                as invoice_id,
    d.invoice_num                                               as invoice_num,
    multiIf(d.invoice_type_code = 'STANDARD', 'Standard', d.invoice_type_code = 'CREDIT', 'Credit memo',
            d.invoice_type_code = 'PREPAYMENT', 'Prepayment', ifNull(d.invoice_type_code, 'Unknown')) as invoice_type,
    d.line_type                                                 as line_type,
    d.is_posted                                                 as is_posted,
    d.is_cancelled                                              as is_cancelled,
    d.is_reversal                                               as is_reversal,
    toUInt8(d.po_distribution_id is not null)                   as is_po_matched,
    d.amount                                                    as amount,
    if(ifNull(d.line_type, '') in ('ITEM', 'ACCRUAL', 'IPV', 'TRV', 'ERV', 'FREIGHT', 'MISCELLANEOUS'), d.amount, 0) as spend_amount,
    if(ifNull(d.line_type, '') in ('REC_TAX', 'NONREC_TAX'), d.amount, 0)                                         as tax_amount,
    if(ifNull(d.line_type, '') = 'PREPAY', d.amount, 0)                                                           as prepayment_amount,
    now()                                                       as _loaded_at
from {{ ref('stg_fusion__ap_invoice_distributions') }} as d
left join (select gl_account_key, code_combination_id from {{ ref('hnh_dim_gl_account') }} where code_combination_id is not null) as a
    on a.code_combination_id = d.code_combination_id
left join (select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null) as b
    on b.fusion_ledger_id = d.ledger_id
left join (select supplier_key from {{ ref('hnh_dim_supplier') }}) as s
    on s.supplier_key = {{ hnh_surrogate_key(['d.vendor_id', 'd.vendor_site_id']) }}
{{ hnh_settings() }}
```

`hnh_fact_ap_payment.sql`:

```sql
{{ config(alias='fact_ap_payment', order_by='(branch_key, payment_date_key_nn, ap_payment_key)') }}

select
    {{ hnh_surrogate_key(['p.invoice_payment_id']) }}           as ap_payment_key,
    p.invoice_payment_id                                        as invoice_payment_id,
    ifNull(b.branch_key, toUInt8(0))                            as branch_key,
    ifNull(s.supplier_key, toInt64(-1))                         as supplier_key,
    {{ hnh_date_key_in_range('p.payment_date') }}               as payment_date_key,
    ifNull({{ hnh_date_key_in_range('p.payment_date') }}, 0)    as payment_date_key_nn,
    p.bank_account_id                                           as bank_account_id,
    p.invoice_id                                                as invoice_id,
    p.payment_num                                               as payment_num,
    p.check_number                                              as check_number,
    p.payment_method                                            as payment_method,
    p.payment_status                                            as payment_status,
    toUInt8(ifNull(p.payment_status, '') = 'VOIDED')            as is_voided,
    p.is_posted                                                 as is_posted,
    p.amount                                                    as amount,
    if(sc.invoice_date is null or p.payment_date is null, cast(null as Nullable(Int64)),
       dateDiff('day', assumeNotNull(sc.invoice_date), assumeNotNull(p.payment_date)))  as days_invoice_to_payment,
    if(sc.due_date is null or p.payment_date is null, cast(null as Nullable(Int64)),
       dateDiff('day', assumeNotNull(sc.due_date), assumeNotNull(p.payment_date)))      as days_after_due,
    now()                                                       as _loaded_at
from {{ ref('stg_fusion__ap_payments') }} as p
left join (select invoice_id, invoice_date, due_date from {{ ref('stg_fusion__ap_payment_schedules') }}) as sc on sc.invoice_id = p.invoice_id
left join (select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null) as b
    on b.fusion_ledger_id = p.ledger_id
left join (select supplier_key from {{ ref('hnh_dim_supplier') }}) as s
    on s.supplier_key = {{ hnh_surrogate_key(['p.vendor_id', 'p.vendor_site_id']) }}
{{ hnh_settings() }}
```

`fact_ap_open_item.sql`:

```sql
{{ config(order_by='(branch_key, ap_open_item_key)') }}

-- As-of-build snapshot: Fusion keeps only the current remaining amount of each invoice.
with items as (
    select
        sc.invoice_id as invoice_id, sc.vendor_id as vendor_id, sc.vendor_site_id as vendor_site_id, sc.invoice_num as invoice_num,
        sc.invoice_type_code as invoice_type_code, sc.approval_status as approval_status, sc.payment_status_flag as payment_status_flag,
        sc.is_on_hold as is_on_hold, sc.invoice_date as invoice_date, sc.cancelled_date as cancelled_date,
        sc.business_unit_id as business_unit_id, sc.due_date as due_date, sc.gross_amount as gross_amount,
        sc.amount_remaining as amount_remaining,
        toUInt8(sc.cancelled_date is not null)                                       as is_cancelled_f,
        if(sc.amount_remaining = 0 or sc.cancelled_date is not null or sc.due_date is null, toInt64(0),
           greatest(dateDiff('day', assumeNotNull(sc.due_date), today()), 0))        as days_overdue_f
    from {{ ref('stg_fusion__ap_payment_schedules') }} as sc
)

select
    {{ hnh_surrogate_key(['i.invoice_id']) }}                   as ap_open_item_key,
    ifNull(b.branch_key, toUInt8(0))                            as branch_key,
    ifNull(s.supplier_key, toInt64(-1))                         as supplier_key,
    {{ hnh_date_key_in_range('i.invoice_date') }}               as invoice_date_key,
    {{ hnh_date_key_in_range('i.due_date') }}                   as due_date_key,
    i.invoice_id                                                as invoice_id,
    i.invoice_num                                               as invoice_num,
    multiIf(i.invoice_type_code = 'STANDARD', 'Standard', i.invoice_type_code = 'CREDIT', 'Credit memo',
            i.invoice_type_code = 'PREPAYMENT', 'Prepayment', ifNull(i.invoice_type_code, 'Unknown')) as invoice_type,
    i.approval_status                                           as approval_status,
    multiIf(i.payment_status_flag = 'Y', 'Paid', i.payment_status_flag = 'P', 'Partially paid', 'Unpaid') as payment_status,
    i.is_on_hold                                                as is_on_hold,
    i.is_cancelled_f                                            as is_cancelled,
    if(i.amount_remaining = 0 or i.is_cancelled_f = 1, 'Settled',
       if(i.due_date is not null and i.due_date >= today(), 'Not due', {{ hnh_ageing_bucket('i.days_overdue_f') }})) as ageing_bucket,
    today()                                                     as snapshot_date,
    i.gross_amount                                              as gross_amount,
    i.amount_remaining                                          as amount_remaining,
    i.days_overdue_f                                            as days_overdue,
    now()                                                       as _loaded_at
from items as i
left join (select business_unit_id, primary_ledger_id from {{ ref('stg_fusion__business_units') }}) as bu
    on bu.business_unit_id = i.business_unit_id
left join (select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null) as b
    on b.fusion_ledger_id = bu.primary_ledger_id
left join (select supplier_key from {{ ref('hnh_dim_supplier') }}) as s
    on s.supplier_key = {{ hnh_surrogate_key(['i.vendor_id', 'i.vendor_site_id']) }}
{{ hnh_settings() }}
```


- [ ] **Step 3: Run the unit tests and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select fact_ap_invoice_line hnh_fact_ap_payment fact_ap_open_item`
Expected: three unit tests PASS; models built (≈37K, 1.3K, 5.9K rows); tests PASS.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/finance/
git commit -m "Add payables facts: invoice distributions, payments and open items"
```

---

### Task 10: Reconciliation models and monitors

**Files:**
- Create: `hnh_dwh/models/hnh/marts/reconciliation/rec_gl_balance_monthly.sql`, `rec_gl_revenue_monthly.sql`, `rec_income_statement_budget.sql`; tests `hnh_dwh/tests/hnh/assert_finance_facts_have_branch.sql`, `warn_unmapped_fs_accounts.sql`, `warn_unposted_gl_batches.sql`, `warn_unbalanced_journals.sql`, `warn_intercompany_mismatch.sql`, `warn_revenue_without_location.sql`, `warn_gl_revenue_gap.sql`, `warn_ap_without_supplier.sql`
- Modify: `_reconciliation__models.yml`, `_reconciliation_unit_tests.yml`, `hnh_dwh/macros/hnh/hnh_tests.sql` (new generic test `hnh_within_tolerance`)

**Interfaces:**
- Consumes: finance facts and dimensions of Tasks 4–9; `stg_fusion__gl_balances`; `fact_charge_line` (branch_key, delivery_date_key, care_type_key, revenue_amount); `dim_care_type` (care_type_key, care_type); `fact_budget_monthly`.
- Produces:
  - `rec_gl_balance_monthly(branch_key, period_key, gold_debit, gold_credit, fusion_debit, fusion_credit, debit_difference, credit_difference, accounts_compared, accounts_with_closing_difference)`
  - `rec_gl_revenue_monthly(branch_key, month_start, gl_revenue_op, gl_revenue_ip, gl_revenue_er, gl_revenue_other, gl_revenue_unallocated, gl_contractual_discount, gl_net_revenue, oasis_revenue_op, oasis_revenue_ip, oasis_revenue_er, oasis_revenue_daycase, oasis_revenue_unknown, oasis_revenue_total, difference, ratio)`
  - `rec_income_statement_budget(branch_key, fiscal_year, scenario, budget_line_code, computed_amount, file_amount, difference)`

- [ ] **Step 1: Write the failing unit test and YAML**

Append to `_reconciliation_unit_tests.yml`:

```yaml
  - name: rec_gl_revenue_monthly_compares_gl_with_oasis
    description: >
      Branch 6, June 2026: GL OP revenue 1,000 less a contractual discount of 100 (net 900); an opening-balance
      revenue line of 5,000 is excluded. Oasis recognised revenue: OP 880 and day case 20, so the difference is 0.
    model: rec_gl_revenue_monthly
    given:
      - input: ref('hnh_fact_gl_journal_line')
        format: sql
        rows: |
          select toUInt8(6) as branch_key, toInt64(a) as gl_account_key, toInt32(202607) as period_key,
                 toUInt8(ob) as is_opening_balance_journal, toFloat64(amt) as amount
          from values('a UInt32, ob UInt8, amt Float64', (1, 0, -1000), (2, 0, 100), (1, 1, -5000))
      - input: ref('hnh_dim_gl_account')
        format: sql
        rows: |
          select toInt64(a) as gl_account_key, 'OP' as revenue_care_type, toInt64(f) as fs_line_key
          from values('a UInt32, f UInt32', (1, 91), (2, 92))
      - input: ref('dim_fs_line')
        format: sql
        rows: |
          select toInt64(f) as fs_line_key, g as statement_group, c as fs_caption
          from values('f UInt32, g String, c String', (91, 'Revenue', 'Revenue Cash'), (92, 'Revenue discounts', 'Revenue - Contractual Discounts'))
      - input: ref('hnh_dim_gl_period')
        format: sql
        rows: |
          select toInt32(202607) as period_key, toDate('2026-06-30') as end_date
      - input: ref('fact_charge_line')
        format: sql
        rows: |
          select toUInt8(6) as branch_key, toInt32(20260615) as delivery_date_key, toInt8(ct) as care_type_key, toFloat64(r) as revenue_amount
          from values('ct Int8, r Float64', (1, 880), (4, 20))
      - input: ref('dim_care_type')
        format: sql
        rows: |
          select toInt8(k) as care_type_key, c as care_type from values('k Int8, c String', (1, 'OP'), (2, 'ER'), (3, 'IP'), (4, 'DAYCASE'), (-1, 'Unknown'))
    expect:
      rows:
        - {branch_key: 6, month_start: 2026-06-01, gl_revenue_op: 1000, gl_contractual_discount: 100, gl_net_revenue: 900, oasis_revenue_op: 880, oasis_revenue_daycase: 20, oasis_revenue_total: 900, difference: 0}
```

Append to `_reconciliation__models.yml`:

```yaml
  - name: rec_gl_balance_monthly
    tests:
      - hnh_unique_combination:
          columns: [branch_key, period_key]
  - name: rec_gl_revenue_monthly
    tests:
      - hnh_unique_combination:
          columns: [branch_key, month_start]
  - name: rec_income_statement_budget
    tests:
      - hnh_unique_combination:
          columns: [branch_key, fiscal_year, scenario, budget_line_code]
    columns:
      - name: difference
        tests:
          - hnh_within_tolerance:
              tolerance: 0.01
              config: {severity: warn}
```

`hnh_within_tolerance` does not exist yet. Define it in `hnh_dwh/macros/hnh/hnh_tests.sql` (append):

```sql
{# Fails with one row per value whose absolute size exceeds the tolerance. #}
{% test hnh_within_tolerance(model, column_name, tolerance) %}
select {{ column_name }} as value
from {{ model }}
where abs({{ column_name }}) > {{ tolerance }}
{% endtest %}
```

Run: `python scripts/run_dbt.py test --no-partial-parse --select rec_gl_revenue_monthly_compares_gl_with_oasis`
Expected: FAIL — model not found.

- [ ] **Step 2: Write the three reconciliation models**

`rec_gl_balance_monthly.sql`:

```sql
{{ config(order_by='(branch_key, period_key)') }}

-- Posted journal activity and closing balances against Fusion's own balance table, per branch and period.
with gold_activity as (
    select branch_key, period_key, sum(debit) as gold_debit, sum(credit) as gold_credit
    from {{ ref('hnh_fact_gl_journal_line') }}
    where is_posted = 1
    group by branch_key, period_key
),

fusion_rows as (
    select b.branch_key as branch_key, p.period_key as period_key, a.gl_account_key as gl_account_key,
           f.period_debit as period_debit, f.period_credit as period_credit,
           f.begin_debit - f.begin_credit + f.period_debit - f.period_credit as fusion_closing
    from {{ ref('stg_fusion__gl_balances') }} as f
    inner join (select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null) as b
        on b.fusion_ledger_id = f.ledger_id
    inner join (select period_key, period_name from {{ ref('hnh_dim_gl_period') }}) as p on p.period_name = f.period_name
    left join (select gl_account_key, code_combination_id from {{ ref('hnh_dim_gl_account') }} where code_combination_id is not null) as a
        on a.code_combination_id = f.code_combination_id
    where f.actual_flag = 'A' and f.currency_balance_type = 'TOTAL'
),

fusion_activity as (
    select branch_key, period_key, sum(period_debit) as fusion_debit, sum(period_credit) as fusion_credit
    from fusion_rows
    group by branch_key, period_key
),

closings as (
    select f.branch_key as branch_key, f.period_key as period_key, count() as accounts_compared,
           countIf(abs(ifNull(g.closing_balance, 0) - f.fusion_closing) > 0.01) as accounts_with_closing_difference
    from fusion_rows as f
    left join (
        select gl_account_key, period_key, closing_balance from {{ ref('fact_gl_balance_monthly') }}
        where balance_view = 'posted' and is_prior_year_roll = 0
    ) as g on g.gl_account_key = f.gl_account_key and g.period_key = f.period_key
    group by f.branch_key, f.period_key
),

spine as (
    select branch_key, period_key from gold_activity
    union distinct
    select branch_key, period_key from fusion_activity
)

select
    s.branch_key                                            as branch_key,
    s.period_key                                            as period_key,
    ifNull(g.gold_debit, 0)                                 as gold_debit,
    ifNull(g.gold_credit, 0)                                as gold_credit,
    ifNull(fa.fusion_debit, 0)                              as fusion_debit,
    ifNull(fa.fusion_credit, 0)                             as fusion_credit,
    ifNull(g.gold_debit, 0) - ifNull(fa.fusion_debit, 0)    as debit_difference,
    ifNull(g.gold_credit, 0) - ifNull(fa.fusion_credit, 0)  as credit_difference,
    ifNull(c.accounts_compared, 0)                          as accounts_compared,
    ifNull(c.accounts_with_closing_difference, 0)           as accounts_with_closing_difference
from spine as s
left join gold_activity as g on g.branch_key = s.branch_key and g.period_key = s.period_key
left join fusion_activity as fa on fa.branch_key = s.branch_key and fa.period_key = s.period_key
left join closings as c on c.branch_key = s.branch_key and c.period_key = s.period_key
{{ hnh_settings() }}
```

`rec_gl_revenue_monthly.sql`:

```sql
{{ config(order_by='(branch_key, month_start)') }}

-- GL revenue (Oasis feed and manual, including unposted, opening-balance journals excluded) against Oasis
-- recognised revenue, per branch and month. Revenue is credit-positive; contractual discounts debit-positive.
with gl as (
    select
        j.branch_key                                    as branch_key,
        toStartOfMonth(p.end_date)                      as month_start,
        sumIf(-j.amount, f.statement_group = 'Revenue' and a.revenue_care_type = 'OP')          as gl_revenue_op,
        sumIf(-j.amount, f.statement_group = 'Revenue' and a.revenue_care_type = 'IP')          as gl_revenue_ip,
        sumIf(-j.amount, f.statement_group = 'Revenue' and a.revenue_care_type = 'ER')          as gl_revenue_er,
        sumIf(-j.amount, f.statement_group = 'Revenue' and a.revenue_care_type = 'Other')       as gl_revenue_other,
        sumIf(-j.amount, f.statement_group = 'Revenue' and a.revenue_care_type = 'Unallocated') as gl_revenue_unallocated,
        sumIf(j.amount, f.fs_caption = 'Revenue - Contractual Discounts')                       as gl_contractual_discount
    from {{ ref('hnh_fact_gl_journal_line') }} as j
    inner join (select gl_account_key, revenue_care_type, fs_line_key from {{ ref('hnh_dim_gl_account') }}) as a
        on a.gl_account_key = j.gl_account_key
    inner join (select fs_line_key, statement_group, fs_caption from {{ ref('dim_fs_line') }}) as f on f.fs_line_key = a.fs_line_key
    inner join (select period_key, end_date from {{ ref('hnh_dim_gl_period') }}) as p on p.period_key = j.period_key
    where j.is_opening_balance_journal = 0
      and (f.statement_group = 'Revenue' or f.fs_caption = 'Revenue - Contractual Discounts')
    group by j.branch_key, month_start
),

oasis as (
    select
        c.branch_key                                            as branch_key,
        toStartOfMonth(toDate(toString(c.delivery_date_key)))   as month_start,
        sumIf(c.revenue_amount, ct.care_type = 'OP')            as oasis_revenue_op,
        sumIf(c.revenue_amount, ct.care_type = 'IP')            as oasis_revenue_ip,
        sumIf(c.revenue_amount, ct.care_type = 'ER')            as oasis_revenue_er,
        sumIf(c.revenue_amount, ct.care_type = 'DAYCASE')       as oasis_revenue_daycase,
        sumIf(c.revenue_amount, ifNull(ct.care_type, 'Unknown') = 'Unknown') as oasis_revenue_unknown,
        sum(c.revenue_amount)                                   as oasis_revenue_total
    from {{ ref('fact_charge_line') }} as c
    left join (select care_type_key, care_type from {{ ref('dim_care_type') }}) as ct on ct.care_type_key = c.care_type_key
    where (c.branch_key, toStartOfMonth(toDate(toString(c.delivery_date_key)))) in (select branch_key, month_start from gl)
    group by c.branch_key, month_start
)

select
    g.branch_key as branch_key, g.month_start as month_start,
    g.gl_revenue_op as gl_revenue_op, g.gl_revenue_ip as gl_revenue_ip, g.gl_revenue_er as gl_revenue_er,
    g.gl_revenue_other as gl_revenue_other, g.gl_revenue_unallocated as gl_revenue_unallocated,
    g.gl_contractual_discount as gl_contractual_discount,
    g.gl_revenue_op + g.gl_revenue_ip + g.gl_revenue_er + g.gl_revenue_other + g.gl_revenue_unallocated - g.gl_contractual_discount as gl_net_revenue,
    ifNull(o.oasis_revenue_op, 0)      as oasis_revenue_op,
    ifNull(o.oasis_revenue_ip, 0)      as oasis_revenue_ip,
    ifNull(o.oasis_revenue_er, 0)      as oasis_revenue_er,
    ifNull(o.oasis_revenue_daycase, 0) as oasis_revenue_daycase,
    ifNull(o.oasis_revenue_unknown, 0) as oasis_revenue_unknown,
    ifNull(o.oasis_revenue_total, 0)   as oasis_revenue_total,
    gl_net_revenue - oasis_revenue_total                                            as difference,
    if(oasis_revenue_total = 0, cast(null as Nullable(Float64)), gl_net_revenue / oasis_revenue_total) as ratio
from gl as g
left join oasis as o on o.branch_key = g.branch_key and o.month_start = g.month_start
{{ hnh_settings() }}
```

`rec_income_statement_budget.sql`:

```sql
{{ config(order_by='(branch_key, fiscal_year, scenario, budget_line_code)') }}

-- Budget subtotals computed by the model against the subtotal rows of the budget file, per branch, year and scenario.
with computed as (
    select branch_key, toUInt16(toYear(month_start)) as fiscal_year, 'most_likely' as scenario, budget_line_code,
           sum(budget_most_likely) as computed_amount
    from {{ ref('fact_income_statement_monthly') }}
    group by branch_key, fiscal_year, budget_line_code
    union all
    select branch_key, toUInt16(toYear(month_start)), 'worst_case', budget_line_code, sum(budget_worst_case)
    from {{ ref('fact_income_statement_monthly') }}
    group by branch_key, toUInt16(toYear(month_start)), budget_line_code
),

delivered as (
    select branch_key, toUInt16(toYear(month_start)) as fiscal_year, scenario, budget_line_code, sum(budget_amount) as file_amount
    from {{ ref('fact_budget_monthly') }}
    where is_subtotal = 1
    group by branch_key, fiscal_year, scenario, budget_line_code
)

select
    d.branch_key                                    as branch_key,
    d.fiscal_year                                   as fiscal_year,
    d.scenario                                      as scenario,
    d.budget_line_code                              as budget_line_code,
    ifNull(c.computed_amount, 0)                    as computed_amount,
    d.file_amount                                   as file_amount,
    ifNull(c.computed_amount, 0) - d.file_amount    as difference
from delivered as d
left join computed as c
    on c.branch_key = d.branch_key and c.fiscal_year = d.fiscal_year and c.scenario = d.scenario and c.budget_line_code = d.budget_line_code
{{ hnh_settings() }}
```

- [ ] **Step 3: Write the branch test and the monitors**

`assert_finance_facts_have_branch.sql`:

```sql
-- Finance facts never fall back to the Group member (branch 0).
select 'fact_gl_journal_line' as fact, count() as rows_without_branch from {{ ref('hnh_fact_gl_journal_line') }} where branch_key = 0 having count() > 0
union all
select 'fact_gl_balance_monthly', count() from {{ ref('fact_gl_balance_monthly') }} where branch_key = 0 having count() > 0
union all
select 'fact_ap_invoice_line', count() from {{ ref('fact_ap_invoice_line') }} where branch_key = 0 having count() > 0
union all
select 'fact_ap_payment', count() from {{ ref('hnh_fact_ap_payment') }} where branch_key = 0 having count() > 0
union all
select 'fact_ap_open_item', count() from {{ ref('fact_ap_open_item') }} where branch_key = 0 having count() > 0
```

`warn_unmapped_fs_accounts.sql`:

```sql
{{ config(severity='warn') }}
-- Posted accounts without an FS line (shown on a Not mapped line), by branch and natural account.
select j.branch_key as branch_key, a.natural_account as natural_account, any(a.natural_account_name) as account_name,
       count() as lines, round(sum(j.debit) + sum(j.credit), 2) as gross_value
from {{ ref('hnh_fact_gl_journal_line') }} as j
inner join {{ ref('hnh_dim_gl_account') }} as a on a.gl_account_key = j.gl_account_key
where a.fs_mapping_source = 'not mapped' and j.is_posted = 1
group by j.branch_key, a.natural_account
```

`warn_unposted_gl_batches.sql`:

```sql
{{ config(severity='warn') }}
-- Unposted journal batches by branch and period: they are in the including_unposted view only.
select branch_key, period_key, uniqExact(je_batch_id) as batches, count() as lines, round(sum(debit), 2) as debit
from {{ ref('hnh_fact_gl_journal_line') }}
where is_posted = 0
group by branch_key, period_key
```

`warn_unbalanced_journals.sql`:

```sql
{{ config(severity='warn') }}
-- Journal headers whose debits and credits differ (all were unposted at 2026-10-05: 19 headers).
select je_header_id, any(branch_key) as branch_key, any(is_posted) as is_posted, round(sum(amount), 2) as out_of_balance
from {{ ref('hnh_fact_gl_journal_line') }}
group by je_header_id
having abs(sum(amount)) > 0.005
```

`warn_intercompany_mismatch.sql`:

```sql
{{ config(severity='warn') }}
-- Branch pairs whose intercompany amounts do not offset (A's lines naming B plus B's lines naming A).
with pairs as (
    select branch_key as from_branch, assumeNotNull(intercompany_branch_key) as to_branch, sum(amount) as net
    from {{ ref('hnh_fact_gl_journal_line') }}
    where intercompany_branch_key is not null and intercompany_branch_key != branch_key
    group by from_branch, to_branch
)
select a.from_branch, a.to_branch, round(a.net, 2) as net_from, round(ifNull(b.net, 0), 2) as net_back,
       round(a.net + ifNull(b.net, 0), 2) as mismatch
from pairs as a
left join pairs as b on b.from_branch = a.to_branch and b.to_branch = a.from_branch
where a.from_branch < a.to_branch and abs(a.net + ifNull(b.net, 0)) > 1
{{ hnh_settings() }}
```

`warn_revenue_without_location.sql`:

```sql
{{ config(severity='warn') }}
-- Revenue lines without a service location (care type Unallocated), opening-balance journals excluded.
select j.branch_key as branch_key, j.period_key as period_key, count() as lines, round(-sum(j.amount), 2) as revenue
from {{ ref('hnh_fact_gl_journal_line') }} as j
inner join {{ ref('hnh_dim_gl_account') }} as a on a.gl_account_key = j.gl_account_key
inner join {{ ref('dim_fs_line') }} as f on f.fs_line_key = a.fs_line_key
where f.statement_group = 'Revenue' and a.revenue_care_type = 'Unallocated' and j.is_opening_balance_journal = 0
group by j.branch_key, j.period_key
```

`warn_gl_revenue_gap.sql`:

```sql
{{ config(severity='warn') }}
-- Closed months where GL net revenue differs from Oasis recognised revenue by more than 2%.
select branch_key, month_start, round(gl_net_revenue, 2) as gl_net_revenue, round(oasis_revenue_total, 2) as oasis_revenue,
       round(ratio, 4) as ratio
from {{ ref('rec_gl_revenue_monthly') }}
where month_start < toStartOfMonth(today()) and oasis_revenue_total != 0 and abs(difference) / abs(oasis_revenue_total) > 0.02
```

`warn_ap_without_supplier.sql`:

```sql
{{ config(severity='warn') }}
-- AP rows whose supplier site is not in dim_supplier.
select 'invoice line' as source, branch_key, count() as rows, round(sum(amount), 2) as amount
from {{ ref('fact_ap_invoice_line') }} where supplier_key = -1 group by branch_key
union all
select 'payment', branch_key, count(), round(sum(amount), 2)
from {{ ref('hnh_fact_ap_payment') }} where supplier_key = -1 group by branch_key
```

- [ ] **Step 4: Run the unit test and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select rec_gl_balance_monthly rec_gl_revenue_monthly rec_income_statement_budget assert_finance_facts_have_branch warn_unmapped_fs_accounts warn_unposted_gl_batches warn_unbalanced_journals warn_intercompany_mismatch warn_revenue_without_location warn_gl_revenue_gap warn_ap_without_supplier`
Expected: unit test PASS; models built; `assert_finance_facts_have_branch` PASS; monitors WARN or PASS (never ERROR); `rec_income_statement_budget.difference` PASS (measured equal for branch 1).

Then check `select branch_key, period_key, debit_difference, credit_difference, accounts_with_closing_difference from gold.rec_gl_balance_monthly where abs(debit_difference) > 0.01 or abs(credit_difference) > 0.01 or accounts_with_closing_difference > 0` — expected empty for Ghirnata (measured equal); record any other rows for Task 11.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/marts/reconciliation/ hnh_dwh/tests/hnh/ hnh_dwh/macros/hnh/hnh_tests.sql
git commit -m "Reconcile GL balances, GL revenue and budget subtotals and add finance monitors"
```

---

### Task 11: Documentation, full build and measurements

**Files:**
- Create: `docs/reconciliation_phase3.md`
- Modify: `docs/receiving_project_config.md`, `docs/superpowers/specs/2026-10-05-hnh-dwh-phase3-finance-design.md` (section 12 "Changes during implementation", only if anything changed)

**Interfaces:**
- Consumes: everything above.
- Produces: documentation; a green full build.

- [ ] **Step 1: Full build**

Run: `python scripts/run_dbt.py build --select tag:hnh`
Expected: `ERROR=0`. Note PASS, WARN and duration. If a test errors, fix it in the task that owns the model and re-run.

- [ ] **Step 2: Measure for the docs**

Run these through `ch_env` and note the results:

```sql
select count(), countIf(is_posted = 1), countIf(is_opening_balance_journal = 1) from gold.fact_gl_journal_line;
select balance_view, count() from gold.fact_gl_balance_monthly group by 1;
select fs_mapping_source, count() from gold.dim_gl_account group by 1;
select branch_key, round(sum(actual_including_unposted) / 1e6, 2) from gold.fact_income_statement_monthly where budget_line_code = 'NET_PROFIT' group by 1 order by 1;
select * from gold.rec_gl_revenue_monthly order by branch_key, month_start;
```

and the row count of each `warn_*` monitor from the build output.

- [ ] **Step 3: Write `docs/reconciliation_phase3.md`**

````markdown
# Phase 3 reconciliation

Run after a successful `dbt build --select tag:hnh`.

## Fusion balances (`gold.rec_gl_balance_monthly`)

Posted journal debits and credits per branch and period beside Fusion's `fact_gl_balance`, and the number of accounts whose posted closing balance differs from Fusion's (begin + debits − credits). Acceptance: all differences 0 for every period Fusion has. Khamis and Alrabwah have no rows in Fusion's balance table (Alrabwah has no journals at all).

## GL revenue against Oasis (`gold.rec_gl_revenue_monthly`)

GL revenue by care type (service location; Oasis feed and manual journals, including unposted, opening-balance journals excluded) less contractual discounts, beside Oasis recognised revenue from `fact_charge_line`. `warn_gl_revenue_gap` lists closed months more than 2% apart. Most Oasis-feed batches were unposted at 2026-10-05, so compare the including-unposted GL figures.

## Budget subtotals (`gold.rec_income_statement_budget`)

The model computes every budget subtotal from detail lines with the same formulas as actuals (spec G12). `difference` against the budget file's subtotal rows must be 0.

## Go-live tie to the old Financial Statements report

The old report reads the Oasis GL on the old server, so it is compared once per branch, at go-live: each branch's opening-balance journal (`is_opening_balance_journal = 1`) should equal the old report's closing balances for the month before go-live.

| Branch | Fusion go-live month | Old report month to export |
|---|---|---|
| 7 Ghirnata | January 2026 | December 2025 |
| 6 Abha | February 2026 | January 2026 |
| Head Office | April 2026 | March 2026 |
| 3 Jazan | June 2026 | May 2026 |
| 8 Muhayil | June 2026 | May 2026 |
| 4 Unaizah | July 2026 | June 2026 |
| 2 Khamis | August 2026 | July 2026 |
| 5 Madinah | September 2026 | August 2026 |

New side, per branch and FS category (debit positive):

```sql
select j.branch_key, f.fs_type, f.fs_element, f.fs_category, round(sum(j.amount), 2) as opening_amount
from gold.fact_gl_journal_line as j
join gold.dim_gl_account as a on a.gl_account_key = j.gl_account_key
join gold.dim_fs_line as f on f.fs_line_key = a.fs_line_key
where j.is_opening_balance_journal = 1
group by j.branch_key, f.fs_type, f.fs_element, f.fs_category
order by j.branch_key, f.fs_type, f.fs_element, f.fs_category
```

Old side: in the old Financial Statements model, filter the branch and the month before go-live and export `Balance` by AccountType, FSElement and FSCategory. `default.map_oasis_fs_account` (`stg.stg_ref__oasis_fs_account`) is the same mapping the old report used, for drilling into a category. Compare at category level: captions differ between the two vocabularies (Oasis splits revenue by care setting and has Medical Consumables; Oracle splits revenue by payer and has Cost of Medicines). Branch 5 code `1` is mapped twice in the Oasis mapping and is left out (spec O-P3-5).

## Monitors at first build

| Monitor | Rows | Note |
|---|---|---|
| warn_unmapped_fs_accounts | <from the build> | Posted accounts on a Not mapped line; worklist `static_mappings/fs_account_unmapped.csv` (O-P3-1) |
| warn_unposted_gl_batches | <from the build> | Branch-periods with unposted batches |
| warn_unbalanced_journals | <from the build> | 19 unposted headers at 2026-10-05 |
| warn_intercompany_mismatch | <from the build> | |
| warn_revenue_without_location | <from the build> | |
| warn_gl_revenue_gap | <from the build> | |
| warn_ap_without_supplier | <from the build> | |
| warn_fs_levels_without_order | <from the build> | |
````

Replace each `<from the build>` with the row count from Step 2 before committing.

- [ ] **Step 4: Update `docs/receiving_project_config.md`**

1. In "Add to `dbt/dbt_project.yml`" add under `vars:`:

```yaml
  hnh_fusion_as_ref: true                # staging reads the project's own Fusion models via ref()
  hnh_head_office_fusion_branch_code: 101
  hnh_head_office_ledger_id: 300000005003375
  hnh_fusion_oasis_feed_source: "300000007046804"   # Fusion journal source id of the Oasis integration
```

and change "add the four `hnh_` vars" to "add the eight `hnh_` vars".

2. Add a section after "How the models read Oasis":

```markdown
## How the models read Fusion

With `hnh_fusion_as_ref: true`, `hnh_fusion_source('<table>')` calls `ref('<table>')` on the project's Fusion models (`models/fusion/staging/...`, same names as the tables: `fact_gl_journal_line`, `dim_gl_account`, `dim_coa_segment_value`, `dim_gl_period`, `fact_gl_balance`, `fact_ap_invoice_distribution`, `fact_ap_payment`, `fact_ap_payment_schedule`, `dim_supplier`, `dim_business_unit`). They are ReplacingMergeTree, so staging reads them with `final`. The hnh YAML declares a source named `fusion`; the project's own Fusion sources are named `ofusion_*`, so there is no clash.
```

3. In "Aliased models" add: `hnh_dim_gl_period`, `hnh_dim_gl_account`, `hnh_dim_supplier`, `hnh_fact_gl_journal_line` and `hnh_fact_ap_payment` are built into `gold.dim_gl_period`, `gold.dim_gl_account`, `gold.dim_supplier`, `gold.fact_gl_journal_line` and `gold.fact_ap_payment` for the same reason (the project's Fusion models already use those names).

4. In "Reference tables that must exist in `default`" add `map_fs_account`, `map_oasis_fs_account`, `map_fs_line_order`, `map_budget_fs_line`, `map_fusion_specialty_unified`, `income_statement_budget`, loaded with `python scripts/load_reference_data.py --only <table>`; `fusion_specialty_unified.csv` is drafted by `scripts/draft_fusion_specialty_map.py` for the BI manager to complete.

5. Append to "Notes for the SSAS model":

```markdown
- Finance statements: multiply `fact_gl_balance_monthly` and journal amounts by `dim_fs_line.display_sign`. Default `balance_view = 'posted'` (ties to the Fusion trial balance); offer an "including unposted" measure set, because most Oasis-feed batches are unposted. Relate `fact_gl_balance_monthly` to `dim_gl_account`, `dim_gl_period` and `dim_branch`; filter one `balance_view` in every measure.
- Monthly trends use `period_movement_excl_opening`; each branch's go-live month carries one opening-balance journal with the year to date before go-live. Balances and year-to-date use the full measures.
- EBITDA, gross profit, net profit and every budget comparison come from `fact_income_statement_monthly` (`budget_line_code`); do not re-derive subtotals in DAX. Never sum across `budget_line_code` without `dim_budget_line.is_subtotal = 0`.
- Budget covers branches 1–6; Ghirnata, Muhayil and Head Office have actuals only.
- `fact_ap_open_item` is a snapshot at the last refresh (`snapshot_date`); payables ageing at a past date is not available.
- Head Office is `branch_key = 100`; the branch role must list it explicitly; admins receive it in `sec_user_access`.
```

- [ ] **Step 5: Record implementation changes in the spec**

If any rule or name changed while implementing, add a section `## 12. Changes during implementation (<date>)` to the spec listing each change in one sentence, as Phase 2B's section 11 does. Otherwise skip.

- [ ] **Step 6: Commit**

```bash
git add docs/reconciliation_phase3.md docs/receiving_project_config.md docs/superpowers/specs/2026-10-05-hnh-dwh-phase3-finance-design.md
git commit -m "Document Phase 3 hand-off and finance reconciliation"
```
