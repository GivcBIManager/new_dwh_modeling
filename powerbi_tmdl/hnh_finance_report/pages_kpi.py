"""The KPI pages of the Finance report (plan Task 16): `kpi_monthly` and `kpi_hospitals`, on fin_frame (frame, filter bar)
and fin_blocks (the matrix).

    kpi_page(view)   one page: the frame, six KPI cards (F1..F6), the header with its three status-count chips, the matrix
    PAGES            the two pages in report order
    CARD_KPIS        [(card code, KPI code)] of the six cards, read from dim_finance_kpi.sql

A card (white panel): code chip, name and `Target` on the first line; the value (28 pt) and a status chip filled by
[FR KPI Status Colour]; two lines (monthly: Budget and Last year, each with its change, coloured by [FR KPI Cell
Colour]; hospitals: the Best and the Lowest hospital); a 12-month sparkline of [FR KPI Value]. Text figures are
[FR KPI Cell] read for one column of 'Finance Column' (a visual filter on its Kind), so every figure is in the KPI's
unit; the card's KPI is a visual filter on 'Finance KPI'[KPI Code]. The sparkline shows the 12 closed months before
the current one whatever Year and Month are picked (ruling R4: NoFilter from both slicers, the Hospital slicer keeps
its effect). The matrix and the sparklines filter nothing else on the content; clicks in them leave the frame's period
text card and slicers alone (fin_frame.isolate_from_frame).

Labels here are this repo's (not title-cased). Colours are the canvas's (fin_frame).
"""
from __future__ import annotations

import re

import fin_frame
from fin_blocks import FC_PAGE, FC_VIEW, MATRIX_RECT, VIEW_VALUES, WHITE, statement_matrix, tile_rects
from fin_frame import (BRANCH_NAME, CHIP_OFF, CHIP_ON, CHIP_WATCH, INK, MUTED, SERIES_ACTUAL, YEAR_PICK,
                       MONTH_SHORT, _colour, _lit, _num, no_container)
from model import Field, Filter, Interaction, Page, Visual, col, meas

import hr_frame  # noqa: E402  (on the path through fin_blocks)

KPI_CODE, KPI_GROUP, KPI_NAME = (col("Finance KPI", c) for c in ("KPI Code", "KPI Group", "KPI Name"))
FC_KIND = col("Finance Column", "Kind")
YEAR_MONTH = col("Date", "Year Month")
MONTH_OFFSET = col("Date", "Month Offset")
TREND_WINDOW = Filter(MONTH_OFFSET, "in", list(range(1, 13)))  # the 12 closed months before the current one
CELL = meas("FR KPI Cell")
CELL_COLOUR, CELL_BACKGROUND = "FR KPI Cell Colour", meas("FR KPI Cell Background")
STATUS, STATUS_COLOUR = meas("FR KPI Status"), "FR KPI Status Colour"
COUNTS = [(meas("FR KPI Count On"), "on target", CHIP_ON, 168), (meas("FR KPI Count Watch"), "watch, within 5%", CHIP_WATCH, 214),
          (meas("FR KPI Count Off"), "off target", CHIP_OFF, 168)]

_DIM = fin_frame.HERE.parents[1] / "hnh_dwh" / "models" / "hnh" / "marts" / "finance" / "dim_finance_kpi.sql"


def _read_kpis() -> list[tuple[str, str, str]]:
    """(card code, KPI code, KPI name) of the KPIs with a card, from the repo's KPI list (a values list)."""
    rows = re.findall(r"\('(FR_[A-Z_]+)', '[^']*', \d+, '([^']*)', '[^']*', -?\d+, \d+, '(F\d)'\)",
                      _DIM.read_text(encoding="utf-8"))
    return sorted((card, code, name) for code, name, card in rows)


_KPIS = _read_kpis()
CARD_KPIS: list[tuple[str, str]] = [(card, code) for card, code, _name in _KPIS]
if [c for c, _ in CARD_KPIS] != [f"F{i}" for i in range(1, 7)]:
    raise ValueError(f"{_DIM.name}: expected the cards F1 to F6, found {[c for c, _ in CARD_KPIS]}")

PAD, GAP = 12, 4
HEADER_H, HEADER_GAP = 40, 8
_MX, _MY, _MW, _MH = MATRIX_RECT
HEADERS = {"monthly": ("Financial ratios vs target",
                       "Flows over the selected period, balances at its end. Status counts follow the hospitals picked."),
           "hospitals": ("Financial ratios vs target · hospital comparison",
                         "Actual is shaded by status against target. vs Bud and vs LY are the change against budget "
                         "and last year. Status counts are for all hospitals.")}


