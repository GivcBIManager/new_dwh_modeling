"""The six detail pages under the Details tab (spec "Pages" 4) and the hidden Employee list (spec "Pages" 7).

Each detail page has the frame with the Details tab current, Hospital, Month and the six sub-tabs in the filter bar,
then in the content box: the page's own slicers when every visual on it accepts them, one or two rows of 4 or 5
cards for the selected month, a 2 x 2 grid of charts, and below it rows of three charts for the rest of the spec's
breakdowns. Pages taller than 1080 px fit their width and scroll (pbir.page_json, ruling R24).

    headcount     Headcount, FTE, average headcount and FTE, Saudization, female and contingent share; trend, by
                  hospital, department, job, grade, position, location, Saudi, gender, worker type, age band, tenure
                  band, full / part time
    movements     Hires, leavers, involuntary leavers, turnover (BSC Turnover), voluntary and new-hire leaver rates,
                  branch transfers, promotions; trends, movements by movement group, changes by kind (job, grade,
                  position, location), leavers by action reason and current tenure band, hires by action, by hospital
                  and department
    payroll       Payroll cost, gross pay, overtime share, cost per FTE, gross pay in open payroll; trend, gross pay
                  by pay category, cost by department, source and payroll status by hospital, overtime. Not by job
                  (ruling R26): Payroll has no job.
    absence       Sick days and rate, absence days of all kinds, leave balance and liability (month end, average,
                  now); trends, absence days by category and type, sick days by type, by hospital. Not by department
                  (ruling R26): the absence and leave facts have no HR department.
    recruitment   Vacancy rate, time to fill, requisitions approved and filled, open openings; trends and by hospital
                  (no department: Requisitions has none)
    productivity  Visits per FTE, revenue per payroll SAR, payroll cost per visit (doctors and nurses), revenue per
                  FTE and per doctor, staff to bed, clinical to doctor

Rules the pages keep:
- Cards and bar charts follow the selected month. Line charts are 12-month trends: 'Date'[Month Offset] 1 to 12 (the
  last 12 closed months) and a NoFilter interaction from the Month slicer, as on Story.
- Hospitals only (a page filter on 'Branch'[Is Hospital]), as Home's area cards, so the figures agree with Home.
- Guards: every measure returns "... can't be analysed by <table>" when a table its guard rejects is filtered
  (`blocked_tables`, read from the model). The build stops when a visual's own columns, a page slicer, the page
  filter or a drill field is such a table; a selection in a chart or table is kept from reaching a visual whose
  measures reject one of its tables (NoFilter interactions, written here).
- Pay (ruling R22): a visual with a pay figure has an [HR Pay Notice] card over it, filtered to non-blank, so it shows
  only to readers without pay access; pay cards are filtered to non-blank too, so they show nothing rather than
  "(Blank)" under the notice.
- Fusion leaver measures are labelled "in Fusion"; the headline turnover is [BSC Turnover]. Labels are this repo's
  (not title-cased).

Employee list (hidden): drill-through on 'Branch'[Branch Name] and 'HR Department'[Department Name] with "keep all
filters" off, as the BSC's family pages: a source visual's own filters ('HR KPI', 'Pay Category', 'Worker Action')
would make [Headcount] return its guard message. The month and the other selections arrive through the page's
slicers, synced with the detail pages'. One table (worker number, name, Oasis staff ID, hospital, department, job,
grade, hire date, status, headcount), filtered to [Headcount] not blank (ruling R4): Employee has no branch
relationship or row filter, so branch security applies through the fact. The name is the measure [HR Employee Name],
blank without pay access; the table has no 'Employee Details' column, because a table grouped by a column with no
visible rows (the role hides Employee Details without pay access) has no rows at all.
"""
from __future__ import annotations

import math
import re
from functools import lru_cache

from fields import MODEL_DIR
from frame import CONTENT, NAVY
from hr_frame import SUB_TAB_X, SUB_TAB_Y, bsc, card_look, filters, hospitals, page_frame, sub_tabs
from model import Field, Filter, Interaction, Page, Visual, col, meas

