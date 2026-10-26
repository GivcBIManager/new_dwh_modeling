"""The report's pages: seven scorecard pages, the hidden KPI detail drill-through page, the family pages, then the two
guide pages (spec docs/superpowers/specs/2026-10-26-bsc-report-redesign-design.md).

Every page has the frame (frame.py: the navy header with the logo, the title and the tabs; the white filter bar with
How to use and Calculations); the geometry is frame.py's. A scorecard page's own tab is current; KPI detail, the
family pages and the guide pages have no tab of their own. `PAGES` is the list `build.py` writes; `build_pages`
writes it with the Date slicer saved on another year.
"""
from __future__ import annotations

import datetime

from frame import (BOARD_BUTTON, BOARD_CHART, CONTENT, DETAIL_BACK, DETAIL_BY_HOSPITAL, DETAIL_MATRIX, DETAIL_OPEN,
                   DETAIL_VISUAL, LINE, NAVY, OV_CARDS, WHITE, _colour, _lit, _num, button_props, frame, no_container)
from model import Field, Filter, Interaction, Page, Visual, col, meas

# Roles of the HNH visual (capabilities.json) -> 'BSC KPI' column, as the visual README's field-well table.
ATTRIBUTE_ROLES = {
    "kpi": "KPI Code", "kpiName": "KPI Name", "shortLabel": "Short Label", "pillar": "Pillar",
    "pillarOrder": "Pillar Order", "pillarWeight": "Pillar Weight", "pillarQuestion": "Pillar Question",
    "objectiveCode": "Objective Code", "objectiveTitle": "Objective Title", "objectiveOrder": "Objective Order",
    "kpiType": "KPI Type", "direction": "Direction", "valueFormat": "Value Format", "displayOrder": "Display Order",
    "kpiStatus": "Status", "valueSource": "Value Source", "owner": "Owner", "coOwners": "Co Owners", "scoreBase": "Score Base",
    "scoreSlope": "Score Slope", "goodFrom": "Good From", "watchFrom": "Watch From",
}
# The visual's KPI-detail wells (README: bound on KPI detail only).
DETAIL_ROLES = {"definition": [col("BSC KPI", "Definition")], "targetBasis": [meas("BSC Target Basis")],
                "manualNote": [meas("BSC Manual Note")]}

BRANCH_NAME = col("Branch", "Branch Name")
IS_HOSPITAL = col("Branch", "Is Hospital")
YEAR_MONTH_NAME = col("Date", "Year Month Name")  # "Aug 2026", sorted by 'Date'[Year Month]: shown and drilled on
BSC_ACTUAL = meas("BSC Actual")

MUTED, SLICER_BORDER = "#5B6B7D", "#CBD3DC"
KPI_DETAIL_NAME = "kpi_detail"

PAGE_TITLE = (30, 186, 1200, 54)  # a family or guide page's own title, at the top of the content box
BODY_TOP = 258  # cards, charts and guide text start here (title + 18 px)
GAP = 24


def select_all_selection() -> dict:
    """Slicer selection: multi-select with a "Select all" entry (one place to correct the property names)."""
    return {"selection": [{"properties": {"singleSelect": _lit(False), "selectAllCheckboxEnabled": _lit(True)}}]}


def back_button(x: float = DETAIL_BACK[0], y: float = DETAIL_BACK[1], w: float = DETAIL_BACK[2],
                h: float = DETAIL_BACK[3]) -> Visual:
    """A button whose action is Back, on the left of the filter bar; for every page reached by drill-through."""
    return Visual("buttonNavigate", x, y, w, h,
                  props={**button_props({"type": _lit("Back")}, "Back", "outline"), **no_container()})


def _hospitals() -> Filter:
    return Filter(IS_HOSPITAL, "in", ["Yes"])


def _container_off() -> dict:
    """No container background or border (frame.no_container's): a native visual on a panel the HNH visual draws
    (the board's chart) or on the filter bar (the selection label). Its visual header stays."""
    off = no_container()
    return {"background": off["background"], "border": off["border"]}


