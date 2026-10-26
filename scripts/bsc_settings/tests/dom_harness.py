"""Starts StubClickHouse + server.py on 127.0.0.1 and takes JSON commands on stdin (used by dom_smoke.js)."""
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

stub = StubClickHouse()
stub.set_now("2026-10-25 09:30:00.123")
stub.branches = [{"branch_key": i, "branch_name": "Hosp%d" % i} for i in range(1, 9)]
stub.tables["map_bsc_kpi"] = [dict(KPI)]
stub.tables["map_bsc_objective"] = [dict(OBJ)]
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
    elif cmd["op"] == "clear_sessions":
        srv.app.sessions.clear()
    print(json.dumps(out, default=str), flush=True)

srv.shutdown()
stub.close()
