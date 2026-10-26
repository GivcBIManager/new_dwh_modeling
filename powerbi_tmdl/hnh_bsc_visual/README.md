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
npm run lint
npx pbiviz package       # writes dist/hnhBscVisual431F658EE9D44EA3BD5E1BEA5FAF899D.1.1.0.0.pbiviz (dist is not committed)
```

Screenshots without Power BI: `powershell -ExecutionPolicy Bypass -File dev\screenshot.ps1` bundles `dev/harness.ts` (the real `Visual` class, a fake host and 70 synthetic KPIs; for the comparison 8 hospitals over 14 objectives) and has headless Edge write one PNG per view into `dev/out/` (git-ignored), at the box the report gives the visual: 1860 × 870 for `overview`, `overview-scores`, `board` (Financial), `board-select` (Financial with a KPI selected), `board-ip` (Internal Process, 26 KPIs), `owner` (and `owner-ontarget-all`, `owner-owned-pick`) and `comparison` (and `comparison-pillar`, `comparison-objective`); 1920 × 996 for `detail`. It then prints the geometry the report's native visuals rely on (the four pillar cards, the board's chart and button slots, the detail panels). The harness takes `?mode=`, and on the board `?pillar=<name>` (the page filter), `?select=<KPI code>` (the host selection the panel shows) and `?objective=<code>` (the objective picker); in detail `?kpi=<KPI code>`.

## Import into Desktop for Report Server

Power BI Desktop for Report Server: Home, then the Visualizations pane "..." menu, **Import a visual from a file**, pick the `.pbiviz`, and accept the warning for a custom visual. Save the report; the visual travels inside the `.pbix`. Publish to Power BI Report Server 1.26 as usual.

## Field wells

The model is `HNH_Analytics` (perspective `Balanced Scorecard`). Every page binds the same wells, except the Payload and the three KPI-detail wells (see the tables):

| Well | Field |
|---|---|
| the 22 attribute roles (KPI Code, KPI Name, Short Label, Pillar, Pillar Order, Pillar Weight, Pillar Question, Objective Code, Objective Title, Objective Order, KPI Type, Direction, Value Format, Display Order, Status, Value Source, Owner, Co-owners, Score Base, Score Slope, Good From, Watch From) | the matching `'BSC KPI'` columns |
| Payload | `[BSC Visual Payload]` on the Overview, pillar, owner and KPI detail pages; `[BSC Visual Payload Scores]` on the Hospital Comparison page. The scores payload has the same first six fields and no monthly trends, which keeps the comparison fast for non-admin (row-level-security) users. Bound to an Overview, it leaves out the sparklines, the deltas and the pillar trend panel, and Needs attention takes the bottom row. |
| Selection label | `[BSC Selection Label]`; the month names of every trend come from its last "Mon YYYY" (none when it has no month) |
| Branch (comparison mode only; the well Power BI shows as "Branch", it takes one hospital per series) | `'Branch'[Branch Name]` |
| Definition (KPI detail only) | `'BSC KPI'[Definition]` |
| Target basis (KPI detail only, a measure) | `[BSC Target Basis]` |
| Manual note (KPI detail only, a measure) | `[BSC Manual Note]` |

Then, per page, set Format pane > Scorecard > View (Show header stays off: the report draws its own header bar and filter bar):

| Page | View | Also |
|---|---|---|
| Overview (BSC landing) | Overview | Payload `[BSC Visual Payload]`; a transparent page-navigation button over each pillar card |
| Financial, Customer, Internal Process, Learning & Growth | Pillar board | Payload `[BSC Visual Payload]`; page filter on `'BSC KPI'[Pillar]`; the native "By hospital" chart and the drill-through button over the panel's two empty slots |
| KPI Detail (drill-through on `'BSC KPI'[KPI Code]`) | KPI detail (mode `detail`) | Payload `[BSC Visual Payload]`, plus the Definition, Target basis and Manual note wells; the visual covers the page under the header bar, with the native Back button over its sub-bar and the native by-hospital chart and matrix over its empty lower right |
| Owner view | Owner view | Payload `[BSC Visual Payload]` |
| Hospital Comparison | Hospital comparison | Payload `[BSC Visual Payload Scores]`; visual-level filter `'Branch'[Is Hospital]` is `Yes`; slicer on `'Branch'[BSC Category]` |

Tooltips: the visual shows its own tooltip (KPI, hospital on the comparison page, objective, actual, target, variance, score, state, owner, source). To use a report-page tooltip instead, set Format pane > General > Tooltips > Type to *Report page* and pick the page; the visual has no Tooltips well.

## Design notes

The layout is the "Corporate BSC" design (spec `docs/superpowers/specs/2026-10-26-bsc-report-redesign-design.md`) at 1.5 × its 1280 × 720 canvas, in HNH colours and Segoe UI. Content sits in white panels (1 px `#DCE5EF` line, radius 12, 21 px headings) on the surface colour; numbers use tabular figures. The visual's own header band (gradient and logo ribbon) is off by default (Format pane > Scorecard > Show header).

