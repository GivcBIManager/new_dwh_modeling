"""Story, the executive page (spec "Pages" 2): the HR Story Month heading, then six blocks top to bottom, each a
sentence (left, 40 %), a 12-month line chart and a KPI tile:

    Size           Headcount, FTE                      HR_HEADCOUNT
    Flow           BSC Turnover                        HR_TURNOVER
    Cost           Payroll Cost                        HR_STAFF_COST_PER_FTE
    Absence        Sick Leave Rate %                   HR_SICK_LEAVE_RATE
    Saudization    BSC Saudization                     HR_SAUDIZATION
    Hiring         BSC Vacancy Rate                    HR_VACANCY_RATE

The page is taller than 1080 px and scrolls (STORY_H). The Month slicer is single-select (ruling R18), so the tiles
and the sentences describe the one month. The charts show twelve months regardless: each carries a visual filter on
'Date'[Month Offset] 1 to 12 (the last 12 closed months; offset 0 is the open month) and ignores the Month slicer
(a NoFilter interaction). The Branch slicer still applies, and the page filter keeps the report's branches: the
eight hospitals and Head Office, in every chart, sentence and tile (user decision 2026-11-03). Trade-off: the window
ends at the last closed month, not at an arbitrary selected month.
"""
from __future__ import annotations

from frame import CONTENT, NAVY, _lit
from hr_frame import branches, card_look, filters, kpi_tile, line_look, page_frame, title_notice
from model import Filter, Interaction, Page, Visual, col, meas

GAP = 24
X0, Y0, W0, _H0 = CONTENT  # 30, 186, 1860
HEADING_H = 60
BLOCK_H = 280
BLOCKS_Y = Y0 + HEADING_H + GAP  # 270
BOTTOM_MARGIN = 30
STORY_H = BLOCKS_Y + 6 * BLOCK_H + 5 * GAP + BOTTOM_MARGIN  # 2100: the page height
SENTENCE_W = round(W0 * 0.4)  # 744
TILE_W = 340
CHART_X = X0 + SENTENCE_W + GAP
CHART_W = X0 + W0 - TILE_W - GAP - CHART_X  # 728
TILE_X = X0 + W0 - TILE_W

YEAR_MONTH = col("Date", "Year Month Name")
MONTH_OFFSET = col("Date", "Month Offset")
LAST_12_CLOSED = Filter(MONTH_OFFSET, "in", list(range(1, 13)))

# (story measure, chart measures, chart title, KPI tile code, the chart's note or None): [HR Pay Notice] on the pay
# chart, [HR Vacancy Note] on the vacancy chart (empty while no budgeted FTE is loaded), in the title band (R31)
BLOCKS = [
    ("HR Story Size", ["Headcount", "FTE"], "Headcount and FTE", "HR_HEADCOUNT", None),
    ("HR Story Flow", ["BSC Turnover"], "Turnover", "HR_TURNOVER", None),
    ("HR Story Cost", ["Payroll Cost"], "Payroll cost",
     "HR_STAFF_COST_PER_FTE", "HR Pay Notice"),
    ("HR Story Absence", ["Sick Leave Rate %"], "Sick leave rate", "HR_SICK_LEAVE_RATE", None),
    ("HR Story Saudization", ["BSC Saudization"], "Saudization", "HR_SAUDIZATION", None),
    ("HR Story Hiring", ["BSC Vacancy Rate"], "Vacancy rate", "HR_VACANCY_RATE", "HR Vacancy Note"),
]


def _heading() -> Visual:
    props = {**card_look(20, NAVY, box=True), "wordWrap": [{"properties": {"show": _lit(True)}}]}
    return Visual("card", X0, Y0, W0, HEADING_H, roles={"Values": [meas("HR Story Month")]}, props=props)


def _sentence(y: float, measure: str) -> Visual:
    props = {**card_look(14, NAVY, box=True), "wordWrap": [{"properties": {"show": _lit(True)}}]}
    return Visual("card", X0, y, SENTENCE_W, BLOCK_H, roles={"Values": [meas(measure)]}, props=props)


def _chart(y: float, measures: list[str], title: str) -> Visual:
    return Visual("lineChart", CHART_X, y, CHART_W, BLOCK_H,
                  roles={"Category": [YEAR_MONTH], "Y": [meas(m) for m in measures]},
                  title=f"{title}, last 12 closed months", filters=[LAST_12_CLOSED], sort=YEAR_MONTH, sort_dir="asc",
                  props=line_look())


def _note(chart: Visual, measure: str) -> Visual:
    """The chart's note in its title band, right-aligned (ruling R31): [HR Pay Notice] ("Requires pay access" without
    pay access) or [HR Vacancy Note]. The measure is "" when there is nothing to say, so the card shows nothing."""
    return title_notice(chart, measure)


def story_page() -> Page:
    bar = filters()
    month_slicer = bar[1]
    visuals = page_frame("story", bar) + [_heading()]
    charts: list[Visual] = []
    for i, (story, measures, title, code, note) in enumerate(BLOCKS):
        y = BLOCKS_Y + i * (BLOCK_H + GAP)
        chart = _chart(y, measures, title)
        charts.append(chart)
        visuals += [_sentence(y, story), chart]
        if note:
            visuals.append(_note(chart, note))
        visuals += kpi_tile(code, TILE_X, y, TILE_W, BLOCK_H)
    interactions = [Interaction(month_slicer, c, "NoFilter") for c in charts]
    # the hospitals and Head Office, as the sentences and tiles (user decision 2026-11-03)
    return Page("story", "Story", visuals, filters=[branches()], interactions=interactions, height=STORY_H)
