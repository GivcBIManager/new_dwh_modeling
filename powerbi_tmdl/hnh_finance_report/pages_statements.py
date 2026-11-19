"""The statement pages of the Finance report (plan Task 15): trial balance, income statement and balance sheet, each a
monthly page and a hospital comparison page, on fin_frame (frame, filter bar) and fin_blocks (tiles, charts, matrix).

    statement_page(statement, view)   one page: the frame, four tiles, two charts, a header, the matrix
    PAGES                             the six pages in report order (tb, is, bs; monthly then hospitals)

Monthly pages: the left chart shows the selected matrix row's actual, budget and last year by month, the right chart its
variance % against budget and last year (the [FR Chart ...] measures fall back to a default line with no row selected).
Hospital pages: the same tiles over the eight hospitals, the selected row's budget achievement % and growth on
last year as bars by hospital (the income statement's in favourable / unfavourable colours), the hospital matrix.
The matrix filters the charts; nothing else on the content filters anything (a chart's month or bar, the tiles).

Labels here are this repo's (not title-cased). Colours are the canvas's (fin_frame).
"""
from __future__ import annotations

import fin_frame
from fin_blocks import (LEFT_CHART_RECT, MATRIX_RECT, RIGHT_CHART_RECT, monthly_chart, ranked_bars, statement_matrix,
                        text, tile, tile_rects, variance_chart)
from fin_frame import (INK, MONTH_BAND, MUTED, PERIOD_BAND, SERIES_ACTUAL, SERIES_BUDGET, SERIES_LAST_YEAR, _lit,
                       no_container, tight)
from model import Field, Filter, Interaction, Page, Visual, col, meas

import hr_frame  # noqa: E402  (on the path through fin_blocks)

STATEMENTS = ("tb", "is", "bs")
GL, PL, PLR = "GL FS Monthly", "P&L Line", "P&L Report"
ROWS: dict[str, list[Field]] = {
    "tb": [col(GL, "FS Type Name"), col(GL, "FS Element Name"), col(GL, "FS Category Name"), col(GL, "FS Caption Name"),
           col(GL, "Account Name")],
    "is": [col(PL, "Section Name"), col(PL, "PL Line Label"), col(PLR, "FS Caption Name"), col(PLR, "Account Name")],
    "bs": [col(GL, "BS Side"), col(GL, "BS Element"), col(GL, "BS Category"), col(GL, "BS Caption"),
           col(GL, "Account Name")],
}
CELLS = {"tb": meas("FR TB Cell"), "is": meas("FR IS Cell"), "bs": meas("FR BS Cell")}
SHORT = {"tb": "TB", "is": "IS", "bs": "BS"}
# the row levels the matrix opens at (canvas); the others by expand or drill (fin_blocks.statement_matrix)
EXPAND = {"tb": 2, "is": 2, "bs": 3}
SERIES_NAMES = ["Actual", "Budget", "Last year"]
VARIANCE_NAMES = ["vs budget", "vs last year"]
ROW_BAND = meas("FR Row Band")
BS_DIFFERENCE = meas("FR BS Difference")
DIFFERENCE_LABEL = "Difference (cutover / unmapped)"
KPI_CODE = col("Finance KPI", "KPI Code")

IS_NOTE = ("Medicines and consumables: Oasis books cost of goods sold under Consumables. G&A budget excludes marketing "
           "and head office charges.")
HEADERS: dict[tuple[str, str], tuple[str, str]] = {
    ("tb", "monthly"): ("Trial balance",
                        "Debit balances positive, credit balances in brackets. Select an account to drive the charts."),
    ("tb", "hospitals"): ("Trial balance · hospital comparison",
                          "Closing balance at the end of the period. Ach % is closing as a share of budget, Growth is "
                          "against the same date last year. Select an account to drive the charts."),
    ("is", "monthly"): ("Income statement", IS_NOTE),
    ("is", "hospitals"): ("Income statement · hospital comparison", IS_NOTE),
    ("bs", "monthly"): ("Statement of financial position",
                        "Month-end balances for the selected period, then the closing position against last year and "
                        "budget. Select a line to drive the charts."),
    ("bs", "hospitals"): ("Statement of financial position · hospital comparison",
                          "Position at the end of the period. Ach % is actual as a share of budget, Growth is against "
                          "the same date last year. Select a line to drive the charts."),
}
DEFAULT_LINE = {"tb": "trade receivables, net", "is": "net revenue", "bs": "trade receivables, net"}
LEFT_TITLE = {"tb": "Selected line · month-end balance by month", "is": "Selected line by month",
              "bs": "Selected line at month end"}
