# Charge line relationships and census by product category — design

Date: 2026-11-16. Owner: BI manager. Status: draft for approval.

## Why

Revenue analysis in `HNH_Analytics` can slice Charge Lines only by the delivering department, the charge's own staff,
service, product category, payer and care type. The BI manager wants to read revenue, census, cost per episode (CPE) and
cost per visit (CPV) by product category, and to slice charges by service department, ordering doctor, the most
responsible physicians (MRP 1, 2, 3), the cashier who charged the line, and the policy and its client company
(STC, Aramco, …) including the referral flag.

## Goals

1. Charge Lines gets six new dimension links:
   | Link | Source | SSAS table |
   |---|---|---|
   | Service department | `delivery_charge.service_dept` | new `Service Department` |
   | Ordering doctor | `delivery_charge.delivery_line` → `delivery_lines.order_line` → order line → order's ordering staff | new role copy `Ordering Doctor` |
   | MRP 1, 2, 3 | `patient_eligibility.consultant_id` of the row with `responsibility` 1, 2, 3 for the charge's patient and episode whose eligibility period covers the delivery time | new role copies `MRP 1`, `MRP 2`, `MRP 3` |
   | Charged by | `delivery_charge.signon_id` → `cashiers_signon.staff_id` (the staff who opened that cashier shift) | new role copy `Charged By` |
   | Policy | `delivery_charge.policy_code` | new `Policy` |
2. New measures that let every Charge Lines slicer (Product Category, Service, Service Department, the doctor roles,
   Policy, …) narrow census, episodes, CPE and CPV.
3. One ClickHouse mapping table, `default.map_policy_client`, holds both the referral policies (today
   `default.map_referral_policies`) and the policy → client company rules. The BI manager edits it; no deploy needed.

## Non-goals

- The existing `Census`, `Episodes`, `Revenue` measures and every Balanced Scorecard number stay unchanged.
- No change to Order Lines' own dimensions beyond the hidden Encounter Key.
- `default.map_referral_policies` is not dropped in this work (kept until the merged table has been in use for a month).

## Anti-goals (a failure even if it works)

- Any change in the BSC referral KPIs (referrals revenue, census, admissions) or `Is Referral Policy` on Encounters and
  Admissions on the day of the switch.
- An active relationship that makes SSAS reject the model or pick a filter path silently.
- Charge Lines refresh noticeably slower (it is the largest fact: ~28M rows a year).

## Constraints

- Production server rules (`CLAUDE.md`): ClickHouse writes (DDL, loading the mapping table), dbt builds against
  production, SSAS deploys and processing need the user's go-ahead each time. The `HNH_Gold` DSN account is
  SELECT-only; config writes go through an update file the user applies with an admin login, as for the BSC config
  (`scripts/bsc_config/`, `apply_bsc_config.ps1`).
- Spec 5 of the SSAS design: facts are never related to each other. The Encounter link is therefore a hidden key used
  inside measures (`TREATAS`), not a relationship.
- Title-casing rule: new mart name/description columns wrapped in `hnh_title`; repo labels ("Cash", "Deductible",
  "Not Recorded") are not, and go into the title-case test's `excluded` list if their column name matches its pattern.
- SSAS model is generated: tables and relationships via `ssas/tools/model_config.py` + `generate.py`; measures
  hand-written in `tables/_Measures.tmdl`, then `measure_guards.py` and `sync_perspectives.py`; every measure needs a
  check in `ssas/tests/measures/<domain>.json`.

## Data facts (checked 2026-11-16, read-only)

- `delivery_charge` since 2024: 70.1M rows; `signon_id` filled on 99.99%, `service_dept` and `delivery_line` on 100%,
  `policy_code` on 66%. It has no `order_line` column.
- `gold.dim_department` is at work-entity grain; one service department covers up to 61 work entities (272 of 366
  cover more than one), so service department needs its own dimension.
- `patient_eligibility.responsibility`: '1' 10.2M rows, '3' 171k, '2' 112k. Distinct consultants per
  patient/episode: responsibility 1 ≈ 1.00, 2 ≈ 1.03, 3 ≈ 2.48 (max 45) — hence the date-range rule below.
