# HR dashboard: executive story, KPI management, guide and data quality

Date: 2026-11-02. Status: for the user's review. Builder check done; user answers of 2026-11-02 (targets, turnover basis, launch users) folded in. Page structure and landing page approved in conversation, from the mockup in `.superpowers/brainstorm/30962-1793615280/content/page-map.html`.

## Intent

The HR team and executives have no single HR report. The workforce data is already in the model (`Workforce` perspective of `HNH_Analytics`, Phase 4) and a few workforce KPIs live in the Balanced Scorecard, but nothing tells the HR story, nothing lets HR manage its own KPIs against targets, and the data issues that HR must fix in Fusion and Oasis are only visible as dbt warnings the HR team never sees.

The user asked for:

- a **comprehensive HR dashboard covering everything HR in the model** ("include everything in the model in there");
- a **landing page**;
- a **story-telling executive summary** for senior management;
- **detail pages for HR staff** to manage the KPIs;
- **targets and thresholds as placeholders**, for the HR team to decide later;
- a **user guide page** with metric and KPI definitions;
- a **data quality page** for HR data issues (duplicate codes, people missing from one of the systems, etc.);
- **the same branding as the BSC report** (chosen over Press Ganey's).

## Goals

1. Every HR fact and measure in the model is reachable from the report: headcount and FTE, composition, movements and turnover, payroll and overtime, absence and leave, recruitment, productivity, and the workforce KPIs that the BSC already has.
2. An executive can open Home or Executive story and understand the month in under a minute without touching a filter.
3. The HR team can see every HR KPI by hospital against its target and threshold. Until HR sets real targets, each KPI is scored against a clearly marked placeholder; a KPI with no target row at all shows **No target yet** and is not scored.
4. HR decides targets and thresholds later **without a report or model rebuild**: they are rows in ClickHouse config tables, like the BSC.
5. The data quality page lists each known HR data issue with its count per hospital, the affected records, which system it must be fixed in, and who owns the fix. When the issue is fixed at source, it drops off after the next nightly build.
6. A user guide page defines every metric and KPI: meaning, formula in words, source, grain, target and threshold, and caveats.
7. It ships to Power BI Report Server by the existing route (`powerbi_tmdl/README.md`).

## Non-goals

- No new HR source data. Attendance, rosters, timesheets, training, performance and talent stay out: there is no source (Phase 4 decision W3; the Fusion talent tables are empty). The four manual BSC learning KPIs (`LRN_STAFF_SATISFACTION`, `LRN_TRAINING_COVERAGE`, `LRN_MANDATORY_TRAINING`, `LRN_COST_PER_LEARNER`) stay in the BSC only.
- No change to the BSC report, its measures or its `map_bsc_*` tables.
- No editing of HR data from the report; it only reports and points to where a fix is made.
- No deploy, SSAS processing, ClickHouse write or report upload without the user's go-ahead each time (CLAUDE.md).
- No settings web page for HR targets in this project (see "Targets and thresholds").

## Anti-goals (a failure even if it works)

- A workforce number that differs from the same measure in the BSC or the `Workforce` perspective for the same selection. Turnover, Saudization, vacancy rate, time to fill and the other shared KPIs must be the same measure, not a copy.
- A placeholder target presented as agreed. Every placeholder is labelled as one wherever a target shows (see "Targets and thresholds").
- A status told by colour alone (BSC rule: colour + shape + word).
- A row-level-security leak: pay amounts, leave liability, productivity and anything else behind `Can See Pay` stay hidden from users without it; a one-hospital user sees only that hospital, including on the data quality page.
- Employee names visible to someone who cannot see them in the model today (see "Security").
- A page Report Server refuses (`check_upload_rules` must stay `[]`).

## Users

At launch (user, 2026-11-02): **`HRM_CORP` and the `EXE_*` users**; hospital HR users are added later by the user. From `bi_users.csv`:

| Login | Hospitals | Pay | PII |
|---|---|---|---|
| `HNHANALYTICSSRV\HRM_CORP` (Human Resources – Corporate) | all (`is_admin` 1) | yes | no |
| `HNHANALYTICSSRV\EXE_CORP` (Operations Executive – Corporate) | all (`is_admin` 1) | **no** | yes |
| `EXE_RBW`, `EXE_KMS`, `EXE_JZN`, `EXE_UNZ`, `EXE_MDN`, `EXE_ABH`, `EXE_GRN`, `EXE_MHL` | one hospital each (1–8) | **no** | yes |

- **Executives:** open Home and Executive story monthly. They want the headline, what changed, and where it is off target. They do not filter much. **None of them has pay access today**, so payroll cost, staff cost per FTE, overtime, leave and the `Staff Productivity` figures are hidden from them, and the story's Cost block shows the "requires pay access" note. Giving them pay access is a `bi_users.csv` change (a server change, the user's call; see "Open").
- **HR corporate (`HRM_CORP`):** uses the KPI scorecard and detail pages to manage KPIs, drills to department, job, grade and person, works the data quality list, sees pay and Fusion names, and sees the Head Office data quality records.
- **Hospital HR users (later):** the same pages for their hospital. Nothing in the design depends on who they are; adding them is a `bi_users.csv` row each.
- **BI manager:** owns the config tables (memory: BI manager owns config) and enters the targets HR decides.

