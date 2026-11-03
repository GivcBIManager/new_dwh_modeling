# HNH Workforce report (HR dashboard, Report Server)

A Python generator writes the HR dashboard as a Power BI project (PBIP): `HNH Workforce.pbip`, with the folders `HNH Workforce.Report/` (pages, visuals, theme, logo) and `HNH Workforce.SemanticModel/` (only the live connection to the `HR Dashboard` perspective of `HNH_Analytics`). Design: `docs/superpowers/specs/2026-11-02-hr-dashboard-design.md`; plan: `docs/superpowers/plans/2026-11-02-hr-dashboard.md`.

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

The server reads only the legacy package: write it with `powerbi_tmdl/hnh_bsc_report/pbir_to_pbix.py` as `powerbi_tmdl/README.md` describes.

## KPI tiles and status

A KPI tile shows `[HR KPI Actual Text]` (the formatted actual; "Requires pay access" for a pay KPI without pay access) under the KPI's short label, `[HR KPI Target Text]` (with "(placeholder)" while the target is one), and `[HR KPI Status Text]` (shape and word) in the colour of `[HR KPI Status Colour]`, set as the card's value colour by conditional formatting (field value). Home's tiles are the seed's `is_home_tile` KPIs in `display_order`. Pages that show these measures carry only the Hospital and Month slicers. Home's Payroll and Productivity area cards use the pay-aware `[HR Payroll Cost Text]` and `[HR Visits per FTE Text]`.

The Month slicer is single-select on `'Date'[Month Pick]` and saved on "Last closed month": the model gives that label to the previous month each day, so every page opens on the last closed month without a rebuild.
