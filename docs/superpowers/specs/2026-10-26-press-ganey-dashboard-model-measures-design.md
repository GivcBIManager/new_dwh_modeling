# Press Ganey dashboard: measures into the SSAS model, test database, Report Server

- **Date:** 2026-10-26
- **Status:** Implemented the same day (see section 6)
- **Scope:** `powerbi_tmdl/pressGaneyDashboard/pressGaneyDashboard/` (the PBIP, its generator `tools/build_report.py`) and
  `ssas/HNH_Analytics/tables/_Measures.tmdl` (domain `Patient Experience`).
- **Parent specs:** `2026-10-07-hnh-dwh-phase6-patient-experience-design.md` (facts, KPI definitions, section 7),
  `2026-10-07-hnh-ssas-tabular-model-design.md` (measure conventions, guards P41).

## 1. Intent

The Press Ganey dashboard was built as a live-connection report with 117 **report-level measures** (`reportExtensions.json`),
because a live connection cannot add model measures. That left the logic outside the model (not tested, not guarded, not
reusable by other reports or the scorecard), pointed the report at production `HNH_Analytics`, whose metadata is from
13 Oct and holds only 16 measures, and relied on three Desktop quirks of report-level measures. The user asked to

1. evaluate, enhance and optimise the measures and the design;
2. use `HNH_Analytics_Test`;
3. put every measure that lives outside the SSAS model into the model;
4. keep the report compatible with Power BI Report Server (PBIRS).

## 2. Decisions

| # | Decision |
|---|---|
| D1 | **Every report measure moves into `_Measures`** (folders `Patient Experience\<topic>`), through the normal route: `///` description, format, `tests/measures/patient_experience.json` check, `measure_guards.py`, `sync_perspectives.py`. The report has no `reportExtensions.json` any more. |
| D2 | **Where the model already had the measure, the report uses the model's name** and the duplicate is dropped: `Total NPS` → `NPS (5-point)`, `Scored Answers` → `NPS Answers`, `Promoter/Passive/Detractor %` → `% Promoters/% Passives/% Detractors`, `Physician NPS` → `Physician NPS (5-point)`, `Completion Rate %` (same), `SMS Delivery %` → `SMS Reach %`, `SMS Sent` → `Invitations (SMS)`, `Duplicate Invitations %` → `Repeat Invitation Rate %`, `Encounter Link Rate %` (all rows) → `Encounter Link %` (primary invitations, the spec's definition), `Avg Days Visit to Response` → `Median Days Visit to Answer` (spec 7.1), report `ER Visits` (arrived, by care type) → model `ER Visits` (Encounter Type ER, not cancelled). |
| D3 | **New measure names follow the model**: "NPS" rather than "Total NPS" (`Network NPS`, `NPS vs Network`, `Specialty NPS`, `NPS (n>=30)`, `NPS (Drivers)`…), `Avg Total NPS` → `Avg NPS by Question`, `Doctor NPS (n>=10)` → `Physician NPS (n>=10)`, `Overall Satisfaction %` → `Overall Satisfaction (0-100)` (it is a 0–100 score, not a percentage). |
| D4 | **Visit-matched measures use the linked encounter's care type**, not a mapping of the survey's care setting to a pool. Linked surveys carry `Care Type Key` from the encounter; the data confirms ER→ER, OP-type services (OP, DEN, OR, HHC, TM, OU)→OP, IP/PIP/LTC→IP, with a few dozen exceptions that the old mapping got wrong (AS "Surgery", RAD "Diagnostics", OUCX "Screening" were all sent to the inpatient pool). Pools are the care types OP, ER, IP; Day case and Unknown are outside. The `pools`/`settings` tables of five measures disappear. |
| D5 | **The `(Response Attr)` bridge switches on `ISFILTERED ( 'Survey Responses' )`** (a column of the response fact is filtered directly) instead of `ISCROSSFILTERED`, which was true whenever a slicer touched Branch or Date, so every page was bridging up to 700K response keys through `TREATAS` for nothing. |
| D6 | **"Months with 1,000+ invitations" is one helper measure** (`Month Has 1000+ Invitations`), network-wide, used by the three visit-matched bases instead of being written out in each. |
| D7 | **Base counts become measures** (`Surveys Responded`, `Surveys Submitted`, `Surveys Partial`, `Surveys Not Started`, `Patients Invited`, `Patients Responded`, `Invitations (SMS)`…), and the existing `Response Rate %`, `Completion Rate %`, `SMS Reach %` are rewritten on top of them (same values, tested). `Patients Invited/Responded` count known patients (`Patient Key <> -1`): an unlinked survey has no patient. |
| D8 | **Boolean helpers return 1 / blank** (`Is Weak Question`, `Is Top Doctor`, `Is Bottom Doctor`): the model has no boolean format convention and they are only read by other measures. |
| D9 | **Guards:** measures that mix the survey facts with `Encounters`/`Admissions` carry `annotation hnh_guard_allow = Survey Service` (they map the care setting themselves through the linked care type); the `(Response Attr)` measures and `Story Profile` carry `hnh_guard_allow = Survey Responses` (they bridge the response attributes themselves). Everything else gets the generated guard. |
| D10 | **The report connects to `HNH_Analytics_Test`** by default (`build_report.py --database`, as the scorecard build does); switch to `HNH_Analytics` with `--database HNH_Analytics` after the production deploy. |
| D11 | **Report Server route:** Desktop for Report Server (May 2026, 2.154) embeds the same PBIR schemas (visualContainer 2.13.0, report 3.3.0, page 2.1.0) and the same project reader (`ReadEnhancedReportFormat`) as Desktop 2.158, so the PBIP opens there directly: open the `.pbip` in Desktop for Report Server, Save as `.pbix`, check with `hnh_bsc_report/pbix.check_upload_rules`, upload. The report uses only visuals Report Server renders (`card`, `cardVisual`, `tableEx`, `pivotTable`, bar/column/line/combo charts, slicers, buttons, text boxes, shapes, images, one private custom visual packaged in the file, API 5.11.1 like the scorecard visual) and no report-level measures, field parameters, visual calculations or bookmarks. |
| D12 | **The dashboard folder joins git** (`!/powerbi_tmdl/pressGaneyDashboard/` in the root `.gitignore`; `branding/` and the zip stay out). It is a generator like `hnh_bsc_report`. |

