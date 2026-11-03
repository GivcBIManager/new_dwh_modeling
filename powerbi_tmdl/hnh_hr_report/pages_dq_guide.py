"""Data quality, How to use and Definitions (spec "Data quality page", "Pages" 5 and 6).

Data quality (`data_quality_page`): the issue catalogue with its records behind it. The filter bar has the Hospital
slicer only: the records carry no month (the model has no relationship to Date, and the measures allow no Date
filter), so there is no Month slicer. A page filter keeps the active issues ('HR Data Issues'[Status]). Top: cards for
[HR Open Issues], [HR Issue Records] and [HR Affected Employees] (distinct people), and the records by "Fix In".
Middle: the issue table and the issue x hospital matrix. Bottom: the records table (cross-filtered by the issue table
and the matrix: a selection in either narrows it) and a table of Issue Name and How To Fix (every issue's fix; one row once an issue is selected). Head Office (100)
records show to administrators only: the role filters the rest. The records table does not filter the other visuals.

How to use (`guide_page`) and Definitions (`definitions_page`) are the two Guide pages the help buttons open; the
Guide tab opens How to use. Definitions is a table over 'HR KPI' with an Area slicer and no Kind filter: the scored
KPIs and the metrics defined without a target are all listed.
"""
from __future__ import annotations

from frame import CONTENT, NAVY
from hr_frame import HR_TARGET_TEXT, bsc, card_look, filters, page_frame
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
    hospital = filters()[0]
    visuals = page_frame("data_quality", [hospital])
    cards = []
    for i, (m, label) in enumerate([("HR Open Issues", "Open issues"), ("HR Issue Records", "Records to fix"),
                                    ("HR Affected Employees", "People affected")]):
        cards.append(Visual("card", X0 + i * (CARD_W + GAP), Y0, CARD_W, TOP_H, roles={"Values": [meas(m)]},
                            labels={meas(m): label}, props=card_look(32, NAVY, category=True, box=True)))
    bar = Visual("barChart", BAR_X, Y0, X0 + W0 - BAR_X, TOP_H, title="Records by where to fix them",
                 roles={"Category": [FIX_IN], "Y": [ISSUE_RECORDS]}, labels={ISSUE_RECORDS: "Records"})
    issues = Visual("table", X0, MID_Y, ISSUES_W, MID_H, title="Issues: select one to see its records",
                    roles={"Values": [ISSUE_NAME, col("HR Data Issues", "Severity"), FIX_IN,
                                      col("HR Data Issues", "Owner"), ISSUE_RECORDS]},
                    labels={ISSUE_NAME: "Issue", ISSUE_RECORDS: "Records"}, filters=[ACTIVE_ISSUES],
                    sort=ISSUE_RECORDS)
    matrix = Visual("matrix", MATRIX_X, MID_Y, X0 + W0 - MATRIX_X, MID_H, title="Records by issue and hospital",
                    roles={"Rows": [ISSUE_NAME], "Columns": [BRANCH_NAME], "Values": [ISSUE_RECORDS]},
                    labels={ISSUE_NAME: "Issue", ISSUE_RECORDS: "Records"}, sort=ISSUE_NAME, sort_dir="asc")
    records_cols = [(col("HR Data Issue Records", "Issue Code"), "Issue code"), (BRANCH_NAME, "Hospital"),
                    (col("HR Data Issue Records", "Worker Number"), "Worker number"),
                    (col("HR Data Issue Records", "Staff ID"), "Oasis staff ID"),
                    (col("Staff", "Staff Name"), "Oasis name"),
                    (col("HR Data Issue Records", "Field Name"), "Field"),
                    (col("HR Data Issue Records", "Value Found"), "Value found"),
                    (col("HR Data Issue Records", "Record Date"), "Record date")]
    records = Visual("table", X0, BOT_Y, RECORDS_W, END - BOT_Y, title="Records behind the selected issue",
                     roles={"Values": [f for f, _ in records_cols]}, labels=dict(records_cols),
                     sort=records_cols[0][0], sort_dir="asc")
    fix = Visual("table", X0 + RECORDS_W + GAP, BOT_Y, FIX_W, END - BOT_Y, title="How to fix",
                 roles={"Values": [ISSUE_NAME, HOW_TO_FIX]}, labels={ISSUE_NAME: "Issue", HOW_TO_FIX: "How to fix"},
                 filters=[ACTIVE_ISSUES], sort=ISSUE_NAME, sort_dir="asc", props=bsc.word_wrap())
    data = cards + [bar, issues, matrix, records, fix]
    # the records table follows the issue table and the matrix; it does not narrow the rest
    interactions = [Interaction(records, v, "NoFilter") for v in data if v is not records]
    interactions += [Interaction(s, t, "NoFilter") for s, t in _guarded("data_quality", data, {"Branch"})]
    return Page("data_quality", "Data quality", visuals + data, filters=[ACTIVE_ISSUES],
                interactions=interactions)


