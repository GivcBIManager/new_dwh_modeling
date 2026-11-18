"""The Finance report's shared content blocks (plan Task 14), on fin_frame and the HR report's look helpers.

    tile(...)                 a KPI tile: white panel, caps label, value, two right-aligned lines coloured by measures
    tile_rects(n)             the 2x2 tiles block (n=4) or the KPI pages' row of n cards (n=6)
    monthly_chart / variance_chart / ranked_bars     clustered columns by month, by month, bars by hospital
    statement_matrix(...)     the page's matrix: rows, branch + group + column across, one cell measure

Geometry in page px, below the frame (y 162). Colours are the canvas's (fin_frame).
"""
from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
HR_DIR = HERE.parent / "hnh_hr_report"
if str(HR_DIR) not in sys.path:
    sys.path.append(str(HR_DIR))  # after this folder and the BSC's: both report folders have a pages.py

import fin_frame  # noqa: E402,F401  (puts the BSC generator's modules on the path)
import hr_frame  # noqa: E402
from fin_frame import (BRANCH_NAME, INK, MONTH_BAND, MONTH_SHORT, MUTED, PERIOD_BAND,  # noqa: E402
                       _colour, _lit, _num)
from model import Field, Filter, Visual, col  # noqa: E402

Rect = tuple[float, float, float, float]

TILES_RECT: Rect = (24, 178, 540, 172)
LEFT_CHART_RECT: Rect = (576, 178, 654, 172)
RIGHT_CHART_RECT: Rect = (1242, 178, 654, 172)
MATRIX_RECT: Rect = (24, 362, 1872, 694)
CARDS_RECT: Rect = (24, 178, 1872, 172)
TILE_GAP, CARD_GAP = 8, 12

FC_PAGE, FC_VIEW = col("Finance Column", "Page"), col("Finance Column", "View")
FC_GROUP, FC_COLUMN = col("Finance Column", "Group Name"), col("Finance Column", "Column Name")
CELL_COLOUR = "FR Cell Colour"
WHITE = "#FFFFFF"
LABEL_PT, VALUE_PT, LINE_PT = 11.5, 25, 11
PAD, PAD_Y = 14, 8


def tile_rects(n: int = 4) -> list[Rect]:
    """n = 4: the tiles block as a 2x2 grid (gap 8); n = 6: six cards across the KPI pages' row (gap 12)."""
    if n == 4:
        x, y, w, h = TILES_RECT
        tw, th = (w - TILE_GAP) / 2, (h - TILE_GAP) / 2
        return [(x + c * (tw + TILE_GAP), y + r * (th + TILE_GAP), tw, th) for r in range(2) for c in range(2)]
    x, y, w, h = CARDS_RECT
    cw = (w - CARD_GAP * (n - 1)) / n
    return [(x + i * (cw + CARD_GAP), y, cw, h) for i in range(n)]


def _label_title() -> dict:
    """hr_frame.small_title in the canvas's muted ink (the HR muted grey differs)."""
    out = hr_frame.small_title(LABEL_PT)
    out["title"][0]["properties"]["fontColor"] = _colour(MUTED)
    return out


def _line(field: Field, colour: Field, x: float, y: float, w: float, h: float) -> Visual:
    look = hr_frame.card_look(LINE_PT, hr_frame.measure_colour(colour.name))
    look["labels"][0]["properties"]["horizontalAlignment"] = _lit("right")
    return Visual("card", x, y, w, h, roles={"Values": [field]}, props=look)


def tile(label: str, value: Field, line1: Field, colour1: Field, line2: Field, colour2: Field,
         rect: Rect) -> list[Visual]:
    """A KPI tile (as hr_frame.kpi_tile): a white panel; on the left the value card (25 pt) under the label in muted
    11.5 pt capitals (the card's title); on the right two stacked right-aligned text lines, each in the colour its measure returns."""
    x, y, w, h = rect
    if h < 60 or w < 200:
        raise ValueError(f"tile {label}: {w} x {h} px is too small")
    ix, iw, ih = x + PAD, w - 2 * PAD, h - 2 * PAD_Y
    value_w = round(iw * 0.46)  # label and figure on the left, the two lines stacked on the right
    line_h = ih / 2
    card = Visual("card", ix, y + PAD_Y, value_w, ih, roles={"Values": [value]}, title=label.upper(),
                  props={**hr_frame.card_look(VALUE_PT, INK), **_label_title()})
    lx, lw = ix + value_w, iw - value_w
    return [hr_frame.white_panel(x, y, w, h), card,
            _line(line1, colour1, lx, y + PAD_Y, lw, line_h),
            _line(line2, colour2, lx, y + PAD_Y + line_h, lw, line_h)]


