"""Scorecard and KPI detail (spec "Pages" 3 and 7).

Scorecard (`scorecard_page`): Hospital, Month and Area dropdowns; a table of every active KPI (Area, KPI code and name,
[HR KPI Status Text] coloured by [HR KPI Status Colour], [HR KPI Actual Text], [HR KPI Target Text], [HR KPI Watch]),
sorted by Display Order; a "Drill through to KPI detail" button, enabled by one selected table row; a matrix of KPI x
hospital showing [HR KPI Status Text] in the same colours. Both are filtered to Kind "kpi" and Status "active". There
is no variance column: the model has no variance measure, and the report adds none (ruling R22).

KPI detail (`kpi_detail_page`, hidden): reached by drill-through on 'HR KPI'[KPI Code] with all filters kept. Left, the
KPI's name and the definition panel (Definition, Formula, Source System, Grain, Caveats); right, cards for
[HR KPI Actual Text], target and status, the 24-month line of actual against target and watch, and the bar by
hospital. The Month slicer (synced with every page) does not reach the line or the bar: NoFilter interactions, so they
show the last 24 closed months ('Date'[Month Offset] 1 to 24) and every hospital whatever the selection. Back returns
to the page you came from.
"""
from __future__ import annotations

from frame import CONTENT, NAVY, _lit, button_props, no_container
from hr_frame import (HR_ACTUAL_TEXT, HR_STATUS_COLOUR, HR_STATUS_TEXT, HR_TARGET_TEXT, KPI_CODE, SUB_TAB_X,
                      SUB_TAB_Y, bsc, card_look, filters, hospitals, measure_colour, page_frame)
from model import Filter, Interaction, Page, Visual, col, meas

X0, Y0, W0, H0 = CONTENT  # 30, 186, 1860, ...
GAP = 24

AREA = col("HR KPI", "Area")
KIND = col("HR KPI", "Kind")
STATUS = col("HR KPI", "Status")
KPI_NAME = col("HR KPI", "KPI Name")
DISPLAY_ORDER = col("HR KPI", "Display Order")
BRANCH_NAME = col("Branch", "Branch Name")
YEAR_MONTH = col("Date", "Year Month Name")
MONTH_OFFSET = col("Date", "Month Offset")
KPI_DETAIL_NAME = "kpi_detail"

ACTIVE_KPIS = [Filter(KIND, "eq", ["kpi"]), Filter(STATUS, "eq", ["active"])]

# ---- Scorecard ----------------------------------------------------------------------------------------------------

AREA_SLICER = (SUB_TAB_X, 90, 270, 66)  # right of the Month slicer, as the others in the filter bar
TABLE_Y, TABLE_H = Y0, 480
DRILL_Y, DRILL_H, DRILL_W = TABLE_Y + TABLE_H + GAP, 54, 420
MATRIX_Y = DRILL_Y + DRILL_H + GAP  # 744
MATRIX_H = 600
SCORECARD_H = MATRIX_Y + MATRIX_H + 30  # 1374: the page scrolls

WILDCARD = {"dataViewWildcard": {"matchingOption": 1}}


def status_colours() -> dict:
    """The status cells' font colour from [HR KPI Status Colour], for the [HR KPI Status Text] column (conditional
    formatting by field value, as the Press Ganey table's `fontColor`)."""
    return {"values": [{"properties": {"fontColor": measure_colour(HR_STATUS_COLOUR.name)},
                        "selector": {"data": [WILDCARD], "metadata": HR_STATUS_TEXT.ref}}]}


def _wrap(props: dict) -> dict:
    return {**props, "values": props["values"] + [{"properties": {"wordWrap": _lit(True)}}],
            "columnHeaders": [{"properties": {"wordWrap": _lit(True)}}]}


def _area_slicer() -> Visual:
    return Visual("slicerDropdown", *AREA_SLICER, roles={"Values": [AREA]}, filters=[ACTIVE_KPIS[0]],
                  props={**bsc.select_all_selection(), **bsc.dropdown_look()}, labels={AREA: "Area"})


