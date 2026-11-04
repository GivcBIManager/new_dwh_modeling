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
MONTH_PICK = col("Date", "Month Pick")
STATUS_COLOUR = meas("HR KPI Status Colour")
TAB_NAMES = ["home", "story", "scorecard", "headcount", "data_quality", "guide"]
DETAIL_NAMES = ["headcount", "movements", "payroll", "absence", "recruitment", "productivity"]
# R13: the slicers a page with HR KPI Actual / Status / Status Text / Status Colour may carry
KPI_MEASURES = {"HR KPI Actual", "HR KPI Actual Text", "HR KPI Status", "HR KPI Status Text", "HR KPI Status Colour"}
AREA = col("HR KPI", "Area")
TIME_CALC = col("Time Calculation", "Time Calculation")
# R13: an Area slicer on the KPI list is allowed; so is the Period slicer (final review I3): it picks a calculation
# item, which every measure guard allows
ALLOWED_KPI_PAGE_SLICERS = {BRANCH_NAME, MONTH_PICK, AREA, TIME_CALC}
# User decision 2026-11-03: Head Office everywhere. The report's branches are the eight hospitals and Head Office
# (100); the dimension's synthetic Group member (0) has no HR data and is kept out of the slicer and the pages.
BRANCH_KEY = col("Branch", "Branch Key")
HEAD_OFFICE = 100
BRANCHES = (BRANCH_KEY, "in", [1, 2, 3, 4, 5, 6, 7, 8, HEAD_OFFICE])


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

def test_filters_branch_and_month_dropdowns():
    """The Branch slicer lists the eight hospitals and Head Office (user decision 2026-11-03), not the Group member."""
    branch, month = filters()
    assert branch.sample == month.sample == "slicerDropdown"
    assert branch.roles == {"Values": [BRANCH_NAME]} and month.roles == {"Values": [MONTH_PICK]}
    assert [(f.field, f.op, f.values) for f in branch.filters] == [BRANCHES]
    assert branch.labels == {BRANCH_NAME: "Branch"} and month.labels == {MONTH_PICK: "Month"}
    for v in (branch, month):  # inside the filter bar, left of the help buttons
        assert frame.FILTER_BAR[1] <= v.y and v.y + v.h <= frame.FILTER_BAR[1] + frame.FILTER_BAR[3]
        assert v.x + v.w < HELP[0][2][0]


def test_month_slicer_single_select_on_last_closed_month():
    """R21: Month is a single-select dropdown on 'Date'[Month Pick] saved on "Last closed month" (the model relabels
    the previous month every day), so Home opens on one month, the one HR Story Home describes."""
    _hospital, month = filters()
    selection = month.props["selection"][0]["properties"]
    assert selection["singleSelect"]["expr"]["Literal"]["Value"] == "true"
    assert selection["selectAllCheckboxEnabled"]["expr"]["Literal"]["Value"] == "false"
    page = PAGES[0]
    i = next(i for i, v in enumerate(page.visuals) if v.sample == "slicerDropdown" and MONTH_PICK in v.roles["Values"])
    objects = pbir.visual_json(page, page.visuals[i], i, "")["visual"]["objects"]
    flt = objects["general"][0]["properties"]["filter"]["filter"]
    assert flt["From"] == [{"Name": "d", "Entity": "Date", "Type": 0}]
    cond = flt["Where"][0]["Condition"]["In"]
    assert cond["Expressions"] == [{"Column": {"Expression": {"SourceRef": {"Source": "d"}}, "Property": "Month Pick"}}]
    assert cond["Values"] == [[{"Literal": {"Value": "'Last closed month'"}}]]
    assert objects["data"] == [{"properties": {"mode": {"expr": {"Literal": {"Value": "'Dropdown'"}}}}}]


def test_home_figures_are_pay_aware_text():
    """R22: users without pay access read "Requires pay access", never "(Blank)": every tile's figure is
    [HR KPI Actual Text], the Payroll and Productivity area cards the text measures."""
    vs = home().visuals
    bound = [f for v in vs for f in v.roles.get("Values", [])]
    assert meas("HR KPI Actual") not in bound
    assert bound.count(meas("HR KPI Actual Text")) == 8
    for measure in ("Payroll Cost", "Visits per FTE"):
        assert meas(measure) not in bound
    for measure in ("HR Payroll Cost Text", "HR Visits per FTE Text"):
        assert bound.count(meas(measure)) == 1
    # the Recruitment area card says why there is no vacancy rate (no budgeted FTE) instead of "(Blank)"
    assert meas("BSC Vacancy Rate") not in bound and bound.count(meas("HR Vacancy Rate Text")) == 1


def test_slicers_sync_across_pages():
    page = PAGES[0]
    groups = []
    for i, v in enumerate(page.visuals):
        if v.sample == "slicerDropdown":
            groups.append(pbir.visual_json(page, v, i, "")["visual"]["syncGroup"])
    assert [g["groupName"] for g in groups] == ["bsc Branch.Branch Name", "bsc Date.Month Pick"]
    assert all(g["fieldChanges"] and g["filterChanges"] for g in groups)


def test_kpi_tile():
    vs = kpi_tile("HR_TURNOVER", 30, 300, 447, 236)
    panel, cards, decor = vs[0], vs[1:4], vs[4:]
    # the KPI's icon, top right on the panel, drawn after the cards (user request 2026-11-04)
    assert [v.sample for v in decor] == ["image"]
    assert panel.x + panel.w / 2 < decor[0].x and decor[0].x + decor[0].w <= panel.x + panel.w
    assert panel.y <= decor[0].y and decor[0].y + decor[0].h <= panel.y + panel.h
    assert panel.sample == "panel" and (panel.x, panel.y, panel.w, panel.h) == (30, 300, 447, 236)
    assert [c.sample for c in cards] == ["card"] * 3
    assert [c.roles["Values"] for c in cards] == [[meas("HR KPI Actual Text")], [meas("HR KPI Target Text")],
                                                  [meas("HR KPI Status Text")]]
    for c in cards:  # the KPI only: the page filter keeps the branches (Head Office included, 2026-11-03)
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


def test_seed_parser_standard_escapes(tmp_path):
    """ClickHouse string escapes: \\n, \\t, \\r, \\0, \\\\ and \\' (any other \\x is x)."""
    sql = tmp_path / "seed.sql"
    sql.write_text(r"INSERT INTO default.map_hr_kpi (kpi_code, short_label) VALUES "
                   r"('A', 'one\ntwo\tthree\r \\ back \' q \0 nul \% x');", encoding="utf-8")
    assert seed_kpis(sql)[0]["short_label"] == "one\ntwo\tthree\r \\ back ' q \x00 nul % x"


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
    assert "bookmarks" not in json.dumps(report)
    # report-level measures would be written to definition/reportExtensions.json
    assert not any("reportExtensions" in k for k in files)


def _branch_key_filters(page_json):
    return [f for f in page_json.get("filterConfig", {}).get("filters", [])
            if f.get("field") == {"Column": {"Expression": {"SourceRef": {"Entity": "Branch"}}, "Property": "Branch Key"}}]


def test_branch_page_filter_locked_in_view_mode():
    """Minor 3e of the Head Office review: the branches page filter is locked in view mode (as the BSC's report-level
    filter, `isLockedInViewMode`), so a reader cannot clear it and bring in the Group member; no other filter is."""
    from hr_frame import lock_branch_filters
    files = pbir.project_files(PAGES, "HNH_Analytics_Test", report_filters=REPORT_FILTERS, report=HR_REPORT)
    files = lock_branch_filters(files)
    seen = 0
    for page in PAGES:
        pj = json.loads(files[f"HNH Workforce.Report/definition/pages/{page.name}/page.json"].decode("utf-8"))
        branch = _branch_key_filters(pj)
        assert len(branch) == (1 if page.filters else 0), page.name
        for f in pj.get("filterConfig", {}).get("filters", []):
            assert f.get("isLockedInViewMode", False) is (f in branch), (page.name, f["name"])
        seen += len(branch)
    assert seen == len([p for p in PAGES if p.filters]) >= 12


