"""The Finance report's shared content blocks: KPI tile, charts, statement matrix."""
import fin_blocks
from fin_blocks import (MATRIX_RECT, TILES_RECT, monthly_chart, ranked_bars, statement_matrix, tile, tile_rects,
                        variance_chart)
from fin_frame import BRANCH_NAME, MONTH_SHORT, MUTED
from model import col, meas

PAGE, VIEW = col("Finance Column", "Page"), col("Finance Column", "View")
GROUP, COLUMN = col("Finance Column", "Group Name"), col("Finance Column", "Column Name")


def _cards(visuals):
    return [v for v in visuals if v.sample == "card"]


def test_tile_has_value_and_two_coloured_lines():
    v, l1, c1, l2, c2 = (meas(n) for n in ("FR V", "FR L1", "FR C1", "FR L2", "FR C2"))
    out = tile("Net revenue", v, l1, c1, l2, c2, (24, 178, 266, 82))
    assert out[0].sample == "panel"
    cards = _cards(out)
    assert [c.roles["Values"] for c in cards] == [[v], [l1], [l2]]
    assert cards[0].title == "NET REVENUE"
    assert MUTED in repr(cards[0].props["title"])
    assert "25" in repr(cards[0].props["labels"])
    for card, colour in ((cards[1], c1), (cards[2], c2)):
        assert colour.name in repr(card.props["labels"]) and "Measure" in repr(card.props["labels"])
        assert "right" in repr(card.props["labels"]).lower()
    x, y, w, h = 24, 178, 266, 82
    for c in out:
        assert x <= c.x and c.x + c.w <= x + w and y <= c.y and c.y + c.h <= y + h


def test_tile_rects_are_a_two_by_two_grid():
    r = tile_rects()
    assert len(r) == 4 and r[0][:2] == (24, 178)
    assert r[1][0] == r[0][0] + r[0][2] + 8 and r[2][1] == r[0][1] + r[0][3] + 8
    assert r[3][0] + r[3][2] == TILES_RECT[0] + TILES_RECT[2] and r[3][1] + r[3][3] == TILES_RECT[1] + TILES_RECT[3]
    six = tile_rects(6)
    assert len(six) == 6 and six[0][0] == 24 and six[5][0] + six[5][2] == 1896


def test_statement_matrix_filters_its_page_and_view():
    rows = [col("Finance Line", "FS Caption Name")]
    cell = meas("FR IS Cell")
    # 'Finance Column'[View] holds "monthly" and "hospital" (dim_finance_column.sql)
    for view, stored in (("monthly", "monthly"), ("hospitals", "hospital")):
        m = statement_matrix("is", view, rows, cell, MATRIX_RECT, 1)
        assert m.sample == "matrix" and (m.x, m.y, m.w, m.h) == (24, 362, 1872, 694)
        assert {(f.field, f.op, tuple(f.values)) for f in m.filters} == {(PAGE, "eq", ("is",)), (VIEW, "eq", (stored,))}
        assert m.roles["Rows"] == rows and m.roles["Values"] == [cell]
        assert m.roles["Columns"] == ([COLUMN, BRANCH_NAME] if view == "hospitals" else [GROUP, COLUMN])


def test_matrix_values_use_the_cell_colour_measure():
    m = statement_matrix("tb", "monthly", [col("Finance Line", "Account Name")], meas("FR TB Cell"), MATRIX_RECT, 2)
    text = repr(m.props["values"])
    assert "FR Cell Colour" in text and "fontColor" in text and "Right" in text
    assert m.expand is False
    assert "#0A2D6E" in repr(m.props["columnHeaders"])


def test_charts():
    a, b = meas("FR A"), meas("FR B")
    mc = monthly_chart("Net revenue", [a, b], ["#0A2D6E", "#32A5E6"], (576, 178, 654, 172))
    assert mc.sample == "columnChart" and mc.roles["Category"] == [MONTH_SHORT] and mc.roles["Y"] == [a, b]
    assert "#32A5E6" in repr(mc.props) and mc.title == "Net revenue"
    vc = variance_chart("Variance", [a], (1242, 178, 654, 172))
    assert vc.sample == "columnChart" and vc.roles["Y"] == [a]
    rb = ranked_bars("By hospital", a, (576, 178, 654, 172), meas("FR Fav"))
    assert rb.sample == "barChart" and rb.roles["Category"] == [BRANCH_NAME] and rb.sort == a and rb.sort_dir == "desc"
    assert "FR Fav" in repr(rb.props)
    assert "FR Fav" not in repr(ranked_bars("By hospital", a, (0, 0, 10, 10), None).props)
    assert fin_blocks.TILES_RECT == (24, 178, 540, 172)


