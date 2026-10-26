"""The report's pages: the frame on every page, the scorecard pages, KPI detail, the family and guide pages: roles,
payloads, filters, layout, and a build against the synthetic template."""
import json
import re
from pathlib import Path

import pytest

import frame
from fields import unknown_fields
from frame import (BOARD_BUTTON, BOARD_CHART, CONTENT, DETAIL_BACK, DETAIL_BY_HOSPITAL, DETAIL_MATRIX, DETAIL_OPEN,
                   DETAIL_VISUAL, HELP_BUTTONS, OV_CARDS, TABS)
from layout import page_section, skipped
from model import col, meas, page_fields
from frame import button_style, label_text
from pages import ATTRIBUTE_ROLES, PAGES, back_button, select_all_selection

# The visual README's field-well table (powerbi_tmdl/hnh_bsc_visual/README.md): role -> 'BSC KPI' column.
README_ROLES = {
    "kpi": "KPI Code", "kpiName": "KPI Name", "shortLabel": "Short Label", "pillar": "Pillar",
    "pillarOrder": "Pillar Order", "pillarWeight": "Pillar Weight", "pillarQuestion": "Pillar Question",
    "objectiveCode": "Objective Code", "objectiveTitle": "Objective Title", "objectiveOrder": "Objective Order",
    "kpiType": "KPI Type", "direction": "Direction", "valueFormat": "Value Format", "displayOrder": "Display Order",
    "kpiStatus": "Status", "valueSource": "Value Source", "owner": "Owner", "coOwners": "Co Owners", "scoreBase": "Score Base",
    "scoreSlope": "Score Slope", "goodFrom": "Good From", "watchFrom": "Watch From",
}
# The three KPI-detail wells (README: "KPI detail only").
DETAIL_ROLES = {"definition": [col("BSC KPI", "Definition")], "targetBasis": [meas("BSC Target Basis")],
                "manualNote": [meas("BSC Manual Note")]}
SCORECARD = ["Overview", "Financial", "Customer", "Internal Process", "Learning & Growth", "Owner view",
             "Hospital comparison"]
SCORECARD_NAMES = ["bsc", "financial", "customer", "internal_process", "learning_growth", "owner_view",
                   "hospital_comparison"]
MODE = {"Overview": "overview", "Financial": "board", "Customer": "board", "Internal Process": "board",
        "Learning & Growth": "board", "Owner view": "owner", "Hospital comparison": "comparison",
        "KPI detail": "detail"}
PAYLOAD = {"Hospital comparison": "BSC Visual Payload Scores"}  # every other HNH visual: [BSC Visual Payload]
PILLARS = {"Financial": "Financial", "Customer": "Customer", "Internal Process": "Internal Process",
           "Learning & Growth": "Learning & Growth"}
PILLAR_PAGES = {"Financial": "financial", "Customer": "customer", "Internal Process": "internal_process",
                "Learning & Growth": "learning_growth"}
# Global Constraints: the pillar colours by Pillar Order 1-4.
PILLAR_COLOUR = {"Financial": "#002E5A", "Customer": "#1478BE", "Internal Process": "#13ACE3",
                 "Learning & Growth": "#6E8196"}
MUTED, SLICER_BORDER, LINE = "#5B6B7D", "#CBD3DC", "#DCE5EF"

YEAR_MONTH_NAME = col("Date", "Year Month Name")
BRANCH_NAME = col("Branch", "Branch Name")
IS_HOSPITAL = col("Branch", "Is Hospital")
HELP_TARGETS = ["'guide'", "'definitions'"]
FAMILY = ["Revenue detail", "Finance detail", "Patient volume detail", "Beds & clinical detail",
          "Revenue cycle detail", "Workforce detail", "Patient experience detail"]
FAMILY_NAMES = ["fam_revenue", "fam_finance", "fam_volume", "fam_beds", "fam_revenue_cycle", "fam_workforce",
                "fam_experience"]
GUIDE = "How to use"
DEFS = "How scores are calculated"


def by_display(name):
    return next(p for p in PAGES if p.display == name)


def hnh(page):
    (v,) = [v for v in page.visuals if v.sample == "hnhVisual"]
    return v


def lit(prop):
    return prop["expr"]["Literal"]["Value"]


def rect(v):
    return (v.x, v.y, v.w, v.h)


def _obj(v, name, selector=None):
    """The properties of format object `name`'s entry with `selector` (None: the entry without a selector)."""
    return next((e["properties"] for e in v.props.get(name, []) if e.get("selector") == selector), {})


def colour(prop):
    return lit(prop["solid"]["color"])


def link(v):
    return v.props["visualLink"][0]["properties"]


def target(v):
    """A button's destination page name (navigation or a literal drill-through destination), or None."""
    props = link(v)
    for key in ("navigationSection", "drillthroughSection"):
        if key in props and "Literal" in props[key]["expr"]:
            return lit(props[key]).strip("'")
    return None


def tabs(page):
    """The page tabs: navigation buttons on the header bar."""
    return [v for v in page.visuals if v.sample == "buttonNavigate" and v.y + v.h <= 84]


def is_current(tab):
    return lit(_obj(tab, "fill")["show"]) == "true"


def slicers(page):
    return [v for v in page.visuals if v.sample.startswith("slicer")]


def text_runs(v):
    return [run for p in v.props["general"][0]["properties"]["paragraphs"] for run in p["textRuns"]]


# ---- page list and the frame ----------------------------------------------------------------------------------------

def test_page_names_and_order():
    shown = [p.display for p in PAGES]
    assert shown[:8] == SCORECARD + ["KPI detail"]
    assert [p.name for p in PAGES[:8]] == SCORECARD_NAMES + ["kpi_detail"]
    assert [p.hidden for p in PAGES[:8]] == [False] * 7 + [True]
    assert shown[-2:] == ["How to use", "How scores are calculated"]
    assert [p.name for p in PAGES[-2:]] == ["guide", "definitions"]
    assert [p.hidden for p in PAGES[-2:]] == [False, False]
    assert [p.drill_fields for p in PAGES[-2:]] == [None, None]
    names = [p.name for p in PAGES]
    assert len(set(names)) == len(names)


def test_frame_targets_are_the_page_names():
    """The tabs and the help buttons in frame.py point at the pages this module writes, under their display names."""
    assert [(n, label) for n, label in TABS] == [(p.name, p.display) for p in PAGES[:7]]
    assert [n for n, _label, _r in HELP_BUTTONS] == [p.name for p in PAGES[-2:]]
    names = {p.name for p in PAGES}
    for p in PAGES:
        for v in p.visuals:
            if v.sample in ("buttonNavigate", "buttonDrill") and target(v) is not None:
                assert target(v) in names, (p.display, target(v))


