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
ALLOWED_KPI_PAGE_SLICERS = {BRANCH_NAME, MONTH_PICK, AREA}  # R13: an Area slicer on the KPI list is allowed


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
    assert hospital.roles == {"Values": [BRANCH_NAME]} and month.roles == {"Values": [MONTH_PICK]}
    assert [(f.field, f.op, f.values) for f in hospital.filters] == [(IS_HOSPITAL, "in", ["Yes"])]
    assert hospital.labels == {BRANCH_NAME: "Hospital"} and month.labels == {MONTH_PICK: "Month"}
    for v in (hospital, month):  # inside the filter bar, left of the help buttons
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
    panel, cards = vs[0], vs[1:]
    assert panel.sample == "panel" and (panel.x, panel.y, panel.w, panel.h) == (30, 300, 447, 236)
    assert [c.sample for c in cards] == ["card"] * 3
    assert [c.roles["Values"] for c in cards] == [[meas("HR KPI Actual Text")], [meas("HR KPI Target Text")],
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
    assert notice[0].filters[0].op == "notblank"  # a blank notice would print "(Blank)" over the chart
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
    # sorted by Display Order; text measures for the cells every user sees (R22); no variance measure exists
    assert table.sort == col("HR KPI", "Display Order") and table.sort_dir == "asc"
    values = table.roles["Values"]
    assert meas("HR KPI Actual Text") in values and meas("HR KPI Actual") not in values
    assert meas("HR KPI Target Text") in values and meas("HR KPI Status Text") in values
    assert col("HR KPI", "KPI Code") in values  # the drill-through field is in the table
    assert matrix.roles["Values"] == [meas("HR KPI Status Text")] and matrix.roles["Columns"] == [BRANCH_NAME]
    # status cells are coloured by [HR KPI Status Colour]
    for v in (table, matrix):
        fc = [e for e in v.props["values"] if "fontColor" in e["properties"]]
        assert STATUS_COLOUR.name in json.dumps(fc) and "HR KPI Status Text" in fc[0]["selector"]["metadata"]
    assert {v.roles["Values"][0] for v in page.visuals if v.sample.startswith("slicer")} == ALLOWED_KPI_PAGE_SLICERS
    drill = [v for v in page.visuals if v.sample == "buttonDrill"]
    assert len(drill) == 1
    assert "kpi_detail" in json.dumps(drill[0].props)


def test_kpi_detail_is_drillthrough_on_code():
    page = _page("kpi_detail")
    assert page.hidden and page.drill_fields == [KPI_CODE] and not page.keep_filters
    assert page.display == "KPI detail" and page.name == "kpi_detail"
    vs = page.visuals
    # a Back button, and the frame without a current tab
    assert any(v.sample == "buttonNavigate" and "Back" in json.dumps(v.props) for v in vs)
    assert not any(v.sample == "buttonNavigate" and nav_target(v) in TAB_NAMES and
                   "primary" in json.dumps(v.props) for v in vs)
    # definition panel
    defs = {v.roles["Values"][0].name for v in vs if v.sample == "card" and v.roles["Values"][0].table == "HR KPI"}
    assert {"Definition", "Formula", "Source System", "Grain", "Caveats"} <= defs
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
    assert {v.roles["Values"][0] for v in vs if v.sample.startswith("slicer")} == {BRANCH_NAME, MONTH_PICK}


def test_scorecard_and_kpi_detail_are_registered():
    names = [p.name for p in PAGES]
    assert names[:4] == ["home", "story", "scorecard", "kpi_detail"]


def test_kpi_detail_charts_have_a_pay_notice():
    page = _page("kpi_detail")
    notices = _on(page, "HR Pay Notice")
    assert len(notices) == 2 and all(n.filters[0].op == "notblank" for n in notices)
    for chart in (next(v for v in page.visuals if v.sample == "lineChart"),
                  next(v for v in page.visuals if v.sample == "barChart")):
        assert any(n.x == chart.x and n.w == chart.w and chart.y <= n.y and n.y + n.h <= chart.y + chart.h
                   for n in notices)


# ---- Detail pages and Employee list ------------------------------------------------------------------------------

HEADCOUNT = meas("Headcount")
PAY_NOTICE = meas("HR Pay Notice")
DEPARTMENT_NAME = col("HR Department", "Department Name")
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


def _data_visuals(page):
    """Cards, charts and tables that show a measure other than the pay notice."""
    return [v for v in page.visuals if v.sample in ("card", "lineChart", "barChart", "table", "matrix")
            and any(m != PAY_NOTICE for m in _measures(v))]


def _columns(v):
    return [f for fs in v.roles.values() for f in fs if f.kind == "column"] + [
        f.field for f in v.filters if f.field.kind == "column"]


def _covers(notice, v):
    """The notice lies over the visual: inside it vertically, overlapping it horizontally."""
    return notice.x < v.x + v.w and v.x < notice.x + notice.w and v.y <= notice.y and notice.y + notice.h <= v.y + v.h


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


def test_detail_pages_cards_then_two_by_two_grid():
    """One or two rows of cards (4 or 5 in the first), then a 2 x 2 grid right under them: filling the screen, or
    at least 300 px high."""
    for page in _detail_pages():
        cards = [v for v in _data_visuals(page) if v.sample == "card"]
        rows = sorted({c.y for c in cards})
        assert len(rows) in (1, 2), page.name
        assert 4 <= len([c for c in cards if c.y == rows[0]]) <= 5, page.name
        assert all(1 <= len([c for c in cards if c.y == y]) <= 5 for y in rows), page.name
        cards_end = max(c.y + c.h for c in cards)
        charts = [v for v in page.visuals if v.sample in ("lineChart", "barChart", "table") and v.y > cards_end]
        first = sorted(charts, key=lambda v: (v.y, v.x))[:4]
        assert len({v.y for v in first}) == 2 and len({v.x for v in first}) == 2, page.name
        assert min(v.y for v in first) - cards_end <= 24, page.name
        assert min(v.h for v in first) >= 300 or max(v.y + v.h for v in first) == 1056, page.name


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
    """Cards follow the selected month; each line chart is a 12-month trend that ignores the Month slicer (Story's
    mechanism); every other data visual follows it."""
    from model import interaction_indexes
    for page in _detail_pages():
        month = _index(page, _month_slicer(page))
        no_filter = {t for s, t, k in interaction_indexes(page) if s == month and k == "NoFilter"}
        lines = [v for v in page.visuals if v.sample == "lineChart"]
        assert lines, page.name
        for v in lines:
            assert v.roles["Category"] == [col("Date", "Year Month Name")] and v.sort_dir == "asc"
            assert (col("Date", "Month Offset"), "in", list(range(1, 13))) in _flt(v), page.name
            assert _index(page, v) in no_filter, page.name
        for v in _data_visuals(page):
            if v.sample != "lineChart":
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
        assert notices and all(_flt(n) == [(PAY_NOTICE, "notblank", [])] for n in notices), name
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

    assert {BRANCH_NAME, DEPARTMENT_NAME, col("Job", "Job Name"), col("Grade", "Grade Name"),
            col("Position", "Position Name"), col("Location", "Location Name"), col("Headcount", "Is Saudi"),
            col("Headcount", "Gender"), col("Headcount", "Age Band"), col("Headcount", "Tenure Band"),
            col("Employee", "Worker Type"), col("Job", "Full Part Time")} <= axes("headcount")
    assert {col("Worker Action", "Action Reason Name"), col("Employee", "Tenure Band")} <= axes("movements")
    assert {col("Pay Category", "Pay Category"), DEPARTMENT_NAME, col("Payroll", "Source"),
            col("Payroll", "Payroll Status")} <= axes("payroll")
    assert {col("Absence Type", "Absence Type Name"), BRANCH_NAME} <= axes("absence")
    assert {col("Staff Productivity", "Staff Category"), BRANCH_NAME} <= axes("productivity")
    card_measures = {m.name for v in _page("headcount").visuals if v.sample == "card" for m in _measures(v)}
    assert "Contingent Share %" in card_measures  # contingent workers shown separately


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
    assert page.drill_fields == [BRANCH_NAME, DEPARTMENT_NAME] and not page.keep_filters
    tables = [v for v in page.visuals if v.sample == "table"]
    assert len(tables) == 1
    people = tables[0]
    assert (HEADCOUNT, "notblank", []) in _flt(people)
    for f in (col("Employee", "Worker Number"), meas("HR Employee Name"), col("Staff", "Staff ID"), BRANCH_NAME,
              DEPARTMENT_NAME, col("Job", "Job Name"), col("Grade", "Grade Name"), col("Employee", "Hire Date"),
              col("Employee", "Assignment Status")):
        assert f in people.roles["Values"], f
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
    assert [f.name for f in records.roles["Values"]] == ["Issue Code", "Branch Name", "Worker Number", "Staff ID",
                                                         "Staff Name", "Field Name", "Value Found", "Record Date"]
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
    assert {v.roles["Values"][0] for v in page.visuals if v.sample.startswith("slicer")} >= {AREA}


def test_guide_text_covers_the_rules():
    text = _text_of(_page("guide"))
    for needle in ("Last closed month", "● On track", "◆ Watch", "■ At risk", "○ No target yet", "– No data", "Parked",
                   "🔒 Requires pay access", "within the watch threshold", "(placeholder)", "BI manager", "Head Office", "PROMOTION", "2 decimals",
                   "largest change", "nightly", "Back", "BSC turnover", "in Fusion"):
        assert needle in text, needle
