# Phase 2B — Claims, Remittance and Pre-authorisation Responses Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Parse the NPHIES pull responses in dbt and build `fact_claim_line`, `fact_claim_payment` and `dim_nphies_reason`, extend `fact_preauth_line` with payer reasons and amounts, and reconcile claims against the legacy logic.

**Architecture:** Claim visits, claim lines and pull responses are staged as views. Two intermediate models parse the FHIR bundles with ClickHouse JSON functions (`int_nphies_adjudication` for claim and pre-authorisation items, `int_claim_payment` for remittance lines); `int_claim_submission` numbers resubmissions and picks the final claim response. Gold facts read those models; rules are `hnh_` macros tested with literal inputs; multi-row and parsing rules are dbt unit tests with SQL fixtures.

**Tech Stack:** ClickHouse 26.5, dbt-core 1.11.12, dbt-clickhouse 1.9.8, Python 3.13 with `clickhouse_connect`.

**Spec:** `docs/superpowers/specs/2026-10-05-hnh-dwh-phase2b-claims-design.md` (parents: `2026-10-04-hnh-dwh-phase2-revenue-cycle-design.md`, `2026-10-01-hnh-dwh-gold-layer-design.md`)

**Prerequisite:** Phase 1 and 2A are on `main` and `python scripts/run_dbt.py build --select tag:hnh` passes. Work happens on branch `phase2b-claims`.

## Global Constraints

- All Phase 1 and 2A constraints apply: databases `stg` / `int` / `gold`; never write to `oasis`, `fusion`, `press_ganey`; models, macros and tests only under `hnh/` folders; macros prefixed `hnh_`; no packages, no seeds; `branch_id` is `UInt8`; Oasis timestamps through `hnh_ksa_wall_clock`; keys through `hnh_surrogate_key`; every model with a `left join` ends with `{{ hnh_settings() }}`; YAML uses the `tests:` key; Oasis tables read with `{{ hnh_oasis_source('<table>') }}` and `final`.
- Run dbt only through `python scripts/run_dbt.py <dbt args>` from the repository root; add `--no-partial-parse` when new YAML or unit tests are not picked up. Ad hoc reads through `scripts/ch_env.py` (`from ch_env import client`); never the machine-wide `CLICKHOUSE_PASSWORD`.
- Facts start at `var('hnh_history_start_date')` (`2022-01-01`) and end at `toDate(concat(toString(toYear(today()) + 2), '-12-31'))`. Claim lines are windowed on the claim visit's statement end date; payments on the payment date.
- Fact dimension keys are never null (missing → `-1`); optional date keys use `hnh_date_key_in_range`.
- Every fact has `_loaded_at` (`now()`), engine `MergeTree`, and an `order_by` starting with `branch_key`.
- Fields that reproduce old behaviour are prefixed `legacy_` and are never used by a new KPI.
- dbt unit tests live in `*_unit_tests.yml`, use `format: sql`, and mock every `ref()` of the model (only the columns the model reads).
- Patient names, identity numbers, mobile, passport, membership and policy-holder fields of claims are never staged. The pull-response bundle text never leaves staging/intermediate; only ClaimResponse and PaymentReconciliation resources are parsed.
- `response_bundle` is `Nullable(String)`: always parse `ifNull(response_bundle, '{}')`.
- ClickHouse cautions met in Phase 2A: an alias that shadows a source column inside an aggregate raises error 184 (rename the intermediate); `x.*` after several joins can come out with qualified names (list columns); sort-key columns must be non-Nullable; `final` is a keyword (never an alias).

### Spec refinements made while planning

| Spec says | Plan does | Why |
|---|---|---|
| `int_claim_payment` keyed by detail identifier | Keyed by `(branch_id, response_id, detail_index)`; the identifier is an attribute | Identifiers are payer-generated and not guaranteed present or unique. |
| Conservation: adjudication items = Σ item counts parsed | Uniqueness of `(branch_id, response_id, item_sequence)` plus the unit test with a multi-item bundle | A count re-parsed with the same JSON path proves nothing the model does not already do. |
| `fact_claim_line` doctor key | Not included | Spec 7.2 lists no doctor key; `doctor_code` mapping to `dim_staff` is unverified. |

## Review Focus