GAP = 24
X0, Y0, W0, H0 = CONTENT  # 30, 186, 1860, 870
CONTENT_END = Y0 + H0  # 1056
SLICER_H = 66  # as the filter bar's slicers
CARD_H = 110
NOTICE_H = 60
EXTRA_H = 300  # the charts below the grid, three to a row
CHART_MIN_H = 300  # the grid's charts: the rest of the screen, but no lower than this
BOTTOM_MARGIN = 30
TOP = 15  # bars on a long axis: the top 15 by the chart's first measure
BACK_W = 110

BRANCH_NAME = col("Branch", "Branch Name")
YEAR_MONTH = col("Date", "Year Month Name")
MONTH_OFFSET = col("Date", "Month Offset")
LAST_12_CLOSED = Filter(MONTH_OFFSET, "in", list(range(1, 13)))
DEPARTMENT = col("HR Department", "Department Name")  # per hospital ("ABH Icu-Nurse"): the drill field
UNIFIED_DEPARTMENT = col("HR Department", "Unified Department")  # across hospitals ("ICU"): the slicer
HEADCOUNT = meas("Headcount")
PAY_NOTICE = meas("HR Pay Notice")
EMPLOYEE_NAME = meas("HR Employee Name")  # one employee's Fusion name; blank without pay access
ABSENCE_TYPE = col("Absence Type", "Absence Type Name")
EMPLOYEE_LIST = "employee_list"

# The page slicers (field, label): only on pages where every measure accepts their tables
WORKFORCE_SLICERS = [(UNIFIED_DEPARTMENT, "Department"), (col("Job", "Job Name"), "Job"),
                     (col("Grade", "Grade Name"), "Grade"), (col("Employee", "Nationality"), "Nationality"),
                     (col("Employee", "Worker Type"), "Worker type")]


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


def _guarded(page_name: str, data: list[Visual], page_tables: set[str]) -> list[tuple[Visual, Visual]]:
    """Checks every data visual against the tables it is analysed by (its own columns and filters, `page_tables`:
    the page's slicers, page filter and drill fields); returns the (source, target) pairs whose cross-filter would
    reach a measure that rejects one of the source's tables."""
    for v in data:
        own = _role_columns(v) | {f.field.table for f in v.filters if f.field.kind == "column"}
        for m in _measures(v):
            clash = blocked_tables(m.name) & (own | page_tables)
            if clash:
                raise ValueError(f"page {page_name}: [{m.name}] in {v.title or v.sample} can't be analysed by "
                                 f"{', '.join(sorted(clash))}")
    return [(s, t) for s in data for t in data
            if t is not s and any(blocked_tables(m.name) & _role_columns(s) for m in _measures(t))]


# ---- building blocks ----------------------------------------------------------------------------------------------

def card(measure: str, label: str, pay: bool = False) -> dict:
    """A card for the selected month: the figure over its label. `pay`: needs pay access."""
    return {"kind": "card", "measures": [measure], "labels": {measure: label}, "pay": pay}


def trend(title: str, measures: list[str], labels: dict | None = None, pay: bool = False) -> dict:
    """A line chart of the last 12 closed months."""
    return {"kind": "lineChart", "title": f"{title}, last 12 closed months", "measures": measures,
            "labels": labels or {}, "pay": pay}


def bars(title: str, by: Field, measures: list[str], labels: dict | None = None, top: bool = False,
         pay: bool = False) -> dict:
    """A bar chart for the selected month, sorted by its first measure; `top`: only the top 15."""
    return {"kind": "barChart", "title": title, "by": by, "measures": measures, "labels": labels or {}, "top": top,
            "pay": pay}


def table(title: str, columns: list[tuple[Field, str]], measures: list[str], labels: dict | None = None,
          pay: bool = False) -> dict:
    return {"kind": "table", "title": title, "columns": columns, "measures": measures, "labels": labels or {},
            "pay": pay}


