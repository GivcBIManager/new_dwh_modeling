import http.client
import json
import socket
import sys
import threading

import pytest

from clickhouse import ClickHouse
from rules import Change, Context, prepare
from server import make_server
from stub_clickhouse import StubClickHouse
from tables import TABLES

NOW = "2026-10-25 09:30:00.123"
OLD = "2026-01-01 00:00:00.000"
PASSWORD = "s3cret-pw-Zq9"


def audit(by="old"):
    return {"changed_at": OLD, "changed_by": by, "change_note": "seed", "is_deleted": 0}


KPI = {"kpi_code": "FIN_DAYS_IN_AR", "kpi_num": 1, "kpi_name": "Days", "short_label": "Days",
       "objective_code": "OBJ1", "kpi_type": "Primary", "direction": "lower", "value_format": "days",
       "chart_hint": "line", "display_order": 1, "definition": "", "status": "active",
       "target_source": "fixed", "value_source": "manual", "detail_page": "finance", **audit()}
OBJ = {"objective_code": "OBJ1", "pillar": "Financial", "pillar_order": 1, "pillar_weight": 0.25,
       "pillar_question": "q", "objective_title": "t", "objective_question": "q", "objective_order": 1,
       **audit()}
MANUAL = {"kpi_code": "FIN_DAYS_IN_AR", "branch_id": 1, "year": 2026, "month": 1, "numerator": 5.0,
          "denominator": 1.0, "note": "", **audit()}
TARGET = {"kpi_code": "FIN_DAYS_IN_AR", "branch_id": 1, "year": 2026, "month": 1, "target_value": 40.0,
          "scale_with_months": 0, "source_basis": "", **audit()}
REMOVED = {**TARGET, "month": 2, "changed_at": "2026-02-01 00:00:00.000", "is_deleted": 1}


@pytest.fixture
def stub():
    s = StubClickHouse()
    s.set_now(NOW)
    s.branches = [{"branch_key": i, "branch_name": "Hosp%d" % i} for i in range(1, 9)]
    s.tables["map_bsc_kpi"] = [dict(KPI)]
    s.tables["map_bsc_objective"] = [dict(OBJ)]
    s.tables["map_bsc_manual_value"] = [dict(MANUAL)]
    s.tables["map_bsc_target"] = [dict(TARGET), dict(REMOVED)]
    yield s
    s.close()


@pytest.fixture
def server(stub):
    srv = make_server(0, stub.url, ClickHouse)
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()
    yield srv
    srv.shutdown()
    srv.server_close()
    t.join(timeout=5)


class Client:
    def __init__(self, server):
        self.port = server.server_address[1]
        self.token = None

    def call(self, method, path, body=None, headers=None, origin=True, host=None):
        h = {"Host": host or "127.0.0.1:%d" % self.port}
        if origin and method == "POST":
            h["Origin"] = "http://127.0.0.1:%d" % self.port
        if self.token:
            h["X-BSC-Session"] = self.token
        h.update(headers or {})
        data = None
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            h["Content-Type"] = "application/json"
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        conn.putrequest(method, path, skip_host=True)
        for k, v in h.items():
            conn.putheader(k, v)
        if data is not None:
            conn.putheader("Content-Length", str(len(data)))
        conn.endheaders(data)
        r = conn.getresponse()
        raw = r.read()
        conn.close()
        try:
            payload = json.loads(raw)
        except ValueError:
            payload = raw
        return r.status, payload, r

    def signin(self, user="tester", password=PASSWORD):
        status, payload, r = self.call("POST", "/api/signin", {"user": user, "password": password})
        if status == 200:
            self.token = payload["token"]
        return status, payload, r


@pytest.fixture
def client(server):
    c = Client(server)
    assert c.signin()[0] == 200
    return c


def manual_change(**over):
    row = {"kpi_code": "FIN_DAYS_IN_AR", "branch_id": 2, "year": 2026, "month": 3, "numerator": 9,
           "denominator": 2}
    row.update(over)
    return {"table": "map_bsc_manual_value", "op": "upsert", "row": row, "base_changed_at": None}


def target_change():
    return {"table": "map_bsc_target", "op": "upsert",
            "row": {"kpi_code": "FIN_DAYS_IN_AR", "branch_id": 2, "year": 2026, "month": 3,
                    "target_value": 30},
            "base_changed_at": None}


def test_binds_localhost_only(server):
    assert server.server_address[0] == "127.0.0.1"


def test_second_server_on_the_same_port_fails(server, stub):
    port = server.server_address[1]
    with pytest.raises(OSError):
        second = make_server(port, stub.url, ClickHouse)
        second.server_close()


@pytest.mark.skipif(sys.platform != "win32", reason="SO_EXCLUSIVEADDRUSE is Windows only")
def test_port_is_exclusive_even_for_a_reuse_socket(server):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        with pytest.raises(OSError):
            s.bind(("127.0.0.1", server.server_address[1]))
    finally:
        s.close()


