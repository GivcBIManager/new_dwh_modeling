"""The Finance report's frame: on every page, four tabs, view buttons to the twin pages, the Hospital slicer on the
monthly pages only, the hospitals page filter locked, the fields in the `Finance Report` perspective."""
import importlib.util
import json
import sys
import tempfile
from pathlib import Path

import pbir
from fields import unknown_fields
from fin_frame import (FIN_FRAME, FIN_REPORT, PAGE_NAMES, TABS, filter_bar, hospitals, lock_branch_filters_on_disk,
                       page_frame)
from model import col, meas


def _fin_pages():
    """This report's pages.py, loaded as `fin_pages`: the name `pages` is the BSC's in a combined test session."""
    if "fin_pages" not in sys.modules:
        spec = importlib.util.spec_from_file_location("fin_pages", Path(__file__).resolve().parents[1] / "pages.py")
        module = importlib.util.module_from_spec(spec)
        sys.modules["fin_pages"] = module
        spec.loader.exec_module(module)
    return sys.modules["fin_pages"]


PAGES, REPORT_FILTERS = _fin_pages().PAGES, _fin_pages().REPORT_FILTERS
BRANCH_NAME = col("Branch", "Branch Name")
BRANCH_KEY = col("Branch", "Branch Key")
ORDER = ["tb_monthly", "tb_hospitals", "is_monthly", "is_hospitals", "bs_monthly", "bs_hospitals", "kpi_monthly",
         "kpi_hospitals"]
MONTHLY = [n for n in ORDER if n.endswith("monthly")]


def lit(prop):
    return prop["expr"]["Literal"]["Value"]


def nav_target(v):
    link = v.props.get("visualLink", [{}])[0].get("properties", {})
    return lit(link["navigationSection"]).strip("'") if "navigationSection" in link else None


def test_specs_and_page_order():
    assert FIN_FRAME.title == "Finance Report" and FIN_FRAME.subtitle == "Hayat Healthcare" and FIN_FRAME.help == []
    assert TABS == [("tb_monthly", "Trial Balance"), ("is_monthly", "Income Statement"),
                    ("bs_monthly", "Balance Sheet"), ("kpi_monthly", "KPIs & Ratios")]
    assert FIN_REPORT.name == "HNH Finance" and FIN_REPORT.perspective == "Finance Report"
    assert [p.name for p in PAGES] == ORDER
    assert PAGE_NAMES["tb"] == ("tb_monthly", "tb_hospitals")
    assert [p.display for p in PAGES][:2] == ["Trial Balance", "Trial Balance · Hospitals"]


def test_every_page_has_the_frame_and_four_tabs():
    for p in PAGES:
        tab_targets = [nav_target(v) for v in p.visuals if nav_target(v) in dict(TABS)]
        assert [t for t in tab_targets if t in dict(TABS)][:4] == [n for n, _ in TABS], p.name
        assert any(v.sample == "image" for v in p.visuals)
        assert any(v.roles.get("Values") == [meas("FR Period Text")] for v in p.visuals), p.name


def test_view_buttons_link_the_twin_pages():
    for statement, (monthly, hospital) in PAGE_NAMES.items():
        for view, page in (("monthly", monthly), ("hospitals", hospital)):
            targets = [nav_target(v) for v in page_frame(statement, view) if v.sample == "buttonNavigate"]
            assert monthly in targets and hospital in targets
            bar = [v for v in filter_bar(statement, view) if v.sample == "buttonNavigate"]
            assert [nav_target(v) for v in bar] == [monthly, hospital]
            filled = [nav_target(v) for v in bar if "fillColor" in json.dumps(v.props["fill"]) and "#0A1E32" in
                      json.dumps(v.props["fill"])]
            assert filled == [page]


def test_hospital_slicer_only_on_monthly_pages():
    for p in PAGES:
        has = any(v.sample.startswith("slicer") and BRANCH_NAME in v.roles.get("Values", []) for v in p.visuals)
        assert has == (p.name in MONTHLY), p.name
        has_text = any(v.sample == "textbox" and "All eight, side by side with the total" in repr(v.props)
                       for v in p.visuals)
        assert has_text == (p.name not in MONTHLY), p.name


def test_year_and_month_slicers():
    bar = filter_bar("tb", "monthly")
    year = next(v for v in bar if col("Date", "Year Pick") in v.roles.get("Values", []))
    assert "Current year" in json.dumps(year.props) and any(f.field == col("Date", "Year") for f in year.filters)
    offered = next(f for f in year.filters if f.field == col("Date", "Year"))
    assert offered.values == list(range(2022, 2041))
    month = next(v for v in bar if col("Date", "Month Short") in v.roles.get("Values", []))
    assert "filter" not in json.dumps(month.props.get("general", []))


def test_branch_filter_is_locked_on_every_page():
    assert hospitals().field == BRANCH_KEY and hospitals().values == [1, 2, 3, 4, 5, 6, 7, 8]
    assert all(hospitals() in p.filters for p in PAGES)
    with tempfile.TemporaryDirectory() as tmp:
        pbir.write_pbip(PAGES, Path(tmp), "HNH_Analytics_Test", "srv", report_filters=REPORT_FILTERS, report=FIN_REPORT)
        assert lock_branch_filters_on_disk(Path(tmp), FIN_REPORT.name) == len(PAGES)
        for page in (Path(tmp) / f"{FIN_REPORT.name}.Report" / "definition" / "pages").glob("*/page.json"):
            flt = json.loads(page.read_text("utf-8"))["filterConfig"]["filters"]
            assert any(f.get("isLockedInViewMode") for f in flt), page


def test_fields_are_in_the_finance_report_perspective():
    assert unknown_fields(PAGES, report_filters=REPORT_FILTERS, perspective="Finance Report") == []
