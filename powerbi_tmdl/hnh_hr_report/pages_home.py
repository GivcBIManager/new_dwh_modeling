"""Home, the landing page (spec "Pages" 1; the approved mockup, inside the BSC frame's content box):

    the HR Story Home sentence      full width
    8 KPI tiles                     2 rows x 4: the seed's is_home_tile codes in display_order
    6 area cards                    one figure each; a click opens the detail page
    the data quality strip          [HR DQ Headline] and Open data quality

The filter bar holds Hospital and Month only (R13: the tiles show HR KPI Actual and Status). Every data visual but the
data quality strip is filtered to hospitals (final review I1); the page has no page filter, so the strip still counts
Head Office (100) records for those who may see them.
"""
from __future__ import annotations

from frame import CONTENT, NAVY, _colour, _lit
from hr_frame import (DETAIL_PAGES, bsc, card_look, filters, home_tile_codes, hospitals, kpi_tile, nav_button,
                      page_frame, white_panel)
from model import Page, Visual, meas

GAP = 24
X0, Y0, W0, H0 = CONTENT  # 30, 186, 1860, 870: ends at y 1056
STORY_H, TILE_H, AREA_H, DQ_H = 120, 236, 100, 82  # with four gaps: 870
STORY = (X0, Y0, W0, STORY_H)
TILES_Y = Y0 + STORY_H + GAP  # 330; the second row at 590
TILE_W = (W0 - 3 * GAP) / 4  # 447
AREAS_Y = TILES_Y + 2 * (TILE_H + GAP)  # 850
AREA_W = (W0 - 5 * GAP) / 6  # 290
DQ_Y = AREAS_Y + AREA_H + GAP  # 974
DQ_BUTTON_W, DQ_BUTTON_H = 230, 48

# Each detail page's figure on its area card: (measure, the figure's label). Repo labels, not title-cased. Pay
# figures are the pay-aware text measures (ruling R22): "Requires pay access" without pay access, never "(Blank)";
# [HR Payroll Cost Text] carries its unit ("SAR 43.6M").
AREA_FIGURES = {
    "headcount": ("Headcount", "Headcount"),
    "movements": ("Hires", "Hires"),
    "payroll": ("HR Payroll Cost Text", "Payroll cost"),
    "absence": ("Sick Days", "Sick days"),
    "recruitment": ("BSC Vacancy Rate", "Vacancy rate"),
    "productivity": ("HR Visits per FTE Text", "Visits per FTE"),
}


def _story() -> Visual:
    """[HR Story Home] on the theme's white panel, wrapped, 14pt ink; hospitals only, as its sentence."""
    props = {**card_look(14, NAVY, box=True), "wordWrap": [{"properties": {"show": _lit(True)}}]}
    return Visual("card", *STORY, roles={"Values": [meas("HR Story Home")]}, filters=[hospitals()], props=props)


def _tiles() -> list[Visual]:
    codes = home_tile_codes()
    if len(codes) != 8:
        raise ValueError(f"Home has 8 tile places; the seed marks {len(codes)} KPIs is_home_tile")
    out: list[Visual] = []
    for i, code in enumerate(codes):
        out += kpi_tile(code, X0 + (TILE_W + GAP) * (i % 4), TILES_Y + (TILE_H + GAP) * (i // 4), TILE_W, TILE_H)
    return out


def _areas() -> list[Visual]:
    """One card per detail page (hospitals only, as the tiles' figures), titled with the page's name, and a
    transparent button over it that opens the page (BSC Overview's card buttons: tooltip "Open <page>")."""
    out: list[Visual] = []
    for i, (name, display, _label) in enumerate(DETAIL_PAGES):
        measure, label = AREA_FIGURES[name]
        rect = (X0 + (AREA_W + GAP) * i, AREAS_Y, AREA_W, AREA_H)
        out.append(Visual("card", *rect, roles={"Values": [meas(measure)]}, filters=[hospitals()],
                          title=f"{display} ›", labels={meas(measure): label},
                          props=card_look(20, NAVY, category=True, box=True)))
        out.append(bsc._card_button(rect, name, display))
    return out


def _dq_strip() -> list[Visual]:
    """A white strip: [HR DQ Headline] ("7 open issues · ...") under the title "Data quality", and Open data
    quality on its right. Not filtered to hospitals: Head Office (100) records count for those who may see them."""
    bx = X0 + W0 - 16 - DQ_BUTTON_W
    headline = Visual("card", X0 + 16, DQ_Y + 4, bx - 16 - (X0 + 16), DQ_H - 8,
                      roles={"Values": [meas("HR DQ Headline")]}, title="Data quality",
                      props={**card_look(12, NAVY), "title": [{"properties": {"fontColor": _colour(NAVY)}}]})
    button = nav_button(bx, DQ_Y + (DQ_H - DQ_BUTTON_H) / 2, DQ_BUTTON_W, DQ_BUTTON_H, "data_quality",
                        "Open data quality ›")
    return [white_panel(X0, DQ_Y, W0, DQ_H), headline, button]


def home_page() -> Page:
    visuals = page_frame("home", filters()) + [_story()] + _tiles() + _areas() + _dq_strip()
    return Page("home", "Home", visuals)
