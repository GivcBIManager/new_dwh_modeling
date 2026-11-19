# Physician Contract Review (HNH Physician Review) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A one-page Power BI report "HNH Physician Review" on `HNH_Analytics_Test` that shows, for one selected
physician and review period, the package and the financial contribution against specialty peers in the home hospital
and across the Group.

**Architecture:** No new fact. dbt adds physician columns to `dim_staff` (population flag, Fusion title, pay grade,
employment type, hire date, and a key that attaches a doctor's rows in other hospitals to the home row), a doctor key
on `fact_claim_line`, and two small list tables (metrics, peer scope). SSAS gets `PR *` measures over the existing
facts, dispatched by the metric list and the peer scope. A new generator `powerbi_tmdl/hnh_physician_review_report/`
writes the PBIP; `pbir_to_pbix.py` writes the upload file.

**Tech Stack:** dbt on ClickHouse (receiving project, built by the user on 172.22.25.214), SSAS Tabular TMDL
(`ssas/tools`), DAX, Python 3.12 + pytest, Pester (Windows PowerShell 5.1), Tabular Editor 2 BPA, PBIR generator.

**Spec:** `docs/superpowers/specs/2026-11-19-physician-contract-review-design.md` (read it first; this plan does not
repeat its definitions).

## Global Constraints

- **Production server (CLAUDE.md). GATE** = the user's go-ahead at the time, every time: any dbt build in the
  receiving project, `deploy.ps1`, `process.ps1`, the upload, any role or folder change. Read-only needs none:
  `SELECT` through DSN `HNH_Gold`, `scripts/render_model_sql.py`, DAX (`Invoke-HnhDax`), pytest, Pester, BPA.
- **dbt is not installed here.** Check each model offline: rendered by `scripts/render_model_sql.py`, refs replaced
  by inline rows, run read-only through `HNH_Gold`, in a Pester file shaped like
  `scripts/finance_config/FinanceModels.Tests.ps1`. No `{% set %}` in new models. dbt yml tests run at GATE G2.
- **Title case (CLAUDE.md):** `job_title` is source text: `{{ hnh_title('j.job_name') }}` at the mart's output,
  qualified column. Repo labels (`employment_type`, metric names, scope names) and codes (`pay_grade`) are not
  title-cased; add `metric_name` and `scope_name` to the `excluded` list of
  `hnh_dwh/tests/hnh/assert_mart_text_title_case.sql`, and `job_title` to its `extra` list.
- **Pay stays gated.** No pay amount, increment or package value may be stored on `Staff` or any table without a
  `Can See Pay` filter. Pay is read only from `Payroll`.
- **No role change.** `ssas/HNH_Analytics/roles/*.tmdl` are not edited.
- **Measures:** in `ssas/HNH_Analytics/tables/_Measures.tmdl`; edit only between `VAR __Value = ( -- measure body`
  and `) -- end of measure body`; each has `///`, `formatString`, `displayFolder` (`Physician Review\Building Blocks`
  hidden, `Physician Review\Report` visible) and a check in `ssas/tests/measures/physician_review.json` (shape of
  `finance.json`). Every `PR` measure carries `hnh_guard_allow` for `Review Metric`, `Peer Scope`, `Staff`, `Branch`
  and `Date`. After edits: `python ssas/tools/measure_guards.py`, `python ssas/tools/sync_perspectives.py`,
  `python -m pytest ssas/tools`, BPA
  `"C:\Program Files (x86)\Tabular Editor\TabularEditor.exe" ssas\HNH_Analytics -A ssas\bpa_rules.json -V` (no
  `type=error`).
- **Exact values from the spec:** physician jobs `Consultant`, `Senior Registrar Doctor`, `Registrar Doctor`,
  `Specialist`, `General Physician`, `Resident Doctor` (compared on the raw Fusion `job_name`, case-insensitive);
  package categories `Basic`, `Housing`, `Transport`, `Food`, `Clinical allowances`, `Other allowances`; within band
  `0.10`; labels `Above`, `Within`, `Below`, `No peers`, `Select one physician`, `Full-time`, `Part-time`,
  `Not linked`, `from payroll`; performance budget 10 seconds.
- **Report rules:** no report measures, bookmarks, visual groups, AppSource visuals or hierarchy fields; page
  1920 × 1080; `check_upload_rules` returns `[]`.
- **Git:** worktree `D:\new_dwh_modeling-pr` on branch `physician-review` from `main` (1208e955), made with
  superpowers:using-git-worktrees. Commit at the end of each task, message ending
  `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`. Never push.

## Review Focus

1. **A physician with rows in two hospitals, Hospital slicer on the home hospital:** income still includes the
   other hospital. *Task 5 check.*
2. **A slicer moved after the physician is picked** (Specialty, Title, Employment type, Hospital): peer statistics do
   not change. *Task 6 check.*
3. **A peer group of one, and no physician or two physicians selected:** `No peers` with blank statistics; blank
   values with `Select one physician`. *Task 6 and Task 4 checks.*
4. **No revenue in the previous period** (a doctor who joined inside the review period): growth % blank, not an
   error or 100 %. *Task 5 check.*
5. **A reader without `Can See Pay`:** salary measures and the ratio blank, billed revenue and its peer statistics
   present. *Task 8 check.*

---

### Task 1: Physician columns on `dim_staff`

**Files:**
- Modify: `hnh_dwh/models/hnh/marts/conformed/dim_staff.sql`, its yml entry, `hnh_dwh/models/hnh/marts/ssas/ssas_dim_staff.sql`
  (not `ssas_dim_staff_role.sql`: the role copies do not get the columns)
- Create: `hnh_dwh/tests/hnh/assert_review_physician_key_has_one_home_row.sql`
- Modify: `hnh_dwh/tests/hnh/assert_mart_text_title_case.sql` (`extra`: `job_title`)
- Create: `scripts/physician_review/PhysicianReviewModels.Tests.ps1`, `scripts/physician_review/list_review_matches.sql`

**Interfaces:**
- Produces, on `dim_staff` and `ssas_dim_staff`:
  `is_review_physician UInt8`, `job_title String`, `pay_grade String`, `employment_type String`,
  `hire_date Nullable(Date)`, `review_physician_key Int64`.
  Unlinked rows: `0`, `'Not linked'`, `'Not linked'`, `'Not linked'`, null, `-1` (or the home key when attached).

- [ ] **Step 1: Write the failing Pester tests** in `PhysicianReviewModels.Tests.ps1`, rendering `dim_staff.sql`
  with inline rows for `bridge_employee_staff`, `dim_employee`, `dim_job`, `dim_grade` and the staff source:

  | Case | Inline rows | Expected |
  |---|---|---|
  | home row | DOCTORS, one employee, job `CONSULTANT`, part-time 0 | flag 1, `job_title` `Consultant`, `employment_type` `Full-time`, key = own `staff_key` |
  | non-physician job | DOCTORS, job `Nurse` | flag 0, key -1, `job_title` `Nurse` |
  | shared record | one staff row, two employees | flag 0, key -1 |
  | contingent | employee in `hnh_contingent_employee_keys()` | flag 0, key -1 |
  | other hospital, id agrees | same `staff_id`, other branch, same `national_id_hash`, unlinked | flag 0, key = home key |
  | other hospital, id missing | same `staff_id`, other branch, hash null on one side | key = home key |
  | other hospital, id differs | same `staff_id`, both hashes present and different | key -1 |
  | two candidate homes | same `staff_id` linked as a physician in two branches, third unlinked row | third row key -1 |
  | part-time | `is_part_time` 1 | `Part-time` |

- [ ] **Step 2: Run** `Invoke-Pester scripts/physician_review/PhysicianReviewModels.Tests.ps1`. Expected: FAIL
  (columns missing).
- [ ] **Step 3: Implement** the six columns in `dim_staff.sql` as CTEs joined at the end; title-case `job_title` in
  the final select only (CLAUDE.md pitfall). Pass them through `ssas_dim_staff.sql`. Add yml tests: `not_null` on
  the six columns except `hire_date`, `accepted_values` on `employment_type`.
- [ ] **Step 4: Write** `assert_review_physician_key_has_one_home_row.sql`: returns keys other than -1 whose count of
  rows with `is_review_physician = 1` is not exactly 1.
- [ ] **Step 5: Write** `list_review_matches.sql` (read-only): one row per attached other-hospital row with home and
  other branch, both staff names, whether the national id agreed or was missing, and `names_differ` (normalised
  lower-case, single spaces). Run it through `HNH_Gold` against the rendered model and save the result to the
  scratchpad for the user (Task 10 hands it over).
- [ ] **Step 6: Run** the Pester file. Expected: PASS. Also run the rendered model's population count read-only:
  about 745 flagged rows (spec); report the real number.
- [ ] **Step 7: Commit.**

### Task 2: Doctor key on claim lines

**Files:**
- Modify: `hnh_dwh/models/hnh/marts/revenue/fact_claim_line.sql`, its yml entry,
  `hnh_dwh/models/hnh/marts/ssas/ssas_fact_claim_line.sql`
- Test: `scripts/physician_review/PhysicianReviewModels.Tests.ps1`

**Interfaces:**
- Produces: `fact_claim_line.staff_key Int64` = `hnh_surrogate_key(['branch_id', 'doctor_code'])` built exactly as
  `dim_staff.staff_key` is (read its expression and reuse it), from `stg_oasis__claim_visits.doctor_code` joined on
  `(branch_id, visit_id)`; `-1` when the visit has no code or the key is not in `dim_staff`.

- [ ] **Step 1: Failing Pester tests:** a claim line whose visit has a known doctor gets that `staff_key`; unknown
  code → -1; null code → -1; the row count of the model is unchanged by the join (two visits rows must not
  duplicate lines: assert count before = count after on inline rows).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement**; add a yml `relationships` test to `dim_staff.staff_key`.
- [ ] **Step 4: Run.** Expected: PASS. Read-only check on production data: share of claim lines since 2025-01 with
  `staff_key != -1` is at least 99 % in every branch (the spec measured 100 % on visits).
- [ ] **Step 5: Commit.**

### Task 3: Metric list and peer scope

**Files:**
- Create: `hnh_dwh/models/hnh/marts/workforce/dim_physician_review_metric.sql`, `dim_peer_scope.sql`, yml entries
- Create: `hnh_dwh/models/hnh/marts/ssas/ssas_dim_physician_review_metric.sql`, `ssas_dim_peer_scope.sql`,
  entries in `_ssas__models.yml`
- Modify: `assert_mart_text_title_case.sql` (`excluded`: `metric_name`, `scope_name`)

**Interfaces:**
- Produces `dim_physician_review_metric` (a `values(...)` list as `dim_finance_kpi.sql`):

  | metric_code | metric_name | section | display_order | unit | direction |
  |---|---|---|---|---|---|
  | `PR_PACKAGE` | Monthly package | Salary | 1 | sar | 0 |
  | `PR_REVENUE` | Billed revenue | Income | 2 | sar | 1 |
  | `PR_REJECTION` | Claim rejection % | Income | 3 | % | -1 |
  | `PR_OP_VISITS` | OPD visits | Income | 4 | n | 1 |
  | `PR_ADMISSIONS` | Admissions | Income | 5 | n | 1 |
  | `PR_SURGERIES` | Surgeries / procedures | Income | 6 | n | 1 |
  | `PR_REV_PER_PATIENT` | Revenue per patient | Income | 7 | sar | 1 |
  | `PR_GROWTH` | Growth vs previous period | Income | 8 | % | 1 |
  | `PR_REV_TO_PAY` | Revenue-to-salary ratio | Income | 9 | x | 1 |

- Produces `dim_peer_scope`: (`HOSPITAL`, `Same hospital`, 1), (`GROUP`, `Group`, 2) as
  `scope_code, scope_name, display_order`.

- [ ] **Step 1: Pester tests:** nine metric rows, unique codes, sections only `Salary`/`Income`, direction in
  (-1, 0, 1); two scope rows.
- [ ] **Step 2: Run** (FAIL), **Step 3: implement**, **Step 4: run** (PASS), **Step 5: commit.**

### GATE G2: dbt build

- [ ] Ask the user to build, in the receiving project: `dim_staff`, `ssas_dim_staff`, `fact_claim_line`,
  `ssas_fact_claim_line`, the four new list models, and to run their tests plus the two `assert_*` tests. Give the
  exact selector and wait. Do not continue to Task 4 until the user reports the build.
- [ ] After it: read-only, confirm the new columns exist in `gold` and the flagged count matches Task 1 Step 6.

### Task 4: Model tables, relationship and selection measures

**Files:**
- Modify: `ssas/tools/model_config.py` (TABLES: `ssas_dim_physician_review_metric` → `Review Metric`,
  `ssas_dim_peer_scope` → `Peer Scope`, both `dim` and in NO_RELATIONSHIP; SORT_BY name → order; hidden order and
  code columns; relationship `Claim Lines`.`Staff Key` → `Staff`.`Staff Key`; perspective `Physician Review` with
  these two tables, as the `Finance Report` entry)
- Run: `python ssas/tools/generate.py` (needs the `HNH_CH_*` variables; reads ClickHouse only)
- Create: `ssas/tools/test_physician_review_perspective.py` (as `test_finance_perspective.py`)
- Modify: `_Measures.tmdl`; create `ssas/tests/measures/physician_review.json`

**Interfaces:**
- Produces columns `Staff[Is Review Physician]`, `Staff[Job Title]`, `Staff[Pay Grade]`, `Staff[Employment Type]`,
  `Staff[Hire Date]`, `Staff[Review Physician Key]` (hidden), `'Claim Lines'[Staff Key]` (hidden).
- Produces hidden building blocks:
  - `PR Home Key`: the `Review Physician Key` when exactly one `Staff[Staff Key]` is in context and it is a home row
    (`Is Review Physician` = 1 and key = own `Staff Key`); else blank.
  - `PR Period Start`, `PR Period End`: first and last `Date[Date]` in context, end capped at `TODAY ()`.
  - `PR Period Months`: whole months from start to end, inclusive.
  - `PR Previous Start` = `EDATE ( start, -months )`, `PR Previous End` = start − 1.
  - `PR Package Month`: the latest `Payroll` month key within the period that has any Basic pay, with every `Staff`
    and `Branch` filter removed (one month for all physicians).
- Produces visible `PR Selection Notice`: `""` when `PR Home Key` is not blank, else `Select one physician`.

- [ ] **Step 1: Write** `test_physician_review_perspective.py`: the perspective holds `Review Metric`, `Peer Scope`
  and every measure whose name starts `PR `; the relationship `claim_lines_staff_key` exists and is active; every
  `PR ` measure has `Review Metric`, `Peer Scope`, `Staff`, `Branch` and `Date` in `hnh_guard_allow`.
- [ ] **Step 2: Run** `python -m pytest ssas/tools/test_physician_review_perspective.py -v`. Expected: FAIL.
- [ ] **Step 3: Edit** `model_config.py`, run `generate.py`, add the measures, then the after-edit commands of
  Global Constraints.
- [ ] **Step 4: Add checks** to `physician_review.json`: for one home physician (pick one with 12 months of data;
  keep the staff key in the file, never the name) and the period 2025-11-01..2026-10-31: `PR Period Months` = 12,
  `PR Previous Start` = 2024-11-01, `PR Previous End` = 2025-10-31. Review Focus 3: with no `Staff` filter and with
  two staff keys, `PR Home Key` is blank and `PR Selection Notice` = `Select one physician`; with an attached
  other-hospital row alone, the same.
- [ ] **Step 5: Run** pytest and BPA. Expected: PASS, no `type=error`. **Commit.**

### Task 5: Physician values (`PR Value`, salary and income)

**Files:** `_Measures.tmdl`, `physician_review.json`, create `ssas/tools/test_physician_review_switch.py`.

**Interfaces:**
- Consumes: Task 4 building blocks; existing `Revenue`, `OP Visits`, `Admissions`, `Theatre Volume`,
  `Claim Rejection Rate %`, `Claims Rejected`, `Payroll Cost` (use their `_Unguarded` twins where the guard objects).
- Produces:
  - Hidden `PR Income Filter` pattern, used by every income measure: evaluate over all rows of the physician,
    ```
    CALCULATE ( <measure>,
        REMOVEFILTERS ( Staff ), REMOVEFILTERS ( Branch ),
        Staff[Review Physician Key] = [PR Home Key] )   -- key read into a VAR first
    ```
  - `PR Basic`, `PR Allowances`, `PR Monthly Package`, `PR Annual Package` (× 12): `Payroll Cost` of the home row in
    `PR Package Month` for the spec's categories. `PR Other Pay`: every other category over the review period.
  - `PR Last Increment Date`, `PR Last Increment Amount`, `PR Last Increment %`: over all payroll months of the home
    row (date filter removed), Basic per month; drop the first paid month and any month whose Basic is below both
    neighbours; the latest remaining month whose Basic exceeds the previous remaining month's.
  - `PR Value`: `SWITCH ( SELECTEDVALUE ( 'Review Metric'[Metric Code] ), ... )` with one branch per code of Task 3,
    each line starting with the quoted code (the switch test parses that).
    - `PR_REV_PER_PATIENT` = revenue ÷ `DISTINCTCOUNT ( 'Charge Lines'[Patient Key] )` over the same rows.
    - `PR_GROWTH` = revenue ÷ previous-period revenue − 1; blank when previous revenue is blank or 0.
    - `PR_REV_TO_PAY` = revenue ÷ `Payroll Cost` of the home row over the period; blank when pay is blank.
  - `PR Previous Value`: the same switch over `PR Previous Start..End` (blank for `PR_GROWTH` and `PR_PACKAGE`).
  - `PR Other Hospital Revenue %`: revenue on attached rows ÷ `PR_REVENUE`.
  - `PR Rejected Amount`: `Claims Rejected` over the physician's rows.

- [ ] **Step 1: Write** `test_physician_review_switch.py` on the pattern of `test_finance_kpi_switch.py`: the codes
  of `dim_physician_review_metric.sql` and the branches of `PR Value` are the same set, nine, no duplicates;
  `PR Previous Value` branches are a subset without `PR_GROWTH` and `PR_PACKAGE`.
- [ ] **Step 2: Run** it. Expected: FAIL.
- [ ] **Step 3: Implement** the measures.
- [ ] **Step 4: Add checks** to `physician_review.json`, each DAX value against a ClickHouse query on `gold`:
  - each of the nine metrics for the Task 4 physician and period;
  - package components for the same physician sum to `PR Monthly Package`;
  - **Review Focus 1:** a physician with attached rows (take one from `list_review_matches.sql`), with
    `Branch[Branch Key]` filtered to the home branch: `PR_REVENUE` equals the SQL sum over home and attached rows;
  - **Review Focus 4:** a physician whose first charge line falls inside the period: `PR_GROWTH` is blank;
  - last increment for three physicians, computed by the same rule in SQL.
- [ ] **Step 5: Run** pytest, guards, BPA. Expected: PASS. **Commit.**

### Task 6: Peer statistics

**Files:** `_Measures.tmdl`, `physician_review.json`.

**Interfaces:**
- Consumes: `PR Value`, `PR Home Key`, `Staff[Unified Specialty]`, `Staff[Job Title]`, `Staff[Branch Key]`,
  `'Peer Scope'[Scope Code]`, `'Review Metric'[Section]` and `[Direction]`.
- Produces `PR Peer Count`, `PR Peer Min`, `PR Peer Average`, `PR Peer Median`, `PR Peer Max`, `PR Rank`,
  `PR Rank Text` (`3 / 12`), `PR Position`, `PR Position Colour`, all over one hidden table expression:
  ```
  VAR Spec = SELECTEDVALUE ( Staff[Unified Specialty] )   -- of the selected home row, read before filters go
  VAR Title = SELECTEDVALUE ( Staff[Job Title] )
  VAR Home = SELECTEDVALUE ( Staff[Branch Key] )
  VAR Peers =
      CALCULATETABLE ( VALUES ( Staff[Staff Key] ),
          REMOVEFILTERS ( Staff ), REMOVEFILTERS ( Branch ),
          Staff[Is Review Physician] = 1,
          Staff[Unified Specialty] = Spec,
          <Salary section only> Staff[Job Title] = Title,
          <HOSPITAL scope only> Staff[Branch Key] = Home )
  VAR Valued =
      FILTER ( ADDCOLUMNS ( Peers, "@v",
          VAR k = Staff[Staff Key]
          RETURN CALCULATE ( [PR Value], REMOVEFILTERS ( Staff ), REMOVEFILTERS ( Branch ), Staff[Staff Key] = k ) ),
          NOT ISBLANK ( [@v] ) )
  ```
  The explicit `Staff[Staff Key] = k` is required: the slicer filters on other `Staff` columns would otherwise
  survive the row's context transition and empty every peer but the selected one.
- Rules: which peers count (spec, "Peer groups"): for `PR_PACKAGE`, those with a package in `PR Package Month`; for
  every income metric, those with billed revenue in the period (so a peer with revenue but no admissions counts as 0
  admissions, and a peer whose ratio or growth is blank is left out of that metric only). Rank 1 = highest value; for direction -1, lowest. With
  `PR Peer Count` = 1: statistics and rank blank, `PR Position` = `No peers`. Position: value above
  average × 1.10 → `Above`, below average × 0.90 → `Below`, else `Within`. Colour: direction 1 `Above` `#04705F`,
  `Below` `#C2230A`; direction -1 reversed; direction 0 and `Within` `#4D5B6B`; `No peers` `#9AA7B5`.
  No peer scope selected → `GROUP`.

- [ ] **Step 1: Add failing checks** to `physician_review.json` (they fail at G3 until the measures exist; offline
  the file is validated by `python -m pytest ssas/tools`): for one specialty with at least five physicians in one
  hospital, period as Task 4, each statistic of `PR_REVENUE` and `PR_PACKAGE` in both scopes against a ClickHouse
  query that builds the peer list independently (`medianExact` is not DAX's median: use
  `quantileExactInclusive(0.5)`).
  - **Review Focus 2:** the same statistics with `Staff[Job Title]`, `Staff[Employment Type]` and
    `Branch[Branch Key]` filtered to the physician's own values equal the unfiltered ones.
  - **Review Focus 3:** a physician who is the only one of the specialty in the hospital: `PR Peer Count` = 1,
    `PR Position` = `No peers`, `PR Peer Median` blank in `HOSPITAL` scope.
- [ ] **Step 2: Implement.** **Step 3: Run** pytest, guards, BPA. Expected: PASS. **Commit.**

### Task 7: Context and footer measures

**Files:** `_Measures.tmdl`, `physician_review.json`.

**Interfaces:**
- Produces: `PR FTE` (latest `Headcount` month in the period, home row), `PR Absence Days` (`Staff Productivity`,
  home row), `PR Clinic Days` (distinct `Clinic Capacity` dates with scheduled minutes > 0, all rows of the
  physician), `PR Clinic Hours` (minutes ÷ 60), `PR Clinic Utilisation %`, `PR Revenue Share OP`, `IP`, `ER`,
  `PR Revenue Share Cash` (pick the `Payer` column after reading its values read-only; record the choice in the
  measure's `///`), `PR Header` (name · id · hospital · specialty · title · type · pay grade · hired), `PR Footer`
  (`Sources: HR / Payroll (Fusion, Oasis) · Oasis billing · NPHIES claims · Review period <d MMM yyyy>–<d MMM yyyy>
  · Previous <…>–<…> · Data as of <latest charge-line date>`), `PR HR Data Note` (`FTE and absence from Jan 2026`
  when the period starts before 2026-01-01, else `""`).
- `PR FTE`, `PR Absence Days` read tables gated by pay access or starting in 2026: blank is a valid result.

- [ ] **Step 1: Add checks** for the Task 4 physician: clinic days and hours against SQL; the four shares sum
  sensibly (OP + IP + ER ≤ 1); `PR HR Data Note` is not empty for a period starting 2025-11-01 and empty for one
  starting 2026-02-01.
- [ ] **Step 2: Implement.** **Step 3: Run** pytest, guards, BPA. **Commit.**

### Task 8: Security and performance entries

**Files:** `ssas/tests/security.json`, `ssas/tests/performance.json`.

- [ ] **Step 1: Security cases** (Review Focus 5), in the file's existing shape, for the existing non-pay test
  reader and the pay test reader, with the Task 4 physician and period:
  - non-pay: `PR Monthly Package`, `PR Basic`, `PR Other Pay`, `PR Last Increment Amount`, `PR Value` for
    `PR_PACKAGE` and `PR_REV_TO_PAY`, and `PR Peer Average` for `PR_PACKAGE` are blank; `PR Value` and
    `PR Peer Average` for `PR_REVENUE` are not blank;
  - pay reader: all of them not blank.
- [ ] **Step 2: Performance case:** the comparison table's query (nine metrics × two scopes × all `PR` peer
  measures) for a physician of the largest specialty over 24 months, limit 10 seconds.
- [ ] **Step 3: Run** `python -m pytest ssas/tools`. **Commit.**

### Task 9: Report generator and the page

**Files:**
- Create: `powerbi_tmdl/hnh_physician_review_report/__init__.py`, `build.py` (copy of
  `hnh_finance_report/build.py`: report name `HNH Physician Review`, one page), `pr_frame.py`, `page_review.py`,
  `tests/__init__.py`, `tests/conftest.py`, `tests/test_review_page.py`

**Interfaces:**
- Consumes: the `PR` measures and the `Staff` columns above; the BSC report modules as the finance report uses them.
- Produces: `page_review.build_page() -> dict` (page id `review`), and the PBIP under
  `powerbi_tmdl/hnh_physician_review_report/HNH Physician Review.Report/`.

- [ ] **Step 1: Write failing tests** in `test_review_page.py`:
  - the report has exactly one page, 1920 × 1080;
  - slicers: `Staff[Staff Name]` (single select, search on), `Staff[Staff ID]`, `Branch` name,
    `Staff[Unified Specialty]`, `Staff[Job Title]`, `Staff[Employment Type]`, and one date slicer on `Date[Date]`;
  - a locked page filter `Staff[Is Review Physician] = 1` and hospitals 1..8 (as `hr_frame.lock_branch_filters`);
  - the salary block sits left of x = 960 and the income block right of it; no two visuals overlap;
  - every measure a visual uses exists in `_Measures.tmdl`, and none is defined in the report;
  - cards for `PR Basic`, `PR Allowances`, `PR Monthly Package`, `PR Annual Package`, the increment, and the eight
    income values; a salary table (rows `Peer Scope`, columns min, average, median, max, rank text, position); an
    income matrix (rows `Review Metric` filtered to `Income`, columns `Peer Scope`, values physician, average,
    median, highest, rank text, position with `PR Position Colour` as font colour); a line chart of `Revenue` by
    month with the previous period; text cards bound to `PR Header`, `PR Footer`, `PR Selection Notice`,
    `HR Pay Notice` (over the salary block), `PR HR Data Note`; a context band with `PR FTE`, `PR Clinic Days`,
    `PR Clinic Hours`, `PR Clinic Utilisation %`, `PR Absence Days`, the four revenue shares, `PR Other Pay`,
    `PR Rejected Amount` and `PR Other Hospital Revenue %`; the word `Confidential` in the footer band;
  - `check_upload_rules` on the converted package returns `[]`.
- [ ] **Step 2: Run** `python -m pytest powerbi_tmdl/hnh_physician_review_report -v`. Expected: FAIL.
- [ ] **Step 3: Implement.** Layout from the spec's sketch. Date slicer: try the relative-date slicer saved as last
  12 calendar months; if the generator or the converter cannot hold it, use the HR report's dates-range slicer with
  its "Last closed month" default and note the choice in the README. The peer range bar is a bar or bullet built
  from `PR Peer Min`, `PR Peer Median`, `PR Peer Max` and `PR Value` with the generator's existing visual types; if
  none reads clearly, leave it out and say so in the task report.
- [ ] **Step 4: Run** the tests and `python powerbi_tmdl/hnh_physician_review_report/build.py`. Expected: PASS, PBIP
  written. **Commit.**

### Task 10: Docs and hand-over

**Files:** create `powerbi_tmdl/hnh_physician_review_report/README.md`; modify `powerbi_tmdl/README.md` (a route
section as the finance report's), `ssas/README.md` if it lists perspectives.

- [ ] **Step 1: README:** what the page shows, the definitions in one table (from the spec), the population rule and
  the other-hospital rule, the gates, how to rebuild and convert, and "access is set on the Report Server folder by
  the BI manager; pay follows `Can See Pay`".
- [ ] **Step 2: Hand the user** the match list of Task 1 Step 5 with the pairs whose names differ on top, and ask
  which pairs to reject. Rejected pairs go into an `excluded_pairs` values list in `dim_staff.sql`'s attach CTE
  (home key, other staff key), with a Pester case; that change is rebuilt at G3's dbt step.
- [ ] **Step 3: Commit.**

### GATE G3: test slot

- [ ] With the user's go-ahead: dbt rebuild of `dim_staff` if pairs were rejected; `deploy.ps1` to
  `HNH_Analytics_Test`; `process.ps1` for `Staff`, `Claim Lines`, `Review Metric`, `Peer Scope`;
  `ssas/scripts/test.ps1` Measures, Security and Performance for the physician review files.
- [ ] All checks pass; the performance case is under 10 seconds. If it is not, stop and report to the user with the
  timing: the spec's fallback (a physician-month table for peer inputs) is the user's decision.
- [ ] Hand check: ten physicians' last increment against their payroll months (read-only SQL), listed for the user.
- [ ] Open the PBIP in Desktop for Report Server against the test slot, export the page to PDF, and send the user
  the PDF with one physician selected.

### GATE G4 and G5

- [ ] G4: with the user's go-ahead, write the upload file with `pbir_to_pbix.py`; the user uploads it to the folder
  they restrict, or names the folder for the upload.
- [ ] G5: with the user's go-ahead, promote to production `HNH_Analytics` as the finance report's README describes,
  and repoint the report.