Security tests use `HRM_CORP` (all hospitals, pay) and `EXE_ABH` (one hospital, no pay), the accounts `ssas/tests/security.json` already uses for those cases.

## Pages

Page frame, size and style are the BSC report's (see "Branding"). Header title "Workforce" / "Hayat Healthcare". Header tabs: **Home, Story, Scorecard, Details, Data quality, Guide**. The six detail pages sit under one "Details" tab. Report Server allows no bookmarks or visual groups, so there is no dropdown menu: the Details tab opens Headcount & mix, and every detail page shows a second row of sub-tabs (the six detail pages) in its filter bar.

The filter bar on every page: Hospital (branch) and Month (default: the last closed month), plus "How to use" and "Definitions" buttons that open the Guide. Detail pages add filters that fit them (department, job, grade, nationality, worker type).

1. **Home (landing page).** As in the mockup:
   - a summary sentence written by a measure;
   - eight headline KPI tiles (Headcount, Turnover, Saudization, Overtime share, Sick leave rate, Vacancy rate, Time to fill, Staff cost per FTE), each with actual, target (with its placeholder mark), and status chip;
   - six area cards with one figure each, linking to the detail pages;
   - a data quality strip: open issue count, the two largest issues, a link to the Data quality page.
2. **Executive story.** Read top to bottom as a briefing in six blocks, in this order: **Size** (headcount and FTE trend), **Flow** (hires vs leavers, turnover), **Cost** (payroll cost, overtime share), **Absence** (sick leave rate, leave liability), **Saudization**, **Hiring** (open vacancies, time to fill). Each block has a sentence written by a measure (what the number is, the change vs the previous month and vs the same month last year, whether it meets target, and the hospital that contributes most to the change), one chart and one KPI tile. Pay-based blocks show a "requires pay access" note instead of figures for users without `Can See Pay`.
3. **KPI scorecard.** One row per HR KPI (catalogue below): status, name, actual, target, threshold, variance, 12-month trend. A matrix version shows KPI × hospital with status for the HR director's comparison. Clicking a KPI drills through to KPI detail.
4. **Detail pages** (HR team):
   - **Headcount & mix:** headcount and FTE trend; by hospital, HR department, job, grade, position, location; by nationality (Saudi / non-Saudi), gender, age band, tenure band, worker type, full/part time; contingent workers shown separately.
   - **Movements & turnover:** hires, leavers, voluntary and involuntary, rehires, transfers between hospitals, promotions and other changes (job, grade, position, location); turnover and voluntary turnover trend; leavers by action reason and by tenure band; new-hire leavers (left within 12 months).
   - **Payroll & overtime** (`Can See Pay`): payroll cost, gross pay, overtime amount and share, cost per FTE; by pay category, department, job; Oasis vs Fusion source and open vs closed payroll shown so a reader knows when a month is not final.
   - **Absence & leave:** sick days and sick leave rate, absence days by category and type, by department; leave balance days and leave liability. The whole `Leave Balances` table is behind `Can See Pay` in `HNH Readers`, so both leave figures need pay access; the role is not changed (my call: no security change in this project).
   - **Recruitment:** requisitions approved and filled, openings, vacancy rate against budgeted FTE, time to fill, by hospital. Not by department: `Requisitions` has no department and budgeted FTE is per hospital and year (my call: no new source data).
   - **Productivity** (`Can See Pay`): doctors and nurses: visits per FTE, revenue per payroll SAR, payroll cost per visit; revenue per FTE, revenue per doctor, staff to bed, clinical to doctor.
