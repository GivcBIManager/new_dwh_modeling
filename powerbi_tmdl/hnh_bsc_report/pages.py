"""The report's pages: seven scorecard pages, the hidden KPI detail drill-through page, then the family pages.

`PAGES` is the list `build.py` writes. Task 6 fills `FAMILY_PAGES` (they follow KPI detail, in that order) and can
reuse `back_button`, `label_text`, `select_all_selection`, `_slicers` and `_nav_buttons`.
Canvas 1920 x 1080: header row y 0-110 (slicers left, page buttons right), content below.
"""
from __future__ import annotations

import datetime

from model import Field, Filter, Page, Visual, col, meas

# Roles of the HNH visual (capabilities.json) -> 'BSC KPI' column, as the visual README's field-well table.
ATTRIBUTE_ROLES = {
    "kpi": "KPI Code", "kpiName": "KPI Name", "shortLabel": "Short Label", "pillar": "Pillar",
    "pillarOrder": "Pillar Order", "pillarWeight": "Pillar Weight", "pillarQuestion": "Pillar Question",
    "objectiveCode": "Objective Code", "objectiveTitle": "Objective Title", "objectiveOrder": "Objective Order",
    "kpiType": "KPI Type", "direction": "Direction", "valueFormat": "Value Format", "displayOrder": "Display Order",
    "kpiStatus": "Status", "valueSource": "Value Source", "owner": "Owner", "coOwners": "Co Owners", "scoreBase": "Score Base",
    "scoreSlope": "Score Slope", "goodFrom": "Good From", "watchFrom": "Watch From",
}

BRANCH_NAME = col("Branch", "Branch Name")
IS_HOSPITAL = col("Branch", "Is Hospital")
YEAR_MONTH_NAME = col("Date", "Year Month Name")  # "Aug 2026", sorted by 'Date'[Year Month]: shown and drilled on


def _lit(value: str | bool) -> dict:
    v = str(value).lower() if isinstance(value, bool) else "'" + value.replace("'", "''") + "'"
    return {"expr": {"Literal": {"Value": v}}}


DEFAULT_STATE, DISABLED_STATE = {"id": "default"}, {"id": "disabled"}


def label_text(text: str) -> dict:
    """The button label object, as Power BI Desktop 2.158's actionButton reads it (BasicShapeVisual bundle): `show`
    from the entry without a selector, the label per button state (default, hover, selected = press, disabled), so in
    the default state's entry (selector id "default"); the other states fall back to it. A label in an entry without
    a selector is never read: the button renders blank."""
    return {"text": [{"properties": {"show": _lit(True)}},
                     {"properties": {"text": _lit(text)}, "selector": DEFAULT_STATE}]}


def select_all_selection() -> dict:
    """Slicer selection: multi-select with a "Select all" entry (one place to correct the property names)."""
    return {"selection": [{"properties": {"singleSelect": _lit(False), "selectAllCheckboxEnabled": _lit(True)}}]}


BUTTON_BLUE, BUTTON_BLUE_DARK, WHITE = "#13ACE3", "#1478BE", "#FFFFFF"
BUTTON_DISABLED_FILL, BUTTON_DISABLED_TEXT = "#DCE9F2", "#1478BE"  # Open detail before a cell is selected


def _num(value: float) -> dict:
    return {"expr": {"Literal": {"Value": f"{value}D"}}}


def _colour(hex_colour: str) -> dict:
    return {"solid": {"color": _lit(hex_colour)}}