def test_main_reports_a_busy_port_and_opens_no_browser(server, monkeypatch, capsys):
    import server as server_module
    opened = []
    monkeypatch.setattr(server_module.webbrowser, "open", lambda *a, **k: opened.append(a))
    real = server_module.make_server

    def no_serve(*a, **k):  # if the bind wrongly succeeds, do not block the test run
        s = real(*a, **k)
        s.serve_forever = lambda *x, **y: None
        return s
    monkeypatch.setattr(server_module, "make_server", no_serve)
    port = server.server_address[1]
    code = server_module.main(["--port", str(port), "--url", "http://127.0.0.1:1/"])
    out = capsys.readouterr().out
    assert code == 1 and opened == []
    assert out.strip() == ("The settings page is already running (port %d in use). "
                           "Close the other window or use --port." % port)


def test_api_needs_session(server):
    status, payload, _ = Client(server).call("GET", "/api/meta")
    assert status == 401
    assert "Signed out" in payload["error"]


def test_static_and_unknown_paths(server):
    c = Client(server)
    status, body, r = c.call("GET", "/")
    assert status == 200 and b'id="shell"' in body
    assert r.getheader("Content-Type").startswith("text/html")
    assert c.call("GET", "/static/../server.py")[0] == 404
    assert c.call("GET", "/static/nope.js")[0] == 404
    assert c.call("GET", "/elsewhere")[0] == 404


def test_signin_returns_token_and_never_echoes_password(server, stub, capfd):
    c = Client(server)
    status, payload, r = c.signin()
    assert status == 200 and payload["user"] == "tester" and len(payload["token"]) >= 32
    assert r.getheader("Set-Cookie") is None
    assert r.getheader("Cache-Control") == "no-store"
    assert c.call("GET", "/api/meta")[0] == 200
    # the token alone in a cookie, or a wrong header, does not sign in
    anon = Client(server)
    assert anon.call("GET", "/api/meta", headers={"Cookie": "bsc_session=" + payload["token"]})[0] == 401
    assert anon.call("GET", "/api/meta", headers={"X-BSC-Session": "nope"})[0] == 401
    stub.reject_user("bad", echo_password=True)
    status, payload, r = c.signin("bad", PASSWORD)
    assert status == 401 and payload["error"].startswith("Sign-in failed: ")
    assert PASSWORD not in json.dumps(payload)
    status, payload, _ = c.signin("bad\nuser", PASSWORD)
    assert status == 401
    out, err = capfd.readouterr()
    assert PASSWORD not in out + err


def test_host_and_origin_checks(client):
    assert client.call("GET", "/api/meta", host="evil.example:%d" % client.port)[0] == 403
    assert client.call("GET", "/", host="evil.example")[0] == 403
    assert client.call("GET", "/api/meta", host="localhost:%d" % client.port)[0] == 200
    body = {"note": "n", "changes": []}
    assert client.call("POST", "/api/review", body, origin=False)[0] == 403
    assert client.call("POST", "/api/review", body, headers={"Origin": "http://evil.example"})[0] == 403
    assert client.call("POST", "/api/review", body,
                       headers={"Origin": "http://localhost:%d" % client.port})[0] == 200


def test_meta_hospitals_and_fallback(client, stub):
    status, meta, r = client.call("GET", "/api/meta")
    assert status == 200 and r.getheader("Cache-Control") == "no-store"
    assert meta["user"] == "tester"
    assert meta["hospitals"]["1"] == "Hosp1" and meta["hospitals_fallback"] is False
    assert [t["name"] for t in meta["tables"]] == list(TABLES)
    assert [k["kpi_code"] for k in meta["kpis"]] == ["FIN_DAYS_IN_AR"]
    assert [o["objective_code"] for o in meta["objectives"]] == ["OBJ1"]
    assert "groups" in meta and "manual_hints" in meta and "default_manual_hint" in meta
    stub.fail_select("ssas_dim_branch")
    meta = client.call("GET", "/api/meta")[1]
    assert meta["hospitals_fallback"] is True
    assert meta["hospitals"] == {str(i): "Hospital %d" % i for i in range(1, 9)}


def test_table_endpoint(client):
    status, payload, _ = client.call("GET", "/api/table?name=map_bsc_target")
    assert status == 200
    assert [r["month"] for r in payload["current"]] == [1]
    assert [r["month"] for r in payload["removed"]] == [2]
    assert len(payload["all"]) == 2
    assert client.call("GET", "/api/table?name=drop_me")[0] == 404
    assert client.call("GET", "/api/table")[0] == 404


def expected_rows(stub, changes, note):
    data = {n: list(stub.tables.get(n, [])) for n in TABLES}
    ch = [Change(c["table"], c["op"], c["row"], c.get("base_changed_at")) for c in changes]
    hospitals = {i: "Hosp%d" % i for i in range(1, 9)}
    return prepare(ch, note, "tester", Context(data, hospitals), NOW)


