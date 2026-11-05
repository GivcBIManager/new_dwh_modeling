"""The six detail pages under the Details tab (spec "Pages" 4) and the hidden Employee list (spec "Pages" 7).

Each detail page has the frame with the Details tab current and Branch, Dates and Last closed month in the filter
bar; in the content box the six sub-tabs, the page's own slicers, then sections. A section has a heading (title, a
short subtitle), its own slicers when it has some, a row of 3 to 6 cards (each with an icon), and rows of charts. The
charts of a row share one height, the tallest chart's (user request 2026-11-05: aligned tops and bottoms); a bar
chart is as high as its bars need (chart_height), a row's widths follow the charts' spans. Every chart shows its data
labels (line charts their markers) and no value axis. Pages taller than 1080 px fit their width and scroll (R24).

Chart types (user request 2026-11-05, "best practice"): lines for months, bars for rankings and branches, columns for
ordered bands (age, tenure, grade), donuts for a split into two or three parts, a line and column combo for counts
with their rate, matrices for two-way breakdowns (shaded as a heat map), drill-down bars for a hierarchy (branch then
location; department, job, position, grade; absence category then type).

    headcount     Size: headcount, FTE, averages, Saudization, female and contingent share; trend; by branch then
                  location. Organisation: department > job > position > grade (drill-down), by grade, and the matrix
                  of department, job and position by grade. Workforce mix: Saudi, gender, worker type, full / part
                  time (donuts), age and tenure bands (columns, in band order)
    movements     Hires and leavers: trends, by branch, department, action reason, tenure band, action. Changes and
                  transfers: changes by kind and branch (heat map), transfers from branch to branch (matrix),
                  movement groups, transfers and promotions by branch
    payroll       Gross pay (what employees are paid) and payroll cost (what the employer pays), each with its cards,
                  trend, pay categories, departments and grades (ranked, grades known only); the step from gross
                  pay to cost (waterfall by pay group, monthly stack). Not by job (ruling R26)
    absence       Absence days (Absence category and type slicers): trend, category then type (drill-down), sick
                  leave. Leave balance and liability (Leave plan slicer): trends, by branch and plan. Not by
                  department (ruling R26)
    recruitment   Status and Phase slicers; vacancy rate, open requisitions, approved, filled, average time to fill,
                  fill rate; approved and filled with the fill rate (combo) by month and branch; time to fill, open
                  requisitions and vacancy rate by month and branch. No department: Requisitions has none
    productivity  Visits per FTE, revenue per payroll SAR, payroll cost per visit (doctors and nurses), revenue per
                  FTE and per doctor, staff to bed, clinical to doctor

Rules the pages keep:
- Dates and Last closed month (hr_frame.filters): with the button on, cards and breakdowns show the month just ended;
  trend charts (lines, stacks, the combo by month) show the closed months of the Dates picked, the last 12 at most
  ('Date'[Month Offset] 1 to 12), and the button does not reach them.
- The branches page filter: the eight hospitals and Head Office (user decision 2026-11-03), locked in view mode.
- Long slicer lists (Department, Job, Grade, Nationality) have the dropdown's search box.
- Guards: every measure returns "... can't be analysed by <table>" when a table its guard rejects is filtered
  (`blocked_tables`, read from the model). The build stops when a visual's own columns, the page filter or a drill
  field is such a table. A slicer, or a selection in a chart, does not reach a visual whose measures reject its table
  (NoFilter interactions, written here); a section's slicers reach only that section's visuals.
- Pay (ruling R22): a visual with a pay figure has an [HR Pay Notice] card: "Requires pay access" to readers without
  pay access, "" (an empty card) to the others; on a chart, table or matrix in its title band (R31), over a run of
  pay cards centred. The notice has no filter (a card filtered to no row prints "(Blank)"); pay cards are filtered
  to non-blank.
- Departments and positions (ruling R30): the prefix-free 'HR Department'[Department Base Name] and
  'Position'[Position Base Name]; the per-hospital Department Name is only on the Employee list.
- Recruitment: while no budgeted FTE is loaded the vacancy rate is blank; its card is [HR Vacancy Rate Text] and each
  vacancy chart has the [HR Vacancy Note] card in its title band. "Openings" read "requisitions" (user request
  2026-11-05); the model's measure is still Open Openings.
- Fusion leaver measures are labelled "in Fusion"; the headline turnover is [BSC Turnover]. Labels are this repo's.

Employee list (hidden): drill-through on 'Branch'[Branch Name] and 'HR Department'[Department Base Name] (the
detail charts' axes) with "keep all filters" off: a source visual's own filters ('HR KPI', 'Pay Category', 'Worker
Action') would make [Headcount] return its guard message. The dates and the other selections arrive through the
page's slicers, synced with the detail pages'. One table (worker number, person number, name, Oasis staff ID,
branch, department, job, grade, hire date, status, headcount), filtered to [Headcount] not blank (ruling R4):
Employee has no branch relationship or row filter, so branch security applies through the fact. The table groups by
Employee columns only; the Oasis staff ID, branch, department (the per-hospital name), job and grade are measures
([HR Employee ...]) read through the month's headcount row (grouped by six dimensions' columns the query ran for
minutes). The name is [HR Employee Name], blank without pay access; the table has no 'Employee Details' column,
because a table grouped by a column with no visible rows (the role hides Employee Details without pay access) has no
rows at all.
"""
from __future__ import annotations

import math
import re
from functools import lru_cache

from fields import MODEL_DIR
from frame import CONTENT, NAVY, _lit, no_container
from hr_frame import (BAR_BUTTON_H, BAR_BUTTON_Y, BAR_X, ICON_SIZE, MUTED, SUB_TAB_H, TREND_WINDOW, bar_look,
                      branches, bsc, card_look, column_look, combo_look, donut_look, filters, heat_colours, icon,
                      line_look, page_frame, search_box, sub_tabs, title_notice, trend_interactions)
from model import Field, Filter, Interaction, Page, Visual, col, meas

GAP = 24
X0, Y0, W0, H0 = CONTENT  # 30, 186, 1860, 870
CONTENT_END = Y0 + H0  # 1056
BODY_Y = Y0 + SUB_TAB_H + GAP  # under the sub-tabs
SLICER_H = 66  # as the filter bar's slicers
CARD_H = 128
CARD_VALUE_PT = 30
CARD_TEXT_PT = 16  # a text figure ("No budgeted FTE", "None open") in a sixth of the width, beside the icon (22pt was cut off)
CARDS_PER_ROW = (3, 6)
NOTICE_H = 60
BOTTOM_MARGIN = 30
TOP = 15  # bars on a long axis: the top 15 by the chart's first measure
TOP_PAIRED = 10  # the top 10 when each bar has two measures (a top 15 of pairs was 750 px high)
BACK_W = 110