def hnh_container() -> dict:
    """The HNH visual's container: frame.no_container (no background or border: it draws its own panels; no visual
    header, whose icons would pop over the tabs and the help buttons) and padding 0 on every side, so the visual's
    box is its rect and the geometry visual.less shares with frame.py holds."""
    zero = _num(0)
    return {**no_container(),
            "padding": [{"properties": {"top": zero, "bottom": zero, "left": zero, "right": zero}}]}


# ---- scorecard pages ----------------------------------------------------------------------------------------------

# (page name, display name, pillar filter, mode, payload measure). The Overview takes the full payload (spec
# "Decisions after review"); the comparison keeps the scores payload.
_SCORECARD = [
    ("bsc", "Overview", None, "overview", "BSC Visual Payload"),
    ("financial", "Financial", "Financial", "board", "BSC Visual Payload"),
    ("customer", "Customer", "Customer", "board", "BSC Visual Payload"),
    ("internal_process", "Internal Process", "Internal Process", "board", "BSC Visual Payload"),
    ("learning_growth", "Learning & Growth", "Learning & Growth", "board", "BSC Visual Payload"),
    ("owner_view", "Owner view", None, "owner", "BSC Visual Payload"),
    ("hospital_comparison", "Hospital comparison", None, "comparison", "BSC Visual Payload Scores"),
]
# The pillar colours by Pillar Order 1-4 (the visual's format-pane defaults), keyed by the pillar page's filter.
PILLAR_COLOURS = {"Financial": "#002E5A", "Customer": "#1478BE", "Internal Process": "#13ACE3",
                  "Learning & Growth": "#6E8196"}

# The filter bar: Hospital, BSC Category, Date, then the selection label; How to use and Calculations on the right.
SLICER_RECTS = [(30, 96, 330, 54), (375, 96, 270, 54), (660, 96, 420, 54)]
SELECTION_LABEL = (1100, 99, 470, 48)


def year_range(build_date: datetime.date) -> tuple[str, str]:
    """1 January - 31 December of the build year: the Date slicer's saved range. The measures and the header label
    stop at today, so what opens reads as year to date; the range moves on at the next rebuild."""
    return f"{build_date.year}-01-01", f"{build_date.year}-12-31"


def dropdown_look() -> dict:
    """The design's dropdown slicer: a small grey header (11pt), a #CBD3DC border with radius 6."""
    return {"header": [{"properties": {"show": _lit(True), "textSize": _num(11), "fontColor": _colour(MUTED)}}],
            "border": [{"properties": {"show": _lit(True), "color": _colour(SLICER_BORDER), "radius": _num(6),
                                       "width": _num(1)}}]}


def _slicers(build_date: datetime.date) -> list[Visual]:
    """The three filter-bar slicers (Branch, BSC Category, Date). The Date slicer is a From - To range saved at
    `year_range(build_date)`. No Time Calculation slicer (controller ruling): its items applied to [BSC Actual] but
    not to the target."""
    hospital, category, date = SLICER_RECTS
    return [
        Visual("slicerDropdown", *hospital, roles={"Values": [BRANCH_NAME]}, filters=[_hospitals()],
               props={**select_all_selection(), **dropdown_look()}),
        Visual("slicerDropdown", *category, roles={"Values": [col("Branch", "BSC Category")]}, props=dropdown_look()),
        Visual("slicerDateRange", *date, roles={"Values": [col("Date", "Date")]}, date_range=year_range(build_date),
               props=dropdown_look()),
    ]


def _selection_label() -> Visual:
    """`[BSC Selection Label]` ("Corporate · Jan 2026 – Sep 2026") as small grey text on the filter bar."""
    return Visual("card", *SELECTION_LABEL, roles={"Values": [meas("BSC Selection Label")]}, props={
        "labels": [{"properties": {"fontSize": _num(12), "color": _colour(MUTED)}}],
        "categoryLabels": [{"properties": {"show": _lit(False)}}], **_container_off()})


