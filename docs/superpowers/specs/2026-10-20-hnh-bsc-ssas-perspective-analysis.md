# Hayat Balanced Scorecard on `HNH_Analytics`: analysis and plan

- **Date:** 2026-10-20
- **Status:** Analysis and proposal. Nothing is built. Decisions taken on 2026-10-20 are recorded in section 9 and Appendix B.
- **Inputs:**
  - The handover project `powerbi_tmdl/Hayat BSC Deliverable/`: the PBIP semantic model and report, and the `Notes/` folder.
  - The SSAS model `ssas/HNH_Analytics/`.
  - The `bsc` views spec `2026-10-12-hnh-bsc-views-design.md`.
  - The reference-data loaders in `scripts/`.
- **Requirements from the request:**
  1. Produce the same scorecard from the SSAS model, through a new BSC perspective.
  2. Apply the SSAS model's own security (`HNH Readers`), not the report's KPI-owner security.
  3. Keep every configuration item and future change in static tables in the DWH layer, not in the SSAS model.
  4. Add drill-through to detail for each KPI.

---

## 1. Summary

**Can we produce the same report from SSAS?** Yes for its content, though not by repointing the existing file.

| Content | Carried over |
|---|---|
| The 71-KPI catalogue and its four pillars | Yes |
| Hospital, category and period selection | Yes |
| Overview score, pillar scores, section boards, hospital comparison and the owner view | Yes |

Repointing the handover pbix at SSAS as it stands would break requirements 3 and 4:

- **Configuration lives in the model and the visuals.** The handover model is about 258 measures over calculated tables. Its configuration is typed into the model (DATATABLEs) and into roughly 2.5 MB of JavaScript duplicated across 9 custom visuals: KPI list, owners, weights, thresholds, hospital ids and categories.
- **The model breaks SSAS conventions.** Our model bans calculated tables (BPA rule `HNH_NO_CALCULATED_TABLES`).
- **The boards cannot drill through.** They use the 2018 "D3JSVisual" (plugin API 1.9), which cannot start a drill-through, a tooltip or a cross-filter.

**Chosen approach (decided 2026-10-20).** It is detailed in section 6.

- Every KPI is an SSAS measure over the model's facts, so it follows the filter context: any period, YTD and prior year through the Time Calculation group, any set of hospitals, and exact distinct counts.
- All configuration lives in ClickHouse `default` tables, which the BI manager edits with SQL:
  - KPI catalogue, labels and parked flag;
  - targets, weights, thresholds and owners;
  - hospital categories, code lists and manual KPI values.
- The warehouse adds the facts the measures need, such as the combined Oasis + Fusion GL and a person-month workforce table.
- The report is rebuilt over a live connection: a new branded custom visual for the scorecard pages, native visuals for the drill-through pages.
- Drill-through goes from KPI to a KPI detail page, then to the transaction-level facts already in the model.

**What the scorecard actually shows today.** Only 45 of the 71 KPIs return a value (section 3.2). The other 26 have no measure, no data, or columns that do not exist on the warehouse the report reads. The rebuild should start with those 45, then add the rest in the groups set out in section 7.

---

## 2. What the handover project is

### 2.1 Model (`Hayat_BSC_Full_RS.SemanticModel`)

| Part | What it does |
|---|---|
| `vw_*` tables (10) | Import queries from ClickHouse `bsc.*` through DSN `chDWH` (the **old** server, `.165`), cut at the current month |
| `01_Financial`, `02_Customer`, `03_Internal Process`, `04_Learning & Growth` | Calculated tables keyed on hospital × month. Every input is a `LOOKUPVALUE` calculated column. 245 measures (`FIN_`, `CSR_`, `INT_`, `LRN_`), each KPI as `_actual` / `_target` |
| `00_Overview` | Calculated table that unions 71 `SELECTCOLUMNS` blocks (hospital × month × KPI). `OV_actual` / `OV_target` are a 71-branch `SWITCH` on the KPI name |
| `KPI Catalog`, `KPI Ownership` (1,214 rows, 21 hospital-name aliases), `TARGETS_INDUSTRY` (17 rows) | Typed DATATABLEs |
| `Hospital View` + bridge | "Corporate" equals all 8 hospitals |
| `Period From` / `Period To` + range bridge | From–to month range. No DAX time intelligence; YTD and prior year are precomputed in Power Query or done by hand-written shifts of `period_id − 100` |
| `vw_hospital.category` | Hard-coded in M: {1,4,5} Scale & Optimize, {2,3} Anchor & Protect, {6,7,8} Ramp-Up & Prove |
| Role `Viewer Access` | Email to role (CEO/COO/…). Filters `00_Overview` by KPI owner. A `{"*","Full"}` fallback gives every unknown login everything |

### 2.2 Report (`Hayat_BSC_Full_RS.Report`, 10 pages)

**Pages:**
- BSC (landing gauge)
- BSC Overview, plus its Expanded and Ownership variants
- Financial, Customer, Internal Process, Learning & Growth (section boards)
- Hospital Comparison
- Instruction Manual (hidden)

**What every page has:**
- **Slicers:** four synced ones (Hospital View, Category, From month, To month).
- **Navigation:** native transparent buttons laid over pills drawn by a D3 header.

**How the boards work:**
- **Data:** every KPI board is a D3JSVisual running 130–385 KB of JavaScript, fed by one table-shaped field well.
- **Scoring is computed in JavaScript, not DAX:**
  - variance % = (a − t) / |t|, reversed for lower-is-better KPIs;
  - score = clamp(85 + 0.6 × variance);
  - status: good ≥ 85, warn ≥ 70, bad below that.
- **Pillar and overall scores** are weighted means of the unit score:
  - unit score = a/t, t/a, a ceiling rule, or an on-target band;
  - weights come from `_V9_WEIGHT_PROFILES` (14 profiles × 21 name aliases);
  - pillar weights are Financial 0.30, Customer 0.20, Internal Process 0.35, Learning & Growth 0.15.

**What the boards cannot do:**
- **Interact with the rest of the report.** They create no selection ids and have no context menu, tooltips or URL launch. A click changes state inside the visual only. The overview's "↗ Dashboard" link is a stub (`/* drill-through not configured */`).
- **Hide KPIs securely on the section pages.** The hiding happens in the browser only. The `Access Keys` tables relate one-way to the pillar tables, so every figure still reaches the browser and is visible through Export data.

### 2.3 Configuration and where it lives today

To change one KPI, the notes (`Notes/06 Changing a KPI.md`) list up to 15 places to edit, across TMDL files and `visual.json` script strings. The notes also warn that reformatting a `visual.json` "has broken a board before".

