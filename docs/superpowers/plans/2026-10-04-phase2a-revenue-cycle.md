# Phase 2A — Revenue Cycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Phase 2A revenue facts in `gold` — charge lines, revenue adjustments, patient receipts, episode invoices with episode billing, and pre-authorisation lines — with their corrected rules, `legacy_*` reconciliation fields and three monthly reconciliation models.

**Architecture:** Oasis billing and pre-authorisation tables are staged as views. Row-level rules are `hnh_` macros tested with literal inputs. `fact_charge_line` (about 105M rows) is incremental by delivery day and reads staging directly; the pre-authorisation response logic lives in `int_preauth_line`. Multi-row rules (co-pay sibling match, final-response pick, latest request per service, discount-document match, delivery after request) are dbt unit tests with SQL fixtures.

**Tech Stack:** ClickHouse 26.5 (216 GB RAM, no per-query memory limit), dbt-core 1.11.12, dbt-clickhouse 1.9.8, Python 3.13 with `clickhouse_connect`.

**Spec:** `docs/superpowers/specs/2026-10-04-hnh-dwh-phase2-revenue-cycle-design.md` (parent: `docs/superpowers/specs/2026-10-01-hnh-dwh-gold-layer-design.md`)

**Prerequisite:** Phase 1 is built on this branch's base (`phase1-patient-flow`) and `python scripts/run_dbt.py build --select tag:hnh` passes. Work happens on branch `phase2-revenue-cycle`.

## Global Constraints

- All Phase 1 constraints apply unchanged: databases `stg` / `int` / `gold`; never write to `oasis`, `fusion`, `press_ganey`; models, macros and tests only under `hnh/` folders; macros prefixed `hnh_`; no packages, no seeds; `branch_id` is `UInt8`; Oasis timestamps go through `hnh_ksa_wall_clock`; keys through `hnh_surrogate_key`; every model with a `left join` ends with `{{ hnh_settings() }}`; YAML uses the `tests:` key; Oasis tables are read with `{{ hnh_oasis_source('<table>') }}` and `final`.
- Run dbt only through `python scripts/run_dbt.py <dbt args>` from the repository root. Query ClickHouse ad hoc with `scripts/ch_env.py` (`from ch_env import client`).
- Facts start at `var('hnh_history_start_date')` (`2022-01-01`) and end at the last `dim_date` day, `toDate(concat(toString(toYear(today()) + 2), '-12-31'))`.
- Fact dimension keys are never null: a reference missing from its dimension becomes `-1`. Optional date keys use `hnh_date_key_in_range` and are nullable.
- Every fact has `_loaded_at` (`now()`), engine `MergeTree`, and an `order_by` starting with `branch_key`.
- Fields that reproduce old-warehouse behaviour are prefixed `legacy_` and are never used by a new KPI.
- Durations are whole minutes through `hnh_minutes_between` (0–1,440, else null) with the unguarded value in a matching `*_raw` column.
- dbt unit tests live in `*_unit_tests.yml`, use `format: sql` for every `given` input, mock **every** `ref()` of the model under test (columns the model reads are enough), and need dbt-core 1.8 or later.
- Reference data is never a seed and never committed: CSV files stay in `static_mappings/` (git-ignored); tables are loaded once into `default` by `scripts/load_reference_data.py`, which never overwrites a table that has rows.
- Card numbers (`payment_card_no`, `crd_payment_card_no`), member names, mobiles, identity numbers and free-text clinical fields of pre-authorisation requests are never staged.
- Medication product categories are exactly `MD, MED, PH, CSM, RTL, MLK`; pharmacy work entities are entity type `P`.

### Spec refinements made while planning (all within the spec's intent)

| Spec says | Plan does | Why |
|---|---|---|
| `staff_id` cast to `Int64` | `hnh_code(staff_id)` text | Phase 1 `dim_staff` keys staff by text code; 10% of charge staff ids are not numeric. |
| `stg_oasis__ios_main` | Reuse existing `stg_oasis__service_items` (same table) | Avoids a second view of `ios_main_data`. |
| Encounter key on charges | `encounter_id` and `encounter_type` kept as attributes only | `delivery_charge.encounter_id` is the Oasis encounter id, not the Phase 1 appointment/ER/admission key (parent spec 13.1). |
| `is_ltc` from `fact_admission` | From `int_admission` (`is_ltc` or `is_ltc_to_date`) | A gold model reads `int`, not another fact, when an `int` exists. |
| Request status `S` with flag `N` and no NPHIES response: not specified | `Pended` | The request was sent and is awaiting a decision (legacy label "Sent"). |
| Requesting department as a key | `service_dept` code kept as an attribute | It is a service department code, not a work entity, so it cannot key `dim_department`. |
| Receipt user key | Not included | `doc` has no cashier column in scope. |
| — | `billed_purchaser_code` and `episode_purchaser_code` added to `fact_charge_line` | Natural codes beside the keys, for display and for unit tests. |
| `rec_revenue_monthly` acceptance against `mv_revenue_dataset` | Same, through `legacy_charge_revenue`; old discount documents shown separately | As spec 11.3. |

## Review Focus

