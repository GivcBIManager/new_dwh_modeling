# HNH Balanced Scorecard Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The top-management scorecard report on Power BI Report Server: landing, four pillar boards, owner view and hospital comparison (custom visual), a KPI Detail drill-through page and seven family detail pages (native visuals), live on the `Balanced Scorecard` perspective of `HNH_Analytics`.

**Architecture:** The user makes one small template `.pbix` in Power BI Desktop for Report Server (live connection, the HNH visual imported, the brand theme applied, one sample of each native visual type). A tested Python generator in `powerbi_tmdl/hnh_bsc_report/` reads the template, clones and rebinds the samples into every page defined in `pages.py`, and writes the report's `Report/Layout` (legacy format, UTF-16 without BOM, the form the handover's own report used). SSAS gains `BSC Numerator` / `BSC Denominator`, three small detail helpers, and the domain measures and tables the detail pages need in the perspective.

**Amendment 2026-10-25 (user decision): the generator writes a PBIP project, no template.** Task 10 adds a PBIR writer that turns the same `PAGES` (Tasks 5–6) into `powerbi_tmdl/hnh_bsc_report/HNH Balanced Scorecard.pbip` + `HNH Balanced Scorecard.Report/` (definition.pbir with a live connection to the perspective, `definition/` pages and visuals, the theme and the HNH visual as resources). The user opens it in Power BI Desktop (2.158), checks it, saves it as `.pbix`, opens and saves that in Desktop for Report Server (the handover's route, Notes/05), runs `check_upload_rules`, and uploads. Task 1 Step 5 (template) and Task 7 Step 1 (template build) are replaced by Task 10; the legacy Layout writer (`layout.py`, `build.py`) stays as the documented fallback until a Desktop-for-Report-Server-saved file passes the upload checks, then is removed. `pbir.py` imports its shared helpers from `layout.py` (`lit`, `field_expr`, `filter_json`, `top_n_json`, `stable_id`, with `source_expr`, `aliases`, `DIRECTION`), and `pbir.py` and `build.py` each hold a copy of `_check_unique` and `SERVER`: removing the legacy writer first moves those into a shared module (for example `common.py`) that `pbir.py` imports, then deletes `layout.py`, `pbix.py`'s template code and `build.py --format pbix`.

**Tech Stack:** Python 3.12 (stdlib `zipfile`, `json`), pytest; SSAS TMDL with the existing generators (`ssas/tools/gen_bsc_kpi_lists.py`, `measure_guards.py`, `sync_perspectives.py`, `generate.py`); Power BI Desktop for Report Server May 2026 (2.154) and Report Server 1.26.9637 (the user's steps).

**Spec:** `docs/superpowers/specs/2026-10-20-hnh-bsc-ssas-perspective-analysis.md` sections 6.3–6.5, 7 (phase 4), 9; handover upload rules `powerbi_tmdl/Hayat BSC Deliverable/Notes/05 Report Server.md`; visual field wells `powerbi_tmdl/hnh_bsc_visual/README.md`.

## Global Constraints

- The uploaded file is a `.pbix` last saved by **Desktop for Report Server**, containing `Report/Layout` (UTF-16 LE, starts with `{`, no byte-order mark) and **no** `Report/definition` folder (Notes/05).
- Live connection to server `HNHANALYTICSSRV\REPORTSERVERDB`, perspective `Balanced Scorecard`; database `HNH_Analytics_Test` while testing, `HNH_Analytics` for release (the generator switches it).
- Security is the model's `HNH Readers` rules; access to the report folder is managed by the user on the report server (D4). No report-level security.
- Pages are 1920 × 1080, theme colours and Segoe UI from the brand: navy `#0A1E32`, blue `#13ACE3`, blue-dark `#1478BE`, sky `#32A4E5`, on track `#0E9F8E`, watch `#EF8B00`, at risk `#DB280A`, no data `#9AA7B5`, surface `#F4F7FB`.
- Default period (user decision 2026-10-22): **year to date to today** — relative date slicer "this calendar year" on `'Date'[Date]`; the measures cap at today.
- Scorecard pages bind the visual as the visual's README says: landing and comparison `[BSC Visual Payload Scores]`, pillar boards and owner view `[BSC Visual Payload]`; comparison adds `Branch[Branch Name]` and a visual filter `Branch[Is Hospital] = "Yes"`.
- Every server-changing step is the user's (CLAUDE.md): SSAS deploys, the speed run (`run_perf.ps1` wrapper), uploading the report, folder security. The folder is chosen by the user at upload.
- KPI Detail shows no Oasis/Fusion data-source flag and no "entered by" for manual values: the model has no such columns (`BSC KPI` has `Value Source` measure/manual only; `BSC Manual Values` has the note but not the author). Adding them is a DWH change outside this plan.
- Labels written by this repo are not title-cased; KPI names and other source text come from the model as they are.

## Review Focus

1. A user who sees one hospital (RLS): every page renders with that hospital only; "Corporate" never shows data the user cannot see; the comparison page shows one column (Task 9 non-admin check; Task 4 test that no visual uses `ALL`-style "show items with no data" on Branch).
2. Drill-through from a parked or "No data yet" KPI: KPI Detail shows the definition and "No data yet", the family button still works, no visual errors (Task 5 test: the detail page has no visual-level filter that would hide a KPI with blank actual; Task 9 check).
3. A manual KPI on KPI Detail: numerator and denominator come from the entered values and the note is shown; a measure KPI shows no empty note box (Task 2 checks; Task 5 conditional visibility test).
4. The family button for a KPI whose family page has no data for the selected hospital × month: the page opens with blanks, not errors (Task 6 test that every family page's drill-through fields are exactly `Branch[Branch Name]` and `'Date'[Year Month Name]` and that only they arrive: "keep all filters" off on the family pages, which filter `Branch[Is Hospital] = "Yes"` themselves. KPI detail's `'BSC KPI'` drill filter, passed on, would make every domain measure's guard return "… can't be analysed by "BSC KPI"").
5. The generated file opened in Desktop for Report Server and uploaded: the Notes/05 zip checks pass before the user ever opens it (Task 1 tests on the generator's own output).

---

### Task 1: Template contract and pbix reader/writer

**Files:**
- Create: `powerbi_tmdl/hnh_bsc_report/pbix.py`, `powerbi_tmdl/hnh_bsc_report/README.md` (section "Make the template"), `powerbi_tmdl/hnh_bsc_report/tests/test_pbix.py`, `powerbi_tmdl/hnh_bsc_report/tests/conftest.py` (builds a small synthetic pbix fixture in `tmp_path`)
- Modify: `.gitignore` (add `!/powerbi_tmdl/hnh_bsc_report/`; keep `dist/` ignored inside it)

**Interfaces:**
- Produces: `read_pbix(path) -> Pbix` with `Pbix.parts: dict[str, bytes]`, `Pbix.layout: dict` (decoded `Report/Layout`), `Pbix.connection: dict` (decoded `Connections`); `write_pbix(pbix, path)` that encodes the layout as UTF-16 LE without BOM and keeps every other part byte for byte; `check_upload_rules(path) -> list[str]` (empty = passes Notes/05: `Report/Layout` present, no `Report/definition/` entry, UTF-16 starting with `{`, no BOM); `set_database(pbix, name)` rewriting the database / initial catalog in `Connections`; `samples(pbix) -> dict[str, dict]` mapping each `sample:<key>` visual title on the template page `Samples` to its visual container.
- Template contract (README): one page `Samples` with visuals titled `sample:card`, `sample:multiRowCard`, `sample:table`, `sample:matrix`, `sample:barChart` (clustered bar), `sample:lineChart`, `sample:slicerDropdown`, `sample:slicerRelativeDate` (relative date on `'Date'[Date]`, "this calendar year"), `sample:textbox`, `sample:buttonNavigate` (page navigation), `sample:buttonDrill` (drill-through action with a conditional destination from a measure), `sample:hnhVisual` (the HNH Balanced Scorecard visual); the brand theme imported (`theme/hnh_bsc_theme.json`, written in this task); one drill-through page `Drill sample` with drill field `'BSC KPI'[KPI Code]` and "keep all filters" on; saved by Desktop for Report Server as `powerbi_tmdl/hnh_bsc_report/template/hnh_bsc_template.pbix` connected to `HNH_Analytics_Test`.

- [ ] **Step 1: Write the failing tests** (on the synthetic fixture): round trip keeps every non-layout part identical and the layout equal; the written layout starts with bytes `7B 00` and has no `FF FE`; `check_upload_rules` returns `[]` for a good file and names each rule for files with a `Report/definition/x`, a BOM, or no layout; `set_database` changes only the catalog; `samples` returns the keys present and raises listing the missing keys of the contract.
- [ ] **Step 2: Run** `python -m pytest powerbi_tmdl/hnh_bsc_report/tests -q`. Expected: FAIL (module missing).
- [ ] **Step 3: Implement** `pbix.py`; write `theme/hnh_bsc_theme.json` (Power BI report theme with the Global Constraints colours as `dataColors`/`good`/`neutral`/`bad`, `textClasses` in Segoe UI) and the README's template steps.
- [ ] **Step 4: Run** the tests. Expected: PASS. Commit.
- [ ] **Step 5: User step.** The user makes the template per the README and puts it at `template/hnh_bsc_template.pbix`. Then run `python -c "from pbix import *; print(sorted(samples(read_pbix('template/hnh_bsc_template.pbix'))))"` from that folder. Expected: all 12 keys. Commit the template (it holds no data).

### Task 2: Numerator and denominator measures

**Files:**
- Create: `ssas/tools/bsc_kpi_parts.py`
- Modify: `ssas/tools/gen_bsc_kpi_lists.py`, `ssas/HNH_Analytics/tables/_Measures.tmdl` (generated), `ssas/tests/measures/balanced_scorecard.json`, `ssas/tools/test_gen_bsc_kpi_lists.py`, `ssas/README.md`

**Interfaces:**
- Produces: `[BSC Numerator]` and `[BSC Denominator]` for the KPI in context, in the same filter context as `[BSC Actual]` (dates capped at today, hospitals only, parked → blank, manual KPIs → the summed `'BSC Manual Values'` numerator / denominator, a denominator of 0 meaning outpatient + ER visits as in `BSC Manual Value`); folder `Balanced Scorecard\Scoring`.
- `bsc_kpi_parts.PARTS: dict[str, tuple[str, str, str]]` = KPI code → (numerator DAX, denominator DAX, kind), kind ∈ `ratio` (actual = num ÷ den), `growth` (actual = num ÷ den − 1), `value` (actual = num, den blank). Each entry is read from that KPI measure's own body; a KPI whose actual is none of the three gets no entry and is listed in `ssas/README.md`.

- [ ] **Step 1: Write the checks** (DAX-only, `select 0` = mismatching KPI rows): `BSC Numerator and BSC Denominator rebuild BSC Actual, every KPI, branch 6, 2026-08` and `…, all hospitals, 2026` (per kind, within 1e-9 relative); `BSC Numerator, EBITDA margin, branch 6, 2026-08` against `bsc.vw_financial.ebitda_actual` and `BSC Denominator` against `net_revenue_actual`; `BSC Numerator, manual PREMs, branch 6, 2026-07` against `gold.ssas_fact_bsc_manual_value`. Pytest: the generator writes both measures and `test_bsc_kpi_lists_agree` covers their lists.
- [ ] **Step 2: Run** `python -m pytest ssas/tools -q`. Expected: FAIL (measures missing).
- [ ] **Step 3: Implement** `PARTS`, the generator change, regenerate (`gen_bsc_kpi_lists.py`, `measure_guards.py`, `sync_perspectives.py`).
- [ ] **Step 4: Prove on HNH_Analytics_Test** read-only (DEFINE every dependant): both checks return 0. Then pytest, BPA, `--check`s, Pester green. Commit.

### Task 3: Perspective and detail helpers

**Files:**
- Modify: `ssas/tools/model_config.py` (`PERSPECTIVE_MEASURE_DOMAINS["Balanced Scorecard"]`, `PERSPECTIVE_EXTRA["Balanced Scorecard"]`), `ssas/HNH_Analytics/perspectives/Balanced Scorecard.tmdl` (regenerated), `_Measures.tmdl`, `balanced_scorecard.json`

**Interfaces:**
- Produces: the perspective holds the Revenue Cycle, Claims & Pre-auth, Finance, Patient Flow, Workforce and Patient Experience measures and every table Task 6's pages use (at least `FS Line`, `GL Account`, `Headcount`, `Worker Movements`, `Order Lines`, `Survey Responses`); measures (folder `Balanced Scorecard\Detail`): `[BSC Detail Page]` = the family page display name for `SELECTEDVALUE('BSC KPI'[Detail Page])` (`revenue` → "Revenue detail", `finance` → "Finance detail", `volume` → "Patient volume detail", `beds` → "Beds & clinical detail", `revenue_cycle` → "Revenue cycle detail", `workforce` → "Workforce detail", `experience` → "Patient experience detail"); `[BSC Manual Note]` = the distinct notes of the KPI in context joined with " · " (blank for measure KPIs); `[BSC Target Basis]` = "Fixed target" / "Budget" / "Same period last year" from `'BSC KPI'[Target Source]`.

- [ ] **Step 1: Write the checks** for the three measures (a finance KPI → "Finance detail"; PREMs branch 6 2026-07 note equals the ClickHouse note; a budget KPI → "Budget") and a pytest that the perspective contains the listed tables and the six domains' measures.
- [ ] **Step 2: Run** pytest. Expected: FAIL.
- [ ] **Step 3: Implement**, regenerate (`generate.py --from-contracts` if tables are added, `measure_guards.py`, `sync_perspectives.py`).
- [ ] **Step 4: Run** pytest, BPA, `--check`s, Pester. Expected: green. Commit.

### Task 4: Page model and generator core

**Files:**
- Create: `powerbi_tmdl/hnh_bsc_report/model.py` (dataclasses), `powerbi_tmdl/hnh_bsc_report/layout.py` (rebinding), `powerbi_tmdl/hnh_bsc_report/fields.py` (reads the perspective and table TMDL through `ssas/tools/hnh_tmdl.py`), `powerbi_tmdl/hnh_bsc_report/build.py` (CLI), tests `test_layout.py`, `test_fields.py`

**Interfaces:**
- Consumes: Task 1 `read_pbix`, `write_pbix`, `samples`, `set_database`, `check_upload_rules`.
- Produces: `Field(table: str, name: str, kind: "column" | "measure")` with `col("Branch", "Branch Name")`, `meas("BSC Actual")`; `Visual(sample: str, x, y, w, h, roles: dict[str, list[Field]], title: str | None, filters: list[Filter], top_n: tuple[Field, int] | None, sort: Field | None, props: dict)`; `Page(name: str, display: str, visuals: list[Visual], filters: list[Filter], drill_fields: list[Field] | None, hidden: bool)`; `Filter(field, op: "in" | "eq", values)`; `build(template: Path, pages: list[Page], database: str, out: Path) -> None` (drops the `Samples` and `Drill sample` pages, writes the pages in order, applies slicer sync group `bsc` to every slicer, runs `check_upload_rules` and raises on any problem); `unknown_fields(pages) -> list[str]` (fields not in the `Balanced Scorecard` perspective).
- CLI: `python powerbi_tmdl/hnh_bsc_report/build.py --database HNH_Analytics_Test --out powerbi_tmdl/hnh_bsc_report/dist/HNH Balanced Scorecard.pbix`.

- [ ] **Step 1: Write the failing tests** against the synthetic fixture's samples: rebinding a bar chart to `Department[Department Name]` / `[Revenue]` writes both into the visual's query and projections and nothing of the sample's old fields remains; a top-N filter and a sort are written; a drill-through page gets its fields and "keep all filters"; a page filter `'BSC KPI'[Pillar] = "Financial"` is written; every visual gets a unique name; `unknown_fields` reports a field missing from the perspective; **Review Focus 1:** no generated visual sets "show items with no data" on a Branch field.
- [ ] **Step 2: Run** `python -m pytest powerbi_tmdl/hnh_bsc_report/tests -q`. Expected: FAIL.
- [ ] **Step 3: Implement** `model.py`, `fields.py`, `layout.py`, `build.py`. Rebinding works on the sample's own JSON (the visual container's `config` string: `singleVisual.prototypeQuery` `From`/`Select`, `projections` per role, `objects`), never on hand-written visual JSON.
- [ ] **Step 4: Run** the tests. Expected: PASS. Commit.

### Task 5: Scorecard pages and KPI Detail

**Files:**
- Create: `powerbi_tmdl/hnh_bsc_report/pages.py` (scorecard and KPI Detail parts), `tests/test_pages.py`

**Interfaces:**
- Consumes: Task 4 model; Task 2–3 measures.
- Produces: `PAGES: list[Page]` in this order and these display names: `BSC`, `Financial`, `Customer`, `Internal Process`, `Learning & Growth`, `Owner view`, `Hospital comparison`, `KPI detail` (hidden from navigation, drill-through), then Task 6's family pages.

Every scorecard page: a header row of slicers (`Branch[Branch Name]` dropdown with visual filter `Branch[Is Hospital] = "Yes"`, multi-select with "Select all"; `Branch[BSC Category]`; the relative-date slicer on `'Date'[Date]` defaulting to this calendar year; `'Time Calculation'[Time Calculation]` dropdown), page-navigation buttons to the seven scorecard pages, and the HNH visual filling the rest (mode per page set in its format objects: Overview / Pillar board / Owner view / Hospital comparison; pillar boards add the page filter `'BSC KPI'[Pillar] = "<pillar>"`; the 21 attribute columns and the payload per the Global Constraints).

KPI detail (drill field `'BSC KPI'[KPI Code]`, keep all filters): a multi-row card of `'BSC KPI'[KPI Name]`, `[Definition]`, `[Owner]`, `[Co Owners]`, `[BSC Target Basis]`, `[BSC KPI Weight]`; cards `[BSC Actual]`, `[BSC Target]`, `[BSC Score]`, `[BSC State]`, `[BSC Numerator]`, `[BSC Denominator]`; a line chart of `[BSC Actual]` and `[BSC Target]` by `'Date'[Year Month Name]` (sorted by `'Date'[Year Month]`) over the selected period (year to date by default; the user widens the date slicer for a longer trend); a bar chart of `[BSC Actual]` by `Branch[Branch Name]` (hospitals only) sorted descending; a multi-row card "Manual entry note" of `[BSC Manual Note]` with a not-blank filter, empty for a measure KPI (a card would show "(Blank)"); the drill button "Open detail" whose destination is `[BSC Detail Page]`, enabled when a hospital bar is selected (it drills on the matrix cell, `Branch[Branch Name]` × `'Date'[Year Month Name]`).

- [ ] **Step 1: Write the failing tests:** page names and order; each scorecard page binds the visual roles exactly as the visual README's table (role → field) and the right payload per page; pillar pages carry their pillar filter; comparison carries the Branch role and the Is Hospital filter; KPI detail has the drill field and keep-all-filters; the drill button's destination is `[BSC Detail Page]`; **Review Focus 2:** KPI detail has no visual-level filter on `[BSC Actual]` or `[BSC State]`; **Review Focus 3:** the note card is the only visual using `[BSC Manual Note]` and has the not-blank condition; `unknown_fields(PAGES) == []`.
- [ ] **Step 2–4:** run (FAIL), implement, run (PASS). Commit.

### Task 6: Seven family detail pages

**Files:**
- Modify: `powerbi_tmdl/hnh_bsc_report/pages.py` (family pages), `tests/test_pages.py`

Every family page: drill fields `Branch[Branch Name]` and `'Date'[Year Month Name]`, keep all filters off (only the drill fields arrive; see Review Focus 4), a page filter `Branch[Is Hospital] = "Yes"`, a back button, a title card with the branch and month, and these visuals (top N where given; bars and tables sorted descending by their measure, a table by its ranking measure, which it shows; the income statement matrix keeps the FS lines' order):

| Page | Cards | Charts and tables |
|---|---|---|
| Revenue detail | `[Revenue]`, `[Gross Charges]`, `[Line Discount]`, `[Claimable Revenue]` | bar `[Revenue]` by `Department[Department Name]` top 15; bar `[Revenue]` by `'Product Category'[High Level Department]`; bar `[Revenue]` by `Payer[Category]`; table doctor name × `[Revenue]` top 20 (the doctor dimension related to Charge Lines in `relationships.tmdl`) |
| Finance detail | `[EBITDA]`, `[EBITDA Margin %]`, `[Net Profit]`, `[Budget Variance %]` | matrix `'FS Line'[FS Caption]` > `'FS Line'[FS Line]` × `[IS Actual]`, `[IS Budget]`, `[Budget Variance]`; bar `[GL Movement]` by `'GL Account'[Natural Account Name]` top 15 |
| Patient volume detail | `[OP Visits]`, `[ER Visits]`, `[Admissions]`, `[New Patients]`, `[Returning Patients]` | bar `[OP Visits]` by `Department[Department Name]` top 15; bar `[Census]` by `Payer[Category]`; bar `[Average Wait (min)]` by `Department[Department Name]` top 15 |
| Beds & clinical detail | `[Bed Occupancy %]`, `[ALOS (days)]`, `[Readmission Rate 30d %]`, `[ICU Readmissions 48h]`, `[Bed Turnover]` | bar `[Bed Occupancy %]` by `Bed[Current Ward]`; bar `[ALOS (days)]` by `Department[Department Name]` top 15; table `'Discharge Outcome'[Outcome Group]` × `[Discharges]` |
| Revenue cycle detail | `[Claim Rejection Rate %]`, `[First-pass Rejection Rate %]`, `[Pre-auth Approval Rate %]`, `[Leak Rate %]`, `[Billed Not Submitted]` | bar `[Claims Rejected]` by `'NPHIES Reason'[Reason]` top 15; bar `[Claimed Amount]` by `Payer[Purchaser Name]` top 15; table `'Claim Status'[Submission Status]` × `[Billed Amount]`; bar `[Lost Value]` by `Department[Department Name]` top 15 |
| Workforce detail | `[Headcount]`, `[FTE]`, `[Saudisation Rate %]`, `[Turnover Rate %]`, `[Hires]` | bar `[Headcount]` by `'HR Department'[Department Name]` top 15; bar `[Headcount]` by `Job[Job Name]` top 15; bar `[Headcount]` by `Employee[Nationality]` top 10 |
| Patient experience detail | `[Hospital NPS (5-point)]`, `[Physician NPS (5-point)]`, `[NPS Answers]`, `[Response Rate %]` | bar `[NPS (5-point)]` by `'Survey Question'[Domain En]`; bar `[NPS (5-point)]` by `Department[Department Name]` top 15; table `'Survey Question'[Question En]` × `[% Promoters]`, `[% Passives]`, `[% Detractors]` top 20 by `[NPS Answers]` |

- [ ] **Step 1: Write the failing tests:** the seven display names equal the values `[BSC Detail Page]` returns (Task 3), so every KPI's button lands on a page; **Review Focus 4:** each page's drill fields are exactly the two fields with keep-all-filters off and the hospital page filter; every listed measure and column is bound; `unknown_fields(PAGES) == []`.
- [ ] **Step 2–4:** run (FAIL), implement, run (PASS). Commit.

### Task 7: Build, check and hand-off

**Files:**
- Modify: `powerbi_tmdl/hnh_bsc_report/README.md` (build, open, check, save, upload, switch to production), `ssas/tests/performance.json` (entries: KPI detail for one KPI — the line chart and the hospital bar — and one family page, limits 10 / 5)

- [ ] **Step 1: Build** `python powerbi_tmdl/hnh_bsc_report/build.py --database HNH_Analytics_Test --out "powerbi_tmdl/hnh_bsc_report/dist/HNH Balanced Scorecard.pbix"`. Expected: the file written and `check_upload_rules` empty. Copy it to `C:\HNH\report\`.
- [ ] **Step 2: Suites** pytest (both folders), BPA, `--check`s, Pester. Commit.

### Task 8: Test-slot deploy and speed (user)

- [ ] The user runs `deploy.ps1 -Stage Test` (refreshes the test data and runs every check, including Task 2–3's) and the `run_perf.ps1` wrapper. Expected: no scorecard check fails; the new speed entries within their limits. Failures go back to Tasks 2–3 or 7.

### Task 9: Desktop for Report Server and the report server (user)

- [ ] The user opens `C:\HNH\report\HNH Balanced Scorecard.pbix` in Desktop for Report Server, checks every page as a non-admin top-management login (Review Focus 1–4: one-hospital user, a parked KPI's drill-through, a manual KPI's detail, a family page without data), saves it, uploads it to a test folder and repeats the checks in the browser, including PDF export. Defects go back to Tasks 4–6.
- [ ] After the production SSAS deploy (its own approval, `deploy.ps1 -Stage All`), rebuild with `--database HNH_Analytics`, open and save in Desktop for Report Server, upload to the folder the user chooses. The handover report stays until the switch (spec phase 6).

### Task 10: PBIP writer (amendment 2026-10-25)

**Files:**
- Create: `powerbi_tmdl/hnh_bsc_report/pbir.py` (writer), `powerbi_tmdl/hnh_bsc_report/tests/test_pbir.py`; output `powerbi_tmdl/hnh_bsc_report/HNH Balanced Scorecard.pbip` and `HNH Balanced Scorecard.Report/` (committed: it is source the user opens)
- Modify: `build.py` (new default command `--format pbip`; the legacy `--format pbix` path kept as fallback), `README.md` (open the PBIP, check, Save As .pbix, open and save in Desktop for Report Server, `check_upload_rules`, upload)

**Interfaces:**
- Consumes: `PAGES`, `Field`, `Visual`, `Page`, `Filter`, `unknown_fields` (Tasks 4–6); the visual kinds in `Visual.sample` (card, multiRowCard, table, matrix, barChart, lineChart, slicerDropdown, slicerRelativeDate, textbox, buttonNavigate, buttonDrill, hnhVisual).
- Produces: `write_pbip(pages, out_dir, database, server, perspective="Balanced Scorecard") -> Path` writing the PBIR project; real format references: `powerbi_tmdl/Hayat BSC Deliverable/00_Full Access/Hayat_BSC_Full_RS.Report` (Desktop-written PBIR: report 3.3.0, page and visual JSON, resource packages) and `powerbi_tmdl/test isual.pbix` (`Connections`: the exact live-connection string Desktop for Report Server writes); the HNH visual from `powerbi_tmdl/hnh_bsc_visual/dist/*.pbiviz`; the theme `theme/hnh_bsc_theme.json` as a registered custom theme.

- [ ] **Step 1: Write the failing tests:** the project tree (`.pbip`, `definition.pbir` with a live connection to `server`/`database`/perspective, `definition/report.json` with the custom theme and the HNH visual registered, `pages/pages.json` in `PAGES` order, one `page.json` per page with display name, 1920 × 1080, hidden flag, page filters, drill-through binding with keep-all-filters as the page sets it (on for KPI detail, off for the family pages), one `visual.json` per visual with position, visual type, roles → projections, sort, top N, visual filters, slicer sync groups per field, button actions, the HNH visual's mode); every JSON file carries its `$schema` like the handover's; no field outside the perspective; deterministic output (two writes are byte-identical).
- [ ] **Step 2–4:** run (FAIL), implement, run (PASS). Write the project with `--database HNH_Analytics_Test`. Commit.
- [ ] **Step 5 (user):** open `HNH Balanced Scorecard.pbip` in Power BI Desktop; every page renders; then the README's Save As .pbix → Desktop for Report Server → save → `check_upload_rules` → upload to a test folder. Defects go back to this task.
