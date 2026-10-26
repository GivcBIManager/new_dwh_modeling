"""The page frame (frame.py): geometry, tabs, header, filter bar, panel and image visuals."""
import re
from pathlib import Path

import pytest

import frame
from frame import (BOARD_BUTTON, BOARD_CHART, CONTENT, DETAIL_BACK, DETAIL_BY_HOSPITAL, DETAIL_MATRIX, DETAIL_OPEN,
                   DETAIL_VISUAL, OV_CARDS, TABS, image, panel, tab_button)

TITLE_BOX = (270, 9, 370, 66)  # fits "Balanced Scorecard" (19pt) over "Hayat Healthcare" (12pt)
SCORECARD = ["bsc", "financial", "customer", "internal_process", "learning_growth", "owner_view",
             "hospital_comparison"]


def lit(prop):
    return prop["expr"]["Literal"]["Value"]


def rect(v):
    return (v.x, v.y, v.w, v.h)


def tabs_of(visuals):
    """The page-navigation buttons whose target is a scorecard page (the tabs), in order."""
    return [v for v in visuals if v.sample == "buttonNavigate"
            and lit(v.props["visualLink"][0]["properties"]["navigationSection"]).strip("'") in SCORECARD]


def underlines(visuals):
    return [v for v in visuals if v.sample == "panel"
            and lit(v.props["background"][0]["properties"]["color"]["solid"]["color"]) == "'#13ACE3'"]


def is_current(tab):
    fill = [e for e in tab.props["fill"] if "selector" not in e]
    return lit(fill[0]["properties"]["show"]) == "true"


# ---- geometry ------------------------------------------------------------------------------------------------------

def test_geometry_constants():
    assert CONTENT == (30, 186, 1860, 870)
    assert len(OV_CARDS) == 4
    assert OV_CARDS[0] == (504, 186, 328.5, 348)
    assert OV_CARDS[3][0] == 504 + 3 * 352.5
    assert all(c[1:] == (186, 328.5, 348) for c in OV_CARDS)
    assert BOARD_CHART == (1254, 735, 612, 219)
    assert BOARD_BUTTON == (1254, 972, 612, 60)
    assert DETAIL_VISUAL == (0, 84, 1920, 996)
    assert DETAIL_BACK == (30, 96, 110, 54)
    assert DETAIL_BY_HOSPITAL == (564, 600, 639, 456)
    assert DETAIL_MATRIX == (1227, 600, 663, 372)
    assert DETAIL_OPEN == (1227, 984, 663, 60)


VISUAL_LESS = Path(__file__).resolve().parents[2] / "hnh_bsc_visual" / "style" / "visual.less"


def _rule(css: str, selector: str) -> str:
    """The declarations of the rule whose selector is exactly `selector` (one line per rule in visual.less)."""
    m = re.search(r"(?m)^" + re.escape(selector) + r"\{([^}]*)\}", css)
    assert m, f"no rule {selector} in visual.less"
    return m.group(1)


def _px(decls: str, prop: str) -> list[float]:
    """The px numbers of `prop` in a rule's declarations, in order."""
    m = re.search(r"(?:^|;)" + re.escape(prop) + r":([^;]*)", decls)
    assert m, f"no {prop} in {decls}"
    return [float(x) for x in re.findall(r"(-?\d+(?:\.\d+)?)px", m.group(1))]