def test_review_then_insert(client, stub):
    changes = [manual_change()]
    status, rev, _ = client.call("POST", "/api/review", {"note": "march", "changes": changes})
    assert status == 200 and rev["can_insert"] is True
    want, _ = expected_rows(stub, changes, "march")
    assert rev["rows"] == want
    assert not [r for r in stub.requests if r["text"].startswith("INSERT")]
    before = len(stub.tables["map_bsc_manual_value"])
    status, done, _ = client.call("POST", "/api/insert", {"review_id": rev["review_id"]})
    assert status == 200 and done == {"inserted": {"map_bsc_manual_value": 1}}
    assert stub.tables["map_bsc_manual_value"][before:] == want["map_bsc_manual_value"]
    assert client.call("POST", "/api/insert", {"review_id": rev["review_id"]})[0] == 409
    assert client.call("POST", "/api/insert", {"review_id": "nope"})[0] == 409


def test_review_with_errors_cannot_insert(client, stub):
    changes = [manual_change(month=13)]
    status, rev, _ = client.call("POST", "/api/review", {"note": "bad", "changes": changes})
    assert status == 200 and rev["can_insert"] is False
    assert any(i["level"] == "error" and i["table"] == "map_bsc_manual_value" for i in rev["issues"])
    assert isinstance(rev["issues"][0]["key"], list)
    assert client.call("POST", "/api/insert", {"review_id": rev["review_id"]})[0] == 409
    assert not [r for r in stub.requests if r["text"].startswith("INSERT")]


def test_review_ids_belong_to_their_session(server, client):
    _, rev, _ = client.call("POST", "/api/review", {"note": "x", "changes": [manual_change()]})
    other = Client(server)
    assert other.signin()[0] == 200
    assert other.call("POST", "/api/insert", {"review_id": rev["review_id"]})[0] == 409


def test_insert_failure_reports_partial(client, stub):
    changes = [manual_change(), target_change()]
    _, rev, _ = client.call("POST", "/api/review", {"note": "two", "changes": changes})
    assert rev["can_insert"] is True
    stub.fail_insert_into("map_bsc_target")
    status, res, _ = client.call("POST", "/api/insert", {"review_id": rev["review_id"]})
    assert status == 502
    assert res["inserted"] == {"map_bsc_manual_value": 1}
    assert res["failed"] == "map_bsc_target"
    assert res["not_inserted"] == []
    assert "error" in res
    assert client.call("POST", "/api/insert", {"review_id": rev["review_id"]})[0] == 409


def test_errors_are_json_without_traceback(client):
    status, payload, _ = client.call("POST", "/api/review", {"note": "x", "changes": "oops"})
    assert status in (400, 500) and "error" in payload and "Traceback" not in json.dumps(payload)


def test_only_select_and_insert_reach_clickhouse(client, stub):
    client.call("GET", "/api/meta")
    client.call("GET", "/api/table?name=map_bsc_target")
    _, rev, _ = client.call("POST", "/api/review", {"note": "n", "changes": [manual_change()]})
    client.call("POST", "/api/insert", {"review_id": rev["review_id"]})
    assert stub.requests
    for r in stub.requests:
        t = r["text"]
        assert t.startswith("SELECT") or t.startswith("INSERT INTO default.map_bsc_"), t


def test_older_review_is_not_insertable(client, stub):
    _, old, _ = client.call("POST", "/api/review", {"note": "a", "changes": [manual_change()]})
    _, new, _ = client.call("POST", "/api/review", {"note": "b", "changes": [manual_change(numerator=1)]})
    assert client.call("POST", "/api/insert", {"review_id": old["review_id"]})[0] == 409
    assert not [r for r in stub.requests if r["text"].startswith("INSERT")]
    assert client.call("POST", "/api/insert", {"review_id": new["review_id"]})[0] == 200


def test_insert_rechecks_for_later_changes(client, stub):
    _, rev, _ = client.call("POST", "/api/review", {"note": "a", "changes": [manual_change()]})
    stub.tables["map_bsc_manual_value"].append(
        {**MANUAL, "branch_id": 2, "month": 3, "changed_at": "2026-10-25 09:31:00.000", "changed_by": "other"})
    status, res, _ = client.call("POST", "/api/insert", {"review_id": rev["review_id"]})
    assert status == 409 and res == {"error": "Changed since review: review again."}
    assert not [r for r in stub.requests if r["text"].startswith("INSERT")]


def test_parents_are_inserted_first(client, stub):
    kpi_row = {k: v for k, v in KPI.items() if k not in ("changed_at", "changed_by", "change_note", "is_deleted")}
    kpi_row["kpi_code"] = "NEW_KPI"
    tgt = {"table": "map_bsc_target", "op": "upsert", "base_changed_at": None,
           "row": {"kpi_code": "NEW_KPI", "branch_id": 2, "year": 2026, "month": 3, "target_value": 3}}
    kpi = {"table": "map_bsc_kpi", "op": "upsert", "row": kpi_row, "base_changed_at": None}
    _, rev, _ = client.call("POST", "/api/review", {"note": "new kpi", "changes": [tgt, kpi]})
    assert rev["can_insert"] is True, rev["issues"]
    assert client.call("POST", "/api/insert", {"review_id": rev["review_id"]})[0] == 200
    inserts = [r["text"].split(" FORMAT")[0] for r in stub.requests if r["text"].startswith("INSERT")]
    assert inserts == ["INSERT INTO default.map_bsc_kpi", "INSERT INTO default.map_bsc_target"]
