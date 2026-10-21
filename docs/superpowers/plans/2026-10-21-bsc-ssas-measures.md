# BSC on SSAS — Plan 2: tables, KPI measures, scoring and the perspective

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Serve the 61 active scorecard KPIs from `HNH_Analytics`:
- one SSAS measure per KPI that follows the filter context;
- dispatcher and scoring measures driven by the `BSC KPI` table;
- a `Balanced Scorecard` perspective;
- `Turnover Rate %` and `Saudisation Rate %` aligned to the scorecard rules.

**Architecture:**
- **DWH additions (Task 1).** Two small config tables (parameters, licensed beds) and the high-value flag on the `Booked Doctor` view, built like Plan 1.
- **Model config (Task 2).** The 8 Plan 1 views plus the 2 new ones become SSAS tables through `model_config.py`.
- **Measures (Tasks 3–7).** All in `_Measures.tmdl`, folder `Balanced Scorecard\<topic>`:
  - building blocks;
  - KPI actuals per pillar;
  - targets;
  - dispatchers and scoring.
- **Checks.** Every measure has a DAX-against-SQL check, mostly against the reconciled `bsc.vw_*` views for August 2026, branch 6 (Abha).

**Tech Stack:**
- SQL Server 2025 Analysis Services (compatibility 1700), TMDL;
- Python 3.12 tools in `ssas/tools`;
- Tabular Editor 2.27 BPA;
- Windows PowerShell 5.1 + Pester 3.4;
- dbt-clickhouse in the receiving project.

**Spec:** `docs/superpowers/specs/2026-10-20-hnh-bsc-ssas-perspective-analysis.md` (sections 6.3, 9, Appendix B including "Further definitions (2026-10-21)"). Model rules: `docs/superpowers/specs/2026-10-07-hnh-ssas-tabular-model-design.md`, `ssas/README.md`.

**Branch:** `bsc-ssas-measures` from `main`.

## Global Constraints

- **Production server** (`CLAUDE.md`). Ask the user before each of these:
  - the ClickHouse writes in Task 1 (`apply_bsc_config.ps1`);
  - the receiving-project dbt build;
  - every `deploy.ps1` stage other than `Validate`;
  - `test.ps1` against a database.

  These need no approval: `generate.py --from-contracts`, `measure_guards.py`, `sync_perspectives.py`, `python -m pytest ssas/tools`, BPA (`TabularEditor.exe ssas\HNH_Analytics -A ssas\bpa_rules.json -V`), Pester, and read-only `SELECT` through `HNH_Gold`.
- **Measure conventions** (README "Change the model"):
  - Every measure lives in `tables/_Measures.tmdl` with a `///` description, `formatString` (or `formatStringDefinition`) and `displayFolder`.
  - Folders are `Balanced Scorecard\Building Blocks`, `Balanced Scorecard\Financial`, `…\Customer`, `…\Internal Process`, `…\Learning & Growth`, `…\Targets` and `…\Scoring`.
  - Write a new measure unwrapped, then run `python ssas/tools/measure_guards.py`, which adds the guard. Later edits go between `VAR __Value = ( -- measure body` and `) -- end of measure body`.
  - Formats: SAR `#,0`, rates `0.0%`, counts `#,0`, days and minutes `#,0.0`, ratios `#,0.00`.
  - VAR names must not be DAX function names.
  - Snapshot measures carry `annotation hnh_snapshot = 1` and appear in all five `ISSELECTEDMEASURE` lists of `tables/Time Calculation.tmdl` (lines 16, 29, 42, 60, 131).
  - No `FILTER/SUMX/AVERAGEX/…` directly over a large fact (BPA `HNH_NO_ITERATOR_OVER_LARGE_FACT`). Iterate over `VALUES(dimension column)`.
- **Measure checks.** Every non-Diagnostics measure appears in at least one check in `ssas/tests/measures/balanced_scorecard.json`:
  - Keys: `name`, `tolerance`, `dax`, `sql`, optional `allow_zero`.
  - DAX filter: `Branch[Branch Key] = 6, 'Date'[Year Month] = 202608`.
  - SQL reads `bsc.vw_*` (bi_user can read it) or `gold.ssas_*`.
- **Hospitals only.** Every KPI is evaluated with `KEEPFILTERS ( Branch[Is Hospital] = "Yes" )`, applied once in the dispatcher (Task 7) and in each KPI check.
- **Labels and codes come from data.** No KPI list, label, weight, threshold or target value is written in DAX. The only codes in DAX are the `SWITCH` keys of the dispatchers (one line per KPI code) and fixed source values (GL captions, budget line codes, payer categories).
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

### Spec refinements made while planning

| Spec says | Plan does | Why |
|---|---|---|
| The tooltip shows numerator and denominator | It shows actual, target, score, state, source and the definition text | A numerator/denominator measure pair per KPI would double the measure count. The definition text explains the formula |
| KPI score drives pillar and overall scores; the handover overview used a/t unit scores | Pillar score = weighted mean of KPI scores (0–100); overall = pillar scores weighted by pillar weight | Same scale as the tiles and the 85 target |
| A fixed target for several hospitals | The average of the selected hospitals' monthly target rows; for `scale_with_months` × months in context ÷ 12 | One number per tile without an extra rule |
| `ceiling` direction | Scored like `lower` | The handover tile treated readmissions as lower-is-better |