- **States** are colour, shape and word everywhere: On track a circle, Watch a diamond, At risk a square, and No data yet, Parked and No target a short dash, in pill chips with a pale background. The words are the model's; the thresholds are `Good From` (85) and `Watch From` (70), applied to the shown (rounded) score. Scores above 100 print in full; rings and bars fill at 100 and stop, and trend axes extend to the next ten above the highest value.
- **Overview:** the overall panel (ring with the weighted overall score "of 100", its chip, the change against the previous month, "Target 85 · gap x", and the On track / Watch / At risk / No data distribution); four pillar cards (colour square, name, weight, score and chip, a progress bar with the target marker, the score sparkline, the state counts and the last change, "Drill into N KPIs →"); the pillar score trend (one line per pillar, labelled at its end, with the dashed target); and Needs attention (the At-risk KPIs, lowest score first, actual in the At-risk colour, the target with ≥ / ≤ / ≈, and a line counting the Watch KPIs). The report's page buttons sit over the pillar cards, card i at x = 474 + i × 352.5 (328.5 × 348) in the visual's 1860 × 870 box; a click on a card is not a selection.
- **Pillar board:** a summary strip (breadcrumb, pillar name, pillar score and chip, change against the previous month, weight, state counts, the pillar question), then the KPI scorecard beside the selected-KPI panel. The scorecard lists the pillar's KPIs by objective order, primary first, then display order: state chip, KPI with its objective (or the reason it has no score), actual, target with ≥ / ≤ / ≈, the direction-adjusted variance, score, and a 12-month sparkline whose end dot carries the state colour; manual KPIs carry a "Manual" tag. The rows scroll under a fixed header. The objective picker in the table's heading narrows the table only (the strip always describes the whole pillar); it is the visual's own state, not a report filter, and resets on another pillar.
- **Selected-KPI panel:** it follows the host selection. With one KPI selected it shows the name, objective and direction note, Actual / Target / Score with the state, and "Monthly trend vs target" bars (pillar colour when that month met its target by the KPI's own rule, the Watch tint when it missed, the dashed monthly target, month initials). With none, or several (Ctrl+click), it asks for one KPI. A KPI without a score shows its chip and reason and no bars. The panel's lower part is left empty for the report's native "By hospital" chart at (1224, 549, 612, 219) and drill-through button at (1224, 786, 612, 60) in the visual's box. A click inside the panel keeps the selection; a click on empty space elsewhere clears it.
- **KPI detail:** a sub-bar (breadcrumb Overview › pillar › KPI, and chips for the drill-through filters: the KPI, the period and the hospital), then the profile (pillar · objective, KPI name, the actual in its state colour, chip, target · variance · score, Definition, Better when, Target basis, Weight, Owner, Co-owners, Source, the three performance bands in the KPI's units from its target and scoring rule (each edge is where the rounded score reaches Good From or Watch From, as the model's state does, so an On track actual is always inside the On track band), and the manual-entry note for a manual KPI) and "Monthly trend with performance bands" (the actual line over each month's three bands and the dashed monthly target; y ticks are never finer than the value format prints, and a SAR axis that reaches 1 million is in millions throughout). The visual shows the first KPI of the first hospital; with several KPIs it says so. Clicks inside the profile and trend panels keep the selection.
- **Hospital comparison** (1.0.1.0) is a league table in one panel: hospitals are rows, ranked; the columns drill **Pillar › Objective › KPI**. Level 1 shows Overall and the four pillars, ranked by the overall score; clicking a pillar header shows that pillar's score and one column per objective ("F1 · Revenue"), ranked by the pillar score; clicking an objective header shows the objective's score and one column per KPI, ranked by the objective score. A breadcrumb ("All pillars › Financial › F1 · Revenue") goes back up. The level is the visual's own state (no host selection, like the board's objective picker): it survives a data refresh and goes back to the top when its pillar or objective is no longer in the data.
- The objective score is the weighted mean of the objective's KPI scores for that hospital, the same rule as the pillar score (KPIs with a score and a weight above 0).
- Ranking uses the shown (rounded) score: equal scores share the rank and are listed by hospital name; a hospital without a score at that level is listed last with "–". The peer median is the median score of the other hospitals at that level. The focus-hospital highlight and the hospital line above the table of 1.0.0.0 are gone: the Overall column and the ranking replace them.
- Overall, pillar and objective cells are tinted and marked (circle, diamond, square) by their rounded score with the visual's thresholds; they are not drill sources. KPI cells show the score with the KPI state's mark and tint, and "actual / target" in the KPI's value format. The legend repeats the marks.
- Comparison cells read "<hospital>: <column> <score> · <state>" to a screen reader and in the hover title (KPI cells add actual / target); no-data cells read "No data yet". Drill headers and breadcrumb links are buttons (Tab, then Enter or Space); after a keyboard drill the focus moves to the breadcrumb's last link, and after going up to the header drilled from.
- Comparison KPI cells take the click (cross-filter), the right-click menu (drill-through to KPI Detail) and the tooltip for that KPI and hospital; "–" cells do nothing.
- The comparison leaves out a branch with no KPI score at all (Head Office, a hospital outside the period); the visual-level filter on `'Branch'[Is Hospital]` keeps such branches out of the query too.
- With the header band switched on and several hospitals, it reads "<n> hospitals · <period>"; with one, that hospital's label.
- **Owner view** (1.0.3.0) is the old report's ownership overview. A row of cards (wrapping when there are many) has one card per owner, each a gauge labelled **Achievement** in % with a state chip; three toggles in the visual pick what it shows: **Score** Weighted (default) or On-target, **Owners** C-Suite (default: CEO, COO, CMO, CFO, CHRO, CIO, CSO) or All owners, **KPI list** Owned + co-owned (default, 1.0.3.2) or Owned. A card always counts the owner's owned and co-owned KPIs, as the old report's cards did; the KPI list toggle changes only the blocks below (Owned + co-owned lists each KPI under its owner and, tagged "co-owner", under each co-owner; Owned lists each owner's own KPIs only). Cards run C-suite first in that order, then the other owners by name; anyone who owns or co-owns a KPI has a card. The toggles and the picked card are the visual's own state (no host selection) and survive a data refresh; a picked owner whose card leaves the strip is dropped.
- Below the strip, every owner's KPI block is listed; clicking a card shows only that owner's block (a second click shows every owner again). Under Owned, a picked co-owner who owns nothing gets a line pointing to Owned + co-owned. KPI rows keep the click, right-click drill-through, tooltip and keyboard focus. Cards and toggles are buttons (Tab, then Enter or Space), and focus stays on them after the re-render.
- **Weighted** is the weighted mean of the owner's KPI *unit scores*, weights = the KPI weight (payload field 6); a KPI without a unit score or a weight above 0 is left out. Unit score, as the handover's `_v9KpiUnitScore` (no cap): higher actual / target (target > 0); lower target / actual (both > 0); ceiling 1 at or under the target, else target / actual; on target max(0, 1 − |actual − target| / |target|); a budget variance (name contains "budget variance", or lower with target 0) 1 − (actual − target), values above 1.5 read as percentages, at or below 0 becomes 0.01. A unit at or below 0, or a KPI without actual and target (or parked / no data), is not scored. The handover also scored /readmission/ names as ceiling; here the configured direction decides.
- **On-target** is the share of the owner's judgeable KPIs (actual and target present) whose direction-adjusted variance (payload field 3) is 0 or more (higher, lower, ceiling). An on_target KPI's variance is −|actual − target|, never above 0, so it counts as on target when its state is On track (score at or above the good threshold).
- Achievement states: 100% and over On track, 85–99% Watch, under 85% At risk, on the rounded value (the gauge colour and the chip); the arc stops at 100% (the target marker), the number does not. "–" when the owner has nothing scored or judged.
- If the Branch well is filled on an overview, board or owner page, those views show the first hospital only, and a line at the top of the view says so.
