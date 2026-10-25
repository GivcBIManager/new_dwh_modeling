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
npx pbiviz package       # writes dist/hnhBscVisual...1.0.3.2.pbiviz (dist is not committed)
```

Screenshots without Power BI: `powershell -ExecutionPolicy Bypass -File dev\screenshot.ps1` bundles `dev/harness.ts` (the real `Visual` class, a fake host and 70 synthetic KPIs; for the comparison 8 hospitals over 14 objectives) and has headless Edge write one PNG per mode, the three comparison levels (`comparison`, `comparison-pillar`, `comparison-objective`) and the design prototype into `dev/out/` (git-ignored).

## Import into Desktop for Report Server

Power BI Desktop for Report Server: Home, then the Visualizations pane "..." menu, **Import a visual from a file**, pick the `.pbiviz`, and accept the warning for a custom visual. Save the report; the visual travels inside the `.pbix`. Publish to Power BI Report Server 1.26 as usual.

## Field wells

The model is `HNH_Analytics` (perspective `Balanced Scorecard`). Every page binds the same wells, except the Payload (see the table):

| Well | Field |
|---|---|
| the 22 attribute roles (KPI Code, KPI Name, Short Label, Pillar, Pillar Order, Pillar Weight, Pillar Question, Objective Code, Objective Title, Objective Order, KPI Type, Direction, Value Format, Display Order, Status, Value Source, Owner, Co-owners, Score Base, Score Slope, Good From, Watch From) | the matching `'BSC KPI'` columns |
| Payload | `[BSC Visual Payload]` on the pillar board and owner pages; `[BSC Visual Payload Scores]` on the landing (Overview) and Hospital Comparison pages. The scores payload has the same first six fields and no monthly trends, which keeps those pages fast for non-admin (row-level-security) users; without trends the overview shows no pillar trend and the tiles no sparklines. |
| Selection label | `[BSC Selection Label]` |
| Branch (comparison mode only; the well Power BI shows as "Branch", it takes one hospital per series) | `'Branch'[Branch Name]` |

Then, per page, set Format pane > Scorecard > View:

| Page | View | Also |
|---|---|---|
| BSC landing | Overview | Payload `[BSC Visual Payload Scores]` |
| Financial, Customer, Internal Process, Learning & Growth | Pillar board | Payload `[BSC Visual Payload]`; page filter on `'BSC KPI'[Pillar]` |
| Owner view | Owner view | Payload `[BSC Visual Payload]`; ownership overview: a strip of owner achievement cards, then one block per owner or co-owner (`Co Owners`, separated by `|`), co-owner rows tagged "co-owner" |
| Hospital Comparison | Hospital comparison | Payload `[BSC Visual Payload Scores]`; visual-level filter `'Branch'[Is Hospital]` is `Yes`; slicer on `'Branch'[BSC Category]` |

The drill-through page (KPI Detail) takes `'BSC KPI'[KPI Code]` as its drill-through field.

Tooltips: the visual shows its own tooltip (KPI, hospital on the comparison page, objective, actual, target, variance, score, state, owner, source). To use a report-page tooltip instead, set Format pane > General > Tooltips > Type to *Report page* and pick the page; the visual has no Tooltips well.

## Design notes

- The gauges show points: scores run 0 to 100 and are not percentages, so the centre reads "85", not "85%".
- The gauge arc and the pillar chip follow the state of the displayed (rounded) score, so 85 is never orange. Green is 85 and over, orange 70 to 84, red under 70.
- Each KPI tile's variance chip carries the state word ("▼ At risk · −29.5%"), not only an icon and a colour.
- The pillar trend and the KPI trends draw a dashed line: the target for a KPI, the "on track" threshold for a pillar.
- The hospital comparison (1.0.1.0) is a league table: hospitals are rows, ranked; the columns drill **Pillar › Objective › KPI**. Level 1 shows Overall and the four pillars, ranked by the overall score; clicking a pillar header shows that pillar's score and one column per objective ("F1 · Revenue"), ranked by the pillar score; clicking an objective header shows the objective's score and one column per KPI, ranked by the objective score. A breadcrumb ("All pillars › Financial › F1 · Revenue") goes back up. The level is the visual's own state (no host selection, like the board tab): it survives a data refresh and goes back to the top when its pillar or objective is no longer in the data.
- The objective score is the weighted mean of the objective's KPI scores for that hospital, the same rule as the pillar score (KPIs with a score and a weight above 0).
- Ranking uses the shown (rounded) score: equal scores share the rank and are listed by hospital name; a hospital without a score at that level is listed last with "–". The peer median is the median score of the other hospitals at that level. The focus-hospital highlight and the hospital line above the table of 1.0.0.0 are gone: the Overall column and the ranking replace them.
- Overall, pillar and objective cells are coloured by their rounded score with the visual's thresholds; they are not drill sources. KPI cells show the score and "actual / target" in the KPI's value format, coloured by the KPI state.
- Comparison cells read "<hospital>: <column> <score> · <state>" to a screen reader and in the hover title (KPI cells add actual / target); no-data cells read "No data yet". Drill headers and breadcrumb links are buttons (Tab, then Enter or Space); after a keyboard drill the focus moves to the breadcrumb's last link, and after going up to the header drilled from.
- Comparison KPI cells take the click (cross-filter), the right-click menu (drill-through to KPI Detail) and the tooltip for that KPI and hospital; "–" cells do nothing.
- The comparison leaves out a branch with no KPI score at all (Head Office, a hospital outside the period); the visual-level filter on `'Branch'[Is Hospital]` keeps such branches out of the query too.
- With several hospitals the header reads "<n> hospitals · <period>"; with one, that hospital's label.
- The owner view (1.0.3.0) is the old report's ownership overview. A strip has one card per owner, each a gauge labelled **Achievement** in %; three toggles in the visual pick what it shows: **Score** Weighted (default) or On-target, **Owners** C-Suite (default: CEO, COO, CMO, CFO, CHRO, CIO, CSO) or All owners, **KPI list** Owned + co-owned (default, 1.0.3.2) or Owned. A card always counts the owner's owned and co-owned KPIs, as the old report's cards did; the KPI list toggle changes only the blocks below (Owned + co-owned lists each KPI under its owner and, tagged "co-owner", under each co-owner; Owned lists each owner's own KPIs only). Cards run C-suite first in that order, then the other owners by name; anyone who owns or co-owns a KPI has a card. The toggles and the picked card are the visual's own state (no host selection) and survive a data refresh; a picked owner whose card leaves the strip is dropped.
- Below the strip, every owner's KPI block is listed; clicking a card shows only that owner's block (a second click shows every owner again). Under Owned, a picked co-owner who owns nothing gets a line pointing to Owned + co-owned. KPI rows keep the click, right-click drill-through, tooltip and keyboard focus. Cards and toggles are buttons (Tab, then Enter or Space), and focus stays on them after the re-render.
- **Weighted** is the weighted mean of the owner's KPI *unit scores*, weights = the KPI weight (payload field 6); a KPI without a unit score or a weight above 0 is left out. Unit score, as the handover's `_v9KpiUnitScore` (no cap): higher actual / target (target > 0); lower target / actual (both > 0); ceiling 1 at or under the target, else target / actual; on target max(0, 1 − |actual − target| / |target|); a budget variance (name contains "budget variance", or lower with target 0) 1 − (actual − target), values above 1.5 read as percentages, at or below 0 becomes 0.01. A unit at or below 0, or a KPI without actual and target (or parked / no data), is not scored. The handover also scored /readmission/ names as ceiling; here the configured direction decides.
- **On-target** is the share of the owner's judgeable KPIs (actual and target present) whose direction-adjusted variance (payload field 3) is 0 or more (higher, lower, ceiling). An on_target KPI's variance is −|actual − target|, never above 0, so it counts as on target when its state is On track (score at or above the good threshold).
- Achievement colours: 100% and over green, 85–99% orange, under 85% red, on the rounded value; the arc stops at 100% (the target marker), the number does not. "–" when the owner has nothing scored or judged.
- If the Branch well is filled on an overview, board or owner page, those views show the first hospital only, and a line under the header says so.