@pytest.mark.parametrize("display", [p.display for p in PAGES])
def test_every_page_has_the_frame(display):
    """The header bar, the seven tabs, How to use and Calculations at the frame's places; a scorecard page's own tab
    is current, every other page (hidden pages, guide pages) has none."""
    page = by_display(display)
    assert rect(page.visuals[0]) == (0, 0, 1920, 84) and page.visuals[0].sample == "panel"
    ts = tabs(page)
    assert [target(t) for t in ts] == SCORECARD_NAMES
    current = [target(t) for t in ts if is_current(t)]
    assert current == ([page.name] if page.name in SCORECARD_NAMES else [])
    helps = [v for v in page.visuals if v.sample == "buttonNavigate" and target(v) in ("guide", "definitions")]
    assert [(target(v), rect(v)) for v in helps] == [(n, r) for n, _label, r in HELP_BUTTONS]
    filter_bar = [v for v in page.visuals if v.sample == "panel" and rect(v) == (0, 84, 1920, 78)]
    assert len(filter_bar) == (0 if display == "KPI detail" else 1)


def test_frame_on_the_pages_matches_frame_py():
    """Each page's frame is frame.frame's output (with the page's own filter-bar visuals)."""
    for p in PAGES:
        head = [rect(v) for v in p.visuals if v.y + v.h <= 84]
        expected = [rect(v) for v in frame.frame(p.name if p.name in SCORECARD_NAMES else None, [],
                                                 filter_bar=p.name != "kpi_detail") if v.y + v.h <= 84]
        assert head == expected, p.display


# ---- the scorecard pages --------------------------------------------------------------------------------------------

@pytest.mark.parametrize("display", SCORECARD + ["KPI detail"])
def test_hnh_visual_roles_follow_the_readme(display):
    v = hnh(by_display(display))
    for role, column in README_ROLES.items():
        assert v.roles[role] == [col("BSC KPI", column)], role
    assert list(ATTRIBUTE_ROLES) == list(README_ROLES)
    assert v.roles["payload"] == [meas(PAYLOAD.get(display, "BSC Visual Payload"))]
    assert v.roles["selectionLabel"] == [meas("BSC Selection Label")]
    extra = set(v.roles) - set(README_ROLES) - {"payload", "selectionLabel"}
    assert extra == ({"branch"} if display == "Hospital comparison" else
                     set(DETAIL_ROLES) if display == "KPI detail" else set())
    if display == "Hospital comparison":
        assert v.roles["branch"] == [BRANCH_NAME]
    if display == "KPI detail":
        assert {r: v.roles[r] for r in DETAIL_ROLES} == DETAIL_ROLES


def test_overview_binds_the_full_payload():
    """Decisions after review: the Overview takes [BSC Visual Payload] (trends for the sparklines and the trend)."""
    assert hnh(by_display("Overview")).roles["payload"] == [meas("BSC Visual Payload")]


@pytest.mark.parametrize("display", SCORECARD + ["KPI detail"])
def test_mode_size_and_no_container(display):
    v = hnh(by_display(display))
    sc = _obj(v, "scorecard")
    assert lit(sc["mode"]) == f"'{MODE[display]}'"
    assert lit(sc["showHeader"]) == "false"
    assert rect(v) == (DETAIL_VISUAL if display == "KPI detail" else CONTENT)
    # controller ruling: the visual's own container is off too (the theme rule by guid is unconfirmed for a private
    # visual); the visual draws its own panels
    assert lit(_obj(v, "background")["show"]) == "false"
    assert lit(_obj(v, "border")["show"]) == "false"


def test_pillar_pages_carry_their_pillar_filter():
    for display, pillar in PILLARS.items():
        (f,) = by_display(display).filters
        assert (f.field, f.op, f.values) == (col("BSC KPI", "Pillar"), "eq", [pillar])
    for display in ("Overview", "Owner view", "Hospital comparison"):
        assert by_display(display).filters == []


def test_comparison_filters_hospitals():
    (f,) = hnh(by_display("Hospital comparison")).filters
    assert (f.field, f.op, f.values) == (IS_HOSPITAL, "in", ["Yes"])
    for d in SCORECARD[:-1] + ["KPI detail"]:
        assert hnh(by_display(d)).filters == []


@pytest.mark.parametrize("display", SCORECARD)
def test_scorecard_slicers_and_selection_label(display):
    page = by_display(display)
    sl = slicers(page)
    assert [(v.sample, v.roles["Values"], rect(v)) for v in sl] == [
        ("slicerDropdown", [BRANCH_NAME], (30, 96, 330, 54)),
        ("slicerDropdown", [col("Branch", "BSC Category")], (375, 96, 270, 54)),
        ("slicerDateRange", [col("Date", "Date")], (660, 96, 420, 54))]
    (flt,) = sl[0].filters
    assert (flt.field, flt.op, flt.values) == (IS_HOSPITAL, "in", ["Yes"])
    sel = sl[0].props["selection"][0]["properties"]
    assert lit(sel["singleSelect"]) == "false"
    assert lit(sel["selectAllCheckboxEnabled"]) == "true"
    for v in sl:  # the design's dropdown look: small grey header, #CBD3DC border, radius 6
        header = _obj(v, "header")
        assert (lit(header["textSize"]), colour(header["fontColor"])) == ("11D", f"'{MUTED}'")
        border = _obj(v, "border")
        assert lit(border["show"]) == "true" and colour(border["color"]) == f"'{SLICER_BORDER}'"
        assert lit(border["radius"]) == "6D"
    (card,) = [v for v in page.visuals if v.sample == "card"]
    assert rect(card) == (1100, 99, 470, 48)
    assert card.roles == {"Values": [meas("BSC Selection Label")]}
    labels = _obj(card, "labels")
    assert (lit(labels["fontSize"]), colour(labels["color"])) == ("12D", f"'{MUTED}'")
    assert lit(_obj(card, "categoryLabels")["show"]) == "false"
    assert lit(_obj(card, "background")["show"]) == "false"
    bar = next(v for v in page.visuals if rect(v) == (0, 84, 1920, 78))
    assert all(page.visuals.index(v) > page.visuals.index(bar) for v in sl + [card])  # drawn on the filter bar


def test_overview_navigation_buttons_over_the_pillar_cards():
    page = by_display("Overview")
    over = [v for v in page.visuals if v.sample == "buttonNavigate" and v.y >= CONTENT[1]]
    assert [rect(v) for v in over] == OV_CARDS
    assert [target(v) for v in over] == list(PILLAR_PAGES.values())
    i = page.visuals.index(hnh(page))
    for v, pillar in zip(over, PILLAR_PAGES):
        assert page.visuals.index(v) > i  # over the visual
        assert lit(link(v)["type"]) == "'PageNavigation'"
        assert lit(link(v)["tooltip"]) == f"'Open {pillar}'"
        assert lit(_obj(v, "fill")["show"]) == "false"
        assert lit(_obj(v, "outline")["show"]) == "false"
        assert lit(_obj(v, "text")["show"]) == "false"
        assert lit(_obj(v, "background")["show"]) == "false" and lit(_obj(v, "border")["show"]) == "false"
    for d in SCORECARD[1:]:
        assert not [v for v in by_display(d).visuals if v.sample == "buttonNavigate" and v.y >= CONTENT[1]], d