## Review Focus

1. **Corporate means hospitals only.**
   - Situation: with no branch filter, Head Office rows exist on charge lines and invoices.
   - Expected: the KPIs exclude them.
   - Pinned by: the Task 7 check `BSC Actual, all hospitals vs sum of 1-8`.
2. **A month in progress or a future month.**
   - Situation: GL carries balances to December, and the workforce fact has no row for the open month.
   - Expected: stock KPIs never read a month after today. Headcount-based KPIs for the current month fall back to the last closed month, and are not 0.
   - Pinned by: the Task 3 check `BSC AR Average ignores future months` and the Task 6 Saudization snapshot check.
3. **A KPI selected in a visual must not trigger guard messages.**
   - Expected: a visual with `BSC KPI[KPI Name]` on rows shows numbers, not "can't be analysed by BSC KPI".
   - Pinned by: the Task 7 check `BSC Actual per KPI row is numeric`.
4. **Parked and empty KPIs.**
   - Expected: a parked KPI returns BLANK actual and the state `Parked`. A manual KPI with no row in the period returns `No data yet` while it has rows in other months, and `Parked` when it has none at all.
   - Pinned by: the Task 7 checks on `BSC State`.
5. **Several hospitals selected.**
   - Expected: ratios pool numerators and denominators (never an average of hospital rates), and weights switch to the corporate weight.
   - Pinned by: the Task 4 check `BSC EBITDA Margin, branches 1-8` (pooled SQL) and the Task 7 check `BSC KPI Weight, two hospitals`.

## File Structure

```
scripts/bsc_config/bsc_config_ddl.sql                   Task 1  + map_bsc_parameter, map_bsc_licensed_beds
scripts/bsc_config/bsc_config_update_2026-10-21.sql     Task 1  parameter and licensed-beds rows; renames of KPIs 22, 58; new definition texts
scripts/bsc_config/apply_bsc_config.ps1                 Task 1  + -Update <file> (insert-only updates)
scripts/bsc_config/ApplyBscConfig.Tests.ps1             Task 1
hnh_dwh/models/hnh/staging/reference/stg_ref__bsc_parameter.sql, stg_ref__bsc_licensed_beds.sql   Task 1
hnh_dwh/models/hnh/marts/scorecard/dim_bsc_parameter.sql, fact_bsc_licensed_beds.sql              Task 1
hnh_dwh/models/hnh/marts/ssas/ssas_dim_bsc_parameter.sql, ssas_fact_bsc_licensed_beds.sql, ssas_dim_staff_role.sql   Task 1
hnh_dwh/models/hnh/marts/ssas/_ssas__models.yml         Task 1  contracts of the new and changed views (hand-added, then regenerated after the build)
ssas/tools/model_config.py, ssas/tools/hnh_tmdl.py      Task 2  tables, keys, active dates, perspective; ACRONYMS + bsc, kpi
ssas/tools/test_hnh_tmdl.py, ssas/tools/test_measure_catalogue.py   Task 2  acronym test; DOMAINS + Balanced Scorecard
ssas/HNH_Analytics/** (generated)                       Task 2
ssas/HNH_Analytics/tables/_Measures.tmdl                Tasks 3-8
ssas/HNH_Analytics/tables/Time Calculation.tmdl         Tasks 3, 6
ssas/HNH_Analytics/tables/BSC KPI.tmdl                  Task 2  + hierarchy Pillar > Objective > KPI (hand-written, kept by the generator)
ssas/tests/measures/balanced_scorecard.json             Tasks 3-8
ssas/tests/measures/workforce.json                      Task 6  updated checks of Turnover and Saudisation
ssas/README.md                                          Task 8  domain list
```

---

### Task 1: DWH additions (parameters, licensed beds, high-value booked doctor, KPI renames)

**Files:** as listed under Task 1 above.

**Interfaces:**

| Object | Columns / content |
|---|---|
| `map_bsc_parameter` | `name String`, `value Float64`, + the change-log columns. Seed rows: `clinic_hours_per_day` 8, `clinic_patients_per_hour` 4, `ancillary_target_share` 0.6 |
| `map_bsc_licensed_beds` | `branch_id UInt8`, `year UInt16`, `licensed_beds Float64`, + the change-log columns. Seed: one row per branch 1–8 for 2026 from `gold.dim_branch.licensed_beds` (an `INSERT ... SELECT`) |
| `gold.dim_bsc_parameter` | One row: `bsc_parameter_key Int64` (constant 1), `clinic_hours_per_day Float64` (default 8 when missing), `clinic_patients_per_hour Float64` (default 4), `ancillary_target_share Float64` (default 0.6) |
| `gold.fact_bsc_licensed_beds` | `branch_key UInt8`, `year_date_key Int32` (1 January), `licensed_beds Float64`. Carries forward like targets: every year up to the current year takes the latest year ≤ it |
| `ssas_dim_staff_role` | Adds `if(is_high_value_specialty = 1, 'Yes', 'No') as is_high_value_specialty` |

The update file inserts new versions of `map_bsc_kpi` for the KPIs below (copy the latest row, change only the columns listed):
- KPI 22: `kpi_name` "Clinic Utilization", new definition text.
- KPI 58: `kpi_name` "OP Doctor Utilization", new definition text.
- KPIs 5, 13, 29, 32, 36, 46, 60, 62, 64: new definition texts, quoting the spec's "Further definitions" row.