def test_committed_project_has_the_branch_filter_locked():
    """build.py writes the lock (the written project is what pbir_to_pbix converts)."""
    root = Path(__file__).resolve().parents[1] / "HNH Workforce.Report" / "definition" / "pages"
    for page in PAGES:
        pj = json.loads((root / page.name / "page.json").read_text(encoding="utf-8"))
        assert all(f.get("isLockedInViewMode") is True for f in _branch_key_filters(pj)), page.name
        assert len(_branch_key_filters(pj)) == (1 if page.filters else 0), page.name


def test_no_visual_groups_or_bookmarks_in_pages():
    files = pbir.project_files(PAGES, "HNH_Analytics_Test", report_filters=REPORT_FILTERS, report=HR_REPORT)
    for k, b in files.items():
        if k.endswith("visual.json"):
            assert "visualGroup" not in json.loads(b.decode("utf-8")), k
    assert not any("bookmarks" in k for k in files)


# ---- Story -------------------------------------------------------------------------------------------------------

STORY_MEASURES = ["HR Story Size", "HR Story Flow", "HR Story Cost", "HR Story Absence", "HR Story Saudization",
                  "HR Story Hiring"]
STORY_TILES = ["HR_HEADCOUNT", "HR_TURNOVER", "HR_STAFF_COST_PER_FTE", "HR_SICK_LEAVE_RATE", "HR_SAUDIZATION",
               "HR_VACANCY_RATE"]
STORY_CHARTS = [["Headcount", "FTE"], ["BSC Turnover"], ["Payroll Cost"], ["Sick Leave Rate %"],
                ["BSC Saudization"], ["BSC Vacancy Rate"]]


def story():
    return next(p for p in PAGES if p.name == "story")


def _on(page, measure_name):
    return [v for v in page.visuals if meas(measure_name) in v.roles.get("Values", [])]


def test_story_block_order():
    page = story()
    ys = []
    for name in STORY_MEASURES:
        found = _on(page, name)
        assert len(found) == 1, name
        assert found[0].sample == "card" and found[0].w == round(1860 * 0.4)  # 40 %, left
        ys.append(found[0].y)
    assert ys == sorted(ys) and len(set(ys)) == 6  # Size < Flow < Cost < Absence < Saudization < Hiring
    heading = _on(page, "HR Story Month")
    assert len(heading) == 1 and heading[0].y < ys[0]


def test_story_blocks_hold_chart_and_tile():
    page = story()
    sentences = [_on(page, n)[0] for n in STORY_MEASURES]
    charts = [v for v in page.visuals if v.sample == "lineChart"]
    assert [[f.name for f in c.roles["Y"]] for c in charts] == STORY_CHARTS
    assert [c.y for c in charts] == [s.y for s in sentences]
    assert kpi_codes(page.visuals) == STORY_TILES
    for c in charts:
        assert c.roles["Category"] == [col("Date", "Year Month Name")] and c.sort_dir == "asc"
        assert all(f.kind == "measure" for f in c.roles["Y"])


def test_story_page_is_tall_and_inside_its_height():
    from pages_story import STORY_H as story_h
    assert story().height == story_h > 1080
    assert max(v.y + v.h for v in story().visuals) <= story_h


def test_story_vacancy_chart_carries_the_vacancy_note():
    """The Hiring block's vacancy chart is empty while no budgeted FTE is loaded: [HR Vacancy Note] says so over it."""
    page = story()
    (chart,) = [v for v in page.visuals if v.sample == "lineChart" and meas("BSC Vacancy Rate") in v.roles["Y"]]
    notes = _on(page, "HR Vacancy Note")
    assert len(notes) == 1 and notes[0].filters == []
    assert chart.x <= notes[0].x and chart.y <= notes[0].y and notes[0].y + notes[0].h <= chart.y + chart.h
    assert page.visuals.index(notes[0]) > page.visuals.index(chart)


def test_story_charts_show_twelve_closed_months_whatever_the_month_slicer_says():
    page = story()
    charts = [v for v in page.visuals if v.sample == "lineChart"]
    offset = col("Date", "Month Offset")
    for c in charts:
        assert [(f.field, f.op, f.values) for f in c.filters] == [(offset, "in", list(range(1, 13)))]
    month = next(v for v in page.visuals if v.sample == "slicerDropdown" and v.roles["Values"] == [MONTH_PICK])
    from model import interaction_indexes
    idx = {(s, t): k for s, t, k in interaction_indexes(page)}
    month_i = next(i for i, v in enumerate(page.visuals) if v is month)
    for c in charts:
        ci = next(i for i, v in enumerate(page.visuals) if v is c)
        assert idx[(month_i, ci)] == "NoFilter"


def test_story_cost_pay_notice_and_slicers():
    page = story()
    notice = _on(page, "HR Pay Notice")
    assert len(notice) == 1
    cost = next(v for v in page.visuals if v.sample == "lineChart" and meas("Payroll Cost") in v.roles["Y"])
    assert cost.x <= notice[0].x and notice[0].y >= cost.y and notice[0].y + notice[0].h <= cost.y + cost.h
    # [HR Pay Notice] is "" for a pay reader: the card shows nothing. A card filtered to no row prints "(Blank)"
    # (the 2026-11-03 screenshots), so the notice card has no filter
    assert notice[0].filters == []
    slicers = {v.roles["Values"][0] for v in page.visuals if v.sample.startswith("slicer")}
    assert slicers == {BRANCH_NAME, MONTH_PICK}  # R13 / R18
    month = next(v for v in page.visuals if v.sample == "slicerDropdown" and v.roles["Values"] == [MONTH_PICK])
    assert month.props["selection"][0]["properties"]["singleSelect"]


# ---- Scorecard and KPI detail ------------------------------------------------------------------------------------

def _page(name):
    return next(p for p in PAGES if p.name == name)


def _flt(v):
    return [(f.field, f.op, f.values) for f in v.filters]