5. **Data quality.** See its section.
6. **User guide.** Two parts: "How to use" (navigation, filters, what closed month means, status rules, who to contact) and "Definitions": a table of every metric and KPI, filterable by area, with name, definition, formula in words, source system, grain, direction, target, threshold, caveats. The definitions come from a model table (see "Model changes") so the guide and the KPI detail page always agree.
7. **Hidden drill-through pages:**
   - **KPI detail:** definition, current value, target and threshold bands, 24-month trend against target, by hospital, and the breakdown that explains it.
   - **Employee list:** the people behind a number (worker number, name, hospital, department, job, grade, hire date, status), for users allowed to see names (see "Security"). The `Employee` table has no branch relationship or row filter, so the list must be filtered through a fact (`Headcount` for the month, or `Worker Movements` for movers), never shown from `Employee` alone.

## KPI catalogue (first draft, the HR team confirms)

Each KPI has a code, direction (higher / lower is better) and value format. Those marked **BSC** already exist as BSC measures and must be reused, not rebuilt.

| Area | KPI | Basis |
|---|---|---|
| Size | Headcount, FTE, Average headcount | existing `Workforce\Headcount` measures |
| Size | Contingent share % | new: contingent heads ÷ all heads |
| Mix | Saudization % | **BSC** `LRN_SAUDIZATION` / `Saudisation Rate %` |
| Mix | Female share % | new |
| Flow | Turnover % | **BSC** `LRN_TURNOVER`, the headline turnover everywhere (user, 2026-11-02): Oasis resignations for hospitals 1–5, Fusion voluntary leavers for 6–8, over `BSC Average Headcount` |
| Flow | New-hire turnover % (leavers within 12 months of hire ÷ hires in the prior 12 months) | new |
| Flow | Hires, Leavers in Fusion, Voluntary leaver rate in Fusion | existing (`Hires`, `Leavers`, `Voluntary Turnover Rate %`), `metric` rows, not scored, always labelled "in Fusion" with a guide note that they do not reconcile with Turnover % |
| Cost | Staff cost per FTE (= `Payroll Cost per FTE`, needs pay access) | existing, scored KPI (user, 2026-11-02) |
| Cost | Payroll cost, Overtime share % | existing |
| Absence | Sick leave rate %, Sick days | existing |
| Leave | Leave liability, Average leave balance (days) | existing / new average |
| Hiring | Vacancy rate %, Time to fill (days) | **BSC** KPIs 47, 48 |
| Productivity | Revenue per FTE, Staff to bed, Clinical to doctor, Revenue per doctor | **BSC** KPIs 44, 45, 68, 55 |
| Productivity | Visits per FTE, Revenue per payroll SAR | existing |

The builder may add a KPI only where the model has the data; any new KPI goes through the HR team's confirmation listed under "Open with the HR team".

## Targets and thresholds (placeholders)

Same pattern as the BSC (`docs/bsc_config.md`): append-only change-log tables in ClickHouse `default`, the newest row per key wins, every row ends with `changed_at`, `changed_by`, `change_note`, `is_deleted`. Read through `staging/reference/` like the `map_bsc_*` tables.

- **`map_hr_kpi`** (key `kpi_code`): `kind` (`kpi` = has a target and status; `metric` = defined in the guide, not scored), name, short label, area, definition, formula in words, source system, grain, caveats, direction (`higher`, `lower`, `ceiling`, `on_target`, as in `map_bsc_kpi`), value format, display order, `bsc_kpi_code` (set when the KPI is a BSC KPI), `measure_name` (the SSAS measure), `target_source` (`fixed`, `bsc`, `none`), `needs_pay`, `is_home_tile`, `status` (`active`, `parked`). This one table feeds both the scorecard and the Guide's definitions, so every metric on the detail pages (gross pay, rehires, absence days by type, …) has a `metric` row (my call).
- **`map_hr_target`** (key `kpi_code`, `branch_id`, `year`, `month`; `branch_id` 0 = every branch, the hospitals and Head Office (from 2026-11-03, below), `month` 0 = the whole year, the more specific row wins, as in `map_bsc_target`): `target_value`, `watch_value`, `scale_with_months` (1 when an annual target is pro-rated by the months selected, e.g. turnover), `source_basis`.

