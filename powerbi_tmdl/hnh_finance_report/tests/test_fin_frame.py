"""The Finance report's frame: on every page, seven tabs, view buttons to the twin pages, drop-down slicers (the
Hospital slicer on Home and the monthly pages only), the hospitals page filter locked, every page but Home hidden, the
fields in the `Finance Report` perspective."""
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
STATEMENT_ORDER = ["tb_monthly", "tb_hospitals", "is_monthly", "is_hospitals", "bs_monthly", "bs_hospitals",
                   "kpi_monthly", "kpi_hospitals"]
ORDER = ["home", *STATEMENT_ORDER, "guide", "definitions"]
MONTHLY = [n for n in ORDER if n.endswith("monthly")]
WITH_FILTER_BAR = ["home", *STATEMENT_ORDER]


def lit(prop):
    return prop["expr"]["Literal"]["Value"]


def nav_target(v):
    link = v.props.get("visualLink", [{}])[0].get("properties", {})
    return lit(link["navigationSection"]).strip("'") if "navigationSection" in link else None


def test_specs_and_page_order():
    assert FIN_FRAME.title == "Finance Report" and FIN_FRAME.subtitle == "Hayat Healthcare" and FIN_FRAME.help == []
    assert TABS == [("home", "Home"), ("tb_monthly", "Trial Balance"), ("is_monthly", "Income Statement"),
                    ("bs_monthly", "Balance Sheet"), ("kpi_monthly", "KPIs & Ratios"), ("guide", "How to use"),
                    ("definitions", "Definitions")]
    assert FIN_REPORT.name == "HNH Finance" and FIN_REPORT.perspective == "Finance Report"
    assert [p.name for p in PAGES] == ORDER
    assert PAGE_NAMES["tb"] == ("tb_monthly", "tb_hospitals")
    assert [p.display for p in PAGES][:3] == ["Home", "Trial Balance", "Trial Balance · Hospitals"]


def test_only_home_is_visible():
    # user request 2026-11-19: navigation only through the tabs and buttons; the report opens on Home (first page)
    assert [p.name for p in PAGES if not p.hidden] == ["home"] and PAGES[0].name == "home"


def test_every_page_has_the_frame_and_seven_tabs():
    for p in PAGES:
        tab_targets = [nav_target(v) for v in p.visuals if nav_target(v) in dict(TABS)]
        assert tab_targets[:7] == [n for n, _ in TABS], p.name
        assert any(v.sample == "image" for v in p.visuals)
        has_period = any(v.roles.get("Values") == [meas("FR Period Text")] for v in p.visuals)
        assert has_period == (p.name in WITH_FILTER_BAR), p.name


def test_slicers_are_drop_downs():
    for p in PAGES:
        slicers = [v for v in p.visuals if v.sample.startswith("slicer")]
        assert all(v.sample == "slicerDropdown" for v in slicers), p.name
        assert (len(slicers) >= 2) == (p.name in WITH_FILTER_BAR), p.name


def test_every_page_is_reachable_by_a_button():
    targets = {nav_target(v) for p in PAGES for v in p.visuals if v.sample == "buttonNavigate"}
    assert {p.name for p in PAGES} <= targets


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
        assert has == (p.name in MONTHLY or p.name == "home"), p.name
        has_text = any(v.sample == "textbox" and "All eight hospitals, side by side with the total" in repr(v.props)
                       for v in p.visuals)
        assert has_text == (p.name in STATEMENT_ORDER and p.name not in MONTHLY), p.name


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
