"""The six detail pages under the Details tab (spec "Pages" 4) and the hidden Employee list (spec "Pages" 7).

Each detail page has the frame with the Details tab current, Branch, Month and the six sub-tabs in the filter bar,
then in the content box: the page's own slicers when every visual on it accepts them, then one or more sections,
each an optional heading, one or two rows of 3 to 5 cards for the selected month (each with an icon), and charts in
two columns, then three. A bar chart is as high as its bars and labels need, other charts LINE_H, and charts fill
their columns top-down (user request 2026-11-04). Every chart shows its data labels (line charts their markers) and
no value axis. Pages taller than 1080 px fit their width and scroll (pbir.page_json, ruling R24).

    headcount     Headcount, FTE, average headcount and FTE, Saudization, female and contingent share; trend, by
                  branch, department, job, grade, position, location, Saudi, gender, worker type, age band, tenure
                  band, full / part time
    movements     Hires, leavers, involuntary leavers, turnover (BSC Turnover), voluntary and new-hire leaver rates,
                  branch transfers, promotions; trends, movements by movement group, changes by kind (job, grade,
                  position, location), leavers by action reason and current tenure band, hires by action, by branch
                  and department
    payroll       Two sections (user request 2026-11-04). Gross pay, what employees are paid: gross pay, overtime
                  share, gross pay in open payroll; trends, by pay category, branch and department, source and
                  payroll status by branch. Payroll cost, what the employer pays: payroll cost, employer charges and
                  their share, cost per FTE; the step from gross pay to cost (waterfall by pay group, monthly
                  stack), cost by pay category, department and branch. Not by job (ruling R26): Payroll has no job.
    absence       Sick days and rate, absence days of all kinds, leave balance and liability (month end, average,
                  now); trends, absence days by category and type, sick days by type, by branch. Not by department
                  (ruling R26): the absence and leave facts have no HR department.
    recruitment   Vacancy rate, time to fill, requisitions approved and filled, open openings; trends and by branch
                  (no department: Requisitions has none)
    productivity  Visits per FTE, revenue per payroll SAR, payroll cost per visit (doctors and nurses), revenue per
                  FTE and per doctor, staff to bed, clinical to doctor

Rules the pages keep:
- Cards, bar and waterfall charts follow the selected month. Line and stacked column charts are 12-month trends:
  'Date'[Month Offset] 1 to 12 (the last 12 closed months) and a NoFilter interaction from the Month slicer, as on
  Story.
- The branches page filter: the eight hospitals and Head Office (user decision 2026-11-03: Head Office everywhere),
  as Home, so the figures agree with Home; it keeps out only the Branch dimension's Group member (no HR data).
- Long slicer lists (Department, about 270 names; Job, Grade, Nationality) have the dropdown's search box.
- Guards: every measure returns "... can't be analysed by <table>" when a table its guard rejects is filtered
  (`blocked_tables`, read from the model). The build stops when a visual's own columns, a page slicer, the page
  filter or a drill field is such a table; a selection in a chart or table is kept from reaching a visual whose
  measures reject one of its tables (NoFilter interactions, written here).
- Pay (ruling R22): a visual with a pay figure has an [HR Pay Notice] card: "Requires pay access" to readers
  without pay access, "" (an empty card) to the others. On a chart or table it sits in the title band, right-aligned
  in a small font (ruling R31: over the plot area it took the hover and clicks); over a run of pay cards, centred. The card has no filter: a card filtered to no row prints
  "(Blank)" (the 2026-11-03 screenshots). Pay cards are still filtered to non-blank.
- Departments and positions (ruling R30): charts and the Department slicer use the prefix-free 'HR Department'
  [Department Base Name] and 'Position'[Position Base Name] ("Nursing Department", "Staff Nurse"), one bar for the
  same name at every hospital and Head Office; the per-hospital Department Name is only on the Employee list.
- Recruitment: while no budgeted FTE is loaded the vacancy rate is blank; its card is [HR Vacancy Rate Text] ("No
  budgeted FTE") and each vacancy chart has the [HR Vacancy Note] card in its title band ("" once loaded).
- Fusion leaver measures are labelled "in Fusion"; the headline turnover is [BSC Turnover]. Labels are this repo's
  (not title-cased).

Employee list (hidden): drill-through on 'Branch'[Branch Name] and 'HR Department'[Department Base Name] (the
detail charts' axes) with "keep all filters" off, as the BSC's family pages: a source visual's own filters ('HR KPI', 'Pay Category', 'Worker Action')
would make [Headcount] return its guard message. The month and the other selections arrive through the page's
slicers, synced with the detail pages'. One table (worker number, person number, name, Oasis staff ID, branch, department, job,
grade, hire date, status, headcount), filtered to [Headcount] not blank (ruling R4): Employee has no branch
relationship or row filter, so branch security applies through the fact. The table groups by Employee columns only;
the Oasis staff ID, branch, department (the per-hospital name), job and grade are measures ([HR Employee ...]) read
through the month's headcount row. Grouped by the columns of six dimensions the query ran for minutes (over 160 s of
CPU on the test slot, an empty table in Desktop); this way it takes about 2 s. The name is the measure
[HR Employee Name], blank without pay access; the table has no 'Employee Details' column, because a table grouped by
a column with no visible rows (the role hides Employee Details without pay access) has no rows at all.
"""
from __future__ import annotations

