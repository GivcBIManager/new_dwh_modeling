"""Offline checks of the measure catalogue (KPI catalogue plan). Every measure in tables/_Measures.tmdl is documented,
foldered and formatted, references columns and measures that exist, and is covered by a DAX-vs-ClickHouse check in
ssas/tests/measures/*.json. The Time Calculation snapshot lists and the perspectives must agree with the measure file."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import hnh_tmdl as t  # noqa: E402
import model_config as cfg  # noqa: E402
import gen_bsc_kpi_lists  # noqa: E402

SSAS = Path(__file__).resolve().parents[1]
MODEL = SSAS / "HNH_Analytics"
DOMAINS = {"Patient Flow", "Revenue Cycle", "Claims & Pre-auth", "Finance", "Workforce", "Supply Chain",
           "Patient Experience", "Balanced Scorecard", t.DIAGNOSTICS}
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


# The scorecard measures that hold the KPI dispatch lists (bsc visual plan, Task 9): (ROW lists of KPI measures, ROW
# lists of budget targets) and as many SWITCH ( Code, "<CODE>", MAXX ( <table>, [@<CODE>] ), ... ) lookups of each.
# BSC Visual Payload has a second KPI list, ADDCOLUMNS ( VALUES ( 'Date'[Year Month] ), ... ), for its 24 months, and
# its lists call the measures' unguarded twins (Task 10); its lookups read the union of both KPI tables.
BSC_KPI_LISTS = {"BSC Actual": (1, 0), "BSC Target": (0, 1), "BSC Variance %": (1, 1), "BSC Score": (1, 1),
                 "BSC State": (1, 1), "BSC Visual Payload": (2, 1), "BSC Visual Payload Scores": (1, 1)}
BSC_LOOKUPS = {"BSC Visual Payload": 2}
BSC_MEASURE_KPIS, BSC_BUDGET_KPIS = len(gen_bsc_kpi_lists.KPIS), len(gen_bsc_kpi_lists.BUDGETS)  # 49, 21
TWIN = "_Unguarded "


def bsc_kpi_list_problems(measures) -> list:
    """Differences between the KPI ROW lists and SWITCH lookups of the BSC_KPI_LISTS measures (empty when they agree).
    A code missing from one list would fall to the SWITCH's BLANK () in that measure only. An unguarded twin counts
    as the measure it copies."""
    import re
    row_re = re.compile(r"(?:ROW \(\n|ADDCOLUMNS \(\n[ \t]*VALUES \( 'Date'\[Year Month\] \),\n)"
                        r'((?:[ \t]*"@[^"]+", \[[^\]]+\],?\n)+)[ \t]*\)')
    switch_re = re.compile(r'SWITCH \(\n[ \t]*Code,\n((?:[ \t]*"[^"]+", MAXX \( \w+, \[@[^\]]+\] \),\n)+)[ \t]*BLANK \(\)')
    problems, rows, switches = [], {"measure": [], "budget": []}, {"measure": [], "budget": []}
    for name, (want_measure, want_budget) in BSC_KPI_LISTS.items():
        text = measures[name].expression
        found = {"measure": [], "budget": []}
        for block in row_re.findall(text):
            pairs = frozenset((code, measure[len(TWIN):] if measure.startswith(TWIN) else measure)
                              for code, measure in re.findall(r'"@([^"]+)", \[([^\]]+)\]', block))
            found["budget" if all(m.startswith("BSC Target ") for _, m in pairs) else "measure"].append(pairs)
        for kind, want in (("measure", want_measure), ("budget", want_budget)):
            if len(found[kind]) != want:
                problems.append(f"{name}: {len(found[kind])} {kind} ROW lists, expected {want}")
            rows[kind] += [(name, pairs) for pairs in found[kind]]
        lookups = [re.findall(r'"([^"]+)", MAXX \( (\w+), \[@([^\]]+)\] \)', block) for block in switch_re.findall(text)]
        want_lookups = BSC_LOOKUPS.get(name, want_measure + want_budget)
        if len(lookups) != want_lookups:
            problems.append(f"{name}: {len(lookups)} SWITCH ( Code, ... ) lookups, expected {want_lookups}")
        for entries in lookups:
            problems += [f"{name}: {code} reads [@{column}]" for code, _, column in entries if code != column]
            if len({table for _, table, _ in entries}) != 1:
                problems.append(f"{name}: one lookup reads several tables")
            kind = "budget" if all("Budget" in table for _, table, _ in entries) else "measure"
            switches[kind].append((name, frozenset(code for code, _, _ in entries)))
    for kind, size in (("measure", BSC_MEASURE_KPIS), ("budget", BSC_BUDGET_KPIS)):
        reference = rows[kind][0][1] if rows[kind] else frozenset()
        if len(reference) != size:
            problems.append(f"{rows[kind][0][0] if rows[kind] else '?'}: {len(reference)} {kind} KPIs, expected {size}")
        codes = frozenset(code for code, _ in reference)
        for name, pairs in rows[kind][1:]:
            if pairs != reference:
                problems.append(f"{name}: {kind} ROW list differs: {sorted(pairs ^ reference)}")
        for name, found_codes in switches[kind]:
            if found_codes != codes:
                problems.append(f"{name}: {kind} lookup differs: {sorted(found_codes ^ codes)}")
    return problems


def test_bsc_kpi_lists_agree():
    assert bsc_kpi_list_problems({m.name: m for m in MEASURES}) == []


def test_speed_entries_reference_existing_measures_and_keep_the_agreed_limits():
    """ssas/tests/performance.json, run by test.ps1 -Stage Performance as the non-admin BI user. Limits agreed with the
    user (2026-10-22): Executive cold 4 s; the scorecard overview and one pillar board stay at 10 s cold / 3 s warm."""
    entries = json.loads((SSAS / "tests" / "performance.json").read_text(encoding="utf-8"))
    assert {e["name"]: unknown_references(e["dax"]) for e in entries if unknown_references(e["dax"])} == {}
    limits = {e["name"].split(":")[0]: (e.get("cold_limit", 3), e.get("warm_limit", 1)) for e in entries}
    assert limits["Executive"] == (4, 1)
    assert limits["Scorecard"] == (10, 3)
    assert limits["Scorecard pillar board"] == (10, 3)
    by_name = {e["name"].split(":")[0]: e["dax"] for e in entries}
    # The landing page binds the scores-only payload (Task 11); a pillar board page binds the full one for one pillar.
    assert '[BSC Visual Payload Scores]' in by_name["Scorecard"] and "Branch" not in by_name["Scorecard"]
    assert '[BSC Visual Payload]' in by_name["Scorecard pillar board"] and "'BSC KPI'[Pillar] )" in by_name["Scorecard pillar board"]
    assert '"Internal Process"' in by_name["Scorecard pillar board"]
    assert limits["Scorecard comparison"] == (15, 6)


def test_bsc_visual_payload_reads_unguarded_twins_and_batches_its_months():
    """Scorecard overview speed for row-level-security users (bsc visual plan, Task 10): the payload's own guard covers
    every fact, so it calls the KPI and budget measures' bodies without their inner guards, and it evaluates the 12 trend
    months and their prior-year months in one ADDCOLUMNS over 'Date'[Year Month] instead of one evaluation per month."""
    import re
    text = {m.name: m for m in MEASURES}["BSC Visual Payload"].expression
    called = t.dax_references(text)[1]
    sources = {m for _, m in gen_bsc_kpi_lists.KPIS} | {m for _, m in gen_bsc_kpi_lists.BUDGETS} | {
        "BSC Manual Value", "BSC Fixed Target", "BSC KPI Weight"}
    assert sorted(called & sources) == []
    assert sorted(sources - {n[len(TWIN):] for n in called if n.startswith(TWIN)}) == []
    assert sorted(n for n in called if n.startswith(TWIN) and n not in NAMES) == []
    assert len(re.findall(r"ADDCOLUMNS \(\n\t*VALUES \( 'Date'\[Year Month\] \),\n", text)) == 1
    assert "[@Period] IN { 0, 1, 2 }" in text


def test_bsc_tables_generated():
    kpi = (MODEL / "tables" / "BSC KPI.tmdl").read_text(encoding="utf-8")
    assert "column 'KPI Code'" in kpi
    assert "hierarchy 'Pillar Objective KPI'" in kpi
    rel = (MODEL / "relationships.tmdl").read_text(encoding="utf-8")
    assert "fromColumn: 'BSC Targets'.'BSC KPI Key'" in rel and "toColumn: 'BSC KPI'.'BSC KPI Key'" in rel
    assert (MODEL / "perspectives" / "Balanced Scorecard.tmdl").exists()


# Names SSAS 2022 rejects as DAX variables ("The syntax for 'KpiStatus' is incorrect", deploy of 2026-10-21) or that
# shadow a DAX function (LastDate). Found by EVALUATE ROW ( "v", VAR <name> = 1 RETURN 1 ) on the server.
RESERVED_VARIABLE_NAMES = {"kpistatus", "kpigoal", "kpivalue", "kpitrend", "kpiweight", "lastdate", "firstdate"}


def test_measure_variables_avoid_reserved_names():
    import re
    bad = sorted({(m.name, v) for m in MEASURES for v in re.findall(r"\bVAR\s+(\w+)\s*=", m.expression, re.I)
                  if v.lower() in RESERVED_VARIABLE_NAMES})
    assert bad == []
