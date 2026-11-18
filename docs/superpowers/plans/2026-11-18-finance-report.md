# Finance Report (HNH Finance) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An eight-page Power BI report "HNH Finance" (trial balance, income statement, balance sheet, KPIs; each
Monthly and Hospital comparison) on `HNH_Analytics_Test`, on merged Oasis + Fusion history, with budget kept,
placeholders for missing budgets and targets, and the model's financial measures unified on one set of definitions.

**Architecture:** dbt adds debit/credit and account names to the merged GL (`fact_gl_fs_monthly`), a P&L-line-to-budget
link, a finance budget fact (budget lines + the user's `default.map_finance_budget` overrides), a KPI list, a target
table and a matrix-column table. SSAS gets shared `Fin *` building blocks, `FR *` report measures and text "cell"
measures for one-matrix statements; the scorecard's GL and budget building blocks are rewritten on `Fin *`. A new
generator `powerbi_tmdl/hnh_finance_report/` on the BSC modules writes the PBIP; `pbir_to_pbix.py` writes the upload.

**Tech Stack:** dbt on ClickHouse (receiving project, built by the user on 172.22.25.214), SSAS Tabular TMDL
(`ssas/tools`), DAX, Python 3.12 + pytest, Pester (Windows PowerShell 5.1), Tabular Editor 2 BPA, PBIR generator.

**Spec:** `docs/superpowers/specs/2026-11-18-finance-report-design.md`
**Look:** the Design canvas, local copy
`C:\Users\ADMINI~1\AppData\Local\Temp\3\claude\d313ea72d3990d8c\fa51d41a-1230-45a1-8c44-897bfdcebbcc\scratchpad\artifact-files\b040a4c2-d19e-43b9-b198-fa53d17d23f7\project\*.dc.html`
(re-read with the Artifact tool if the scratchpad was cleared).

## Global Constraints

- **Production server (CLAUDE.md). GATE** = the user's go-ahead at the time, every time: ClickHouse writes
  (`apply_finance_config.ps1` without `-DryRun`), any dbt build in the receiving project, `deploy.ps1`, `process.ps1`,
  the upload. Read-only needs none: `SELECT` through DSN `HNH_Gold`, `scripts/render_model_sql.py`, DAX
  (`Invoke-HnhDax`), pytest, Pester, BPA.
- **dbt is not installed here.** Check each model offline: rendered by `scripts/render_model_sql.py`, refs/sources
  replaced by inline rows, run read-only through `HNH_Gold`, in Pester files shaped like
  `scripts/bsc_config/BscModels.Tests.ps1`. No `{% set %}`; `var('…')` with single quotes. dbt unit/yml tests run at
  GATE G2.
- **Config tables are change logs:** insert only, newest row per key wins, every row ends with
  `changed_at DateTime64(3), changed_by String, change_note String, is_deleted UInt8`,
  `ENGINE = MergeTree ORDER BY (<key>, changed_at)`, applied through `Invoke-HnhConfigApply` (`scripts/HnhCh.psm1`)
  as `scripts/hr_config/apply_hr_config.ps1`. Edited by the BI manager with SQL (`docs/finance_config.md`).
- **Title case (CLAUDE.md):** `account_name` and the display FS columns are wrapped in `hnh_title`; repo labels
  (`bs_*` grouping, KPI names, Finance Column labels, "Not budgeted", "No budget yet", "No target yet",
  "Current year profit", "Difference") are not; add such `*_name` columns to the `excluded` list of
  `hnh_dwh/tests/hnh/assert_mart_text_title_case.sql`.
- **Signs:** income statement in the P&L Report's sign (revenue and profit positive, costs negative). Balance sheet
  display sign: assets debit-positive, liabilities and equity credit-positive. Trial balance debit-positive, credits in
  brackets. Text cells show SAR thousands: `FORMAT ( x / 1000, "#,0;(#,0);–" )`.
- **Actuals stop at today:** every `Fin`/`FR` actual uses `KEEPFILTERS ( 'Date'[Date] <= TODAY () )`.
- **Hospitals only on the report:** page filter `Branch[Branch Key] in 1..8`, locked (as `hr_frame.lock_branch_filters`).
- **Placeholder words, exact:** `No budget yet` (fillable gap), `Not budgeted` (P&L line with no budget line),
  `No target yet`; grey `#9AA7B5`.
- **Status rule (finance KPIs):** attainment `x = actual / target` (higher better) or `target / actual` (lower better;
  actual <= 0 → 1.25), clamped to 0..1.25; `x >= 1` On target, `x >= 1 - watch_pct` Watch (default `watch_pct` 0.05),
  else Off target; no target → `No target yet`, counted in no chip.
- **Colours (canvas):** ink `#0A1E32`, period band `#0A2D6E`, month band `#32A5E6`, light band `#BFE0F6`, total band
  `#EFF4F9`, net band `#DFE8F1`, selected `#CDE8FA`, favourable `#04705F`, unfavourable `#C2230A`, muted `#4D5B6B`,
  chips On `#D9F3EE`/`#04564A`, Watch `#FFDF8A`/`#5C3F00`, Off `#F5A99B`/`#6E1505`, bars `#05A591`/`#EF8D00`/`#DC280A`,
  chart series Actual `#0A2D6E`, Budget `#32A5E6`, Last year `#A0BEFF`.
- **Measures:** in `ssas/HNH_Analytics/tables/_Measures.tmdl`; edit only between `VAR __Value = ( -- measure body` and
  `) -- end of measure body`; each has `///`, `formatString`, `displayFolder` (`Finance\Building Blocks` hidden for
  `Fin *`, `Finance\Report` for `FR *`) and a check in `ssas/tests/measures/finance.json`. After edits:
  `python ssas/tools/measure_guards.py`, `python ssas/tools/sync_perspectives.py`, `python -m pytest ssas/tools`,
  BPA `"C:\Program Files (x86)\Tabular Editor\TabularEditor.exe" ssas\HNH_Analytics -A ssas\bpa_rules.json -V` (no
  `type=error`).
- **Git:** worktree `D:\new_dwh_modeling-fin` on branch `finance-report` from `main` (266ca5f). Commit at the end of
  each task, message ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push.

## Review Focus

1. **A range crossing a branch's cutover** (Khamis, branch 2, first Fusion month 2026-09; range Aug–Sep 2026): the
   trial balance must show the gap in `Cutover difference`, never a silent mismatch. *Task 9 check.*
2. **"All" with an unbudgeted hospital** (Ghirnata, 7): budget figures compare only budgeted hospital-months;
   `FR Actual (Budgeted)` for all eight equals the six budgeted hospitals' actual. *Task 9 check.*
3. **Future months** (Fusion posts accruals ahead): `FR Actual` for December 2026 is blank while today is in
   November. *Task 8 check on `Fin Net Revenue`, 202612.*
4. **A ratio with a zero or negative denominator** (interest cover with no finance cost; net debt / EBITDA with
   negative EBITDA): blank in the value, `–` in the cell, no error, no infinity, no status. *Task 11 check.*
5. **A one-hospital reader** (row security): "All" is their hospital, the Hospital comparison pages show only their
   column. *Task 18: entry in `ssas/tests/security.json` for `FR Net Revenue` by branch as a one-branch login.*

---

## Part A: config and dbt

### Task 1: Finance config tables and their staging

**Files:**
- Create: `scripts/finance_config/finance_config_ddl.sql`, `scripts/finance_config/finance_config_seed.sql` (comment
  only: no rows), `scripts/finance_config/apply_finance_config.ps1`, `scripts/finance_config/FinanceModels.Tests.ps1`,
  `docs/finance_config.md`
- Create: `hnh_dwh/models/hnh/staging/reference/stg_ref__finance_budget.sql`, `stg_ref__finance_target.sql`
- Modify: `hnh_dwh/models/hnh/staging/reference/_reference__sources.yml` (add `map_finance_budget`,
  `map_finance_target` under the HR block's comment style), `_reference__models.yml`

**Interfaces:**
- Produces: `default.map_finance_budget(branch_id UInt8, year UInt16, month UInt8, statement String, line_code String,
  amount Float64, …change-log columns)` ORDER BY `(branch_id, year, month, statement, line_code, changed_at)`;
  `default.map_finance_target(kpi_code String, branch_id UInt8, year UInt16, target_value Float64, watch_pct Float64,
  …)` ORDER BY `(kpi_code, branch_id, year, changed_at)`.
- Produces: `stg_ref__finance_budget(branch_id, year, month, statement, line_code, amount, last_changed_at)` — latest
  non-deleted row per key; `statement` upper-cased, `line_code` trimmed (IS: a `pl_line_code`; BS: a lower-case FS
  caption); `amount` as entered (positive for revenue and costs alike).
  `stg_ref__finance_target(kpi_code, branch_id, year, target_value, watch_pct, last_changed_at)`; `branch_id` 0 = all
  hospitals; `watch_pct` 0 → 0.05.

- [ ] **Step 1: Write the failing Pester tests** in `FinanceModels.Tests.ps1` (copy `Get-RenderedModel` /
  `Invoke-ModelWithSources` from `BscModels.Tests.ps1`):
  `Describe 'stg_ref__finance_budget'` → `It 'keeps the latest row per key and drops a deleted key'` (3 versions of
  (1, 2026, 1, 'IS', 'DC_EMPLOYEE'), newest deleted; another key with 2 versions → 1 row, amount of the newest);
  `It 'upper-cases statement and trims line_code'` (`' is '`, `' DC_EMPLOYEE '` → `IS`, `DC_EMPLOYEE`).
  `Describe 'stg_ref__finance_target'` → `It 'defaults watch_pct 0 to 0.05'`.
- [ ] **Step 2:** `powershell -NoProfile -Command "Invoke-Pester -Script scripts\finance_config\FinanceModels.Tests.ps1"` → FAIL (model not found).
- [ ] **Step 3:** Write the DDL, the two staging models (argMax over `changed_at`, as `stg_ref__hr_target.sql`), the
  sources/models yml (unique key tests), `apply_finance_config.ps1` (copy of `apply_hr_config.ps1` pointing at the
  finance files), and `docs/finance_config.md`: what each table is, keys, `amount` sign convention (positive numbers;
  the model applies the line's sign), which IS `line_code`s exist (`dim_pl_report_line` detail lines), BS `line_code` =
  lower-case FS caption as in `GL FS Monthly`, how to delete, and an example INSERT for each table; that changes show
  after the nightly build and `process.ps1 -Mode Daily`.
- [ ] **Step 4:** Pester again → PASS. `powershell -File scripts\finance_config\apply_finance_config.ps1 -DryRun` → prints the DDL, writes nothing.
- [ ] **Step 5:** Commit.

### Task 2: Debit, credit and account names on the merged GL

**Files:**
- Modify: `hnh_dwh/models/hnh/staging/oasis_gl/stg_bsc__oasis_gl_line.sql` (add `debit`, `credit`),
  `stg_bsc__oasis_gl_account.sql` (add `account_name`), their yml
- Modify: `hnh_dwh/models/hnh/marts/finance/fact_gl_fs_monthly.sql`, `_finance_marts__models.yml`
- Create: `hnh_dwh/tests/hnh/assert_gl_fs_debit_credit_ties.sql`
- Test: `scripts/finance_config/FinanceModels.Tests.ps1`

**Interfaces:**
- Produces on `fact_gl_fs_monthly`: `debit Float64`, `credit Float64` (both >= 0, opening journals excluded,
  `debit - credit = movement` per row within 0.01), `account_name String` (title-cased; `''` → the account code).
  Grain and every existing column unchanged.

- [ ] **Step 1: Failing tests** `Describe 'fact_gl_fs_monthly debit and credit'`:
  `It 'splits Oasis movement into debit and credit without brought-forward lines'` (inline Oasis lines: (dr 100, cr 0),
  (dr 0, cr 30), brought-forward (dr 500) → debit 100, credit 30, movement 70);
  `It 'takes Fusion debit and credit from journal lines without opening-balance journals'` (journal lines amount 80,
  -20, and an opening journal 1000 → debit 80, credit 20);
  `It 'title-cases account_name and falls back to the code'`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Oasis: sum `debit`/`credit` of posted, non-brought-forward lines into `oasis_month`, carried
  through `oasis_rolled` (0 on grid months without lines) and the `oasis` CTE. Fusion: a new CTE from
  `hnh_fact_gl_journal_line` (`is_opening_balance_journal = 0`, posted or not, as the Fusion side's
  `including_unposted`), `sumIf(amount, amount > 0)` / `-sumIf(amount, amount < 0)` per branch, month (period end
  month, adjustment periods into their quarter's last month as now), natural account; left-joined to the `fusion`
  CTE. Account name: Oasis `stg_bsc__oasis_gl_account.account_name`, Fusion `natural_account_name` of
  `hnh_dim_gl_account`; `{{ hnh_title('…') }}` at the output. The yml test `assert_gl_fs_debit_credit_ties.sql`
  returns rows where `abs(debit - credit - movement) > 0.01`.
- [ ] **Step 4:** Pester → PASS. Read-only sanity through `HNH_Gold` on the rendered model limited to branch 3,
  2025-06: `sum(debit) - sum(credit)` equals `sum(movement)` of the current gold table within 1 SAR.
- [ ] **Step 5:** Commit.

### Task 3: Account names on the P&L Report

**Files:**
- Modify: `hnh_dwh/models/hnh/marts/finance/fact_pl_report_monthly.sql`, the macro `hnh_pl_report_fusion_details`
  (in `hnh_dwh/macros/hnh/`), `_finance_marts__models.yml`
- Test: `FinanceModels.Tests.ps1`

**Interfaces:**
- Consumes: `fact_gl_fs_monthly.account_name` (Task 2).
- Produces: `fact_pl_report_monthly.account_name String` (title-cased); amounts and grain unchanged.

- [ ] **Step 1:** Failing test `It 'carries account_name for Oasis and Fusion rows'`.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Oasis rows take it from `fact_gl_fs_monthly`; the Fusion macro adds
  `natural_account_name`. **Step 4:** Run → PASS; `hnh_dwh/tests/hnh/assert_pl_report_ties_to_gl.sql` still renders.
- [ ] **Step 5:** Commit.

### Task 4: P&L line to budget line link

**Files:**
- Modify: `hnh_dwh/models/hnh/marts/finance/dim_pl_report_line.sql` (two new fields in the `values(...)` list),
  `_finance_marts__models.yml`
- Create: `hnh_dwh/tests/hnh/assert_pl_line_budget_link.sql`
- Test: `FinanceModels.Tests.ps1`

**Interfaces:**
- Produces on `dim_pl_report_line`: `budget_line_code String` (`''` = no budget line) and `budget_sign Int8`
  (multiplies a `budget_most_likely` amount into the P&L sign; 0 when unlinked).
- Link (exact): equal codes for every code present in both `dim_budget_line` and the P&L list (`DC_*`, `GA_GOVT_FEE`,
  `GA_AUDIT`, `GA_COMMUNICATION`, `GA_ECL`, `GA_OTHER`, `GA_POSTAGE`, `GA_PROFESSIONAL`, `GA_SECURITY`, `GA_TRAINING`,
  `GA_EMPLOYEE`, `DIS_VOLUME`, `DIS_REJECTION`, `DIS_SETTLEMENT`, `GROSS_PROFIT`, `OTHER_INCOME`, `EBITDA`,
  `DEPRECIATION`, `FINANCE_COST`, `ZAKAT`, `OCI`); renamed: `NET_REVENUE`→`REV_NET`, `DIRECT_COST`→`TOTAL_DC`,
  `DIS_EARLY_PAYMENT`→`DIS_EARLY_PAY`, `SM`→`GA_MARKETING`, `HO_CHARGES`→`GA_HO_CHARGES`, `GA_TOTAL`→`TOTAL_GA`
  (special: its budget is `TOTAL_GA - GA_MARKETING - GA_HO_CHARGES`, resolved in Task 5), `NET_PROFIT`→`NET_PROFIT`,
  `TOTAL_COMPREHENSIVE_INCOME`→`TOTAL_COMP_INCOME`. Unlinked (`''`): `REV_*`, `DIS_CASH`, `DIS_CREDIT`,
  `DIS_PACKAGE`, `DIS_CONTRACTUAL`, `DIS_UNCLAIMED`, `DIS_PATIENT_REFERRAL`, every `*_NM`/`NOT_MAPPED`,
  `GA_BOARD`, `GA_MGMT_REWARD`, `GA_MAINTENANCE`, `GA_UTILITIES`, `GA_TRAVEL`, `GA_INSURANCE`, `GA_KITCHEN`.
- `budget_sign`: decided from data, not guessed (Step 3).

- [ ] **Step 1:** Failing tests: `It 'links every non-subtotal budget line once or lists it as unlinked'` (the data
  test: every `dim_budget_line` row with `is_subtotal = 0` except `REV_OP`, `REV_IP`, `REV_ER`, `REV_UNALLOCATED`,
  `DIS_REJECTION_INS`, `DIS_REJECTION_MOH`, `UNBUDGETED` appears exactly once in `budget_line_code`);
  `It 'gives budget and actual the same sign'`: read-only over gold, for branch 3, 2026 Jan–Sep, for each linked
  line, `sign(sum(budget_most_likely) * budget_sign) = sign(sum(P&L amount))` for `NET_REVENUE`, `DIRECT_COST`,
  `GROSS_PROFIT`, `EBITDA`, `DC_EMPLOYEE`, `NET_PROFIT`.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Query (read-only) `select budget_line_code, sum(budget_most_likely), sum(actual_posted) from
  gold.fact_income_statement_monthly where branch_key = 3 and month_start between '2026-01-01' and '2026-09-01' group
  by 1` and the P&L amounts for the same lines; set `budget_sign` per line so the signs agree (expected: +1 for
  revenue, profit and other-income lines, -1 for cost lines); add both fields to the values list.
- [ ] **Step 4:** Run → PASS. **Step 5:** Commit.

### Task 5: Finance budget fact

**Files:**
- Create: `hnh_dwh/models/hnh/marts/finance/fact_finance_budget_monthly.sql`, entry in `_finance_marts__models.yml`
- Test: `FinanceModels.Tests.ps1`

**Interfaces:**
- Consumes: `fact_income_statement_monthly` (budget_most_likely), `dim_pl_report_line` (Task 4),
  `stg_ref__finance_budget` (Task 1).
- Produces: `fact_finance_budget_monthly(branch_key UInt8, month_start Date, month_date_key Int64, statement String
  ('IS'|'BS'), pl_line_key UInt16 (0 for BS), pl_line_code String, bs_caption String ('' for IS), amount Float64,
  source String ('budget'|'override'|'rollup'))`; IS amounts in the P&L sign, BS amounts in the display sign.
- Rules (exact):
  1. Linked line amount = `budget_most_likely` of its budget line × `budget_sign`; `GA_TOTAL` = `(TOTAL_GA -
     GA_MARKETING - GA_HO_CHARGES) × budget_sign`. Branch-months whose budget total is 0 give no rows.
  2. Override: a `stg_ref__finance_budget` IS row replaces the line's amount for that branch-month, its amount ×
     the line's natural sign (+1 revenue/other income lines, -1 cost lines: the `budget_sign` rule, or for unlinked
     lines the sign of the line's section, from the same Task 4 query). Overrides on unlinked lines are allowed.
  3. Subtotals (`line_kind = 'subtotal'`): linked subtotal amount + Σ(override − original) over detail lines in its
     `subtotal_sections`; a subtotal with no linked amount = Σ of its sections' detail lines (budget or override).
  4. BS: one row per `stg_ref__finance_budget` BS row, `bs_caption = line_code`, amount as entered.

- [ ] **Step 1:** Failing tests: `It 'signs linked lines by budget_sign'`; `It 'replaces a line by its override and
  moves EBITDA and NET_PROFIT by the difference'` (budget DC_EMPLOYEE 100 → override 120: DIRECT_COST, GROSS_PROFIT,
  EBITDA, NET_PROFIT each 20 lower); `It 'builds subtotals from overrides for a hospital without budget'` (branch 7,
  overrides REV_CASH 50, DC_EMPLOYEE 30 → NET_REVENUE 50, EBITDA 20); `It 'keeps BS overrides as entered'`;
  `It 'gives GA_TOTAL the budget less marketing and head office charges'`.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement (CTEs: linked, overrides, details, subtotal deltas; no
  `{% set %}`). **Step 4:** Run → PASS. **Step 5:** Commit.

### Task 6: KPI list, columns, targets, year pick and the SSAS views

**Files:**
- Create: `hnh_dwh/models/hnh/marts/finance/dim_finance_kpi.sql`, `dim_finance_column.sql`, `dim_finance_target.sql`
- Modify: `hnh_dwh/models/hnh/marts/conformed/dim_date.sql` (`year_pick`)
- Create: `hnh_dwh/models/hnh/marts/ssas/ssas_fact_finance_budget_monthly.sql`, `ssas_dim_finance_kpi.sql`,
  `ssas_dim_finance_column.sql`, `ssas_dim_finance_target.sql`
- Modify: `ssas_fact_gl_fs_monthly.sql`, `ssas_dim_pl_report_line.sql`, `ssas_fact_pl_report_monthly.sql`,
  `_ssas__models.yml` (contracts, hand-written: the receiving server regenerates at G2),
  `hnh_dwh/tests/hnh/assert_mart_text_title_case.sql` (`excluded`)
- Test: `FinanceModels.Tests.ps1`

**Interfaces:**
- `dim_finance_kpi(kpi_code, kpi_group, group_order, kpi_name, unit ('%'|'x'|'d'), direction (1 higher better, -1
  lower), display_order, card_code ('' or 'F1'..'F6'))`, a values list. Codes, groups and order (exact):
  Growth & budget achievement: `FR_REV_GROWTH` Net revenue growth %(1), `FR_REV_VS_BUD` Net revenue vs budget %(1),
  `FR_NP_GROWTH` Net profit growth %(1), `FR_NP_VS_BUD` Net profit vs budget %(1);
  Profitability: `FR_GP_MARGIN`, `FR_EBITDA_MARGIN`, `FR_OP_MARGIN`, `FR_NP_MARGIN`, `FR_ROA`, `FR_ROE` (all %, 1);
  Liquidity: `FR_CURRENT_RATIO`, `FR_QUICK_RATIO`, `FR_CASH_RATIO` (x, 1);
  Efficiency & working capital: `FR_AR_DAYS` (d,-1), `FR_INV_DAYS` (d,-1), `FR_AP_DAYS` (d,1), `FR_CCC` (d,-1),
  `FR_ASSET_TURNOVER` (x,1);
  Leverage & solvency: `FR_DEBT_EQUITY` (x,-1), `FR_NET_DEBT_EBITDA` (x,-1), `FR_INTEREST_COVER` (x,1),
  `FR_EQUITY_RATIO` (%,1);
  Cost structure & revenue cycle: `FR_COST_TO_REV` Cost of revenue ratio (%,-1), `FR_STAFF_COST_RATIO` (%,-1),
  `FR_MED_MATERIALS_RATIO` (%,-1), `FR_REJECTION_RATE` Claim rejection rate (%,-1), `FR_ECL_RATIO` Credit loss charge
  (%,-1). Cards: F1 `FR_REV_GROWTH`, F2 `FR_EBITDA_MARGIN`, F3 `FR_NP_VS_BUD`, F4 `FR_AR_DAYS`, F5
  `FR_REJECTION_RATE`, F6 `FR_COST_TO_REV`.
- `dim_finance_column(column_key, page ('tb'|'is'|'bs'|'kpi'), view ('monthly'|'hospital'), group_name, group_order,
  column_name, column_order, kind, month_num)`, a values list; kinds and labels per page:
  tb monthly: group "Period" [Opening `opening`, Opening journals `opening_journal`, Debit `debit`, Credit `credit`,
  Closing `closing`, Cutover difference `cutover`], "Net movement by month" [Jan..Dec `month`, month_num 1..12],
  "Closing vs last year and budget" [Last year `ly`, Growth `growth`, Budget `budget`, vs Bud `vs_bud`];
  is monthly: "Actual by month" [Jan..Dec], "Period total" [Actual `actual`, Budget, Variance `variance`, Var %
  `var_pct`, Last year, Growth, % Rev `pct_rev`];
  bs monthly: "Month-end balance" [Jan..Dec], "End of period vs last year and budget" [Last year, Growth, Budget,
  vs Bud, % Assets `pct_assets`];
  kpi monthly: "Period" [Target `target`, Actual, Status `status`, Budget, vs Bud, Last year, vs LY `vs_ly`],
  "Actual by month" [Jan..Dec];
  hospital views (all four pages): one group "" with [Ach % `ach`, Growth] (tb, bs: also Closing `closing` first;
  is: Actual first), kpi hospital: [Actual, vs Bud, vs LY].
- `dim_finance_target(kpi_code, branch_id, year, target_value, watch_pct)` from `stg_ref__finance_target`.
- `dim_date.year_pick String`: `if(toYear(d.date_day) = toYear(addMonths(toStartOfMonth(today()), -1)), 'Current
  year', toString(toYear(d.date_day)))` (the last closed month's year); sorted by year (Task 7 `SORT_BY`).
- `ssas_fact_gl_fs_monthly` adds: `debit`, `credit`, `account_name`, title-cased display columns `fs_type_name`,
  `fs_element_name`, `fs_category_name`, `fs_caption_name`, and BS grouping `bs_side` ('Assets' | 'Liabilities &
  equity'), `bs_element` ('Assets' | 'Liabilities' | 'Equity'), `bs_category`, `bs_caption` (title-cased category and
  caption for BS rows; IS rows: 'Liabilities & equity' / 'Equity' / 'Equity' / 'Current year profit'), `display_sign`
  (BS assets +1, liabilities/equity -1; IS -1), `sort` columns `bs_element_order`, `bs_category_order`.
- `ssas_dim_pl_report_line` keeps `budget_line_code`, `budget_sign`; adds `budget_kind` ('linked' | 'unlinked' |
  'subtotal'). `ssas_fact_pl_report_monthly` keeps `account_name`.

- [ ] **Step 1:** Failing tests: `It 'year_pick labels the last closed month''s year Current year'`;
  `It 'maps IS rows to Equity / Current year profit'`; `It 'lists 27 KPIs with six cards F1..F6'`;
  `It 'has 12 month columns per monthly page'`.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement models and views (`hnh_ssas_view` as the siblings); contracts in
  `_ssas__models.yml`. **Step 4:** Run → PASS; `python scripts/render_model_sql.py <each new model>` renders.
- [ ] **Step 5:** Commit.

## Part B: SSAS model

### Task 7: Tables, relationships and the Finance Report perspective

**Files:**
- Modify: `ssas/tools/model_config.py` (TABLES, DIM_KEYS / relationships, NO_RELATIONSHIP, SORT_BY, COLUMN_NAMES,
  HIDDEN_COLUMNS, PERSPECTIVES, PERSPECTIVE_MEASURE_DOMAINS)
- Generated: `ssas/HNH_Analytics/tables/*.tmdl`, `relationships.tmdl`, `perspectives/Finance Report.tmdl`
- Create: `ssas/tools/test_finance_perspective.py`

**Interfaces:**
- Tables: `Finance Budget` (fact: → Branch, Date via `month_date_key`, P&L Line via `pl_line_key`), `Finance KPI`
  (dim, no relationship), `Finance Column` (dim, no relationship), `Finance Target` (no relationship: branch_id 0 =
  all, resolved in DAX). Sort: `Date[Year Pick]` by `Year`; `Finance Column[Column Name]` by `Column Order`,
  `[Group Name]` by `Group Order`; `Finance KPI[KPI Name]` by `Display Order`, `[KPI Group]` by `Group Order`;
  `GL FS Monthly[BS Element]` by `BS Element Order`, `[BS Category]` by `BS Category Order`.
- Perspective `Finance Report`: `GL FS Monthly`, `P&L Report`, `P&L Line`, `Finance Budget`, `Finance KPI`,
  `Finance Column`, `Finance Target`, `Branch`, `Date`; measure domain `Finance`.
- `Balanced Scorecard` and `HR Dashboard` perspectives gain `P&L Report` and `Finance Budget` (their measures will
  read them, Task 12).

- [ ] **Step 1:** Failing pytest `test_finance_report_perspective_has_the_report_tables` and
  `test_finance_budget_relates_to_branch_date_and_pl_line` (read the generated TMDL with `hnh_tmdl`).
- [ ] **Step 2:** `python -m pytest ssas/tools/test_finance_perspective.py` → FAIL.
- [ ] **Step 3:** Edit `model_config.py`; `python ssas/tools/generate.py --from-contracts`.
- [ ] **Step 4:** pytest → PASS; full `python -m pytest ssas/tools` passes. **Step 5:** Commit.

### Task 8: Building blocks (`Fin *`)

**Files:** Modify `ssas/HNH_Analytics/tables/_Measures.tmdl`, `ssas/tests/measures/finance.json`.

**Interfaces (all `Finance\Building Blocks`, hidden, `#,0`, SAR, today cutoff):**
- From `P&L Report` by `'P&L Line'[PL Line Code]`, positive for costs: `Fin Revenue Total` (REV_TOTAL),
  `Fin Net Revenue` (NET_REVENUE), `Fin Direct Cost` (-DIRECT_COST), `Fin Gross Profit` (GROSS_PROFIT), `Fin G&A`
  (-GA_TOTAL), `Fin Marketing` (-SM), `Fin HO Charges` (-HO_CHARGES), `Fin Other Income` (OTHER_INCOME),
  `Fin EBITDA` (EBITDA), `Fin D&A` (-DEPRECIATION), `Fin Finance Cost` (-FINANCE_COST), `Fin Zakat` (-ZAKAT),
  `Fin Net Profit` (NET_PROFIT), `Fin Consumables` (-DC_CONSUMABLES), `Fin Medicines` (-DC_MEDICINES),
  `Fin Employee Cost` (-(DC_EMPLOYEE + GA_EMPLOYEE)), `Fin Doctors Fee` (-DC_DOCTORS_FEE), `Fin Rejections`
  (-DIS_REJECTION), `Fin ECL` (-GA_ECL), `Fin Opex` = `[Fin Net Revenue] + [Fin Other Income] - [Fin EBITDA]`.
- Month-end from `GL FS Monthly` (per branch, last month with data in context, summed over branches; display sign):
  `Fin Trade Receivables` (caption `trade receivables, net`), `Fin Inventories` (`inventories, net`), `Fin Cash`
  (`cash and bank balances`), `Fin Trade Payables` (`trade payables`, credit-positive), `Fin Current Assets`
  (category `current assets`), `Fin Current Liabilities` (`current liabilities`, credit-positive), `Fin Total Assets`
  (element `assets`), `Fin Total Liabilities` (element `liabilities`, credit-positive), `Fin Lease Liability`
  (caption `lease liability`, credit-positive).
- Helpers: `Fin Period Days` (days of the months in context up to today), `Fin Annualise` (12 / months in context).
- Budget twins, from `Finance Budget` IS rows: `Fin Budget Net Revenue`, `Fin Budget Direct Cost`, `Fin Budget G&A`,
  `Fin Budget Marketing`, `Fin Budget EBITDA`, `Fin Budget Net Profit`, `Fin Budget Consumables`,
  `Fin Budget Medicines`, `Fin Budget Opex` (= NET_REVENUE + OTHER_INCOME − EBITDA budgets); blank when the total is 0.

- [ ] **Step 1:** Add checks to `finance.json` (DAX vs SQL on `gold.ssas_fact_pl_report_monthly` /
  `gold.ssas_fact_gl_fs_monthly` / `gold.ssas_fact_finance_budget_monthly`): `Fin Net Revenue, branch 3, 2025-06`;
  `Fin EBITDA, branch 2, 2026` (crosses the cutover); `Fin Trade Receivables, branch 5, 2026-03..2026-05` (= May
  closing); `Fin Net Revenue, branch 3, 202612` → blank (`allow_zero: true`, SQL `select 0`) (Review Focus 3);
  `Fin Budget EBITDA, branch 1, 2026-01`.
- [ ] **Step 2:** Write the measures. **Step 3:** guards, perspectives, pytest, BPA → clean.
- [ ] **Step 4:** Commit. (The DAX checks run at GATE G3.)

### Task 9: Statement measures (`FR *`)

**Files:** `_Measures.tmdl`, `finance.json`.

**Interfaces (folder `Finance\Report`):**
- Income statement, in context of `'P&L Line'`: `FR Actual` (`P&L Report` amount; a subtotal line = its own row),
  `FR Last Year` (`SAMEPERIODLASTYEAR` of the months in context, today cutoff on the current year only), `FR Budget`
  (`Finance Budget` IS amount; like-for-like for many branches: Σ over branch × month with a budget),
  `FR Actual (Budgeted)` (actual over the same branch-months as `FR Budget`), `FR Budget Variance`
  (`[FR Actual (Budgeted)] - [FR Budget]`), `FR Budget Variance %` (÷ ABS budget), `FR Achievement %`,
  `FR Growth %` (÷ ABS last year), `FR % of Revenue` (÷ `Fin Net Revenue` of the same context without the line
  filter), `FR Budget Label` (text: `Not budgeted` when the line's `Budget Kind` = unlinked and no override,
  `No budget yet` when blank, else `""`), `FR Budget Basis Label` ("vs budget (budgeted hospitals)" when a branch in
  context has no budget, else "vs budget"), `FR Favourable` (1/-1/0 by the line's nature: revenue and profit lines
  higher is better, costs lower).
- Trial balance and balance sheet, in context of `GL FS Monthly` columns: `FR GL Opening` (opening of the first
  month in context per branch), `FR GL Opening Journals`, `FR GL Debit`, `FR GL Credit`, `FR GL Net Movement`,
  `FR GL Closing` (last month per branch), `FR GL Cutover Difference` (`Closing - Opening - Journals - Debit +
  Credit`, blank when |x| < 1), `FR GL Closing Last Year`, `FR BS Balance` (display sign; for `bs_caption = "Current
  year profit"` = `[Fin Net Profit]` year to date of the last month in context), `FR BS Difference`
  (assets − liabilities − equity − current year profit, blank when |x| < 1), `FR BS Budget` (`Finance Budget` BS rows
  by caption; `No budget yet` via `FR BS Budget Label`), `FR % of Assets`.
- Tiles: `FR Period Debits`, `FR Period Credits`, `FR Out of Balance` (debits − credits), `FR Net Working Capital`
  (current assets − current liabilities).

- [ ] **Step 1:** Checks: `FR Actual NET_PROFIT branch 6 2025` vs SQL; `FR GL Cutover Difference, branch 2,
  202608..202609` non-blank vs SQL (Review Focus 1); `FR Actual (Budgeted), all hospitals, 2026-03, NET_REVENUE` =
  SQL over branches 1-6 only (Review Focus 2); `FR Budget, branch 7` → blank; `FR BS Difference` matches SQL for
  branch 4, 2026-06; `FR Out of Balance, branch 1, 2025-12` vs SQL `sum(debit) - sum(credit)`.
- [ ] **Step 2:** Write. **Step 3:** guards, perspectives, pytest, BPA. **Step 4:** Commit.

### Task 10: Matrix cell, colour and header measures

**Files:** `_Measures.tmdl`, `finance.json`, `ssas/tools/test_finance_cells.py` (create).

**Interfaces:**
- `FR TB Cell`, `FR IS Cell`, `FR BS Cell` (text): `SWITCH` on `SELECTEDVALUE('Finance Column'[Kind])`; `month`
  kinds evaluate the page's monthly figure for `'Date'[Month] = month_num` and return BLANK when that month is not in
  the months picked (so the matrix drops the column); amounts `FORMAT ( x / 1000, "#,0;(#,0);–" )`; % kinds `"▲ 0.0%"`
  / `"▼ 0.0%"` (`0.0%` within 0.05, `n/m` above 999 %); placeholder labels from Task 9; `ach` = closing / budget %;
  BLANK when every component is blank (so empty rows drop).
- `FR Cell Colour` (hex): favourable `#04705F` / unfavourable `#C2230A` on variance and growth kinds, `#9AA7B5` on
  placeholders, else `#0A1E32`.
- `FR Period Text` ("Oct 2026" / "Jan to Oct 2026").
- Tile lines, one set per tile of Task 15: `FR Tile <Tile> vs Budget`, `FR Tile <Tile> vs LY` (text, e.g. "▲ 3.2% vs
  budget (budgeted hospitals)", "+1.4 pt vs last year" for margins) and their `… Colour` twins (favourable /
  unfavourable / muted).
- Chart series with the canvas's default line when the matrix has no selection: `FR Chart Actual`, `FR Chart Budget`,
  `FR Chart Last Year`, `FR Chart vs Budget %`, `FR Chart vs LY %`, each `IF ( ISFILTERED ( <row column> ), <figure>,
  CALCULATE ( <figure>, <default row> ) )` per page kind: trial balance and balance sheet default
  `'GL FS Monthly'[FS Caption] = "trade receivables, net"` (month-end balance), income statement default
  `'P&L Line'[PL Line Code] = "NET_REVENUE"`; one set per page kind (`FR Chart TB …`, `FR Chart IS …`, `FR Chart BS …`).
- `test_finance_cells.py`: `test_every_finance_column_kind_is_handled` (every kind in `dim_finance_column.sql` for
  page X appears in `FR X Cell`'s SWITCH).

- [ ] **Step 1:** Failing pytest; checks `FR IS Cell, NET_REVENUE, Actual, branch 3, 2025` = SQL /1000 formatted;
  `FR IS Cell, REV_CASH, Budget` = `Not budgeted`; `FR TB Cell, Feb column, months Jan..Mar` non-blank and `Apr
  column` blank.
- [ ] **Step 2:** Write. **Step 3:** guards, perspectives, pytest, BPA. **Step 4:** Commit.

### Task 11: KPI measures

**Files:** `_Measures.tmdl`, `finance.json`, create `ssas/tools/test_finance_kpi_switch.py`.

**Interfaces:**
- `FR KPI Value` (`SWITCH` on `SELECTEDVALUE('Finance KPI'[KPI Code])`, one branch per code of Task 6, from `Fin *`;
  annualised where the canvas annualises: ROA, ROE, asset turnover, net debt / EBITDA; days = balance /
  flow × `Fin Period Days`; `FR_AP_DAYS` flow = direct cost − employee − doctors fee + G&A − G&A employee +
  marketing; `FR_DEBT_EQUITY` = lease liability / (total assets − total liabilities); `FR_OP_MARGIN` uses EBITDA −
  D&A; `FR_REJECTION_RATE` = rejections / revenue total); DIVIDE so a zero denominator is blank; a negative
  denominator in `FR_NET_DEBT_EBITDA` and `FR_INTEREST_COVER` → blank.
- `FR KPI Budget` (same formula on `Fin Budget *`, blank when an input has no budget; growth KPIs blank;
  `FR_*_VS_BUD` budget = 100 %), `FR KPI Last Year`, `FR KPI Target` (`Finance Target` for the KPI, year of the
  last month in context, branch row else branch 0), `FR KPI Attainment`, `FR KPI Status` (text per the Global
  status rule), `FR KPI Status Colour`, `FR KPI Cell` (text, kinds of `kpi` pages), `FR KPI Count On` / `Watch` /
  `Off`, `FR KPI Card Line Budget` / `Card Line LY` (monthly) and `FR KPI Card Best` / `Card Lowest` (hospital page).
- `test_finance_kpi_switch.py`: `test_every_kpi_code_has_a_switch_branch` (codes parsed from
  `dim_finance_kpi.sql` against the `FR KPI Value` SWITCH).

- [ ] **Step 1:** Failing pytest; checks `FR KPI Value, FR_EBITDA_MARGIN, branch 3, 2025` = SQL; `FR_INTEREST_COVER`
  for a branch-month with no finance cost → blank, `FR KPI Status` = `No target yet` (Review Focus 4);
  `FR KPI Value FR_CURRENT_RATIO, branch 5, 2026-06` = SQL.
- [ ] **Step 2:** Write. **Step 3:** guards, perspectives, pytest, BPA. **Step 4:** Commit.

### Task 12: Unify the model on the finance definitions

**Files:** `_Measures.tmdl`, `ssas/tests/measures/balanced_scorecard.json`, `finance.json`, `hr_dashboard.json` (if a
check's expected value moves), create `ssas/scripts/compare_bsc_actuals.ps1` (+ Pester `CompareBscActuals.Tests.ps1`).

**Interfaces — rewrites (expression only; names, folders and format strings unchanged):**

| Measure | New body |
|---|---|
| `BSC GL Net Revenue` | `[Fin Net Revenue]` |
| `BSC GL Opex` | `[Fin Opex]` |
| `BSC GL EBITDA` | `[Fin EBITDA]` (other income now in) |
| `BSC GL G&A` | `[Fin G&A]` (P&L G&A section) |
| `BSC GL Consumables` | `[Fin Consumables]` (now includes Oasis cost of goods sold, per the P&L rules) |
| `BSC GL Income` | `[Fin Net Profit]` |
| `BSC GL Marketing` | `[Fin Marketing]` |
| `BSC GL COGS` | `[Fin Consumables] + [Fin Medicines]` |
| `BSC GL Rejection` | `[Fin Rejections]` |
| `BSC GL AR Average` | `[Fin Trade Receivables]` (month-end; description updated) |
| `BSC GL Inventory Average` | `[Fin Inventories]` (month-end) |
| `BSC Return on Assets` | `[Fin Net Profit] * [Fin Annualise] / [Fin Total Assets]` (as `FR_ROA`) |
| `BSC Budget Net Revenue` / `EBITDA` / `Opex` / `G&A` / `Consumables` / `Marketing` / `Medicines` | the `Fin Budget *` twin |
| `EBITDA`, `Gross Profit`, `Net Profit` | `[Fin EBITDA]`, `[Fin Gross Profit]`, `[Fin Net Profit]` |
| `EBITDA Margin %` | `DIVIDE ( [Fin EBITDA], [Fin Net Revenue] )` |

`BSC GL Assets Opening` stays if still referenced, else is removed. `_Unguarded` copies are rewritten by
`measure_guards.py`; `python ssas/tools/gen_bsc_kpi_lists.py` is re-run if `test_gen_bsc_kpi_lists.py` asks.

- `compare_bsc_actuals.ps1 -Database <db> -YearMonth <yyyymm> -Out <csv>` (read-only): `[BSC Actual]` and
  `[BSC Target]` per `'BSC KPI'[KPI Code]` × hospital (1-8) for the month, written to CSV; `-Compare <before.csv>
  <after.csv>` prints KPI, hospital, before, after, change %, sorted by |change|.

- [ ] **Step 1:** Run `compare_bsc_actuals.ps1 -Database HNH_Analytics_Test -YearMonth 202610 -Out
  C:\HNH\finance\bsc_before.csv` now (read-only; the test slot still has the old measures). Pester test for the
  script's CSV shape and compare output (inline tables).
- [ ] **Step 2:** Rewrite the measures; update the checks whose expected SQL encoded the old definitions (EBITDA
  without other income, average AR/inventory, G&A category) to the P&L / month-end SQL.
- [ ] **Step 3:** guards, perspectives, `python -m pytest ssas/tools` (incl. `test_bsc_kpi_lists_agree`), BPA → clean.
- [ ] **Step 4:** Commit. (After-values and the comparison table come at GATE G3.)

## Part C: the report

### Task 13: Report scaffolding and frame

**Files:**
- Create: `powerbi_tmdl/hnh_finance_report/build.py` (copy of `hnh_hr_report/build.py`: report `FIN_REPORT`, page
  list from this folder's `pages.py`, branch filter lock), `fin_frame.py`, `pages.py`, `README.md`,
  `tests/__init__.py`, `tests/conftest.py` (as HR's), `tests/test_fin_frame.py`

**Interfaces (`fin_frame.py`):**
- `FIN_FRAME = frame.FrameSpec("Finance Report", "Hayat Healthcare", TABS, [], logo=LOGO.name)`, `TABS = [("tb_monthly",
  "Trial Balance"), ("is_monthly", "Income Statement"), ("bs_monthly", "Balance Sheet"), ("kpi_monthly", "KPIs &
  Ratios")]`; `FIN_REPORT = ReportSpec("HNH Finance", "Finance Report", THEME, LOGO, custom_visual=False,
  cross_filter=True)`.
- `PAGE_NAMES = {"tb": ("tb_monthly", "tb_hospitals"), "is": (…), "bs": (…), "kpi": (…)}`; display names "Trial
  Balance", "Trial Balance · Hospitals", ….
- `page_frame(statement: str, view: str) -> list[Visual]`: `frame.frame` with the statement's tab current and the
  filter bar `filter_bar(statement, view)`.
- `filter_bar(statement, view) -> list[Visual]`: view buttons (two `nav_button`s to the twin pages, the current one
  navy-filled), on monthly pages the Hospital tile slicer on `Branch[Branch Name]` (Select all on, label "All"),
  on hospital pages a text box "All eight, side by side with the total", the Year tile slicer on `Date[Year Pick]`
  (single select, saved "Current year", filtered to years 2022 and later), the Month tile slicer on
  `Date[Month Short]` (multi-select, no saved selection), the period text card `[FR Period Text]` and "SAR '000".
- `hospitals() -> Filter` (`Branch[Branch Key]` in 1..8), applied to every page and locked.
- Colour constants of the Global Constraints.

- [ ] **Step 1:** Failing tests: `test_every_page_has_the_frame_and_four_tabs`, `test_view_buttons_link_the_twin_pages`,
  `test_hospital_slicer_only_on_monthly_pages`, `test_branch_filter_is_locked_on_every_page`,
  `test_fields_are_in_the_finance_report_perspective` (`fields.unknown_fields(..., perspective="Finance Report")` → []).
- [ ] **Step 2:** `python -m pytest powerbi_tmdl/hnh_finance_report` → FAIL. **Step 3:** Implement (pages.py lists
  eight empty pages with the frame). **Step 4:** PASS; `python -m pytest powerbi_tmdl` (BSC and HR suites, incl.
  `test_bsc_unchanged.py`) still passes. **Step 5:** Commit.

### Task 14: Shared content blocks

**Files:** Create `powerbi_tmdl/hnh_finance_report/fin_blocks.py`, `tests/test_fin_blocks.py`.

**Interfaces:**
- Geometry (page px, below the frame at y 162): tiles block (24, 178, 540, 172) as a 2×2 grid (gap 8); left chart
  (576, 178, 654, 172); right chart (1242, 178, 654, 172); matrix (24, 362, 1872, 694). KPI pages: six cards across
  (24, 178, 1872, 172), gap 12.
- `tile(label: str, value: Field, line1: Field, colour1: Field, line2: Field, colour2: Field, rect) -> list[Visual]`
  (white panel, label 11.5 pt muted caps, value card 25 pt, two right-aligned text cards coloured by measure, as
  `hr_frame.kpi_tile`).
- `monthly_chart(title: str, measures: list[Field], colours: list[str], rect)`: clustered column by
  `Date[Month Short]` with data labels; `variance_chart(title, measures, rect)`; `ranked_bars(title, measure, rect,
  favourable: Field | None)` by `Branch[Branch Name]`, sorted desc.
- `statement_matrix(page: str, view: str, rows: list[Field], cell: Field, rect, expand_levels: int) -> Visual`:
  Rows = `rows`, Columns = (`Branch[Branch Name]` on hospital views) + `Finance Column[Group Name]`,
  `Finance Column[Column Name]`; Values = `cell`; visual filters `Finance Column[Page] = page`, `[View] = view`;
  values right-aligned, font colour by `[FR Cell Colour]` (`hr_frame.measure_colour`), header bands coloured per
  group (period `#0A2D6E` white text, months `#32A5E6`, comparison `#0A2D6E`), row subtotals bold, `expand=False`
  with the first `expand_levels` levels open.

- [ ] **Step 1:** Failing tests: `test_tile_has_value_and_two_coloured_lines`, `test_statement_matrix_filters_its_page_and_view`,
  `test_matrix_values_use_the_cell_colour_measure`. **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** PASS.
  **Step 5:** Commit.

### Task 15: Statement pages (trial balance, income statement, balance sheet)

**Files:** Create `powerbi_tmdl/hnh_finance_report/pages_statements.py`, `tests/test_statement_pages.py`; modify
`pages.py`.

**Interfaces (six pages; rows, tiles, charts exact):**
- `tb_monthly`: rows `GL FS Monthly`[FS Type Name] > [FS Element Name] > [FS Category Name] > [FS Caption Name] >
  [Account Name]; tiles Period debits `[FR Period Debits]`, Period credits, Out of balance (line 1 "In balance" teal /
  "Review" red), Total assets (`[Fin Total Assets]`, vs budget / vs last year); left chart `FR Chart TB Actual /
  Budget / Last Year` by `Date[Month Short]`, right chart `FR Chart TB vs Budget % / vs LY %` (Task 10); the matrix
  cross-filters both charts.
- `is_monthly`: rows `P&L Line`[Section Name] > [PL Line Label] > `P&L Report`[FS Caption] > [Account Name], matrix
  shows subtotal lines as rows with bold + band (`Line Kind` = subtotal via `FR Row Band` colour measure); tiles Net
  revenue, EBITDA, EBITDA margin, Net profit with `FR Budget Basis Label` text in the vs-budget line; default chart
  line NET_REVENUE; subtitle text: "Medicines and consumables: Oasis books cost of goods sold under Consumables.
  G&A budget excludes marketing and head office charges."
- `bs_monthly`: rows `GL FS Monthly`[BS Side] > [BS Element] > [BS Category] > [BS Caption] > [Account Name]; the
  spec's grey Difference row is a text card directly under the matrix's total row, shown only when
  `[FR BS Difference]` is not blank ("Difference (cutover / unmapped): …"), because a matrix cannot add a row that no
  GL row carries (deviation from the spec, told to the user); tiles Total assets, Net working capital, Current ratio (`FR KPI Value` for `FR_CURRENT_RATIO`), Receivable
  days; default chart line `trade receivables, net`.
- `*_hospitals`: same tiles over all eight; `ranked_bars` achievement % and growth % (income statement with
  favourable colours); hospital matrices.

- [ ] **Step 1:** Failing tests: `test_six_statement_pages_in_order`, `test_matrix_rows_per_page`,
  `test_tiles_per_page`, `test_hospital_pages_have_no_hospital_slicer`, `test_fields_in_perspective`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** PASS; `python powerbi_tmdl/hnh_finance_report/build.py`
  prints `report schemas: passed` and `Desktop project reader: opened`. **Step 5:** Commit.

### Task 16: KPI pages

**Files:** Create `powerbi_tmdl/hnh_finance_report/pages_kpi.py`, `tests/test_kpi_pages.py`; modify `pages.py`.

**Interfaces:**
- `kpi_monthly`: six cards (code chip, name, `Target …`, value 28 pt, status chip coloured by `[FR KPI Status
  Colour]`, budget and last-year lines, a 12-month small line chart of `[FR KPI Value]` by `Date[Year Month]`
  filtered to the card's KPI and `Date[Month Offset]` 1..12); header chips `[FR KPI Count On]` etc.; matrix rows
  `Finance KPI`[KPI Group] > [KPI Name], columns `Finance Column` (page `kpi`, view `monthly`), value `[FR KPI Cell]`.
- `kpi_hospitals`: same cards with Best / Lowest lines; matrix columns Branch × [Actual, vs Bud, vs LY], cell
  background by status (`FR KPI Status Colour` as background on the Actual kind via a `FR KPI Cell Background`
  measure).

- [ ] **Step 1:** Failing tests: `test_six_cards_f1_to_f6`, `test_kpi_matrix_rows_are_group_and_kpi`,
  `test_status_chips_present`. **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** PASS; build passes the checks.
  **Step 5:** Commit.

### Task 17: Docs and the upload file

**Files:** `powerbi_tmdl/hnh_finance_report/README.md`, `powerbi_tmdl/README.md` (an "HNH Finance route" section as
HR's), `ssas/README.md` ("Finance report" section: building blocks, unified definitions, config tables),
`docs/finance_config.md` (final).

- [ ] **Step 1:** Write the docs: route, deployment checklist (Part D), how to test as a one-hospital user, what to
  check on first open (cutover difference column appears only across a cutover; "Not budgeted" vs "No budget yet";
  Year opens on Current year; months pick; cross-filter from matrix to charts).
- [ ] **Step 2:** `python powerbi_tmdl/hnh_bsc_report/pbir_to_pbix.py "powerbi_tmdl/hnh_finance_report/HNH Finance.pbip"
  --out "C:\HNH\report\HNH Finance.pbix"`, then from `powerbi_tmdl/hnh_bsc_report`:
  `python -c "from pbix import check_upload_rules; print(check_upload_rules(r'C:\HNH\report\HNH Finance.pbix'))"` → `[]`.
- [ ] **Step 3:** Commit.

### Task 18: Security check entry

**Files:** `ssas/tests/security.json`.

- [ ] **Step 1:** Add an entry: a one-branch login (as the existing HR entries) sees `[FR Actual]` for NET_REVENUE only
  for its branch and blank for others; "All" equals its branch. **Step 2:** `Invoke-Pester -Script ssas\scripts` passes
  (the entry runs at GATE G3 with `test.ps1 -Stage Security`). **Step 3:** Commit.

## Part D: gates (each needs the user's go-ahead at the time)

- **G1 ClickHouse:** `powershell -ExecutionPolicy Bypass -File scripts\finance_config\apply_finance_config.ps1`
  (creates the two empty tables).
- **G2 dbt (user, receiving project, off-hours, `--threads 1`):** `dbt build --select stg_bsc__oasis_gl_line
  stg_bsc__oasis_gl_account fact_gl_fs_monthly+ fact_pl_report_monthly+ dim_pl_report_line+ stg_ref__finance_budget+
  stg_ref__finance_target+ dim_finance_kpi+ dim_finance_column+ dim_date+` → ERROR=0 (runs unit and yml tests incl.
  `assert_gl_fs_debit_credit_ties`, `assert_pl_line_budget_link`, `assert_pl_report_ties_to_gl`, title case). Then
  regenerate the view contracts read-only through `HNH_Gold` and compare with the hand-written ones; `generate.py
  --from-contracts` again if they differ.
- **G3 test slot:** `deploy.ps1 -Stage TestMeasures` and process the changed tables of `HNH_Analytics_Test`
  (`GL FS Monthly`, `P&L Report`, `P&L Line`, `Finance *`, `Date`); `test.ps1` measure checks (finance, BSC, HR)
  and security; `compare_bsc_actuals.ps1 -Database HNH_Analytics_Test -YearMonth 202610 -Out
  C:\HNH\finance\bsc_after.csv` and `-Compare` → show the user the table before anything else.
- **G4 upload:** build, convert, `check_upload_rules` → `[]`, open in Desktop for Report Server, upload into a new
  Finance folder at `http://hnhanalyticssrv/reports`; screenshots of the eight pages against the canvas.
- **G5 production (separate, later):** deploy to `HNH_Analytics`, rebuild with `--database HNH_Analytics`, re-upload.
