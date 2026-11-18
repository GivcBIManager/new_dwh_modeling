# Finance Report (HNH Finance) design

Date: 2026-11-18. Status: for the user's approval (builder check done; the user's answers on "All" budgets and one
set of definitions are in).
Look: the Design canvas "Finance Power BI Report" (https://claude.ai/code/artifact/b040a4c2-d19e-43b9-b198-fa53d17d23f7,
four 1920 x 1080 artboards: Trial Balance, Income Statement, Balance Sheet, KPIs & Ratios). The canvas runs on made-up
data ("Illustrative data"); its numbers, account codes, hospital names and KPI targets are not used.

## Intent

A Power BI report on the SSAS model for **both management and the finance team**: management reads the hospitals'
results against budget and last year, finance checks the trial balance and the balance sheet month by month. It is
the first finance report on `HNH_Analytics`; the old `powerbi_tmdl/Financial Statements updated/` model (GLTransactions,
AccountTree) is not reused.

### Goals

- Four statements, each in two views: **Monthly** (one hospital or all, by month) and **Hospital comparison** (the
  eight hospitals side by side with the total). Eight pages.
- **History**: actuals from the merged Oasis and Fusion GL (each branch-month from one system, Oasis before the
  branch's first Fusion GL month, Fusion from it), so last year and growth work from 2023 on (data from 2022).
- **Budget kept** wherever it exists (the income statement budget lines, most likely scenario) and a **labelled
  placeholder** wherever it does not, with a table the user fills in later.
- **KPI targets** in a new table the user fills in later (`map_finance_target`); until then a labelled placeholder
  ("No target yet").
- **One set of finance definitions** across the model: the scorecard's financial measures are rewritten on the same
  building blocks as this report (see that section).
- Built and published as the repo's other reports: a generator writes the PBIP, `pbir_to_pbix.py` writes the legacy
  package Power BI Report Server reads (`powerbi_tmdl/README.md`).

### Non-goals

- Head Office as a page column or slicer item (the canvas shows the eight hospitals; `fact_gl_fs_monthly` holds
  branches 1-8 only). Head Office stays out of every page, including the income statement, though the P&L Report has
  it.
- The P&L Report's specialty, service location and service group slicers (Fusion only); a later page can add them.
- Worst-case budget scenario, Arabic labels, AP pages (AP tables stay in the Finance perspective for other reports).
- Changing the `bsc` dbt models (`bsc_vw_financial` keeps the old server's values, CLAUDE.md). The scorecard's
  **SSAS measures** do change: see "One set of finance definitions".

### Anti-goals (a failure even if it technically works)

- A number that looks like a budget or target but was invented. Placeholders read "No budget yet" / "No target yet";
  no seeded figures.
- EBITDA or gross profit that jumps at a hospital's Oasis-to-Fusion cutover because a line moved section.
- Measures in the report (`reportExtensions.json`) or bookmarks: the converter refuses both.
- A trial balance that hides an out-of-balance: the difference is shown, not plugged.

## Constraints

- Production server rules (CLAUDE.md): dbt builds, ClickHouse DDL/inserts, SSAS deploys and processing, and the
  upload each need the user's go-ahead. Read-only DAX and offline checks do not.
- Power BI Report Server (May 2026) reads only `Report/Layout`; no bookmarks, report measures, visual groups,
  AppSource visuals or hierarchy fields (`powerbi_tmdl/README.md`). So the canvas's in-page toggles (view switch,
  period presets, expand-to-level buttons, row selection state) become pages, slicers and the matrix's own drill.
- Configuration lives in ClickHouse `default.map_*` insert-only change-log tables edited by the BI manager with SQL,
  never CSV or workbooks (decision 2026-10-20).
- Measures are SSAS measures over facts, wrapped by `ssas/tools/measure_guards.py`; a measure allowed to be filtered
  by a table calls `_Unguarded` twins.
- Title-casing rule (CLAUDE.md) for mart text from source systems; labels this repo defines are not title-cased.
- Fonts: Power BI on this server has no Zain web font; the BSC theme's font is used.

## Approaches considered (income statement structure)

| | Rows | Budget | History | Cost |
|---|---|---|---|---|
| A. GL structure as it is (`GL FS Monthly`: element > category > caption > account) | Oasis and Fusion captions differ (revenue by care type vs by payer; Oasis depreciation under direct cost) | only on the few rows that equal a budget subtotal | yes | none |
| B1. Own mapping of every caption to a budget line | budget-line layout | every line | yes | ~60 mapping rows, dbt change |
| **B2. P&L Report (chosen)** | the Fusion profitability report's lines, Oasis and Fusion already matched by `pl_report_line_rule` | every line that has a budget line; revenue at total | yes (2022+) | a ~15-code link to budget lines |

The user first chose B over A (budget on every line, EBITDA comparable across the cutover), then asked for the newly
added P&L Report, which already does B's mapping: B2. The balance sheet and the trial balance use the GL structure
(their captions are the same in both systems).

## Data and model changes

### Sources per page

| Page | Rows | Actual | Last year | Budget |
|---|---|---|---|---|
| Trial balance | `GL FS Monthly`: Type > Element > Category > Caption > Account | opening, debit, credit, closing, monthly net movement | same date last year | placeholder table (BS and IS captions) |
| Income statement | `P&L Line`: Section > Line > Caption > Account (detail lines; subtotal lines as rows of their own) | `P&L Report`[Amount] (credit positive) | same period last year | `Income Statement`[Budget Most Likely] through the P&L-to-budget link; placeholder table for the rest |
| Balance sheet | `GL FS Monthly` regrouped: Side (Assets / Liabilities & equity) > Element > Category > Caption > Account, IS accounts as Equity > Current year profit | month-end closing | same date last year | placeholder table |
| KPIs & ratios | a KPI list (group > KPI) | measures over P&L Report and GL FS Monthly | same | from budget amounts where both inputs have a budget; targets from `map_finance_target` (placeholder until filled) |

### dbt (hnh_dwh)

1. `fact_gl_fs_monthly` gains `debit` and `credit` (the movement split, opening journals excluded, so
   `debit - credit = movement`). Oasis: `gold.fact_oasis_gl_line` has `debit` and `credit` per line (checked
   2026-11-18), summed over posted, non-brought-forward lines; `stg_bsc__oasis_gl_line` exposes them. Fusion: not
   from `fact_gl_balance_monthly` (its `period_debit`/`period_credit` include opening journals and it has no split
   excluding them); read from `hnh_fact_gl_journal_line` (including unposted, `is_opening_balance_journal = 0`), so
   `fact_gl_balance_monthly`, `GL Balances` and the TB measures are untouched. A test checks the identity.
2. `fact_gl_fs_monthly` (or its ssas view) gains `account_name`: Oasis from `gold.dim_oasis_gl_account.account_name`
   (exposed through `stg_bsc__oasis_gl_account`), Fusion natural account name, title-cased with `hnh_title`; plus
   title-cased display columns for type, element, category and caption (`fs_caption` stays lower case for the
   measures' comparisons). Same for `account_name` on `fact_pl_report_monthly`.
3. Balance sheet grouping columns on the ssas view of `fact_gl_fs_monthly`: `bs_side`, `bs_element`, `bs_category`,
   `bs_caption` (repo labels, not title-cased; add to the title-case test's `excluded` list). IS accounts are not
   shown by their GL closing balance: **Current year profit** (Liabilities & equity > Equity) is the year-to-date net
   profit from the P&L Report (Oasis and Fusion months), so it ties to the income statement page even in a cutover
   year, where Fusion's IS closing covers only the months since go-live. Whatever then stops the sides agreeing
   (assets - liabilities - equity - current year profit) shows as a grey **Difference** row under the total, only
   when it is not zero (my call: finance sees the cutover gap instead of a hidden plug).
4. `dim_pl_report_line` gains `budget_line_code` (repo mapping in its values list): equal codes link directly
   (`DC_EMPLOYEE`, `DC_MEDICINES`, `GA_ECL`, `GROSS_PROFIT`, `EBITDA`, `NET_PROFIT` ...), renamed ones by hand
   (`NET_REVENUE`->`REV_NET`, `DIRECT_COST`->`TOTAL_DC`, `DIS_EARLY_PAYMENT`->`DIS_EARLY_PAY`,
   `DIS_REJECTION`->`DIS_REJECTION` (budget subtotal of INS + MOH), `SM`->`GA_MARKETING`, `HO_CHARGES`->`GA_HO_CHARGES`,
   `GA_TOTAL`->`TOTAL_GA` ...), empty for lines without one. A test checks every non-subtotal budget line is linked
   once or listed as unlinked on purpose.
   **Revenue**: the budget's revenue lines are net of contractual discounts (O-P3-7) and it has no contractual-discount
   line, while the P&L's Revenue Total is before them. So `REV_TOTAL`, `REV_CASH`, `REV_CREDIT` and the contractual
   discount section carry no budget and read **"Not budgeted"** (a structural gap, unlike "No budget yet", which the
   user can fill); the revenue comparison is on Net Revenue (and the settlement-discount lines). The claim rejection
   rate KPI has no budget value.
   **Medicines and consumables**: compared line by line with their own budget lines (my call); Oasis books cost of
   goods sold under Consumables, so the split between the two lines differs before and after cutover, which the
   income statement subtitle notes. The model's `IS Budget (Comparable)` pairing is not used here.
   **Known mismatch**: the budget's Total G&A includes marketing and head office charges, the P&L's G&A total does not;
   the link compares the P&L's G&A total with `TOTAL_GA - GA_MARKETING - GA_HO_CHARGES` (stated in the page's
   subtitle).
5. New `default.map_finance_budget` (branch_id, year, month, statement `IS`/`BS`, line_code (a P&L line code or a
   lower-case FS caption), amount, changed_at, changed_by, change_note, is_deleted) and
   `default.map_finance_target` (kpi_code, branch_id (0 = all), year, target_value, watch_pct, changed_at, changed_by,
   change_note, is_deleted), DDL in `scripts/finance_config/`, read through `stg_ref__*` latest-row views into
   `fact_finance_budget_monthly` and `dim_finance_target`. Empty at first. A budget-table row for an IS line replaces
   the budget-line amount for that branch-month-line (so the user can also fill Ghirnata and Muhayil). The user enters
   **detail lines only**: `fact_finance_budget_monthly` rolls the lines up into the P&L subtotals (by
   `dim_pl_report_line.subtotal_sections`) and into the balance sheet's category, element and side totals, so an
   override on one line moves EBITDA and Net profit with it (my call).
6. `dim_date` gains `year_pick` ("Current year" for the year of the last closed month, else the year), sorted by
   year, so the Year slicer opens on the current year without a rebuild (as `month_pick`).
7. A KPI list `dim_finance_kpi` (repo values list): code, group, name, unit (`%`, `x`, `d`), direction, display
   order.

### SSAS (ssas/HNH_Analytics)

- New/changed tables: `GL FS Monthly` columns above, `P&L Line`[Budget Line Code], `Finance Budget` (fact),
  `Finance Target`, `Finance KPI`, and a disconnected `Finance Column` table per page kind (see Matrices).
- New perspective `Finance Report` (the report's fields only).
- Measures, folder `Finance\Report`, prefix `FR`: actual, last year, budget (with the placeholder text twins
  `FR Budget Text` = "No budget yet"), variance, variance %, growth %, achievement %, opening, debit, credit,
  closing, month-end balance (last month with data per branch, as `TB Closing Balance` does), % of revenue,
  % of assets, the KPI value by `SWITCH` over `Finance KPI`, target, status (On target / Watch / Off target / No
  target yet), attainment, card text lines, and colour measures for conditional formatting. Actuals stop at today
  (`'Date'[Date] <= TODAY()`, as the BSC: Fusion holds accruals for future periods).
- Signs: income statement in the P&L Report's sign (revenue and profit positive, costs negative), favourable /
  unfavourable by line nature; balance sheet assets debit-positive, liabilities and equity credit-positive; trial
  balance debit-positive with credits in brackets.
- Amounts shown in SAR thousands (visual display units), as the canvas header says.
- KPI definitions as on the canvas, on real lines: e.g. EBITDA margin = EBITDA / Net revenue; receivable days =
  trade receivables, net / net revenue x days; inventory days = inventories, net / (consumables + medicines) x days;
  current ratio = current assets / current liabilities; staff cost ratio = (DC_EMPLOYEE + GA_EMPLOYEE) / net revenue;
  claim rejection rate = -DIS_REJECTION / Revenue total. **Equity-based ratios** (ROE, debt to equity, equity ratio)
  use net assets (total assets - total liabilities, which includes the head-office account), because a hospital
  branch holds little equity of its own; **debt** is lease liability (no borrowing captions exist in the GL).
  Ratios over a period are annualised as on the canvas.

### Budget for "All" hospitals (user decision 2026-11-18)

Like-for-like: with more than one hospital in the filter, every budget figure (budget, variance, variance %,
achievement %, the vs-budget tile lines, KPI budget values) compares only the hospital-months that have a budget for
that line: their actual against their budget. The label reads "vs budget (budgeted hospitals)" when a hospital in the
filter has none. Ghirnata and Muhayil join once their budget is filled in `map_finance_budget`. Last year and growth
use every hospital.

### One set of finance definitions (user decision 2026-11-18)

The finance report uses its own definitions (built on the income statement and balance sheet it shows), and **the
whole model is unified on them**: the existing financial measures are rewritten to call the same building blocks, so
the scorecard, the HR dashboard and this report show the same figure for the same hospital and month.

- Shared building blocks (hidden, folder `Finance\Building Blocks`): net revenue, revenue total, direct cost, G&A,
  marketing, head office charges, other income, EBITDA (P&L Report, so other income is in), D&A, finance cost, zakat,
  net profit, consumables, medicines, employee cost, rejections, ECL from `P&L Report`; trade receivables, inventories,
  cash, trade payables, current assets and liabilities, total assets and liabilities (month-end) from `GL FS Monthly`;
  their budgets through the P&L-to-budget link, like-for-like.
- Rewritten on them: the 12 `BSC GL *` and 7 `BSC Budget *` building blocks, so `BSC Net Revenue`, `BSC EBITDA
  Margin`, `BSC Cost to Revenue`, `BSC Consumables Ratio`, `BSC Days in AR (days)`, `BSC Days Inventory (days)`,
  `BSC G&A Ratio`, `BSC Return on Assets`, `BSC Revenue/EBITDA per Bed/Doctor/FTE`, `BSC Cost Budget Variance`,
  `BSC Claim Final Rejection` (GL part) and their `BSC Target *` (budget-source targets) follow; and the Fusion-only
  `EBITDA`, `Gross Profit`, `Net Profit`, `EBITDA Margin %` measures move from `Income Statement` to the P&L Report
  (Oasis + Fusion). `IS Actual` / `IS Budget` stay as they are (budget-line grain, used by the budget reconciliation).
- Definition changes this brings to the scorecard: EBITDA includes other income; receivable and inventory days use the
  month-end balance, not the average of opening and closing; G&A is the P&L's G&A section (without marketing and head
  office charges) and its budget `TOTAL_GA - GA_MARKETING - GA_HO_CHARGES`. Scorecard scores move on the deploy; the
  plan lists, per scorecard KPI and hospital, the last closed month's value before and after (read-only DAX on the
  test slot) for the user to see before production.
- The scorecard keeps its own status rule (thresholds in `map_bsc_threshold`) and its own targets table; only the
  calculations are shared. The finance KPIs page uses `map_finance_target` and its own On target / Watch / Off target
  rule.

## The report

Folder `powerbi_tmdl/hnh_finance_report/` on the BSC generator's modules, as `hnh_hr_report/`: `build.py`,
`fin_frame.py`, `pages_*.py`, `tests/`, report name **HNH Finance**, perspective `Finance Report`, database
`HNH_Analytics_Test` until the production deploy. Cross-filter on (a click filters, not highlights).

### Frame (every page)

The BSC frame (`frame.frame` with a Finance `FrameSpec`): navy header with the white logo, title "Finance Report"
over "Hayat Healthcare", and four tabs Trial Balance, Income Statement, Balance Sheet, KPIs & Ratios (each tab goes to
that statement's Monthly page). The filter bar under it holds, left to right:

- **View** switch: two buttons, Monthly and Hospital comparison, page navigation to the twin page (current one
  filled navy, as the canvas).
- **Hospital** tile slicer (Monthly pages only): the eight hospitals with Select all = "All", synced across pages.
  Hospital comparison pages show the text "All eight, side by side with the total" instead.
- **Year** single-select tile slicer on `'Date'[Year Pick]`, 2022 to the current year, opens on "Current year".
- **Month** tile slicer Jan to Dec (`'Date'[Month Short]`), multi-select, no saved selection (= the whole year so
  far). The canvas's Month / Last 3M / YTD presets need bookmarks and are dropped: a reader picks months.
- Period and "SAR '000" as text on the right of the header (a text measure for the period).

### Content (as the canvas, 1920 x 1080, below the frame)

Each page: a row of four tiles (KPIs page: six scorecard cards), two charts, and a matrix filling the rest.

| Page | Tiles | Left chart | Right chart | Matrix |
|---|---|---|---|---|
| Trial balance | Period debits, Period credits, Out of balance (debits - credits; teal "In balance" or red "Review"), Total assets (vs budget, vs last year) | selected account by month: actual / budget / last year (clustered columns) | variance % by month vs budget and vs last year | rows: type > element > category > caption > account; columns: Period (Opening, Opening journals, Debit, Credit, Closing, Cutover difference), Net movement by month, Closing vs last year and budget (Last year, Growth, Budget, vs Bud); total row "Total · all accounts". Opening journals (Oasis January brought-forward, Fusion go-live loads) and Cutover difference (Closing - Opening - journals - Debit + Credit, non-zero only over a range that crosses a branch's cutover) are hidden when empty (my call) |
| Income statement | Net revenue, EBITDA, EBITDA margin, Net profit, each with vs budget and vs last year lines coloured favourable / unfavourable | selected line by month: actual / budget / last year | variance % by month | rows: P&L lines in report order (subtotals bold on a tinted band, detail lines drill to caption and account); columns: Actual by month, Period total (Actual, Budget, Variance, Var %, Last year, Growth, % Rev) |
| Balance sheet | Total assets, Net working capital, Current ratio, Receivable days | selected line at month end: actual / budget / last year | variance % by month | rows: side > element > category > caption > account, with Current year profit and Total liabilities & equity; columns: month-end balance by month, End of month vs last year and budget (Last year, Growth, Budget, vs Bud, % Assets) |
| KPIs & ratios | six cards F1 to F6 (net revenue growth, EBITDA margin, net profit vs budget, receivable days, claim rejection rate, cost of revenue ratio): code, name, target, value, status chip, budget and last-year lines, a 12-month sparkline (a small line chart) | none | none | rows: KPI group > KPI; columns: Target, Actual, Attainment (data bar, 0-125 %), Status chip, Budget, vs Bud, Last year, vs LY, Actual by month; header chips: counts on target / watch / off target |

Hospital comparison pages: same tiles over all eight hospitals; charts become ranked bars by hospital
(achievement % with a 100 % line, and growth %), favourable teal and unfavourable red on the income statement;
the matrix columns become hospital groups (Ach %, Growth) with the All-hospitals group (Closing / Actual, Ach %,
Growth); the KPI matrix becomes a heat map (Actual shaded by status, vs Bud, vs LY per hospital).

The selected matrix row drives the charts (cross-filter); with no selection they show the canvas's default line
(Trade receivables on the trial balance and balance sheet, Net revenue on the income statement). "Expand to level"
is the matrix's own expand / collapse.

Placeholders: a budget, variance or achievement cell without a budget shows "No budget yet" in grey (`#9AA7B5`, the
HR report's grey); a KPI without a target shows "No target yet" and counts in none of the three chips.

Colours (the canvas's, close to the brand): ground `#F2F5F9`, ink `#0A1E32`, period band `#0A2D6E`, month band
`#32A5E6`, selected row `#CDE8FA`, total band `#EFF4F9`, favourable `#04705F`, unfavourable `#C2230A`, status chips
On target `#D9F3EE`/`#04564A`, Watch `#FFDF8A`/`#5C3F00`, Off target `#F5A99B`/`#6E1505`.

### Matrices

A Power BI matrix cannot mix month columns with differently-measured columns. Each statement page uses a
disconnected `Finance Column` table (column group, column name, order, kind) on the matrix's columns and one value
measure that returns the right figure per column (`SWITCH` on the kind, month columns filtered to the months
picked, empty columns hidden). The value is a formatted text so a cell can hold "No budget yet"; alignment right,
conditional font colour from the colour measures. The two header bands of the canvas are the two levels of the
column table. If the text values prove slow on the full account level, the fallback is two matrices (period block and
months) stacked, and the builder says so.

## Security

`HNH Readers` row filters on Branch apply unchanged; a one-hospital reader sees that hospital only (All = their
hospital). The new config tables carry no person data. Test as a non-admin member of `HNH_BI_Users`.

## Deployment (each step on the user's go-ahead)

1. ClickHouse DDL for the two `map_finance_*` tables (empty).
2. dbt build of the changed models and their children (`fact_gl_fs_monthly+`, `fact_pl_report_monthly+`,
   `dim_pl_report_line+`, `dim_date+`, new models), contracts regenerated.
3. Deploy the model to `HNH_Analytics_Test` and process the changed tables; show the user the scorecard's before /
   after values (the unified definitions) before anything goes to production.
4. Build the report, convert to `.pbix`, `check_upload_rules` returns `[]`, open in Desktop for Report Server.
5. Upload to `http://hnhanalyticssrv/reports` (a new Finance folder) and test as a one-hospital user.
6. Production model deploy and the `--database HNH_Analytics` rebuild are separate go-aheads.

## Checks

- dbt unit tests: debit/credit identity, account names, BS regrouping, P&L-to-budget link coverage, budget roll-up,
  config tables' latest-row logic. The existing `hnh_dwh/tests/hnh/assert_pl_report_ties_to_gl.sql` (Total
  Comprehensive Income to the GL) keeps the P&L side honest; no new tie on Net Profit (it differs by OCI).
- DAX smoke test on the test slot: every `FR` measure on each page's grouping returns no guard message; TB total per
  branch-month (debits - credits) printed; income statement totals match `P&L Amount`.
- Generator tests (pytest), `pbir_check` (schemas, Desktop project reader), `check_upload_rules`.
- Screenshots of the eight pages against the canvas.

## Left to the builder

Exact geometry within the frame; chart formatting (from the HR report's `column_look` / `bar_look`); measure
names beyond the `FR` prefix; how the guards are annotated; the KPI list's display order.