def test_scorecard_filters_kind_kpi():
    page = _page("scorecard")
    assert not page.hidden and page.display == "Scorecard"
    table = next(v for v in page.visuals if v.sample == "table")
    matrix = next(v for v in page.visuals if v.sample == "matrix")
    for v in (table, matrix):
        assert ((col("HR KPI", "Kind"), "in", ["kpi"]) in _flt(v)
                or (col("HR KPI", "Kind"), "eq", ["kpi"]) in _flt(v))
        assert (col("HR KPI", "Status"), "in", ["active"]) in _flt(v) or             (col("HR KPI", "Status"), "eq", ["active"]) in _flt(v)
    # sorted by Display Order; text measures for the cells every user sees (R22), so a reader without pay access
    # reads "Requires pay access" in a pay KPI's actual, target, variance and watch cells (final review C1, I4, M2)
    assert table.sort == col("HR KPI", "Display Order") and table.sort_dir == "asc"
    values = table.roles["Values"]
    assert meas("HR KPI Actual Text") in values and meas("HR KPI Actual") not in values
    assert meas("HR KPI Target Text") in values and meas("HR KPI Status Text") in values
    assert meas("HR KPI Variance Text") in values and meas("HR KPI Watch Text") in values
    assert not {meas("HR KPI Target"), meas("HR KPI Watch"), meas("HR KPI Variance")} & set(values)
    order = [f.name for f in values]
    assert (order.index("HR KPI Actual Text") < order.index("HR KPI Target Text") < order.index("HR KPI Variance Text")
            < order.index("HR KPI Watch Text"))
    assert table.labels[meas("HR KPI Variance Text")] == "Variance" and table.labels[meas("HR KPI Watch Text")] == "Watch at"
    # every measure column has a header label (the screenshots showed "HR KPI Status Text": no label was given)
    assert {table.labels[meas(m)] for m in ("HR KPI Status Text", "HR KPI Actual Text", "HR KPI Target Text")} == {
        "Status", "Actual", "Target"}
    assert all(f in table.labels for f in values if f.kind == "measure")
    # the drill-through field is the KPI name, a column of the table and of the matrix: no KPI Code column
    assert col("HR KPI", "KPI Code") not in values and col("HR KPI", "KPI Name") in values
    assert col("HR KPI", "KPI Name") in matrix.roles["Rows"]
    _assert_fixed_columns(table, min_font=11)
    assert matrix.roles["Values"] == [meas("HR KPI Status Text")] and matrix.roles["Columns"] == [BRANCH_NAME]
    # status cells are coloured by [HR KPI Status Colour]
    for v in (table, matrix):
        fc = [e for e in v.props["values"] if "fontColor" in e["properties"]]
        assert STATUS_COLOUR.name in json.dumps(fc) and "HR KPI Status Text" in fc[0]["selector"]["metadata"]
    assert {v.roles["Values"][0] for v in page.visuals if v.sample.startswith("slicer")} == ALLOWED_KPI_PAGE_SLICERS
    drill = [v for v in page.visuals if v.sample == "buttonDrill"]
    assert len(drill) == 1
    assert "kpi_detail" in json.dumps(drill[0].props)


def _assert_fixed_columns(table, min_font):
    """A table that fits its width: fixed column widths for every field (no autosize), wrapped text, a readable
    font, no total row."""
    props = table.props
    headers = props["columnHeaders"][0]["properties"]
    assert headers["autoSizeColumnWidth"]["expr"]["Literal"]["Value"] == "false"
    assert headers["columnAdjustment"]["expr"]["Literal"]["Value"] == "'fixedWidth'"
    widths = {e["selector"]["metadata"]: float(e["properties"]["value"]["expr"]["Literal"]["Value"].rstrip("D"))
              for e in props["columnWidth"]}
    fields = [f for fs in table.roles.values() for f in fs]
    assert set(widths) == {f.ref for f in fields}
    assert sum(widths.values()) <= table.w - 30  # the vertical scroll bar and the cell padding
    assert any("wordWrap" in e["properties"] for e in props["values"])
    sizes = [float(e["properties"]["fontSize"]["expr"]["Literal"]["Value"].rstrip("D"))
             for e in props["values"] + props["columnHeaders"] if "fontSize" in e["properties"]]
    assert len(sizes) == 2 and min(sizes) >= min_font
    assert props["total"][0]["properties"]["totals"]["expr"]["Literal"]["Value"] == "false"
    # text measures are left-aligned like the text columns (a measure column is right-aligned by default)
    left = {e["selector"]["metadata"] for e in props.get("columnFormatting", [])
            if e["properties"]["alignment"]["expr"]["Literal"]["Value"] == "'Left'"}
    assert {f.ref for f in fields if f.kind == "measure"} <= left


def test_kpi_detail_is_drillthrough_on_name():
    page = _page("kpi_detail")
    assert page.hidden and page.drill_fields == [col("HR KPI", "KPI Name")] and not page.keep_filters
    assert page.display == "KPI detail" and page.name == "kpi_detail"
    vs = page.visuals
    # a Back button, and the frame without a current tab
    assert any(v.sample == "buttonNavigate" and "Back" in json.dumps(v.props) for v in vs)
    assert not any(v.sample == "buttonNavigate" and nav_target(v) in TAB_NAMES and
                   "primary" in json.dumps(v.props) for v in vs)
    # definition panel: the definition is [HR KPI Definition Text], which says how to pick a KPI when the page is
    # opened without a drill-through; the heading is [HR KPI Detail Title] (the KPI name, or the same prompt)
    defs = {v.roles["Values"][0].name for v in vs if v.sample == "card" and v.roles["Values"][0].table == "HR KPI"}
    assert {"Formula", "Source System", "Grain", "Caveats"} <= defs
    for m in ("HR KPI Definition Text", "HR KPI Detail Title"):
        assert len(_on(page, m)) == 1, m
    title = _on(page, "HR KPI Detail Title")[0]
    assert (title.x, title.y) == (frame.CONTENT[0], frame.CONTENT[1])
    # cards for actual (text), target, status
    for m in ("HR KPI Actual Text", "HR KPI Target Text", "HR KPI Status Text"):
        assert len(_on(page, m)) == 1, m
    # the 24-month line: actual against target and watch, last 24 closed months whatever the Month slicer says
    line = next(v for v in vs if v.sample == "lineChart")
    assert line.roles["Y"] == [meas("HR KPI Actual"), meas("HR KPI Target"), meas("HR KPI Watch")]
    assert _flt(line) == [(col("Date", "Month Offset"), "in", list(range(1, 25)))]
    from model import interaction_indexes
    idx = {(s, t): k for s, t, k in interaction_indexes(page)}
    month = next(i for i, v in enumerate(vs) if v.sample == "slicerDropdown" and v.roles["Values"] == [MONTH_PICK])
    assert idx[(month, next(i for i, v in enumerate(vs) if v is line))] == "NoFilter"
    # the bar by hospital
    bar = next(v for v in vs if v.sample == "barChart")
    assert bar.roles["Category"] == [BRANCH_NAME] and bar.roles["Y"] == [meas("HR KPI Actual")]
    assert {v.roles["Values"][0] for v in vs if v.sample.startswith("slicer")} == {BRANCH_NAME, MONTH_PICK, TIME_CALC}


def test_scorecard_and_kpi_detail_are_registered():
    names = [p.name for p in PAGES]
    assert names[:4] == ["home", "story", "scorecard", "kpi_detail"]


def test_kpi_detail_charts_have_a_pay_notice():
    """Final review I2: the notice is [HR KPI Pay Notice], which reads the drilled KPI's needs_pay: a reader without
    pay access sees it over the charts of a pay KPI only (Turnover's charts stay clear)."""
    page = _page("kpi_detail")
    assert _on(page, "HR Pay Notice") == []
    notices = _on(page, "HR KPI Pay Notice")
    assert len(notices) == 2 and all(n.filters == [] for n in notices)  # "" for a pay reader: an empty card
    for chart in (next(v for v in page.visuals if v.sample == "lineChart"),
                  next(v for v in page.visuals if v.sample == "barChart")):
        assert any(_in_title_band(n, chart) for n in notices)  # ruling R31


def _period(page):
    return [v for v in page.visuals if v.sample.startswith("slicer") and v.roles["Values"] == [TIME_CALC]]