1. **A co-pay row whose purchaser row was cancelled or superseded** (the only live row on the delivery line is the patient's): it must be treated as pure cash (`9999`, `is_cash_billed = 1`), not as Deductible. Pinned in Task 6 (`fact_charge_line` unit test, delivery line 60).
2. **A pre-authorisation answered APPROVED and later re-answered with an ERROR or PENDED response**: the final outcome must stay Approved while `nphies_last_status` shows the later response. Pinned in Task 9 (`int_preauth_line` unit test, line A1).
3. **A service delivered before its pre-authorisation request** (same patient, episode and service): it must not count as delivered for that request, so an approved request stays "approved, not delivered". Pinned in Task 10 (`fact_preauth_line` unit test, line A1).
4. **A fixed-asset depreciation document whose number ends in `D`** (`SYSDPRC`), and a credit document ending in `D` whose base is not a charge invoice: neither may become a revenue adjustment. Pinned in Task 7 (`fact_revenue_adjustment` unit test, documents 3 and 4).
5. **A second request for a different service in the same episode**: earlier approved, undelivered lines for another service must stay in Lost Revenue (`is_latest_request_for_service = 1`), unlike the legacy per-episode rule. Pinned in Task 9 (`int_preauth_line` unit test, lines A2 and A3).

## File Structure

```
scripts/
  extract_pbi_table.py                       decodes a table embedded in a TMDL partition into a CSV
  load_reference_data.py                     + map_nphies_reason; connects through ch_env
hnh_dwh/
  macros/hnh/hnh_rules_revenue.sql           charge, payer, medication, care-type and pre-auth rules
  tests/hnh/assert_hnh_revenue_macros.sql
  tests/hnh/assert_fact_charge_line_matches_staging.sql
  tests/hnh/assert_fact_invoice_matches_staging.sql
  tests/hnh/assert_preauth_line_conservation.sql
  tests/hnh/warn_*.sql                       six revenue monitors (Task 11)
  models/hnh/staging/reference/              + stg_ref__product_category, stg_ref__claim_status, stg_ref__nphies_reason
  models/hnh/staging/oasis/                  + 14 staging views (Tasks 3 and 4)
  models/hnh/intermediate/revenue/
    _revenue__models.yml, _revenue_unit_tests.yml
    int_invoice_payer.sql, int_preauth_line.sql
  models/hnh/marts/conformed/                + dim_service, dim_product_category, dim_preauth_outcome
  models/hnh/marts/revenue/
    _revenue_marts__models.yml, _revenue_marts_unit_tests.yml
    fact_charge_line.sql, fact_revenue_adjustment.sql, fact_cash_receipt.sql,
    fact_invoice.sql, agg_episode_billing.sql, fact_preauth_line.sql
  models/hnh/marts/reconciliation/           + rec_revenue_monthly, rec_billing_monthly, rec_preauth_monthly
docs/
  receiving_project_config.md                + Phase 2 notes
  reconciliation_phase2.md                   acceptance guide
```

---

### Task 1: Reference data for revenue

**Files:**
- Create: `scripts/extract_pbi_table.py`
- Modify: `scripts/load_reference_data.py` (`connect()` and `SMALL_TABLES`)
- Modify: `hnh_dwh/models/hnh/staging/reference/_reference__sources.yml`
- Create: `hnh_dwh/models/hnh/staging/reference/stg_ref__product_category.sql`, `stg_ref__claim_status.sql`, `stg_ref__nphies_reason.sql`
- Modify: `hnh_dwh/models/hnh/staging/reference/_reference__models.yml`

**Interfaces:**
- Produces: `stg_ref__product_category(branch_id UInt8, category_code String, group_name, unified_category, department, high_level_department Nullable(String))`; `stg_ref__claim_status(detailed_status, submission_status, validation_status String)`; `stg_ref__nphies_reason(reason_code, reason, reason_category String)`; table `default.map_nphies_reason(CODE, REASON, CATEGORY)`.

- [ ] **Step 1: Make the loader connect through `ch_env`**

The machine's `CLICKHOUSE_PASSWORD` belongs to a different server. In `scripts/load_reference_data.py` replace `connect()`:

```python
def connect():
    # HNH_CH_* settings (or the clickhouse MCP entry), never the machine-wide CLICKHOUSE_* variables.
    from ch_env import client
    return client()
```

and remove the now-unused `import os` only if nothing else uses it (`grep -n "os\." scripts/load_reference_data.py`). Update the module docstring line "Connection comes from the environment: CLICKHOUSE_HOST, …" to "Connection comes from scripts/ch_env.py (HNH_CH_* variables or the clickhouse MCP entry)."

- [ ] **Step 2: Write the TMDL table extractor**

`scripts/extract_pbi_table.py`:

```python
"""Write a table that a Power BI model embeds in its partition (Table.FromRows over a
compressed JSON blob) to a CSV file.

Usage: python scripts/extract_pbi_table.py <table.tmdl> <out.csv> <COL1> <COL2> ...
"""
import base64
import csv
import json
import re
import sys
import zlib


def main():
    tmdl, out, columns = sys.argv[1], sys.argv[2], sys.argv[3:]
    text = open(tmdl, encoding="utf-8").read()
    match = re.search(r'Binary\.FromText\("([^"]+)"', text)
    if not match:
        raise SystemExit(f"No embedded table in {tmdl}")
    rows = json.loads(zlib.decompress(base64.b64decode(match.group(1)), -15))
    if any(len(r) != len(columns) for r in rows):
        raise SystemExit(f"Expected {len(columns)} columns per row")
    with open(out, "w", encoding="utf-8", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(columns)
        writer.writerows([[str(v).strip() for v in r] for r in rows])
    print(f"wrote {len(rows)} rows to {out}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Extract the NPHIES rejection reasons**

Run: `python scripts/extract_pbi_table.py "powerbi_tmdl/claims/tables/Rejection Reasons.tmdl" static_mappings/nphies_reason_mapping.csv CODE REASON CATEGORY`
Expected: `wrote 73 rows to static_mappings/nphies_reason_mapping.csv`. Then `git status --short static_mappings` must print nothing (CSV is ignored).

- [ ] **Step 4: Add the table to the loader**

In `SMALL_TABLES` of `scripts/load_reference_data.py`, after `"map_claim_status"`:

```python
    "map_nphies_reason": (
        "nphies_reason_mapping.csv",
        [("CODE", "String", s), ("REASON", "String", s), ("CATEGORY", "LowCardinality(String)", s)],
        "CODE",
    ),
```

Run: `python scripts/load_reference_data.py --only map_nphies_reason`
Expected: `default.map_nphies_reason: loaded 73 -> 73 rows in table`.

- [ ] **Step 5: Declare the sources and write the failing model tests**

Append to the `tables:` list in `_reference__sources.yml`:

```yaml
      - name: map_product_category
      - name: map_claim_status
      - name: map_nphies_reason
```

Append to `_reference__models.yml` (under `models:`):

```yaml
  - name: stg_ref__product_category
    tests:
      - hnh_unique_combination:
          columns: [branch_id, category_code]
  - name: stg_ref__claim_status
    columns:
      - name: detailed_status
        tests: [unique, not_null]
  - name: stg_ref__nphies_reason
    columns:
      - name: reason_code
        tests: [unique, not_null]
      - name: reason_category
        tests:
          - accepted_values:
              values: ['Technical and contractual', 'Appropriateness of care', 'Pharmacy Benefit Management', 'Duplicated Service', 'Fraud']
```

Run: `python scripts/run_dbt.py build --select stg_ref__product_category stg_ref__claim_status stg_ref__nphies_reason`
Expected: FAIL — the three models do not exist.

- [ ] **Step 6: Write the staging models**

`stg_ref__product_category.sql` (`GROUP` is a keyword, so it is quoted):

```sql
select
    toUInt8(BRANCH_ID)                  as branch_id,
    assumeNotNull({{ hnh_code('CATEGORY_CODE') }}) as category_code,
    {{ hnh_str('`GROUP`') }}            as group_name,
    {{ hnh_str('UNIFIED_CATEGORY') }}   as unified_category,
    {{ hnh_str('DEPARTMENT') }}         as department,
    {{ hnh_str('HIGH_LEVEL_DEPT') }}    as high_level_department
from {{ source('reference', 'map_product_category') }}
where {{ hnh_code('CATEGORY_CODE') }} is not null
```

`stg_ref__claim_status.sql`:

```sql
select
    trimBoth(DetailedStatus)    as detailed_status,
    trimBoth(SubmitionStatus)   as submission_status,
    trimBoth(ValidationStatus)  as validation_status
from {{ source('reference', 'map_claim_status') }}
```

`stg_ref__nphies_reason.sql`:

```sql
select
    upper(trimBoth(CODE))   as reason_code,
    trimBoth(REASON)        as reason,
    trimBoth(CATEGORY)      as reason_category
from {{ source('reference', 'map_nphies_reason') }}
```

- [ ] **Step 7: Run the tests**

Run: `python scripts/run_dbt.py build --select stg_ref__product_category stg_ref__claim_status stg_ref__nphies_reason`
Expected: PASS, 3 models and 5 tests.

- [ ] **Step 8: Commit**

```bash
git add scripts/extract_pbi_table.py scripts/load_reference_data.py hnh_dwh/models/hnh/staging/reference
git commit -m "Add revenue reference sources and the NPHIES reason loader"
```

---

### Task 2: Revenue rule macros

**Files:**
- Create: `hnh_dwh/macros/hnh/hnh_rules_revenue.sql`
- Test: `hnh_dwh/tests/hnh/assert_hnh_revenue_macros.sql`

**Interfaces:**
- Produces (all return ClickHouse expressions):
  - `hnh_charge_status(cancel_flag)` → `'Live' | 'Cancelled' | 'Superseded' | 'Unknown'`
  - `hnh_is_recognised_revenue(cancel_flag, package_deal_flag)` → `UInt8`
  - `hnh_is_medication(product_category_code, delivery_entity_type)` → `UInt8`
  - `hnh_billed_purchaser(bill_to, purchaser_code, has_purchaser_sibling)` → `Int64`
  - `hnh_charge_care_type(episode_care_type, attendance_type)` → `'OP' | 'ER' | 'IP' | 'DAYCASE' | 'Unknown'`
  - `hnh_preauth_outcome(nphies_status, authorised_flag, request_status)` → outcome label
  - `hnh_preauth_outcome_key(expr)` → `Int8`

- [ ] **Step 1: Write the failing macro test**

`tests/hnh/assert_hnh_revenue_macros.sql`:

```sql
{% set null_s = "cast(null as Nullable(String))" %}
{% set null_i = "cast(null as Nullable(Int64))" %}

select 'charge status wrong' as failure
where {{ hnh_charge_status(null_s) }} != 'Live' or {{ hnh_charge_status("'C'") }} != 'Cancelled'
   or {{ hnh_charge_status("'R'") }} != 'Superseded' or {{ hnh_charge_status("'Q'") }} != 'Unknown'

union all
select 'recognised revenue wrong'
where {{ hnh_is_recognised_revenue(null_s, null_s) }} != 1
   or {{ hnh_is_recognised_revenue(null_s, "'N'") }} != 1
   or {{ hnh_is_recognised_revenue(null_s, "'Y'") }} != 0
   or {{ hnh_is_recognised_revenue("'C'", null_s) }} != 0
   or {{ hnh_is_recognised_revenue("'R'", null_s) }} != 0

union all
select 'medication flag wrong'
where {{ hnh_is_medication("'MD'", "'W'") }} != 1 or {{ hnh_is_medication("'RTL'", null_s) }} != 1
   or {{ hnh_is_medication("'LAB'", "'P'") }} != 1 or {{ hnh_is_medication("'LAB'", "'V'") }} != 0
   or {{ hnh_is_medication(null_s, null_s) }} != 0

union all
select 'billed purchaser wrong'
where {{ hnh_billed_purchaser("'1'", "toNullable(toInt64(300))", "toUInt8(1)") }} != 300
   or {{ hnh_billed_purchaser("'3'", "toNullable(toInt64(300))", "toUInt8(1)") }} != 8888
   or {{ hnh_billed_purchaser("'2'", null_i, "toUInt8(1)") }} != 8888
   or {{ hnh_billed_purchaser("'3'", null_i, "toUInt8(0)") }} != 9999
   or {{ hnh_billed_purchaser("'3'", "toNullable(toInt64(410))", "toUInt8(0)") }} != 410
   or {{ hnh_billed_purchaser("'1'", null_i, "toUInt8(1)") }} != 9999

union all
select 'charge care type wrong'
where {{ hnh_charge_care_type("'ER'", "'O'") }} != 'ER'
   or {{ hnh_charge_care_type("'Unknown'", "'I'") }} != 'IP'
   or {{ hnh_charge_care_type(null_s, "'O'") }} != 'OP'
   or {{ hnh_charge_care_type(null_s, null_s) }} != 'Unknown'

union all
select 'preauth outcome wrong'
where {{ hnh_preauth_outcome("'APPROVED'", null_s, null_s) }} != 'Approved'
   or {{ hnh_preauth_outcome("'ALL LISTED SERVICES ARE APPROVED'", null_s, null_s) }} != 'Approved'
   or {{ hnh_preauth_outcome("'ACCEPT.'", null_s, null_s) }} != 'Approved'
   or {{ hnh_preauth_outcome("'APPROVED ONLY UP TO 30 DAYS'", null_s, null_s) }} != 'Approved'
   or {{ hnh_preauth_outcome("'PARTIAL'", null_s, null_s) }} != 'Partially approved'
   or {{ hnh_preauth_outcome("'NOT-REQUIRED'", null_s, null_s) }} != 'Not required'
   or {{ hnh_preauth_outcome("'REJECTED'", "'Y'", "'S'") }} != 'Rejected'
   or {{ hnh_preauth_outcome("'PENDED'", null_s, null_s) }} != 'Pended'
   or {{ hnh_preauth_outcome("'QUEUED BY NPHIES'", null_s, null_s) }} != 'Pended'
   or {{ hnh_preauth_outcome("'ERROR BY NPHIES'", null_s, null_s) }} != 'Error'
   or {{ hnh_preauth_outcome("'SOMETHING ELSE'", null_s, null_s) }} != 'Unknown'
   or {{ hnh_preauth_outcome(null_s, "'Y'", "'S'") }} != 'Approved'
   or {{ hnh_preauth_outcome(null_s, "'R'", "'S'") }} != 'Rejected'
   or {{ hnh_preauth_outcome(null_s, "'Z'", "'S'") }} != 'Not required'
   or {{ hnh_preauth_outcome(null_s, "'C'", "'S'") }} != 'Cancelled'
   or {{ hnh_preauth_outcome(null_s, "'H'", "'S'") }} != 'Pended'
   or {{ hnh_preauth_outcome(null_s, "'N'", "'S'") }} != 'Pended'
   or {{ hnh_preauth_outcome(null_s, "'N'", "'P'") }} != 'Not sent'
   or {{ hnh_preauth_outcome(null_s, null_s, "'O'") }} != 'Not sent'
   or {{ hnh_preauth_outcome(null_s, "'Q'", "'S'") }} != 'Unknown'

union all
select 'preauth outcome key wrong'
where {{ hnh_preauth_outcome_key("'Approved'") }} != 1 or {{ hnh_preauth_outcome_key("'Not sent'") }} != 8
   or {{ hnh_preauth_outcome_key("'Unknown'") }} != -1
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `python scripts/run_dbt.py test --select assert_hnh_revenue_macros`
Expected: compilation error — `'hnh_charge_status' is undefined`.

- [ ] **Step 3: Write the macros**

`macros/hnh/hnh_rules_revenue.sql`:

```sql
{# delivery_charge.cancel_flag: null is the live row; C is a cancellation; R is a superseded
   version that was credited and re-billed (its credit note equals the row). #}
{% macro hnh_charge_status(cancel_flag) -%}
multiIf({{ cancel_flag }} is null, 'Live', {{ cancel_flag }} = 'C', 'Cancelled',
        {{ cancel_flag }} = 'R', 'Superseded', 'Unknown')
{%- endmacro %}

{# Only live rows that are not package components are revenue: the package header carries the price. #}
{% macro hnh_is_recognised_revenue(cancel_flag, package_deal_flag) -%}
toUInt8({{ cancel_flag }} is null and ifNull({{ package_deal_flag }}, 'N') != 'Y')
{%- endmacro %}

{% macro hnh_is_medication(product_category_code, delivery_entity_type) -%}
toUInt8(ifNull({{ product_category_code }}, '') in ('MD', 'MED', 'PH', 'CSM', 'RTL', 'MLK')
        or ifNull({{ delivery_entity_type }}, '') = 'P')
{%- endmacro %}

{# Who a charge row is billed to. A patient-paid row (bill-to 2 or 3) on a delivery line that also
   has a live purchaser row is the co-pay: 8888 Deductible. Otherwise the row's purchaser; none is 9999 Cash. #}
{% macro hnh_billed_purchaser(bill_to, purchaser_code, has_purchaser_sibling) -%}
toInt64(if(ifNull({{ bill_to }}, '') != '1' and {{ has_purchaser_sibling }} = 1,
           8888, ifNull({{ purchaser_code }}, 9999)))
{%- endmacro %}

{# Care type of a charge: the episode's, else the charge's own attendance type. #}
{% macro hnh_charge_care_type(episode_care_type, attendance_type) -%}
if(ifNull({{ episode_care_type }}, 'Unknown') != 'Unknown', ifNull({{ episode_care_type }}, 'Unknown'),
   multiIf({{ attendance_type }} = 'I', 'IP', {{ attendance_type }} = 'O', 'OP', 'Unknown'))
{%- endmacro %}

{# Pre-authorisation outcome. The NPHIES status (upper-cased) wins when present; otherwise the
   Oasis line: request status S/P with authorised flag Y/R/Z/C/H, S+N is sent and awaiting. #}
{% macro hnh_preauth_outcome(nphies_status, authorised_flag, request_status) -%}
multiIf(
    {{ nphies_status }} in ('ACCEPT.', 'ALL LISTED SERVICES ARE APPROVED')
        or startsWith(ifNull({{ nphies_status }}, ''), 'APPROVED'),          'Approved',
    {{ nphies_status }} = 'PARTIAL',                                         'Partially approved',
    {{ nphies_status }} = 'NOT-REQUIRED',                                    'Not required',
    {{ nphies_status }} = 'REJECTED',                                        'Rejected',
    {{ nphies_status }} in ('PENDED', 'QUEUED', 'QUEUED BY NPHIES'),         'Pended',
    startsWith(ifNull({{ nphies_status }}, ''), 'ERROR'),                    'Error',
    {{ nphies_status }} is not null,                                         'Unknown',
    ifNull({{ request_status }}, '') in ('S', 'P') and {{ authorised_flag }} = 'Y', 'Approved',
    ifNull({{ request_status }}, '') in ('S', 'P') and {{ authorised_flag }} = 'R', 'Rejected',
    {{ authorised_flag }} = 'Z',                                             'Not required',
    {{ authorised_flag }} = 'C',                                             'Cancelled',
    {{ authorised_flag }} = 'H',                                             'Pended',
    ifNull({{ request_status }}, '') = 'S' and ifNull({{ authorised_flag }}, 'N') = 'N', 'Pended',
    ifNull({{ request_status }}, '') in ('O', 'P') or ifNull({{ authorised_flag }}, 'N') = 'N', 'Not sent',
    'Unknown')
{%- endmacro %}

{% macro hnh_preauth_outcome_key(expr) -%}
toInt8(multiIf({{ expr }} = 'Approved', 1, {{ expr }} = 'Partially approved', 2, {{ expr }} = 'Not required', 3,
               {{ expr }} = 'Rejected', 4, {{ expr }} = 'Pended', 5, {{ expr }} = 'Error', 6,
               {{ expr }} = 'Cancelled', 7, {{ expr }} = 'Not sent', 8, -1))
{%- endmacro %}
```

- [ ] **Step 4: Run the test**

Run: `python scripts/run_dbt.py test --select assert_hnh_revenue_macros`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/macros/hnh/hnh_rules_revenue.sql hnh_dwh/tests/hnh/assert_hnh_revenue_macros.sql
git commit -m "Add revenue and pre-authorisation rule macros"
```

---

### Task 3: Charge, document, invoice and catalogue staging

**Files:**
- Modify: `hnh_dwh/models/hnh/staging/oasis/_oasis__sources.yml`, `_oasis__models.yml`
- Create in `hnh_dwh/models/hnh/staging/oasis/`: `stg_oasis__charges.sql`, `stg_oasis__delivery_lines.sql`, `stg_oasis__master_deliveries.sql`, `stg_oasis__ar_documents.sql`, `stg_oasis__episode_invoices.sql`, `stg_oasis__invoice_statements.sql`, `stg_oasis__ios_master.sql`, `stg_oasis__policies.sql`

**Interfaces:**
- Consumes: `hnh_oasis_source`, `hnh_id`, `hnh_str`, `hnh_code`, `hnh_flag`, `hnh_ksa_wall_clock` (Phase 1).
- Produces (column names later tasks use):
  - `stg_oasis__charges`: `branch_id, delivery_charge_id, delivery_line, delivered_at, patient_id, episode_no, admission_no, encounter_id, encounter_type, staff_id, ios, purchaser_code, package_id, doc_id, invoice_doc_no, cancel_flag, cancel_reason_code, bill_to, package_deal_flag, attendance_type, product_category_code, units_delivered, price_paid_purchaser, discount_given, vat_value, updated_at`
  - `stg_oasis__delivery_lines`: `branch_id, delivery_line, master_delivery_no, order_line`
  - `stg_oasis__master_deliveries`: `branch_id, master_delivery_no, work_entity`
  - `stg_oasis__ar_documents`: `branch_id, doc_id, doc_no, doc_type, doc_at, account_code, ext_ref, ext_acc_doc_no, alloc_doc_id, total_doc_price, total_doc_disc, total_doc_tax`
  - `stg_oasis__episode_invoices`: `branch_id, invoice_no, created_at, service_start_at, service_end_at, account_code, patient_id, episode_no, attendance_type, gross_amount, discount_amount, net_amount, vat_amount, total_amount, stat_invoice_no, approval_status_code, claim_type`
  - `stg_oasis__invoice_statements`: `branch_id, stat_invoice_no, statement_end_at, statement_sent_at, approved_at, approved_by, cancelled_flag, statement_type`
  - `stg_oasis__ios_master`: `branch_id, ios, ios_main, ios_user, ios_type, ios_category, service_dept, product_category_code`
  - `stg_oasis__policies`: `branch_id, policy_code, purchaser_code, account_no, description, is_active`

- [ ] **Step 1: Declare sources and write the failing tests**

Append to the `oasis` source `tables:` in `_oasis__sources.yml` (the receiving project has an `oasis_lake` model for each, so `hnh_oasis_source_only` stays unchanged):

```yaml
      - name: delivery_charge
      - name: delivery_lines
        freshness: null
      - name: master_deliveries
        freshness: null
      - name: doc
      - name: ar_episode_invoices
      - name: ar_stat_of_invoices
        freshness: null
      - name: ios_master_data
        freshness: null
      - name: policies
        freshness: null
```

Append to `_oasis__models.yml`:

```yaml
  - name: stg_oasis__charges
    tests:
      - hnh_unique_combination:
          columns: [branch_id, delivery_charge_id]
  - name: stg_oasis__delivery_lines
    tests:
      - hnh_unique_combination:
          columns: [branch_id, delivery_line]
  - name: stg_oasis__master_deliveries
    tests:
      - hnh_unique_combination:
          columns: [branch_id, master_delivery_no]
  - name: stg_oasis__ar_documents
    tests:
      - hnh_unique_combination:
          columns: [branch_id, doc_id]
    columns:
      - name: doc_type
        tests:
          - accepted_values:
              values: ['INVOICEAR', 'CREDITAR', 'DEBITAR', 'RECEIPT']
  - name: stg_oasis__episode_invoices
    tests:
      - hnh_unique_combination:
          columns: [branch_id, invoice_no]
  - name: stg_oasis__invoice_statements
    tests:
      - hnh_unique_combination:
          columns: [branch_id, stat_invoice_no]
  - name: stg_oasis__ios_master
    tests:
      - hnh_unique_combination:
          columns: [branch_id, ios]
  - name: stg_oasis__policies
    tests:
      - hnh_unique_combination:
          columns: [branch_id, policy_code]
```

Run: `python scripts/run_dbt.py build --select stg_oasis__charges stg_oasis__delivery_lines stg_oasis__master_deliveries stg_oasis__ar_documents stg_oasis__episode_invoices stg_oasis__invoice_statements stg_oasis__ios_master stg_oasis__policies`
Expected: FAIL — models do not exist.

- [ ] **Step 2: Write the charge staging views**

`stg_oasis__charges.sql` (card numbers are not selected):

```sql
select
    toUInt8(branch_id)                          as branch_id,
    toInt64(delivery_charge_id)                 as delivery_charge_id,
    {{ hnh_id('delivery_line') }}               as delivery_line,
    {{ hnh_ksa_wall_clock('delivery_date') }}   as delivered_at,
    {{ hnh_id('patient_id') }}                  as patient_id,
    {{ hnh_id('episode_no') }}                  as episode_no,
    {{ hnh_id('admission_no') }}                as admission_no,
    {{ hnh_id('encounter_id') }}                as encounter_id,
    {{ hnh_code('encounter_type') }}            as encounter_type,
    {{ hnh_code('staff_id') }}                  as staff_id,
    {{ hnh_id('ios') }}                         as ios,
    {{ hnh_id('purchaser_code') }}              as purchaser_code,
    {{ hnh_id('package_id') }}                  as package_id,
    {{ hnh_id('doc_id') }}                      as doc_id,
    {{ hnh_str('invoice_no') }}                 as invoice_doc_no,
    {{ hnh_code('cancel_flag') }}               as cancel_flag,
    toInt64OrNull(trimBoth(ifNull(status_reason_code, ''))) as cancel_reason_code,
    {{ hnh_code('bill_to') }}                   as bill_to,
    {{ hnh_code('package_deal_flag') }}         as package_deal_flag,
    {{ hnh_code('attendance_type') }}           as attendance_type,
    {{ hnh_code('product_category_code') }}     as product_category_code,
    toFloat64(ifNull(units_delivered, 0))       as units_delivered,
    toFloat64(ifNull(price_paid_purchaser, 0))  as price_paid_purchaser,
    toFloat64(ifNull(discount_given, 0))        as discount_given,
    toFloat64(ifNull(vat_value, 0))             as vat_value,
    recorded_updated_at                         as updated_at
from {{ hnh_oasis_source('delivery_charge') }} final
```

`stg_oasis__delivery_lines.sql`:

```sql
select
    toUInt8(branch_id)                  as branch_id,
    toInt64(delivery_line)              as delivery_line,
    {{ hnh_id('master_delivery_no') }}  as master_delivery_no,
    {{ hnh_id('order_line') }}          as order_line
from {{ hnh_oasis_source('delivery_lines') }} final
```

`stg_oasis__master_deliveries.sql`:

```sql
select
    toUInt8(branch_id)                    as branch_id,
    toInt64(master_delivery_no)           as master_delivery_no,
    {{ hnh_id('delivery_work_entity') }}  as work_entity
from {{ hnh_oasis_source('master_deliveries') }} final
```

- [ ] **Step 3: Write the document, invoice and catalogue views**

`stg_oasis__ar_documents.sql` (the only staging row filter in the project: `doc` holds 127M GL, stock and payroll documents):

```sql
select
    toUInt8(branch_id)                       as branch_id,
    toInt64(doc_id)                          as doc_id,
    {{ hnh_str('doc_no') }}                  as doc_no,
    {{ hnh_code('doc_type') }}               as doc_type,
    {{ hnh_ksa_wall_clock('doc_date') }}     as doc_at,
    {{ hnh_code('account_code') }}           as account_code,
    {{ hnh_str('ext_ref') }}                 as ext_ref,
    {{ hnh_str('ext_acc_doc_no') }}          as ext_acc_doc_no,
    {{ hnh_id('alloc_doc_id') }}             as alloc_doc_id,
    toFloat64(ifNull(total_doc_price, 0))    as total_doc_price,
    toFloat64(ifNull(total_doc_disc, 0))     as total_doc_disc,
    toFloat64(ifNull(total_doc_tax, 0))      as total_doc_tax
from {{ hnh_oasis_source('doc') }} final
where doc_type in ('INVOICEAR', 'CREDITAR', 'DEBITAR', 'RECEIPT') and doc_status = 'P'
```

`stg_oasis__episode_invoices.sql`:

```sql
select
    toUInt8(branch_id)                                  as branch_id,
    toInt64(invoice_no)                                 as invoice_no,
    {{ hnh_ksa_wall_clock('invoice_creation_date') }}   as created_at,
    {{ hnh_ksa_wall_clock('invoice_start_date') }}      as service_start_at,
    {{ hnh_ksa_wall_clock('invoice_end_date') }}        as service_end_at,
    {{ hnh_code('account_code') }}                      as account_code,
    {{ hnh_id('patient_id') }}                          as patient_id,
    {{ hnh_id('episode_no') }}                          as episode_no,
    {{ hnh_code('attendance_type') }}                   as attendance_type,
    toFloat64(ifNull(invoice_gross, 0))                 as gross_amount,
    toFloat64(ifNull(invoice_discount, 0))              as discount_amount,
    toFloat64(ifNull(invoice_net_amount, 0))            as net_amount,
    toFloat64(ifNull(invoice_vat, 0))                   as vat_amount,
    toFloat64(ifNull(invoice_total, 0))                 as total_amount,
    {{ hnh_str('stat_invoice_no') }}                    as stat_invoice_no,
    {{ hnh_code('approval_status') }}                   as approval_status_code,
    {{ hnh_str('claim_type') }}                         as claim_type
from {{ hnh_oasis_source('ar_episode_invoices') }} final
```

`stg_oasis__invoice_statements.sql`:

```sql
select
    toUInt8(branch_id)                          as branch_id,
    assumeNotNull({{ hnh_str('stat_invoice_no') }}) as stat_invoice_no,
    {{ hnh_ksa_wall_clock('stat_end_date') }}   as statement_end_at,
    {{ hnh_ksa_wall_clock('stat_send_date') }}  as statement_sent_at,
    {{ hnh_ksa_wall_clock('approved_date') }}   as approved_at,
    {{ hnh_str('approved_by') }}                as approved_by,
    {{ hnh_code('cancelled_flag') }}            as cancelled_flag,
    {{ hnh_code('statement_type') }}            as statement_type
from {{ hnh_oasis_source('ar_stat_of_invoices') }} final
```

`stg_oasis__ios_master.sql`:

```sql
select
    toUInt8(branch_id)                       as branch_id,
    toInt64(ios)                             as ios,
    {{ hnh_id('ios_main') }}                 as ios_main,
    {{ hnh_code('ios_user') }}               as ios_user,
    {{ hnh_code('ios_type') }}               as ios_type,
    {{ hnh_code('ios_category') }}           as ios_category,
    {{ hnh_id('service_dept') }}             as service_dept,
    {{ hnh_code('product_category_code') }}  as product_category_code
from {{ hnh_oasis_source('ios_master_data') }} final
```

`stg_oasis__policies.sql`:

```sql
select
    toUInt8(branch_id)                 as branch_id,
    toInt64(policy_code)               as policy_code,
    {{ hnh_id('purchaser_code') }}     as purchaser_code,
    {{ hnh_code('account_no') }}       as account_no,
    {{ hnh_str('description') }}       as description,
    toUInt8(ifNull(toString(active_flag), 'Y') != 'N') as is_active
from {{ hnh_oasis_source('policies') }} final
```

- [ ] **Step 4: Run the tests**

Run the Step 1 command again.
Expected: PASS, 8 views and 9 tests. If a `hnh_unique_combination` fails, stop: the source's `ReplacingMergeTree` key was checked on 2026-10-04 to be exactly these columns, so a failure means the ingestion changed.

- [ ] **Step 5: Spot-check a known episode**

```bash
python - <<'EOF'
import sys; sys.path.insert(0, "scripts")
from ch_env import client
c = client()
print(c.query("""
select bill_to, ifNull(cancel_flag, '-') as cf, round(sum(price_paid_purchaser), 2)
from stg.stg_oasis__charges
where branch_id = 1 and patient_id = 902748 and episode_no = 1
group by bill_to, cf order by bill_to, cf""").result_rows)
EOF
```

Expected (measured 2026-10-04; a later re-bill of this episode moves the numbers): bill-to `1` live (`'-'`) about `5137986.15` (`1797478.92` package headers and ordinary lines plus `3340507.23` package components), and bill-to `1` `R` exactly the credit-note total `976581.77` (spec finding R1).

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/models/hnh/staging/oasis
git commit -m "Stage charges, AR documents, episode invoices and the service catalogue"
```

---

### Task 4: Pre-authorisation staging

**Files:**
- Modify: `hnh_dwh/models/hnh/staging/oasis/_oasis__sources.yml`, `_oasis__models.yml`
- Create in `hnh_dwh/models/hnh/staging/oasis/`: `stg_oasis__authorisation_requests.sql`, `stg_oasis__authorisations.sql`, `stg_oasis__preauth_api_requests.sql`, `stg_oasis__preauth_api_request_items.sql`, `stg_oasis__preauth_api_responses.sql`, `stg_oasis__preauth_api_response_items.sql`

**Interfaces:**
- Produces:
  - `stg_oasis__authorisation_requests`: `branch_id, request_no, patient_id, episode_no, requested_at, request_status, contract_no`
  - `stg_oasis__authorisations`: `branch_id, authorisation_no, request_no, patient_id, episode_no, ios, requested_qty, authorised_qty, used_qty, authorised_flag, amount_authorised, is_transfer, com_req_id`
  - `stg_oasis__preauth_api_requests`: `branch_id, api_trans_id, oasis_request_no, patient_id, episode_no, purchaser_code, service_dept, physician_staff_id, treatment_type, diagnosis_code, is_transfer, sent_at`
  - `stg_oasis__preauth_api_request_items`: `branch_id, request_item_id, api_trans_id, item_no, ios, authorisation_no, quantity, estimated_cost`
  - `stg_oasis__preauth_api_responses`: `branch_id, response_id, api_trans_id, responded_at, auth_status`
  - `stg_oasis__preauth_api_response_items`: `branch_id, response_item_id, response_id, item_no, status, approved_quantity, approved_amount, payer_comment`

- [ ] **Step 1: Declare sources and write the failing tests**

Append to the `oasis` source tables:

```yaml
      - name: authorisations_master
      - name: authorisations
        freshness: null
      - name: api_pre_approval_req
      - name: api_pre_approval_req_details
        freshness: null
      - name: api_pre_approval_res
        freshness: null
      - name: api_pre_approval_res_details
        freshness: null
```

Append to `_oasis__models.yml`:

```yaml
  - name: stg_oasis__authorisation_requests
    tests:
      - hnh_unique_combination:
          columns: [branch_id, request_no]
  - name: stg_oasis__authorisations
    tests:
      - hnh_unique_combination:
          columns: [branch_id, authorisation_no]
  - name: stg_oasis__preauth_api_requests
    tests:
      - hnh_unique_combination:
          columns: [branch_id, api_trans_id]
  - name: stg_oasis__preauth_api_request_items
    tests:
      - hnh_unique_combination:
          columns: [branch_id, request_item_id]
  - name: stg_oasis__preauth_api_responses
    tests:
      - hnh_unique_combination:
          columns: [branch_id, response_id]
  - name: stg_oasis__preauth_api_response_items
    tests:
      - hnh_unique_combination:
          columns: [branch_id, response_item_id]
```

Run: `python scripts/run_dbt.py build --select stg_oasis__authorisation_requests stg_oasis__authorisations stg_oasis__preauth_api_requests stg_oasis__preauth_api_request_items stg_oasis__preauth_api_responses stg_oasis__preauth_api_response_items`
Expected: FAIL — models do not exist.

- [ ] **Step 2: Write the Oasis authorisation views**

`stg_oasis__authorisation_requests.sql` (`1900-01-01` request dates become null through `hnh_ksa_wall_clock`):

```sql
select
    toUInt8(branch_id)                       as branch_id,
    toInt64(request_no)                      as request_no,
    {{ hnh_id('patient_id') }}               as patient_id,
    {{ hnh_id('episode_no') }}               as episode_no,
    {{ hnh_ksa_wall_clock('request_date') }} as requested_at,
    {{ hnh_code('status') }}                 as request_status,
    {{ hnh_id('contract_no') }}              as contract_no
from {{ hnh_oasis_source('authorisations_master') }} final
```

`stg_oasis__authorisations.sql`:

```sql
select
    toUInt8(branch_id)                   as branch_id,
    toInt64(authorisation_no)            as authorisation_no,
    {{ hnh_id('request_no') }}           as request_no,
    {{ hnh_id('patient_id') }}           as patient_id,
    {{ hnh_id('episode_no') }}           as episode_no,
    {{ hnh_id('ios') }}                  as ios,
    toFloat64OrNull(toString(no_requested))  as requested_qty,
    toFloat64OrNull(toString(no_authorised)) as authorised_qty,
    toFloat64OrNull(toString(no_used))       as used_qty,
    {{ hnh_code('authorised_flag') }}    as authorised_flag,
    toFloat64OrNull(toString(amount_authorised)) as amount_authorised,
    {{ hnh_flag('transfer_request') }}   as is_transfer,
    {{ hnh_str('com_req_id') }}          as com_req_id
from {{ hnh_oasis_source('authorisations') }} final
```

- [ ] **Step 3: Write the NPHIES request and response views**

`stg_oasis__preauth_api_requests.sql` (member names, mobile, identity numbers and clinical free text are not selected):

```sql
select
    toUInt8(branch_id)                       as branch_id,
    toInt64(api_trans_id)                    as api_trans_id,
    {{ hnh_id('oasis_request_no') }}         as oasis_request_no,
    {{ hnh_id('patient_id') }}               as patient_id,
    {{ hnh_id('episode_no') }}               as episode_no,
    {{ hnh_id('purchaser_code') }}           as purchaser_code,
    {{ hnh_id('service_dept') }}             as service_dept,
    {{ hnh_code('physician_staff_id') }}     as physician_staff_id,
    {{ hnh_str('treatment_type') }}          as treatment_type,
    {{ hnh_str('diagnosis_code') }}          as diagnosis_code,
    {{ hnh_flag('transfer_request') }}       as is_transfer,
    {{ hnh_ksa_wall_clock('creation_date') }} as sent_at
from {{ hnh_oasis_source('api_pre_approval_req') }} final
```

`stg_oasis__preauth_api_request_items.sql` (`estimated_cost` is text with a comma decimal separator in some rows):

```sql
select
    toUInt8(branch_id)                  as branch_id,
    toInt64(id)                         as request_item_id,
    {{ hnh_id('api_trans_id') }}        as api_trans_id,
    {{ hnh_str('item_no') }}            as item_no,
    {{ hnh_id('ios') }}                 as ios,
    {{ hnh_id('authorisation_no') }}    as authorisation_no,
    toFloat64OrNull(toString(quantity)) as quantity,
    toFloat64OrNull(replaceAll(trimBoth(ifNull(estimated_cost, '')), ',', '.')) as estimated_cost
from {{ hnh_oasis_source('api_pre_approval_req_details') }} final
```

`stg_oasis__preauth_api_responses.sql`:

```sql
select
    toUInt8(branch_id)                        as branch_id,
    toInt64(id)                               as response_id,
    {{ hnh_id('req_api_trans_id') }}          as api_trans_id,
    {{ hnh_ksa_wall_clock('creation_date') }} as responded_at,
    {{ hnh_code('auth_status') }}             as auth_status
from {{ hnh_oasis_source('api_pre_approval_res') }} final
```

`stg_oasis__preauth_api_response_items.sql`:

```sql
select
    toUInt8(branch_id)                          as branch_id,
    toInt64(id)                                 as response_item_id,
    {{ hnh_id('res_id') }}                      as response_id,
    {{ hnh_str('item_no') }}                    as item_no,
    {{ hnh_code('status') }}                    as status,
    toFloat64OrNull(toString(approved_quantity)) as approved_quantity,
    toFloat64OrNull(toString(approved_amount))   as approved_amount,
    {{ hnh_str('error_text') }}                 as payer_comment
from {{ hnh_oasis_source('api_pre_approval_res_details') }} final
```

- [ ] **Step 4: Run the tests**

Run the Step 1 command again.
Expected: PASS, 6 views and 6 tests.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/staging/oasis
git commit -m "Stage Oasis and NPHIES pre-authorisation tables"
```

---

### Task 5: Revenue dimensions

**Files:**
- Create: `hnh_dwh/models/hnh/marts/conformed/dim_service.sql`, `dim_product_category.sql`, `dim_preauth_outcome.sql`
- Modify: `hnh_dwh/models/hnh/marts/conformed/_conformed__models.yml`

**Interfaces:**
- Consumes: `stg_oasis__ios_master`, `stg_oasis__service_items` (Phase 1: `branch_id, ios_main, description, product_code, product_category_code`), `stg_ref__product_category`, `hnh_preauth_outcome_key`.
- Produces: `dim_service(service_key Int64, branch_key, ios, ios_user, service_name, ios_type, ios_category, service_dept, ios_main, product_category_code, product_group, unified_category, product_department, high_level_department)`; `dim_product_category(product_category_key Int64, branch_key, category_code, product_group, unified_category, product_department, high_level_department, is_medication_category)`; `dim_preauth_outcome(preauth_outcome_key Int8, preauth_outcome, is_approved)`. Keys are `hnh_surrogate_key(['branch_id', 'ios'])` and `hnh_surrogate_key(['branch_id', 'category_code'])`; Unknown is `-1`.

- [ ] **Step 1: Write the failing tests**

Append to `_conformed__models.yml`:

```yaml
  - name: dim_service
    columns:
      - name: service_key
        tests: [unique, not_null]
  - name: dim_product_category
    columns:
      - name: product_category_key
        tests: [unique, not_null]
  - name: dim_preauth_outcome
    columns:
      - name: preauth_outcome_key
        tests: [unique, not_null]
      - name: preauth_outcome
        tests:
          - accepted_values:
              values: ['Approved', 'Partially approved', 'Not required', 'Rejected', 'Pended', 'Error', 'Cancelled', 'Not sent', 'Unknown']
```

Run: `python scripts/run_dbt.py build --select dim_service dim_product_category dim_preauth_outcome`
Expected: FAIL — models do not exist.

- [ ] **Step 2: Write `dim_service`**

```sql
{{ config(order_by='service_key') }}

with services as (
    select
        m.branch_id      as branch_id,
        m.ios            as ios,
        m.ios_user       as ios_user,
        m.ios_type       as ios_type,
        m.ios_category   as ios_category,
        m.service_dept   as service_dept,
        m.ios_main       as ios_main,
        si.description   as service_name,
        coalesce(m.product_category_code, si.product_category_code) as product_category_code
    from {{ ref('stg_oasis__ios_master') }} as m
    left join {{ ref('stg_oasis__service_items') }} as si
        on si.branch_id = m.branch_id and si.ios_main = m.ios_main
)

select * from (
select
    {{ hnh_surrogate_key(['s.branch_id', 's.ios']) }} as service_key,
    s.branch_id                                       as branch_key,
    toNullable(s.ios)                                 as ios,
    s.ios_user                                        as ios_user,
    ifNull(s.service_name, 'Unknown')                 as service_name,
    s.ios_type                                        as ios_type,
    s.ios_category                                    as ios_category,
    s.service_dept                                    as service_dept,
    s.ios_main                                        as ios_main,
    s.product_category_code                           as product_category_code,
    ifNull(pc.group_name, 'Not Mapped')               as product_group,
    ifNull(pc.unified_category, 'Not Mapped')         as unified_category,
    ifNull(pc.department, 'Not Mapped')               as product_department,
    ifNull(pc.high_level_department, 'Not Mapped')    as high_level_department
from services as s
left join {{ ref('stg_ref__product_category') }} as pc
    on pc.branch_id = s.branch_id and pc.category_code = s.product_category_code

union all

select toInt64(-1), toUInt8(0), null, null, 'Unknown', null, null, null, null, null,
       'Unknown', 'Unknown', 'Unknown', 'Unknown'
)
{{ hnh_settings() }}
```

- [ ] **Step 3: Write `dim_product_category` and `dim_preauth_outcome`**

`dim_product_category.sql`:

```sql
{{ config(order_by='product_category_key') }}

with codes as (
    select distinct branch_id, category_code from (
        select branch_id, category_code from {{ ref('stg_ref__product_category') }}
        union all
        select branch_id, assumeNotNull(product_category_code) from {{ ref('stg_oasis__ios_master') }}
        where product_category_code is not null
        union all
        select branch_id, assumeNotNull(product_category_code) from {{ ref('stg_oasis__service_items') }}
        where product_category_code is not null
    )
)

select * from (
select
    {{ hnh_surrogate_key(['c.branch_id', 'c.category_code']) }} as product_category_key,
    c.branch_id                                      as branch_key,
    toNullable(c.category_code)                      as category_code,
    ifNull(pc.group_name, 'Not Mapped')              as product_group,
    ifNull(pc.unified_category, 'Not Mapped')        as unified_category,
    ifNull(pc.department, 'Not Mapped')              as product_department,
    ifNull(pc.high_level_department, 'Not Mapped')   as high_level_department,
    {{ hnh_is_medication('c.category_code', "cast(null as Nullable(String))") }} as is_medication_category
from codes as c
left join {{ ref('stg_ref__product_category') }} as pc
    on pc.branch_id = c.branch_id and pc.category_code = c.category_code

union all

select toInt64(-1), toUInt8(0), null, 'Unknown', 'Unknown', 'Unknown', 'Unknown', toUInt8(0)
)
{{ hnh_settings() }}
```

`dim_preauth_outcome.sql`:

```sql
{{ config(order_by='preauth_outcome_key') }}

select {{ hnh_preauth_outcome_key('o') }} as preauth_outcome_key, o as preauth_outcome,
       toUInt8(o in ('Approved', 'Partially approved', 'Not required')) as is_approved
from (select arrayJoin(['Approved', 'Partially approved', 'Not required', 'Rejected', 'Pended',
                        'Error', 'Cancelled', 'Not sent', 'Unknown']) as o)
```

- [ ] **Step 4: Run the tests**

Run the Step 1 command again.
Expected: PASS, 3 models and 6 tests.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/marts/conformed
git commit -m "Add service, product category and pre-authorisation outcome dimensions"
```

---

### Task 6: Charge line fact

**Files:**
- Create: `hnh_dwh/models/hnh/marts/revenue/fact_charge_line.sql`
- Create: `hnh_dwh/models/hnh/marts/revenue/_revenue_marts__models.yml`, `_revenue_marts_unit_tests.yml`
- Test: `hnh_dwh/tests/hnh/assert_fact_charge_line_matches_staging.sql`

**Interfaces:**
- Consumes: Task 2 macros; Task 3 staging; `int_episode(branch_id, patient_id, episode_no, care_type, purchaser_code)`; `int_admission(branch_id, admission_no, is_ltc, is_ltc_to_date)`; `dim_patient(patient_key)`, `dim_staff(staff_key)`, `hnh_dim_department(department_key, entity_type)`, `dim_service(service_key)`, `dim_product_category(product_category_key)`, `dim_payer(payer_key, creditor)`.
- Produces `gold.fact_charge_line` columns used later: `charge_line_key, branch_key, delivery_date_key, episode_key, patient_key, service_key, billed_payer_key, care_type_key, invoice_doc_no, charge_status, is_recognised_revenue, is_claimable, is_patient_share, is_cash_billed, is_medication, net_amount, gross_amount, line_discount_amount, vat_amount, revenue_amount, claimable_amount, package_content_amount, legacy_revenue_amount`. `episode_key = hnh_surrogate_key(['branch_id','patient_id','episode_no'])` (same as Phase 1); `service_key` is dimension-checked (`-1` when unknown).

- [ ] **Step 1: Write the failing unit test**

`_revenue_marts_unit_tests.yml`:

```yaml
version: 2

unit_tests:
  - name: fact_charge_line_applies_billing_rules
    description: >
      Line 10 (outpatient): purchaser row, co-pay on bill-to 3, and a superseded R row that must be dropped.
      Line 20 (inpatient): purchaser row and co-pay on bill-to 2. Line 30: pure cash. Line 40: a package
      component (not revenue). Line 50: a cancelled row. Line 60: a patient row whose purchaser row is
      superseded, so it is pure cash, not a co-pay.
    model: fact_charge_line
    overrides:
      macros:
        is_incremental: false
    given:
      - input: ref('stg_oasis__charges')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(id) as delivery_charge_id, toNullable(toInt64(line)) as delivery_line,
                 toNullable(toDateTime('2026-06-01 10:00:00', 'Asia/Riyadh')) as delivered_at,
                 toNullable(toInt64(patient)) as patient_id, toNullable(toInt64(1)) as episode_no,
                 cast(null as Nullable(Int64)) as admission_no, cast(null as Nullable(Int64)) as encounter_id,
                 cast(null as Nullable(String)) as encounter_type, cast(null as Nullable(String)) as staff_id,
                 toNullable(toInt64(500)) as ios,
                 if(purchaser = 0, cast(null as Nullable(Int64)), toNullable(toInt64(purchaser))) as purchaser_code,
                 cast(null as Nullable(Int64)) as package_id, toNullable(toInt64(77)) as doc_id,
                 toNullable('CRD1') as invoice_doc_no,
                 if(cf = '', cast(null as Nullable(String)), toNullable(cf)) as cancel_flag,
                 cast(null as Nullable(Int64)) as cancel_reason_code,
                 toNullable(bill_to) as bill_to,
                 if(pkg = '', cast(null as Nullable(String)), toNullable(pkg)) as package_deal_flag,
                 toNullable(att) as attendance_type, toNullable('LAB') as product_category_code,
                 toFloat64(1) as units_delivered, toFloat64(price) as price_paid_purchaser,
                 toFloat64(disc) as discount_given, toFloat64(0) as vat_value,
                 toDateTime64('2026-06-02 00:00:00', 6, 'UTC') as updated_at
          from values('id UInt32, line UInt32, patient UInt32, bill_to String, cf String, pkg String, purchaser UInt32, att String, price Float64, disc Float64',
              (1, 10, 100, '1', '',  '',  300, 'O', 80,  20),
              (2, 10, 100, '3', '',  '',  0,   'O', 20,  0),
              (3, 10, 100, '1', 'R', '',  300, 'O', 80,  20),
              (4, 20, 200, '1', '',  '',  300, 'I', 500, 0),
              (5, 20, 200, '2', '',  '',  300, 'I', 50,  0),
              (6, 30, 100, '3', '',  '',  0,   'O', 40,  0),
              (7, 40, 200, '1', '',  'Y', 300, 'I', 70,  0),
              (8, 50, 200, '1', 'C', '',  300, 'I', 60,  0),
              (9, 60, 100, '1', 'R', '',  300, 'O', 90,  0),
              (10, 60, 100, '3', '', '',  0,   'O', 15,  0))
      - input: ref('stg_oasis__delivery_lines')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(-1) as delivery_line, toNullable(toInt64(-1)) as master_delivery_no
      - input: ref('stg_oasis__master_deliveries')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(-1) as master_delivery_no, cast(null as Nullable(Int64)) as work_entity
      - input: ref('int_episode')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(100) as patient_id, toInt64(1) as episode_no,
                 'OP' as care_type, toInt64(300) as purchaser_code
          union all
          select toUInt8(1), toInt64(200), toInt64(1), 'IP', toInt64(300)
      - input: ref('int_admission')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(-5) as admission_no, toUInt8(0) as is_ltc, toUInt8(0) as is_ltc_to_date
      - input: ref('dim_patient')
        format: sql
        rows: |
          select toInt64(-1) as patient_key
      - input: ref('dim_staff')
        format: sql
        rows: |
          select toInt64(-1) as staff_key
      - input: ref('hnh_dim_department')
        format: sql
        rows: |
          select toInt64(-1) as department_key, cast(null as Nullable(String)) as entity_type
      - input: ref('dim_service')
        format: sql
        rows: |
          select toInt64(-1) as service_key
      - input: ref('dim_product_category')
        format: sql
        rows: |
          select toInt64(-1) as product_category_key
      - input: ref('dim_payer')
        format: sql
        rows: |
          select toInt64(-1) as payer_key, 'Unknown' as creditor
    expect:
      rows:
        - {delivery_charge_id: 1,  charge_status: Live,      billed_purchaser_code: 300,  is_patient_share: 0, is_cash_billed: 0, is_recognised_revenue: 1, revenue_amount: 80,  gross_amount: 100, package_content_amount: 0,  is_claimable: 1, care_type_key: 1, legacy_trans_purchaser: 300,  legacy_patient_purchaser: 300}
        - {delivery_charge_id: 2,  charge_status: Live,      billed_purchaser_code: 8888, is_patient_share: 1, is_cash_billed: 0, is_recognised_revenue: 1, revenue_amount: 20,  gross_amount: 20,  package_content_amount: 0,  is_claimable: 0, care_type_key: 1, legacy_trans_purchaser: 8888, legacy_patient_purchaser: 300}
        - {delivery_charge_id: 4,  charge_status: Live,      billed_purchaser_code: 300,  is_patient_share: 0, is_cash_billed: 0, is_recognised_revenue: 1, revenue_amount: 500, gross_amount: 500, package_content_amount: 0,  is_claimable: 1, care_type_key: 3, legacy_trans_purchaser: 300,  legacy_patient_purchaser: 300}
        - {delivery_charge_id: 5,  charge_status: Live,      billed_purchaser_code: 8888, is_patient_share: 1, is_cash_billed: 0, is_recognised_revenue: 1, revenue_amount: 50,  gross_amount: 50,  package_content_amount: 0,  is_claimable: 0, care_type_key: 3, legacy_trans_purchaser: 8888, legacy_patient_purchaser: 300}
        - {delivery_charge_id: 6,  charge_status: Live,      billed_purchaser_code: 9999, is_patient_share: 0, is_cash_billed: 1, is_recognised_revenue: 1, revenue_amount: 40,  gross_amount: 40,  package_content_amount: 0,  is_claimable: 0, care_type_key: 1, legacy_trans_purchaser: 9999, legacy_patient_purchaser: 9999}
        - {delivery_charge_id: 7,  charge_status: Live,      billed_purchaser_code: 300,  is_patient_share: 0, is_cash_billed: 0, is_recognised_revenue: 0, revenue_amount: 0,   gross_amount: 70,  package_content_amount: 70, is_claimable: 0, care_type_key: 3, legacy_trans_purchaser: 300,  legacy_patient_purchaser: 300}
        - {delivery_charge_id: 8,  charge_status: Cancelled, billed_purchaser_code: 300,  is_patient_share: 0, is_cash_billed: 0, is_recognised_revenue: 0, revenue_amount: 0,   gross_amount: 60,  package_content_amount: 0,  is_claimable: 0, care_type_key: 3, legacy_trans_purchaser: 300,  legacy_patient_purchaser: 300}
        - {delivery_charge_id: 10, charge_status: Live,      billed_purchaser_code: 9999, is_patient_share: 0, is_cash_billed: 1, is_recognised_revenue: 1, revenue_amount: 15,  gross_amount: 15,  package_content_amount: 0,  is_claimable: 0, care_type_key: 1, legacy_trans_purchaser: 9999, legacy_patient_purchaser: 9999}
```

Run: `python scripts/run_dbt.py test --select "fact_charge_line,test_type:unit"`
Expected: FAIL — `fact_charge_line` does not exist.

- [ ] **Step 2: Write `fact_charge_line`**

```sql
{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['branch_key', 'delivery_date_key'],
    order_by='(branch_key, delivery_date_key, charge_line_key)'
) }}

{% set first_at = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with charges as (
    select
        branch_id, delivery_charge_id, delivery_line, delivered_at,
        assumeNotNull(toDate(delivered_at)) as delivery_day,
        patient_id, episode_no, admission_no, encounter_id, encounter_type, staff_id, ios, purchaser_code,
        package_id, doc_id, invoice_doc_no, cancel_flag, cancel_reason_code, bill_to, package_deal_flag,
        attendance_type, product_category_code, units_delivered, price_paid_purchaser, discount_given,
        vat_value, updated_at
    from {{ ref('stg_oasis__charges') }}
    where delivered_at >= {{ first_at }} and toDate(delivered_at) <= {{ last_day }}
),

{% if is_incremental() %}
changed_days as (
    -- Rebuild whole days. A re-bill updates the old row (now R), so the old day is rebuilt too.
    select distinct branch_id, delivery_day
    from charges
    where updated_at > (select max(_loaded_at) - toIntervalDay(1) from {{ this }})
),
{% endif %}

in_scope as (
    select c.*
    from charges as c
    {% if is_incremental() %}
    inner join changed_days as d on d.branch_id = c.branch_id and d.delivery_day = c.delivery_day
    {% endif %}
),

purchaser_lines as (
    -- Delivery lines with a live row billed to a purchaser. A patient-paid row on such a line is the
    -- co-pay (bill-to 3 for outpatients, 2 for inpatients). A delivery line never spans two dates
    -- (spec finding R8), so one day batch always holds both rows.
    select branch_id, delivery_line, min(purchaser_code) as sibling_purchaser_code
    from in_scope
    where cancel_flag is null and bill_to = '1' and delivery_line is not null
    group by branch_id, delivery_line
),

lines as (
    select
        c.branch_id                 as branch_id,
        c.delivery_charge_id        as delivery_charge_id,
        c.delivery_line             as delivery_line,
        c.delivered_at              as delivered_at,
        c.delivery_day              as delivery_day,
        c.patient_id                as patient_id,
        c.episode_no                as episode_no,
        c.admission_no              as admission_no,
        c.encounter_id              as encounter_id,
        c.encounter_type            as encounter_type,
        c.staff_id                  as staff_id,
        c.ios                       as ios,
        c.purchaser_code            as purchaser_code,
        c.package_id                as package_id,
        c.doc_id                    as doc_id,
        c.invoice_doc_no            as invoice_doc_no,
        c.cancel_flag               as cancel_flag,
        c.cancel_reason_code        as cancel_reason_code,
        c.bill_to                   as bill_to,
        c.package_deal_flag         as package_deal_flag,
        c.attendance_type           as attendance_type,
        c.product_category_code     as product_category_code,
        c.units_delivered           as units_delivered,
        c.price_paid_purchaser      as price_paid_purchaser,
        c.discount_given            as discount_given,
        c.vat_value                 as vat_value,
        toUInt8(pl.delivery_line is not null) as has_purchaser_sibling,
        pl.sibling_purchaser_code   as sibling_purchaser_code,
        md.work_entity              as work_entity
    from in_scope as c
    left join purchaser_lines as pl
        on pl.branch_id = c.branch_id and pl.delivery_line = c.delivery_line
    left join (
        select branch_id, delivery_line, master_delivery_no from {{ ref('stg_oasis__delivery_lines') }}
        {% if is_incremental() %}
        where (branch_id, delivery_line) in (select branch_id, delivery_line from in_scope where delivery_line is not null)
        {% endif %}
    ) as dl on dl.branch_id = c.branch_id and dl.delivery_line = c.delivery_line
    left join {{ ref('stg_oasis__master_deliveries') }} as md
        on md.branch_id = dl.branch_id and md.master_delivery_no = dl.master_delivery_no
    where c.cancel_flag is null or c.cancel_flag = 'C'
),

keyed as (
    select
        l.*,
        ep.care_type                                              as episode_care_type,
        ifNull(ep.purchaser_code, toInt64(9999))                  as episode_purchaser_code,
        toUInt8(ifNull(ad.is_ltc, 0) = 1 or ifNull(ad.is_ltc_to_date, 0) = 1) as is_ltc,
        {{ hnh_charge_care_type('ep.care_type', 'l.attendance_type') }}       as care_type,
        {{ hnh_billed_purchaser('l.bill_to', 'l.purchaser_code', 'l.has_purchaser_sibling') }} as billed_purchaser_code,
        {{ hnh_surrogate_key(['l.branch_id', 'l.delivery_charge_id']) }}      as charge_line_key,
        {{ hnh_surrogate_key(['l.branch_id', 'l.patient_id', 'l.episode_no']) }} as episode_key,
        {{ hnh_surrogate_key(['l.branch_id', 'l.admission_no']) }}            as admission_key,
        {{ hnh_surrogate_key(['l.branch_id', 'l.patient_id']) }}              as patient_key_raw,
        {{ hnh_surrogate_key(['l.branch_id', 'l.staff_id']) }}                as staff_key_raw,
        {{ hnh_surrogate_key(['l.branch_id', 'l.work_entity']) }}             as department_key_raw,
        {{ hnh_surrogate_key(['l.branch_id', 'l.ios']) }}                     as service_key_raw,
        {{ hnh_surrogate_key(['l.branch_id', 'l.product_category_code']) }}   as product_category_key_raw
    from lines as l
    left join (select branch_id, patient_id, episode_no, care_type, purchaser_code from {{ ref('int_episode') }}) as ep
        on ep.branch_id = l.branch_id and ep.patient_id = l.patient_id and ep.episode_no = l.episode_no
    left join (select branch_id, admission_no, is_ltc, is_ltc_to_date from {{ ref('int_admission') }}) as ad
        on ad.branch_id = l.branch_id and ad.admission_no = l.admission_no
),

with_payers as (
    select
        k.*,
        {{ hnh_surrogate_key(['k.branch_id', 'k.billed_purchaser_code']) }}  as billed_payer_key_raw,
        {{ hnh_surrogate_key(['k.branch_id', 'k.episode_purchaser_code']) }} as episode_payer_key_raw
    from keyed as k
)

select
    w.charge_line_key                                   as charge_line_key,
    w.branch_id                                         as branch_key,
    toInt32(toYYYYMMDD(w.delivery_day))                 as delivery_date_key,
    {{ hnh_time_key('w.delivered_at') }}                as delivery_time_key,
    w.episode_key                                       as episode_key,
    w.admission_key                                     as admission_key,
    ifNull(dp.patient_key, toInt64(-1))                 as patient_key,
    ifNull(ds.staff_key, toInt64(-1))                   as staff_key,
    ifNull(dd.department_key, toInt64(-1))              as department_key,
    ifNull(dsv.service_key, toInt64(-1))                as service_key,
    ifNull(dpc.product_category_key, toInt64(-1))       as product_category_key,
    ifNull(dbp.payer_key, toInt64(-1))                  as billed_payer_key,
    ifNull(dep.payer_key, toInt64(-1))                  as episode_payer_key,
    {{ hnh_care_type_key('w.care_type') }}              as care_type_key,
    w.delivery_charge_id                                as delivery_charge_id,
    w.delivery_line                                     as delivery_line,
    w.encounter_id                                      as encounter_id,
    w.encounter_type                                    as encounter_type,
    w.invoice_doc_no                                    as invoice_doc_no,
    w.package_id                                        as package_id,
    w.bill_to                                           as bill_to,
    w.billed_purchaser_code                             as billed_purchaser_code,
    w.episode_purchaser_code                            as episode_purchaser_code,
    {{ hnh_charge_status('w.cancel_flag') }}            as charge_status,
    w.cancel_reason_code                                as cancel_reason_code,
    toUInt8(ifNull(w.package_deal_flag, 'N') = 'Y')     as is_package_component,
    toUInt8(ifNull(w.bill_to, '') != '1' and w.has_purchaser_sibling = 1) as is_patient_share,
    toUInt8(w.bill_to = '3' and w.has_purchaser_sibling = 0)              as is_cash_billed,
    {{ hnh_is_medication('w.product_category_code', 'dd.entity_type') }}  as is_medication,
    w.is_ltc                                            as is_ltc,
    w.units_delivered                                   as units,
    w.price_paid_purchaser                              as net_amount,
    w.discount_given                                    as line_discount_amount,
    w.price_paid_purchaser + w.discount_given           as gross_amount,
    w.vat_value                                         as vat_amount,
    {{ hnh_is_recognised_revenue('w.cancel_flag', 'w.package_deal_flag') }} as is_recognised_revenue,
    if(is_recognised_revenue = 1, w.price_paid_purchaser, 0)               as revenue_amount,
    if(w.cancel_flag is null and ifNull(w.package_deal_flag, 'N') = 'Y', w.price_paid_purchaser, 0) as package_content_amount,
    toUInt8(is_recognised_revenue = 1 and w.bill_to = '1')                 as is_claimable,
    if(is_claimable = 1, w.price_paid_purchaser, 0)                        as claimable_amount,
    -- old mv_revenue_dataset: package N, cancel flag X (live), invoiced
    toUInt8(ifNull(w.package_deal_flag, 'N') = 'N' and w.cancel_flag is null and ifNull(w.doc_id, 0) != 0) as legacy_in_revenue,
    if(legacy_in_revenue = 1, w.price_paid_purchaser, 0)                   as legacy_revenue_amount,
    -- old TRANS_PURCHASER / PATIENT_PURCHASER: the co-pay is 8888 on one, the insurer on the other
    toInt64(if(ifNull(w.bill_to, '') != '1' and w.has_purchaser_sibling = 1, 8888, ifNull(w.purchaser_code, 9999))) as legacy_trans_purchaser,
    toInt64(multiIf(legacy_trans_purchaser = 9999 and dep.creditor = 'Cash Offers', w.episode_purchaser_code,
                    ifNull(w.bill_to, '') != '1' and w.has_purchaser_sibling = 1, ifNull(w.sibling_purchaser_code, 0),
                    legacy_trans_purchaser))           as legacy_patient_purchaser,
    multiIf(w.episode_care_type = 'OP', 'OP', w.episode_care_type = 'ER', 'ER', 'IP') as legacy_care_type,
    now()                                               as _loaded_at
from with_payers as w
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = w.patient_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as ds on ds.staff_key = w.staff_key_raw
left join (select department_key, entity_type from {{ ref('hnh_dim_department') }}) as dd on dd.department_key = w.department_key_raw
left join (select service_key from {{ ref('dim_service') }}) as dsv on dsv.service_key = w.service_key_raw
left join (select product_category_key from {{ ref('dim_product_category') }}) as dpc on dpc.product_category_key = w.product_category_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dbp on dbp.payer_key = w.billed_payer_key_raw
left join (select payer_key, creditor from {{ ref('dim_payer') }}) as dep on dep.payer_key = w.episode_payer_key_raw
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the unit test**

Run: `python scripts/run_dbt.py test --select "fact_charge_line,test_type:unit"`
Expected: PASS. (Row 3 and row 9 are absent because they are `R`; row 10 is pure cash because its line's only purchaser row is superseded.)

- [ ] **Step 4: Write the conservation test and the model YAML**

`tests/hnh/assert_fact_charge_line_matches_staging.sql`:

```sql
-- Every live or cancelled charge in the window is in the fact; every row left out is a superseded R row.
select 'fact_charge_line row count differs from staging' as failure, f.n as in_fact, s.n as in_staging
from (select count() as n from {{ ref('fact_charge_line') }}) as f
cross join (
    select count() as n
    from {{ ref('stg_oasis__charges') }}
    where delivered_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
      and toDate(delivered_at) <= toDate(concat(toString(toYear(today()) + 2), '-12-31'))
      and (cancel_flag is null or cancel_flag = 'C')
) as s
where f.n != s.n

union all

select 'charge rows with an unexpected cancel flag', count(), toUInt64(0)
from {{ ref('stg_oasis__charges') }}
where cancel_flag not in ('C', 'R')
having count() > 0
```

`_revenue_marts__models.yml`:

```yaml
version: 2

models:
  - name: fact_charge_line
    description: One live or cancelled Oasis charge row. Superseded (R) rows are excluded. Incremental by delivery day.
    columns:
      - name: charge_line_key
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
      - name: delivery_date_key
        tests:
          - not_null
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: patient_key
        tests:
          - relationships: {to: ref('dim_patient'), field: patient_key}
      - name: staff_key
        tests:
          - relationships: {to: ref('dim_staff'), field: staff_key}
      - name: department_key
        tests:
          - relationships: {to: ref('hnh_dim_department'), field: department_key}
      - name: service_key
        tests:
          - relationships: {to: ref('dim_service'), field: service_key}
      - name: product_category_key
        tests:
          - relationships: {to: ref('dim_product_category'), field: product_category_key}
      - name: billed_payer_key
        tests:
          - relationships: {to: ref('dim_payer'), field: payer_key}
      - name: episode_payer_key
        tests:
          - relationships: {to: ref('dim_payer'), field: payer_key}
      - name: care_type_key
        tests:
          - relationships: {to: ref('dim_care_type'), field: care_type_key}
      - name: charge_status
        tests:
          - accepted_values:
              values: ['Live', 'Cancelled']
      - name: bill_to
        tests:
          - accepted_values:
              values: ['1', '2', '3']
              config: {severity: warn}
```

- [ ] **Step 5: Build the full fact and run all its tests**

Run: `python scripts/run_dbt.py build --select fact_charge_line assert_fact_charge_line_matches_staging`
Expected: PASS. First build reads about 106M rows; allow up to 30 minutes. Then run it a second time and confirm the log line `1 of 1 OK created sql incremental model gold.fact_charge_line` finishes in minutes (incremental path).

- [ ] **Step 6: Check the billed amount against invoices**

```bash
python - <<'EOF'
import sys; sys.path.insert(0, "scripts")
from ch_env import client
c = client()
print(c.query("""
with inv as (
    select branch_id, patient_id, episode_no, sum(net_amount) as net
    from stg.stg_oasis__episode_invoices
    where branch_id = 1 and (patient_id, episode_no) in (
        select patient_id, episode_no from stg.stg_oasis__episode_invoices
        where branch_id = 1 and created_at >= '2026-05-01' and created_at < '2026-05-08' and attendance_type = 'O')
    group by branch_id, patient_id, episode_no),
ch as (
    select episode_key, sum(claimable_amount) as claimable
    from gold.fact_charge_line where branch_key = 1 group by episode_key)
select count(), countIf(abs(inv.net - ch.claimable) < 1)
from inv join ch on ch.episode_key = toInt64(bitShiftRight(cityHash64(concat(toString(inv.branch_id), '|', toString(inv.patient_id), '|', toString(inv.episode_no), '|')), 1))
""").result_rows)
EOF
```

Expected: both numbers equal (about 1,994), reproducing spec finding R5 for outpatients.

- [ ] **Step 7: Commit**

```bash
git add hnh_dwh/models/hnh/marts/revenue hnh_dwh/tests/hnh/assert_fact_charge_line_matches_staging.sql
git commit -m "Add incremental charge line fact with billed and episode payers"
```

---

### Task 7: Revenue adjustments and patient receipts

**Files:**
- Create: `hnh_dwh/models/hnh/marts/revenue/fact_revenue_adjustment.sql`, `fact_cash_receipt.sql`
- Modify: `hnh_dwh/models/hnh/marts/revenue/_revenue_marts__models.yml`, `_revenue_marts_unit_tests.yml`

**Interfaces:**
- Consumes: `stg_oasis__ar_documents`; `fact_charge_line(branch_key, invoice_doc_no, episode_key, patient_key, billed_payer_key, care_type_key, charge_status, net_amount)`; `dim_patient`.
- Produces: `fact_revenue_adjustment(adjustment_key, branch_key, adjustment_date_key, episode_key, patient_key, billed_payer_key, care_type_key, doc_id, doc_no, base_doc_no, adjustment_amount, base_invoice_net_amount, _loaded_at)`; `fact_cash_receipt(receipt_key, branch_key, receipt_date_key, receipt_time_key, patient_key, episode_key, doc_id, doc_no, receipt_type, receipt_amount, _loaded_at)`.

- [ ] **Step 1: Write the failing unit test**

Append to `_revenue_marts_unit_tests.yml` under `unit_tests:`:

```yaml
  - name: fact_revenue_adjustment_matches_discount_documents
    description: >
      CRD100D is a post-invoice discount on charge invoice CRD100. MD55D is a depreciation document and
      CRD999D has no charge invoice; neither is an adjustment. The keys come from the most frequent
      combination on the base invoice (episode 11, two lines) rather than episode 12 (one line).
    model: fact_revenue_adjustment
    given:
      - input: ref('stg_oasis__ar_documents')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(id) as doc_id, toNullable(no) as doc_no, toNullable(t) as doc_type,
                 toNullable(toDateTime('2026-06-20 12:00:00', 'Asia/Riyadh')) as doc_at, toFloat64(amt) as total_doc_price
          from values('id UInt32, no String, t String, amt Float64',
              (1, 'CRD100', 'INVOICEAR', 250), (2, 'CRD100D', 'CREDITAR', -30),
              (3, 'MD55D', 'SYSDPRC', 500), (4, 'CRD999D', 'CREDITAR', -10))
      - input: ref('fact_charge_line')
        format: sql
        rows: |
          select toUInt8(1) as branch_key, toNullable('CRD100') as invoice_doc_no, toInt64(ep) as episode_key,
                 toInt64(21) as patient_key, toInt64(31) as billed_payer_key, toInt8(1) as care_type_key,
                 'Live' as charge_status, toFloat64(net) as net_amount
          from values('ep Int64, net Float64', (11, 100), (11, 100), (12, 50))
    expect:
      rows:
        - {doc_id: 2, base_doc_no: CRD100, adjustment_amount: -30, base_invoice_net_amount: 250, episode_key: 11, patient_key: 21, billed_payer_key: 31, care_type_key: 1}
```

Run: `python scripts/run_dbt.py test --select "fact_revenue_adjustment,test_type:unit"`
Expected: FAIL — model does not exist.

- [ ] **Step 2: Write `fact_revenue_adjustment`**

```sql
{{ config(order_by='(branch_key, adjustment_date_key, adjustment_key)') }}

{% set first_at = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with credit_docs as (
    -- Post-invoice discount: a credit document numbered <charge invoice>D.
    select branch_id, doc_id, doc_no, doc_at, total_doc_price,
           substring(assumeNotNull(doc_no), 1, length(assumeNotNull(doc_no)) - 1) as base_doc_no
    from {{ ref('stg_oasis__ar_documents') }}
    where doc_type = 'CREDITAR' and endsWith(ifNull(doc_no, ''), 'D')
      and doc_at >= {{ first_at }} and toDate(doc_at) <= {{ last_day }}
),

invoice_docs as (
    select distinct branch_id, assumeNotNull(doc_no) as doc_no
    from {{ ref('stg_oasis__ar_documents') }}
    where doc_type = 'INVOICEAR' and doc_no is not null
),

base_lines as (
    select branch_key, invoice_doc_no, episode_key, patient_key, billed_payer_key, care_type_key,
           count() as n, sum(net_amount) as net
    from {{ ref('fact_charge_line') }}
    where charge_status = 'Live' and invoice_doc_no in (select base_doc_no from credit_docs)
    group by branch_key, invoice_doc_no, episode_key, patient_key, billed_payer_key, care_type_key
),

base as (
    select
        branch_key, invoice_doc_no,
        tupleElement(argMax(tuple(episode_key, patient_key, billed_payer_key, care_type_key), tuple(n, -episode_key)), 1) as episode_key,
        tupleElement(argMax(tuple(episode_key, patient_key, billed_payer_key, care_type_key), tuple(n, -episode_key)), 2) as patient_key,
        tupleElement(argMax(tuple(episode_key, patient_key, billed_payer_key, care_type_key), tuple(n, -episode_key)), 3) as billed_payer_key,
        tupleElement(argMax(tuple(episode_key, patient_key, billed_payer_key, care_type_key), tuple(n, -episode_key)), 4) as care_type_key,
        sum(net) as base_invoice_net_amount
    from base_lines
    group by branch_key, invoice_doc_no
)

select
    {{ hnh_surrogate_key(['c.branch_id', 'c.doc_id']) }}  as adjustment_key,
    c.branch_id                                          as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(c.doc_at)))         as adjustment_date_key,
    ifNull(b.episode_key, toInt64(-1))                   as episode_key,
    ifNull(b.patient_key, toInt64(-1))                   as patient_key,
    ifNull(b.billed_payer_key, toInt64(-1))              as billed_payer_key,
    toInt8(ifNull(b.care_type_key, -1))                  as care_type_key,
    c.doc_id                                             as doc_id,
    c.doc_no                                             as doc_no,
    c.base_doc_no                                        as base_doc_no,
    c.total_doc_price                                    as adjustment_amount,
    ifNull(b.base_invoice_net_amount, 0)                 as base_invoice_net_amount,
    now()                                                as _loaded_at