# A measure's name in charts and tables (legend, tooltip, header) unless the chart gives one: Fusion leaver measures
# say "in Fusion"; the BSC measures lose their prefix
LABELS = {"Leavers": "Leavers in Fusion", "Voluntary Leavers": "Voluntary leavers in Fusion",
          "Voluntary Turnover Rate %": "Voluntary leaver rate in Fusion",
          "New Hire Turnover %": "New-hire leaver rate in Fusion", "BSC Turnover": "Turnover",
          "BSC Saudization": "Saudization", "BSC Vacancy Rate": "Vacancy rate",
          "BSC Time to Fill (days)": "Time to fill (days)", "BSC Revenue per FTE": "Revenue per FTE (SAR)",
          "BSC Revenue per Doctor": "Revenue per doctor (SAR)", "BSC Staff to Bed": "Staff to bed",
          "BSC Clinical to Doctor": "Clinical staff to doctor", "Payroll Cost": "Payroll cost (SAR)",
          "Gross Pay": "Gross pay (SAR)", "Gross Pay (Open Payroll)": "Gross pay in open payroll (SAR)",
          "Involuntary Leavers": "Involuntary leavers in Fusion", "Branch Transfers": "Branch transfers",
          "Promotions": "Promotions (Fusion action)", "Job Changes": "Job changes", "Grade Changes": "Grade changes",
          "Position Changes": "Position changes", "Location Changes": "Location changes",
          "Requisitions Approved": "Requisitions approved", "Requisitions Filled": "Requisitions filled",
          "Open Openings": "Open openings", "Absence Days": "Absence days"}


def _labels(spec: dict) -> dict[Field, str]:
    names = {**LABELS, **spec["labels"]}
    return {meas(m): names[m] for m in spec["measures"] if m in names}


def _visual(spec: dict, x: float, y: float, w: float, h: float) -> Visual:
    ms = [meas(m) for m in spec["measures"]]
    kind = spec["kind"]
    if kind == "card":
        return Visual("card", x, y, w, h, roles={"Values": ms}, labels=_labels(spec),
                      filters=[Filter(ms[0], "notblank")] if spec["pay"] else [],
                      props=card_look(24, NAVY, category=True, box=True))
    if kind == "lineChart":
        return Visual("lineChart", x, y, w, h, roles={"Category": [YEAR_MONTH], "Y": ms}, title=spec["title"],
                      labels=_labels(spec), filters=[LAST_12_CLOSED], sort=YEAR_MONTH, sort_dir="asc")
    if kind == "barChart":
        by = spec["by"]
        return Visual("barChart", x, y, w, h, roles={"Category": [by], "Y": ms}, title=spec["title"],
                      labels=_labels(spec), sort=ms[0], top_n=(ms[0], TOP) if spec["top"] else None)
    columns = [c for c, _label in spec["columns"]]
    return Visual("table", x, y, w, h, roles={"Values": columns + ms}, title=spec["title"],
                  labels={**{c: label for c, label in spec["columns"]}, **_labels(spec)}, sort=columns[0],
                  sort_dir="asc")


def _notice(x: float, y: float, w: float, h: float) -> Visual:
    """[HR Pay Notice] ("Requires pay access") centred over a pay visual; blank for readers with pay access, so the
    card is filtered to a non-blank notice (Story's Cost block)."""
    return Visual("card", x, y + (h - NOTICE_H) / 2, w, NOTICE_H, roles={"Values": [PAY_NOTICE]},
                  filters=[Filter(PAY_NOTICE, "notblank")], props=card_look(16, NAVY))


def slicer(field: Field, label: str, x: float, y: float, w: float) -> Visual:
    """A multi-select dropdown with Select all, as the filter bar's Hospital; synced across pages by its field."""
    return Visual("slicerDropdown", x, y, w, SLICER_H, roles={"Values": [field]},
                  props={**bsc.select_all_selection(), **bsc.dropdown_look()}, labels={field: label})


def _row(n: int) -> float:
    return (W0 - GAP * (n - 1)) / n


