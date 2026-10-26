"""The frame on every page and the page geometry (spec "The frame on every page"; one module owns the numbers).

Page 1920 x 1080 = the design's 1280 x 720 x 1.5. Header bar (0, 0, 1920, 84) navy: the logo, the title text box and
the page tabs (right-aligned to x 1890). Filter bar (0, 84, 1920, 78) white with a 1 px rule at y 161: the page's
slicers (given by the page) and the outline buttons "How to use" and "Calculations" on its right. Content below, in
`CONTENT`; the HNH visual draws its own panels there, the native visuals sit in the rects named here.

    frame(current, filter_visuals, filter_bar=True) -> list[Visual]

Also the button primitives every page uses (`button_props`, `label_text`, the styles) and the two frame-only visual
kinds: `panel` (a filled rectangle: a text box without text, coloured by its container background; no Desktop-written
shape visual exists on this server) and `image` (the logo, a RegisteredResources image as the handover's image
visual). Frame visuals set their own container objects: the theme puts white boxes on the data visuals only.
"""
from __future__ import annotations

from pathlib import Path

from model import Visual

HERE = Path(__file__).resolve().parent
LOGO = HERE / "theme" / "hnh_logo_white.png"  # tools/crop_logo.ps1, from branding/<name>-08.png

Rect = tuple[float, float, float, float]  # (x, y, w, h) in page px

# ---- brand tokens ---------------------------------------------------------------------------------------------------

NAVY, BLUE_DARK, BLUE, WHITE = "#0A1E32", "#1478BE", "#13ACE3", "#FFFFFF"
LINE, TAB_TEXT = "#DCE5EF", "#C3CEDB"

# ---- geometry (page px) ---------------------------------------------------------------------------------------------

PAGE_W, PAGE_H = 1920, 1080
HEADER: Rect = (0, 0, 1920, 84)
FILTER_BAR: Rect = (0, 84, 1920, 78)
FILTER_RULE: Rect = (0, 161, 1920, 1)
LOGO_RECT: Rect = (30, 21, 220, 42)
TITLE_RECT: Rect = (270, 9, 370, 66)  # "Balanced Scorecard" 19pt over "Hayat Healthcare" 12pt
HELP_BUTTONS: list[tuple[str, str, Rect]] = [("guide", "How to use", (1590, 96, 140, 54)),
                                             ("definitions", "Calculations", (1745, 96, 145, 54))]
CONTENT: Rect = (30, 186, 1860, 870)  # ends at y 1056: 24 px under the filter bar, 24 px bottom margin

# Overview (inside the visual, origin = CONTENT): top row 348 high; the overall panel 450 wide; four pillar cards.
_GAP = 24
OV_TOP_H = 348
OV_OVERALL: Rect = (30, 186, 450, OV_TOP_H)
_CARD_W = (1860 - 450 - _GAP - 3 * _GAP) / 4  # 328.5
OV_CARDS: list[Rect] = [(30 + 450 + _GAP + i * (_CARD_W + _GAP), 186, _CARD_W, OV_TOP_H) for i in range(4)]
OV_NEEDS_ATTENTION: Rect = (30 + 1860 - 630, 186 + 372, 630, 870 - 372)

# Pillar board: the selected-KPI panel's reserved slots, in page px (panel x 1200 + 24, body y 117 + 432 / 669).
BOARD_CHART: Rect = (1254, 735, 612, 219)  # "By hospital"
BOARD_BUTTON: Rect = (1254, 972, 612, 60)  # drill to KPI detail

# KPI detail: the visual covers the filter bar and the content (it draws the white sub-bar itself).
DETAIL_VISUAL: Rect = (0, 84, 1920, 996)
DETAIL_BACK: Rect = (30, 96, 110, 54)
DETAIL_BY_HOSPITAL: Rect = (564, 600, 639, 456)
DETAIL_MATRIX: Rect = (1227, 600, 663, 372)
DETAIL_OPEN: Rect = (1227, 984, 663, 60)

# The page tabs: (page name, label), right-aligned to TABS_RIGHT, each 42 + 10.5 px per character, 3 px apart.
TABS: list[tuple[str, str]] = [("bsc", "Overview"), ("financial", "Financial"), ("customer", "Customer"),
                               ("internal_process", "Internal Process"), ("learning_growth", "Learning & Growth"),
                               ("owner_view", "Owner view"), ("hospital_comparison", "Hospital comparison")]
TABS_RIGHT, TAB_GAP = 1890, 3
TAB_Y, TAB_H, UNDERLINE_H = 0, 80, 4  # the current tab's underline fills the header's last 4 px
TAB_FONT_SIZE = 14  # pt
CURRENT_TAB_FILL_TRANSPARENCY = 92  # white at 8 %


def tab_width(label: str) -> float:
    return 42 + 10.5 * len(label)