def _hnh_visual(rect: tuple, mode: str, payload: str, extra_roles: dict | None = None,
                filters: list[Filter] | None = None) -> Visual:
    """The HNH visual in `mode`, its header band off (the frame is native) and `hnh_container` (no container box: it
    draws its own panels; set here as well as by the theme's rule for its guid, which is unconfirmed for a private
    visual)."""
    roles = {role: [col("BSC KPI", column)] for role, column in ATTRIBUTE_ROLES.items()}
    roles["payload"] = [meas(payload)]
    roles["selectionLabel"] = [meas("BSC Selection Label")]
    roles.update(extra_roles or {})
    props = {"scorecard": [{"properties": {"mode": _lit(mode), "showHeader": _lit(False)}}], **hnh_container()}
    return Visual("hnhVisual", *rect, roles=roles, filters=filters or [], props=props)


def _card_button(rect: tuple, page_name: str, label: str) -> Visual:
    """A transparent page-navigation button over an Overview pillar card: no fill, outline or label; the tooltip
    "Open <pillar>"."""
    off = [{"properties": {"show": _lit(False)}}]
    link = {"show": _lit(True), "type": _lit("PageNavigation"), "navigationSection": _lit(page_name),
            "tooltip": _lit(f"Open {label}")}
    return Visual("buttonNavigate", *rect, props={"visualLink": [{"properties": link}], "fill": off, "outline": off,
                                                  "text": off, **no_container()})


def _by_hospital(rect: tuple, props: dict | None = None) -> Visual:
    """`[BSC Actual]` by hospital, largest first."""
    return Visual("barChart", *rect, roles={"Category": [BRANCH_NAME], "Y": [BSC_ACTUAL]}, title="By hospital",
                  filters=[_hospitals()], sort=BSC_ACTUAL, sort_dir="desc", props=props or {})


def on_panel_chart() -> dict:
    """The board's by-hospital chart: no axis titles, data labels on, no box (it sits on the visual's panel)."""
    return {"categoryAxis": [{"properties": {"showAxisTitle": _lit(False)}}],
            "valueAxis": [{"properties": {"showAxisTitle": _lit(False)}}],
            "labels": [{"properties": {"show": _lit(True)}}], **_container_off()}


def _drill_to_detail(pillar: str) -> Visual:
    """The board's drill-through button to KPI detail, outlined in the pillar colour; Power BI enables it when one
    KPI is selected."""
    link = {"type": _lit("Drillthrough"), "drillthroughSection": _lit(KPI_DETAIL_NAME)}
    return Visual("buttonDrill", *BOARD_BUTTON, props={
        **button_props(link, "Drill through to KPI detail →", "outline", PILLAR_COLOURS[pillar]), **no_container()})


def _scorecard_page(build_date: datetime.date, name: str, display: str, pillar: str | None, mode: str,
                    payload: str) -> Page:
    """The frame (this page's tab current, the slicers and the selection label in the filter bar), the HNH visual in
    the content box, and the native visuals over it: the Overview's card buttons, a pillar board's chart and button.
    On a board, a click on a hospital bar filters neither the HNH visual (Power BI would clear its KPI selection, so
    the panel and the chart would empty) nor the selection label: NoFilter interactions."""
    comparison = mode == "comparison"
    visual = _hnh_visual(CONTENT, mode, payload, {"branch": [BRANCH_NAME]} if comparison else None,
                         [_hospitals()] if comparison else None)
    label = _selection_label()
    visuals = frame(name, _slicers(build_date) + [label]) + [visual]
    interactions: list[Interaction] = []
    if mode == "overview":
        # The card buttons assume the visual draws the cards in this order ('BSC KPI'[Pillar Order] 1-4, all four
        # pillars present; README "Pillar order")
        pillars = [row for row in _SCORECARD if row[3] == "board"]
        visuals += [_card_button(r, row[0], row[1]) for r, row in zip(OV_CARDS, pillars)]
    elif mode == "board":
        chart = _by_hospital(BOARD_CHART, on_panel_chart())
        visuals += [chart, _drill_to_detail(pillar)]
        interactions = [Interaction(chart, visual, "NoFilter"), Interaction(chart, label, "NoFilter")]
    page_filters = [Filter(col("BSC KPI", "Pillar"), "eq", [pillar])] if pillar else []
    return Page(name, display, visuals, filters=page_filters, interactions=interactions)


def scorecard_pages(build_date: datetime.date) -> list[Page]:
    return [_scorecard_page(build_date, *row) for row in _SCORECARD]