## 3. Measure catalogue (domain `Patient Experience`)

Existing (unchanged names): `Invitations`, `All Invitations`, `SMS Reach %`, `Response Rate %`, `Completion Rate %`,
`Answer Completeness %`, `Median Days Visit to Answer`, `Encounter Link %`, `Doctor Attribution %`,
`Repeat Invitation Rate %`, `NPS (5-point)`, `Hospital NPS (5-point)`, `Physician NPS (5-point)`, `NPS Answers`,
`% Promoters`, `% Passives`, `% Detractors`.

New, by folder:

- **Survey Quality:** Surveys Responded, Surveys Submitted, Surveys Partial, Surveys Not Started, Patients Invited, Patients Responded.
- **Survey Channel:** Invitations (SMS), Invitations (Agent Call), Responded (SMS), Responded (Agent Call), Response Rate % (SMS), Response Rate % (Agent Call), Completion Rate % (SMS), Completion Rate % (Agent Call), Agent Call Share of Responses %.
- **Data Quality:** Partial Rate %, Unknown Gender %.
- **Sample Size:** Month Has 1000+ Invitations, Actual Visits, Survey Coverage %, Response Coverage %, Required Sample (±5%), Sample Gap, Margin of Error (±).
- **Representativeness:** Invitations (Visit-Matched), Respondents (Visit-Matched), Response Rate % (Visit-Matched), Response Share %, Visit Share %, Representation Index, Representation Status, Mismatch (Branch | Care Type | Gender | Nationality | Payer), Sample Representativeness, Sample Mix, NPS (Visit-Matched), Weighted NPS, NPS Weighting Effect.
- **NPS:** Respondents, Avg NPS by Question, NPS (n>=30), Physician NPS (n>=10).
- **Satisfaction:** Overall Satisfaction (0-100), Top Box %.
- **Benchmark:** Network NPS, NPS vs Network, Network Overall Satisfaction (0-100), Network Response Rate %, Specialty NPS.
- **Reliability:** NPS Margin of Error, Reliability, NPS Margin of Error (Response Attr), Reliability (Response Attr).
- **Patient Profile:** NPS (Response Attr), Overall Satisfaction (Response Attr), % Promoters (Response Attr), % Detractors (Response Attr), Respondents (Response Attr).
- **Ranking:** Min Answers (Drivers), NPS (Drivers), Min Answers (Questions), NPS (Questions), Group NPS (Bottom 8), Group NPS (Top 8), Is Weak Question, Q NPS (Bottom 8), Q % Promoters (Bottom 8), Q % Detractors (Bottom 8), Q Answers (Bottom 8), Group Network Rank (Low), Weak Group NPS (Bottom 5), Specialty Volume Rank, Specialty NPS (Top 15 by Volume), Doctor Score, Is Top Doctor, Is Bottom Doctor, Top/Bottom Doctor NPS, Top/Bottom Doctor Specialty NPS, Top/Bottom Doctor Physician NPS, Top/Bottom Doctor Answers.
- **Formatting:** NPS Color, Gap Color, Representation Color, Report Title Context.
- **Story:** Insight Participation, Insight NPS, Insight Branches, Insight Drivers, Story Participation, Story Satisfaction, Story Drivers, Story Branches, Story Doctors, Story Profile, Story Representativeness.