def test_visual_css_contract():
    """The native visuals over the HNH visual sit where its CSS leaves room: frame.py's rects follow from the
    numbers in visual.less (the visual's origin is CONTENT's corner, or DETAIL_VISUAL's on KPI detail)."""
    css = VISUAL_LESS.read_text(encoding="utf-8")
    x0, y0, width, height = CONTENT

    # overview: 450 px overall panel, then four equal pillar cards, rows of 348 px, gap 24
    ov = _rule(css, ".ov")
    assert _px(ov, "grid-template-columns") == [450]
    assert _px(ov, "grid-template-rows") == [348]
    (gap,) = _px(ov, "gap")
    assert gap == 24
    overall, top = 450, 348
    card_w = (width - overall - 4 * gap) / 4
    assert OV_CARDS == [(x0 + overall + gap + i * (card_w + gap), y0, card_w, top) for i in range(4)]

    # board: strip 96, gap 21; panel 660 wide after a 24 gap; in it 432 of content, the 219 chart slot and the 60
    # button slot, each inset 24 at the sides, the button 18 under the chart
    bd = _rule(css, ".bd")
    (strip,) = _px(bd, "grid-template-rows")
    (bd_gap,) = _px(bd, "gap")
    assert (strip, bd_gap) == (96, 21)
    body = _rule(css, ".bd-body")
    (panel_w,) = _px(body, "grid-template-columns")
    (body_gap,) = _px(body, "gap")
    assert (panel_w, body_gap) == (660, 24)
    (main_h,) = _px(_rule(css, ".bd-panel-main"), "height")
    chart = _rule(css, ".bd-slot-chart")
    button = _rule(css, ".bd-slot-button")
    (chart_h,) = _px(chart, "height")
    (button_h,) = _px(button, "height")
    assert (main_h, chart_h, button_h) == (432, 219, 60)
    chart_m = _px(chart, "margin")  # 0 24px
    button_m = _px(button, "margin")  # 18px 24px 0
    assert chart_m == [24] and button_m == [18, 24]
    side, button_top = chart_m[0], button_m[0]
    panel_x = x0 + width - panel_w
    chart_y = y0 + strip + bd_gap + main_h
    assert BOARD_CHART == (panel_x + side, chart_y, panel_w - 2 * side, chart_h)
    assert BOARD_BUTTON == (panel_x + side, chart_y + chart_h + button_top, panel_w - 2 * side, button_h)
    assert BOARD_BUTTON[0] - x0 == width - panel_w + side  # the table takes the rest: 1176 + 24 gap
    assert width - panel_w - body_gap == 1176

    # KPI detail: the visual's sub-bar 78; body padded 24 / 30 with a 510 profile and a 390 trend row, gap 24. The
    # native lower row starts under the trend panel, at its left edge, and ends at the body's right and bottom padding
    vx, vy, vw, vh = DETAIL_VISUAL
    (sub_h,) = _px(_rule(css, ".dt-sub"), "height")
    dt = _rule(css, ".dt-body")
    (profile_w,) = _px(dt, "grid-template-columns")
    (trend_h,) = _px(dt, "grid-template-rows")
    (dt_gap,) = _px(dt, "gap")
    pad_y, pad_x = _px(dt, "padding")
    assert (sub_h, profile_w, trend_h, dt_gap, pad_y, pad_x) == (78, 510, 390, 24, 24, 30)
    trend_x = vx + pad_x + profile_w + dt_gap
    lower_y = vy + sub_h + pad_y + trend_h + dt_gap
    right, bottom = vx + vw - pad_x, vy + vh - pad_y
    assert trend_x == 564 and lower_y == 600
    bh, mx, op = DETAIL_BY_HOSPITAL, DETAIL_MATRIX, DETAIL_OPEN
    assert (bh[0], bh[1]) == (trend_x, lower_y) and bh[1] + bh[3] == bottom
    assert mx[0] == bh[0] + bh[2] + dt_gap and mx[1] == lower_y and mx[0] + mx[2] == right
    assert (op[0], op[2]) == (mx[0], mx[2]) and op[1] > mx[1] + mx[3] and op[1] + op[3] <= bottom
    # Back sits in the sub-bar, left of its text (padding-left 150)
    sub_pad = _px(_rule(css, ".dt-sub"), "padding")
    assert DETAIL_BACK[1] >= vy and DETAIL_BACK[1] + DETAIL_BACK[3] <= vy + sub_h
    assert DETAIL_BACK[0] + DETAIL_BACK[2] <= vx + sub_pad[-1]


def test_tab_list():
    assert TABS == [("bsc", "Overview"), ("financial", "Financial"), ("customer", "Customer"),
                    ("internal_process", "Internal Process"), ("learning_growth", "Learning & Growth"),
                    ("owner_view", "Owner view"), ("hospital_comparison", "Hospital comparison")]


