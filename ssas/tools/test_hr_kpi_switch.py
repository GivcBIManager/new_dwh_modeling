"""HR KPI Actual dispatches every scored HR KPI of the seed (scripts/hr_config/hr_config_seed.sql) to its measure: one
SWITCH branch "<KPI code>", [<measure_name>] per kind-'kpi' row, and every measure_name of the seed (KPIs and metrics)
is a measure of tables/_Measures.tmdl (HR dashboard plan, Task 7)."""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import hnh_tmdl as t  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SEED = (ROOT / "scripts" / "hr_config" / "hr_config_seed.sql").read_text(encoding="utf-8")
MEASURES = {m.name: m for m in t.measures(
    (ROOT / "ssas" / "HNH_Analytics" / "tables" / f"{t.MEASURE_TABLE}.tmdl").read_text(encoding="utf-8"))}


def _sql_values(row: str) -> list:
    """The values of one VALUES tuple: quoted strings unquoted ('' and \\' as a quote), anything else as written."""
    values, i = [], 0
    while i < len(row):
        if row[i] in " ,":
            i += 1
        elif row[i] == "'":
            j, text = i + 1, []
            while True:
                if row[j] == "\\":
                    text.append(row[j + 1])
                    j += 2
                elif row[j] == "'" and row[j + 1:j + 2] == "'":
                    text.append("'")
                    j += 2
                elif row[j] == "'":
                    break
                else:
                    text.append(row[j])
                    j += 1
            values.append("".join(text))
            i = j + 1
        else:
            j = i
            depth = 0
            while j < len(row) and (depth or row[j] != ","):
                depth += {"(": 1, ")": -1}.get(row[j], 0)
                j += 1
            values.append(row[i:j].strip())
            i = j
    return values


def seed_kpis() -> list:
    """The rows of the map_hr_kpi insert as dicts."""
    statement = re.search(r"INSERT INTO default\.map_hr_kpi \(([^)]*)\) VALUES\n(.*?);\n", SEED, re.S)
    columns = [c.strip() for c in statement.group(1).split(",")]
    rows = re.findall(r"(?m)^\s*\((.*)\),?$", statement.group(2))
    return [dict(zip(columns, _sql_values(row))) for row in rows]


def actual_branches() -> list:
    """(code, measure) of every branch of the SWITCH ( Code, ... ) in HR KPI Actual, in order."""
    text = MEASURES["HR KPI Actual"].expression
    block = re.search(r"SWITCH \(\n\s*Code,\n(.*?)\n\s*BLANK \(\)", text, re.S)
    assert block, "HR KPI Actual has no SWITCH ( Code, ... BLANK () )"
    return re.findall(r'^\s*"([^"]+)", \[([^\]]+)\],$', block.group(1), re.M)


def test_seed_parses():
    kpis = seed_kpis()
    assert len(kpis) == 33
    assert all(len(k) == 23 for k in kpis)
    assert len([k for k in kpis if k["kind"] == "kpi"]) == 18


def test_switch_codes_equal_the_seed_kpis():
    codes = [code for code, _ in actual_branches()]
    assert len(codes) == len(set(codes))
    assert sorted(codes) == sorted(k["kpi_code"] for k in seed_kpis() if k["kind"] == "kpi")


def test_each_branch_calls_the_seed_measure():
    wanted = {k["kpi_code"]: k["measure_name"] for k in seed_kpis()}
    assert {code: measure for code, measure in actual_branches() if wanted.get(code) != measure} == {}


def test_every_seed_measure_exists():
    assert sorted({k["measure_name"] for k in seed_kpis()} - set(MEASURES)) == []
