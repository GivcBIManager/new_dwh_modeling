"""The scorecard pages and KPI detail: roles, payloads, filters, layout, and a build against the synthetic template."""
import json
import re
from pathlib import Path

import pytest

from fields import unknown_fields
from layout import page_section
from model import col, meas, page_fields
from pages import ATTRIBUTE_ROLES, PAGES, back_button, label_text, select_all_selection

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


YEAR_MONTH_NAME = col("Date", "Year Month Name")


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
        ("slicerDateRange", [col("Date", "Date")])]
    (flt,) = slicers[0].filters
    assert (flt.field, flt.op, flt.values) == (col("Branch", "Is Hospital"), "in", ["Yes"])
    sel = slicers[0].props["selection"][0]["properties"]
    assert lit(sel["singleSelect"]) == "false"
    assert lit(sel["selectAllCheckboxEnabled"]) == "true"
    buttons = [v for v in page.visuals if v.sample == "buttonNavigate"]
    targets = [lit(v.props["visualLink"][0]["properties"]["navigationSection"]) for v in buttons]
    assert targets == [f"'{p.name}'" for p in PAGES[:7]]


def _date_slicers(pages):
    return [(p, v) for p in pages for v in p.visuals if v.sample.startswith("slicer") and v.roles["Values"] == [col("Date", "Date")]]


def test_no_page_uses_the_relative_date_slicer():
    assert not [p.display for p in PAGES for v in p.visuals if v.sample == "slicerRelativeDate"]


def test_date_slicer_is_a_range_over_the_build_year():
    """Task 11: scorecard pages and KPI detail open on 1 January - 31 December of the build year (today by default);
    the family pages have no date slicer."""
    import datetime
    import pages
    year = datetime.date.today().year
    found = _date_slicers(PAGES)
    assert {p.display for p, _ in found} == set(SCORECARD) | {"KPI detail"}
    assert {v.date_range for _, v in found} == {(f"{year}-01-01", f"{year}-12-31")}
    later = pages.build_pages(datetime.date(2027, 1, 2))
    assert {v.date_range for _, v in _date_slicers(later)} == {("2027-01-01", "2027-12-31")}
    assert [p.name for p in later] == [p.name for p in PAGES]


def test_no_page_binds_time_calculation():
    """Controller ruling: no Time Calculation slicer. Its items applied to [BSC Actual] but not to the target, so the
    page opened on "MTD" compared a month-to-date actual with a full-year target."""
    for p in PAGES:
        assert all(f.table != "Time Calculation" for f in page_fields(p)), p.display


def test_kpi_detail_page():
    page = by_display("KPI detail")
    assert page.drill_fields == [col("BSC KPI", "KPI Code")]
    by = {}
    for v in page.visuals:
        by.setdefault(v.sample, []).append(v)
    assert "multiRowCard" not in by
    (about,) = [v for v in by["table"] if v.title == "About this KPI"]
    assert about.roles == {"Values": [col("BSC KPI", "KPI Name"), col("BSC KPI", "Definition"),
                                      col("BSC KPI", "Owner"), col("BSC KPI", "Co Owners"),
                                      meas("BSC Target Basis"), meas("BSC KPI Weight")]}
    cards = [v.roles["Values"] for v in by["card"]]
    assert cards == [[meas(m)] for m in ("BSC Actual", "BSC Target", "BSC Score", "BSC State", "BSC Numerator",
                                         "BSC Denominator")]
    (line,) = by["lineChart"]
    assert line.roles == {"Category": [YEAR_MONTH_NAME], "Y": [meas("BSC Actual"), meas("BSC Target")]}
    assert (line.sort, line.sort_dir) == (YEAR_MONTH_NAME, "asc")
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
    # a table of KPI name and note: a table drops the rows whose measures are all blank, so a measure KPI shows an
    # empty table (the multi-row card showed "(Blank)"); no not-blank filter
    assert note.sample == "table" and note.roles == {"Values": [col("BSC KPI", "KPI Name"), note_field]}
    assert note.title == "Manual entry note"
    assert note.filters == []


def _obj(v, name, selector=None):
    """The properties of format object `name`'s entry with `selector` (None: the entry without a selector)."""
    return next((e["properties"] for e in v.props.get(name, []) if e.get("selector") == selector), {})


def test_kpi_information_table_wraps_text():
    (about,) = [v for v in by_display("KPI detail").visuals if v.title == "About this KPI"]
    assert lit(_obj(about, "values")["wordWrap"]) == "true"
    assert lit(_obj(about, "columnHeaders")["wordWrap"]) == "true"


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


IS_HOSPITAL = col("Branch", "Is Hospital")
CAPABILITIES = Path(__file__).resolve().parents[2] / "hnh_bsc_visual" / "capabilities.json"


def test_role_names_come_from_the_visual_capabilities():
    roles = [r["name"] for r in json.loads(CAPABILITIES.read_text(encoding="utf-8-sig"))["dataRoles"]]
    assert roles == list(README_ROLES) + ["branch", "payload", "selectionLabel"]
    for display in SCORECARD:
        assert set(hnh(by_display(display)).roles) <= set(roles)