def test_tabs_fit_right_of_the_title_and_end_at_1890():
    tabs = tabs_of(frame.frame("bsc", []))
    assert [lit(t.props["visualLink"][0]["properties"]["navigationSection"]).strip("'") for t in tabs] == SCORECARD
    for t, (_name, label) in zip(tabs, TABS):
        assert t.w == 42 + 10.5 * len(label)
        (text,) = [e for e in t.props["text"] if e.get("selector") == {"id": "default"}]
        assert lit(text["properties"]["text"]) == f"'{label}'"
    assert tabs[0].x >= 664 and tabs[0].x >= TITLE_BOX[0] + TITLE_BOX[2]
    assert tabs[-1].x + tabs[-1].w == 1890
    for a, b in zip(tabs, tabs[1:]):
        assert b.x == pytest.approx(a.x + a.w + 3)
    assert all(t.y + t.h <= 84 for t in tabs)


@pytest.mark.parametrize("current", SCORECARD)
def test_exactly_one_current_tab_on_a_scorecard_page(current):
    vs = frame.frame(current, [])
    tabs = tabs_of(vs)
    assert [is_current(t) for t in tabs] == [name == current for name in SCORECARD]
    (cur,) = [t for t in tabs if is_current(t)]
    (line,) = underlines(vs)
    assert (line.x, line.w, line.h) == (cur.x, cur.w, 4)
    assert line.y == cur.y + cur.h and line.y + line.h <= 84
    label = [e for e in cur.props["text"] if e.get("selector") == {"id": "default"}][0]["properties"]
    assert lit(label["fontColor"]["solid"]["color"]) == "'#FFFFFF'"
    fill = [e for e in cur.props["fill"] if e.get("selector") == {"id": "default"}][0]["properties"]
    assert lit(fill["fillColor"]["solid"]["color"]) == "'#FFFFFF'" and lit(fill["transparency"]) == "92D"


def test_no_current_tab_when_current_is_none():
    vs = frame.frame(None, [])
    tabs = tabs_of(vs)
    assert len(tabs) == 7 and not any(is_current(t) for t in tabs)
    assert underlines(vs) == []
    for t in tabs:
        label = [e for e in t.props["text"] if e.get("selector") == {"id": "default"}][0]["properties"]
        assert lit(label["fontColor"]["solid"]["color"]) == "'#C3CEDB'"


def test_unknown_current_page_raises():
    with pytest.raises(ValueError, match="nope"):
        frame.frame("nope", [])


def test_tab_button_alone():
    assert len(tab_button("bsc", "Overview", 100, 126, False)) == 1
    button, line = tab_button("bsc", "Overview", 100, 126, True)
    assert button.sample == "buttonNavigate" and line.sample == "panel"
    assert lit(button.props["visualLink"][0]["properties"]["type"]) == "'PageNavigation'"


# ---- the frame -----------------------------------------------------------------------------------------------------

def _texts(v):
    return [run for p in v.props["general"][0]["properties"]["paragraphs"] for run in p["textRuns"]]


def test_frame_header_logo_title_filter_bar_and_help_buttons():
    slicer = frame.panel(40, 96, 300, 54, "#FFFFFF")  # any visual stands in for the filter-bar slicers
    vs = frame.frame("financial", [slicer])
    header = vs[0]
    assert header.sample == "panel" and rect(header) == (0, 0, 1920, 84)
    assert lit(header.props["background"][0]["properties"]["color"]["solid"]["color"]) == "'#0A1E32'"
    (logo,) = [v for v in vs if v.sample == "image"]
    assert rect(logo) == (30, 21, 220, 42)
    (title,) = [v for v in vs if v.sample == "textbox"]
    assert rect(title) == TITLE_BOX
    big, small = _texts(title)
    assert big == {"value": "Balanced Scorecard", "textStyle": {
        "fontFamily": "Segoe UI Semibold", "fontSize": "19pt", "color": "#FFFFFF"}}
    assert small["value"] == "Hayat Healthcare"
    assert small["textStyle"]["fontSize"] == "12pt" and small["textStyle"]["color"] == "#C3CEDB"
    # frame visuals set their own container: no white theme box behind the title on the navy bar
    assert lit(title.props["background"][0]["properties"]["show"]) == "false"
    bars = [v for v in vs if v.sample == "panel" and rect(v) == (0, 84, 1920, 78)]
    rules = [v for v in vs if v.sample == "panel" and rect(v) == (0, 161, 1920, 1)]
    assert len(bars) == 1 and len(rules) == 1
    assert lit(bars[0].props["background"][0]["properties"]["color"]["solid"]["color"]) == "'#FFFFFF'"
    assert lit(rules[0].props["background"][0]["properties"]["color"]["solid"]["color"]) == "'#DCE5EF'"
    assert vs.index(bars[0]) < vs.index(slicer)  # the bar is drawn under the slicers
    helps = [v for v in vs if v.sample == "buttonNavigate" and v not in tabs_of(vs)]
    assert [(rect(v), lit(v.props["visualLink"][0]["properties"]["navigationSection"])) for v in helps] == [
        ((1590, 96, 140, 54), "'guide'"), ((1745, 96, 145, 54), "'definitions'")]
    for v in helps:
        outline = [e for e in v.props["outline"] if e.get("selector") == {"id": "default"}][0]["properties"]
        assert lit(outline["lineColor"]["solid"]["color"]) == "'#1478BE'"
        assert lit(v.props["fill"][0]["properties"]["show"]) == "false"