- `cashiers_signon(signon_id, staff_id, shift_start, shift_end, …)` is the only Oasis table with a sign-on id.
- `orders_master.hl7_encounter` is filled on 14,899,412 of 14,899,833 orders since 2024 (match to encounter ids not yet verified).
- 2025 OP/ER arrived, not cancelled encounters reached from a charge's `encounter_key`: ER 209,784 of 213,713 (98%),
  OP 1,358,900 of 1,517,628 (90%).
- `oasis.policies`: 212,918 rows, 176,965 distinct descriptions, named `<INSURER> - <CLIENT> (<number>)`, e.g.
  `TAWUNIYA - STC PAY (2540)`, `BUPA - SAUDI ARAMCO SHELL REFINERY CO (45193700)`. `WESTCON` and `MISTCA` contain "STC".

## Approaches considered

**Census by product category** (user picked A):
- **A. Hidden Encounter Key on Charge Lines and Order Lines, filter applied inside new measures. Chosen.** Existing
  measures untouched. A visit with charges in two categories counts once in each, so categories add up to more than
  the total.
- B. Two-way relationships Encounters ↔ Charge Lines: ambiguous paths through Date, Branch, Patient, Payer,
  Department; SSAS rejects them, and row security gets slow. Rejected.
- C. dbt table encounter × product category: fast but covers product category only. Rejected.

(The user approved A as "one-way relationships". An active one-way relationship Encounters → Charge Lines is also
ambiguous — Date reaches Charge Lines directly and through Encounters — so A is implemented with `TREATAS` on the
hidden key. The user-visible behaviour is what was approved.)

**Policy → client company** (user picked A, then asked to merge the referral map into it):
- **A. Rules table `default.map_policy_client` in ClickHouse, edited by the BI manager. Chosen**, merged with the
  referral policies.
- B. A CSV seed in the repo: every change needs a commit and dbt run. Rejected.

## Design

### dbt

**Staging (new or extended)**
- `stg_oasis__eligibility`: add `eligibility_start`, `eligibility_end` (KSA wall clock, `hnh_ksa_wall_clock`) and
  `eligibility_status`.
- `stg_oasis__charges`: add `service_dept`, `signon_id`, `policy_code`.
- `stg_oasis__orders`: add `hl7_encounter` if not already there.
- New `stg_oasis__cashier_signons(branch_id, signon_id, staff_id, shift_start, shift_end)` from a new source table
  `cashiers_signon` (add to `_oasis__sources.yml`, freshness null; check the receiving project's
  `hnh_oasis_source_only` / `hnh_oasis_as_ref` handling).
- New `stg_ref__policy_client` from `default.map_policy_client`. `stg_ref__referral_policy` keeps its output columns
  but reads the merged table's referral rows, so `fact_episode` is unchanged.

**`default.map_policy_client`** (one table, BI-manager owned)

| column | meaning |
|---|---|
| `branch_id` Nullable(UInt8) | null = every branch |
| `purchaser_code` Nullable(Int64) | optional narrowing |
| `policy_code` Nullable(Int64) | set → exact rule for one policy |
| `name_pattern` Nullable(String) | set → whole-word, case-insensitive match on the policy description (e.g. `STC\|SAUDI TELECOM`) |
| `client_company` Nullable(String) | unified client name, written as it should appear (e.g. `STC`, `Saudi Aramco`) |
| `is_referral` Nullable(UInt8) | 1 = referral, 0 = not referral, null = this row says nothing about referral |
| `note` String | free text |

