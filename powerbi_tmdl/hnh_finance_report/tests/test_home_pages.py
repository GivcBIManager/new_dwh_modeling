"""Home, How to use and Definitions (user request 2026-11-19)."""
import pages_landing as ph
from fin_frame import PAGE_NAMES
from model import meas


def _nav_targets(page):
    out = []
    for v in page.visuals:
        link = v.props.get("visualLink", [{}])[0].get("properties", {})
        if v.sample == "buttonNavigate" and "navigationSection" in link:
            out.append(link["navigationSection"]["expr"]["Literal"]["Value"].strip("'"))
    return out


def test_home_links_every_statement_view_and_the_text_pages():
    targets = _nav_targets(ph.home_page())
    for monthly, hospitals in PAGE_NAMES.values():
        assert monthly in targets and hospitals in targets
    assert "guide" in targets and "definitions" in targets


def test_home_headlines_are_the_statement_tiles():
    values = [v.roles["Values"][0] for v in ph.home_page().visuals if v.sample == "card"
              and v.roles.get("Values") and v.roles["Values"][0].name in
              ("FR Net Revenue", "FR EBITDA", "FR Net Profit", "FR Total Assets")]
    assert values == [meas("FR Net Revenue"), meas("FR EBITDA"), meas("FR Net Profit"), meas("FR Total Assets")]


def test_every_kpi_has_a_definition():
    kpis = ph.read_kpis()
    assert len(kpis) == 27
    assert {k["code"] for k in kpis} == set(ph.KPI_DEFINITIONS)


def test_definitions_page_names_every_kpi():
    text = repr(ph.definitions_page().visuals)
    for k in ph.read_kpis():
        assert k["name"] + ": " in text, k["name"]
    assert "Higher is better" in text and "Lower is better" in text


def test_text_pages_are_hidden_and_fit_the_page():
    for page in (ph.guide_page(), ph.definitions_page()):
        assert page.hidden
        for v in page.visuals:
            assert v.x >= 0 and v.y >= 0 and v.x + v.w <= 1920 and v.y + v.h <= 1080, (page.name, v.sample)
