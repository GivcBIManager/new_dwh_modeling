"""The KPI pages (kpi_monthly, kpi_hospitals): six cards F1..F6 with a status chip and a 12-month sparkline, header
chips, the KPI matrix; and, on all eight pages, content clicks that leave the period text card and the slicers alone."""
import importlib.util
import re
import sys
from pathlib import Path

import pages_kpi as pk
from fields import unknown_fields
from fin_frame import PERIOD_TEXT
from model import Filter, col, meas

FIN = Path(__file__).resolve().parents[1]
KPI, GROUP, NAME = col("Finance KPI", "KPI Code"), col("Finance KPI", "KPI Group"), col("Finance KPI", "KPI Name")
MONTH_OFFSET = col("Date", "Month Offset")
YEAR_MONTH = col("Date", "Year Month")
BRANCH_NAME = col("Branch", "Branch Name")
CARDS = {"F1": "FR_REV_GROWTH", "F2": "FR_EBITDA_MARGIN", "F3": "FR_NP_VS_BUD", "F4": "FR_AR_DAYS",
         "F5": "FR_REJECTION_RATE", "F6": "FR_COST_TO_REV"}
KPI_PAGES = ("kpi_monthly", "kpi_hospitals")


def _fin_pages():
    if "fin_pages" not in sys.modules:
        spec = importlib.util.spec_from_file_location("fin_pages", FIN / "pages.py")
        module = importlib.util.module_from_spec(spec)
        sys.modules["fin_pages"] = module
        spec.loader.exec_module(module)
    return sys.modules["fin_pages"]


def _page(name):
    return next(p for p in pk.PAGES if p.name == name)


def _matrix(page):
    found = [v for v in page.visuals if v.sample == "matrix"]
    assert len(found) == 1
    return found[0]


def _sparklines(page):
    return [v for v in page.visuals if v.sample == "lineChart"]


def _codes(v):
    return [f.values[0] for f in v.filters if f.field == KPI]


def _text(v):
    return v.props["general"][0]["properties"]["paragraphs"][0]["textRuns"][0]["value"]


def _off(page):
    return {(id(i.source), id(i.target)) for i in page.interactions if i.type == "NoFilter"}


def _cells(page, kind):
    return [v for v in page.visuals if v.sample == "card" and v.roles.get("Values") == [meas("FR KPI Cell")]
            and any(f.field.name == "Kind" and f.values == [kind] for f in v.filters)]


def test_six_cards_f1_to_f6():
    assert dict(pk.CARD_KPIS) == CARDS
    for name in KPI_PAGES:
        p = _page(name)
        chips = [v for v in p.visuals if v.sample == "textbox" and re.fullmatch(r"F[1-6]", _text(v))]
        assert [_text(v) for v in chips] == list(CARDS), name
        lines = _sparklines(p)
        assert [_codes(v) for v in lines] == [[c] for c in CARDS.values()], name
        panels = [v for v in p.visuals if v.sample == "panel" and 170 < v.y < 360]
        assert len(panels) == 6
        for panel, line in zip(panels, lines):
            assert panel.x <= line.x and line.x + line.w <= panel.x + panel.w
            assert panel.y <= line.y and line.y + line.h <= panel.y + panel.h


def test_sparkline_is_a_twelve_month_trend_off_the_year_and_month_slicers():
    for name in KPI_PAGES:
        p = _page(name)
        slicers = [v for v in p.visuals if v.sample == "slicerTile"]
        hospital = [v for v in slicers if BRANCH_NAME in v.roles["Values"]]
        year, month = [v for v in slicers if BRANCH_NAME not in v.roles["Values"]]
        assert (len(hospital) == 1) == (name == "kpi_monthly")
        off = _off(p)
        for s in _sparklines(p):
            assert s.roles["Category"] == [YEAR_MONTH] and s.roles["Y"] == [meas("FR KPI Value")]
            # no title and 50+ px: smaller, or under the default title, Desktop drew a placeholder icon (2026-11-19)
            assert s.h >= 50 and s.props["title"][0]["properties"]["show"]["expr"]["Literal"]["Value"] == "false"
            for axis in ("categoryAxis", "valueAxis"):  # no axis title ("FR KP..." beside the line)
                assert s.props[axis][0]["properties"]["showAxisTitle"]["expr"]["Literal"]["Value"] == "false"
            assert Filter(MONTH_OFFSET, "in", list(range(1, 13))) in s.filters
            assert (id(year), id(s)) in off and (id(month), id(s)) in off, name
            for h in hospital:  # the Hospital slicer keeps its effect
                assert (id(h), id(s)) not in off, name


def test_status_chips_present():
    for name in KPI_PAGES:
        p = _page(name)
        chips = [v for v in p.visuals if v.sample == "card" and v.roles.get("Values") == [meas("FR KPI Status")]]
        assert [_codes(v) for v in chips] == [[c] for c in CARDS.values()], name
        for v in chips:
            assert "FR KPI Status Colour" in repr(v.props["background"]), name
            assert "FR KPI Status Text Colour" in repr(v.props["labels"]), name  # R16a
        counts = {meas(n): fg for n, fg in (("FR KPI Count On", "#04564A"), ("FR KPI Count Watch", "#5C3F00"),
                                            ("FR KPI Count Off", "#6E1505"))}
        header = [v for v in p.visuals if v.sample == "card" and v.roles.get("Values", [None])[0] in counts]
        assert [v.roles["Values"][0] for v in header] == list(counts), name
        for v, fill in zip(header, ("#D9F3EE", "#FFDF8A", "#F5A99B")):
            assert counts[v.roles["Values"][0]] in repr(v.props["labels"]), name
            assert sum(1 for t in p.visuals if t.sample == "textbox" and fill in repr(t.props)) == 1, name