## 4. What the review found in the report measures

| Finding | Action |
|---|---|
| 12 report measures duplicated or contradicted model measures (D2). | Use the model's. |
| `ISCROSSFILTERED ( 'Survey Responses' )` made the response bridge run on every page (D5). | `ISFILTERED`. |
| Care-setting → visit-pool mapping misfiled Surgery, Diagnostics and Screening surveys as inpatient and was repeated in 5 measures (D4). | Linked care type. |
| Months-with-1,000-invitations table repeated in 3 measures (D6). | Helper measure. |
| `Overall Satisfaction %` is a 0–100 score (D3). | Renamed. |
| Report `ER Visits` (arrived, by care type name) differed from the model's `ER Visits`. | Model's. |
| `NPS Margin of Error` divides the answer-share variance by distinct respondents, not answers. | Kept (conservative; the guide explains it); noted here. |
| `Patients Invited` counted the unknown patient (−1) as one patient. | Excluded (D7). |
| Text `Story`/`Insight` measures evaluate up to 6 NPS measures each; they are per page, not per row. | Kept. |

## 4a. Visual design pass (same day)

The reader scans a chapter for its one sentence of insight, then checks the evidence, so the design spends its one
bold element on that sentence and quietens the rest:

- the key-takeaway banner is the only tinted panel on a page (pale blue, accent-blue edge) and its type grows from
  10 to 12 px (11 px in the four Home takeaways and the page-1 verdict);
- panels lose their borders: white on the light page background is separation enough, with an 8 px radius;
- tables and matrices get a light header (ink on `#EAF0F6`) instead of seven dark bars on the participation page,
  no row banding, and hairline grid `#EEF2F7`;
- axes, legends (top, no title), data labels and slicer headers drop to 9 px grey, chart subtitles to 9 px;
- KPI rows are one classic card per figure (value 22 px over its 10 px label, no chrome) under a row title, instead
  of the multi-value "new card" visual, which the user did not like and which is the less proven visual on Report
  Server (`Page.add_kpi_row`);
- the signal-bar reliability icons next to NPS in tables and matrices stay (a Reliability text column was tried and
  undone at the user's request).
- the five sections of the participation page open with a 40 × 3 px accent rule, the device the header band uses;
- Home's six chapter tiles become pale buttons, so the header's "Start" button is the page's one call to action;
- the date range no longer saves a default; a Period tile slicer on the model's `Time Calculation` group (MTD | YTD,
  MTD saved) opens the report on this month to date without a build-time date stamp. The monthly trend
  charts ignore the Period through `visualInteractions` (`NoFilter`), so YTD does not turn them cumulative. Checked
  read-only on the test database: MTD = this month's invitations, YTD = this year's, and the text measures follow.

Palette and typeface are unchanged (brand). Validated against Desktop's and Desktop for Report Server's schemas.

## 5. Not done, recommended

- `Overall Satisfaction (0-100)` and `Top Box %` rescale answers in DAX (`SUMMARIZE` by scale and score). A gold column
  `answer_score_pct` (0–100) and `is_top_box` on `fact_survey_answer` would make them plain averages; needs a dbt change,
  `generate.py` and a full process of `Survey Answers`.
