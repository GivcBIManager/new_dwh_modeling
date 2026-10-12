"""Offline checks of the measure catalogue (KPI catalogue plan). Every measure in tables/_Measures.tmdl is documented,
foldered and formatted, references columns and measures that exist, and is covered by a DAX-vs-ClickHouse check in
ssas/tests/measures/*.json. The Time Calculation snapshot lists and the perspectives must agree with the measure file."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import hnh_tmdl as t  # noqa: E402
import model_config as cfg  # noqa: E402

SSAS = Path(__file__).resolve().parents[1]
MODEL = SSAS / "HNH_Analytics"
DOMAINS = {"Patient Flow", "Revenue Cycle", "Claims & Pre-auth", "Finance", "Workforce", "Supply Chain",
           "Patient Experience", t.DIAGNOSTICS}
MEASURES_TEXT = (MODEL / "tables" / f"{t.MEASURE_TABLE}.tmdl").read_text(encoding="utf-8")
MEASURES = t.measures(MEASURES_TEXT)
NAMES = {m.name for m in MEASURES}
COLUMNS = dict(t.table_columns(path.read_text(encoding="utf-8")) for path in (MODEL / "tables").glob("*.tmdl"))
CHECKS = [check for path in sorted((SSAS / "tests" / "measures").glob("*.json"))
          for check in json.loads(path.read_text(encoding="utf-8"))]


def unknown_references(dax):
    columns, names = t.dax_references(dax)
    bad = [f"{table}[{column}]" for table, column in sorted(columns) if column not in COLUMNS.get(table, set())]
    return bad + [f"[{name}]" for name in sorted(names - NAMES)]


def test_every_measure_has_a_description_folder_and_format():
    bad = [m.name for m in MEASURES
           if not m.description or not m.folder or not (m.format_string or m.format_expression)]
    assert bad == []


def test_every_folder_starts_with_a_domain():
    assert [m.name for m in MEASURES if m.folder.split("\\")[0] not in DOMAINS] == []


def test_measure_names_are_unique():
    names = [m.name for m in MEASURES]
    assert sorted({n for n in names if names.count(n) > 1}) == []


def test_measures_reference_existing_columns_and_measures():
    bad = {m.name: unknown_references(m.expression + "\n" + m.format_expression) for m in MEASURES}
    assert {name: refs for name, refs in bad.items() if refs} == {}


def test_checks_reference_existing_columns_and_measures():
    bad = {c["name"]: unknown_references(c["dax"]) for c in CHECKS}
    assert {name: refs for name, refs in bad.items() if refs} == {}


def test_every_measure_has_a_check():
    checked = set().union(*(t.dax_references(c["dax"])[1] for c in CHECKS))
    assert sorted(m.name for m in MEASURES if m.folder.split("\\")[0] != t.DIAGNOSTICS and m.name not in checked) == []


def test_check_names_are_unique():
    names = [c["name"] for c in CHECKS]
    assert sorted({n for n in names if names.count(n) > 1}) == []


def test_snapshot_lists_match_the_snapshot_measures():
    snapshots = sorted(m.name for m in MEASURES if m.annotations.get("hnh_snapshot") == "1")
    lists = t.snapshot_lists((MODEL / "tables" / "Time Calculation.tmdl").read_text(encoding="utf-8"))
    assert len(lists) == 5
    assert [sorted(found) for found in lists] == [snapshots] * 5


def test_perspectives_list_their_domain_measures():
    folders = t.measure_folders(MEASURES_TEXT)
    stale = []
    for name in cfg.PERSPECTIVES:
        text = (MODEL / "perspectives" / f"{name}.tmdl").read_text(encoding="utf-8")
        wanted = t.perspective_measures(name, folders, cfg.PERSPECTIVE_MEASURE_DOMAINS)
        if t.replace_perspective_measures(text, wanted) != text:
            stale.append(name)
    assert stale == [], "run python ssas/tools/sync_perspectives.py"


def test_nps_measures_show_insufficient_sample():
    bad = [m.name for m in MEASURES if "NPS (5-point)" in m.name and "insufficient sample" not in m.format_expression]
    assert bad == []


# DAX function names a VAR may not take (the engine rejects "VAR LastDate": LASTDATE is a function; first test deploy
# of the KPI catalogue, 2026-10-11).
DAX_FUNCTIONS = {"LASTDATE", "FIRSTDATE", "DATE", "TODAY", "NOW", "YEAR", "MONTH", "DAY", "VALUES", "FILTER", "ALL",
                 "MAX", "MIN", "SUM", "COUNT", "AVERAGE", "MEDIAN", "DIVIDE", "ENDOFMONTH", "STARTOFMONTH",
                 "PREVIOUSMONTH", "NEXTMONTH", "DATESYTD", "DATESMTD", "DATESQTD", "DATESINPERIOD", "RANK", "BLANK"}
# Table names the engine does not accept unquoted ("The syntax for 'Item' is incorrect", same deploy).
QUOTE_ALWAYS = {"Item"}


def test_var_names_are_not_dax_functions():
    bad = {m.name: names for m in MEASURES
           if (names := sorted({v for v in t.re.findall(r"\bVAR\s+(\w+)", m.expression + "\n" + m.format_expression)
                                if v.upper() in DAX_FUNCTIONS}))}
    assert bad == {}


def test_reserved_table_names_are_quoted():
    pattern = t.re.compile(r"(?<![\w'])(" + "|".join(sorted(QUOTE_ALWAYS)) + r")\[")
    texts = {m.name: m.expression + "\n" + m.format_expression for m in MEASURES}
    texts.update({"check: " + c["name"]: c["dax"] for c in CHECKS})
    assert sorted(name for name, text in texts.items() if pattern.search(text)) == []


def test_measure_guards_are_current():
    import measure_guards
    rels, kinds = measure_guards.model_inputs(MODEL)
    assert measure_guards.render(MEASURES_TEXT, rels, kinds) == MEASURES_TEXT, "run python ssas/tools/measure_guards.py"