def button_style(kind: str) -> dict:
    """The one place for button looks. As the handover's buttons write them: `show` in an entry without a selector,
    colours in the default state's entry (selector id "default"). "primary" (page navigation, Open detail):
    brand-blue fill, white text, no outline; disabled (Open detail until a matrix cell is selected; Desktop's default
    is a light grey fill with grey text): pale blue fill, blue-dark text. "outline" (Back): no fill, blue-dark
    outline and text."""
    default = DEFAULT_STATE
    if kind == "primary":
        fill = [{"properties": {"show": _lit(True)}},
                {"properties": {"fillColor": _colour(BUTTON_BLUE), "transparency": _num(0)}, "selector": default},
                {"properties": {"fillColor": _colour(BUTTON_DISABLED_FILL), "transparency": _num(0)},
                 "selector": DISABLED_STATE}]
        outline = [{"properties": {"show": _lit(False)}}]
        text = [{"properties": {"fontColor": _colour(WHITE)}, "selector": default},
                {"properties": {"fontColor": _colour(BUTTON_DISABLED_TEXT)}, "selector": DISABLED_STATE}]
    elif kind == "outline":
        fill = [{"properties": {"show": _lit(False)}}]
        outline = [{"properties": {"show": _lit(True)}},
                   {"properties": {"lineColor": _colour(BUTTON_BLUE_DARK), "weight": _num(1),
                                   "transparency": _num(0)}, "selector": default}]
        text = [{"properties": {"fontColor": _colour(BUTTON_BLUE_DARK)}, "selector": default}]
    else:
        raise ValueError(f"button style must be 'primary' or 'outline', got {kind!r}")
    return {"fill": fill, "outline": outline, "text": text}


def _by_selector(*entry_lists: list[dict]) -> list[dict]:
    """Format object entries merged into one entry per selector (first-seen order)."""
    out: list[dict] = []
    for entries in entry_lists:
        for e in entries:
            match = next((x for x in out if x.get("selector") == e.get("selector")), None)
            if match is None:
                out.append({**e, "properties": dict(e["properties"])})
            else:
                match["properties"].update(e["properties"])
    return out


def button_props(link: dict, label: str, kind: str) -> dict:
    """A button's format objects: the action (`visualLink` properties besides show), the label and the style."""
    style = button_style(kind)
    return {"visualLink": [{"properties": {"show": _lit(True), **link}}],
            "text": _by_selector(label_text(label)["text"], style.pop("text")), **style}


def back_button(x: float = 16, y: float = 35, w: float = 104, h: float = 50) -> Visual:
    """A button whose action is Back; for every page reached by drill-through or a link."""
    return Visual("buttonNavigate", x, y, w, h, props=button_props({"type": _lit("Back")}, "Back", "outline"))


def _hospitals() -> Filter:
    return Filter(IS_HOSPITAL, "in", ["Yes"])


# ---- header -------------------------------------------------------------------------------------------------------

# (page name, display name, pillar filter, mode, payload measure)
_SCORECARD = [
    ("bsc", "BSC", None, "overview", "BSC Visual Payload Scores"),
    ("financial", "Financial", "Financial", "board", "BSC Visual Payload"),
    ("customer", "Customer", "Customer", "board", "BSC Visual Payload"),
    ("internal_process", "Internal Process", "Internal Process", "board", "BSC Visual Payload"),
    ("learning_growth", "Learning & Growth", "Learning & Growth", "board", "BSC Visual Payload"),
    ("owner_view", "Owner view", None, "owner", "BSC Visual Payload"),
    ("hospital_comparison", "Hospital comparison", None, "comparison", "BSC Visual Payload Scores"),
]


NAV_X = 1156  # the first page button


def year_range(build_date: datetime.date) -> tuple[str, str]:
    """1 January - 31 December of the build year: the Date slicer's saved range. The measures and the header label
    stop at today, so what opens reads as year to date; the range moves on at the next rebuild."""
    return f"{build_date.year}-01-01", f"{build_date.year}-12-31"


def _slicers(build_date: datetime.date, x0: float = 16, right: float = NAV_X - 10) -> list[Visual]:
    """The three header slicers (Branch, BSC Category, Date) spread between x0 and `right` in the ratio 3 : 2 : 4.
    The Date slicer is a From - To range saved at `year_range(build_date)`.
    No Time Calculation slicer (controller ruling): its items applied to [BSC Actual] but not to the target."""
    gap, weights = 10, [3, 2, 4]
    unit = (right - x0 - gap * (len(weights) - 1)) / sum(weights)
    w = [unit * k for k in weights]
    xs = [x0, x0 + w[0] + gap, x0 + w[0] + w[1] + 2 * gap]
    return [
        Visual("slicerDropdown", xs[0], 20, w[0], 80, roles={"Values": [BRANCH_NAME]}, filters=[_hospitals()],
               props=select_all_selection()),
        Visual("slicerDropdown", xs[1], 20, w[1], 80, roles={"Values": [col("Branch", "BSC Category")]}),
        Visual("slicerDateRange", xs[2], 20, w[2], 80, roles={"Values": [col("Date", "Date")]},
               date_range=year_range(build_date)),
    ]


