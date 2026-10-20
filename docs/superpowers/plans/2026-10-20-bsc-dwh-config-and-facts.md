# BSC on SSAS — Plan 1: DWH configuration tables and facts

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put every balanced-scorecard setting in ClickHouse `default` change-log tables, and build the gold and `gold.ssas_*` objects that the SSAS KPI measures (Plan 2) will read.

**Architecture:**
- **Config tables.** Eleven `default.map_bsc_*` tables, insert-only. Created and first filled from the handover project and the decisions in the spec by a generated SQL script.
- **Staging.** `stg_ref__bsc_*` views take the latest row per key.
- **Gold models** in a new `marts/scorecard/` folder resolve targets, weights and manual values. Two models gain columns (`dim_branch`, `dim_product_category`).
- **New facts.** `fact_bsc_workforce_monthly` holds the `vw_work_force` rules at person level, and `fact_recruiting_requisition` is a new gold model.
- **SSAS views.** New `ssas_*` views expose the above, plus `fact_gl_fs_monthly`. Existing views gain a referral flag and the legacy capacity slots.
- **What this plan does not do:** SSAS model changes and measures are Plan 2; the visual is Plan 3; the report is Plan 4.

**Tech Stack:**
- dbt-clickhouse in the receiving project, ClickHouse 26.5;
- Python 3.12 standard library + pytest;
- Windows PowerShell 5.1 + Pester 3.4;
- ODBC DSN `HNH_Gold` for read-only checks.

**Spec:** `docs/superpowers/specs/2026-10-20-hnh-bsc-ssas-perspective-analysis.md` (sections 6.1–6.3, 9, Appendix B). Parent: `2026-10-12-hnh-bsc-views-design.md`.

**Branch:** create `bsc-ssas-dwh` from `main`.

## Global Constraints

- **HNHANALYTICSSRV is the production server** (`CLAUDE.md`).
  - Ask the user before any ClickHouse write (Task 10: DDL and seed) and before the dbt build on the receiving server.
  - `SELECT`/`DESCRIBE` through `HNH_Gold`, pytest and Pester need no confirmation.
  - Never print or commit a password: the apply script uses `Get-Credential`.
- **dbt conventions** (from the bsc plan):
  - work only under `hnh/` folders; YAML uses `tests:`; no packages, no seeds;
  - `branch_key` is `UInt8`;
  - gold tables with a `left join` end with `{{ hnh_settings() }}`.
- **Renderer limits.** Models in `staging/reference` and `marts/scorecard` use only `config()`, `ref()`, `source()`, `var()` and `hnh_settings()`, so `scripts/render_model_sql.py` can render them for read-only checks. There are no `{% %}` blocks and no other macros. The surrogate key is written inline as `toInt64(bitShiftRight(cityHash64(concat(<code>, '|')), 1))`, which equals `hnh_surrogate_key([<code>])`. `ssas_*` views keep using `hnh_ssas_view` and are checked after the receiving build.
- **ClickHouse caution.** An alias that shadows a source column inside an aggregate raises error 184. The latest-row staging pattern therefore aggregates into one tuple, `argMax(tuple(...), changed_at) as latest`, and unpacks it in an outer select.
- **Change-log columns.** Every config table ends with `changed_at DateTime64(3)`, `changed_by String`, `change_note String`, `is_deleted UInt8`. The engine is `MergeTree ORDER BY (<key>, changed_at)`.
- **Labels are repo-defined:** no `hnh_title()`. Add every new `*_name`/`*_desc`/description column of `marts/scorecard` to `excluded` in `tests/hnh/assert_mart_text_title_case.sql`.
- **Branches 1–8 only** in every scorecard model. Branch 0 in a config key means "every hospital"; it is never a row in gold.
- **Windows PowerShell 5.1** syntax only. Pester 3.4: `| Should Be`.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## KPI codes and seed decisions (fixed by the spec)

70 KPIs: 71 in the catalogue, with KPIs 2 and 3 merged into `FIN_REVENUE_GROWTH`, which keeps `kpi_num` 2.

The code is `<prefix>_<slug>`. The prefix is the board pillar: FIN, CUS, INT or LRN. "Additional" KPIs take the pillar of their objective below.