BAR_TITLES = {"tb": ("Selected line · closing vs budget by hospital, 100% = on budget",
                     "Selected line · growth vs same date last year"),
              "is": ("Selected line · budget achievement by hospital, 100% = on budget",
                     "Selected line · growth vs same period last year"),
              "bs": ("Selected line · actual vs budget by hospital, 100% = on budget",
                     "Selected line · growth vs same date last year")}

# Header and matrix below the tiles and charts (MATRIX_RECT's box): the header, then the matrix. The balance sheet's
# Difference sits at the header's right (under the matrix it ran off the page, screenshot 2026-11-19).
HEADER_H, HEADER_GAP = 48, 8
DIFF_LABEL_W, DIFF_VALUE_W, DIFF_H = 250, 150, 30
_MX, _MY, _MW, _MH = MATRIX_RECT
DIFF_W = DIFF_LABEL_W + DIFF_VALUE_W + 8
HEADER_RECT = (_MX, _MY, _MW, HEADER_H)


def _tile_spec(statement: str) -> list[tuple]:
    """(label, value, line 1, colour 1, line 2, colour 2, value filters, decimals) of the statement's four tiles."""
    def lines(name: str) -> tuple:
        t = f"FR Tile {name}"
        return meas(f"{t} vs Budget"), meas(f"{t} vs Budget Colour"), meas(f"{t} vs LY"), meas(f"{t} vs LY Colour")

    if statement == "tb":
        return [("Period debits", meas("FR Period Debits"), None, None, None, None, None, None),
                ("Period credits", meas("FR Period Credits"), None, None, None, None, None, None),
                ("Out of balance", meas("FR Out of Balance"), meas("FR Tile Out of Balance"),
                 meas("FR Tile Out of Balance Colour"), None, None, None, None),
                ("Total assets", meas("FR Total Assets"), *lines("Total Assets"), None, None)]
    if statement == "is":
        return [("Net revenue", meas("FR Net Revenue"), *lines("Net Revenue"), None, None),
                ("EBITDA", meas("FR EBITDA"), *lines("EBITDA"), None, None),
                ("EBITDA margin", meas("EBITDA Margin %"), *lines("EBITDA Margin"), None, None),
                ("Net profit", meas("FR Net Profit"), *lines("Net Profit"), None, None)]
    if statement == "bs":
        return [("Total assets", meas("FR Total Assets"), *lines("Total Assets"), None, None),
                ("Net working capital", meas("FR Net Working Capital"), *lines("Net Working Capital"), None, None),
                ("Current ratio", meas("FR KPI Value"), *lines("Current Ratio"),
                 [Filter(KPI_CODE, "eq", ["FR_CURRENT_RATIO"])], 2),
                ("Receivable days", meas("FR KPI Value"), *lines("Receivable Days"),
                 [Filter(KPI_CODE, "eq", ["FR_AR_DAYS"])], 0)]
    raise ValueError(f"statement must be one of {', '.join(STATEMENTS)}, got {statement!r}")


def tiles(statement: str) -> list[Visual]:
    out: list[Visual] = []
    for (label, value, l1, c1, l2, c2, flt, dec), rect in zip(_tile_spec(statement), tile_rects(4)):
        out += tile(label, value, l1, c1, l2, c2, rect, value_filters=flt, decimals=dec)
    return out


def charts(statement: str, view: str) -> list[Visual]:
    """Monthly: actual / budget / last year by month (left), variance % by month in two colours (right). Hospitals
    (ruling R15d): budget achievement % and growth on last year by hospital, largest first (income statement:
    favourable / unfavourable colour by bar; achievement takes the vs-budget colour, the same sign)."""
    s = SHORT[statement]
    if view == "monthly":
        default = f" (default: {DEFAULT_LINE[statement]})"
        return [monthly_chart(LEFT_TITLE[statement] + default,
                              [meas(f"FR Chart {s} Actual"), meas(f"FR Chart {s} Budget"),
                               meas(f"FR Chart {s} Last Year")],
                              [SERIES_ACTUAL, SERIES_BUDGET, SERIES_LAST_YEAR], LEFT_CHART_RECT, SERIES_NAMES),
                variance_chart("Selected line · variance % by month",
                               [meas(f"FR Chart {s} vs Budget %"), meas(f"FR Chart {s} vs LY %")], RIGHT_CHART_RECT,
                               [PERIOD_BAND, MONTH_BAND], VARIANCE_NAMES)]
    budget_fav = meas("FR Chart IS vs Budget Colour") if statement == "is" else None
    growth_fav = meas("FR Chart IS vs LY Colour") if statement == "is" else None
    left, right = BAR_TITLES[statement]
    return [ranked_bars(left, meas(f"FR Chart {s} Achievement %"), LEFT_CHART_RECT, budget_fav),
            ranked_bars(right, meas(f"FR Chart {s} vs LY %"), RIGHT_CHART_RECT, growth_fav)]