BRANCH_NAME = col("Branch", "Branch Name")
FROM_BRANCH = col("From Branch", "Branch Name")
YEAR_MONTH = col("Date", "Year Month Name")
# prefix-free ("Icu-Nurse" for "ABH Icu-Nurse"; ruling R30): the charts' axis, the slicer and the drill field
DEPARTMENT = col("HR Department", "Department Base Name")
POSITION = col("Position", "Position Base Name")  # prefix-free ("Staff Nurse" for "RBW Staff Nurse")
JOB = col("Job", "Job Name")
GRADE = col("Grade", "Grade Name")
LOCATION = col("Location", "Location Name")
HEADCOUNT = meas("Headcount")
PAY_NOTICE = meas("HR Pay Notice")
EMPLOYEE_NAME = meas("HR Employee Name")  # one employee's Fusion name; blank without pay access
ABSENCE_TYPE = col("Absence Type", "Absence Type Name")
ABSENCE_CATEGORY = col("Absence Type", "Absence Category")
LEAVE_PLAN = col("Leave Balances", "Absence Plan Name")
LEAVE_SOURCE = col("Leave Balances", "Source")
ABSENCE_SOURCE = col("Absence Days", "Source")
EMPLOYEE_LIST = "employee_list"
# a grade ranking leaves out the employees without a grade in the month's headcount (Unknown: before 2026, Oasis
# staff with no Fusion employee)
GRADE_KNOWN = Filter(GRADE, "notin", ["Unknown"])

# The page slicers (field, label)
WORKFORCE_SLICERS = [(DEPARTMENT, "Department"), (JOB, "Job"), (GRADE, "Grade"),
                     (col("Employee", "Nationality"), "Nationality"), (col("Employee", "Worker Type"), "Worker type")]
# Slicers with a search box in their dropdown: long lists (Department has about 270 prefix-free names)
SEARCH_FIELDS = {DEPARTMENT, JOB, GRADE, col("Employee", "Nationality")}


# ---- guards -------------------------------------------------------------------------------------------------------

@lru_cache(maxsize=None)
def _measure_bodies() -> dict[str, str]:
    """{measure name: its TMDL} from ssas/HNH_Analytics/tables/_Measures.tmdl."""
    text = (MODEL_DIR / "tables" / "_Measures.tmdl").read_text(encoding="utf-8-sig")
    out = {}
    for block in re.split(r"\n\tmeasure ", text)[1:]:
        m = re.match(r"'((?:[^']|'')+)'|(\S+)", block)
        out[(m.group(1) or m.group(2)).replace("''", "'")] = block
    return out


def blocked_tables(measure: str) -> frozenset[str]:
    """The tables whose filter makes `measure` return its guard message: those its guard (`VAR __Wrong =
    [_Guard ...]`, written by ssas/tools/measure_guards.py) tests with ISFILTERED. Empty for an unguarded measure."""
    bodies = _measure_bodies()
    if measure not in bodies:
        raise ValueError(f"measure [{measure}] is not in the model")
    guard = re.search(r"VAR __Wrong = \[(_Guard [^\]]+)\]", bodies[measure])
    if not guard:
        return frozenset()
    return frozenset(re.findall(r"ISFILTERED \( '([^']+)' \)", bodies[guard.group(1)]))


def _measures(v: Visual) -> list[Field]:
    return [f for fs in v.roles.values() for f in fs if f.kind == "measure"]


def _role_columns(v: Visual) -> set[str]:
    return {f.table for fs in v.roles.values() for f in fs if f.kind == "column"}


def _rejects(v: Visual, tables: set[str]) -> bool:
    return any(blocked_tables(m.name) & tables for m in _measures(v))


def _guarded(page_name: str, data: list[Visual], page_tables: set[str]) -> list[tuple[Visual, Visual]]:
    """Checks every data visual against the tables it is analysed by (its own columns and filters, `page_tables`:
    the page filter and drill fields); returns the (source, target) pairs whose cross-filter would reach a measure
    that rejects one of the source's tables."""
    for v in data:
        own = _role_columns(v) | {f.field.table for f in v.filters if f.field.kind == "column"}
        for m in _measures(v):
            clash = blocked_tables(m.name) & (own | page_tables)
            if clash:
                raise ValueError(f"page {page_name}: [{m.name}] in {v.title or v.sample} can't be analysed by "
                                 f"{', '.join(sorted(clash))}")
    return [(s, t) for s in data for t in data if t is not s and _rejects(t, _role_columns(s))]


# ---- chart specs --------------------------------------------------------------------------------------------------

def card(measure: str, label: str, pay: bool = False, decimals: int | None = None) -> dict:
    """A card: the figure over its label, with the measure's icon (CARD_ICONS). `pay`: needs pay access.
    `decimals`: the value's decimal places, whatever the measure's format."""
    return {"kind": "card", "measures": [measure], "labels": {measure: label}, "pay": pay, "decimals": decimals}


def _spec(kind: str, title: str, measures: list[str], labels: dict | None, pay: bool, note: str | None,
          span: int, **more) -> dict:
    return {"kind": kind, "title": title, "measures": measures, "labels": labels or {}, "pay": pay, "note": note,
            "span": span, "filters": [], **more}


def trend(title: str, measures: list[str], labels: dict | None = None, pay: bool = False, note: str | None = None,
          stacked: bool = False, span: int = 1) -> dict:
    """A line chart by month (the Dates' closed months, TREND_WINDOW); `stacked`: a stacked column chart (parts of a
    total). `note`: a text measure in the title band ("" when there is nothing to say)."""
    return _spec("stackedColumnChart" if stacked else "lineChart", title, measures, labels, pay, note, span,
                 by=[YEAR_MONTH])


def combo(title: str, by: Field, columns: list[str], line: list[str], labels: dict | None = None,
          span: int = 1) -> dict:
    """Columns (`columns`, counts) and a line (`line`, their rate) over `by`: by month (YEAR_MONTH, a trend) or by
    another axis, sorted by the first column measure."""
    return _spec("comboChart", title, columns + line, labels, False, None, span, by=[by], line=list(line))