def _series(measures: list[Field], colours: list[str]) -> dict:
    return {"dataPoint": [{"properties": {"fill": _colour(c)}, "selector": {"metadata": m.ref}}
                          for m, c in zip(measures, colours)]}


def _legend(show: bool) -> dict:
    return {"legend": [{"properties": {"show": _lit(show), "position": _lit("Top"), "fontSize": _num(10)}}]}


def monthly_chart(title: str, measures: list[Field], colours: list[str], rect: Rect) -> Visual:
    """A clustered column chart by month (`Date[Month Short]`), one series per measure in `colours`, data labels on,
    legend on when there are several series."""
    if len(measures) != len(colours):
        raise ValueError("monthly_chart: one colour per measure")
    return Visual("columnChart", *rect, roles={"Category": [MONTH_SHORT], "Y": list(measures)}, title=title,
                  sort=MONTH_SHORT, sort_dir="asc",
                  props={**hr_frame.column_look("none"), **_series(measures, colours), **_legend(len(measures) > 1)})


def variance_chart(title: str, measures: list[Field], rect: Rect) -> Visual:
    """Variance by month: clustered columns in the canvas's month blue, labels on (the measures return the P&L sign,
    positive favourable)."""
    ms = list(measures)
    return Visual("columnChart", *rect, roles={"Category": [MONTH_SHORT], "Y": ms}, title=title,
                  sort=MONTH_SHORT, sort_dir="asc",
                  props={**hr_frame.column_look("none"), **_series(ms, [MONTH_BAND] * len(ms)),
                         **_legend(len(ms) > 1)})


def ranked_bars(title: str, measure: Field, rect: Rect, favourable: Field | None) -> Visual:
    """Bars by hospital (`Branch[Branch Name]`) sorted by `measure`, largest first. `favourable`: a measure returning
    a colour per bar (conditional fill by field value); None: one navy colour."""
    fill = hr_frame.measure_colour(favourable.name) if favourable is not None else _colour(PERIOD_BAND)
    return Visual("barChart", *rect, roles={"Category": [BRANCH_NAME], "Y": [measure]}, title=title, sort=measure,
                  sort_dir="desc", props={**hr_frame.bar_look("none"),
                                          "dataPoint": [{"properties": {"fill": fill}}]})


def statement_matrix(page: str, view: str, rows: list[Field], cell: Field, rect: Rect,
                     expand_levels: int) -> Visual:
    """The page's statement matrix: `rows` down, `Finance Column[Group Name]` > `[Column Name]` across (hospital
    views: the branch first), `cell` in the values, filtered to the page's and view's Finance Column rows. Values
    right-aligned, font colour from [FR Cell Colour]; header band navy with white text; row subtotals bold. The
    matrix opens at its first row level (expand=False); opening `expand_levels` levels is not expressible by the
    generator (see the task report), the argument is only checked to be at least 1."""
    if expand_levels < 1:
        raise ValueError(f"expand_levels {expand_levels}: at least 1")
    columns = ([BRANCH_NAME] if view == "hospitals" else []) + [FC_GROUP, FC_COLUMN]
    props = {
        "values": [{"properties": {"fontColor": hr_frame.measure_colour(CELL_COLOUR), "fontSize": _num(11),
                                   "fontFamily": _lit("Segoe UI"), "alignment": _lit("Right")}}],
        "columnHeaders": [{"properties": {"backColor": _colour(PERIOD_BAND), "fontColor": _colour(WHITE),
                                          "fontSize": _num(11), "alignment": _lit("Center"),
                                          "fontFamily": _lit("Segoe UI Semibold")}}],
        "rowHeaders": [{"properties": {"fontSize": _num(11), "fontColor": _colour(INK)}}],
        "subTotals": [{"properties": {"rowSubtotals": _lit(True), "fontBold": _lit(True),
                                      "fontColor": _colour(INK)}}],
        **hr_frame.bsc.white_panel(),
    }
    return Visual("matrix", *rect, roles={"Rows": list(rows), "Columns": columns, "Values": [cell]},
                  filters=[Filter(FC_PAGE, "eq", [page]), Filter(FC_VIEW, "eq", [view])], props=props,
                  expand=False)