| num | kpi_code | objective | type | dir | fmt | status | target_source | value_source | detail_page |
|---|---|---|---|---|---|---|---|---|---|
| 1 | FIN_NET_REVENUE | F1 | Primary | higher | sar | active | budget | measure | revenue |
| 2 | FIN_REVENUE_GROWTH | F1 | Supporting | higher | sar | active | prior_year | measure | revenue |
| 4 | FIN_EBITDA_MARGIN | F2 | Primary | higher | pct | active | budget | measure | finance |
| 5 | FIN_COST_TO_REVENUE | F2 | Supporting | lower | pct | active | budget | measure | finance |
| 63 | FIN_CONSUMABLES_RATIO | F2 | Supporting | lower | pct | active | budget | measure | finance |
| 6 | FIN_DAYS_IN_AR | F3 | Primary | lower | days | active | fixed | measure | finance |
| 7 | FIN_NET_COLLECTION | F3 | Supporting | higher | pct | parked | none | measure | revenue_cycle |
| 64 | FIN_DAYS_INVENTORY | F3 | Supporting | lower | days | active | budget | measure | finance |
| 65 | FIN_BREAKEVEN_GAP | F3 | Supporting | higher | sar | parked | none | measure | finance |
| 8 | FIN_REVENUE_PER_BED | F4 | Primary | higher | sar | active | budget | measure | revenue |
| 9 | FIN_RETURN_ON_ASSETS | F4 | Primary | higher | pct | active | fixed | measure | finance |
| 10 | FIN_EBITDA_PER_BED | F4 | Supporting | higher | sar | active | budget | measure | finance |
| 55 | FIN_REVENUE_PER_DOCTOR | F5 | Supporting | higher | sar | active | budget | measure | revenue |
| 56 | FIN_EBITDA_PER_DOCTOR | F5 | Supporting | higher | sar | active | budget | measure | finance |
| 11 | CUS_MULTI_SPECIALTY_SHARE | C1 | Primary | higher | pct | active | budget | measure | revenue |
| 12 | CUS_PAYER_MIX | C1 | Primary | higher | pct | active | budget | measure | revenue |
| 13 | CUS_PATIENT_SATISFACTION | C2 | Primary | higher | pct | active | none | measure | experience |
| 14 | CUS_PATIENT_RETENTION | C2 | Supporting | higher | pct | active | fixed | measure | volume |
| 15 | CUS_NEW_PATIENTS | C2 | Supporting | higher | pct | active | fixed | measure | volume |
| 16 | CUS_PREMS | C2 | Supporting | higher | pct | active | fixed | manual | experience |
| 17 | CUS_PROMS | C2 | Supporting | higher | pct | active | none | manual | experience |
| 66 | CUS_COMPLAINT_RATE | C2 | Supporting | lower | pct | active | fixed | manual | experience |
| 67 | CUS_OP_WAIT | C2 | Supporting | lower | mins | active | fixed | measure | volume |
| 18 | CUS_NON_MOH_SHARE | C3 | Primary | higher | pct | active | budget | measure | revenue |
| 19 | CUS_NON_ELIGIBLE_REFERRAL | C3 | Supporting | lower | pct | parked | none | measure | volume |
| 20 | CUS_PAYER_VOLUME | C3 | Supporting | higher | num | active | budget | measure | volume |
| 61 | CUS_REFERRAL_CONVERSION | C3 | Supporting | higher | pct | parked | none | measure | volume |
| 62 | CUS_ACQUISITION_COST | C3 | Supporting | lower | sar | active | none | measure | finance |
| 21 | INT_BED_OCCUPANCY | P1 | Primary | higher | pct | active | fixed | measure | beds |
| 22 | INT_OP_UTILIZATION | P1 | Primary | higher | pct | active | budget | measure | volume |
| 23 | INT_ALOS | P1 | Supporting | lower | days | active | fixed | measure | beds |
| 24 | INT_OP_TO_IP | P1 | Supporting | higher | pct | active | budget | measure | volume |
| 42 | INT_PATIENT_VOLUME | P1 | Supporting | higher | num | active | budget | measure | volume |
| 57 | INT_ER_GROWTH | P1 | Supporting | higher | pct | active | budget | measure | volume |
| 58 | INT_DOCTOR_UTILIZATION | P1 | Supporting | higher | pct | active | none | measure | volume |
| 60 | INT_ACTIVATED_BEDS | P1 | Supporting | higher | pct | active | none | measure | beds |
| 25 | INT_HIGH_VALUE_REVENUE | P2 | Primary | higher | pct | active | fixed | measure | revenue |
| 26 | INT_HIGH_VALUE_CENSUS | P2 | Primary | higher | pct | active | fixed | measure | volume |
| 27 | INT_OP_REVENUE_PER_EPISODE | P2 | Supporting | higher | sar | active | budget | measure | revenue |
| 28 | INT_ANCILLARY_UTILIZATION | P2 | Supporting | higher | pct | active | budget | measure | revenue |
| 29 | INT_REVENUE_LEAKAGE | P3 | Primary | lower | pct | active | fixed | measure | revenue_cycle |
| 30 | INT_CLAIM_INITIAL_REJECTION | P3 | Supporting | lower | pct | active | fixed | measure | revenue_cycle |
| 31 | INT_ORDER_NOT_DONE | P3 | Supporting | lower | pct | active | fixed | measure | revenue_cycle |
| 32 | INT_APPROVAL_TAT | P3 | Supporting | lower | mins | active | fixed | measure | revenue_cycle |
| 33 | INT_CLAIM_FINAL_REJECTION | P3 | Supporting | lower | pct | parked | none | measure | revenue_cycle |
| 34 | INT_COST_BUDGET_VARIANCE | P4 | Primary | lower | pct | active | fixed | measure | finance |
| 35 | INT_GA_RATIO | P4 | Supporting | lower | pct | active | budget | measure | finance |
| 36 | INT_READMISSION_30D | P5 | Primary | ceiling | pct | active | fixed | measure | beds |
| 37 | INT_READMISSION_48H_CRITICAL | P5 | Primary | ceiling | pct | active | fixed | measure | beds |
| 38 | INT_HAI_RATE | P5 | Supporting | lower | pct | active | none | manual | beds |
| 39 | INT_FALL_RATE | P5 | Supporting | lower | pct | active | none | manual | beds |
| 40 | INT_PAYER_CONTRACT_ACTIVATION | P6 | Primary | higher | pct | parked | none | measure | revenue |
| 41 | INT_EXTERNAL_REFERRALS | P6 | Supporting | higher | num | active | none | measure | volume |
| 59 | INT_REFERRAL_TO_HUB | P6 | Supporting | higher | pct | parked | none | measure | volume |
| 43 | LRN_TURNOVER | L1 | Primary | lower | pct | active | fixed | measure | workforce |
| 44 | LRN_REVENUE_PER_FTE | L1 | Primary | higher | sar | active | budget | measure | workforce |
| 45 | LRN_STAFF_TO_BED | L1 | Supporting | on_target | num | active | fixed | measure | workforce |
| 46 | LRN_SAUDIZATION | L1 | Supporting | higher | pct | active | none | measure | workforce |
| 47 | LRN_VACANCY_RATE | L1 | Supporting | lower | pct | active | none | measure | workforce |
| 48 | LRN_TIME_TO_FILL | L1 | Supporting | lower | days | active | none | measure | workforce |
| 68 | LRN_CLINICAL_TO_DOCTOR | L1 | Supporting | higher | num | active | none | measure | workforce |
| 69 | LRN_STAFF_SATISFACTION | L1 | Supporting | higher | pct | active | none | manual | workforce |
| 70 | LRN_COST_PER_HIRE | L1 | Supporting | lower | sar | parked | none | measure | workforce |
| 71 | LRN_COST_PER_FIRE | L1 | Supporting | lower | sar | parked | none | measure | workforce |
| 49 | LRN_DIGITAL_ON_TIME | L2 | Primary | higher | pct | active | none | manual | workforce |
| 50 | LRN_TRAINING_COVERAGE | L2 | Supporting | higher | pct | active | none | manual | workforce |
| 51 | LRN_MANDATORY_TRAINING | L2 | Supporting | higher | pct | active | none | manual | workforce |
| 52 | LRN_COST_PER_LEARNER | L2 | Supporting | lower | sar | active | none | manual | workforce |
| 53 | LRN_DOA_COMPLIANCE | L3 | Primary | higher | pct | active | none | manual | workforce |
| 54 | LRN_AUDIT_CLOSURE | L3 | Supporting | higher | pct | active | none | manual | workforce |

