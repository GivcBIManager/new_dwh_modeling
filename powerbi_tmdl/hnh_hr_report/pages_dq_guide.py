"""Data quality, How to use and Definitions (spec "Data quality page", "Pages" 5 and 6).

Data quality (`data_quality_page`): the issue catalogue with its records behind it. The filter bar has the Branch
slicer only: the records carry no month (the model has no relationship to Date, and the measures allow no Date
filter), so there is no Month slicer. Page filters keep the active issues ('HR Data Issues'[Status]) and the report's
branches (the hospitals and Head Office, as every data page). Top: cards for
[HR Open Issues], [HR Issue Records] and [HR Affected Employees] (distinct people), and the records by "Fix In".
Middle: the issue table and the issue x branch matrix. Bottom: the records table (cross-filtered by the issue table
and the matrix: a selection in either narrows it) and a table of Issue Name and How To Fix (every issue's fix; one row once an issue is selected). Head Office (100)
records show to administrators only: the role filters the rest. The records table does not filter the other visuals.

How to use (`guide_page`) and Definitions (`definitions_page`) are the two Guide pages the help buttons open; the
Guide tab opens How to use. Definitions is a table over 'HR KPI' with an Area slicer and no Kind filter: the scored
KPIs and the metrics defined without a target are all listed.
"""
from __future__ import annotations

from frame import CONTENT, NAVY, _lit
from hr_frame import (HR_TARGET_TEXT, HR_WATCH_TEXT, ICON_SIZE, bar_look, branches, bsc, card_look, filters, fixed_table,
                      icon, page_frame)
from model import Filter, Interaction, Page, Visual, col, meas
from pages_detail import _guarded

X0, Y0, W0, H0 = CONTENT  # 30, 186, 1860, 870
GAP = 24
END = Y0 + H0  # 1056

BRANCH_NAME = col("Branch", "Branch Name")
ISSUE_NAME = col("HR Data Issues", "Issue Name")
FIX_IN = col("HR Data Issues", "Fix In")
HOW_TO_FIX = col("HR Data Issues", "How To Fix")
ISSUE_STATUS = col("HR Data Issues", "Status")
ISSUE_RECORDS = meas("HR Issue Records")
ACTIVE_ISSUES = Filter(ISSUE_STATUS, "eq", ["active"])

# ---- Data quality -------------------------------------------------------------------------------------------------

TOP_H = 180
CARD_W = 280
BAR_X = X0 + 3 * (CARD_W + GAP)  # 942
MID_Y = Y0 + TOP_H + GAP  # 390
MID_H = 300
ISSUES_W = 1000
MATRIX_X = X0 + ISSUES_W + GAP
BOT_Y = MID_Y + MID_H + GAP  # 714
FIX_W = 540
RECORDS_W = W0 - FIX_W - GAP