def _nav_buttons() -> list[Visual]:
    out = []
    for i, (name, display, *_rest) in enumerate(_SCORECARD):
        out.append(Visual("buttonNavigate", NAV_X + 108 * i, 35, 104, 50, props=button_props(
            {"type": _lit("PageNavigation"), "navigationSection": _lit(name)}, display, "primary")))
    return out


def _scorecard_page(build_date: datetime.date, name: str, display: str, pillar: str | None, mode: str,
                    payload: str) -> Page:
    roles = {role: [col("BSC KPI", column)] for role, column in ATTRIBUTE_ROLES.items()}
    roles["payload"] = [meas(payload)]
    roles["selectionLabel"] = [meas("BSC Selection Label")]
    filters = []
    if mode == "comparison":
        roles["branch"] = [BRANCH_NAME]
        filters = [_hospitals()]
    visual = Visual("hnhVisual", 0, 120, 1920, 960, roles=roles, filters=filters,
                    props={"scorecard": [{"properties": {"mode": _lit(mode)}}]})
    page_filters = [Filter(col("BSC KPI", "Pillar"), "eq", [pillar])] if pillar else []
    return Page(name, display, _slicers(build_date) + _nav_buttons() + [visual], filters=page_filters)


def scorecard_pages(build_date: datetime.date) -> list[Page]:
    return [_scorecard_page(build_date, *row) for row in _SCORECARD]


SCORECARD_PAGES: list[Page] = scorecard_pages(datetime.date.today())


# ---- KPI detail ---------------------------------------------------------------------------------------------------

def word_wrap() -> dict:
    """A table's text wrap for values and column headers (tableEx `values.wordWrap`, `columnHeaders.wordWrap`)."""
    return {"values": [{"properties": {"wordWrap": _lit(True)}}],
            "columnHeaders": [{"properties": {"wordWrap": _lit(True)}}]}


def _kpi_detail(build_date: datetime.date) -> Page:
    """Drill-through target (KPI Code, keep all filters). Header: Back, the four slicers (synced by field with the
    scorecard pages), the seven page buttons. The "Open detail" button drills on the matrix's cell selection
    (Branch Name x Year Month Name, the family pages' drill fields); the matrix is the drill source and sits beside
    the button. The KPI information and the manual-entry note are tables: a table wraps long text (Definition) where
    a multi-row card truncates it, and drops the rows whose measures are all blank, so a measure KPI shows an empty
    note table where a card showed "(Blank)"."""
    cards = ["BSC Actual", "BSC Target", "BSC Score", "BSC State", "BSC Numerator", "BSC Denominator"]
    visuals = [back_button()] + _slicers(build_date, 130) + _nav_buttons()
    visuals += [Visual("card", 16 + 310 * i, 120, 300, 130, roles={"Values": [meas(m)]})
                for i, m in enumerate(cards)]
    visuals += [
        Visual("lineChart", 16, 270, 940, 300, roles={"Category": [YEAR_MONTH_NAME],
                                                      "Y": [meas("BSC Actual"), meas("BSC Target")]},
               title="Actual vs target by month", sort=YEAR_MONTH_NAME, sort_dir="asc"),
        Visual("barChart", 976, 270, 928, 300, roles={"Category": [BRANCH_NAME], "Y": [meas("BSC Actual")]},
               title="Actual by hospital", filters=[_hospitals()], sort=meas("BSC Actual"), sort_dir="desc"),
        Visual("table", 16, 590, 940, 370, title="About this KPI",
               roles={"Values": [col("BSC KPI", "KPI Name"), col("BSC KPI", "Definition"), col("BSC KPI", "Owner"),
                                 col("BSC KPI", "Co Owners"), meas("BSC Target Basis"), meas("BSC KPI Weight")]},
               props=word_wrap()),
        Visual("matrix", 976, 590, 700, 210, title="Select a hospital and month, then Open detail",
               roles={"Rows": [BRANCH_NAME], "Columns": [YEAR_MONTH_NAME], "Values": [meas("BSC Actual")]},
               filters=[_hospitals()]),
        Visual("buttonDrill", 1690, 590, 214, 50, props=button_props(
            {"type": _lit("Drillthrough"), "drillthroughSection": {
                "expr": {"Measure": {"Expression": {"SourceRef": {"Entity": "_Measures"}},
                                     "Property": "BSC Detail Page"}}}},
            "Open detail", "primary")),
        Visual("table", 976, 810, 928, 150, title="Manual entry note",
               roles={"Values": [col("BSC KPI", "KPI Name"), meas("BSC Manual Note")]}, props=word_wrap()),
    ]
    return Page("kpi_detail", "KPI detail", visuals, drill_fields=[col("BSC KPI", "KPI Code")], hidden=True)