- [ ] **Step 1: Failing tests.**
  - Extend `ApplyBscConfig.Tests.ps1`: the dry run lists 12 `CREATE TABLE` statements, and `-DryRun -Update bsc_config_update_2026-10-21.sql` prints `default.map_bsc_parameter: 3 rows`, `default.map_bsc_kpi: 11 rows` and `default.map_bsc_licensed_beds: INSERT ... SELECT from gold.dim_branch`.
  - Extend `BscModels.Tests.ps1`:
    - `dim_bsc_parameter` without rows gives 8, 4 and 0.6;
    - `fact_bsc_licensed_beds` with a 2026 row for branch 6 = 100 and as-of 2027-03-01 gives 100 for 2027.
- [ ] **Step 2: Run them, see them fail** (`Invoke-Pester -Script scripts\bsc_config\ApplyBscConfig.Tests.ps1`, `…\BscModels.Tests.ps1`).
- [ ] **Step 3: Implement.** Write the DDL, the staging views (the latest-row pattern of Plan 1), the gold models (licensed beds use the `fact_bsc_target_monthly` carry-forward logic with years), the `ssas_` views, the `-Update` switch and the update file. Add the contracts of the two new views and the new `ssas_dim_staff_role` column to `_ssas__models.yml` by hand (types: Int64 keys, Float64 values, String flag).
- [ ] **Step 4: Run the tests, see them pass.**
- [ ] **Step 5: Commit** ("Add scorecard parameters, licensed beds and the high-value booked doctor").
- [ ] **Step 6: Ask the user, then apply and build.**
  - `apply_bsc_config.ps1` (creates the two tables and inserts the seed), then `apply_bsc_config.ps1 -Update scripts\bsc_config\bsc_config_update_2026-10-21.sql`.
  - Receiving build: `dbt build --select stg_ref__bsc_parameter+ stg_ref__bsc_licensed_beds+ ssas_dim_staff_role`.
  - Afterwards, regenerate the contracts from `system.columns` (only additions expected) and commit.

---

### Task 2: Model config and generation

**Files:** `ssas/tools/model_config.py`, `ssas/tools/hnh_tmdl.py:9-13`, `ssas/tools/test_hnh_tmdl.py`, `ssas/tools/test_measure_catalogue.py:15-16`, generated `ssas/HNH_Analytics/**`, hand-written hierarchy in `tables/BSC KPI.tmdl`.

**Interfaces:**

| Config | Value |
|---|---|
| `TABLES` | `Table("ssas_dim_bsc_kpi", "BSC KPI", "dim", "Balanced-scorecard KPIs with their objective, pillar, thresholds and corporate weight.")`; `Table("ssas_dim_bsc_parameter", "BSC Parameters", "dim", "Scorecard parameters (clinic hours per day, patients per hour, ancillary target share).")`; facts `"BSC Targets"`, `"BSC Weights"`, `"BSC Manual Values"`, `"BSC Budgeted FTE"`, `"BSC Licensed Beds"`, `"GL FS Monthly"`, `"Workforce Monthly"`, `"Requisitions"` with one-line descriptions; no partition column |
| `DIM_KEYS` | `"bsc_kpi_key": ("BSC KPI", "bsc_kpi_key")` |
| `ACTIVE_DATE` | BSC Targets `month_date_key`; BSC Manual Values `month_date_key`; BSC Budgeted FTE `year_date_key`; BSC Licensed Beds `year_date_key`; GL FS Monthly `month_date_key`; Workforce Monthly `month_date_key`; Requisitions `filled_date_key` (approved date inactive) |
| `PERSPECTIVES` | `"Balanced Scorecard": ["BSC Targets", "BSC Weights", "BSC Manual Values", "BSC Budgeted FTE", "BSC Licensed Beds", "GL FS Monthly", "Workforce Monthly", "Requisitions", "Charge Lines", "Encounters", "Admissions", "Episodes", "Bed Occupancy", "Clinic Capacity", "Claim Lines", "Pre-auth Lines", "Invoices", "Survey Answers", "Income Statement", "Targets"]` |
| `PERSPECTIVE_EXTRA` | `"Balanced Scorecard": ["BSC Parameters"]` |
| `PERSPECTIVE_MEASURE_DOMAINS` | `"Balanced Scorecard": ["Balanced Scorecard"]` |
| `SORT_BY` | `("ssas_dim_bsc_kpi", "kpi_name"): "display_order"`, `("ssas_dim_bsc_kpi", "pillar"): "pillar_order"`, `("ssas_dim_bsc_kpi", "objective_title"): "objective_order"` |
| `ACRONYMS` | `+ "bsc", "kpi"` |
| `DOMAINS` (test_measure_catalogue) | `+ "Balanced Scorecard"` |

- [ ] **Step 1: Failing tests.**
  - In `test_hnh_tmdl.py::test_friendly_names_and_acronyms`, assert `friendly("bsc_category") == "BSC Category"` and `friendly("kpi_code") == "KPI Code"`.
  - Add `test_bsc_tables_generated`: after generation, `tables/BSC KPI.tmdl` contains `column 'KPI Code'` and `relationships.tmdl` relates `'BSC Targets'.'BSC KPI Key'` to `'BSC KPI'.'BSC KPI Key'`.