from credit_docs as c
inner join invoice_docs as i on i.branch_id = c.branch_id and i.doc_no = c.base_doc_no
left join base as b on b.branch_key = c.branch_id and b.invoice_doc_no = c.base_doc_no
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the unit test**

Run: `python scripts/run_dbt.py test --select "fact_revenue_adjustment,test_type:unit"`
Expected: PASS.

- [ ] **Step 4: Write `fact_cash_receipt`**

```sql
{{ config(order_by='(branch_key, receipt_date_key, receipt_key)') }}

{% set first_at = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with receipts as (
    select branch_id, doc_id, doc_no, doc_at, total_doc_price,
           toInt64OrNull(ext_ref)        as patient_id,
           toInt64OrNull(ext_acc_doc_no) as episode_no
    from {{ ref('stg_oasis__ar_documents') }}
    where doc_type = 'RECEIPT' and doc_at >= {{ first_at }} and toDate(doc_at) <= {{ last_day }}
)

select
    {{ hnh_surrogate_key(['r.branch_id', 'r.doc_id']) }}                    as receipt_key,
    r.branch_id                                                            as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(r.doc_at)))                           as receipt_date_key,
    {{ hnh_time_key('r.doc_at') }}                                         as receipt_time_key,
    ifNull(dp.patient_key, toInt64(-1))                                    as patient_key,
    {{ hnh_surrogate_key(['r.branch_id', 'r.patient_id', 'r.episode_no']) }} as episode_key,
    r.doc_id                                                               as doc_id,
    r.doc_no                                                               as doc_no,
    multiIf(startsWith(ifNull(r.doc_no, ''), 'CSH'), 'Cashier',
            startsWith(ifNull(r.doc_no, ''), 'RCT'), 'AR cash receipt', 'Other') as receipt_type,
    -r.total_doc_price                                                     as receipt_amount,
    now()                                                                  as _loaded_at
from receipts as r
left join (select patient_key from {{ ref('dim_patient') }}) as dp
    on dp.patient_key = {{ hnh_surrogate_key(['r.branch_id', 'r.patient_id']) }}
{{ hnh_settings() }}
```