import math
import re
from functools import lru_cache

from fields import MODEL_DIR
from frame import CONTENT, NAVY, _lit, no_container
from hr_frame import (ICON_SIZE, MUTED, SUB_TAB_X, SUB_TAB_Y, bar_look, branches, bsc, card_look, column_look, filters,
                      icon, line_look, page_frame, search_box, sub_tabs, title_notice)
from model import Field, Filter, Interaction, Page, Visual, col, meas

GAP = 24
X0, Y0, W0, H0 = CONTENT  # 30, 186, 1860, 870
CONTENT_END = Y0 + H0  # 1056
SLICER_H = 66  # as the filter bar's slicers
CARD_H = 110
NOTICE_H = 60
BOTTOM_MARGIN = 30
TOP = 15  # bars on a long axis: the top 15 by the chart's first measure
BACK_W = 110

BRANCH_NAME = col("Branch", "Branch Name")
YEAR_MONTH = col("Date", "Year Month Name")
MONTH_OFFSET = col("Date", "Month Offset")
LAST_12_CLOSED = Filter(MONTH_OFFSET, "in", list(range(1, 13)))
# prefix-free ("Icu-Nurse" for "ABH Icu-Nurse"; ruling R30): the charts' axis, the slicer and the drill field
DEPARTMENT = col("HR Department", "Department Base Name")
POSITION = col("Position", "Position Base Name")  # prefix-free ("Staff Nurse" for "RBW Staff Nurse")
HEADCOUNT = meas("Headcount")
PAY_NOTICE = meas("HR Pay Notice")
EMPLOYEE_NAME = meas("HR Employee Name")  # one employee's Fusion name; blank without pay access
ABSENCE_TYPE = col("Absence Type", "Absence Type Name")
EMPLOYEE_LIST = "employee_list"

# The page slicers (field, label): only on pages where every measure accepts their tables
WORKFORCE_SLICERS = [(DEPARTMENT, "Department"), (col("Job", "Job Name"), "Job"),
                     (col("Grade", "Grade Name"), "Grade"), (col("Employee", "Nationality"), "Nationality"),
                     (col("Employee", "Worker Type"), "Worker type")]
# Slicers with a search box in their dropdown: long lists (Department has about 270 prefix-free names)
SEARCH_FIELDS = {DEPARTMENT, col("Job", "Job Name"), col("Grade", "Grade Name"), col("Employee", "Nationality")}


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

def card(measure: str, label: str, pay: bool = False, decimals: int | None = None) -> dict:
    """A card for the selected month: the figure over its label, with the measure's icon (CARD_ICONS). `pay`: needs
    pay access. `decimals`: the value's decimal places, whatever the measure's format."""
    return {"kind": "card", "measures": [measure], "labels": {measure: label}, "pay": pay, "decimals": decimals}


def trend(title: str, measures: list[str], labels: dict | None = None, pay: bool = False,
          note: str | None = None, stacked: bool = False) -> dict:
    """A line chart of the last 12 closed months; `stacked`: a stacked column chart instead (parts of a total).
    `note`: as bars()."""
    return {"kind": "stackedColumnChart" if stacked else "lineChart", "title": f"{title}, last 12 closed months",
            "measures": measures, "labels": labels or {}, "pay": pay, "note": note}