| Configuration | Written in |
|---|---|
| KPI list, labels, pillar, objective, type | `KPI Catalog`; `_rows` ×4; `_kpis` ×4; `_HC.kpis` |
| Lower-is-better / direction | `KPI Catalog`; `lowerBetter` ×6; `dir` in weight profiles |
| Chart type, number format | `kpiCharts`; `kpiColumns.fmt`; `_kpiFmt`; `00_Overview` `fmt` |
| Owners | `KPI Catalog`; `KPI Ownership`; `_KPI_OWNERS` ×4; `_V9_OWNERS` ×6 |
| KPI weights, pillar weights | `_V9_WEIGHT_PROFILES` (95 KB × 9 copies); `_V9_PERSPECTIVE_W` |
| Fixed targets | `TARGETS_INDUSTRY`, plus fallback constants repeated in DAX. Also constants in measures: Patient Retention 0.65; New Patient Acquisition 0.7 or 0.3 by hospital; Budget Variance 0 |
| Thresholds | JavaScript constants: 85, 70, 0.6, −10 |
| Hospital ids, aliases, category | `vw_hospital` M seed; `_HC.hospitals`; `_V9_HOSP_*`; `_CANON_HOSPS` |
| Formula constants | Leakage × 10; ancillary target = OP target × 0.6 (in dbt); GL caption strings; the "active hospital" rule for BOR and OP utilisation |

---

## 3. KPI status

### 3.1 Coverage groups

| Group | KPIs | Count | Meaning |
|---|---|---|---|
| **A: live today** | 1–6, 8–16, 18, 20–32, 34–37, 42–45, 55–57, 63, 64, 66, 67, 68 | 45 | Value returned today. 13, 16 and 66 come from the hand-loaded `patient_satisfaction` sheet. 68 has no target |
| **B: derivable from gold** | 7, 33, 41, 46, 47, 48, 58, 60, 62 | 9 | Blank today, but the data is in gold or in the new `bsc` views on `.214`, so a definition and a metric are enough |
| **C: no source system** | 17, 38, 39, 49, 50, 51, 52, 53, 54, 69 | 10 | PROMs, HAI, falls, digital initiatives, training (×3), DOA, audit closure, staff satisfaction. Needs monthly manual entry, or a future source (Fusion Learning for training) |
| **D: needs a definition first** | 19, 40, 59, 61, 65, 70, 71 | 7 | Non-eligible referral, payer contract activation, referral to hub, referral conversion, breakeven gap, cost per hire / fire. No agreed formula and no data |

The full per-KPI list, with source and drill-through target, is in Appendix A.

### 3.2 Why 26 are blank today

- **Learning & Growth asks for columns the old warehouse does not have.**
  - The report reads `bsc.vw_work_force` on the old server, which has 8 columns.
  - The measures ask for `saudi_headcount`, `approved_positions`, `vacancies_filled`, `training_cost`, …, which Power Query creates as null.
  - The new `bsc.vw_work_force` on `.214` adds `saudi_headcount`, `vacant_positions`, `filled_positions` and `avg_time_to_fill_days`. That brings back 46 and part of 47–48 (Oracle Recruiting covers mostly Abha and Head Office).
- **KPIs 7 and 65 have no measure at all.** The Financial board references `FIN_net_collection_rate_*` and `FIN_breakeven_revenue_gap_*`, which do not exist.
- **The rest are `BLANK()` placeholders** (17, 19, 33, 38–41, 58–62).

### 3.3 Defects in the handover model to fix, not copy

| # | Defect |
|---|---|
| 1 | KPI 39 is "Fall Rate with Harm" in the catalogue and "Patient Falls Rate" in the overview, so the catalogue join misses it |
| 2 | Return on Asset compares a period ratio with an annual 12% target (Q1 9.2% against 12%) |
| 3 | Insurance TAT and Patient Satisfaction are unweighted averages of monthly figures |
| 4 | Revenue Leakage multiplies by 10 (user-approved, but hidden in a measure) |
| 5 | `02_Customer` and `03_Internal Process` are keyed on `vw_customer`, so finance, bed and RCM months missing from it are dropped. A duplicate `LOOKUPVALUE` key also fails silently to BLANK |
| 6 | Duplicate measures: Budget Variance, G&A, Ancillary, Total Patient Volume and Census-HV each exist twice |
| 7 | KPI Ownership uses hospital-name aliases that mostly don't match `Hospital View`. It also includes two hospitals not in the warehouse (Jazan - Sabya, Riyadh - Al Kharj) |
| 8 | Sparklines have no data (`*_ytd_trend` measures are BLANK) |
| 9 | It reads the old server, so finance after each branch's Fusion go-live is missing or wrong (the reason for the `bsc` views spec) |

---

## 4. What the SSAS model offers today

### 4.1 Existing measures

Matched against `HNH_Analytics` measures: 16 KPIs have a matching measure, 38 have base measures but no ratio, and 17 have no data. The main differences from the scorecard definitions:

| Area | Scorecard (`bsc` views on `.214`) | `HNH_Analytics` |
|---|---|---|
| Finance (KPIs 1–6, 9, 10, 34, 35, 56, 62–64) | `gold.fact_gl_fs_monthly`: Oasis before each branch's Fusion cutover, Fusion after, unposted included, from 2024 | Fusion GL only, from 2026. `Income Statement` uses posted journals, where Oasis-feed revenue is almost zero (Jazan Jul-26: −2.8M posted against 21.0M including unposted) |
| Claim final rejection | ÷ adjudicated submitted amount | ÷ approved + rejected |
| Turnover | Resignations from Oasis for branches 1–5, Fusion for 6–8 | Fusion leavers only |
| OP / doctor utilisation | `legacy_capacity_slots` | Inflated `Slots Total` (O-B3) |
| Revenue per doctor, FTE | Includes part-time doctors seen only through revenue | Not derivable |

### 4.2 What it already provides

| Asset | Use for the scorecard |
|---|---|
| `Branch`, `Date`, `Time Calculation` (YTD, PY, YoY, MoM, Rolling 12M) | Hospital and period slicing, YTD and prior-year KPIs |
| `HNH Readers` | Branch security, the rule the request asks for |
| Detail facts | Drill-through targets (section 6.3): Charge Lines, Encounters, Admissions, Episodes, Bed Occupancy, Claim Lines, Pre-auth Lines, Order Lines, GL Journal Lines, Headcount, Worker Movements, Survey Answers |
| Conventions and tooling | Perspective generation, measure guards, measure-vs-SQL tests, BPA rules |

---

## 5. Options