- [ ] **Step 5: Add model tests and build**

Append to `_revenue_marts__models.yml` under `models:`:

```yaml
  - name: fact_revenue_adjustment
    description: Post-invoice discounts (CREDITAR documents numbered <charge invoice>D), dated on the credit date.
    columns:
      - name: adjustment_key
        tests: [unique, not_null]
      - name: adjustment_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: billed_payer_key
        tests:
          - relationships: {to: ref('dim_payer'), field: payer_key}
      - name: care_type_key
        tests:
          - relationships: {to: ref('dim_care_type'), field: care_type_key}
  - name: fact_cash_receipt
    description: Oasis patient receipts (CSH cashier, RCT AR cash). Insurer collections are Phase 3.
    columns:
      - name: receipt_key
        tests: [unique, not_null]
      - name: receipt_date_key
        tests:
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: patient_key
        tests:
          - relationships: {to: ref('dim_patient'), field: patient_key}
      - name: receipt_type
        tests:
          - accepted_values:
              values: ['Cashier', 'AR cash receipt', 'Other']
```

Run: `python scripts/run_dbt.py build --select fact_revenue_adjustment fact_cash_receipt`
Expected: PASS. Sanity check: `select branch_key, sum(adjustment_amount) from gold.fact_revenue_adjustment where adjustment_date_key between 20260601 and 20260630 group by branch_key` — branch 1 near `-50141` (spec finding R9).

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/models/hnh/marts/revenue
git commit -m "Add post-invoice discount adjustments and patient receipts"
```

---

### Task 8: Episode invoices and episode billing

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/revenue/int_invoice_payer.sql`, `_revenue__models.yml`
- Create: `hnh_dwh/models/hnh/marts/revenue/fact_invoice.sql`, `agg_episode_billing.sql`
- Modify: `hnh_dwh/models/hnh/marts/revenue/_revenue_marts__models.yml`
- Test: `hnh_dwh/tests/hnh/assert_fact_invoice_matches_staging.sql`

