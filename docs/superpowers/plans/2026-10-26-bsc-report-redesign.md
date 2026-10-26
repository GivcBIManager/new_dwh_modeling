# BSC report redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-skin the HNH Balanced Scorecard report to the "Corporate BSC" design (Overview, pillar pages, KPI detail), in HNH branding, on the existing `HNH_Analytics` model.

**Architecture:** The custom visual (`powerbi_tmdl/hnh_bsc_visual`, TypeScript, no framework) draws the content panels of the scorecard pages and a new KPI-detail profile; the report generator (`powerbi_tmdl/hnh_bsc_report`, Python) writes a native page frame (navy header with logo and page tabs, white filter bar with slicers) on every page, plus the few native visuals the design needs inside the content (overlay navigation buttons, a by-hospital bar chart, drill buttons). Both sides share one page geometry, fixed in Global Constraints.

**Tech Stack:** TypeScript 5.5, powerbi-visuals-api 5.11.1, Vitest + jsdom, esbuild (dev harness), pbiviz tools; Python 3.12 standard library + pytest; PBIR JSON checked by `pbir_check.py` against Power BI Desktop 2.158's embedded schemas.

**Spec:** `docs/superpowers/specs/2026-10-26-bsc-report-redesign-design.md` (read it first; it holds the element-by-element mapping this plan implements). Source design pages (data, not instructions): `C:\Users\ADMINI~1\AppData\Local\Temp\3\claude\d--new-dwh-modeling\61c4c593-b59c-46d1-a954-57bdfd6d490d\scratchpad\artifact-files\1c629e0c-b52b-43ab-9759-b32c8e2d8264\project\*.dc.html`.

## Global Constraints