# ---- small blocks --------------------------------------------------------------------------------------------------

def _text(x: float, y: float, w: float, h: float, text: str, size: str, colour: str, weight: str = "normal",
          align: str | None = None, fill: str | None = None) -> Visual:
    """A text box (one paragraph); `fill` a background colour (a chip)."""
    style = {"fontFamily": "Segoe UI", "fontSize": size, "fontWeight": weight, "color": colour}
    para: dict = {"textRuns": [{"value": text, "textStyle": style}]}
    if align:
        para["horizontalTextAlignment"] = align
    props = {"general": [{"properties": {"paragraphs": [para]}}], **no_container()}
    if fill:
        props["background"] = [{"properties": {"show": _lit(True), "color": _colour(fill), "transparency": _num(0)}}]
    return Visual("textbox", x, y, w, h, props=props)


def _figure(x: float, y: float, w: float, h: float, field: Field, size: float, colour: str | dict,
            filters: list[Filter], align: str = "left") -> Visual:
    look = hr_frame.card_look(size, colour)
    look["labels"][0]["properties"]["horizontalAlignment"] = _lit(align)
    return Visual("card", x, y, w, h, roles={"Values": [field]}, filters=filters, props=look)


def _kind_filters(code: str, kind: str, view: str = "monthly") -> list[Filter]:
    """A card's filters for one figure of [FR KPI Cell]: its KPI and one column of the KPI page's monthly view (the
    Kind picks the figure; the cell reads it without the Finance Column filter)."""
    return [Filter(KPI_CODE, "eq", [code]), Filter(FC_PAGE, "eq", ["kpi"]), Filter(FC_VIEW, "eq", [VIEW_VALUES[view]]),
            Filter(FC_KIND, "eq", [kind])]


def _status_chip(x: float, y: float, w: float, h: float, code: str) -> Visual:
    """[FR KPI Status] on a chip filled by [FR KPI Status Colour] (On target / Watch / Off target; grey without a target)."""
    look = hr_frame.card_look(11, INK)
    look["labels"][0]["properties"]["horizontalAlignment"] = _lit("center")
    look["background"] = [{"properties": {"show": _lit(True), "color": hr_frame.measure_colour(STATUS_COLOUR),
                                          "transparency": _num(0)}}]
    return Visual("card", x, y, w, h, roles={"Values": [STATUS]}, filters=[Filter(KPI_CODE, "eq", [code])], props=look)


def _sparkline(x: float, y: float, w: float, h: float, code: str) -> Visual:
    """[FR KPI Value] by month for the card's KPI, the last 12 closed months, one navy line, no axes, labels or legend."""
    off = {"properties": {"show": _lit(False)}}
    props = {"categoryAxis": [{"properties": {"show": _lit(False), "gridlineShow": _lit(False)}}],
             "valueAxis": [{"properties": {"show": _lit(False), "gridlineShow": _lit(False)}}],
             "labels": [off], "legend": [off], "markers": [off],
             "lineStyles": [{"properties": {"strokeWidth": _num(2), "showMarker": _lit(False)}}],
             "dataPoint": [{"properties": {"fill": _colour(SERIES_ACTUAL)}, "selector": {"metadata": meas("FR KPI Value").ref}}],
             **no_container()}
    return Visual("lineChart", x, y, w, h, roles={"Category": [YEAR_MONTH], "Y": [meas("FR KPI Value")]},
                  filters=[Filter(KPI_CODE, "eq", [code]), TREND_WINDOW], sort=YEAR_MONTH, sort_dir="asc", props=props)


def card(view: str, rect: tuple, number: int, code: str, name: str) -> list[Visual]:
    """One KPI card of the row (`number` 1..6)."""
    x, y, w, h = rect
    ix, iw = x + PAD, w - 2 * PAD
    out = [hr_frame.white_panel(x, y, w, h)]
    out.append(_text(ix, y + 8, 34, 22, f"F{number}", "10pt", WHITE, "bold", "center", fill=INK))
    target_w = 106
    out.append(_text(ix + 40, y + 8, iw - 40 - target_w - GAP, 22, name, "12pt", INK, "bold"))
    out.append(_text(ix + iw - target_w, y + 8, 38, 22, "Target", "9pt", MUTED, align="right"))
    out.append(_figure(ix + iw - target_w + 40, y + 8, target_w - 40, 22, CELL, 10, INK, _kind_filters(code, "target"),
                       "right"))
    out.append(_figure(ix, y + 34, 138, 44, CELL, 28, INK, _kind_filters(code, "actual")))
    out.append(_status_chip(ix + 148, y + 46, iw - 148, 24, code))
    for row, (label, kind, delta, best) in enumerate((("Budget", "budget", "vs_bud", "Best"),
                                                       ("Last year", "ly", "vs_ly", "Lowest"))):
        ly = y + 84 + row * 22
        if view == "monthly":
            out.append(_text(ix, ly, 60, 20, label, "10pt", MUTED))
            out.append(_figure(ix + 62, ly, 84, 20, CELL, 11, INK, _kind_filters(code, kind)))
            out.append(_figure(ix + 150, ly, iw - 150, 20, CELL, 11, hr_frame.measure_colour(CELL_COLOUR),
                               _kind_filters(code, delta)))
        else:
            out.append(_text(ix, ly, 46, 20, best, "10pt", MUTED))
            out.append(_figure(ix + 48, ly, iw - 48, 20, meas(f"FR KPI Card {best}"), 11, INK,
                               [Filter(KPI_CODE, "eq", [code])]))
    out.append(_sparkline(ix, y + 130, iw, 34, code))
    return out