def scorecard_page() -> Page:
    bar = filters() + [_area_slicer()]
    watch = meas("HR KPI Watch")
    table_fields = [AREA, KPI_CODE, KPI_NAME, HR_STATUS_TEXT, HR_ACTUAL_TEXT, HR_TARGET_TEXT, watch, DISPLAY_ORDER]
    table = Visual("table", X0, TABLE_Y, W0, TABLE_H, title="Every active KPI: select a row, then drill through",
                   roles={"Values": table_fields}, filters=list(ACTIVE_KPIS), sort=DISPLAY_ORDER, sort_dir="asc",
                   props=_wrap(status_colours()), labels={DISPLAY_ORDER: "Order", watch: "Watch at"})
    link = {"type": _lit("Drillthrough"), "drillthroughSection": _lit(KPI_DETAIL_NAME)}
    drill = Visual("buttonDrill", X0, DRILL_Y, DRILL_W, DRILL_H,
                   props={**button_props(link, "Drill through to KPI detail →", "primary"), **no_container()})
    matrix = Visual("matrix", X0, MATRIX_Y, W0, MATRIX_H, title="Status by hospital",
                    roles={"Rows": [KPI_NAME], "Columns": [BRANCH_NAME], "Values": [HR_STATUS_TEXT]},
                    filters=list(ACTIVE_KPIS) + [hospitals()], sort=KPI_NAME, sort_dir="asc", props=status_colours())
    return Page("scorecard", "Scorecard", page_frame("scorecard", bar) + [table, drill, matrix],
                height=SCORECARD_H)


# ---- KPI detail ---------------------------------------------------------------------------------------------------

LEFT_W = 700
RIGHT_X = X0 + LEFT_W + GAP  # 754
RIGHT_W = X0 + W0 - RIGHT_X  # 1136
CARD_W = (RIGHT_W - 2 * GAP) / 3
TITLE_H = 60
CARDS_H = 150
LINE_Y = Y0 + CARDS_H + GAP
LINE_H = 380
BAR_Y = LINE_Y + LINE_H + GAP
BAR_H = Y0 + H0 - BAR_Y
BACK_W = 110

# (HR KPI column, panel height)
DEFINITION = [("Definition", 150), ("Formula", 120), ("Source System", 90), ("Grain", 90), ("Caveats", 150)]


def kpi_detail_page() -> Page:
    hospital, month = filters()
    back = bsc.back_button(SUB_TAB_X, SUB_TAB_Y, BACK_W, 54)
    visuals = page_frame(None, [hospital, month, back])
    wrap = {"wordWrap": [{"properties": {"show": _lit(True)}}]}
    visuals.append(Visual("card", X0, Y0, LEFT_W, TITLE_H, roles={"Values": [KPI_NAME]},
                          props={**card_look(20, NAVY, box=True), **wrap}))
    y = Y0 + TITLE_H + GAP
    for name, h in DEFINITION:
        visuals.append(Visual("card", X0, y, LEFT_W, h, roles={"Values": [col("HR KPI", name)]},
                              props={**card_look(12, NAVY, category=True, box=True), **wrap}))
        y += h + GAP
    figures = [(HR_ACTUAL_TEXT, "Actual", card_look(28, NAVY, category=True, box=True)),
               (HR_TARGET_TEXT, "Target", card_look(28, NAVY, category=True, box=True)),
               (HR_STATUS_TEXT, "Status", card_look(24, measure_colour(HR_STATUS_COLOUR.name), category=True,
                                                    box=True))]
    for i, (field, label, props) in enumerate(figures):
        visuals.append(Visual("card", RIGHT_X + i * (CARD_W + GAP), Y0, CARD_W, CARDS_H,
                              roles={"Values": [field]}, props=props, labels={field: label}))
    line = Visual("lineChart", RIGHT_X, LINE_Y, RIGHT_W, LINE_H,
                  title="Actual, target and watch, last 24 closed months",
                  roles={"Category": [YEAR_MONTH],
                         "Y": [meas("HR KPI Actual"), meas("HR KPI Target"), meas("HR KPI Watch")]},
                  filters=[Filter(MONTH_OFFSET, "in", list(range(1, 25)))], sort=YEAR_MONTH, sort_dir="asc")
    bars = Visual("barChart", RIGHT_X, BAR_Y, RIGHT_W, BAR_H, title="By hospital",
                  roles={"Category": [BRANCH_NAME], "Y": [meas("HR KPI Actual")]}, filters=[hospitals()])
    visuals += [line, bars]
    interactions = [Interaction(month, line, "NoFilter"), Interaction(month, bars, "NoFilter"),
                    Interaction(hospital, bars, "NoFilter")]
    return Page(KPI_DETAIL_NAME, "KPI detail", visuals, interactions=interactions, drill_fields=[KPI_CODE],
                hidden=True)