**Period.** As in the BSC (decision 6, 2026-10-20), a KPI's actual follows the filter context: the selected month by default, year to date or any range through the existing Time Calculation table. Snapshot KPIs (headcount, Saudization, vacancy rate, leave balance) take the last month in the selection; flow KPIs (turnover, overtime share, sick leave rate) cover the selection, and their annual targets are pro-rated with `scale_with_months`. KPI detail shows the monthly series and the 12-month rolling value. Labels name the period ("Turnover, Oct 2026"), not "monthly" (my call).

Status rule: **On track** when the actual meets the target in the KPI's direction; **Watch** when it misses the target but is no worse than `watch_value`; **At risk** beyond `watch_value`. For `on_target`, the distance from target is compared with the distance from `watch_value` to target; `ceiling` reads like `lower`. **No target yet** when there is no target row (grey, not scored); **No data** when the actual is blank. Shapes and colours are the BSC's (circle / diamond / square, `#0E9F8E` / `#EF8B00` / `#DB280A`, grey `#9AA7B5`).

**Placeholder targets at launch (user, 2026-11-02: "add placeholder targets").** My reading of the user's answer, to be confirmed on review:

- **Revenue per FTE** keeps the BSC target (the budget, `BSC Target Revenue per FTE`), so its HR status equals its BSC status.
- **Staff cost per FTE** is a scored HR KPI. The model has no staff-cost budget, so it gets a placeholder like the rest.
- **Every other KPI gets a placeholder target and watch value**, including those the BSC targets with a "hold" (turnover 6 %, staff to bed 4.0): the HR team sets its own.

How placeholders are made (my call): one row per KPI for all hospitals (`branch_id` 0), year 2026 and 2027, `source_basis = 'Placeholder – HR to confirm'`. The value holds the current level: the KPI's network value for January–September 2026, rounded; the watch value is 10 % worse in the KPI's direction. The seed SQL lists the numbers it inserted, in `docs/hr_config.md`.

Placeholders are scored like real targets, but wherever a target shows (tiles, scorecard, KPI detail, story sentences) it carries a "placeholder" mark (a small outlined "P" chip and the word in the tooltip), driven by `source_basis`. When HR inserts a real target row, the mark disappears.

HR decides targets; the BI manager enters them by SQL insert, with documented examples, in a new `docs/hr_config.md`. A settings page is a later project (non-goal).

## Data quality page

Each issue is one row in a catalogue, with its records behind it. Built nightly in dbt, so a fix at source disappears on the next build.

**Issue list (start; the builder adds others that show in the data):**

| Issue | Fix in | Today |
|---|---|---|
| Fusion employee with no Oasis staff record (same hospital, worker number) | Oasis or Fusion | 39 (`warn_employees_without_staff_link`) |
| Active Oasis staff with no Fusion employee | Fusion | new check |
| One Oasis staff record linked to several Fusion employees | Oasis | 3 (`warn_staff_linked_to_many_employees`) |
| Oasis staff IDs that differ only in format (duplicate codes) | Oasis | `warn_staff_id_collisions` |
| Duplicate worker numbers or duplicate people in Fusion | Fusion | new check |
| FTE of 0 replaced by 1 | Fusion | 1,626 (`warn_fte_out_of_range`) |
| Duplicate leave balance entries in a period | Fusion | 36 (`assert_leave_balance_single_entry_per_period`) |
| Overlapping absences | Fusion | 1 (`assert_absence_daily_no_overlap`) |
| Absences with zero days | Fusion | `warn_absence_zero_days` |
| Annual leave balance with no salary (no liability) | Fusion | `warn_leave_without_salary` |
| Pay codes not mapped to a pay category | BI (`map_pay_category`) | `warn_unmapped_pay_codes` |
| Branch 8 payroll copies Branch 7 (Jan–Apr 2026) | Fusion payroll | `warn_branch8_payroll_copies_branch7` |
| Hospital-months with no payroll (e.g. Branch 8, May–Jul 2026) | Fusion payroll | new check |
| Leave balances that stop (Branch 1 after 2026-08) | Fusion | new check |
| Terminated employees still holding a current leave balance | Fusion | reconciliation §5 |
| Future-dated movements and absences | Fusion | reconciliation §5 |
| Contractors with no hospital (branch 0) | Fusion | 21 |
| Legal employer of the latest period of service differs from the assignment's legal employer | Fusion | 3 (SSAS spec P15) |
| Active employees missing gender, nationality, birth date, department, job or grade | Fusion | new check |