| | **A. Port the handover model into SSAS** | **B. KPI fact in the DWH, generic measures (recommended)** | **C. One SSAS measure per KPI on existing facts** |
|---|---|---|---|
| **How** | Copy the four pillar tables, `00_Overview`, the bridges and 258 measures; keep the D3 visuals | dbt computes `numerator`, `denominator`, `target` per KPI × branch × month from config tables. SSAS gets a few small tables and about 12 generic measures. The report is rebuilt on a new data-driven custom visual | Write about 71 actual and 71 target measures over `Charge Lines`, `Admissions`, GL and other facts; targets from a config table |
| **Configuration in DWH tables** | No: DATATABLEs and JavaScript stay | **Yes**: catalogue, targets, weights, thresholds, owners, categories, manual values, KPI composition | Partly: targets and weights yes, formulas no (each change is an SSAS deploy) |
| **Drill-through** | No (D3 boards) | **Yes**: KPI to detail page to transaction facts | Yes, and the KPI itself can be sliced by department, payer or doctor |
| **SSAS conventions** | Breaks them (calculated tables, `LOOKUPVALUE` columns) | Fits them (`gold.ssas_*` views, `model_config.py`, tests) | Fits them |
| **Matches the scorecard's definitions** | Yes | Yes: reuses the reconciled `bsc` logic | No, until the finance gap (4.1) is closed: needs `fact_gl_fs_monthly` in SSAS and many definition changes |
| **Effort** | Medium, and the result is fragile | Medium–large | Large |
| **Verdict** | Rejected: fails requirements 3 and 4 | Recommended first; replaced on 2026-10-20 | **Chosen 2026-10-20 (D12), with all configuration kept in DWH tables (section 6)** |

---

## 6. Chosen design: KPI measures in SSAS, configuration in the DWH

Decided 2026-10-20 (D12):
- **Formulas are SSAS measures** over the model's facts, so every KPI follows the filter context: any date range, YTD or prior year from the Time Calculation group, any set of hospitals, and exact distinct counts.
- **Everything that is not a formula** lives in ClickHouse `default` tables: the catalogue, labels, active/parked flag, targets, weights, thresholds, owners, hospital category, manual values, and code lists such as ancillary categories and survey questions.

This replaces the monthly KPI table of option B. Option B's two-step "metric" and "composition" layer is not built.

### 6.1 Architecture

```
BI manager: INSERT a new version row (SQL)                                   <- ClickHouse write
        |
default.map_bsc_*   (insert-only change logs: key, values, changed_at, changed_by, change_note, is_deleted)
        |  latest row per key
stg_ref__bsc_*  ->  gold.dim_bsc_kpi, fact_bsc_target_monthly, fact_bsc_weight, fact_bsc_manual_value,
                    dim_branch (+ bsc_category, is_hospital), dim_product_category (+ is_bsc_ancillary)
gold detail facts (existing or new) ->  fact_gl_fs_monthly, fact_bsc_workforce_monthly (new),
                    fact_recruiting_requisition (new), fact_encounter (+ is_referral_policy),
                    agg_clinic_capacity_daily (+ legacy_capacity_slots in the ssas view)
        |
gold.ssas_* views  ->  HNH_Analytics tables  ->  KPI measures + dispatcher + scoring measures
        |  perspective "Balanced Scorecard", role HNH Readers
Power BI Report Server report (live connection, HNH Balanced Scorecard visual, drill-through pages)
```

### 6.2 DWH layer: configuration and the facts the measures need

**Config tables**

These are reference tables in ClickHouse `default` (`default.map_bsc_*`), and the tables themselves are the source of truth. There is no workbook, no CSV and no loader script (decision D6). The BI manager edits them directly with SQL (decision D7).

Each table is an **insert-only change log**:
- **Columns:** the key, the values, then `changed_at DateTime64(3)`, `changed_by String`, `change_note String` and `is_deleted UInt8`.
- **How a change is made:** insert a new row for the key. Nothing is ever updated in place: there are no `ALTER ... UPDATE` mutations.
- **Delete:** a row with `is_deleted = 1`.
- **Current value:** the `stg_ref__bsc_*` view takes the latest row per key (`argMax(..., changed_at)`) and drops deleted keys.
- **History and undo:** every value ever set, who set it and why stays queryable; to undo, insert the previous values again.

The tables are created once, and their first content is generated from the handover project and the decisions in Appendix B. Both steps are ClickHouse writes and need approval. Section 6.2.1 shows the editing routine.

| Table | Key | Holds |
|---|---|---|
| `map_bsc_kpi` | `kpi_code` | `kpi_num`, name, short label, pillar, objective code, type (Primary / Supporting), direction (higher / lower / ceiling / on_target), format (`sar`, `pct`, `days`, `mins`, `num`), chart hint, display order, definition text, status (`active` / `parked`), target source (`fixed`, `budget`, `prior_year`, `none`), detail page |
| `map_bsc_objective` | `objective_code` | Pillar, title, question, order, and the pillar weights 0.30 / 0.20 / 0.35 / 0.15 |
| `map_bsc_target` | `kpi_code`, `branch_id` (0 = every hospital), year, month (0 = annual) | Fixed target value, basis, note. Replaces `TARGETS_INDUSTRY` and the DAX constants |
| `map_bsc_weight` | profile (`category:<name>` or `branch:<id>`), `kpi_code` | KPI weight inside its pillar. Replaces `_V9_WEIGHT_PROFILES` |
| `map_bsc_threshold` | `kpi_code` (`*` = default) | Score base 85, slope 0.6, good from 85, watch from 70 |
| `map_bsc_owner` | `kpi_code`, `branch_id` (0 = Corporate) | Owner and co-owners (information only, decision D4) |
| `map_bsc_hospital_category` | `branch_id` | Category (Scale & Optimize, Anchor & Protect, Ramp-Up & Prove) |
| `map_bsc_manual_value` | `kpi_code`, `branch_id`, year, month | Numerator, denominator, note: the group C KPIs, and PREMs and complaints, which today come from the hand-loaded sheet |
| `map_bsc_code_list` | `list_name`, `code` | Code lists that measures filter on: `ancillary_category` (MD, MED, CSM, RTL, MLK, PH, LAB, RAD), `satisfaction_question` (the survey questions behind KPI 13) |

**Gold models built from them** (in `marts/scorecard/`, schema `gold`; not `marts/bsc/`, which is the old-server compatibility schema):

| Model | Grain | Purpose |
|---|---|---|
| `dim_bsc_kpi` | KPI | Catalogue, objective and pillar attributes, sort keys, thresholds, Corporate owner |
| `fact_bsc_target_monthly` | KPI × branch × month | Fixed targets resolved to months (an annual row repeats on every month of its year; a branch row overrides the all-hospitals row) |
| `fact_bsc_weight` | KPI × branch | Weight resolved from the branch's category profile or a branch profile |
| `fact_bsc_manual_value` | KPI × branch × month | Manual numerator and denominator |
| `dim_branch` | + `bsc_category`, `is_hospital` | Category for the slicer; `is_hospital` = branches 1–8 (decision D5) |
| `dim_product_category` | + `is_bsc_ancillary` | From the `ancillary_category` list |

**New or extended detail facts**, so that the measures can reproduce the reconciled `bsc` definitions:

| Model | Grain | Why |
|---|---|---|
| `fact_gl_fs_monthly` (exists) | Branch × month × source × account | Finance KPIs on the combined Oasis + Fusion GL. New SSAS table `GL FS Monthly` |
| `fact_bsc_workforce_monthly` (new) | Person × branch × month | The `vw_work_force` rules at person level: payroll heads before 2026, Fusion heads from 2026, part-time doctors (revenue-only), doctor and medical flags, Saudi flag, FTE, and resignations (Oasis for branches 1–5, Fusion for 6–8). Distinct counts and averages then work for any period. SSAS `Turnover Rate %` and `Saudisation Rate %` are changed to read it (Appendix B) |
| `fact_recruiting_requisition` (new gold model over `fusion.fact_recruiting_requisition`) | Requisition | Vacancy rate and time to fill |
| `fact_encounter` | + `is_referral_policy` (from the episode) | Referral volume (KPI 41) |
| `ssas_agg_clinic_capacity_daily` | + `legacy_capacity_slots` | OP and doctor utilisation (KPIs 22, 58) |

The SSAS role copy `Booked Doctor` also gains `Is High Value Specialty`, for KPI 26. This is configured in `model_config.py`.

**What a change costs:**

| Change | Where | Refresh |
|---|---|---|
| Target, weight, threshold, owner, category, label, order, direction, format, parked or active, manual value, code list | A new version row in a `default.map_bsc_*` table | Nightly dbt + SSAS Daily (or the fast path, with approval) |
| A KPI's formula, or a new KPI | SSAS measure in `_Measures.tmdl`, one line in the dispatcher, a catalogue row | SSAS deploy (approval) |
| A new detail column a formula needs | dbt model + `ssas_*` view + `generate.py` | dbt build + SSAS deploy |

**Tests** (dbt, on the `stg_ref__bsc_*` current-value views and the gold models):
- Unique keys, accepted values, and foreign keys from every config table to `map_bsc_kpi`.
- Every active KPI with target source `fixed` has a target for every hospital-month of the current year (warn).
- Thresholds are ordered. Manual values exist only for KPIs marked manual.
- `fact_bsc_workforce_monthly` reproduces `bsc.vw_work_force` (headcount, FTE, resignations, Saudi heads) for every branch-month.

**A bad edit can't hold up the warehouse** (changed 2026-10-20 after review). The config tests only warn, because a failing test would make the nightly `tag:hnh` run unsuccessful and keep the SSAS gate closed for the whole model. The models ignore rows they cannot use (an unknown KPI code, category or list). The BI manager can run `dbt test --select stg_ref__bsc_*` straight after an edit to see the warnings.

**Targets carry forward.** An annual target applies to later years until a newer one is entered.

#### 6.2.1 Editing routine for the BI manager

```sql
-- Change Days in AR target for 2027 (all hospitals)
INSERT INTO default.map_bsc_target
  (kpi_code, branch_id, year, month, target_value, source_basis, changed_at, changed_by, change_note, is_deleted)
VALUES ('FIN_DAYS_IN_AR', 0, 2027, 0, 170, 'Board 2027', now64(3), 'bi_manager', 'FY2027 target approved', 0);

-- See the history of a key
SELECT * FROM default.map_bsc_target WHERE kpi_code = 'FIN_DAYS_IN_AR' ORDER BY changed_at;
```

The same pattern covers the other tables: a weight, an owner, a hospital's category, a monthly manual value (HAI, falls, training, ...), parking a KPI. `docs/bsc_config.md` will list every table, its columns and an example.

### 6.3 SSAS layer: formulas and structure

**New tables:**

| Table | Source view | Kind |
|---|---|---|
| `BSC KPI` | `ssas_dim_bsc_kpi` | Dimension, disconnected from the facts. Sorted by display order; pillar and objective attributes |
| `BSC Targets` | `ssas_fact_bsc_target_monthly` | Fact → Branch, Date, BSC KPI |
| `BSC Weights` | `ssas_fact_bsc_weight` | Fact → Branch, BSC KPI |
| `BSC Manual Values` | `ssas_fact_bsc_manual_value` | Fact → Branch, Date, BSC KPI |
| `GL FS Monthly` | `ssas_fact_gl_fs_monthly` | Fact → Branch, Date (month) |
| `Workforce Monthly` | `ssas_fact_bsc_workforce_monthly` | Fact → Branch, Date (month end), Staff |
| `Requisitions` | `ssas_fact_recruiting_requisition` | Fact → Branch, Date |
| `Branch`, `Product Category`, `Encounters`, `Clinic Capacity`, `Booked Doctor` | existing | + the columns above |

**Measures** (folder `Balanced Scorecard\<pillar>` and `Balanced Scorecard\Scoring`):
- **One actual measure per active KPI** (about 50). These reuse existing measures where Appendix B chose them, e.g. `[Bed Occupancy %]`, `[ALOS (days)]`, `[Readmission Rate 30d %]`. Each is written so that it works for any filter context:
  - flows (revenue, visits, claims) are sums;
  - stocks (AR, assets, inventory, beds, headcount, FTE) are averaged over the months in context per hospital, then added across hospitals;
  - Days in AR and DIO multiply by the days in context.
- **Target measures** only where the target is not a fixed number: budget-based ones (`IS Budget` lines, `Target Revenue`/`Census`/`Episodes`) and "same period last year".
- **Dispatchers.**
  - `BSC Actual` = `SWITCH(SELECTEDVALUE('BSC KPI'[KPI Code]), "FIN_NET_REVENUE", [BSC Net Revenue], ...)`.
  - `BSC Target` reads the KPI's target source: a fixed target from `BSC Targets` (hospital row, else the all-hospitals row), a budget measure through the same `SWITCH` pattern, or `CALCULATE([BSC Actual], SAMEPERIODLASTYEAR('Date'[Date]))`.
  - Parked KPIs return BLANK, and `BSC State` returns `Parked`.
  - Manual KPIs read `BSC Manual Values`.
- **Scoring:**
  - `BSC Variance %`, `BSC Score` (85 + 0.6 × variance, clamped 0–100; thresholds from `BSC KPI`), `BSC Status` (`On track` / `Watch` / `At risk`), `BSC State` (`Parked` / `No data yet` / the status);
  - `BSC Pillar Score` and `BSC Overall Score` (weighted with `BSC Weights` and the pillar weights);
  - `BSC Trend` (12 monthly values as text, for the sparkline);
  - `BSC Numerator` and `BSC Denominator` (for the tooltip).
- **Model conventions apply:**
  - a `///` description, format string and display folder on every measure;
  - `measure_guards.py`, with `hnh_guard_allow = BSC KPI` on the dispatchers;
  - `hnh_snapshot = 1` where a stock measure needs it;
  - a check per measure in `ssas/tests/measures/balanced_scorecard.json`. The SQL side of each check is the reconciled `bsc` view at branch × month, which proves that the measure equals the scorecard definition.