**KPI names:**
- The name is the handover `KPI Catalog` name, except for KPI 2, which is "Net Revenue Growth vs Last Year".
- KPI 39 keeps the catalogue name "Fall Rate with Harm".
- The short label is the section-board label where one exists (e.g. "Net Rev Achievement (YTD vs PY)" is dropped with the merge).

**Other seed values:**
- **Fixed targets** (`map_bsc_target`, `branch_id` 0, `year` 2026, `month` 0):
  - `TARGETS_INDUSTRY` rows: 6 → 180, 9 → 0.12, 16 → 0.85, 66 → 0.005, 67 → 20, 21 → 0.70, 23 → 4, 29 → 0.05, 30 → 0.10, 31 → 0.10, 32 → 20, 36 → 0.10, 37 → 0.03, 43 → 0.06 (`scale_with_months` 1), 45 → 4, 25 → 0.18, 26 → 0.12;
  - the DAX constants: 14 → 0.65, 34 → 0;
  - KPI 15 → 0.7 on branch rows 6, 7, 8 and 0.3 on branch rows 1–5.
- **Objectives:** `_DOMAIN.objectives` code, title and question from the four board scripts. Pillar weights: Financial 0.30, Customer 0.20, Internal Process 0.35, Learning & Growth 0.15.
- **Weights:**
  - from `_V9_WEIGHT_PROFILES`: the profile of each hospital (via `_V9_HOSP_ID_TO_SHEET`) becomes `branch:<id>`, and the `Corporate` profile becomes `corporate`;
  - the merged KPI 2 weight is the sum of the old KPI 2 and 3 weights;
  - category profiles are not seeded, because each branch has its own.
- **Owners:**
  - the `KPI Catalog` owner and co-owners on `branch_id` 0;
  - a `KPI Ownership` row whose `hospital_view` alias maps to a branch (alias map below) and differs from the catalogue becomes a `branch_id` row.
  - Alias map:
    - 1 Alrabwah / Riyadh - Al Rabwah / Riyadh Al Rabwah
    - 2 Khamis / Khamis Mushait
    - 3 Jazan
    - 4 Unaizah / Qassim - Unaiza / Qassim (Unayzah)
    - 5 Madinah
    - 6 Abha
    - 7 Ghirnata / Ghirnatah / Riyadh - Ghirnatah
    - 8 Muhayil / Muhayil Asir
  - Sabya and Al Kharj rows are skipped (D9).
- **Thresholds:** one row, `kpi_code` `*`: base 85, slope 0.6, good 85, watch 70.
- **Categories:** branches 1, 4, 5 → Scale & Optimize; 2, 3 → Anchor & Protect; 6, 7, 8 → Ramp-Up & Prove.
- **Code lists:**
  - `ancillary_category`: MD, MED, CSM, RTL, MLK, PH, LAB, RAD;
  - `satisfaction_nps_role`: Hospital NPS, Physician NPS.
- **Manual values:** from `default.bsc_patient_satisfaction` (already on `.214`):
  - KPI 16 ← `prems_score_actual` (numerator = value, denominator 1);
  - KPI 66 ← `patient_complaint_rate_actual` (numerator = complaints count, denominator = 0, so that Plan 2 uses OP + ER census as the denominator).
- **Budgeted FTE:** no rows. KPI 47 shows "No data yet" until the BI manager enters them.

## Review Focus

1. **Latest edit wins, and a deleted key disappears.**
   - Situation: the BI manager inserts a second target row for a key, then a third with `is_deleted = 1`.
   - Expected: staging shows the second row's value after the second insert, and no row after the third.
   - Pinned by: Task 2 unit test `stg_ref__bsc_target` (keys `FIN_DAYS_IN_AR` and `INT_ALOS`).
2. **A branch target overrides the all-hospitals target, only for that branch.**
   - Expected: KPI 15 at Abha (6) resolves to 0.7, at Alrabwah (1) to 0.3; a KPI with only a branch-0 row resolves on all 8 branches.
   - Pinned by: Task 3 unit test `fact_bsc_target_monthly`.
3. **An annual target appears once per month of its year, and a monthly row replaces that month only.**
   - Expected: a 2027 monthly row for March changes March and leaves the other 11 months on the annual value.
   - Pinned by: Task 3, same unit test, key `INT_ALOS` 2027.
4. **The person-month workforce fact adds up to `bsc.vw_work_force` exactly.**
   - Expected: headcount, part-time doctors, FTE, resignations and Saudi heads per branch-month match the reconciled view for every closed month from January 2025.
   - Pinned by: Task 5 singular test `assert_bsc_workforce_matches_vw_work_force` and its read-only check.
5. **A weight profile falls back correctly.**
   - Expected: a branch without a `branch:<id>` profile row for a KPI gets the `corporate` weight; a KPI absent from both gets weight 0 (not NULL), so pillar scores still compute.
   - Pinned by: Task 3 unit test `fact_bsc_weight`.

## File Structure