**Catalogue table:** the issue list, owner, severity, "fix in" and how-to-fix text live in a third change-log table, `default.map_hr_dq_issue`, so they change without a rebuild (my call, plan 2026-11-02).

**Page layout:** summary tiles (open issues, records affected, by "fix in" system); an issue table (issue, severity, fix in, owner, count by hospital; no trend vs last build, which needs a history table: a later addition, my call); a records table for the selected issue (worker number, Oasis staff ID, hospital, field, value found, and the name where the viewer may see names); a note per issue on how to fix it, from the catalogue.

**Owner and severity per issue:** columns in the catalogue, filled with placeholders ("HR" / "BI", "Medium") for the HR team to confirm, like targets.

**What a record carries:** issue, hospital, worker number and/or Oasis staff ID, the field and the value found. **No names and no amounts** in the data quality fact (my call). Names show only by joining to the model's existing name columns under their existing rules, and a payroll or leave issue shows a count of records or months, never SAR, so the page needs no pay access.

**Records with no hospital** (the branch 0 contractors, checks on unbranched Fusion tables such as work measures) get the Head Office branch key (100), which only admins see today (`assert_sec_admins_see_head_office`). The hospital HR teams do not see them; the BI manager does (my call: the conservative choice; widening it is a later security change).

**Freshness:** a fix at source shows after the next dbt build of these models and the SSAS refresh. Dagster's nightly dbt jobs use their own selectors, not `tag:hnh` (memory 2026-11-01); the plan must give the user the selector to add, since the Dagster job lives on the dbt host, not in this repo.

Where a `warn_*` test already holds the logic, the data quality model and the test must not drift: the builder either has the test read the data quality model or shares the SQL in a macro.

## Model changes

**dbt (`hnh_dwh/models/hnh/`):**
- staging for `map_hr_kpi` and `map_hr_target` (`staging/reference/`), with tests like `stg_ref__bsc_*`;
- `marts/hr/` (or under `marts/workforce/`): `dim_hr_kpi` (current KPI list), `fact_hr_target` (resolved targets), `dim_hr_dq_issue` (catalogue) and `fact_hr_dq_record` (one row per issue × record, with branch key);
- `ssas_*` views for the new tables;
- CLAUDE.md title-case rule applies: names and source text in the new marts wrapped in `hnh_title`, repo labels (issue names, KPI names in the config) excluded in `assert_mart_text_title_case.sql`.

**SSAS (`ssas/tools/model_config.py`, `_Measures.tmdl`):**
- tables `HR KPI`, `HR Targets`, `HR Data Issues`, `HR Data Issue Records`, related to Branch and Date where they have them;
- measures in a `HR Dashboard\…` folder: `HR KPI Actual` (switch over the KPI code to the existing measures), `HR KPI Target`, `HR KPI Watch`, `HR KPI Status`, `HR KPI Status Label`, the new KPIs from the catalogue, the story sentences (`HR Story Home`, `HR Story Size`, … one per block), the data quality counts;
- a new perspective `HR Dashboard` (the `Workforce` perspective plus the new tables, the BSC workforce measures and `Branch`/`Date`);
- measure tests in `ssas/tests/measures/hr_dashboard.json`.
- All measures live in the model, none in the report (README rule).

## Security

- Branch row security (`User Access[Branch Key]`) applies to every new table that has a branch, including data quality records.
- Pay pages and blocks follow the existing `Can See Pay` rule; a user without it sees the page with a "requires pay access" message, not an error.
- **Employee names:** Fusion names are in `Employee Details`, which requires `Can See Pay`; Oasis `Staff Name` is visible to every reader (P15). The report adds no new exposure: the Employee list shows Fusion names only to pay users and otherwise worker number and Oasis staff ID; the data quality page shows the Oasis staff name only where the model shows it today (my call).
- Security tests as a non-admin `HNH_BI_Users` member (an SSAS admin bypasses row filters).