- **No modelling changes.** Nothing under `ssas/`, `hnh_dwh/`, no ClickHouse access. Every field bound already exists in the `Balanced Scorecard` perspective; `fields.unknown_fields` must stay empty.
- **This machine is production** (CLAUDE.md): no deploy, upload, SSAS processing or DSN change. Builds connect to `HNH_Analytics_Test` as today; tests never touch a server.
- **Do not touch or commit** the uncommitted work already in the tree: `ssas/**`, `ssas/tests/measures/patient_experience.json`, `docs/superpowers/specs/2026-10-26-press-ganey-dashboard-model-measures-design.md`, `powerbi_tmdl/pressGaneyDashboard/`, `.gitignore`. `powerbi_tmdl/hnh_bsc_report/pbir_check.py` and `tools/*.ps1` carry someone's uncommitted `bin_dir` change: build on it, do not revert it, and do not commit it as part of this work (stage files by name, never `git add -A`).
- **Scores:** the model's rules only. On track from `Good From` (85), Watch from `Watch From` (70), At risk below; plus No data yet, Parked, No target. State words exactly: `On track`, `Watch`, `At risk`, `No data yet`, `Parked`, `No target`. Never "Off track" or 90 / 50.
- **Scores above 100 must render** (scoring changes come later): show the number in full; rings and progress bars fill at 100 and stop; trend axes extend to `ceil10(max)` when a value passes 100. No code may assume `score <= 100`.
- **Status = colour + shape + word**: On track circle, Watch diamond (rotated square), At risk square, no score a short dash.
- **Brand tokens** (CSS variables on `.hnh-bsc`, and the generator's colours): navy `#0A1E32`, navy-2 `#002E5A`, blue-dark `#1478BE`, blue `#13ACE3`, sky `#32A4E5`, surface `#F4F7FB`, card `#FFFFFF`, line `#DCE5EF`, muted `#5B6B7D`, ink `#0A1E32`, track `#E6EBF0`, tab text `#C3CEDB`, slicer border `#CBD3DC`; good `#0E9F8E` / text `#08776B` / bg `#E3F6F3`; warn `#EF8B00` / `#A35F00` / `#FFF2E0`; bad `#DB280A` / `#A81E06` / `#FDE9E5`; nodata `#9AA7B5` / `#5B6B7D` / `#EEF2F6`; missed-bar `#F5B865`; row highlight `#E8F2FA`.
- **Pillar colours** (by `Pillar Order` 1–4, format-pane defaults): `#002E5A`, `#1478BE`, `#13ACE3`, `#6E8196`; fallback `#1478BE`.
- **Type:** `"Segoe UI", system-ui, sans-serif`; numbers `font-variant-numeric: tabular-nums`, weight 600. Design px × 1.5 (design 13 px → 19.5 px; 11 → 16.5; 14 headings → 21; 34 big numbers → 51).
- **Page geometry** (page px, 1920 × 1080, design × 1.5). One module owns it in the generator (`frame.py`, Task 7); the visual's CSS uses the same numbers inside its own box:
  - Header bar `(0, 0, 1920, 84)` navy. Filter bar `(0, 84, 1920, 78)` white with a 1 px `#DCE5EF` rule at y 161.
  - Content box `CONTENT = (30, 186, 1860, 870)` (ends at y 1056).
  - Overview, inside the visual (origin = content box): top row height 348; overall panel width 450; gap 24; four pillar cards of width `(1860 - 450 - 24 - 3*24) / 4 = 328.5`, card i at x `474 + i * 352.5`; bottom row from y 372, "Needs attention" width 630 on the right.
  - Pillar board, inside the visual: summary strip height 96; gap 21; body from y 117 to 870; table x 0–1176; panel x 1200–1860 (width 660). Panel: visual content in its top 432 px; reserved "By hospital" slot at panel-relative `(24, 432, 612, 219)`; reserved drill-button slot at `(24, 669, 612, 60)`. Page coordinates: chart `(1254, 735, 612, 219)`, button `(1254, 972, 612, 60)`.
  - KPI detail: the visual covers `(0, 84, 1920, 996)` and draws the white sub-bar (its first 78 px) and, from y 102 inside it (page y 186), the profile panel `(30, 102, 510, 870)` and the trend panel `(564, 102, 1326, 390)` in its own coordinates; Back button `(30, 96, 110, 54)` page; native lower row page `(564, 600, 639, 456)` (by hospital) and `(1227, 600, 663, 372)` (matrix) with Open detail `(1227, 984, 663, 60)`.
- **Copy:** labels this repo defines are not title-cased (CLAUDE.md applies to dbt marts only); KPI names come from the model as they are.
- Visual version `1.1.0.0` (package.json, pbiviz.json). Commit messages: `BSC visual 1.1.0.0: …` / `BSC report: …`, ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A pillar with 26 KPIs (Internal Process)** — the scorecard table must scroll inside its panel with the header row fixed, never push the panel or page; test in Task 4 asserts the table body has `overflow-y: auto` and a fixed header.
2. **A KPI with no target, parked, or no data in the selected-KPI panel and in Needs attention** — the panel shows the state chip and reason with "–" values and no bars or bands; Needs attention never lists them. Tests in Tasks 3–5.
3. **A selection label without a month** ("No hospital", or an empty period) — month labels are left out, nothing crashes, trends still draw. Test in Task 2 (`monthLabels`) and Task 3.
4. **Host selection of two KPIs (Ctrl+click) on a pillar page** — the panel shows "Select a KPI…" (it describes one KPI only), the native chart shows whatever Power BI shows for two; test in Task 4.
5. **Score above 100 or below 0 in a payload** — ring, progress bar and trend axis stay inside their boxes and the number prints in full (Global Constraints); tests in Tasks 3 and 4.

---

### Task 1: Visual — brand tokens, pillar colours, status marks, header off

**Files:**
- Modify: `powerbi_tmdl/hnh_bsc_visual/style/visual.less` (tokens, chip and mark styles; remove nothing the owner/comparison views still use)
- Modify: `powerbi_tmdl/hnh_bsc_visual/src/settings.ts`, `capabilities.json` (`colours` gains `pillar1`–`pillar4`; `scorecard.mode` gains `detail`)
- Modify: `powerbi_tmdl/hnh_bsc_visual/src/render/chips.ts`
- Test: `test/settings.test.ts`, `test/tile.test.ts` (chip tests move to a new `test/chips.test.ts`)

**Interfaces:**
- Produces: `stateMark(key: StateKey): HTMLElement` → `<span class="mark {good|warn|bad|nodata}" aria-hidden="true">` (CSS draws circle / diamond / square / dash); `stateChip(key, word, text?)` now = `<span class="chip {cls}">` + `stateMark(key)` + text (no ✓ ! ▼ icons; `ICON` stays exported for the tooltip and owner view if they use it); `pillarColourVar(order: number): string` → `"var(--p1)"`…`"var(--p4)"`, `"var(--blue-dk)"` otherwise; `Mode` gains `"detail"`; `VisualSettings.colours.pillar1..pillar4`; `applyColours` writes `--p1..--p4`; `showHeader` default `false`.

- [ ] **Step 1: Write the failing tests** — `settings.test.ts`: defaults `pillar1..4 = #002E5A, #1478BE, #13ACE3, #6E8196`, `showHeader === false`, mode items include `{value: "detail"}`; `applyColours` sets `--p3` to `#13ACE3`. `chips.test.ts`: `stateChip("warn", "Watch").querySelector(".mark.warn")` exists and `textContent === "Watch"`; `stateChip("parked", "Parked", "3")` has class `chip nodata`, text `"3 Parked"`; `pillarColourVar(2) === "var(--p2)"`, `pillarColourVar(9) === "var(--blue-dk)"`.
- [ ] **Step 2: Run** `npm test -- settings chips` (in `powerbi_tmdl/hnh_bsc_visual`). Expected: FAIL.
- [ ] **Step 3: Implement** the settings, capabilities objects and enumeration, `chips.ts` changes, and the LESS tokens of Global Constraints (keep `--hdr-*` for the optional band). `.mark` is 10.5 px; diamond = `transform: rotate(45deg)` at 9 px; dash = 10 × 3 px.
- [ ] **Step 4: Run** `npm test`. Expected: the new tests pass; fix the existing tests that asserted the old icon text in chips (owner/tile tests) to the new text, nothing else.
- [ ] **Step 5: Commit** `BSC visual 1.1.0.0: HNH tokens, pillar colours, status marks, header off by default`.

### Task 2: Visual — model helpers and the three new field wells

**Files:**
- Create: `src/model/months.ts`, `src/model/bands.ts`
- Modify: `src/model/types.ts`, `src/model/parse.ts`, `src/model/score.ts`, `capabilities.json` (roles + mapping), `test/fixtures.ts` (`CATEGORY_ROLES` + `definition`; value columns `targetBasis`, `manualNote` when present on a row)
- Test: `test/months.test.ts`, `test/bands.test.ts`, `test/parse.test.ts`, `test/score.test.ts`

**Interfaces:**
- Produces:
  - `KpiRow` gains `definition: string`, `targetBasis: string`, `manualNote: string`, `scoreBase: number`, `scoreSlope: number`, `goodFrom: number`, `watchFrom: number` (per row; fall back to 85 / 0.6 / 85 / 70 when blank).
  - Roles: `definition` (Grouping, displayName "Definition"), `targetBasis` (Measure, "Target basis"), `manualNote` (Measure, "Manual note"); each `max: 1`, mapped like `owner` and `payload`.
  - `monthLabels(label: string, n: number): string[]` — the last `MMM yyyy` in the label is the end month; returns n three-letter English month names ending there (`"Corporate · Jan 2026 – Sep 2026"`, 12 → `["Oct", …, "Sep"]`); `[]` when the label has no month.
  - `lastDelta(trend: (number|null)[]): number | null` — `trend[n-1] - trend[n-2]` when both are finite, else null.
  - `overallTrend(pillars: PillarSummary[]): (number|null)[]` — per month, the pillar-weighted mean of `pillar.trend[i]` (same `weighted` rule as `overallScore`).
  - `varianceOf(actual: number, target: number, direction: string): number` — the model's `BSC Variance %`: diff = higher `A−T`, on_target `−|A−T|`, lower/ceiling (and anything else) `T−A`; `T === 0 ? diff : diff / |T|`.
  - `kpiScoreOf(row: KpiRow, actual: number, target: number): number` — `Math.round(row.scoreBase + row.scoreSlope * 100 * varianceOf(...))`, **not clamped** (the model clamps today; see Global Constraints).
  - `met(row, actual, target): boolean` — `kpiScoreOf(...) >= row.goodFrom`.
  - `bandEdges(row: KpiRow, target: number): { kind: "above" | "below" | "around"; good: number; watch: number } | null` — with `vg = (goodFrom − scoreBase) / (scoreSlope × 100)`, `vw = (watchFrom − scoreBase) / (scoreSlope × 100)`, `s = |T|` (1 when T = 0): higher `above`, good `T + vg·s`, watch `T + vw·s`; lower/ceiling `below`, good `T − vg·s`, watch `T − vw·s`; on_target `around`, half-widths good `max(0, −vg·s)`, watch `max(0, −vw·s)`. Null when `scoreSlope` is 0 or the target is not finite.

- [ ] **Step 1: Write the failing tests** — `monthLabels("Corporate · Jan 2026 – Sep 2026", 12)` → starts `"Oct"`, ends `"Sep"`, length 12; `monthLabels("Hospital A · Mar 2026", 3)` → `["Jan","Feb","Mar"]`; `monthLabels("No hospital", 12)` → `[]`. `lastDelta([80, null, 82, 84.5]) === 2.5`; `lastDelta([80, null]) === null`. `bandEdges` with base 85, slope 0.6, good 85, watch 70: higher T 100 → `{above, good: 100, watch: 75}`; lower T 0.05 → `{below, good: 0.05, watch: 0.0625}`; on_target T 4 → `{around, good: 0, watch: 1}`; slope 0 → null. `kpiScoreOf` higher A 120 T 100 → 97; A 300 T 100 → 205 (unclamped). `met` lower A 4 T 5 → true. `parseDataView` reads `definition`, `targetBasis`, `manualNote` and the four per-row thresholds; blank thresholds fall back to 85 / 0.6 / 85 / 70. `overallTrend` of two pillars (weights 0.3, 0.7; trends `[80, 90]`, `[60, null]`) → `[66, 90]`.
- [ ] **Step 2: Run** `npm test -- months bands parse score`. Expected: FAIL.
- [ ] **Step 3: Implement** in the files above.
- [ ] **Step 4: Run** `npm test`. Expected: PASS.
- [ ] **Step 5: Commit** `BSC visual 1.1.0.0: month labels, deltas, performance bands, definition and note wells`.

### Task 3: Visual — Overview

**Files:**
- Rewrite: `src/render/overview.ts`; Create: `src/render/ring.ts`, `src/render/linechart.ts`
- Modify: `style/visual.less` (`.ov*` rules), `src/interactions.ts` (only if the Needs attention rows need nothing beyond `[data-key]`; they should not)
- Test: `test/modes.test.ts` (overview block), `test/visual.test.ts` ("payload without trends" block)

**Interfaces:**
- Consumes: Task 1 `stateChip`, `stateMark`, `pillarColourVar`; Task 2 `monthLabels`, `lastDelta`, `overallTrend`.
- Produces: `overview(vm: ViewModel): HTMLElement` with this DOM contract (the generator's overlay buttons and the tests rely on it): `.ov` grid `grid-template-columns: 450px repeat(4, minmax(0, 1fr)); grid-template-rows: 348px minmax(0, 1fr); gap: 24px`; `section.ov-overall`; four `article.ov-pillar[data-pillar]` in pillar order (columns 2–5 of row 1); `section.ov-trend` (row 2, columns 1–4 minus the attention width) and `section.ov-attention` (row 2, width 630 px, right). `ring(score: number|null, size: number, label: string): SVGSVGElement` — full circle, navy arc on track `#E6EBF0`, fills `min(max(score,0),100)/100`, aria-label `"<label> <shown> of 100"`. `lineChart(series: {name: string; colourVar: string; values: (number|null)[]}[], opts: {months: string[]; target: number; width: number; height: number}): SVGSVGElement` — y from `min(floor10(minValue) - 0, target - 10)` clamped at ≥ 0 to `max(100, ceil10(maxValue))`, gridlines every 10, dashed target line, a dot and the series name at each line's last point.

Overview content, exactly as the spec's Overview table: overall panel (h2 "Overall BSC score", "Weighted · 4 pillars", ring 168 px with the rounded score and "of 100", chip, `▲ 0.3 vs Aug` from `lastDelta(overallTrend)` with `monthLabels(...)[n-2]`, "Target 85 · gap 10.2" from `thresholds.good`, a 12 px distribution bar of On track / Watch / At risk / No data counts with the counts and words under it); pillar card (colour square `pillarColourVar(order)`, name, "Weight 30%"; 51 px score + chip; 9 px progress bar to `min(score,100)` with a 3 × 18 px navy marker at `good`; 60 px area sparkline of `pillar.trend`; counts with marks and the delta; "Drill into N KPIs →" in the pillar colour); trend panel ("Pillar score trend · last 12 months", legend with the four pillars and "Target 85"); Needs attention (rows = At-risk KPIs of the first-branch rows, ascending score, at most what fits: 6 rows of 66 px; each row a `[data-key][data-series]` element with tabindex 0: name, pillar mark + name, actual in `--bad` text colour, `target ≥ x` / `≤ x` / `≈ x`; badge "N at risk"; footer "N more KPIs are on watch. Open a pillar to review them." when Watch > 0).

No trends (the Scores payload): no sparkline, no delta, no `.ov-trend`; `.ov-attention` spans the whole second row.

- [ ] **Step 1: Write the failing tests** (replace the old overview tests): four `.ov-pillar` in order Financial, Customer, Internal Process, Learning & Growth; `.ov-overall` text contains `"of 100"` and `"Target 85"`; the distribution counts match the fixture (On track 3, Watch 2, At risk 1); Needs attention lists only the At-risk KPI (`F1`) and its row carries `data-key`; a parked or no-data KPI is never listed; with a score of 112 the ring's arc `stroke-dasharray` equals the full circumference and the text shows `112`; with trends the `.ov-trend svg path` count ≥ 4 and the delta text matches `/[▲▼] \d+\.\d vs [A-Z][a-z]{2}/`; with scores-only payloads `.ov-trend` is absent and no `.spark`; with label `"No hospital"` the chart has no month labels and does not throw.
- [ ] **Step 2: Run** `npm test -- modes visual`. Expected: the new overview tests FAIL.
- [ ] **Step 3: Implement** `ring.ts`, `linechart.ts`, `overview.ts`, the `.ov*` CSS.
- [ ] **Step 4: Run** `npm test`. Expected: PASS.
- [ ] **Step 5: Commit** `BSC visual 1.1.0.0: Overview in the Corporate BSC layout`.

### Task 4: Visual — pillar board (strip, scorecard table, objective picker, selected-KPI panel)

**Files:**
- Rewrite: `src/render/board.ts`; Create: `src/render/scorecard.ts` (table), `src/render/kpipanel.ts` (panel), `src/render/bars.ts` (monthly bars)
- Delete: `src/render/tile.ts`, `test/tile.test.ts` (tiles are gone; move any still-useful assertions)
- Modify: `src/visual.ts` (objective pick state; panel follows the host selection), `src/interactions.ts` (`INTERNAL_SELECTOR` gains `select[data-objective-picker]`), `src/render/index.ts` (`UiState.objective: string | null`), `style/visual.less`
- Test: `test/modes.test.ts` (board block), `test/visual.test.ts` (board picks), `test/interactions.test.ts`

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces: `board(vm: ViewModel, wanted: string | null, objective: string | null, selectedKey: string | null): HTMLElement` with DOM contract `.bd` = `section.bd-strip` (height 96) + `.bd-body` grid `grid-template-columns: minmax(0,1fr) 660px; gap: 24px` of `section.bd-table` and `section.bd-panel`. `section.bd-panel` has `.bd-panel-main` (height 432) then `.bd-slot-chart` (219 px, empty) and `.bd-slot-button` (60 px, empty), so the native chart and button sit over the empty slots. `scorecardTable(rows: KpiRow[], selectedKey: string|null, colourVar: string): HTMLElement`: a header row, then a scroll body (`overflow-y: auto`) of rows; each row is `div.bd-row[data-key][data-series][tabindex=0]` with seven cells: chip, name + objective (reason instead for unscored), actual, target with ≥/≤/≈, variance (`formatVariance`, coloured by state), rounded score, 156 × 42 sparkline. `kpiPanel(row: KpiRow | null, months: string[], colourVar: string): HTMLElement`. `monthlyBars(row: KpiRow, width: number, height: number, colourVar: string): SVGSVGElement`: one bar per month of `row.trend`, met (`met(row, a, t)` with that month's `targetTrend`) in the pillar colour, missed in `#F5B865`, the monthly targets as a dashed step line.
- `Visual` keeps `pick.objective: string | null` (reset to null when the pillar changes or the objective disappears) and renders the board with `selectedKey` = the single host-selected row's key, or null when zero or several are selected. `WireHost` gains `onSelected?: () => void`, which `wire` calls after every `select` / `clear` promise resolves (the host's `registerOnSelectCallback` fires only for selections made outside the visual, such as bookmarks); `Visual` passes `() => this.refreshSelection()`, and `refreshSelection()` re-renders in board mode (so the panel follows clicks, Ctrl+clicks and clears), keeping keyboard focus on the row that had it. Rows of manual KPIs carry a small "Manual" tag after the name.

Strip content (spec): "Overview › Financial" text, pillar mark + name (h1, 30 px), "Pillar score" + 36 px score + chip, "vs Aug" delta, "Weight 30%", "KPI status" counts with marks (On track, Watch, At risk, No data), and the pillar question right-aligned (muted, max two lines). The objective picker is a `<select data-objective-picker aria-label="Objective">` in `.bd-table`'s heading row ("KPI scorecard", hint "Select a KPI to update the panel · right-click › Drill through for full detail", then the select with "All objectives" + one option per objective of the pillar in objective order); it narrows the rows only. Row order: objective order, primary first, display order. Empty panel text: "Select a KPI in the table to see its monthly trend and hospitals".

- [ ] **Step 1: Write the failing tests** — the strip shows the pillar's name, weight `30%`, and a status count line containing `On track`; with an objective picked the strip's score is unchanged and the table lists only that objective's rows; the table has seven header cells (`Status`, `KPI · objective`, `Actual`, `Target`, `Variance`, `Score`, `12-mo trend`) and the body has `overflow-y: auto` in the stylesheet (`layout.test.ts` style check, as the existing layout tests read `visual.less`); a lower-is-better row shows `≤` before its target; a parked row shows the `Parked` chip, `–` for actual and no sparkline; `selectedKey` null → panel text "Select a KPI in the table…"; a selected row gets class `selected` and the panel shows its name, objective and direction note, and `monthlyBars` draws one bar per month, the missed ones filled `#F5B865`; a score of 130 prints `130` in the score cell; `Visual`: a click on a row calls `selectionManager.select` and, after the select callback, the panel shows that row; two selected ids → empty panel; changing the `<select>` re-renders without a host selection and keeps the pick across a plain update; a vanished objective resets the pick; `.bd-slot-chart` and `.bd-slot-button` exist and are empty.
- [ ] **Step 2: Run** `npm test -- modes visual interactions layout`. Expected: FAIL.
- [ ] **Step 3: Implement** the files above; delete the tile renderer and its test.
- [ ] **Step 4: Run** `npm test`. Expected: PASS.
- [ ] **Step 5: Commit** `BSC visual 1.1.0.0: pillar board as a KPI scorecard with a selected-KPI panel`.

### Task 5: Visual — KPI detail mode

**Files:**
- Create: `src/render/detail.ts`; Modify: `src/render/index.ts` (mode `detail`), `style/visual.less`
- Test: `test/detail.test.ts`

**Interfaces:**
- Consumes: Tasks 1–2 (`bandEdges`, `monthLabels`, `met`), Task 3 `lineChart` is not reused (the band chart differs).
- Produces: `detail(vm: ViewModel): HTMLElement` for the first first-branch row (the drill-through leaves one KPI), DOM: `.dt-sub` (78 px white band; its text stays between x 150 and x 1570, clear of the native Back button on its left and the How to use / Calculations buttons on its right: the breadcrumb "Overview › <pillar> › <KPI name>" and chips split from `vm.label` — the KPI name, the period, the hospital part), then `.dt-body` with `section.dt-profile` (510 px wide) and `section.dt-trend` (390 px high), leaving the lower right empty for native visuals. `bandChart(row: KpiRow, months: string[], width: number, height: number): SVGSVGElement` — per month, three shaded bands from `bandEdges(row, targetTrend[i])` (On track `#E3F6F3`, Watch `#FFF2E0`, At risk `#FDE9E5`; `around` draws a centred band), the actual line in `--blue-dk` with dots, the dashed monthly target.

Profile content (spec, "KPI detail"): pillar mark · pillar · objective; KPI name (h1 30 px); 66 px actual in the state's text colour; chip; "Target x · variance · score n"; definition list Definition, Better when, Target basis, Weight, Owner, Co-owners, Source ("Manual entry" / "Calculated"); "Performance bands" in KPI units via `formatValue` (`above`: "On track ≥ g", "Watch w – g", "At risk < w"; `below` mirrored with ≤ / >; `around`: "On track within ± g", "Watch within ± w", "At risk beyond ± w"); for a manual KPI with a note, "Manual entry note" and the note. More than one KPI in the data: render the first and add the hint line "Showing <name>; open KPI detail from one KPI".

- [ ] **Step 1: Write the failing tests** — breadcrumb text `"Overview › Financial › F1 name"`; chips include the KPI name and `"Jan 2026 – Sep 2026"`; the profile lists `Definition` with the fixture's definition and `Target basis` with its value; a higher KPI with target 0.5 (pct) shows "On track ≥ 50.0%" and "At risk < 37.5%"; an on-target KPI shows "within ±"; no target → no "Performance bands" heading and no band paths; a manual KPI's note is shown; the band chart has 12 × 3 band rects for a 12-month trend.
- [ ] **Step 2: Run** `npm test -- detail`. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `npm test`. Expected: PASS.
- [ ] **Step 5: Commit** `BSC visual 1.1.0.0: KPI detail mode (profile, bands, trend)`.

### Task 6: Visual — owner view and comparison restyle, harness, package

**Files:**
- Modify: `style/visual.less` (owner and comparison rules to the panel style: white, 1 px line, radius 12, 21 px headings, chips with marks), `src/render/owner.ts` and `src/render/comparison.ts` only where markup must change for the chips
- Modify: `dev/harness.ts` (modes `overview`, `overview-scores`, `board` with `?select=<code>` and `?objective=`, `detail`, the owner and comparison shots; fixture rows get definitions, a target basis, a manual note, one score of 112), `dev/screenshot.ps1` (window 1860 × 870 for overview/board/owner/comparison, 1920 × 996 for detail; drop the 1280 × 720 and prototype shots; add a `design` loop that screenshots the source design pages if their folder exists, for side-by-side review)
- Modify: `package.json`, `pbiviz.json` (1.1.0.0), `README.md` (field wells table: the three new wells on KPI detail; per-page View table: KPI detail = Detail; design notes rewritten to the new layout)
- Test: existing owner / comparison / highcontrast / package tests

- [ ] **Step 1: Run** `npm test`; restyle; run again. Expected: PASS (adjust only assertions about removed icon text).
- [ ] **Step 2: Run** `powershell -ExecutionPolicy Bypass -File dev\screenshot.ps1`. Expected: one PNG per shot in `dev/out/`; open them next to the design screenshots and fix visible layout differences (proportions, spacing, overflow, text clipping) before moving on.
- [ ] **Step 3: Run** `npx pbiviz package` and `npm run lint`. Expected: `dist/hnhBscVisual431F658EE9D44EA3BD5E1BEA5FAF899D.1.1.0.0.pbiviz`; lint clean.
- [ ] **Step 4: Commit** `BSC visual 1.1.0.0: owner and comparison restyle, harness, README` (no `dist/`, no `dev/out/`).

### Task 7: Report generator — panel and image visuals, the logo, the frame module

**Files:**
- Create: `powerbi_tmdl/hnh_bsc_report/frame.py` (geometry constants of Global Constraints; `frame(page_name: str | None, filters: list[Visual]) -> list[Visual]`)
- Create: `powerbi_tmdl/hnh_bsc_report/theme/hnh_logo_white.png` (from `branding/الحياة للرعاية الصحية-08.png`, cropped to its non-transparent bounding box plus 2 % padding, scaled to 600 px wide; made once with PowerShell `System.Drawing`, script `tools/crop_logo.ps1`, committed with the PNG)
- Modify: `pbir.py` (`VISUAL_TYPES` gains `"panel": "textbox"` and `"image": "image"`; report.json registers the logo as `{"name": "hnh_logo_white.png", "path": "hnh_logo_white.png", "type": "Image"}`; the PNG is written to `StaticResources/RegisteredResources/`), `layout.py` / `build.py` (the pbix fallback drops `panel` and `image` visuals with a printed note, spec "Legacy template fallback"), `model.py` (`Visual.sample` doc lists the new kinds), `theme/hnh_bsc_theme.json` (spec "Theme": page background `#F4F7FB`; visualStyles `*` background white, border `#DCE5EF` radius 12; dataColors = the four pillar colours then `#13ACE3`, `#32A4E5`, `#0E9F8E`, `#EF8B00`; good/neutral/bad)
- Test: `tests/test_pbir.py`, new `tests/test_frame.py`

**Interfaces:**
- Produces: `panel(x, y, w, h, colour: str, radius: int = 0) -> Visual` (a textbox with no paragraphs, container `background` show/colour/transparency 0, `border` show false or radius, `visualHeader` off); `image(x, y, w, h) -> Visual` (the logo; objects as the handover's image visual: `image.sourceFile.image.{name, url: ResourcePackageItem(RegisteredResources, PackageType 1, ItemName "hnh_logo_white.png"), scaling 'Fit'}`); `tab_button(page_name, label, x, w, current: bool) -> list[Visual]` (an actionButton PageNavigation with no fill or a white-8 % fill when current, label `#C3CEDB` / white; plus, when current, a 4 px `#13ACE3` panel under it); `TABS: list[tuple[str, str]]` = `[("bsc", "Overview"), ("financial", "Financial"), ("customer", "Customer"), ("internal_process", "Internal Process"), ("learning_growth", "Learning & Growth"), ("owner_view", "Owner view"), ("hospital_comparison", "Hospital comparison")]`, right-aligned to x 1890 with width `42 + 10.5 × len(label)` each and 3 px gaps; `frame(current: str | None, filter_visuals: list[Visual], filter_bar: bool = True) -> list[Visual]` = header panel, logo `(30, 21, 220, 42)`, title text box `(270, 12, 370, 60)` with "Balanced Scorecard" (Segoe UI Semibold 19pt white) and "Hayat Healthcare" (12pt `#C3CEDB`), the tabs, the filter-bar panel and its rule (left out when `filter_bar` is False: KPI detail's visual draws that band itself), `filter_visuals`, and the outline buttons "How to use" `(1590, 96, 140, 54)` and "Calculations" `(1745, 96, 145, 54)` styled for the white bar; `CONTENT`, `OV_CARDS: list[tuple[float, float, float, float]]` (the four card rects in page px), `BOARD_CHART`, `BOARD_BUTTON`, `DETAIL_*` rects.

- [ ] **Step 1: Write the failing tests** — `test_frame.py`: tabs fit between x 664 and 1890 and do not overlap the title box; exactly one tab has the current style on a scorecard page and none when `current` is None; `OV_CARDS[0] == (504, 186, 328.5, 348)` and `OV_CARDS[3][0] == 504 + 3 * 352.5`; `BOARD_CHART == (1254, 735, 612, 219)`. `test_pbir.py`: report.json lists the logo as an `Image` item; the PNG is written under `StaticResources/RegisteredResources/`; a `panel` visual is a `textbox` with container `background` colour and no paragraphs; the `image` visual's `url` expr is a `ResourcePackageItem` named `hnh_logo_white.png`; `test_report_definition_matches_desktop_schemas` still passes; the pbix route skips both kinds.
- [ ] **Step 2: Run** `python -m pytest powerbi_tmdl/hnh_bsc_report/tests -q -k "frame or pbir"` (repo root). Expected: FAIL.
- [ ] **Step 3: Implement**, then crop the logo with `tools/crop_logo.ps1` (read-only on `branding/`, writes only the theme PNG).
- [ ] **Step 4: Run** the whole suite `python -m pytest powerbi_tmdl/hnh_bsc_report/tests -q`. Expected: PASS (page tests may still describe the old pages; they change in Task 8).
- [ ] **Step 5: Commit** `BSC report: page frame (header, tabs, filter bar), logo and theme` (stage by name; not `pbir_check.py` or `tools/*` other than `crop_logo.ps1`).

### Task 8: Report generator — the pages

**Files:**
- Modify: `powerbi_tmdl/hnh_bsc_report/pages.py`, `tests/test_pages.py`, `tests/test_pbir.py` (page-level expectations)

**Interfaces:**
- Consumes: Task 7 `frame`, `panel`, `TABS`, rects; visual roles from Task 2 (`definition`, `targetBasis`, `manualNote`), mode `detail` from Task 1.
- Produces: `build_pages(build_date) -> list[Page]` unchanged in signature; page names unchanged (`bsc` stays the Overview's internal name; its display name becomes "Overview").

Per page (spec sections; geometry from `frame.py`):
- **Scorecard pages:** `frame(name, _slicers(build_date))` with the three slicers at Hospital `(30, 96, 330, 54)`, BSC Category `(375, 96, 270, 54)`, Date `(660, 96, 420, 54)` (dropdown look: header 11pt muted, border `#CBD3DC`, radius 6); the selection-label card `(1100, 99, 470, 48)` (`[BSC Selection Label]`, 12pt muted, no category label, transparent background). The HNH visual at `CONTENT`, `showHeader` false. Overview: payload `BSC Visual Payload` (spec decision), mode overview, plus four transparent page-navigation buttons at `OV_CARDS` to the four pillar pages (no fill, no outline, no label, tooltip "Open <pillar>"). Pillar pages: mode board; the "By hospital" bar chart at `BOARD_CHART` (`[BSC Actual]` by `'Branch'[Branch Name]`, hospitals only, sorted desc, title "By hospital", no axis titles, data labels on, no visual background: it sits on the visual's panel); a drill-through button at `BOARD_BUTTON` to `kpi_detail` labelled "Drill through to KPI detail →", outline in the pillar colour (the four pillar colours of Global Constraints). Owner view and comparison: unchanged roles and payloads, new frame.
- **KPI detail:** `frame(None, [], filter_bar=False)` (no slicers, spec; the page is hidden, so no current tab; the white bar is the visual's own band), then the HNH visual at `(0, 84, 1920, 996)` in mode `detail` with the usual roles plus `definition`, `targetBasis`, `manualNote`; Back `(30, 96, 110, 54)` above it; "By hospital" bar chart `(564, 600, 639, 456)`; the matrix `(1227, 600, 663, 372)` titled "Select a hospital and month, then Open detail"; Open detail `(1227, 984, 663, 60)`. The six cards, the line chart, "About this KPI" and "Manual entry note" tables go. Drill field and keep-all-filters unchanged.
- **Family pages:** the frame's header with no current tab and no filter visuals (keep the filter-bar panel empty apart from Back at `(30, 96, 110, 54)` and the help buttons); the title text box moves to `(30, 186, 1200, 54)` at 22pt; cards and charts shift down so they start at y 258 and stay inside 1056; every card/chart keeps the theme's white panel style. Content and filters unchanged.
- **Guide pages:** the frame (no slicers); text boxes in white panels below y 186; copy updated: "BSC" → "Overview"; "The page buttons at the top right" → "The tabs in the dark bar at the top"; "Right-click a KPI and choose Drill through › KPI detail" stays and adds "On a pillar page, select a KPI in the table to see its monthly trend and hospitals on the right, then Drill through to KPI detail."; the Overview's "Needs attention" list is described in one bullet ("Needs attention lists the KPIs at risk, lowest score first.").
- `test_no_overlaps_and_inside_the_canvas` allows exactly these overlaps: frame panels under the visuals placed on them, the tab underline under its tab, overlay buttons and the board's chart and button over the HNH visual, KPI detail's native visuals over the detail visual. Everything else still may not overlap.

- [ ] **Step 1: Update and write the failing tests** in `test_pages.py`: page order and display names (`Overview` first); every visible page has exactly one current tab, the hidden pages none; scorecard pages bind the three slicers at the frame positions; the Overview binds `BSC Visual Payload` and has four navigation buttons at `OV_CARDS` targeting `financial`, `customer`, `internal_process`, `learning_growth`; each pillar page has the by-hospital chart at `BOARD_CHART` with an `Is Hospital` filter and a drill-through button at `BOARD_BUTTON`; KPI detail binds `Definition`, `BSC Target Basis`, `BSC Manual Note`, mode `detail`, has no slicer, and still drills on `'BSC KPI'[KPI Code]` with keep-all-filters on; family pages keep their drill fields and no slicers, and nothing goes below y 1056; `unknown_fields` is empty; the guide copy contains "Overview" and not "BSC:" as a page name. Keep `test_committed_project_is_current` (it passes after Task 9's rebuild).
- [ ] **Step 2: Run** `python -m pytest powerbi_tmdl/hnh_bsc_report/tests -q`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement** in `pages.py`.
- [ ] **Step 4: Run** the suite. Expected: PASS except `test_committed_project_is_current` and the schema/Desktop tests that need the rebuilt project.
- [ ] **Step 5: Commit** `BSC report: Overview, pillar pages and KPI detail in the Corporate BSC layout; frame on every page`.

### Task 9: Build, check, README

**Files:**
- Modify: `powerbi_tmdl/hnh_bsc_report/README.md` (step 2 page checks rewritten for the new pages, including: the Overview cards open their pillar page; on a pillar page, clicking a KPI row fills the panel and the By hospital chart; **check that the "Drill through to KPI detail" button is enabled after a row click — if it is not, report it: the fallback is to replace it with the visual's hint "Right-click a KPI › Drill through › KPI detail"**; KPI detail shows the profile, bands and trend; scores above 100 show in full; the fallback appendix says the pbix route writes pages without the frame)
- Regenerate: `powerbi_tmdl/hnh_bsc_report/HNH Balanced Scorecard.Report/**` (generated; commit it)

- [ ] **Step 1: Run** `npx pbiviz package` in the visual folder if Task 6's package is stale, then `python powerbi_tmdl/hnh_bsc_report/build.py` from the repo root. Expected: `report schemas: passed`, `Desktop project reader: opened`, exit 0.
- [ ] **Step 2: Run** `python -m pytest powerbi_tmdl/hnh_bsc_report/tests -q` and `npm test` (visual). Expected: all PASS, including `test_committed_project_is_current`.
- [ ] **Step 3: Commit** `BSC report: rebuild the PBIP with visual 1.1.0.0; README page checks` (stage the `.Report` folder, `.pbip`, README; not `pbir_check.py`/`tools/` from the other session).
- [ ] **Step 4: Hand back** the manual Desktop checks to the user (README step 2 onward: open the PBIP in Desktop 2.158, then the Report Server route). Do not upload or deploy.