```
scripts/bsc_config/bsc_config_ddl.sql            Task 1  CREATE TABLE IF NOT EXISTS for the 11 default.map_bsc_* tables
scripts/bsc_config/build_seed.py                 Task 1  read the handover files + decisions, write bsc_config_seed.sql
scripts/bsc_config/handover.py                   Task 1  parsers for TMDL DATATABLEs and visual.json script blocks
scripts/bsc_config/test_build_seed.py            Task 1
scripts/bsc_config/bsc_config_seed.sql           Task 1  generated INSERTs (committed, used once by Task 10)
scripts/bsc_config/apply_bsc_config.ps1          Task 10 run DDL + seed over HTTP (-DryRun, Get-Credential, refuses non-empty tables)
hnh_dwh/models/hnh/staging/reference/_reference__sources.yml   Task 2  + 11 sources
hnh_dwh/models/hnh/staging/reference/stg_ref__bsc_*.sql        Task 2  11 latest-row views
hnh_dwh/models/hnh/staging/reference/_reference__models.yml    Task 2  tests
hnh_dwh/models/hnh/staging/reference/_bsc_ref_unit_tests.yml   Task 2
hnh_dwh/models/hnh/marts/scorecard/dim_bsc_kpi.sql             Task 3
hnh_dwh/models/hnh/marts/scorecard/fact_bsc_target_monthly.sql Task 3
hnh_dwh/models/hnh/marts/scorecard/fact_bsc_weight.sql         Task 3
hnh_dwh/models/hnh/marts/scorecard/fact_bsc_manual_value.sql   Task 3
hnh_dwh/models/hnh/marts/scorecard/fact_bsc_budgeted_fte.sql   Task 3
hnh_dwh/models/hnh/marts/scorecard/_scorecard__models.yml      Task 3-6
hnh_dwh/models/hnh/marts/scorecard/_scorecard_unit_tests.yml   Task 3, 5
hnh_dwh/models/hnh/marts/conformed/hnh_dim_branch.sql          Task 4  + bsc_category, is_hospital
hnh_dwh/models/hnh/marts/conformed/dim_product_category.sql    Task 4  + is_bsc_ancillary
hnh_dwh/models/hnh/marts/scorecard/fact_bsc_workforce_monthly.sql   Task 5
hnh_dwh/tests/hnh/assert_bsc_workforce_matches_vw_work_force.sql   Task 5
hnh_dwh/models/hnh/marts/workforce/fact_recruiting_requisition.sql Task 6
hnh_dwh/models/hnh/marts/ssas/ssas_*.sql                       Task 7  new and extended views
hnh_dwh/tests/hnh/assert_mart_text_title_case.sql              Task 3  + excluded columns
docs/bsc_consumables_mapping_review.md                         Task 8
docs/bsc_config.md                                             Task 9
docs/receiving_project_config.md                               Task 9
```

---

### Task 1: Config DDL and seed generator

**Files:**
- Create: `scripts/bsc_config/bsc_config_ddl.sql`, `scripts/bsc_config/handover.py`, `scripts/bsc_config/build_seed.py`, `scripts/bsc_config/test_build_seed.py`
- Generate: `scripts/bsc_config/bsc_config_seed.sql`

**Interfaces:**
- Produces the table definitions that Tasks 2 and 10 rely on. All key and text columns are `String` unless noted; every table also ends with the four change-log columns.

| Table | Columns |
|---|---|
| `map_bsc_kpi` | `kpi_code`, `kpi_num UInt16`, `kpi_name`, `short_label`, `objective_code`, `kpi_type`, `direction`, `value_format`, `chart_hint`, `display_order UInt16`, `definition`, `status`, `target_source`, `value_source`, `detail_page` |
| `map_bsc_objective` | `objective_code`, `pillar`, `pillar_order UInt8`, `pillar_weight Float64`, `pillar_question`, `objective_title`, `objective_question`, `objective_order UInt8` |
| `map_bsc_target` | `kpi_code`, `branch_id UInt8`, `year UInt16`, `month UInt8`, `target_value Float64`, `scale_with_months UInt8`, `source_basis` |
| `map_bsc_weight` | `profile`, `kpi_code`, `weight Float64` |
| `map_bsc_threshold` | `kpi_code`, `score_base Float64`, `score_slope Float64`, `good_from Float64`, `watch_from Float64` |
| `map_bsc_owner` | `kpi_code`, `branch_id UInt8`, `owner`, `co_owners` |
| `map_bsc_hospital_category` | `branch_id UInt8`, `category` |
| `map_bsc_manual_value` | `kpi_code`, `branch_id UInt8`, `year UInt16`, `month UInt8`, `numerator Float64`, `denominator Float64`, `note` |
| `map_bsc_code_list` | `list_name`, `code` |
| `map_bsc_budgeted_fte` | `branch_id UInt8`, `year UInt16`, `budgeted_fte Float64` |

- `handover.py`:
  - `read_datatable(tmdl_path: Path, table: str) -> list[dict]`: parses a `DATATABLE(...)` partition into rows keyed by column name.
  - `read_script_block(visual_json: Path, name: str) -> object`: finds `<name> = {` or `var <name> = {` in the visual's `js` literal and returns the JSON value, with `''` unescaped and trailing commas tolerated.
- `build_seed.py`:
  - `build_rows(handover_dir: Path) -> dict[str, list[dict]]`: table name → rows.
  - `render_sql(rows: dict) -> str`: one `INSERT INTO default.<table> (...) VALUES` per table. Strings are escaped, `changed_at` is `now64(3)`, `changed_by` is `'seed'`, and `change_note` is `'seed from handover 2026-10-20'`.
  - The manual values are not built here; they come from one `INSERT ... SELECT` from `default.bsc_patient_satisfaction`, appended verbatim.
  - `main()` writes `bsc_config_seed.sql` next to the script.

- [ ] **Step 1: Write the failing tests** in `test_build_seed.py`. They use the real handover folder (`powerbi_tmdl/Hayat BSC Deliverable/00_Full Access`):

