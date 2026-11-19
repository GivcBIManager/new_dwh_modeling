"""The statement pages (trial balance, income statement, balance sheet; monthly and hospital comparison): matrix rows,
tiles, charts, the IS grand total hidden and its subtotal band, the balance sheet's Difference card, the fields in the
`Finance Report` perspective."""
import importlib.util
import sys
from pathlib import Path

import pages_statements as ps
from fields import unknown_fields
from fin_blocks import LEFT_CHART_RECT, RIGHT_CHART_RECT
from model import Filter, col, meas

ORDER = ["tb_monthly", "tb_hospitals", "is_monthly", "is_hospitals", "bs_monthly", "bs_hospitals"]
BRANCH_NAME = col("Branch", "Branch Name")
IS_NOTE = ("Medicines and consumables: Oasis books cost of goods sold under Consumables. G&A budget excludes marketing "
           "and head office charges.")


def _fin_pages():
    """This report's pages.py, loaded as `fin_pages` (test_fin_frame.py does the same; the name `pages` is the BSC's)."""
    if "fin_pages" not in sys.modules:
        spec = importlib.util.spec_from_file_location("fin_pages", Path(__file__).resolve().parents[1] / "pages.py")
        module = importlib.util.module_from_spec(spec)
        sys.modules["fin_pages"] = module
        spec.loader.exec_module(module)
    return sys.modules["fin_pages"]


def _page(name):
    return next(p for p in ps.PAGES if p.name == name)


def _matrix(page):
    found = [v for v in page.visuals if v.sample == "matrix"]
    assert len(found) == 1, page.name
    return found[0]


def _text_of(v):
    return "".join(r["value"] for p in v.props["general"][0]["properties"]["paragraphs"] for r in p["textRuns"])


def _tile_cards(page):
    """(label, value card) of each tile: the capitals label text box and the card right under it, in page order."""
    out = []
    for t in page.visuals:
        if t.sample == "textbox" and 170 < t.y < 380 and _text_of(t).isupper():  # under the frame
            card = [v for v in page.visuals if v.sample == "card" and v.x == t.x and v.y == t.y + t.h]
            assert len(card) == 1, _text_of(t)
            out.append((_text_of(t), card[0]))
    return out


def _tile_values(page):
    """(label, value measure, value filters) of each tile's value card, in page order."""
    return [(label, v.roles["Values"][0], v.filters) for label, v in _tile_cards(page)]


def _charts(page):
    return [v for v in page.visuals if v.sample in ("columnChart", "barChart")]


def test_six_statement_pages_in_order():
    assert [p.name for p in ps.PAGES] == ORDER
    report = _fin_pages().PAGES
    assert [p.name for p in report][:6] == ORDER
    for p in report[:6]:
        assert any(v.sample == "matrix" for v in p.visuals), p.name
    assert [p.name for p in report][6:] == ["kpi_monthly", "kpi_hospitals"]


def test_matrix_rows_per_page():
    gl, pl, rep = "GL FS Monthly", "P&L Line", "P&L Report"
    rows = {"tb": [col(gl, "FS Type Name"), col(gl, "FS Element Name"), col(gl, "FS Category Name"),
                   col(gl, "FS Caption Name"), col(gl, "Account Name")],
            "is": [col(pl, "Section Name"), col(pl, "PL Line Label"), col(rep, "FS Caption Name"), col(rep, "Account Name")],
            "bs": [col(gl, "BS Side"), col(gl, "BS Element"), col(gl, "BS Category"), col(gl, "BS Caption"),
                   col(gl, "Account Name")]}
    cells = {"tb": "FR TB Cell", "is": "FR IS Cell", "bs": "FR BS Cell"}
    for name in ORDER:
        st, view = name.split("_")
        m = _matrix(_page(name))
        assert m.roles["Rows"] == rows[st], name
        assert m.roles["Values"] == [meas(cells[st])], name
        stored = {"monthly": "monthly", "hospitals": "hospital"}[view]
        assert {(f.field.name, tuple(f.values)) for f in m.filters} == {("Page", (st,)), ("View", (stored,))}, name
        assert (BRANCH_NAME in m.roles["Columns"]) == (view == "hospitals"), name