def bars(title: str, by: Field, measures: list[str], labels: dict | None = None, top: bool = False,
         pay: bool = False, note: str | None = None, filters: list[Filter] = (), n: int | None = None) -> dict:
    """A bar chart for the selected month, sorted by its first measure; `top`: only the top 15. `note`: a text measure
    shown on a card over the chart ("" when there is nothing to say). `filters`: the visual's own filters. `n`: the
    number of bars when the axis is not in AXIS_COUNTS (the chart's height fits its bars)."""
    return {"kind": "barChart", "title": title, "by": by, "measures": measures, "labels": labels or {}, "top": top,
            "pay": pay, "note": note, "filters": list(filters), "n": n}


def waterfall(title: str, by: Field, measure: str, labels: dict | None = None, pay: bool = False,
              filters: list[Filter] = ()) -> dict:
    """A waterfall for the selected month: `measure` by `by` (in `by`'s order), then the total."""
    return {"kind": "waterfallChart", "title": title, "by": by, "measures": [measure], "labels": labels or {},
            "pay": pay, "note": None, "filters": list(filters)}


def table(title: str, columns: list[tuple[Field, str]], measures: list[str], labels: dict | None = None,
          pay: bool = False, h: float | None = None) -> dict:
    return {"kind": "table", "title": title, "columns": columns, "measures": measures, "labels": labels or {},
            "pay": pay, "h": h}


def section(cards: list[dict], blocks: list[tuple[int, list[dict]]], title: str | None = None,
            subtitle: str | None = None) -> dict:
    """A part of a detail page: an optional heading (`title` over `subtitle`), a row or two of cards, then blocks of
    charts, each (columns, charts)."""
    return {"title": title, "subtitle": subtitle, "cards": cards, "blocks": blocks}


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
          "Open Openings": "Open openings", "Absence Days": "Absence days",
          "Employer Charges": "Employer charges (SAR)",
          "Employer Charges Share %": "Employer charges' share of payroll cost"}

# A card's icon (hr_frame.icon), by its measure
CARD_ICONS = {
    "Headcount": "users", "FTE": "users", "Average Headcount": "users", "Average FTE": "users",
    "BSC Saudization": "flag", "Female Share %": "female", "Contingent Share %": "badge",
    "Hires": "user_plus", "Leavers": "user_minus", "Involuntary Leavers": "user_minus", "BSC Turnover": "swap",
    "Voluntary Turnover Rate %": "percent", "New Hire Turnover %": "percent", "Branch Transfers": "swap",
    "Promotions": "trend_up",
    "Gross Pay": "banknote", "Overtime Share %": "clock", "HR Open Payroll Text": "receipt",
    "Payroll Cost": "coins", "Employer Charges": "building", "Employer Charges Share %": "percent",
    "Payroll Cost per FTE": "coins",
    "Sick Days": "pulse", "Sick Leave Rate %": "pulse", "Absence Days": "calendar", "Leave Balance (days)": "sun",
    "Leave Liability": "wallet", "Average Leave Balance (days)": "sun", "Current Leave Balance (days)": "sun",
    "Current Leave Liability": "wallet",
    "HR Vacancy Rate Text": "target", "BSC Time to Fill (days)": "hourglass", "Requisitions Approved": "briefcase",
    "Requisitions Filled": "check", "Open Openings": "briefcase",
    "Visits per FTE": "chart", "Revenue per Payroll SAR": "trend_up", "Payroll Cost per Visit": "coins",
    "BSC Revenue per FTE": "banknote", "BSC Revenue per Doctor": "stethoscope",
}


def _labels(spec: dict) -> dict[Field, str]:
    names = {**LABELS, **spec["labels"]}
    return {meas(m): names[m] for m in spec["measures"] if m in names}


# ---- chart sizes --------------------------------------------------------------------------------------------------
# User request 2026-11-04: a bar chart is as high as its bars and labels need: the title band and padding, a legend
# when it has more than one measure, and per category 8 px plus BAR_SERIES_PX for each measure. Line, column and
# waterfall charts are LINE_H; tables TABLE_H unless the spec gives a height.
LINE_H = 300
TABLE_H = 330
SECTION_HEAD_H = 56  # a section heading: title over subtitle
TRENDS = ("lineChart", "stackedColumnChart")  # 12-month charts: the Month slicer does not filter them
BAR_MIN_H, BAR_CHROME, BAR_LEGEND_H, BAR_SERIES_PX = 150, 64, 24, 18
# The number of bars on an axis for the report's branches and a month (HNH_Analytics_Test, 2026-11-04); a top N axis
# has TOP. An axis not listed needs the spec's `n`.
AXIS_COUNTS = {
    BRANCH_NAME: 9, col("Worker Action", "Movement Group"): 8, col("Headcount", "Is Saudi"): 2,
    col("Headcount", "Gender"): 2, col("Employee", "Worker Type"): 2, col("Headcount", "Age Band"): 6,
    col("Headcount", "Tenure Band"): 5, col("Job", "Full Part Time"): 2, col("Employee", "Tenure Band"): 5,
    col("Absence Type", "Absence Category"): 5, col("Staff Productivity", "Staff Category"): 2,
}