SCORECARD_PAGES: list[Page] = scorecard_pages(datetime.date.today())


# ---- KPI detail ---------------------------------------------------------------------------------------------------

def word_wrap() -> dict:
    """A table's text wrap for values and column headers (tableEx `values.wordWrap`, `columnHeaders.wordWrap`)."""
    return {"values": [{"properties": {"wordWrap": _lit(True)}}],
            "columnHeaders": [{"properties": {"wordWrap": _lit(True)}}]}


def _kpi_detail() -> Page:
    """Drill-through target (KPI Code, keep all filters; no slicers: the filters arrive by drill-through). The HNH
    visual in mode "detail" covers the page under the header and draws the white sub-bar, the profile and the trend;
    it goes in the frame's filter-bar slot (there is no filter bar), so Back and How to use / Calculations are drawn
    over its sub-bar. Over its empty lower right: the by-hospital chart, and the matrix with the "Open detail" button
    under it, which drills on the matrix's cell (Branch Name x Year Month Name, the family pages' drill fields)."""
    detail = _hnh_visual(DETAIL_VISUAL, "detail", "BSC Visual Payload", DETAIL_ROLES)
    visuals = frame(None, [detail, back_button()], filter_bar=False)
    visuals += [
        _by_hospital(DETAIL_BY_HOSPITAL),
        Visual("matrix", *DETAIL_MATRIX, title="Select a hospital and month, then Open detail",
               roles={"Rows": [BRANCH_NAME], "Columns": [YEAR_MONTH_NAME], "Values": [BSC_ACTUAL]},
               filters=[_hospitals()]),
        Visual("buttonDrill", *DETAIL_OPEN, props=button_props(
            {"type": _lit("Drillthrough"), "drillthroughSection": {
                "expr": {"Measure": {"Expression": {"SourceRef": {"Entity": "_Measures"}},
                                     "Property": "BSC Detail Page"}}}},
            "Open detail", "primary")),
    ]
    return Page(KPI_DETAIL_NAME, "KPI detail", visuals, drill_fields=[col("BSC KPI", "KPI Code")], hidden=True)


KPI_DETAIL: Page = _kpi_detail()

# ---- family detail pages --------------------------------------------------------------------------------------------

# Each chart, table and matrix takes a title: a label of this repo (not title-cased), shown on the visual.

def _bar(title: str, measure: str, by: Field, n: int | None = None, rank: str | None = None,
         props: dict | None = None) -> dict:
    """A bar chart sorted descending by its measure; the top N ranks by `rank` (default the bar's measure)."""
    return {"sample": "barChart", "title": title, "roles": {"Category": [by], "Y": [meas(measure)]},
            "sort": meas(measure), "top_n": (meas(rank or measure), n) if n else None, "props": props or {}}


def labels_not_axis() -> dict:
    """Bar chart: no value axis, data labels on. For [NPS (5-point)], whose format string prints "insufficient
    sample" (fewer than 30 answers) along the value axis."""
    return {"valueAxis": [{"properties": {"show": _lit(False)}}],
            "labels": [{"properties": {"show": _lit(True)}}]}


def _table(title: str, by: Field, measures: list[str], n: int | None = None, rank: str | None = None) -> dict:
    """A table sorted descending by its ranking measure (`rank`, else the first measure), which the top N also ranks
    by; a `rank` measure not among `measures` is added as the last column (a visual sorts only by its own fields)."""
    ranking = rank or measures[0]
    shown = measures + ([ranking] if ranking not in measures else [])
    return {"sample": "table", "title": title, "roles": {"Values": [by] + [meas(m) for m in shown]},
            "sort": meas(ranking), "top_n": (meas(ranking), n) if n else None}


def _matrix(title: str, rows: list[Field], measures: list[str]) -> dict:
    return {"sample": "matrix", "title": title, "roles": {"Rows": rows, "Values": [meas(m) for m in measures]}}


def title_text(text: str) -> dict:
    """The text box content: one paragraph, one text run in Segoe UI 22pt bold ink (the run's `textStyle` with CSS
    values, as Desktop's text box reads it: fontFamily, fontSize, fontWeight, color)."""
    style = {"fontFamily": "Segoe UI", "fontSize": "22pt", "fontWeight": "bold", "color": NAVY}
    return {"general": [{"properties": {"paragraphs": [{"textRuns": [{"value": text, "textStyle": style}]}]}}]}