## Branding and build

- BSC branding exactly: `powerbi_tmdl/hnh_bsc_report/theme/hnh_bsc_theme.json`, the frame geometry and colours in `frame.py` (1920 × 1080, navy header 0–84 px with logo and two-line title, white filter bar 84–162 px, content area 30,186,1860,870, white panels with 1 px `#DCE5EF` border and radius 12, Segoe UI), status chips and shapes as in the BSC.
- Native Power BI visuals only; no new custom visual (my call: the BSC visual is built for the BSC payload, and native cards, line and bar charts, matrices with icon formatting cover these pages; a status shape is a conditional-format icon plus the status word).
- A Python generator like the BSC's, in `powerbi_tmdl/hnh_hr_report/`, reusing the BSC generator's modules (`frame`, `pbir`, `pbix`, `fields`, `pbir_check`) rather than copying them. `frame.py` hard-codes the BSC title and tabs, so it needs parameters; the BSC report must build byte-identical afterwards. If reuse needs a refactor into a shared package, that is the builder's call. Field checks against the `HR Dashboard` perspective, `pbir_check.py` and `check_upload_rules` are the gate.
- Live connection to `HNH_Analytics_Test` with perspective `HR Dashboard` until the production deploy; switch with `--database`.
- Upload route as `powerbi_tmdl/README.md`: `pbir_to_pbix.py`, check, upload to `http://hnhanalyticssrv/reports`, test as a non-admin.

## Constraints

- Report Server (May 2026): no bookmarks, no visual groups, no AppSource visuals, no report-level measures, legacy package only.
- The test slot `HNH_Analytics_Test` may hold other unreleased work (Press Ganey, BSC score changes). The HR changes deploy into it alongside, never replacing it.
- ClickHouse writes (creating `map_hr_*`, seeding the KPI list) and every deploy or process need the user's go-ahead at the time.
- Fusion headcount starts 2026-01; movements from 2022; payroll mixes Oasis and Fusion by `map_payroll_cutover`; Al-Rabwa, Khamis and Madinah payroll is still in Oasis (O-P4-2). Year-on-year headcount comparisons are blank before 2027 and the story sentence must say "no prior-year data" rather than show 0.
- Arabic names arrive garbled through the ODBC driver (code page 1252); the report shows English names.

## Decisions after review

- **2026-11-03, Head Office everywhere (user: "keep head office everywhere").** Head Office (branch 100) is included in the slicer (now labelled Branch: the eight hospitals and Head Office), on every page, in every KPI (the scorecard-shared ones too: turnover, Saudization, vacancy, time to fill, staff to bed, clinical to doctor, revenue per FTE and per doctor), in targets and placeholders, the story, productivity and data quality. This supersedes the build's ruling R14 (HR KPI actual and target over hospitals only) and final review finding I1 (hospitals-only page filters). The HR measures carry no branch restriction; the report keeps out only the Branch dimension's synthetic Group member (0). `map_hr_target` `branch_id` 0 now applies to Head Office as well, and `branch_id` 100 sets Head Office's own target. The BSC report is not changed and stays hospitals only, so for the shared KPIs the HR network figure may differ from the BSC's; today it does not, because the facts behind those measures (scorecard workforce, GL, requisitions, beds) and staff productivity hold no Head Office rows: Head Office reads No data for them (`powerbi_tmdl/hnh_hr_report/README.md`, "Head Office", has the per-KPI table). Row security is unchanged: Head Office is visible only to users whose access grants branch 100 (administrators).

## Open (not blockers)

With the HR team:
- the real target and watch value per KPI and hospital, replacing the placeholders;
- the KPI list itself (add, drop, or park);
- data quality owner and severity per issue.

With the user:
- whether the `EXE_*` users get pay access (`can_see_pay` in `bi_users.csv`), without which the executive story has no cost figures;
- the hospital HR users, added to `bi_users.csv` later.

## Left to the builder

- Exact visual choice and placement within the BSC frame on each detail page.
- The wording of the story sentences, within the rule above.
- Whether data quality models live under `marts/hr/` or `marts/workforce/`.
- The order of work, provided the model changes are deployed to the test slot before the report is built against them.