def header(statement: str, view: str) -> Visual:
    """The matrix's header: the statement's title in bold ink and its note in muted grey under it (the balance sheet
    leaves the right DIFF_W px to the Difference)."""
    title, note = HEADERS[(statement, view)]

    def run(text: str, size: str, colour: str, weight: str) -> dict:
        return {"textRuns": [{"value": text, "textStyle": {"fontFamily": "Segoe UI", "fontSize": size,
                                                          "fontWeight": weight, "color": colour}}]}

    paragraphs = [run(title, "13pt", INK, "bold"), run(note, "10pt", MUTED, "normal")]
    x, y, w, h = HEADER_RECT
    if statement == "bs":
        w -= DIFF_W + 16
    return Visual("textbox", x, y, w, h, props={"general": [{"properties": {"paragraphs": paragraphs}}],
                                                **no_container(), **tight()})


def difference_card() -> list[Visual]:
    """The balance sheet's Difference at the header's right: the label "Difference (cutover / unmapped)" and
    [FR BS Difference] (blank unless the sides and the year's profit differ by 1 SAR or more, e.g. a cutover or
    unmapped accounts). A matrix cannot add a row no GL row carries, so this stands for the canvas's grey Difference
    row. Returns [label text box, value card]."""
    x = _MX + _MW - DIFF_W
    y = _MY + (HEADER_H - DIFF_H) / 2
    look = hr_frame.card_look(13, INK)
    look["labels"][0]["properties"]["horizontalAlignment"] = _lit("right")
    return [text(x, y + 4, DIFF_LABEL_W, DIFF_H - 4, DIFFERENCE_LABEL, 10, MUTED, align="right"),
            Visual("card", x + DIFF_LABEL_W + 8, y, DIFF_VALUE_W, DIFF_H, roles={"Values": [BS_DIFFERENCE]},
                   props={**look, **tight()})]


def matrix(statement: str, view: str) -> Visual:
    y = _MY + HEADER_H + HEADER_GAP
    h = _MY + _MH - y
    if statement == "is":  # R9e: budget figures are blank over several sections, so no grand total row
        return statement_matrix("is", view, ROWS["is"], CELLS["is"], (_MX, y, _MW, h), EXPAND["is"],
                                grand_total=False, row_band=ROW_BAND)
    # the balance sheet's grand total would add Assets + Liabilities & equity + Not mapped (about twice the assets)
    return statement_matrix(statement, view, ROWS[statement], CELLS[statement], (_MX, y, _MW, h), EXPAND[statement],
                            grand_total=statement != "bs")


def interactions(m: Visual, chart_visuals: list[Visual], cards: list[Visual]) -> list[Interaction]:
    """The matrix filters the charts (its default) but not the tiles or the Difference card (a row selection would
    blank the tiles' own line filters); a chart's month or bar filters nothing on the content."""
    out = [Interaction(m, c, "NoFilter") for c in cards]
    for c in chart_visuals:
        out += [Interaction(c, t, "NoFilter") for t in [m, *cards, *chart_visuals] if t is not c]
    return out


def statement_page(statement: str, view: str) -> Page:
    """One statement page: the frame and filter bar, four tiles, two charts, the header, the matrix (balance sheet:
    the Difference at the header's right), on the hospitals page filter."""
    name = fin_frame.PAGE_NAMES[statement][0 if view == "monthly" else 1]
    tile_visuals = tiles(statement)
    chart_visuals = charts(statement, view)
    m = matrix(statement, view)
    content = [*tile_visuals, *chart_visuals, header(statement, view), m]
    if statement == "bs":
        content += difference_card()
    cards = [v for v in content if v.sample == "card"]
    visuals = fin_frame.page_frame(statement, view) + content
    return Page(name, fin_frame.DISPLAY[name], visuals, filters=[fin_frame.hospitals()],
                interactions=interactions(m, chart_visuals, cards)
                + fin_frame.isolate_from_frame([m, *chart_visuals], visuals))


PAGES: list[Page] = [statement_page(st, view) for st in STATEMENTS for view, _label in fin_frame.VIEWS]
