# Press Ganey Patient Experience dashboard (Hayat Healthcare)

A Power BI project (PBIP, PBIR format) with a **live connection** to SSAS:
`hnhanalyticssrv\reportserverdb` > `HNH_Analytics_Test` (the default; `HNH_Analytics` after the production deploy),
perspective **Patient Experience**. Design and decisions:
`docs/superpowers/specs/2026-10-26-press-ganey-dashboard-model-measures-design.md`.

**Every measure lives in the SSAS model** (`ssas/HNH_Analytics/tables/_Measures.tmdl`, domain `Patient Experience`,
folders Survey Quality, Survey Channel, Data Quality, Sample Size, Representativeness, NPS, Satisfaction, Benchmark,
Reliability, Patient Profile, Ranking, Formatting, Story). The report holds no report-level measures, so the same
definitions serve other reports and the scorecard, each measure has a `///` description, a guard (P41) and a
DAX-vs-ClickHouse check in `ssas/tests/measures/patient_experience.json`. To change a measure, edit the TMDL and follow
`ssas/README.md` ("Change the model"); the report only names measures.

Open `PressGaneyDashboard.pbip` in Power BI Desktop (2.158) or in Power BI Desktop for Report Server (May 2026):
both embed the same PBIR schemas and project reader. To render the report in the brand typeface, install the
[Zain](https://fonts.google.com/specimen/Zain) font. The theme falls back to Segoe UI if Zain isn't installed.

## Pages: a landing page, then six chapters

Each chapter opens with the question it answers, a live **key takeaway** sentence next to the filters (a `Story …`
text measure that updates with the slicers), and **Home / Next** buttons. Every visual fits on the page without
scrolling: long lists are shown as fixed Top / Bottom N views, using the `Ranking` measures.

| Page | Question | What it shows |
| --- | --- | --- |
| Home | How are we doing? | NPS gauge, headline KPIs, four auto-generated takeaways, links to each chapter. Opens on month to date, like every page (see Date range below) |
| 1 · Participation | Can we trust the numbers? | Taller page (1280 × 2460, fits to width), five numbered sections: 1 at a glance (volume, response rate, NPS margin, reliability, sample mix); 2 SMS vs call-centre agent (no SMS = agent call), monthly trend, data quality; 3 response rate by channel and patient profile; 4 **is the sample like our visits** (see below); 5 sample size vs visits by care type and branch |
| 2 · Satisfaction & NPS | How do patients rate us? | NPS (5-point), Avg NPS by Question, Overall Satisfaction (0–100), Top Box, Hospital / Physician NPS, trend, care-setting scorecards |
| 3 · What Drives the Score | Which parts of the journey pull NPS down? | 8 lowest and 8 highest question groups (drill down to questions), the 8 lowest-scoring questions |
| 4 · Branch Benchmark | Which branches lead and lag? | Branch scorecards vs network, the 5 weakest question groups by branch, gap to network |
| 5 · Specialties & Doctors | Where to recognise, where to coach? | 15 most-surveyed specialties > doctors by branch; top 8 and bottom 8 doctors (30+ answers) |
| 6 · Patient Profile | Does experience differ by patient? | NPS and satisfaction by gender, nationality, payer and the survey's basic questions |
| Guide 1 · Metrics | How is each number calculated? | Plain-language definition and formula of every measure: participation, answer scoring bands, NPS variants, satisfaction, colours |
| Guide 2 · Rules & Use | What rules apply, and how do I use it? | Benchmarks, minimum sample sizes, Top / Bottom N lists, Patient Profile bridging, slicers, drill down / through, data source |

Every page has a **? Guide** button in its header that opens the guide. The guide text lives in `page_guide_metrics()` /
`page_guide_rules()` in `tools/build_report.py`: update it there when a measure's definition changes in the model.

Navigation buttons work with a plain click on the Report Server, and with **Ctrl + click** while editing in Desktop.

**Drillthrough to "What Drives the Score":** right-click a doctor or a specialty (on 5 · Specialties & Doctors, or any
visual showing them) > **Drill through**:

- *3 · Drivers by Doctor* (hidden page): chapter 3's layout, filtered to the selected **doctor**.
- *3 · Drivers by Specialty* (hidden page): chapter 3's layout, filtered to the selected **specialty**.

Only these two hidden twins are drillthrough targets. Chapter 3 itself has no drillthrough field, so it always shows
the full picture and never needs clearing. Each twin has a single field, so it works whatever fields the source visual
carries. Use **‹ Back** to return. The minimum sample adapts to the context (`Min Answers (Drivers)` /
`Min Answers (Questions)`): question groups need 30+ answers for the network, 10+ for a specialty and 5+ for a doctor;
individual questions need 30 / 10 / 2. The key-takeaway sentence names the doctor or specialty.

**Slicers are synced:** Date range, Branch, Care setting, Specialty and Question group each belong to a sync group, so a
selection carries to every page that has that slicer (check it in Desktop: View > Sync slicers).

- **Period:** horizontal tiles on the model's `'Time Calculation'[Time Calculation]` group, limited to
  **MTD | YTD**, single select, **MTD saved** so the report opens on this month to date without any date stamped at
  build time. MTD / YTD run every measure month / year to date (up to today) on top of the date range when one is
  set. The two monthly trend charts (pages 1 and 2)
  ignore the Period (`page.visualInteractions`, type `NoFilter`), so they always show every month of the date range.
- **Date range:** a Between slicer on `'Date'[Date]` on every page, with start and end date pickers and **no saved
  range**. A visual-level filter (`[Invitations]` is not blank) limits the pickers to dates with surveys.
- **Branch:** page 4 (Branch Benchmark) has no Branch slicer on purpose, so it always compares all branches.

**Clicking a chart cross-filters** the other visuals on the page (report setting `defaultFilterActionIsDataFilter`),
instead of cross-highlighting them.

**Reliability is shown on every page.** It comes from `NPS Margin of Error` (95% confidence, ± NPS points) and
`Reliability` (High ≤ ±3, Moderate ≤ ±7, else Low):

- headline KPI tiles (Home, page 2);
- key-takeaway sentences;
- gauge footers and tooltips (custom visual v1.1);
- signal-bar icons next to NPS in tables and matrices (pages 3–5);
- chart tooltips (pages 2, 3, 4, 6);
- the reliability tile on page 1.

**KPI rows** are classic card tiles, one per figure (value over its label, no chrome), laid out by
`Page.add_kpi_row` from the `card([...], title)` lists in the page functions.

**NPS (5-point)** is the model's `NPS (5-point)`: (promoter − detractor answers) ÷ scored answers × 100 across every
scored question, on the Press Ganey 5-point scales (not comparable with 0–10 benchmarks). Under 30 answers the model
formats it as "insufficient sample"; the ranking measures (`NPS (n>=30)`, `NPS (Drivers)`, `NPS (Questions)`) are blank
instead, so Top / Bottom lists never rank a small sample.

**Sample vs actual visits (page 1)** compares survey responses with the population they should represent.

- **Actual visits:** every survey linked to a visit carries that visit's care type; each care type is one visit pool,
  counted once with the model's Patient Flow measures.

  | Linked visit's care type | Measure |
  | --- | --- |
  | Emergency | `[ER Visits]` |
  | Outpatient | `[OP Visits]` |
  | Inpatient | `[Admissions]` |

  - Day case and unknown care types are outside the comparison.
  - Only months with 1,000+ invitations network-wide count (`Month Has 1000+ Invitations`), so a month whose surveys are still arriving is left out.
  - Only responses linked to a visit count.
  - A care-setting selection needs no mapping: the linked care type follows the surveys (Surgery, Diagnostics and Screening surveys land in the pool of the visit they were linked to).
- **Index:** share of responses ÷ share of visits per group, for care type, branch, gender, nationality and payer.
  - 0.80–1.25 is a fair share.
  - Except by care type, responses are first re-weighted to each care type's share of visits. Otherwise the inpatient over-sampling would distort every other profile.
- **Mismatch:** ½ Σ |response share − visit share|. The verdict uses the worst profile: up to 5% is representative, up to 10% acceptable.
- **Weighted NPS:** each branch × care type is weighted by its visits, then compared with the NPS as surveyed.
- **Non-response bias:** it can't be tested by channel, because each care setting uses a single channel (inpatient = agent call, outpatient / ER = SMS).

**Patient Profile (page 6).** `Survey Answers` has no relationship to `Survey Responses`. The `(Response Attr)`
measures bridge the response key with `TREATAS` when a response attribute (who completed the survey, first visit…) is
filtered directly (`ISFILTERED ( 'Survey Responses' )`), so those attributes filter NPS correctly without bridging on
every other page.

## Layout

```text
PressGaneyDashboard.pbip
PressGaneyDashboard.SemanticModel/   modelReference.json -> SSAS live connection (no local model)
PressGaneyDashboard.Report/          PBIR definition, theme, logo, packaged custom visual
custom-visual/hayatNpsScorecard/     source of the "Hayat NPS Scorecard" custom visual (pbiviz)
tools/                               generator, theme, validation scripts
branding/                            brand guideline and logo files (source material, not in git)
```

The report files are generated. To change them, edit `tools/` and rebuild instead of editing the JSON by hand:

```powershell
python tools/build_report.py [--database HNH_Analytics]        # regenerate the .Report / .SemanticModel folders
python tools/validate_pbir.py [--desktop-rs]                   # Desktop's schemas + project reader, field references, layout
python tools/smoke_test_visuals.py [--define]; powershell.exe -NoProfile -File tools\smoke_test_visuals.ps1 [-Catalog HNH_Analytics]
powershell.exe -NoProfile -File tools\export_model_fields.ps1 [-Catalog HNH_Analytics]   # refresh tools/model_fields.json
```

- **Measures**: in the model. `tools/model_measures.py` reads the repository's `Patient Experience` perspective, so the
  report can name a measure before it is deployed; `tools/model_fields.json` (exported from the live cube through
  DMVs) supplies the columns. The smoke test runs every visual's query on the deployed measures, guards included,
  and flags a guard message inside a visual (a measure allowed to be filtered by a table must call the measures it
  wraps through their `_Unguarded` twins, see `ssas/tools/measure_guards.py`); with `--define` it defines the
  repository's measures query-scoped, without guards, to try the visuals before a deploy.
- **Theme**: `tools/HayatHealthcare.theme.json` (brand palette from the guideline: Dark Blue `#0A1E32`, Light Blue `#32A5E6`, plus the secondary and tertiary colours).
- **Custom visual**: `cd custom-visual/hayatNpsScorecard && npm install && npx pbiviz package`, then rerun `build_report.py`.

## Power BI Report Server

The report is built for Power BI Report Server (PBIRS 15.0.1121, May 2026) on `HNHANALYTICSSRV`: core visuals, slicers,
buttons, text boxes, one private custom visual packaged in the file (API 5.11.1, as the scorecard visual), a live
connection and no report-level measures, field parameters, visual calculations or bookmarks.

1. Deploy the model measures first: `ssas\scripts\deploy.ps1 -Stage TestMeasures` (test database) or `-Stage All`
   (production); the measure checks of `tests/measures/patient_experience.json` run as part of it.
2. `python tools/build_report.py` (default `HNH_Analytics_Test`; `--database HNH_Analytics` for production), then
   `python tools/validate_pbir.py --desktop-rs` and the smoke test.
3. Open `PressGaneyDashboard.pbip` in **Power BI Desktop for Report Server** (May 2026, `C:\Program Files\Microsoft
   Power BI Desktop RS`). Check Home, page 1 and a drillthrough. File > Save As > `.pbix` (for example
   `C:\HNH\report\PressGaneyDashboard.pbix`). Desktop for Report Server writes the legacy `Report/Layout` package the
   server needs. If it refuses the project, open it in Desktop 2.158 first, Save As `.pbix`, then open that file in
   Desktop for Report Server and Save (the route of `powerbi_tmdl/hnh_bsc_report/README.md`).
4. Check the file from `powerbi_tmdl/hnh_bsc_report`:
   `python -c "from pbix import check_upload_rules; print(check_upload_rules(r'C:\HNH\report\PressGaneyDashboard.pbix'))"`
   → `[]`.
5. Upload in the web portal. A live connection needs no stored credentials: the viewer's Windows identity flows to
   SSAS, which applies the row filters. Custom visuals must be allowed on the server so the Hayat NPS Scorecard loads.
6. Sign in as a one-branch user (a non-admin member of `HNH_BI_Users`) and check that every page shows that branch only.

Leave the `.pbip` and its folders off the server. Desktop writes its local state to `.pbi/` folders, which are git-ignored.

## PBIR rules learned the hard way

- A report-level measure must be referenced with `"SourceRef": {"Schema": "extension", …}` and its `references` must
  list only other report measures, or Desktop drops the file. The report has none any more; `validate_pbir.py` fails
  on any `Schema` in a field reference or on a `reportExtensions.json`.
- A button label needs a `selector: {"id": "default"}` entry (Desktop reads text per state).
