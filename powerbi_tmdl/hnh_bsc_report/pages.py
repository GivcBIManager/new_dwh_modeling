"""The report's pages: seven scorecard pages, the hidden KPI detail drill-through page, then the family pages.

`PAGES` is the list `build.py` writes. Task 6 fills `FAMILY_PAGES` (they follow KPI detail, in that order).
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


def _slicers() -> list[Visual]:
    selection = {"selection": [{"properties": {"singleSelect": _lit(False), "selectAllCheckboxEnabled": _lit(True)}}]}
    return [
        Visual("slicerDropdown", 16, 20, 300, 80, roles={"Values": [BRANCH_NAME]}, filters=[_hospitals()],
               props=selection),
        Visual("slicerDropdown", 326, 20, 220, 80, roles={"Values": [col("Branch", "BSC Category")]}),
        Visual("slicerRelativeDate", 556, 20, 360, 80, roles={"Values": [col("Date", "Date")]}),
        Visual("slicerDropdown", 926, 20, 220, 80, roles={"Values": [col("Time Calculation", "Time Calculation")]}),
    ]


def _nav_buttons() -> list[Visual]:
    out = []
    for i, (name, display, *_rest) in enumerate(_SCORECARD):
        out.append(Visual("buttonNavigate", 1156 + 108 * i, 35, 104, 50, props={
            "visualLink": [{"properties": {"show": _lit(True), "type": _lit("PageNavigation"),
                                           "navigationSection": _lit(name)}}],
            "text": [{"properties": {"show": _lit(True), "text": _lit(display)}}]}))
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
    cards = ["BSC Actual", "BSC Target", "BSC Score", "BSC State", "BSC Numerator", "BSC Denominator"]
    visuals = _slicers()
    visuals += [Visual("card", 16 + 310 * i, 120, 300, 130, roles={"Values": [meas(m)]})
                for i, m in enumerate(cards)]
    visuals += [
        Visual("lineChart", 16, 270, 940, 380, roles={"Category": [YEAR_MONTH],
                                                      "Y": [meas("BSC Actual"), meas("BSC Target")]},
               sort=YEAR_MONTH, sort_dir="asc"),
        Visual("barChart", 976, 270, 928, 380, roles={"Category": [BRANCH_NAME], "Y": [meas("BSC Actual")]},
               filters=[_hospitals()], sort=meas("BSC Actual"), sort_dir="desc"),
        Visual("multiRowCard", 16, 670, 940, 300,
               roles={"Values": [col("BSC KPI", "KPI Name"), col("BSC KPI", "Definition"), col("BSC KPI", "Owner"),
                                 col("BSC KPI", "Co Owners"), meas("BSC Target Basis"), meas("BSC KPI Weight")]}),
        Visual("card", 976, 670, 928, 150, roles={"Values": [meas("BSC Manual Note")]},
               filters=[Filter(meas("BSC Manual Note"), "notblank")]),
        Visual("buttonDrill", 976, 840, 220, 50, props={
            "visualLink": [{"properties": {"show": _lit(True), "type": _lit("Drillthrough"), "drillthroughSection": {
                "expr": {"Measure": {"Expression": {"SourceRef": {"Entity": "_Measures"}},
                                     "Property": "BSC Detail Page"}}}}}],
            "text": [{"properties": {"show": _lit(True), "text": _lit("Open detail")}}]}),
    ]
    return Page("kpi_detail", "KPI detail", visuals, drill_fields=[col("BSC KPI", "KPI Code")], hidden=True)


KPI_DETAIL: Page = _kpi_detail()

# Task 6 appends the family pages here.
FAMILY_PAGES: list[Page] = []

PAGES: list[Page] = SCORECARD_PAGES + [KPI_DETAIL] + FAMILY_PAGES