- [ ] **Step 2: Run** `python -m pytest ssas/tools -q`. Expected: the two tests fail.
- [ ] **Step 3: Implement the config. Run** `python ssas/tools/generate.py --from-contracts`, then add the hierarchy block `Pillar Objective KPI` (levels `Pillar`, `Objective Title`, `KPI Name`) to `tables/BSC KPI.tmdl`, then `python ssas/tools/measure_guards.py` and `python ssas/tools/sync_perspectives.py`.
- [ ] **Step 4: Run** `python -m pytest ssas/tools -q` and BPA. Expected: all pass, and BPA prints "No objects in violation".
- [ ] **Step 5: Commit** ("Add the scorecard tables and perspective to the SSAS model").

---

### Task 3: Building-block measures

Folder `Balanced Scorecard\Building Blocks`. Each has a check for Abha, August 2026, against the value in the right-hand column. The SQL side of each check is the `bsc` view column or the gold query noted.

**GL measures.** These read `'GL FS Monthly'`. Each has `KEEPFILTERS ( 'Date'[Date] <= TODAY () )` so the carried future months are ignored. The FS columns are lower case.

| Measure | Definition | Aug-26 b6 |
|---|---|---|
| `BSC GL Net Revenue` | `- SUM(Movement)` with `[FS Element] = "revenue"` | 23,191,095.16 = `vw_financial.net_revenue_actual` |
| `BSC GL Opex` | `SUM(Movement)` with `[FS Element] = "expenses"`, `[FS Category]` not in {finance cost, zakat, depreciation and amortization}, `[FS Caption]` not in {depreciation, depreciation on rou, amortization of intangible assets, depreciation expense, amortization expense} | 15,466,538.21 = `operating_expenses` |
| `BSC GL EBITDA` | Net Revenue − Opex | 7,724,556.95 = `ebitda_actual` |
| `BSC GL G&A` | `SUM(Movement)`, `[FS Category] = "general and administrative expenses"` | 2,309,139.29 = `ga_expenses_actual` |
| `BSC GL Consumables` | `SUM(Movement)`, `[FS Caption] = "medical consumables"` | 0 = `consumables_actual` (`allow_zero`) |
| `BSC GL Income` | `- SUM(Movement)`, `[FS Type] = "is"` | 6,776,696.42 = `income` |
| `BSC GL Marketing` | `SUM(Movement)`, `[FS Category] = "selling and marketing expenses"` | 390,640 (gold SQL) |
| `BSC GL COGS` | `SUM(Movement)`, `[FS Caption] IN {cost of goods sold, medical consumables}` OR `[FS Line] = "cost of medicines"` | 136,789.33 (gold SQL) |
| `BSC GL AR Average` | Per branch, `AVERAGEX ( VALUES ( 'Date'[Year Month] ), (open + close) ÷ 2 )`, then summed over branches. Close = `SUM('Closing Balance')`; open = `SUM('Opening Balance' + 'Opening Journal Amount')`; `[FS Caption] = "trade receivables, net"` | (93,825,443.90 + 82,828,756.23) ÷ 2 |
| `BSC GL Inventory Average` | Same pattern, caption `inventories, net` | (12,380,731.15 + 12,019,705.94) ÷ 2 |
| `BSC GL Assets Opening` | Per branch, the opening (open + journal) of the first month in context, `[FS Element] = "assets"`, summed over branches | 529,438,340.09 = `assets_opening_balance` |
| `BSC Days in Period` | `COUNTROWS ( CALCULATETABLE ( VALUES ( 'Date'[Date] ), KEEPFILTERS ( 'Date'[Date] <= TODAY () ) ) )` | 31 |

**Budget measures.** These read `'Income Statement'[Budget Most Likely]` with `'Budget Line'[Budget Line Code] = <code>`:

| Measure | Code | Aug-26 b6 |
|---|---|---|
| `BSC Budget Net Revenue` | `REV_NET` | 31,190,437.01 |
| `BSC Budget EBITDA` | `EBITDA` | 8,262,346.77 |
| `BSC Budget Opex` | `TOTAL_DC` + `TOTAL_GA` | 23,021,661.55 |
| `BSC Budget G&A` | `TOTAL_GA` − `GA_MARKETING` | 3,998,614.03 |
| `BSC Budget Consumables` | `DC_CONSUMABLES` | 1,871,426.22 |
| `BSC Budget Medicines` | `DC_MEDICINES` | 2,495,234.96 |

**Capacity measures:**

| Measure | Definition | Aug-26 b6 |
|---|---|---|
| `BSC Available Beds` | Per branch, `AVERAGEX ( VALUES ( 'Date'[Year Month] ), DIVIDE ( SUM ( 'Bed Occupancy'[Is Available] ), DISTINCTCOUNT ( 'Bed Occupancy'[Date Key] ) ) )` with `[Is Inpatient Ward] = "Yes"` and `[Is Excluded Ward] = "No"`, summed over branches | 191.9 (5,949 ÷ 31; the bsc view rounds to 192, tolerance 1) |
| `BSC Licensed Beds` | `SUM ( 'BSC Licensed Beds'[Licensed Beds] )` with `REMOVEFILTERS ( 'Date' )` and `'Date'[Year] IN VALUES ( 'Date'[Year] )` via `TREATAS`, then `AVERAGEX` over years in context | 100 |
| `BSC Clinic Capacity` | `SUM ( Branch[Clinics Count] )` (per branch in context) × `MAX('BSC Parameters'[Clinic Hours Per Day])` × `MAX('BSC Parameters'[Clinic Patients Per Hour])` × working days (`'Date'[Date] <= TODAY ()` and `'Date'[Day Of Week]` ≠ Friday), summed over branches | gold SQL: `clinics_count * 32 * <non-Friday days>` |