def test_tiles_per_page():
    labels = {"tb": ["PERIOD DEBITS", "PERIOD CREDITS", "OUT OF BALANCE", "TOTAL ASSETS"],
              "is": ["NET REVENUE", "EBITDA", "EBITDA MARGIN", "NET PROFIT"],
              "bs": ["TOTAL ASSETS", "NET WORKING CAPITAL", "CURRENT RATIO", "RECEIVABLE DAYS"]}
    # ruling R15c: visible measures only (EBITDA Margin % is a visible Finance\Statement measure)
    values = {"tb": ["FR Period Debits", "FR Period Credits", "FR Out of Balance", "FR Total Assets"],
              "is": ["FR Net Revenue", "FR EBITDA", "EBITDA Margin %", "FR Net Profit"],
              "bs": ["FR Total Assets", "FR Net Working Capital", "FR KPI Value", "FR KPI Value"]}
    kpi = col("Finance KPI", "KPI Code")
    for name in ORDER:
        st = name.split("_")[0]
        tiles = _tile_values(_page(name))
        assert [t[0] for t in tiles] == labels[st], name
        assert [t[1].name for t in tiles] == values[st], name
        if st == "bs":
            assert tiles[2][2] == [Filter(kpi, "eq", ["FR_CURRENT_RATIO"])]
            assert tiles[3][2] == [Filter(kpi, "eq", ["FR_AR_DAYS"])]
    lines = {v.roles["Values"][0].name for p in ps.PAGES for v in p.visuals
             if v.sample == "card" and v.roles.get("Values")}
    for needed in ("FR Tile Out of Balance", "FR Tile Total Assets vs Budget", "FR Tile Total Assets vs LY",
                   "FR Tile Net Revenue vs Budget", "FR Tile EBITDA vs LY", "FR Tile EBITDA Margin vs Budget",
                   "FR Tile Net Profit vs LY", "FR Tile Net Working Capital vs Budget", "FR Tile Current Ratio vs LY",
                   "FR Tile Receivable Days vs Budget"):
        assert needed in lines, needed
    tb = _page("tb_monthly")
    debit_cards = [v for label, v in _tile_cards(tb) if label in ("PERIOD DEBITS", "PERIOD CREDITS")]
    assert len(debit_cards) == 2 and all(v.w > 200 for v in debit_cards)  # no lines: the value takes the tile's width


def test_hospital_pages_have_no_hospital_slicer():
    for p in ps.PAGES:
        slicer = any(v.sample.startswith("slicer") and BRANCH_NAME in v.roles.get("Values", []) for v in p.visuals)
        assert slicer == p.name.endswith("monthly"), p.name


def test_fields_in_perspective():
    assert unknown_fields(ps.PAGES, perspective="Finance Report") == []
    assert unknown_fields(_fin_pages().PAGES, report_filters=_fin_pages().REPORT_FILTERS,
                          perspective="Finance Report") == []


def test_monthly_charts_and_hospital_ranked_bars():
    series = ["#0A2D6E", "#32A5E6", "#A0BEFF"]
    for st, short in (("tb", "TB"), ("is", "IS"), ("bs", "BS")):
        left, right = _charts(_page(f"{st}_monthly"))
        assert [m.name for m in left.roles["Y"]] == [f"FR Chart {short} {s}" for s in ("Actual", "Budget", "Last Year")]
        assert (left.x, left.y) == LEFT_CHART_RECT[:2] and (right.x, right.y) == RIGHT_CHART_RECT[:2]
        for colour in series:
            assert colour in repr(left.props["dataPoint"])
        assert [m.name for m in right.roles["Y"]] == [f"FR Chart {short} vs Budget %", f"FR Chart {short} vs LY %"]
        fills = [p["properties"]["fill"]["solid"]["color"]["expr"]["Literal"]["Value"] for p in right.props["dataPoint"]]
        assert fills == ["'#0A2D6E'", "'#32A5E6'"]
        bars = _charts(_page(f"{st}_hospitals"))
        assert [b.sample for b in bars] == ["barChart", "barChart"]
        # ruling R15d: budget achievement % on the left, growth % on the right
        assert [b.roles["Y"][0].name for b in bars] == [f"FR Chart {short} Achievement %", f"FR Chart {short} vs LY %"]
        fav = [repr(b.props["dataPoint"]) for b in bars]
        if st == "is":
            assert "FR Chart IS vs Budget Colour" in fav[0] and "FR Chart IS vs LY Colour" in fav[1]
        else:
            assert all("Measure" not in f for f in fav)


