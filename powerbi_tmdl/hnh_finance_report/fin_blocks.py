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
                       _colour, _lit, _num, _text_props, tight)
from model import Field, Filter, Visual, col  # noqa: E402

Rect = tuple[float, float, float, float]

# the top row 196 px tall and the tiles 620 wide (screenshot 2026-11-19: at 172 x 540 the tiles' labels wrapped and
# pushed the figures out of their boxes, and the hospital bar charts scrolled after five bars)
TILES_RECT: Rect = (24, 178, 620, 196)
LEFT_CHART_RECT: Rect = (656, 178, 614, 196)
RIGHT_CHART_RECT: Rect = (1282, 178, 614, 196)
MATRIX_RECT: Rect = (24, 386, 1872, 670)
CARDS_RECT: Rect = (24, 178, 1872, 232)
TILE_GAP, CARD_GAP = 8, 12

FC_PAGE, FC_VIEW = col("Finance Column", "Page"), col("Finance Column", "View")
FC_GROUP, FC_COLUMN = col("Finance Column", "Group Name"), col("Finance Column", "Column Name")
CELL_COLOUR = "FR Cell Colour"
VIEW_VALUES = {"monthly": "monthly", "hospitals": "hospital"}  # page view -> 'Finance Column'[View] (dim_finance_column)
ALL_HOSPITALS = "All hospitals"
WHITE = "#FFFFFF"
LABEL_PT, VALUE_PT, LINE_PT = 10, 22, 10
PAD, PAD_Y, LABEL_H = 14, 8, 22
CHART_TITLE_PT = 11
MILLIONS = "millions"


def tile_rects(n: int = 4) -> list[Rect]:
    """n = 4: the tiles block as a 2x2 grid (gap 8); n = 6: six cards across the KPI pages' row (gap 12)."""
    if n == 4:
        x, y, w, h = TILES_RECT
        tw, th = (w - TILE_GAP) / 2, (h - TILE_GAP) / 2
        return [(x + c * (tw + TILE_GAP), y + r * (th + TILE_GAP), tw, th) for r in range(2) for c in range(2)]
    x, y, w, h = CARDS_RECT
    cw = (w - CARD_GAP * (n - 1)) / n
    return [(x + i * (cw + CARD_GAP), y, cw, h) for i in range(n)]


def text(x: float, y: float, w: float, h: float, value: str, size: float, colour: str, weight: str = "normal",
         align: str | None = None) -> Visual:
    """A one-line text box, padding 0 (fin_frame.tight)."""
    return Visual("textbox", x, y, w, h, props=_text_props(value, f"{size}pt", colour, weight, align))


def _line(field: Field, colour: Field, x: float, y: float, w: float, h: float) -> Visual:
    look = hr_frame.card_look(LINE_PT, hr_frame.measure_colour(colour.name))
    look["labels"][0]["properties"]["horizontalAlignment"] = _lit("right")
    return Visual("card", x, y, w, h, roles={"Values": [field]}, props={**look, **tight()})


def tile(label: str, value: Field, line1: Field | None, colour1: Field | None, line2: Field | None,
         colour2: Field | None, rect: Rect, value_filters: list[Filter] | None = None,
         decimals: int | None = None) -> list[Visual]:
    """A KPI tile (as hr_frame.kpi_tile): a white panel; the label across the top in muted LABEL_PT capitals (one
    line: a text box, so it never wraps into the figure), under it on the left the value card (VALUE_PT), on the right
    two stacked right-aligned text lines, each in the colour its measure returns. A line given as None is left out
    (the trial balance's debits and credits have none; a tile without lines gives the value card the whole width).
    `value_filters`: visual filters of the value card only (a KPI code for [FR KPI Value]); `decimals`: the value's
    decimal places (card_look), None keeps the format's."""
    x, y, w, h = rect
    if h < 84 or w < 240:
        raise ValueError(f"tile {label}: {w} x {h} px is too small")
    if (line1 is None) != (colour1 is None) or (line2 is None) != (colour2 is None):
        raise ValueError(f"tile {label}: a line and its colour go together")
    ix, iw = x + PAD, w - 2 * PAD
    body_y, body_h = y + PAD_Y + LABEL_H, h - 2 * PAD_Y - LABEL_H
    lines = [(f, c) for f, c in ((line1, colour1), (line2, colour2)) if f is not None]
    value_w = round(iw * 0.42) if lines else iw  # the figure on the left, the two lines stacked on the right
    line_h = body_h / 2
    card = Visual("card", ix, body_y, value_w, body_h, roles={"Values": [value]}, filters=list(value_filters or []),
                  props={**hr_frame.card_look(VALUE_PT, INK, decimals=decimals), **tight()})
    lx, lw = ix + value_w, iw - value_w
    return [hr_frame.white_panel(x, y, w, h), text(ix, y + PAD_Y, iw, LABEL_H, label.upper(), LABEL_PT, MUTED), card] \
        + [_line(f, c, lx, body_y + i * line_h, lw, line_h) for i, (f, c) in enumerate(lines)]


def _series(measures: list[Field], colours: list[str]) -> dict:
    return {"dataPoint": [{"properties": {"fill": _colour(c)}, "selector": {"metadata": m.ref}}
                          for m, c in zip(measures, colours)]}


def _legend(show: bool) -> dict:
    return {"legend": [{"properties": {"show": _lit(show), "position": _lit("Top"), "fontSize": _num(10)}}]}


def _chart_title() -> dict:
    """The chart's title in CHART_TITLE_PT (the theme's 14 pt wrapped the longer titles onto two lines)."""
    return {"title": [{"properties": {"fontSize": _num(CHART_TITLE_PT)}}]}