def test_kpi_matrix_rows_are_group_and_kpi():
    for name, stored in (("kpi_monthly", "monthly"), ("kpi_hospitals", "hospital")):
        m = _matrix(_page(name))
        assert m.roles["Rows"] == [GROUP, NAME]
        assert m.roles["Values"] == [meas("FR KPI Cell")]
        assert {(f.field.name, tuple(f.values)) for f in m.filters} == {("Page", ("kpi",)), ("View", (stored,))}
        assert m.expand is True
        assert "FR KPI Cell Colour" in repr(m.props["values"][0]["properties"]["fontColor"])
        assert (BRANCH_NAME in m.roles["Columns"]) == (stored == "hospital")
        # hospitals: Actual shaded by status; monthly: the Status column (the measure reads the column View and Kind)
        assert "FR KPI Cell Background" in repr(m.props["values"][0]["properties"]["backColor"])


def _changes(page, kind, measure):
    return [v for v in page.visuals if v.sample == "card" and v.roles.get("Values") == [meas(measure)]
            and any(f.field.name == "Kind" and f.values == [kind] for f in v.filters)]


def test_card_lines_by_page():
    monthly, hospitals = _page("kpi_monthly"), _page("kpi_hospitals")
    for kind in ("budget", "ly"):
        assert len(_cells(monthly, kind)) == 6 and not _cells(hospitals, kind), kind
    # R16b: the change is its own measure, blank when the figure beside it is a placeholder (shown once)
    for kind, measure in (("vs_bud", "FR KPI Card Budget Change"), ("vs_ly", "FR KPI Card LY Change")):
        found = _changes(monthly, kind, measure)
        assert len(found) == 6 and not _cells(monthly, kind) and not _changes(hospitals, kind, measure), kind
        for v in found:
            assert "FR KPI Cell Colour" in repr(v.props["labels"])
    for measure in ("FR KPI Card Best", "FR KPI Card Lowest"):
        found = [v for v in hospitals.visuals if v.roles.get("Values") == [meas(measure)]]
        assert [_codes(v) for v in found] == [[c] for c in CARDS.values()], measure
        assert not [v for v in monthly.visuals if v.roles.get("Values") == [meas(measure)]]
    for page in (monthly, hospitals):
        for kind in ("target", "actual"):
            assert [_codes(v) for v in _cells(page, kind)] == [[c] for c in CARDS.values()], page.name


def test_the_matrix_and_sparklines_filter_nothing_on_the_content():
    for p in pk.PAGES:
        m = _matrix(p)
        content = [v for v in p.visuals if v.y > 170 and v is not m and v.sample in ("card", "lineChart")]
        off = _off(p)
        for v in content:
            assert (id(m), id(v)) in off, (p.name, v.sample)
        for s in _sparklines(p):
            for v in content + [m]:
                if v is not s:
                    assert (id(s), id(v)) in off, (p.name, v.sample)


def test_content_clicks_leave_the_period_card_and_slicers_alone_on_every_page():
    pages = _fin_pages().PAGES
    assert len(pages) == 8
    for p in pages:
        frame = [v for v in p.visuals if v.sample.startswith("slicer") or
                 (v.sample == "card" and v.roles.get("Values") == [PERIOD_TEXT])]
        assert len(frame) >= 3, p.name
        sources = [v for v in p.visuals if v.sample in ("matrix", "columnChart", "barChart", "lineChart")]
        assert sources, p.name
        off = _off(p)
        for s in sources:
            for f in frame:
                assert (id(s), id(f)) in off, (p.name, s.sample, f.sample)


def test_fields_in_perspective_and_cards_bind_visible_measures_only():
    import fields
    assert unknown_fields(pk.PAGES, perspective="Finance Report") == []
    assert unknown_fields(_fin_pages().PAGES, report_filters=_fin_pages().REPORT_FILTERS,
                          perspective="Finance Report") == []
    text = (fields.MODEL_DIR / "tables" / "_Measures.tmdl").read_text(encoding="utf-8")
    hidden = set()
    for block in re.split(r"\n\t(?=measure )", text):
        m = re.match(r"measure '?([^'=]+?)'? =", block)
        if m and re.search(r"^\t\tisHidden$", block.split("\n\t///", 1)[0], re.M):
            hidden.add(m.group(1))
    used = {f.name for p in pk.PAGES for v in p.visuals for role in ("Values", "Y") for f in v.roles.get(role, [])
            if f.kind == "measure"}
    used |= set(re.findall(r"'Property': '([^']+)'", repr([v.props for p in pk.PAGES for v in p.visuals])))
    assert "FR KPI Cell" in used and not (used & hidden), sorted(used & hidden)


def test_report_has_the_kpi_pages_in_place():
    pages = _fin_pages().PAGES
    assert [p.name for p in pages][6:] == list(KPI_PAGES)
    for p in pages[6:]:
        assert any(v.sample == "matrix" for v in p.visuals)