def test_period_slicer_on_scorecard_and_kpi_detail_only():
    """Final review I3: a single-select Period dropdown on 'Time Calculation', saved on Current, offering the items
    that make sense for a KPI against its target; on Scorecard and KPI detail only (its sync group is its field, so
    the two pages share it). Story stays on one month (R18)."""
    with_period = [p.name for p in PAGES if _period(p)]
    assert with_period == ["scorecard", "kpi_detail"]
    for name in with_period:
        page = _page(name)
        (period,) = _period(page)
        assert period.sample == "slicerDropdown" and period.labels == {TIME_CALC: "Period"}
        selection = period.props["selection"][0]["properties"]
        assert lit(selection["singleSelect"]) == "true" and lit(selection["selectAllCheckboxEnabled"]) == "false"
        assert _flt(period) == [(TIME_CALC, "in", ["Current", "QTD", "YTD"])]
        i = _index(page, period)
        out = pbir.visual_json(page, period, i, "")["visual"]
        cond = out["objects"]["general"][0]["properties"]["filter"]["filter"]["Where"][0]["Condition"]["In"]
        assert cond["Values"] == [[{"Literal": {"Value": "'Current'"}}]]
        assert cond["Expressions"][0]["Column"]["Property"] == "Time Calculation"
        assert out["syncGroup"]["groupName"] == "bsc Time Calculation.Time Calculation"
        # in the filter bar, clear of the other slicers and buttons there, left of the help buttons
        assert frame.FILTER_BAR[1] <= period.y and period.y + period.h <= frame.FILTER_BAR[1] + frame.FILTER_BAR[3]
        assert period.x + period.w < HELP[0][2][0]
        for v in page.visuals:
            if v is not period and v.y < frame.FILTER_BAR[1] + frame.FILTER_BAR[3] and v.y + v.h > frame.FILTER_BAR[1]:
                if v.x >= frame.CONTENT[0] and v.x + v.w <= HELP[0][2][0] and v.sample != "panel":
                    assert v.x + v.w <= period.x or period.x + period.w <= v.x, (name, v.sample)
    assert not _period(story())


def test_kpi_detail_trend_ignores_the_period():
    """The 24-month line stays a monthly trend whatever Period says (NoFilter); the cards and the bar follow it."""
    from model import interaction_indexes
    page = _page("kpi_detail")
    idx = {(s, t): k for s, t, k in interaction_indexes(page)}
    (period,) = _period(page)
    line = next(v for v in page.visuals if v.sample == "lineChart")
    bar = next(v for v in page.visuals if v.sample == "barChart")
    assert idx[(_index(page, period), _index(page, line))] == "NoFilter"
    assert (_index(page, period), _index(page, bar)) not in idx


# The Guide pages hold text and the KPI definitions: no branch page filter.
GUIDE_PAGES = {"guide", "guide_definitions"}


def test_no_page_filters_out_head_office():
    """User decision 2026-11-03 (supersedes final review I1): Head Office is on every page. No page, visual or report
    filter is on 'Branch'[Is Hospital]; every filter on Branch keeps Head Office (100); every data page carries the
    branches filter (the hospitals and Head Office), which keeps out only the Group member (0), a synthetic row of
    the dimension with no HR data."""
    branch_tables = {"Branch"}
    assert [f for f in REPORT_FILTERS if f.field.table in branch_tables] == []
    for page in PAGES:
        filters_here = [(page.name, f) for f in page.filters]
        filters_here += [(f"{page.name}/{v.sample}/{v.title}", f) for v in page.visuals for f in v.filters]
        for where, f in filters_here:
            assert f.field != IS_HOSPITAL, where
            if f.field.table in branch_tables:
                assert (f.field, f.op, f.values) == BRANCHES, where
                assert HEAD_OFFICE in f.values and 0 not in f.values, where
        if page.name not in GUIDE_PAGES:
            assert BRANCHES in [(f.field, f.op, f.values) for f in page.filters], page.name


def test_branch_wording():
    """Head Office is a branch, not a hospital: no visual title or field label says "hospital"; the Branch slicer
    is labelled Branch on every page."""
    for page in PAGES:
        for v in page.visuals:
            assert "hospital" not in (v.title or "").lower(), (page.name, v.title)
            for label in v.labels.values():
                assert "hospital" not in label.lower(), (page.name, v.title, label)
            if v.sample.startswith("slicer") and v.roles["Values"] == [BRANCH_NAME]:
                assert v.labels == {BRANCH_NAME: "Branch"}, page.name


def _string_literals(dax):
    """The DAX text literals of an expression, guard messages ("... can't be analysed by ") left out."""
    import re
    return [s.replace('""', '"') for s in re.findall(r'"((?:[^"]|"")*)"', dax) if "can't be analysed by" not in s]


def test_branch_wording_in_measure_texts_and_seed():
    """Minor 3c of the Head Office review: the text a reader sees from the model says branch where Head Office is
    included. No text literal of a measure on the HR pages or in the HR Dashboard folders says "hospital" (KPI
    detail's placeholder said "trend, hospitals and definition"), and no KPI's Grain or definition in
    hr_config_seed.sql does ("Hospital, month", "per hospital"), but turnover's factual "hospitals 1 to 5 / 6 to 8"."""
    import re
    import sys as _sys
    _sys.path.insert(0, str(Path(MODEL_DIR).parents[0] / "tools"))
    import hnh_tmdl
    measures = {m.name: m for m in hnh_tmdl.measures((Path(MODEL_DIR) / "tables" / "_Measures.tmdl")
                                                     .read_text(encoding="utf-8-sig"))}
    used = {f.name for p in PAGES for f in page_fields(p) if f.kind == "measure"}
    hr = {n for n, m in measures.items() if (m.folder or "").startswith("HR Dashboard")}
    assert "HR KPI Definition Text" in used | hr and len(hr) > 40
    for name in sorted(used | hr):
        for text in _string_literals(measures[name].expression):
            assert "hospital" not in text.lower(), (name, text)
    seed = seed_kpis()
    assert len(seed) >= 33
    for row in seed:
        for column in ("grain", "definition"):
            text = re.sub(r"hospitals \d to \d", "", str(row[column]))
            assert "hospital" not in text.lower(), (row["kpi_code"], column, row[column])


# Long lists get a search box in their dropdown (Desktop's slicer "Search": objects.general selfFilterEnabled)
SEARCH_SLICERS = {col("HR Department", "Department Base Name"), col("Job", "Job Name"), col("Grade", "Grade Name"),
                  col("Employee", "Nationality")}


def _search_on(v):
    return any(e["properties"].get("selfFilterEnabled", {}).get("expr", {}).get("Literal", {}).get("Value") == "true"
               for e in v.props.get("general", []))


def test_long_slicers_have_a_search_box():
    """The Department slicer lists about 270 prefix-free names (screens fix): it, Job, Grade and Nationality have
    the dropdown's search box; the short lists (Branch, Month, Worker type, Area, Period) do not."""
    seen = set()
    for page in PAGES:
        for i, v in enumerate(page.visuals):
            if not v.sample.startswith("slicer"):
                continue
            field = v.roles["Values"][0]
            assert _search_on(v) == (field in SEARCH_SLICERS), (page.name, field)
            if field in SEARCH_SLICERS:
                seen.add(field)
                general = pbir.visual_json(page, v, i, "")["visual"]["objects"]["general"]
                assert general == [{"properties": {"selfFilterEnabled": {"expr": {"Literal": {"Value": "true"}}}}}]
    assert seen == SEARCH_SLICERS


# ---- Detail pages and Employee list ------------------------------------------------------------------------------

HEADCOUNT = meas("Headcount")
PAY_NOTICE = meas("HR Pay Notice")
DEPARTMENT_NAME = col("HR Department", "Department Name")
DEPARTMENT_BASE = col("HR Department", "Department Base Name")
POSITION_BASE = col("Position", "Position Base Name")
# The measures that read pay-gated tables (Payroll through 'Pay Category', 'Leave Balances', 'Staff Productivity')
# on the pay pages and Absence & leave each such visual has an HR Pay Notice over it
PAY_FIELDS = {meas(m) for m in ("Payroll Cost", "Gross Pay", "Gross Pay (Open Payroll)", "Overtime Share %",
                                "Payroll Cost per FTE", "Leave Balance (days)", "Leave Liability", "Visits per FTE",
                                "Revenue per Payroll SAR", "Payroll Cost per Visit", "Current Leave Balance (days)",
                                "Current Leave Liability", "Average Leave Balance (days)")}