**Perspective `Balanced Scorecard`:**
- the BSC tables, the facts behind the KPI measures, Branch, Date and Time Calculation;
- the detail facts used by the drill-through pages (section 6.5).

**Who uses it (decision D4).** The scorecard is for top management only:
- **Report access:** the BI manager grants it through Power BI Report Server folder permissions.
- **Data rules:** the model keeps its existing rules, unchanged.
- **Excel and other report tools:** any `HNH_BI_Users` member connecting with Excel can read the BSC measures, filtered to their own branches by `HNH Readers`. These are the same facts they can already query.

**Security.** `HNH Readers` is unchanged:
- **Branch filter.** It applies to every fact behind the KPI measures.
- **"Corporate".** It means "all hospitals the user may see", with `Branch[Is Hospital] = "Yes"` (Head Office excluded).
- **Other filters.** Staff, specialty and pay filters now also narrow the KPIs that read Staff-linked facts. That is consistent with every other report.
- **What is dropped:** KPI-owner security (`Viewer Access`, the `{"*","Full"}` fallback, client-side tile hiding) and the e-mail logins.

### 6.4 Report (Power BI Desktop for Report Server, live connection to the perspective)

The scorecard pages use a new custom visual, **HNH Balanced Scorecard** (section 6.7, decision D2). It follows the current boards' design, adds the improvements below and applies the Hayat brand. The drill-through pages use native visuals.

| Page | Built with |
|---|---|
| BSC (landing) | Custom visual, overview mode: overall gauge, four pillar cards |
| Financial / Customer / Internal Process / Learning & Growth | Custom visual, board mode (pillar filter): KPI tiles grouped by objective |
| Owner view | Custom visual, owner mode (owners shown as information only) |
| Hospital Comparison | Custom visual, comparison mode: focus hospital against peers; `BSC Category` slicer |
| **KPI Detail** (drill-through) | Native visuals, see 6.5 |
| **Detail pages** (drill-through) | Native visuals, see 6.5 |

- **Slicers:**
  - Branch (with "all" = Corporate) and `BSC Category`;
  - a Date month range, which replaces the From/To bridges;
  - optionally Time Calculation (YTD, etc.).
- **Theme:** the HNH colours move into the report theme JSON.
- **Saving format:** the file must be saved by Desktop for Report Server in the legacy layout (Notes/05).

### 6.5 Drill-through, three levels

1. **Scorecard to KPI Detail.** Right-click a KPI tile in the custom visual (the visual opens Power BI's own context menu on that KPI's selection) to open a page with drill-through field `BSC KPI[KPI Code]` and filters kept. It shows:
   - monthly actual against target (trend);
   - every hospital for that KPI, ranked;
   - numerator and denominator;
   - the definition, owner, weight and target basis (from config);
   - the `data_source` flag (Oasis / Fusion);
   - for manual KPIs, the note and who entered it.
2. **KPI Detail to transaction detail.** A second drill-through goes from the hospital × month on the KPI Detail page to a page per KPI family. Its visuals read existing `HNH_Analytics` facts, filtered by Branch and Date.
3. **Which family page each KPI uses.** `map_bsc_kpi.detail_page` names the family page, and the KPI Detail page shows a button only for that page (a button with a conditional destination).

| Family page | KPIs | Detail facts and breakdowns |
|---|---|---|
| Revenue | 1–3, 8, 11, 12, 18, 25, 27, 28, 44, 55 | Charge Lines by department, service, product category, payer, doctor |
| Finance (GL) | 4–6, 9, 10, 34, 35, 56, 62–65 | GL balances by FS line and account; Fusion GL Journal Lines. Oasis months need `fact_gl_fs_monthly` added to SSAS as `GL FS Monthly` (134K rows) |
| Patient volume | 14, 15, 20, 22, 24, 26, 41, 42, 57, 67 | Encounters, Admissions, Episodes by department, doctor, payer, visit type |
| Beds & clinical | 21, 23, 36, 37, 45, 60 | Bed Occupancy by ward and bed; Admissions with LOS and readmission flags |
| Revenue cycle | 29–33 | Claim Lines by payer, NPHIES reason, status; Pre-auth Lines; Order Lines |
| Workforce | 43, 44, 46–48, 68 | Headcount, Worker Movements, Employee by department, job, nationality |
| Patient experience | 13, 16 | Survey Responses / Answers |

**Exposure under existing rules.** Detail pages show what `HNH Readers` already allows. Patient details, pay and employee names stay behind the PII and pay flags. Doctor-level revenue is visible to all users of a branch, as it is in other reports today.

### 6.6 Benefits and drawbacks of the chosen design

**Benefits**
- **Exact for any selection.** Every KPI follows the filter context: date range, YTD and prior year, any set of hospitals, exact distinct patient counts. Where the facts allow it, a KPI can also be sliced by department, payer or doctor.
- **One definition everywhere.** The scorecard reuses the model's measures, and the model's Turnover and Saudisation measures are aligned to the scorecard rule. Other reports and the scorecard show the same numbers.
- **Configuration in one place.** Catalogue, targets, weights, thresholds, owners, categories, code lists and manual values are rows in DWH tables, with no SSAS deploy and no JavaScript editing. This replaces the 15-step change in Notes/06.
- **Correct numbers.** The finance KPIs use the combined Oasis + Fusion GL, and the workforce KPIs use the reconciled `vw_work_force` rules.
- **Real drill-through.** The new visual opens Power BI's context menu, tooltips and cross-filtering, from KPI to hospital and month, then to transaction lines.
- **Consistent security.** `HNH Readers` applies, which closes the open `*`=Full fallback and the browser-only tile hiding.
- **Less to maintain:** no calculated tables, no ODBC refresh or `chDWH` DSN for the report (it connects live), and about 2.5 MB of duplicated JavaScript removed.
- **Testable.** dbt tests on the config, and a DAX-against-SQL check for every KPI measure.

**Drawbacks**
- **A formula change is an SSAS change.** Changing a KPI's formula, or adding a KPI, means editing `_Measures.tmdl`, adding its test and deploying (with approval). Configuration changes stay in the DWH.
- **More SSAS work and more measures.** About 50 KPI measures, about 15 target, dispatcher and scoring measures, 7 new tables, and a check for each measure.
- **Query cost.** The scorecard asks for about 55 KPIs × 8 hospitals × 12 months (sparklines) over large facts. Performance has to be measured on the test database before release (`ssas/tests/performance.json`).
- **We own a custom visual.**
  - The HNH Balanced Scorecard visual is TypeScript code that the BI team must maintain.
  - Each Power BI Report Server upgrade must be checked against the visual's API version.
  - It is a private visual (not certified), so it is imported into the report file.