def test_helpers_write_literal_values():
    sel = select_all_selection()["selection"][0]["properties"]
    assert (lit(sel["singleSelect"]), lit(sel["selectAllCheckboxEnabled"])) == ("false", "true")
    txt = label_text("Hi")["text"]
    # Desktop's actionButton reads `show` from the entry without a selector and the label per state: the default
    # state's entry (selector id "default") holds it; hover, press and disabled fall back to it
    assert [lit(e["properties"]["show"]) for e in txt if "selector" not in e] == ["true"]
    assert [lit(e["properties"]["text"]) for e in txt if e.get("selector") == {"id": "default"}] == ["'Hi'"]
    assert all("text" not in e["properties"] for e in txt if "selector" not in e)
    link = back_button().props["visualLink"][0]["properties"]
    assert (lit(link["show"]), lit(link["type"])) == ("true", "'Back'")


def test_nav_buttons_assert_link_type_and_show():
    for v in by_display("BSC").visuals:
        if v.sample == "buttonNavigate":
            link = v.props["visualLink"][0]["properties"]
            assert (lit(link["show"]), lit(link["type"])) == ("true", "'PageNavigation'")


def test_kpi_detail_header_back_and_navigation():
    page = by_display("KPI detail")
    backs = [v for v in page.visuals if v.sample == "buttonNavigate"
             and lit(v.props["visualLink"][0]["properties"]["type"]) == "'Back'"]
    assert len(backs) == 1 and backs[0].x < min(v.x for v in page.visuals if v.y < 110 and v is not backs[0])
    navs = [v for v in page.visuals if v.sample == "buttonNavigate" and v not in backs]
    assert [lit(v.props["visualLink"][0]["properties"]["navigationSection"]) for v in navs] == \
        [f"'{p.name}'" for p in PAGES[:7]]
    slicers = [v for v in page.visuals if v.sample.startswith("slicer")]
    scorecard = [v for v in by_display("BSC").visuals if v.sample.startswith("slicer")]
    assert [(v.sample, v.roles) for v in slicers] == [(v.sample, v.roles) for v in scorecard]
    assert [f.field for f in slicers[0].filters] == [IS_HOSPITAL]
    assert max(v.x + v.w for v in slicers) < min(v.x for v in navs)
    assert backs[0].x + backs[0].w < min(v.x for v in slicers)


def test_kpi_detail_matrix_is_the_drill_source():
    page = by_display("KPI detail")
    (m,) = [v for v in page.visuals if v.sample == "matrix"]
    assert m.roles == {"Rows": [col("Branch", "Branch Name")], "Columns": [YEAR_MONTH_NAME],
                       "Values": [meas("BSC Actual")]}
    assert [(f.field, f.op, f.values) for f in m.filters] == [(IS_HOSPITAL, "in", ["Yes"])]
    assert m.title == "Select a hospital and month, then Open detail"
    (b,) = [v for v in page.visuals if v.sample == "buttonDrill"]
    assert m.y <= b.y and b.y + b.h <= m.y + m.h and b.x >= m.x + m.w
    assert {v.sample for v in page.visuals} >= {"lineChart", "barChart"}


FAMILY = ["Revenue detail", "Finance detail", "Patient volume detail", "Beds & clinical detail",
          "Revenue cycle detail", "Workforce detail", "Patient experience detail"]
FAMILY_NAMES = ["fam_revenue", "fam_finance", "fam_volume", "fam_beds", "fam_revenue_cycle", "fam_workforce",
                "fam_experience"]


def test_family_pages_names_order_and_hidden():
    import pages
    assert [p.display for p in pages.FAMILY_PAGES] == FAMILY
    assert [p.name for p in pages.FAMILY_PAGES] == FAMILY_NAMES
    assert all(p.hidden for p in pages.FAMILY_PAGES)
    assert PAGES[8:] == pages.FAMILY_PAGES


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


@pytest.mark.parametrize("display", FAMILY)
def test_family_drill_fields_header_and_no_slicers(display):
    page = by_display(display)
    assert page.drill_fields == [col("Branch", "Branch Name"), YEAR_MONTH_NAME]
    assert not [v for v in page.visuals if v.sample.startswith("slicer")]
    backs = [v for v in page.visuals if v.sample == "buttonNavigate"]
    assert len(backs) == 1 and lit(backs[0].props["visualLink"][0]["properties"]["type"]) == "'Back'"
    (mrc,) = [v for v in page.visuals if v.sample == "multiRowCard"]
    assert mrc.roles["Values"] == [col("Branch", "Branch Name"), YEAR_MONTH_NAME]
    assert [v for v in page.visuals if v.sample == "textbox"]


