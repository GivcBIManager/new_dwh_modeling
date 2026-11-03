"""The HR report: the frame on every page, the fields against the `HR Dashboard` perspective, Home's KPI tiles from the
seed, the building blocks in hr_frame.py, and the written project."""
import importlib.util
import json
import sys
from pathlib import Path

import pytest

import frame
import pbir
from fields import MODEL_DIR, _tables, prop_fields, unknown_fields
from hr_frame import (DETAIL_PAGES, HELP, HR_FRAME, HR_REPORT, SEED, TABS, filters, home_tile_codes, kpi_tile,
                      seed_kpis, sub_tabs)
from model import col, meas, page_fields


def _hr_pages():
    """This report's pages.py, loaded as `hr_pages`: the name `pages` is the BSC's in a combined test session."""
    if "hr_pages" not in sys.modules:
        spec = importlib.util.spec_from_file_location("hr_pages", Path(__file__).resolve().parents[1] / "pages.py")
        module = importlib.util.module_from_spec(spec)
        sys.modules["hr_pages"] = module
        spec.loader.exec_module(module)
    return sys.modules["hr_pages"]


PAGES, REPORT_FILTERS = _hr_pages().PAGES, _hr_pages().REPORT_FILTERS

KPI_CODE = col("HR KPI", "KPI Code")
BRANCH_NAME = col("Branch", "Branch Name")
IS_HOSPITAL = col("Branch", "Is Hospital")
YEAR_MONTH_NAME = col("Date", "Year Month Name")
STATUS_COLOUR = meas("HR KPI Status Colour")
TAB_NAMES = ["home", "story", "scorecard", "headcount", "data_quality", "guide"]
DETAIL_NAMES = ["headcount", "movements", "payroll", "absence", "recruitment", "productivity"]
# R13: the slicers a page with HR KPI Actual / Status / Status Text / Status Colour may carry
KPI_MEASURES = {"HR KPI Actual", "HR KPI Status", "HR KPI Status Text", "HR KPI Status Colour"}
ALLOWED_KPI_PAGE_SLICERS = {BRANCH_NAME, YEAR_MONTH_NAME}


def lit(prop):
    return prop["expr"]["Literal"]["Value"]


def nav_target(v):
    link = v.props.get("visualLink", [{}])[0].get("properties", {})
    return lit(link["navigationSection"]).strip("'") if "navigationSection" in link else None


def home():
    return next(p for p in PAGES if p.name == "home")


def kpi_codes(visuals):
    """The KPI codes the visuals are filtered to, in visual order, each once."""
    out = []
    for v in visuals:
        for f in v.filters:
            if f.field == KPI_CODE and f.op == "eq" and f.values[0] not in out:
                out.append(f.values[0])
    return out


# ---- the frame ---------------------------------------------------------------------------------------------------

def test_frame_and_report_specs():
    assert HR_FRAME.title == "Workforce" and HR_FRAME.subtitle == "Hayat Healthcare"
    assert TABS == [("home", "Home"), ("story", "Story"), ("scorecard", "Scorecard"), ("headcount", "Details"),
                    ("data_quality", "Data quality"), ("guide", "Guide")]
    assert [(n, label) for n, label, _r in HELP] == [("guide", "How to use"), ("guide_definitions", "Definitions")]
    assert HR_FRAME.tabs == TABS and HR_FRAME.help == HELP
    assert HR_REPORT.name == "HNH Workforce" and HR_REPORT.perspective == "HR Dashboard"
    assert HR_REPORT.custom_visual is False
    # the BSC theme and logo files, by path (not copies), and the frame registers the same logo
    assert HR_REPORT.theme == pbir.THEME and HR_REPORT.logo == frame.LOGO
    assert HR_FRAME.logo == HR_REPORT.logo.name


@pytest.mark.parametrize("page", [p for p in PAGES if not p.hidden], ids=lambda p: p.name)
def test_every_page_has_frame(page):
    assert frame.title_box(HR_FRAME) in page.visuals
    tab_targets = {nav_target(v) for v in page.visuals
                   if v.sample == "buttonNavigate" and (v.y, v.h) == (frame.TAB_Y, frame.TAB_H)}
    assert tab_targets == set(TAB_NAMES)
    for b in frame.help_buttons(HR_FRAME):
        assert b in page.visuals
    assert len([v for v in page.visuals if v.sample == "buttonNavigate" and nav_target(v) in
                ("guide", "guide_definitions") and (v.y, v.h) == (96, 54)]) == 2


def test_fields_in_perspective():
    assert unknown_fields(PAGES, report_filters=REPORT_FILTERS, perspective="HR Dashboard") == []


def test_no_report_measures():
    tables = set(_tables(MODEL_DIR))
    for page in PAGES:
        used = page_fields(page) + [f for v in page.visuals for f in prop_fields(v.props)]
        assert {f.table for f in used} <= tables, page.name
    assert {f.field.table for f in REPORT_FILTERS} <= tables


