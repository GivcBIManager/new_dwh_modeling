"""Tests for the balanced-scorecard config seed (plan 2026-10-20-bsc-dwh-config-and-facts, Task 1).

Run: python -m pytest scripts/bsc_config/test_build_seed.py -q
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from build_seed import HANDOVER, build_rows, render_sql  # noqa: E402

ROWS = build_rows(HANDOVER)


def test_catalog_has_70_kpis_with_unique_codes():
    rows = ROWS["map_bsc_kpi"]
    assert len(rows) == 70
    assert len({r["kpi_code"] for r in rows}) == 70
    assert {r["kpi_num"] for r in rows} == set(range(1, 72)) - {3}


def test_merged_revenue_growth():
    k = {r["kpi_num"]: r for r in ROWS["map_bsc_kpi"]}
    assert k[2]["kpi_code"] == "FIN_REVENUE_GROWTH" and k[2]["target_source"] == "prior_year"
    assert k[2]["kpi_name"] == "Net Revenue Growth vs Last Year"
    assert k[39]["kpi_name"] == "Fall Rate with Harm"


def test_parked_kpis():
    parked = {r["kpi_num"] for r in ROWS["map_bsc_kpi"] if r["status"] == "parked"}
    assert parked == {7, 19, 33, 40, 59, 61, 65, 70, 71}


def test_fixed_targets():
    t = {(r["kpi_code"], r["branch_id"]): r for r in ROWS["map_bsc_target"]}
    assert t[("FIN_DAYS_IN_AR", 0)]["target_value"] == 180
    assert t[("LRN_TURNOVER", 0)]["scale_with_months"] == 1
    assert t[("CUS_NEW_PATIENTS", 6)]["target_value"] == 0.7 and t[("CUS_NEW_PATIENTS", 1)]["target_value"] == 0.3
    assert ("CUS_NEW_PATIENTS", 0) not in t
    assert len([r for r in t.values() if r["branch_id"] == 0]) == 19


def test_every_fixed_target_kpi_has_a_target():
    fixed = {r["kpi_code"] for r in ROWS["map_bsc_kpi"] if r["target_source"] == "fixed"}
    assert fixed == {r["kpi_code"] for r in ROWS["map_bsc_target"]}


def test_weights_sum_to_one_per_profile():
    profiles = {}
    for r in ROWS["map_bsc_weight"]:
        profiles.setdefault(r["profile"], 0.0)
        profiles[r["profile"]] += r["weight"]
    assert set(profiles) == {"corporate"} | {f"branch:{i}" for i in range(1, 9)}
    assert all(abs(v - 1.0) < 1e-6 for v in profiles.values()), profiles


def test_merged_kpi_weight_is_the_sum_of_kpis_2_and_3():
    w = {(r["profile"], r["kpi_code"]): r["weight"] for r in ROWS["map_bsc_weight"]}
    assert abs(w[("corporate", "FIN_REVENUE_GROWTH")] - 0.036) < 1e-9


def test_owner_rows_only_for_known_branches():
    o = ROWS["map_bsc_owner"]
    assert {r["branch_id"] for r in o} <= set(range(0, 9))
    assert len([r for r in o if r["branch_id"] == 0]) == 70
    assert len({(r["kpi_code"], r["branch_id"]) for r in o}) == len(o)


def test_objectives_categories_and_code_lists():
    assert len(ROWS["map_bsc_objective"]) == 17
    assert {x["branch_id"]: x["category"] for x in ROWS["map_bsc_hospital_category"]}[6] == "Ramp-Up & Prove"
    assert sorted(x["code"] for x in ROWS["map_bsc_code_list"] if x["list_name"] == "ancillary_category") == \
        sorted(["MD", "MED", "CSM", "RTL", "MLK", "PH", "LAB", "RAD"])
    kpi_objectives = {r["objective_code"] for r in ROWS["map_bsc_kpi"]}
    assert kpi_objectives <= {r["objective_code"] for r in ROWS["map_bsc_objective"]}


def test_render_sql_escapes_quotes():
    sql = render_sql({"map_bsc_code_list": [{"list_name": "x", "code": "O'Neil"}]})
    assert "'O\\'Neil'" in sql and "now64(3)" in sql and "INSERT INTO default.map_bsc_code_list" in sql