@pytest.mark.parametrize("display", FAMILY)
def test_family_pages_take_only_the_drill_fields(display):
    """Review Focus 4: a family page does not keep all filters. KPI detail carries the 'BSC KPI' drill filter (and a
    pillar page filter); passed on, every domain measure's guard returns "... can't be analysed by "BSC KPI"". The
    page filters hospitals itself."""
    page = by_display(display)
    assert page.keep_filters is False
    assert [(f.field, f.op, f.values) for f in page.filters] == [(IS_HOSPITAL, "in", ["Yes"])]


def test_kpi_detail_keeps_all_filters():
    assert by_display("KPI detail").keep_filters is True


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
    tables = [v for p in PAGES[8:] for v in p.visuals if v.sample == "table"]
    assert len(tables) == 4
    for v in tables:
        rank = v.top_n[0] if v.top_n else v.roles["Values"][1]
        assert (v.sort, v.sort_dir) == (rank, "desc"), v.title
        assert rank in v.roles["Values"]
    for p in PAGES[8:]:
        assert all(v.sort is None for v in p.visuals if v.sample == "matrix"), p.display


def test_family_bar_top_n_ranks_by_the_bars_measure():
    """Except NPS by department: the 15 departments with most answers (ranked by NPS, departments with a few answers
    won), bars sorted by NPS."""
    for p in PAGES[8:]:
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


@pytest.mark.parametrize("display", FAMILY)
def test_family_title_is_20pt_bold(display):
    (tb,) = [v for v in by_display(display).visuals if v.sample == "textbox"]
    (run,) = tb.props["general"][0]["properties"]["paragraphs"][0]["textRuns"]
    assert run["value"] == display
    assert run["textStyle"] == {"fontFamily": "Segoe UI", "fontSize": "20pt", "fontWeight": "bold"}


def test_family_pages_build_against_the_synthetic_template(pbix_path):
    from pbix import read_pbix, samples
    p = read_pbix(pbix_path)
    smp = samples(p)
    lay = p.layout
    base, drill = lay["sections"][0], lay["sections"][1]
    for i, page in enumerate(PAGES):
        if i < 8:
            continue
        section, _ = page_section(page, i, smp, lay, drill, base)
        assert len(section["visualContainers"]) == len(page.visuals)
        assert json.loads(section["config"]).get("visibility") == 1


CHART_TITLES = {
    "KPI detail": ["Actual vs target by month", "Actual by hospital", "About this KPI",
                   "Select a hospital and month, then Open detail", "Manual entry note"],
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
    for p in PAGES[7:]:
        assert all(v.title for v in p.visuals if v.sample in CHARTS), p.display


def _style(v):
    """(fill colour or None, outline shown, text colour) of a button. As the handover's buttons: `show` in an entry
    without a selector, colours in the default state's entry (selector id "default")."""
    def entry(obj, selector):
        return next((e["properties"] for e in v.props.get(obj, []) if e.get("selector") == selector), {})
    default = {"id": "default"}
    fill, outline, text = entry("fill", default), entry("outline", default), entry("text", default)
    assert "show" not in fill and "show" not in outline
    colour = (lambda p, k: p[k]["solid"]["color"]["expr"]["Literal"]["Value"] if k in p else None)
    return (colour(fill, "fillColor") if lit(entry("fill", None)["show"]) == "true" else None,
            lit(entry("outline", None)["show"]), colour(text, "fontColor"))


def test_buttons_have_a_visible_style():
    from pages import button_style
    for p in PAGES:
        for v in p.visuals:
            if v.sample not in ("buttonNavigate", "buttonDrill"):
                continue
            back = lit(v.props["visualLink"][0]["properties"]["type"]) == "'Back'"
            if back:
                assert _style(v) == (None, "true", "'#1478BE'")
            else:
                assert _style(v) == ("'#13ACE3'", "false", "'#FFFFFF'")
            # the label: `show` without a selector, the text in the default state's entry; one entry per selector
            assert lit(_obj(v, "text")["show"]) == "true"
            assert lit(_obj(v, "text", {"id": "default"})["text"])
            for obj, entries in v.props.items():
                sels = [json.dumps(e.get("selector"), sort_keys=True) for e in entries]
                assert len(sels) == len(set(sels)), (obj, sels)
    assert set(button_style("primary")) == set(button_style("outline")) == {"fill", "outline", "text"}


def test_open_detail_button_is_readable_when_disabled():
    """Open detail is disabled until a matrix cell is selected; Desktop's disabled default is a light grey fill with
    grey text. The disabled state gets its own fill and text colour; the label falls back to the default state's."""
    (btn,) = [v for v in by_display("KPI detail").visuals if v.sample == "buttonDrill"]
    disabled = {"id": "disabled"}
    colour = (lambda p, k: p[k]["solid"]["color"]["expr"]["Literal"]["Value"])
    fill, text = _obj(btn, "fill", disabled), _obj(btn, "text", disabled)
    assert colour(fill, "fillColor") != colour(text, "fontColor")
    assert lit(fill["transparency"]) == "0D"
    assert lit(_obj(btn, "text", {"id": "default"})["text"]) == "'Open detail'"