FUSION_LEAVER_MEASURES = {"Leavers", "Voluntary Leavers", "Involuntary Leavers", "Voluntary Turnover Rate %",
                          "New Hire Turnover %"}


def _detail_pages():
    return [_page(n) for n in DETAIL_NAMES]


def _index(page, visual):
    return next(i for i, v in enumerate(page.visuals) if v is visual)


def _month_slicer(page):
    return next(v for v in page.visuals if v.sample == "slicerDropdown" and v.roles["Values"] == [MONTH_PICK])


def _measures(v):
    return [f for fs in v.roles.values() for f in fs if f.kind == "measure"]


NOTES = {PAY_NOTICE, meas("HR Vacancy Note")}  # text cards over a visual ("" when there is nothing to say)
CHARTS = ("lineChart", "barChart", "stackedColumnChart", "waterfallChart")
MONEY = {"Gross Pay", "Payroll Cost", "Employer Charges", "Gross Pay (Open Payroll)", "Leave Liability",
         "Current Leave Liability"}


def _data_visuals(page):
    """Cards, charts and tables that show a measure other than a note (the pay notice, the vacancy note)."""
    return [v for v in page.visuals if v.sample in ("card", "table", "matrix") + CHARTS
            and any(m not in NOTES for m in _measures(v))]


def _columns(v):
    return [f for fs in v.roles.values() for f in fs if f.kind == "column"] + [
        f.field for f in v.filters if f.field.kind == "column"]


def _covers(notice, v):
    """The notice lies over the visual: inside it vertically, overlapping it horizontally."""
    return notice.x < v.x + v.w and v.x < notice.x + notice.w and v.y <= notice.y and notice.y + notice.h <= v.y + v.h


def _in_title_band(notice, chart):
    """Ruling R31: the notice lies in the chart's title strip (the top TITLE_BAND_H px, the title's row), right of the
    title's text and inside the chart's right edge, so the plot area below stays free for hover and selection."""
    from hr_frame import TITLE_BAND_H, title_text_width
    return (chart.title is not None and chart.y <= notice.y and notice.y + notice.h <= chart.y + TITLE_BAND_H
            and notice.x >= chart.x + title_text_width(chart.title) and notice.x + notice.w <= chart.x + chart.w)


NOTICE_MEASURES = {"HR Pay Notice", "HR KPI Pay Notice", "HR Vacancy Note"}


def test_chart_notices_sit_in_the_title_band():
    """Ruling R31: a notice over a chart or table ([HR Pay Notice], [HR KPI Pay Notice], [HR Vacancy Note]) sits in
    that visual's title band, right-aligned, in a small font, drawn after it; it never reaches the plot area of any
    titled visual, so tooltips and cross-highlighting on the chart work. Notices over a run of cards (no title) stay
    over the cards."""
    from hr_frame import NOTICE_PT, TITLE_BAND_H, notice_text_width
    seen = 0
    for page in PAGES:
        titled = [v for v in page.visuals if v.sample in CHARTS + ("table", "matrix")]
        cards = [v for v in page.visuals if v.sample == "card" and not set(m.name for m in _measures(v)) & NOTICE_MEASURES]
        for n in (v for v in page.visuals if v.sample == "card" and {m.name for m in _measures(v)} & NOTICE_MEASURES):
            under = [c for c in titled if _overlaps(n, c)]
            if not under:  # a notice over a run of pay cards
                assert any(_overlaps(n, c) for c in cards), (page.name, n)
                continue
            seen += 1
            assert len(under) == 1 and _in_title_band(n, under[0]), (page.name, under[0].title, n)
            assert _index(page, n) > _index(page, under[0]), (page.name, under[0].title)
            assert n.y + n.h <= under[0].y + TITLE_BAND_H  # never over the plot area
            assert lit(n.props["labels"][0]["properties"]["fontSize"]) == f"{NOTICE_PT}D" and NOTICE_PT <= 10
            assert n.w >= notice_text_width(_measures(n)[0].name), (page.name, under[0].title)
            assert n.filters == []
            assert n.x + n.w >= under[0].x + under[0].w - 16  # right-aligned in the strip
    assert seen >= 10


def _overlaps(a, b):
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h


def test_detail_pages_have_sub_tabs():
    """The six detail pages, registered after KPI detail, each in the frame with the Details tab current, the six
    sub-tabs (its own filled) and the shared Hospital and Month slicers in the filter bar."""
    from hr_frame import page_frame
    names = [p.name for p in PAGES]
    assert names[4:10] == DETAIL_NAMES
    for (name, display, _label), page in zip(DETAIL_PAGES, _detail_pages()):
        assert page.display == display and not page.hidden
        for v in page_frame("headcount", filters() + sub_tabs(name)):
            assert v in page.visuals, name


SIZED_BY_N = {"Changes by kind and branch"}  # a spec's n: fewer bars than the axis has (a month's changes)


def test_detail_pages_cards_then_charts_that_fit():
    """Each section: one or two rows of 3 to 5 cards, then its charts below them. User request 2026-11-04: a bar chart
    is as high as its bars and labels need (chart_height: the axis's count of bars, or the top 15), line, column and
    waterfall charts LINE_H; no two data visuals overlap and every one is on the page."""
    from pages_detail import AXIS_COUNTS, BAR_CHROME, BAR_LEGEND_H, BAR_MIN_H, BAR_SERIES_PX, LINE_H, TOP
    for page in _detail_pages():
        data = _data_visuals(page)
        cards = [v for v in data if v.sample == "card"]
        rows = sorted({c.y for c in cards})
        assert all(3 <= len([c for c in cards if c.y == y]) <= 5 or y != rows[0] for y in rows), page.name
        for i, a in enumerate(data):
            assert a.y + a.h <= page.height, (page.name, a.title)
            for b in data[i + 1:]:
                assert not _overlaps(a, b), (page.name, a.title, b.title)
        for v in data:
            if v.sample == "barChart":
                k = len(v.roles["Y"])
                by = v.roles["Category"][0]
                n = TOP if v.top_n else AXIS_COUNTS.get(by)
                if n is not None and v.title not in SIZED_BY_N:
                    want = max(BAR_MIN_H, BAR_CHROME + (BAR_LEGEND_H if k > 1 else 0) + n * (8 + BAR_SERIES_PX * k))
                    assert v.h == want, (page.name, v.title, v.h, want)
            elif v.sample in ("lineChart", "stackedColumnChart", "waterfallChart"):
                assert v.h == LINE_H, (page.name, v.title)


def test_chart_format_labels_markers_no_value_axis():
    """User request 2026-11-04: every chart shows its data labels (and a line chart its markers) and no value axis or
    gridlines (the Y axis of line and column charts, the X axis of bar charts); a bar chart's category labels may take
    40 % of its width."""
    seen = set()
    for page in PAGES:
        for v in page.visuals:
            if v.sample not in CHARTS:
                continue
            seen.add(v.sample)
            assert lit(v.props["labels"][0]["properties"]["show"]) == "true", (page.name, v.title)
            axis = v.props["valueAxis"][0]["properties"]
            assert lit(axis["show"]) == "false" and lit(axis["gridlineShow"]) == "false", (page.name, v.title)
            if v.sample == "lineChart":
                assert lit(v.props["markers"][0]["properties"]["show"]) == "true", (page.name, v.title)
            if v.sample == "barChart":
                margin = v.props["categoryAxis"][0]["properties"]["maxMarginFactor"]
                assert margin == {"expr": {"Literal": {"Value": "40L"}}}, (page.name, v.title)
            # SAR amounts in millions ("0.4M", not "0M"); other bars as their format has them (13, not "0.0K")
            units = v.props["labels"][0]["properties"].get("labelDisplayUnits")
            names = {m.name for m in _measures(v)}
            if page.name in DETAIL_NAMES and v.sample != "lineChart" and names <= MONEY:
                assert lit(units) == "1000000D", (page.name, v.title)
            elif v.sample == "barChart":
                assert lit(units) == "1D", (page.name, v.title)
    assert seen == set(CHARTS)