```python
def test_catalog_has_70_kpis_with_unique_codes():
    rows = build_rows(HANDOVER)["map_bsc_kpi"]
    assert len(rows) == 70
    assert len({r["kpi_code"] for r in rows}) == 70
    assert {r["kpi_num"] for r in rows} == set(range(1, 72)) - {3}

def test_merged_revenue_growth():
    k = {r["kpi_num"]: r for r in build_rows(HANDOVER)["map_bsc_kpi"]}
    assert k[2]["kpi_code"] == "FIN_REVENUE_GROWTH" and k[2]["target_source"] == "prior_year"
    assert k[2]["kpi_name"] == "Net Revenue Growth vs Last Year"

def test_parked_kpis():
    parked = {r["kpi_num"] for r in build_rows(HANDOVER)["map_bsc_kpi"] if r["status"] == "parked"}
    assert parked == {7, 19, 33, 40, 59, 61, 65, 70, 71}

def test_fixed_targets():
    t = {(r["kpi_code"], r["branch_id"]): r for r in build_rows(HANDOVER)["map_bsc_target"]}
    assert t[("FIN_DAYS_IN_AR", 0)]["target_value"] == 180
    assert t[("LRN_TURNOVER", 0)]["scale_with_months"] == 1
    assert t[("CUS_NEW_PATIENTS", 6)]["target_value"] == 0.7 and t[("CUS_NEW_PATIENTS", 1)]["target_value"] == 0.3
    assert ("CUS_NEW_PATIENTS", 0) not in t
    assert len([r for r in t.values() if r["branch_id"] == 0]) == 19

def test_weights_corporate_sum_to_one_per_pillar_set():
    w = [r for r in build_rows(HANDOVER)["map_bsc_weight"] if r["profile"] == "corporate"]
    assert abs(sum(r["weight"] for r in w) - 1.0) < 1e-6
    assert {r["profile"] for r in build_rows(HANDOVER)["map_bsc_weight"]} == {"corporate"} | {f"branch:{i}" for i in range(1, 9)}

def test_owner_rows_only_for_known_branches():
    o = build_rows(HANDOVER)["map_bsc_owner"]
    assert {r["branch_id"] for r in o} <= set(range(0, 9))
    assert len([r for r in o if r["branch_id"] == 0]) == 70

def test_categories_and_code_lists():
    r = build_rows(HANDOVER)
    assert {x["branch_id"]: x["category"] for x in r["map_bsc_hospital_category"]}[6] == "Ramp-Up & Prove"
    assert sorted(x["code"] for x in r["map_bsc_code_list"] if x["list_name"] == "ancillary_category") == \
        sorted(["MD", "MED", "CSM", "RTL", "MLK", "PH", "LAB", "RAD"])

def test_render_sql_escapes_quotes():
    sql = render_sql({"map_bsc_code_list": [{"list_name": "x", "code": "O'Neil"}]})
    assert "'O\\'Neil'" in sql and "now64(3)" in sql
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `python -m pytest scripts/bsc_config/test_build_seed.py -q`
Expected: FAIL. `ModuleNotFoundError: No module named 'build_seed'`.

- [ ] **Step 3: Write `bsc_config_ddl.sql`, `handover.py` and `build_seed.py`.**
  - The KPI table at the top of this plan is a constant `KPIS` in `build_seed.py`. Names, owners and lower-better come from `KPI Catalog`.
  - Objectives come from `_DOMAIN` in the four board `visual.json` files (paths in the handover `Notes/03 Measures.md`).
  - Weights come from `_V9_WEIGHT_PROFILES` in the BSC page visual. Owner overrides come from `KPI Ownership`.

- [ ] **Step 4: Run the tests to see them pass**

Run: `python -m pytest scripts/bsc_config/test_build_seed.py -q`
Expected: `8 passed`.

- [ ] **Step 5: Generate the seed and check it renders against the DDL offline**

Run: `python scripts/bsc_config/build_seed.py`
Expected: prints `bsc_config_seed.sql: 11 tables, <n> rows` with map_bsc_kpi 70, map_bsc_objective 17, map_bsc_hospital_category 8, map_bsc_threshold 1.

- [ ] **Step 6: Commit**

```bash
git add scripts/bsc_config
git commit -m "Generate the balanced-scorecard config tables and their first content"
```

---

### Task 2: Sources and latest-row staging views

**Files:**
- Modify: `hnh_dwh/models/hnh/staging/reference/_reference__sources.yml` (11 tables, comment `# BSC config change log (bsc ssas spec 6.2)`), `_reference__models.yml`
- Create: `hnh_dwh/models/hnh/staging/reference/stg_ref__bsc_kpi.sql`, `stg_ref__bsc_objective.sql`, `stg_ref__bsc_target.sql`, `stg_ref__bsc_weight.sql`, `stg_ref__bsc_threshold.sql`, `stg_ref__bsc_owner.sql`, `stg_ref__bsc_hospital_category.sql`, `stg_ref__bsc_manual_value.sql`, `stg_ref__bsc_code_list.sql`, `stg_ref__bsc_budgeted_fte.sql`, `_bsc_ref_unit_tests.yml`

**Interfaces:**
- Each view returns the table's key and value columns from Task 1, without the change-log columns, plus `changed_at` as `last_changed_at`. Only the latest non-deleted row per key is returned. Text is trimmed.
- The pattern, shown for `stg_ref__bsc_target`:

```sql
select kpi_code, branch_id, year, month,
       latest.1 as target_value, latest.2 as scale_with_months, latest.3 as source_basis, latest.5 as last_changed_at
from (
    select trimBoth(kpi_code) as kpi_code, branch_id, year, month,
           argMax(tuple(target_value, scale_with_months, trimBoth(source_basis), is_deleted, changed_at), changed_at) as latest
    from {{ source('reference', 'map_bsc_target') }}
    group by kpi_code, branch_id, year, month
)
where latest.4 = 0
```

- [ ] **Step 1: Write the unit test** `stg_ref__bsc_target` in `_bsc_ref_unit_tests.yml`.
  - Given three source rows for `FIN_DAYS_IN_AR`/0/2027/0 (values 180, 170 and 160; the 160 row `is_deleted` 1, latest) and two for `INT_ALOS`/0/2026/0 (4 then 3.8).
  - Expect one row: `INT_ALOS` 3.8.
  - Add the same latest-wins case for `stg_ref__bsc_kpi`: a later row changes `status` to `parked`.
- [ ] **Step 2: Write the 10 views and the sources.**
- [ ] **Step 3: Add the tests to `_reference__models.yml`:**
  - `hnh_unique_combination` on every key;
  - `accepted_values`:
    - `status` [active, parked]; `target_source` [fixed, budget, prior_year, none]; `value_source` [measure, manual];
    - `direction` [higher, lower, ceiling, on_target]; `value_format` [sar, pct, days, mins, num];
    - `kpi_type` [Primary, Supporting]; `category` [Scale & Optimize, Anchor & Protect, Ramp-Up & Prove];
    - `branch_id` 0–8 in target and owner, 1–8 in category, manual value and budgeted FTE;
    - `month` 0–12;
  - `relationships` from every `kpi_code` (except threshold `*`) to `stg_ref__bsc_kpi.kpi_code`, and from `objective_code` to `stg_ref__bsc_objective`.