def bars(title: str, by: Field | list[Field], measures: list[str], labels: dict | None = None, top: bool = False,
         pay: bool = False, note: str | None = None, filters: list[Filter] = (), n: int | None = None,
         span: int = 1) -> dict:
    """A bar chart sorted by its first measure; `by` a list: a drill-down from the first field (its bars) to the
    next. `top`: only the top 15 of the first field. `filters`: the visual's own filters. `n`: the number of bars
    when the first field is not in AXIS_COUNTS (the chart's height fits its bars)."""
    return {**_spec("barChart", title, measures, labels, pay, note, span, by=_fields(by), top=top, n=n),
            "filters": list(filters)}


def columns(title: str, by: Field, measures: list[str], labels: dict | None = None, pay: bool = False,
            filters: list[Filter] = (), span: int = 1) -> dict:
    """A column chart over an ordered axis (age band, tenure band, grade), in the axis's order."""
    return {**_spec("columnChart", title, measures, labels, pay, None, span, by=[by]), "filters": list(filters)}


def donut(title: str, by: Field, measure: str, labels: dict | None = None, span: int = 1) -> dict:
    """A donut of a split into a few parts, each slice labelled with its share."""
    return _spec("donutChart", title, [measure], labels, False, None, span, by=[by])


def waterfall(title: str, by: Field, measure: str, labels: dict | None = None, pay: bool = False,
              filters: list[Filter] = (), span: int = 1) -> dict:
    """A waterfall: `measure` by `by` (in `by`'s order), then the total."""
    return {**_spec("waterfallChart", title, [measure], labels, pay, None, span, by=[by]), "filters": list(filters)}


def matrix(title: str, rows: list[Field], cols: list[Field], measures: list[str], labels: dict | None = None,
           h: float = 360, heat: bool = True, expand: bool = True, pay: bool = False, span: int = 1) -> dict:
    """A matrix: `rows` (a hierarchy when several; `expand` off shows the first level, the others by expand or drill
    down) by `cols`, the cells shaded white to blue by value (`heat`)."""
    return _spec("matrix", title, measures, labels, pay, None, span, rows=list(rows), cols=list(cols), h=h,
                 heat=heat, expand=expand)


def table(title: str, cols: list[tuple[Field, str]], measures: list[str], labels: dict | None = None,
          pay: bool = False, h: float | None = None, span: int = 1) -> dict:
    return _spec("table", title, measures, labels, pay, None, span, columns=cols, h=h)


def section(title: str, cards: list[dict], rows: list[list[dict]], subtitle: str | None = None,
            slicers: list[tuple[Field, str]] = ()) -> dict:
    """A part of a detail page: its heading (`title` over `subtitle`), its own slicers (they reach only this
    section's visuals), a row of 3 to 6 cards, then rows of charts."""
    return {"title": title, "subtitle": subtitle, "cards": cards, "rows": rows, "slicers": list(slicers)}


def _fields(by: Field | list[Field]) -> list[Field]:
    return list(by) if isinstance(by, (list, tuple)) else [by]


# A measure's name in charts and tables (legend, tooltip, header) unless the chart gives one: Fusion leaver measures
# say "in Fusion"; the BSC measures lose their prefix; openings read requisitions (user request 2026-11-05)
LABELS = {"Leavers": "Leavers in Fusion", "Voluntary Leavers": "Voluntary leavers in Fusion",
          "Voluntary Turnover Rate %": "Voluntary leaver rate in Fusion",
          "New Hire Turnover %": "New-hire leaver rate in Fusion", "BSC Turnover": "Turnover",
          "BSC Saudization": "Saudization", "BSC Vacancy Rate": "Vacancy rate",
          "BSC Time to Fill (days)": "Average time to fill (days)", "BSC Revenue per FTE": "Revenue per FTE (SAR)",
          "BSC Revenue per Doctor": "Revenue per doctor (SAR)", "BSC Staff to Bed": "Staff to bed",
          "BSC Clinical to Doctor": "Clinical staff to doctor", "Payroll Cost": "Payroll cost (SAR)",
          "Gross Pay": "Gross pay (SAR)", "Gross Pay (Open Payroll)": "Gross pay in open payroll (SAR)",
          "Involuntary Leavers": "Involuntary leavers in Fusion", "Branch Transfers": "Branch transfers",
          "Promotions": "Promotions (Fusion action)", "Job Changes": "Job", "Grade Changes": "Grade",
          "Position Changes": "Position", "Location Changes": "Location",
          "Requisitions Approved": "Approved", "Requisitions Filled": "Filled",
          "Requisition Fill Rate %": "Fill rate", "Open Openings": "Open requisitions", "Absence Days": "Absence days",
          "Sick Days": "Sick days", "Sick Leave Rate %": "Sick leave rate", "Headcount": "Headcount",
          "Employer Charges": "Employer charges (SAR)", "Payroll Cost per FTE": "Payroll cost per FTE (SAR)",
          "Employer Charges Share %": "Employer charges' share", "Overtime Share %": "Overtime share",
          "Leave Balance (days)": "Leave balance (days)", "Leave Liability": "Leave liability (SAR)"}

# A card's icon (hr_frame.icon), by its measure
CARD_ICONS = {
    "Headcount": "users", "FTE": "users", "Average Headcount": "users", "Average FTE": "users",
    "BSC Saudization": "flag", "Female Share %": "female", "Contingent Share %": "badge",
    "Hires": "user_plus", "Leavers": "user_minus", "Involuntary Leavers": "user_minus", "BSC Turnover": "swap",
    "Voluntary Turnover Rate %": "percent", "New Hire Turnover %": "percent", "Branch Transfers": "swap",
    "Promotions": "trend_up", "Movements": "chart",
    "Gross Pay": "banknote", "Overtime Share %": "clock", "HR Open Payroll Text": "receipt",
    "Payroll Cost": "coins", "Employer Charges": "building", "Employer Charges Share %": "percent",
    "Payroll Cost per FTE": "coins",
    "Sick Days": "pulse", "Sick Leave Rate %": "pulse", "Absence Days": "calendar", "Leave Balance (days)": "sun",
    "Leave Liability": "wallet", "Average Leave Balance (days)": "sun", "Current Leave Balance (days)": "sun",
    "Current Leave Liability": "wallet",
    "HR Vacancy Rate Text": "target", "BSC Time to Fill (days)": "hourglass", "Requisitions Approved": "briefcase",
    "Requisitions Filled": "check", "Open Openings": "briefcase", "Requisition Fill Rate %": "percent",
    "Visits per FTE": "chart", "Revenue per Payroll SAR": "trend_up", "Payroll Cost per Visit": "coins",
    "BSC Revenue per FTE": "banknote", "BSC Revenue per Doctor": "stethoscope",
}