def chart_height(spec: dict) -> float:
    """The height a chart spec is drawn at (see "chart sizes")."""
    if spec["kind"] == "barChart":
        n = spec.get("n") or (TOP if spec["top"] else AXIS_COUNTS.get(spec["by"]))
        if n is None:
            raise ValueError(f"bar chart '{spec['title']}': give n, the number of bars on {spec['by']}")
        k = len(spec["measures"])
        return max(BAR_MIN_H, BAR_CHROME + (BAR_LEGEND_H if k > 1 else 0) + n * (8 + BAR_SERIES_PX * k))
    if spec["kind"] == "table":
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
                      props=card_look(24, NAVY, category=True, box=True, decimals=spec.get("decimals")))
    if kind in TRENDS:
        look = line_look() if kind == "lineChart" else column_look(_units(spec))
        return Visual(kind, x, y, w, h, roles={"Category": [YEAR_MONTH], "Y": ms}, title=spec["title"],
                      labels=_labels(spec), filters=[LAST_12_CLOSED], sort=YEAR_MONTH, sort_dir="asc", props=look)
    if kind == "barChart":
        by = spec["by"]
        return Visual("barChart", x, y, w, h, roles={"Category": [by], "Y": ms}, title=spec["title"],
                      labels=_labels(spec), sort=ms[0], top_n=(ms[0], TOP) if spec["top"] else None,
                      filters=list(spec.get("filters", [])), props=bar_look(_units(spec)))
    if kind == "waterfallChart":
        by = spec["by"]
        return Visual("waterfallChart", x, y, w, h, roles={"Category": [by], "Y": ms}, title=spec["title"],
                      labels=_labels(spec), sort=by, sort_dir="asc", filters=list(spec.get("filters", [])),
                      props=column_look(_units(spec)))
    columns = [c for c, _label in spec["columns"]]
    return Visual("table", x, y, w, h, roles={"Values": columns + ms}, title=spec["title"],
                  labels={**{c: label for c, label in spec["columns"]}, **_labels(spec)}, sort=columns[0],
                  sort_dir="asc")


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


def _slicer_row(fields: list[tuple[Field, str]], y: float) -> list[Visual]:
    w = _row(len(fields))
    return [slicer(f, label, X0 + i * (w + GAP), y, w) for i, (f, label) in enumerate(fields)]


def _interactions(page_name: str, month: Visual, slicers: list[Visual], data: list[Visual],
                  page_tables: set[str]) -> list[Interaction]:
    tables = page_tables | {f.table for s in slicers for f in s.roles["Values"]}
    out = [Interaction(month, v, "NoFilter") for v in data if v.sample in TRENDS]
    out += [Interaction(s, t, "NoFilter") for s, t in _guarded(page_name, data, tables)]
    return out


def _place(specs: list[dict], cols: int, y0: float) -> tuple[list[tuple], float]:
    """Charts in `cols` columns, each at its chart_height(), each into the column whose bottom is highest so far
    (then the leftmost): (spec, x, y, w, h) per chart, and the lowest bottom."""
    w = _row(cols)
    tops = [y0] * cols
    placed = []
    for spec in specs:
        h = chart_height(spec)
        c = min(range(cols), key=lambda i: (tops[i], i))
        placed.append((spec, X0 + c * (w + GAP), tops[c], w, h))
        tops[c] += h + GAP
    return placed, max(tops) - GAP


def _heading(title: str, subtitle: str | None, y: float) -> Visual:
    """A section heading: `title` (Segoe UI Semibold 14pt, navy) over `subtitle` (10pt, grey)."""
    runs = [(title, {"fontFamily": "Segoe UI Semibold", "fontSize": "14pt", "color": NAVY})]
    if subtitle:
        runs.append((subtitle, {"fontFamily": "Segoe UI", "fontSize": "10pt", "color": MUTED}))
    paragraphs = [{"textRuns": [{"value": v, "textStyle": st}]} for v, st in runs]
    return Visual("textbox", X0, y, W0, SECTION_HEAD_H,
                  props={"general": [{"properties": {"paragraphs": paragraphs}}], **no_container()})