- [ ] **Step 4: Render every view offline and run it read-only against an inline copy of the seed**

Run, for each view: `python scripts/render_model_sql.py stg_ref__bsc_target`
Expected: SQL ending `from default.map_bsc_target` with the outer `where latest.4 = 0`. Executing it waits for Task 10, when the tables exist.

- [ ] **Step 5: Commit** ("Read the latest balanced-scorecard config rows in staging").

---

### Task 3: Scorecard gold models

**Files:**
- Create: `hnh_dwh/models/hnh/marts/scorecard/dim_bsc_kpi.sql`, `fact_bsc_target_monthly.sql`, `fact_bsc_weight.sql`, `fact_bsc_manual_value.sql`, `fact_bsc_budgeted_fte.sql`, `_scorecard__models.yml`, `_scorecard_unit_tests.yml`
- Modify: `hnh_dwh/tests/hnh/assert_mart_text_title_case.sql` (add `dim_bsc_kpi.kpi_name`, `dim_bsc_kpi.objective_title`, `dim_bsc_kpi.definition`, `dim_bsc_kpi.owner_name` to `excluded`), `hnh_dwh/dbt_project.yml` (no change needed: `marts/` defaults apply)

**Interfaces:**
- **`dim_bsc_kpi`** (order by `bsc_kpi_key`). One row per KPI:
  - `bsc_kpi_key Int64` (inline hash of `kpi_code`), `kpi_code`, `kpi_num`, `kpi_name`, `short_label`;
  - `pillar`, `pillar_order`, `pillar_weight`, `pillar_question`, `objective_code`, `objective_title`, `objective_question`, `objective_order`;
  - `kpi_type`, `direction`, `value_format`, `chart_hint`, `display_order`, `definition`;
  - `status`, `target_source`, `value_source`, `detail_page`;
  - `owner`, `co_owners` (branch 0 rows);
  - `score_base`, `score_slope`, `good_from`, `watch_from` (the KPI's threshold row, else `*`);
  - `corporate_weight Float64` (the `corporate` profile weight, 0 when absent; Plan 2 uses it when several hospitals are selected);
  - `is_active UInt8` (`status = 'active'`).
- **`fact_bsc_target_monthly`** (order by `(bsc_kpi_key, branch_key, month_date_key)`). Columns: `bsc_kpi_key`, `branch_key UInt8` (1–8), `month_date_key Int32` (first day of the month, YYYYMMDD), `target_value Float64`, `scale_with_months UInt8`, `source_basis`.
  - Resolution order for (KPI, branch, month): branch monthly row → branch annual row → branch-0 monthly row → branch-0 annual row.
  - Months: every month of each target's year up to December, from `dim_date`.
- **`fact_bsc_weight`**. Columns: `bsc_kpi_key`, `branch_key` (1–8), `weight Float64`.
  - Every active KPI × every branch.
  - Weight = the `branch:<id>` row, else `corporate`, else 0.
- **`fact_bsc_manual_value`**. Columns: `bsc_kpi_key`, `branch_key`, `month_date_key`, `numerator Float64`, `denominator Float64`, `note`.
- **`fact_bsc_budgeted_fte`**. Columns: `branch_key`, `year_date_key` (1 January, YYYYMMDD), `budgeted_fte Float64`.

- [ ] **Step 1: Write the unit tests** in `_scorecard_unit_tests.yml`:
  - **`fact_bsc_target_monthly`:**
    - KPI 15 branch rows 6 = 0.7 and 1 = 0.3 for 2026 → the March 2026 rows give 0.7 at branch 6 and 0.3 at branch 1.
    - `INT_ALOS` branch-0 annual 2027 = 4 plus a branch-0 monthly 2027-03 = 3.5 → branch 2 gives 4 in February and 3.5 in March.
    - Each (KPI, branch, year) annual target gives 12 rows.
  - **`fact_bsc_weight`:**
    - `branch:6` has `FIN_NET_REVENUE` 0.05, `corporate` has 0.042 → branch 6 = 0.05, branch 1 = 0.042.
    - A KPI with no weight rows → 0 on all branches.
    - `dim_bsc_kpi.corporate_weight` for `FIN_NET_REVENUE` = 0.042.
  - **`dim_bsc_kpi`:** a KPI with its own threshold row gets it; the others get the `*` row.
- [ ] **Step 2: Implement the five models.**
- [ ] **Step 3: Add tests to `_scorecard__models.yml`:**
  - `unique`/`not_null` on `bsc_kpi_key` and `kpi_code`;
  - `hnh_unique_combination` on each fact's key;
  - `relationships` from each fact's `bsc_kpi_key` to `dim_bsc_kpi`;
  - `accepted_values` on `branch_key` 1–8 in every fact;
  - a `warn` singular test `warn_bsc_fixed_target_missing` (active KPIs with `target_source = 'fixed'` without a target row for a branch in the current year).
- [ ] **Step 4: Render the models offline**

Run: `python scripts/render_model_sql.py fact_bsc_target_monthly`
Expected: plain SQL, no Jinja left. Running it waits for Task 10.

- [ ] **Step 5: Commit** ("Resolve balanced-scorecard targets, weights and manual values in gold").

---

### Task 4: Branch category and ancillary flag

**Files:**
- Modify: `hnh_dwh/models/hnh/marts/conformed/hnh_dim_branch.sql`, `hnh_dwh/models/hnh/marts/conformed/dim_product_category.sql`, `_conformed__models.yml`

**Interfaces:**
- **`dim_branch`** gains:
  - `bsc_category String`, from `stg_ref__bsc_hospital_category`; `'None'` for 0, 100 and unmapped branches;
  - `is_hospital UInt8`: 1 for branches 1–8, 0 for Group (0) and Head Office (100).
- **`dim_product_category`** gains `is_bsc_ancillary UInt8`: 1 when `category_code` is in `stg_ref__bsc_code_list` where `list_name = 'ancillary_category'`. Matched case-insensitively and trimmed.

- [ ] **Step 1: Extend the conformed unit tests:**
  - `dim_branch`: branch 6 → `Ramp-Up & Prove` and `is_hospital` 1; branch 100 → `None` and 0.
  - `dim_product_category`: `LAB` → 1, `XRY` → 0.
- [ ] **Step 2: Implement.** The `union all` rows for 0 and 100 get the literal values.
- [ ] **Step 3: Check offline that today's codes match** (read-only):

Run: `powershell -NoProfile -Command "Import-Module .\scripts\HnhCh.psm1; Invoke-HnhSelect -Dsn HNH_Gold -Sql \"select countIf(category_code in ('MD','MED','CSM','RTL','MLK','PH','LAB','RAD')) n from gold.dim_product_category\""`
Expected: a count > 0. Record it in the commit message; it is the number of rows that will be flagged.

- [ ] **Step 4: Commit** ("Add the scorecard category to branches and the ancillary flag to product categories").

---

### Task 5: Person-month workforce fact

**Files:**
- Create: `hnh_dwh/models/hnh/marts/scorecard/fact_bsc_workforce_monthly.sql`, `hnh_dwh/tests/hnh/assert_bsc_workforce_matches_vw_work_force.sql`
- Modify: `_scorecard__models.yml`, `_scorecard_unit_tests.yml`

**Interfaces:**
- **Grain:** one row per (`branch_key`, `month_date_key` = month end YYYYMMDD, `person_id`, `row_type`).
- **Columns:**
  - `person_id String`, `staff_key Int64`, `employee_key Int64` (-1 when not Fusion);
  - `row_type`: `head`, `pt_doctor` or `resignation`;
  - `headcount UInt8` (1 for head and pt_doctor, 0 for resignation);
  - `fte Float64` (Fusion FTE, 1 per paid person, 0.5 per part-time doctor, 0 for resignation);
  - `is_doctor UInt8`, `is_medical UInt8`, `is_saudi UInt8` (0 for `pt_doctor`, by the user decision of 2026-10-13);
  - `is_resignation UInt8`;
  - `data_source` (`oasis` or `fusion`).
- **Window:** closed months from `hnh_history_start_date` to the last closed month. This is wider than the bsc view: all history, not just the last year.
- **Logic:** exactly the CTEs of `bsc_vw_work_force.sql`, left at person level:
  - `people` → `head` rows;
  - `part_time` before its `uniqExact` → `pt_doctor` rows;
  - each `resignations` branch → one row per leaver: `staff`-based rows for branches 1–5 and pre-Fusion months, `hnh_fact_worker_movement` voluntary leavers for 6–8 from `hnh_hr_snapshot_start`;
  - `is_doctor` = `dim_staff.category = 'DOCTORS'`; `is_medical` = `classification in ('NURSE','DOC')`. A `pt_doctor` has both = 1.

- [ ] **Step 1: Write the unit test.** Reuse the `bsc_vw_work_force` unit-test inputs (staff 13, 14, 15, 17, and the paid and Fusion people) and assert row-level outputs:
  - staff 15, revenue-only doctor → one `pt_doctor` row, fte 0.5, `is_saudi` 0;
  - staff 13, on payroll → `head`, not `pt_doctor`;
  - a branch-7 voluntary leaver → a `resignation` row;
  - a branch-2 Oasis resignation → a `resignation` row.
- [ ] **Step 2: Write the singular test** `assert_bsc_workforce_matches_vw_work_force`. It returns branch-months where any of these differ between the fact and `bsc_vw_work_force`, from January of last year:
  - Σ`headcount` vs `headcount`;
  - Σ`headcount` where `row_type = 'pt_doctor'` vs `pt_doctors_headcount`;
  - Σ`fte` vs `FTE` (tolerance 0.001);
  - count of `is_resignation` vs `resignations`;
  - Σ`is_saudi` vs `saudi_headcount`;
  - Σ`headcount` where `is_doctor` vs `doctors_headcount`;
  - Σ`headcount` where `is_medical` vs `medical_headcount`.
- [ ] **Step 3: Implement the model.**
- [ ] **Step 4: Run the comparison read-only.** Render the fact inline and compare it with the built `bsc.vw_work_force` on `.214`:

Run: `python scripts/render_model_sql.py fact_bsc_workforce_monthly --out C:\...\scratchpad\wf.sql`, then `powershell -File scripts\query_model.ps1` with the comparison query of Step 2 over `(rendered SQL)` against `bsc.vw_work_force`.
Expected: 0 rows. Any row: stop and report the branch-month and column.

- [ ] **Step 5: Commit** ("Keep the vw_work_force rules at person level for the scorecard measures").

---

### Task 6: Recruiting requisitions in gold

**Files:**
- Create: `hnh_dwh/models/hnh/marts/workforce/fact_recruiting_requisition.sql`
- Modify: `_workforce_marts__models.yml`

**Interfaces:**
- **Columns:**
  - `requisition_id`, `branch_key UInt8`;
  - `approved_date_key Int32`, `filled_date_key Nullable(Int32)`;
  - `number_to_hire UInt32`;
  - `days_to_fill Nullable(Int32)`: NULL when not filled, or when the fill is before approval.
- **Rows:** not deleted, approved, branch 1–8. The filter and join are the `requisitions` CTE of `bsc_vw_work_force.sql`.

- [ ] **Step 1: Write the model and its tests** (`unique` `requisition_id`; `accepted_values` `branch_key` 1–8).
- [ ] **Step 2: Check row counts read-only.** The count of the rendered model equals `select count() from stg.stg_fusion__recruiting_requisitions q join gold.hr_department ...` as in the bsc CTE.
Expected (2026-10-20): about 89 rows. Record the exact number.
- [ ] **Step 3: Commit** ("Model recruiting requisitions in gold").

---

### Task 7: SSAS views

**Files:**
- Create in `hnh_dwh/models/hnh/marts/ssas/`:
  - `ssas_dim_bsc_kpi.sql`: `{{ hnh_ssas_view('dim_bsc_kpi', floats=['pillar_weight','score_base','score_slope','good_from','watch_from','corporate_weight']) }}`
  - `ssas_fact_bsc_target_monthly.sql`: `decimals=['target_value']`, `int_flags=['scale_with_months']`
  - `ssas_fact_bsc_weight.sql`: `floats=['weight']`
  - `ssas_fact_bsc_manual_value.sql`: `decimals=['numerator','denominator']`
  - `ssas_fact_bsc_budgeted_fte.sql`: `decimals=['budgeted_fte']`
  - `ssas_fact_gl_fs_monthly.sql`:
    - `decimals=['opening_balance','movement','opening_journal_amount','closing_balance']`;
    - `extra=['toInt32(toYYYYMMDD(t.month_start)) as month_date_key']`;
    - `drop=['month_start']`.
  - `ssas_fact_bsc_workforce_monthly.sql`:
    - `floats=['fte']`;
    - `int_flags=['headcount','is_doctor','is_medical','is_saudi','is_resignation']` (measures sum them).
  - `ssas_fact_recruiting_requisition.sql`
- Modify:
  - `ssas_fact_encounter.sql` and `ssas_fact_admission.sql`: add
    - `extra=["if(ep.is_referral_policy = 1, 'Yes', 'No') as is_referral_policy"]`,
    - `joins='left join (select episode_key, is_referral_policy from ' ~ ref('fact_episode') ~ ') as ep on ep.episode_key = t.episode_key'`.
    - `episode_key` stays in `drop`. Keep the existing `drop`/`floats` lists.
  - `ssas_agg_clinic_capacity_daily.sql`: `extra=['toInt64(t.legacy_capacity_slots) as bsc_capacity_slots']`. The macro drops `legacy_*`, so the column is re-added under a new name.

**Interfaces:** SSAS table and column names follow in Plan 2. These views are the contract it builds on.

- [ ] **Step 1: Write the views.**
- [ ] **Step 2: Check that the macro arguments name real columns.** Render is not possible for `hnh_ssas_view`, so list each model's columns from its SQL and compare with every `drop`/`floats`/`decimals`/`int_flags` name by hand. The typo guard enforces this at build time in Task 10.
- [ ] **Step 3: Commit** ("Expose the scorecard config and facts to SSAS").

---

### Task 8: Fusion consumables mapping review (decision on KPI 63)

**Files:**
- Create: `docs/bsc_consumables_mapping_review.md`

- [ ] **Step 1: Query read-only.**
  - Find the Fusion natural accounts of 2026 with expense movement whose description or FS caption suggests medical supplies: `ilike '%consum%' or ilike '%supply%' or ilike '%medical%'`, from `gold.dim_gl_account` → `gold.dim_fs_line` → `gold.fact_gl_fs_monthly`.
  - Also find the Oasis accounts that today map to caption `medical consumables` (`gold.dim_oasis_gl_account`).
- [ ] **Step 2: Write the review.**
  - **Table 1:** the Oasis accounts on `medical consumables` with their 2025 amounts.
  - **Table 2:** candidate Fusion accounts with their current caption and 2026 amounts, and a "map to medical consumables?" column for the user.
  - **The one sentence to act on:** the user adds the chosen accounts in `map_fs_account` (caption `medical consumables`) and reloads with `load_fs_mapping.ps1`.
- [ ] **Step 3: Commit** ("Review the Fusion accounts for the medical consumables caption").

---

### Task 9: Editing guide and receiving-project notes

**Files:**
- Create: `docs/bsc_config.md`
- Modify: `docs/receiving_project_config.md` (the new `marts/scorecard/` folder needs no config block; list the new sources)

- [ ] **Step 1: Write `docs/bsc_config.md`.** It is written for the BI manager. One section per table, each with:
  - its columns and allowed values (copied from the Task 2 accepted values);
  - an `INSERT` example;
  - a "see the history" query.

  It also covers:
  - how to park or unpark a KPI;
  - how to enter a month of manual values;
  - the refresh path: nightly, or `dbt build --select stg_ref__bsc_*+` then `process.ps1 -Mode Daily -Force` (approval);
  - "check your edit": `dbt test --select stg_ref__bsc_*`.
- [ ] **Step 2: Commit** ("Document how to edit the scorecard configuration").

---

### Task 10: Apply on the server (approval required at each step)

**Files:**
- Create: `scripts/bsc_config/apply_bsc_config.ps1`
  - Parameters: `-Url 'http://172.22.25.214:8123/'`, `-DryRun`.
  - Runs `bsc_config_ddl.sql`, then refuses to seed a table that already has rows, then runs `bsc_config_seed.sql`.
  - Uses `Get-Credential`, and follows `load_bsc_reference.ps1` for HTTP posting.

- [ ] **Step 1: Dry run**

Run: `powershell -ExecutionPolicy Bypass -File scripts\bsc_config\apply_bsc_config.ps1 -DryRun`
Expected: lists 11 CREATE statements and the row count per table; no connection to `.214`.

- [ ] **Step 2: Ask the user, then apply.**
Expected: 11 tables created; row counts equal to the dry run. The manual-value `INSERT ... SELECT` reports its row count.

- [ ] **Step 3: Read-only checks**

Run: `select count() from default.map_bsc_kpi` → 70. Then render `stg_ref__bsc_kpi`, run it through `query_model.ps1` → 70 rows, 9 `parked`.

- [ ] **Step 4: Ask the user, then build in the receiving project.**
  - Copy the changed `hnh/` folders as `docs/receiving_project_config.md` describes.
  - Run `dbt build --select stg_ref__bsc_*+ hnh_dim_branch+ dim_product_category+ fact_bsc_workforce_monthly+ fact_recruiting_requisition+ ssas_fact_encounter ssas_fact_admission ssas_agg_clinic_capacity_daily`.
  - Expected: every model and test passes (the `warn_` test may warn).
- [ ] **Step 5: Regenerate the SSAS view contracts.**

Run: `python scripts/gen_view_contracts.py` (needs `clickhouse_connect` and `HNH_CH_*`, as the SSAS README says).
Expected: the YAML gains the 8 new views and the 4 changed ones. Commit the YAML.

- [ ] **Step 6: Commit** ("Apply the scorecard configuration and build its DWH layer").