def _labels(spec: dict) -> dict[Field, str]:
    names = {**LABELS, **spec["labels"]}
    return {meas(m): names[m] for m in spec["measures"] if m in names}


# ---- chart sizes --------------------------------------------------------------------------------------------------
# A bar chart is as high as its bars and labels need (user request 2026-11-04): the title band and padding, a legend
# when it has more than one measure, and per bar 8 px plus BAR_SERIES_PX for each measure. Other charts are LINE_H;
# tables and matrices their own height. A row of charts takes its tallest chart's height (user request 2026-11-05).
LINE_H = 300
TABLE_H = 330
SECTION_HEAD_H = 64  # a section heading: title over subtitle
TRENDS = ("lineChart", "stackedColumnChart")  # by month: the Last closed month button does not reach them
BAR_MIN_H, BAR_CHROME, BAR_LEGEND_H, BAR_SERIES_PX = 150, 64, 24, 18
# The number of bars on an axis for the report's branches and a month (HNH_Analytics_Test, 2026-11-04); a top N axis
# has TOP. An axis not listed needs the spec's `n`.
AXIS_COUNTS = {
    BRANCH_NAME: 9, col("Worker Action", "Movement Group"): 8, col("Employee", "Tenure Band"): 5,
    ABSENCE_CATEGORY: 5, col("Staff Productivity", "Staff Category"): 2, LEAVE_PLAN: 6,
}


def is_trend(spec_or_visual) -> bool:
    """A chart by month: lines, stacks and a combo on the month axis."""
    if isinstance(spec_or_visual, dict):
        return spec_or_visual["kind"] in TRENDS or (spec_or_visual["kind"] == "comboChart"
                                                   and spec_or_visual["by"] == [YEAR_MONTH])
    v = spec_or_visual
    return v.sample in TRENDS or (v.sample == "comboChart" and v.roles.get("Category") == [YEAR_MONTH])


def _top(spec: dict) -> int:
    return TOP if len(spec["measures"]) == 1 else TOP_PAIRED


def chart_height(spec: dict) -> float:
    """The height a chart spec needs (see "chart sizes")."""
    if spec["kind"] == "barChart":
        n = spec.get("n") or (_top(spec) if spec["top"] else AXIS_COUNTS.get(spec["by"][0]))
        if n is None:
            raise ValueError(f"bar chart '{spec['title']}': give n, the number of bars on {spec['by'][0]}")
        k = len(spec["measures"])
        return max(BAR_MIN_H, BAR_CHROME + (BAR_LEGEND_H if k > 1 else 0) + n * (8 + BAR_SERIES_PX * k))
    if spec["kind"] in ("table", "matrix"):
        return spec.get("h") or TABLE_H
    return LINE_H


# SAR amounts in millions: their chart labels read "31.3M" and "0.4M" (Desktop's auto units gave small bars "0M")
MONEY = {"Gross Pay", "Payroll Cost", "Employer Charges", "Gross Pay (Open Payroll)", "Leave Liability",
         "Current Leave Liability"}


def _units(spec: dict) -> str:
    return "millions" if set(spec["measures"]) <= MONEY else "none"


def _visual(spec: dict, x: float, y: float, w: float, h: float) -> Visual:
    ms = [meas(m) for m in spec["measures"]]
    kind = spec["kind"]
    if kind == "card":
        return Visual("card", x, y, w, h, roles={"Values": ms}, labels=_labels(spec),
                      filters=[Filter(ms[0], "notblank")] if spec["pay"] else [],
                      props=card_look(CARD_TEXT_PT if ms[0].name.endswith(" Text") else CARD_VALUE_PT, NAVY,
                                      category=True, box=True, decimals=spec.get("decimals")))
    common = {"title": spec["title"], "labels": _labels(spec), "filters": list(spec["filters"])}
    if kind in TRENDS:
        look = line_look(_units(spec)) if kind == "lineChart" else column_look(_units(spec))
        return Visual(kind, x, y, w, h, roles={"Category": [YEAR_MONTH], "Y": ms}, sort=YEAR_MONTH, sort_dir="asc",
                      props=look, **{**common, "filters": common["filters"] + [TREND_WINDOW]})
    if kind == "comboChart":
        line = [meas(m) for m in spec["line"]]
        cols = [m for m in ms if m not in line]
        by = spec["by"][0]
        month = by == YEAR_MONTH
        return Visual("comboChart", x, y, w, h, roles={"Category": [by], "Y": cols, "Y2": line},
                      sort=by if month else cols[0], sort_dir="asc" if month else "desc", props=combo_look(),
                      **{**common, "filters": common["filters"] + ([TREND_WINDOW] if month else [])})
    if kind == "barChart":
        return Visual("barChart", x, y, w, h, roles={"Category": spec["by"], "Y": ms}, sort=ms[0],
                      top_n=(ms[0], _top(spec)) if spec["top"] else None, props=bar_look(_units(spec)), **common)
    if kind == "columnChart":
        by = spec["by"][0]
        return Visual("columnChart", x, y, w, h, roles={"Category": [by], "Y": ms}, sort=by, sort_dir="asc",
                      props=column_look("none" if _units(spec) == "none" else "millions"), **common)
    if kind == "donutChart":
        return Visual("donutChart", x, y, w, h, roles={"Category": spec["by"], "Y": ms}, sort=ms[0],
                      props=donut_look(), **common)
    if kind == "waterfallChart":
        by = spec["by"][0]
        return Visual("waterfallChart", x, y, w, h, roles={"Category": [by], "Y": ms}, sort=by, sort_dir="asc",
                      props=column_look(_units(spec)), **common)
    if kind == "matrix":
        labels = {**common["labels"], **{f: lbl for f, lbl in spec["labels"].items() if isinstance(f, Field)}}
        roles = {"Rows": spec["rows"], **({"Columns": spec["cols"]} if spec["cols"] else {}), "Values": ms}
        return Visual("matrix", x, y, w, h, roles=roles,
                      sort=spec["rows"][0], sort_dir="asc", expand=spec["expand"],
                      props=heat_colours(ms) if spec["heat"] else {},
                      **{**common, "labels": labels})
    cols = [c for c, _label in spec["columns"]]
    return Visual("table", x, y, w, h, roles={"Values": cols + ms}, sort=cols[0], sort_dir="asc",
                  **{**common, "labels": {**{c: label for c, label in spec["columns"]}, **common["labels"]}})


