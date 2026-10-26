from rules import (Change, Context, batch_changed_at, current, history, key_of, prepare)
from tables import TABLES

NOW = "2026-10-25 10:00:00.000"


def audit(at, by="old", deleted=0, note="n"):
    return {"changed_at": at, "changed_by": by, "change_note": note, "is_deleted": deleted}


def tgt(kpi, branch, year, month, value, at, **kw):
    return {"kpi_code": kpi, "branch_id": branch, "year": year, "month": month, "target_value": value,
            "scale_with_months": 0, "source_basis": "", **audit(at, **kw)}


def kpi(code, fmt="num", at="2026-01-01 00:00:00.000", objective="OBJ1", **kw):
    return {"kpi_code": code, "kpi_num": 1, "kpi_name": code, "short_label": code, "objective_code": objective,
            "kpi_type": "Primary", "direction": "higher", "value_format": fmt, "chart_hint": "line",
            "display_order": 1, "definition": "", "status": "active", "target_source": "fixed",
            "value_source": "manual", "detail_page": "finance", **audit(at, **kw)}


def objective(code, at="2026-01-01 00:00:00.000"):
    return {"objective_code": code, "pillar": "Financial", "pillar_order": 1, "pillar_weight": 0.25,
            "pillar_question": "q", "objective_title": "t", "objective_question": "q", "objective_order": 1,
            **audit(at)}


def weight(profile, kpi_code, w, at="2026-01-01 00:00:00.000"):
    return {"profile": profile, "kpi_code": kpi_code, "weight": w, **audit(at)}


def manual(kpi_code, branch, year, month, num, den, at="2026-01-01 00:00:00.000"):
    return {"kpi_code": kpi_code, "branch_id": branch, "year": year, "month": month, "numerator": num,
            "denominator": den, "note": "", **audit(at)}


def ctx(**tables):
    data = {name: [] for name in TABLES}
    data["map_bsc_objective"] = [objective("OBJ1")]
    data["map_bsc_kpi"] = [kpi("FIN_DAYS_IN_AR"), kpi("FIN_RATE", "pct"), kpi("CUS_COMPLAINT_RATE", "num")]
    data.update(tables)
    return Context(data=data, hospitals={i: f"H{i}" for i in range(1, 9)})


def run(changes, note="because", c=None):
    return prepare(changes, note, "me", c or ctx(), NOW)


def up(table, **row):
    return Change(table, "upsert", row)


def target(**over):
    row = dict(kpi_code="FIN_DAYS_IN_AR", branch_id=1, year=2026, month=1, target_value=0.7,
               scale_with_months=0, source_basis="")
    row.update(over)
    return up("map_bsc_target", **row)


def msgs(issues, level):
    return [i.message for i in issues if i.level == level]


def test_current_takes_the_latest_and_drops_removed():
    spec = TABLES["map_bsc_target"]
    rows = [tgt("A", 1, 2026, 1, 1, "2026-01-01 00:00:00.000"),
            tgt("A", 1, 2026, 1, 3, "2026-03-01 00:00:00.000"),
            tgt("A", 1, 2026, 1, 2, "2026-02-01 00:00:00.000"),
            tgt("B", 1, 2026, 1, 5, "2026-01-01 00:00:00.000"),
            tgt("B", 1, 2026, 1, 5, "2026-02-01 00:00:00.000", deleted=1)]
    cur = current(spec, rows)
    assert list(cur) == [("A", 1, 2026, 1)]
    assert cur[("A", 1, 2026, 1)]["target_value"] == 3
    both = current(spec, rows, include_removed=True)
    assert ("B", 1, 2026, 1) in both and both[("B", 1, 2026, 1)]["is_deleted"] == 1


def test_current_equal_changed_at_later_row_wins():
    spec = TABLES["map_bsc_target"]
    at = "2026-01-01 00:00:00.000"
    cur = current(spec, [tgt("A", 1, 2026, 1, 1, at), tgt("A", 1, 2026, 1, 2, at)])
    assert cur[("A", 1, 2026, 1)]["target_value"] == 2