def test_visuals_inside_page():
    for page in PAGES:
        for v in page.visuals:
            assert v.x >= 0 and v.y >= 0, (page.name, v.sample, v.x, v.y)
            assert v.x + v.w <= 1920, (page.name, v.sample, v.x, v.w)
            assert v.y + v.h <= page.height, (page.name, v.sample, v.y, v.h, page.height)


# ---- Home --------------------------------------------------------------------------------------------------------

def test_home_tiles_are_home_codes():
    codes = home_tile_codes()
    assert len(codes) == 8
    assert kpi_codes(home().visuals) == codes


def test_home_tile_codes_follow_the_seed_display_order():
    rows = [r for r in seed_kpis() if r["is_home_tile"] == 1]
    assert home_tile_codes() == [r["kpi_code"] for r in sorted(rows, key=lambda r: r["display_order"])]


def test_home_is_the_first_page():
    assert PAGES[0].name == "home" and PAGES[0].display == "Home" and not PAGES[0].hidden


def test_home_tiles_two_rows_of_four_inside_content():
    x0, y0, w0, h0 = frame.CONTENT
    panels = [v for v in home().visuals if v.sample == "panel" and v.y >= y0 and v.h > 150]
    assert len(panels) == 8
    assert len({p.y for p in panels}) == 2 and len({p.x for p in panels}) == 4
    for p in panels:
        assert x0 <= p.x and p.x + p.w <= x0 + w0 + 0.01 and p.y + p.h <= y0 + h0


def test_home_story_dq_strip_and_area_cards():
    vs = home().visuals
    story = [v for v in vs if meas("HR Story Home") in v.roles.get("Values", [])]
    assert len(story) == 1 and story[0].w == frame.CONTENT[2]
    dq = [v for v in vs if meas("HR DQ Headline") in v.roles.get("Values", [])]
    assert len(dq) == 1
    targets = [nav_target(v) for v in vs if v.sample == "buttonNavigate" and v.y >= frame.CONTENT[1]]
    assert targets.count("data_quality") == 1
    assert [t for t in targets if t in DETAIL_NAMES] == DETAIL_NAMES


def test_kpi_pages_carry_only_hospital_and_month_slicers():
    """R13: a page that shows HR KPI Actual / Status / Status Text / Status Colour has no other slicers."""
    for page in PAGES:
        names = {f.name for f in page_fields(page) if f.kind == "measure"}
        names |= {f.name for v in page.visuals for f in prop_fields(v.props)}
        if names & KPI_MEASURES:
            slicer_fields = {f for v in page.visuals if v.sample.startswith("slicer") for f in v.roles["Values"]}
            assert slicer_fields <= ALLOWED_KPI_PAGE_SLICERS, page.name


# ---- building blocks ---------------------------------------------------------------------------------------------

def test_filters_hospital_and_month_dropdowns():
    hospital, month = filters()
    assert hospital.sample == month.sample == "slicerDropdown"
    assert hospital.roles == {"Values": [BRANCH_NAME]} and month.roles == {"Values": [YEAR_MONTH_NAME]}
    assert [(f.field, f.op, f.values) for f in hospital.filters] == [(IS_HOSPITAL, "in", ["Yes"])]
    assert hospital.labels == {BRANCH_NAME: "Hospital"} and month.labels == {YEAR_MONTH_NAME: "Month"}
    for v in (hospital, month):  # inside the filter bar, left of the help buttons
        assert frame.FILTER_BAR[1] <= v.y and v.y + v.h <= frame.FILTER_BAR[1] + frame.FILTER_BAR[3]
        assert v.x + v.w < HELP[0][2][0]


def test_slicers_sync_across_pages():
    page = PAGES[0]
    groups = []
    for i, v in enumerate(page.visuals):
        if v.sample == "slicerDropdown":
            groups.append(pbir.visual_json(page, v, i, "")["visual"]["syncGroup"])
    assert [g["groupName"] for g in groups] == ["bsc Branch.Branch Name", "bsc Date.Year Month Name"]
    assert all(g["fieldChanges"] and g["filterChanges"] for g in groups)


def test_kpi_tile():
    vs = kpi_tile("HR_TURNOVER", 30, 300, 447, 236)
    panel, cards = vs[0], vs[1:]
    assert panel.sample == "panel" and (panel.x, panel.y, panel.w, panel.h) == (30, 300, 447, 236)
    assert [c.sample for c in cards] == ["card"] * 3
    assert [c.roles["Values"] for c in cards] == [[meas("HR KPI Actual")], [meas("HR KPI Target Text")],
                                                  [meas("HR KPI Status Text")]]
    for c in cards:
        assert [(f.field, f.op, f.values) for f in c.filters] == [(KPI_CODE, "eq", ["HR_TURNOVER"])]
        assert panel.x <= c.x and c.x + c.w <= panel.x + panel.w
        assert panel.y <= c.y and c.y + c.h <= panel.y + panel.h
    # the label is the seed's short label
    assert cards[0].title == "Turnover"
    # status: the colour comes from [HR KPI Status Colour] (conditional formatting), the word and shape from the text
    assert STATUS_COLOUR in prop_fields(cards[2].props)
    colour = cards[2].props["labels"]
    assert any("Measure" in e["properties"].get("color", {}).get("solid", {}).get("color", {}).get("expr", {})
               for e in colour)
    assert all(STATUS_COLOUR not in prop_fields(c.props) for c in cards[:2])