def _notice(x: float, y: float, w: float, h: float, measure: Field = PAY_NOTICE) -> Visual:
    """A note centred over a run of cards: [HR Pay Notice] ("Requires pay access") over pay cards. The measure returns
    "" when there is nothing to say, so the card shows nothing; it has no filter, because a card filtered to no row
    prints "(Blank)". A chart's or table's notice sits in its title band instead (hr_frame.title_notice, R31)."""
    return Visual("card", x, y + (h - NOTICE_H) / 2, w, NOTICE_H, roles={"Values": [measure]},
                  props=card_look(16, NAVY))


def slicer(field: Field, label: str, x: float, y: float, w: float) -> Visual:
    """A multi-select dropdown with Select all, as the filter bar's Branch; synced across pages by its field. A long
    list (SEARCH_FIELDS) has the dropdown's search box."""
    search = search_box() if field in SEARCH_FIELDS else {}
    return Visual("slicerDropdown", x, y, w, SLICER_H, roles={"Values": [field]},
                  props={**bsc.select_all_selection(), **bsc.dropdown_look(), **search}, labels={field: label})


def _row(n: int) -> float:
    return (W0 - GAP * (n - 1)) / n


SLICER_W = 360


def _slicer_row(fields: list[tuple[Field, str]], y: float, w: float | None = None) -> list[Visual]:
    w = w or _row(len(fields))
    return [slicer(f, label, X0 + i * (w + GAP), y, w) for i, (f, label) in enumerate(fields)]


def _place_rows(rows: list[list[dict]], y0: float) -> tuple[list[tuple], float]:
    """Each row of charts across the content width, the widths by the charts' spans, all at the row's tallest
    chart_height: (spec, x, y, w, h) per chart, and the y under the last row."""
    placed, y = [], y0
    for row in rows:
        if not row:
            continue
        spans = [s["span"] for s in row]
        free = W0 - GAP * (len(row) - 1)
        h = max(chart_height(s) for s in row)
        x = X0
        for spec, span in zip(row, spans):
            w = free * span / sum(spans)
            placed.append((spec, x, y, w, h))
            x += w + GAP
        y += h + GAP
    return placed, y


def _heading(title: str, subtitle: str | None, y: float) -> Visual:
    """A section heading: `title` (Segoe UI Semibold 16pt, navy) over `subtitle` (11pt, grey), a short line."""
    runs = [(title, {"fontFamily": "Segoe UI Semibold", "fontSize": "16pt", "color": NAVY})]
    if subtitle:
        runs.append((subtitle, {"fontFamily": "Segoe UI", "fontSize": "11pt", "color": MUTED}))
    paragraphs = [{"textRuns": [{"value": v, "textStyle": st}]} for v, st in runs]
    return Visual("textbox", X0, y, W0, SECTION_HEAD_H,
                  props={"general": [{"properties": {"paragraphs": paragraphs}}], **no_container()})


