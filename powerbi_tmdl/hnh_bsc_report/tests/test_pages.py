"""The scorecard pages and KPI detail: roles, payloads, filters, layout, and a build against the synthetic template."""
import json

import pytest

from fields import unknown_fields
from layout import page_section
from model import col, meas
from pages import ATTRIBUTE_ROLES, PAGES

# The visual README's field-well table (powerbi_tmdl/hnh_bsc_visual/README.md): role -> 'BSC KPI' column.
README_ROLES = {
    "kpi": "KPI Code", "kpiName": "KPI Name", "shortLabel": "Short Label", "pillar": "Pillar",
    "pillarOrder": "Pillar Order", "pillarWeight": "Pillar Weight", "pillarQuestion": "Pillar Question",
    "objectiveCode": "Objective Code", "objectiveTitle": "Objective Title", "objectiveOrder": "Objective Order",
    "kpiType": "KPI Type", "direction": "Direction", "valueFormat": "Value Format", "displayOrder": "Display Order",
    "kpiStatus": "Status", "valueSource": "Value Source", "owner": "Owner", "scoreBase": "Score Base",
    "scoreSlope": "Score Slope", "goodFrom": "Good From", "watchFrom": "Watch From",
}
SCORECARD = ["BSC", "Financial", "Customer", "Internal Process", "Learning & Growth", "Owner view",
             "Hospital comparison"]
MODE = {"BSC": "overview", "Financial": "board", "Customer": "board", "Internal Process": "board",
        "Learning & Growth": "board", "Owner view": "owner", "Hospital comparison": "comparison"}
PAYLOAD = {"BSC": "BSC Visual Payload Scores", "Hospital comparison": "BSC Visual Payload Scores"}
PILLARS = {"Financial": "Financial", "Customer": "Customer", "Internal Process": "Internal Process",
           "Learning & Growth": "Learning & Growth"}


def by_display(name):
    return next(p for p in PAGES if p.display == name)


def hnh(page):
    (v,) = [v for v in page.visuals if v.sample == "hnhVisual"]
    return v


def lit(prop):
    return prop["expr"]["Literal"]["Value"]


def test_page_names_and_order():
    shown = [p.display for p in PAGES]
    assert shown[:8] == SCORECARD + ["KPI detail"]
    assert [p.hidden for p in PAGES[:8]] == [False] * 7 + [True]
    names = [p.name for p in PAGES]
    assert len(set(names)) == len(names)


@pytest.mark.parametrize("display", SCORECARD)
def test_hnh_visual_roles_follow_the_readme(display):
    v = hnh(by_display(display))
    for role, column in README_ROLES.items():
        assert v.roles[role] == [col("BSC KPI", column)], role
    assert list(ATTRIBUTE_ROLES) == list(README_ROLES)
    assert v.roles["payload"] == [meas(PAYLOAD.get(display, "BSC Visual Payload"))]
    assert v.roles["selectionLabel"] == [meas("BSC Selection Label")]
    extra = set(v.roles) - set(README_ROLES) - {"payload", "selectionLabel"}
    assert extra == ({"branch"} if display == "Hospital comparison" else set())
    if display == "Hospital comparison":
        assert v.roles["branch"] == [col("Branch", "Branch Name")]


@pytest.mark.parametrize("display", SCORECARD)
def test_mode_and_size(display):
    v = hnh(by_display(display))
    assert lit(v.props["scorecard"][0]["properties"]["mode"]) == f"'{MODE[display]}'"
    assert (v.x, v.y, v.w, v.h) == (0, 120, 1920, 960)


def test_pillar_pages_carry_their_pillar_filter():
    for display, pillar in PILLARS.items():
        (f,) = by_display(display).filters
        assert (f.field, f.op, f.values) == (col("BSC KPI", "Pillar"), "eq", [pillar])
    for display in ("BSC", "Owner view", "Hospital comparison"):
        assert by_display(display).filters == []


def test_comparison_filters_hospitals():
    (f,) = hnh(by_display("Hospital comparison")).filters
    assert (f.field, f.op, f.values) == (col("Branch", "Is Hospital"), "in", ["Yes"])
    for d in SCORECARD[:-1]:
        assert hnh(by_display(d)).filters == []


