# HNH Finance report

Power BI report "HNH Finance" on the `Finance Report` perspective, generated with the BSC generator's modules
(`../hnh_bsc_report`), like `../hnh_hr_report`. Eleven pages: Home (`pages_home.py`, the page the report opens on:
headline tiles, a card per statement with its two views), a monthly and a hospitals view of the Trial Balance, Income
Statement, Balance Sheet and KPIs & Ratios, then How to use and Definitions (`pages_home.py`; the KPI formulas in
`KPI_DEFINITIONS`, kept in step with `dim_finance_kpi.sql` by a test). Every page has the frame (`fin_frame.py`): seven
tabs (Home, the four statements, How to use, Definitions); the statement pages add the view buttons, the Hospital /
Year / Month drop-down slicers (synced across pages) and the period text. Every page but Home is hidden: the tabs and
buttons are the navigation. Every page carries the locked page filter `Branch[Branch Key]` in 1..8 (hospitals only).

The trial balance, income statement and balance sheet pages (`pages_statements.py`) add four tiles, two charts
driven by the matrix row (by month on the monthly pages, by hospital on the hospitals pages), a header and the
statement matrix (`fin_blocks.py`); the income statement hides its grand total row (R9e) and bands its subtotal lines
([FR Row Band]); the balance sheet shows [FR BS Difference] at the right of the matrix's header.

    python powerbi_tmdl/hnh_finance_report/build.py [--database HNH_Analytics_Test]
    python -m pytest powerbi_tmdl/hnh_finance_report

`build.py` writes `HNH Finance.pbip` here and checks it against Power BI Desktop's schemas and project reader (offline).
The Report Server package is written from the project by `../hnh_bsc_report/pbir_to_pbix.py` (`../README.md`).

## Route to Report Server

1. `python powerbi_tmdl/hnh_finance_report/build.py` (prints `report schemas: passed` and `Desktop project reader: opened`).
2. `python powerbi_tmdl/hnh_bsc_report/pbir_to_pbix.py "powerbi_tmdl/hnh_finance_report/HNH Finance.pbip" --out "C:\HNH\report\HNH Finance.pbix"`.
3. `check_upload_rules` on the file must print `[]` (from `powerbi_tmdl/hnh_bsc_report`: `python -c "from pbix import check_upload_rules; print(check_upload_rules(r'C:\HNH\report\HNH Finance.pbix'))"`).
4. Open the `.pbix` in Desktop for Report Server without saving. Upload into a new Finance folder at `http://hnhanalyticssrv/reports` only on the user's go-ahead.

The report points at `HNH_Analytics_Test` until the model is deployed to production (G5). Then rebuild with `--database HNH_Analytics`, convert again and upload that file (a separate go-ahead).

## Deployment checklist

In this order. Every step except the read-only ones needs the user's go-ahead at the time, every time (`CLAUDE.md`).