def _names(measures: list[Field], names: list[str] | None) -> dict[Field, str]:
    """The series' names in the legend (each measure's display name in this visual): "Actual", not "FR Chart TB
    Actual" (screenshot 2026-11-19)."""
    if names is None:
        return {}
    if len(names) != len(measures):
        raise ValueError("one name per measure")
    return dict(zip(measures, names))


def monthly_chart(title: str, measures: list[Field], colours: list[str], rect: Rect,
                  names: list[str] | None = None) -> Visual:
    """A clustered column chart by month (`Date[Month Short]`), one series per measure in `colours` and named by
    `names` in the legend; data labels on the first series only (Actual; all three crowded the columns), in SAR
    millions with one decimal; legend on when there are several series."""
    if len(measures) != len(colours):
        raise ValueError("monthly_chart: one colour per measure")
    props = {**hr_frame.column_look(MILLIONS), **_series(measures, colours), **_legend(len(measures) > 1),
             **_chart_title()}
    props["labels"] += [{"properties": {"showSeries": _lit(False)}, "selector": {"metadata": m.ref}}
                        for m in measures[1:]]
    return Visual("columnChart", *rect, roles={"Category": [MONTH_SHORT], "Y": list(measures)}, title=title,
                  sort=MONTH_SHORT, sort_dir="asc", props=props, labels=_names(measures, names))


def variance_chart(title: str, measures: list[Field], rect: Rect, colours: list[str] | None = None,
                   names: list[str] | None = None) -> Visual:
    """Variance by month: clustered columns, one colour per series (`colours`; default the canvas's month blue for
    every series) named by `names` in the legend, labels on (the measures return the P&L sign, positive
    favourable)."""
    ms = list(measures)
    colours = list(colours) if colours is not None else [MONTH_BAND] * len(ms)
    if len(colours) != len(ms):
        raise ValueError("variance_chart: one colour per measure")
    return Visual("columnChart", *rect, roles={"Category": [MONTH_SHORT], "Y": ms}, title=title,
                  sort=MONTH_SHORT, sort_dir="asc", labels=_names(ms, names),
                  props={**hr_frame.column_look("none"), **_series(ms, colours), **_legend(len(ms) > 1),
                         **_chart_title()})


# every data point: a fill by field value applies per bar only with this selector (without it the colour was read
# once for the whole chart: every bar red, screenshot 2026-11-19; hr_frame's conditional fills use the same)
EVERY_POINT = {"data": [{"dataViewWildcard": {"matchingOption": 1}}]}


def ranked_bars(title: str, measure: Field, rect: Rect, favourable: Field | None) -> Visual:
    """Bars by hospital (`Branch[Branch Name]`) sorted by `measure`, largest first, the eight hospitals in the chart's
    height (small category labels, narrow gaps). `favourable`: a measure returning each bar's colour (conditional
    fill by field value, per bar); None: one navy colour."""
    if favourable is not None:
        fill = [{"properties": {"fill": hr_frame.measure_colour(favourable.name)}, "selector": EVERY_POINT}]
    else:
        fill = [{"properties": {"fill": _colour(PERIOD_BAND)}}]
    props = {**hr_frame.bar_look("none"), "dataPoint": fill, **_chart_title()}
    axis = props["categoryAxis"][0]["properties"]
    axis["fontSize"] = _num(9)
    axis["innerPadding"] = _num(15)
    props["labels"][0]["properties"]["fontSize"] = _num(9)
    return Visual("barChart", *rect, roles={"Category": [BRANCH_NAME], "Y": [measure]}, title=title, sort=measure,
                  sort_dir="desc", props=props)


def statement_matrix(page: str, view: str, rows: list[Field], cell: Field, rect: Rect,
                     expand_levels: int, grand_total: bool = True, row_band: Field | None = None,
                     cell_colour: str = CELL_COLOUR, expand: bool = False) -> Visual:
    """The page's statement matrix: `rows` down, `cell` in the values, filtered to the page's and view's Finance Column
    rows ('Finance Column'[View] holds "monthly" / "hospital"). Monthly: `Finance Column[Group Name]` > `[Column Name]`
    across, no column subtotals (a text cell has no total across columns). Hospitals (ruling R15b): `[Column Name]` >
    `Branch[Branch Name]` across, with the Branch level's column subtotal on, labelled "All hospitals" (the eight
    hospitals' figure of each column: Closing / Actual, Ach %, Growth), the Column Name level's (the grand total, a
    blank column: a cell needs a Finance Column kind) off; the view's Group Name is empty, so it is left out. Values
    right-aligned, font colour from [FR Cell Colour]; header band navy with white text; row subtotals bold.
    `grand_total` False hides the row grand total: subtotals per row level, the first level's subtotal (the grand
    total) off, the others on. `row_band`: a measure returning each row's background colour (conditional formatting
    of the values by field value; row headers keep theirs). The matrix opens its first `expand_levels` row levels (the
    others by expand or drill) and shows every column level (pbir._active). `cell_colour`: the measure for the font
    colour (default [FR Cell Colour]); `expand`: True opens every row level (the KPI pages' group > KPI)."""
    if expand_levels < 1:
        raise ValueError(f"expand_levels {expand_levels}: at least 1")
    if view not in VIEW_VALUES:
        raise ValueError(f"view must be one of {', '.join(VIEW_VALUES)}, got {view!r}")
    hospitals = view == "hospitals"
    columns = [FC_COLUMN, BRANCH_NAME] if hospitals else [FC_GROUP, FC_COLUMN]
    values = {"fontColor": hr_frame.measure_colour(cell_colour), "fontSize": _num(11),
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
                  expand=True if expand else min(expand_levels, len(rows)))