**Interfaces:**
- Consumes: `stg_oasis__policies`, `stg_oasis__episode_invoices`, `stg_oasis__invoice_statements`, `int_code_decode(branch_id, code_type, user_code, description)`, `stg_ref__claim_status`, `int_episode`, `dim_patient`, `dim_payer`, `fact_charge_line`.
- Produces: `int_invoice_payer(branch_id, account_code, purchaser_code, purchaser_count)`; `fact_invoice(invoice_key, branch_key, invoice_date_key, …, episode_key, patient_key, payer_key, care_type_key, account_code, net_amount, is_verified, submission_status, is_submission_status_mapped, …)`; `agg_episode_billing(branch_key, episode_key, patient_key, care_type_key, claimable_amount, invoiced_net_amount, unbilled_amount, overbilled_amount, invoice_count, first_invoice_date_key, last_invoice_date_key, is_long_stay_contract)`.

- [ ] **Step 1: Write the failing tests**

`intermediate/revenue/_revenue__models.yml`:

```yaml
version: 2

models:
  - name: int_invoice_payer
    description: Invoice account code to purchaser, through policies.account_no. Lowest policy code wins.
    tests:
      - hnh_unique_combination:
          columns: [branch_id, account_code]
```

Append to `_revenue_marts__models.yml`:

```yaml
  - name: fact_invoice
    description: One Oasis episode invoice with its statement. net_amount is what the payer is billed.
    columns:
      - name: invoice_key
        tests: [unique, not_null]
      - name: invoice_date_key
        tests:
          - not_null
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: patient_key
        tests:
          - relationships: {to: ref('dim_patient'), field: patient_key}
      - name: payer_key
        tests:
          - relationships: {to: ref('dim_payer'), field: payer_key}
      - name: care_type_key
        tests:
          - relationships: {to: ref('dim_care_type'), field: care_type_key}
      - name: submission_status
        tests:
          - accepted_values:
              values: ['New', 'Submitted', 'Cancelled', 'Error In Response', 'Failed To Submit', 'Invalid', 'Queued In Nphies', 'Under Processing']
  - name: agg_episode_billing
    description: Claimable charges against invoiced net per episode. Replaces the claims model's Not Billed.
    tests:
      - hnh_unique_combination:
          columns: [branch_key, episode_key]
```

`tests/hnh/assert_fact_invoice_matches_staging.sql`:

```sql
select 'fact_invoice row count differs from staging' as failure, f.n as in_fact, s.n as in_staging
from (select count() as n from {{ ref('fact_invoice') }}) as f
cross join (
    select count() as n from {{ ref('stg_oasis__episode_invoices') }}
    where created_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
      and toDate(created_at) <= toDate(concat(toString(toYear(today()) + 2), '-12-31'))
) as s
where f.n != s.n
```

Run: `python scripts/run_dbt.py build --select int_invoice_payer fact_invoice agg_episode_billing assert_fact_invoice_matches_staging`
Expected: FAIL — models do not exist.

- [ ] **Step 2: Write `int_invoice_payer`**

```sql
{{ config(order_by='(branch_id, account_code)') }}

select
    branch_id,
    assumeNotNull(account_no)              as account_code,
    argMin(purchaser_code, policy_code)    as purchaser_code,
    uniqExact(purchaser_code)              as purchaser_count
from {{ ref('stg_oasis__policies') }}
where account_no is not null and purchaser_code is not null
group by branch_id, account_no
```

- [ ] **Step 3: Write `fact_invoice`**