- **G1 ClickHouse.** `powershell -ExecutionPolicy Bypass -File scripts\finance_config\apply_finance_config.ps1` (`-DryRun` first). It creates the two empty config tables `map_finance_budget` and `map_finance_target` (`docs/finance_config.md`). A write to production ClickHouse.
- **G2 dbt** (the user, in the receiving project, off-hours, `--threads 1`): `dbt build --select stg_bsc__oasis_gl_line stg_bsc__oasis_gl_account fact_gl_fs_monthly+ fact_pl_report_monthly+ dim_pl_report_line+ stg_ref__finance_budget+ stg_ref__finance_target+ dim_finance_kpi+ dim_finance_column+ dim_date+`. It must end with ERROR=0: the unit and yml tests run, among them `assert_gl_fs_debit_credit_ties`, `assert_pl_line_budget_link`, `assert_pl_report_ties_to_gl` and the title-case test. Then run `python ssas/tools/generate.py` against ClickHouse (read-only; not `--from-contracts`), so the sort-by pairs are validated against the real views. `generate.py` writes the model's TMDL files into `ssas/HNH_Analytics` (tables, relationships, perspectives): read `git diff ssas/HNH_Analytics` to compare with the hand-written contracts, and run `generate.py --from-contracts` again if they differ.
- **G3 test slot.** `deploy.ps1 -Stage TestMeasures`, which loads only the partitions not yet processed (new tables). Tables that already hold data (`GL FS Monthly`, `P&L Report`, `P&L Line`, `Finance *`, `Date`) are refreshed by `powershell -ExecutionPolicy Bypass -File ssas\scripts\process.ps1 -Database HNH_Analytics_Test -Mode Daily -Force` (`process.ps1` takes no table list; it refreshes the daily partitions and the small tables). Read-only checks: `python ssas/tools/check_measure_sql.py`, then `test.ps1` one stage per run (`-Stage Measures` for the finance, BSC and HR checks, then `-Stage Security`). Then compare the scorecard before and after the unified definitions (`ssas/README.md`, "Finance report"): `ssas/scripts/compare_bsc_actuals.ps1 -Database HNH_Analytics_Test -YearMonth 202610 -Out C:\HNH\finance\bsc_after.csv`, then `-Compare C:\HNH\finance\bsc_before.csv,C:\HNH\finance\bsc_after.csv` (one comma-separated pair, no space). Before-snapshots exist for 202610 and 202609; October's GL is thin, so read 202609 too. Show the user the table before production.
- **G4 upload.** Build, convert, `check_upload_rules` returns `[]`, open in Desktop for Report Server, upload (Route above). Take screenshots of the pages against the canvas.
- **G5 production** (separate, later). `deploy.ps1 -Stage Promote`, rebuild with `--database HNH_Analytics`, upload again.

## Nightly refresh

The nightly Dagster dbt selection must include `stg_ref__finance_*`, `fact_finance_budget_monthly`, `dim_finance_*` and the changed `fact_gl_fs_monthly`, `fact_pl_report_monthly` and `dim_pl_report_line` (with their `ssas_*` views). The Dagster dbt runs are not `tag:hnh`, so add them to the selector, or edits to the finance config tables (`default.map_finance_budget`, `default.map_finance_target`) never reach the report.

## How to test as a one-hospital user

Log in to Windows as a non-admin member of `HNH_BI_Users` limited to one hospital (for example `HNHANALYTICSSRV\EXE_ABH`). An SSAS server administrator bypasses the row filters. A domain reader needs a `bi_users.csv` row with the UPN `<name>@hnhriyadh.com`, or sees no data. Every hospital page then shows that hospital's figures and blanks for the others, and "All hospitals" equals the one hospital.

## To check on first open

Not yet done. Desktop for Report Server, then the portal.

- Year opens on "Current year". It offers 2022 to 2040 (a fixed list, no yearly rebuild). Months are picked in the Month slicer.
- The cutover difference column appears only when the selection crosses a branch's cutover (the move from Oasis to Fusion).
- "Not budgeted" (the line has no budget row) and "No budget yet" (no budget is loaded for that hospital and period) read differently. With an unbudgeted hospital in the selection the column reads "vs budget (budgeted hospitals)": the comparison is like for like.
- The balance sheet Difference card shows the cutover difference and the unmapped accounts (it includes the "Not mapped" side). "Current year profit" is the year-to-date total comprehensive income.
- The income statement's grand total row is hidden.
- Hospital pages are metric first: each metric shows the eight hospitals, then All hospitals.
- A click on a matrix row filters the charts, not the tiles or the header.
- The KPI heat map is unshaded until targets are entered in `map_finance_target`.

## Known generator limits

- The matrix header is one colour (no per-group bands).
- Only the first row level is open; the reader expands the rest.
- Income statement subtotal lines are banded, not bold.
- Chart titles are static.
- The hospital slicer reads "Select all".
- Tile labels may clip: check in Desktop.
