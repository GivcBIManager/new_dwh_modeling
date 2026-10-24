"""The report's pages: seven scorecard pages, the hidden KPI detail drill-through page, then the family pages.

`PAGES` is the list `build.py` writes. Task 6 fills `FAMILY_PAGES` (they follow KPI detail, in that order) and can
reuse `back_button`, `label_text`, `select_all_selection`, `_slicers` and `_nav_buttons`.
Canvas 1920 x 1080: header row y 0-110 (slicers left, page buttons right), content below.
"""
from __future__ import annotations

from model import Field, Filter, Page, Visual, col, meas

# Roles of the HNH visual (capabilities.json) -> 'BSC KPI' column, as the visual README's field-well table.
ATTRIBUTE_ROLES = {
    "kpi": "KPI Code", "kpiName": "KPI Name", "shortLabel": "Short Label", "pillar": "Pillar",
    "pillarOrder": "Pillar Order", "pillarWeight": "Pillar Weight", "pillarQuestion": "Pillar Question",
    "objectiveCode": "Objective Code", "objectiveTitle": "Objective Title", "objectiveOrder": "Objective Order",
    "kpiType": "KPI Type", "direction": "Direction", "valueFormat": "Value Format", "displayOrder": "Display Order",
    "kpiStatus": "Status", "valueSource": "Value Source", "owner": "Owner", "scoreBase": "Score Base",
    "scoreSlope": "Score Slope", "goodFrom": "Good From", "watchFrom": "Watch From",
}

BRANCH_NAME = col("Branch", "Branch Name")
IS_HOSPITAL = col("Branch", "Is Hospital")
YEAR_MONTH_NAME = col("Date", "Year Month Name")  # "Aug 2026", sorted by 'Date'[Year Month]: shown and drilled on


def _lit(value: str | bool) -> dict:
    v = str(value).lower() if isinstance(value, bool) else "'" + value.replace("'", "''") + "'"
    return {"expr": {"Literal": {"Value": v}}}


def label_text(text: str) -> dict:
    """The button label object (one place to correct the property names against the real template)."""
    return {"text": [{"properties": {"show": _lit(True), "text": _lit(text)}}]}


def select_all_selection() -> dict:
    """Slicer selection: multi-select with a "Select all" entry (one place to correct the property names)."""
    return {"selection": [{"properties": {"singleSelect": _lit(False), "selectAllCheckboxEnabled": _lit(True)}}]}


BUTTON_BLUE, BUTTON_BLUE_DARK, WHITE = "#13ACE3", "#1478BE", "#FFFFFF"


def _num(value: float) -> dict:
    return {"expr": {"Literal": {"Value": f"{value}D"}}}


def _colour(hex_colour: str) -> dict:
    return {"solid": {"color": _lit(hex_colour)}}


def button_style(kind: str) -> dict:
    """The one place for button looks. As the handover's buttons write them: `show` in an entry without a selector,
    colours in the default state's entry (selector id "default"). "primary" (page navigation, Open detail):
    brand-blue fill, white text, no outline. "outline" (Back): no fill, blue-dark outline and text."""
    default = {"id": "default"}
    if kind == "primary":
        fill = [{"properties": {"show": _lit(True)}},
                {"properties": {"fillColor": _colour(BUTTON_BLUE), "transparency": _num(0)}, "selector": default}]
        outline = [{"properties": {"show": _lit(False)}}]
        text = WHITE
    elif kind == "outline":
        fill = [{"properties": {"show": _lit(False)}}]
        outline = [{"properties": {"show": _lit(True)}},
                   {"properties": {"lineColor": _colour(BUTTON_BLUE_DARK), "weight": _num(1),
                                   "transparency": _num(0)}, "selector": default}]
        text = BUTTON_BLUE_DARK
    else:
        raise ValueError(f"button style must be 'primary' or 'outline', got {kind!r}")
    return {"fill": fill, "outline": outline,
            "text": [{"properties": {"fontColor": _colour(text)}, "selector": default}]}


def button_props(link: dict, label: str, kind: str) -> dict:
    """A button's format objects: the action (`visualLink` properties besides show), the label and the style."""
    style = button_style(kind)
    return {"visualLink": [{"properties": {"show": _lit(True), **link}}],
            "text": label_text(label)["text"] + style.pop("text"), **style}


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


def _slicers(x0: float = 16, shrink: float = 0) -> list[Visual]:
    """The four header slicers from x0; `shrink` narrows them to make room for a Back button."""
    w = [300 - shrink, 220 - shrink / 2, 360 - shrink, 220 - shrink / 2]
    xs = [x0]
    for width in w[:-1]:
        xs.append(xs[-1] + width + 10)
    return [
        Visual("slicerDropdown", xs[0], 20, w[0], 80, roles={"Values": [BRANCH_NAME]}, filters=[_hospitals()],
               props=select_all_selection()),
        Visual("slicerDropdown", xs[1], 20, w[1], 80, roles={"Values": [col("Branch", "BSC Category")]}),
        Visual("slicerRelativeDate", xs[2], 20, w[2], 80, roles={"Values": [col("Date", "Date")]}),
        Visual("slicerDropdown", xs[3], 20, w[3], 80, roles={"Values": [col("Time Calculation", "Time Calculation")]}),
    ]