def _cards(name: str, specs: list[dict], y: float) -> tuple[list[Visual], list[Visual], float]:
    """A row or two of 3 to 5 cards from y: (the cards, their icons and pay notices, the y below them). A run of pay
    cards next to each other in a row gets one notice over it."""
    per_row = len(specs) if len(specs) <= 5 else math.ceil(len(specs) / 2)
    if not 3 <= per_row <= 5 or len(specs) > 10:
        raise ValueError(f"page {name}: one or two rows of 3 to 5 cards")
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


def detail_page(name: str, display: str, cards: list[dict] = (), grid: list[dict] = (), extras: list[dict] = (),
                page_slicers: list[tuple[Field, str]] = (), sections: list[dict] | None = None) -> Page:
    """A detail page: the frame (Details tab current, Branch, Month and the sub-tabs in the filter bar), the page's
    slicers, then its sections, each an optional heading, a row or two of 3 to 5 cards (with icons) and blocks of
    charts. Without `sections`: one section of `cards`, `grid` in two columns and `extras` in three. Charts are as high
    as they need (chart_height) and fill their columns top-down (_place); the page grows and scrolls when they go
    below the screen. Pay visuals get an HR Pay Notice: in each pay chart's title band, over each run of pay cards."""
    if sections is None:
        sections = [section(list(cards), [(2, list(grid))] + ([(3, list(extras))] if extras else []))]
    branch, month = filters()
    visuals = page_frame("headcount", [branch, month] + sub_tabs(name))
    y = Y0
    own_slicers = _slicer_row(list(page_slicers), y) if page_slicers else []
    visuals += own_slicers
    if own_slicers:
        y += SLICER_H + GAP
    data: list[Visual] = []
    decor: list[Visual] = []  # headings, icons and notices: drawn over the data visuals
    for i, sec in enumerate(sections):
        if i:
            y += GAP  # more room between sections
        if sec["title"]:
            decor.append(_heading(sec["title"], sec["subtitle"], y))
            y += SECTION_HEAD_H + GAP / 2
        if sec["cards"]:
            cards_, more, y = _cards(name, sec["cards"], y)
            data += cards_
            decor += more
        for cols, specs in sec["blocks"]:
            if not specs:
                continue
            placed, bottom = _place(specs, cols, y)
            for spec, x, cy, cw, ch in placed:
                v = _visual(spec, x, cy, cw, ch)
                data.append(v)
                if spec["pay"]:  # in the chart's title band (ruling R31)
                    decor.append(title_notice(v, PAY_NOTICE.name))
                if spec.get("note"):
                    decor.append(title_notice(v, spec["note"]))
            y = bottom + GAP
    visuals += data + decor
    height = max(1080, math.ceil(y - GAP + BOTTOM_MARGIN))
    page_filters = [branches()]
    interactions = _interactions(name, month, own_slicers + [branch], data,
                                 {f.field.table for f in page_filters})
    return Page(name, display, visuals, filters=page_filters, interactions=interactions, height=height)


# ---- the pages ----------------------------------------------------------------------------------------------------

def headcount_page() -> Page:
    hc = ["Headcount"]
    return detail_page(
        "headcount", "Headcount & mix",
        # FTE equals headcount today (Fusion FTE values are 1; a zero FTE is replaced by 1): no decimals
        cards=[card("Headcount", "Headcount"), card("FTE", "FTE", decimals=0),
               card("Average Headcount", "Average headcount", decimals=0),
               card("Average FTE", "Average FTE", decimals=0), card("BSC Saudization", "Saudization"),
               card("Female Share %", "Female share"), card("Contingent Share %", "Contingent workers' share")],
        grid=[trend("Headcount and FTE", ["Headcount", "FTE"]),
              bars("Headcount by branch", BRANCH_NAME, hc),
              bars("Headcount by department, top 15", DEPARTMENT, hc, top=True),
              bars("Headcount by job, top 15", col("Job", "Job Name"), hc, top=True)],
        extras=[bars("Headcount by grade, top 15", col("Grade", "Grade Name"), hc, top=True),
                bars("Headcount by position, top 15", POSITION, hc, top=True),
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
              bars("Changes by kind and branch", BRANCH_NAME, CHANGES, n=5)],  # a month's changes are at a few branches
        extras=[bars("Leavers in Fusion by action reason, top 15", col("Worker Action", "Action Reason Name"), leavers,
                     top=True),
                bars("Leavers in Fusion by current tenure band (years)", col("Employee", "Tenure Band"), leavers),
                bars("Hires by action (rehires included), top 15", col("Worker Action", "Action Name"), ["Hires"],
                     top=True),
                bars("Hires and leavers in Fusion by branch", BRANCH_NAME, ["Hires", "Leavers"]),
                bars("Hires and leavers in Fusion by department, top 15", DEPARTMENT, ["Hires", "Leavers"],
                     top=True),
                bars("Branch transfers and promotions by branch", BRANCH_NAME, ["Branch Transfers", "Promotions"])],
        page_slicers=WORKFORCE_SLICERS)