@pytest.mark.parametrize("display", SCORECARD)
def test_header_slicers_and_navigation(display):
    page = by_display(display)
    slicers = [v for v in page.visuals if v.sample.startswith("slicer")]
    assert [(v.sample, v.roles["Values"]) for v in slicers] == [
        ("slicerDropdown", [col("Branch", "Branch Name")]),
        ("slicerDropdown", [col("Branch", "BSC Category")]),
        ("slicerRelativeDate", [col("Date", "Date")]),
        ("slicerDropdown", [col("Time Calculation", "Time Calculation")])]
    (flt,) = slicers[0].filters
    assert (flt.field, flt.op, flt.values) == (col("Branch", "Is Hospital"), "in", ["Yes"])
    sel = slicers[0].props["selection"][0]["properties"]
    assert lit(sel["singleSelect"]) == "false"
    assert lit(sel["selectAllCheckboxEnabled"]) == "true"
    buttons = [v for v in page.visuals if v.sample == "buttonNavigate"]
    targets = [lit(v.props["visualLink"][0]["properties"]["navigationSection"]) for v in buttons]
    assert targets == [f"'{p.name}'" for p in PAGES[:7]]


def test_kpi_detail_page():
    page = by_display("KPI detail")
    assert page.drill_fields == [col("BSC KPI", "KPI Code")]
    by = {}
    for v in page.visuals:
        by.setdefault(v.sample, []).append(v)
    (mrc,) = by["multiRowCard"]
    assert mrc.roles["Values"] == [col("BSC KPI", "KPI Name"), col("BSC KPI", "Definition"),
                                   col("BSC KPI", "Owner"), col("BSC KPI", "Co Owners"),
                                   meas("BSC Target Basis"), meas("BSC KPI Weight")]
    cards = [v.roles["Values"] for v in by["card"]]
    assert cards == [[meas(m)] for m in ("BSC Actual", "BSC Target", "BSC Score", "BSC State", "BSC Numerator",
                                         "BSC Denominator", "BSC Manual Note")]
    (line,) = by["lineChart"]
    assert line.roles == {"Category": [col("Date", "Year Month")], "Y": [meas("BSC Actual"), meas("BSC Target")]}
    assert (line.sort, line.sort_dir) == (col("Date", "Year Month"), "asc")
    (bar,) = by["barChart"]
    assert bar.roles == {"Category": [col("Branch", "Branch Name")], "Y": [meas("BSC Actual")]}
    assert (bar.sort, bar.sort_dir) == (meas("BSC Actual"), "desc")
    (hf,) = bar.filters
    assert (hf.field, hf.op, hf.values) == (col("Branch", "Is Hospital"), "in", ["Yes"])
    (btn,) = by["buttonDrill"]
    link = btn.props["visualLink"][0]["properties"]
    assert link["drillthroughSection"]["expr"]["Measure"]["Property"] == "BSC Detail Page"
    assert "Open detail" in json.dumps(btn.props)


def test_review_focus_2_no_filter_on_actual_or_state():
    for p in PAGES:
        for f in p.filters + [f for v in p.visuals for f in v.filters]:
            assert f.field not in (meas("BSC Actual"), meas("BSC State")), p.display


def test_review_focus_3_note_card():
    note_field = meas("BSC Manual Note")
    users = [(p.display, v) for p in PAGES for v in p.visuals
             if note_field in [f for fs in v.roles.values() for f in fs] + [f.field for f in v.filters]]
    assert [d for d, _ in users] == ["KPI detail"]
    ((_, note),) = users
    assert note.sample == "card" and note.roles == {"Values": [note_field]}
    assert [(f.field, f.op) for f in note.filters] == [(note_field, "notblank")]


def test_no_overlaps_and_inside_the_canvas():
    for p in PAGES:
        for i, a in enumerate(p.visuals):
            assert a.x >= 0 and a.y >= 0 and a.x + a.w <= 1920 and a.y + a.h <= 1080, (p.display, i)
            for j, b in enumerate(p.visuals[:i]):
                apart = a.x >= b.x + b.w or b.x >= a.x + a.w or a.y >= b.y + b.h or b.y >= a.y + a.h
                assert apart, (p.display, i, j)


def test_unknown_fields_is_empty():
    assert unknown_fields(PAGES) == []


def test_family_pages_slot_exists():
    import pages
    assert PAGES == pages.SCORECARD_PAGES + [pages.KPI_DETAIL] + pages.FAMILY_PAGES


def test_pages_build_against_the_synthetic_template(pbix_path):
    from pbix import read_pbix, samples
    p = read_pbix(pbix_path)
    smp = samples(p)
    lay = p.layout
    base, drill = lay["sections"][0], lay["sections"][1]
    sections = []
    for i, page in enumerate(PAGES):
        section, _ = page_section(page, i, smp, lay, drill, base)
        assert len(section["visualContainers"]) == len(page.visuals)
        sections.append(section)
    fin = sections[1]
    assert "Financial" in fin["filters"]
    nav = [vc for vc in fin["visualContainers"] if "navigationSection" in vc["config"]]
    assert len(nav) == 7
    detail = sections[7]
    assert json.loads(detail["config"]).get("visibility") == 1
    assert "BSC Detail Page" in json.dumps(detail["visualContainers"])