@pytest.mark.parametrize("display", list(PILLARS))
def test_pillar_page_by_hospital_chart_and_drill_button(display):
    page = by_display(display)
    i = page.visuals.index(hnh(page))
    (chart,) = [v for v in page.visuals if v.sample == "barChart"]
    assert rect(chart) == BOARD_CHART and page.visuals.index(chart) > i
    assert chart.roles == {"Category": [BRANCH_NAME], "Y": [meas("BSC Actual")]}
    assert [(f.field, f.op, f.values) for f in chart.filters] == [(IS_HOSPITAL, "in", ["Yes"])]
    assert (chart.sort, chart.sort_dir, chart.title) == (meas("BSC Actual"), "desc", "By hospital")
    assert lit(_obj(chart, "categoryAxis")["showAxisTitle"]) == "false"
    assert lit(_obj(chart, "valueAxis")["showAxisTitle"]) == "false"
    assert lit(_obj(chart, "labels")["show"]) == "true"
    assert lit(_obj(chart, "background")["show"]) == "false"  # it sits on the visual's panel
    assert lit(_obj(chart, "border")["show"]) == "false"
    (btn,) = [v for v in page.visuals if v.sample == "buttonDrill"]
    assert rect(btn) == BOARD_BUTTON and page.visuals.index(btn) > i
    assert lit(link(btn)["type"]) == "'Drillthrough'"
    assert link(btn)["drillthroughSection"] == {"expr": {"Literal": {"Value": "'kpi_detail'"}}}
    assert lit(_obj(btn, "text", {"id": "default"})["text"]) == "'Drill through to KPI detail →'"
    outline = _obj(btn, "outline", {"id": "default"})
    assert lit(_obj(btn, "outline")["show"]) == "true"
    assert colour(outline["lineColor"]) == f"'{PILLAR_COLOUR[display]}'"
    assert lit(_obj(btn, "fill")["show"]) == "false"


def test_pillar_pages_bind_no_branch_series():
    """The board's geometry assumes no hospital series; KPI detail binds none either."""
    for d in list(PILLARS) + ["KPI detail", "Overview", "Owner view"]:
        assert "branch" not in hnh(by_display(d)).roles, d


def test_only_pillar_pages_have_the_board_chart():
    for d in ("Overview", "Owner view", "Hospital comparison"):
        assert not [v for v in by_display(d).visuals if v.sample in ("barChart", "buttonDrill")], d


def _date_slicers(pages):
    return [(p, v) for p in pages for v in p.visuals if v.sample.startswith("slicer")
            and v.roles["Values"] == [col("Date", "Date")]]


def test_no_page_uses_the_relative_date_slicer():
    assert not [p.display for p in PAGES for v in p.visuals if v.sample == "slicerRelativeDate"]


def test_date_slicer_is_a_range_over_the_build_year():
    """The scorecard pages open on 1 January - 31 December of the build year; KPI detail (filters by drill-through),
    the family pages and the guide pages have no date slicer."""
    import datetime
    import pages
    year = 2026
    current = pages.build_pages(datetime.date(year, 10, 25))
    found = _date_slicers(current)
    assert {p.display for p, _ in found} == set(SCORECARD)
    assert {v.date_range for _, v in found} == {(f"{year}-01-01", f"{year}-12-31")}
    later = pages.build_pages(datetime.date(2027, 1, 2))
    assert {v.date_range for _, v in _date_slicers(later)} == {("2027-01-01", "2027-12-31")}
    assert [p.name for p in later] == [p.name for p in PAGES]


def test_no_page_binds_time_calculation():
    """Controller ruling: no Time Calculation slicer. Its items applied to [BSC Actual] but not to the target, so the
    page opened on "MTD" compared a month-to-date actual with a full-year target."""
    for p in PAGES:
        assert all(f.table != "Time Calculation" for f in page_fields(p)), p.display


# ---- KPI detail -----------------------------------------------------------------------------------------------------

def test_kpi_detail_page():
    page = by_display("KPI detail")
    assert page.drill_fields == [col("BSC KPI", "KPI Code")]
    assert page.keep_filters is True and page.hidden is True
    assert slicers(page) == []  # the filters arrive by drill-through
    samples = [v.sample for v in page.visuals]
    for gone in ("card", "multiRowCard", "lineChart", "table"):
        assert gone not in samples, gone
    v = hnh(page)
    i = page.visuals.index(v)
    (back,) = [b for b in page.visuals if b.sample == "buttonNavigate" and lit(link(b)["type"]) == "'Back'"]
    assert rect(back) == DETAIL_BACK and page.visuals.index(back) > i
    helps = [b for b in page.visuals if b.sample == "buttonNavigate" and target(b) in ("guide", "definitions")]
    assert len(helps) == 2 and all(page.visuals.index(b) > i for b in helps)  # over the visual's sub-bar
    (bar,) = [b for b in page.visuals if b.sample == "barChart"]
    assert rect(bar) == DETAIL_BY_HOSPITAL and page.visuals.index(bar) > i
    assert bar.roles == {"Category": [BRANCH_NAME], "Y": [meas("BSC Actual")]}
    assert (bar.sort, bar.sort_dir, bar.title) == (meas("BSC Actual"), "desc", "By hospital")
    assert [(f.field, f.op, f.values) for f in bar.filters] == [(IS_HOSPITAL, "in", ["Yes"])]
    (m,) = [b for b in page.visuals if b.sample == "matrix"]
    assert rect(m) == DETAIL_MATRIX and page.visuals.index(m) > i
    (btn,) = [b for b in page.visuals if b.sample == "buttonDrill"]
    assert rect(btn) == DETAIL_OPEN and page.visuals.index(btn) > i
    assert link(btn)["drillthroughSection"]["expr"]["Measure"]["Property"] == "BSC Detail Page"
    assert lit(_obj(btn, "text", {"id": "default"})["text"]) == "'Open detail'"


def test_kpi_detail_matrix_is_the_drill_source():
    page = by_display("KPI detail")
    (m,) = [v for v in page.visuals if v.sample == "matrix"]
    assert m.roles == {"Rows": [BRANCH_NAME], "Columns": [YEAR_MONTH_NAME], "Values": [meas("BSC Actual")]}
    assert [(f.field, f.op, f.values) for f in m.filters] == [(IS_HOSPITAL, "in", ["Yes"])]
    assert m.title == "Select a hospital and month, then Open detail"
    (b,) = [v for v in page.visuals if v.sample == "buttonDrill"]
    assert b.x == m.x and b.w == m.w and b.y >= m.y + m.h  # under the matrix


