"""Finance KPI measures (finance report plan, Task 11): FR KPI Value dispatches every KPI code of dim_finance_kpi.sql in a
SWITCH branch, the cell handles every kind of the 'kpi' page of 'Finance Column', and the KPI measures can be evaluated
while 'Finance KPI' and 'Finance Column' filter them (ruling R9a: a disconnected table must not trip the measure guards)."""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import hnh_tmdl as t  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
MARTS = ROOT / "hnh_dwh" / "models" / "hnh" / "marts" / "finance"
KPI_DIM = (MARTS / "dim_finance_kpi.sql").read_text(encoding="utf-8")
COLUMN_DIM = (MARTS / "dim_finance_column.sql").read_text(encoding="utf-8")
MEASURES = {m.name: m for m in t.measures(
    (ROOT / "ssas" / "HNH_Analytics" / "tables" / f"{t.MEASURE_TABLE}.tmdl").read_text(encoding="utf-8"))}
KPI_ROW = re.compile(r"\('(FR_\w+)', '[^']*', \d+, '[^']*', '([%xd])', (-?1), \d+, '(\w*)'\)")
KPI_MEASURES = [n for n in MEASURES if n.startswith("FR KPI ")]


def kpi_codes() -> list:
    return [row[0] for row in KPI_ROW.findall(KPI_DIM)]


def switch_codes(measure: str) -> list:
    """Codes that start a SWITCH branch of the measure: a quoted FR_ code at the start of a line."""
    return re.findall(r'(?m)^\s*"(FR_\w+)",', MEASURES[measure].expression)


def test_every_kpi_code_has_a_switch_branch():
    codes = kpi_codes()
    assert len(codes) == 27 and len(set(codes)) == 27
    value = switch_codes("FR KPI Value")
    assert sorted(set(codes) - set(value)) == [], "KPI codes without a branch in FR KPI Value"
    assert sorted(set(value) - set(codes)) == [], "FR KPI Value branches for codes that are not KPIs"
    assert len(value) == len(set(value)), "a code has two branches"


def test_budget_branches_are_kpi_codes():
    codes = set(kpi_codes())
    budget = switch_codes("FR KPI Budget")
    assert budget and set(budget) <= codes
    # growth and balance sheet KPIs have no budget
    assert not {c for c in budget if c.endswith("_GROWTH") or c in ("FR_AR_DAYS", "FR_CURRENT_RATIO")}


def test_cell_handles_every_kpi_column_kind():
    kinds = {kind for page, _view, kind in re.findall(r"\('(\w+)', '(\w+)', '[^']*', \d+, '[^']*', \d+, '(\w+)', \d+\)", COLUMN_DIM) if page == "kpi"}
    assert {"target", "actual", "status", "budget", "vs_bud", "ly", "vs_ly", "month"} <= kinds
    expression = MEASURES["FR KPI Cell"].expression
    assert sorted(k for k in kinds if f'"{k}"' not in expression) == []


def test_every_kpi_measure_is_allowed_under_finance_column_and_kpi_filters():
    assert len(KPI_MEASURES) >= 16
    for name in KPI_MEASURES:
        measure = MEASURES[name]
        allowed = measure.annotations.get("hnh_guard_allow", "")
        assert "Finance Column" in allowed and "Finance KPI" in allowed, name
        guard = re.search(r"VAR __Wrong = \[(_Guard [^\]]+)\]", measure.expression)
        if guard:
            assert "'Finance KPI'" not in MEASURES[guard.group(1)].expression, f"{name} would return guard text under Finance KPI"
            assert "'Finance Column'" not in MEASURES[guard.group(1)].expression, f"{name} would return guard text under Finance Column"


def test_value_budget_and_cell_read_without_the_selection_tables():
    # the Fin * blocks they call carry their own guards, which do not allow Finance KPI / Finance Column
    for name in ("FR KPI Value", "FR KPI Budget"):
        expression = MEASURES[name].expression
        assert "REMOVEFILTERS ( 'Finance KPI' )" in expression and "REMOVEFILTERS ( 'Finance Column' )" in expression, name
    assert "REMOVEFILTERS ( 'Finance Column' )" in MEASURES["FR KPI Cell"].expression


def test_status_rule_words_colours_and_unit_formats():
    status = MEASURES["FR KPI Status"].expression
    for word in ("On target", "Watch", "Off target", "No target yet"):
        assert f'"{word}"' in status
    colour = MEASURES["FR KPI Status Colour"].expression
    for hex_code in ("#D9F3EE", "#FFDF8A", "#F5A99B", "#9AA7B5"):
        assert hex_code in colour
    attainment = MEASURES["FR KPI Attainment"].expression
    assert "1.25" in attainment and "MIN ( 1.25" in attainment and "MAX ( 0" in attainment
    cell = MEASURES["FR KPI Cell"].expression
    for text in ('"0.0%"', '"0.00""x"""', '"0 ""d"""', "No budget yet", "No target yet"):
        assert text in cell


def test_ratios_with_a_negative_denominator_are_blank():
    value = MEASURES["FR KPI Value"].expression
    assert "IF ( YearEBITDA > 0" in value and "IF ( Interest > 0" in value


def test_receivable_days_are_the_balance_sheet_tile_formula():
    value = MEASURES["FR KPI Value"].expression
    assert 'DIVIDE ( [Fin Trade Receivables], [Fin Net Revenue] ) * [Fin Period Days]' in value