1. **A bundle that also carries Patient and Coverage resources** (every real bundle does): only the ClaimResponse is parsed; no patient field appears in any model. Pinned in Task 3 (`int_nphies_adjudication` unit test, fixture bundle with a Patient resource).
2. **A claim transaction answered PARTIAL and later answered ERROR**: the final response stays the PARTIAL one and the line keeps its approved amount. Pinned in Task 5 (`int_claim_submission` unit test, transaction 7002).
3. **A rejected item whose response carries no reason code, but whose claim line notes contain `MN-1-1`**: reason source `Claim notes`, code MN-1-1. Pinned in Task 7 (`fact_claim_line` unit test, visit 4 line 2).
4. **An approved item with a 20% co-pay**: rejected amount 0 and approved amount 24 of 30 (the co-pay is the patient's share, not a rejection). Pinned in Task 7 (`fact_claim_line` unit test, visit 4 line 1).
5. **A claim invoice submitted twice**: the first submission is numbered 1 and not latest; KPIs on the latest submission do not double count. Pinned in Task 5 (`int_claim_submission` unit test, invoice 500) and Task 7 (`fact_claim_line` unit test, visits 1 and 2).

## File Structure

```
hnh_dwh/
  macros/hnh/hnh_rules_claims.sql                 NPHIES outcome, adjudication status, decision status, notes reason, adjudication amount
  tests/hnh/assert_hnh_claims_macros.sql
  tests/hnh/assert_fact_claim_line_matches_staging.sql
  tests/hnh/warn_claims_without_response.sql, warn_unmatched_claim_response_items.sql,
            warn_unmatched_claim_payments.sql, warn_unknown_nphies_reason.sql, warn_advance_authorisations.sql
  models/hnh/staging/oasis/                       + stg_oasis__claim_visits, stg_oasis__claim_services, stg_oasis__pull_responses
  models/hnh/intermediate/revenue/                + int_nphies_adjudication, int_claim_payment, int_claim_submission;
                                                    int_preauth_line extended; _claims_unit_tests.yml
  models/hnh/marts/conformed/                     + dim_nphies_reason
  models/hnh/marts/revenue/                       + fact_claim_line, fact_claim_payment; fact_preauth_line extended;
                                                    _claims_marts_unit_tests.yml
  models/hnh/marts/reconciliation/                + rec_claims_monthly; rec_preauth_monthly extended
docs/receiving_project_config.md, docs/reconciliation_phase2.md
```

---

### Task 1: Claims and pull-response staging

**Files:**
- Modify: `hnh_dwh/models/hnh/staging/oasis/_oasis__sources.yml`, `_oasis__models.yml`
- Create: `hnh_dwh/models/hnh/staging/oasis/stg_oasis__claim_visits.sql`, `stg_oasis__claim_services.sql`, `stg_oasis__pull_responses.sql`

**Interfaces:**
- Produces:
  - `stg_oasis__claim_visits(branch_id, visit_id, request_at, visit_at, statement_end_at, created_at, claim_invoice_no, stat_invoice_no, patient_id, episode_no, purchaser_code, contract_no, claim_type, doctor_code, provider_department_code, api_trans_id, claim_status, res_status, submit_outcome, is_cancelled, cancelled_at, total_claimed_amount, total_net_amount)`
  - `stg_oasis__claim_services(branch_id, visit_id, sequence_no, service_id, invoice_number, ios, service_code, qty, line_claimed_amount, line_discount_amount, net_amount, co_pay, co_insurance, net_vat_amount, patient_vat_amount, net_with_vat, outcome, approved_qty_text, pre_auth_id, package_id, notes)`
  - `stg_oasis__pull_responses(branch_id, response_id, api_trans_id, about_api_trans_id, response_type, res_status, status, responded_at, response_bundle)` — `response_bundle` is `String` (never null), `res_status` upper-cased.

- [ ] **Step 1: Declare sources and write the failing tests**

Append to the `oasis` source `tables:` in `_oasis__sources.yml`:

```yaml
      - name: claim_visit_detail
      - name: claim_service_detail
        freshness: null
      - name: api_pull_response_details
```

Append to `_oasis__models.yml`:

```yaml
  - name: stg_oasis__claim_visits
    tests:
      - hnh_unique_combination:
          columns: [branch_id, visit_id]
  - name: stg_oasis__claim_services
    tests:
      - hnh_unique_combination:
          columns: [branch_id, visit_id, sequence_no]
  - name: stg_oasis__pull_responses
    tests:
      - hnh_unique_combination:
          columns: [branch_id, response_id]
    columns:
      - name: response_type
        tests:
          - accepted_values:
              values: ['claim-response', 'priorauth-response', 'advanced-authorization', 'payment-reconciliation']
```

Run: `python scripts/run_dbt.py build --select stg_oasis__claim_visits stg_oasis__claim_services stg_oasis__pull_responses`
Expected: FAIL — models do not exist.

- [ ] **Step 2: Write the three views**

`stg_oasis__claim_visits.sql` (patient names, identity numbers, mobile, passport, membership and policy-holder columns are not selected):

```sql
select
    toUInt8(branch_id)                              as branch_id,
    toInt64(visit_id)                               as visit_id,
    {{ hnh_ksa_wall_clock('request_date') }}        as request_at,
    {{ hnh_ksa_wall_clock('visit_date') }}          as visit_at,
    {{ hnh_ksa_wall_clock('stat_end_date') }}       as statement_end_at,
    {{ hnh_ksa_wall_clock('creation_date') }}       as created_at,
    {{ hnh_id('claim_invoice_no') }}                as claim_invoice_no,
    {{ hnh_str('stat_invoice_no') }}                as stat_invoice_no,
    {{ hnh_id('patient_id') }}                      as patient_id,
    nullIf(toInt64OrNull(trimBoth(ifNull(episode_no, ''))), 0) as episode_no,
    {{ hnh_id('purchaser_code') }}                  as purchaser_code,
    {{ hnh_id('contract_no') }}                     as contract_no,
    {{ hnh_code('claim_type') }}                    as claim_type,
    {{ hnh_code('doctor_code') }}                   as doctor_code,
    {{ hnh_code('provider_department_code') }}      as provider_department_code,
    {{ hnh_id('api_trans_id') }}                    as api_trans_id,
    {{ hnh_code('status') }}                        as claim_status,
    {{ hnh_code('res_status') }}                    as res_status,
    {{ hnh_code('submit_claim_outcome') }}          as submit_outcome,
    {{ hnh_flag('canceled') }}                      as is_cancelled,
    {{ hnh_ksa_wall_clock('cancel_date') }}         as cancelled_at,
    toFloat64(ifNull(total_claimed_amount, 0))      as total_claimed_amount,
    toFloat64(ifNull(total_net_amount, 0))          as total_net_amount
from {{ hnh_oasis_source('claim_visit_detail') }} final
```

`stg_oasis__claim_services.sql`:

```sql
select
    toUInt8(branch_id)                          as branch_id,
    toInt64(visit_id)                           as visit_id,
    toInt64(sequence_no)                        as sequence_no,
    toInt64(service_id)                         as service_id,
    {{ hnh_str('invoice_number') }}             as invoice_number,
    {{ hnh_id('ios') }}                         as ios,
    {{ hnh_code('service_code') }}              as service_code,
    toFloat64OrNull(toString(qty))              as qty,
    toFloat64(ifNull(line_claimed_amount, 0))   as line_claimed_amount,
    toFloat64(ifNull(line_item_discount, 0))    as line_discount_amount,
    toFloat64(ifNull(net_amount, 0))            as net_amount,
    toFloat64(ifNull(co_pay, 0))                as co_pay,
    toFloat64(ifNull(co_insurance, 0))          as co_insurance,
    toFloat64(ifNull(net_vat_amount, 0))        as net_vat_amount,
    toFloat64(ifNull(patient_vat_amount, 0))    as patient_vat_amount,
    toFloat64(ifNull(net_with_vat, 0))          as net_with_vat,
    {{ hnh_code('outcome') }}                   as outcome,
    {{ hnh_str('approved_qunatity') }}          as approved_qty_text,
    {{ hnh_str('pre_auth_id') }}                as pre_auth_id,
    {{ hnh_id('package_id') }}                  as package_id,
    {{ hnh_str('notes') }}                      as notes
from {{ hnh_oasis_source('claim_service_detail') }} final
```

`stg_oasis__pull_responses.sql` (only the parsed response types; the bundle is carried for the intermediate parsers and never selected into gold):

```sql
select
    toUInt8(branch_id)                          as branch_id,
    toInt64(response_id)                        as response_id,
    {{ hnh_id('api_trans_id') }}                as api_trans_id,
    {{ hnh_id('about_api_trans_id') }}          as about_api_trans_id,
    lower(trimBoth(ifNull(response_type, ''))) as response_type,
    {{ hnh_code('res_status') }}                as res_status,
    {{ hnh_code('status') }}                    as status,
    {{ hnh_ksa_wall_clock('creation_date') }}   as responded_at,
    ifNull(response_bundle, '{}')               as response_bundle
from {{ hnh_oasis_source('api_pull_response_details') }} final
where lower(trimBoth(ifNull(response_type, ''))) in
      ('claim-response', 'priorauth-response', 'advanced-authorization', 'payment-reconciliation')
```

- [ ] **Step 3: Run the tests**

Run the Step 1 command again.
Expected: PASS, 3 views and 4 tests. If a uniqueness test fails, stop and report the duplicated key counts (the ReplacingMergeTree keys were checked on 2026-10-05: visits `(branch_id, visit_id)`, services `(branch_id, visit_id, service_id, invoice_number, sequence_no)` with `(branch_id, visit_id, sequence_no)` measured unique in 2026, pull responses `(branch_id, response_id)`).

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/staging/oasis
git commit -m "Stage claim visits, claim lines and NPHIES pull responses"
```

---

### Task 2: Claim rule macros

**Files:**
- Create: `hnh_dwh/macros/hnh/hnh_rules_claims.sql`
- Test: `hnh_dwh/tests/hnh/assert_hnh_claims_macros.sql`

**Interfaces:**
- Produces:
  - `hnh_nphies_outcome(outcome_code)` → `'Approved' | 'Partially approved' | 'Not required' | 'Rejected' | 'Pended' | 'Unknown'` (input case-insensitive)
  - `hnh_is_decision_status(res_status)` → `UInt8`
  - `hnh_claim_adjudication_status(is_sent, has_response, final_status)` → `'Not sent' | 'No response' | 'Adjudicated' | 'Pended' | 'Error'`
  - `hnh_reason_from_notes(notes)` → `Nullable(String)`
  - `hnh_adjudication_amount(categories, adjudications, code)` → `Nullable(Float64)` (amount of the adjudication whose category code is `code`)

- [ ] **Step 1: Write the failing test**

`tests/hnh/assert_hnh_claims_macros.sql` (NULL-safe: every check is `not ifNull(<expr> = <expected>, 0)`):

```sql
{% set null_s = "cast(null as Nullable(String))" %}

select 'nphies outcome wrong' as failure
where not ifNull({{ hnh_nphies_outcome("'approved'") }} = 'Approved', 0)
   or not ifNull({{ hnh_nphies_outcome("'PARTIAL'") }} = 'Partially approved', 0)
   or not ifNull({{ hnh_nphies_outcome("'not-required'") }} = 'Not required', 0)
   or not ifNull({{ hnh_nphies_outcome("'rejected'") }} = 'Rejected', 0)
   or not ifNull({{ hnh_nphies_outcome("'pended'") }} = 'Pended', 0)
   or not ifNull({{ hnh_nphies_outcome("'queued'") }} = 'Pended', 0)
   or not ifNull({{ hnh_nphies_outcome("'odd'") }} = 'Unknown', 0)
   or not ifNull({{ hnh_nphies_outcome(null_s) }} = 'Unknown', 0)

union all
select 'decision status wrong'
where not ifNull({{ hnh_is_decision_status("'APPROVED'") }} = 1, 0)
   or not ifNull({{ hnh_is_decision_status("'PARTIAL'") }} = 1, 0)
   or not ifNull({{ hnh_is_decision_status("'REJECTED'") }} = 1, 0)
   or not ifNull({{ hnh_is_decision_status("'PENDED'") }} = 0, 0)
   or not ifNull({{ hnh_is_decision_status("'ERROR'") }} = 0, 0)
   or not ifNull({{ hnh_is_decision_status(null_s) }} = 0, 0)

union all
select 'claim adjudication status wrong'
where not ifNull({{ hnh_claim_adjudication_status("toUInt8(0)", "toUInt8(0)", null_s) }} = 'Not sent', 0)
   or not ifNull({{ hnh_claim_adjudication_status("toUInt8(1)", "toUInt8(0)", null_s) }} = 'No response', 0)
   or not ifNull({{ hnh_claim_adjudication_status("toUInt8(1)", "toUInt8(1)", "'PARTIAL'") }} = 'Adjudicated', 0)
   or not ifNull({{ hnh_claim_adjudication_status("toUInt8(1)", "toUInt8(1)", "'PENDED'") }} = 'Pended', 0)
   or not ifNull({{ hnh_claim_adjudication_status("toUInt8(1)", "toUInt8(1)", "'QUEUED'") }} = 'Pended', 0)
   or not ifNull({{ hnh_claim_adjudication_status("toUInt8(1)", "toUInt8(1)", "'ERROR'") }} = 'Error', 0)
   or not ifNull({{ hnh_claim_adjudication_status("toUInt8(1)", "toUInt8(1)", null_s) }} = 'Error', 0)

union all
select 'reason from notes wrong'
where not ifNull({{ hnh_reason_from_notes("'  BE-1-3Submission not compliant'") }} = 'BE-1-3', 0)
   or not ifNull({{ hnh_reason_from_notes("'- MN-1-1  '") }} = 'MN-1-1', 0)
   or not ifNull({{ hnh_reason_from_notes("'Approved'") }} is null, 0)
   or not ifNull({{ hnh_reason_from_notes(null_s) }} is null, 0)

union all
select 'adjudication amount wrong'
where not ifNull({{ hnh_adjudication_amount("['eligible','benefit']", "['{\"amount\":{\"value\":19}}','{\"amount\":{\"value\":15.2}}']", "'benefit'") }} = 15.2, 0)
   or not ifNull({{ hnh_adjudication_amount("['eligible']", "['{\"amount\":{\"value\":19}}']", "'benefit'") }} is null, 0)
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `python scripts/run_dbt.py test --select assert_hnh_claims_macros --no-partial-parse`
Expected: compilation error — `'hnh_nphies_outcome' is undefined`.

- [ ] **Step 3: Write the macros**

`macros/hnh/hnh_rules_claims.sql`:

```sql
{# NPHIES item adjudication outcome code (extension-adjudication-outcome) to a label. #}
{% macro hnh_nphies_outcome(outcome_code) -%}
multiIf(lower(ifNull({{ outcome_code }}, '')) = 'approved', 'Approved',
        lower(ifNull({{ outcome_code }}, '')) = 'partial', 'Partially approved',
        lower(ifNull({{ outcome_code }}, '')) = 'not-required', 'Not required',
        lower(ifNull({{ outcome_code }}, '')) = 'rejected', 'Rejected',
        lower(ifNull({{ outcome_code }}, '')) in ('pended', 'queued'), 'Pended',
        'Unknown')
{%- endmacro %}

{# A pull-response status that carries a payer decision. #}
{% macro hnh_is_decision_status(res_status) -%}
toUInt8(ifNull({{ res_status }}, '') in ('APPROVED', 'PARTIAL', 'REJECTED'))
{%- endmacro %}

{% macro hnh_claim_adjudication_status(is_sent, has_response, final_status) -%}
multiIf({{ is_sent }} = 0, 'Not sent',
        {{ has_response }} = 0, 'No response',
        ifNull({{ final_status }}, '') in ('APPROVED', 'PARTIAL', 'REJECTED'), 'Adjudicated',
        ifNull({{ final_status }}, '') in ('PENDED', 'QUEUED'), 'Pended',
        'Error')
{%- endmacro %}

{# First NPHIES reason code (e.g. BE-1-3) written in a claim line's free-text notes. #}
{% macro hnh_reason_from_notes(notes) -%}
nullIf(extract(ifNull({{ notes }}, ''), '[A-Z]{2}-[0-9]+-[0-9]+'), '')
{%- endmacro %}

{# Amount of the adjudication whose category code is `code`; null when the category is absent. #}
{% macro hnh_adjudication_amount(categories, adjudications, code) -%}
if(has({{ categories }}, {{ code }}),
   JSONExtractFloat(arrayElement({{ adjudications }}, indexOf({{ categories }}, {{ code }})), 'amount', 'value'),
   cast(null as Nullable(Float64)))
{%- endmacro %}
```

- [ ] **Step 4: Run the test**

Run: `python scripts/run_dbt.py test --select assert_hnh_claims_macros --no-partial-parse`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/macros/hnh/hnh_rules_claims.sql hnh_dwh/tests/hnh/assert_hnh_claims_macros.sql
git commit -m "Add NPHIES claim rule macros"
```

---

### Task 3: NPHIES adjudication parser

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/revenue/int_nphies_adjudication.sql`, `_claims_unit_tests.yml`
- Modify: `hnh_dwh/models/hnh/intermediate/revenue/_revenue__models.yml`

**Interfaces:**
- Consumes: `stg_oasis__pull_responses`; Task 2 macros.
- Produces `int_nphies_adjudication(branch_id UInt8, response_id Int64, item_sequence Int64, response_kind 'Claim'|'Pre-authorisation', response_type, about_api_trans_id Nullable(Int64), res_status, responded_at, outcome, submitted, eligible, benefit, copay, deductible, tax, patient_share Nullable(Float64), approved_qty Nullable(Float64), reason_codes Array(String), primary_reason_code Nullable(String), legacy_reason_amount Nullable(Float64), preauth_reference Nullable(String), preauth_valid_from Nullable(Date), preauth_valid_to Nullable(Date))`.

- [ ] **Step 1: Write the failing unit test**

`intermediate/revenue/_claims_unit_tests.yml`:

```yaml
version: 2

unit_tests:
  - name: int_nphies_adjudication_parses_claim_items
    description: >
      One claim-response bundle with a MessageHeader, a ClaimResponse with two items and a Patient
      resource (ignored). Item 1 is partial with two reason codes on the benefit adjudication; item 2
      is approved. One priorauth-response with a preAuthRef and period. One payment reconciliation
      (not an adjudication; must produce no row).
    model: int_nphies_adjudication
    given:
      - input: ref('stg_oasis__pull_responses')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(9001) as response_id, toNullable(toInt64(1)) as api_trans_id,
                 toNullable(toInt64(7001)) as about_api_trans_id, 'claim-response' as response_type,
                 toNullable('PARTIAL') as res_status, toNullable('SUCCEEDED') as status,
                 toNullable(toDateTime('2026-06-02 10:00:00', 'Asia/Riyadh')) as responded_at,
                 '{"resourceType":"Bundle","entry":[{"resource":{"resourceType":"MessageHeader"}},{"resource":{"resourceType":"ClaimResponse","item":[{"itemSequence":1,"extension":[{"url":"http://nphies.sa/fhir/ksa/nphies-fs/StructureDefinition/extension-adjudication-outcome","valueCodeableConcept":{"coding":[{"code":"partial"}]}}],"adjudication":[{"category":{"coding":[{"code":"submitted"}]},"amount":{"value":100}},{"category":{"coding":[{"code":"eligible"}]},"amount":{"value":80}},{"category":{"coding":[{"code":"benefit"}]},"reason":{"coding":[{"code":"BE-1-7"},{"code":"MN-1-1"}]},"amount":{"value":64}},{"category":{"coding":[{"code":"copay"}]},"amount":{"value":16}},{"category":{"coding":[{"code":"approved-quantity"}]},"value":2}]},{"itemSequence":2,"extension":[{"url":"x/extension-adjudication-outcome","valueCodeableConcept":{"coding":[{"code":"approved"}]}}],"adjudication":[{"category":{"coding":[{"code":"submitted"}]},"amount":{"value":30}},{"category":{"coding":[{"code":"eligible"}]},"amount":{"value":30}},{"category":{"coding":[{"code":"benefit"}]},"amount":{"value":24}},{"category":{"coding":[{"code":"copay"}]},"amount":{"value":6}}]}]}},{"resource":{"resourceType":"Patient","name":[{"text":"MUST NOT APPEAR"}]}}]}' as response_bundle
          union all
          select toUInt8(1), toInt64(9101), toNullable(toInt64(2)), toNullable(toInt64(8001)), 'priorauth-response',
                 toNullable('REJECTED'), toNullable('P'), toNullable(toDateTime('2026-06-03 09:00:00', 'Asia/Riyadh')),
                 '{"entry":[{"resource":{"resourceType":"ClaimResponse","preAuthRef":"PA-77","preAuthPeriod":{"start":"2026-06-03","end":"2026-07-03"},"item":[{"itemSequence":1,"extension":[{"url":"x/extension-adjudication-outcome","valueCodeableConcept":{"coding":[{"code":"rejected"}]}}],"adjudication":[{"category":{"coding":[{"code":"benefit"}]},"reason":{"coding":[{"code":"CV-1-5"}]},"amount":{"value":0}}]}]}}]}'
          union all
          select toUInt8(1), toInt64(9201), toNullable(toInt64(3)), toNullable(toInt64(7001)), 'payment-reconciliation',
                 toNullable('COMPLETE'), toNullable('SUCCEEDED'), toNullable(toDateTime('2026-06-20 09:00:00', 'Asia/Riyadh')),
                 '{"entry":[{"resource":{"resourceType":"PaymentReconciliation","detail":[]}}]}'
    expect:
      rows:
        - {response_id: 9001, item_sequence: 1, response_kind: Claim, about_api_trans_id: 7001, outcome: Partially approved, submitted: 100, eligible: 80, benefit: 64, copay: 16, approved_qty: 2, primary_reason_code: BE-1-7, legacy_reason_amount: 64, preauth_reference: null}
        - {response_id: 9001, item_sequence: 2, response_kind: Claim, about_api_trans_id: 7001, outcome: Approved, submitted: 30, eligible: 30, benefit: 24, copay: 6, approved_qty: null, primary_reason_code: null, legacy_reason_amount: null, preauth_reference: null}
        - {response_id: 9101, item_sequence: 1, response_kind: Pre-authorisation, about_api_trans_id: 8001, outcome: Rejected, submitted: null, eligible: null, benefit: 0, copay: null, approved_qty: null, primary_reason_code: CV-1-5, legacy_reason_amount: 0, preauth_reference: PA-77}
```

Run: `python scripts/run_dbt.py test --select "int_nphies_adjudication,test_type:unit" --no-partial-parse`
Expected: FAIL — model does not exist.

- [ ] **Step 2: Write `int_nphies_adjudication`**

```sql
{{ config(order_by='(branch_id, response_id, item_sequence)') }}

with responses as (
    select branch_id, response_id, about_api_trans_id, response_type, res_status, responded_at, response_bundle
    from {{ ref('stg_oasis__pull_responses') }}
    where response_type in ('claim-response', 'priorauth-response', 'advanced-authorization')
),

claim_responses as (
    -- Only ClaimResponse resources are read; Patient, Coverage and Organization entries are skipped.
    select
        branch_id, response_id, about_api_trans_id, response_type, res_status, responded_at,
        arrayJoin(arrayFilter(e -> JSONExtractString(e, 'resource', 'resourceType') = 'ClaimResponse',
                              JSONExtractArrayRaw(response_bundle, 'entry'))) as entry
    from responses
),

items as (
    select
        branch_id, response_id, about_api_trans_id, response_type, res_status, responded_at,
        nullIf(JSONExtractString(entry, 'resource', 'preAuthRef'), '')                       as preauth_reference,
        toDateOrNull(JSONExtractString(entry, 'resource', 'preAuthPeriod', 'start'))          as preauth_valid_from,
        toDateOrNull(JSONExtractString(entry, 'resource', 'preAuthPeriod', 'end'))            as preauth_valid_to,
        arrayJoin(JSONExtractArrayRaw(entry, 'resource', 'item'))                             as item
    from claim_responses
),

parsed as (
    select
        branch_id, response_id, about_api_trans_id, response_type, res_status, responded_at,
        preauth_reference, preauth_valid_from, preauth_valid_to,
        toInt64(JSONExtractInt(item, 'itemSequence'))                                        as item_sequence,
        JSONExtractArrayRaw(item, 'adjudication')                                            as adjudications,
        arrayMap(a -> JSONExtractString(a, 'category', 'coding', 1, 'code'), adjudications)  as categories,
        arrayFirst(x -> x != '',
            arrayMap(e -> if(position(JSONExtractString(e, 'url'), 'adjudication-outcome') > 0,
                             JSONExtractString(e, 'valueCodeableConcept', 'coding', 1, 'code'), ''),
                     JSONExtractArrayRaw(item, 'extension')))                                as outcome_code,
        arrayFlatten(arrayMap(a -> arrayMap(c -> JSONExtractString(c, 'code'),
                                            JSONExtractArrayRaw(a, 'reason', 'coding')),
                              adjudications))                                                as reason_codes,
        arrayFirst(a -> length(JSONExtractArrayRaw(a, 'reason', 'coding')) > 0, adjudications) as first_reason_adjudication
    from items
)

select
    branch_id,
    response_id,
    item_sequence,
    if(response_type = 'claim-response', 'Claim', 'Pre-authorisation')                  as response_kind,
    response_type,
    about_api_trans_id,
    res_status,
    responded_at,
    {{ hnh_nphies_outcome('outcome_code') }}                                            as outcome,
    {{ hnh_adjudication_amount('categories', 'adjudications', "'submitted'") }}         as submitted,
    {{ hnh_adjudication_amount('categories', 'adjudications', "'eligible'") }}          as eligible,
    {{ hnh_adjudication_amount('categories', 'adjudications', "'benefit'") }}           as benefit,
    {{ hnh_adjudication_amount('categories', 'adjudications', "'copay'") }}             as copay,
    {{ hnh_adjudication_amount('categories', 'adjudications', "'deductible'") }}        as deductible,
    {{ hnh_adjudication_amount('categories', 'adjudications', "'tax'") }}               as tax,
    {{ hnh_adjudication_amount('categories', 'adjudications', "'patientShare'") }}      as patient_share,
    if(has(categories, 'approved-quantity'),
       JSONExtractFloat(arrayElement(adjudications, indexOf(categories, 'approved-quantity')), 'value'),
       cast(null as Nullable(Float64)))                                                 as approved_qty,
    reason_codes,
    if(empty(reason_codes), cast(null as Nullable(String)), reason_codes[1])            as primary_reason_code,
    if(first_reason_adjudication = '', cast(null as Nullable(Float64)),
       JSONExtractFloat(first_reason_adjudication, 'amount', 'value'))                  as legacy_reason_amount,
    preauth_reference,
    preauth_valid_from,
    preauth_valid_to
from parsed
```

- [ ] **Step 3: Run the unit test**

Run: `python scripts/run_dbt.py test --select "int_nphies_adjudication,test_type:unit" --no-partial-parse`
Expected: PASS (three rows; the payment reconciliation and the Patient resource produce nothing).

- [ ] **Step 4: Add model tests and build**

Append to `_revenue__models.yml` under `models:`:

```yaml
  - name: int_nphies_adjudication
    description: One item of one NPHIES ClaimResponse (claim or pre-authorisation) parsed from the pull-response bundle.
    tests:
      - hnh_unique_combination:
          columns: [branch_id, response_id, item_sequence]
    columns:
      - name: outcome
        tests:
          - accepted_values:
              values: ['Approved', 'Partially approved', 'Not required', 'Rejected', 'Pended', 'Unknown']
              config: {severity: warn}
```

Run: `python scripts/run_dbt.py build --select int_nphies_adjudication`
Expected: PASS. Report the row count by `response_kind` and the build time. If the uniqueness test fails (a bundle with two ClaimResponse resources or a repeated item sequence), stop and report the duplicated keys.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/revenue
git commit -m "Parse NPHIES claim and pre-authorisation adjudications"
```

---

### Task 4: Remittance parser

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/revenue/int_claim_payment.sql`
- Modify: `_claims_unit_tests.yml`, `_revenue__models.yml`

**Interfaces:**
- Consumes: `stg_oasis__pull_responses`.
- Produces `int_claim_payment(branch_id, response_id, detail_index UInt64, detail_identifier Nullable(String), claim_api_trans_id Nullable(Int64), payer_claim_response_id Nullable(String), detail_type, detail_date Nullable(Date), amount Float64, payment_component, early_fee, nphies_fee Float64, payment_date Nullable(Date), payment_amount_total Nullable(Float64), period_start, period_end Nullable(Date), payment_reference Nullable(String))`.

- [ ] **Step 1: Write the failing unit test**

Append to `_claims_unit_tests.yml` under `unit_tests:`:

```yaml
  - name: int_claim_payment_parses_reconciliation_details
    description: One payment reconciliation with two detail lines (payment with an early-payment fee, and an advance), plus a claim response that must be ignored.
    model: int_claim_payment
    given:
      - input: ref('stg_oasis__pull_responses')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(9201) as response_id, 'payment-reconciliation' as response_type,
                 '{"entry":[{"resource":{"resourceType":"PaymentReconciliation","paymentDate":"2026-06-18","paymentAmount":{"value":55.0},"paymentIdentifier":{"value":"C1120-1"},"period":{"start":"2026-03-01","end":"2026-03-24"},"detail":[{"identifier":{"value":"D-1"},"type":{"coding":[{"code":"payment"}]},"request":{"identifier":{"value":"7001"}},"response":{"identifier":{"value":"CR-9"}},"date":"2026-06-18","amount":{"value":11.4},"extension":[{"url":"x/extension-component-payment","valueMoney":{"value":13.41}},{"url":"x/extension-component-early-fee","valueMoney":{"value":-2.01}},{"url":"x/extension-component-nphies-fee","valueMoney":{"value":0}}]},{"identifier":{"value":"D-2"},"type":{"coding":[{"code":"advance"}]},"request":{"identifier":{"value":"7002"}},"amount":{"value":43.6}}]}}]}' as response_bundle
          union all
          select toUInt8(1), toInt64(9001), 'claim-response', '{"entry":[{"resource":{"resourceType":"ClaimResponse","item":[]}}]}'
    expect:
      rows:
        - {response_id: 9201, detail_index: 1, detail_identifier: D-1, claim_api_trans_id: 7001, payer_claim_response_id: CR-9, detail_type: payment, amount: 11.4, payment_component: 13.41, early_fee: -2.01, nphies_fee: 0, payment_reference: C1120-1}
        - {response_id: 9201, detail_index: 2, detail_identifier: D-2, claim_api_trans_id: 7002, payer_claim_response_id: null, detail_type: advance, amount: 43.6, payment_component: 0, early_fee: 0, nphies_fee: 0, payment_reference: C1120-1}
```

Run: `python scripts/run_dbt.py test --select "int_claim_payment,test_type:unit" --no-partial-parse`
Expected: FAIL — model does not exist.

- [ ] **Step 2: Write `int_claim_payment`**

```sql
{{ config(order_by='(branch_id, response_id, detail_index)') }}

with reconciliations as (
    select
        branch_id, response_id,
        arrayJoin(arrayFilter(e -> JSONExtractString(e, 'resource', 'resourceType') = 'PaymentReconciliation',
                              JSONExtractArrayRaw(response_bundle, 'entry'))) as entry
    from {{ ref('stg_oasis__pull_responses') }}
    where response_type = 'payment-reconciliation'
),

details as (
    select
        branch_id, response_id,
        toDateOrNull(JSONExtractString(entry, 'resource', 'paymentDate'))              as payment_date,
        JSONExtractFloat(entry, 'resource', 'paymentAmount', 'value')                   as payment_amount_total,
        nullIf(JSONExtractString(entry, 'resource', 'paymentIdentifier', 'value'), '')  as payment_reference,
        toDateOrNull(JSONExtractString(entry, 'resource', 'period', 'start'))           as period_start,
        toDateOrNull(JSONExtractString(entry, 'resource', 'period', 'end'))             as period_end,
        JSONExtractArrayRaw(entry, 'resource', 'detail')                                as detail_list,
        arrayJoin(arrayEnumerate(detail_list))                                          as detail_index
    from reconciliations
),

parsed as (
    select
        branch_id, response_id, payment_date, payment_amount_total, payment_reference, period_start, period_end,
        toUInt64(detail_index)                                                          as detail_index,
        detail_list[detail_index]                                                       as detail,
        arrayMap(e -> tuple(JSONExtractString(e, 'url'), JSONExtractFloat(e, 'valueMoney', 'value')),
                 JSONExtractArrayRaw(detail_list[detail_index], 'extension'))           as components
    from details
)

select
    branch_id,
    response_id,
    detail_index,
    nullIf(JSONExtractString(detail, 'identifier', 'value'), '')                       as detail_identifier,
    toInt64OrNull(JSONExtractString(detail, 'request', 'identifier', 'value'))          as claim_api_trans_id,
    nullIf(JSONExtractString(detail, 'response', 'identifier', 'value'), '')           as payer_claim_response_id,
    JSONExtractString(detail, 'type', 'coding', 1, 'code')                              as detail_type,
    toDateOrNull(JSONExtractString(detail, 'date'))                                     as detail_date,
    JSONExtractFloat(detail, 'amount', 'value')                                         as amount,
    arraySum(arrayMap(c -> if(position(tupleElement(c, 1), 'component-payment') > 0, tupleElement(c, 2), 0), components))   as payment_component,
    arraySum(arrayMap(c -> if(position(tupleElement(c, 1), 'early-fee') > 0, tupleElement(c, 2), 0), components))           as early_fee,
    arraySum(arrayMap(c -> if(position(tupleElement(c, 1), 'nphies-fee') > 0, tupleElement(c, 2), 0), components))          as nphies_fee,
    payment_date,
    payment_amount_total,
    period_start,
    period_end,
    payment_reference
from parsed
```

- [ ] **Step 3: Run the unit test**

Run: `python scripts/run_dbt.py test --select "int_claim_payment,test_type:unit" --no-partial-parse`
Expected: PASS.

- [ ] **Step 4: Add model tests and build**

Append to `_revenue__models.yml`:

```yaml
  - name: int_claim_payment
    description: One NPHIES payment-reconciliation detail line (claim-level remittance).
    tests:
      - hnh_unique_combination:
          columns: [branch_id, response_id, detail_index]
```

Run: `python scripts/run_dbt.py build --select int_claim_payment`
Expected: PASS. Report row count, the distinct `detail_type` values with counts and sums, and the share with `claim_api_trans_id` not null.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/revenue
git commit -m "Parse NPHIES payment reconciliation details"
```

---

### Task 5: Claim submissions

**Files:**
- Create: `hnh_dwh/models/hnh/intermediate/revenue/int_claim_submission.sql`
- Modify: `_claims_unit_tests.yml`, `_revenue__models.yml`

**Interfaces:**
- Consumes: `stg_oasis__claim_visits`, `stg_oasis__pull_responses`, Task 2 macros.
- Produces `int_claim_submission(branch_id, visit_id, claim_invoice_no, stat_invoice_no, patient_id, episode_no, purchaser_code, claim_type, api_trans_id, request_at, statement_end_at, is_cancelled, submission_number UInt64, submission_count UInt64, is_latest_submission UInt8, is_sent UInt8, final_response_id Nullable(Int64), final_status Nullable(String), final_responded_at, response_count UInt64, adjudication_status)`.

- [ ] **Step 1: Write the failing unit test**

Append to `_claims_unit_tests.yml`:

```yaml
  - name: int_claim_submission_numbers_and_picks_final_response
    description: >
      Invoice 500 is submitted twice (visits 1 then 2). Visit 2's transaction 7002 got PARTIAL and later
      ERROR: the final response is the PARTIAL one. Visit 3 (invoice 600) was sent but has no response.
      Visit 4 was never sent.
    model: int_claim_submission
    given:
      - input: ref('stg_oasis__claim_visits')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(v) as visit_id,
                 toNullable(toDateTime(rq, 'Asia/Riyadh')) as request_at,
                 toNullable(toDateTime('2026-06-30 00:00:00', 'Asia/Riyadh')) as statement_end_at,
                 if(inv = 0, cast(null as Nullable(Int64)), toNullable(toInt64(inv))) as claim_invoice_no,
                 toNullable('S1') as stat_invoice_no, toNullable(toInt64(100)) as patient_id, toNullable(toInt64(1)) as episode_no,
                 toNullable(toInt64(300)) as purchaser_code, toNullable('O') as claim_type,
                 if(t = 0, cast(null as Nullable(Int64)), toNullable(toInt64(t))) as api_trans_id, toUInt8(0) as is_cancelled
          from values('v UInt32, rq String, inv UInt32, t UInt32',
              (1, '2026-06-01 09:00:00', 500, 7001), (2, '2026-06-10 09:00:00', 500, 7002),
              (3, '2026-06-05 09:00:00', 600, 7003), (4, '2026-06-06 09:00:00', 700, 0))
      - input: ref('stg_oasis__pull_responses')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(r) as response_id, toNullable(toInt64(t)) as about_api_trans_id,
                 'claim-response' as response_type, toNullable(st) as res_status,
                 toNullable(toDateTime(at, 'Asia/Riyadh')) as responded_at
          from values('r UInt32, t UInt32, st String, at String',
              (9001, 7001, 'REJECTED', '2026-06-03 10:00:00'),
              (9002, 7002, 'PARTIAL',  '2026-06-12 10:00:00'),
              (9003, 7002, 'ERROR',    '2026-06-13 10:00:00'))
    expect:
      rows:
        - {visit_id: 1, submission_number: 1, submission_count: 2, is_latest_submission: 0, is_sent: 1, final_response_id: 9001, final_status: REJECTED, response_count: 1, adjudication_status: Adjudicated}
        - {visit_id: 2, submission_number: 2, submission_count: 2, is_latest_submission: 1, is_sent: 1, final_response_id: 9002, final_status: PARTIAL, response_count: 2, adjudication_status: Adjudicated}
        - {visit_id: 3, submission_number: 1, submission_count: 1, is_latest_submission: 1, is_sent: 1, final_response_id: null, final_status: null, response_count: 0, adjudication_status: No response}
        - {visit_id: 4, submission_number: 1, submission_count: 1, is_latest_submission: 1, is_sent: 0, final_response_id: null, final_status: null, response_count: 0, adjudication_status: Not sent}
```

Run: `python scripts/run_dbt.py test --select "int_claim_submission,test_type:unit" --no-partial-parse`
Expected: FAIL — model does not exist.

- [ ] **Step 2: Write `int_claim_submission`**

```sql
{{ config(order_by='(branch_id, visit_id)') }}

with visits as (
    select
        branch_id, visit_id, request_at, statement_end_at, claim_invoice_no, stat_invoice_no,
        patient_id, episode_no, purchaser_code, claim_type, api_trans_id, is_cancelled,
        -- a visit without an invoice number is its own claim
        ifNull(claim_invoice_no, -visit_id) as claim_group
    from {{ ref('stg_oasis__claim_visits') }}
),

numbered as (
    select
        v.*,
        row_number() over (partition by branch_id, claim_group
                           order by ifNull(request_at, toDateTime(0, 'Asia/Riyadh')), visit_id)       as submission_number,
        count() over (partition by branch_id, claim_group)                                           as submission_count
    from visits as v
),

final_responses as (
    -- final answer: the latest decision (approved, partial, rejected); else the latest of any status
    select
        branch_id, about_api_trans_id,
        count()                                                                                       as response_count,
        argMax(tuple(response_id, res_status, responded_at),
               tuple({{ hnh_is_decision_status('res_status') }},
                     ifNull(responded_at, toDateTime(0, 'Asia/Riyadh')), response_id))               as final_answer
    from {{ ref('stg_oasis__pull_responses') }}
    where response_type = 'claim-response' and about_api_trans_id is not null
    group by branch_id, about_api_trans_id
)

select
    n.branch_id                                                as branch_id,
    n.visit_id                                                 as visit_id,
    n.claim_invoice_no                                         as claim_invoice_no,
    n.stat_invoice_no                                          as stat_invoice_no,
    n.patient_id                                               as patient_id,
    n.episode_no                                               as episode_no,
    n.purchaser_code                                           as purchaser_code,
    n.claim_type                                               as claim_type,
    n.api_trans_id                                             as api_trans_id,
    n.request_at                                               as request_at,
    n.statement_end_at                                         as statement_end_at,
    n.is_cancelled                                             as is_cancelled,
    toUInt64(n.submission_number)                              as submission_number,
    toUInt64(n.submission_count)                               as submission_count,
    toUInt8(n.submission_number = n.submission_count)          as is_latest_submission,
    toUInt8(n.api_trans_id is not null)                        as is_sent,
    if(fr.about_api_trans_id is null, cast(null as Nullable(Int64)), tupleElement(fr.final_answer, 1))   as final_response_id,
    if(fr.about_api_trans_id is null, cast(null as Nullable(String)), tupleElement(fr.final_answer, 2))  as final_status,
    if(fr.about_api_trans_id is null, cast(null as Nullable(DateTime('Asia/Riyadh'))), tupleElement(fr.final_answer, 3)) as final_responded_at,
    toUInt64(ifNull(fr.response_count, 0))                     as response_count,
    {{ hnh_claim_adjudication_status('toUInt8(n.api_trans_id is not null)',
                                     'toUInt8(fr.about_api_trans_id is not null)',
                                     'if(fr.about_api_trans_id is null, cast(null as Nullable(String)), tupleElement(fr.final_answer, 2))') }} as adjudication_status
from numbered as n
left join final_responses as fr
    on fr.branch_id = n.branch_id and fr.about_api_trans_id = n.api_trans_id
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the unit test**

Run: `python scripts/run_dbt.py test --select "int_claim_submission,test_type:unit" --no-partial-parse`
Expected: PASS.

- [ ] **Step 4: Add model tests and build**

Append to `_revenue__models.yml`:

```yaml
  - name: int_claim_submission
    description: One claim submission (claim visit) with its submission number and final NPHIES claim response.
    tests:
      - hnh_unique_combination:
          columns: [branch_id, visit_id]
    columns:
      - name: adjudication_status
        tests:
          - accepted_values:
              values: ['Not sent', 'No response', 'Adjudicated', 'Pended', 'Error']
```

Run: `python scripts/run_dbt.py build --select int_claim_submission`
Expected: PASS. Report counts by `adjudication_status` for statement months 2026-01 to 2026-08 and the share of invoices with more than one submission.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/revenue
git commit -m "Number claim submissions and pick the final NPHIES response"
```

---

### Task 6: NPHIES reason dimension

**Files:**
- Create: `hnh_dwh/models/hnh/marts/conformed/dim_nphies_reason.sql`
- Modify: `hnh_dwh/models/hnh/marts/conformed/_conformed__models.yml`

**Interfaces:**
- Consumes: `stg_ref__nphies_reason(reason_code, reason, reason_category)`.
- Produces `dim_nphies_reason(nphies_reason_key Int64, reason_code Nullable(String), reason, reason_category)`; key `hnh_surrogate_key(['reason_code'])`; members `-1` Unknown and `0` Not given.

- [ ] **Step 1: Write the failing test**

Append to `_conformed__models.yml`:

```yaml
  - name: dim_nphies_reason
    columns:
      - name: nphies_reason_key
        tests: [unique, not_null]
```

Run: `python scripts/run_dbt.py build --select dim_nphies_reason`
Expected: FAIL — model does not exist.

- [ ] **Step 2: Write the model**

```sql
{{ config(order_by='nphies_reason_key') }}

select {{ hnh_surrogate_key(['reason_code']) }} as nphies_reason_key,
       toNullable(reason_code)                as reason_code,
       reason                                 as reason,
       reason_category                        as reason_category
from {{ ref('stg_ref__nphies_reason') }}

union all
select toInt64(-1), null, 'Unknown code', 'Unknown'

union all
select toInt64(0), null, 'Not given', 'Not given'
```

- [ ] **Step 3: Build and test**

Run: `python scripts/run_dbt.py build --select dim_nphies_reason`
Expected: PASS, 75 rows.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/conformed
git commit -m "Add NPHIES rejection reason dimension"
```

---

### Task 7: Claim line fact

**Files:**
- Create: `hnh_dwh/models/hnh/marts/revenue/fact_claim_line.sql`, `_claims_marts_unit_tests.yml`
- Modify: `hnh_dwh/models/hnh/marts/revenue/_revenue_marts__models.yml`
- Test: `hnh_dwh/tests/hnh/assert_fact_claim_line_matches_staging.sql`

**Interfaces:**
- Consumes: `stg_oasis__claim_services`, `int_claim_submission` (Task 5), `int_nphies_adjudication` (Task 3), `int_episode(branch_id, patient_id, episode_no, care_type)`, `dim_patient(patient_key)`, `dim_payer(payer_key)`, `dim_service(service_key)`, `dim_nphies_reason(nphies_reason_key)`, macros `hnh_reason_from_notes`, `hnh_nphies_outcome`, `hnh_care_type`, `hnh_care_type_key`.
- Produces `gold.fact_claim_line` with `claim_line_key, branch_key, statement_end_date_key, submitted_date_key, response_date_key, patient_key, episode_key, payer_key, service_key, care_type_key, invoice_key, nphies_reason_key, visit_id, sequence_no, claim_invoice_no, stat_invoice_no, service_code, submission_number, is_latest_submission, is_sent, is_cancelled_claim, adjudication_status, item_outcome, reason_codes, primary_reason_code, reason_source, claimed_amount, submitted_amount, eligible_amount, approved_amount, copay_amount, deductible_amount, patient_share_amount, tax_amount, approved_qty, rejected_amount, legacy_submitted_amount, legacy_approved_amount, legacy_rejected_amount, _loaded_at`. `invoice_key = hnh_surrogate_key(['branch_id', 'claim_invoice_no'])` (same as `fact_invoice.invoice_key`).

- [ ] **Step 1: Write the failing unit test**

`marts/revenue/_claims_marts_unit_tests.yml`:

```yaml
version: 2

unit_tests:
  - name: fact_claim_line_applies_adjudication_rules
    description: >
      Invoice 500: visit 1 (submission 1) was rejected with BE-1-3; visit 2 (latest) was partially approved
      without a reason. Visit 3 was sent but not answered. Visit 4: line 1 approved with a 20% co-pay
      (rejected 0, legacy rejected 6); line 2 rejected with no reason in the response but MN-1-1 in the notes.
    model: fact_claim_line
    given:
      - input: ref('stg_oasis__claim_services')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(v) as visit_id, toInt64(sq) as sequence_no, toNullable(toInt64(500)) as ios,
                 toNullable('S-1') as service_code, toFloat64(net) as net_amount,
                 if(oc = '', cast(null as Nullable(String)), toNullable(oc)) as outcome,
                 if(nt = '', cast(null as Nullable(String)), toNullable(nt)) as notes
          from values('v UInt32, sq UInt32, net Float64, oc String, nt String',
              (1, 1, 100, 'REJECTED', ''), (2, 1, 100, 'PARTIAL', ''), (3, 1, 50, '', ''),
              (4, 1, 30, 'APPROVED', ''), (4, 2, 40, 'REJECTED', '- MN-1-1 not justified'))
      - input: ref('int_claim_submission')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(v) as visit_id, toNullable(toInt64(inv)) as claim_invoice_no,
                 toNullable('S1') as stat_invoice_no, toNullable(toInt64(100)) as patient_id, toNullable(toInt64(1)) as episode_no,
                 toNullable(toInt64(300)) as purchaser_code, toNullable('O') as claim_type,
                 toNullable(toDateTime('2026-06-01 09:00:00', 'Asia/Riyadh')) as request_at,
                 toNullable(toDateTime('2026-06-30 00:00:00', 'Asia/Riyadh')) as statement_end_at, toUInt8(0) as is_cancelled,
                 toUInt64(sn) as submission_number, toUInt8(lt) as is_latest_submission, toUInt8(1) as is_sent,
                 if(fr = 0, cast(null as Nullable(Int64)), toNullable(toInt64(fr))) as final_response_id,
                 toNullable(toDateTime('2026-06-05 09:00:00', 'Asia/Riyadh')) as final_responded_at,
                 st as adjudication_status
          from values('v UInt32, inv UInt32, sn UInt32, lt UInt8, fr UInt32, st String',
              (1, 500, 1, 0, 9001, 'Adjudicated'), (2, 500, 2, 1, 9002, 'Adjudicated'),
              (3, 600, 1, 1, 0, 'No response'), (4, 700, 1, 1, 9004, 'Adjudicated'))
      - input: ref('int_nphies_adjudication')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(r) as response_id, toInt64(sq) as item_sequence, 'Claim' as response_kind,
                 oc as outcome, toNullable(toFloat64(sub)) as submitted, toNullable(toFloat64(elg)) as eligible,
                 toNullable(toFloat64(ben)) as benefit, toNullable(toFloat64(cp)) as copay,
                 cast(null as Nullable(Float64)) as deductible, cast(null as Nullable(Float64)) as tax,
                 toNullable(toFloat64(cp)) as patient_share, cast(null as Nullable(Float64)) as approved_qty,
                 if(rc = '', cast([] as Array(String)), [rc]) as reason_codes,
                 if(rc = '', cast(null as Nullable(String)), toNullable(rc)) as primary_reason_code,
                 if(rc = '', cast(null as Nullable(Float64)), toNullable(toFloat64(ben))) as legacy_reason_amount
          from values('r UInt32, sq UInt32, oc String, sub Float64, elg Float64, ben Float64, cp Float64, rc String',
              (9001, 1, 'Rejected', 100, 0, 0, 0, 'BE-1-3'),
              (9002, 1, 'Partially approved', 100, 80, 64, 16, ''),
              (9004, 1, 'Approved', 30, 30, 24, 6, ''),
              (9004, 2, 'Rejected', 40, 0, 0, 0, ''))
      - input: ref('int_episode')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(100) as patient_id, toInt64(1) as episode_no, 'OP' as care_type
      - input: ref('dim_patient')
        format: sql
        rows: |
          select toInt64(-1) as patient_key
      - input: ref('dim_payer')
        format: sql
        rows: |
          select toInt64(-1) as payer_key
      - input: ref('dim_service')
        format: sql
        rows: |
          select toInt64(-1) as service_key
      - input: ref('dim_nphies_reason')
        format: sql
        rows: |
          select toInt64(-1) as nphies_reason_key
    expect:
      rows:
        - {visit_id: 1, sequence_no: 1, is_latest_submission: 0, adjudication_status: Adjudicated, item_outcome: Rejected, approved_amount: 0, rejected_amount: 100, reason_source: NPHIES response, primary_reason_code: BE-1-3, legacy_approved_amount: 0, legacy_rejected_amount: 100, care_type_key: 1}
        - {visit_id: 2, sequence_no: 1, is_latest_submission: 1, adjudication_status: Adjudicated, item_outcome: Partially approved, approved_amount: 64, rejected_amount: 20, reason_source: Not given, primary_reason_code: null, legacy_approved_amount: 0, legacy_rejected_amount: 100, care_type_key: 1}
        - {visit_id: 3, sequence_no: 1, is_latest_submission: 1, adjudication_status: No response, item_outcome: Not adjudicated, approved_amount: null, rejected_amount: null, reason_source: Not given, primary_reason_code: null, legacy_approved_amount: 50, legacy_rejected_amount: 0, care_type_key: 1}
        - {visit_id: 4, sequence_no: 1, is_latest_submission: 1, adjudication_status: Adjudicated, item_outcome: Approved, approved_amount: 24, rejected_amount: 0, reason_source: Not given, primary_reason_code: null, legacy_approved_amount: 30, legacy_rejected_amount: 0, care_type_key: 1}
        - {visit_id: 4, sequence_no: 2, is_latest_submission: 1, adjudication_status: Adjudicated, item_outcome: Rejected, approved_amount: 0, rejected_amount: 40, reason_source: Claim notes, primary_reason_code: MN-1-1, legacy_approved_amount: 0, legacy_rejected_amount: 40, care_type_key: 1}
```

(Visit 2's legacy approved is 0: the old logic took the benefit of a reason-bearing adjudication, and there is none. Visit 4 line 1's legacy rejected is 0 because the old logic counted `net_amount` as approved for an APPROVED outcome; the co-pay distortion appears only on partial lines.)

Run: `python scripts/run_dbt.py test --select "fact_claim_line,test_type:unit" --no-partial-parse`
Expected: FAIL — model does not exist.

- [ ] **Step 2: Write `fact_claim_line`**

```sql
{{ config(order_by='(branch_key, statement_end_date_key, claim_line_key)') }}

{% set first_at = "toDateTime('" ~ var('hnh_history_start_date') ~ " 00:00:00', 'Asia/Riyadh')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with lines as (
    select
        s.branch_id                 as branch_id,
        s.visit_id                  as visit_id,
        s.sequence_no               as sequence_no,
        s.ios                       as ios,
        s.service_code              as service_code,
        s.net_amount                as net_amount,
        s.outcome                   as line_outcome,
        s.notes                     as notes,
        sub.claim_invoice_no        as claim_invoice_no,
        sub.stat_invoice_no         as stat_invoice_no,
        sub.patient_id              as patient_id,
        sub.episode_no              as episode_no,
        sub.purchaser_code          as purchaser_code,
        sub.claim_type              as claim_type,
        sub.request_at              as request_at,
        sub.statement_end_at        as statement_end_at,
        sub.is_cancelled            as is_cancelled,
        sub.submission_number       as submission_number,
        sub.is_latest_submission    as is_latest_submission,
        sub.is_sent                 as is_sent,
        sub.final_response_id       as final_response_id,
        sub.final_responded_at      as final_responded_at,
        sub.adjudication_status     as adjudication_status
    from {{ ref('stg_oasis__claim_services') }} as s
    inner join {{ ref('int_claim_submission') }} as sub
        on sub.branch_id = s.branch_id and sub.visit_id = s.visit_id
    where sub.statement_end_at >= {{ first_at }} and toDate(sub.statement_end_at) <= {{ last_day }}
),

items as (
    select branch_id, response_id, item_sequence, outcome, submitted, eligible, benefit, copay, deductible, tax,
           patient_share, approved_qty, reason_codes, primary_reason_code, legacy_reason_amount
    from {{ ref('int_nphies_adjudication') }}
    where response_kind = 'Claim'
),

adjudicated as (
    select
        l.*,
        toUInt8(l.adjudication_status = 'Adjudicated' and a.response_id is not null)        as has_adjudication,
        a.outcome                    as response_outcome,
        a.submitted                  as response_submitted,
        a.eligible                   as response_eligible,
        a.benefit                    as response_benefit,
        a.copay                      as response_copay,
        a.deductible                 as response_deductible,
        a.tax                        as response_tax,
        a.patient_share              as response_patient_share,
        a.approved_qty               as response_approved_qty,
        a.reason_codes               as response_reason_codes,
        a.primary_reason_code        as response_reason_code,
        a.legacy_reason_amount       as legacy_reason_amount,
        {{ hnh_reason_from_notes('l.notes') }}                                             as notes_reason_code
    from lines as l
    left join items as a
        on a.branch_id = l.branch_id and a.response_id = l.final_response_id and a.item_sequence = l.sequence_no
),

keyed as (
    select
        d.*,
        coalesce(d.response_reason_code, d.notes_reason_code)                                as primary_reason_code,
        {{ hnh_surrogate_key(['d.branch_id', 'd.visit_id', 'd.sequence_no']) }}             as claim_line_key,
        {{ hnh_surrogate_key(['d.branch_id', 'd.patient_id', 'd.episode_no']) }}             as episode_key,
        {{ hnh_surrogate_key(['d.branch_id', 'd.claim_invoice_no']) }}                       as invoice_key,
        {{ hnh_surrogate_key(['d.branch_id', 'd.patient_id']) }}                             as patient_key_raw,
        {{ hnh_surrogate_key(['d.branch_id', 'd.ios']) }}                                    as service_key_raw,
        {{ hnh_surrogate_key(['d.branch_id', 'ifNull(d.purchaser_code, toInt64(9999))']) }}  as payer_key_raw,
        if(ifNull(ep.care_type, 'Unknown') != 'Unknown', ifNull(ep.care_type, 'Unknown'),
           {{ hnh_care_type('d.claim_type') }})                                              as care_type
    from adjudicated as d
    left join (select branch_id, patient_id, episode_no, care_type from {{ ref('int_episode') }}) as ep
        on ep.branch_id = d.branch_id and ep.patient_id = d.patient_id and ep.episode_no = d.episode_no
)

select
    k.claim_line_key                                                        as claim_line_key,
    k.branch_id                                                             as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(k.statement_end_at)))                  as statement_end_date_key,
    {{ hnh_date_key_in_range('k.request_at') }}                             as submitted_date_key,
    {{ hnh_date_key_in_range('k.final_responded_at') }}                     as response_date_key,
    ifNull(dp.patient_key, toInt64(-1))                                     as patient_key,
    k.episode_key                                                           as episode_key,
    ifNull(dpy.payer_key, toInt64(-1))                                      as payer_key,
    ifNull(dsv.service_key, toInt64(-1))                                    as service_key,
    {{ hnh_care_type_key('k.care_type') }}                                  as care_type_key,
    k.invoice_key                                                           as invoice_key,
    if(k.primary_reason_code is null, toInt64(0), ifNull(dr.nphies_reason_key, toInt64(-1))) as nphies_reason_key,
    k.visit_id                                                              as visit_id,
    k.sequence_no                                                           as sequence_no,
    k.claim_invoice_no                                                      as claim_invoice_no,
    k.stat_invoice_no                                                       as stat_invoice_no,
    k.service_code                                                          as service_code,
    k.submission_number                                                     as submission_number,
    k.is_latest_submission                                                  as is_latest_submission,
    k.is_sent                                                               as is_sent,
    k.is_cancelled                                                          as is_cancelled_claim,
    k.adjudication_status                                                   as adjudication_status,
    multiIf(k.has_adjudication = 1, k.response_outcome,
            k.line_outcome is not null, {{ hnh_nphies_outcome('k.line_outcome') }},
            'Not adjudicated')                                              as item_outcome,
    if(k.has_adjudication = 1, k.response_reason_codes, cast([] as Array(String))) as reason_codes,
    k.primary_reason_code                                                   as primary_reason_code,
    multiIf(k.response_reason_code is not null, 'NPHIES response',
            k.notes_reason_code is not null, 'Claim notes', 'Not given')    as reason_source,
    k.net_amount                                                            as claimed_amount,
    if(k.has_adjudication = 1, k.response_submitted, null)                  as submitted_amount,
    if(k.has_adjudication = 1, k.response_eligible, null)                   as eligible_amount,
    if(k.has_adjudication = 1, ifNull(k.response_benefit, 0), null)         as approved_amount,
    if(k.has_adjudication = 1, k.response_copay, null)                      as copay_amount,
    if(k.has_adjudication = 1, k.response_deductible, null)                 as deductible_amount,
    if(k.has_adjudication = 1, k.response_patient_share, null)              as patient_share_amount,
    if(k.has_adjudication = 1, k.response_tax, null)                        as tax_amount,
    if(k.has_adjudication = 1, k.response_approved_qty, null)               as approved_qty,
    if(k.has_adjudication = 1,
       greatest(ifNull(k.response_submitted, k.net_amount) - ifNull(k.response_eligible, 0), 0), null) as rejected_amount,
    -- old claims model and bsc.vw_rcm
    k.net_amount                                                            as legacy_submitted_amount,
    multiIf(ifNull(k.line_outcome, '') = 'REJECTED', 0,
            ifNull(k.line_outcome, '') = 'PARTIAL', ifNull(k.legacy_reason_amount, 0),
            k.net_amount)                                                   as legacy_approved_amount,
    greatest(k.net_amount - legacy_approved_amount, 0)                      as legacy_rejected_amount,
    now()                                                                   as _loaded_at
from keyed as k
left join (select patient_key from {{ ref('dim_patient') }}) as dp on dp.patient_key = k.patient_key_raw
left join (select payer_key from {{ ref('dim_payer') }}) as dpy on dpy.payer_key = k.payer_key_raw
left join (select service_key from {{ ref('dim_service') }}) as dsv on dsv.service_key = k.service_key_raw
left join (select nphies_reason_key from {{ ref('dim_nphies_reason') }}) as dr
    on dr.nphies_reason_key = {{ hnh_surrogate_key(['k.primary_reason_code']) }}
{{ hnh_settings() }}
```

- [ ] **Step 3: Run the unit test**

Run: `python scripts/run_dbt.py test --select "fact_claim_line,test_type:unit" --no-partial-parse`
Expected: PASS.

- [ ] **Step 4: Conservation test and YAML**

`tests/hnh/assert_fact_claim_line_matches_staging.sql`:

```sql
-- One fact row per staged claim line whose claim visit falls in the window.
select 'fact_claim_line row count differs from staging' as failure, f.n as in_fact, s.n as in_staging
from (select count() as n from {{ ref('fact_claim_line') }}) as f
cross join (
    select count() as n
    from {{ ref('stg_oasis__claim_services') }} as c
    inner join {{ ref('stg_oasis__claim_visits') }} as v on v.branch_id = c.branch_id and v.visit_id = c.visit_id
    where v.statement_end_at >= toDateTime('{{ var("hnh_history_start_date") }} 00:00:00', 'Asia/Riyadh')
      and toDate(v.statement_end_at) <= toDate(concat(toString(toYear(today()) + 2), '-12-31'))
) as s
where f.n != s.n
```

Append to `_revenue_marts__models.yml` under `models:`:

```yaml
  - name: fact_claim_line
    description: One NPHIES claim service line per submission, with the final adjudication of that submission. Default KPIs use is_latest_submission = 1.
    columns:
      - name: claim_line_key
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
      - name: statement_end_date_key
        tests:
          - not_null
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: patient_key
        tests:
          - relationships: {to: ref('dim_patient'), field: patient_key}
      - name: payer_key
        tests:
          - relationships: {to: ref('dim_payer'), field: payer_key}
      - name: service_key
        tests:
          - relationships: {to: ref('dim_service'), field: service_key}
      - name: care_type_key
        tests:
          - relationships: {to: ref('dim_care_type'), field: care_type_key}
      - name: nphies_reason_key
        tests:
          - relationships: {to: ref('dim_nphies_reason'), field: nphies_reason_key}
      - name: invoice_key
        tests:
          - relationships:
              to: ref('fact_invoice')
              field: invoice_key
              config: {severity: warn}
      - name: adjudication_status
        tests:
          - accepted_values:
              values: ['Not sent', 'No response', 'Adjudicated', 'Pended', 'Error']
```

- [ ] **Step 5: Build and check**

Run: `python scripts/run_dbt.py build --select fact_claim_line assert_fact_claim_line_matches_staging`
Expected: PASS (the `invoice_key` warning may WARN). Report: row count; for statement month 2026-06, branch 1, latest submissions: Σ claimed (sent, not cancelled), Σ approved, Σ rejected, rejection rate, and the legacy submitted/approved/rejected totals.

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/models/hnh/marts/revenue hnh_dwh/tests/hnh/assert_fact_claim_line_matches_staging.sql
git commit -m "Add NPHIES claim line fact with adjudication and legacy fields"
```

---

### Task 8: Remittance fact

**Files:**
- Create: `hnh_dwh/models/hnh/marts/revenue/fact_claim_payment.sql`
- Modify: `hnh_dwh/models/hnh/marts/revenue/_revenue_marts__models.yml`

**Interfaces:**
- Consumes: `int_claim_payment` (Task 4), `int_claim_submission` (Task 5), `dim_patient`, `dim_payer`.
- Produces `gold.fact_claim_payment(claim_payment_key, branch_key, payment_date_key, statement_end_date_key Nullable(Int32), patient_key, episode_key, payer_key, invoice_key, visit_id Nullable(Int64), claim_api_trans_id, payer_claim_response_id, detail_type, payment_reference, period_start, period_end, payment_amount, payment_component, early_fee, nphies_fee, days_to_payment Nullable(Int64), _loaded_at)`.

- [ ] **Step 1: Write the YAML test first**

Append to `_revenue_marts__models.yml`:

```yaml
  - name: fact_claim_payment
    description: One NPHIES remittance line (claim level). Non-NPHIES payers and AR ageing are Phase 3.
    columns:
      - name: claim_payment_key
        tests: [unique, not_null]
      - name: branch_key
        tests:
          - relationships: {to: ref('hnh_dim_branch'), field: branch_key}
      - name: payment_date_key
        tests:
          - not_null
          - relationships: {to: ref('dim_date'), field: date_key}
      - name: payer_key
        tests:
          - relationships: {to: ref('dim_payer'), field: payer_key}
```

Run: `python scripts/run_dbt.py build --select fact_claim_payment`
Expected: FAIL — model does not exist.

- [ ] **Step 2: Write `fact_claim_payment`**

```sql
{{ config(order_by='(branch_key, payment_date_key, claim_payment_key)') }}

{% set first_day = "toDate('" ~ var('hnh_history_start_date') ~ "')" %}
{% set last_day = "toDate(concat(toString(toYear(today()) + 2), '-12-31'))" %}

with payments as (
    select * from {{ ref('int_claim_payment') }}
    where payment_date >= {{ first_day }} and payment_date <= {{ last_day }}
),

claims as (
    -- one claim visit per NPHIES transaction (latest visit when a transaction was reused)
    select
        branch_id, api_trans_id,
        tupleElement(argMax(tuple(visit_id, patient_id, episode_no, purchaser_code, claim_invoice_no, request_at, statement_end_at), visit_id), 1) as visit_id,
        tupleElement(argMax(tuple(visit_id, patient_id, episode_no, purchaser_code, claim_invoice_no, request_at, statement_end_at), visit_id), 2) as patient_id,
        tupleElement(argMax(tuple(visit_id, patient_id, episode_no, purchaser_code, claim_invoice_no, request_at, statement_end_at), visit_id), 3) as episode_no,
        tupleElement(argMax(tuple(visit_id, patient_id, episode_no, purchaser_code, claim_invoice_no, request_at, statement_end_at), visit_id), 4) as purchaser_code,
        tupleElement(argMax(tuple(visit_id, patient_id, episode_no, purchaser_code, claim_invoice_no, request_at, statement_end_at), visit_id), 5) as claim_invoice_no,
        tupleElement(argMax(tuple(visit_id, patient_id, episode_no, purchaser_code, claim_invoice_no, request_at, statement_end_at), visit_id), 6) as request_at,
        tupleElement(argMax(tuple(visit_id, patient_id, episode_no, purchaser_code, claim_invoice_no, request_at, statement_end_at), visit_id), 7) as statement_end_at
    from {{ ref('int_claim_submission') }}
    where api_trans_id is not null
    group by branch_id, api_trans_id
)

select
    {{ hnh_surrogate_key(['p.branch_id', 'p.response_id', 'p.detail_index']) }}              as claim_payment_key,
    p.branch_id                                                                             as branch_key,
    toInt32(toYYYYMMDD(assumeNotNull(p.payment_date)))                                      as payment_date_key,
    {{ hnh_date_key_in_range('c.statement_end_at') }}                                       as statement_end_date_key,
    ifNull(dp.patient_key, toInt64(-1))                                                     as patient_key,
    {{ hnh_surrogate_key(['p.branch_id', 'c.patient_id', 'c.episode_no']) }}                as episode_key,
    ifNull(dpy.payer_key, toInt64(-1))                                                      as payer_key,
    {{ hnh_surrogate_key(['p.branch_id', 'c.claim_invoice_no']) }}                          as invoice_key,
    c.visit_id                                                                              as visit_id,
    p.claim_api_trans_id                                                                    as claim_api_trans_id,
    p.payer_claim_response_id                                                               as payer_claim_response_id,
    p.detail_type                                                                           as detail_type,
    p.payment_reference                                                                     as payment_reference,
    p.period_start                                                                          as period_start,
    p.period_end                                                                            as period_end,
    p.amount                                                                                as payment_amount,
    p.payment_component                                                                     as payment_component,
    p.early_fee                                                                             as early_fee,
    p.nphies_fee                                                                            as nphies_fee,
    if(c.request_at is null, cast(null as Nullable(Int64)), dateDiff('day', toDate(c.request_at), assumeNotNull(p.payment_date))) as days_to_payment,
    now()                                                                                   as _loaded_at
from payments as p
left join claims as c on c.branch_id = p.branch_id and c.api_trans_id = p.claim_api_trans_id
left join (select patient_key from {{ ref('dim_patient') }}) as dp
    on dp.patient_key = {{ hnh_surrogate_key(['p.branch_id', 'c.patient_id']) }}
left join (select payer_key from {{ ref('dim_payer') }}) as dpy
    on dpy.payer_key = {{ hnh_surrogate_key(['p.branch_id', 'ifNull(c.purchaser_code, toInt64(9999))']) }}
{{ hnh_settings() }}
```

If ClickHouse raises error 184 on the repeated `argMax(...)` aliases, compute the argMax once in an inner subquery and unpack it there (behaviour unchanged).

- [ ] **Step 3: Build and check**

Run: `python scripts/run_dbt.py build --select fact_claim_payment`
Expected: PASS. Report row count, Σ `payment_amount` by `detail_type`, the share with `visit_id` null, and median `days_to_payment` for 2026.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/revenue
git commit -m "Add NPHIES claim remittance fact"
```

---

### Task 9: Pre-authorisation responses in the pre-auth fact

**Files:**
- Modify: `hnh_dwh/models/hnh/intermediate/revenue/int_preauth_line.sql`, `_revenue_unit_tests.yml`, `_revenue__models.yml`
- Modify: `hnh_dwh/models/hnh/marts/revenue/fact_preauth_line.sql`, `_revenue_marts_unit_tests.yml`, `_revenue_marts__models.yml`

**Interfaces:**
- Consumes: `int_nphies_adjudication` (Task 3, `response_kind = 'Pre-authorisation'`), `dim_nphies_reason` (Task 6); the existing `sent_items` CTE of `int_preauth_line` (columns `branch_id, line_natural_id, api_trans_id, item_no`).
- Produces new `int_preauth_line` columns (appended after `legacy_is_last_request`): `primary_reason_code Nullable(String)`, `reason_codes Array(String)`, `payer_eligible_amount Nullable(Float64)`, `payer_approved_amount Nullable(Float64)`, `preauth_reference Nullable(String)`, `preauth_valid_from Nullable(Date)`, `preauth_valid_to Nullable(Date)`. New `fact_preauth_line` columns: `nphies_reason_key Int64`, `preauth_valid_from_date_key`, `preauth_valid_to_date_key` (plus the int columns, passed through by `k.* except`).

- [ ] **Step 1: Extend the unit tests first**

In `_revenue_unit_tests.yml`, test `int_preauth_line_picks_final_response_and_latest_request`, add an input (keep all existing inputs and expectations):

```yaml
      - input: ref('int_nphies_adjudication')
        format: sql
        rows: |
          select toUInt8(1) as branch_id, toInt64(r) as response_id, toNullable(toInt64(t)) as about_api_trans_id,
                 toInt64(1) as item_sequence, 'Pre-authorisation' as response_kind, oc as outcome,
                 toNullable(toDateTime(at, 'Asia/Riyadh')) as responded_at,
                 if(rc = '', cast([] as Array(String)), [rc]) as reason_codes,
                 if(rc = '', cast(null as Nullable(String)), toNullable(rc)) as primary_reason_code,
                 toNullable(toFloat64(elg)) as eligible, toNullable(toFloat64(ben)) as benefit,
                 toNullable(ref) as preauth_reference,
                 toNullable(toDate('2026-06-01')) as preauth_valid_from, toNullable(toDate('2026-07-01')) as preauth_valid_to
          from values('r UInt32, t UInt32, oc String, at String, rc String, elg Float64, ben Float64, ref String',
              (5001, 1001, 'Pended', '2026-06-01 09:20:00', '', 0, 0, 'PA-0'),
              (5002, 1002, 'Partially approved', '2026-06-01 09:50:00', 'BE-1-6', 200, 180, 'PA-1'),
              (5004, 1003, 'Rejected', '2026-06-01 10:10:00', 'MN-1-1', 0, 0, 'PA-2'))
```

and extend the expected rows: A1 gets `primary_reason_code: BE-1-6, payer_approved_amount: 180, preauth_reference: PA-1`; A2 and A3 get `primary_reason_code: null, payer_approved_amount: null, preauth_reference: null`; N1003-1 gets `primary_reason_code: MN-1-1, payer_approved_amount: 0, preauth_reference: PA-2`. (Keep every column the rows already list.)

In `_revenue_marts_unit_tests.yml`, test `fact_preauth_line_counts_delivery_after_request_only`, add to the `int_preauth_line` fixture the columns `cast(null as Nullable(String)) as primary_reason_code, cast(null as Nullable(Date)) as preauth_valid_from, cast(null as Nullable(Date)) as preauth_valid_to`, add an input:

```yaml
      - input: ref('dim_nphies_reason')
        format: sql
        rows: |
          select toInt64(-1) as nphies_reason_key
```

and add `nphies_reason_key: 0` to both expected rows.

Run: `python scripts/run_dbt.py test --select "int_preauth_line,test_type:unit" "fact_preauth_line,test_type:unit" --no-partial-parse`
Expected: FAIL (new columns do not exist).

- [ ] **Step 2: Extend `int_preauth_line`**

Insert this CTE between `response_summary` and `all_lines`:

```sql
payer_adjudication as (
    -- The payer's parsed pre-authorisation answer for the line: latest decision, else latest of any kind.
    select
        branch_id, line_natural_id,
        tupleElement(pa, 1) as primary_reason_code,
        tupleElement(pa, 2) as reason_codes,
        tupleElement(pa, 3) as payer_eligible_amount,
        tupleElement(pa, 4) as payer_approved_amount,
        tupleElement(pa, 5) as preauth_reference,
        tupleElement(pa, 6) as preauth_valid_from,
        tupleElement(pa, 7) as preauth_valid_to
    from (
        select
            s.branch_id as branch_id, s.line_natural_id as line_natural_id,
            argMax(tuple(a.primary_reason_code, a.reason_codes, a.eligible, a.benefit,
                         a.preauth_reference, a.preauth_valid_from, a.preauth_valid_to),
                   tuple(toUInt8(a.outcome in ('Approved', 'Partially approved', 'Not required', 'Rejected')),
                         ifNull(a.responded_at, toDateTime(0, 'Asia/Riyadh')), a.response_id)) as pa
        from sent_items as s
        inner join (select * from {{ ref('int_nphies_adjudication') }} where response_kind = 'Pre-authorisation') as a
            on a.branch_id = s.branch_id and a.about_api_trans_id = s.api_trans_id
           and toString(a.item_sequence) = s.item_no
        group by s.branch_id, s.line_natural_id
    )
),
```

Append to the final `select`, after `legacy_is_last_request`:

```sql
    ,
    pa.primary_reason_code                               as primary_reason_code,
    ifNull(pa.reason_codes, cast([] as Array(String)))   as reason_codes,
    pa.payer_eligible_amount                             as payer_eligible_amount,
    pa.payer_approved_amount                             as payer_approved_amount,
    pa.preauth_reference                                 as preauth_reference,
    pa.preauth_valid_from                                as preauth_valid_from,
    pa.preauth_valid_to                                  as preauth_valid_to
```

and add, after the `left join response_summary as rs …` clause and before `{{ hnh_settings() }}`:

```sql
left join payer_adjudication as pa
    on pa.branch_id = l.branch_id and pa.line_natural_id = l.line_natural_id
```

(Arrays cannot be Nullable; with `join_use_nulls = 1` an unmatched `pa.reason_codes` is the empty array, and `ifNull` keeps the expression valid either way.)

- [ ] **Step 3: Extend `fact_preauth_line`**

In the final `select`, before the `k.* except (...)` line, add:

```sql
    if(k.primary_reason_code is null, toInt64(0), ifNull(dnr.nphies_reason_key, toInt64(-1))) as nphies_reason_key,
    {{ hnh_date_key_in_range('k.preauth_valid_from') }}        as preauth_valid_from_date_key,
    {{ hnh_date_key_in_range('k.preauth_valid_to') }}          as preauth_valid_to_date_key,
```

and add this join after the existing `dim_payer` join, before `{{ hnh_settings() }}`:

```sql
left join (select nphies_reason_key from {{ ref('dim_nphies_reason') }}) as dnr
    on dnr.nphies_reason_key = {{ hnh_surrogate_key(['k.primary_reason_code']) }}
```

Append to the `fact_preauth_line` columns in `_revenue_marts__models.yml`:

```yaml
      - name: nphies_reason_key
        tests:
          - relationships: {to: ref('dim_nphies_reason'), field: nphies_reason_key}
```

- [ ] **Step 4: Run tests and build**

Run: `python scripts/run_dbt.py build --select int_preauth_line fact_preauth_line assert_preauth_line_conservation --no-partial-parse`
Expected: PASS. Report, for June 2026: rejected lines with a reason code, and the top five reason codes.

- [ ] **Step 5: Commit**

```bash
git add hnh_dwh/models/hnh/intermediate/revenue hnh_dwh/models/hnh/marts/revenue
git commit -m "Add NPHIES reasons and payer amounts to pre-authorisation lines"
```

---

### Task 10: Claims reconciliation and monitors

**Files:**
- Create: `hnh_dwh/models/hnh/marts/reconciliation/rec_claims_monthly.sql`
- Modify: `hnh_dwh/models/hnh/marts/reconciliation/rec_preauth_monthly.sql`, `_reconciliation__models.yml`
- Create: `hnh_dwh/tests/hnh/warn_claims_without_response.sql`, `warn_unmatched_claim_response_items.sql`, `warn_unmatched_claim_payments.sql`, `warn_unknown_nphies_reason.sql`, `warn_advance_authorisations.sql`

**Interfaces:**
- Consumes: `fact_claim_line`, `fact_claim_payment`, `fact_preauth_line`, `dim_nphies_reason`, `int_nphies_adjudication`, `stg_oasis__claim_services`, `int_claim_submission`.
- Produces `rec_claims_monthly(branch_key, month_start, legacy_submitted, legacy_approved, legacy_rejected, submitted, approved, rejected, adjudicated_submitted, first_pass_rejected, first_pass_adjudicated_submitted, resubmission_recovery, pending, remitted, remittance_fees)`; `rec_preauth_monthly` gains `rejected_technical_contractual, rejected_appropriateness, rejected_pharmacy, rejected_duplicated, rejected_fraud, rejected_reason_not_given`.

- [ ] **Step 1: YAML test first**

Append to `_reconciliation__models.yml`:

```yaml
  - name: rec_claims_monthly
    tests:
      - hnh_unique_combination:
          columns: [branch_key, month_start]
```

Run: `python scripts/run_dbt.py build --select rec_claims_monthly`
Expected: FAIL — model does not exist.

- [ ] **Step 2: Write `rec_claims_monthly`**

```sql
{{ config(order_by='(branch_key, month_start)') }}

with claims as (
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(statement_end_date_key)))                         as month_start,
        sum(legacy_submitted_amount)                                                              as legacy_submitted,
        sum(legacy_approved_amount)                                                               as legacy_approved,
        sum(legacy_rejected_amount)                                                               as legacy_rejected,
        sumIf(claimed_amount, is_sent = 1 and is_latest_submission = 1 and is_cancelled_claim = 0) as submitted,
        sumIf(ifNull(approved_amount, 0), is_latest_submission = 1)                              as approved,
        sumIf(ifNull(rejected_amount, 0), is_latest_submission = 1)                              as rejected,
        sumIf(ifNull(submitted_amount, 0), is_latest_submission = 1 and adjudication_status = 'Adjudicated') as adjudicated_submitted,
        sumIf(ifNull(rejected_amount, 0), submission_number = 1)                                 as first_pass_rejected,
        sumIf(ifNull(submitted_amount, 0), submission_number = 1 and adjudication_status = 'Adjudicated') as first_pass_adjudicated_submitted,
        sumIf(ifNull(approved_amount, 0), submission_number > 1)                                 as resubmission_recovery,
        sumIf(claimed_amount, is_sent = 1 and is_latest_submission = 1
                              and adjudication_status in ('No response', 'Pended'))              as pending
    from {{ ref('fact_claim_line') }}
    group by branch_key, month_start
),

remittance as (
    -- remittance by the statement month of the claim it pays
    select
        branch_key,
        toStartOfMonth(YYYYMMDDToDate(toUInt32(assumeNotNull(statement_end_date_key))))          as month_start,
        sum(payment_amount)                                                                       as remitted,
        sum(early_fee + nphies_fee)                                                               as remittance_fees
    from {{ ref('fact_claim_payment') }}
    where statement_end_date_key is not null
    group by branch_key, month_start
)

select
    c.branch_key                        as branch_key,
    c.month_start                       as month_start,
    c.legacy_submitted                  as legacy_submitted,
    c.legacy_approved                   as legacy_approved,
    c.legacy_rejected                   as legacy_rejected,
    c.submitted                         as submitted,
    c.approved                          as approved,
    c.rejected                          as rejected,
    c.adjudicated_submitted             as adjudicated_submitted,
    c.first_pass_rejected               as first_pass_rejected,
    c.first_pass_adjudicated_submitted  as first_pass_adjudicated_submitted,
    c.resubmission_recovery             as resubmission_recovery,
    c.pending                           as pending,
    ifNull(r.remitted, 0)               as remitted,
    ifNull(r.remittance_fees, 0)        as remittance_fees
from claims as c
left join remittance as r on r.branch_key = c.branch_key and r.month_start = c.month_start
{{ hnh_settings() }}
```

- [ ] **Step 3: Extend `rec_preauth_monthly`**

Change its `from {{ ref('fact_preauth_line') }}` to `from {{ ref('fact_preauth_line') }} as f left join (select nphies_reason_key, reason_category from {{ ref('dim_nphies_reason') }}) as r on r.nphies_reason_key = f.nphies_reason_key`, qualify existing column references with `f.` where ambiguous, add `{{ hnh_settings() }}` at the end, and add these measures:

```sql
    countIf(f.preauth_outcome = 'Rejected' and r.reason_category = 'Technical and contractual')   as rejected_technical_contractual,
    countIf(f.preauth_outcome = 'Rejected' and r.reason_category = 'Appropriateness of care')     as rejected_appropriateness,
    countIf(f.preauth_outcome = 'Rejected' and r.reason_category = 'Pharmacy Benefit Management') as rejected_pharmacy,
    countIf(f.preauth_outcome = 'Rejected' and r.reason_category = 'Duplicated Service')          as rejected_duplicated,
    countIf(f.preauth_outcome = 'Rejected' and r.reason_category = 'Fraud')                       as rejected_fraud,
    countIf(f.preauth_outcome = 'Rejected' and f.nphies_reason_key = 0)                           as rejected_reason_not_given
```

- [ ] **Step 4: Write the five warn monitors**

Each file starts with `{{ config(severity='warn') }}`.

`warn_claims_without_response.sql`:

```sql
{{ config(severity='warn') }}
-- Sent claims (latest submission) with no NPHIES answer, by branch and statement month; the current month is excluded.
select branch_key, intDiv(statement_end_date_key, 100) as statement_month, count() as lines, sum(claimed_amount) as claimed
from {{ ref('fact_claim_line') }}
where is_sent = 1 and is_latest_submission = 1 and adjudication_status = 'No response'
  and statement_end_date_key < toInt32(toYYYYMMDD(toStartOfMonth(today())))
group by branch_key, statement_month
```

`warn_unmatched_claim_response_items.sql`:

```sql
{{ config(severity='warn') }}
-- Claim-response items that match no claim line of the visit that sent the transaction.
select a.branch_id, count() as items
from {{ ref('int_nphies_adjudication') }} as a
left join (
    select v.branch_id as branch_id, v.api_trans_id as api_trans_id, s.sequence_no as sequence_no
    from {{ ref('int_claim_submission') }} as v
    inner join {{ ref('stg_oasis__claim_services') }} as s on s.branch_id = v.branch_id and s.visit_id = v.visit_id
    where v.api_trans_id is not null
) as c on c.branch_id = a.branch_id and c.api_trans_id = a.about_api_trans_id and c.sequence_no = a.item_sequence
where a.response_kind = 'Claim' and c.api_trans_id is null
group by a.branch_id
settings join_use_nulls = 1
```

`warn_unmatched_claim_payments.sql`:

```sql
{{ config(severity='warn') }}
select branch_key, count() as payment_lines, sum(payment_amount) as amount
from {{ ref('fact_claim_payment') }}
where visit_id is null
group by branch_key
```

`warn_unknown_nphies_reason.sql`:

```sql
{{ config(severity='warn') }}
select branch_key, primary_reason_code, count() as lines
from {{ ref('fact_claim_line') }}
where nphies_reason_key = -1
group by branch_key, primary_reason_code
```

`warn_advance_authorisations.sql`:

```sql
{{ config(severity='warn') }}
-- Payer-initiated advance authorisations are parsed but not reported (spec open item O-P2B-3).
select branch_id, toStartOfMonth(toDate(responded_at)) as month_start, uniqExact(response_id) as authorisations
from {{ ref('int_nphies_adjudication') }}
where response_type = 'advanced-authorization'
group by branch_id, month_start
```

- [ ] **Step 5: Build and test**

Run: `python scripts/run_dbt.py build --select rec_claims_monthly rec_preauth_monthly warn_claims_without_response warn_unmatched_claim_response_items warn_unmatched_claim_payments warn_unknown_nphies_reason warn_advance_authorisations --no-partial-parse`
Expected: models and unique tests PASS; warns may WARN, never ERROR. Report each warn's row count and, for branch 1 June 2026, every `rec_claims_monthly` column.

- [ ] **Step 6: Commit**

```bash
git add hnh_dwh/models/hnh/marts/reconciliation hnh_dwh/tests/hnh/warn_*.sql
git commit -m "Add claims reconciliation, pre-auth reasons and NPHIES monitors"
```

---

### Task 11: Full build and hand-off

**Files:**
- Modify: `docs/receiving_project_config.md`, `docs/reconciliation_phase2.md`

- [ ] **Step 1: Full build**

Run: `python scripts/run_dbt.py build --select tag:hnh`
Expected: `ERROR=0`; warnings only from `warn_*` tests and warn-severity tests. Record the totals, time, and the time of `int_nphies_adjudication`.

- [ ] **Step 2: Receiving-project notes**

In `docs/receiving_project_config.md`:
- Under "How the models read Oasis", add: "`api_pull_response_details` was ingested on 2026-10-05. If the server's `oasis_lake` project has no model of that name, add `'api_pull_response_details'` to `hnh_oasis_source_only` so staging reads it with `source()`; `claim_visit_detail` and `claim_service_detail` already have `oasis_lake` models."
- Under "Notes for the SSAS model", add:

```markdown
- Claim KPIs filter `fact_claim_line.is_latest_submission = 1` unless the measure is first-pass (`submission_number = 1`). Rejection rate divides `rejected_amount` by `submitted_amount` of lines with `adjudication_status = 'Adjudicated'`.
- `fact_claim_payment` is claim-level remittance from NPHIES only; it is not insurer AR (Phase 3).
- `fact_claim_line.invoice_key` and `fact_claim_payment.invoice_key` equal `fact_invoice.invoice_key`; do not relate facts to each other in SSAS, use them for drill-through or SQL.
```

- [ ] **Step 3: Reconciliation guide**

Append to `docs/reconciliation_phase2.md`:

```markdown
## Claims (`gold.rec_claims_monthly`)

1. Export the claims model's Submitted Claims Amount, Approved Amount and Rejections for a closed month, and the same month from `bsc.vw_rcm`.
2. Compare with `legacy_submitted`, `legacy_approved`, `legacy_rejected`. Acceptance: within 0.5% per branch.
3. Explain the gap to `submitted`, `approved`, `rejected` with the corrections in the Phase 2B spec, section 8.
4. Check `warn_claims_without_response` first: months with many unanswered claims are not comparable until the pull-response load is complete (open item O-P2B-1).
```

Then add the five new monitors with their row counts from Step 1 to the monitor table.

- [ ] **Step 4: Commit**

```bash
git add docs/receiving_project_config.md docs/reconciliation_phase2.md
git commit -m "Document Phase 2B hand-off and claims reconciliation"
```