def test_matrix_drives_the_charts_not_the_tiles():
    for p in ps.PAGES:
        m = _matrix(p)
        charts = _charts(p)
        off = {id(i.target) for i in p.interactions if i.source is m and i.type == "NoFilter"}
        assert not any(id(c) in off for c in charts), p.name
        data_cards = [v for v in p.visuals if v.sample == "card" and v.y > 170]
        assert data_cards and all(id(c) in off for c in data_cards), p.name
        for c in charts:  # a chart's month or bar does not filter the matrix, the tiles or the other chart
            targets = {id(i.target) for i in p.interactions if i.source is c and i.type == "NoFilter"}
            assert id(m) in targets and all(id(d) in targets for d in data_cards), p.name


def test_income_statement_hides_the_grand_total_and_bands_subtotal_lines():
    for name in ("is_monthly", "is_hospitals"):
        m = _matrix(_page(name))
        level = [e for e in m.props["subTotals"] if e.get("selector") == {"metadata": "P&L Line.Section Name"}]
        assert level and level[0]["properties"]["levelSubtotalEnabled"]["expr"]["Literal"]["Value"] == "false"
        assert "FR Row Band" in repr(m.props["values"][0]["properties"]["backColor"])
    for name in ("tb_monthly",):
        assert "levelSubtotalEnabled" not in repr(_matrix(_page(name)).props["subTotals"])


def test_balance_sheet_hides_the_grand_total():
    # the grand total would add Assets + Liabilities & equity + Not mapped
    for name in ("bs_monthly", "bs_hospitals"):
        m = _matrix(_page(name))
        level = [e for e in m.props["subTotals"] if e.get("selector") == {"metadata": "GL FS Monthly.BS Side"}]
        assert level and level[0]["properties"]["levelSubtotalEnabled"]["expr"]["Literal"]["Value"] == "false", name


def test_page_headers_and_the_income_statement_note():
    for name in ("is_monthly", "is_hospitals"):
        assert any(v.sample == "textbox" and IS_NOTE in repr(v.props) for v in _page(name).visuals), name
    for p in ps.PAGES:
        m = _matrix(p)
        heads = [v for v in p.visuals if v.sample == "textbox" and v.y < m.y and v.y > 380
                 and "Difference (cutover / unmapped)" not in repr(v.props)]
        assert len(heads) == 1, p.name


def test_balance_sheet_difference_card_at_the_header_right():
    # under the matrix the card ran off the page (screenshot 2026-11-19): it sits at the header's right, labelled
    for name in ("bs_monthly", "bs_hospitals"):
        p = _page(name)
        m = _matrix(p)
        diff = [v for v in p.visuals if v.roles.get("Values") == [meas("FR BS Difference")]]
        assert len(diff) == 1, name
        d = diff[0]
        assert d.sample == "card" and d.x + d.w == m.x + m.w and m.y - 60 <= d.y and d.y + d.h <= m.y
        label = [v for v in p.visuals if v.sample == "textbox" and "Difference (cutover / unmapped)" in repr(v.props)]
        assert len(label) == 1 and label[0].x + label[0].w <= d.x and abs(label[0].y - d.y) <= 8
        head = [v for v in p.visuals if v.sample == "textbox" and "Statement of financial position" in repr(v.props)]
        assert len(head) == 1 and head[0].x + head[0].w <= label[0].x
    for name in ORDER[:4]:
        assert not any(v.roles.get("Values") == [meas("FR BS Difference")] for v in _page(name).visuals)


def test_tiles_bind_visible_measures_only():
    # ruling R15c: a tile binds no hidden measure
    import re

    import fields
    text = (fields.MODEL_DIR / "tables" / "_Measures.tmdl").read_text(encoding="utf-8")
    hidden = set()
    for block in re.split(r"\n\t(?=measure )", text):
        m = re.match(r"measure '?([^'=]+?)'? =", block)
        if m and re.search(r"^\t\tisHidden$", block.split("\n\t///", 1)[0], re.M):
            hidden.add(m.group(1))
    assert "Fin Total Assets" in hidden and "FR Total Assets" not in hidden
    used = {f.name for p in ps.PAGES for v in p.visuals if v.sample == "card" for f in v.roles.get("Values", [])}
    assert used and not (used & hidden), sorted(used & hidden)