def data_quality_page() -> Page:
    branch = filters()[0]
    visuals = page_frame("data_quality", [branch])
    cards, icons = [], []
    for i, (m, label, name) in enumerate([("HR Open Issues", "Open issues", "alert"),
                                          ("HR Issue Records", "Records to fix", "list"),
                                          ("HR Affected Employees", "People affected", "users")]):
        cards.append(Visual("card", X0 + i * (CARD_W + GAP), Y0, CARD_W, TOP_H, roles={"Values": [meas(m)]},
                            labels={meas(m): label}, props=card_look(32, NAVY, category=True, box=True)))
        icons.append(icon(name, X0 + i * (CARD_W + GAP) + 16, Y0 + 16))  # top left, clear of the centred figure
    bar = Visual("barChart", BAR_X, Y0, X0 + W0 - BAR_X, TOP_H, title="Records by where to fix them",
                 roles={"Category": [FIX_IN], "Y": [ISSUE_RECORDS]}, labels={ISSUE_RECORDS: "Records"},
                 props=bar_look())
    issues = Visual("table", X0, MID_Y, ISSUES_W, MID_H, title="Issues: select one to see its records",
                    roles={"Values": [ISSUE_NAME, col("HR Data Issues", "Severity"), FIX_IN,
                                      col("HR Data Issues", "Owner"), ISSUE_RECORDS]},
                    labels={ISSUE_NAME: "Issue", ISSUE_RECORDS: "Records"}, filters=[ACTIVE_ISSUES],
                    sort=ISSUE_RECORDS)
    matrix = Visual("matrix", MATRIX_X, MID_Y, X0 + W0 - MATRIX_X, MID_H, title="Records by issue and branch",
                    roles={"Rows": [ISSUE_NAME], "Columns": [BRANCH_NAME], "Values": [ISSUE_RECORDS]},
                    labels={ISSUE_NAME: "Issue", ISSUE_RECORDS: "Records"}, sort=ISSUE_NAME, sort_dir="asc")
    records_cols = [(col("HR Data Issue Records", "Issue Code"), "Issue code"), (BRANCH_NAME, "Branch"),
                    (col("HR Data Issue Records", "Worker Number"), "Worker number"),
                    (col("HR Data Issue Records", "Staff ID"), "Oasis staff ID"),
                    (meas("HR Issue Oasis Name"), "Oasis name"),  # "" without an Oasis staff record
                    (col("HR Data Issue Records", "Field Name"), "Field"),
                    (col("HR Data Issue Records", "Value Found"), "Value found"),
                    (col("HR Data Issue Records", "Record Date"), "Record date")]
    records = Visual("table", X0, BOT_Y, RECORDS_W, END - BOT_Y, title="Records behind the selected issue",
                     roles={"Values": [f for f, _ in records_cols]}, labels=dict(records_cols),
                     sort=records_cols[0][0], sort_dir="asc",
                     props={"total": [{"properties": {"totals": _lit(False)}}]})
    fix = Visual("table", X0 + RECORDS_W + GAP, BOT_Y, FIX_W, END - BOT_Y, title="How to fix",
                 roles={"Values": [ISSUE_NAME, HOW_TO_FIX]}, labels={ISSUE_NAME: "Issue", HOW_TO_FIX: "How to fix"},
                 filters=[ACTIVE_ISSUES], sort=ISSUE_NAME, sort_dir="asc", props=bsc.word_wrap())
    data = cards + [bar, issues, matrix, records, fix]
    # the records table follows the issue table and the matrix; it does not narrow the rest
    interactions = [Interaction(records, v, "NoFilter") for v in data if v is not records]
    interactions += [Interaction(s, t, "NoFilter") for s, t in _guarded("data_quality", data, {"Branch"})]
    return Page("data_quality", "Data quality", visuals + data + icons, filters=[ACTIVE_ISSUES, branches()],
                interactions=interactions)


# ---- How to use ---------------------------------------------------------------------------------------------------

def _section(heading: str, bullets: list[str]) -> list[tuple[str, str]]:
    return [("heading", heading)] + [("bullet", b) for b in bullets]


GUIDE_SECTIONS = [
    [_section("Find your way", [
        "Home: the headline figures. Story: one sentence and one chart per area. Scorecard: every KPI and its "
        "status. Details: six pages of breakdowns. Data quality and Guide.",
        "On the Scorecard, select a KPI row, then Drill through to KPI detail.",
        "Right-click a branch or department bar, then Drill through > Employee list, to see the people. Back "
        "returns to the page you came from.",
        "Charts with arrows drill down a level: branch, then location; department, then job, position and grade; "
        "absence category, then type.",
        "Click a bar or a cell to filter the rest of the page; click it again to clear."]),
     _section("Pick the dates", [
        "Last closed month is on when the report opens: the cards and breakdowns show the month just ended.",
        "Click it off to use Dates. Hires, pay and absence days add up over the dates; headcount and leave "
        "balance are those at the end of the last closed month in them.",
        "Trend charts show the closed months of the Dates, the last 12 at most, with Last closed month on or off.",
        "Period, on Scorecard and KPI detail: the month (Current), quarter to date (QTD) or year to date (YTD). "
        "Annual targets of rates such as turnover are pro-rated to the months.",
        "Branch lists the eight hospitals and Head Office. Every page, KPI and target includes Head Office; it "
        "shows only to users whose access includes it."])],
    [_section("Read the status", [
        "● On track (green): the actual meets the target.",
        "◆ Watch (amber): short of the target, but within the watch threshold.",
        "■ At risk (red): worse than the watch value.",
        "○ No target yet (grey): no target is set.",
        "– No data (grey): no figure for the period.",
        "Parked: listed, but not scored for now.",
        "🔒 Requires pay access: pay figures show only to users with pay access.",
        "(placeholder): a starting target, the current level, until HR sets the real one. The BI manager enters "
        "targets (docs/hr_config.md)."]),
     _section("Scorecard formulas", [
        "Turnover, Saudization, vacancy rate, time to fill, staff to bed, clinical to doctor and revenue per FTE "
        "and per doctor use the balanced scorecard's formulas. That report covers the hospitals only.",
        "Vacancy rate and time to fill include Head Office's requisitions; the other sources have no Head Office "
        "data today, so Head Office reads No data there."])],
    [_section("Know the figures", [
        "Turnover is the BSC turnover: Oasis resignations for hospitals 1 to 5, Fusion voluntary leavers for "
        "hospitals 6 to 8. Leaver figures marked in Fusion count Fusion leavers only.",
        "Promotions are the Fusion PROMOTION action (HR to confirm).",
        "FTE equals headcount today: Fusion records an FTE of 1 for almost everyone, and a zero FTE is replaced by 1.",
        "Pay by grade uses each person's grade in the month's headcount; pay of people without one is left out.",
        "Absence days come from Fusion and, before each branch moved its absences to Fusion in 2026, from Oasis.",
        "Leave balances come from Fusion absence plans. Where Fusion has none for a person and month, Oasis gives "
        "it: the annual leave earned in the current contract minus the leave taken against it.",
        "Vacancy rate: open requisitions divided by the budgeted FTE of the year. It reads No budgeted FTE until "
        "the budget is loaded.",
        "Story rates show 2 decimals; the largest change names the branch that moved most.",
        "Unknown means the record names no department, job, grade or other item.",
        "Data quality is rebuilt nightly, so a fix at the source shows the next day.",
        "Questions or a target to change: contact the BI manager."])],
]

