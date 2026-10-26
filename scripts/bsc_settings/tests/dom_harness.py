"""Starts StubClickHouse + server.py on 127.0.0.1 and takes JSON commands on stdin (used by dom_smoke.js)."""
import datetime
import json
import sys
import threading
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE))

from clickhouse import ClickHouse  # noqa: E402
from server import make_server  # noqa: E402
from stub_clickhouse import StubClickHouse  # noqa: E402

OLD = "2026-01-01 00:00:00.000"
AUDIT = {"changed_at": OLD, "changed_by": "old", "change_note": "seed", "is_deleted": 0}
XSS = '<img src=x onerror="window.__xss=1">'
KPI = {"kpi_code": "FIN_DAYS_IN_AR", "kpi_num": 1, "kpi_name": "Days " + XSS, "short_label": "Days",
       "objective_code": "OBJ1", "kpi_type": "Primary", "direction": "lower", "value_format": "days",
       "chart_hint": "line", "display_order": 1, "definition": "", "status": "active",
       "target_source": "fixed", "value_source": "manual", "detail_page": "finance", **AUDIT}
OBJ = {"objective_code": "OBJ1", "pillar": "Financial", "pillar_order": 1, "pillar_weight": 0.25,
       "pillar_question": "q", "objective_title": "t", "objective_question": "q", "objective_order": 1, **AUDIT}
TARGET = {"kpi_code": "FIN_DAYS_IN_AR", "branch_id": 1, "year": 2026, "month": 1, "target_value": 40.0,
          "scale_with_months": 0, "source_basis": XSS, **AUDIT}

KPI2 = {**KPI, "kpi_code": "FIN_OTHER", "kpi_num": 2, "kpi_name": "Other manual", "short_label": "Other", "display_order": 2}
KPI3 = {**KPI, "kpi_code": "FIN_MEASURE", "kpi_num": 3, "kpi_name": "Measured", "short_label": "Meas",
        "objective_code": "OBJ2", "value_source": "measure", "display_order": 3}
OBJ2 = {**OBJ, "objective_code": "OBJ2", "pillar": "Customer", "pillar_order": 2, "objective_order": 2}
_t = datetime.date.today()
LAST = (_t.year - 1, 12) if _t.month == 1 else (_t.year, _t.month - 1)  # the page's default period
MANUAL = {"kpi_code": "FIN_DAYS_IN_AR", "branch_id": 2, "year": LAST[0], "month": LAST[1], "numerator": 50.0,
          "denominator": 5.0, "note": "seed", **AUDIT}


def W(profile, code, weight):
    return {"profile": profile, "kpi_code": code, "weight": weight, **AUDIT}


stub = StubClickHouse()
stub.set_now("2026-10-25 09:30:00.123")
stub.branches = [{"branch_key": i, "branch_name": "Hosp%d" % i} for i in range(1, 9)]
stub.tables["map_bsc_kpi"] = [dict(KPI), dict(KPI2), dict(KPI3)]
stub.tables["map_bsc_objective"] = [dict(OBJ), dict(OBJ2)]
stub.tables["map_bsc_manual_value"] = [dict(MANUAL)]
stub.tables["map_bsc_weight"] = [W("corporate", "FIN_DAYS_IN_AR", 0.5), W("corporate", "FIN_OTHER", 0.3), W("corporate", "FIN_MEASURE", 0.2),
                                 W("branch:1", "FIN_DAYS_IN_AR", 0.6), W("branch:1", "FIN_OTHER", 0.2),
                                 W("branch:2", "FIN_DAYS_IN_AR", 0.4), W("branch:2", "FIN_MEASURE", 0.6)]
stub.tables["map_bsc_target"] = [dict(TARGET)]
srv = make_server(0, stub.url, ClickHouse)
threading.Thread(target=srv.serve_forever, daemon=True).start()
print(json.dumps({"port": srv.server_address[1]}), flush=True)

for line in sys.stdin:
    cmd = json.loads(line)
    out = {}
    if cmd["op"] == "dump":
        out = {"tables": stub.tables}
    elif cmd["op"] == "fail_select":
        stub.fail_select(cmd["substring"])
    elif cmd["op"] == "clear_failures":
        stub._fail_selects.clear()
    elif cmd["op"] == "clear_sessions":
        srv.app.sessions.clear()
    print(json.dumps(out, default=str), flush=True)

srv.shutdown()
stub.close()