def test_keys_are_trimmed():
    spec = TABLES["map_bsc_threshold"]
    base = {"score_base": 1, "score_slope": 1, "good_from": 1, "watch_from": 1}
    rows = [{"kpi_code": "FIN_DAYS_IN_AR ", **base, **audit("2026-01-01 00:00:00.000")},
            {"kpi_code": "FIN_DAYS_IN_AR", **base, **audit("2026-02-01 00:00:00.000")}]
    assert list(current(spec, rows)) == [("FIN_DAYS_IN_AR",)]
    assert key_of(TABLES["map_bsc_target"], {"kpi_code": " A ", "branch_id": "3", "year": 2026.0, "month": 1}) \
        == ("A", 3, 2026, 1)
    rows, issues = run([up("map_bsc_threshold", kpi_code=" FIN_DAYS_IN_AR ", **base)])
    assert not msgs(issues, "error")
    assert rows["map_bsc_threshold"][0]["kpi_code"] == "FIN_DAYS_IN_AR"


def test_history_newest_first():
    spec = TABLES["map_bsc_target"]
    rows = [tgt("A", 1, 2026, 1, 1, "2026-01-01 00:00:00.000"),
            tgt("A", 1, 2026, 1, 3, "2026-03-01 00:00:00.000", deleted=1),
            tgt("A", 1, 2026, 1, 2, "2026-02-01 00:00:00.000"),
            tgt("B", 1, 2026, 1, 9, "2026-02-01 00:00:00.000")]
    h = history(spec, rows, ("A", 1, 2026, 1))
    assert [r["target_value"] for r in h] == [3, 2, 1]


def test_batch_changed_at():
    assert batch_changed_at("2026-10-25 10:00:00.000", ["2026-10-25 10:00:00.000"]) == "2026-10-25 10:00:00.001"
    assert batch_changed_at("2026-10-25 10:00:05.000", ["2026-10-25 10:00:00.000"]) == "2026-10-25 10:00:05.000"
    assert batch_changed_at(NOW, []) == NOW


def test_upsert_row_has_audit_columns():
    rows, issues = run([target()], note="the note")
    assert not issues
    (r,) = rows["map_bsc_target"]
    assert r["changed_by"] == "me" and r["change_note"] == "the note" and r["is_deleted"] == 0
    assert r["changed_at"] == batch_changed_at(NOW, [])
    spec = TABLES["map_bsc_target"]
    assert set(r) == {c.name for c in spec.columns} | {"changed_at", "changed_by", "change_note", "is_deleted"}
    assert r["target_value"] == 0.7 and r["year"] == 2026


def test_new_row_wins_over_existing_with_later_changed_at():
    c = ctx(map_bsc_target=[tgt("FIN_DAYS_IN_AR", 1, 2026, 1, 0.5, "2026-10-25 10:00:00.000")])
    rows, _ = run([target()], c=c)
    assert rows["map_bsc_target"][0]["changed_at"] == "2026-10-25 10:00:00.001"


def test_remove_copies_the_current_row():
    c = ctx(map_bsc_target=[tgt("FIN_DAYS_IN_AR", 1, 2026, 1, 0.5, "2026-01-01 00:00:00.000")])
    key = dict(kpi_code="FIN_DAYS_IN_AR", branch_id=1, year=2026, month=1)
    rows, issues = run([Change("map_bsc_target", "remove", key)], c=c)
    assert not issues
    (r,) = rows["map_bsc_target"]
    assert r["target_value"] == 0.5 and r["is_deleted"] == 1 and r["changed_by"] == "me"
    rows, issues = run([Change("map_bsc_target", "remove", dict(key, month=2))], c=c)
    assert any(i.level == "error" and "nothing to remove" in i.message for i in issues)
    assert not rows.get("map_bsc_target")


def test_restoring_a_removed_key_is_a_warning():
    c = ctx(map_bsc_target=[tgt("FIN_DAYS_IN_AR", 1, 2026, 1, 0.5, "2026-01-01 00:00:00.000", deleted=1)])
    _, issues = run([target()], c=c)
    assert any("restores a key removed on 2026-01-01" in m for m in msgs(issues, "warning"))
    assert not msgs(issues, "error")


def err(change, column, c=None, note="because"):
    _, issues = run([change] if not isinstance(change, list) else change, note=note, c=c)
    errors = [i for i in issues if i.level == "error"]
    assert errors, f"no error for {column}"
    assert any(column in i.message for i in errors), [i.message for i in errors]