- The Balanced Scorecard perspective lists every Patient Experience measure (`PERSPECTIVE_MEASURE_DOMAINS`), so it now
  shows the ~110 dashboard measures too. Narrowing it needs a per-folder rule in `model_config.py`.

## 6. Implementation record

Section 2 was implemented on 2026-10-26: `_Measures.tmdl` (102 new measures, 3 rewritten), guards and perspectives
regenerated, `tests/measures/patient_experience.json` extended by 103 checks, the report generator rewritten to model
measures and `HNH_Analytics_Test` (`tools/model_measures.py` reads the perspective from the TMDL), `validate_pbir.py`
on Desktop's and Desktop for Report Server's embedded schemas and project readers (both pass), the README's Report
Server steps. The DAX of every new measure was validated query-scoped (`DEFINE MEASURE`) against `HNH_Analytics_Test`
and against ClickHouse on Jan–Jun 2026 (a closed period: the test database was loaded on 25 Oct) before the model
deploy, which is the user's step (`deploy.ps1 -Stage TestMeasures`).

Found on the way:

- `REMOVEFILTERS ( 'Survey Responses' )` also removes the Date filter, because the fact's expanded table includes the
  Date columns. `Month Has 1000+ Invitations` re-applies `VALUES ( 'Date'[Start Of Month] )` after it.
- `dim_survey_question.domain_en` spells one question group two ways ("Moving Through your visit" in one survey,
  "Moving Through Your Visit" in another). SSAS groups case-insensitively (27 groups), ClickHouse does not (28), so the
  checks group on `lowerUTF8(trim(…))`. The warehouse should carry one spelling (a dbt fix in
  `dim_survey_question`); until then the report shows whichever spelling SSAS keeps.
- Query-scoped DAX in `SUMMARIZECOLUMNS` reproduces the visuals' `ALLSELECTED ()` shares exactly, so the checks can
  test the ranking and share measures in their visual context.
- **The checks need fresh test data.** The user's `deploy.ps1 -Stage TestMeasures` run of 12:08 failed 131 of 487
  checks across every domain, each by a sliver (Surveys Responded 31,386 vs 31,681; Open Payables 261.2M vs 252.1M):
  that stage keeps the test database's data (survey tables loaded 25 Oct 05:34) while ClickHouse moves on, and late
  survey answers, late-linked encounters and corrections reach ClickHouse first. The survey checks were moved to the
  closed period January–September 2026 (`gen_checks.py`), which narrows the drift to a few rows but does not remove
  it; a stage that refreshes the test data first (`-Stage Test`, the Daily refresh) makes them exact, as the H1
  comparison on the same load was.
- **The Report Server takes only the legacy package.** The user's two uploads (12:56, 12:58) failed with a 400: the
  server's `PbixParserV1.GetReportDocumentFromPowerBIPackage` found no `Report/Layout`, because a `.pbix` saved from
  this project by Desktop 2.158 or by Desktop for Report Server (May 2026) carries the PBIR folder `Report/definition`
  (D11's assumption that Desktop for Report Server rewrites the legacy format was wrong; its package library knows
  PBIR, so it keeps it). `tools/pbir_to_pbix.py` now writes the legacy package from the generated definition folder
  (shapes from `powerbi_tmdl/test isual.pbix`, the handover pbix and `hnh_bsc_report/LAYOUT_FORMAT.md`); it passes
  the upload rules and Desktop for Report Server opens it without a dialog. Unverified from this session: the custom
  theme item type (201) and the numeric `visualInteractions` type (NoFilter = 3) are inferred; a render check in
  Desktop for Report Server or on the server settles both. The same route applies to the scorecard report.
- **Guards chain.** A measure allowed to be filtered by a table (`hnh_guard_allow`) must call the measures it wraps
  through their `_Unguarded` twins, and those twins must not call guarded measures themselves: the first screenshot
  round showed page 6 failing because `NPS (Response Attr)` called `[NPS (5-point)]`, whose guard fired on the
  response filter, and `[NPS (5-point)]` in turn called `[NPS Answers]`. The bridged measures and `Actual Visits`
  now call `_Unguarded` twins, and the four answer-share measures read `[_Unguarded NPS Answers]`. The smoke test
  runs the deployed measures by default and flags any guard message inside a visual (`--define` is for a model not
  deployed yet).