KPI_DETAIL: Page = _kpi_detail(datetime.date.today())

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
    """The text box content: one paragraph, one text run in Segoe UI 20pt bold (the run's `textStyle` with CSS
    values, as Desktop's text box reads it: fontFamily, fontSize, fontWeight)."""
    style = {"fontFamily": "Segoe UI", "fontSize": "20pt", "fontWeight": "bold"}
    return {"general": [{"properties": {"paragraphs": [{"textRuns": [{"value": text, "textStyle": style}]}]}}]}


def _family_page(name: str, display: str, cards: list[str], charts: list[dict]) -> Page:
    """Drill-through page: Back, a title, a card of the filtered hospital and month, the measure cards, then a
    2-column grid of charts. No slicers. Keep all filters is off: only the drill fields (Branch Name, Year Month
    Name) arrive, never KPI detail's 'BSC KPI' drill filter or pillar filter, which every domain measure's guard
    rejects ("... can't be analysed by "BSC KPI""); the page filters hospitals itself (Review Focus 4)."""
    visuals = [back_button(),
               Visual("textbox", 130, 25, 1000, 70, props=title_text(display)),
               Visual("multiRowCard", 1300, 10, 604, 95, roles={"Values": [BRANCH_NAME, YEAR_MONTH_NAME]})]
    gap = 10
    w = (1888 - gap * (len(cards) - 1)) / len(cards)
    visuals += [Visual("card", 16 + (w + gap) * i, 130, w, 110, roles={"Values": [meas(m)]})
                for i, m in enumerate(cards)]
    for i, c in enumerate(charts):
        visuals.append(Visual(c["sample"], 16 + 958 * (i % 2), 260 + 400 * (i // 2), 930, 390, roles=c["roles"],
                              title=c["title"], sort=c.get("sort"), top_n=c.get("top_n"),
                              props=c.get("props") or {}))
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

HEADING_BLUE, BODY_INK = "#1478BE", "#0A1E32"


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


def _text(x: float, y: float, w: float, h: float, paragraphs: list[tuple[str, str]]) -> Visual:
    return Visual("textbox", x, y, w, h, props=text_box(paragraphs))


def _header(title: str) -> list[Visual]:
    return [Visual("textbox", 16, 25, 1100, 70, props=title_text(title))] + _nav_buttons()


def _section(heading: str, bullets: list[str]) -> list[tuple[str, str]]:
    return [("heading", heading)] + [("bullet", b) for b in bullets]


def _guide_page() -> Page:
    cols = [16, 650, 1284]
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
            "Owner view shows Achievement in %: 100% or more is on track, 85% to 99% watch, below 85% at risk."]),
        _section("Go deeper", [
            "The page buttons at the top right move between the scorecard pages.",
            "Right-click a KPI and choose Drill through › KPI detail for its trend, hospitals and definition.",
            "On KPI detail, select a hospital and month in the table, then Open detail for the detail page behind "
            "it.",
            "Back (top left) returns to the page you came from.",
            "Hospital comparison: click a pillar header to see its objectives, then an objective header to see its "
            "KPIs; the path above the table goes back up.",
            "Owner view: click an owner's card to list only their KPIs; click it again to list everyone.",
            "Hover over a KPI for its actual, target, variance and owner."]),
    ]
    visuals = _header("How to use the scorecard")
    visuals.append(_text(16, 120, 1888, 50, [("body", (
        "Overall score  ›  4 pillars  ›  objectives  ›  KPIs  ›  KPI detail  ›  detail pages "
        "(Revenue, Finance, Patient volume, Beds & clinical, Revenue cycle, Workforce, Patient experience)"))]))
    visuals += [_text(x, 185, 620, 440, sec) for x, sec in zip(cols, sections)]
    visuals.append(_text(16, 640, 1888, 420, [("heading", "Pages")] + [("body", t) for t in [
        "BSC: how are we doing overall and in each pillar?",
        "Financial, Customer, Internal Process, Learning & Growth: which KPIs in this pillar are on track, on watch "
        "or at risk?",
        "Owner view: how are each executive's KPIs doing?",
        "Hospital comparison: which hospital leads or lags, and on which pillar, objective or KPI?",
        "KPI detail: how has this KPI moved by month and by hospital, and how is it defined?",
        "Detail pages: what is behind a hospital's figures for a month?",
        "How scores are calculated: how is each score worked out, and what does each KPI measure?"]]))
    return Page("guide", "How to use", visuals)