def test_errors_block():
    kpi_row = kpi("NEW_KPI")
    kpi_row.pop("changed_at"), kpi_row.pop("changed_by"), kpi_row.pop("change_note"), kpi_row.pop("is_deleted")
    err(up("map_bsc_kpi", **dict(kpi_row, direction="up")), "direction")
    err(up("map_bsc_kpi", **dict(kpi_row, status="Active")), "status")
    err(up("map_bsc_weight", profile="branch:9", kpi_code="FIN_RATE", weight=0.1), "profile")
    err(up("map_bsc_manual_value", kpi_code="FIN_RATE", branch_id=0, year=2026, month=1,
           numerator=1, denominator=1, note=""), "branch_id")
    err(up("map_bsc_manual_value", kpi_code="FIN_RATE", branch_id=1, year=2026, month=0,
           numerator=1, denominator=1, note=""), "month")
    err(target(month=13), "month")
    err(target(branch_id=9), "branch_id")
    err(up("map_bsc_kpi", **dict(kpi_row, objective_code="NOPE")), "objective_code")
    err(target(kpi_code="NOPE"), "kpi_code")
    err(target(kpi_code=""), "kpi_code")
    err(target(), "note is required", note="  ")
    err([target(), target(target_value=0.8)], "changed twice")
    # '*' is allowed in thresholds; an unknown code is not
    base = {"score_base": 1, "score_slope": 1, "good_from": 1, "watch_from": 1}
    _, issues = run([up("map_bsc_threshold", kpi_code="*", **base)])
    assert not msgs(issues, "error")
    err(up("map_bsc_threshold", kpi_code="NOPE", **base), "kpi_code")
    # target branch 0 is allowed
    _, issues = run([target(branch_id=0, month=0)])
    assert not msgs(issues, "error")


def test_bad_numbers_are_errors():
    for bad in ("0,7", "70%", " ", "abc"):
        err(target(target_value=bad), "target_value")
    for ok in ("0.7", 0.7):
        rows, issues = run([target(target_value=ok)])
        assert not msgs(issues, "error")
        assert rows["map_bsc_target"][0]["target_value"] == 0.7
    err(target(year="20x6"), "year")


def test_int_keys_must_be_whole_numbers():
    for col, bad in (("branch_id", "1.5"), ("branch_id", 1.5), ("year", "2026.5"), ("month", "1.2")):
        _, issues = run([target(**{col: bad})])
        errors = msgs(issues, "error")
        assert any(m == f"{col} is not a whole number" for m in errors), (col, bad, errors)
    # a removal of a non-integer key is refused too (never truncated to another key)
    c = ctx(map_bsc_target=[tgt("FIN_DAYS_IN_AR", 1, 2026, 1, 0.5, "2026-01-01 00:00:00.000")])
    rows, issues = run([Change("map_bsc_target", "remove",
                               {"kpi_code": "FIN_DAYS_IN_AR", "branch_id": "1.5", "year": 2026, "month": 1})], c=c)
    assert "branch_id is not a whole number" in msgs(issues, "error") and not rows
    for ok in ("1", "1.0", 1.0):
        rows, issues = run([target(branch_id=ok)])
        assert not msgs(issues, "error") and rows["map_bsc_target"][0]["branch_id"] == 1


def test_year_must_be_2020_to_2100():
    m = dict(kpi_code="FIN_RATE", branch_id=1, month=1, numerator=1, denominator=1, note="")
    year_changes = {
        "map_bsc_target": lambda y: target(year=y),
        "map_bsc_manual_value": lambda y: up("map_bsc_manual_value", year=y, **m),
        "map_bsc_licensed_beds": lambda y: up("map_bsc_licensed_beds", branch_id=1, year=y, licensed_beds=10),
        "map_bsc_budgeted_fte": lambda y: up("map_bsc_budgeted_fte", branch_id=1, year=y, budgeted_fte=10),
    }
    assert set(year_changes) == {n for n, s in TABLES.items() if any(c.name == "year" for c in s.columns)}
    for name, make in year_changes.items():
        for bad in (2019, 2101, 26, 0):
            _, issues = run([make(bad)])
            assert "year must be 2020 to 2100" in msgs(issues, "error"), (name, bad)
        for ok in (2020, 2026, 2100):
            _, issues = run([make(ok)])
            assert not msgs(issues, "error"), (name, ok, msgs(issues, "error"))