# ---- format-object primitives ---------------------------------------------------------------------------------------

def _lit(value: str | bool) -> dict:
    v = str(value).lower() if isinstance(value, bool) else "'" + value.replace("'", "''") + "'"
    return {"expr": {"Literal": {"Value": v}}}


DEFAULT_STATE, DISABLED_STATE = {"id": "default"}, {"id": "disabled"}


def label_text(text: str) -> dict:
    """The button label object, as Power BI Desktop 2.158's actionButton reads it (BasicShapeVisual bundle): `show`
    from the entry without a selector, the label per button state (default, hover, selected = press, disabled), so in
    the default state's entry (selector id "default"); the other states fall back to it. A label in an entry without
    a selector is never read: the button renders blank."""
    return {"text": [{"properties": {"show": _lit(True)}},
                     {"properties": {"text": _lit(text)}, "selector": DEFAULT_STATE}]}


BUTTON_BLUE, BUTTON_BLUE_DARK = BLUE, BLUE_DARK
BUTTON_DISABLED_FILL, BUTTON_DISABLED_TEXT = "#DCE9F2", "#1478BE"  # Open detail before a cell is selected


def _num(value: float) -> dict:
    return {"expr": {"Literal": {"Value": f"{value}D"}}}


def _colour(hex_colour: str) -> dict:
    return {"solid": {"color": _lit(hex_colour)}}


def button_style(kind: str, colour: str | None = None) -> dict:
    """The one place for button looks. As the handover's buttons write them: `show` in an entry without a selector,
    colours in the default state's entry (selector id "default"). "primary" (Open detail): brand-blue fill, white
    text, no outline; disabled (Open detail until a matrix cell is selected; Desktop's default is a light grey fill
    with grey text): pale blue fill, blue-dark text. "outline" (Back, How to use, Calculations): no fill, blue-dark
    outline and text, or `colour` ones (the pillar pages' drill-through button, in the pillar colour). "tab" (a page
    tab on the navy header): no fill, no outline, `TAB_TEXT` label; "tab_current" (the page's own tab): white label
    on a white 8 % fill."""
    default = DEFAULT_STATE
    if kind == "primary":
        fill = [{"properties": {"show": _lit(True)}},
                {"properties": {"fillColor": _colour(BUTTON_BLUE), "transparency": _num(0)}, "selector": default},
                {"properties": {"fillColor": _colour(BUTTON_DISABLED_FILL), "transparency": _num(0)},
                 "selector": DISABLED_STATE}]
        outline = [{"properties": {"show": _lit(False)}}]
        text = [{"properties": {"fontColor": _colour(WHITE)}, "selector": default},
                {"properties": {"fontColor": _colour(BUTTON_DISABLED_TEXT)}, "selector": DISABLED_STATE}]
    elif kind == "outline":
        line = colour or BUTTON_BLUE_DARK
        fill = [{"properties": {"show": _lit(False)}}]
        outline = [{"properties": {"show": _lit(True)}},
                   {"properties": {"lineColor": _colour(line), "weight": _num(1),
                                   "transparency": _num(0)}, "selector": default}]
        text = [{"properties": {"fontColor": _colour(line)}, "selector": default}]
    elif kind in ("tab", "tab_current"):
        current = kind == "tab_current"
        fill = [{"properties": {"show": _lit(current)}}]
        if current:
            fill.append({"properties": {"fillColor": _colour(WHITE),
                                        "transparency": _num(CURRENT_TAB_FILL_TRANSPARENCY)}, "selector": default})
        outline = [{"properties": {"show": _lit(False)}}]
        text = [{"properties": {"fontColor": _colour(WHITE if current else TAB_TEXT),
                                "fontSize": _num(TAB_FONT_SIZE)}, "selector": default}]
    else:
        raise ValueError(f"button style must be 'primary', 'outline', 'tab' or 'tab_current', got {kind!r}")
    return {"fill": fill, "outline": outline, "text": text}


def _by_selector(*entry_lists: list[dict]) -> list[dict]:
    """Format object entries merged into one entry per selector (first-seen order)."""
    out: list[dict] = []
    for entries in entry_lists:
        for e in entries:
            match = next((x for x in out if x.get("selector") == e.get("selector")), None)
            if match is None:
                out.append({**e, "properties": dict(e["properties"])})
            else:
                match["properties"].update(e["properties"])
    return out


def button_props(link: dict, label: str, kind: str, colour: str | None = None) -> dict:
    """A button's format objects: the action (`visualLink` properties besides show), the label and the style
    (`colour`: an outline button's line and text colour)."""
    style = button_style(kind, colour)
    return {"visualLink": [{"properties": {"show": _lit(True), **link}}],
            "text": _by_selector(label_text(label)["text"], style.pop("text")), **style}


