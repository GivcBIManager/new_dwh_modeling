# HNH Workforce report (HR dashboard, Report Server)

A Python generator writes the HR dashboard as a Power BI project (PBIP): `HNH Workforce.pbip`, with the folders `HNH Workforce.Report/` (pages, visuals, theme, logo) and `HNH Workforce.SemanticModel/` (only the live connection to the `HR Dashboard` perspective of `HNH_Analytics`). Design: `docs/superpowers/specs/2026-11-02-hr-dashboard-design.md`; plan: `docs/superpowers/plans/2026-11-02-hr-dashboard.md`.

The generator reuses the Balanced Scorecard generator's modules in `powerbi_tmdl/hnh_bsc_report/` (`frame`, `model`, `pbir`, `fields`, `pbir_check`, and its `pages.py` helpers loaded as `bsc_pages`); nothing is copied. The theme and the logo are the BSC's files. The report has no custom visual, no bookmarks, no visual groups and no report-level measures: every measure is in the model.

Code:

- `hr_frame.py`: `HR_FRAME` (title "Workforce" / "Hayat Healthcare", tabs Home, Story, Scorecard, Details, Data quality, Guide, and the How to use and Definitions buttons), `HR_REPORT` (name, perspective, theme, logo), `page_frame(tab, bar)`, the filter bar (`filters()`: Hospital and Month, Month saved on "Last closed month"; `sub_tabs(current)`: the six detail pages), `kpi_tile(code, x, y, w, h)`, and the KPI list read from `scripts/hr_config/hr_config_seed.sql` (`seed_kpis()`, `home_tile_codes()`, `kpi_label()`).
- `pages_home.py`: Home. `pages.py`: `PAGES` (in order) and `REPORT_FILTERS` (this year and last year).
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