**Workforce measures** (`'Workforce Monthly'`). Each averages monthly sums over `VALUES ( 'Date'[Year Month] )` per branch, then adds the branches:

| Measure | Monthly value |
|---|---|
| `BSC Average Headcount` | `SUM(Headcount)` |
| `BSC Average FTE` | `SUM(FTE)` |
| `BSC Average Doctors` | `SUM(Headcount)` with `[Is Doctor] = 1` |
| `BSC Average Medical` | `SUM(Headcount)` with `[Is Medical] = 1` |

August 2026 values for branch 6: 492, 461.5, 169, 374 (`vw_work_force`).

- [ ] **Step 1: Write the checks** in `ssas/tests/measures/balanced_scorecard.json`, one per measure, with the values above (money tolerance 0.01, beds tolerance 1). Add `BSC AR Average ignores future months`: `'Date'[Year Month] = 202612` must equal the October value, because no later month is read. SQL: the AR average of October from `bsc.vw_financial`.
- [ ] **Step 2: Run the offline catalogue test,** `python -m pytest ssas/tools -q`. Expected: FAIL, because the checks reference measures that do not exist.
- [ ] **Step 3: Write the measures unwrapped. Then run** `measure_guards.py` and `sync_perspectives.py`.
- [ ] **Step 4: Run** pytest and BPA. Expected: pass. The DAX side of the checks runs in Task 9.
- [ ] **Step 5: Commit** ("Add the scorecard building-block measures").

---

### Task 4: Financial KPI measures

Folder `Balanced Scorecard\Financial`. One measure per KPI. Each check is for Abha, August 2026.

| KPI | Measure | Formula | Aug-26 b6 |
|---|---|---|---|
| 1, 2 | `BSC Net Revenue` | `[BSC GL Net Revenue]` | 23,191,095.16 |
| 4 | `BSC EBITDA Margin` | EBITDA ÷ Net Revenue | 0.3331 |
| 5 | `BSC Cost to Revenue` | (Net Revenue − EBITDA) ÷ Net Revenue | 0.6669 |
| 63 | `BSC Consumables Ratio` | Consumables ÷ Net Revenue | 0 (`allow_zero`) |
| 6 | `BSC Days in AR (days)` | AR Average × Days ÷ Net Revenue | 118.07 |
| 64 | `BSC Days Inventory (days)` | Inventory Average × Days ÷ COGS | 2,764.9 |
| 8 | `BSC Revenue per Bed` | Net Revenue ÷ Available Beds | 120,786.95 (tolerance 1%) |
| 9 | `BSC Return on Assets` | Income ÷ Assets Opening | 0.0128 |
| 10 | `BSC EBITDA per Bed` | EBITDA ÷ Available Beds | 40,232.07 (1%) |
| 55 | `BSC Revenue per Doctor` | Net Revenue ÷ Average Doctors | 137,225.4 |
| 56 | `BSC EBITDA per Doctor` | EBITDA ÷ Average Doctors | 45,707.4 |

Review Focus 5 check: `BSC EBITDA Margin, branches 1-8, 2026-08`, against `select sum(ebitda_actual)/sum(net_revenue_actual) from bsc.vw_financial where period = '2026-08-01'`.

- [ ] **Steps 1–5:** checks first, catalogue test fails, write the measures, guards and perspectives, pytest + BPA pass, commit ("Add the financial scorecard KPIs").

---

### Task 5: Customer and Internal Process KPI measures

Folders `Balanced Scorecard\Customer` and `Balanced Scorecard\Internal Process`. The Aug-26 b6 values are from the research of 2026-10-21. The SQL side reads `bsc.vw_customer`, `vw_rcm` or `vw_hospital_beds_utilization` where the definition is unchanged, and gold for the Appendix B definitions.

**Customer:**

| KPI | Measure | Formula (SSAS) | Aug-26 b6 |
|---|---|---|---|
| 11 | `BSC Multi-Specialty Revenue Share` | (Revenue with Care Type OP + Revenue with Care Type IP and `'Charge Lines'[Is LTC] = "No"`) ÷ GL Net Revenue | 0.4516 |
| 12 | `BSC Payer Mix` | Revenue (episode payer, `USERELATIONSHIP('Charge Lines'[Episode Payer Key], Payer[Payer Key])`) with `Payer[Category] = "Insurance"` ÷ GL Net Revenue | 0.1755 |
| 13 | `BSC Patient Satisfaction` | `'Survey Answers'[NPS Role] IN {"Hospital NPS", "Physician NPS"}`: (Σ Is Promoter − Σ Is Detractor) ÷ answers × 100. Format `#,0.0`; sample rule as `Hospital NPS (5-point)` | 51.10 |
| 14 | `BSC Patient Retention` | Distinct OP patients (arrived, not cancelled) with `Is Returning = "Yes"` ÷ distinct OP patients | 932 ÷ 2,816 = 0.3310 |
| 15 | `BSC New Patient Acquisition` | OP visits with `Visit Type = "New patient"` and Is Arrived = "Yes" ÷ `[OP Visits]` | 0.4074 |
| 16, 17, 66 | (manual, Task 6) | | |
| 67 | `BSC OP Waiting Time (min)` | `AVERAGE(Encounters[Wait Minutes])`, OP arrived, not cancelled | 35.08 |
| 18 | `BSC Non-MoH Revenue Share` | Revenue (episode payer) with `Payer[Is MOH] = "No"` ÷ GL Net Revenue | 0.2542 |
| 20 | `BSC Payer Volume` | Census with `Payer[Category] = "Insurance"` | 3,838 |
| 62 | `BSC Patient Acquisition Cost` | GL Marketing ÷ distinct new OP patients | 390,640 ÷ 1,627 = 240.10 |