def _cards(name: str, specs: list[dict], y: float) -> tuple[list[Visual], list[Visual], float]:
    """A row of 3 to 6 cards from y (two rows when more): (the cards, their icons and pay notices, the y below
    them). A run of pay cards next to each other gets one notice over it."""
    lo, hi = CARDS_PER_ROW
    per_row = len(specs) if len(specs) <= hi else math.ceil(len(specs) / 2)
    if not lo <= per_row <= hi or len(specs) > 2 * hi:
        raise ValueError(f"page {name}: one or two rows of {lo} to {hi} cards")
    w = _row(per_row)
    cards, decor, runs = [], [], []
    for i, spec in enumerate(specs):
        v = _visual(spec, X0 + (i % per_row) * (w + GAP), y + (i // per_row) * (CARD_H + GAP), w, CARD_H)
        m = spec["measures"][0]
        if m in CARD_ICONS:  # left of the figure, centred in the card's height
            decor.append(icon(CARD_ICONS[m], v.x + 18, v.y + (CARD_H - ICON_SIZE) / 2))
        if spec["pay"]:
            prev = cards[-1] if cards else None
            if runs and runs[-1][-1] is prev and prev.y == v.y:
                runs[-1].append(v)
            elif runs and runs[-1][-1].y == v.y:
                raise ValueError(f"page {name}: the pay cards must be next to each other")
            else:
                runs.append([v])
        cards.append(v)
    decor += [_notice(r[0].x, r[0].y, r[-1].x + r[-1].w - r[0].x, CARD_H) for r in runs]
    return cards, decor, y + math.ceil(len(specs) / per_row) * (CARD_H + GAP)


def detail_page(name: str, display: str, sections: list[dict], page_slicers: list[tuple[Field, str]] = ()) -> Page:
    """A detail page: the frame (Details tab current; Branch, Dates and Last closed month in the filter bar), the
    sub-tabs, the page's slicers, then its sections (heading, slicers, cards, rows of charts; see `section`). Pay
    visuals get an HR Pay Notice: in each pay chart's title band, over each run of pay cards."""
    bar = filters()
    visuals = page_frame("headcount", bar) + sub_tabs(name, X0, Y0)
    y = BODY_Y
    page_slicer_visuals = _slicer_row(list(page_slicers), y) if page_slicers else []
    visuals += page_slicer_visuals
    if page_slicer_visuals:
        y += SLICER_H + GAP
    data: list[Visual] = []
    decor: list[Visual] = []  # headings, icons and notices: drawn over the data visuals
    scoped: list[tuple[Visual, list[Visual]]] = []  # (section slicer, its section's data visuals)
    for i, sec in enumerate(sections):
        if i:
            y += GAP  # more room between sections
        decor.append(_heading(sec["title"], sec["subtitle"], y))
        y += SECTION_HEAD_H + GAP / 2
        own = _slicer_row(sec["slicers"], y, SLICER_W) if sec["slicers"] else []
        visuals += own
        if own:
            y += SLICER_H + GAP
        first = len(data)
        if sec["cards"]:
            cards_, more, y = _cards(name, sec["cards"], y)
            data += cards_
            decor += more
        placed, y = _place_rows(sec["rows"], y)
        for spec, x, cy, cw, ch in placed:
            v = _visual(spec, x, cy, cw, ch)
            data.append(v)
            if spec["pay"]:  # in the chart's title band (ruling R31)
                decor.append(title_notice(v, PAY_NOTICE.name))
            if spec.get("note"):
                decor.append(title_notice(v, spec["note"]))
        scoped += [(s, data[first:]) for s in own]
    visuals += data + decor
    height = max(1080, math.ceil(y - GAP + BOTTOM_MARGIN))
    page_filters = [branches()]
    trends = [v for v in data if is_trend(v)]
    interactions = trend_interactions(bar, trends)
    interactions += _slicer_interactions(bar[:1] + page_slicer_visuals, scoped, data)
    interactions += [Interaction(s, t, "NoFilter")
                     for s, t in _guarded(name, data, {f.field.table for f in page_filters})]
    return Page(name, display, visuals, filters=page_filters, interactions=interactions, height=height)


def _slicer_interactions(page_wide: list[Visual], scoped: list[tuple[Visual, list[Visual]]],
                         data: list[Visual]) -> list[Interaction]:
    """A slicer does not reach a visual whose measures reject its table (the visual would show the guard message);
    a section's slicer reaches only its section's visuals."""
    out = []
    for s in page_wide:
        tables = {f.table for f in s.roles["Values"]}
        out += [Interaction(s, v, "NoFilter") for v in data if _rejects(v, tables)]
    for s, mine in scoped:
        tables = {f.table for f in s.roles["Values"]}
        out += [Interaction(s, v, "NoFilter") for v in data
                if not any(v is m for m in mine) or _rejects(v, tables)]
    return out


# ---- the pages ----------------------------------------------------------------------------------------------------

def headcount_page() -> Page:
    hc = ["Headcount"]
    size = section(
        "Size", [card("Headcount", "Headcount"),
                 # FTE equals headcount today (Fusion FTE values are 1; a zero FTE is replaced by 1): no decimals
                 card("FTE", "FTE", decimals=0), card("Average Headcount", "Average headcount", decimals=0),
                 card("BSC Saudization", "Saudization"), card("Female Share %", "Female share"),
                 card("Contingent Share %", "Contingent workers")],
        # FTE equals headcount today: one line, or every label shows twice
        [[trend("Headcount by month", hc, span=2),
          bars("Headcount by branch, then location", [BRANCH_NAME, LOCATION], hc)]],
        subtitle="Month-end headcount; contingent workers are counted apart.")
    organisation = section(
        "Organisation", [],
        [[bars("Headcount by department, then job, position and grade", [DEPARTMENT, JOB, POSITION, GRADE], hc,
               top=True),
          columns("Headcount by grade", GRADE, hc)],
         [matrix("Headcount by department, job and position (rows) and grade (columns)", [DEPARTMENT, JOB, POSITION],
                 [GRADE], hc, h=480, expand=False,
                 labels={DEPARTMENT: "Department", JOB: "Job", POSITION: "Position", GRADE: "Grade"})]],
        subtitle="Use the arrows on a chart or matrix to drill down a level.")
    mix = section(
        "Workforce mix", [],
        [[donut("Saudi nationals", col("Headcount", "Is Saudi"), "Headcount"),
          donut("Gender", col("Headcount", "Gender"), "Headcount"),
          donut("Worker type", col("Employee", "Worker Type"), "Headcount"),
          donut("Full and part time", col("Job", "Full Part Time"), "Headcount")],
         [columns("Headcount by age band (years)", col("Headcount", "Age Band"), hc),
          columns("Headcount by tenure band (years)", col("Headcount", "Tenure Band"), hc)]])
    return detail_page("headcount", "Headcount & mix", [size, organisation, mix], page_slicers=WORKFORCE_SLICERS)


CHANGES = ["Job Changes", "Grade Changes", "Position Changes", "Location Changes"]


def movements_page() -> Page:
    leavers = ["Leavers", "Voluntary Leavers"]
    flow = section(
        "Hires and leavers",
        [card("Hires", "Hires"), card("Leavers", "Leavers in Fusion"),
         card("Involuntary Leavers", "Involuntary leavers in Fusion"), card("BSC Turnover", "Turnover"),
         card("Voluntary Turnover Rate %", "Voluntary leaver rate in Fusion"),
         card("New Hire Turnover %", "New-hire leaver rate in Fusion")],
        [[trend("Hires and leavers by month", ["Hires"] + leavers + ["Involuntary Leavers"]),
          trend("Turnover and voluntary leaver rate by month", ["BSC Turnover", "Voluntary Turnover Rate %"])],
         [bars("Hires and leavers by branch", BRANCH_NAME, ["Hires", "Leavers"]),
          bars("Hires and leavers by department, top 10", DEPARTMENT, ["Hires", "Leavers"], top=True)],
         [bars("Leavers by action reason, top 10", col("Worker Action", "Action Reason Name"), leavers, top=True),
          bars("Leavers by current tenure band (years)", col("Employee", "Tenure Band"), leavers),
          bars("Hires by action, top 15", col("Worker Action", "Action Name"), ["Hires"], top=True)]],
        subtitle="Turnover is the scorecard's; leaver figures marked in Fusion count Fusion leavers only.")
    changes = section(
        "Changes and transfers",
        [card("Branch Transfers", "Branch transfers"), card("Promotions", "Promotions (Fusion action)"),
         card("Movements", "All movements")],
        [[matrix("Changes by branch and kind", [BRANCH_NAME], [], CHANGES, h=360,
                 labels={BRANCH_NAME: "Branch"}),
          matrix("Branch transfers: from (rows) and to (columns)", [FROM_BRANCH], [BRANCH_NAME],
                 ["Branch Transfers"], h=360, labels={FROM_BRANCH: "From", BRANCH_NAME: "To"})],
         [bars("Movements by movement group", col("Worker Action", "Movement Group"), ["Movements"]),
          bars("Branch transfers and promotions by branch", BRANCH_NAME, ["Branch Transfers", "Promotions"])]],
        subtitle="A darker cell is a larger number.")
    return detail_page("movements", "Movements & turnover", [flow, changes], page_slicers=WORKFORCE_SLICERS)


PAY_CATEGORY = col("Pay Category", "Pay Category")
PAY_GROUP = col("Pay Category", "Pay Group")
GROSS_PAY_CATEGORIES = Filter(col("Pay Category", "Is Gross Pay"), "eq", ["Yes"])
COST_CATEGORIES = Filter(col("Pay Category", "Is Cost"), "eq", ["Yes"])


def payroll_page() -> Page:
    """Payroll & overtime, in two sections (user request 2026-11-04): gross pay, what employees are paid (earnings and
    earnings adjustments), and payroll cost, what the employer pays (gross pay plus the employer charges: GOSI employer
    charge and other employer charges), each with its breakdowns; by grade ranked high to low, grades known only (user
    request 2026-11-05; Payroll's grade is the month's headcount grade). The cost section shows the step from one to
    the other: a waterfall by pay group and the monthly split of payroll cost into gross pay and employer charges.
    Not by job (ruling R26): Payroll has no job."""
    gross = section(
        "Gross pay: what employees are paid",
        [card("Gross Pay", "Gross pay (SAR)", pay=True),
         card("Overtime Share %", "Overtime share of gross pay", pay=True),
         card("HR Open Payroll Text", "Gross pay in open payroll", pay=True)],
        [[trend("Gross pay by month", ["Gross Pay"], pay=True),
          bars("Gross pay by pay category", PAY_CATEGORY, ["Gross Pay"], pay=True, filters=[GROSS_PAY_CATEGORIES],
               n=11)],
         [trend("Overtime share by month", ["Overtime Share %"], pay=True),
          bars("Overtime share by branch", BRANCH_NAME, ["Overtime Share %"], pay=True)],
         [bars("Gross pay by grade, top 15", GRADE, ["Gross Pay"], top=True, pay=True, filters=[GRADE_KNOWN]),
          bars("Gross pay by department, top 15", DEPARTMENT, ["Gross Pay"], top=True, pay=True)],
         [table("Payroll source and status by branch (an open month is not final)",
                [(BRANCH_NAME, "Branch"), (col("Payroll", "Source"), "Source"),
                 (col("Payroll", "Payroll Status"), "Payroll status")],
                ["Gross Pay", "Gross Pay (Open Payroll)"], pay=True)]],
        subtitle="Earnings and their adjustments, before employee deductions.")
    cost = section(
        "Payroll cost: what the employer pays",
        [card("Payroll Cost", "Payroll cost (SAR)", pay=True),
         card("Employer Charges", "Employer charges (SAR)", pay=True),
         card("Employer Charges Share %", "Employer charges' share", pay=True),
         card("Payroll Cost per FTE", "Payroll cost per FTE (SAR)", pay=True)],
        [[waterfall("From gross pay to payroll cost, by pay group", PAY_GROUP, "Payroll Cost", pay=True,
                    filters=[COST_CATEGORIES]),
          trend("Payroll cost by month: gross pay and employer charges", ["Gross Pay", "Employer Charges"], pay=True,
                stacked=True)],
         [bars("Payroll cost by pay category", PAY_CATEGORY, ["Payroll Cost"], pay=True, filters=[COST_CATEGORIES],
               n=13),
          bars("Payroll cost by department, top 15", DEPARTMENT, ["Payroll Cost"], top=True, pay=True)],
         [bars("Payroll cost by grade, top 15", GRADE, ["Payroll Cost"], top=True, pay=True, filters=[GRADE_KNOWN]),
          bars("Payroll cost per FTE by branch", BRANCH_NAME, ["Payroll Cost per FTE"], pay=True),
          bars("Employer charges by branch", BRANCH_NAME, ["Employer Charges"], pay=True)]],
        subtitle="Gross pay plus employer charges (GOSI and others).")
    return detail_page("payroll", "Payroll & overtime", [gross, cost],
                       page_slicers=[(DEPARTMENT, "Department"), (GRADE, "Grade")])


def absence_page() -> Page:
    """Absence & leave in two sections (user request 2026-11-05): absence days, with Absence category, Absence type
    and Source slicers (Fusion absences and Oasis absences, the branches' system before they moved to Fusion during
    2026), and leave balance and liability, with Leave plan and Source slicers; each section's slicers reach its own
    visuals only. Leave balances are Fusion's absence plans and, for an employee and month without a Fusion annual-leave
    balance, the Oasis annual-leave balance (earned in the current contract minus taken; plan Oasis Annual Leave,
    source Oasis; user request 2026-11-05). Not by department
    (ruling R26): the absence and leave facts have no HR department."""
    days = section(
        "Absence days",
        [card("Absence Days", "Absence days, all kinds"), card("Sick Days", "Sick days"),
         card("Sick Leave Rate %", "Sick leave rate")],
        [[trend("Absence days by month", ["Absence Days"]),
          bars("Absence days by category, then type", [ABSENCE_CATEGORY, ABSENCE_TYPE], ["Absence Days"])],
         [trend("Sick leave rate by month", ["Sick Leave Rate %"]),
          bars("Sick leave rate by branch", BRANCH_NAME, ["Sick Leave Rate %"])],
         [bars("Absence days by branch", BRANCH_NAME, ["Absence Days"]),
          bars("Sick days by absence type, top 15", ABSENCE_TYPE, ["Sick Days"], top=True)]],
        subtitle="Fusion absences, and Oasis absences from before each branch moved to Fusion.",
        slicers=[(ABSENCE_CATEGORY, "Absence category"), (ABSENCE_TYPE, "Absence type"), (ABSENCE_SOURCE, "Source")])
    leave = section(
        "Leave balance and liability",
        [card("Leave Balance (days)", "Leave balance at month end (days)", pay=True),
         card("Leave Liability", "Leave liability at month end (SAR)", pay=True),
         card("Average Leave Balance (days)", "Average leave balance (days)", pay=True),
         card("Current Leave Balance (days)", "Leave balance now (days)", pay=True),
         card("Current Leave Liability", "Leave liability now (SAR)", pay=True)],
        [[trend("Leave liability by month", ["Leave Liability"], pay=True),
          trend("Leave balance by month (days)", ["Leave Balance (days)"], pay=True)],
         [bars("Leave liability by branch", BRANCH_NAME, ["Leave Liability"], pay=True),
          bars("Leave balance by branch (days)", BRANCH_NAME, ["Leave Balance (days)"], pay=True)],
         [bars("Leave balance by leave plan (days)", LEAVE_PLAN, ["Leave Balance (days)"], pay=True),
          bars("Leave liability by leave plan", LEAVE_PLAN, ["Leave Liability"], pay=True)]],
        subtitle="Fusion absence plans; Oasis annual leave where Fusion has no balance.",
        slicers=[(LEAVE_PLAN, "Leave plan"), (LEAVE_SOURCE, "Source")])
    return detail_page("absence", "Absence & leave", [days, leave])


REQUISITION_STATE = col("Requisitions", "Requisition State")
REQUISITION_PHASE = col("Requisitions", "Requisition Phase")


def recruitment_page() -> Page:
    """Recruitment, by branch only: Requisitions has no department (spec "Pages" 4). Status (the Fusion state:
    Posted, Filled, In Progress, ...) and Phase slicers (user request 2026-11-05). No budgeted FTE is loaded yet: the
    vacancy card and charts say so ([HR Vacancy Rate Text], [HR Vacancy Note])."""
    counts = ["Requisitions Approved", "Requisitions Filled"]
    rate = ["Requisition Fill Rate %"]
    hiring = section(
        "Requisitions",
        [card("HR Vacancy Rate Text", "Vacancy rate"), card("Open Openings", "Open requisitions"),
         card("Requisitions Approved", "Requisitions approved"), card("Requisitions Filled", "Requisitions filled"),
         card("BSC Time to Fill (days)", "Average time to fill (days)"),
         card("Requisition Fill Rate %", "Fill rate")],
        [[combo("Approved and filled, with the fill rate, by month", YEAR_MONTH, counts, rate),
          combo("Approved and filled, with the fill rate, by branch", BRANCH_NAME, counts, rate)],
         [trend("Average time to fill by month (days)", ["BSC Time to Fill (days)"]),
          bars("Average time to fill by branch (days)", BRANCH_NAME, ["BSC Time to Fill (days)"])],
         [trend("Open requisitions at month end", ["Open Openings"]),
          bars("Open requisitions by branch", BRANCH_NAME, ["Open Openings"])],
         [trend("Vacancy rate by month", ["BSC Vacancy Rate"], note="HR Vacancy Note"),
          bars("Vacancy rate by branch", BRANCH_NAME, ["BSC Vacancy Rate"], note="HR Vacancy Note")]],
        subtitle="Approved Oracle Recruiting requisitions. Fill rate: the approved that are filled.")
    return detail_page("recruitment", "Recruitment", [hiring],
                       page_slicers=[(REQUISITION_STATE, "Status"), (REQUISITION_PHASE, "Phase")])


STAFF_CATEGORY = col("Staff Productivity", "Staff Category")


def productivity_page() -> Page:
    clinical = section(
        "Doctors and nurses",
        [card("Visits per FTE", "Visits per FTE", pay=True),
         card("Revenue per Payroll SAR", "Revenue per payroll SAR", pay=True),
         card("Payroll Cost per Visit", "Payroll cost per visit (SAR)", pay=True),
         card("BSC Revenue per FTE", "Revenue per FTE (SAR)"),
         card("BSC Revenue per Doctor", "Revenue per doctor (SAR)")],
        [[bars("Visits per FTE", STAFF_CATEGORY, ["Visits per FTE"], pay=True),
          bars("Revenue per payroll SAR", STAFF_CATEGORY, ["Revenue per Payroll SAR"], pay=True),
          bars("Payroll cost per visit (SAR)", STAFF_CATEGORY, ["Payroll Cost per Visit"], pay=True)],
         [trend("Visits per FTE by month", ["Visits per FTE"], pay=True),
          bars("Staff to bed and clinical staff to doctor by branch", BRANCH_NAME,
               ["BSC Staff to Bed", "BSC Clinical to Doctor"])],
         [bars("Revenue per FTE by branch", BRANCH_NAME, ["BSC Revenue per FTE"]),
          bars("Revenue per doctor by branch", BRANCH_NAME, ["BSC Revenue per Doctor"])]],
        subtitle="Visits and revenue of doctors and nurses linked to Oasis.")
    return detail_page("productivity", "Productivity", [clinical])


def detail_pages() -> list[Page]:
    """The six detail pages, in DETAIL_PAGES order."""
    return [headcount_page(), movements_page(), payroll_page(), absence_page(), recruitment_page(),
            productivity_page()]


# ---- Employee list ------------------------------------------------------------------------------------------------

def employee_list_page() -> Page:
    """Hidden drill-through on branch and the prefix-free department (keep all filters off; see the module
    docstring)."""
    bar = filters()
    back = bsc.back_button(BAR_X, BAR_BUTTON_Y, BACK_W, BAR_BUTTON_H)
    visuals = page_frame(None, bar + [back])
    own_slicers = _slicer_row(WORKFORCE_SLICERS, Y0)
    y = Y0 + SLICER_H + GAP
    worker = col("Employee", "Worker Number")
    # [HR Employee Name] is blank for every row without pay access, and a table keeps only the rows where one of its
    # measures is not blank: [Headcount] (1 a person) is a column too, so the rows stay. Grouped by Employee columns
    # only; the other attributes are measures through the month's headcount row (fast; see the module docstring)
    # Person Number is one per person (4,314 people, 4,276 worker numbers in October 2026): without it the people
    # with no worker number and the same hire date fold into one row
    fields = [(worker, "Worker number"), (col("Employee", "Person Number"), "Person number"),
              (EMPLOYEE_NAME, "Name (pay access)"),
              (meas("HR Employee Staff ID"), "Oasis staff ID"), (meas("HR Employee Hospital"), "Branch"),
              (meas("HR Employee Department"), "Department"), (meas("HR Employee Job"), "Job"),
              (meas("HR Employee Grade"), "Grade"), (col("Employee", "Hire Date"), "Hire date"),
              (col("Employee", "Assignment Status"), "Status"), (HEADCOUNT, "Headcount")]
    people = Visual("table", X0, y, W0, CONTENT_END - y, roles={"Values": [f for f, _ in fields]},
                    title="People in the headcount", labels=dict(fields),
                    filters=[Filter(HEADCOUNT, "notblank")], sort=worker, sort_dir="asc",
                    props={"total": [{"properties": {"totals": _lit(False)}}]})  # a list of people has no total
    visuals += own_slicers + [people]
    page_filters = [branches()]
    drill = [BRANCH_NAME, DEPARTMENT]
    interactions = trend_interactions(bar, [])
    interactions += _slicer_interactions(bar[:1] + own_slicers, [], [people])
    interactions += [Interaction(s, t, "NoFilter") for s, t in
                     _guarded(EMPLOYEE_LIST, [people], {f.field.table for f in page_filters} | {f.table for f in drill})]
    return Page(EMPLOYEE_LIST, "Employee list", visuals, filters=page_filters, drill_fields=drill, hidden=True,
                keep_filters=False, interactions=interactions)