def test_removing_a_whole_branch_profile_is_not_a_total_warning():
    c = ctx(map_bsc_weight=[weight("branch:3", "FIN_DAYS_IN_AR", 0.6), weight("branch:3", "FIN_RATE", 0.4)])
    rm = [Change("map_bsc_weight", "remove", {"profile": "branch:3", "kpi_code": k}) for k in ("FIN_DAYS_IN_AR", "FIN_RATE")]
    rows, issues = run(rm, c=c)
    assert not msgs(issues, "error") and len(rows["map_bsc_weight"]) == 2
    w = msgs(issues, "warning")
    assert not any("should be 1.0000" in x for x in w), w
    assert "profile branch:3: no weights left, so the hospital uses the corporate profile" in w
    # removing only one row still warns about the total
    _, issues = run(rm[:1], c=c)
    assert any("profile branch:3: total 0.4000, should be 1.0000" in x for x in msgs(issues, "warning"))


def test_new_kpi_is_not_an_error_but_needs_its_measure():
    row = kpi("BRAND_NEW")
    for k in ("changed_at", "changed_by", "change_note", "is_deleted"):
        row.pop(k)
    _, issues = run([up("map_bsc_kpi", **row)])
    assert not msgs(issues, "error")
    assert any("needs its SSAS measure" in m for m in msgs(issues, "warning"))
    # an existing KPI is not new
    row["kpi_code"] = "FIN_RATE"
    _, issues = run([up("map_bsc_kpi", **row)])
    assert not any("SSAS measure" in m for m in msgs(issues, "warning"))


def test_batch_adding_objective_and_kpi_passes():
    obj = objective("OBJ_NEW")
    kp = kpi("K_NEW", objective="OBJ_NEW")
    for d in (obj, kp):
        for k in ("changed_at", "changed_by", "change_note", "is_deleted"):
            d.pop(k)
    _, issues = run([up("map_bsc_objective", **obj), up("map_bsc_kpi", **kp),
                     target(kpi_code="K_NEW")])
    assert not msgs(issues, "error")


def test_warnings():
    c = ctx(map_bsc_weight=[weight("corporate", "FIN_DAYS_IN_AR", 0.5), weight("corporate", "FIN_RATE", 0.5)])
    _, issues = run([up("map_bsc_weight", profile="corporate", kpi_code="FIN_RATE", weight=0.51)], c=c)
    assert any("total 1.0100, should be 1.0000" in m for m in msgs(issues, "warning"))
    _, issues = run([up("map_bsc_weight", profile="corporate", kpi_code="FIN_RATE", weight=0.5)], c=c)
    assert not msgs(issues, "warning")

    _, issues = run([target(kpi_code="FIN_RATE", target_value=1.5)])
    assert any("above 1" in m for m in msgs(issues, "warning"))
    _, issues = run([target(kpi_code="FIN_DAYS_IN_AR", target_value=1.5)])
    assert not msgs(issues, "warning")

    m = dict(branch_id=1, year=2026, month=1, note="")
    _, issues = run([up("map_bsc_manual_value", kpi_code="FIN_RATE", numerator=70, denominator=1, **m)])
    assert any("above 1" in x for x in msgs(issues, "warning"))
    _, issues = run([up("map_bsc_manual_value", kpi_code="FIN_DAYS_IN_AR", numerator=5, denominator=0, **m)])
    assert any("denominator 0" in x for x in msgs(issues, "warning"))
    _, issues = run([up("map_bsc_manual_value", kpi_code="CUS_COMPLAINT_RATE", numerator=5, denominator=0, **m)])
    assert not msgs(issues, "warning")


def test_stale_base_is_a_warning():
    c = ctx(map_bsc_target=[tgt("FIN_DAYS_IN_AR", 1, 2026, 1, 0.5, "2026-10-01 08:00:00.000", by="sara")])
    ch = target()
    ch.base_changed_at = "2026-09-01 00:00:00.000"
    _, issues = run([ch], c=c)
    w = msgs(issues, "warning")
    assert any("sara" in m and "2026-10-01 08:00:00.000" in m for m in w)
    ch.base_changed_at = "2026-10-01 08:00:00.000"
    _, issues = run([ch], c=c)
    assert not msgs(issues, "warning")


def test_unknown_table_and_op_are_errors():
    _, issues = run([Change("nope", "upsert", {})])
    assert msgs(issues, "error")