def test_kpi_detail_keeps_all_filters():
    assert by_display("KPI detail").keep_filters is True


def test_review_focus_2_no_filter_on_actual_or_state():
    for p in PAGES:
        for f in p.filters + [f for v in p.visuals for f in v.filters]:
            assert f.field not in (meas("BSC Actual"), meas("BSC State")), p.display


def test_review_focus_3_manual_note():
    """[BSC Manual Note] is bound once: the KPI detail visual's Manual note well, without a filter on it."""
    note_field = meas("BSC Manual Note")
    users = [(p.display, v) for p in PAGES for v in p.visuals
             if note_field in [f for fs in v.roles.values() for f in fs] + [f.field for f in v.filters]]
    assert [(d, v.sample) for d, v in users] == [("KPI detail", "hnhVisual")]
    ((_, v),) = users
    assert v.roles["manualNote"] == [note_field]
    assert v.filters == []


# ---- every page -----------------------------------------------------------------------------------------------------

def _inside(a, b):
    return a.x >= b.x and a.y >= b.y and a.x + a.w <= b.x + b.w and a.y + a.h <= b.y + b.h


def _may_overlap(lower, upper):
    """The overlaps the layout means: a frame panel under the visuals placed on it, and native visuals over the HNH
    visual (the Overview's buttons, the board's chart and button, KPI detail's Back, guide buttons, chart, matrix and
    button). The upper one is drawn later and lies inside the lower one."""
    return lower.sample in ("panel", "hnhVisual") and _inside(upper, lower)


def test_no_overlaps_and_inside_the_canvas():
    for p in PAGES:
        for i, a in enumerate(p.visuals):
            assert a.x >= 0 and a.y >= 0 and a.x + a.w <= 1920 and a.y + a.h <= 1080, (p.display, i)
            for j, b in enumerate(p.visuals[:i]):
                apart = a.x >= b.x + b.w or b.x >= a.x + a.w or a.y >= b.y + b.h or b.y >= a.y + a.h
                assert apart or _may_overlap(b, a), (p.display, i, j)


def test_overlap_rule_bites():
    from model import Visual
    hv, panel = Visual("hnhVisual", 0, 0, 100, 100), frame.panel(0, 0, 100, 100, "#FFFFFF")
    inner, sticking_out = Visual("card", 10, 10, 20, 20), Visual("card", 90, 10, 20, 20)
    assert _may_overlap(hv, inner) and _may_overlap(panel, inner)
    assert not _may_overlap(hv, sticking_out) and not _may_overlap(inner, hv)
    assert not _may_overlap(Visual("card", 0, 0, 100, 100), inner)


def test_unknown_fields_is_empty():
    assert unknown_fields(PAGES) == []


def test_family_pages_slot_exists():
    import pages
    assert PAGES == pages.SCORECARD_PAGES + [pages.KPI_DETAIL] + pages.FAMILY_PAGES + pages.GUIDE_PAGES


def test_pages_build_against_the_synthetic_template(pbix_path):
    from pbix import read_pbix, samples
    p = read_pbix(pbix_path)
    smp = samples(p)
    lay = p.layout
    base, drill = lay["sections"][0], lay["sections"][1]
    sections = []
    for i, page in enumerate(PAGES):
        section, _ = page_section(page, i, smp, lay, drill, base)
        assert len(section["visualContainers"]) == len(page.visuals) - len(skipped(page))
        sections.append(section)
    fin = sections[1]
    assert "Financial" in fin["filters"]
    nav = [vc for vc in fin["visualContainers"] if "navigationSection" in vc["config"]]
    assert len(nav) == 9  # seven tabs, How to use, Calculations
    assert len([vc for vc in fin["visualContainers"] if "kpi_detail" in vc["config"]]) == 1
    detail = sections[7]
    assert json.loads(detail["config"]).get("visibility") == 1
    assert "BSC Detail Page" in json.dumps(detail["visualContainers"])


CAPABILITIES = Path(__file__).resolve().parents[2] / "hnh_bsc_visual" / "capabilities.json"


def test_role_names_come_from_the_visual_capabilities():
    roles = [r["name"] for r in json.loads(CAPABILITIES.read_text(encoding="utf-8-sig"))["dataRoles"]]
    attributes = [r for r in roles if r not in ("branch", "payload", "selectionLabel", *DETAIL_ROLES)]
    assert attributes == list(README_ROLES)
    assert set(roles) == set(README_ROLES) | {"branch", "payload", "selectionLabel"} | set(DETAIL_ROLES)
    for display in SCORECARD + ["KPI detail"]:
        assert set(hnh(by_display(display)).roles) <= set(roles)
    # the README binds the three new wells on KPI detail only
    for display in SCORECARD:
        assert not set(hnh(by_display(display)).roles) & set(DETAIL_ROLES), display
    assert set(DETAIL_ROLES) <= set(hnh(by_display("KPI detail")).roles)


def test_owner_view_binds_co_owners():
    assert hnh(by_display("Owner view")).roles["coOwners"] == [col("BSC KPI", "Co Owners")]


def test_helpers_write_literal_values():
    sel = select_all_selection()["selection"][0]["properties"]
    assert (lit(sel["singleSelect"]), lit(sel["selectAllCheckboxEnabled"])) == ("false", "true")
    txt = label_text("Hi")["text"]
    # Desktop's actionButton reads `show` from the entry without a selector and the label per state: the default
    # state's entry (selector id "default") holds it; hover, press and disabled fall back to it
    assert [lit(e["properties"]["show"]) for e in txt if "selector" not in e] == ["true"]
    assert [lit(e["properties"]["text"]) for e in txt if e.get("selector") == {"id": "default"}] == ["'Hi'"]
    assert all("text" not in e["properties"] for e in txt if "selector" not in e)
    b = back_button()
    assert (lit(link(b)["show"]), lit(link(b)["type"])) == ("true", "'Back'")
    assert rect(b) == DETAIL_BACK


def test_nav_buttons_assert_link_type_and_show():
    for v in by_display("Overview").visuals:
        if v.sample == "buttonNavigate":
            assert (lit(link(v)["show"]), lit(link(v)["type"])) == ("true", "'PageNavigation'")


# ---- family pages ---------------------------------------------------------------------------------------------------

def test_family_pages_names_order_and_hidden():
    import pages
    assert [p.display for p in pages.FAMILY_PAGES] == FAMILY
    assert [p.name for p in pages.FAMILY_PAGES] == FAMILY_NAMES
    assert all(p.hidden for p in pages.FAMILY_PAGES)
    assert PAGES[8:15] == pages.FAMILY_PAGES


