# Phase 4 — Workforce: Headcount, Movements, Payroll, Absence and Productivity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the workforce gold layer: employee and HR dimensions, a staff bridge to Oasis, monthly headcount, movements, payroll from Oasis and Fusion with a per-branch cutover, absence and leave with leave liability, a clinical-productivity aggregate, reconciliation and monitors.

**Architecture:** Fusion HCM tables are staged through `hnh_fusion_source()` with `final`; Oasis payroll transactions through `hnh_oasis_source()`. Three intermediate models resolve the legal employer to a branch, the latest period of service per person, and the primary assignment valid at each month-end. Gold dimensions are current-state; facts are a month-end snapshot, an event fact, a monthly payroll fact, absence entries with a daily split and monthly leave balances. Rules are `hnh_` macros tested with literals; multi-row rules are dbt unit tests with SQL fixtures.

**Tech Stack:** ClickHouse 26.5, dbt-core 1.11.12, dbt-clickhouse 1.9.8, Python 3.13 with `clickhouse_connect`.

**Spec:** `docs/superpowers/specs/2026-10-06-hnh-dwh-phase4-workforce-design.md` (parents: `2026-10-05-hnh-dwh-phase3-finance-design.md`, `2026-10-01-hnh-dwh-gold-layer-design.md`)

**Prerequisite:** Phases 1–3 are on `main` and `python scripts/run_dbt.py build --select tag:hnh` passes. Work happens on branch `phase4-workforce` (created; the spec is committed there).

## Global Constraints

- All earlier-phase constraints apply: databases `stg` / `int` / `gold`; never write to `oasis`, `fusion`, `press_ganey`; models, macros and tests only under `hnh/` folders; macros prefixed `hnh_`; no packages, no seeds; `branch_id` / `branch_key` are `UInt8`; keys through `hnh_surrogate_key`; every model with a `left join` ends with `{{ hnh_settings() }}`; YAML uses the `tests:` key.
- **A ClickHouse SETTINGS clause after `union all` binds only to the last branch:** every CTE that contains a left join whose NULLs matter ends with its own `{{ hnh_settings() }}` (with a one-line comment), and the model keeps its trailing `{{ hnh_settings() }}`.
- Run dbt only through `python scripts/run_dbt.py <dbt args>` from the repository root; add `--no-partial-parse` after YAML or unit-test edits. Ad hoc reads through `scripts/ch_env.py` (`from ch_env import client`); never the machine-wide `CLICKHOUSE_PASSWORD`.
- Fusion tables are read only with `{{ hnh_fusion_source('<table>') }} final`; Oasis tables with `{{ hnh_oasis_source('<table>') }} final`.
- Fusion SCD columns: `is_current` is the string 'Y'/'N'; open-ended rows have `valid_to` 2299-12-31 23:00 UTC, beyond `Date` — cast with `toDate32`, never `toDate`. A history row's `valid_to` is the day before the next row's `valid_from` (inclusive end).
- Names, phone numbers, e-mail, bank details and national ids are never staged.
- Model names that exist in the receiving project's Fusion models carry the `hnh_` prefix and an alias: `hnh_dim_employee` → `dim_employee`, `hnh_dim_job` → `dim_job`, `hnh_dim_grade` → `dim_grade`, `hnh_dim_position` → `dim_position`, `hnh_dim_location` → `dim_location`, `hnh_dim_worker_action` → `dim_worker_action`, `hnh_dim_absence_type` → `dim_absence_type`, `hnh_fact_worker_movement` → `fact_worker_movement`.
- Every fact has `_loaded_at` (`now()`), engine `MergeTree`, an `order_by` starting with `branch_key`; sort-key columns non-Nullable; fact dimension keys never null (missing → `-1`).
- Reference CSVs under `static_mappings/` are git-ignored and never committed; `scripts/load_reference_data.py` never overwrites a table that has rows.
- dbt unit tests live in `*_unit_tests.yml`, use `format: sql`, mock every `ref()` of the model (only the columns it reads), and may set `overrides: vars:`. Fixtures call `hnh_surrogate_key` in Jinja; if the runner does not render Jinja in fixtures, replace each call with its literal (computed through `ch_env` with the same expression) and note it in the report.

### Spec refinements made while planning

| Spec says | Plan does | Why |
|---|---|---|
| `hnh_hr_branch_key` macro (4.1) | Intermediate model `int_legal_employer_branch` (legal employer → branch) | The rule needs three joins (organisation, business unit, branch); a model is testable and reused by four facts. |
| Movement branch from the legal employer | Movement branch from the department prefix (`hnh_hr_dept_prefix_branch`), falling back to the person's current branch | `fact_worker_movement` carries organisation ids but no legal employer; department names carry the branch prefix (H6). |
| Movement key (`assignment_id`, `effective_start_date`, `effective_sequence`) | (`assignment_id`, `effective_end_date_key`, `effective_sequence`) | The source table's key; the spec's triple is not unique (11,841 of 11,863). |
| `map_pay_category` keyed by (source, code) | Keyed by (`SOURCE`, `SOURCE_CODE`, `PAYABLE_TYPE`) | Oasis `GOSI_ADJ` appears as payable type P (employee) and K (employer). |
| Bridge monitor "worker numbers matching several staff records" | "Staff records linked to several employees" | (`branch_id`, `staff_id`) is unique in `dim_staff`, so one worker number cannot match two staff in a branch; the reverse can happen. |
| Absence and lateness deductions are employee deductions | Pay group *Earnings adjustments*: `is_cost = 1`, `is_gross_pay = 1` | They reduce the pay actually earned (Oasis amounts are already negative); loans, bank charges and employee GOSI are not cost. |
| Fusion deduction amounts as delivered | `amount = result_value × fusion_sign` (deductions −1) | Fusion stores deductions as positive values; Oasis stores them signed. |
| Paired Fusion deduction elements ("X Deduction" and "X Deduction Results") | The element without "Results" is *Not pay* when its "Results" twin exists | The pair records the same deduction twice (entry and result). |

## Review Focus

1. **A person with two primary active assignments at a month-end** (62 people today): exactly one headcount row, the assignment with the latest `valid_from`. Pinned in Task 4 (`int_assignment_month_end` unit test, person 3).
2. **A parallel-run month** (Jazan July 2026: Oasis and Fusion both paid): payroll cost comes from Fusion only; the Oasis rows stay with `is_parallel_run = 1` and contribute 0 to cost. Pinned in Task 7 (`fact_payroll_monthly` unit test, branch 3 month 202607).
3. **An Oasis staff id that exists in two branches** (1,667 ids): the bridge links the employee to the staff record of the employee's own branch only. Pinned in Task 5 (`bridge_employee_staff` unit test, worker 500).
4. **An annual-leave balance for someone not yet paid** (new hire): liability null, not zero, and listed by a monitor. Pinned in Task 8 (`fact_leave_balance_monthly` unit test, person 3).
5. **A sick leave from 30 June to 2 July**: three daily rows, one in June and two in July. Pinned in Task 8 (`fact_absence_daily` unit test, entry 1).

## File Structure

```
scripts/load_reference_data.py                   + map_pay_category, map_payroll_cutover
scripts/draft_pay_category_map.py                 draft pay-category mapping (keyword rules)
static_mappings/ (git-ignored)                    pay_category_mapping.csv, payroll_cutover.csv
hnh_dwh/dbt_project.yml                           + vars hnh_hr_snapshot_start, hnh_hr_snapshot_end
hnh_dwh/macros/hnh/hnh_rules_workforce.sql        movement group, absence status/category, bands, FTE, dept prefix, worker type
hnh_dwh/tests/hnh/assert_hnh_workforce_macros.sql and the workforce assert_/warn_ tests (Tasks 6–9)
hnh_dwh/models/hnh/staging/fusion/                + 19 stg_fusion__ HCM views (Task 3)
hnh_dwh/models/hnh/staging/oasis/                 + stg_oasis__payroll_transactions
hnh_dwh/models/hnh/staging/reference/             + stg_ref__pay_category, stg_ref__payroll_cutover
hnh_dwh/models/hnh/intermediate/workforce/        int_legal_employer_branch, int_employee_period, int_assignment_month_end,
                                                    _workforce__models.yml, _workforce_unit_tests.yml
hnh_dwh/models/hnh/marts/conformed/               + hnh_dim_employee, hnh_dim_hr_department, hnh_dim_job, hnh_dim_grade,
                                                    hnh_dim_position, hnh_dim_location, hnh_dim_worker_action,
                                                    hnh_dim_absence_type, dim_pay_category, bridge_employee_staff,
                                                    _workforce_conformed_unit_tests.yml
hnh_dwh/models/hnh/marts/workforce/               fact_headcount_monthly, hnh_fact_worker_movement, fact_payroll_monthly,
                                                    fact_absence, fact_absence_daily, fact_leave_balance_monthly,
                                                    agg_staff_productivity_monthly, _workforce_marts__models.yml,
                                                    _workforce_marts_unit_tests.yml
hnh_dwh/models/hnh/marts/reconciliation/          + rec_payroll_monthly, rec_headcount_monthly
docs/reconciliation_phase4.md, docs/receiving_project_config.md
```

---

### Task 1: Workforce macros and vars

**Files:**
- Modify: `hnh_dwh/dbt_project.yml` (vars)
- Create: `hnh_dwh/macros/hnh/hnh_rules_workforce.sql`, `hnh_dwh/tests/hnh/assert_hnh_workforce_macros.sql`

**Interfaces:**
- Produces: `hnh_movement_group(action_code)`, `hnh_absence_status(status_code, approval_code)`, `hnh_is_counted_absence(status_code, approval_code)` (UInt8), `hnh_absence_category(type_name)`, `hnh_age_band(birth_date, ref_date)`, `hnh_tenure_band(start_date, ref_date)`, `hnh_fte(value)` (Float64), `hnh_hr_dept_prefix_branch(prefix)` (UInt8), `hnh_worker_type_label(code)`; vars `hnh_hr_snapshot_start` ("2026-01-01"), `hnh_hr_snapshot_end` ("" = today).

- [ ] **Step 1: Write the failing macro test**

`hnh_dwh/tests/hnh/assert_hnh_workforce_macros.sql`:

```sql
{% set null_s = "cast(null as Nullable(String))" %}
{% set null_d = "cast(null as Nullable(Date32))" %}

select 'movement group wrong' as failure
where not ({{ hnh_movement_group("'HIRE'") }} = 'Hire' and {{ hnh_movement_group("'ADD_CWK'") }} = 'Hire'
       and {{ hnh_movement_group("'REHIRE'") }} = 'Rehire' and {{ hnh_movement_group("'GLB_TRANSFER'") }} = 'Transfer'
       and {{ hnh_movement_group("'ASG_CHANGE'") }} = 'Position change' and {{ hnh_movement_group("'POSITION_CHANGE'") }} = 'Position change'
       and {{ hnh_movement_group("'RESIGNATION'") }} = 'Voluntary leaver'
       and {{ hnh_movement_group("'TERMINATION_ARTICLE_80'") }} = 'Involuntary leaver'
       and {{ hnh_movement_group("'TERMINATION_ARTICLE_74'") }} = 'Involuntary leaver'
       and {{ hnh_movement_group("'END_OF_CONTRACT'") }} = 'Involuntary leaver'
       and {{ hnh_movement_group("'END_CONTRACT_IN_PROB_PERIOD'") }} = 'Involuntary leaver'
       and {{ hnh_movement_group("'TERMINATION_OTHER'") }} = 'Involuntary leaver'
       and {{ hnh_movement_group("'CONTRACT_EXTENSION'") }} = 'Contract extension'
       and {{ hnh_movement_group("'MANAGER_CHANGE'") }} = 'Other' and {{ hnh_movement_group(null_s) }} = 'Other')

union all
select 'absence status wrong'
where not ({{ hnh_absence_status("'SUBMITTED'", "'APPROVED'") }} = 'Approved'
       and {{ hnh_absence_status("'SUBMITTED'", "'AWAITING'") }} = 'Awaiting'
       and {{ hnh_absence_status("'SUBMITTED'", "'DENIED'") }} = 'Denied'
       and {{ hnh_absence_status("'ORA_WITHDRAWN'", "'APPROVED'") }} = 'Withdrawn'
       and {{ hnh_absence_status("'SAVED'", null_s) }} = 'Saved'
       and {{ hnh_absence_status(null_s, null_s) }} = 'Other')

union all
select 'counted absence wrong'
where not ({{ hnh_is_counted_absence("'SUBMITTED'", "'APPROVED'") }} = 1
       and {{ hnh_is_counted_absence("'ORA_WITHDRAWN'", "'APPROVED'") }} = 0
       and {{ hnh_is_counted_absence("'SUBMITTED'", "'AWAITING'") }} = 0
       and {{ hnh_is_counted_absence(null_s, null_s) }} = 0)

union all
select 'absence category wrong'
where not ({{ hnh_absence_category("'Sick Leave'") }} = 'Sick' and {{ hnh_absence_category("'HQ Annual Leave - NS'") }} = 'Annual'
       and {{ hnh_absence_category("'Unpaid Leave'") }} = 'Unpaid' and {{ hnh_absence_category("'Permission Leave'") }} = 'Permission'
       and {{ hnh_absence_category("'Time Back'") }} = 'Time back' and {{ hnh_absence_category("'Maternity'") }} = 'Other'
       and {{ hnh_absence_category(null_s) }} = 'Other')

union all
select 'age band wrong'
where not ({{ hnh_age_band("toDate32('2002-06-01')", "toDate32('2026-05-31')") }} = '<25'
       and {{ hnh_age_band("toDate32('2001-01-01')", "toDate32('2026-06-01')") }} = '25-34'
       and {{ hnh_age_band("toDate32('1990-01-01')", "toDate32('2026-06-01')") }} = '35-44'
       and {{ hnh_age_band("toDate32('1980-01-01')", "toDate32('2026-06-01')") }} = '45-54'
       and {{ hnh_age_band("toDate32('1960-01-01')", "toDate32('2026-06-01')") }} = '55+'
       and {{ hnh_age_band(null_d, "toDate32('2026-06-01')") }} = 'Unknown')

union all
select 'tenure band wrong'
where not ({{ hnh_tenure_band("toDate32('2026-01-01')", "toDate32('2026-06-01')") }} = '<1'
       and {{ hnh_tenure_band("toDate32('2024-01-01')", "toDate32('2026-06-01')") }} = '1-3'
       and {{ hnh_tenure_band("toDate32('2022-01-01')", "toDate32('2026-06-01')") }} = '3-5'
       and {{ hnh_tenure_band("toDate32('2018-01-01')", "toDate32('2026-06-01')") }} = '5-10'
       and {{ hnh_tenure_band("toDate32('2000-01-01')", "toDate32('2026-06-01')") }} = '10+'
       and {{ hnh_tenure_band(null_d, "toDate32('2026-06-01')") }} = 'Unknown')

union all
select 'fte wrong'
where not ({{ hnh_fte('toFloat64(0.5)') }} = 0.5 and {{ hnh_fte('toFloat64(1.5)') }} = 1.5 and {{ hnh_fte('toFloat64(0)') }} = 1
       and {{ hnh_fte('toFloat64(2)') }} = 1 and {{ hnh_fte('cast(null as Nullable(Float64))') }} = 1)

union all
select 'dept prefix branch wrong'
where not ({{ hnh_hr_dept_prefix_branch("'RBW'") }} = 1 and {{ hnh_hr_dept_prefix_branch("'KHM'") }} = 2
       and {{ hnh_hr_dept_prefix_branch("'JAZ'") }} = 3 and {{ hnh_hr_dept_prefix_branch("'UNI'") }} = 4
       and {{ hnh_hr_dept_prefix_branch("'MAD'") }} = 5 and {{ hnh_hr_dept_prefix_branch("'ABH'") }} = 6
       and {{ hnh_hr_dept_prefix_branch("'GHI'") }} = 7 and {{ hnh_hr_dept_prefix_branch("'MHL'") }} = 8
       and {{ hnh_hr_dept_prefix_branch("'HQ'") }} = 100 and {{ hnh_hr_dept_prefix_branch("'XXX'") }} = 0)

union all
select 'worker type wrong'
where not ({{ hnh_worker_type_label("'EMP'") }} = 'Employee' and {{ hnh_worker_type_label("'EX_EMP'") }} = 'Ex-employee'
       and {{ hnh_worker_type_label("'CWK'") }} = 'Contingent worker' and {{ hnh_worker_type_label("'CON'") }} = 'Contractor'
       and {{ hnh_worker_type_label("'CANCELED_HIRE'") }} = 'Cancelled hire' and {{ hnh_worker_type_label(null_s) }} = 'Unknown')
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python scripts/run_dbt.py test --select assert_hnh_workforce_macros`
Expected: compilation error — `'hnh_movement_group' is undefined`.

- [ ] **Step 3: Add the vars**

In `hnh_dwh/dbt_project.yml` under `vars:` add:

```yaml
  hnh_hr_snapshot_start: "2026-01-01"   # first month-end of the headcount snapshot (Fusion core HR go-live)
  hnh_hr_snapshot_end: ""               # empty = today; unit tests override it
```

- [ ] **Step 4: Write the macros**

`hnh_dwh/macros/hnh/hnh_rules_workforce.sql`:

```sql
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
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `python scripts/run_dbt.py test --select assert_hnh_workforce_macros`
Expected: `PASS=1`.

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/macros/hnh/hnh_rules_workforce.sql hnh_dwh/dbt_project.yml hnh_dwh/tests/hnh/assert_hnh_workforce_macros.sql
git commit -m "Add workforce rule macros and the headcount snapshot window"
```

---

### Task 2: Pay-category and cutover reference data

**Files:**
- Create: `scripts/draft_pay_category_map.py`; git-ignored data `static_mappings/pay_category_mapping.csv` (generated), `static_mappings/payroll_cutover.csv`
- Modify: `scripts/load_reference_data.py`, `hnh_dwh/models/hnh/staging/reference/_reference__sources.yml`, `_reference__models.yml`
- Create: `hnh_dwh/models/hnh/staging/reference/stg_ref__pay_category.sql`, `stg_ref__payroll_cutover.sql`

