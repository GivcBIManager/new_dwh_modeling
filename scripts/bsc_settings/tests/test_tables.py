import re
from pathlib import Path

from tables import (AUDIT, COMPLAINTS_KPI, DEFAULT_MANUAL_HINT, GROUPS, MANUAL_HINTS,
                    RATE_FORMAT, TABLES)

ROOT = Path(__file__).resolve().parents[3]
DDL = ROOT / "scripts" / "bsc_config" / "bsc_config_ddl.sql"
DOC = ROOT / "docs" / "bsc_config.md"


def allowed(table, column):
    col = next(c for c in TABLES[table].columns if c.name == column)
    return col


def parse_ddl():
    text = DDL.read_text(encoding="utf-8")
    out = {}
    for m in re.finditer(r"CREATE TABLE IF NOT EXISTS default\.(\w+)\s*\((.*?)\)\s*ENGINE", text, re.S):
        cols = []
        for part in m.group(2).split(","):
            part = part.strip()
            if not part:
                continue
            name, typ = part.split(None, 1)
            cols.append((name, typ.strip()))
        out[m.group(1)] = cols
    return out


def test_twelve_tables_in_menu_order():
    assert list(TABLES) == [
        "map_bsc_manual_value", "map_bsc_target", "map_bsc_weight", "map_bsc_threshold",
        "map_bsc_kpi", "map_bsc_objective", "map_bsc_owner", "map_bsc_hospital_category",
        "map_bsc_licensed_beds", "map_bsc_budgeted_fte", "map_bsc_parameter", "map_bsc_code_list"]
    assert GROUPS == ("Monthly", "Targets & scoring", "KPI setup", "Hospital facts", "Advanced")
    assert [t.label for t in TABLES.values()] == [
        "Manual values", "Targets", "Weights", "Thresholds", "KPIs", "Objectives & pillars",
        "Owners", "Hospital categories", "Licensed beds", "Budgeted FTE", "Parameters", "Code lists"]
    assert [t.group for t in TABLES.values()] == [
        "Monthly", "Targets & scoring", "Targets & scoring", "Targets & scoring",
        "KPI setup", "KPI setup", "KPI setup",
        "Hospital facts", "Hospital facts", "Hospital facts", "Advanced", "Advanced"]
    assert all(t.name == k for k, t in TABLES.items())


def test_columns_match_the_ddl():
    ddl = parse_ddl()
    assert set(ddl) == set(TABLES)
    kinds = {"String": "str", "UInt8": "int", "UInt16": "int", "Float64": "float"}
    for name, spec in TABLES.items():
        assert [c.name for c in spec.columns] + list(AUDIT) == [c for c, _ in ddl[name]], name
        for col, (_, typ) in zip(spec.columns, ddl[name]):
            expect = "flag" if col.name == "scale_with_months" else kinds[typ]
            assert col.kind == expect, (name, col.name)
        assert set(spec.key) <= {c.name for c in spec.columns}


def test_keys_match_the_doc():
    keys = {n: t.key for n, t in TABLES.items()}
    assert keys["map_bsc_target"] == ("kpi_code", "branch_id", "year", "month")
    assert keys["map_bsc_weight"] == ("profile", "kpi_code")
    assert keys["map_bsc_manual_value"] == ("kpi_code", "branch_id", "year", "month")
    assert keys["map_bsc_owner"] == ("kpi_code", "branch_id")
    assert keys["map_bsc_code_list"] == ("list_name", "code")
    assert keys["map_bsc_budgeted_fte"] == ("branch_id", "year")
    assert keys["map_bsc_licensed_beds"] == ("branch_id", "year")
    assert keys["map_bsc_kpi"] == ("kpi_code",)
    assert keys["map_bsc_objective"] == ("objective_code",)
    assert keys["map_bsc_threshold"] == ("kpi_code",)
    assert keys["map_bsc_hospital_category"] == ("branch_id",)
    assert keys["map_bsc_parameter"] == ("name",)


def doc_values(column):
    for line in DOC.read_text(encoding="utf-8").splitlines():
        if line.startswith(f"| `{column}` |"):
            cell = line.split("|")[2]
            cell = re.sub(r"\([^)]*\)", "", cell)
            return re.findall(r"`([^`]+)`", cell)
    raise AssertionError(column)


def test_allowed_values_cover_the_doc():
    for column in ("kpi_type", "direction", "value_format", "chart_hint", "status",
                   "target_source", "value_source", "detail_page"):
        vals = doc_values(column)
        assert vals, column
        assert set(vals) <= set(allowed("map_bsc_kpi", column).allowed), column
    assert "signed" in allowed("map_bsc_kpi", "chart_hint").allowed
    assert allowed("map_bsc_objective", "pillar").allowed == (
        "Financial", "Customer", "Internal Process", "Learning & Growth")
    assert allowed("map_bsc_hospital_category", "category").allowed == (
        "Scale & Optimize", "Anchor & Protect", "Ramp-Up & Prove")
    assert allowed("map_bsc_code_list", "list_name").allowed == (
        "ancillary_category", "satisfaction_nps_role")
    assert allowed("map_bsc_weight", "profile").pattern == r"^(corporate|branch:[1-8])$"


def test_doc_lists_signed():
    assert "signed" in doc_values("chart_hint")


def test_refs():
    for name, spec in TABLES.items():
        for col in spec.columns:
            if col.name == "kpi_code":
                assert col.ref == ("kpi_or_default" if name == "map_bsc_threshold" else "kpi"), name
            elif col.name == "objective_code" and name == "map_bsc_kpi":
                assert col.ref == "objective"
            elif col.name == "branch_id":
                assert col.ref == ("branch_or_all" if name in ("map_bsc_target", "map_bsc_owner")
                                   else "branch"), name
            elif col.name != "objective_code":
                assert col.ref is None, (name, col.name)


def test_manual_hints():
    assert MANUAL_HINTS["CUS_COMPLAINT_RATE"] == (
        "Count in numerator, 0 in denominator (the measure divides by OP and ER visits).")
    assert DEFAULT_MANUAL_HINT == (
        "Numerator and denominator; for a rate already worked out, the rate in numerator and 1 in denominator.")
    assert COMPLAINTS_KPI == "CUS_COMPLAINT_RATE"
    assert RATE_FORMAT == "pct"


def test_to_json():
    j = TABLES["map_bsc_target"].to_json()
    assert j["name"] == "map_bsc_target" and j["key"] == ["kpi_code", "branch_id", "year", "month"]
    assert j["columns"][0]["name"] == "kpi_code" and j["columns"][0]["ref"] == "kpi"