TITLE_H = 54
BODY_Y = Y0 + TITLE_H + 18  # 258
COL_W = (W0 - 2 * GAP) / 3
COLS = [X0 + (COL_W + GAP) * i for i in range(3)]
GUIDE_HEADING_PT, GUIDE_BODY_PT = 16, 13


def guide_text(sections: list[list[tuple[str, str]]]) -> dict:
    """A guide column's text box (user request 2026-11-05: the 12pt text was too compact): headings in 16pt
    Semibold navy, bullets in 13pt, an empty line between bullets and before each heading."""
    heading = {"fontFamily": "Segoe UI Semibold", "fontSize": f"{GUIDE_HEADING_PT}pt", "color": NAVY}
    body = {"fontFamily": "Segoe UI", "fontSize": f"{GUIDE_BODY_PT}pt", "color": NAVY}
    space = {"fontFamily": "Segoe UI", "fontSize": "6pt", "color": NAVY}
    out = []
    for i, sec in enumerate(sections):
        for style, text in sec:
            if style == "heading" and (i or out):
                out.append({"textRuns": [{"value": " ", "textStyle": dict(space)}]})
            value = "• " + text if style == "bullet" else text
            out.append({"textRuns": [{"value": value, "textStyle": dict(heading if style == "heading" else body)}]})
            out.append({"textRuns": [{"value": " ", "textStyle": dict(space)}]})
    return {"general": [{"properties": {"paragraphs": out}}]}


def guide_page() -> Page:
    visuals = page_frame("guide", []) + [bsc._page_title("How to use the HR report")]
    visuals += [Visual("textbox", x, BODY_Y, COL_W, END - BODY_Y, props={**guide_text(col), **bsc.white_panel()})
                for x, col in zip(COLS, GUIDE_SECTIONS)]
    return Page("guide", "How to use", visuals)


# ---- Definitions --------------------------------------------------------------------------------------------------

AREA = col("HR KPI", "Area")
AREA_SLICER = (X0, Y0, 360, 66)
TABLE_Y = Y0 + 66 + GAP


def definitions_page() -> Page:
    area = Visual("slicerDropdown", *AREA_SLICER, roles={"Values": [AREA]},
                  props={**bsc.select_all_selection(), **bsc.dropdown_look()}, labels={AREA: "Area"})
    name = col("HR KPI", "KPI Name")
    order = col("HR KPI", "Display Order")
    # Fixed widths in px (sum within the table's 1860 less the scroll bar), text wrapped: the table fits the page
    # (with auto-sized columns the Grain column fell off its right edge)
    widths = {AREA: 100, name: 170, col("HR KPI", "Kind"): 60, col("HR KPI", "Definition"): 340,
              col("HR KPI", "Formula"): 250, col("HR KPI", "Source System"): 130, col("HR KPI", "Grain"): 150,
              col("HR KPI", "Direction"): 80, HR_TARGET_TEXT: 120, HR_WATCH_TEXT: 120, col("HR KPI", "Caveats"): 250,
              order: 50}
    fields = list(widths)
    # No Kind filter: the scored KPIs and the metrics are all defined here
    table = Visual("table", X0, TABLE_Y, W0, END - TABLE_Y, title="Every KPI and metric", roles={"Values": fields},
                   labels={name: "KPI or metric", HR_TARGET_TEXT: "Target", HR_WATCH_TEXT: "Watch at",
                           order: "Order"}, sort=order, sort_dir="asc", props=fixed_table(widths, 10, left=(HR_TARGET_TEXT, HR_WATCH_TEXT)))
    return Page("guide_definitions", "Definitions", page_frame("guide", filters()) + [area, table])


def guide_pages() -> list[Page]:
    return [guide_page(), definitions_page()]