**Interfaces:**
- Produces: `stg_ref__pay_category(source String, source_code String, payable_type String, pay_category String)`; `stg_ref__payroll_cutover(branch_id UInt8, first_fusion_month Int32)`.

- [ ] **Step 1: Write the failing staging tests**

Append to the `reference` source `tables:` in `_reference__sources.yml`:

```yaml
      - name: map_pay_category
      - name: map_payroll_cutover
```

Append to `_reference__models.yml`:

```yaml
  - name: stg_ref__pay_category
    tests:
      - hnh_unique_combination:
          columns: [source, source_code, payable_type]
    columns:
      - name: source
        tests:
          - accepted_values:
              values: ['oasis', 'fusion']
      - name: pay_category
        tests:
          - accepted_values:
              values: ['Basic', 'Housing', 'Transport', 'Food', 'Clinical allowances', 'Other allowances', 'Overtime',
                       'Leave pay', 'End of service', 'Awards and bonus', 'Absence and lateness deduction',
                       'GOSI employer charge', 'Other employer charges', 'GOSI employee deduction', 'Loans and advances',
                       'Other deductions', 'Not pay', 'Unmapped']
  - name: stg_ref__payroll_cutover
    columns:
      - name: branch_id
        tests: [unique, not_null]
```

Run: `python scripts/run_dbt.py build --select stg_ref__pay_category stg_ref__payroll_cutover`
Expected: FAIL — models do not exist.

- [ ] **Step 2: Write the cutover file**

`static_mappings/payroll_cutover.csv` (spec 4.2, from the parallel-run evidence H10):

```csv
BRANCH_ID,FIRST_FUSION_MONTH
7,202603
100,202603
6,202605
3,202607
4,202608
8,202608
```

- [ ] **Step 3: Write and run the pay-category draft script**

`scripts/draft_pay_category_map.py`:

```python
"""Draft static_mappings/pay_category_mapping.csv: Oasis pay codes and Fusion pay-value elements to pay categories.

Keyword rules, first match wins. Codes with no rule are written with PAY_CATEGORY 'Unmapped' for the BI manager to
complete. Fusion: only elements that carry a 'Pay Value' input; a deduction element without 'Results' whose
'<name> Results' twin exists is 'Not pay' (the pair records the same deduction twice).

Usage:  python scripts/draft_pay_category_map.py
"""
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ch_env import client  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "static_mappings" / "pay_category_mapping.csv"

OASIS_RULES = [
    (r"^HOUS_GURNT$", "Other deductions"),
    (r"^STAFF GOSI$|^GOSI_ADJ$", "GOSI employee deduction"),
    (r"^BASIC", "Basic"),
    (r"^HOUS", "Housing"),
    (r"^TRANSP", "Transport"),
    (r"^FOOD", "Food"),
    (r"CRITIC|NUR_ALLW|WRK_NT|WORK_TYPE|WORK TY|^D_H_ALOW", "Clinical allowances"),
    (r"OVERTIM|^FIXOT$", "Overtime"),
    (r"ANN_LEAVE|VAC_PAY|LEAV_PAY|PAY_LEAVE|TIME ?BACK|STUDYLEAVE|MATERNITY|DEATH LEAV", "Leave pay"),
    (r"^PAYAWARD$", "Awards and bonus"),
    (r"HRS_N_WRKD|ABSENCE|^LATE$|SICK|UNPAID|VAC_NOTENT|SHORTAGE|DISPL_DED", "Absence and lateness deduction"),
    (r"^LOAN", "Loans and advances"),
    (r"BANK_CHARG|^WATER$|ELECT|MISC_DED|IQAMA_FEES|WORK_PERM|MCT_EA|EXAM FEES|^MOH$", "Other deductions"),
    (r"SUPV|SUPERV|RECP_ALLOW|DEFC_ALLOW|JZN_ALOWNC|MOBILE|CAR_|SPECIAL|OTHER|ACTINGUP|PROJ_ALLW|B_BANK_ALW|TICK|INSURANCE|ADJ_STAFF|STAFF_ADJ|RETURN_PAY", "Other allowances"),
]

FUSION_NAME_RULES = [
    (r"gosi adjustment deduction", "GOSI employee deduction"),
    (r"loan", "Loans and advances"),
    (r"bank charges|admin penalty|other deductions|shortage", "Other deductions"),
    (r"delay|absence|early leave|one punch|basic salary deduction|allowance deduction|penalty", "Absence and lateness deduction"),
    (r"^basic salary", "Basic"),
    (r"^housing", "Housing"),
    (r"^transportation", "Transport"),
    (r"^food", "Food"),
    (r"critical area|nurse|work nature", "Clinical allowances"),
    (r"overtime", "Overtime"),
    (r"annual leave|encashment|time back", "Leave pay"),
    (r"end of service", "End of service"),
    (r"gosi adjustment|other allowance|supervisor|deficit|department head|special|reception|mobile", "Other allowances"),
]


def first(rules, text):
    return next((cat for pattern, cat in rules if re.search(pattern, text)), "Unmapped")


def main():
    c = client()
    oasis = c.query(
        "select distinct upper(trimBoth(trx_type)), upper(trimBoth(ifNull(payable_type, ''))) "
        "from oasis.account_transactions final where trx_type is not null"
    ).result_rows
    rows = []
    for code, payable in sorted(oasis):
        cat = "GOSI employer charge" if payable == "K" else first(OASIS_RULES, code)
        rows.append(("oasis", code, payable, cat))
    fusion = c.query(
        "select distinct e.element_name, e.classification_name "
        "from fusion.dim_payroll_element e final "
        "join (select distinct element_type_id from fusion.dim_payroll_input_value final "
        "      where input_value_base_name = 'Pay Value') i on i.element_type_id = e.element_type_id "
        "where e.is_current = 'Y' and e.element_name is not null"
    ).result_rows
    names = {n for n, _ in fusion}
    for name, cls in sorted(fusion):
        low = name.lower()
        if cls == "Information":
            cat = "Not pay"
        elif cls == "Employer Charges":
            cat = "GOSI employer charge" if "gosi" in low else "Other employer charges"
        elif cls == "Social Insurance Deductions":
            cat = "GOSI employee deduction"
        elif "deduction" in low and not low.endswith("results") and f"{name} Results" in names:
            cat = "Not pay"
        else:
            cat = first(FUSION_NAME_RULES, low)
        rows.append(("fusion", name, "", cat))
    with open(OUT, "w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["SOURCE", "SOURCE_CODE", "PAYABLE_TYPE", "PAY_CATEGORY"])
        w.writerows(rows)
    unmapped = sum(1 for r in rows if r[3] == "Unmapped")
    print(f"{len(rows)} codes ({len(oasis)} Oasis, {len(fusion)} Fusion), {unmapped} unmapped -> {OUT}")


if __name__ == "__main__":
    main()
```

Run: `python scripts/draft_pay_category_map.py`
Expected: about 90 Oasis and a few hundred Fusion codes (all elements with a Pay Value input, used or not); the unmapped count is printed. Open the CSV and confirm: `BASIC` → Basic, `EMP GOSI` (K) → GOSI employer charge, `STAFF GOSI` → GOSI employee deduction, `Saudi GOSI Reference Earnings` → Not pay, `Basic Salary` → Basic, `Delay Deduction Results` → Absence and lateness deduction, `Basic Salary Deduction` → Not pay (twin), `Employer GOSI Hazards` → GOSI employer charge. Report every Fusion element that was paid in 2026 and is Unmapped (query in the report).

- [ ] **Step 4: Add the loader entries and load**

In `scripts/load_reference_data.py`, add to `SMALL_TABLES`:

```python
    # Pay category per Oasis pay code (with payable type) and Fusion pay-value element; drafted by
    # scripts/draft_pay_category_map.py, reviewed by the BI manager.
    "map_pay_category": (
        "pay_category_mapping.csv",
        [("SOURCE", "LowCardinality(String)", s), ("SOURCE_CODE", "String", s), ("PAYABLE_TYPE", "String", s),
         ("PAY_CATEGORY", "LowCardinality(String)", s)],
        "(SOURCE, SOURCE_CODE, PAYABLE_TYPE)",
    ),
    # First payroll month (yyyymm) paid from Fusion per branch; branches without a row are paid from Oasis.
    "map_payroll_cutover": (
        "payroll_cutover.csv",
        [("BRANCH_ID", "UInt8", i), ("FIRST_FUSION_MONTH", "UInt32", i)],
        "BRANCH_ID",
    ),
```