MEASURES_TMDL = Path(__file__).resolve().parents[3] / "ssas" / "HNH_Analytics" / "tables" / "_Measures.tmdl"


def detail_page_outputs(text: str) -> list[str]:
    """The page names [BSC Detail Page] returns: the result of each `"<key>", "<page>",` pair of its SWITCH."""
    m = re.search(r"(?ms)^\tmeasure 'BSC Detail Page' =\n(.*?)^\t\t(?:formatString|displayFolder)", text)
    assert m, "BSC Detail Page measure not found"
    switch = re.search(r"SWITCH \(\s*SELECTEDVALUE \( 'BSC KPI'\[Detail Page\] \),(.*)BLANK \(\)", m.group(1), re.S)
    assert switch, "BSC Detail Page is not a SWITCH on 'BSC KPI'[Detail Page]"
    return re.findall(r'"[^"]*"\s*,\s*"([^"]*)"\s*,', switch.group(1))


def test_family_display_names_match_bsc_detail_page_measure():
    import pages
    outputs = detail_page_outputs(MEASURES_TMDL.read_text(encoding="utf-8-sig"))
    assert len(outputs) == len(set(outputs))
    assert set(outputs) == {p.display for p in pages.FAMILY_PAGES} == set(FAMILY)  # every output has a page, and back


def test_detail_page_outputs_parse_the_switch():
    text = ("\tmeasure 'BSC Detail Page' =\n\t\t\tSWITCH (\n\t\t\t\tSELECTEDVALUE ( 'BSC KPI'[Detail Page] ),\n"
            '\t\t\t\t"a", "A detail",\n\t\t\t\t"b", "B detail",\n\t\t\t\tBLANK ()\n\t\t\t)\n\t\tformatString: General\n'
            "\tmeasure 'Other' =\n\t\t\tSWITCH ( x, \"c\", \"C detail\", BLANK () )\n\t\tformatString: General\n")
    assert detail_page_outputs(text) == ["A detail", "B detail"]


def _content(page):
    """The visuals below the filter bar."""
    return [v for v in page.visuals if v.y >= CONTENT[1]]


@pytest.mark.parametrize("display", FAMILY)
def test_family_drill_fields_header_and_no_slicers(display):
    page = by_display(display)
    assert page.drill_fields == [BRANCH_NAME, YEAR_MONTH_NAME]
    assert not slicers(page)
    backs = [v for v in page.visuals if v.sample == "buttonNavigate" and lit(link(v)["type"]) == "'Back'"]
    assert [rect(v) for v in backs] == [DETAIL_BACK]
    # the filter bar holds only Back and the help buttons
    in_bar = [v for v in page.visuals if v.sample != "panel" and 84 <= v.y and v.y + v.h <= 162]
    assert [target(v) if target(v) else lit(link(v)["type"]) for v in in_bar] == ["'Back'", "guide", "definitions"]
    (mrc,) = [v for v in page.visuals if v.sample == "multiRowCard"]
    assert mrc.roles["Values"] == [BRANCH_NAME, YEAR_MONTH_NAME]
    (title,) = [v for v in page.visuals if v.sample == "textbox" and v.y >= CONTENT[1]]
    assert rect(title) == (30, 186, 1200, 54)


@pytest.mark.parametrize("display", FAMILY)
def test_family_layout_inside_the_content_box(display):
    """Cards and charts start at y 258 and stay inside x 30-1890, y up to 1056; a 2-column chart grid."""
    page = by_display(display)
    for v in _content(page):
        assert v.x >= 30 and v.x + v.w <= 1890 and v.y + v.h <= 1056, (v.sample, rect(v))
    body = [v for v in page.visuals if v.sample in ("card", "barChart", "table", "matrix")]
    assert min(v.y for v in body) == 258
    charts = [v for v in body if v.sample != "card"]
    assert {v.x for v in charts} <= {30, 972} and {v.w for v in charts} == {918}
    assert len({v.h for v in charts}) == 1  # shrunk evenly
    for v in body:  # the theme's white panel: no container override
        assert "background" not in v.props and "border" not in v.props, v.title


@pytest.mark.parametrize("display", FAMILY)
def test_family_pages_take_only_the_drill_fields(display):
    """Review Focus 4: a family page does not keep all filters. KPI detail carries the 'BSC KPI' drill filter (and a
    pillar page filter); passed on, every domain measure's guard returns "... can't be analysed by "BSC KPI"". The
    page filters hospitals itself."""
    page = by_display(display)
    assert page.keep_filters is False
    assert [(f.field, f.op, f.values) for f in page.filters] == [(IS_HOSPITAL, "in", ["Yes"])]


def test_family_drill_fields_are_the_kpi_detail_matrix_fields():
    """The "Open detail" button drills on the matrix's cell: its row and column fields are the family drill fields."""
    (m,) = [v for v in by_display("KPI detail").visuals if v.sample == "matrix"]
    for display in FAMILY:
        assert by_display(display).drill_fields == m.roles["Rows"] + m.roles["Columns"], display


def test_months_show_by_name():
    """'Date'[Year Month Name] (sorted by 'Date'[Year Month]) for display and drill; the number never shows."""
    for p in PAGES:
        assert col("Date", "Year Month") not in page_fields(p), p.display


def _spec(page):
    cards = [v.roles["Values"][0].name for v in page.visuals if v.sample == "card"]
    charts = [(v.sample, v.roles, v.sort, v.top_n) for v in page.visuals if v.sample in ("barChart", "table", "matrix")]
    return cards, charts