**Internal Process:**

| KPI | Measure | Formula | Aug-26 b6 |
|---|---|---|---|
| 21 | `BSC Bed Occupancy` | `[Bed Occupancy %]` | 0.46747 |
| 22 | `BSC Clinic Utilization` | `[OP Visits]` ÷ `[BSC Clinic Capacity]` | gold SQL |
| 23 | `BSC ALOS (days)` | Average `LOS Days`, countable, `Is LTC = "No"`, physical discharge date | 3.33489 |
| 24 | `BSC OP to IP Conversion` | `[Admissions]` ÷ `[OP Visits]` | 0.0766 |
| 42 | `BSC Patient Volume` | OP Visits + ER Visits + Admissions | 4,997 + 1,631 + 383 |
| 57 | `BSC ER Growth` | ER Visits ÷ ER Visits same period last year − 1 | 0.5215 |
| 58 | `BSC OP Doctor Utilization` | `[OP Visits]` ÷ `SUM('Clinic Capacity'[BSC Capacity Slots])` | 0.2102 |
| 60 | `BSC Activated Beds` | Available Beds ÷ Licensed Beds | 1.919 |
| 25 | `BSC High-Value Revenue Share` | Revenue with `Staff[Is High Value Specialty] = "Yes"` ÷ GL Net Revenue | 0.1287 |
| 26 | `BSC High-Value Census` | (Census with `'Booked Doctor'[Is High Value Specialty] = "Yes"` + countable Admissions with `Staff[Is High Value Specialty] = "Yes"`) ÷ Census | 0.1549 |
| 27 | `BSC OP Revenue per Episode` | Revenue OP ÷ `[Episodes]` with Care Type OP | 509.80 |
| 28 | `BSC Ancillary Utilization` | Revenue OP with `'Product Category'[Is BSC Ancillary] = "Yes"` ÷ Revenue OP | 0.5884 |
| 29 | `BSC Revenue Leakage` | `Invoices[Net Amount]`, invoice date, `Payer[Category] IN {"Insurance","Government"}`, `'Claim Status'[Submission Channel] <> "Manual"`, numerator also `'Claim Status'[Is Submitted] = "No"` | 5.15M ÷ 16.92M = 0.304 (gold SQL) |
| 30 | `BSC Claim Initial Rejection` | `[Claims Rejected]` ÷ `[Claims Submitted]` | 0.0898 |
| 31 | `BSC Order Not Done` | `[Unutilised Approval Rate %]` | 0.1535 |
| 32 | `BSC Approval TAT (min)` | `[Sent to Response Avg (min)]` | 74.56 |
| 34 | `BSC Cost Budget Variance` | (GL Opex − Budget Opex) ÷ Budget Opex | −0.3282 |
| 35 | `BSC G&A Ratio` | GL G&A ÷ GL Net Revenue | 0.0996 |
| 36 | `BSC Readmission 30d` | Countable admissions with `Is Readmission 30d = "Yes"` (admit date) ÷ `[Discharges]` | 10 ÷ 367 = 0.0272 |
| 37 | `BSC Readmission 48h Critical` | `[ICU Readmissions 48h]` ÷ `[Discharges]` with `Bed[Is Critical] = "Yes"` | 0 ÷ 99 (`allow_zero`) |
| 41 | `BSC External Referrals` | Census with `Encounters[Is Referral Policy] = "Yes"` + countable Admissions with `Admissions[Is Referral Policy] = "Yes"` | 475 |

- [ ] **Steps 1–5:** as Task 4, commit ("Add the customer and internal-process scorecard KPIs").

---

### Task 6: Learning & Growth KPIs, manual values, aligned workforce measures

Folder `Balanced Scorecard\Learning & Growth`.