def _slicer_row(fields: list[tuple[Field, str]], y: float) -> list[Visual]:
    w = _row(len(fields))
    return [slicer(f, label, X0 + i * (w + GAP), y, w) for i, (f, label) in enumerate(fields)]


def _interactions(page_name: str, month: Visual, slicers: list[Visual], data: list[Visual],
                  page_tables: set[str]) -> list[Interaction]:
    tables = page_tables | {f.table for s in slicers for f in s.roles["Values"]}
    out = [Interaction(month, v, "NoFilter") for v in data if v.sample == "lineChart"]
    out += [Interaction(s, t, "NoFilter") for s, t in _guarded(page_name, data, tables)]
    return out


def detail_page(name: str, display: str, cards: list[dict], grid: list[dict], extras: list[dict] = (),
                page_slicers: list[tuple[Field, str]] = ()) -> Page:
    """A detail page: the frame (Details tab current, Hospital, Month and the sub-tabs in the filter bar), the page's
    slicers, one or two rows of 4 or 5 cards, a 2 x 2 grid of charts (filling the screen, at least CHART_MIN_H
    high), and `extras` three to a row below it (the page then scrolls). Pay visuals get an HR Pay Notice over them:
    one over each pay chart, one over each row's run of pay cards."""
    per_row = len(cards) if len(cards) <= 5 else math.ceil(len(cards) / 2)
    if not 4 <= per_row <= 5 or len(cards) > 10 or len(grid) != 4:
        raise ValueError(f"page {name}: one or two rows of 4 or 5 cards and a 2 x 2 grid")
    hospital, month = filters()
    visuals = page_frame("headcount", [hospital, month] + sub_tabs(name))
    y = Y0
    own_slicers = _slicer_row(list(page_slicers), y) if page_slicers else []
    visuals += own_slicers
    if own_slicers:
        y += SLICER_H + GAP
    data: list[Visual] = []
    notices: list[Visual] = []
    w = _row(per_row)
    pay_runs: list[list[Visual]] = []  # per row, the pay cards (next to each other)
    for i, spec in enumerate(cards):
        v = _visual(spec, X0 + (i % per_row) * (w + GAP), y + (i // per_row) * (CARD_H + GAP), w, CARD_H)
        data.append(v)
        if spec["pay"]:
            if pay_runs and pay_runs[-1][-1] is data[-2] and pay_runs[-1][-1].y == v.y:
                pay_runs[-1].append(v)
            elif pay_runs and pay_runs[-1][-1] is not data[-2]:
                raise ValueError(f"page {name}: the pay cards must be next to each other")
            else:
                pay_runs.append([v])
    for run in pay_runs:
        notices.append(_notice(run[0].x, run[0].y, run[-1].x + run[-1].w - run[0].x, CARD_H))
    y += math.ceil(len(cards) / per_row) * (CARD_H + GAP)
    chart_w, chart_h = _row(2), max(CHART_MIN_H, (CONTENT_END - y - GAP) / 2)
    placed = [(spec, X0 + (i % 2) * (chart_w + GAP), y + (i // 2) * (chart_h + GAP), chart_w, chart_h)
              for i, spec in enumerate(grid)]
    grid_end = y + 2 * chart_h + GAP
    extra_w = _row(3)
    placed += [(spec, X0 + (i % 3) * (extra_w + GAP), grid_end + GAP + (i // 3) * (EXTRA_H + GAP), extra_w,
                EXTRA_H) for i, spec in enumerate(extras)]
    for spec, x, cy, cw, ch in placed:
        v = _visual(spec, x, cy, cw, ch)
        data.append(v)
        if spec["pay"]:
            notices.append(_notice(x, cy, cw, ch))
    visuals += data + notices
    rows = math.ceil(len(extras) / 3)
    bottom = grid_end + rows * (GAP + EXTRA_H)
    height = max(1080, math.ceil(bottom + BOTTOM_MARGIN)) if bottom > CONTENT_END else 1080
    page_filters = [hospitals()]
    interactions = _interactions(name, month, own_slicers + [hospital], data,
                                 {f.field.table for f in page_filters})
    return Page(name, display, visuals, filters=page_filters, interactions=interactions, height=height)


# ---- the pages ----------------------------------------------------------------------------------------------------

def headcount_page() -> Page:
    hc = ["Headcount"]
    return detail_page(
        "headcount", "Headcount & mix",
        cards=[card("Headcount", "Headcount"), card("FTE", "FTE"), card("Average Headcount", "Average headcount"),
               card("Average FTE", "Average FTE"), card("BSC Saudization", "Saudization"),
               card("Female Share %", "Female share"), card("Contingent Share %", "Contingent workers' share")],
        grid=[trend("Headcount and FTE", ["Headcount", "FTE"]),
              bars("Headcount by hospital", BRANCH_NAME, hc),
              bars("Headcount by department, top 15", DEPARTMENT, hc, top=True),
              bars("Headcount by job, top 15", col("Job", "Job Name"), hc, top=True)],
        extras=[bars("Headcount by grade, top 15", col("Grade", "Grade Name"), hc, top=True),
                bars("Headcount by position, top 15", col("Position", "Position Name"), hc, top=True),
                bars("Headcount by location, top 15", col("Location", "Location Name"), hc, top=True),
                bars("Headcount, Saudi and non-Saudi", col("Headcount", "Is Saudi"), hc),
                bars("Headcount by gender", col("Headcount", "Gender"), hc),
                bars("Headcount by worker type", col("Employee", "Worker Type"), hc),
                bars("Headcount by age band", col("Headcount", "Age Band"), hc),
                bars("Headcount by tenure band (years)", col("Headcount", "Tenure Band"), hc),
                bars("Headcount, full and part time", col("Job", "Full Part Time"), hc)],
        page_slicers=WORKFORCE_SLICERS)


CHANGES = ["Job Changes", "Grade Changes", "Position Changes", "Location Changes"]


def movements_page() -> Page:
    leavers = ["Leavers", "Voluntary Leavers"]
    return detail_page(
        "movements", "Movements & turnover",
        cards=[card("Hires", "Hires"), card("Leavers", "Leavers in Fusion"),
               card("Involuntary Leavers", "Involuntary leavers in Fusion"), card("BSC Turnover", "Turnover"),
               card("Voluntary Turnover Rate %", "Voluntary leaver rate in Fusion"),
               card("New Hire Turnover %", "New-hire leaver rate in Fusion"),
               card("Branch Transfers", "Branch transfers"), card("Promotions", "Promotions (Fusion action)")],
        grid=[trend("Hires and leavers in Fusion", ["Hires"] + leavers + ["Involuntary Leavers"]),
              trend("Turnover and voluntary leaver rate in Fusion", ["BSC Turnover", "Voluntary Turnover Rate %"]),
              bars("Movements by movement group", col("Worker Action", "Movement Group"), ["Movements"]),
              bars("Changes by kind and hospital", BRANCH_NAME, CHANGES)],
        extras=[bars("Leavers in Fusion by action reason, top 15", col("Worker Action", "Action Reason Name"), leavers,
                     top=True),
                bars("Leavers in Fusion by current tenure band (years)", col("Employee", "Tenure Band"), leavers),
                bars("Hires by action (rehires included), top 15", col("Worker Action", "Action Name"), ["Hires"],
                     top=True),
                bars("Hires and leavers in Fusion by hospital", BRANCH_NAME, ["Hires", "Leavers"]),
                bars("Hires and leavers in Fusion by department, top 15", DEPARTMENT, ["Hires", "Leavers"],
                     top=True),
                bars("Branch transfers and promotions by hospital", BRANCH_NAME, ["Branch Transfers", "Promotions"])],
        page_slicers=WORKFORCE_SLICERS)


def payroll_page() -> Page:
    """Payroll & overtime. Not by job (ruling R26): Payroll has no job, and only the Department slicer suits every
    visual ([Payroll Cost per FTE] rejects Pay Category and Payroll)."""
    return detail_page(
        "payroll", "Payroll & overtime",
        cards=[card("Payroll Cost", "Payroll cost (SAR)", pay=True), card("Gross Pay", "Gross pay (SAR)", pay=True),
               card("Overtime Share %", "Overtime share of gross pay", pay=True),
               card("Payroll Cost per FTE", "Payroll cost per FTE (SAR)", pay=True),
               card("Gross Pay (Open Payroll)", "Gross pay in open payroll (SAR)", pay=True)],
        grid=[trend("Payroll cost and gross pay", ["Payroll Cost", "Gross Pay"], pay=True),
              bars("Gross pay by pay category (overtime included)", col("Pay Category", "Pay Category"),
                   ["Gross Pay"], pay=True),
              bars("Payroll cost by department, top 15", DEPARTMENT, ["Payroll Cost"], top=True, pay=True),
              table("Payroll source and status by hospital: an open month is not final",
                    [(BRANCH_NAME, "Hospital"), (col("Payroll", "Source"), "Source"),
                     (col("Payroll", "Payroll Status"), "Payroll status")],
                    ["Payroll Cost", "Gross Pay (Open Payroll)"], pay=True)],
        extras=[trend("Overtime share of gross pay", ["Overtime Share %"], pay=True),
                bars("Payroll cost per FTE by hospital (SAR)", BRANCH_NAME, ["Payroll Cost per FTE"], pay=True),
                bars("Overtime share of gross pay by hospital", BRANCH_NAME, ["Overtime Share %"], pay=True)],
        page_slicers=[(UNIFIED_DEPARTMENT, "Department")])


def absence_page() -> Page:
    """Absence & leave. Not by department (ruling R26): the absence and leave facts have no HR department."""
    return detail_page(
        "absence", "Absence & leave",
        cards=[card("Sick Days", "Sick days"), card("Sick Leave Rate %", "Sick leave rate"),
               card("Absence Days", "Absence days, all kinds"),
               card("Leave Balance (days)", "Leave balance at month end (days)", pay=True),
               card("Leave Liability", "Leave liability at month end (SAR)", pay=True),
               card("Average Leave Balance (days)", "Average leave balance (days)", pay=True),
               card("Current Leave Balance (days)", "Leave balance now (days)", pay=True),
               card("Current Leave Liability", "Leave liability now (SAR)", pay=True)],
        grid=[trend("Sick leave rate", ["Sick Leave Rate %"]),
              bars("Absence days by category", col("Absence Type", "Absence Category"), ["Absence Days"]),
              bars("Absence days by absence type, top 15", ABSENCE_TYPE, ["Absence Days"], top=True),
              bars("Sick leave rate by hospital", BRANCH_NAME, ["Sick Leave Rate %"])],
        extras=[bars("Sick days by absence type, top 15", ABSENCE_TYPE, ["Sick Days"], top=True),
                trend("Sick days", ["Sick Days"]),
                trend("Absence days, all kinds", ["Absence Days"]),
                bars("Leave liability by hospital (SAR)", BRANCH_NAME, ["Leave Liability"], pay=True),
                bars("Leave balance by hospital (days)", BRANCH_NAME, ["Leave Balance (days)"], pay=True),
                trend("Leave liability (SAR)", ["Leave Liability"], pay=True)])


def recruitment_page() -> Page:
    """Recruitment, by hospital only: Requisitions has no department (spec "Pages" 4)."""
    return detail_page(
        "recruitment", "Recruitment",
        cards=[card("BSC Vacancy Rate", "Vacancy rate (openings / budgeted FTE)"),
               card("BSC Time to Fill (days)", "Time to fill (days)"),
               card("Requisitions Approved", "Requisitions approved"),
               card("Requisitions Filled", "Requisitions filled"), card("Open Openings", "Open openings")],
        grid=[trend("Vacancy rate", ["BSC Vacancy Rate"]),
              bars("Vacancy rate by hospital", BRANCH_NAME, ["BSC Vacancy Rate"]),
              trend("Requisitions approved and filled", ["Requisitions Approved", "Requisitions Filled"]),
              bars("Open openings by hospital", BRANCH_NAME, ["Open Openings"])],
        extras=[trend("Time to fill (days)", ["BSC Time to Fill (days)"]),
                bars("Time to fill by hospital (days)", BRANCH_NAME, ["BSC Time to Fill (days)"]),
                trend("Open openings at month end", ["Open Openings"])])


STAFF_CATEGORY = col("Staff Productivity", "Staff Category")


def productivity_page() -> Page:
    return detail_page(
        "productivity", "Productivity",
        cards=[card("Visits per FTE", "Visits per FTE, doctors and nurses", pay=True),
               card("Revenue per Payroll SAR", "Revenue per payroll SAR", pay=True),
               card("Payroll Cost per Visit", "Payroll cost per visit (SAR)", pay=True),
               card("BSC Revenue per FTE", "Revenue per FTE (SAR)"),
               card("BSC Revenue per Doctor", "Revenue per doctor (SAR)")],
        grid=[bars("Visits per FTE, doctors and nurses", STAFF_CATEGORY, ["Visits per FTE"], pay=True),
              bars("Revenue per payroll SAR, doctors and nurses", STAFF_CATEGORY, ["Revenue per Payroll SAR"],
                   pay=True),
              trend("Visits per FTE", ["Visits per FTE"], pay=True),
              bars("Staff to bed and clinical staff to doctor by hospital", BRANCH_NAME,
                   ["BSC Staff to Bed", "BSC Clinical to Doctor"])],
        extras=[bars("Payroll cost per visit, doctors and nurses (SAR)", STAFF_CATEGORY, ["Payroll Cost per Visit"],
                     pay=True),
                bars("Revenue per FTE by hospital (SAR)", BRANCH_NAME, ["BSC Revenue per FTE"]),
                bars("Revenue per doctor by hospital (SAR)", BRANCH_NAME, ["BSC Revenue per Doctor"])])


def detail_pages() -> list[Page]:
    """The six detail pages, in DETAIL_PAGES order."""
    return [headcount_page(), movements_page(), payroll_page(), absence_page(), recruitment_page(),
            productivity_page()]


# ---- Employee list ------------------------------------------------------------------------------------------------

def employee_list_page() -> Page:
    """Hidden drill-through on hospital and department (keep all filters off; see the module docstring)."""
    hospital, month = filters()
    back = bsc.back_button(SUB_TAB_X, SUB_TAB_Y, BACK_W, 54)
    visuals = page_frame(None, [hospital, month, back])
    own_slicers = _slicer_row(WORKFORCE_SLICERS, Y0)
    y = Y0 + SLICER_H + GAP
    worker = col("Employee", "Worker Number")
    # [HR Employee Name] is blank for every row without pay access, and a table keeps only the rows where one of its
    # measures is not blank: [Headcount] (1 a person) is a column too, so the rows stay
    fields = [(worker, "Worker number"), (EMPLOYEE_NAME, "Name (pay access)"),
              (col("Staff", "Staff ID"), "Oasis staff ID"), (BRANCH_NAME, "Hospital"), (DEPARTMENT, "Department"),
              (col("Job", "Job Name"), "Job"), (col("Grade", "Grade Name"), "Grade"),
              (col("Employee", "Hire Date"), "Hire date"), (col("Employee", "Assignment Status"), "Status"),
              (HEADCOUNT, "Headcount")]
    people = Visual("table", X0, y, W0, CONTENT_END - y, roles={"Values": [f for f, _ in fields]},
                    title="People in the headcount of the month", labels=dict(fields),
                    filters=[Filter(HEADCOUNT, "notblank")], sort=worker, sort_dir="asc")
    visuals += own_slicers + [people]
    page_filters = [hospitals()]
    drill = [BRANCH_NAME, DEPARTMENT]
    interactions = _interactions(EMPLOYEE_LIST, month, own_slicers + [hospital], [people],
                                 {f.field.table for f in page_filters} | {f.table for f in drill})
    return Page(EMPLOYEE_LIST, "Employee list", visuals, filters=page_filters, drill_fields=drill, hidden=True,
                keep_filters=False, interactions=interactions)