def test_family_cards_and_charts():
    D, P, m = col("Department", "Department Name"), col("Payer", "Category"), meas
    exp = {
        "Revenue detail": (["Revenue", "Gross Charges", "Line Discount", "Claimable Revenue"], [
            ("barChart", {"Category": [D], "Y": [m("Revenue")]}, m("Revenue"), (m("Revenue"), 15)),
            ("barChart", {"Category": [col("Product Category", "High Level Department")], "Y": [m("Revenue")]},
             m("Revenue"), None),
            ("barChart", {"Category": [P], "Y": [m("Revenue")]}, m("Revenue"), None),
            ("table", {"Values": [col("Staff", "Staff Name"), m("Revenue")]}, m("Revenue"), (m("Revenue"), 20))]),
        "Finance detail": (["EBITDA", "EBITDA Margin %", "Net Profit", "Budget Variance %"], [
            ("matrix", {"Rows": [col("Budget Line", "Budget Line Name")],
                        "Values": [m("IS Actual"), m("IS Budget"), m("Budget Variance")]}, None, None),
            ("barChart", {"Category": [col("GL Account", "Natural Account Name")], "Y": [m("GL Movement")]},
             m("GL Movement"), (m("GL Movement"), 15))]),
        "Patient volume detail": (["OP Visits", "ER Visits", "Admissions", "New Patients", "Returning Patients"], [
            ("barChart", {"Category": [D], "Y": [m("OP Visits")]}, m("OP Visits"), (m("OP Visits"), 15)),
            ("barChart", {"Category": [P], "Y": [m("Census")]}, m("Census"), None),
            ("barChart", {"Category": [D], "Y": [m("Average Wait (min)")]}, m("Average Wait (min)"),
             (m("Average Wait (min)"), 15))]),
        "Beds & clinical detail": (["Bed Occupancy %", "ALOS (days)", "Readmission Rate 30d %",
                                    "ICU Readmissions 48h", "Bed Turnover"], [
            ("barChart", {"Category": [col("Bed", "Current Ward")], "Y": [m("Bed Occupancy %")]},
             m("Bed Occupancy %"), None),
            ("barChart", {"Category": [D], "Y": [m("ALOS (days)")]}, m("ALOS (days)"), (m("ALOS (days)"), 15)),
            ("table", {"Values": [col("Discharge Outcome", "Outcome Group"), m("Discharges")]}, m("Discharges"),
             None)]),
        "Revenue cycle detail": (["Claim Rejection Rate %", "First-pass Rejection Rate %",
                                  "Pre-auth Approval Rate %", "Leak Rate %", "Billed Not Submitted"], [
            ("barChart", {"Category": [col("NPHIES Reason", "Reason")], "Y": [m("Claims Rejected")]},
             m("Claims Rejected"), (m("Claims Rejected"), 15)),
            ("barChart", {"Category": [col("Payer", "Purchaser Name")], "Y": [m("Claimed Amount")]},
             m("Claimed Amount"), (m("Claimed Amount"), 15)),
            ("table", {"Values": [col("Claim Status", "Submission Status"), m("Billed Amount")]}, m("Billed Amount"),
             None),
            ("barChart", {"Category": [D], "Y": [m("Lost Value")]}, m("Lost Value"), (m("Lost Value"), 15))]),
        "Workforce detail": (["Headcount", "FTE", "Saudisation Rate %", "Turnover Rate %", "Hires"], [
            ("barChart", {"Category": [col("HR Department", "Department Name")], "Y": [m("Headcount")]},
             m("Headcount"), (m("Headcount"), 15)),
            ("barChart", {"Category": [col("Job", "Job Name")], "Y": [m("Headcount")]}, m("Headcount"),
             (m("Headcount"), 15)),
            ("barChart", {"Category": [col("Employee", "Nationality")], "Y": [m("Headcount")]}, m("Headcount"),
             (m("Headcount"), 10))]),
        "Patient experience detail": (["Hospital NPS (5-point)", "Physician NPS (5-point)", "NPS Answers",
                                       "Response Rate %"], [
            ("barChart", {"Category": [col("Survey Question", "Domain En")], "Y": [m("NPS (5-point)")]},
             m("NPS (5-point)"), None),
            ("barChart", {"Category": [D], "Y": [m("NPS (5-point)")]}, m("NPS (5-point)"),
             (m("NPS Answers"), 15)),
            ("table", {"Values": [col("Survey Question", "Question En"), m("% Promoters"), m("% Passives"),
                                  m("% Detractors"), m("NPS Answers")]}, m("NPS Answers"), (m("NPS Answers"), 20))]),
    }
    for display, (cards, charts) in exp.items():
        assert _spec(by_display(display)) == (cards, charts), display


def test_family_tables_sort_by_their_ranking_measure():
    """A family table sorts descending by the measure it ranks by (its top N measure, else its first measure), so
    "Top 20 doctors by revenue" lists the top doctor first; the income statement matrix keeps the FS lines' order."""
    tables = [v for p in PAGES[8:15] for v in p.visuals if v.sample == "table"]
    assert len(tables) == 4
    for v in tables:
        rank = v.top_n[0] if v.top_n else v.roles["Values"][1]
        assert (v.sort, v.sort_dir) == (rank, "desc"), v.title
        assert rank in v.roles["Values"]
    for p in PAGES[8:15]:
        assert all(v.sort is None for v in p.visuals if v.sample == "matrix"), p.display


def test_family_bar_top_n_ranks_by_the_bars_measure():
    """Except NPS by department: the 15 departments with most answers (ranked by NPS, departments with a few answers
    won), bars sorted by NPS."""
    for p in PAGES[8:15]:
        for v in p.visuals:
            if v.sample == "barChart" and v.top_n:
                assert v.roles["Y"][0] == v.sort, v.title
                expected = meas("NPS Answers") if v.title == "NPS by department (15 with most answers)" else v.sort
                assert v.top_n[0] == expected, v.title


def test_nps_charts_hide_the_value_axis_and_show_data_labels():
    """[NPS (5-point)]'s format string prints "insufficient sample" along the value axis: hide the axis, show the
    values as data labels."""
    nps = [v for v in by_display("Patient experience detail").visuals
           if v.sample == "barChart" and v.roles["Y"] == [meas("NPS (5-point)")]]
    assert len(nps) == 2
    for v in nps:
        assert lit(_obj(v, "valueAxis")["show"]) == "false", v.title
        assert lit(_obj(v, "labels")["show"]) == "true", v.title


TITLE_STYLE = {"fontFamily": "Segoe UI", "fontSize": "22pt", "fontWeight": "bold", "color": "#0A1E32"}


@pytest.mark.parametrize("display", FAMILY)
def test_family_title_is_22pt_bold(display):
    (tb,) = [v for v in by_display(display).visuals if v.sample == "textbox" and v.y >= CONTENT[1]]
    (run,) = text_runs(tb)
    assert run["value"] == display
    assert run["textStyle"] == TITLE_STYLE
    assert lit(_obj(tb, "background")["show"]) == "false"  # on the page surface


def test_family_pages_build_against_the_synthetic_template(pbix_path):
    from pbix import read_pbix, samples
    p = read_pbix(pbix_path)
    smp = samples(p)
    lay = p.layout
    base, drill = lay["sections"][0], lay["sections"][1]
    for i, page in enumerate(PAGES):
        if not 8 <= i < 15:
            continue
        section, _ = page_section(page, i, smp, lay, drill, base)
        assert len(section["visualContainers"]) == len(page.visuals) - len(skipped(page))
        assert json.loads(section["config"]).get("visibility") == 1


