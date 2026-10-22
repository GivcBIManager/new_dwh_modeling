"""The report's pages: seven scorecard pages, the hidden KPI detail drill-through page, then the family pages.

`PAGES` is the list `build.py` writes. Task 6 fills `FAMILY_PAGES` (they follow KPI detail, in that order) and can
reuse `back_button`, `label_text`, `select_all_selection`, `_slicers` and `_nav_buttons`.
Canvas 1920 x 1080: header row y 0-110 (slicers left, page buttons right), content below.
"""
from __future__ import annotations

from model import Filter, Page, Visual, col, meas

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

# Task 6 appends the family pages here.
FAMILY_PAGES: list[Page] = []

PAGES: list[Page] = SCORECARD_PAGES + [KPI_DETAIL] + FAMILY_PAGES