- **Data is a day old, not near real time.** Changes appear after the nightly dbt build and `process.ps1 -Mode Daily`. The fast path (`-Force`) needs approval each time.
- **Manual KPIs need a monthly routine.** The BI manager owns it, and every entry is a ClickHouse insert.
- **Edits are SQL inserts.** That is fast for the BI manager, but a mistake in a key is only caught by the dbt tests (section 6.2). There is no form with validation.
- **Numbers move.** They come from the new server and corrected definitions, so 2025–2026 values differ from the current report, mainly finance after cutover. `docs/reconciliation_bsc.md` explains the differences.

### 6.7 Custom visual "HNH Balanced Scorecard"

**Design reference.** The current boards were rendered with sample data. The prototype of the new visual is `docs/superpowers/specs/assets/2026-10-20-bsc-visual-prototype.html`: open it in Edge, switch between the two modes, hover a tile, right-click a tile.

**Carried over from the current boards:**
- the blue-to-navy header band;
- semicircle score gauges with a target marker;
- the four pillar cards with their questions;
- objective sections (F1 … L3) with primary KPIs given more space;
- variance chips and "at risk" counts;
- the owner view and the hospital comparison.

**Brand** (from `branding/`):
- **Colours:** navy `#0A1E32` / `#002E5A`; the logo's blue gradient `#13ACE3` → `#1478BE`; sky `#32A4E5` for data.
- **Status colours:** green-teal for on track, `#EF8B00` for watch, `#DB280A` for at risk.
- **Logo:** the logo mark sits in the header band, and the band's ribbon shape is taken from it.
- **Font:** Segoe UI, as today. The guideline PDF holds its text as outlines, so the brand typeface is not known. If brand font files exist, they can be embedded in the visual.

**Improvements:**

| # | Improvement | Today |
|---|---|---|
| 1 | All KPI lists, labels, objectives, owners, weights, thresholds, formats and directions arrive as data columns from `BSC KPI`. No configuration is written in the visual | About 2.5 MB of copied JavaScript configuration |
| 2 | Right-click opens Power BI's context menu (drill-through to KPI Detail and the family page, include and exclude). A click cross-filters the other visuals. Hover shows a report-page tooltip or the built-in tooltip with numerator, denominator, score and source | No interaction |
| 3 | 12-month sparkline per KPI, with the target line; 12-month pillar score trend | Sparklines are empty |
| 4 | "No data yet" is its own state: definition to be agreed, waiting for this month's manual entry, or not yet calculated. It is never shown as 0 or as a bare dash | Blank tiles |
| 5 | Each tile has a status icon and word (✓ on track, ! watch, ▼ at risk) as well as a colour, and a "lower is better" note | Colour only |
| 6 | Badges for data source (Oasis + Fusion GL, Oasis, manual entry) and owner | — |
| 7 | KPI status strip on each pillar card: one square per KPI. Hover names the KPI, click goes to it | — |
| 8 | An on-card legend explains how the score is calculated | Hidden in the JavaScript |
| 9 | Keyboard navigation, high-contrast mode, Power BI rendering events (so export and subscriptions wait for the visual) | — |
| 10 | Format pane: mode (overview, board, owner, comparison), and theme colours with brand defaults | Edit the script |

**How the visual is built:**
- **Package:** TypeScript with `powerbi-visuals-tools` (pbiviz), D3 v7, packaged as a private `.pbiviz` and imported into the report.
- **API version:** pinned to the highest version that Power BI Report Server 1.26 and Desktop for Report Server (May 2026) accept. This is confirmed first with a minimal test visual.
- **Data:**
  - categorical mapping: category `BSC KPI[KPI Code]`, plus `Branch` in comparison mode;
  - KPI attributes as grouping columns;
  - measures `BSC Actual`, `BSC Target`, `BSC Score`, `BSC Status`, `BSC Numerator`, `BSC Denominator`, and `BSC Trend`, which returns 12 monthly values as text so a selection stays one KPI.
- **Selection and drill-through:** each KPI gets a selection id from its category. `selectionManager.showContextMenu` gives Power BI's drill-through menu, and the tooltip service gives tooltips.
- **Build machine:** Node 24 is already on this server, but `powerbi-visuals-tools` is not installed. Installing it (npm) is a software install on the production server and needs approval; it can also be built on a separate PC.
- **Source:** in the repository under `powerbi_tmdl/hnh_bsc_visual/`, with unit tests for the scoring and formatting functions.

---

## 7. Plan

Every step that writes to ClickHouse, deploys or processes SSAS, or changes the report server waits for approval (CLAUDE.md).

| Phase | Work | Output | Size |
|---|---|---|---|
| **0. Decisions** | Done 2026-10-20 (section 9, Appendix B). Visual design approval from the prototype | This spec | S |
| **1. DWH** (plan `2026-10-20-bsc-dwh-config-and-facts.md`) | `default.map_bsc_*` DDL and first content (generated from the handover files and Appendix B); `stg_ref__bsc_*`; `dim_bsc_kpi`, `fact_bsc_target_monthly`, `fact_bsc_weight`, `fact_bsc_manual_value`; `bsc_category` / `is_hospital` on `dim_branch`; `is_bsc_ancillary`; `fact_bsc_workforce_monthly`; `fact_recruiting_requisition`; `is_referral_policy` on encounters; `ssas_*` views and contracts; Fusion consumables mapping review; `docs/bsc_config.md` | Config in ClickHouse and gold tables (writes and the dbt build need approval) | L |
| **2. SSAS** | `model_config.py` tables and columns; KPI measures, dispatchers and scoring; Turnover and Saudisation aligned; the `Balanced Scorecard` perspective; measure checks against the `bsc` views; performance test. `deploy.ps1 -Stage TestMeasures`, then `-Stage All` | Perspective live on the test slot, then production (approval each) | L |
| **3a. Visual: API probe** | Minimal test visual at the candidate API version, opened in Desktop for Report Server and on the report server (needs approval to install `powerbi-visuals-tools`, or a separate PC) | Confirmed API version | S |
| **3b. Visual: build** | `powerbi_tmdl/hnh_bsc_visual/`: four modes, context menu, tooltips, sparklines, format pane, rendering events, unit tests. Reviewed against the prototype | `.pbiviz` package | L |
| **4. Report** | Desktop for Report Server, live to the perspective: landing, four pillar pages, owner view, hospital comparison (custom visual), KPI Detail and family detail pages (native). Tested as a non-admin top-management login | New pbix in a top-management folder on the report server, beside the old report | M |
| **5. Manual KPIs** | The BI manager enters HAI, falls, training, DOA, audit, staff satisfaction, PROMs, PREMs and complaints monthly | KPIs leave Parked as data arrives | ongoing |
| **6. Switch** | Users compare old and new side by side; retire the handover pbix and the `chDWH` dependency | One scorecard | S |

Phases 1–4 deliver the 45 KPIs that work today, plus drill-through, on SSAS. Phases 5–7 can run in parallel once phase 2 exists.

---

## 8. Extending later

