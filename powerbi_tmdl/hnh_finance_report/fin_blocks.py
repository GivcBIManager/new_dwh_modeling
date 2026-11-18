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
VIEW_VALUES = {"monthly": "monthly", "hospitals": "hospital"}  # page view -> 'Finance Column'[View] (dim_finance_column)
ALL_HOSPITALS = "All hospitals"
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


def tile(label: str, value: Field, line1: Field | None, colour1: Field | None, line2: Field | None,
         colour2: Field | None, rect: Rect, value_filters: list[Filter] | None = None,
         decimals: int | None = None) -> list[Visual]:
    """A KPI tile (as hr_frame.kpi_tile): a white panel; on the left the value card (25 pt) under the label in muted
    11.5 pt capitals (the card's title); on the right two stacked right-aligned text lines, each in the colour its
    measure returns. A line given as None is left out (the trial balance's debits and credits have none; a tile
    without lines gives the value card the whole width). `value_filters`: visual filters of the value card only (a
    KPI code for [FR KPI Value]); `decimals`: the value's decimal places (card_look), None keeps the format's."""
    x, y, w, h = rect
    if h < 60 or w < 200:
        raise ValueError(f"tile {label}: {w} x {h} px is too small")
    if (line1 is None) != (colour1 is None) or (line2 is None) != (colour2 is None):
        raise ValueError(f"tile {label}: a line and its colour go together")
    ix, iw, ih = x + PAD, w - 2 * PAD, h - 2 * PAD_Y
    lines = [(f, c) for f, c in ((line1, colour1), (line2, colour2)) if f is not None]
    value_w = round(iw * 0.46) if lines else iw  # label and figure on the left, the two lines stacked on the right
    line_h = ih / 2
    card = Visual("card", ix, y + PAD_Y, value_w, ih, roles={"Values": [value]}, title=label.upper(),
                  filters=list(value_filters or []),
                  props={**hr_frame.card_look(VALUE_PT, INK, decimals=decimals), **_label_title()})
    lx, lw = ix + value_w, iw - value_w
    return [hr_frame.white_panel(x, y, w, h), card] + [_line(f, c, lx, y + PAD_Y + i * line_h, lw, line_h)
                                                       for i, (f, c) in enumerate(lines)]


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


def variance_chart(title: str, measures: list[Field], rect: Rect, colours: list[str] | None = None) -> Visual:
    """Variance by month: clustered columns, one colour per series (`colours`; default the canvas's month blue for
    every series), labels on (the measures return the P&L sign, positive favourable)."""
    ms = list(measures)
    colours = list(colours) if colours is not None else [MONTH_BAND] * len(ms)
    if len(colours) != len(ms):
        raise ValueError("variance_chart: one colour per measure")
    return Visual("columnChart", *rect, roles={"Category": [MONTH_SHORT], "Y": ms}, title=title,
                  sort=MONTH_SHORT, sort_dir="asc",
                  props={**hr_frame.column_look("none"), **_series(ms, colours), **_legend(len(ms) > 1)})


def ranked_bars(title: str, measure: Field, rect: Rect, favourable: Field | None) -> Visual:
    """Bars by hospital (`Branch[Branch Name]`) sorted by `measure`, largest first. `favourable`: a measure returning
    a colour per bar (conditional fill by field value); None: one navy colour."""
    fill = hr_frame.measure_colour(favourable.name) if favourable is not None else _colour(PERIOD_BAND)
    return Visual("barChart", *rect, roles={"Category": [BRANCH_NAME], "Y": [measure]}, title=title, sort=measure,
                  sort_dir="desc", props={**hr_frame.bar_look("none"),
                                          "dataPoint": [{"properties": {"fill": fill}}]})


def statement_matrix(page: str, view: str, rows: list[Field], cell: Field, rect: Rect,
                     expand_levels: int, grand_total: bool = True, row_band: Field | None = None) -> Visual:
    """The page's statement matrix: `rows` down, `cell` in the values, filtered to the page's and view's Finance Column
    rows ('Finance Column'[View] holds "monthly" / "hospital"). Monthly: `Finance Column[Group Name]` > `[Column Name]`
    across, no column subtotals (a text cell has no total across columns). Hospitals (ruling R15b): `[Column Name]` >
    `Branch[Branch Name]` across, with the Branch level's column subtotal on, labelled "All hospitals" (the eight
    hospitals' figure of each column: Closing / Actual, Ach %, Growth), the Column Name level's (the grand total, a
    blank column: a cell needs a Finance Column kind) off; the view's Group Name is empty, so it is left out. Values
    right-aligned, font colour from [FR Cell Colour]; header band navy with white text; row subtotals bold.
    `grand_total` False hides the row grand total: subtotals per row level, the first level's subtotal (the grand
    total) off, the others on. `row_band`: a measure returning each row's background colour (conditional formatting
    of the values by field value; row headers keep theirs). The matrix opens at its first row level (expand=False);
    opening `expand_levels` levels is not expressible by the generator (see the task report), the argument is only
    checked to be at least 1."""
    if expand_levels < 1:
        raise ValueError(f"expand_levels {expand_levels}: at least 1")
    if view not in VIEW_VALUES:
        raise ValueError(f"view must be one of {', '.join(VIEW_VALUES)}, got {view!r}")
    hospitals = view == "hospitals"
    columns = [FC_COLUMN, BRANCH_NAME] if hospitals else [FC_GROUP, FC_COLUMN]
    values = {"fontColor": hr_frame.measure_colour(CELL_COLOUR), "fontSize": _num(11),
              "fontFamily": _lit("Segoe UI"), "alignment": _lit("Right")}
    if row_band is not None:
        values["backColor"] = hr_frame.measure_colour(row_band.name)
    subtotals = [{"properties": {"rowSubtotals": _lit(True), "columnSubtotals": _lit(hospitals), "bold": _lit(True),
                                 "fontColor": _colour(INK)}}]
    if hospitals:
        subtotals[0]["properties"]["perColumnLevel"] = _lit(True)
        subtotals += [{"properties": {"levelSubtotalEnabled": _lit(False)}, "selector": {"metadata": FC_COLUMN.ref}},
                      {"properties": {"levelSubtotalEnabled": _lit(True), "levelSubtotalLabel": _lit(ALL_HOSPITALS)},
                       "selector": {"metadata": BRANCH_NAME.ref}}]
    if not grand_total:
        subtotals[0]["properties"]["perRowLevel"] = _lit(True)
        subtotals.append({"properties": {"levelSubtotalEnabled": _lit(False)}, "selector": {"metadata": rows[0].ref}})
    props = {
        "values": [{"properties": values}],
        "columnHeaders": [{"properties": {"backColor": _colour(PERIOD_BAND), "fontColor": _colour(WHITE),
                                          "fontSize": _num(11), "alignment": _lit("Center"),
                                          "fontFamily": _lit("Segoe UI Semibold")}}],
        "rowHeaders": [{"properties": {"fontSize": _num(11), "fontColor": _colour(INK)}}],
        "subTotals": subtotals,
        **hr_frame.bsc.white_panel(),
    }
    return Visual("matrix", *rect, roles={"Rows": list(rows), "Columns": columns, "Values": [cell]},
                  filters=[Filter(FC_PAGE, "eq", [page]), Filter(FC_VIEW, "eq", [VIEW_VALUES[view]])], props=props,
                  expand=False)