def _definitions_page() -> Page:
    cols = [16, 650, 1284]
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
    visuals = _header("How scores are calculated")
    visuals += [_text(x, 120, 620, 330, sec) for x, sec in zip(cols, sections)]
    visuals.append(_text(16, 460, 1888, 50, [("body", (
        "Example: Net Revenue Achievement, actual SAR 41.2M against a target of SAR 48.0M. Variance −14.2%, so "
        "the score is 85 + 0.6 × (−14.2) = 76.5, rounded to 77: Watch."))]))
    visuals += [Visual("slicerDropdown", x, 520, 300, 70, roles={"Values": [col("BSC KPI", c)]},
                       props=select_all_selection())
                for x, c in zip([16, 326, 636], ["Pillar", "Objective Title", "Owner"])]
    visuals.append(_text(946, 520, 958, 70, [("body", (
        "Better when: higher = higher is better · lower = lower is better · ceiling = must stay at or below "
        "the target · on_target = the closer to the target the better. Weight: the KPI's corporate weight within "
        "its pillar."))]))
    kpi_num = col("BSC KPI", "KPI Num")
    fields = [kpi_num] + [col("BSC KPI", c) for c in ("Pillar", "Objective Title", "KPI Name", "Definition",
                                                       "Direction")]
    fields += [meas("BSC Target Basis"), meas("BSC KPI Weight"), col("BSC KPI", "Owner"), col("BSC KPI", "Co Owners")]
    visuals.append(Visual("table", 16, 600, 1888, 460, title="Every active KPI", roles={"Values": fields},
                          filters=[Filter(col("BSC KPI", "Is Active"), "in", ["Yes"])], sort=kpi_num,
                          sort_dir="asc", props=word_wrap()))
    return Page("definitions", "How scores are calculated", visuals)


GUIDE_PAGES: list[Page] = [_guide_page(), _definitions_page()]

PAGES: list[Page] = SCORECARD_PAGES + [KPI_DETAIL] + FAMILY_PAGES + GUIDE_PAGES


def build_pages(build_date: datetime.date) -> list[Page]:
    """The report's pages with the Date slicer saved on `build_date`'s year (`PAGES` is today's)."""
    return scorecard_pages(build_date) + [_kpi_detail(build_date)] + FAMILY_PAGES + GUIDE_PAGES