CHART_TITLES = {
    "KPI detail": ["By hospital", "Select a hospital and month, then Open detail"],
    "Revenue detail": ["Revenue by department (top 15)", "Revenue by product category", "Revenue by payer category",
                       "Top 20 doctors by revenue"],
    "Finance detail": ["Income statement: actual vs budget", "GL movement by account (top 15)"],
    "Patient volume detail": ["OP visits by department (top 15)", "Census by payer category",
                              "Average wait by department (top 15)"],
    "Beds & clinical detail": ["Bed occupancy by ward", "ALOS by department (top 15)", "Discharges by outcome"],
    "Revenue cycle detail": ["Rejected claims by NPHIES reason (top 15)", "Claimed amount by payer (top 15)",
                             "Billed amount by submission status", "Lost value by department (top 15)"],
    "Workforce detail": ["Headcount by department (top 15)", "Headcount by job (top 15)",
                         "Headcount by nationality (top 10)"],
    "Patient experience detail": ["NPS by domain", "NPS by department (15 with most answers)",
                                  "Promoters, passives and detractors by question (top 20)"],
}
CHARTS = {"lineChart", "barChart", "table", "matrix"}


def test_drill_page_charts_have_titles():
    for display, titles in CHART_TITLES.items():
        charts = [v for v in by_display(display).visuals if v.sample in CHARTS]
        assert [v.title for v in charts] == titles, display
    for p in PAGES[1:15]:
        assert all(v.title for v in p.visuals if v.sample in CHARTS), p.display


# ---- buttons --------------------------------------------------------------------------------------------------------

def _style(v):
    """(fill colour or None, outline shown, text colour) of a button. As the handover's buttons: `show` in an entry
    without a selector, colours in the default state's entry (selector id "default")."""
    default = {"id": "default"}
    fill, outline, text = _obj(v, "fill", default), _obj(v, "outline", default), _obj(v, "text", default)
    assert "show" not in fill and "show" not in outline

    def c(p, k):
        return colour(p[k]) if k in p else None
    return (c(fill, "fillColor") if lit(_obj(v, "fill")["show"]) == "true" else None,
            lit(_obj(v, "outline")["show"]), c(text, "fontColor"))


def _kind(page, v):
    """tab, overlay (Overview card), board drill, outline (Back, help) or primary (Open detail)."""
    if v in tabs(page):
        return "tab"
    if v.sample == "buttonNavigate" and v.y >= CONTENT[1]:
        return "overlay"
    if target(v) == "kpi_detail":
        return "board drill"
    if lit(link(v)["type"]) == "'Back'" or target(v) in ("guide", "definitions"):
        return "outline"
    return "primary"


def test_buttons_have_a_visible_style():

    kinds = set()
    for p in PAGES:
        for v in p.visuals:
            if v.sample not in ("buttonNavigate", "buttonDrill"):
                continue
            kind = _kind(p, v)
            kinds.add(kind)
            if kind == "tab":
                continue  # test_frame.py
            if kind == "overlay":
                assert _style(v) == (None, "false", None)
                continue
            if kind == "board drill":
                c = PILLAR_COLOUR[p.display]
                assert _style(v) == (None, "true", f"'{c}'")
            elif kind == "outline":
                assert _style(v) == (None, "true", "'#1478BE'")
            else:
                assert _style(v) == ("'#13ACE3'", "false", "'#FFFFFF'")
            # the label: `show` without a selector, the text in the default state's entry; one entry per selector
            assert lit(_obj(v, "text")["show"]) == "true"
            assert lit(_obj(v, "text", {"id": "default"})["text"])
            for obj, entries in v.props.items():
                sels = [json.dumps(e.get("selector"), sort_keys=True) for e in entries]
                assert len(sels) == len(set(sels)), (obj, sels)
    assert kinds == {"tab", "overlay", "board drill", "outline", "primary"}
    assert set(button_style("primary")) == set(button_style("outline")) == {"fill", "outline", "text"}


def test_open_detail_button_is_readable_when_disabled():
    """Open detail is disabled until a matrix cell is selected; Desktop's disabled default is a light grey fill with
    grey text. The disabled state gets its own fill and text colour; the label falls back to the default state's."""
    (btn,) = [v for v in by_display("KPI detail").visuals if v.sample == "buttonDrill"]
    disabled = {"id": "disabled"}
    fill, text = _obj(btn, "fill", disabled), _obj(btn, "text", disabled)
    assert colour(fill["fillColor"]) != colour(text["fontColor"])
    assert lit(fill["transparency"]) == "0D"
    assert lit(_obj(btn, "text", {"id": "default"})["text"]) == "'Open detail'"


# ---- "How to use" and "How scores are calculated" ----------------------------------------------------------------

def paragraphs(v):
    """[(text, fontSize, fontWeight, fontColor)] of a text box's paragraphs (one run each)."""
    out = []
    for para in v.props["general"][0]["properties"]["paragraphs"]:
        (run,) = para["textRuns"]
        st = run["textStyle"]
        out.append((run["value"], st["fontSize"], st.get("fontWeight"), st.get("color")))
    return out


def box(page, x, y):
    (v,) = [v for v in page.visuals if v.sample == "textbox" and (v.x, v.y) == (x, y)]
    return v


def texts_at(page, x, y):
    return [t[0] for t in paragraphs(box(page, x, y))]


COLS = [30, 658, 1286]  # three 604-wide columns, 24 apart, from 30 to 1890


def test_text_box_styles():
    from pages import text_box
    props = text_box([("heading", "H"), ("body", "B"), ("bullet", "L")])
    paras = props["general"][0]["properties"]["paragraphs"]
    assert len(paras) == 3
    runs = [p["textRuns"][0] for p in paras]
    assert [r["value"] for r in runs] == ["H", "B", "• L"]
    assert runs[0]["textStyle"] == {"fontFamily": "Segoe UI", "fontSize": "14pt", "fontWeight": "bold",
                                    "color": "#1478BE"}
    for r in runs[1:]:
        assert r["textStyle"] == {"fontFamily": "Segoe UI", "fontSize": "12pt", "color": "#0A1E32"}
    with pytest.raises(ValueError):
        text_box([("title", "x")])


@pytest.mark.parametrize("display, title", [(GUIDE, "How to use the scorecard"), (DEFS, DEFS)])
def test_guide_pages_header_and_panels(display, title):
    page = by_display(display)
    tb = box(page, 30, 186)
    assert (tb.w, tb.h) == (1200, 54)
    (run,) = text_runs(tb)
    assert run["value"] == title
    assert run["textStyle"] == TITLE_STYLE
    assert [v for v in page.visuals if v.sample == "slicerDateRange"] == []
    assert not [v for v in page.visuals if v.sample.startswith("slicer") and v.y < CONTENT[1]]  # none in the bar
    # the text boxes below the title sit in white panels inside the content box
    texts = [v for v in page.visuals if v.sample == "textbox" and v.y >= CONTENT[1] and v is not tb]
    assert texts
    for v in _content(page):
        assert v.x >= 30 and v.x + v.w <= 1890 and v.y + v.h <= 1056, rect(v)
        assert v is tb or v.y >= 258, rect(v)
    for v in texts:
        bg, border = _obj(v, "background"), _obj(v, "border")
        assert lit(bg["show"]) == "true" and colour(bg["color"]) == "'#FFFFFF'"
        assert lit(border["show"]) == "true" and colour(border["color"]) == f"'{LINE}'"
        assert lit(border["radius"]) == "12D"