Run: `cd scripts && python load_reference_data.py --only map_pay_category map_payroll_cutover`
Expected: `map_pay_category: loaded <n>` (the script's count) and `map_payroll_cutover: loaded 6`.

- [ ] **Step 5: Write the staging views**

`stg_ref__pay_category.sql`:

```sql
select
    lower(trimBoth(SOURCE))         as source,
    trimBoth(SOURCE_CODE)           as source_code,
    upper(trimBoth(PAYABLE_TYPE))   as payable_type,
    trimBoth(PAY_CATEGORY)          as pay_category
from {{ source('reference', 'map_pay_category') }}
```

`stg_ref__payroll_cutover.sql`:

```sql
select
    toUInt8(BRANCH_ID)              as branch_id,
    toInt32(FIRST_FUSION_MONTH)     as first_fusion_month
from {{ source('reference', 'map_payroll_cutover') }}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `python scripts/run_dbt.py build --no-partial-parse --select stg_ref__pay_category stg_ref__payroll_cutover`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add scripts/load_reference_data.py scripts/draft_pay_category_map.py hnh_dwh/models/hnh/staging/reference/
git commit -m "Load the pay-category map and the payroll cutover months"
```

---

### Task 3: HCM and Oasis payroll staging

**Files:**
- Modify: `hnh_dwh/models/hnh/staging/fusion/_fusion__sources.yml`, `_fusion__models.yml`, `hnh_dwh/models/hnh/staging/oasis/_oasis__sources.yml`, `_oasis__models.yml`
- Create (in `staging/fusion/`): `stg_fusion__employees.sql`, `stg_fusion__assignments.sql`, `stg_fusion__periods_of_service.sql`, `stg_fusion__worker_movements.sql`, `stg_fusion__work_measures.sql`, `stg_fusion__hr_departments.sql`, `stg_fusion__organizations.sql`, `stg_fusion__jobs.sql`, `stg_fusion__grades.sql`, `stg_fusion__positions.sql`, `stg_fusion__locations.sql`, `stg_fusion__worker_actions.sql`, `stg_fusion__payroll_run_results.sql`, `stg_fusion__payroll_elements.sql`, `stg_fusion__payroll_input_values.sql`, `stg_fusion__absence_entries.sql`, `stg_fusion__absence_types.sql`, `stg_fusion__absence_plans.sql`, `stg_fusion__absence_balances.sql`; (in `staging/oasis/`) `stg_oasis__payroll_transactions.sql`

**Interfaces:**
- Consumes: `hnh_fusion_source`, `hnh_oasis_source`, `hnh_str`, `hnh_code`, `hnh_flag`.
- Produces (date columns are `Date32` unless noted; flags `UInt8`):
  - `stg_fusion__employees(person_id, valid_from, valid_to, is_current, person_number, worker_type, gender, nationality, birth_date, hire_date, termination_date, legal_employer_id)`
  - `stg_fusion__assignments(assignment_id, valid_from, valid_to, is_current, person_id, assignment_type, assignment_status, is_primary, organization_id, job_id, position_id, grade_id, location_id, legal_employer_id)`
  - `stg_fusion__periods_of_service(period_of_service_id, person_id, legal_employer_id, worker_number, start_date, original_hire_date, termination_date, is_terminated)`
  - `stg_fusion__worker_movements(assignment_id, effective_end_date_key, effective_sequence, effective_start_date, person_id, action_code, action_reason_code, action_date, assignment_status, organization_id, job_id, position_id, grade_id, location_id, previous_organization_id, previous_job_id, previous_position_id, previous_grade_id, previous_location_id, is_organization_changed, is_job_changed, is_position_changed, is_grade_changed, is_location_changed)`
  - `stg_fusion__work_measures(assign_work_measure_id, assignment_id, unit, value Float64, effective_start_date, effective_end_date)`
  - `stg_fusion__hr_departments(organization_id, department_name)` (current rows)
  - `stg_fusion__organizations(organization_id, organization_name, classification_codes)` (current rows)
  - `stg_fusion__jobs(job_id, job_code, job_name, full_part_time, regular_temporary)`, `stg_fusion__grades(grade_id, grade_code, grade_name)`, `stg_fusion__positions(position_id, position_code, position_name)`, `stg_fusion__locations(location_id, location_code, location_name, town_or_city)` (current rows)
  - `stg_fusion__worker_actions(action_code, action_reason_code, action_name, action_reason_name)`
  - `stg_fusion__payroll_run_results(run_result_id, input_value_id, element_type_id, person_id, legal_employer_id, payroll_action_status, effective_date, result_value Nullable(Float64))`
  - `stg_fusion__payroll_elements(element_type_id, element_name, classification_name)`, `stg_fusion__payroll_input_values(input_value_id, element_type_id, input_value_base_name, uom)` (current rows)
  - `stg_fusion__absence_entries(absence_entry_id, person_id, absence_type_id, legal_employer_id, absence_status_code, approval_status_code, start_date, end_date, duration Nullable(Float64), duration_uom)`
  - `stg_fusion__absence_types(absence_type_id, absence_type_name, absence_plan_name, plan_type)`, `stg_fusion__absence_plans(absence_plan_id, absence_plan_name, plan_type)` (current rows)
  - `stg_fusion__absence_balances(accrual_entry_id, person_id, absence_plan_id, accrual_period_date, status, begin_balance, accrued, used, end_balance)` (Float64)
  - `stg_oasis__payroll_transactions(branch_id UInt8, account_transaction_no Int64, staff_id, payroll_month Int32, trx_type, payable_type, status, amount Float64)`

- [ ] **Step 1: Declare sources and write the failing tests**

Append to the `fusion` source `tables:` in `_fusion__sources.yml`:

```yaml
      - name: dim_employee
      - name: dim_assignment
      - name: fact_period_of_service
      - name: fact_worker_movement
      - name: fact_assignment_work_measure
      - name: dim_department
      - name: dim_organization
      - name: dim_job
      - name: dim_grade
      - name: dim_position
      - name: dim_location
      - name: dim_worker_action
      - name: fact_payroll_run_result
      - name: dim_payroll_element
      - name: dim_payroll_input_value
      - name: fact_absence_entry
      - name: dim_absence_type
      - name: dim_absence_plan
      - name: fact_absence_balance
```

Append to the `oasis` source `tables:` in `_oasis__sources.yml`:

```yaml
      - name: account_transactions
```

Append to `_fusion__models.yml`:

```yaml
  - name: stg_fusion__employees
    tests:
      - hnh_unique_combination:
          columns: [person_id, valid_from]
  - name: stg_fusion__assignments
    tests:
      - hnh_unique_combination:
          columns: [assignment_id, valid_from]
  - name: stg_fusion__periods_of_service
    columns:
      - name: period_of_service_id
        tests: [unique, not_null]
  - name: stg_fusion__worker_movements
    tests:
      - hnh_unique_combination:
          columns: [assignment_id, effective_end_date_key, effective_sequence]
  - name: stg_fusion__work_measures
    columns:
      - name: assign_work_measure_id
        tests: [not_null]
  - name: stg_fusion__hr_departments
    columns:
      - name: organization_id
        tests: [unique, not_null]
  - name: stg_fusion__organizations
    columns:
      - name: organization_id
        tests: [unique, not_null]
  - name: stg_fusion__jobs
    columns:
      - name: job_id
        tests: [unique, not_null]
  - name: stg_fusion__grades
    columns:
      - name: grade_id
        tests: [unique, not_null]
  - name: stg_fusion__positions
    columns:
      - name: position_id
        tests: [unique, not_null]
  - name: stg_fusion__locations
    columns:
      - name: location_id
        tests: [unique, not_null]
  - name: stg_fusion__worker_actions
    tests:
      - hnh_unique_combination:
          columns: [action_code, action_reason_code]
  - name: stg_fusion__payroll_run_results
    tests:
      - hnh_unique_combination:
          columns: [run_result_id, input_value_id]
  - name: stg_fusion__payroll_elements
    columns:
      - name: element_type_id
        tests: [unique, not_null]
  - name: stg_fusion__payroll_input_values
    columns:
      - name: input_value_id
        tests: [unique, not_null]
  - name: stg_fusion__absence_entries
    columns:
      - name: absence_entry_id
        tests: [unique, not_null]
  - name: stg_fusion__absence_types
    columns:
      - name: absence_type_id
        tests: [unique, not_null]
  - name: stg_fusion__absence_plans
    columns:
      - name: absence_plan_id
        tests: [unique, not_null]
  - name: stg_fusion__absence_balances
    columns:
      - name: accrual_entry_id
        tests: [unique, not_null]
```

Append to `_oasis__models.yml`:

```yaml
  - name: stg_oasis__payroll_transactions
    tests:
      - hnh_unique_combination:
          columns: [branch_id, account_transaction_no]
```

Run: `python scripts/run_dbt.py build --select path:models/hnh/staging/fusion stg_oasis__payroll_transactions`
Expected: FAIL — the new models do not exist (the Phase 3 views build).

- [ ] **Step 2: Write the views**

`stg_fusion__employees.sql` (names, phones, e-mail, national id, religion and marital status are not selected):

```sql
select
    person_id,
    toDate32(valid_from)                    as valid_from,
    toDate32(ifNull(valid_to, toDateTime64('2299-12-31 00:00:00', 6, 'UTC'))) as valid_to,
    toUInt8(ifNull(is_current, '') = 'Y')   as is_current,
    {{ hnh_code('person_number') }}         as person_number,
    {{ hnh_code('worker_type') }}           as worker_type,
    {{ hnh_code('gender') }}                as gender,
    {{ hnh_code('nationality') }}           as nationality,
    toDate32(date_of_birth)                 as birth_date,
    toDate32(hire_date)                     as hire_date,
    toDate32(actual_termination_date)       as termination_date,
    legal_employer_id
from {{ hnh_fusion_source('dim_employee') }} final
```

`stg_fusion__assignments.sql`:

```sql
select
    assignment_id,
    toDate32(valid_from)                    as valid_from,
    toDate32(ifNull(valid_to, toDateTime64('2299-12-31 00:00:00', 6, 'UTC'))) as valid_to,
    toUInt8(ifNull(is_current, '') = 'Y')   as is_current,
    person_id,
    {{ hnh_code('assignment_type') }}       as assignment_type,
    {{ hnh_code('assignment_status_type') }} as assignment_status,
    {{ hnh_flag('primary_flag') }}          as is_primary,
    organization_id,
    job_id,
    position_id,
    grade_id,
    location_id,
    legal_employer_id
from {{ hnh_fusion_source('dim_assignment') }} final
```

`stg_fusion__periods_of_service.sql`:

```sql
select
    period_of_service_id,
    person_id,
    legal_employer_id,
    {{ hnh_code('worker_number') }}                         as worker_number,
    toDate32(start_date)                                    as start_date,
    toDate32OrNull(substring(ifNull(original_date_of_hire, ''), 1, 10)) as original_hire_date,
    toDate32(actual_termination_date)                       as termination_date,
    {{ hnh_flag('terminated_flag') }}                       as is_terminated
from {{ hnh_fusion_source('fact_period_of_service') }} final
```

`stg_fusion__worker_movements.sql`:

```sql
select
    assignment_id,
    effective_end_date_key,
    effective_sequence,
    toDate32(effective_start_date)          as effective_start_date,
    person_id,
    {{ hnh_code('action_code') }}           as action_code,
    {{ hnh_code('action_reason_code') }}    as action_reason_code,
    toDate32(coalesce(action_date, effective_start_date)) as action_date,
    {{ hnh_code('assignment_status_type') }} as assignment_status,
    organization_id, job_id, position_id, grade_id, location_id,
    previous_organization_id, previous_job_id, previous_position_id, previous_grade_id, previous_location_id,
    {{ hnh_flag('organization_changed_flag') }} as is_organization_changed,
    {{ hnh_flag('job_changed_flag') }}          as is_job_changed,
    {{ hnh_flag('position_changed_flag') }}     as is_position_changed,
    {{ hnh_flag('grade_changed_flag') }}        as is_grade_changed,
    {{ hnh_flag('location_changed_flag') }}     as is_location_changed
from {{ hnh_fusion_source('fact_worker_movement') }} final
```

`stg_fusion__work_measures.sql`:

```sql
select
    assign_work_measure_id,
    assignment_id,
    {{ hnh_code('unit') }}                          as unit,
    toFloat64(ifNull(work_measure_value, 0))        as value,
    toDate32(effective_start_date)                  as effective_start_date,
    toDate32(ifNull(effective_end_date, toDateTime64('2299-12-31 00:00:00', 6, 'UTC'))) as effective_end_date
from {{ hnh_fusion_source('fact_assignment_work_measure') }} final
```

`stg_fusion__hr_departments.sql`:

```sql
select organization_id, {{ hnh_str('organization_name') }} as department_name
from {{ hnh_fusion_source('dim_department') }} final
where ifNull(is_current, '') = 'Y'
```

`stg_fusion__organizations.sql`:

```sql
select organization_id,
       {{ hnh_str('organization_name') }}      as organization_name,
       {{ hnh_str('classification_codes') }}   as classification_codes
from {{ hnh_fusion_source('dim_organization') }} final
where ifNull(is_current, '') = 'Y'
limit 1 by organization_id
```

`stg_fusion__jobs.sql`:

```sql
select job_id, {{ hnh_str('job_code') }} as job_code, {{ hnh_str('job_name') }} as job_name,
       {{ hnh_code('full_part_time') }} as full_part_time, {{ hnh_code('regular_temporary') }} as regular_temporary
from {{ hnh_fusion_source('dim_job') }} final
where ifNull(is_current, '') = 'Y'
```

`stg_fusion__grades.sql`:

```sql
select grade_id, {{ hnh_str('grade_code') }} as grade_code, {{ hnh_str('grade_name') }} as grade_name
from {{ hnh_fusion_source('dim_grade') }} final
where ifNull(is_current, '') = 'Y'
```

`stg_fusion__positions.sql`:

```sql
select position_id, {{ hnh_str('position_code') }} as position_code, {{ hnh_str('position_name') }} as position_name
from {{ hnh_fusion_source('dim_position') }} final
where ifNull(is_current, '') = 'Y'
```

`stg_fusion__locations.sql`:

```sql
select location_id, {{ hnh_str('location_code') }} as location_code, {{ hnh_str('location_name') }} as location_name,
       {{ hnh_str('town_or_city') }} as town_or_city
from {{ hnh_fusion_source('dim_location') }} final
where ifNull(is_current, '') = 'Y'
limit 1 by location_id
```

`stg_fusion__worker_actions.sql` (one row per action and reason across business groups):

```sql
select {{ hnh_code('action_code') }} as action_code, {{ hnh_code('action_reason_code') }} as action_reason_code,
       any({{ hnh_str('action_name') }}) as action_name, any({{ hnh_str('action_reason_name') }}) as action_reason_name
from {{ hnh_fusion_source('dim_worker_action') }} final
group by action_code, action_reason_code
```

`stg_fusion__payroll_run_results.sql`:

```sql
select
    run_result_id,
    input_value_id,
    element_type_id,
    person_id,
    legal_employer_id,
    {{ hnh_code('payroll_action_status') }}     as payroll_action_status,
    toDate32(payroll_effective_date)            as effective_date,
    toFloat64OrNull(trimBoth(ifNull(result_value, ''))) as result_value
from {{ hnh_fusion_source('fact_payroll_run_result') }} final
```

`stg_fusion__payroll_elements.sql`:

```sql
select element_type_id, {{ hnh_str('element_name') }} as element_name, {{ hnh_str('classification_name') }} as classification_name
from {{ hnh_fusion_source('dim_payroll_element') }} final
where ifNull(is_current, '') = 'Y'
```

`stg_fusion__payroll_input_values.sql`:

```sql
select input_value_id, element_type_id, {{ hnh_str('input_value_base_name') }} as input_value_base_name, {{ hnh_code('uom') }} as uom
from {{ hnh_fusion_source('dim_payroll_input_value') }} final
where ifNull(is_current, '') = 'Y'
```

`stg_fusion__absence_entries.sql`:

```sql
select
    per_absence_entry_id                        as absence_entry_id,
    person_id,
    absence_type_id,
    legal_employer_id,
    {{ hnh_code('absence_status_code') }}       as absence_status_code,
    {{ hnh_code('approval_status_code') }}      as approval_status_code,
    toDate32(absence_start_date)                as start_date,
    toDate32(absence_end_date)                  as end_date,
    toFloat64OrNull(trimBoth(ifNull(duration, ''))) as duration,
    {{ hnh_code('duration_uom') }}              as duration_uom
from {{ hnh_fusion_source('fact_absence_entry') }} final
```

`stg_fusion__absence_types.sql`:

```sql
select absence_type_id, {{ hnh_str('absence_type_name') }} as absence_type_name,
       {{ hnh_str('absence_plan_name') }} as absence_plan_name, {{ hnh_code('plan_type') }} as plan_type
from {{ hnh_fusion_source('dim_absence_type') }} final
where ifNull(is_current, '') = 'Y'
```

`stg_fusion__absence_plans.sql`:

```sql
select absence_plan_id, {{ hnh_str('absence_plan_name') }} as absence_plan_name, {{ hnh_code('plan_type') }} as plan_type
from {{ hnh_fusion_source('dim_absence_plan') }} final
where ifNull(is_current, '') = 'Y'
```

`stg_fusion__absence_balances.sql`:

```sql
select
    per_accrual_entry_id                    as accrual_entry_id,
    person_id,
    absence_plan_id,
    toDate32(accrual_period_date)           as accrual_period_date,
    {{ hnh_code('status') }}                as status,
    toFloat64(ifNull(begin_balance, 0))     as begin_balance,
    toFloat64(ifNull(accrued, 0))           as accrued,
    toFloat64(ifNull(used, 0))              as used,
    toFloat64(ifNull(end_balance, 0))       as end_balance
from {{ hnh_fusion_source('fact_absence_balance') }} final
```

`staging/oasis/stg_oasis__payroll_transactions.sql`:

```sql
select
    toUInt8(branch_id)                          as branch_id,
    toInt64(account_transaction_no)             as account_transaction_no,
    {{ hnh_code('staff_id') }}                  as staff_id,
    toInt32(ifNull(year, 0) * 100 + ifNull(period, 0)) as payroll_month,
    upper(trimBoth(ifNull(trx_type, '')))       as trx_type,
    upper(trimBoth(ifNull(payable_type, '')))   as payable_type,
    {{ hnh_code('status') }}                    as status,
    toFloat64(ifNull(amount, 0))                as amount
from {{ hnh_oasis_source('account_transactions') }} final
```

- [ ] **Step 3: Run the tests to verify they pass**

Run: `python scripts/run_dbt.py build --no-partial-parse --select path:models/hnh/staging/fusion stg_oasis__payroll_transactions`
Expected: all PASS. If `stg_fusion__organizations` or `stg_fusion__locations` fail uniqueness without `limit 1 by`, keep the `limit 1 by` as written; if any other uniqueness test fails, report the duplicated keys instead of adding `limit 1 by`.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/staging/
git commit -m "Stage Fusion HCM, payroll and absence tables and Oasis payroll transactions"
```

---

### Task 4: HR intermediate models

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/workforce/int_legal_employer_branch.sql`, `int_employee_period.sql`, `int_assignment_month_end.sql`, `_workforce__models.yml`, `_workforce_unit_tests.yml`

**Interfaces:**
- Consumes: `stg_fusion__organizations`, `stg_fusion__business_units` (Phase 3), `hnh_dim_branch`, `stg_fusion__periods_of_service`, `stg_fusion__assignments`, `stg_fusion__work_measures`; `hnh_hr_month_ends`.
- Produces:
  - `int_legal_employer_branch(legal_employer_id Int64, legal_employer_name String, branch_key UInt8)` (0 when unresolved)
  - `int_employee_period(person_id Int64, period_of_service_id, worker_number, start_date, original_hire_date, termination_date, is_terminated, legal_employer_id, branch_key UInt8)` (latest period per person)
  - `int_assignment_month_end(person_id, month_end Date, assignment_id, assignment_type, assignment_status, organization_id, job_id, position_id, grade_id, location_id, legal_employer_id, branch_key UInt8, fte Float64)`

- [ ] **Step 1: Write YAML tests and the failing unit tests**

`_workforce__models.yml`:

```yaml
version: 2

models:
  - name: int_legal_employer_branch
    columns:
      - name: legal_employer_id
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
  - name: int_employee_period
    columns:
      - name: person_id
        tests: [unique, not_null]
  - name: int_assignment_month_end
    tests:
      - hnh_unique_combination:
          columns: [person_id, month_end]
```

`_workforce_unit_tests.yml`:

```yaml
version: 2

unit_tests:
  - name: int_legal_employer_branch_resolves_names
    description: "HNH Abha" resolves through business unit "Abha" and its ledger to branch 6; Head Office to 100; an unknown employer to 0.
    model: int_legal_employer_branch
    given:
      - input: ref('stg_fusion__organizations')
        format: sql
        rows: |
          select toInt64(o) as organization_id, toNullable(n) as organization_name, toNullable('HCM_LEMP,HCM_PSU') as classification_codes
          from values('o UInt32, n String', (1, 'HNH Abha'), (2, 'HNH Head Office'), (3, 'HNH Nowhere'))
      - input: ref('stg_fusion__business_units')
        format: sql
        rows: |
          select toInt64(b) as business_unit_id, toNullable(n) as business_unit_name, toNullable(toInt64(l)) as primary_ledger_id
          from values('b UInt32, n String, l UInt64', (10, 'Abha', 300000005003384), (11, 'Head Office', 300000005003375))
      - input: ref('hnh_dim_branch')
        format: sql
        rows: |
          select toUInt8(k) as branch_key, toNullable(toInt64(l)) as fusion_ledger_id
          from values('k UInt8, l UInt64', (6, 300000005003384), (100, 300000005003375))
    expect:
      rows:
        - {legal_employer_id: 1, branch_key: 6}
        - {legal_employer_id: 2, branch_key: 100}
        - {legal_employer_id: 3, branch_key: 0}

  - name: int_assignment_month_end_picks_one_assignment
    description: >
      Window January–March 2026. Person 1 changes job on 2026-01-16 (two history rows): January takes the row valid on
      31 January (job 20). Person 2 is INACTIVE in February (kept here with its status; the fact drops it). Person 3 has
      two primary active assignments: the one with the later valid_from (assignment 31) wins. Person 1 has an FTE
      measure of 0.5 from February; values outside (0, 1.5] or missing give 1.
    model: int_assignment_month_end
    overrides:
      vars:
        hnh_hr_snapshot_start: "2026-01-01"
        hnh_hr_snapshot_end: "2026-03-31"
    given:
      - input: ref('stg_fusion__assignments')
        format: sql
        rows: |
          select toInt64(a) as assignment_id, toDate32(vf) as valid_from, toDate32(vt) as valid_to, toNullable(toInt64(p)) as person_id,
                 toNullable('E') as assignment_type, toNullable(st) as assignment_status, toUInt8(1) as is_primary,
                 toNullable(toInt64(900)) as organization_id, toNullable(toInt64(j)) as job_id, cast(null as Nullable(Int64)) as position_id,
                 cast(null as Nullable(Int64)) as grade_id, cast(null as Nullable(Int64)) as location_id, toNullable(toInt64(1)) as legal_employer_id
          from values('a UInt32, vf String, vt String, p UInt32, st String, j UInt32',
              (11, '2025-01-01', '2026-01-15', 1, 'ACTIVE', 10), (11, '2026-01-16', '2299-12-31', 1, 'ACTIVE', 20),
              (21, '2025-01-01', '2026-01-31', 2, 'ACTIVE', 10), (21, '2026-02-01', '2026-02-28', 2, 'INACTIVE', 10),
              (21, '2026-03-01', '2299-12-31', 2, 'ACTIVE', 10),
              (30, '2024-01-01', '2299-12-31', 3, 'ACTIVE', 10), (31, '2025-06-01', '2299-12-31', 3, 'ACTIVE', 30))
      - input: ref('stg_fusion__work_measures')
        format: sql
        rows: |
          select toInt64(m) as assign_work_measure_id, toNullable(toInt64(a)) as assignment_id, toNullable(u) as unit,
                 toFloat64(v) as value, toDate32(s) as effective_start_date, toDate32('2299-12-31') as effective_end_date
          from values('m UInt32, a UInt32, u String, v Float64, s String', (1, 11, 'FTE', 0.5, '2026-02-01'), (2, 21, 'FTE', 0, '2025-01-01'))
      - input: ref('int_legal_employer_branch')
        format: sql
        rows: |
          select toInt64(1) as legal_employer_id, toUInt8(6) as branch_key
    expect:
      rows:
        - {person_id: 1, month_end: 2026-01-31, assignment_id: 11, job_id: 20, assignment_status: ACTIVE, branch_key: 6, fte: 1}
        - {person_id: 1, month_end: 2026-02-28, assignment_id: 11, job_id: 20, assignment_status: ACTIVE, branch_key: 6, fte: 0.5}
        - {person_id: 1, month_end: 2026-03-31, assignment_id: 11, job_id: 20, assignment_status: ACTIVE, branch_key: 6, fte: 0.5}
        - {person_id: 2, month_end: 2026-01-31, assignment_id: 21, job_id: 10, assignment_status: ACTIVE, branch_key: 6, fte: 1}
        - {person_id: 2, month_end: 2026-02-28, assignment_id: 21, job_id: 10, assignment_status: INACTIVE, branch_key: 6, fte: 1}
        - {person_id: 2, month_end: 2026-03-31, assignment_id: 21, job_id: 10, assignment_status: ACTIVE, branch_key: 6, fte: 1}
        - {person_id: 3, month_end: 2026-01-31, assignment_id: 31, job_id: 30, assignment_status: ACTIVE, branch_key: 6, fte: 1}
        - {person_id: 3, month_end: 2026-02-28, assignment_id: 31, job_id: 30, assignment_status: ACTIVE, branch_key: 6, fte: 1}
        - {person_id: 3, month_end: 2026-03-31, assignment_id: 31, job_id: 30, assignment_status: ACTIVE, branch_key: 6, fte: 1}
```

Run: `python scripts/run_dbt.py test --no-partial-parse --select int_legal_employer_branch_resolves_names int_assignment_month_end_picks_one_assignment`
Expected: FAIL — models not found.

- [ ] **Step 2: Write the three models**

`int_legal_employer_branch.sql`:

```sql
-- Legal employer (an organisation named "HNH <name>") to branch: "<name>" is a Fusion business-unit name whose
-- primary ledger is the branch's ledger (spec 4.1). Unresolved employers get branch 0, which the facts' tests reject.
select
    o.organization_id                                   as legal_employer_id,
    ifNull(o.organization_name, '')                     as legal_employer_name,
    ifNull(b.branch_key, toUInt8(0))                    as branch_key
from {{ ref('stg_fusion__organizations') }} as o
left join (select business_unit_name, primary_ledger_id from {{ ref('stg_fusion__business_units') }}) as bu
    on bu.business_unit_name = replaceOne(ifNull(o.organization_name, ''), 'HNH ', '')
left join (select branch_key, fusion_ledger_id from {{ ref('hnh_dim_branch') }} where fusion_ledger_id is not null) as b
    on b.fusion_ledger_id = bu.primary_ledger_id
where ifNull(o.classification_codes, '') like '%HCM_LEMP%'
{{ hnh_settings() }}
```

`int_employee_period.sql`:

```sql
-- The latest period of service of each person (by start date, then period id) with its legal employer's branch.
with latest as (
    select *
    from {{ ref('stg_fusion__periods_of_service') }}
    where person_id is not null
    order by person_id, start_date desc, period_of_service_id desc
    limit 1 by person_id
)

select
    assumeNotNull(l.person_id)              as person_id,
    l.period_of_service_id                  as period_of_service_id,
    l.worker_number                         as worker_number,
    l.start_date                            as start_date,
    l.original_hire_date                    as original_hire_date,
    l.termination_date                      as termination_date,
    l.is_terminated                         as is_terminated,
    l.legal_employer_id                     as legal_employer_id,
    ifNull(b.branch_key, toUInt8(0))        as branch_key
from latest as l
left join {{ ref('int_legal_employer_branch') }} as b on b.legal_employer_id = l.legal_employer_id
{{ hnh_settings() }}
```

`int_assignment_month_end.sql`:

```sql
-- The primary assignment valid at each month-end of the snapshot window, one per person. Ties (two primary
-- assignments): ACTIVE before SUSPENDED before other statuses, then the latest valid_from, then the highest id.
with months as ({{ hnh_hr_month_ends() }}),

candidates as (
    select a.person_id as person_id, m.month_end as month_end, a.assignment_id as assignment_id,
           a.valid_from as valid_from, a.assignment_type as assignment_type, a.assignment_status as assignment_status,
           a.organization_id as organization_id, a.job_id as job_id, a.position_id as position_id,
           a.grade_id as grade_id, a.location_id as location_id, a.legal_employer_id as legal_employer_id
    from {{ ref('stg_fusion__assignments') }} as a
    cross join months as m
    where a.is_primary = 1 and a.person_id is not null
      and a.valid_from <= m.month_end and a.valid_to >= m.month_end
),

picked as (
    select *
    from candidates
    order by person_id, month_end,
             multiIf(ifNull(assignment_status, '') = 'ACTIVE', 1, ifNull(assignment_status, '') = 'SUSPENDED', 2, 3),
             valid_from desc, assignment_id desc
    limit 1 by person_id, month_end
),

fte_at_month_end as (
    select p.assignment_id as assignment_id, p.month_end as month_end, argMax(w.value, w.effective_start_date) as fte_value
    from picked as p
    inner join (select assignment_id, value, effective_start_date, effective_end_date
                from {{ ref('stg_fusion__work_measures') }} where unit = 'FTE') as w
        on w.assignment_id = p.assignment_id
    where w.effective_start_date <= p.month_end and w.effective_end_date >= p.month_end
    group by p.assignment_id, p.month_end
)

select
    assumeNotNull(p.person_id)              as person_id,
    p.month_end                             as month_end,
    p.assignment_id                         as assignment_id,
    p.assignment_type                       as assignment_type,
    p.assignment_status                     as assignment_status,
    p.organization_id                       as organization_id,
    p.job_id                                as job_id,
    p.position_id                           as position_id,
    p.grade_id                              as grade_id,
    p.location_id                           as location_id,
    p.legal_employer_id                     as legal_employer_id,
    ifNull(b.branch_key, toUInt8(0))        as branch_key,
    {{ hnh_fte('f.fte_value') }}            as fte
from picked as p
left join fte_at_month_end as f on f.assignment_id = p.assignment_id and f.month_end = p.month_end
left join {{ ref('int_legal_employer_branch') }} as b on b.legal_employer_id = p.legal_employer_id
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the unit tests and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select int_legal_employer_branch int_employee_period int_assignment_month_end`
Expected: both unit tests PASS, models built, YAML tests PASS. Then check: `select branch_key, count() from int.int_legal_employer_branch group by 1` — expect nine legal employers on branches 1–8 and 100, none on 0.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/workforce/
git commit -m "Resolve legal employers to branches and build the month-end assignment snapshot"
```

---

### Task 5: Workforce dimensions and the staff bridge

**Files:**
- Create in `hnh_dwh/models/hnh/marts/conformed/`: `hnh_dim_employee.sql`, `hnh_dim_hr_department.sql`, `hnh_dim_job.sql`, `hnh_dim_grade.sql`, `hnh_dim_position.sql`, `hnh_dim_location.sql`, `hnh_dim_worker_action.sql`, `hnh_dim_absence_type.sql`, `dim_pay_category.sql`, `bridge_employee_staff.sql`, `_workforce_conformed_unit_tests.yml`
- Modify: `_conformed__models.yml`

**Interfaces:**
- Consumes: Task 3 staging; Task 4 intermediates; `dim_staff` (staff_key = `hnh_surrogate_key([branch_id, staff_id])`), `stg_ref__fusion_specialty_unified` (Phase 3: `specialty_name`, `unified_department`).
- Produces (all with an Unknown `-1` row unless noted):
  - `hnh_dim_employee(employee_key, person_id, person_number, worker_number, worker_type, worker_type_code, gender, nationality, is_saudi, birth_date, age_band, hire_date, original_hire_date, termination_date, is_terminated, tenure_band, branch_key, hr_department_key, job_key, grade_key, position_key, location_key, assignment_status, staff_key)` — alias `dim_employee`, `employee_key` = `hnh_surrogate_key(['person_id'])`
  - `hnh_dim_hr_department(hr_department_key, organization_id, department_name, branch_prefix, department_base_name, unified_department, branch_key)`
  - `hnh_dim_job(job_key, job_id, job_code, job_name, full_part_time, regular_temporary)`, `hnh_dim_grade(grade_key, grade_id, grade_code, grade_name)`, `hnh_dim_position(position_key, position_id, position_code, position_name)`, `hnh_dim_location(location_key, location_id, location_code, location_name, town_or_city)`
  - `hnh_dim_worker_action(worker_action_key, action_code, action_reason_code, action_name, action_reason_name, movement_group)`
  - `hnh_dim_absence_type(absence_type_key, absence_type_id, absence_type_name, absence_plan_name, plan_type, absence_category)`
  - `dim_pay_category(pay_category_key, pay_category, pay_group, is_cost, is_gross_pay, is_recurring, fusion_sign Int8, sort_order)` (no Unknown row; `Unmapped` is a member)
  - `bridge_employee_staff(employee_key, staff_key, branch_key, worker_number, match_method)`
  - Keys: `hr_department_key = hnh_surrogate_key(['organization_id'])`, `job_key = …(['job_id'])`, `grade_key`, `position_key`, `location_key` likewise, `worker_action_key = …(['action_code', 'action_reason_code'])`, `absence_type_key = …(['absence_type_id'])`, `pay_category_key = …(['pay_category'])`.

- [ ] **Step 1: Write the YAML tests and the failing unit test**

Append to `_conformed__models.yml`:

```yaml
  - name: hnh_dim_employee
    columns:
      - name: employee_key
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
  - name: hnh_dim_hr_department
    columns:
      - name: hr_department_key
        tests: [unique, not_null]
  - name: hnh_dim_job
    columns:
      - name: job_key
        tests: [unique, not_null]
  - name: hnh_dim_grade
    columns:
      - name: grade_key
        tests: [unique, not_null]
  - name: hnh_dim_position
    columns:
      - name: position_key
        tests: [unique, not_null]
  - name: hnh_dim_location
    columns:
      - name: location_key
        tests: [unique, not_null]
  - name: hnh_dim_worker_action
    columns:
      - name: worker_action_key
        tests: [unique, not_null]
  - name: hnh_dim_absence_type
    columns:
      - name: absence_type_key
        tests: [unique, not_null]
  - name: dim_pay_category
    columns:
      - name: pay_category_key
        tests: [unique, not_null]
  - name: bridge_employee_staff
    columns:
      - name: employee_key
        tests:
          - unique
          - relationships: {to: ref('hnh_dim_employee'), field: employee_key}
      - name: staff_key
        tests:
          - relationships: {to: ref('dim_staff'), field: staff_key}
```

`_workforce_conformed_unit_tests.yml`:

```yaml
version: 2

unit_tests:
  - name: bridge_employee_staff_matches_within_branch
    description: >
      Worker 500 exists as Oasis staff in branches 4 and 5; the employee belongs to branch 4, so only the branch 4
      record links. Worker 600 (branch 4) has no Oasis record. A Head Office employee (branch 100) is never linked.
    model: bridge_employee_staff
    given:
      - input: ref('int_employee_period')
        format: sql
        rows: |
          select toInt64(p) as person_id, toNullable(w) as worker_number, toUInt8(b) as branch_key
          from values('p UInt32, w String, b UInt8', (1, '500', 4), (2, '600', 4), (3, '500', 100))
      - input: ref('dim_staff')
        format: sql
        rows: |
          select {{ hnh_surrogate_key(['toUInt8(b)', 's']) }} as staff_key, toUInt8(b) as branch_key, s as staff_id
          from values('b UInt8, s String', (4, '500'), (5, '500'))
    expect:
      rows:
        - {worker_number: '500', branch_key: 4, match_method: worker_number}
```

If the unit-test runner does not render the Jinja macro in the fixture, replace the `staff_key` expression with the literal values from `select toInt64(bitShiftRight(cityHash64(concat('4','|','500','|')),1)), toInt64(bitShiftRight(cityHash64(concat('5','|','500','|')),1))` (run through `ch_env`), and note it in the report.

Run: `python scripts/run_dbt.py test --no-partial-parse --select bridge_employee_staff_matches_within_branch`
Expected: FAIL — model not found.

- [ ] **Step 2: Write the small dimensions**

`hnh_dim_job.sql`:

```sql
{{ config(alias='dim_job', order_by='job_key') }}
select {{ hnh_surrogate_key(['job_id']) }} as job_key, toNullable(job_id) as job_id, job_code, job_name, full_part_time, regular_temporary
from {{ ref('stg_fusion__jobs') }}
union all
select toInt64(-1), null, null, 'Unknown', null, null
```

`hnh_dim_grade.sql`:

```sql
{{ config(alias='dim_grade', order_by='grade_key') }}
select {{ hnh_surrogate_key(['grade_id']) }} as grade_key, toNullable(grade_id) as grade_id, grade_code, grade_name
from {{ ref('stg_fusion__grades') }}
union all
select toInt64(-1), null, null, 'Unknown'
```

`hnh_dim_position.sql`:

```sql
{{ config(alias='dim_position', order_by='position_key') }}
select {{ hnh_surrogate_key(['position_id']) }} as position_key, toNullable(position_id) as position_id, position_code, position_name
from {{ ref('stg_fusion__positions') }}
union all
select toInt64(-1), null, null, 'Unknown'
```

`hnh_dim_location.sql`:

```sql
{{ config(alias='dim_location', order_by='location_key') }}
select {{ hnh_surrogate_key(['location_id']) }} as location_key, toNullable(location_id) as location_id, location_code, location_name, town_or_city
from {{ ref('stg_fusion__locations') }}
union all
select toInt64(-1), null, null, 'Unknown', null
```

`hnh_dim_worker_action.sql`:

```sql
{{ config(alias='dim_worker_action', order_by='worker_action_key') }}
select {{ hnh_surrogate_key(['action_code', 'action_reason_code']) }} as worker_action_key,
       toNullable(action_code) as action_code, toNullable(action_reason_code) as action_reason_code,
       action_name, action_reason_name, {{ hnh_movement_group('action_code') }} as movement_group
from {{ ref('stg_fusion__worker_actions') }}
union all
select toInt64(-1), null, null, 'Unknown', null, 'Other'
```

`hnh_dim_absence_type.sql`:

```sql
{{ config(alias='dim_absence_type', order_by='absence_type_key') }}
select {{ hnh_surrogate_key(['absence_type_id']) }} as absence_type_key, toNullable(absence_type_id) as absence_type_id,
       absence_type_name, absence_plan_name, plan_type, {{ hnh_absence_category('absence_type_name') }} as absence_category
from {{ ref('stg_fusion__absence_types') }}
union all
select toInt64(-1), null, 'Unknown', null, null, 'Other'
```

`hnh_dim_hr_department.sql`:

```sql
{{ config(order_by='hr_department_key') }}

-- Department names are "<branch prefix> <specialty name>" (spec H6); the unified department reuses the Phase 3
-- specialty mapping by name.
with depts as (
    select organization_id, department_name,
           splitByChar(' ', ifNull(department_name, ''))[1]                         as branch_prefix,
           trimBoth(substring(ifNull(department_name, ''), length(splitByChar(' ', ifNull(department_name, ''))[1]) + 2)) as department_base_name
    from {{ ref('stg_fusion__hr_departments') }}
),

unified as (
    select lower(specialty_name) as name_lower, any(unified_department) as unified_department
    from {{ ref('stg_ref__fusion_specialty_unified') }}
    where specialty_name is not null and unified_department is not null
    group by name_lower
),

departments as (
    select
        {{ hnh_surrogate_key(['d.organization_id']) }}      as hr_department_key,
        toNullable(d.organization_id)                       as organization_id,
        d.department_name                                   as department_name,
        d.branch_prefix                                     as branch_prefix,
        d.department_base_name                              as department_base_name,
        ifNull(u.unified_department, 'Unknown')             as unified_department,
        {{ hnh_hr_dept_prefix_branch('d.branch_prefix') }}  as branch_key
    from depts as d
    left join unified as u on u.name_lower = lower(d.department_base_name)
    {{ hnh_settings() }}  -- left join in a CTE feeding a union: settings must sit here
)

select * from departments

union all

select toInt64(-1), null, 'Unknown', null, null, 'Unknown', toUInt8(0)
{{ hnh_settings() }}
```

`dim_pay_category.sql`:

```sql
{{ config(order_by='pay_category_key') }}

-- Common pay categories of Oasis and Fusion payroll (spec 4.3). fusion_sign turns Fusion's positive deduction values
-- into negative amounts; Oasis amounts are already signed.
select
    {{ hnh_surrogate_key(['c']) }}  as pay_category_key,
    c                               as pay_category,
    g                               as pay_group,
    toUInt8(cost)                   as is_cost,
    toUInt8(gross)                  as is_gross_pay,
    toUInt8(rec)                    as is_recurring,
    toInt8(sgn)                     as fusion_sign,
    toUInt16(srt)                   as sort_order
from values('c String, g String, cost UInt8, gross UInt8, rec UInt8, sgn Int8, srt UInt16',
    ('Basic', 'Earnings', 1, 1, 1, 1, 10), ('Housing', 'Earnings', 1, 1, 1, 1, 20), ('Transport', 'Earnings', 1, 1, 1, 1, 30),
    ('Food', 'Earnings', 1, 1, 1, 1, 40), ('Clinical allowances', 'Earnings', 1, 1, 1, 1, 50),
    ('Other allowances', 'Earnings', 1, 1, 1, 1, 60), ('Overtime', 'Earnings', 1, 1, 0, 1, 70),
    ('Leave pay', 'Earnings', 1, 1, 0, 1, 80), ('End of service', 'Earnings', 1, 1, 0, 1, 90),
    ('Awards and bonus', 'Earnings', 1, 1, 0, 1, 100),
    ('Absence and lateness deduction', 'Earnings adjustments', 1, 1, 0, -1, 110),
    ('GOSI employer charge', 'Employer charges', 1, 0, 0, 1, 120), ('Other employer charges', 'Employer charges', 1, 0, 0, 1, 130),
    ('GOSI employee deduction', 'Employee deductions', 0, 0, 0, -1, 140),
    ('Loans and advances', 'Employee deductions', 0, 0, 0, -1, 150), ('Other deductions', 'Employee deductions', 0, 0, 0, -1, 160),
    ('Not pay', 'Not pay', 0, 0, 0, 1, 170), ('Unmapped', 'Unmapped', 0, 0, 0, 1, 180))
```

- [ ] **Step 3: Write the employee dimension and the bridge**

`bridge_employee_staff.sql`:

```sql
{{ config(order_by='employee_key') }}

-- Fusion worker number = Oasis staff id within the employee's branch (spec W1, H4). Head Office has no Oasis staff.
select
    {{ hnh_surrogate_key(['e.person_id']) }}    as employee_key,
    s.staff_key                                 as staff_key,
    e.branch_key                                as branch_key,
    assumeNotNull(e.worker_number)              as worker_number,
    'worker_number'                             as match_method
from {{ ref('int_employee_period') }} as e
inner join (select staff_key, branch_key, staff_id from {{ ref('dim_staff') }} where staff_id is not null) as s
    on s.branch_key = e.branch_key and s.staff_id = e.worker_number
where e.worker_number is not null and e.branch_key between 1 and 8
```

`hnh_dim_employee.sql`:

```sql
{{ config(alias='dim_employee', order_by='employee_key') }}

-- Current state of each Fusion person (cancelled hires excluded). No names, contact details or identifiers.
with emp as (
    select * from {{ ref('stg_fusion__employees') }}
    where is_current = 1 and ifNull(worker_type, '') != 'CANCELED_HIRE'
    order by person_id, valid_from desc
    limit 1 by person_id
),

current_assignment as (
    select person_id, organization_id, job_id, grade_id, position_id, location_id, assignment_status
    from {{ ref('stg_fusion__assignments') }}
    where is_current = 1 and is_primary = 1 and person_id is not null
    order by person_id,
             multiIf(ifNull(assignment_status, '') = 'ACTIVE', 1, ifNull(assignment_status, '') = 'SUSPENDED', 2, 3),
             valid_from desc, assignment_id desc
    limit 1 by person_id
),

joined as (
    select
        e.person_id as person_id, e.person_number as person_number, p.worker_number as worker_number,
        e.worker_type as worker_type_code, e.gender as gender, e.nationality as nationality, e.birth_date as birth_date,
        coalesce(p.start_date, e.hire_date) as hire_date, p.original_hire_date as original_hire_date,
        coalesce(p.termination_date, e.termination_date) as termination_date, ifNull(p.is_terminated, toUInt8(0)) as is_terminated,
        ifNull(p.branch_key, toUInt8(0)) as branch_key,
        a.organization_id as organization_id, a.job_id as job_id, a.grade_id as grade_id, a.position_id as position_id,
        a.location_id as location_id, a.assignment_status as assignment_status, b.staff_key as staff_key
    from emp as e
    left join {{ ref('int_employee_period') }} as p on p.person_id = e.person_id
    left join current_assignment as a on a.person_id = e.person_id
    left join {{ ref('bridge_employee_staff') }} as b on b.employee_key = {{ hnh_surrogate_key(['e.person_id']) }}
    {{ hnh_settings() }}  -- left joins inside a CTE that feeds a union: settings must sit here
)

select
    {{ hnh_surrogate_key(['person_id']) }}                      as employee_key,
    toNullable(person_id)                                       as person_id,
    person_number, worker_number,
    {{ hnh_worker_type_label('worker_type_code') }}             as worker_type,
    worker_type_code, gender, nationality,
    toUInt8(ifNull(nationality, '') = 'SA')                     as is_saudi,
    birth_date,
    {{ hnh_age_band('birth_date', 'toDate32(today())') }}       as age_band,
    hire_date, original_hire_date, termination_date, is_terminated,
    {{ hnh_tenure_band('coalesce(original_hire_date, hire_date)', 'toDate32(today())') }} as tenure_band,
    branch_key,
    if(organization_id is null, toInt64(-1), {{ hnh_surrogate_key(['organization_id']) }}) as hr_department_key,
    if(job_id is null, toInt64(-1), {{ hnh_surrogate_key(['job_id']) }})                   as job_key,
    if(grade_id is null, toInt64(-1), {{ hnh_surrogate_key(['grade_id']) }})               as grade_key,
    if(position_id is null, toInt64(-1), {{ hnh_surrogate_key(['position_id']) }})         as position_key,
    if(location_id is null, toInt64(-1), {{ hnh_surrogate_key(['location_id']) }})         as location_key,
    assignment_status,
    ifNull(staff_key, toInt64(-1))                              as staff_key
from joined

union all

select toInt64(-1), null, null, null, 'Unknown', null, null, null, toUInt8(0), null, 'Unknown', null, null, null, toUInt8(0),
       'Unknown', toUInt8(0), toInt64(-1), toInt64(-1), toInt64(-1), toInt64(-1), toInt64(-1), null, toInt64(-1)
{{ hnh_settings() }}
```

- [ ] **Step 4: Run the unit test and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select hnh_dim_employee hnh_dim_hr_department hnh_dim_job hnh_dim_grade hnh_dim_position hnh_dim_location hnh_dim_worker_action hnh_dim_absence_type dim_pay_category bridge_employee_staff`
Expected: unit test PASS; models built; tests PASS. Spot-check: `select count(), countIf(staff_key != -1) from gold.dim_employee` — about 4,790 people, about 4,400 linked; `select countIf(branch_key = 0) from gold.dim_employee where employee_key != -1` — 0; `select unified_department = 'Unknown', count() from gold.hnh_dim_hr_department group by 1` — record the split.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/marts/conformed/
git commit -m "Add workforce dimensions, pay categories and the employee-to-staff bridge"
```

---

### Task 6: Headcount snapshot and movements

**Files:**
- Create: `hnh_dwh/models/hnh/marts/workforce/fact_headcount_monthly.sql`, `hnh_fact_worker_movement.sql`, `_workforce_marts__models.yml`, `_workforce_marts_unit_tests.yml`, `hnh_dwh/tests/hnh/assert_workforce_facts_have_branch.sql`

**Interfaces:**
- Consumes: `int_assignment_month_end`, `int_employee_period`, `hnh_dim_employee` (employee_key, worker_type_code, gender, is_saudi, birth_date, staff_key, branch_key), `hnh_dim_hr_department` (organization_id, branch_key), `stg_fusion__worker_movements`, `stg_fusion__assignments`.
- Produces:
  - `fact_headcount_monthly(headcount_key, branch_key, employee_key, staff_key, hr_department_key, job_key, grade_key, position_key, location_key, month_date_key, month_end, worker_type_code, is_contingent, assignment_status, is_saudi, gender, age_band, tenure_band, headcount UInt8, fte Float64, is_new_hire_in_month, is_leaver_in_month, _loaded_at)`
  - `hnh_fact_worker_movement` (alias `fact_worker_movement`): `movement_key, branch_key, previous_branch_key, employee_key, staff_key, worker_action_key, action_date_key, hr_department_key, previous_hr_department_key, job_key, previous_job_key, grade_key, previous_grade_key, position_key, previous_position_key, location_key, previous_location_key, action_code, movement_group, is_organization_changed, is_job_changed, is_position_changed, is_grade_changed, is_location_changed, is_hire, is_leaver, is_voluntary_leaver, is_branch_transfer, _loaded_at`

- [ ] **Step 1: Write the failing unit tests and YAML**

`_workforce_marts_unit_tests.yml`:

```yaml
version: 2

unit_tests:
  - name: fact_headcount_monthly_counts_active_people
    description: >
      Person 1 (employee, Saudi, hired 2026-02-10) is active at the February and March month-ends: hire flag in
      February. Person 2 is active in January, INACTIVE at the end of February (no row), active again at the end of
      March with a termination date of 2026-03-15 (leaver flag in March). Person 3 is a contingent worker: a row with
      is_contingent = 1.
    model: fact_headcount_monthly
    given:
      - input: ref('int_assignment_month_end')
        format: sql
        rows: |
          select toInt64(p) as person_id, toDate(me) as month_end, toInt64(p * 10) as assignment_id, toNullable('E') as assignment_type,
                 toNullable(st) as assignment_status, toNullable(toInt64(900)) as organization_id, toNullable(toInt64(1)) as job_id,
                 cast(null as Nullable(Int64)) as position_id, cast(null as Nullable(Int64)) as grade_id, cast(null as Nullable(Int64)) as location_id,
                 toUInt8(6) as branch_key, toFloat64(1) as fte
          from values('p UInt32, me String, st String',
              (1, '2026-02-28', 'ACTIVE'), (1, '2026-03-31', 'ACTIVE'),
              (2, '2026-01-31', 'ACTIVE'), (2, '2026-02-28', 'INACTIVE'), (2, '2026-03-31', 'ACTIVE'),
              (3, '2026-03-31', 'ACTIVE'))
      - input: ref('int_employee_period')
        format: sql
        rows: |
          select toInt64(p) as person_id, toDate32(sd) as start_date, if(td = '', cast(null as Nullable(Date32)), toNullable(toDate32(td))) as termination_date,
                 cast(null as Nullable(Date32)) as original_hire_date
          from values('p UInt32, sd String, td String', (1, '2026-02-10', ''), (2, '2020-01-01', '2026-03-15'), (3, '2025-01-01', ''))
      - input: ref('hnh_dim_employee')
        format: sql
        rows: |
          select {{ hnh_surrogate_key(['toInt64(p)']) }} as employee_key, toNullable(toInt64(p)) as person_id, toNullable(wt) as worker_type_code,
                 toNullable('M') as gender, toUInt8(sa) as is_saudi, toNullable(toDate32('1990-01-01')) as birth_date, toInt64(-1) as staff_key
          from values('p UInt32, wt String, sa UInt8', (1, 'EMP', 1), (2, 'EMP', 0), (3, 'CWK', 0))
    expect:
      rows:
        - {month_date_key: 20260228, headcount: 1, is_saudi: 1, is_contingent: 0, is_new_hire_in_month: 1, is_leaver_in_month: 0}
        - {month_date_key: 20260331, headcount: 1, is_saudi: 1, is_contingent: 0, is_new_hire_in_month: 0, is_leaver_in_month: 0}
        - {month_date_key: 20260131, headcount: 1, is_saudi: 0, is_contingent: 0, is_new_hire_in_month: 0, is_leaver_in_month: 0}
        - {month_date_key: 20260331, headcount: 1, is_saudi: 0, is_contingent: 0, is_new_hire_in_month: 0, is_leaver_in_month: 1}
        - {month_date_key: 20260331, headcount: 1, is_saudi: 0, is_contingent: 1, is_new_hire_in_month: 0, is_leaver_in_month: 0}

  - name: fact_worker_movement_flags_transfers
    description: >
      A GLB_TRANSFER from a KHM department to an ABH department: branch 6 after, branch 2 before, branch transfer flag.
      A RESIGNATION is a voluntary leaver. A HIRE before 2022 is outside the window.
    model: hnh_fact_worker_movement
    given:
      - input: ref('stg_fusion__worker_movements')
        format: sql
        rows: |
          select toInt64(a) as assignment_id, toInt64(20991231) as effective_end_date_key, toInt64(1) as effective_sequence,
                 toDate32(d) as effective_start_date, toNullable(toInt64(p)) as person_id, toNullable(ac) as action_code,
                 cast(null as Nullable(String)) as action_reason_code, toDate32(d) as action_date, toNullable('ACTIVE') as assignment_status,
                 toNullable(toInt64(org)) as organization_id, cast(null as Nullable(Int64)) as job_id, cast(null as Nullable(Int64)) as position_id,
                 cast(null as Nullable(Int64)) as grade_id, cast(null as Nullable(Int64)) as location_id,
                 if(porg = 0, cast(null as Nullable(Int64)), toNullable(toInt64(porg))) as previous_organization_id,
                 cast(null as Nullable(Int64)) as previous_job_id, cast(null as Nullable(Int64)) as previous_position_id,
                 cast(null as Nullable(Int64)) as previous_grade_id, cast(null as Nullable(Int64)) as previous_location_id,
                 toUInt8(porg != 0) as is_organization_changed, toUInt8(0) as is_job_changed, toUInt8(0) as is_position_changed,
                 toUInt8(0) as is_grade_changed, toUInt8(0) as is_location_changed
          from values('a UInt32, d String, p UInt32, ac String, org UInt32, porg UInt32',
              (1, '2026-05-01', 1, 'GLB_TRANSFER', 61, 21), (2, '2026-06-30', 2, 'RESIGNATION', 61, 0), (3, '2019-01-01', 3, 'HIRE', 61, 0))
      - input: ref('hnh_dim_hr_department')
        format: sql
        rows: |
          select {{ hnh_surrogate_key(['toInt64(o)']) }} as hr_department_key, toNullable(toInt64(o)) as organization_id, toUInt8(b) as branch_key
          from values('o UInt32, b UInt8', (61, 6), (21, 2))
      - input: ref('hnh_dim_employee')
        format: sql
        rows: |
          select {{ hnh_surrogate_key(['toInt64(p)']) }} as employee_key, toNullable(toInt64(p)) as person_id, toUInt8(6) as branch_key, toInt64(-1) as staff_key
          from values('p UInt32', (1), (2), (3))
      - input: ref('hnh_dim_worker_action')
        format: sql
        rows: |
          select toInt64(k) as worker_action_key, toNullable(a) as action_code, cast(null as Nullable(String)) as action_reason_code
          from values('k Int64, a String', (101, 'GLB_TRANSFER'), (102, 'RESIGNATION'), (103, 'HIRE'))
    expect:
      rows:
        - {action_code: GLB_TRANSFER, worker_action_key: 101, branch_key: 6, previous_branch_key: 2, movement_group: Transfer, is_branch_transfer: 1, is_leaver: 0, is_voluntary_leaver: 0}
        - {action_code: RESIGNATION, worker_action_key: 102, branch_key: 6, previous_branch_key: 6, movement_group: Voluntary leaver, is_branch_transfer: 0, is_leaver: 1, is_voluntary_leaver: 1}
```

(If the fixture Jinja is not rendered, compute the hash literals through `ch_env` as in Task 5 and note it.)

`_workforce_marts__models.yml`:

```yaml
version: 2

models:
  - name: fact_headcount_monthly
    tests:
      - hnh_unique_combination:
          columns: [employee_key, month_date_key]
    columns:
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
      - name: employee_key
        tests:
          - relationships: {to: ref('hnh_dim_employee'), field: employee_key}
      - name: hr_department_key
        tests:
          - relationships: {to: ref('hnh_dim_hr_department'), field: hr_department_key}
      - name: job_key
        tests:
          - relationships: {to: ref('hnh_dim_job'), field: job_key}
      - name: month_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
  - name: hnh_fact_worker_movement
    columns:
      - name: movement_key
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
      - name: worker_action_key
        tests:
          - relationships: {to: ref('hnh_dim_worker_action'), field: worker_action_key}
      - name: action_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
```

Run: `python scripts/run_dbt.py test --no-partial-parse --select fact_headcount_monthly_counts_active_people fact_worker_movement_flags_transfers`
Expected: FAIL — models not found.

- [ ] **Step 2: Write the facts**

`fact_headcount_monthly.sql`:

```sql
{{ config(order_by='(branch_key, month_date_key, employee_key)') }}

-- Primary assignment ACTIVE or SUSPENDED at a month-end (spec 6.1), cancelled hires excluded through dim_employee.
with snap as (
    select * from {{ ref('int_assignment_month_end') }}
    where ifNull(assignment_status, '') in ('ACTIVE', 'SUSPENDED')
),

joined as (
    select s.person_id as person_id, s.month_end as month_end, s.branch_key as branch_key, s.assignment_status as assignment_status,
           s.organization_id as organization_id, s.job_id as job_id, s.grade_id as grade_id, s.position_id as position_id,
           s.location_id as location_id, s.fte as fte,
           e.employee_key as employee_key, e.worker_type_code as worker_type_code, e.gender as gender, e.is_saudi as is_saudi,
           e.birth_date as birth_date, e.staff_key as staff_key,
           p.start_date as start_date, p.original_hire_date as original_hire_date, p.termination_date as termination_date
    from snap as s
    inner join (select employee_key, person_id, worker_type_code, gender, is_saudi, birth_date, staff_key
                from {{ ref('hnh_dim_employee') }} where person_id is not null) as e
        on e.person_id = s.person_id
    left join {{ ref('int_employee_period') }} as p on p.person_id = s.person_id
    {{ hnh_settings() }}
)

select
    {{ hnh_surrogate_key(['employee_key', 'month_end']) }}                          as headcount_key,
    branch_key,
    employee_key,
    staff_key,
    if(organization_id is null, toInt64(-1), {{ hnh_surrogate_key(['organization_id']) }}) as hr_department_key,
    if(job_id is null, toInt64(-1), {{ hnh_surrogate_key(['job_id']) }})                   as job_key,
    if(grade_id is null, toInt64(-1), {{ hnh_surrogate_key(['grade_id']) }})               as grade_key,
    if(position_id is null, toInt64(-1), {{ hnh_surrogate_key(['position_id']) }})         as position_key,
    if(location_id is null, toInt64(-1), {{ hnh_surrogate_key(['location_id']) }})         as location_key,
    {{ hnh_date_key('month_end') }}                                                 as month_date_key,
    month_end,
    worker_type_code,
    toUInt8(ifNull(worker_type_code, '') in ('CWK', 'CON'))                         as is_contingent,
    assignment_status,
    is_saudi,
    gender,
    {{ hnh_age_band('birth_date', 'toDate32(month_end)') }}                         as age_band,
    {{ hnh_tenure_band('coalesce(original_hire_date, start_date)', 'toDate32(month_end)') }} as tenure_band,
    toUInt8(1)                                                                      as headcount,
    fte,
    toUInt8(start_date is not null and toStartOfMonth(start_date) = toStartOfMonth(month_end))             as is_new_hire_in_month,
    toUInt8(termination_date is not null and toStartOfMonth(termination_date) = toStartOfMonth(month_end)) as is_leaver_in_month,
    now()                                                                           as _loaded_at
from joined
```

`hnh_fact_worker_movement.sql`:

```sql
{{ config(alias='fact_worker_movement', order_by='(branch_key, action_date_key, movement_key)') }}

-- One Fusion assignment action from 2022 (spec 6.3). Branch from the department prefix (plan refinement), falling
-- back to the person's current branch.
with mv as (
    select * from {{ ref('stg_fusion__worker_movements') }}
    where action_date >= toDate32('{{ var("hnh_history_start_date") }}') and person_id is not null
),

depts as (select organization_id, branch_key from {{ ref('hnh_dim_hr_department') }} where organization_id is not null),

joined as (
    select m.*, d.branch_key as dept_branch, pd.branch_key as prev_dept_branch,
           e.employee_key as employee_key, e.branch_key as employee_branch, e.staff_key as staff_key,
           wa.worker_action_key as action_key_found
    from mv as m
    left join depts as d on d.organization_id = m.organization_id
    left join depts as pd on pd.organization_id = m.previous_organization_id
    inner join (select employee_key, person_id, branch_key, staff_key from {{ ref('hnh_dim_employee') }} where person_id is not null) as e
        on e.person_id = m.person_id
    left join (select worker_action_key, ifNull(action_code, '') as wa_code, ifNull(action_reason_code, '') as wa_reason
               from {{ ref('hnh_dim_worker_action') }} where worker_action_key != -1) as wa
        on wa.wa_code = ifNull(m.action_code, '') and wa.wa_reason = ifNull(m.action_reason_code, '')
    {{ hnh_settings() }}
)

select
    {{ hnh_surrogate_key(['assignment_id', 'effective_end_date_key', 'effective_sequence']) }}  as movement_key,
    if(ifNull(dept_branch, 0) = 0, employee_branch, assumeNotNull(dept_branch))             as branch_key,
    if(ifNull(prev_dept_branch, 0) = 0, branch_key, assumeNotNull(prev_dept_branch))        as previous_branch_key,
    employee_key,
    staff_key,
    ifNull(action_key_found, toInt64(-1))                                                   as worker_action_key,
    {{ hnh_date_key('action_date') }}                                                       as action_date_key,
    if(organization_id is null, toInt64(-1), {{ hnh_surrogate_key(['organization_id']) }})            as hr_department_key,
    if(previous_organization_id is null, toInt64(-1), {{ hnh_surrogate_key(['previous_organization_id']) }}) as previous_hr_department_key,
    if(job_id is null, toInt64(-1), {{ hnh_surrogate_key(['job_id']) }})                    as job_key,
    if(previous_job_id is null, toInt64(-1), {{ hnh_surrogate_key(['previous_job_id']) }})  as previous_job_key,
    if(grade_id is null, toInt64(-1), {{ hnh_surrogate_key(['grade_id']) }})                as grade_key,
    if(previous_grade_id is null, toInt64(-1), {{ hnh_surrogate_key(['previous_grade_id']) }}) as previous_grade_key,
    if(position_id is null, toInt64(-1), {{ hnh_surrogate_key(['position_id']) }})          as position_key,
    if(previous_position_id is null, toInt64(-1), {{ hnh_surrogate_key(['previous_position_id']) }}) as previous_position_key,
    if(location_id is null, toInt64(-1), {{ hnh_surrogate_key(['location_id']) }})          as location_key,
    if(previous_location_id is null, toInt64(-1), {{ hnh_surrogate_key(['previous_location_id']) }}) as previous_location_key,
    action_code,
    {{ hnh_movement_group('action_code') }}                                                 as movement_group,
    is_organization_changed, is_job_changed, is_position_changed, is_grade_changed, is_location_changed,
    toUInt8(movement_group in ('Hire', 'Rehire'))                                           as is_hire,
    toUInt8(movement_group in ('Voluntary leaver', 'Involuntary leaver'))                   as is_leaver,
    toUInt8(movement_group = 'Voluntary leaver')                                            as is_voluntary_leaver,
    toUInt8(branch_key != previous_branch_key)                                              as is_branch_transfer,
    now()                                                                                   as _loaded_at
from joined
```


`hnh_dwh/tests/hnh/assert_workforce_facts_have_branch.sql` (extended in Tasks 7–8):

```sql
-- Workforce facts never fall back to the Group member (branch 0).
select 'fact_headcount_monthly' as fact, count() as rows_without_branch from {{ ref('fact_headcount_monthly') }} where branch_key = 0 having count() > 0
union all
select 'fact_worker_movement', count() from {{ ref('hnh_fact_worker_movement') }} where branch_key = 0 having count() > 0
```

- [ ] **Step 3: Run the unit tests and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select fact_headcount_monthly hnh_fact_worker_movement assert_workforce_facts_have_branch`
Expected: both unit tests PASS, models built, tests PASS. Spot-check: headcount by branch for the last month-end (`select branch_key, sum(headcount), round(sum(fte)) from gold.fact_headcount_monthly where month_end = (select max(month_end) from gold.fact_headcount_monthly) and is_contingent = 0 group by 1 order by 1`) — record; the total should be near the 4,445 active primary assignments.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/workforce/ hnh_dwh/tests/hnh/assert_workforce_facts_have_branch.sql
git commit -m "Add the monthly headcount snapshot and worker movements"
```

---

### Task 7: Payroll fact

**Files:**
- Create: `hnh_dwh/models/hnh/marts/workforce/fact_payroll_monthly.sql`, `hnh_dwh/tests/hnh/assert_fact_payroll_matches_staging.sql`, `hnh_dwh/tests/hnh/assert_payroll_single_source_per_month.sql`
- Modify: `_workforce_marts__models.yml`, `_workforce_marts_unit_tests.yml`, `hnh_dwh/tests/hnh/assert_workforce_facts_have_branch.sql`

**Interfaces:**
- Consumes: `stg_oasis__payroll_transactions`, `stg_fusion__payroll_run_results`, `stg_fusion__payroll_elements`, `stg_fusion__payroll_input_values`, `stg_ref__pay_category`, `stg_ref__payroll_cutover`, `dim_pay_category`, `int_legal_employer_branch`, `bridge_employee_staff`, `dim_staff` (staff_key), `fact_headcount_monthly` (employee_key, month_end, hr_department_key).
- Produces: `fact_payroll_monthly(payroll_key, branch_key, source, payee_key, employee_key, staff_key, pay_category_key, pay_category, month_date_key, payroll_month Int32, hr_department_key, is_parallel_run, amount, cost_amount, gross_pay, _loaded_at)`; `payee_key` identifies the paid person within a source (Fusion: person; Oasis: branch + staff id).

- [ ] **Step 1: Write the failing unit test, the YAML and the two assertions**

Append to `_workforce_marts_unit_tests.yml`:

```yaml
  - name: fact_payroll_monthly_switches_at_cutover
    description: >
      Branch 3 cuts over in 202607. Oasis June (202606): basic 1,000 and staff GOSI −90 (an employee deduction, not cost).
      Oasis July is a parallel-run month: kept with is_parallel_run = 1 and zero cost. Fusion July: basic 1,100 and
      a delay deduction of 50 stored positive (amount −50, an earnings adjustment that lowers cost) and a GOSI
      reference earnings result (Not pay). A Fusion June result is before the cutover and dropped.
    model: fact_payroll_monthly
    given:
      - input: ref('stg_oasis__payroll_transactions')
        format: sql
        rows: |
          select toUInt8(3) as branch_id, toInt64(n) as account_transaction_no, toNullable('500') as staff_id, toInt32(m) as payroll_month,
                 t as trx_type, 'P' as payable_type, toNullable('C') as status, toFloat64(a) as amount
          from values('n UInt32, m UInt32, t String, a Float64', (1, 202606, 'BASIC', 1000), (2, 202606, 'STAFF GOSI', -90), (3, 202607, 'BASIC', 1000))
      - input: ref('stg_fusion__payroll_run_results')
        format: sql
        rows: |
          select toInt64(r) as run_result_id, toInt64(iv) as input_value_id, toNullable(toInt64(el)) as element_type_id,
                 toNullable(toInt64(7)) as person_id, toNullable(toInt64(1)) as legal_employer_id, toNullable('C') as payroll_action_status,
                 toDate32(d) as effective_date, toNullable(toFloat64(v)) as result_value
          from values('r UInt32, iv UInt32, el UInt32, d String, v Float64',
              (1, 101, 11, '2026-07-31', 1100), (2, 102, 12, '2026-07-31', 50), (3, 103, 13, '2026-07-31', 9000), (4, 101, 11, '2026-06-30', 999))
      - input: ref('stg_fusion__payroll_elements')
        format: sql
        rows: |
          select toInt64(e) as element_type_id, toNullable(n) as element_name
          from values('e UInt32, n String', (11, 'Basic Salary'), (12, 'Delay Deduction Results'), (13, 'Saudi GOSI Reference Earnings'))
      - input: ref('stg_fusion__payroll_input_values')
        format: sql
        rows: |
          select toInt64(i) as input_value_id, toNullable('Pay Value') as input_value_base_name from values('i UInt32', (101), (102), (103))
      - input: ref('stg_ref__pay_category')
        format: sql
        rows: |
          select s as source, c as source_code, pt as payable_type, cat as pay_category
          from values('s String, c String, pt String, cat String',
              ('oasis', 'BASIC', 'P', 'Basic'), ('oasis', 'STAFF GOSI', 'P', 'GOSI employee deduction'),
              ('fusion', 'Basic Salary', '', 'Basic'), ('fusion', 'Delay Deduction Results', '', 'Absence and lateness deduction'),
              ('fusion', 'Saudi GOSI Reference Earnings', '', 'Not pay'))
      - input: ref('stg_ref__payroll_cutover')
        format: sql
        rows: |
          select toUInt8(3) as branch_id, toInt32(202607) as first_fusion_month
      - input: ref('dim_pay_category')
        format: sql
        rows: |
          select {{ hnh_surrogate_key(['c']) }} as pay_category_key, c as pay_category, toUInt8(cost) as is_cost, toUInt8(gross) as is_gross_pay, toInt8(sgn) as fusion_sign
          from values('c String, cost UInt8, gross UInt8, sgn Int8',
              ('Basic', 1, 1, 1), ('GOSI employee deduction', 0, 0, -1), ('Absence and lateness deduction', 1, 1, -1), ('Not pay', 0, 0, 1), ('Unmapped', 0, 0, 1))
      - input: ref('int_legal_employer_branch')
        format: sql
        rows: |
          select toInt64(1) as legal_employer_id, toUInt8(3) as branch_key
      - input: ref('bridge_employee_staff')
        format: sql
        rows: |
          select {{ hnh_surrogate_key(['toInt64(7)']) }} as employee_key, {{ hnh_surrogate_key(['toUInt8(3)', "'500'"]) }} as staff_key,
                 toUInt8(3) as branch_key, '500' as worker_number
      - input: ref('dim_staff')
        format: sql
        rows: |
          select {{ hnh_surrogate_key(['toUInt8(3)', "'500'"]) }} as staff_key
      - input: ref('fact_headcount_monthly')
        format: sql
        rows: |
          select {{ hnh_surrogate_key(['toInt64(7)']) }} as employee_key, toDate('2026-07-31') as month_end, toInt64(-1) as hr_department_key
    expect:
      rows:
        - {source: oasis, payroll_month: 202606, pay_category: Basic, is_parallel_run: 0, amount: 1000, cost_amount: 1000, gross_pay: 1000}
        - {source: oasis, payroll_month: 202606, pay_category: GOSI employee deduction, is_parallel_run: 0, amount: -90, cost_amount: 0, gross_pay: 0}
        - {source: oasis, payroll_month: 202607, pay_category: Basic, is_parallel_run: 1, amount: 1000, cost_amount: 0, gross_pay: 0}
        - {source: fusion, payroll_month: 202607, pay_category: Basic, is_parallel_run: 0, amount: 1100, cost_amount: 1100, gross_pay: 1100}
        - {source: fusion, payroll_month: 202607, pay_category: Absence and lateness deduction, is_parallel_run: 0, amount: -50, cost_amount: -50, gross_pay: -50}
        - {source: fusion, payroll_month: 202607, pay_category: Not pay, is_parallel_run: 0, amount: 9000, cost_amount: 0, gross_pay: 0}
```

(Same Jinja-in-fixture fallback as Task 5.)

Append to `_workforce_marts__models.yml`:

```yaml
  - name: fact_payroll_monthly
    columns:
      - name: payroll_key
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
      - name: pay_category_key
        tests:
          - relationships: {to: ref('dim_pay_category'), field: pay_category_key}
      - name: employee_key
        tests:
          - relationships: {to: ref('hnh_dim_employee'), field: employee_key}
      - name: month_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: source
        tests:
          - accepted_values:
              values: ['oasis', 'fusion']
```

`hnh_dwh/tests/hnh/assert_fact_payroll_matches_staging.sql`:

```sql
-- Conservation: Oasis status-C amounts in the window and Fusion pay-value results of completed actions in cutover
-- months reach the fact once (signed), per source.
with oasis_staged as (
    select round(sum(amount), 2) as amt
    from {{ ref('stg_oasis__payroll_transactions') }}
    where status = 'C' and payroll_month >= toInt32(toYYYYMM(toDate('{{ var("hnh_history_start_date") }}'))) and payroll_month % 100 between 1 and 12
),
fusion_staged as (
    select round(sum(r.result_value * ifNull(c.fusion_sign, 1)), 2) as amt
    from {{ ref('stg_fusion__payroll_run_results') }} as r
    inner join (select input_value_id from {{ ref('stg_fusion__payroll_input_values') }} where input_value_base_name = 'Pay Value') as i
        on i.input_value_id = r.input_value_id
    inner join {{ ref('int_legal_employer_branch') }} as b on b.legal_employer_id = r.legal_employer_id
    inner join {{ ref('stg_ref__payroll_cutover') }} as k on k.branch_id = b.branch_key
    left join (select element_type_id, element_name from {{ ref('stg_fusion__payroll_elements') }}) as e on e.element_type_id = r.element_type_id
    left join (select source_code, pay_category from {{ ref('stg_ref__pay_category') }} where source = 'fusion') as m on m.source_code = e.element_name
    left join {{ ref('dim_pay_category') }} as c on c.pay_category = ifNull(m.pay_category, 'Unmapped')
    where r.payroll_action_status = 'C' and r.result_value is not null
      and toInt32(toYYYYMM(r.effective_date)) >= k.first_fusion_month
),
fact as (
    select round(sumIf(amount, source = 'oasis'), 2) as oasis_amt, round(sumIf(amount, source = 'fusion'), 2) as fusion_amt
    from {{ ref('fact_payroll_monthly') }}
)
select 'payroll fact differs from staging' as failure, f.oasis_amt, o.amt as oasis_staged, f.fusion_amt, u.amt as fusion_staged
from fact as f cross join oasis_staged as o cross join fusion_staged as u
where abs(f.oasis_amt - o.amt) > 0.01 or abs(f.fusion_amt - u.amt) > 0.01
{{ hnh_settings() }}
```

`hnh_dwh/tests/hnh/assert_payroll_single_source_per_month.sql`:

```sql
-- No branch-month carries cost from both sources (parallel-run Oasis rows carry no cost).
select branch_key, payroll_month
from {{ ref('fact_payroll_monthly') }}
where cost_amount != 0 or gross_pay != 0
group by branch_key, payroll_month
having uniqExact(source) > 1
```

Append to `assert_workforce_facts_have_branch.sql`:

```sql
union all
select 'fact_payroll_monthly', count() from {{ ref('fact_payroll_monthly') }} where branch_key = 0 having count() > 0
```

Run: `python scripts/run_dbt.py test --no-partial-parse --select fact_payroll_monthly_switches_at_cutover`
Expected: FAIL — model not found.

- [ ] **Step 2: Write the fact**

`fact_payroll_monthly.sql`:

```sql
{{ config(order_by='(branch_key, payroll_month, source, payee_key, pay_category_key)') }}

{% set first_month = "toInt32(toYYYYMM(toDate('" ~ var('hnh_history_start_date') ~ "')))" %}

with cutover as (select branch_id, first_fusion_month from {{ ref('stg_ref__payroll_cutover') }}),

categories as (select pay_category_key, pay_category, is_cost, is_gross_pay, fusion_sign from {{ ref('dim_pay_category') }}),

oasis_lines as (
    select t.branch_id as branch_key, 'oasis' as source, t.staff_id as staff_id, cast(null as Nullable(Int64)) as person_id,
           t.payroll_month as payroll_month, ifNull(m.pay_category, 'Unmapped') as pay_category, t.amount as raw_amount,
           toUInt8(k.first_fusion_month is not null and t.payroll_month >= k.first_fusion_month) as is_parallel_run
    from {{ ref('stg_oasis__payroll_transactions') }} as t
    left join (select source_code, payable_type, pay_category from {{ ref('stg_ref__pay_category') }} where source = 'oasis') as m
        on m.source_code = t.trx_type and m.payable_type = t.payable_type
    left join cutover as k on k.branch_id = t.branch_id
    where t.status = 'C' and t.payroll_month >= {{ first_month }} and t.payroll_month % 100 between 1 and 12
    {{ hnh_settings() }}  -- left joins in a CTE feeding a union
),

fusion_lines as (
    select b.branch_key as branch_key, 'fusion' as source, cast(null as Nullable(String)) as staff_id, r.person_id as person_id,
           toInt32(toYYYYMM(r.effective_date)) as payroll_month, ifNull(m.pay_category, 'Unmapped') as pay_category,
           assumeNotNull(r.result_value) as raw_amount, toUInt8(0) as is_parallel_run
    from {{ ref('stg_fusion__payroll_run_results') }} as r
    inner join (select input_value_id from {{ ref('stg_fusion__payroll_input_values') }} where input_value_base_name = 'Pay Value') as i
        on i.input_value_id = r.input_value_id
    inner join {{ ref('int_legal_employer_branch') }} as b on b.legal_employer_id = r.legal_employer_id
    inner join cutover as k on k.branch_id = b.branch_key
    left join (select element_type_id, element_name from {{ ref('stg_fusion__payroll_elements') }}) as e on e.element_type_id = r.element_type_id
    left join (select source_code, pay_category from {{ ref('stg_ref__pay_category') }} where source = 'fusion') as m
        on m.source_code = e.element_name
    where r.payroll_action_status = 'C' and r.result_value is not null
      and toInt32(toYYYYMM(r.effective_date)) >= k.first_fusion_month
    {{ hnh_settings() }}  -- left joins in a CTE feeding a union
),

lines as (
    select * from oasis_lines
    union all
    select * from fusion_lines
),

aggregated as (
    select l.branch_key as branch_key, l.source as source, l.staff_id as staff_id, l.person_id as person_id,
           l.payroll_month as payroll_month, l.pay_category as pay_category, l.is_parallel_run as is_parallel_run,
           sum(if(l.source = 'fusion', l.raw_amount * c.fusion_sign, l.raw_amount)) as amount,
           any(c.pay_category_key) as pay_category_key, any(c.is_cost) as is_cost, any(c.is_gross_pay) as is_gross_pay
    from lines as l
    inner join categories as c on c.pay_category = l.pay_category
    group by l.branch_key, l.source, l.staff_id, l.person_id, l.payroll_month, l.pay_category, l.is_parallel_run
),

keyed as (
    select a.*,
           if(a.source = 'fusion', {{ hnh_surrogate_key(['a.person_id']) }}, toInt64(-1))           as fusion_employee_key,
           if(a.source = 'oasis', {{ hnh_surrogate_key(['a.branch_key', 'a.staff_id']) }}, toInt64(-1)) as oasis_staff_key,
           toLastDayOfMonth(makeDate(intDiv(a.payroll_month, 100), a.payroll_month % 100, 1))       as month_end
    from aggregated as a
),

resolved as (
    select k.*,
           if(k.source = 'fusion', k.fusion_employee_key, ifNull(bo.employee_key, toInt64(-1)))    as employee_key,
           if(k.source = 'oasis', ifNull(ds.staff_key, toInt64(-1)), ifNull(bf.staff_key, toInt64(-1))) as staff_key
    from keyed as k
    left join (select employee_key, staff_key from {{ ref('bridge_employee_staff') }}) as bo on bo.staff_key = k.oasis_staff_key
    left join (select employee_key, staff_key from {{ ref('bridge_employee_staff') }}) as bf on bf.employee_key = k.fusion_employee_key
    left join (select staff_key from {{ ref('dim_staff') }}) as ds on ds.staff_key = k.oasis_staff_key
    {{ hnh_settings() }}
)

select
    {{ hnh_surrogate_key(['r.source', 'r.branch_key', "ifNull(toString(r.person_id), r.staff_id)", 'r.payroll_month', 'r.pay_category', 'r.is_parallel_run']) }} as payroll_key,
    r.branch_key                                                        as branch_key,
    r.source                                                            as source,
    {{ hnh_surrogate_key(['r.source', 'r.branch_key', "ifNull(toString(r.person_id), r.staff_id)"]) }} as payee_key,
    r.employee_key                                                      as employee_key,
    r.staff_key                                                         as staff_key,
    r.pay_category_key                                                  as pay_category_key,
    r.pay_category                                                      as pay_category,
    toInt32(r.payroll_month * 100 + 1)                                  as month_date_key,
    r.payroll_month                                                     as payroll_month,
    ifNull(h.hr_department_key, toInt64(-1))                            as hr_department_key,
    r.is_parallel_run                                                   as is_parallel_run,
    r.amount                                                            as amount,
    if(r.is_parallel_run = 0 and r.is_cost = 1, r.amount, 0)            as cost_amount,
    if(r.is_parallel_run = 0 and r.is_gross_pay = 1, r.amount, 0)       as gross_pay,
    now()                                                               as _loaded_at
from resolved as r
left join (select employee_key, month_end, hr_department_key from {{ ref('fact_headcount_monthly') }}) as h
    on h.employee_key = r.employee_key and h.month_end = r.month_end and r.employee_key != -1
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the unit test and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select fact_payroll_monthly assert_fact_payroll_matches_staging assert_payroll_single_source_per_month assert_workforce_facts_have_branch`
Expected: unit test PASS; model built; all tests PASS. Spot-check gross pay by branch and month for 2026 (`select branch_key, payroll_month, source, round(sum(gross_pay)/1e6, 2) from gold.fact_payroll_monthly where payroll_month >= 202601 group by 1,2,3 order by 1,2`) — continuity across each cutover month; record it.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/workforce/ hnh_dwh/tests/hnh/
git commit -m "Add the monthly payroll fact with a per-branch Oasis-to-Fusion cutover"
```

---

### Task 8: Absence and leave

**Files:**
- Create: `hnh_dwh/models/hnh/marts/workforce/fact_absence.sql`, `fact_absence_daily.sql`, `fact_leave_balance_monthly.sql`
- Modify: `_workforce_marts__models.yml`, `_workforce_marts_unit_tests.yml`, `hnh_dwh/tests/hnh/assert_workforce_facts_have_branch.sql`

**Interfaces:**
- Consumes: `stg_fusion__absence_entries`, `stg_fusion__absence_balances`, `stg_fusion__absence_plans`, `hnh_dim_absence_type` (absence_type_key, absence_type_id), `hnh_dim_employee` (employee_key, person_id, branch_key, staff_key), `int_legal_employer_branch`, `fact_payroll_monthly` (employee_key, payroll_month, pay_category, amount, is_parallel_run).
- Produces:
  - `fact_absence(absence_key, branch_key, employee_key, staff_key, absence_type_key, start_date_key, end_date_key, absence_status, is_counted, duration_uom, absence_days, absence_hours, _loaded_at)`
  - `fact_absence_daily(absence_day_key, branch_key, employee_key, staff_key, absence_type_key, date_key, absence_days, _loaded_at)`
  - `fact_leave_balance_monthly(leave_balance_key, branch_key, employee_key, absence_plan_id, absence_plan_name, is_annual_plan, accrual_period_date_key, begin_balance, accrued, used, end_balance, monthly_salary, daily_rate, leave_liability_amount, _loaded_at)`

- [ ] **Step 1: Write the failing unit tests and YAML**

Append to `_workforce_marts_unit_tests.yml`:

```yaml
  - name: fact_absence_daily_splits_across_months
    description: >
      Entry 1: approved sick leave 30 June – 2 July 2026 (3 days, two months). Entry 2: withdrawn annual leave
      (not counted, no daily rows). Entry 3: approved permission leave in hours (no daily rows).
    model: fact_absence_daily
    given:
      - input: ref('stg_fusion__absence_entries')
        format: sql
        rows: |
          select toInt64(e) as absence_entry_id, toNullable(toInt64(5)) as person_id, toNullable(toInt64(t)) as absence_type_id,
                 toNullable(toInt64(1)) as legal_employer_id, toNullable(st) as absence_status_code, toNullable('APPROVED') as approval_status_code,
                 toDate32(sd) as start_date, toDate32(ed) as end_date, toNullable(toFloat64(dur)) as duration, toNullable(u) as duration_uom
          from values('e UInt32, t UInt32, st String, sd String, ed String, dur Float64, u String',
              (1, 70, 'SUBMITTED', '2026-06-30', '2026-07-02', 3, 'C'),
              (2, 71, 'ORA_WITHDRAWN', '2026-06-01', '2026-06-05', 5, 'C'),
              (3, 72, 'SUBMITTED', '2026-06-10', '2026-06-10', 2, 'H'))
      - input: ref('hnh_dim_absence_type')
        format: sql
        rows: |
          select {{ hnh_surrogate_key(['toInt64(t)']) }} as absence_type_key, toNullable(toInt64(t)) as absence_type_id from values('t UInt32', (70), (71), (72))
      - input: ref('hnh_dim_employee')
        format: sql
        rows: |
          select {{ hnh_surrogate_key(['toInt64(5)']) }} as employee_key, toNullable(toInt64(5)) as person_id, toUInt8(6) as branch_key, toInt64(-1) as staff_key
      - input: ref('int_legal_employer_branch')
        format: sql
        rows: |
          select toInt64(1) as legal_employer_id, toUInt8(6) as branch_key
    expect:
      rows:
        - {date_key: 20260630, absence_days: 1}
        - {date_key: 20260701, absence_days: 1}
        - {date_key: 20260702, absence_days: 1}

  - name: fact_leave_balance_monthly_values_liability
    description: >
      Person 1: annual-leave balance of 15 days at 2026-07-31; recurring pay in July 2026 is basic 6,000 + housing 1,500
      (overtime 900 excluded) → daily rate 250, liability 3,750. Person 2: sick-leave plan → no liability. Person 3:
      annual leave but never paid → salary and liability null.
    model: fact_leave_balance_monthly
    given:
      - input: ref('stg_fusion__absence_balances')
        format: sql
        rows: |
          select toInt64(a) as accrual_entry_id, toNullable(toInt64(p)) as person_id, toNullable(toInt64(pl)) as absence_plan_id,
                 toDate32('2026-07-31') as accrual_period_date, toNullable('A') as status, toFloat64(0) as begin_balance,
                 toFloat64(0) as accrued, toFloat64(0) as used, toFloat64(eb) as end_balance
          from values('a UInt32, p UInt32, pl UInt32, eb Float64', (1, 1, 80, 15), (2, 2, 81, 4), (3, 3, 80, 10))
      - input: ref('stg_fusion__absence_plans')
        format: sql
        rows: |
          select toInt64(pl) as absence_plan_id, toNullable(n) as absence_plan_name, toNullable(t) as plan_type
          from values('pl UInt32, n String, t String', (80, 'Hospitals Annual Leave', 'A'), (81, 'Sick Leave', 'Q'))
      - input: ref('hnh_dim_employee')
        format: sql
        rows: |
          select {{ hnh_surrogate_key(['toInt64(p)']) }} as employee_key, toNullable(toInt64(p)) as person_id, toUInt8(6) as branch_key
          from values('p UInt32', (1), (2), (3))
      - input: ref('fact_payroll_monthly')
        format: sql
        rows: |
          select {{ hnh_surrogate_key(['toInt64(1)']) }} as employee_key, toInt32(202607) as payroll_month, c as pay_category,
                 toFloat64(a) as amount, toUInt8(0) as is_parallel_run
          from values('c String, a Float64', ('Basic', 6000), ('Housing', 1500), ('Overtime', 900))
    expect:
      rows:
        - {end_balance: 15, is_annual_plan: 1, monthly_salary: 7500, daily_rate: 250, leave_liability_amount: 3750}
        - {end_balance: 4, is_annual_plan: 0, monthly_salary: null, daily_rate: null, leave_liability_amount: null}
        - {end_balance: 10, is_annual_plan: 1, monthly_salary: null, daily_rate: null, leave_liability_amount: null}
```

Append to `_workforce_marts__models.yml`:

```yaml
  - name: fact_absence
    columns:
      - name: absence_key
        tests: [unique, not_null]
      - name: absence_type_key
        tests:
          - relationships: {to: ref('hnh_dim_absence_type'), field: absence_type_key}
  - name: fact_absence_daily
    columns:
      - name: absence_day_key
        tests: [unique, not_null]
      - name: date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
  - name: fact_leave_balance_monthly
    columns:
      - name: leave_balance_key
        tests: [unique, not_null]
      - name: employee_key
        tests:
          - relationships: {to: ref('hnh_dim_employee'), field: employee_key}
```

Run: `python scripts/run_dbt.py test --no-partial-parse --select fact_absence_daily_splits_across_months fact_leave_balance_monthly_values_liability`
Expected: FAIL — models not found.

- [ ] **Step 2: Write the three facts**

`fact_absence.sql`:

```sql
{{ config(order_by='(branch_key, start_date_key, absence_key)') }}

-- One Fusion absence entry (spec 6.5). Branch from the entry's legal employer, else the person's current branch.
select
    {{ hnh_surrogate_key(['a.absence_entry_id']) }}                                    as absence_key,
    if(ifNull(lb.branch_key, 0) = 0, e.branch_key, assumeNotNull(lb.branch_key))      as branch_key,
    e.employee_key                                                                      as employee_key,
    e.staff_key                                                                         as staff_key,
    ifNull(t.absence_type_key, toInt64(-1))                                             as absence_type_key,
    ifNull({{ hnh_date_key_in_range('a.start_date') }}, 0)                              as start_date_key,
    {{ hnh_date_key_in_range('a.end_date') }}                                           as end_date_key,
    {{ hnh_absence_status('a.absence_status_code', 'a.approval_status_code') }}         as absence_status,
    {{ hnh_is_counted_absence('a.absence_status_code', 'a.approval_status_code') }}     as is_counted,
    a.duration_uom                                                                      as duration_uom,
    if(ifNull(a.duration_uom, '') = 'C', ifNull(a.duration, 0), 0)                       as absence_days,
    if(ifNull(a.duration_uom, '') = 'H', ifNull(a.duration, 0), 0)                       as absence_hours,
    now()                                                                               as _loaded_at
from {{ ref('stg_fusion__absence_entries') }} as a
inner join (select employee_key, person_id, branch_key, staff_key from {{ ref('hnh_dim_employee') }} where person_id is not null) as e
    on e.person_id = a.person_id
left join (select absence_type_key, absence_type_id from {{ ref('hnh_dim_absence_type') }} where absence_type_id is not null) as t
    on t.absence_type_id = a.absence_type_id
left join {{ ref('int_legal_employer_branch') }} as lb on lb.legal_employer_id = a.legal_employer_id
{{ hnh_settings() }}
```

`fact_absence_daily.sql`:

```sql
{{ config(order_by='(branch_key, date_key, absence_day_key)') }}

-- One row per calendar day of a counted, day-unit absence (spec 6.5); entries longer than 366 days are skipped.
with counted as (
    select a.absence_entry_id as absence_entry_id, a.start_date as start_date, a.end_date as end_date,
           if(ifNull(lb.branch_key, 0) = 0, e.branch_key, assumeNotNull(lb.branch_key)) as branch_key,
           e.employee_key as employee_key, e.staff_key as staff_key, ifNull(t.absence_type_key, toInt64(-1)) as absence_type_key
    from {{ ref('stg_fusion__absence_entries') }} as a
    inner join (select employee_key, person_id, branch_key, staff_key from {{ ref('hnh_dim_employee') }} where person_id is not null) as e
        on e.person_id = a.person_id
    left join (select absence_type_key, absence_type_id from {{ ref('hnh_dim_absence_type') }} where absence_type_id is not null) as t
        on t.absence_type_id = a.absence_type_id
    left join {{ ref('int_legal_employer_branch') }} as lb on lb.legal_employer_id = a.legal_employer_id
    where {{ hnh_is_counted_absence('a.absence_status_code', 'a.approval_status_code') }} = 1
      and ifNull(a.duration_uom, '') = 'C' and a.start_date is not null and a.end_date is not null
      and a.end_date >= a.start_date and dateDiff('day', a.start_date, a.end_date) <= 366
    {{ hnh_settings() }}
)

select
    {{ hnh_surrogate_key(['absence_entry_id', 'day']) }}    as absence_day_key,
    branch_key, employee_key, staff_key, absence_type_key,
    {{ hnh_date_key('day') }}                               as date_key,
    toUInt8(1)                                              as absence_days,
    now()                                                   as _loaded_at
from counted
array join arrayMap(i -> start_date + i, range(toUInt32(dateDiff('day', start_date, end_date) + 1))) as day
```

`fact_leave_balance_monthly.sql`:

```sql
{{ config(order_by='(branch_key, accrual_period_date_key, leave_balance_key)') }}

-- Leave balances with liability for annual-leave plans (spec 6.6): daily rate = monthly salary / 30, monthly salary =
-- recurring pay (Basic, Housing, Transport, Food, Clinical and Other allowances) of the latest payroll month on or before
-- the accrual period.
with balances as (
    select b.accrual_entry_id as accrual_entry_id, b.absence_plan_id as absence_plan_id, b.accrual_period_date as accrual_period_date,
           b.begin_balance as begin_balance, b.accrued as accrued, b.used as used, b.end_balance as end_balance,
           e.employee_key as employee_key, e.branch_key as branch_key,
           p.absence_plan_name as absence_plan_name,
           toUInt8(lower(ifNull(p.absence_plan_name, '')) like '%annual leave%') as is_annual_plan,
           toInt32(toYYYYMM(b.accrual_period_date)) as accrual_month
    from {{ ref('stg_fusion__absence_balances') }} as b
    inner join (select employee_key, person_id, branch_key from {{ ref('hnh_dim_employee') }} where person_id is not null) as e
        on e.person_id = b.person_id
    left join {{ ref('stg_fusion__absence_plans') }} as p on p.absence_plan_id = b.absence_plan_id
    {{ hnh_settings() }}
),

salary as (
    select employee_key, payroll_month, sum(amount) as monthly_salary
    from {{ ref('fact_payroll_monthly') }}
    where is_parallel_run = 0 and employee_key != -1
      and pay_category in ('Basic', 'Housing', 'Transport', 'Food', 'Clinical allowances', 'Other allowances')
    group by employee_key, payroll_month
)

select
    {{ hnh_surrogate_key(['b.accrual_entry_id']) }}                     as leave_balance_key,
    b.branch_key                                                        as branch_key,
    b.employee_key                                                      as employee_key,
    b.absence_plan_id                                                   as absence_plan_id,
    b.absence_plan_name                                                 as absence_plan_name,
    b.is_annual_plan                                                    as is_annual_plan,
    ifNull({{ hnh_date_key_in_range('b.accrual_period_date') }}, 0)     as accrual_period_date_key,
    b.begin_balance, b.accrued, b.used, b.end_balance,
    if(b.is_annual_plan = 1 and s.payroll_month is not null, toNullable(s.monthly_salary), cast(null as Nullable(Float64))) as monthly_salary,
    monthly_salary / 30                                                 as daily_rate,
    b.end_balance * daily_rate                                          as leave_liability_amount,
    now()                                                               as _loaded_at
from balances as b
asof left join salary as s on s.employee_key = b.employee_key and s.payroll_month <= b.accrual_month
{{ hnh_settings() }}
```

If `asof left join` rejects `join_use_nulls`, keep the ASOF join and test `s.payroll_month = 0` (the default for an unmatched ASOF row without `join_use_nulls`) instead of `is not null`; record the change in the report.

Append to `assert_workforce_facts_have_branch.sql`:

```sql
union all
select 'fact_absence', count() from {{ ref('fact_absence') }} where branch_key = 0 having count() > 0
union all
select 'fact_leave_balance_monthly', count() from {{ ref('fact_leave_balance_monthly') }} where branch_key = 0 having count() > 0
```

- [ ] **Step 3: Run the unit tests and the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select fact_absence fact_absence_daily fact_leave_balance_monthly assert_workforce_facts_have_branch`
Expected: both unit tests PASS; models built; tests PASS. Spot-check total leave liability at the latest accrual period by branch; record.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/workforce/ hnh_dwh/tests/hnh/assert_workforce_facts_have_branch.sql
git commit -m "Add absence entries with a daily split and leave balances with liability"
```

---

### Task 9: Productivity aggregate, reconciliation and monitors

**Files:**
- Create: `hnh_dwh/models/hnh/marts/workforce/agg_staff_productivity_monthly.sql`, `hnh_dwh/models/hnh/marts/reconciliation/rec_payroll_monthly.sql`, `rec_headcount_monthly.sql`; tests `warn_unmapped_pay_codes.sql`, `warn_employees_without_staff_link.sql`, `warn_staff_linked_to_many_employees.sql`, `warn_branch8_payroll_copies_branch7.sql`, `warn_fte_out_of_range.sql`, `warn_leave_without_salary.sql`, `warn_absence_zero_days.sql`
- Modify: `_workforce_marts__models.yml`, `_reconciliation__models.yml`

**Interfaces:**
- Consumes: workforce facts and dims; Phase 1 `fact_encounter` (treating_staff_key, encounter_date_key, is_arrived, is_cancelled); Phase 2 `fact_charge_line` (staff_key, delivery_date_key, revenue_amount); `dim_staff` (staff_key, category); Phase 3 `hnh_fact_gl_journal_line` (branch_key, period_key, je_source_label, debit, gl_account_key), `hnh_dim_gl_account` (gl_account_key, balance_side), `hnh_dim_gl_period` (period_key, end_date), `fact_income_statement_monthly` (branch_key, month_start, budget_line_code, actual_including_unposted).
- Produces:
  - `agg_staff_productivity_monthly(staff_key, branch_key, month_date_key, month_start, staff_category, encounters_seen, revenue_amount, payroll_cost, gross_pay, fte, absence_days, _loaded_at)`
  - `rec_payroll_monthly(branch_key, payroll_month, payroll_cost, gross_pay, oasis_parallel_gross_pay, fusion_gross_pay, gl_employee_cost, gl_payroll_journal_debit)`
  - `rec_headcount_monthly(branch_key, month_end, fusion_headcount, fusion_fte, oasis_paid_headcount, fusion_paid_headcount)`

- [ ] **Step 1: Write the YAML tests**

Append to `_workforce_marts__models.yml`:

```yaml
  - name: agg_staff_productivity_monthly
    tests:
      - hnh_unique_combination:
          columns: [staff_key, month_date_key]
    columns:
      - name: staff_key
        tests:
          - relationships: {to: ref('dim_staff'), field: staff_key}
```

Append to `_reconciliation__models.yml`:

```yaml
  - name: rec_payroll_monthly
    tests:
      - hnh_unique_combination:
          columns: [branch_key, payroll_month]
  - name: rec_headcount_monthly
    tests:
      - hnh_unique_combination:
          columns: [branch_key, month_end]
```

Run: `python scripts/run_dbt.py build --no-partial-parse --select agg_staff_productivity_monthly rec_payroll_monthly rec_headcount_monthly`
Expected: FAIL — models not found.

- [ ] **Step 2: Write the aggregate and the reconciliation models**

`agg_staff_productivity_monthly.sql`:

```sql
{{ config(order_by='(branch_key, month_date_key, staff_key)') }}

-- Linked doctors and nurses per month from the snapshot start (spec 6.7): one row per staff and month with activity
-- or pay. Ratios are sums over this table in SSAS.
{% set start_key = "toInt32(toYYYYMMDD(toDate('" ~ var('hnh_hr_snapshot_start') ~ "')))" %}

with linked as (
    select b.staff_key as staff_key, b.branch_key as branch_key, s.category as staff_category
    from {{ ref('bridge_employee_staff') }} as b
    inner join (select staff_key, category from {{ ref('dim_staff') }}) as s on s.staff_key = b.staff_key
    where ifNull(s.category, '') in ('DOCTORS', 'NURSE')
),

measures as (
    select treating_staff_key as staff_key, toStartOfMonth(toDate(toString(encounter_date_key))) as month_start,
           toUInt64(count()) as encounters_seen, toFloat64(0) as revenue_amount, toFloat64(0) as payroll_cost,
           toFloat64(0) as gross_pay, toFloat64(0) as fte, toFloat64(0) as absence_days
    from {{ ref('fact_encounter') }}
    where is_arrived = 1 and is_cancelled = 0 and encounter_date_key >= {{ start_key }}
      and treating_staff_key in (select staff_key from linked)
    group by staff_key, month_start
    union all
    select staff_key, toStartOfMonth(toDate(toString(delivery_date_key))), 0, sum(revenue_amount), 0, 0, 0, 0
    from {{ ref('fact_charge_line') }}
    where delivery_date_key >= {{ start_key }} and staff_key in (select staff_key from linked)
    group by staff_key, toStartOfMonth(toDate(toString(delivery_date_key)))
    union all
    select staff_key, toStartOfMonth(toDate(toString(month_date_key))), 0, 0, sum(cost_amount), sum(gross_pay), 0, 0
    from {{ ref('fact_payroll_monthly') }}
    where month_date_key >= {{ start_key }} and staff_key in (select staff_key from linked)
    group by staff_key, toStartOfMonth(toDate(toString(month_date_key)))
    union all
    select staff_key, toStartOfMonth(month_end), 0, 0, 0, 0, sum(fte), 0
    from {{ ref('fact_headcount_monthly') }}
    where staff_key in (select staff_key from linked)
    group by staff_key, toStartOfMonth(month_end)
    union all
    select staff_key, toStartOfMonth(toDate(toString(date_key))), 0, 0, 0, 0, 0, sum(absence_days)
    from {{ ref('fact_absence_daily') }}
    where staff_key in (select staff_key from linked)
    group by staff_key, toStartOfMonth(toDate(toString(date_key)))
    -- if ClickHouse reports a type mismatch between the union branches, cast the literal zeros (toUInt64(0), toFloat64(0))
)

select
    m.staff_key                                 as staff_key,
    l.branch_key                                as branch_key,
    {{ hnh_date_key('m.month_start') }}         as month_date_key,
    m.month_start                               as month_start,
    any(l.staff_category)                       as staff_category,
    sum(m.encounters_seen)                      as encounters_seen,
    sum(m.revenue_amount)                       as revenue_amount,
    sum(m.payroll_cost)                         as payroll_cost,
    sum(m.gross_pay)                            as gross_pay,
    sum(m.fte)                                  as fte,
    sum(m.absence_days)                         as absence_days,
    now()                                       as _loaded_at
from measures as m
inner join linked as l on l.staff_key = m.staff_key
group by m.staff_key, l.branch_key, m.month_start
```

`rec_payroll_monthly.sql`:

```sql
{{ config(order_by='(branch_key, payroll_month)') }}

-- Payroll cost against the GL (employee-cost budget lines and Payroll-source journal debits) and Oasis against Fusion
-- in parallel-run months, per branch and month.
with pay as (
    select branch_key, payroll_month,
           sum(cost_amount) as payroll_cost, sum(gross_pay) as gross_pay,
           sumIf(amount, source = 'oasis' and is_parallel_run = 1 and pay_category in ('Basic', 'Housing', 'Transport', 'Food', 'Clinical allowances', 'Other allowances', 'Overtime', 'Leave pay', 'End of service', 'Awards and bonus', 'Absence and lateness deduction')) as oasis_parallel_gross_pay,
           sumIf(gross_pay, source = 'fusion') as fusion_gross_pay
    from {{ ref('fact_payroll_monthly') }}
    group by branch_key, payroll_month
),

gl_cost as (
    select branch_key, toInt32(toYYYYMM(month_start)) as payroll_month, sum(actual_including_unposted) as gl_employee_cost
    from {{ ref('fact_income_statement_monthly') }}
    where budget_line_code in ('DC_EMPLOYEE', 'GA_EMPLOYEE')
    group by branch_key, payroll_month
),

gl_journal as (
    select j.branch_key as branch_key, toInt32(toYYYYMM(p.end_date)) as payroll_month, sum(j.debit) as gl_payroll_journal_debit
    from {{ ref('hnh_fact_gl_journal_line') }} as j
    inner join (select gl_account_key from {{ ref('hnh_dim_gl_account') }} where balance_side = 'IS') as a on a.gl_account_key = j.gl_account_key
    inner join (select period_key, end_date from {{ ref('hnh_dim_gl_period') }}) as p on p.period_key = j.period_key
    where j.je_source_label = 'Payroll'
    group by branch_key, payroll_month
),

spine as (
    select branch_key, payroll_month from pay
    union distinct select branch_key, payroll_month from gl_cost
    union distinct select branch_key, payroll_month from gl_journal
)

select
    s.branch_key                                    as branch_key,
    s.payroll_month                                 as payroll_month,
    ifNull(p.payroll_cost, 0)                       as payroll_cost,
    ifNull(p.gross_pay, 0)                          as gross_pay,
    ifNull(p.oasis_parallel_gross_pay, 0)           as oasis_parallel_gross_pay,
    ifNull(p.fusion_gross_pay, 0)                   as fusion_gross_pay,
    ifNull(c.gl_employee_cost, 0)                   as gl_employee_cost,
    ifNull(g.gl_payroll_journal_debit, 0)           as gl_payroll_journal_debit
from spine as s
left join pay as p on p.branch_key = s.branch_key and p.payroll_month = s.payroll_month
left join gl_cost as c on c.branch_key = s.branch_key and c.payroll_month = s.payroll_month
left join gl_journal as g on g.branch_key = s.branch_key and g.payroll_month = s.payroll_month
{{ hnh_settings() }}
```

`rec_headcount_monthly.sql`:

```sql
{{ config(order_by='(branch_key, month_end)') }}

-- Fusion month-end headcount beside paid headcount from each payroll source, from the snapshot start.
with hc as (
    select branch_key, month_end, sumIf(headcount, is_contingent = 0) as fusion_headcount, sumIf(fte, is_contingent = 0) as fusion_fte
    from {{ ref('fact_headcount_monthly') }}
    group by branch_key, month_end
),

paid as (
    select branch_key, toLastDayOfMonth(makeDate(intDiv(payroll_month, 100), payroll_month % 100, 1)) as month_end,
           uniqExactIf(payee_key, source = 'oasis' and amount > 0 and pay_category = 'Basic') as oasis_paid_headcount,
           uniqExactIf(payee_key, source = 'fusion' and amount > 0 and pay_category = 'Basic') as fusion_paid_headcount
    from {{ ref('fact_payroll_monthly') }}
    where payroll_month >= toInt32(toYYYYMM(toDate('{{ var("hnh_hr_snapshot_start") }}')))
    group by branch_key, month_end
),

spine as (
    select branch_key, month_end from hc
    union distinct select branch_key, month_end from paid
)

select
    s.branch_key                            as branch_key,
    s.month_end                             as month_end,
    ifNull(h.fusion_headcount, 0)           as fusion_headcount,
    ifNull(h.fusion_fte, 0)                 as fusion_fte,
    ifNull(p.oasis_paid_headcount, 0)       as oasis_paid_headcount,
    ifNull(p.fusion_paid_headcount, 0)      as fusion_paid_headcount
from spine as s
left join hc as h on h.branch_key = s.branch_key and h.month_end = s.month_end
left join paid as p on p.branch_key = s.branch_key and p.month_end = s.month_end
{{ hnh_settings() }}
```

- [ ] **Step 3: Write the monitors**

`warn_unmapped_pay_codes.sql`:

```sql
{{ config(severity='warn') }}
-- Pay codes with no pay category (not counted in cost), by source and branch, with their amounts.
select source, branch_key, count() as rows, round(sum(amount), 2) as amount
from {{ ref('fact_payroll_monthly') }}
where pay_category = 'Unmapped'
group by source, branch_key
```

`warn_employees_without_staff_link.sql`:

```sql
{{ config(severity='warn') }}
-- Current hospital employees whose worker number matches no Oasis staff in their branch.
select branch_key, count() as employees
from {{ ref('hnh_dim_employee') }}
where employee_key != -1 and staff_key = -1 and branch_key between 1 and 8 and worker_type_code = 'EMP' and is_terminated = 0
group by branch_key
```

`warn_staff_linked_to_many_employees.sql`:

```sql
{{ config(severity='warn') }}
-- Oasis staff records linked to more than one Fusion employee (rehires or reused worker numbers).
select staff_key, branch_key, count() as employees
from {{ ref('bridge_employee_staff') }}
group by staff_key, branch_key
having count() > 1
```

`warn_branch8_payroll_copies_branch7.sql`:

```sql
{{ config(severity='warn') }}
-- Months where branch 8's Oasis payroll equals branch 7's in paid staff and amount (source duplication, spec H11).
with m as (
    select branch_key, payroll_month, uniqExact(payee_key) as payees, round(sum(amount), 0) as amount
    from {{ ref('fact_payroll_monthly') }}
    where source = 'oasis' and branch_key in (7, 8)
    group by branch_key, payroll_month
)
select a.payroll_month, a.payees, a.amount
from m as a inner join m as b on b.payroll_month = a.payroll_month and b.branch_key = 7
where a.branch_key = 8 and a.payees = b.payees and a.amount = b.amount
```

`warn_fte_out_of_range.sql`:

```sql
{{ config(severity='warn') }}
-- FTE work measures outside (0, 1.5] (replaced by 1 in the snapshot).
select unit, count() as measures, min(value) as min_value, max(value) as max_value
from {{ ref('stg_fusion__work_measures') }}
where unit = 'FTE' and not (value > 0 and value <= 1.5)
group by unit
```

`warn_leave_without_salary.sql`:

```sql
{{ config(severity='warn') }}
-- Annual-leave balances with no monthly salary, so no liability (spec 6.6), by branch at the latest accrual period.
select branch_key, count() as balances, round(sum(end_balance), 1) as days
from {{ ref('fact_leave_balance_monthly') }}
where is_annual_plan = 1 and monthly_salary is null
  and accrual_period_date_key = (select max(accrual_period_date_key) from {{ ref('fact_leave_balance_monthly') }})
group by branch_key
```

`warn_absence_zero_days.sql`:

```sql
{{ config(severity='warn') }}
-- Counted day-unit absences with zero or missing days.
select branch_key, count() as entries
from {{ ref('fact_absence') }}
where is_counted = 1 and duration_uom = 'C' and absence_days <= 0
group by branch_key
```

- [ ] **Step 4: Run the build**

Run: `python scripts/run_dbt.py build --no-partial-parse --select agg_staff_productivity_monthly rec_payroll_monthly rec_headcount_monthly warn_unmapped_pay_codes warn_employees_without_staff_link warn_staff_linked_to_many_employees warn_branch8_payroll_copies_branch7 warn_fte_out_of_range warn_leave_without_salary warn_absence_zero_days`
Expected: models built; uniqueness and relationship tests PASS; monitors PASS or WARN (never ERROR); `warn_branch8_payroll_copies_branch7` returns the four January–April 2026 months. Record each monitor's row count and `select * from gold.rec_payroll_monthly where payroll_month >= 202601 order by 1, 2` for Task 10.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/marts/ hnh_dwh/tests/hnh/
git commit -m "Add staff productivity, payroll and headcount reconciliation, and workforce monitors"
```

---

### Task 10: Documentation, full build and measurements

**Files:**
- Create: `docs/reconciliation_phase4.md`
- Modify: `docs/receiving_project_config.md`, `docs/superpowers/specs/2026-10-06-hnh-dwh-phase4-workforce-design.md` (section 11 "Changes during implementation", only if anything changed)

- [ ] **Step 1: Full build**

Run: `python scripts/run_dbt.py build --select tag:hnh`
Expected: `ERROR=0`. Note PASS, WARN and duration; if a test errors, report BLOCKED with the node and error (do not change models in this task).

- [ ] **Step 2: Measure**

Through `ch_env`, record: headcount and FTE by branch at the latest month-end (non-contingent); hires and leavers per month in 2026; Saudisation rate by branch at the latest month-end; payroll gross pay by branch and month 2026 by source; leave liability by branch at the latest accrual period; `rec_payroll_monthly` for 2026; `rec_headcount_monthly` for 2026; row counts of all workforce facts; each monitor's row count from the build.

- [ ] **Step 3: Write `docs/reconciliation_phase4.md`**

Sections (fill every number from Step 2; no placeholders left):
1. **Payroll against the GL (`gold.rec_payroll_monthly`)** — `payroll_cost` beside `gl_employee_cost` (DC_EMPLOYEE + GA_EMPLOYEE actual including unposted) and `gl_payroll_journal_debit` (Payroll-source journals on income-statement accounts); differences are expected where payroll is posted in a later month or through accruals; branches still paid from Oasis (Al-Rabwa, Khamis, Madinah) have Oasis payroll and Fusion GL from their GL go-live.
2. **Cutover check** — for each branch's parallel-run months, `oasis_parallel_gross_pay` beside `fusion_gross_pay`; a large gap means the cutover month in `map_payroll_cutover` is wrong.
3. **Headcount (`gold.rec_headcount_monthly`)** — Fusion month-end headcount beside paid headcount (people with basic pay) from Oasis and Fusion.
4. **Monitors at first build** — table of the seven workforce monitors with row counts and a one-line note each.

- [ ] **Step 4: Update `docs/receiving_project_config.md`**

1. Under "Add to `dbt/dbt_project.yml`" `vars:` add `hnh_hr_snapshot_start: "2026-01-01"` and `hnh_hr_snapshot_end: ""` and update the var count sentence.
2. In "How the models read Fusion" add the HCM tables now read through `hnh_fusion_source` (the 19 names from Task 3), and note that `account_transactions` is read through `hnh_oasis_source`.
3. In "Aliased models" add the eight Phase 4 aliases from the Global Constraints.
4. In "Reference tables that must exist in `default`" add `map_pay_category` (drafted by `scripts/draft_pay_category_map.py`) and `map_payroll_cutover` (one row per branch when it moves payroll to Fusion — update it when Al-Rabwa, Khamis or Madinah move).
5. Append to "Notes for the SSAS model":
   - Headcount is a month-end snapshot from January 2026: use the last month of the selection or an average, never a sum across months; exclude contingent workers (`is_contingent = 0`) by default. Before 2026 only paid headcount (distinct `payee_key` with basic pay in `fact_payroll_monthly`) exists.
   - Payroll measures filter `is_parallel_run = 0` (the cost columns already exclude parallel-run rows; `amount` does not).
   - Turnover = leavers ÷ average month-end headcount, from 2026.
   - Put `fact_payroll_monthly`, `fact_leave_balance_monthly` and `agg_staff_productivity_monthly` in an HR/finance-only perspective and role; they carry pay.
   - Leave liability = end balance × monthly salary ÷ 30, monthly salary = recurring pay (basic, housing, transport, food, clinical and other allowances) of the latest paid month; null where the person has not been paid yet.
   - `agg_staff_productivity_monthly` covers linked doctors and nurses; compute revenue per payroll SAR as Σ `revenue_amount` ÷ Σ `payroll_cost`, never an average of ratios.

- [ ] **Step 5: Record changes in the spec**

If any rule or name changed while implementing, add `## 11. Changes during implementation (<date>)` to the spec, one sentence per change; otherwise skip.

- [ ] **Step 6: Commit**

```bash
git add docs/reconciliation_phase4.md docs/receiving_project_config.md docs/superpowers/specs/2026-10-06-hnh-dwh-phase4-workforce-design.md
git commit -m "Document Phase 4 hand-off and workforce reconciliation"
```
