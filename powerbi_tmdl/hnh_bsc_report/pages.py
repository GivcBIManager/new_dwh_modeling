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
YEAR_MONTH = col("Date", "Year Month")


def _lit(value: str | bool) -> dict:
    v = str(value).lower() if isinstance(value, bool) else "'" + value.replace("'", "''") + "'"
    return {"expr": {"Literal": {"Value": v}}}


def label_text(text: str) -> dict:
    """The button label object (one place to correct the property names against the real template)."""
    return {"text": [{"properties": {"show": _lit(True), "text": _lit(text)}}]}


def select_all_selection() -> dict:
    """Slicer selection: multi-select with a "Select all" entry (one place to correct the property names)."""
    return {"selection": [{"properties": {"singleSelect": _lit(False), "selectAllCheckboxEnabled": _lit(True)}}]}


def back_button(x: float = 16, y: float = 35, w: float = 104, h: float = 50) -> Visual:
    """A button whose action is Back; for every page reached by drill-through or a link."""
    return Visual("buttonNavigate", x, y, w, h, props={
        "visualLink": [{"properties": {"show": _lit(True), "type": _lit("Back")}}], **label_text("Back")})


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
        out.append(Visual("buttonNavigate", 1156 + 108 * i, 35, 104, 50, props={
            "visualLink": [{"properties": {"show": _lit(True), "type": _lit("PageNavigation"),
                                           "navigationSection": _lit(name)}}],
            **label_text(display)}))
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
    (Branch Name x Year Month) with keep-all-filters; the matrix is the drill source and sits beside the button."""
    cards = ["BSC Actual", "BSC Target", "BSC Score", "BSC State", "BSC Numerator", "BSC Denominator"]
    visuals = [back_button()] + _slicers(130, shrink=40) + _nav_buttons()
    visuals += [Visual("card", 16 + 310 * i, 120, 300, 130, roles={"Values": [meas(m)]})
                for i, m in enumerate(cards)]
    visuals += [
        Visual("lineChart", 16, 270, 940, 300, roles={"Category": [YEAR_MONTH],
                                                      "Y": [meas("BSC Actual"), meas("BSC Target")]},
               sort=YEAR_MONTH, sort_dir="asc"),
        Visual("barChart", 976, 270, 928, 300, roles={"Category": [BRANCH_NAME], "Y": [meas("BSC Actual")]},
               filters=[_hospitals()], sort=meas("BSC Actual"), sort_dir="desc"),
        Visual("multiRowCard", 16, 590, 940, 370,
               roles={"Values": [col("BSC KPI", "KPI Name"), col("BSC KPI", "Definition"), col("BSC KPI", "Owner"),
                                 col("BSC KPI", "Co Owners"), meas("BSC Target Basis"), meas("BSC KPI Weight")]}),
        Visual("matrix", 976, 590, 700, 210, title="Select a hospital and month, then Open detail",
               roles={"Rows": [BRANCH_NAME], "Columns": [YEAR_MONTH], "Values": [meas("BSC Actual")]},
               filters=[_hospitals()]),
        Visual("buttonDrill", 1690, 590, 214, 50, props={
            "visualLink": [{"properties": {"show": _lit(True), "type": _lit("Drillthrough"), "drillthroughSection": {
                "expr": {"Measure": {"Expression": {"SourceRef": {"Entity": "_Measures"}},
                                     "Property": "BSC Detail Page"}}}}}],
            **label_text("Open detail")}),
        Visual("card", 976, 810, 928, 150, roles={"Values": [meas("BSC Manual Note")]},
               filters=[Filter(meas("BSC Manual Note"), "notblank")]),
    ]
    return Page("kpi_detail", "KPI detail", visuals, drill_fields=[col("BSC KPI", "KPI Code")], hidden=True)


KPI_DETAIL: Page = _kpi_detail()

# ---- family detail pages --------------------------------------------------------------------------------------------

def _bar(measure: str, by: Field, n: int | None = None) -> dict:
    return {"sample": "barChart", "roles": {"Category": [by], "Y": [meas(measure)]},
            "sort": meas(measure), "top_n": (meas(measure), n) if n else None}


def _table(by: Field, measures: list[str], n: int | None = None, rank: str | None = None) -> dict:
    return {"sample": "table", "roles": {"Values": [by] + [meas(m) for m in measures]},
            "top_n": (meas(rank or measures[0]), n) if n else None}


def _matrix(rows: list[Field], measures: list[str]) -> dict:
    return {"sample": "matrix", "roles": {"Rows": rows, "Values": [meas(m) for m in measures]}}


def title_text(text: str) -> dict:
    """The text box content (one place to correct the property names against the real template)."""
    return {"general": [{"properties": {"paragraphs": [{"textRuns": [{"value": text}]}]}}]}


def _family_page(name: str, display: str, cards: list[str], charts: list[dict]) -> Page:
    """Drill-through page: Back, a title, a card of the filtered hospital and month, the measure cards, then a
    2-column grid of charts. No slicers: filters arrive by drill-through with keep-all-filters."""
    visuals = [back_button(),
               Visual("textbox", 130, 25, 1000, 70, props=title_text(display)),
               Visual("multiRowCard", 1300, 10, 604, 95, roles={"Values": [BRANCH_NAME, YEAR_MONTH]})]
    gap = 10
    w = (1888 - gap * (len(cards) - 1)) / len(cards)
    visuals += [Visual("card", 16 + (w + gap) * i, 130, w, 110, roles={"Values": [meas(m)]})
                for i, m in enumerate(cards)]
    for i, c in enumerate(charts):
        visuals.append(Visual(c["sample"], 16 + 958 * (i % 2), 260 + 400 * (i // 2), 930, 390, roles=c["roles"],
                              sort=c.get("sort"), top_n=c.get("top_n")))
    return Page(name, display, visuals, drill_fields=[BRANCH_NAME, YEAR_MONTH], hidden=True)


_DEPT = col("Department", "Department Name")
_PAYER_CAT = col("Payer", "Category")

FAMILY_PAGES: list[Page] = [
    _family_page("fam_revenue", "Revenue detail",
                 ["Revenue", "Gross Charges", "Line Discount", "Claimable Revenue"],
                 [_bar("Revenue", _DEPT, 15), _bar("Revenue", col("Product Category", "High Level Department")),
                  _bar("Revenue", _PAYER_CAT), _table(col("Staff", "Staff Name"), ["Revenue"], 20)]),
    _family_page("fam_finance", "Finance detail",
                 ["EBITDA", "EBITDA Margin %", "Net Profit", "Budget Variance %"],
                 [_matrix([col("FS Line", "FS Caption"), col("FS Line", "FS Line")],
                          ["IS Actual", "IS Budget", "Budget Variance"]),
                  _bar("GL Movement", col("GL Account", "Natural Account Name"), 15)]),
    _family_page("fam_volume", "Patient volume detail",
                 ["OP Visits", "ER Visits", "Admissions", "New Patients", "Returning Patients"],
                 [_bar("OP Visits", _DEPT, 15), _bar("Census", _PAYER_CAT), _bar("Average Wait (min)", _DEPT, 15)]),
    _family_page("fam_beds", "Beds & clinical detail",
                 ["Bed Occupancy %", "ALOS (days)", "Readmission Rate 30d %", "ICU Readmissions 48h",
                  "Bed Turnover"],
                 [_bar("Bed Occupancy %", col("Bed", "Current Ward")), _bar("ALOS (days)", _DEPT, 15),
                  _table(col("Discharge Outcome", "Outcome Group"), ["Discharges"])]),
    _family_page("fam_revenue_cycle", "Revenue cycle detail",
                 ["Claim Rejection Rate %", "First-pass Rejection Rate %", "Pre-auth Approval Rate %", "Leak Rate %",
                  "Billed Not Submitted"],
                 [_bar("Claims Rejected", col("NPHIES Reason", "Reason"), 15),
                  _bar("Claimed Amount", col("Payer", "Purchaser Name"), 15),
                  _table(col("Claim Status", "Submission Status"), ["Billed Amount"]),
                  _bar("Lost Value", _DEPT, 15)]),
    _family_page("fam_workforce", "Workforce detail",
                 ["Headcount", "FTE", "Saudisation Rate %", "Turnover Rate %", "Hires"],
                 [_bar("Headcount", col("HR Department", "Department Name"), 15),
                  _bar("Headcount", col("Job", "Job Name"), 15),
                  _bar("Headcount", col("Employee", "Nationality"), 10)]),
    _family_page("fam_experience", "Patient experience detail",
                 ["Hospital NPS (5-point)", "Physician NPS (5-point)", "NPS Answers", "Response Rate %"],
                 [_bar("NPS (5-point)", col("Survey Question", "Domain En")),
                  _bar("NPS (5-point)", _DEPT, 15),
                  _table(col("Survey Question", "Question En"), ["% Promoters", "% Passives", "% Detractors"], 20,
                         rank="NPS Answers")]),
]

PAGES: list[Page] = SCORECARD_PAGES + [KPI_DETAIL] + FAMILY_PAGES
