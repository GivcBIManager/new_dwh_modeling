# HNH Balanced Scorecard visual

## API version

- `powerbi-visuals-tools`: 7.2.1 (installed globally 2026-10-21)
- `powerbi-visuals-api`: 5.11.1 (the version `pbiviz new` wrote)
- Runtimes: Power BI Desktop for Report Server May 2026 (2.154) and Power BI Report Server 1.26.9637
- **Confirmed 2026-10-22** with a probe visual at 5.11.1, in Desktop for Report Server and on the report server: render with a hospital series, drill-through menu, default and report-page tooltips, selection and cross-filter, format pane, keyboard focus, empty state, PDF/PowerPoint export.
- If a later server rejects it, step down in this order: 5.11.0, 5.10.0, 5.9.1, 5.9.0, 5.8.0, 5.7.0, 5.6.1, 5.6.0, 5.4.0, 5.3.0, 5.2.0, 5.1.0 (5.1+ offers `formattingModel`, which the visual uses).

## Build, test and package

```powershell
npm install
npm test                 # Vitest, jsdom
npx pbiviz package       # writes dist/hnhBscVisual...1.0.0.0.pbiviz (dist is not committed)
```

Screenshots without Power BI: `powershell -ExecutionPolicy Bypass -File dev\screenshot.ps1` bundles `dev/harness.ts` (the real `Visual` class, a fake host and 70 synthetic KPIs) and has headless Edge write one PNG per mode, plus the design prototype, into `dev/out/` (git-ignored).

## Import into Desktop for Report Server

Power BI Desktop for Report Server: Home, then the Visualizations pane "..." menu, **Import a visual from a file**, pick the `.pbiviz`, and accept the warning for a custom visual. Save the report; the visual travels inside the `.pbix`. Publish to Power BI Report Server 1.26 as usual.

## Field wells

The model is `HNH_Analytics` (perspective `Balanced Scorecard`). Every page binds the same wells, except the Payload on the Hospital Comparison page:

| Well | Field |
|---|---|
| the 21 attribute roles (KPI Code, KPI Name, Short Label, Pillar, Pillar Order, Pillar Weight, Pillar Question, Objective Code, Objective Title, Objective Order, KPI Type, Direction, Value Format, Display Order, Status, Value Source, Owner, Score Base, Score Slope, Good From, Watch From) | the matching `'BSC KPI'` columns |
| Payload | `[BSC Visual Payload]`; on the Hospital Comparison page `[BSC Visual Payload Scores]` (same first six fields, no monthly trends, so KPI × hospital stays fast) |
| Selection label | `[BSC Selection Label]` |
| Branch (comparison mode only; the well Power BI shows as "Branch", it takes one hospital per series) | `'Branch'[Branch Name]` |

Then, per page, set Format pane > Scorecard > View:

| Page | View | Also |
|---|---|---|
| BSC landing | Overview | |
| Financial, Customer, Internal Process, Learning & Growth | Pillar board | page filter on `'BSC KPI'[Pillar]` |
| Owner view | Owner view | |
| Hospital Comparison | Hospital comparison | Payload `[BSC Visual Payload Scores]`; visual-level filter `'Branch'[Is Hospital]` is `Yes`; slicer on `'Branch'[BSC Category]` |

The drill-through page (KPI Detail) takes `'BSC KPI'[KPI Code]` as its drill-through field.

Tooltips: the visual shows its own tooltip (KPI, hospital on the comparison page, objective, actual, target, variance, score, state, owner, source). To use a report-page tooltip instead, set Format pane > General > Tooltips > Type to *Report page* and pick the page; the visual has no Tooltips well.

## Design notes

- The gauges show points: scores run 0 to 100 and are not percentages, so the centre reads "85", not "85%".
- The gauge arc and the pillar chip follow the state of the displayed (rounded) score, so 85 is never orange. Green is 85 and over, orange 70 to 84, red under 70.
- Each KPI tile's variance chip carries the state word ("▼ At risk · −29.5%"), not only an icon and a colour.
- The pillar trend and the KPI trends draw a dashed line: the target for a KPI, the "on track" threshold for a pillar.
- Comparison cells read "<hospital>: <score> · <state>" to a screen reader and in the hover title; no-data cells read "No data yet".
- Comparison score cells take the click (cross-filter), the right-click menu (drill-through to KPI Detail) and the tooltip for that KPI and hospital; "–" cells do nothing.
- The comparison leaves out a branch with no KPI score at all (Head Office, a hospital outside the period); the visual-level filter on `'Branch'[Is Hospital]` keeps such branches out of the query too.
- With several hospitals the header reads "<n> hospitals · <period>"; with one, that hospital's label.
- If the Branch well is filled on an overview, board or owner page, those views show the first hospital only, and a line under the header says so.