Resolution per policy, done once in an intermediate model (`int_policy_client`, one row per branch + policy code) that
both `dim_policy` and `stg_ref__referral_policy` read: an exact `policy_code` row wins over a pattern row; a row for
the branch wins over a null-branch row; among pattern rows the longest pattern wins. `client_company` and `is_referral`
are resolved separately, each from the best row where that column is not null, so a row added only for the company
leaves the referral flag alone. A policy with no referral row is not a referral. `stg_ref__referral_policy` outputs the
resolved referral policies with its current columns, so `fact_episode`, Encounters, Admissions and the BSC referral KPIs
follow the table, including future pattern rows (*builder's call, approved 2026-11-16 as "one table"*). On day one the
table's referral rows are exactly `map_referral_policies`, so referral numbers do not change. No company match → the client name taken from the description: text after the first
`-`, with a trailing `(digits)` or number removed, title-cased; no `-` → the whole description. First load: every row of
`map_referral_policies` as an exact row with `is_referral = 1`, plus starter patterns for STC (`STC|SAUDI TELECOM`) and
Saudi Aramco (`ARAMCO`). A draft script (`scripts/draft_policy_client_map.py`, like the other `draft_*` scripts) lists
the most frequent client names by revenue for the BI manager to turn into rules.

**`dim_policy`** (new conformed mart, then `ssas_dim_policy`): one row per branch + policy code, plus three fixed
members per branch for lines without a policy:
- `Cash`: charge is cash-billed (`is_cash_billed = 1` or billed payer is cash 9999);
- `Deductible`: the patient's share of an insured line (`is_patient_share = 1`);
- `Not Recorded`: any other line without a policy code.
Columns: `policy_key`, `branch_key`, `policy_code`, `policy_name` (`hnh_title`), `insurer` (payer name of the policy's
purchaser), `client_company`, `is_referral` (Yes/No), `is_active`.

**`dim_service_department`** (new conformed mart, then `ssas_dim_service_department`): one row per branch + service
department from `stg_oasis__service_departments`: `service_department_key`, `branch_key`, `service_dept`,
`service_department_name` (`hnh_title`), `service_department_type`, `short_code`. Unknown member -1 as in other dims.

**`fact_charge_line` new columns** (all `Int64`, `-1` when not found, like the existing keys)
- `service_department_key` = key of (branch, `service_dept`).
- `ordering_staff_key`: `delivery_line` → `stg_oasis__delivery_lines.order_line` → order line → order's ordering
  staff, the same staff resolution `fact_order_line` uses for `ordering_staff_key`.
- `order_line_key` is not exposed; the ordering doctor is enough.
- `mrp_1_staff_key`, `mrp_2_staff_key`, `mrp_3_staff_key`: for responsibility k (the user's "MRP responsibility
  1, 2, 3"), the eligibility rows of the charge's branch, patient and episode with
  `eligibility_start <= delivered_at <= ifNull(eligibility_end, now())` and `eligibility_status != 'C'` (cancelled;
  statuses seen: O, S, C); if several match, the latest `eligibility_start`, then the highest `patient_eligibility_id`.
  Consultant → staff key. No covering period → -1 (Unknown), per the user's rule. October 2026 check: 510,352 of
  522,552 charges (98%) fall in a responsibility-1 period; 68,126 in a responsibility-2 and 42,719 in a
  responsibility-3 period.
- `charged_by_staff_key`: `signon_id` → `cashiers_signon.staff_id` → staff key.
- `policy_key`: policy code → its key; no code → the branch's Cash / Deductible / Not Recorded member as above. A
  patient-share line that carries a policy code goes to that policy (the user: empty codes are the cash and deductible
  invoices); slice co-pay out with `Is Patient Share`.
- `encounter_key` already exists; it stays in the fact and is no longer dropped by `ssas_fact_charge_line`.

**`fact_order_line`**: add `encounter_key` from the order's `hl7_encounter`, built with the same
`hnh_surrogate_key(['branch_id', <encounter type>, <encounter id>])` recipe as `fact_encounter.encounter_key`. The
encounter type is resolved as `fact_charge_line` does (look up the id in `int_encounter` for the same patient). Where
`hl7_encounter` does not resolve, use the encounter of the order line's first delivered charge; otherwise -1. Report
the share resolved each way after the first build.

**`fact_encounter`**: `encounter_key` stops being dropped in `ssas_fact_encounter`.

**`fact_episode`**: `is_referral_policy` keeps its current expression (via `stg_ref__referral_policy`).

**Tests**: uniqueness of the new dims' keys; relationship tests from the new fact keys (allowing -1); a reconciliation
check that the count of referral episodes per branch and month is identical before and after the switch; the
title-case test covers `policy_name`, `service_department_name`, `client_company` (add to `extra` if the column name
does not match the automatic pattern).

### SSAS

**Tables** (`ssas/tools/model_config.py`)
- `Service Department` (dim, from `ssas_dim_service_department`), `Policy` (dim, from `ssas_dim_policy`).
- Role copies of Staff from `ssas_dim_staff_role`: `Ordering Doctor`, `MRP 1`, `MRP 2`, `MRP 3`, `Charged By`.
- The existing `Staff` link on Charge Lines (`staff_key`, from `delivery_charge.staff_id`) stays as it is.

**Relationships** (`ROLE_KEYS` / dimension key rules), all single direction, active:
- `Charge Lines[service_department_key]` → `Service Department`
- `Charge Lines[ordering_staff_key]` → `Ordering Doctor`
- `Charge Lines[mrp_1_staff_key]` → `MRP 1`, `mrp_2` → `MRP 2`, `mrp_3` → `MRP 3`
- `Charge Lines[charged_by_staff_key]` → `Charged By`
- `Charge Lines[policy_key]` → `Policy`
- `Charge Lines[encounter_key]`, `Order Lines[encounter_key]`, `Encounters[encounter_key]`: hidden, in `NO_RELATIONSHIP`.

**Measures** (folder `Revenue Cycle\By Charges`, perspective Revenue Cycle and Executive):
- `Census (Charged)`: `[Census]` restricted to encounters that have a charge line in the current Charge Lines filter:
  `TREATAS` of the encounter keys of the filtered, recognised charge lines (Date filter removed on the charge side)
  onto `Encounters[Encounter Key]` — the encounter date governs the period; the charge's delivery date does not drop
  a visit charged the next day.
- `Episodes (Charged)`: same pattern on `[Episodes]` with `Charge Lines[Episode Key]` → `Episodes[Episode Key]`
  (requires keeping `episode_key` in both SSAS views).
- **Which side filters (user, 2026-11-16):** Department, Staff, Payer, Care Type and Patient relate to both
  Encounters and Charge Lines; in these measures they act on the **charge side only** (Department = Radiology → visits
  that had a Radiology charge). The measures remove those dimensions' filters from Encounters / Episodes and keep them
  on Charge Lines (Order Lines for `Census (Ordered)`). Date and Branch act on the encounter / episode side.
- `Revenue (Charged Visits)`: `[Revenue]` of the charge lines **in the current Charge Lines filter** whose encounter is
  counted in `Census (Charged)` — with Product Category = Lab, only the Lab revenue of those visits (user, 2026-11-16).
  Charges delivered after the selected period still count for a visit inside it.
- `CPV` = `DIVIDE ( [Revenue (Charged Visits)], [Census (Charged)] )`: Lab revenue ÷ visits with a Lab charge.
- `CPE` = `DIVIDE ( [Revenue (Charged Episodes)], [Episodes (Charged)] )`, where `Revenue (Charged Episodes)` is the
  revenue of the filtered charge lines of the counted episodes (same rule).
- `Census (Ordered)`: same as `Census (Charged)` through `Order Lines[Encounter Key]`, for order-side slicers (ordering
  department, order status).
- "Charged" means a charge line with `Is Recognised Revenue = Yes` (live, not a package component), so a visit whose
  only lines were cancelled is not counted.
- Names and descriptions say these are cohort measures (revenue of the counted visits or episodes), different from
  `BSC OP Revenue per Episode` (revenue by delivery date ÷ episodes by start date) and `Target Cost per Episode`
  (budget).
- When no Charge Lines dimension is filtered, `Census (Charged)` differs from `Census` only by visits with no charge
  (about 10% of OP in 2025); the measure description says so.
- Guards: the new measures must accept the Charge Lines dimensions; `measure_guards.py` decides the guard from the
  tables a measure reads — check the generated guard allows them.
- Checks in `ssas/tests/measures/revenue_cycle.json`: each new measure against a ClickHouse SQL equivalent for one
  branch and month, sliced by one product category.

### Rollout (each step needing approval is marked)

1. dbt code + tests; compile and run unit tests offline.
2. Write `scripts/policy_config/map_policy_client_create.sql` and first-load file; user applies them (ClickHouse write — approval).
3. dbt build of the changed models (production ClickHouse — approval), then the referral reconciliation check.
4. `gen_view_contracts.py`, `generate.py`, measures, guards, perspectives; BPA, pytest, Pester offline.
5. `deploy.ps1 -Stage Test` to `HNH_Analytics_Test` (approval); measure checks; user reviews in a report.
6. Promote to `HNH_Analytics` (approval).
7. Docs: `docs/policy_client_config.md` (how to edit the mapping), `ssas/README.md` table list, `CLAUDE.md` if a rule changes.

## Left to the builder

- Exact key recipes and unknown-member handling, following the existing dims.
- The tie-break when two eligibility rows have the same start (highest `patient_eligibility_id` is the default).
- Which existing ordering-staff resolution `fact_order_line` uses (reuse it, don't re-derive).
- Measure formatting, display folders inside `Revenue Cycle\By Charges`, descriptions.