def test_frame_without_the_filter_bar():
    slicer = frame.panel(40, 96, 300, 54, "#FFFFFF")
    vs = frame.frame(None, [slicer], filter_bar=False)
    assert not [v for v in vs if v.sample == "panel" and v.y in (84, 161) and v.w == 1920]
    assert slicer in vs
    assert len([v for v in vs if v.sample == "buttonNavigate"]) == 9  # 7 tabs + How to use + Calculations


# ---- panel and image -----------------------------------------------------------------------------------------------

def test_panel():
    v = panel(1, 2, 3, 4, "#0A1E32")
    assert v.sample == "panel" and rect(v) == (1, 2, 3, 4)
    bg = v.props["background"][0]["properties"]
    assert (lit(bg["show"]), lit(bg["color"]["solid"]["color"]), lit(bg["transparency"])) == \
        ("true", "'#0A1E32'", "0D")
    assert lit(v.props["border"][0]["properties"]["show"]) == "false"
    assert lit(v.props["visualHeader"][0]["properties"]["show"]) == "false"
    assert "general" not in v.props  # no paragraphs
    rounded = panel(1, 2, 3, 4, "#FFFFFF", radius=12).props["border"][0]["properties"]
    assert lit(rounded["show"]) == "true" and lit(rounded["radius"]) == "12D"
    assert lit(rounded["color"]["solid"]["color"]) == "'#FFFFFF'"  # same colour: rounds the corners, no outline


def test_image_is_the_logo():
    v = image(30, 21, 220, 42)
    assert v.sample == "image" and rect(v) == (30, 21, 220, 42)
    src = v.props["image"][0]["properties"]["sourceFile"]["image"]
    assert lit(src["name"]) == "'hnh_logo_white.png'"
    assert src["url"] == {"expr": {"ResourcePackageItem": {
        "PackageName": "RegisteredResources", "PackageType": 1, "ItemName": "hnh_logo_white.png"}}}
    # 'Normal' keeps the aspect ratio (Desktop's theme schema titles it "Fit"; 'Fit' stretches)
    assert lit(src["scaling"]) == "'Normal'"
    assert lit(v.props["background"][0]["properties"]["show"]) == "false"


def test_logo_png_is_committed_and_600_wide():
    import struct
    data = (frame.LOGO).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    width, height = struct.unpack(">II", data[16:24])
    assert width == 600 and 0 < height < 600


def test_outline_button_takes_a_colour():
    """The pillar pages' drill-through button is outlined in the pillar colour; the default is blue-dark."""
    style = frame.button_style("outline", "#6E8196")
    (line,) = [e for e in style["outline"] if e.get("selector") == {"id": "default"}]
    (text,) = [e for e in style["text"] if e.get("selector") == {"id": "default"}]
    assert lit(line["properties"]["lineColor"]["solid"]["color"]) == "'#6E8196'"
    assert lit(text["properties"]["fontColor"]["solid"]["color"]) == "'#6E8196'"
    (line,) = [e for e in frame.button_style("outline")["outline"] if e.get("selector") == {"id": "default"}]
    assert lit(line["properties"]["lineColor"]["solid"]["color"]) == "'#1478BE'"
    props = frame.button_props({"type": frame._lit("Back")}, "Back", "outline", "#002E5A")
    (text,) = [e for e in props["text"] if e.get("selector") == {"id": "default"}]
    assert lit(text["properties"]["fontColor"]["solid"]["color"]) == "'#002E5A'"