def no_container() -> dict:
    """Container objects of a frame visual: no background, border or visual header (the theme leaves frame kinds
    alone, but the base theme gives every visual a background)."""
    return {"background": [{"properties": {"show": _lit(False)}}],
            "border": [{"properties": {"show": _lit(False)}}],
            "visualHeader": [{"properties": {"show": _lit(False)}}]}


def _navigate(page_name: str) -> dict:
    return {"type": _lit("PageNavigation"), "navigationSection": _lit(page_name)}


# ---- the frame visuals ----------------------------------------------------------------------------------------------

def panel(x: float, y: float, w: float, h: float, colour: str, radius: int = 0) -> Visual:
    """A filled rectangle: a text box without paragraphs whose container background is `colour`. With a radius the
    border is on in the same colour (Power BI rounds a container's corners through its border), so no outline shows."""
    border = ({"show": _lit(True), "color": _colour(colour), "radius": _num(radius), "width": _num(1)} if radius
              else {"show": _lit(False)})
    return Visual("panel", x, y, w, h, props={
        "background": [{"properties": {"show": _lit(True), "color": _colour(colour), "transparency": _num(0)}}],
        "border": [{"properties": border}],
        "visualHeader": [{"properties": {"show": _lit(False)}}]})


def image(x: float, y: float, w: float, h: float) -> Visual:
    """The logo (`LOGO`, registered by pbir.py as a RegisteredResources image), as the handover's image visual writes
    `image.sourceFile.image`. Scaling 'Normal' keeps the aspect ratio inside the box (Desktop's report theme schema
    titles 'Normal' "Fit"; the value 'Fit' is its "Stretch")."""
    source = {"name": _lit(LOGO.name),
              "url": {"expr": {"ResourcePackageItem": {"PackageName": "RegisteredResources", "PackageType": 1,
                                                       "ItemName": LOGO.name}}},
              "scaling": _lit("Normal")}
    return Visual("image", x, y, w, h, props={"image": [{"properties": {"sourceFile": {"image": source}}}],
                                              **no_container()})


def tab_button(page_name: str, label: str, x: float, w: float, current: bool) -> list[Visual]:
    """A page tab: a page-navigation button on the header, plus, for the page's own tab, a 4 px blue underline
    under it (a panel)."""
    props = {**button_props(_navigate(page_name), label, "tab_current" if current else "tab"), **no_container()}
    out = [Visual("buttonNavigate", x, TAB_Y, w, TAB_H, props=props)]
    if current:
        out.append(panel(x, TAB_Y + TAB_H, w, UNDERLINE_H, BLUE))
    return out


def title_box() -> Visual:
    """"Balanced Scorecard" (Segoe UI Semibold 19pt, white) over "Hayat Healthcare" (12pt, tab grey)."""
    runs = [("Balanced Scorecard", {"fontFamily": "Segoe UI Semibold", "fontSize": "19pt", "color": WHITE}),
            ("Hayat Healthcare", {"fontFamily": "Segoe UI", "fontSize": "12pt", "color": TAB_TEXT})]
    paragraphs = [{"textRuns": [{"value": value, "textStyle": style}]} for value, style in runs]
    return Visual("textbox", *TITLE_RECT, props={"general": [{"properties": {"paragraphs": paragraphs}}],
                                                 **no_container()})


def tabs(current: str | None) -> list[Visual]:
    names = [name for name, _label in TABS]
    if current is not None and current not in names:
        raise ValueError(f"current page {current!r} has no tab (tabs: {', '.join(names)}); pass None")
    x = TABS_RIGHT - sum(tab_width(label) for _name, label in TABS) - TAB_GAP * (len(TABS) - 1)
    out: list[Visual] = []
    for name, label in TABS:
        out += tab_button(name, label, x, tab_width(label), name == current)
        x += tab_width(label) + TAB_GAP
    return out


def help_buttons() -> list[Visual]:
    """"How to use" and "Calculations": outline buttons on the right of the white filter bar."""
    return [Visual("buttonNavigate", *r, props={**button_props(_navigate(name), label, "outline"), **no_container()})
            for name, label, r in HELP_BUTTONS]


def frame(current: str | None, filter_visuals: list[Visual], filter_bar: bool = True) -> list[Visual]:
    """The frame, bottom to top: the header bar, the logo, the title, the tabs (`current`: the page's own tab, one of
    `TABS`' names, or None for a page without one), the filter bar and its rule (left out when `filter_bar` is False:
    KPI detail's visual draws that band itself), `filter_visuals`, then How to use and Calculations. KPI detail passes
    its HNH visual and Back as `filter_visuals`, so How to use and Calculations are drawn over the visual's sub-bar."""
    out = [panel(*HEADER, NAVY), image(*LOGO_RECT), title_box(), *tabs(current)]
    if filter_bar:
        out += [panel(*FILTER_BAR, WHITE), panel(*FILTER_RULE, LINE)]
    return out + list(filter_visuals) + help_buttons()