def _nav_buttons() -> list[Visual]:
    out = []
    for i, (name, display, *_rest) in enumerate(_SCORECARD):
        out.append(Visual("buttonNavigate", 1156 + 108 * i, 35, 104, 50, props=button_props(
            {"type": _lit("PageNavigation"), "navigationSection": _lit(name)}, display, "primary")))
    return out


def _scorecard_page(name: str, display: str, pillar: str | None, mode: str, payload: str) -> Page:
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
    return Page(name, display, _slicers() + _nav_buttons() + [visual], filters=page_filters)


SCORECARD_PAGES: list[Page] = [_scorecard_page(*row) for row in _SCORECARD]


# ---- KPI detail ---------------------------------------------------------------------------------------------------

def _kpi_detail() -> Page:
    """Drill-through target (KPI Code, keep all filters). Header: Back, the four slicers (synced by field with the
    scorecard pages), the seven page buttons. The "Open detail" button drills on the matrix's cell selection
    (Branch Name x Year Month Name, the family pages' drill fields); the matrix is the drill source and sits beside
    the button. The manual-entry note is a multi-row card: with its not-blank filter it renders empty for a measure
    KPI, where a card would show "(Blank)"."""
    cards = ["BSC Actual", "BSC Target", "BSC Score", "BSC State", "BSC Numerator", "BSC Denominator"]
    visuals = [back_button()] + _slicers(130, shrink=40) + _nav_buttons()
    visuals += [Visual("card", 16 + 310 * i, 120, 300, 130, roles={"Values": [meas(m)]})
                for i, m in enumerate(cards)]
    visuals += [
        Visual("lineChart", 16, 270, 940, 300, roles={"Category": [YEAR_MONTH_NAME],
                                                      "Y": [meas("BSC Actual"), meas("BSC Target")]},
               title="Actual vs target by month", sort=YEAR_MONTH_NAME, sort_dir="asc"),
        Visual("barChart", 976, 270, 928, 300, roles={"Category": [BRANCH_NAME], "Y": [meas("BSC Actual")]},
               title="Actual by hospital", filters=[_hospitals()], sort=meas("BSC Actual"), sort_dir="desc"),
        Visual("multiRowCard", 16, 590, 940, 370,
               roles={"Values": [col("BSC KPI", "KPI Name"), col("BSC KPI", "Definition"), col("BSC KPI", "Owner"),
                                 col("BSC KPI", "Co Owners"), meas("BSC Target Basis"), meas("BSC KPI Weight")]}),
        Visual("matrix", 976, 590, 700, 210, title="Select a hospital and month, then Open detail",
               roles={"Rows": [BRANCH_NAME], "Columns": [YEAR_MONTH_NAME], "Values": [meas("BSC Actual")]},
               filters=[_hospitals()]),
        Visual("buttonDrill", 1690, 590, 214, 50, props=button_props(
            {"type": _lit("Drillthrough"), "drillthroughSection": {
                "expr": {"Measure": {"Expression": {"SourceRef": {"Entity": "_Measures"}},
                                     "Property": "BSC Detail Page"}}}},
            "Open detail", "primary")),
        Visual("multiRowCard", 976, 810, 928, 150, roles={"Values": [meas("BSC Manual Note")]},
               title="Manual entry note", filters=[Filter(meas("BSC Manual Note"), "notblank")]),
    ]
    return Page("kpi_detail", "KPI detail", visuals, drill_fields=[col("BSC KPI", "KPI Code")], hidden=True)


KPI_DETAIL: Page = _kpi_detail()

# ---- family detail pages --------------------------------------------------------------------------------------------

# Each chart, table and matrix takes a title: a label of this repo (not title-cased), shown on the visual.

def _bar(title: str, measure: str, by: Field, n: int | None = None) -> dict:
    return {"sample": "barChart", "title": title, "roles": {"Category": [by], "Y": [meas(measure)]},
            "sort": meas(measure), "top_n": (meas(measure), n) if n else None}


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
    """The text box content (one place to correct the property names against the real template)."""
    return {"general": [{"properties": {"paragraphs": [{"textRuns": [{"value": text}]}]}}]}


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
                              title=c["title"], sort=c.get("sort"), top_n=c.get("top_n")))
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
                 [_matrix("Income statement: actual vs budget",
                          [col("FS Line", "FS Caption"), col("FS Line", "FS Line")],
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
                 [_bar("NPS by domain", "NPS (5-point)", col("Survey Question", "Domain En")),
                  _bar("NPS by department (top 15)", "NPS (5-point)", _DEPT, 15),
                  _table("Promoters, passives and detractors by question (top 20)",
                         col("Survey Question", "Question En"), ["% Promoters", "% Passives", "% Detractors"], 20,
                         rank="NPS Answers")]),
]

PAGES: list[Page] = SCORECARD_PAGES + [KPI_DETAIL] + FAMILY_PAGES
