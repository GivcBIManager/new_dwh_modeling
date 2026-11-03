"""Scorecard and KPI detail (spec "Pages" 3 and 7).

Scorecard (`scorecard_page`): Branch, Month, Area and Period dropdowns; a table of every active KPI (Area, KPI
name, Status: [HR KPI Status Text] coloured by [HR KPI Status Colour], Actual, Target, Variance, Watch at: the text
measures; Order), sorted by Display Order, with fixed column widths that fill the table (no total row); a "Drill
through to KPI detail" button, enabled by one selected table row; a matrix of KPI x branch showing
[HR KPI Status Text] in the same colours. The drill-through field is 'HR KPI'[KPI Name] (unique, as the code), a
column of both the table and the matrix, so the table needs no KPI Code column and a matrix row drills too. Both are
filtered to Kind "kpi" and Status "active". The cells are the model's text measures (R22): a reader without pay access
reads "Requires pay access" for a pay KPI's figures, target, variance and watch value (final review C1). No sparkline
column: the generator has no sparkline, and KPI detail has the trend.

Period (final review I3): a single-select dropdown on 'Time Calculation' saved on Current, offering Current, QTD and
YTD; on Scorecard and KPI detail only, synced between them (the sync group is the field). Under YTD the
actual, target and status describe January to the selected month: a flow KPI's annual target is pro-rated by the
months (scale_with_months), a snapshot KPI keeps its month-end value. Story stays on one month (R18).

KPI detail (`kpi_detail_page`, hidden): reached by drill-through on 'HR KPI'[KPI Name] only (keep_filters off: the
scorecard's Month would otherwise AND with the line's Month Offset filter and leave one point); the page's own synced
Branch, Month and Period slicers apply. Left, [HR KPI Detail Title] (the KPI's name) and the definition panel
([HR KPI Definition Text], Formula, Source System, Grain, Caveats): opened without a drill-through, the title and the
definition say how to pick a KPI instead of "(Blank)"; right, cards for [HR KPI Actual Text], target and status, the 24-month line of actual against
target and watch, and the bar by branch. The Month slicer (synced with every page) does not reach the line or the
bar: NoFilter interactions, so they show the last 24 closed months ('Date'[Month Offset] 1 to 24) and every branch
whatever the selection. Period does not reach the line either (a monthly trend); the bar follows it. In each chart's
title band (right-aligned, small; ruling R31), [HR KPI Pay Notice] says "Requires pay access" for a pay KPI to a reader without pay access (final review I2), and
"" (an empty card, no filter) otherwise. Back returns to the page you came from.

Both pages carry the branches page filter: the eight hospitals and Head Office (user decision 2026-11-03, the scope
of the HR KPI measures), not the Branch dimension's Group member, which would be a matrix column of "– No data".
"""
from __future__ import annotations

from frame import CONTENT, NAVY, _lit, button_props, no_container
from hr_frame import (HR_ACTUAL_TEXT, HR_STATUS_COLOUR, HR_STATUS_TEXT, HR_TARGET_TEXT, HR_VARIANCE_TEXT,
                      HR_WATCH_TEXT, SUB_TAB_X, SUB_TAB_Y, branches, bsc, card_look, filters, fixed_table,
                      measure_colour, page_frame, saved_selection, single_selection, title_notice)
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
TABLE_Y, TABLE_H = Y0, 600  # 18 KPIs at 12 pt with a wrapped header
DRILL_Y, DRILL_H, DRILL_W = TABLE_Y + TABLE_H + GAP, 54, 420
MATRIX_Y = DRILL_Y + DRILL_H + GAP  # 888
MATRIX_H = 600
SCORECARD_H = MATRIX_Y + MATRIX_H + 30  # 1518: the page scrolls
TABLE_FONT = 12
# The scorecard columns' widths in px (sum within the table's 1860 less the scroll bar)
SCORECARD_WIDTHS = {AREA: 170, KPI_NAME: 330, HR_STATUS_TEXT: 260, HR_ACTUAL_TEXT: 210, HR_TARGET_TEXT: 260,
                    HR_VARIANCE_TEXT: 190, HR_WATCH_TEXT: 260, DISPLAY_ORDER: 90}

WILDCARD = {"dataViewWildcard": {"matchingOption": 1}}


def status_colours() -> dict:
    """The status cells' font colour from [HR KPI Status Colour], for the [HR KPI Status Text] column (conditional
    formatting by field value, as the Press Ganey table's `fontColor`)."""
    return {"values": [{"properties": {"fontColor": measure_colour(HR_STATUS_COLOUR.name)},
                        "selector": {"data": [WILDCARD], "metadata": HR_STATUS_TEXT.ref}}]}


def _area_slicer() -> Visual:
    return Visual("slicerDropdown", *AREA_SLICER, roles={"Values": [AREA]}, filters=[ACTIVE_KPIS[0]],
                  props={**bsc.select_all_selection(), **bsc.dropdown_look()}, labels={AREA: "Area"})


# ---- Period (final review I3) ---------------------------------------------------------------------------------------

