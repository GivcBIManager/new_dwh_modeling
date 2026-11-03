# HNH Workforce report (HR dashboard, Report Server)

A Python generator writes the HR dashboard as a Power BI project (PBIP): `HNH Workforce.pbip`, with the folders `HNH Workforce.Report/` (pages, visuals, theme, logo) and `HNH Workforce.SemanticModel/` (only the live connection to the `HR Dashboard` perspective of `HNH_Analytics`). Design: `docs/superpowers/specs/2026-11-02-hr-dashboard-design.md`; plan: `docs/superpowers/plans/2026-11-02-hr-dashboard.md`.

To put the dashboard live, follow the [deployment checklist](#deployment-checklist) below, in order.

The generator reuses the Balanced Scorecard generator's modules in `powerbi_tmdl/hnh_bsc_report/` (`frame`, `model`, `pbir`, `fields`, `pbir_check`, and its `pages.py` helpers loaded as `bsc_pages`); nothing is copied. The theme and the logo are the BSC's files. The report has no custom visual, no bookmarks, no visual groups and no report-level measures: every measure is in the model.

Code:

- `hr_frame.py`: `HR_FRAME` (title "Workforce" / "Hayat Healthcare", tabs Home, Story, Scorecard, Details, Data quality, Guide, and the How to use and Definitions buttons), `HR_REPORT` (name, perspective, theme, logo), `page_frame(tab, bar)`, the filter bar (`filters()`: Hospital and Month, Month saved on "Last closed month"; `sub_tabs(current)`: the six detail pages), `kpi_tile(code, x, y, w, h)`, and the KPI list read from `scripts/hr_config/hr_config_seed.sql` (`seed_kpis()`, `home_tile_codes()`, `kpi_label()`).
- `pages_home.py`: Home. `pages_story.py`: Story. `pages_scorecard.py`: Scorecard and KPI detail.
- `pages_detail.py`: the six detail pages (Headcount & mix, Movements & turnover, Payroll & overtime, Absence & leave, Recruitment, Productivity) and the hidden Employee list. `pages.py`: `PAGES` (in order) and `REPORT_FILTERS` (this year and last year).

## Detail pages and the Employee list

Each detail page has the Details tab current and the six sub-tabs in the filter bar, its own slicers where every visual on it accepts them, one or two rows of cards for the selected month, a 2 x 2 grid of charts and, below it, rows of three more. Pages taller than 1080 px are written "FitToWidth" (`pbir.page_json`), so they scroll instead of shrinking. Absence by department and payroll by job are not shown (ruling R26: those facts have no department or job). Line charts show the last 12 closed months whatever the Month slicer says (as on Story). The pages show hospitals only, as Home's area cards.

Every model measure returns "... can't be analysed by <table>" when a table its guard rejects is filtered. `pages_detail.blocked_tables` reads those tables from `_Measures.tmdl`: the build stops when a visual's axis, a page slicer or a drill field is one of them, and a click in a chart does not reach a visual whose measures reject the chart's tables (a NoFilter interaction, written by the generator). So Payroll has only a Department slicer (`Payroll Cost per FTE` rejects Pay Category), Absence & leave, Recruitment and Productivity have none.

Pay figures (Payroll, Productivity, the leave figures on Absence & leave) have an `[HR Pay Notice]` card over them, shown only without pay access; their cards are filtered to non-blank, so they show nothing rather than "(Blank)". Fusion leaver figures are labelled "in Fusion"; the headline turnover is `[BSC Turnover]`.

The Employee list is reached by drill-through on a hospital or an HR department, with "keep all filters" off (a source visual's own filters, such as 'HR KPI' or 'Pay Category', would turn `[Headcount]` into its guard message). The month and the Department, Job, Grade, Nationality and Worker type selections come from its slicers, synced with the detail pages'. Its one table is filtered to `[Headcount]` not blank, so branch security applies through the fact. The Fusion name is the measure `[HR Employee Name]` (blank without pay access), never an 'Employee Details' column: a table grouped by a column with no visible rows has no rows, so the column would empty the list for readers without pay access. `[Headcount]` is a column too, because a table drops the rows where all its measures are blank.
- `build.py`: the CLI.

Test with `python -m pytest powerbi_tmdl/hnh_hr_report/tests -q`. Both report folders have a `pages.py` and a `build.py`; the HR tests load this folder's `pages.py` as `hr_pages` so that `python -m pytest powerbi_tmdl` runs both suites in one session.

## Build the project

Run from the repository root:

`python powerbi_tmdl/hnh_hr_report/build.py`

The arguments are the BSC `build.py`'s. The defaults are `--database HNH_Analytics_Test` and `--server HNHANALYTICSSRV\REPORTSERVERDB`; `--out` is the folder for the project and defaults to this folder. Only the project is built (`--format pbip`); `--pbiviz` is not used. The command stops if a field is not in the `HR Dashboard` perspective. It then prints `report schemas: passed` and `Desktop project reader: opened`, and exits 1 on any problem. Commit the regenerated project.

The server reads only the legacy package: write it with `powerbi_tmdl/hnh_bsc_report/pbir_to_pbix.py` as `powerbi_tmdl/README.md` describes (section "HNH Workforce (HR dashboard) route": the commands, the checks on first open, and the switch to production).

`python powerbi_tmdl/hnh_bsc_report/pbir_to_pbix.py "powerbi_tmdl/hnh_hr_report/HNH Workforce.pbip" --out "C:\HNH\report\HNH Workforce.pbix"`

The switch to production is `build.py --database HNH_Analytics` after the model is deployed to production; then convert again.

## KPI tiles and status

A KPI tile shows `[HR KPI Actual Text]` (the formatted actual; "Requires pay access" for a pay KPI without pay access) under the KPI's short label, `[HR KPI Target Text]` (with "(placeholder)" while the target is one), and `[HR KPI Status Text]` (shape and word) in the colour of `[HR KPI Status Colour]`, set as the card's value colour by conditional formatting (field value). Home's tiles are the seed's `is_home_tile` KPIs in `display_order`, read from `scripts/hr_config/hr_config_seed.sql` when the report is built: a change to `is_home_tile` or `short_label` needs the seed file changed and the report rebuilt (`docs/hr_config.md`). Pages that show these measures carry only the Hospital and Month slicers, and on Scorecard and KPI detail the Period slicer. Home's Payroll and Productivity area cards use the pay-aware `[HR Payroll Cost Text]` and `[HR Visits per FTE Text]`.

The Scorecard table shows, per KPI, the status, actual, target, variance (`[HR KPI Variance Text]`, actual minus target in the KPI's format) and watch value (`[HR KPI Watch Text]`). Every one of them is a text measure that says "Requires pay access" for a pay KPI to a reader without pay access: a pay KPI's target is a pay level, so `[HR KPI Target]`, `[HR KPI Watch]` and `[HR KPI Variance]` are blank for that reader too (final review C1). KPI detail's chart notice is `[HR KPI Pay Notice]`, shown only for a pay KPI. Definitions shows the target and the watch value.

The Month slicer is single-select on `'Date'[Month Pick]` and saved on "Last closed month": the model gives that label to the previous month each day, so every page opens on the last closed month without a rebuild. Scorecard and KPI detail also have Period (single-select on `'Time Calculation'`, saved on Current; Current, QTD, YTD), synced between those two pages: under YTD the KPIs read January to the selected month, a flow KPI's annual target pro-rated by the months and a month-end KPI at the month end. KPI detail's 24-month line ignores Period. Story stays on one month (R18).

Every data page shows hospitals only (a page filter on `Branch[Is Hospital]`), as the HR KPI measures do; Home filters each visual instead, so that its data quality strip still counts Head Office records. Data quality and the Guide pages are not filtered.

## Deployment checklist

In this order. A step marked **user's go-ahead** changes the production server or live data (`CLAUDE.md`): ask at the time, every time. The other steps are read-only.

1. **dbt build in the receiving project** (user's go-ahead). First read "The production Date table" below. If the config tables do not exist yet, create them with `scripts\hr_config\apply_hr_config.ps1` (`-DryRun` first; the real run is a ClickHouse write, its own go-ahead). Copy the models as `docs/receiving_project_config.md` ("HR dashboard") lists them, then:
   `dbt build --select stg_ref__hr_*+ fact_hr_dq_record+ dim_date+`
2. **Regenerate the view contracts** (read-only): `python scripts/gen_view_contracts.py`. It needs `clickhouse_connect`; where it is missing, use the ODBC equivalent through DSN `HNH_Gold` (ruling R10: the same `describe` per `gold.ssas_*` view; installing the package is a software install, its own go-ahead). Confirm that the only change is the 4 HR views and that `month_pick String` is the last column of `ssas_dim_date` (`python -m pytest ssas/tools/test_hr_perspective.py`).
3. **Model to the test slot** (user's go-ahead): `powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage TestMeasures`, then (read-only) `powershell -ExecutionPolicy Bypass -File ssas\scripts\test.ps1 -Database HNH_Analytics_Test -Stage Security` and the same with `-Stage Measures` (one stage per run: `-File` passes `Security,Measures` as one word). The Security stage logs on as each user of `ssas/tests/security.json` and, with the HR tables deployed, checks `HR pay targets`: for a user without pay access (`EXE_ABH`, `CTL_RBW`) every pay KPI's target, watch value and variance are blank and their texts and `[HR KPI Pay Notice]` say "Requires pay access"; for a pay user (`HRM_CORP`) they never do.
4. **Placeholder targets.**
   1. `powershell -ExecutionPolicy Bypass -File scripts\hr_config\build_hr_placeholders.ps1 -Database HNH_Analytics_Test -Out scripts\hr_config\hr_config_update_<date>.sql` (read-only DAX). Review the values with the user; flow KPIs (turnover, new-hire turnover, staff cost per FTE, revenue per doctor) are annualised x 12/9.
   2. `scripts\hr_config\apply_hr_config.ps1 -Update <file>` (user's go-ahead: ClickHouse write).
   3. `dbt build --select stg_ref__hr_*+` in the receiving project (user's go-ahead; the file also re-inserts `map_hr_kpi` rows, so not only `stg_ref__hr_target+`).
   4. `powershell -ExecutionPolicy Bypass -File ssas\scripts\process.ps1 -Database HNH_Analytics_Test -Mode Daily -Force` (user's go-ahead).
   5. `test.ps1 -Database HNH_Analytics_Test -Stage Measures`, then `-Stage Security`, again (read-only): the direction-rule and YTD checks now compare real targets (ruling R12). Commit the update file.
5. **Report.** `python powerbi_tmdl/hnh_hr_report/build.py`, then `pbir_to_pbix.py` and `pbix.check_upload_rules` (`[]`) as `powerbi_tmdl/README.md` ("HNH Workforce (HR dashboard) route") shows. Open the file in Desktop for Report Server and go through that section's first-open checks, as `HRM_CORP` and as `EXE_ABH`. Upload (user's go-ahead).
6. **Dagster nightly selector** (user's go-ahead: a change to the Dagster job on the dbt server). Add `stg_ref__hr_*+ fact_hr_dq_record+` to the nightly dbt job's selector, and set the SSAS refresh asset's `selected` (`ssas/dagster/hnh_analytics_refresh.py`, passed to `process.ps1 -Selected`) to that job's selector, so the gate opens after the run that built the HR models. Until then a change to the HR config shows only after steps 4.3 and 4.4 by hand.

Switching the report to production (`build.py --database HNH_Analytics`) follows a production deploy of the model (`deploy.ps1 -Stage Promote`, its own go-ahead).

### The production Date table

Step 1 rebuilds `gold.ssas_dim_date` with one more column, `month_pick`, which the production `HNH_Analytics` model does not have until the HR model is deployed there.

- **How a partition reads its view.** Every partition is a Power Query (M) partition, `Odbc.Query("dsn=HNH_Gold", "select * from gold.<view>")` (`ssas/tools/hnh_tmdl.py` `odbc_expression`; the Date table's in `ssas/HNH_Analytics/tables/Date.tmdl`). Each data column of the table names its source with `sourceColumn`; the engine fills each such column from the result column of that name. A result column that no `sourceColumn` names is not loaded; a `sourceColumn` the result lacks fails the refresh. By that binding the extra `month_pick` is ignored, and the Daily process (`process.ps1` refreshes the Date table DataOnly every day) loads the production Date table as before.
- **Not yet proven on this server.** The production model was last processed on 2026-10-11 (`$SYSTEM.TMSCHEMA_PARTITIONS`: all 528 partitions), and 12 of its tables already read views with columns it does not bind (2026-11-03): Branch (`bsc_category`, `is_hospital`), Payroll (`oasis_payment_amount`, `oasis_deduction_amount`), Claim Lines (`claim_status_key`, `response_benefit_amount`), Invoices (`claim_status_key`), Admissions and Encounters (`is_referral_policy`), the three staff role tables (`is_high_value_specialty`), Clinic Capacity (`bsc_capacity_slots`), Product Category (`is_bsc_ancillary`), Revenue Adjustments (`staff_key`). No production process has run since, so the next one meets extra columns whether or not step 1 runs.
- **If it fails.** `process.ps1` commits the whole refresh in one transaction: a column error rolls it back, the production data stays as it was, and the script (and Dagster) exits 1.
- **Check before the nightly production run** (user's go-ahead): run `powershell -ExecutionPolicy Bypass -File ssas\scripts\process.ps1 -Database HNH_Analytics -Mode Daily -Force` once by hand and read its log in `ssas/logs` (`Daily processing of HNH_Analytics committed`). It covers the Date table and the 12 tables above, and changes nothing if it fails. If it fails on a column, deploy the current model to production (`deploy.ps1 -Stage Promote`, which binds `month_pick` and the other columns) before the nightly run, or process the test slot's Date table under pre-HR metadata to confirm the cause.