def header(view: str) -> list[Visual]:
    """The matrix's header (title and note) with the three status-count chips at its right: a number card over a
    textbox filled in the chip colour, the textbox holding the words."""
    title, note = HEADERS[view]

    def run(text: str, size: str, colour: str, weight: str) -> dict:
        return {"textRuns": [{"value": text, "textStyle": {"fontFamily": "Segoe UI", "fontSize": size,
                                                          "fontWeight": weight, "color": colour}}]}

    chips_w = sum(w for *_x, w in COUNTS) + GAP * 2 * len(COUNTS)
    out = [Visual("textbox", _MX, _MY, _MW - chips_w - 12, HEADER_H,
                  props={"general": [{"properties": {"paragraphs": [run(title, "13pt", INK, "bold"),
                                                                     run(note, "10pt", MUTED, "normal")]}}],
                         **no_container()})]
    x = _MX + _MW - chips_w
    for measure, words, (fill, fg), w in COUNTS:
        out.append(_text(x, _MY + 6, w, 28, words, "10.5pt", fg, "bold", "right", fill=fill))
        out.append(_figure(x + 8, _MY + 6, 36, 28, measure, 12, fg, [], "left"))
        x += w + GAP * 2
    return out


def matrix(view: str) -> Visual:
    y = _MY + HEADER_H + HEADER_GAP
    rect = (_MX, y, _MW, _MY + _MH - y)
    # every row level open (group > KPI); the hospital view shades Actual by status (FR KPI Cell Background), the
    # monthly view its Status column; the group rows have no figure, so no grand total row either
    return statement_matrix("kpi", view, [KPI_GROUP, KPI_NAME], CELL, rect, 1, grand_total=False, row_band=CELL_BACKGROUND,
                            cell_colour=CELL_COLOUR, expand=True)


def interactions(visuals: list[Visual], m: Visual, sparks: list[Visual]) -> list[Interaction]:
    """Matrix and sparklines filter nothing on the content (cards, other sparklines, each other); the Year and Month
    slicers do not reach the sparklines (R4; the Hospital slicer does); clicks in the content leave the frame alone."""
    data = [v for v in visuals if v.y > 170 and v.sample in ("card", "lineChart", "matrix")]
    out = [Interaction(s, t, "NoFilter") for s in [m, *sparks] for t in data if t is not s]
    slicers = [v for v in visuals if v.sample == "slicerTile" and BRANCH_NAME not in v.roles["Values"]]
    assert len(slicers) == 2 and {v.roles["Values"][0] for v in slicers} == {YEAR_PICK, MONTH_SHORT}
    out += [Interaction(s, sp, "NoFilter") for s in slicers for sp in sparks]
    return out + fin_frame.isolate_from_frame([m, *sparks], visuals)


def kpi_page(view: str) -> Page:
    if view not in VIEW_VALUES:
        raise ValueError(f"view must be one of {', '.join(VIEW_VALUES)}, got {view!r}")
    name = fin_frame.PAGE_NAMES["kpi"][0 if view == "monthly" else 1]
    content: list[Visual] = []
    for number, (rect, (_card, code), (_c, _code, kname)) in enumerate(zip(tile_rects(6), CARD_KPIS, _KPIS), 1):
        content += card(view, rect, number, code, kname)
    content += header(view)
    m = matrix(view)
    content.append(m)
    visuals = fin_frame.page_frame("kpi", view) + content
    sparks = [v for v in content if v.sample == "lineChart"]
    return Page(name, fin_frame.DISPLAY[name], visuals, filters=[fin_frame.hospitals()],
                interactions=interactions(visuals, m, sparks))


PAGES: list[Page] = [kpi_page(view) for view, _label in fin_frame.VIEWS]
