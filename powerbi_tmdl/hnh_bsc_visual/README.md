# HNH Balanced Scorecard visual

## API version

- `powerbi-visuals-tools`: 7.2.1 (installed globally 2026-10-21)
- `powerbi-visuals-api` candidate: 5.11.1 (the version `pbiviz new` wrote; probe packaged with it on 2026-10-21)
- Fallbacks, newest to oldest: 5.11.0, 5.10.0, 5.9.1, 5.9.0, 5.8.0, 5.7.0, 5.6.1, 5.6.0, 5.4.0, 5.3.0, 5.2.0, 5.1.0 (5.1+ offers `formattingModel`)
- Target runtimes: Power BI Desktop for Report Server May 2026 (2.154) and Power BI Report Server 1.26.9637
- **Confirmed in Desktop for Report Server and on the report server: pending (Task 1 Step 5)**

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

The model is `HNH_Analytics` (perspective `Balanced Scorecard`). Every page binds the same wells:

| Well | Field |
|---|---|
| the 21 attribute roles (KPI Code, KPI Name, Short Label, Pillar, Pillar Order, Pillar Weight, Pillar Question, Objective Code, Objective Title, Objective Order, KPI Type, Direction, Value Format, Display Order, Status, Value Source, Owner, Score Base, Score Slope, Good From, Watch From) | the matching `'BSC KPI'` columns |
| Payload | `[BSC Visual Payload]` |
| Selection label | `[BSC Selection Label]` |
| Hospital (comparison mode only) | `'Branch'[Branch Name]` |

Then, per page, set Format pane > Scorecard > View:

| Page | View | Also |
|---|---|---|
| BSC landing | Overview | |
| Financial, Customer, Internal Process, Learning & Growth | Pillar board | page filter on `'BSC KPI'[Pillar]` |
| Owner view | Owner view | |
| Hospital Comparison | Hospital comparison | slicer on `'Branch'[BSC Category]` |

The drill-through page (KPI Detail) takes `'BSC KPI'[KPI Code]` as its drill-through field.