```sql
{{ config(order_by='(branch_key, invoice_date_key, invoice_key)') }}

{% set first_at = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with invoices as (
    select * from {{ ref('stg_oasis__episode_invoices') }}
    where created_at >= {{ first_at }} and toDate(created_at) <= {{ last_day }}
),

approval_codes as (
    -- Code type 5116 is matched on user_code; identical in all eight branches.
    select branch_id, assumeNotNull(user_code) as user_code, any(description) as description
    from {{ ref('int_code_decode') }}
    where code_type = 5116 and user_code is not null
    group by branch_id, user_code
),

enriched as (
    select
        i.branch_id            as branch_id,
        i.invoice_no           as invoice_no,
        i.created_at           as created_at,
        i.service_start_at     as service_start_at,
        i.service_end_at       as service_end_at,
        i.account_code         as account_code,
        i.patient_id           as patient_id,
        i.episode_no           as episode_no,
        i.attendance_type      as attendance_type,
        i.gross_amount         as gross_amount,
        i.discount_amount      as discount_amount,
        i.net_amount           as net_amount,
        i.vat_amount           as vat_amount,
        i.total_amount         as total_amount,
        i.stat_invoice_no      as stat_invoice_no,
        i.approval_status_code as approval_status_code,
        i.claim_type           as claim_type,
        s.statement_end_at     as statement_end_at,
        s.statement_sent_at    as statement_sent_at,
        s.approved_at          as statement_approved_at,
        s.approved_by          as approved_by,
        s.cancelled_flag       as cancelled_flag,
        ac.description         as approval_status,
        cs.submission_status   as submission_status,
        cs.validation_status   as validation_status,
        py.purchaser_code      as purchaser_code,
        ep.care_type           as episode_care_type
    from invoices as i
    left join {{ ref('stg_oasis__invoice_statements') }} as s
        on s.branch_id = i.branch_id and s.stat_invoice_no = i.stat_invoice_no
    left join approval_codes as ac
        on ac.branch_id = i.branch_id and ac.user_code = i.approval_status_code
    left join {{ ref('stg_ref__claim_status') }} as cs
        on lower(cs.detailed_status) = lower(ac.description)
    left join {{ ref('int_invoice_payer') }} as py
        on py.branch_id = i.branch_id and py.account_code = i.account_code
    left join (select branch_id, patient_id, episode_no, care_type from {{ ref('int_episode') }}) as ep
        on ep.branch_id = i.branch_id and ep.patient_id = i.patient_id and ep.episode_no = i.episode_no
)

select
    {{ hnh_surrogate_key(['e.branch_id', 'e.invoice_no']) }}                 as invoice_key,
    e.branch_id                                                             as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(e.created_at)))                        as invoice_date_key,
    {{ hnh_date_key_in_range('e.service_start_at') }}                       as service_start_date_key,
    {{ hnh_date_key_in_range('e.service_end_at') }}                         as service_end_date_key,
    {{ hnh_date_key_in_range('e.statement_end_at') }}                       as statement_end_date_key,
    {{ hnh_date_key_in_range('e.statement_sent_at') }}                      as statement_sent_date_key,
    {{ hnh_date_key_in_range('e.statement_approved_at') }}                  as statement_approved_date_key,
    {{ hnh_surrogate_key(['e.branch_id', 'e.patient_id', 'e.episode_no']) }} as episode_key,
    ifNull(dp.patient_key, toInt64(-1))                                     as patient_key,
    ifNull(dpy.payer_key, toInt64(-1))                                      as payer_key,
    {{ hnh_care_type_key(hnh_charge_care_type('e.episode_care_type', 'e.attendance_type')) }} as care_type_key,
    e.invoice_no                                                            as invoice_no,
    e.stat_invoice_no                                                       as stat_invoice_no,
    e.account_code                                                          as account_code,
    e.purchaser_code                                                        as purchaser_code,
    e.gross_amount                                                          as gross_amount,
    e.discount_amount                                                       as discount_amount,
    e.net_amount                                                            as net_amount,
    e.vat_amount                                                            as vat_amount,
    e.total_amount                                                          as total_amount,
    e.approval_status_code                                                  as approval_status_code,
    ifNull(e.approval_status, if(e.approval_status_code is null, 'Not set', 'Unknown')) as approval_status,
    ifNull(e.submission_status, 'New')                                      as submission_status,
    ifNull(e.validation_status, 'New')                                      as validation_status,
    toUInt8(e.approval_status_code is null or e.submission_status is not null) as is_submission_status_mapped,
    toUInt8(e.approved_by is not null)                                      as is_verified,
    toUInt8(e.statement_sent_at is not null)                                as is_sent,
    toUInt8(e.cancelled_flag = 'Y')                                         as is_cancelled_statement,
    e.claim_type                                                            as claim_type,
    toUInt8(e.approved_by is not null)                                      as legacy_is_verified,
    now()                                                                   as _loaded_at
from enriched as e
left join (select patient_key from {{ ref('dim_patient') }}) as dp
    on dp.patient_key = {{ hnh_surrogate_key(['e.branch_id', 'e.patient_id']) }}
left join (select payer_key from {{ ref('dim_payer') }}) as dpy
    on dpy.payer_key = {{ hnh_surrogate_key(['e.branch_id', 'e.purchaser_code']) }}
{{ hnh_settings() }}
```

- [ ] **Step 4: Write `agg_episode_billing`**

```sql
{{ config(order_by='(branch_key, episode_key)') }}

with charges as (
    select branch_key, episode_key, any(patient_key) as patient_key, any(care_type_key) as care_type_key,
           sum(claimable_amount) as claimable_amount
    from {{ ref('fact_charge_line') }}
    where is_claimable = 1 and episode_key != -1
    group by branch_key, episode_key
),

invoices as (
    select branch_key, episode_key, any(patient_key) as patient_key, any(care_type_key) as care_type_key,
           sum(net_amount) as invoiced_net_amount, count() as invoice_count,
           min(invoice_date_key) as first_invoice_date_key, max(invoice_date_key) as last_invoice_date_key,
           countIf(startsWith(ifNull(account_code, ''), 'DIR-')) as contract_invoices
    from {{ ref('fact_invoice') }}
    where episode_key != -1
    group by branch_key, episode_key
),

both_sides as (
    select branch_key, episode_key, patient_key, care_type_key, claimable_amount,
           toFloat64(0) as invoiced_net_amount, toUInt64(0) as invoice_count,
           cast(null as Nullable(Int32)) as first_invoice_date_key, cast(null as Nullable(Int32)) as last_invoice_date_key,
           toUInt64(0) as contract_invoices
    from charges
    union all
    select branch_key, episode_key, patient_key, care_type_key, toFloat64(0), invoiced_net_amount, invoice_count,
           toNullable(first_invoice_date_key), toNullable(last_invoice_date_key), contract_invoices
    from invoices
)

select
    branch_key,
    episode_key,
    any(patient_key)                                      as patient_key,
    any(care_type_key)                                    as care_type_key,
    sum(claimable_amount)                                 as claimable_amount,
    sum(invoiced_net_amount)                              as invoiced_net_amount,
    greatest(sum(claimable_amount) - sum(invoiced_net_amount), 0) as unbilled_amount,
    greatest(sum(invoiced_net_amount) - sum(claimable_amount), 0) as overbilled_amount,
    sum(invoice_count)                                    as invoice_count,
    min(first_invoice_date_key)                           as first_invoice_date_key,
    max(last_invoice_date_key)                            as last_invoice_date_key,
    toUInt8(sum(contract_invoices) > 0 and sum(invoice_count) > 12) as is_long_stay_contract,
    now()                                                 as _loaded_at
from both_sides
group by branch_key, episode_key
```

- [ ] **Step 5: Build and test**

Run: `python scripts/run_dbt.py build --select int_invoice_payer fact_invoice agg_episode_billing assert_fact_invoice_matches_staging`
Expected: PASS. Check the R6 episode: `select claimable_amount, invoiced_net_amount, overbilled_amount, is_long_stay_contract from gold.agg_episode_billing where branch_key = 1 and episode_key = toInt64(bitShiftRight(cityHash64('1|902748|1|'), 1))` → claimable near `1797478.92`, invoiced near `1994622.32`, `is_long_stay_contract = 1`.

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/revenue hnh_dwh/models/hnh/marts/revenue hnh_dwh/tests/hnh/assert_fact_invoice_matches_staging.sql
git commit -m "Add episode invoice fact, invoice payer lookup and episode billing aggregate"
```

---

### Task 9: Pre-authorisation intermediate

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/revenue/int_preauth_line.sql`, `_revenue_unit_tests.yml`
- Modify: `hnh_dwh/models/hnh/intermediate/revenue/_revenue__models.yml`
- Test: `hnh_dwh/tests/hnh/assert_preauth_line_conservation.sql`

**Interfaces:**
- Consumes: Task 4 staging; `hnh_preauth_outcome`.
- Produces `int_preauth_line` with exactly these columns (Task 10 passes most through): `branch_id, line_natural_id, line_source ('Oasis' | 'NPHIES only'), authorisation_no, api_trans_id, item_no, request_no, patient_id, episode_no, ios, service_dept, requesting_staff_id, purchaser_code, treatment_type, diagnosis_code, requested_at, request_status, authorised_flag, requested_qty, approved_qty, used_qty, estimated_amount, legacy_amount_authorised, is_transfer, has_communication_request, request_send_count, first_sent_at, response_count, nphies_first_status, nphies_last_status, nphies_final_status, final_responded_at, last_responded_at, nphies_approved_amount, payer_comment, preauth_outcome, legacy_line_status, is_latest_request_for_service, legacy_is_last_request`.

- [ ] **Step 1: Write the failing unit test**

`_revenue_unit_tests.yml`:

```yaml
version: 2

unit_tests:
  - name: int_preauth_line_picks_final_response_and_latest_request
    description: >
      A1 was sent twice: PENDED, then APPROVED, then a later ERROR; the final answer is APPROVED.
      A2 (another service, same episode) was never sent and is rejected in Oasis; it stays the latest
      request for its service although A3 is a later request in the episode. A3 is sent in Oasis (S+N)
      with no NPHIES answer. Item 3 has no Oasis line, so it is its own NPHIES-only line.
    model: int_preauth_line
    given:
      - input: ref('stg_oasis__authorisations')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(a) as authorisation_no, toNullable(toInt64(req)) as request_no,
                 toNullable(toInt64(100)) as patient_id, toNullable(toInt64(1)) as episode_no, toNullable(toInt64(ios)) as ios,
                 toNullable(toFloat64(2)) as requested_qty, toNullable(toFloat64(2)) as authorised_qty,
                 toNullable(toFloat64(0)) as used_qty, toNullable(flag) as authorised_flag,
                 toNullable(toFloat64(0)) as amount_authorised, toUInt8(0) as is_transfer,
                 cast(null as Nullable(String)) as com_req_id
          from values('a UInt32, req UInt32, ios UInt32, flag String', (1, 10, 500, 'Y'), (2, 11, 600, 'R'), (3, 12, 500, 'N'))
      - input: ref('stg_oasis__authorisation_requests')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(req) as request_no,
                 toNullable(toDateTime('2026-06-01 09:00:00', 'Asia/Riyadh')) as requested_at, toNullable('S') as request_status
          from values('req UInt32', (10), (11), (12))
      - input: ref('stg_oasis__preauth_api_requests')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(t) as api_trans_id, toNullable(toInt64(req)) as oasis_request_no,
                 toNullable(toInt64(p)) as patient_id, toNullable(toInt64(1)) as episode_no,
                 toNullable(toInt64(300)) as purchaser_code, cast(null as Nullable(Int64)) as service_dept,
                 cast(null as Nullable(String)) as physician_staff_id, cast(null as Nullable(String)) as treatment_type,
                 cast(null as Nullable(String)) as diagnosis_code, toUInt8(0) as is_transfer,
                 toNullable(toDateTime(sent, 'Asia/Riyadh')) as sent_at
          from values('t UInt32, req UInt32, p UInt32, sent String',
              (1001, 10, 100, '2026-06-01 09:10:00'), (1002, 10, 100, '2026-06-01 09:40:00'), (1003, 13, 200, '2026-06-01 10:00:00'))
      - input: ref('stg_oasis__preauth_api_request_items')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(id) as request_item_id, toNullable(toInt64(t)) as api_trans_id,
                 toNullable('1') as item_no, toNullable(toInt64(ios)) as ios, toNullable(toInt64(a)) as authorisation_no,
                 toNullable(toFloat64(1)) as quantity, toNullable(toFloat64(cost)) as estimated_cost
          from values('id UInt32, t UInt32, ios UInt32, a UInt32, cost Float64',
              (1, 1001, 500, 1, 200), (2, 1002, 500, 1, 200), (3, 1003, 700, 999, 50))
      - input: ref('stg_oasis__preauth_api_responses')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(r) as response_id, toNullable(toInt64(t)) as api_trans_id,
                 toNullable(toDateTime(at, 'Asia/Riyadh')) as responded_at, toNullable(st) as auth_status
          from values('r UInt32, t UInt32, at String, st String',
              (1, 1001, '2026-06-01 09:20:00', 'PENDED'), (2, 1002, '2026-06-01 09:50:00', 'APPROVED'),
              (3, 1002, '2026-06-01 10:30:00', 'ERROR BY NPHIES'), (4, 1003, '2026-06-01 10:10:00', 'REJECTED'))
      - input: ref('stg_oasis__preauth_api_response_items')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(id) as response_item_id, toNullable(toInt64(r)) as response_id,
                 toNullable('1') as item_no, toNullable(st) as status, toNullable(toFloat64(1)) as approved_quantity,
                 toNullable(toFloat64(amt)) as approved_amount, cast(null as Nullable(String)) as payer_comment
          from values('id UInt32, r UInt32, st String, amt Float64', (11, 1, 'PENDED', 0), (12, 2, 'APPROVED', 180), (14, 4, 'REJECTED', 0))
    expect:
      rows:
        - {line_natural_id: A1, line_source: Oasis, preauth_outcome: Approved, nphies_final_status: APPROVED, nphies_first_status: PENDED, nphies_last_status: ERROR BY NPHIES, response_count: 3, request_send_count: 2, nphies_approved_amount: 180, is_latest_request_for_service: 0, legacy_is_last_request: 0}
        - {line_natural_id: A2, line_source: Oasis, preauth_outcome: Rejected, nphies_final_status: null, nphies_first_status: null, nphies_last_status: null, response_count: 0, request_send_count: 0, nphies_approved_amount: null, is_latest_request_for_service: 1, legacy_is_last_request: 0}
        - {line_natural_id: A3, line_source: Oasis, preauth_outcome: Pended, nphies_final_status: null, nphies_first_status: null, nphies_last_status: null, response_count: 0, request_send_count: 0, nphies_approved_amount: null, is_latest_request_for_service: 1, legacy_is_last_request: 1}
        - {line_natural_id: N1003-1, line_source: NPHIES only, preauth_outcome: Rejected, nphies_final_status: REJECTED, nphies_first_status: REJECTED, nphies_last_status: REJECTED, response_count: 1, request_send_count: 1, nphies_approved_amount: 0, is_latest_request_for_service: 1, legacy_is_last_request: 1}
```

Run: `python scripts/run_dbt.py test --select "int_preauth_line,test_type:unit"`
Expected: FAIL — model does not exist.

- [ ] **Step 2: Write `int_preauth_line`**