PAY_CATEGORY = col("Pay Category", "Pay Category")
PAY_GROUP = col("Pay Category", "Pay Group")
GROSS_PAY_CATEGORIES = Filter(col("Pay Category", "Is Gross Pay"), "eq", ["Yes"])
COST_CATEGORIES = Filter(col("Pay Category", "Is Cost"), "eq", ["Yes"])


def payroll_page() -> Page:
    """Payroll & overtime, in two sections (user request 2026-11-04): gross pay, what employees are paid (earnings and
    earnings adjustments), and payroll cost, what the employer pays (gross pay plus the employer charges: GOSI employer
    charge and other employer charges). The cost section shows the step from one to the other: a waterfall by pay
    group and the 12-month split of payroll cost into gross pay and employer charges ([Employer Charges] = [Payroll
    Cost] - [Gross Pay]). Not by job (ruling R26): Payroll has no job, and only the Department slicer suits every
    visual ([Payroll Cost per FTE] rejects Pay Category and Payroll)."""
    gross = section(
        cards=[card("Gross Pay", "Gross pay (SAR)", pay=True),
               card("Overtime Share %", "Overtime share of gross pay", pay=True),
               card("HR Open Payroll Text", "Gross pay in open payroll", pay=True)],
        blocks=[(2, [trend("Gross pay", ["Gross Pay"], pay=True),
                     bars("Gross pay by pay category (overtime included)", PAY_CATEGORY, ["Gross Pay"], pay=True,
                          filters=[GROSS_PAY_CATEGORIES], n=11),
                     trend("Overtime share", ["Overtime Share %"], pay=True),
                     bars("Overtime share of gross pay by branch", BRANCH_NAME, ["Overtime Share %"], pay=True),
                     table("Payroll source and status by branch: an open month is not final",
                           [(BRANCH_NAME, "Branch"), (col("Payroll", "Source"), "Source"),
                            (col("Payroll", "Payroll Status"), "Payroll status")],
                           ["Gross Pay", "Gross Pay (Open Payroll)"], pay=True),
                     bars("Gross pay by department, top 15", DEPARTMENT, ["Gross Pay"], top=True, pay=True)])],
        title="Gross pay: what employees are paid",
        subtitle="Earnings (basic, allowances, overtime, leave pay, end of service, awards) and earnings adjustments "
                 "(absence and lateness deductions), before employee deductions.")
    cost = section(
        cards=[card("Payroll Cost", "Payroll cost (SAR)", pay=True),
               card("Employer Charges", "Employer charges (SAR)", pay=True),
               card("Employer Charges Share %", "Employer charges' share of payroll cost", pay=True),
               card("Payroll Cost per FTE", "Payroll cost per FTE (SAR)", pay=True)],
        blocks=[(2, [waterfall("From gross pay to payroll cost, by pay group", PAY_GROUP, "Payroll Cost", pay=True,
                               filters=[COST_CATEGORIES]),
                     trend("Payroll cost: gross pay and employer charges", ["Gross Pay", "Employer Charges"],
                           pay=True, stacked=True),
                     bars("Payroll cost by pay category (employer charges included)", PAY_CATEGORY, ["Payroll Cost"],
                          pay=True, filters=[COST_CATEGORIES], n=13),
                     bars("Payroll cost by department, top 15", DEPARTMENT, ["Payroll Cost"], top=True, pay=True),
                     bars("Payroll cost per FTE by branch (SAR)", BRANCH_NAME, ["Payroll Cost per FTE"], pay=True),
                     bars("Employer charges by branch (SAR)", BRANCH_NAME, ["Employer Charges"], pay=True)])],
        title="Payroll cost: what the employer pays",
        subtitle="Gross pay plus employer charges (GOSI employer charge and other employer charges). Payroll cost per "
                 "FTE and the BSC's staff cost per FTE use it.")
    return detail_page("payroll", "Payroll & overtime", sections=[gross, cost], page_slicers=[(DEPARTMENT, "Department")])


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
              bars("Sick leave rate by branch", BRANCH_NAME, ["Sick Leave Rate %"])],
        extras=[bars("Sick days by absence type, top 15", ABSENCE_TYPE, ["Sick Days"], top=True),
                trend("Sick days", ["Sick Days"]),
                trend("Absence days, all kinds", ["Absence Days"]),
                bars("Leave liability by branch (SAR)", BRANCH_NAME, ["Leave Liability"], pay=True),
                bars("Leave balance by branch (days)", BRANCH_NAME, ["Leave Balance (days)"], pay=True),
                trend("Leave liability (SAR)", ["Leave Liability"], pay=True)])