def test_guide_page_copy():
    page = by_display(GUIDE)
    (path,) = texts_at(page, 30, 258)
    assert path == ("Overall score  ›  4 pillars  ›  objectives  ›  KPIs  ›  KPI detail  ›  "
                    "detail pages (Revenue, Finance, Patient volume, Beds & clinical, Revenue cycle, Workforce, "
                    "Patient experience)")
    assert (box(page, 30, 258).w, box(page, 30, 258).h) == (1860, 54)
    for x in COLS:
        v = box(page, x, 336)
        assert (v.w, v.h) == (604, 420)
    choose = texts_at(page, 30, 336)
    assert choose[0] == "Choose what you see" and len(choose) == 5
    assert choose[1] == ("• Hospital: pick one or more hospitals, or leave it empty for all hospitals together "
                         "(Corporate).")
    assert choose[4] == "• Your choices carry over to every scorecard page and to KPI detail."
    read = texts_at(page, 658, 336)
    assert read[0] == "Read the scores and colours" and len(read) == 8
    assert "• On track: 85 or more." in read and "• Watch: 70 to 84." in read
    assert "• Needs attention lists the KPIs at risk, lowest score first." in read
    assert read[-1] == ("• Owner view shows Achievement in %: 100% or more is on track, 85% to 99% watch, "
                        "below 85% at risk.")
    deeper = texts_at(page, 1286, 336)
    assert deeper[0] == "Go deeper" and len(deeper) == 9
    assert deeper[1] == "• The tabs in the dark bar at the top move between the scorecard pages."
    assert deeper[2] == ("• Right-click a KPI and choose Drill through › KPI detail for its trend, hospitals and "
                         "definition.")
    assert deeper[3] == ("• On a pillar page, select a KPI in the table to see its monthly trend and hospitals on "
                         "the right, then Drill through to KPI detail.")
    assert deeper[-1] == "• Hover over a KPI for its actual, target, variance and owner."
    pages_box = texts_at(page, 30, 780)
    assert pages_box[0] == "Pages" and len(pages_box) == 8
    assert pages_box[1] == "Overview: how are we doing overall and in each pillar?"
    assert pages_box[-1] == "How scores are calculated: how is each score worked out, and what does each KPI measure?"
    v = box(page, 30, 780)
    assert (v.w, v.h) == (1860, 276)
    assert paragraphs(v)[0][1:] == ("14pt", "bold", "#1478BE")
    assert {t[1] for t in paragraphs(v)[1:]} == {"12pt"}


def test_guide_copy_names_the_overview():
    """The page once called "BSC" is "Overview" everywhere in the guide; the old page buttons are gone."""
    texts = [t for v in _content(by_display(GUIDE)) if v.sample == "textbox" for t, *_ in paragraphs(v)]
    assert any("Overview" in t for t in texts)
    assert not [t for t in texts if t.startswith("BSC:") or "BSC page" in t or "page buttons" in t]


def test_definitions_page_copy():
    page = by_display(DEFS)
    score = texts_at(page, 30, 258)
    assert score[0] == "KPI score (0 to 100)" and len(score) == 5
    assert score[2] == "• Score = score base + score slope × variance, rounded and kept between 0 and 100."
    assert score[4] == "• Status: On track from 85, Watch from 70, At risk below 70."
    pillar = texts_at(page, 658, 258)
    assert pillar[0] == "Pillar and overall scores" and len(pillar) == 6
    assert pillar[-1] == "• Hospital comparison ranks hospitals by these scores; equal rounded scores share a rank."
    owner = texts_at(page, 1286, 258)
    assert owner[0] == "Owner achievement (%)" and len(owner) == 5
    assert owner[1] == ("• Each KPI's achievement: actual ÷ target where higher is better; target ÷ actual "
                        "where lower is better; 100% when a ceiling KPI is at or below its ceiling; for on-target "
                        "KPIs, 100% less the distance from the target.")
    assert owner[-1] == "• C-suite cards come first: CEO, COO, CMO, CFO, CHRO, CIO, CSO."
    for x in COLS:
        v = box(page, x, 258)
        assert (v.w, v.h) == (604, 300)
    (example,) = texts_at(page, 30, 582)
    assert example == ("Example: Net Revenue Achievement, actual SAR 41.2M against a target of SAR 48.0M. Variance "
                       "−14.2%, so the score is 85 + 0.6 × (−14.2) = 76.5, rounded to 77: Watch.")
    assert (box(page, 30, 582).w, box(page, 30, 582).h) == (1860, 54)
    (legend,) = texts_at(page, 1002, 660)
    assert legend.startswith("Better when: higher = higher is better · lower = lower is better")
    assert legend.endswith("Weight: the KPI's corporate weight within its pillar.")
    assert (box(page, 1002, 660).w, box(page, 1002, 660).h) == (888, 60)


def test_definitions_slicers_and_table():
    from pages import word_wrap
    page = by_display(DEFS)
    sl = slicers(page)
    assert [v.sample for v in sl] == ["slicerDropdown"] * 3
    assert [v.roles["Values"] for v in sl] == [
        [col("BSC KPI", "Pillar")], [col("BSC KPI", "Objective Title")], [col("BSC KPI", "Owner")]]
    assert [rect(v) for v in sl] == [(30, 660, 300, 60), (354, 660, 300, 60), (678, 660, 300, 60)]
    assert all(v.props == select_all_selection() for v in sl)
    (t,) = [v for v in page.visuals if v.sample == "table"]
    assert rect(t) == (30, 744, 1860, 312)
    assert t.title == "Every active KPI"
    assert t.roles["Values"] == [
        col("BSC KPI", "KPI Num"), col("BSC KPI", "Pillar"), col("BSC KPI", "Objective Title"),
        col("BSC KPI", "KPI Name"), col("BSC KPI", "Definition"), col("BSC KPI", "Direction"),
        meas("BSC Target Basis"), meas("BSC KPI Weight"), col("BSC KPI", "Owner"), col("BSC KPI", "Co Owners")]
    assert (t.sort, t.sort_dir) == (col("BSC KPI", "KPI Num"), "asc")
    (f,) = t.filters
    assert (f.field, f.op, f.values) == (col("BSC KPI", "Is Active"), "in", ["Yes"])
    assert t.props == word_wrap()