def test_variance_chart_takes_one_colour_per_series():
    a, b = meas("FR A"), meas("FR B")
    vc = variance_chart("Variance", [a, b], (1242, 178, 654, 172), ["#0A2D6E", "#32A5E6"])
    points = vc.props["dataPoint"]
    assert [(p["selector"]["metadata"], p["properties"]["fill"]["solid"]["color"]["expr"]["Literal"]["Value"])
            for p in points] == [(a.ref, "'#0A2D6E'"), (b.ref, "'#32A5E6'")]
    try:
        variance_chart("Variance", [a, b], (1242, 178, 654, 172), ["#0A2D6E"])
    except ValueError:
        pass
    else:
        raise AssertionError("one colour per series")


def test_tile_without_lines_has_only_the_value_card():
    v = meas("FR V")
    out = tile("Period credits", v, None, None, None, None, (24, 178, 266, 82))
    assert [c.roles["Values"] for c in _cards(out)] == [[v]]
    one = tile("Out of balance", v, meas("FR L1"), meas("FR C1"), None, None, (24, 178, 266, 82))
    assert [c.roles["Values"] for c in _cards(one)] == [[v], [meas("FR L1")]]


def test_tile_value_filter_and_decimals():
    from model import Filter
    kpi = Filter(col("Finance KPI", "KPI Code"), "eq", ["FR_CURRENT_RATIO"])
    out = tile("Current ratio", meas("FR KPI Value"), meas("FR L1"), meas("FR C1"), meas("FR L2"), meas("FR C2"),
               (24, 178, 266, 82), value_filters=[kpi], decimals=2)
    value = _cards(out)[0]
    assert value.filters == [kpi]
    assert "labelPrecision" in repr(value.props["labels"]) and "2L" in repr(value.props["labels"])


def test_matrix_column_subtotals_off_and_subtotals_bold():
    m = statement_matrix("tb", "monthly", [col("GL FS Monthly", "FS Type Name")], meas("FR TB Cell"), MATRIX_RECT, 1)
    sub = m.props["subTotals"][0]["properties"]
    assert sub["columnSubtotals"]["expr"]["Literal"]["Value"] == "false"
    assert sub["bold"]["expr"]["Literal"]["Value"] == "true" and "fontBold" not in sub


def test_matrix_without_grand_total_turns_off_the_first_level_subtotal():
    rows = [col("P&L Line", "Section Name"), col("P&L Line", "PL Line Label")]
    m = statement_matrix("is", "monthly", rows, meas("FR IS Cell"), MATRIX_RECT, 1, grand_total=False)
    entries = m.props["subTotals"]
    assert entries[0]["properties"]["perRowLevel"]["expr"]["Literal"]["Value"] == "true"
    level = [e for e in entries if e.get("selector") == {"metadata": rows[0].ref}]
    assert len(level) == 1 and level[0]["properties"]["levelSubtotalEnabled"]["expr"]["Literal"]["Value"] == "false"
    assert not any(e.get("selector") == {"metadata": rows[1].ref} for e in entries)  # section subtotals stay
    shown = statement_matrix("is", "monthly", rows, meas("FR IS Cell"), MATRIX_RECT, 1)
    assert "levelSubtotalEnabled" not in repr(shown.props["subTotals"])


def test_matrix_row_band_measure_colours_the_value_background():
    m = statement_matrix("is", "monthly", [col("P&L Line", "Section Name")], meas("FR IS Cell"), MATRIX_RECT, 1,
                         row_band=meas("FR Row Band"))
    values = m.props["values"][0]["properties"]
    assert "FR Row Band" in repr(values["backColor"]) and "Measure" in repr(values["backColor"])
    plain = statement_matrix("is", "monthly", [col("P&L Line", "Section Name")], meas("FR IS Cell"), MATRIX_RECT, 1)
    assert "backColor" not in plain.props["values"][0]["properties"]


def test_hospital_matrix_totals_the_hospitals_per_column():
    # ruling R15b: the "All hospitals" block is the Branch level's column subtotal (per column: Closing, Ach %, Growth)
    m = statement_matrix("tb", "hospitals", [col("GL FS Monthly", "FS Type Name")], meas("FR TB Cell"), MATRIX_RECT, 1)
    entries = m.props["subTotals"]
    general = entries[0]["properties"]
    assert general["columnSubtotals"]["expr"]["Literal"]["Value"] == "true"
    assert general["perColumnLevel"]["expr"]["Literal"]["Value"] == "true"
    by_level = {e["selector"]["metadata"]: e["properties"] for e in entries if "selector" in e}
    assert by_level[COLUMN.ref]["levelSubtotalEnabled"]["expr"]["Literal"]["Value"] == "false"
    assert by_level[BRANCH_NAME.ref]["levelSubtotalEnabled"]["expr"]["Literal"]["Value"] == "true"
    assert by_level[BRANCH_NAME.ref]["levelSubtotalLabel"]["expr"]["Literal"]["Value"] == "'All hospitals'"