| KPI | Measure | Formula | Aug-26 b6 |
|---|---|---|---|
| 43 | `BSC Turnover` | `SUM('Workforce Monthly'[Resignations])` ÷ Average Headcount | 6 ÷ 492 = 0.0122 |
| 44 | `BSC Revenue per FTE` | GL Net Revenue ÷ Average FTE | 50,251.6 |
| 45 | `BSC Staff to Bed` | Average FTE ÷ Available Beds | 2.404 (1%) |
| 46 | `BSC Saudization` | Snapshot (P20 pattern on `'Workforce Monthly'`, last closed month per branch): Σ Is Saudi × Headcount ÷ Σ Headcount, rows `Row Type = "head"`; `hnh_snapshot = 1` | 126 ÷ 431 = 0.2923 |
| 47 | `BSC Vacancy Rate` | Openings open at the end of the period: Σ `Number To Hire` with Approved Date ≤ last date and (Filled Date blank or > last date), all dates removed, ÷ `SUM('BSC Budgeted FTE'[Budgeted FTE])` of the period's year; `hnh_snapshot = 1` | blank (no budgeted FTE yet; `allow_zero`) |
| 48 | `BSC Time to Fill (days)` | `AVERAGE(Requisitions[Days To Fill])` by filled date | blank in Aug (`allow_zero`) |
| 68 | `BSC Clinical to Doctor` | Average Medical ÷ Average Doctors | 2.213 |
| manual | `BSC Manual Value` | `SELECTEDVALUE('BSC KPI'[KPI Code])`. Σ Numerator ÷ Σ Denominator of `'BSC Manual Values'` for that KPI; when Σ Denominator = 0, ÷ `[Census]` (complaints) | checks: PREMs Abha Jul-26 and Complaint Rate Alrabwah Jul-26 against `default.bsc_patient_satisfaction` |

**Aligned workforce measures (Appendix B):**
- `Turnover Rate %` becomes `[BSC Turnover]`'s formula. It keeps its name and folder `Workforce\Movements`.
- `Saudisation Rate %` becomes `BSC Saudization`'s formula. It keeps its name and folder `Workforce\Headcount` and stays a snapshot.
- Update their checks in `ssas/tests/measures/workforce.json` to the `vw_work_force` SQL: `resignations / headcount`, and `saudi_headcount / (headcount - pt_doctors_headcount)`.

- [ ] **Steps 1–5:** as Task 4. Add `BSC Saudization` and `BSC Vacancy Rate` to the five snapshot lists. Commit ("Add the learning-and-growth scorecard KPIs and align turnover and Saudisation").

---

### Task 7: Targets, dispatchers and scoring

Folders `Balanced Scorecard\Targets` and `Balanced Scorecard\Scoring`. Every measure here carries `annotation hnh_guard_allow = BSC KPI`.

**Budget target measures** (one per KPI with `target_source = budget`):

| KPI | Measure | Formula |
|---|---|---|
| 1 | `BSC Target Net Revenue` | Budget Net Revenue |
| 4 | `BSC Target EBITDA Margin` | Budget EBITDA ÷ Budget Net Revenue |
| 5 | `BSC Target Cost to Revenue` | (Budget Net Revenue − Budget EBITDA) ÷ Budget Net Revenue |
| 63 | `BSC Target Consumables Ratio` | Budget Consumables ÷ Budget Net Revenue |
| 64 | `BSC Target Days Inventory (days)` | Inventory Average × Days ÷ (Budget Consumables + Budget Medicines) |
| 8 | `BSC Target Revenue per Bed` | Budget Net Revenue ÷ Available Beds |
| 10 | `BSC Target EBITDA per Bed` | Budget EBITDA ÷ Available Beds |
| 55 | `BSC Target Revenue per Doctor` | Budget Net Revenue ÷ Average Doctors |
| 56 | `BSC Target EBITDA per Doctor` | Budget EBITDA ÷ Average Doctors |
| 11 | `BSC Target Multi-Specialty Share` | ([Target Revenue] Care Type OP + [Target Revenue] Care Type IP with `Targets[Stay Type] <> "LTC"`) ÷ Budget Net Revenue |
| 12 | `BSC Target Payer Mix` | [Target Revenue] with `Targets[Creditor] = "Insurance"` ÷ Budget Net Revenue |
| 18 | `BSC Target Non-MoH Share` | [Target Revenue] with `Targets[Creditor] <> "Government"` ÷ Budget Net Revenue |
| 20 | `BSC Target Payer Volume` | [Target Census] with `Targets[Creditor] = "Insurance"` |
| 22 | `BSC Target Clinic Utilization` | [Target Census] OP ÷ Clinic Capacity |
| 24 | `BSC Target OP to IP` | [Target Census] IP ÷ [Target Census] OP |
| 42 | `BSC Target Patient Volume` | [Target Census] OP + ER + IP |
| 57 | `BSC Target ER Growth` | [Target Census] ER ÷ ER Visits PY − 1 |
| 27 | `BSC Target OP Revenue per Episode` | [Target Revenue] OP ÷ [Target Episodes] OP |
| 28 | `BSC Target Ancillary Utilization` | `MAX('BSC Parameters'[Ancillary Target Share])` (seeded 0.6, the handover rule OP target × 0.6 ÷ OP target) |
| 35 | `BSC Target G&A Ratio` | Budget G&A ÷ Budget Net Revenue |
| 44 | `BSC Target Revenue per FTE` | Budget Net Revenue ÷ Average FTE |

**Dispatchers and scoring.** `Code` = `SELECTEDVALUE('BSC KPI'[KPI Code])`.