TIME_CALC = col("Time Calculation", "Time Calculation")
# The calculation items a KPI is read against its target in: the month, the quarter to date, the year to date. MTD
# equals Current for a month; PY and the YoY and MoM items compare periods and have no target to meet. Rolling 12M is
# left out: the HR targets are yearly from 2026, so a window reaching into 2025 pro-rates a flow KPI's target over
# fewer months than its actual covers.
PERIODS = ["Current", "QTD", "YTD"]
PERIOD_W = 270
SLICER_GAP = 15  # as between the Hospital and Month slicers


def period_slicer(x: float) -> Visual:
    """Period: single-select on 'Time Calculation', saved on Current, at `x` in the filter bar."""
    return Visual("slicerDropdown", x, AREA_SLICER[1], PERIOD_W, AREA_SLICER[3], roles={"Values": [TIME_CALC]},
                  filters=[Filter(TIME_CALC, "in", list(PERIODS))],
                  props={**single_selection(), **bsc.dropdown_look(), **saved_selection(TIME_CALC, "Current")},
                  labels={TIME_CALC: "Period"})


def scorecard_page() -> Page:
    area = _area_slicer()
    bar = filters() + [area, period_slicer(area.x + area.w + SLICER_GAP)]
    # every column labelled: a field without a label shows its model name ("HR KPI Status Text")
    table_fields = list(SCORECARD_WIDTHS)
    props = fixed_table(SCORECARD_WIDTHS, TABLE_FONT, left=(HR_STATUS_TEXT, HR_ACTUAL_TEXT, HR_TARGET_TEXT,
                                                            HR_VARIANCE_TEXT, HR_WATCH_TEXT))
    props["values"] = status_colours()["values"] + props["values"]
    table = Visual("table", X0, TABLE_Y, W0, TABLE_H, title="Every active KPI: select a row, then drill through",
                   roles={"Values": table_fields}, filters=list(ACTIVE_KPIS), sort=DISPLAY_ORDER, sort_dir="asc",
                   props=props,
                   labels={KPI_NAME: "KPI", HR_STATUS_TEXT: "Status", HR_ACTUAL_TEXT: "Actual", HR_TARGET_TEXT: "Target",
                           DISPLAY_ORDER: "Order", HR_VARIANCE_TEXT: "Variance", HR_WATCH_TEXT: "Watch at"})
    link = {"type": _lit("Drillthrough"), "drillthroughSection": _lit(KPI_DETAIL_NAME)}
    drill = Visual("buttonDrill", X0, DRILL_Y, DRILL_W, DRILL_H,
                   props={**button_props(link, "Drill through to KPI detail →", "primary"), **no_container()})
    matrix = Visual("matrix", X0, MATRIX_Y, W0, MATRIX_H, title="Status by branch",
                    roles={"Rows": [KPI_NAME], "Columns": [BRANCH_NAME], "Values": [HR_STATUS_TEXT]},
                    filters=list(ACTIVE_KPIS), sort=KPI_NAME, sort_dir="asc", props=status_colours())
    return Page("scorecard", "Scorecard", page_frame("scorecard", bar) + [table, drill, matrix],
                filters=[branches()], height=SCORECARD_H)


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
    branch, month = filters()
    back = bsc.back_button(SUB_TAB_X, SUB_TAB_Y, BACK_W, 54)
    period = period_slicer(SUB_TAB_X + BACK_W + GAP)
    visuals = page_frame(None, [branch, month, back, period])
    wrap = {"wordWrap": [{"properties": {"show": _lit(True)}}]}
    # the heading and the definition are measures that say how to pick a KPI when no drill-through brought one
    visuals.append(Visual("card", X0, Y0, LEFT_W, TITLE_H, roles={"Values": [meas("HR KPI Detail Title")]},
                          props={**card_look(20, NAVY, box=True), **wrap}))
    y = Y0 + TITLE_H + GAP
    for name, h in DEFINITION:
        field = meas("HR KPI Definition Text") if name == "Definition" else col("HR KPI", name)
        visuals.append(Visual("card", X0, y, LEFT_W, h, roles={"Values": [field]},
                              props={**card_look(12, NAVY, category=True, box=True), **wrap},
                              labels={field: name} if field.kind == "measure" else {}))
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
    bars = Visual("barChart", RIGHT_X, BAR_Y, RIGHT_W, BAR_H, title="By branch",
                  roles={"Category": [BRANCH_NAME], "Y": [meas("HR KPI Actual")]})
    visuals += [line, bars]
    # Without pay access a pay KPI's charts are empty: [HR KPI Pay Notice] says why (final review I2), in each chart's
    # title band (ruling R31: over the plot it took the hover and clicks). It is "" for pay readers and for a KPI that
    # needs no pay, so the card shows nothing; no filter, because a card filtered to no row prints "(Blank)"
    visuals += [title_notice(chart, "HR KPI Pay Notice") for chart in (line, bars)]
    interactions = [Interaction(month, line, "NoFilter"), Interaction(month, bars, "NoFilter"),
                    Interaction(branch, bars, "NoFilter"), Interaction(period, line, "NoFilter")]
    return Page(KPI_DETAIL_NAME, "KPI detail", visuals, filters=[branches()], interactions=interactions,
                drill_fields=[KPI_NAME], hidden=True, keep_filters=False)