def recruitment_page() -> Page:
    """Recruitment, by branch only: Requisitions has no department (spec "Pages" 4). No budgeted FTE is loaded
    yet: the vacancy card and charts say so ([HR Vacancy Rate Text], [HR Vacancy Note])."""
    return detail_page(
        "recruitment", "Recruitment",
        cards=[card("HR Vacancy Rate Text", "Vacancy rate (openings / budgeted FTE)"),
               card("BSC Time to Fill (days)", "Time to fill (days)"),
               card("Requisitions Approved", "Requisitions approved"),
               card("Requisitions Filled", "Requisitions filled"), card("Open Openings", "Open openings")],
        grid=[trend("Vacancy rate", ["BSC Vacancy Rate"], note="HR Vacancy Note"),
              bars("Vacancy rate by branch", BRANCH_NAME, ["BSC Vacancy Rate"], note="HR Vacancy Note"),
              trend("Requisitions approved and filled", ["Requisitions Approved", "Requisitions Filled"]),
              bars("Open openings by branch", BRANCH_NAME, ["Open Openings"])],
        extras=[trend("Time to fill (days)", ["BSC Time to Fill (days)"]),
                bars("Time to fill by branch (days)", BRANCH_NAME, ["BSC Time to Fill (days)"]),
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
              bars("Staff to bed and clinical staff to doctor by branch", BRANCH_NAME,
                   ["BSC Staff to Bed", "BSC Clinical to Doctor"])],
        extras=[bars("Payroll cost per visit (SAR)", STAFF_CATEGORY, ["Payroll Cost per Visit"],  # by doctor, nurse
                     pay=True),
                bars("Revenue per FTE by branch (SAR)", BRANCH_NAME, ["BSC Revenue per FTE"]),
                bars("Revenue per doctor by branch (SAR)", BRANCH_NAME, ["BSC Revenue per Doctor"])])


def detail_pages() -> list[Page]:
    """The six detail pages, in DETAIL_PAGES order."""
    return [headcount_page(), movements_page(), payroll_page(), absence_page(), recruitment_page(),
            productivity_page()]


# ---- Employee list ------------------------------------------------------------------------------------------------

def employee_list_page() -> Page:
    """Hidden drill-through on branch and the prefix-free department (keep all filters off; see the module
    docstring)."""
    branch, month = filters()
    back = bsc.back_button(SUB_TAB_X, SUB_TAB_Y, BACK_W, 54)
    visuals = page_frame(None, [branch, month, back])
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
                    title="People in the headcount of the month", labels=dict(fields),
                    filters=[Filter(HEADCOUNT, "notblank")], sort=worker, sort_dir="asc",
                    props={"total": [{"properties": {"totals": _lit(False)}}]})  # a list of people has no total
    visuals += own_slicers + [people]
    page_filters = [branches()]
    drill = [BRANCH_NAME, DEPARTMENT]
    interactions = _interactions(EMPLOYEE_LIST, month, own_slicers + [branch], [people],
                                 {f.field.table for f in page_filters} | {f.table for f in drill})
    return Page(EMPLOYEE_LIST, "Employee list", visuals, filters=page_filters, drill_fields=drill, hidden=True,
                keep_filters=False, interactions=interactions)