def test_cards_carry_icons():
    """User request 2026-11-04: the cards have decorative icons (icons/hr_icon_*.svg, registered with the report): every
    KPI tile, every detail-page card, the Home area cards and the data quality cards; each icon is drawn after the
    card it sits on and lies inside it."""
    from hr_frame import ICON_FILES
    registered = {i.name for i in HR_REPORT.images}
    assert registered == {f.name for f in ICON_FILES} and len(registered) >= 20
    report = pbir.report_json(None, report=HR_REPORT)
    items = {i["name"] for pkg in report["resourcePackages"] if pkg["name"] == "RegisteredResources"
             for i in pkg["items"] if i["type"] == "Image"}
    assert registered <= items
    for name in ["home", "story", "data_quality"] + DETAIL_NAMES:
        page = _page(name)
        images = [v for v in page.visuals if v.sample == "image" and v.w < 100]
        cards = [v for v in _data_visuals(page) if v.sample == "card"]
        if name in DETAIL_NAMES:
            assert len(images) == len(cards), name
        assert images, name
        for im in images:
            host = [c for c in page.visuals if c.sample in ("card", "panel") and c.x <= im.x and im.x + im.w <= c.x + c.w
                    and c.y <= im.y and im.y + im.h <= c.y + c.h]
            assert host and _index(page, im) > min(_index(page, c) for c in host), (name, im)
            file = im.props["image"][0]["properties"]["sourceFile"]["image"]["name"]
            assert lit(file).strip("'") in registered, (name, file)


def test_payroll_page_separates_gross_pay_and_payroll_cost():
    """User request 2026-11-04: Payroll has two sections, gross pay (what employees are paid) and payroll cost (what the
    employer pays), each with its own cards and breakdowns, and the step between them: a waterfall of payroll cost by
    pay group (cost categories only) and gross pay plus employer charges stacked by month."""
    page = _page("payroll")
    headings = [v for v in page.visuals if v.sample == "textbox" and v.y > 162]
    texts = [v.props["general"][0]["properties"]["paragraphs"][0]["textRuns"][0]["value"] for v in headings]
    assert texts == ["Gross pay: what employees are paid", "Payroll cost: what the employer pays"]
    split = headings[1].y
    data = _data_visuals(page)
    gross = {m.name for v in data if v.y < split for m in _measures(v)}
    cost = {m.name for v in data if v.y > split for m in _measures(v)}
    assert {"Gross Pay", "Overtime Share %", "HR Open Payroll Text"} <= gross and "Payroll Cost" not in gross
    assert {"Payroll Cost", "Employer Charges", "Employer Charges Share %", "Payroll Cost per FTE"} <= cost
    fall = next(v for v in data if v.sample == "waterfallChart")
    assert fall.y > split and fall.roles["Category"] == [col("Pay Category", "Pay Group")]
    assert _flt(fall) == [(col("Pay Category", "Is Cost"), "eq", ["Yes"])]
    stack = next(v for v in data if v.sample == "stackedColumnChart")
    assert stack.y > split and [m.name for m in stack.roles["Y"]] == ["Gross Pay", "Employer Charges"]
    open_card = next(v for v in data if v.sample == "card" and meas("HR Open Payroll Text") in _measures(v))
    assert open_card.labels[meas("HR Open Payroll Text")] == "Gross pay in open payroll"  # a text: never "(Blank)"


def test_tall_pages_fit_width_and_scroll():
    """R24: a page taller than 1080 px fits its width (it scrolls); FitToPage would shrink it to one screen."""
    tall = {p.name for p in PAGES if p.height > 1080}
    assert {"story", "headcount", "movements", "absence"} <= tall
    for page in PAGES:
        expected = "FitToWidth" if page.height > 1080 else "FitToPage"
        assert pbir.page_json(page)["displayOption"] == expected, page.name


def test_detail_movements_recruitment_absence_detail():
    """R27: the model's movement, recruitment and absence measures on the detail pages."""
    def bound(name, sample=None):
        return {m.name for v in _page(name).visuals if sample in (None, v.sample) for m in _measures(v)}

    def bars_by(name, column):
        return [{m.name for m in _measures(v)} for v in _page(name).visuals
                if v.sample == "barChart" and v.roles["Category"] == [column]]

    movements = _page("movements").visuals
    assert {"Movements"} in bars_by("movements", col("Worker Action", "Movement Group"))
    assert {"Branch Transfers", "Promotions", "Involuntary Leavers"} <= bound("movements", "card")
    assert any({"Job Changes", "Grade Changes", "Position Changes", "Location Changes"} <= {m.name for m in
                                                                                         _measures(v)}
               for v in movements)
    promotions = next(v for v in movements if v.sample == "card" and meas("Promotions") in _measures(v))
    assert promotions.labels[meas("Promotions")] == "Promotions (Fusion action)"
    assert any(v.title and "current tenure band" in v.title and v.roles["Category"] == [col("Employee", "Tenure Band")]
               for v in movements if v.sample == "barChart")
    recruitment_cards = bound("recruitment", "card")
    assert {"Requisitions Approved", "Requisitions Filled", "Open Openings"} <= recruitment_cards
    assert not {"Hires", "FTE"} & recruitment_cards
    assert any(v.sample == "lineChart" and {m.name for m in _measures(v)} == {"Requisitions Approved",
                                                                              "Requisitions Filled"}
               for v in _page("recruitment").visuals)
    assert {"Open Openings"} in bars_by("recruitment", BRANCH_NAME)
    assert {"Absence Days"} in bars_by("absence", col("Absence Type", "Absence Category"))
    assert {"Absence Days"} in bars_by("absence", col("Absence Type", "Absence Type Name"))
    assert {"Sick Days"} in bars_by("absence", col("Absence Type", "Absence Type Name"))
    assert {"Current Leave Balance (days)", "Current Leave Liability", "Average Leave Balance (days)"} <= bound(
        "absence", "card")
    assert {"Average Headcount", "Average FTE"} <= bound("headcount", "card")
    for name in DETAIL_NAMES:  # the headline measures are BSC Saudization and BSC Turnover
        assert not {"Saudisation Rate %", "Turnover Rate %"} & bound(name), name


def test_detail_cards_follow_month_and_trends_show_twelve_closed_months():
    """Cards follow the selected month; each line chart (and stacked column chart) is a 12-month trend that ignores
    the Month slicer (Story's mechanism); every other data visual follows it."""
    from model import interaction_indexes
    for page in _detail_pages():
        month = _index(page, _month_slicer(page))
        no_filter = {t for s, t, k in interaction_indexes(page) if s == month and k == "NoFilter"}
        lines = [v for v in page.visuals if v.sample in ("lineChart", "stackedColumnChart")]
        assert lines, page.name
        for v in lines:
            assert v.roles["Category"] == [col("Date", "Year Month Name")] and v.sort_dir == "asc"
            assert (col("Date", "Month Offset"), "in", list(range(1, 13))) in _flt(v), page.name
            assert _index(page, v) in no_filter, page.name
        for v in _data_visuals(page):
            if v.sample not in ("lineChart", "stackedColumnChart"):
                assert _index(page, v) not in no_filter, (page.name, v.title)


