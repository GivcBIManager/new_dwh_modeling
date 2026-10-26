# BSC report redesign: the "Corporate BSC" design in HNH branding

Date: 2026-10-26. Status: approved in conversation ("update the design first"); scoring changes follow separately.

## Intent

The user had a Power BI report design made (Design canvas "Corporate BSC — Power BI Report", https://claude.ai/code/artifact/1c629e0c-b52b-43ab-9759-b32c8e2d8264, copied locally from its `project/*.dc.html` files). It shows a denser, more report-like scorecard than today's gauges and tiles: one Overview page, one page per pillar with a KPI table and a selected-KPI panel, and a KPI drill-through page.

The user's words: **apply the exact design, with our branding, on top of the same model, no modelling changes**. The current report (`powerbi_tmdl/hnh_bsc_report`, visual `powerbi_tmdl/hnh_bsc_visual` 1.0.3.2) has not been deployed to anyone, so its pages can be replaced freely; nothing needs to stay backward compatible.

## Source design, page by page

Canvas pages are 1280 × 720 px. Every page has the same frame:

- **Header bar**, 56 px, dark: logo, title "Corporate Balanced Scorecard" with a subtitle line, page tabs on the right (current tab: white text, light fill, 3 px underline).
- **Filter bar**, 52 px, white with a bottom rule: dropdown buttons (label inside, small grey; value bold), then on the right a "Sample data" badge, "Data as of …" and "Reset filters".
- **Content** on a light grey page, in white panels (1 px border, radius 8, 16 px gaps, 14 px headings).

Status everywhere is colour + shape + word: circle = on track, rotated square (diamond) = at risk, square = off track; pill chips with a pale background.

1. **Overview** (`Main.dc.html`). Top row 232 px: an "Overall BSC score" panel (300 px; ring with the score and "of 100", status chip, "▲ 0.3 vs Aug", "Target 90.0 · gap 15.2", a status distribution bar with counts) and four pillar cards (colour square, name, weight; big score + chip; progress bar with a target marker; area sparkline; status counts and a delta; "Drill into N KPIs →", the whole card is a link to the pillar page). Bottom row: "Pillar score trend · last 12 months" (one line per pillar, dashed target, y labels, month labels, a legend) and "Needs attention" (420 px; off-track KPIs: name, pillar, actual in red, target; a count badge; a footer line about the at-risk KPIs).
2. **Pillar pages** (`Financial/Patient/Process/People.dc.html`, identical layout, pillar colour changes). A 64 px summary strip (breadcrumb Overview › pillar, pillar name, pillar score + chip, delta vs previous month, weight, KPI status counts, pillar owner on the right). Then a "KPI scorecard" table (status chip, KPI name with the objective under it, actual, target with ≥/≤, variance, score, 12-month sparkline with an end dot; 52 px rows; the clicked row is highlighted) beside a 440 px "Selected KPI" panel (name, objective · polarity; actual, target, score; "Monthly trend vs target" bars coloured met / missed with a dashed target; "By facility · YTD" bars; a "Drill through to KPI detail →" button). The filter bar adds an "Objective" dropdown.
3. **KPI drill-through** (`KPIDetail.dc.html`). The filter bar is replaced by Back, a breadcrumb (Overview › pillar › KPI) and drill-filter chips. A 340 px profile panel (pillar · objective, KPI name, big actual in its status colour, chip, target / variance / score, a definition list: Definition, Formula, Polarity, Frequency, Source, KPI owner; "Performance bands" in KPI units; "Linked initiative"). On the right: "Monthly trend with performance bands" (actual line over three shaded bands, dashed target, a 12 / 24 months toggle) and two breakdown panels (rejection rate by payer, top rejection reasons).
4. **Build spec** (`BuildSpec.dc.html`): the designer's hand-off (a new star schema, DAX, 90 / 50 scoring, theme, Report Server notes).

## Goals

1. The Overview, the four pillar pages and KPI detail look like the design, element for element, in HNH branding, at the same proportions.
2. Every number comes from the measures and columns the report uses today: the `Balanced Scorecard` perspective of `HNH_Analytics` (built against `HNH_Analytics_Test`), payloads `[BSC Visual Payload]` / `[BSC Visual Payload Scores]`, `[BSC Selection Label]`, `[BSC Actual]` and the other existing measures.
3. The pages the design does not show (Owner view, Hospital comparison, the seven family pages, How to use, How scores are calculated) get the design's frame and panel style, with their content unchanged.
4. The report still goes to Power BI Report Server the same way (PBIP → Desktop 2.158 → `.pbix` → Desktop for Report Server → upload); `build.py`, `pbir_check.py` and the tests stay the gate.

## Non-goals

- **No modelling changes:** no SSAS measures, columns, perspectives or roles; no dbt models; no ClickHouse tables or rows. If a design element needs data the model does not have, the element is adapted or dropped (table below), never fed by a new measure.
- The Build spec page is not built: its star schema, DAX, 90 / 50 scoring and "Off track" wording are the designer's proposal and are replaced by the existing model.
- No deploy, upload or SSAS processing as part of this work (CLAUDE.md: those need the user's go-ahead; the README steps stay the user's).
- The uncommitted Press Ganey work in the working tree (`_Measures.tmdl`, perspectives, `ssas/tests/measures/patient_experience.json`, its spec) is not touched or committed.

## Anti-goals (a failure even if it works)

- A number that differs from what the same measure shows today for the same selection.
- A status told by colour alone.
- The design's scoring or state words (90 / 50, "Off track") anywhere in the report. The model's rules stay: On track from 85, Watch 70–84, At risk under 70, plus No data yet, Parked and No target.
- A page that Desktop for Report Server or the server refuses (`check_upload_rules` must stay `[]`).
- A row-level-security leak: everything stays a live connection under the viewer's identity, as today.

## Branding (replaces the design's palette and type)

From `branding/` and the visual's existing tokens (`style/visual.less`, plan 2026-10-21 D10):

| Design | HNH |
|---|---|
| Header #0F1E2E | navy `#0A1E32` |
| Page #F3F5F8 | surface `#F4F7FB` |
| Panel border #E1E6EC | line `#DCE5EF` |
| Secondary text #5F6E7E | muted `#5B6B7D` (passes 4.5:1 on white and on the surface) |
| Links, primary accents #1D4E89 | blue-dark `#1478BE` |
| Current-tab underline (white) | blue `#13ACE3` |
| On track #15803D | `#0E9F8E` (chip text `#08776B` on `#E3F6F3`) |
| At risk #B45309 | Watch `#EF8B00` (chip text `#A35F00` on `#FFF2E0`) |
| Off track #B91C1C | At risk `#DB280A` (chip text `#A81E06` on `#FDE9E5`) |
| (no equivalent) | No data yet / Parked / No target `#9AA7B5`, chip text `#5B6B7D` on `#EEF2F6`, shape: a short dash |
| "Missed" bar #E8A25A | Watch tint `#F5B865` |
| Ring #0F1E2E | navy `#0A1E32` |
| Logo placeholder | `branding/الحياة للرعاية الصحية-08.png` (white mark on transparent), cropped to its content |
| Fonts Barlow / Barlow Semi Condensed | Segoe UI / Segoe UI Semibold (numbers with tabular figures) |

Fonts are my call: the native visuals (slicers, buttons, text boxes, charts) only have the fonts installed on the viewer's machine, so Barlow inside the custom visual and Segoe UI around it would mix two typefaces on one page. The design's own build spec says the same (Segoe UI and DIN in Power BI).

**Pillar colours** (my call; the design uses four unrelated hues, which are not in the HNH palette): Financial `#002E5A` (navy-2), Customer `#1478BE` (blue-dark), Internal Process `#13ACE3` (blue), Learning & Growth `#6E8196` (slate). They differ in lightness, so the trend lines stay apart in greyscale, and the trend chart labels each line at its end so colour is never the only key. They are format-pane colours of the visual (Colours card), so they can change without code.

Status shapes, as in the design: On track = circle, Watch = diamond, At risk = square, no score = dash.

## Page size

The report stays **1920 × 1080**; every design measurement is multiplied by **1.5** (header 84 px, filter bar 78 px, gaps 24 px, panel radius 12, 14 px headings → 21 px, and so on). Power BI fits the page to the window, so this looks the same as the design's 1280 × 720 while the family and guide pages keep their layout. (My call.)

## The frame on every page (native visuals, written by the generator)

- **Header bar:** a navy rectangle across the page (0, 0, 1920, 84); the logo image; a text box "Balanced Scorecard" (Segoe UI Semibold, white) with "Hayat Healthcare" under it in a light grey on navy; then the page tabs on the right as page-navigation buttons: **Overview** (the page now called "BSC"), Financial, Customer, Internal Process, Learning & Growth, Owner view, Hospital comparison, then How to use and Calculations. Tab style as the design: no fill, light text `#C3CEDB`; the current page's tab has white text, a light fill (white at 8%) and a 3 px `#13ACE3` underline (a thin rectangle under the button). The generator knows which page it writes, so the current tab is styled per page.
- **Filter bar:** a white rectangle (0, 84, 1920, 78) with a 1 px `#DCE5EF` rule below. Slicers as today, restyled to the design's dropdown look (border `#CBD3DC`, radius 6, small grey header): Hospital (Branch Name, hospitals only), BSC Category, Date (the From – To range saved on the build year). On the right, the selection label `[BSC Selection Label]` (for example "Corporate · Jan 2026 – Sep 2026") as a small grey text card, in place of "Data as of".
- Dropped from the filter bar (my calls): "Sample data" (the report shows real data), "Compare to" (the model has one comparison, the target), "Reset filters" (it needs a bookmark; the generator writes none, and a cleared slicer does the same).
- Content panels drawn by the visual sit on the surface colour from y = 162 + 24 down to the bottom margin of 24 px, left and right margins 30 px.

The visual's own header band (gradient, logo ribbon, title) is no longer shown: `showHeader` defaults to off, the frame is native.

## Overview (visual mode "overview")

As the design, with these adaptations:

| Design element | Built from |
|---|---|
| Overall score ring, "of 100" (the ring fills at 100; a higher score shows in full) | `overallScore` (the visual's weighted pillar mean, as today); ring stroke navy, track `#E6EBF0` |
| Status chip | the state of the rounded overall score (85 / 70 thresholds) |
| "▲ 0.3 vs Aug" | the overall score of the last month minus the month before, from the KPI score trends (payload field 9), with the previous month's name |
| "Target 90.0 · gap 15.2" | "Target 85 · gap x" using the good threshold (`Good From`) |
| Status distribution bar + counts | On track / Watch / At risk counts, plus a grey "No data" segment and count for No data yet + Parked + No target (the model has these; the design does not) |
| Pillar card: weight, score, chip, progress bar with target marker | pillar weight, pillar score, its state; the marker at the good threshold |
| Pillar card sparkline + delta | the pillar score trend (as today's `pillarTrend`) and its last-month change |
| Pillar card counts | On track / Watch / At risk counts of the pillar |
| "Drill into N KPIs →" and the card as a link | a transparent page-navigation button over each card (native, written by the generator at the card's position); the visual can't change pages itself |
| Pillar score trend · last 12 months | the four pillar trends, dashed line at the good threshold, y axis from the lower ten below the lowest value to 100, month labels (below) |
| Needs attention | At-risk KPIs (the model's worst state), lowest score first, as many as fit; actual in the At-risk colour, target with ≥ / ≤ / ≈ from the direction. Badge "N at risk". Footer "N more KPIs are on watch. Open a pillar to review them." Click selects (cross-filter); right-click › Drill through › KPI detail, as everywhere in the visual |

**Month labels.** The payload's trends are the 12 months ending at the selection's last month up to today. The visual names them from the end month in `[BSC Selection Label]` (its last "Mon YYYY"); if the label has no month, the axis shows no month names.

**Payload.** The design's sparklines, deltas and trend chart need the monthly trends, which only `[BSC Visual Payload]` carries. The Overview switches from `[BSC Visual Payload Scores]` to `[BSC Visual Payload]` (Decisions after review). Without trends (if the scores payload is kept), the visual leaves out the sparklines, the deltas and the trend panel, and the Needs attention panel takes the full bottom row.

## Pillar pages (visual mode "board", page filter on `'BSC KPI'[Pillar]`)

Pillar names are the model's: Financial, Customer, Internal Process, Learning & Growth.

- **Summary strip** (visual): breadcrumb text "Overview › <pillar>" (not a link; the tabs navigate), pillar colour square and name, pillar score + chip, "vs <previous month>" delta, weight, status counts (On track / Watch / At risk / No data). On the right, in place of "Pillar owner" (the model has no pillar owner): the pillar question (`Pillar Question`). (My call.)
- **KPI scorecard** (visual): one row per KPI of the pillar, sorted by objective order, then primary first, then display order (today's board order), flat with the objective under the KPI name as in the design. Columns: status chip, KPI · objective, actual (`Value Format`), target with ≥ (higher), ≤ (lower, ceiling) or ≈ (on_target), variance (the model's direction-adjusted variance %, signed, coloured by state), score (rounded), 12-month sparkline of actual with the end dot in the state colour. A KPI without a score shows its state chip ("No data yet", "Parked", "No target"), "–" for missing values and its reason in the objective line's place. Rows scroll inside the panel when they do not fit (Internal Process has 26 KPIs). Manual KPIs keep a small "Manual" tag.
- **Objective picker** (my call, in place of the design's "Objective" slicer in the filter bar): a dropdown-styled button "Objective: All objectives" in the KPI scorecard panel's heading row, drawn by the visual and kept as the visual's own state (as today's board tabs are). It narrows the table only; the summary strip always shows the whole pillar. A native slicer would filter the visual's query, so the strip's "pillar score" would silently become the objective's score, and it would sync across the four pillar pages and with the slicer on "How scores are calculated". The picker is not a report filter, so it does not travel to KPI detail; it resets when the page's data changes and the picked objective is gone.
- **Row click:** highlights the row, shows it in the panel, and selects the KPI for the host (cross-filters the native visuals on the page). Right-click: the drill-through menu, as today.
- **Selected KPI panel:** with no row picked, the panel reads "Select a KPI in the table to see its monthly trend and hospitals". With a row picked: name; objective · direction note ("Higher is better", "Lower is better", "At most the target", "Closest to the target is best"); Actual, Target, Score + state; "Monthly trend vs target" bars from the actual trend, each coloured met (pillar colour) or missed (Watch tint) against that month's target (`targetTrend`), with the monthly target as a dashed step line; month initials.
- **By hospital** (native, in the panel's lower part): a clustered bar chart of `[BSC Actual]` by `'Branch'[Branch Name]` (hospitals only), sorted descending, no axis titles, data labels on, styled to the panel; it follows the visual's KPI selection. Title "By hospital". The panel is drawn by the visual with this area left empty; the chart sits on top. (My call: the board payload has no per-hospital values; a native chart over the existing measure gives them without a model change.)
- **"Drill through to KPI detail →"** (native): a drill-through button to KPI detail at the panel's foot, outlined in the pillar colour, enabled when one KPI is selected. Whether Power BI enables a drill-through button from a custom visual's selection must be confirmed in Desktop (plan step); if it does not, the button is replaced by the visual's text "Right-click a KPI › Drill through › KPI detail".

## KPI detail (drill-through on `'BSC KPI'[KPI Code]`, keep all filters on; hidden)

The design's sub-bar replaces the filter bar: Back (native) and, drawn by the visual, the breadcrumb "Overview › <pillar> › <KPI name>" and the drill-filter chips (KPI name, the period and the hospital from `[BSC Selection Label]`). No slicers on this page (as the design); the filters arrive by drill-through.

A new visual mode **"detail"** draws the sub-bar text, the profile panel and the trend panel:

- **Profile:** pillar colour · pillar · objective; KPI name; actual in the state colour; chip; "Target x · variance · score n". Definition list: Definition (`'BSC KPI'[Definition]`), Better when (the direction note), Target basis (`[BSC Target Basis]`), Weight (payload field 6), Owner, Co-owners, Source ("Manual entry" or "Calculated", from `Value Source`). The design's Formula, Frequency and Source system have no field in the model and are dropped. "Performance bands" in the KPI's units, worked out from the target and the KPI's own `Score Base`, `Score Slope`, `Good From`, `Watch From` and direction, the same rule the score measure uses: On track from …, Watch …–…, At risk beyond …; not shown for a KPI without a target. In place of "Linked initiative": the manual-entry note (`[BSC Manual Note]`) for a manual KPI, nothing for a calculated one.
- **Monthly trend with performance bands:** the 12-month actual line over three shaded bands per month (from that month's target and the same rule), the dashed monthly target, y labels, month labels. The 24-month toggle is dropped: the payload carries 12 months.
- New field wells for this mode (report side only, existing model fields): Definition (`'BSC KPI'[Definition]`, grouping), Target basis (`[BSC Target Basis]`, measure), Manual note (`[BSC Manual Note]`, measure).
- **Lower row (native)**, in the design's two breakdown panels, which are claims-specific in the design: left "By hospital" (`[BSC Actual]` by Branch Name, hospitals only, as today's bar chart); right today's matrix (Branch Name × Year Month Name, `[BSC Actual]`) with the "Open detail" drill button to the family page, titled "Select a hospital and month, then Open detail".
- Today's six cards, line chart, "About this KPI" table and "Manual entry note" table go: the visual shows the same facts.

## Owner view and Hospital comparison

Not in the design. Their content and behaviour stay as they are (README of the visual); they take the design's frame, panel style (white, 1 px line, radius 12, 21 px headings), chip shapes and type sizes. The comparison keeps `[BSC Visual Payload Scores]`.

## Family pages and guide pages

The design's frame: header bar with tabs (no current tab on the family pages, which are hidden; the title text box moves into the content area as a 30 px heading), Back where they have it today, white panels behind the cards and charts (native visual backgrounds: white, 1 px `#DCE5EF` border, radius 12). Content unchanged. The guide text is updated where it describes the old look (for example "The page buttons at the top right", "BSC" → "Overview", the Needs attention list, the selected-KPI panel).

## Theme

`theme/hnh_bsc_theme.json`: page background `#F4F7FB`; visual backgrounds white with a `#DCE5EF` border and radius; text classes in Segoe UI with the sizes above; dataColors start with the four pillar colours, then the blues; good / neutral / bad = the three state colours. The base theme stays.

## What changes, by part

- **Visual** (`powerbi_tmdl/hnh_bsc_visual`, version 1.1.0.0): new Overview and board renderers, new "detail" mode, restyled owner and comparison views, status chips with shapes, month labels from the selection label, pillar colours and state colours in the Colours card, the header band off by default, three new field wells. Tests (Vitest) and the dev screenshot harness at 1920 × 1080 for every mode.
- **Report generator** (`powerbi_tmdl/hnh_bsc_report`): new visual kinds for a filled rectangle (shape) and an image (the logo as a registered resource), tab-style navigation buttons with a current-tab style, the frame on every page, the overlay buttons on the Overview, the by-hospital chart and drill button on the pillar pages, the new KPI detail layout, the theme, the guide text; `pbir_check.py` keeps passing; tests updated; README updated (the page checks of step 2).
- **No change:** `ssas/`, `hnh_dwh/`, ClickHouse.
- **Legacy template fallback** (`layout.py`, `--format pbix`; my call): it may lag. It can only rebind the template's 12 samples, which have no shape or image, so it writes the new pages without the header and filter-bar rectangles, the tab underline and the logo. The README's appendix says so. Its tests keep passing on what it can write; no new template samples.

## Left to the builder

- Exact pixel positions within the 1.5× scaling, as long as the proportions follow the design.
- How the visual lays out rows that do not fit (scroll or "N more").
- The logo crop method (no Pillow on the server; .NET `System.Drawing` from PowerShell works).
- How the generator writes the shape and image visuals, within what `pbir_check.py` accepts.
- Order of the work, and whether the visual or the generator goes first.

## Decisions after review

- **Overview payload** (my call, the user asked for the exact design): `[BSC Visual Payload]`, the design in full. It is one binding in `pages.py` (`_SCORECARD`); if the Overview is too slow for a one-hospital user, switch it back to `[BSC Visual Payload Scores]` and the visual leaves out the trend parts (above).
- **Scoring is a later, separate piece of work** (user, 2026-10-26: "update the design first, then we will work on the scoring later"). The user does not want the score capped at 100; that is a change to the SSAS score measures (`MIN ( 100, MAX ( 0, … ) )` in `BSC Score`, both visual payloads and the scores payload), outside this redesign. For reference, the old Hayat report floors every score at 0, caps a KPI's score at 100, and does not cap pillar and overall scores (they come from unit scores × 100). This redesign must not stand in the way: the visual draws any score above 100 correctly (the number shows in full; rings and progress bars fill at 100 and stop; the trend axis extends above 100 when a value does), and no code in the visual or the generator assumes a score is at most 100.