def _page_title(text: str) -> Visual:
    """A family or guide page's title at the top of the content box, on the page surface (no box)."""
    return Visual("textbox", *PAGE_TITLE, props={**title_text(text), **no_container()})


CARD_H = 110
CHARTS_TOP = BODY_TOP + CARD_H + GAP  # 392
CHART_W = (CONTENT[2] - GAP) / 2  # 918: two columns
CHART_H = (CONTENT[1] + CONTENT[3] - CHARTS_TOP - GAP) / 2  # 320: two rows end at y 1056


def _family_page(name: str, display: str, cards: list[str], charts: list[dict]) -> Page:
    """Drill-through page: the frame without a current tab, Back in the filter bar; in the content box the title and
    a card of the filtered hospital and month, the measure cards, then a 2-column grid of charts (two rows at most).
    Cards and charts keep the theme's white panel. No slicers. Keep all filters is off: only the drill fields
    (Branch Name, Year Month Name) arrive, never KPI detail's 'BSC KPI' drill filter or pillar filter, which every
    domain measure's guard rejects ("... can't be analysed by "BSC KPI""); the page filters hospitals itself (Review
    Focus 4)."""
    x0, width = CONTENT[0], CONTENT[2]
    visuals = frame(None, [back_button()])
    title_end = PAGE_TITLE[0] + PAGE_TITLE[2] + GAP
    visuals += [_page_title(display),
                Visual("multiRowCard", title_end, PAGE_TITLE[1], x0 + width - title_end, PAGE_TITLE[3],
                       roles={"Values": [BRANCH_NAME, YEAR_MONTH_NAME]})]
    w = (width - GAP * (len(cards) - 1)) / len(cards)
    visuals += [Visual("card", x0 + (w + GAP) * i, BODY_TOP, w, CARD_H, roles={"Values": [meas(m)]})
                for i, m in enumerate(cards)]
    if len(charts) > 4:
        raise ValueError(f"family page {display}: at most four charts fit (two rows of two)")
    for i, c in enumerate(charts):
        visuals.append(Visual(c["sample"], x0 + (CHART_W + GAP) * (i % 2), CHARTS_TOP + (CHART_H + GAP) * (i // 2),
                              CHART_W, CHART_H, roles=c["roles"], title=c["title"], sort=c.get("sort"),
                              top_n=c.get("top_n"), props=c.get("props") or {}))
    return Page(name, display, visuals, filters=[_hospitals()], drill_fields=[BRANCH_NAME, YEAR_MONTH_NAME],
                hidden=True, keep_filters=False)


_DEPT = col("Department", "Department Name")
_PAYER_CAT = col("Payer", "Category")

FAMILY_PAGES: list[Page] = [
    _family_page("fam_revenue", "Revenue detail",
                 ["Revenue", "Gross Charges", "Line Discount", "Claimable Revenue"],
                 [_bar("Revenue by department (top 15)", "Revenue", _DEPT, 15),
                  _bar("Revenue by product category", "Revenue", col("Product Category", "High Level Department")),
                  _bar("Revenue by payer category", "Revenue", _PAYER_CAT),
                  _table("Top 20 doctors by revenue", col("Staff", "Staff Name"), ["Revenue"], 20)]),
    _family_page("fam_finance", "Finance detail",
                 ["EBITDA", "EBITDA Margin %", "Net Profit", "Budget Variance %"],
                 [_matrix("Income statement: actual vs budget", [col("Budget Line", "Budget Line Name")],
                          ["IS Actual", "IS Budget", "Budget Variance"]),
                  _bar("GL movement by account (top 15)", "GL Movement", col("GL Account", "Natural Account Name"),
                       15)]),
    _family_page("fam_volume", "Patient volume detail",
                 ["OP Visits", "ER Visits", "Admissions", "New Patients", "Returning Patients"],
                 [_bar("OP visits by department (top 15)", "OP Visits", _DEPT, 15),
                  _bar("Census by payer category", "Census", _PAYER_CAT),
                  _bar("Average wait by department (top 15)", "Average Wait (min)", _DEPT, 15)]),
    _family_page("fam_beds", "Beds & clinical detail",
                 ["Bed Occupancy %", "ALOS (days)", "Readmission Rate 30d %", "ICU Readmissions 48h",
                  "Bed Turnover"],
                 [_bar("Bed occupancy by ward", "Bed Occupancy %", col("Bed", "Current Ward")),
                  _bar("ALOS by department (top 15)", "ALOS (days)", _DEPT, 15),
                  _table("Discharges by outcome", col("Discharge Outcome", "Outcome Group"), ["Discharges"])]),
    _family_page("fam_revenue_cycle", "Revenue cycle detail",
                 ["Claim Rejection Rate %", "First-pass Rejection Rate %", "Pre-auth Approval Rate %", "Leak Rate %",
                  "Billed Not Submitted"],
                 [_bar("Rejected claims by NPHIES reason (top 15)", "Claims Rejected", col("NPHIES Reason", "Reason"),
                       15),
                  _bar("Claimed amount by payer (top 15)", "Claimed Amount", col("Payer", "Purchaser Name"), 15),
                  _table("Billed amount by submission status", col("Claim Status", "Submission Status"),
                         ["Billed Amount"]),
                  _bar("Lost value by department (top 15)", "Lost Value", _DEPT, 15)]),
    _family_page("fam_workforce", "Workforce detail",
                 ["Headcount", "FTE", "Saudisation Rate %", "Turnover Rate %", "Hires"],
                 [_bar("Headcount by department (top 15)", "Headcount", col("HR Department", "Department Name"), 15),
                  _bar("Headcount by job (top 15)", "Headcount", col("Job", "Job Name"), 15),
                  _bar("Headcount by nationality (top 10)", "Headcount", col("Employee", "Nationality"), 10)]),
    _family_page("fam_experience", "Patient experience detail",
                 ["Hospital NPS (5-point)", "Physician NPS (5-point)", "NPS Answers", "Response Rate %"],
                 [_bar("NPS by domain", "NPS (5-point)", col("Survey Question", "Domain En"),
                       props=labels_not_axis()),
                  _bar("NPS by department (15 with most answers)", "NPS (5-point)", _DEPT, 15, rank="NPS Answers",
                       props=labels_not_axis()),
                  _table("Promoters, passives and detractors by question (top 20)",
                         col("Survey Question", "Question En"), ["% Promoters", "% Passives", "% Detractors"], 20,
                         rank="NPS Answers")]),
]

# ---- "How to use" and "How scores are calculated" -------------------------------------------------------------------

HEADING_BLUE, BODY_INK = "#1478BE", NAVY


def text_box(paragraphs: list[tuple[str, str]]) -> dict:
    """Text box content, one paragraph per (style, text): "heading" Segoe UI 14pt bold blue, "body" 12pt dark,
    "bullet" a body paragraph prefixed "• ". Same `general.paragraphs[].textRuns[]` shape as `title_text`."""
    base = {"fontFamily": "Segoe UI"}
    styles = {"heading": {**base, "fontSize": "14pt", "fontWeight": "bold", "color": HEADING_BLUE},
              "body": {**base, "fontSize": "12pt", "color": BODY_INK}}
    styles["bullet"] = styles["body"]
    out = []
    for style, text in paragraphs:
        if style not in styles:
            raise ValueError(f"paragraph style must be heading, body or bullet, got {style!r}")
        value = "• " + text if style == "bullet" else text
        out.append({"textRuns": [{"value": value, "textStyle": dict(styles[style])}]})
    return {"general": [{"properties": {"paragraphs": out}}]}


def white_panel() -> dict:
    """A text box's container as the theme's data-visual panel: white, 1 px #DCE5EF border, radius 12."""
    return {"background": [{"properties": {"show": _lit(True), "color": _colour(WHITE), "transparency": _num(0)}}],
            "border": [{"properties": {"show": _lit(True), "color": _colour(LINE), "radius": _num(12),
                                       "width": _num(1)}}]}


def _text(x: float, y: float, w: float, h: float, paragraphs: list[tuple[str, str]]) -> Visual:
    return Visual("textbox", x, y, w, h, props={**text_box(paragraphs), **white_panel()})


def _section(heading: str, bullets: list[str]) -> list[tuple[str, str]]:
    return [("heading", heading)] + [("bullet", b) for b in bullets]


COL_W = (CONTENT[2] - 2 * GAP) / 3  # 604: three text columns
COLS = [CONTENT[0] + (COL_W + GAP) * i for i in range(3)]  # 30, 658, 1286
FULL_W = CONTENT[2]
CONTENT_END = CONTENT[1] + CONTENT[3]  # 1056


def _guide_page() -> Page:
    sections = [
        _section("Choose what you see", [
            "Hospital: pick one or more hospitals, or leave it empty for all hospitals together (Corporate).",
            "BSC Category: pick a group of hospitals (Scale & Optimize, Anchor & Protect, Ramp-Up & Prove).",
            "Date: set the From and To dates. The report opens on 1 January to 31 December of this year; figures "
            "stop at today, so it reads as year to date.",
            "Your choices carry over to every scorecard page and to KPI detail."]),
        _section("Read the scores and colours", [
            "Every KPI gets a score from 0 to 100. Scores are points, not percentages.",
            "On track: 85 or more.",
            "Watch: 70 to 84.",
            "At risk: below 70.",
            "No data yet, No target and Parked KPIs are listed but not scored.",
            "Needs attention lists the KPIs at risk, lowest score first.",
            "Owner view shows Achievement in %: 100% or more is on track, 85% to 99% watch, below 85% at risk."]),
        _section("Go deeper", [
            "The tabs in the dark bar at the top move between the scorecard pages.",
            "Right-click a KPI and choose Drill through › KPI detail for its trend, hospitals and definition.",
            "On a pillar page, select a KPI in the table to see its monthly trend and hospitals on the right, then "
            "Drill through to KPI detail.",
            "On KPI detail, select a hospital and month in the table, then Open detail for the detail page behind "
            "it.",
            "Back (on the left, under the dark bar) returns to the page you came from.",
            "Hospital comparison: click a pillar header to see its objectives, then an objective header to see its "
            "KPIs; the path above the table goes back up.",
            "Owner view: click an owner's card to list only their KPIs; click it again to list everyone.",
            "Hover over a KPI for its actual, target, variance and owner."]),
    ]
    path_h, section_h = 54, 420
    sections_y = BODY_TOP + path_h + GAP  # 336
    pages_y = sections_y + section_h + GAP  # 780
    visuals = frame(None, []) + [_page_title("How to use the scorecard")]
    visuals.append(_text(COLS[0], BODY_TOP, FULL_W, path_h, [("body", (
        "Overall score  ›  4 pillars  ›  objectives  ›  KPIs  ›  KPI detail  ›  detail pages "
        "(Revenue, Finance, Patient volume, Beds & clinical, Revenue cycle, Workforce, Patient experience)"))]))
    visuals += [_text(x, sections_y, COL_W, section_h, sec) for x, sec in zip(COLS, sections)]
    visuals.append(_text(COLS[0], pages_y, FULL_W, CONTENT_END - pages_y, [("heading", "Pages")] + [
        ("body", t) for t in [
            "Overview: how are we doing overall and in each pillar?",
            "Financial, Customer, Internal Process, Learning & Growth: which KPIs in this pillar are on track, on "
            "watch or at risk?",
            "Owner view: how are each executive's KPIs doing?",
            "Hospital comparison: which hospital leads or lags, and on which pillar, objective or KPI?",
            "KPI detail: how has this KPI moved by month and by hospital, and how is it defined?",
            "Detail pages: what is behind a hospital's figures for a month?",
            "How scores are calculated: how is each score worked out, and what does each KPI measure?"]]))
    return Page("guide", "How to use", visuals)


def _definitions_page() -> Page:
    sections = [
        _section("KPI score (0 to 100)", [
            "Variance: how far the actual is from the target, as a % of the target. Where lower is better, the sign "
            "is flipped, so beating the target is always positive. For on-target KPIs, any distance from the target "
            "counts against.",
            "Score = score base + score slope × variance, rounded and kept between 0 and 100.",
            "Every KPI today uses base 85 and slope 0.6: a KPI exactly on target scores 85, and each point of "
            "variance moves the score by 0.6.",
            "Status: On track from 85, Watch from 70, At risk below 70."]),
        _section("Pillar and overall scores", [
            "Objective and pillar score: the average of their KPI scores, weighted by KPI weight.",
            "With one hospital selected, that hospital's KPI weights apply; otherwise the corporate weights.",
            "Overall score: the average of the pillar scores, weighted by pillar weight.",
            "KPIs without a score (no data, no target, parked) are left out; the others' weights count in full.",
            "Hospital comparison ranks hospitals by these scores; equal rounded scores share a rank."]),
        _section("Owner achievement (%)", [
            "Each KPI's achievement: actual ÷ target where higher is better; target ÷ actual where lower is "
            "better; 100% when a ceiling KPI is at or below its ceiling; for on-target KPIs, 100% less the distance "
            "from the target.",
            "Weighted: the owner's achievements averaged by KPI weight, over the KPIs they own and co-own. Not "
            "capped at 100%.",
            "On-target: the share of those KPIs at or better than target (on-target KPIs count when On track).",
            "C-suite cards come first: CEO, COO, CMO, CFO, CHRO, CIO, CSO."]),
    ]
    section_h, example_h, slicer_h, slicer_w = 300, 54, 60, 300
    example_y = BODY_TOP + section_h + GAP  # 582
    slicers_y = example_y + example_h + GAP  # 660
    table_y = slicers_y + slicer_h + GAP  # 744
    visuals = frame(None, []) + [_page_title("How scores are calculated")]
    visuals += [_text(x, BODY_TOP, COL_W, section_h, sec) for x, sec in zip(COLS, sections)]
    visuals.append(_text(COLS[0], example_y, FULL_W, example_h, [("body", (
        "Example: Net Revenue Achievement, actual SAR 41.2M against a target of SAR 48.0M. Variance −14.2%, so "
        "the score is 85 + 0.6 × (−14.2) = 76.5, rounded to 77: Watch."))]))
    xs = [COLS[0] + (slicer_w + GAP) * i for i in range(3)]  # 30, 354, 678
    visuals += [Visual("slicerDropdown", x, slicers_y, slicer_w, slicer_h, roles={"Values": [col("BSC KPI", c)]},
                       props=select_all_selection())
                for x, c in zip(xs, ["Pillar", "Objective Title", "Owner"])]
    legend_x = xs[-1] + slicer_w + GAP  # 1002
    visuals.append(_text(legend_x, slicers_y, COLS[0] + FULL_W - legend_x, slicer_h, [("body", (
        "Better when: higher = higher is better · lower = lower is better · ceiling = must stay at or below "
        "the target · on_target = the closer to the target the better. Weight: the KPI's corporate weight within "
        "its pillar."))]))
    kpi_num = col("BSC KPI", "KPI Num")
    fields = [kpi_num] + [col("BSC KPI", c) for c in ("Pillar", "Objective Title", "KPI Name", "Definition",
                                                       "Direction")]
    fields += [meas("BSC Target Basis"), meas("BSC KPI Weight"), col("BSC KPI", "Owner"), col("BSC KPI", "Co Owners")]
    visuals.append(Visual("table", COLS[0], table_y, FULL_W, CONTENT_END - table_y, title="Every active KPI",
                          roles={"Values": fields}, filters=[Filter(col("BSC KPI", "Is Active"), "in", ["Yes"])],
                          sort=kpi_num, sort_dir="asc", props=word_wrap()))
    return Page("definitions", "How scores are calculated", visuals)


GUIDE_PAGES: list[Page] = [_guide_page(), _definitions_page()]

PAGES: list[Page] = SCORECARD_PAGES + [KPI_DETAIL] + FAMILY_PAGES + GUIDE_PAGES


def build_pages(build_date: datetime.date) -> list[Page]:
    """The report's pages with the Date slicer saved on `build_date`'s year (`PAGES` is today's)."""
    return scorecard_pages(build_date) + [KPI_DETAIL] + FAMILY_PAGES + GUIDE_PAGES