def test_kpi_tile_unknown_code():
    with pytest.raises(ValueError):
        kpi_tile("HR_NOPE", 0, 0, 100, 100)


def test_sub_tabs():
    vs = sub_tabs("movements")
    buttons = [v for v in vs if v.sample == "buttonNavigate"]
    assert [nav_target(b) for b in buttons] == DETAIL_NAMES
    assert [n for n, _d, _l in DETAIL_PAGES] == DETAIL_NAMES
    current = [b for b in buttons if nav_target(b) == "movements"]
    others = [b for b in buttons if nav_target(b) != "movements"]
    assert current[0].props["fill"] != others[0].props["fill"]
    assert len({json.dumps(b.props["fill"]) for b in others}) == 1
    # right of the slicers, left of the help buttons, inside the filter bar, in one row
    right_of_slicers = max(v.x + v.w for v in filters())
    assert min(b.x for b in buttons) > right_of_slicers
    assert max(b.x + b.w for b in buttons) < HELP[0][2][0]
    assert len({b.y for b in buttons}) == 1
    assert frame.FILTER_BAR[1] <= buttons[0].y and buttons[0].y + buttons[0].h <= 162
    for b in buttons:  # Report Server: a label in the default state's entry
        assert any(e.get("selector") == {"id": "default"} and "text" in e["properties"] for e in b.props["text"])
    with pytest.raises(ValueError):
        sub_tabs("home")


def test_seed_parser_reads_quotes_escapes_and_calls(tmp_path):
    sql = tmp_path / "seed.sql"
    sql.write_text(
        "-- comment with (parens) and 'quotes'\n"
        "INSERT INTO default.map_hr_kpi (kpi_code, kind, short_label, display_order, is_home_tile, status, "
        "changed_at, is_deleted) VALUES\n"
        "    ('B', 'kpi', 'It\\'s (b)', 2, 1, 'active', now64(3), 0),\n"
        "    ('A', 'kpi', 'a, ''quoted''', 1, 1, 'active', now64(3), 0),\n"
        "    ('C', 'kpi', 'c', 3, 0, 'active', now64(3), 0),\n"
        "    ('D', 'kpi', 'd', 0, 1, 'parked', now64(3), 0);\n"
        "INSERT INTO default.map_hr_dq_issue (issue_code) VALUES ('X');\n", encoding="utf-8")
    rows = seed_kpis(sql)
    assert [r["kpi_code"] for r in rows] == ["B", "A", "C", "D"]
    assert rows[0]["short_label"] == "It's (b)" and rows[1]["short_label"] == "a, 'quoted'"
    assert rows[0]["display_order"] == 2 and rows[0]["changed_at"] == "now64(3)"
    assert home_tile_codes(sql) == ["A", "B"]


def test_seed_is_the_repository_file():
    assert SEED.name == "hr_config_seed.sql" and SEED.is_file()


# ---- the project -------------------------------------------------------------------------------------------------

def test_project_files_without_custom_visual():
    files = pbir.project_files(PAGES, "HNH_Analytics_Test", report_filters=REPORT_FILTERS, report=HR_REPORT)
    assert "HNH Workforce.pbip" in files
    assert not any("CustomVisuals" in k for k in files)
    model_ref = json.loads(files["HNH Workforce.SemanticModel/modelReference.json"].decode("utf-8"))
    assert model_ref["connectionString"].endswith('Cube="HR Dashboard"')
    assert "Initial Catalog=HNH_Analytics_Test" in model_ref["connectionString"]
    for k, b in files.items():
        assert not b.startswith(b"\xef\xbb\xbf"), k
    report = json.loads(files["HNH Workforce.Report/definition/report.json"].decode("utf-8"))
    assert "reportExtensions" not in json.dumps(report) and "bookmarks" not in json.dumps(report)


def test_no_visual_groups_or_bookmarks_in_pages():
    files = pbir.project_files(PAGES, "HNH_Analytics_Test", report_filters=REPORT_FILTERS, report=HR_REPORT)
    for k, b in files.items():
        if k.endswith("visual.json"):
            assert "visualGroup" not in json.loads(b.decode("utf-8")), k
    assert not any("bookmarks" in k for k in files)
