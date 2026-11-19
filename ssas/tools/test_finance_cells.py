"""Finance report matrix cells (finance report plan, Task 10): every kind of 'Finance Column' that a statement page
offers is handled by that page's cell measure, and the cell, colour and header measures can be evaluated while
'Finance Column' filters them (ruling R9a: a disconnected table must not trip the measure guards)."""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import hnh_tmdl as t  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
DIM = (ROOT / "hnh_dwh" / "models" / "hnh" / "marts" / "finance" / "dim_finance_column.sql").read_text(encoding="utf-8")
MEASURES = {m.name: m for m in t.measures(
    (ROOT / "ssas" / "HNH_Analytics" / "tables" / f"{t.MEASURE_TABLE}.tmdl").read_text(encoding="utf-8"))}
CELLS = {"tb": "FR TB Cell", "is": "FR IS Cell", "bs": "FR BS Cell"}
ROW = re.compile(r"\('(\w+)', '(\w+)', '[^']*', \d+, '[^']*', \d+, '(\w+)', \d+\)")


def kinds_of(page: str) -> set:
    return {kind for p, _view, kind in ROW.findall(DIM) if p == page}


def test_every_finance_column_kind_is_handled():
    assert sum(len(kinds_of(p)) for p in CELLS) >= 20
    for page, name in CELLS.items():
        expression = MEASURES[name].expression
        missing = sorted(k for k in kinds_of(page) if f'"{k}"' not in expression)
        assert not missing, f"{name} does not handle the kinds {missing} of page {page}"


def test_cell_measures_read_without_the_finance_column_filter():
    # the guards of the FR measures they call would otherwise say "can't be analysed by Finance Column"
    for name in [*CELLS.values(), "FR Cell Colour"]:
        expression = MEASURES[name].expression
        assert "REMOVEFILTERS ( 'Finance Column' )" in expression, name


def test_cell_measures_are_allowed_under_finance_column_filters():
    for name in [*CELLS.values(), "FR Cell Colour"]:
        measure = MEASURES[name]
        assert "Finance Column" in measure.annotations.get("hnh_guard_allow", ""), name
        guard = re.search(r"VAR __Wrong = \[(_Guard [^\]]+)\]", measure.expression).group(1)
        assert "'Finance Column'" not in MEASURES[guard].expression, f"{name} would return guard text under Finance Column"


def test_month_columns_blank_when_the_month_is_not_picked():
    for name in CELLS.values():
        assert "MonthNum IN VALUES ( 'Date'[Month] )" in MEASURES[name].expression, name


def test_colours_and_placeholder_words():
    expression = MEASURES["FR Cell Colour"].expression
    for colour in ("#04705F", "#C2230A", "#9AA7B5", "#0A1E32", "#4D5B6B"):
        assert colour in expression
    assert "No budget yet" in MEASURES["FR TB Cell"].expression and "Not budgeted" in MEASURES["FR Budget Label"].expression


def test_chart_series_have_a_default_line_per_page():
    for tag, default in (("TB", "trade receivables, net"), ("BS", "trade receivables, net"), ("IS", "NET_REVENUE")):
        for series in ("Actual", "Budget", "Last Year", "vs Budget %", "vs LY %"):
            expression = MEASURES[f"FR Chart {tag} {series}"].expression
            assert "ISFILTERED" in expression and default in expression, f"FR Chart {tag} {series}"


def test_tiles_have_two_lines_and_colours():
    for tile in ("Net Revenue", "EBITDA", "EBITDA Margin", "Net Profit", "Total Assets", "Net Working Capital", "Current Ratio", "Receivable Days"):
        for line in ("vs Budget", "vs Budget Colour", "vs LY", "vs LY Colour"):
            assert f"FR Tile {tile} {line}" in MEASURES


def test_chart_measures_are_allowed_under_finance_column_filters():
    # ruling R15a: a selected matrix value cell passes 'Finance Column' on to the charts
    charts = [name for name in MEASURES if name.startswith("FR Chart ")]
    assert len(charts) >= 20
    for name in charts:
        measure = MEASURES[name]
        assert "REMOVEFILTERS ( 'Finance Column' )" in measure.expression, name
        assert "Finance Column" in measure.annotations.get("hnh_guard_allow", ""), name
        guard = re.search(r"VAR __Wrong = \[(_Guard [^\]]+)\]", measure.expression).group(1)
        assert "'Finance Column'" not in MEASURES[guard].expression, f"{name} would return guard text under Finance Column"


def test_percent_of_revenue_ignores_the_income_statement_rows():
    # the income statement's rows are P&L Report caption and account columns; revenue must be read across them
    # or "% Rev" is blank below line level
    expression = MEASURES["FR % of Revenue"].expression
    for column in ("FS Caption Name", "Account Name", "FS Caption", "FS Line", "Account Code"):
        assert f"'P&L Report'[{column}]" in expression, column