def test_detail_visuals_never_hit_a_measure_guard():
    """A measure returns "... can't be analysed by <table>" when a table its guard rejects is filtered. On every
    detail page and the Employee list: a visual's own columns (axis, rows, visual filters), every slicer, page filter
    and drill field are tables all its measures accept; a selection in a chart or table does not reach a visual
    whose measures reject one of its tables (a NoFilter interaction)."""
    from model import interaction_indexes
    from pages_detail import blocked_tables
    assert "Pay Category" in blocked_tables("Payroll Cost per FTE")
    assert "Pay Category" not in blocked_tables("Payroll Cost") and blocked_tables("HR Pay Notice") == frozenset()
    for page in _detail_pages() + [_page("employee_list")]:
        slicer_tables = {f.table for v in page.visuals if v.sample.startswith("slicer") for f in v.roles["Values"]}
        slicer_tables |= {f.field.table for f in page.filters} | {f.table for f in page.drill_fields or []}
        no_filter = {(s, t) for s, t, k in interaction_indexes(page) if k == "NoFilter"}
        data = _data_visuals(page)
        for v in data:
            for m in _measures(v):
                assert not blocked_tables(m.name) & ({c.table for c in _columns(v)} | slicer_tables), (
                    page.name, v.title, m.name)
        for source in data:
            tables = {c.table for fs in source.roles.values() for c in fs if c.kind == "column"}
            for target in data:
                if target is not source and any(blocked_tables(m.name) & tables for m in _measures(target)):
                    assert (_index(page, source), _index(page, target)) in no_filter, (
                        page.name, source.title, target.title)


def test_detail_pay_visuals_carry_a_pay_notice():
    """R22: on Payroll, Productivity and Absence & leave, every visual with a pay figure lies under an
    [HR Pay Notice] card (non-blank filter) drawn after it; pay cards are filtered to non-blank, so a reader without
    pay access sees the notice rather than "(Blank)"."""
    for name in ("payroll", "absence", "productivity"):
        page = _page(name)
        notices = [v for v in page.visuals if v.roles.get("Values") == [PAY_NOTICE]]
        assert notices and all(_flt(n) == [] for n in notices), name  # "" for a pay reader: an empty card
        pay = [v for v in _data_visuals(page) if set(_measures(v)) & PAY_FIELDS]
        assert pay, name
        for v in pay:
            over = [n for n in notices if _covers(n, v)]
            assert over and all(_index(page, n) > _index(page, v) for n in over), (name, v.title)
            if v.sample == "card":
                assert (_measures(v)[0], "notblank", []) in _flt(v), (name, v.roles)
    for name in ("headcount", "movements", "recruitment"):
        assert not [v for v in _data_visuals(_page(name)) if set(_measures(v)) & PAY_FIELDS], name


def test_detail_fusion_leaver_figures_say_in_fusion():
    for page in _detail_pages():
        for v in page.visuals:
            for m in _measures(v):
                if m.name in FUSION_LEAVER_MEASURES:
                    assert "in Fusion" in v.labels.get(m, ""), (page.name, v.title, m.name)
    bound = {m.name for v in _page("movements").visuals for m in _measures(v)}
    assert {"Hires", "Leavers", "Voluntary Leavers", "BSC Turnover", "Voluntary Turnover Rate %",
            "New Hire Turnover %"} <= bound
    assert "Turnover Rate %" not in bound  # headline turnover is BSC Turnover


def test_detail_pages_use_underlying_measures_and_spec_breakdowns():
    """No HR KPI measures on detail pages (so their slicers are free, R13); the spec's breakdowns."""
    for page in _detail_pages():
        assert not {m.name for v in page.visuals for m in _measures(v)} & KPI_MEASURES, page.name

    def axes(name):
        return {c for v in _page(name).visuals if v.sample in ("barChart", "table", "matrix")
                for fs in v.roles.values() for c in fs if c.kind == "column"}

    assert {BRANCH_NAME, DEPARTMENT_BASE, col("Job", "Job Name"), col("Grade", "Grade Name"),
            POSITION_BASE, col("Location", "Location Name"), col("Headcount", "Is Saudi"),
            col("Headcount", "Gender"), col("Headcount", "Age Band"), col("Headcount", "Tenure Band"),
            col("Employee", "Worker Type"), col("Job", "Full Part Time")} <= axes("headcount")
    assert {col("Worker Action", "Action Reason Name"), col("Employee", "Tenure Band")} <= axes("movements")
    assert {col("Pay Category", "Pay Category"), DEPARTMENT_BASE, col("Payroll", "Source"),
            col("Payroll", "Payroll Status")} <= axes("payroll")
    assert {col("Absence Type", "Absence Type Name"), BRANCH_NAME} <= axes("absence")
    assert {col("Staff Productivity", "Staff Category"), BRANCH_NAME} <= axes("productivity")
    card_measures = {m.name for v in _page("headcount").visuals if v.sample == "card" for m in _measures(v)}
    assert "Contingent Share %" in card_measures  # contingent workers shown separately


def test_charts_and_slicers_use_prefix_free_names():
    """R30: departments and positions in charts and the Department slicer are prefix-free ("Nursing Department",
    not "RBW Nursing Department"); the prefixed Department Name is only on the Employee list (through a measure)."""
    prefixed = {DEPARTMENT_NAME, col("HR Department", "Unified Department"), col("Position", "Position Name")}
    for page in PAGES:
        assert not prefixed & set(page_fields(page)), page.name
    slicers = {v.roles["Values"][0] for p in _detail_pages() for v in p.visuals if v.sample.startswith("slicer")}
    assert DEPARTMENT_BASE in slicers


def test_headcount_cards_show_whole_numbers():
    """FTE equals headcount today (Fusion FTE values are 1): FTE and the monthly averages show no decimal."""
    page = _page("headcount")
    for m in ("FTE", "Average Headcount", "Average FTE"):
        (card,) = [v for v in page.visuals if v.sample == "card" and v.roles["Values"] == [meas(m)]]
        assert card.props["labels"][0]["properties"]["labelPrecision"]["expr"]["Literal"]["Value"] == "0L", m


def test_recruitment_says_when_budgeted_fte_is_missing():
    """No budgeted FTE is loaded: the vacancy card is [HR Vacancy Rate Text] ("No budgeted FTE")
    and each vacancy chart has the [HR Vacancy Note] card over it (an empty text once the budget is loaded)."""
    page = _page("recruitment")
    cards = [v for v in page.visuals if v.sample == "card" and v.roles["Values"][0].name.startswith(
        ("BSC Vacancy", "HR Vacancy Rate"))]
    assert [c.roles["Values"] for c in cards] == [[meas("HR Vacancy Rate Text")]]
    notes = _on(page, "HR Vacancy Note")
    charts = [v for v in page.visuals if v.sample in ("lineChart", "barChart") and meas("BSC Vacancy Rate") in
              _measures(v)]
    assert len(charts) == 2 and len(notes) == 2
    for chart in charts:
        assert any(_covers(n, chart) and _index(page, n) > _index(page, chart) and n.filters == [] for n in notes)


def test_recruitment_has_no_department():
    page = _page("recruitment")
    assert "HR Department" not in {f.table for f in page_fields(page)}
    assert not any(v.sample.startswith("slicer") and v.roles["Values"][0].table == "HR Department"
                   for v in page.visuals)
    bound = {m.name for v in page.visuals for m in _measures(v)}
    assert {"BSC Vacancy Rate", "BSC Time to Fill (days)"} <= bound