- **A new KPI:** a catalogue row with status `parked` until its measure exists. Then a measure, a dispatcher line and a test, deployed to SSAS, and the status set to `active`.
- **A parked KPI gets a source** (for example Fusion Learning for training): a gold model, an `ssas_*` view, a measure. Until then, it can be fed through `map_bsc_manual_value`.

---

## 9. Decisions

Taken on 2026-10-20:

| # | Decision | Answer |
|---|---|---|
| D1 | Option A, B or C | B (implied by D2–D7) |
| D2 | Report look | **A new custom visual, similar in design to the current boards, with improvements and the Hayat brand** (section 6.7) |
| D3 | Where a scorecard definition differs from SSAS, which wins | **Decided per KPI by the user** (Appendix B). Both definitions are built as metrics, so a choice can be changed later in `map_bsc_kpi` |
| D4 | Who sees it; security | **Top management only. Access is managed on the report server; the model keeps the same `HNH Readers` rules** |
| D6 | Where configuration lives | **ClickHouse `default` reference tables, not CSV files** (insert-only change logs, section 6.2) |
| D7 | Owner of the configuration and the manual values | **BI manager** |

Also taken on 2026-10-20:

| # | Decision | Answer |
|---|---|---|
| D5 | "Corporate" | Hospitals 1–8 the user can see; Head Office (100) and the Group row (0) excluded |
| D8 | KPIs without data | **Parked** when there is no data at all or no agreed definition; **No data yet** when only the selected months or hospitals are missing |
| D9 | Hospitals not in the warehouse (Sabya, Al Kharj) and the "Specialist & Bespoke" category | Left out until they exist as branches |
| D10 | Typeface | Segoe UI |
| D11 | YTD | No YTD-specific measures: every KPI follows the filter context (date slicer, Time Calculation group). KPIs 2 and 3 are merged |
| D3 | Per-KPI definitions | Appendix B |
| D12 | Where KPI formulas live | **SSAS measures over the facts, following the filter context; all configuration stays in ClickHouse `default` tables** (section 6) |

Still open: approval to install `powerbi-visuals-tools` on this server for the visual build (phase 4a).

---

## Appendix A: KPIs, today's status, source and drill target

Status: **A** live, **B** derivable, **C** manual, **D** definition needed. Source: the `bsc` view or metric behind the KPI on `.214`. Drill: the family page in section 6.5.