```sql
{{ config(order_by='(branch_id, line_natural_id)') }}

{% set not_final = "('Pended', 'Error', 'Unknown')" %}
{% set null_s = "cast(null as Nullable(String))" %}

with oasis_lines as (
    select
        a.branch_id          as branch_id,
        a.authorisation_no   as authorisation_no,
        a.request_no         as request_no,
        a.patient_id         as patient_id,
        a.episode_no         as episode_no,
        a.ios                as ios,
        a.requested_qty      as requested_qty,
        a.authorised_qty     as authorised_qty,
        a.used_qty           as used_qty,
        a.authorised_flag    as authorised_flag,
        a.amount_authorised  as amount_authorised,
        a.is_transfer        as is_transfer,
        a.com_req_id         as com_req_id,
        r.requested_at       as requested_at,
        r.request_status     as request_status
    from {{ ref('stg_oasis__authorisations') }} as a
    left join {{ ref('stg_oasis__authorisation_requests') }} as r
        on r.branch_id = a.branch_id and r.request_no = a.request_no
),

sent_items as (
    -- Each time an item went to NPHIES. An item with a known Oasis line belongs to that line
    -- (resubmissions collect there); otherwise it is its own line.
    select
        i.branch_id            as branch_id,
        i.request_item_id      as request_item_id,
        i.api_trans_id         as api_trans_id,
        i.item_no              as item_no,
        i.ios                  as item_ios,
        i.quantity             as quantity,
        i.estimated_cost       as estimated_cost,
        q.oasis_request_no     as oasis_request_no,
        q.patient_id           as patient_id,
        q.episode_no           as episode_no,
        q.purchaser_code       as purchaser_code,
        q.service_dept         as service_dept,
        q.physician_staff_id   as physician_staff_id,
        q.treatment_type       as treatment_type,
        q.diagnosis_code       as diagnosis_code,
        q.is_transfer          as is_transfer,
        q.sent_at              as sent_at,
        if(ol.authorisation_no is not null,
           concat('A', toString(i.authorisation_no)),
           concat('N', toString(i.api_trans_id), '-', ifNull(i.item_no, ''))) as line_natural_id
    from {{ ref('stg_oasis__preauth_api_request_items') }} as i
    inner join {{ ref('stg_oasis__preauth_api_requests') }} as q
        on q.branch_id = i.branch_id and q.api_trans_id = i.api_trans_id
    left join (select branch_id, authorisation_no from {{ ref('stg_oasis__authorisations') }}) as ol
        on ol.branch_id = i.branch_id and ol.authorisation_no = i.authorisation_no
),

sends as (
    select
        branch_id, line_natural_id, latest,
        request_send_count, first_sent_at,
        tupleElement(latest, 1)  as oasis_request_no,
        tupleElement(latest, 2)  as patient_id,
        tupleElement(latest, 3)  as episode_no,
        tupleElement(latest, 4)  as item_ios,
        tupleElement(latest, 5)  as purchaser_code,
        tupleElement(latest, 6)  as service_dept,
        tupleElement(latest, 7)  as physician_staff_id,
        tupleElement(latest, 8)  as treatment_type,
        tupleElement(latest, 9)  as diagnosis_code,
        tupleElement(latest, 10) as quantity,
        tupleElement(latest, 11) as estimated_cost,
        tupleElement(latest, 12) as api_trans_id,
        tupleElement(latest, 13) as item_no,
        is_transfer
    from (
        select
            branch_id, line_natural_id,
            uniqExact(api_trans_id)  as request_send_count,
            min(sent_at)             as first_sent_at,
            max(is_transfer)         as is_transfer,
            argMax(tuple(oasis_request_no, patient_id, episode_no, item_ios, purchaser_code, service_dept,
                         physician_staff_id, treatment_type, diagnosis_code, quantity, estimated_cost,
                         api_trans_id, item_no),
                   tuple(ifNull(sent_at, toDateTime(0, 'Asia/Riyadh')), request_item_id)) as latest
        from sent_items
        group by branch_id, line_natural_id
    )
),

responses as (
    select
        s.branch_id                                    as branch_id,
        s.line_natural_id                              as line_natural_id,
        r.response_id                                  as response_id,
        r.responded_at                                 as responded_at,
        ifNull(r.responded_at, toDateTime(0, 'Asia/Riyadh')) as responded_sort,
        coalesce(ri.status, r.auth_status)             as nphies_status,
        ri.approved_amount                             as approved_amount,
        ri.approved_quantity                           as approved_quantity,
        ri.payer_comment                               as payer_comment
    from sent_items as s
    inner join {{ ref('stg_oasis__preauth_api_responses') }} as r
        on r.branch_id = s.branch_id and r.api_trans_id = s.api_trans_id
    left join {{ ref('stg_oasis__preauth_api_response_items') }} as ri
        on ri.branch_id = r.branch_id and ri.response_id = r.response_id and ri.item_no = s.item_no
),

response_summary as (
    select
        branch_id, line_natural_id, response_count, nphies_first_status, nphies_last_status, last_responded_at,
        tupleElement(final_answer, 1) as nphies_final_status,
        tupleElement(final_answer, 2) as final_responded_at,
        tupleElement(final_answer, 3) as nphies_approved_amount,
        tupleElement(final_answer, 4) as nphies_approved_quantity,
        tupleElement(final_answer, 5) as payer_comment
    from (
        select
            branch_id, line_natural_id,
            count()                                                        as response_count,
            argMin(nphies_status, tuple(responded_sort, response_id))      as nphies_first_status,
            argMax(nphies_status, tuple(responded_sort, response_id))      as nphies_last_status,
            max(responded_at)                                              as last_responded_at,
            -- final answer: the latest that is not pended, queued or an error; else the latest of any kind
            argMax(tuple(nphies_status, responded_at, approved_amount, approved_quantity, payer_comment),
                   tuple(toUInt8({{ hnh_preauth_outcome('nphies_status', null_s, null_s) }} not in {{ not_final }}),
                         responded_sort, response_id))                      as final_answer
        from responses
        group by branch_id, line_natural_id
    )
),

all_lines as (
    select
        ol.branch_id                                     as branch_id,
        concat('A', toString(ol.authorisation_no))       as line_natural_id,
        'Oasis'                                          as line_source,
        toNullable(ol.authorisation_no)                  as authorisation_no,
        cast(null as Nullable(Int64))                    as api_trans_id,
        cast(null as Nullable(String))                   as item_no,
        ol.request_no                                    as request_no,
        coalesce(ol.patient_id, s.patient_id)            as patient_id,
        coalesce(ol.episode_no, s.episode_no)            as episode_no,
        coalesce(ol.ios, s.item_ios)                     as ios,
        s.service_dept                                   as service_dept,
        s.physician_staff_id                             as requesting_staff_id,
        s.purchaser_code                                 as purchaser_code,
        s.treatment_type                                 as treatment_type,
        s.diagnosis_code                                 as diagnosis_code,
        ol.requested_at                                  as requested_at,
        ol.request_status                                as request_status,
        ol.authorised_flag                               as authorised_flag,
        ol.requested_qty                                 as requested_qty,
        ol.authorised_qty                                as oasis_approved_qty,
        ol.used_qty                                      as used_qty,
        s.estimated_cost                                 as estimated_amount,
        ol.amount_authorised                             as legacy_amount_authorised,
        toUInt8(ol.is_transfer = 1 or ifNull(s.is_transfer, 0) = 1) as is_transfer,
        toUInt8(ol.com_req_id is not null)               as has_communication_request,
        toUInt64(ifNull(s.request_send_count, 0))        as request_send_count,
        s.first_sent_at                                  as first_sent_at
    from oasis_lines as ol
    left join sends as s
        on s.branch_id = ol.branch_id and s.line_natural_id = concat('A', toString(ol.authorisation_no))

    union all

    select
        s.branch_id, s.line_natural_id, 'NPHIES only', cast(null as Nullable(Int64)),
        toNullable(s.api_trans_id), s.item_no, s.oasis_request_no, s.patient_id, s.episode_no, s.item_ios,
        s.service_dept, s.physician_staff_id, s.purchaser_code, s.treatment_type, s.diagnosis_code,
        s.first_sent_at, cast(null as Nullable(String)), cast(null as Nullable(String)),
        s.quantity, cast(null as Nullable(Float64)), cast(null as Nullable(Float64)), s.estimated_cost,
        cast(null as Nullable(Float64)), toUInt8(s.is_transfer), toUInt8(0),
        toUInt64(s.request_send_count), s.first_sent_at
    from sends as s
    where startsWith(s.line_natural_id, 'N')
)

select
    l.branch_id                                          as branch_id,
    l.line_natural_id                                    as line_natural_id,
    l.line_source                                        as line_source,
    l.authorisation_no                                   as authorisation_no,
    l.api_trans_id                                       as api_trans_id,
    l.item_no                                            as item_no,
    l.request_no                                         as request_no,
    l.patient_id                                         as patient_id,
    l.episode_no                                         as episode_no,
    l.ios                                                as ios,
    l.service_dept                                       as service_dept,
    l.requesting_staff_id                                as requesting_staff_id,
    l.purchaser_code                                     as purchaser_code,
    l.treatment_type                                     as treatment_type,
    l.diagnosis_code                                     as diagnosis_code,
    l.requested_at                                       as requested_at,
    l.request_status                                     as request_status,
    l.authorised_flag                                    as authorised_flag,
    l.requested_qty                                      as requested_qty,
    coalesce(l.oasis_approved_qty, rs.nphies_approved_quantity) as approved_qty,
    l.used_qty                                           as used_qty,
    l.estimated_amount                                   as estimated_amount,
    l.legacy_amount_authorised                           as legacy_amount_authorised,
    l.is_transfer                                        as is_transfer,
    l.has_communication_request                          as has_communication_request,
    l.request_send_count                                 as request_send_count,
    l.first_sent_at                                      as first_sent_at,
    toUInt64(ifNull(rs.response_count, 0))               as response_count,
    rs.nphies_first_status                               as nphies_first_status,
    rs.nphies_last_status                                as nphies_last_status,
    rs.nphies_final_status                               as nphies_final_status,
    rs.final_responded_at                                as final_responded_at,
    rs.last_responded_at                                 as last_responded_at,
    rs.nphies_approved_amount                            as nphies_approved_amount,
    rs.payer_comment                                     as payer_comment,
    {{ hnh_preauth_outcome('rs.nphies_final_status', 'l.authorised_flag', 'l.request_status') }} as preauth_outcome,
    multiIf(l.request_status = 'S' and l.authorised_flag = 'Y', 'Approved',
            l.request_status = 'S' and l.authorised_flag = 'H', 'Hold',
            l.request_status = 'S' and l.authorised_flag = 'N', 'Sent',
            l.request_status = 'S' and l.authorised_flag = 'R', 'Rejected',
            l.request_status = 'P' and l.authorised_flag = 'N', 'Posted',
            l.request_status = 'O' and l.authorised_flag = 'N', 'Opened', null) as legacy_line_status,
    toUInt8(ifNull(l.request_no, 0) = max(ifNull(l.request_no, 0))
            over (partition by l.branch_id, l.patient_id, l.episode_no, l.ios))  as is_latest_request_for_service,
    toUInt8(ifNull(l.request_no, 0) = max(ifNull(l.request_no, 0))
            over (partition by l.branch_id, l.patient_id, l.episode_no))         as legacy_is_last_request
from all_lines as l
left join response_summary as rs
    on rs.branch_id = l.branch_id and rs.line_natural_id = l.line_natural_id
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the unit test**

Run: `python scripts/run_dbt.py test --select "int_preauth_line,test_type:unit"`
Expected: PASS.

- [ ] **Step 4: Write the conservation test and model YAML**

`tests/hnh/assert_preauth_line_conservation.sql`:

```sql
-- Every Oasis authorisation line is one row; no line is duplicated.
select 'Oasis authorisation lines differ from staging' as failure, i.n as in_int, s.n as in_staging
from (select count() as n from {{ ref('int_preauth_line') }} where line_source = 'Oasis') as i
cross join (select count() as n from {{ ref('stg_oasis__authorisations') }}) as s
where i.n != s.n
```

Append to `intermediate/revenue/_revenue__models.yml`:

```yaml
  - name: int_preauth_line
    description: One Oasis authorisation line, or one NPHIES item without an Oasis line, with its final NPHIES answer.
    tests:
      - hnh_unique_combination:
          columns: [branch_id, line_natural_id]
    columns:
      - name: preauth_outcome
        tests:
          - accepted_values:
              values: ['Approved', 'Partially approved', 'Not required', 'Rejected', 'Pended', 'Error', 'Cancelled', 'Not sent', 'Unknown']
```

- [ ] **Step 5: Build and test**

Run: `python scripts/run_dbt.py build --select int_preauth_line assert_preauth_line_conservation`
Expected: PASS. Sanity check: `select preauth_outcome, count() from int.int_preauth_line where requested_at >= '2026-06-01' and requested_at < '2026-07-01' group by 1 order by 2 desc` — Approved first; `Unknown` under 0.5% of rows (the Task 11 warn monitor tracks it).

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/revenue hnh_dwh/tests/hnh/assert_preauth_line_conservation.sql
git commit -m "Add pre-authorisation line model with final NPHIES response"
```

---

### Task 10: Pre-authorisation fact

**Files:**
- Create: `hnh_dwh/models/hnh/marts/revenue/fact_preauth_line.sql`
- Modify: `hnh_dwh/models/hnh/marts/revenue/_revenue_marts__models.yml`, `_revenue_marts_unit_tests.yml`, `hnh_dwh/tests/hnh/assert_preauth_line_conservation.sql`

**Interfaces:**
- Consumes: `int_preauth_line` (Task 9 columns), `int_episode`, `fact_charge_line(branch_key, episode_key, service_key, delivery_date_key, charge_status)`, `dim_patient`, `dim_staff`, `dim_service`, `dim_payer`, `hnh_preauth_outcome`, `hnh_preauth_outcome_key`.
- Produces `fact_preauth_line`: keys `preauth_line_key, branch_key, request_date_key, first_sent_date_key, final_response_date_key, episode_key, patient_key, requesting_staff_key, service_key, payer_key, care_type_key, preauth_outcome_key`; flags `is_approved, has_final_response, is_first_response_approved, is_resubmitted, is_status_override, is_delivered, is_approved_not_delivered, is_delivered_not_approved`; measures `approved_estimated_amount, request_to_sent_minutes(_raw), sent_to_response_minutes(_raw), total_turnaround_minutes(_raw), legacy_sent_to_response_minutes`; plus every `int_preauth_line` column except the natural ids replaced by keys.

- [ ] **Step 1: Write the failing unit test**

Append to `_revenue_marts_unit_tests.yml`:

```yaml
  - name: fact_preauth_line_counts_delivery_after_request_only
    description: >
      A1 (service 500) was approved; its only charge was on 5 June, before the 10 June request, so it is
      approved and not delivered. A2 (service 600) was rejected but delivered on 12 June.
    model: fact_preauth_line
    given:
      - input: ref('int_preauth_line')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, line as line_natural_id, toNullable(toInt64(100)) as patient_id,
                 toNullable(toInt64(1)) as episode_no, toNullable(toInt64(ios)) as ios,
                 cast(null as Nullable(String)) as requesting_staff_id, toNullable(toInt64(300)) as purchaser_code,
                 toNullable(toDateTime('2026-06-10 09:00:00', 'Asia/Riyadh')) as requested_at,
                 toNullable(toDateTime('2026-06-10 09:10:00', 'Asia/Riyadh')) as first_sent_at,
                 toNullable(toDateTime('2026-06-10 09:40:00', 'Asia/Riyadh')) as final_responded_at,
                 toNullable(toDateTime('2026-06-10 09:40:00', 'Asia/Riyadh')) as last_responded_at,
                 outcome as preauth_outcome, toNullable(st) as nphies_final_status, toNullable(st) as nphies_first_status,
                 toNullable(flag) as authorised_flag, toUInt64(1) as request_send_count,
                 toNullable(toFloat64(2)) as requested_qty, toNullable(toFloat64(2)) as approved_qty,
                 toNullable(toFloat64(200)) as estimated_amount
          from values('line String, ios UInt32, outcome String, st String, flag String',
              ('A1', 500, 'Approved', 'APPROVED', 'Y'), ('A2', 600, 'Rejected', 'REJECTED', 'R'))
      - input: ref('int_episode')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(100) as patient_id, toInt64(1) as episode_no,
                 'OP' as care_type, toInt64(300) as purchaser_code
      - input: ref('fact_charge_line')
        format: sql
        rows: |
          select toUInt8(1) as branch_key, toInt64(bitShiftRight(cityHash64('1|100|1|'), 1)) as episode_key,
                 toInt64(bitShiftRight(cityHash64(svc), 1)) as service_key, toInt32(d) as delivery_date_key,
                 'Live' as charge_status
          from values('svc String, d UInt32', ('1|500|', 20260605), ('1|600|', 20260612))
      - input: ref('dim_patient')
        format: sql
        rows: |
          select toInt64(-1) as patient_key
      - input: ref('dim_staff')
        format: sql
        rows: |
          select toInt64(-1) as staff_key
      - input: ref('dim_service')
        format: sql
        rows: |
          select toInt64(-1) as service_key
      - input: ref('dim_payer')
        format: sql
        rows: |
          select toInt64(-1) as payer_key
    expect:
      rows:
        - {line_natural_id: A1, is_delivered: 0, is_approved_not_delivered: 1, is_delivered_not_approved: 0, approved_estimated_amount: 200, is_approved: 1, has_final_response: 1, care_type_key: 1}
        - {line_natural_id: A2, is_delivered: 1, is_approved_not_delivered: 0, is_delivered_not_approved: 1, approved_estimated_amount: 200, is_approved: 0, has_final_response: 1, care_type_key: 1}
```

Run: `python scripts/run_dbt.py test --select "fact_preauth_line,test_type:unit"`
Expected: FAIL — model does not exist.

- [ ] **Step 2: Write `fact_preauth_line`**

```sql
{{ config(order_by='(branch_key, request_date_key, preauth_line_key)') }}

{% set first_at = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}
{% set null_s = "cast(null as Nullable(String))" %}
{% set approved_set = "('Approved', 'Partially approved', 'Not required')" %}

with lines as (
    select * from {{ ref('int_preauth_line') }}
    where requested_at >= {{ first_at }} and toDate(requested_at) <= {{ last_day }}
),

deliveries as (
    -- Latest live delivery per episode and service: delivered after a request
    -- exactly when this date is on or after the request date.
    select branch_key, episode_key, service_key, max(delivery_date_key) as last_delivery_date_key
    from {{ ref('fact_charge_line') }}
    where charge_status = 'Live'
    group by branch_key, episode_key, service_key
),

keyed as (
    select
        l.*,
        toInt32(toYYYYMMDD(assumeNotNull(l.requested_at)))                      as request_date_key,
        {{ hnh_surrogate_key(['l.branch_id', 'l.line_natural_id']) }}           as preauth_line_key,
        {{ hnh_surrogate_key(['l.branch_id', 'l.patient_id', 'l.episode_no']) }} as episode_key,
        {{ hnh_surrogate_key(['l.branch_id', 'l.patient_id']) }}                as patient_key_raw,
        {{ hnh_surrogate_key(['l.branch_id', 'l.ios']) }}                       as service_key_raw,
        {{ hnh_surrogate_key(['l.branch_id', 'l.requesting_staff_id']) }}       as staff_key_raw,
        coalesce(l.purchaser_code, ep.purchaser_code, toInt64(9999))            as payer_purchaser_code,
        ifNull(ep.care_type, 'Unknown')                                         as care_type,
        {{ hnh_preauth_outcome('l.nphies_final_status', null_s, null_s) }}      as nphies_outcome,
        {{ hnh_preauth_outcome('l.nphies_first_status', null_s, null_s) }}      as nphies_first_outcome
    from lines as l
    left join (select branch_id, patient_id, episode_no, care_type, purchaser_code from {{ ref('int_episode') }}) as ep
        on ep.branch_id = l.branch_id and ep.patient_id = l.patient_id and ep.episode_no = l.episode_no
)

select
    k.preauth_line_key                                         as preauth_line_key,
    k.branch_id                                                as branch_key,
    k.request_date_key                                         as request_date_key,
    {{ hnh_date_key_in_range('k.first_sent_at') }}             as first_sent_date_key,
    {{ hnh_date_key_in_range('k.final_responded_at') }}        as final_response_date_key,
    k.episode_key                                              as episode_key,
    ifNull(dp.patient_key, toInt64(-1))                        as patient_key,
    ifNull(ds.staff_key, toInt64(-1))                          as requesting_staff_key,
    ifNull(dsv.service_key, toInt64(-1))                       as service_key,
    ifNull(dpy.payer_key, toInt64(-1))                         as payer_key,
    {{ hnh_care_type_key('k.care_type') }}                     as care_type_key,
    {{ hnh_preauth_outcome_key('k.preauth_outcome') }}         as preauth_outcome_key,
    toUInt8(k.preauth_outcome in {{ approved_set }})           as is_approved,
    toUInt8(k.nphies_final_status is not null
            and k.nphies_outcome in ('Approved', 'Partially approved', 'Not required', 'Rejected')) as has_final_response,
    toUInt8(k.nphies_first_outcome = 'Approved')               as is_first_response_approved,
    toUInt8(k.request_send_count > 1)                          as is_resubmitted,
    toUInt8((k.authorised_flag = 'Y' and k.nphies_outcome = 'Rejected')
            or (k.authorised_flag = 'R' and k.nphies_outcome in {{ approved_set }})) as is_status_override,
    toUInt8(ifNull(dv.last_delivery_date_key, 0) >= k.request_date_key)          as is_delivered,
    toUInt8(k.preauth_outcome = 'Approved' and is_delivered = 0)                as is_approved_not_delivered,
    toUInt8(k.preauth_outcome = 'Rejected' and is_delivered = 1)                as is_delivered_not_approved,
    if(ifNull(k.requested_qty, 0) > 0, k.estimated_amount / k.requested_qty * k.approved_qty, null) as approved_estimated_amount,
    {{ hnh_minutes_between('k.requested_at', 'k.first_sent_at') }}              as request_to_sent_minutes,
    dateDiff('minute', k.requested_at, k.first_sent_at)                         as request_to_sent_minutes_raw,
    {{ hnh_minutes_between('k.first_sent_at', 'k.final_responded_at') }}        as sent_to_response_minutes,
    dateDiff('minute', k.first_sent_at, k.final_responded_at)                   as sent_to_response_minutes_raw,
    {{ hnh_minutes_between('k.requested_at', 'k.final_responded_at') }}         as total_turnaround_minutes,
    dateDiff('minute', k.requested_at, k.final_responded_at)                    as total_turnaround_minutes_raw,
    -- old report: first sent to the last response of any kind
    dateDiff('minute', k.first_sent_at, k.last_responded_at)                    as legacy_sent_to_response_minutes,
    k.* except (branch_id, patient_id, episode_no, ios, requesting_staff_id, purchaser_code,
                request_date_key, preauth_line_key, episode_key, patient_key_raw, service_key_raw,
                staff_key_raw, care_type, nphies_first_outcome),
    now()                                                      as _loaded_at
from keyed as k
left join deliveries as dv
    on dv.branch_key = k.branch_id and dv.episode_key = k.episode_key and dv.service_key = k.service_key_raw
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = k.patient_key_raw
left join (select staff_key from {{ ref('dim_staff') }}) as ds on ds.staff_key = k.staff_key_raw
left join (select service_key from {{ ref('dim_service') }}) as dsv on dsv.service_key = k.service_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dpy
    on dpy.payer_key = {{ hnh_surrogate_key(['k.branch_id', 'k.payer_purchaser_code']) }}
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the unit test**

Run: `python scripts/run_dbt.py test --select "fact_preauth_line,test_type:unit"`
Expected: PASS.

- [ ] **Step 4: Extend the conservation test and add model YAML**

Append to `tests/hnh/assert_preauth_line_conservation.sql`:

```sql