| Measure | Definition |
|---|---|
| `BSC Actual` | If `'BSC KPI'[Status]` is `parked`: BLANK. If `Value Source` is `manual`: `[BSC Manual Value]`. Otherwise `SWITCH ( Code, "FIN_NET_REVENUE", [BSC Net Revenue], … )`, one line per measure KPI code, evaluated with `REMOVEFILTERS('BSC KPI')` and `KEEPFILTERS(Branch[Is Hospital] = "Yes")`. Format via `formatStringDefinition` from `'BSC KPI'[Value Format]` (sar `#,0`, pct `0.0%`, days and mins `#,0.0`, num `#,0.00`) |
| `BSC Target` | By `'BSC KPI'[Target Source]`: `fixed` → `AVERAGE('BSC Targets'[Target Value])` × (months in context ÷ 12 when `Scale With Months` = 1); `budget` → `SWITCH(Code, …)` over the target measures; `prior_year` → `CALCULATE([BSC Actual], SAMEPERIODLASTYEAR('Date'[Date]))`; `none` → BLANK |
| `BSC Variance %` | For `higher`: (actual − target) ÷ \|target\|. For `lower` and `ceiling`: (target − actual) ÷ \|target\|. For `on_target`: −\|actual − target\| ÷ \|target\|. If the target is 0: actual − target |
| `BSC Score` | `MIN(100, MAX(0, ROUND(Score Base + Score Slope × 100 × Variance %, 0)))` from `'BSC KPI'` |
| `BSC Status` | "On track" if score ≥ Good From; "Watch" if score ≥ Watch From; otherwise "At risk" |
| `BSC State` | "Parked" if status is parked, or if `[BSC Actual]` is blank over all dates. "No data yet" if `[BSC Actual]` is blank. Otherwise `[BSC Status]` |
| `BSC KPI Weight` | For one hospital: `SUM('BSC Weights'[Weight])`. Otherwise `SUM('BSC KPI'[Corporate Weight])` |
| `BSC Pillar Score` | `DIVIDE ( SUMX ( FILTER ( VALUES ( 'BSC KPI'[KPI Code] ), NOT ISBLANK ( [BSC Score] ) ), [BSC Score] * [BSC KPI Weight] ), SUMX ( …same filter…, [BSC KPI Weight] ) )` |
| `BSC Overall Score` | Over `VALUES('BSC KPI'[Pillar])`: Σ pillar score × pillar weight ÷ Σ pillar weight, counting pillars with a score |
| `BSC Trend` | `CONCATENATEX` of `[BSC Actual]` over the 12 months ending at the last month in context, separated by `;`, in month order |

**Checks:**
- `BSC Actual, all hospitals vs sum of 1-8`: FIN_NET_REVENUE with no branch filter = `sum(net_revenue_actual)` from `bsc.vw_financial` for 2026-08.
- `BSC Actual per KPI row is numeric`: `EVALUATE ROW("v", COUNTROWS(FILTER(ADDCOLUMNS(VALUES('BSC KPI'[KPI Code]), "a", [BSC Actual]), ISTEXT([a]))))` = 0.
- `BSC State`:
  - FIN_NET_COLLECTION → "Parked";
  - CUS_PREMS at Abha in Aug-26 → "No data yet" (manual rows only to Jul);
  - LRN_DOA_COMPLIANCE → "Parked".
- `BSC Target`:
  - fixed INT_ALOS = 4;
  - LRN_TURNOVER for Q1-2026 = 0.015 (0.06 × 3 ÷ 12);
  - budget FIN_NET_REVENUE = 31,190,437.01;
  - prior-year FIN_REVENUE_GROWTH = 12,843,310.36.
- `BSC Score`: INT_ALOS at Abha Aug-26 = round(85 + 0.6 × 100 × (4 − 3.33489) ÷ 4) = 95.
- `BSC KPI Weight, two hospitals` = `corporate_weight` of FIN_NET_REVENUE.

- [ ] **Steps 1–5:** as Task 4, commit ("Add scorecard targets, dispatchers and scoring").

---

### Task 8: Perspective, catalogue and documents

- [ ] **Step 1:** `python ssas/tools/sync_perspectives.py`. Confirm that `perspectives/Balanced Scorecard.tmdl` lists every `Balanced Scorecard\…` measure and the tables of Task 2.
- [ ] **Step 2:** Add "Balanced Scorecard" to the domain list in `ssas/README.md:33`. Add a "Balanced scorecard" section there that points to `docs/bsc_config.md` for settings and to `_Measures.tmdl` for formulas.
- [ ] **Step 3: Run the full offline suite:** `python -m pytest ssas/tools -q`, BPA, `Invoke-Pester -Script ssas\scripts`. Expected: everything passes, "No objects in violation".
- [ ] **Step 4: Commit** ("Document the scorecard perspective").

---

### Task 9: Deploy and verify (approval required at each step)

- [ ] **Step 1: Ask the user, then run** `powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage TestMeasures`. Expected: every check in `balanced_scorecard.json`, `workforce.json` and the other measure files passes on `HNH_Analytics_Test`. On a failure: stop, use systematic-debugging, fix, re-run.
- [ ] **Step 2: Performance (read-only DAX on the test database).** One query with `SUMMARIZECOLUMNS('BSC KPI'[KPI Code], Branch[Branch Name], 'Date'[Year Month], "a", [BSC Actual], "t", [BSC Target], "s", [BSC Score])` for 2026, plus `[BSC Trend]` per KPI. Record the times in `ssas/tests/performance.json`. Target: under 10 s each.
- [ ] **Step 3: Ask the user, then run** `deploy.ps1 -Stage All` (validate, test with row counts and security, promote to `HNH_Analytics`). Expected: the stages pass and the backup is taken.
- [ ] **Step 4: Commit** the performance results ("Verify the scorecard measures on the test database").