# ---- How to use ---------------------------------------------------------------------------------------------------

def _section(heading: str, bullets: list[str]) -> list[tuple[str, str]]:
    return [("heading", heading)] + [("bullet", b) for b in bullets]


GUIDE_SECTIONS = [
    _section("Find your way", [
        "The tabs in the dark bar: Home (the headline figures), Story (one sentence and one chart for each area), "
        "Scorecard (every KPI and its status), Details (six pages, opened with the buttons beside the Month "
        "slicer), Data quality and Guide.",
        "How to use and Definitions, top right, open this Guide.",
        "On the Scorecard, select a row and use Drill through to KPI detail for its trend, hospitals and definition. "
        "Right-click a hospital or department bar and choose Drill through > Employee list for the people behind "
        "a number. Back, beside the Month slicer, returns to the page you came from.",
        "Hospital and Month carry over to every page. Month opens on Last closed month, the month just ended; pick "
        "another month in the list to see it.",
        "The sentences on Story and the figures on the cards describe the one month you picked. The trend charts "
        "always show the last 12 closed months, whatever Month says.",
        "Story rates show 2 decimals because monthly rates are small. The largest change names the hospital whose "
        "rate or number moved most."]),
    _section("Read the status", [
        "● On track (green): the actual meets the target.",
        "◆ Watch (amber): short of the target but still within the watch threshold. For on-target KPIs, the "
        "distance from the target is compared with the distance from the watch value to the target.",
        "■ At risk (red): it is worse than the watch value.",
        "○ No target yet (grey): no target is set, so the KPI is not scored.",
        "– No data (grey): there is no figure for the month.",
        "Parked: the KPI is listed but not scored for now.",
        "🔒 Requires pay access: pay figures (payroll, overtime, leave, productivity) show only to users with pay "
        "access; others see this note instead of a number.",
        "Every target marked (placeholder) is a starting value, the current level, until HR sets the real one. HR "
        "decides the targets; the BI manager enters them (docs/hr_config.md). The mark goes when a real target is "
        "in."]),
    _section("Know the figures", [
        "Turnover is the BSC turnover: Oasis resignations for hospitals 1 to 5 and Fusion voluntary leavers for "
        "hospitals 6 to 8. The leaver figures marked in Fusion count Fusion leavers and do not reconcile with "
        "it; they are not scored.",
        "Promotions are the Fusion PROMOTION action. HR to confirm that this is the definition they want.",
        "Absence is not shown by department and payroll is not shown by job: the model has no department on the "
        "absence facts and no job on payroll.",
        "Data quality: the records are rebuilt with the nightly build, so a fix at the source disappears on the "
        "next day's refresh. Records at Head Office are visible to administrators only.",
        "Definitions lists every KPI and metric with its definition, formula, source and caveats; pick an Area to "
        "narrow it.",
        "Questions, corrections, or a target to change: contact the BI manager."]),
]

TITLE_H = 54
BODY_Y = Y0 + TITLE_H + 18  # 258
COL_W = (W0 - 2 * GAP) / 3
COLS = [X0 + (COL_W + GAP) * i for i in range(3)]


def guide_page() -> Page:
    visuals = page_frame("guide", []) + [bsc._page_title("How to use the HR report")]
    visuals += [bsc._text(x, BODY_Y, COL_W, END - BODY_Y, sec) for x, sec in zip(COLS, GUIDE_SECTIONS)]
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
    fields = ([AREA, name] + [col("HR KPI", c) for c in ("Kind", "Definition", "Formula", "Source System", "Grain",
                                                          "Direction")]
              + [HR_TARGET_TEXT, col("HR KPI", "Caveats"), order])
    # No Kind filter: the scored KPIs and the metrics are all defined here
    table = Visual("table", X0, TABLE_Y, W0, END - TABLE_Y, title="Every KPI and metric", roles={"Values": fields},
                   labels={name: "KPI or metric", HR_TARGET_TEXT: "Target", order: "Order"}, sort=order,
                   sort_dir="asc", props=bsc.word_wrap())
    hospital, month = filters()
    return Page("guide_definitions", "Definitions", page_frame("guide", [hospital, month]) + [area, table])


def guide_pages() -> list[Page]:
    return [guide_page(), definitions_page()]