| # | KPI | Pillar | Status | Source (num / den; target) | Drill |
|---|---|---|---|---|---|
| 1 | Net Revenue Achievement | F | A | GL net revenue; budget REV_NET | Revenue |
| 2 | Net Revenue Achievement (YTD vs Previous YTD) | F | A | YTD GL revenue; PY YTD | Revenue |
| 3 | Net Revenue Achievement (Month YoY) | F | A | Range GL revenue; same range PY | Revenue |
| 4 | EBITDA Margin | F | A | EBITDA / net revenue; budget | Finance |
| 5 | Cost-to-Revenue Ratio | F | A | (revenue − EBITDA) / revenue; budget | Finance |
| 6 | Days in AR | F | A | Average AR × days / revenue; 180 | Finance |
| 7 | Net Collection Rate | F | B | Remittances / approved claims (definition to agree) | Revenue cycle |
| 8 | Revenue per Bed | F | A | Revenue / average available beds; budget | Revenue |
| 9 | Return on Asset | F | A | Income / opening assets; 12% annual (annualise or pro-rate) | Finance |
| 10 | EBITDA per Bed | F | A | EBITDA / average beds; budget | Finance |
| 11 | Multi-Specialty Revenue Share | C | A | (OP + non-LTC IP revenue) / GL revenue; target revenue | Revenue |
| 12 | Payer-Segment Revenue Mix | C | A | Insurance revenue / GL revenue; target | Revenue |
| 13 | Patient Satisfaction (Press Ganey) | C | A (manual) | Manual value (today: hand-loaded sheet) | Patient experience |
| 14 | Patient Retention | C | A | (OP census − new) / OP census; 0.65 | Patient volume |
| 15 | New Patient Acquisition | C | A | New OP / OP census; 0.7 or 0.3 by hospital | Patient volume |
| 16 | PREMs Score | C | A (manual) | Manual value; 0.85 | Patient experience |
| 17 | PROMs Score | C | C | Manual value | — |
| 18 | Non-MoH Revenue Share | C | A | Non-MoH revenue / GL revenue; target | Revenue |
| 19 | Non-Eligible Referral Rate | C | D | — | — |
| 20 | Total Payer Volume | C | A | Insurance census; target | Patient volume |
| 21 | BOR | IP | A | Occupied / available bed nights; 0.70 | Beds |
| 22 | OP Utilization | IP | A | OP census / legacy slots; target | Patient volume |
| 23 | ALOS | IP | A | Σ LOS / discharges (non-LTC); 4 | Beds |
| 24 | OP-to-IP Conversion | IP | A | Admissions / OP census; target | Patient volume |
| 25 | High-Value Service-Line Revenue Share | IP | A | HV revenue / GL revenue; 0.18 | Revenue |
| 26 | Census for High-Value Services | IP | A | HV volume / census; 0.12 | Patient volume |
| 27 | OP Revenue per Episode | IP | A | OP revenue / OP episodes; target | Revenue |
| 28 | Ancillary Service Utilization | IP | A | Ancillary / OP revenue; OP target × 0.6 | Revenue |
| 29 | Revenue Leakage Rate | IP | A | 10 × pending / submitted claims; 0.05 | Revenue cycle |
| 30 | Claim Initial Rejection Rate | IP | A | Rejections / submitted; 0.10 | Revenue cycle |
| 31 | Order Not Done | IP | A | Approved not done / orders; 0.10 | Revenue cycle |
| 32 | Insurance Approval Turnaround Time | IP | A | Σ TAT / pre-auths (weighted, fixes 3.3 #3); 20 min | Revenue cycle |
| 33 | Claim Final Rejection Rate | IP | B | Final rejected / adjudicated (claim lines) | Revenue cycle |
| 34 | Budget Variance (Cost Budget) | IP | A | (opex − budget) / budget; 0 | Finance |
| 35 | G&A Expense Ratio | IP | A | G&A / revenue; budget | Finance |
| 36 | 30-Day Readmission Rate | IP | A | Readmissions / discharges; 0.10 ceiling | Beds |
| 37 | 48-Hour Readmission Rate (Critical) | IP | A | ICU readmissions / ICU discharges; 0.03 ceiling | Beds |
| 38 | HAI Rate | IP | C | Manual value | — |
| 39 | Fall Rate with Harm | IP | C | Manual value | — |
| 40 | Payer Contract Activation | IP | D | — | — |
| 41 | External/Other Facility Referral Volume | IP | B | `referrals_volume` (Ghirnata and Muhayil unmapped, O-B8) | Patient volume |
| 42 | Total Patient Volume | IP | A | OP + admissions + ER; target | Patient volume |
| 43 | Turnover Ratio | LG | A | Resignations / average headcount; 0.06 × months / 12 | Workforce |
| 44 | Revenue per FTE | LG | A | Revenue / average FTE; budget | Workforce |
| 45 | Staff-to-Bed Ratio | LG | A | Average FTE / average beds; 4 (band) | Workforce |
| 46 | Saudization | LG | B | Saudi headcount / headcount (new `vw_work_force`) | Workforce |
| 47 | Job Vacancy Rate | LG | B | Vacant / approved positions (Oracle Recruiting; partial coverage) | Workforce |
| 48 | Time to Fill | LG | B | Average days approval to fill | Workforce |
| 49 | Timely Completion Rate for Digital Initiatives | LG | C | Manual value | — |
| 50 | Training Coverage Rate | LG | C | Manual value (Fusion Learning later) | — |
| 51 | Mandatory Training Completion Rate | LG | C | Manual value | — |
| 52 | Cost per Learner | LG | C | Manual value | — |
| 53 | DOA Compliance | LG | C | Manual value | — |
| 54 | Audit Finding Closure Rate | LG | C | Manual value | — |
| 55 | Revenue per Doctor | Add | A | Revenue / average doctors (incl. part-time); budget | Revenue |
| 56 | EBITDA per Doctor | Add | A | EBITDA / average doctors; budget | Finance |
| 57 | ER Volume Growth | Add | A | ER / PY ER − 1; target | Patient volume |
| 58 | Doctor Utilization | Add | B | Doctor visits / legacy slots | Patient volume |
| 59 | Referral to Hub | Add | D | — | — |
| 60 | Activated Bed Rate | Add | B | Average available / licensed beds | Beds |
| 61 | Referral Conversion Rate | Add | D | — | — |
| 62 | Patient Acquisition Cost | Add | B | Marketing GL / new patients | Finance |
| 63 | Total Consumables Ratio | Add | A | Medical consumables / revenue; budget (Fusion has no consumables caption yet, O-P3-8) | Finance |
| 64 | Days Inventory Outstanding | Add | A | Average inventory × days / COGS; budget | Finance |
| 65 | Breakeven Revenue Gap | Add | D | Needs a fixed/variable cost split | Finance |
| 66 | Patient Complaint Rate | LG/C | A (manual) | Complaints / census; 0.005 | Patient experience |
| 67 | Avg OP Waiting Time | Add | A | Σ wait / OP census; 20 min | Patient volume |
| 68 | Clinical Staff-to-Doctor Ratio | Add | A (no target) | Average clinical / average doctors | Workforce |
| 69 | Staff Satisfaction | LG | C | Manual value | — |
| 70 | Cost per Hire | LG | D | Recruiting cost source needed | — |
| 71 | Cost per Fire | LG | D | Separation cost (end-of-service pay) | — |

---

## Appendix B: per-KPI definitions (decisions taken 2026-10-20)

Each KPI's formula is the SSAS measure for the definition below (D12). Changing a definition later means changing the measure.

| # | KPI | Decision |
|---|---|---|
| 1 | Net Revenue Achievement | GL net revenue (Oasis to each branch's Fusion cutover, then Fusion including unposted) ÷ budget REV_NET |
| 2 + 3 | Net Revenue Achievement (YTD vs Previous YTD), (Month YoY) | **Merged into one KPI, "Net Revenue Growth vs Last Year"**: GL net revenue in the selected period ÷ the same period last year. The period comes from the filter context (date slicer or Time Calculation: YTD, MTD, …). There are no YTD-specific measures |
| 4, 5, 6 | EBITDA Margin, Cost-to-Revenue, Days in AR | Combined Oasis + Fusion GL (`fact_gl_fs_monthly`) |
| 8, 10, 45 | Revenue per Bed, EBITDA per Bed, Staff-to-Bed | ÷ average available beds (bed occupancy) |
| 9 | Return on Asset | As the handover: period income ÷ opening assets against the annual 12% |
| 13 | Patient Satisfaction (Press Ganey) | **Survey data in the warehouse: the average NPS score over the related questions.** The list of questions is a config row |
| 14 | Patient Retention | **SSAS returning-patients definition, OP only**: distinct returning OP patients ÷ distinct OP patients (ER excluded) |
| 22, 58 | OP Utilization, Doctor Utilization | ÷ legacy capacity slots, until O-B3 is fixed |
| 29 | Revenue Leakage Rate | **Claims not submitted, excluding errored and cancelled claims, ÷ total submitted claims**, from the reconciled `vw_rcm`. No ×10 multiplier |
| 30 | Claim Initial Rejection Rate | `vw_rcm` rejections ÷ submitted (latest submission, statement month) |
| 32 | Insurance Approval Turnaround Time | Average over all pre-auth requests |
| 33 | Claim Final Rejection Rate | **Parked.** The final rejection is only known after payer payment reconciliation, which neither the ERP nor the HIS captures |
| 43 | Turnover Ratio | `vw_work_force` rule (resignations from Oasis for branches 1–5, Fusion voluntary leavers for 6–8) ÷ average headcount. **SSAS `Turnover Rate %` is changed to the same rule** |
| 44, 55, 56 | Revenue per FTE, Revenue per Doctor, EBITDA per Doctor | Part-time doctors included (0.5 FTE each) |
| 46 | Saudization | `vw_work_force` rule: Saudi ÷ (headcount − part-time doctors). **SSAS `Saudisation Rate %` is aligned to it** |
| 63 | Total Consumables Ratio | GL medical consumables ÷ net revenue. **Review the Fusion FS mapping:** list the Fusion accounts that should carry the consumables caption, and the user adds them |
| 64 | Days Inventory Outstanding | GL average inventory × days ÷ (GL cost of medicines + medical consumables) |
| 67 | Avg OP Waiting Time | Average over OP visits with a recorded wait |

### Other KPI decisions

| # | KPI | Decision |
|---|---|---|
| 7 | Net Collection Rate | Parked until finance agrees a definition |
| 62 | Patient Acquisition Cost | GL marketing expense (Oasis + Fusion; budget line GA_MARKETING) ÷ new OP patients |
| 47, 48 | Job Vacancy Rate, Time to Fill | Shown where Oracle Recruiting data exists. Other hospitals show "No data yet", and the Corporate figure is labelled partial |
| 19, 40, 59, 61, 65, 70, 71 | Group D | Parked (no agreed definition) |
| 17, 38, 39, 49–54, 69 | Group C | Manual entry by the BI manager. Parked until the first value |

### KPI states shown by the visual

| State | When |
|---|---|
| **Parked** | The KPI has no data in any month, or its definition is not agreed (`map_bsc_kpi.status = 'parked'`) |
| **No data yet** | The KPI has data in some months or hospitals, but none in the current selection |
| On track / Watch / At risk | From the score and thresholds |