def test_employee_list_filtered_by_headcount():
    """Hidden drill-through on hospital and HR department. Employee has no branch relationship or row filter, so the
    table is filtered to people with a [Headcount] in context (R4: branch security applies through the fact).
    Keep all filters is off: only the drill fields arrive (a source visual's own filters, such as 'HR KPI' or
    'Pay Category', would make Headcount return its guard message); the month and the other selections come from
    the page's slicers, synced with the detail pages' slicers."""
    page = _page("employee_list")
    assert page.hidden and page.display == "Employee list" and PAGES[-1] is page
    # the drill fields are the detail charts' axes: hospital and the prefix-free department (R30)
    assert page.drill_fields == [BRANCH_NAME, DEPARTMENT_BASE] and not page.keep_filters
    tables = [v for v in page.visuals if v.sample == "table"]
    assert len(tables) == 1
    people = tables[0]
    assert (HEADCOUNT, "notblank", []) in _flt(people)
    for f in (col("Employee", "Worker Number"), col("Employee", "Person Number"), meas("HR Employee Name"),
              meas("HR Employee Staff ID"),
              meas("HR Employee Hospital"), meas("HR Employee Department"), meas("HR Employee Job"),
              meas("HR Employee Grade"), col("Employee", "Hire Date"), col("Employee", "Assignment Status")):
        assert f in people.roles["Values"], f
    # Grouped by Employee columns only: a table grouped by six dimensions' columns ran for minutes (empty in
    # Desktop); the hospital, department, job, grade and staff ID are measures through the month's headcount row
    assert {f.table for f in people.roles["Values"] if f.kind == "column"} == {"Employee"}
    assert people.props["total"][0]["properties"]["totals"]["expr"]["Literal"]["Value"] == "false"
    # The role hides Employee Details without pay access, and a table grouped by a column with no visible rows has
    # no rows: the name is the measure [HR Employee Name] (blank without pay access), never an Employee Details
    # column. A table drops the rows where all its measures are blank, so [Headcount] is a column too.
    assert "Employee Details" not in {f.table for f in page_fields(page)}
    assert HEADCOUNT in people.roles["Values"]
    assert not [v for v in page.visuals if v.roles.get("Values") == [PAY_NOTICE]]
    assert {v.roles["Values"][0] for v in page.visuals if v.sample.startswith("slicer")} >= {BRANCH_NAME, MONTH_PICK}
    assert any(v.sample == "buttonNavigate" and "Back" in json.dumps(v.props) for v in page.visuals)


# ---- Data quality and Guide --------------------------------------------------------------------------------------

def _text_of(page):
    """All the text of a page's text boxes (guide pages)."""
    out = []
    for v in page.visuals:
        for g in v.props.get("general", []):
            for p in g["properties"].get("paragraphs", []):
                out += [r["value"] for r in p["textRuns"]]
    return "\n".join(out)


def test_dq_guide_pages_registered_in_order():
    names = [p.name for p in PAGES]
    assert names[-4:] == ["data_quality", "guide", "guide_definitions", "employee_list"]
    for n in ("data_quality", "guide", "guide_definitions"):
        assert not _page(n).hidden


def test_dq_page_has_no_month_slicer():
    page = _page("data_quality")
    slicers = {v.roles["Values"][0] for v in page.visuals if v.sample.startswith("slicer")}
    assert MONTH_PICK not in slicers and BRANCH_NAME in slicers
    assert all(f.table != "Date" for f in page_fields(page))


def test_dq_page_content_and_measures():
    page = _page("data_quality")
    by_sample = lambda s: [v for v in page.visuals if v.sample == s]  # noqa: E731
    cards = {v.roles["Values"][0].name for v in by_sample("card")}
    assert {"HR Open Issues", "HR Issue Records", "HR Affected Employees"} <= cards
    bar = by_sample("barChart")[0]
    assert bar.roles["Category"] == [col("HR Data Issues", "Fix In")] and bar.roles["Y"] == [meas("HR Issue Records")]
    tables = by_sample("table")
    issue_table = next(v for v in tables if meas("HR Issue Records") in v.roles["Values"])
    records = next(v for v in tables if col("HR Data Issue Records", "Issue Code") in v.roles["Values"])
    fix = next(v for v in tables if v.roles["Values"] == [col("HR Data Issues", "Issue Name"),
                                                        col("HR Data Issues", "How To Fix")])
    assert (col("HR Data Issues", "Status"), "eq", ["active"]) in _flt(fix) and fix.title == "How to fix"
    for c in ("Issue Name", "Severity", "Fix In", "Owner"):
        assert col("HR Data Issues", c) in issue_table.roles["Values"]
    assert meas("HR Issue Records") in issue_table.roles["Values"]
    assert (col("HR Data Issues", "Status"), "eq", ["active"]) in _flt(issue_table)
    # the Oasis name is [HR Issue Oasis Name]: "" rather than the Staff Unknown member's "Unknown" without a record
    assert [f.name for f in records.roles["Values"]] == ["Issue Code", "Branch Name", "Worker Number", "Staff ID",
                                                         "HR Issue Oasis Name", "Field Name", "Value Found",
                                                         "Record Date"]
    assert col("Staff", "Staff Name") not in page_fields(page)
    matrix = by_sample("matrix")[0]
    assert matrix.roles["Rows"] == [col("HR Data Issues", "Issue Name")]
    assert matrix.roles["Columns"] == [BRANCH_NAME]
    assert not any(col("HR Data Issues", "How To Fix") in v.roles.get("Values", []) for v in by_sample("card"))
    assert not [i for i in page.interactions if i.source is issue_table and i.target is fix]
    # the records table follows the issue table (default cross-filter), not the other way round
    assert not [i for i in page.interactions if i.source is issue_table and i.target is records]


def test_dq_measures_never_hit_a_guard():
    from pages_detail import blocked_tables
    page = _page("data_quality")
    for v in page.visuals:
        own = {f.table for fs in v.roles.values() for f in fs if f.kind == "column"}
        for fs in v.roles.values():
            for f in fs:
                if f.kind == "measure":
                    assert not blocked_tables(f.name) & own, (v.title, f.name)


def test_definitions_cover_all_kinds():
    page = _page("guide_definitions")
    table = next(v for v in page.visuals if v.sample == "table")
    assert all(f.field != col("HR KPI", "Kind") for f in table.filters)
    assert all(f.field != col("HR KPI", "Kind") for f in page.filters)
    values = table.roles["Values"]
    for c in ("KPI Name", "Kind", "Definition", "Formula", "Source System", "Grain", "Direction", "Caveats"):
        assert col("HR KPI", c) in values
    assert meas("HR KPI Target Text") in values
    # final review M2: the watch value beside the target, as text (placeholder mark, pay-aware)
    names = [f.name for f in values]
    assert names.index("HR KPI Watch Text") == names.index("HR KPI Target Text") + 1
    assert table.labels[meas("HR KPI Watch Text")] == "Watch at"
    assert {v.roles["Values"][0] for v in page.visuals if v.sample.startswith("slicer")} >= {AREA}
    _assert_fixed_columns(table, min_font=10)  # the Grain column was cut off


def test_guide_text_covers_the_rules():
    text = _text_of(_page("guide"))
    for needle in ("Last closed month", "● On track", "◆ Watch", "■ At risk", "○ No target yet", "– No data", "Parked",
                   "🔒 Requires pay access", "within the watch threshold", "(placeholder)", "BI manager", "Head Office", "PROMOTION", "2 decimals",
                   "largest change", "nightly", "Back", "BSC turnover", "in Fusion", "Period", "pro-rated",
                   "Unknown", "FTE equals headcount", "zero FTE", "budgeted FTE",
                   # user decision 2026-11-03: Head Office everywhere; the scorecard report stays hospitals only
                   "Branch lists the eight hospitals and Head Office", "covers the hospitals only",
                   "no Head Office data", "include Head Office's requisitions"):  # ruling R32
        assert needle in text, needle