union all

-- Every line requested inside the window reaches the fact.
select 'fact_preauth_line differs from int_preauth_line in the window', f.n, i.n
from (select count() as n from {{ ref('fact_preauth_line') }}) as f
cross join (
    select count() as n from {{ ref('int_preauth_line') }}
    where requested_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
      and toDate(requested_at) <= toDate(concat(toString(toYear(today()) + 2), '-12-31'))
) as i
where f.n != i.n
```

Append to `_revenue_marts__models.yml`:

```yaml
  - name: fact_preauth_line
    description: One pre-authorisation line with its final NPHIES answer, turnaround and delivery.
    columns:
      - name: preauth_line_key
        tests: [unique, not_null]
      - name: request_date_key
        tests:
          - not_null
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: patient_key
        tests:
          - relationships: {to: ref('dim_patient'), field: patient_key}
      - name: requesting_staff_key
        tests:
          - relationships: {to: ref('dim_staff'), field: staff_key}
      - name: service_key
        tests:
          - relationships: {to: ref('dim_service'), field: service_key}
      - name: payer_key
        tests:
          - relationships: {to: ref('dim_payer'), field: payer_key}
      - name: care_type_key
        tests:
          - relationships: {to: ref('dim_care_type'), field: care_type_key}
      - name: preauth_outcome_key
        tests:
          - relationships: {to: ref('dim_preauth_outcome'), field: preauth_outcome_key}
```

- [ ] **Step 5: Build and test**

Run: `python scripts/run_dbt.py build --select fact_preauth_line assert_preauth_line_conservation`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/models/hnh/marts/revenue hnh_dwh/tests/hnh/assert_preauth_line_conservation.sql
git commit -m "Add pre-authorisation fact with delivery and turnaround measures"
```

---

### Task 11: Reconciliation models and monitors

**Files:**
- Create in `hnh_dwh/models/hnh/marts/reconciliation/`: `rec_revenue_monthly.sql`, `rec_billing_monthly.sql`, `rec_preauth_monthly.sql`
- Modify: `hnh_dwh/models/hnh/marts/reconciliation/_reconciliation__models.yml`
- Create in `hnh_dwh/tests/hnh/`: `warn_unmapped_product_category.sql`, `warn_invoice_without_payer.sql`, `warn_invoice_account_many_purchasers.sql`, `warn_unmapped_invoice_approval_status.sql`, `warn_preauth_outcome_unknown.sql`, `warn_op_billing_mismatch.sql`

**Interfaces:**
- Consumes: Task 6–10 facts, `agg_episode_billing`, `int_invoice_payer`, `stg_oasis__ar_documents`.
- Produces: `rec_revenue_monthly(branch_key, month_start, revenue, gross_charges, line_discount, vat, claimable_revenue, patient_share_revenue, cash_revenue, medication_revenue, package_content, cancelled_charges, op_revenue, er_revenue, ip_revenue, daycase_revenue, unknown_care_revenue, adjustments, net_revenue_after_adjustments, legacy_charge_revenue, legacy_discount_documents)`; `rec_billing_monthly(branch_key, month_start, care_type_key, claimable_charges, invoiced_net, verified_invoiced_net, long_stay_overbilled)`; `rec_preauth_monthly(branch_key, month_start, services, approved, rejected, final_responses, unutilised, lost_revenue, delivered_not_approved, legacy_approved, legacy_rejected, legacy_lost_revenue)`.

- [ ] **Step 1: Write the YAML tests first**

Append to `_reconciliation__models.yml` under `models:`:

```yaml
  - name: rec_revenue_monthly
    tests:
      - hnh_unique_combination:
          columns: [branch_key, month_start]
  - name: rec_billing_monthly
    tests:
      - hnh_unique_combination:
          columns: [branch_key, month_start, care_type_key]
  - name: rec_preauth_monthly
    tests:
      - hnh_unique_combination:
          columns: [branch_key, month_start]
```

Run: `python scripts/run_dbt.py build --select rec_revenue_monthly rec_billing_monthly rec_preauth_monthly`
Expected: FAIL — models do not exist.

- [ ] **Step 2: Write `rec_revenue_monthly`**

```sql
{{ config(order_by='(branch_key, month_start)') }}

with charges as (
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(delivery_date_key)))  as month_start,
        sum(revenue_amount)                                          as revenue,
        sumIf(gross_amount, is_recognised_revenue = 1)               as gross_charges,
        sumIf(line_discount_amount, is_recognised_revenue = 1)       as line_discount,
        sumIf(vat_amount, is_recognised_revenue = 1)                 as vat,
        sum(claimable_amount)                                        as claimable_revenue,
        sumIf(revenue_amount, is_patient_share = 1)                  as patient_share_revenue,
        sumIf(revenue_amount, is_cash_billed = 1)                    as cash_revenue,
        sumIf(revenue_amount, is_medication = 1)                     as medication_revenue,
        sum(package_content_amount)                                  as package_content,
        sumIf(net_amount, charge_status = 'Cancelled')               as cancelled_charges,
        sumIf(revenue_amount, care_type_key = 1)                     as op_revenue,
        sumIf(revenue_amount, care_type_key = 2)                     as er_revenue,
        sumIf(revenue_amount, care_type_key = 3)                     as ip_revenue,
        sumIf(revenue_amount, care_type_key = 4)                     as daycase_revenue,
        sumIf(revenue_amount, care_type_key = -1)                    as unknown_care_revenue,
        sum(legacy_revenue_amount)                                   as legacy_charge_revenue
    from {{ ref('fact_charge_line') }}
    group by branch_key, month_start
),

adjustments as (
    select branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(adjustment_date_key))) as month_start,
           sum(adjustment_amount) as adjustments
    from {{ ref('fact_revenue_adjustment') }}
    group by branch_key, month_start
),

legacy_discounts as (
    -- old vw_discounts: every AR document whose number ends in D, before the fan-out
    select branch_id as branch_key, toStartOfMonth(toDate(doc_at)) as month_start,
           sum(total_doc_price) as legacy_discount_documents
    from {{ ref('stg_oasis__ar_documents') }}
    where endsWith(ifNull(doc_no, ''), 'D')
      and doc_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
    group by branch_key, month_start
)

select
    c.*,
    ifNull(a.adjustments, 0)                      as adjustments,
    c.revenue + ifNull(a.adjustments, 0)          as net_revenue_after_adjustments,
    ifNull(d.legacy_discount_documents, 0)        as legacy_discount_documents
from charges as c
left join adjustments as a on a.branch_key = c.branch_key and a.month_start = c.month_start
left join legacy_discounts as d on d.branch_key = c.branch_key and d.month_start = c.month_start
{{ hnh_settings() }}
```

- [ ] **Step 3: Write `rec_billing_monthly` and `rec_preauth_monthly`**

`rec_billing_monthly.sql`:

```sql
{{ config(order_by='(branch_key, month_start, care_type_key)') }}

select branch_key, month_start, care_type_key,
       sum(claimable_charges)      as claimable_charges,
       sum(invoiced_net)           as invoiced_net,
       sum(verified_invoiced_net)  as verified_invoiced_net,
       sum(long_stay_overbilled)   as long_stay_overbilled
from (
    select branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(delivery_date_key))) as month_start, care_type_key,
           sum(claimable_amount) as claimable_charges, toFloat64(0) as invoiced_net,
           toFloat64(0) as verified_invoiced_net, toFloat64(0) as long_stay_overbilled
    from {{ ref('fact_charge_line') }}
    where is_claimable = 1
    group by branch_key, month_start, care_type_key

    union all

    select branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(invoice_date_key))), care_type_key,
           toFloat64(0), sum(net_amount), sumIf(net_amount, is_verified = 1), toFloat64(0)
    from {{ ref('fact_invoice') }}
    group by branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(invoice_date_key))), care_type_key

    union all

    select branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(assumeNotNull(last_invoice_date_key)))), care_type_key,
           toFloat64(0), toFloat64(0), toFloat64(0), sum(overbilled_amount)
    from {{ ref('agg_episode_billing') }}
    where is_long_stay_contract = 1 and last_invoice_date_key is not null
    group by branch_key, toStartOfMonth(YYYYMMDDToDate(toUInt32(assumeNotNull(last_invoice_date_key)))), care_type_key
)
group by branch_key, month_start, care_type_key
```

`rec_preauth_monthly.sql`:

```sql
{{ config(order_by='(branch_key, month_start)') }}

select
    branch_key,
    toStartOfMonth(YYYYMMDDToDate(toUInt32(request_date_key)))                  as month_start,
    count()                                                                     as services,
    countIf(is_approved = 1)                                                    as approved,
    countIf(preauth_outcome = 'Rejected')                                       as rejected,
    countIf(has_final_response = 1)                                             as final_responses,
    countIf(is_approved_not_delivered = 1)                                      as unutilised,
    sumIf(approved_estimated_amount, is_approved_not_delivered = 1 and is_latest_request_for_service = 1) as lost_revenue,
    countIf(is_delivered_not_approved = 1)                                      as delivered_not_approved,
    -- the RCM Authorization report: last response of any kind, all services as denominator
    countIf(nphies_last_status in ('APPROVED', 'NOT-REQUIRED', 'PARTIAL'))      as legacy_approved,
    countIf(nphies_last_status = 'REJECTED')                                    as legacy_rejected,
    sumIf(approved_estimated_amount, nphies_last_status = 'APPROVED' and is_delivered = 0 and legacy_is_last_request = 1) as legacy_lost_revenue
from {{ ref('fact_preauth_line') }}
group by branch_key, month_start
```

- [ ] **Step 4: Write the six warn monitors**

Each file starts with `{{ config(severity='warn') }}`.

`warn_unmapped_product_category.sql`:

```sql
{{ config(severity='warn') }}
-- Category codes on charges with no row in default.map_product_category.
select branch_key, count() as unmapped_categories
from {{ ref('dim_product_category') }}
where unified_category = 'Not Mapped' and product_category_key != -1
group by branch_key
```

`warn_invoice_without_payer.sql`:

```sql
{{ config(severity='warn') }}
select branch_key, uniqExact(account_code) as accounts_without_payer, count() as invoices
from {{ ref('fact_invoice') }}
where payer_key = -1
group by branch_key
```

`warn_invoice_account_many_purchasers.sql`:

```sql
{{ config(severity='warn') }}
-- The lowest policy code decides the payer of these accounts; review if the list grows.
select branch_id, account_code, purchaser_count
from {{ ref('int_invoice_payer') }}
where purchaser_count > 1
```

`warn_unmapped_invoice_approval_status.sql`:

```sql
{{ config(severity='warn') }}
-- Approval statuses with no row in default.map_claim_status; they report submission status New.
select branch_key, approval_status, count() as invoices
from {{ ref('fact_invoice') }}
where is_submission_status_mapped = 0
group by branch_key, approval_status
```

`warn_preauth_outcome_unknown.sql`:

```sql
{{ config(severity='warn') }}
select branch_key, nphies_final_status, authorised_flag, count() as lines
from {{ ref('fact_preauth_line') }}
where preauth_outcome = 'Unknown'
group by branch_key, nphies_final_status, authorised_flag
```

`warn_op_billing_mismatch.sql`:

```sql
{{ config(severity='warn') }}
-- Outpatient invoices equal claimable charges (100% of a May 2026 sample). Mismatches in closed months
-- mean a billing rule changed.
select branch_key, count() as episodes, sum(abs(claimable_amount - invoiced_net_amount)) as difference
from {{ ref('agg_episode_billing') }}
where care_type_key = 1 and invoice_count > 0
  and last_invoice_date_key < toInt32(toYYYYMMDD(toStartOfMonth(today())))
  and abs(claimable_amount - invoiced_net_amount) >= 1
group by branch_key
```

- [ ] **Step 5: Build and test**

Run: `python scripts/run_dbt.py build --select rec_revenue_monthly rec_billing_monthly rec_preauth_monthly warn_unmapped_product_category warn_invoice_without_payer warn_invoice_account_many_purchasers warn_unmapped_invoice_approval_status warn_preauth_outcome_unknown warn_op_billing_mismatch`
Expected: 3 models and 3 tests PASS; the `warn_*` tests may report WARN, never ERROR. Record each warning's row count in `docs/reconciliation_phase2.md` (Task 12).

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/models/hnh/marts/reconciliation hnh_dwh/tests/hnh/warn_*.sql
git commit -m "Add revenue, billing and pre-authorisation reconciliation with monitors"
```

---

### Task 12: Full build, documentation and hand-off

**Files:**
- Modify: `docs/receiving_project_config.md`
- Create: `docs/reconciliation_phase2.md`

- [ ] **Step 1: Full build**

Run: `python scripts/run_dbt.py build --select tag:hnh`
Expected: `ERROR=0`. Warnings only from `warn_*` tests. Note the total run time and the `fact_charge_line` time (incremental).

- [ ] **Step 2: Verify a full refresh gives the same charge fact**

```bash
python - <<'EOF'
import sys; sys.path.insert(0, "scripts")
from ch_env import client
print(client().query("select count(), round(sum(revenue_amount), 2) from gold.fact_charge_line").result_rows)
EOF
python scripts/run_dbt.py build --select fact_charge_line --full-refresh
```

Run the Python check again. Expected: the same count and revenue as before (any difference must come only from source rows changed between the two runs; re-run both if the ingestion was active).

- [ ] **Step 3: Update the receiving-project notes**

In `docs/receiving_project_config.md`:
- Add `map_product_category`, `map_claim_status`, `map_nphies_reason` to the list under "Reference tables that must exist in `default`".
- Under "Notes for the SSAS model" add:

```markdown
- `fact_charge_line` relates to `dim_payer` twice: `billed_payer_key` (who the line is billed to; co-pay is 8888 Deductible) and `episode_payer_key` (the episode's payer). Revenue is `SUM(revenue_amount)`; never sum `net_amount` for revenue, it includes package components and cancelled rows.
- Run `dbt build --full-refresh --select fact_charge_line` weekly, like `agg_clinic_capacity_daily`: late changes to episodes, admissions or dimensions do not touch the charge rows, so the incremental load does not revisit those days.
- Pre-authorisation approval and rejection rates divide by lines with `has_final_response = 1`; the RCM Authorization report's all-lines denominator is reproduced by `rec_preauth_monthly.legacy_*`.
```

- [ ] **Step 4: Write the reconciliation guide**

`docs/reconciliation_phase2.md`:

```markdown
# Phase 2A reconciliation

Run after a successful `dbt build --select tag:hnh`. Choose one closed month with finance (open item O-P2-6).

## Revenue (`gold.rec_revenue_monthly`)

1. Export the old `mv_revenue_dataset` charge part for the month (rows with `PACKAGE_DEAL_FLAG = 'N'`, `CANCEL_FLAG = 'X'`, `DOC_ID != 0`, summed by branch).
2. Compare with `legacy_charge_revenue`. Acceptance: within 0.5% per branch.
3. Explain the gap to the new `revenue` with the corrections in spec section 9: the old discount part (compare `legacy_discount_documents` with the old discount rows), package components, care-type mapping.

## Billing (`gold.rec_billing_monthly`, `gold.agg_episode_billing`)

1. Outpatient `claimable_charges` and `invoiced_net` should agree for closed months; `warn_op_billing_mismatch` lists exceptions.
2. `long_stay_overbilled` is the long-stay contract gap (open item O-P2-2). Take the largest episodes to finance.

## Pre-authorisation (`gold.rec_preauth_monthly`)

1. Refresh the RCM Authorization report for the same month.
2. Compare its Approved Services, Rejected Services and Lost Revenue with `legacy_approved`, `legacy_rejected`, `legacy_lost_revenue`. Acceptance: within 0.5%.
3. The new `approved`, `rejected` and `lost_revenue` differ by design (final response, sent-line denominator, latest request per service).

## Monitors at first build

| Monitor | Rows | Note |
|---|---|---|
| warn_unmapped_product_category | | |
| warn_invoice_without_payer | | |
| warn_invoice_account_many_purchasers | | |
| warn_unmapped_invoice_approval_status | | |
| warn_preauth_outcome_unknown | | |
| warn_op_billing_mismatch | | |
```

Fill the Rows column with the counts from Task 11 Step 5 and Step 1 of this task before committing.

- [ ] **Step 5: Commit**

```bash
git add docs/receiving_project_config.md docs/reconciliation_phase2.md
git commit -m "Document Phase 2A hand-off and reconciliation"
```
