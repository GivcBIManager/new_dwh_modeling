"""Local web server for the BSC settings page (standard library only).

Listens on 127.0.0.1. The page signs in with a ClickHouse user and password; the server keeps one
guarded ClickHouse client per session and only ever sends SELECTs and reviewed INSERTs.
"""
import argparse
import json
import re
import secrets
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from clickhouse import ClickHouse, ClickHouseError  # noqa: E402
from rules import Change, Context, current, key_of, prepare  # noqa: E402
from tables import DEFAULT_MANUAL_HINT, GROUPS, MANUAL_HINTS, TABLES  # noqa: E402

STATIC = HERE / "static"
TOKEN_HEADER = "X-BSC-Session"
MAX_BODY = 5 * 1024 * 1024
CONTENT_TYPES = {".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8",
                 ".css": "text/css; charset=utf-8"}
STATIC_NAME = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.-]*$")
# parents first, so a failed batch never leaves rows pointing at a KPI or objective that is missing
INSERT_ORDER = ["map_bsc_objective", "map_bsc_kpi"] + [
    t for t in TABLES if t not in ("map_bsc_objective", "map_bsc_kpi")]
SIGNED_OUT = "Signed out: sign in again."
HOSPITAL_SQL = ("SELECT branch_key, branch_name FROM gold.ssas_dim_branch "
                "WHERE is_hospital = 'Yes' ORDER BY branch_key")


class ApiError(Exception):
    def __init__(self, status, message, payload=None):
        super().__init__(message)
        self.status = status
        self.payload = payload if payload is not None else {"error": message}


class Session:
    def __init__(self, user, ch):
        self.user = user
        self.ch = ch
        self.reviews = {}


class App:
    """Shared state: sessions and the allowed Host / Origin values."""

    def __init__(self, ch_url, ch_factory):
        self.ch_url = ch_url
        self.ch_factory = ch_factory
        self.sessions = {}
        self.lock = threading.Lock()
        self.port = 0

    def hosts(self):
        return {"127.0.0.1:%d" % self.port, "localhost:%d" % self.port}

    def origins(self):
        return {"http://" + h for h in self.hosts()}


def read_table(ch, name):
    return ch.select("SELECT * FROM default.%s" % name)


def read_hospitals(ch):
    try:
        rows = ch.select(HOSPITAL_SQL)
        hospitals = {int(r["branch_key"]): str(r["branch_name"]) for r in rows}
        if hospitals:
            return hospitals, False
    except (ClickHouseError, KeyError, ValueError, TypeError):
        pass
    return {i: "Hospital %d" % i for i in range(1, 9)}, True


def jsonable(value):
    if isinstance(value, tuple):
        return [jsonable(v) for v in value]
    return value


class Handler(BaseHTTPRequestHandler):
    server_version = "BscSettings"
    sys_version = ""
    protocol_version = "HTTP/1.0"

    # --- logging: method, path (no query) and status only ---------------
    def log_message(self, format, *args):
        pass

    def log_error(self, format, *args):
        pass

    def log_request(self, code="-", size="-"):
        path = urlsplit(self.path).path
        sys.stderr.write("%s %s %s\n" % (self.command, path, code))

    # --- plumbing -------------------------------------------------------
    @property
    def app(self):
        return self.server.app

    def send_bytes(self, status, body, content_type, extra=()):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        for k, v in extra:
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def send_json(self, status, payload, extra=()):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_bytes(status, body, "application/json; charset=utf-8",
                        (("Cache-Control", "no-store"),) + tuple(extra))

    def read_json(self):
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            raise ApiError(400, "Bad request.") from None
        if length < 0 or length > MAX_BODY:
            raise ApiError(400, "Bad request.")
        try:
            data = json.loads(self.rfile.read(length).decode("utf-8")) if length else {}
        except (ValueError, UnicodeDecodeError):
            raise ApiError(400, "Bad request: not valid JSON.") from None
        if not isinstance(data, dict):
            raise ApiError(400, "Bad request: expected a JSON object.")
        return data

    def session(self):
        token = self.headers.get(TOKEN_HEADER)
        sess = self.app.sessions.get(token) if token else None
        if sess is None:
            raise ApiError(401, SIGNED_OUT)
        return sess

    def dispatch(self, method):
        try:
            if self.headers.get("Host") not in self.app.hosts():
                raise ApiError(403, "Forbidden host.")
            if method == "POST" and self.headers.get("Origin") not in self.app.origins():
                raise ApiError(403, "Forbidden origin.")
            parts = urlsplit(self.path)
            path = parts.path
            if method == "GET" and (path == "/" or path.startswith("/static/")):
                return self.serve_static(path)
            routes = {("POST", "/api/signin"): self.api_signin,
                      ("GET", "/api/meta"): self.api_meta,
                      ("GET", "/api/table"): self.api_table,
                      ("POST", "/api/review"): self.api_review,
                      ("POST", "/api/insert"): self.api_insert}
            fn = routes.get((method, path))
            if fn is None:
                raise ApiError(404, "Not found.")
            self.query = parse_qs(parts.query)
            payload, extra = fn()
            self.send_json(200, payload, extra)
        except ApiError as e:
            self.send_json(e.status, e.payload)
        except Exception as e:  # never leak a traceback or request content
            self.send_json(500, {"error": "%s: %s" % (type(e).__name__, e)})

    def do_GET(self):
        self.dispatch("GET")

    def do_POST(self):
        self.dispatch("POST")

    # --- static ---------------------------------------------------------
    def serve_static(self, path):
        name = "index.html" if path == "/" else path[len("/static/"):]
        file = STATIC / name
        ctype = CONTENT_TYPES.get(file.suffix)
        if not STATIC_NAME.match(name) or ctype is None or not file.is_file():
            raise ApiError(404, "Not found.")
        self.send_bytes(200, file.read_bytes(), ctype, (("Cache-Control", "no-store"),))

    # --- API ------------------------------------------------------------
    def api_signin(self):
        data = self.read_json()
        user, password = data.get("user"), data.get("password")
        if not isinstance(user, str) or not isinstance(password, str) or not user:
            raise ApiError(401, "Sign-in failed: enter a user name and password.")
        try:
            ch = self.app.ch_factory(self.app.ch_url, user, password)
            ch.select("SELECT 1")
        except ClickHouseError as e:
            raise ApiError(401, "Sign-in failed: %s" % e) from None
        token = secrets.token_urlsafe(32)
        with self.app.lock:
            self.app.sessions[token] = Session(user, ch)
        return {"user": user, "token": token}, ()

    def api_meta(self):
        sess = self.session()
        hospitals, fallback = read_hospitals(sess.ch)
        kpi_spec, obj_spec = TABLES["map_bsc_kpi"], TABLES["map_bsc_objective"]
        kpis = list(current(kpi_spec, read_table(sess.ch, kpi_spec.name)).values())
        objectives = list(current(obj_spec, read_table(sess.ch, obj_spec.name)).values())
        return {"user": sess.user,
                "tables": [t.to_json() for t in TABLES.values()],
                "groups": list(GROUPS),
                "hospitals": {str(k): v for k, v in hospitals.items()},
                "hospitals_fallback": fallback,
                "kpis": kpis, "objectives": objectives,
                "manual_hints": MANUAL_HINTS, "default_manual_hint": DEFAULT_MANUAL_HINT}, ()

    def api_table(self):
        sess = self.session()
        name = (self.query.get("name") or [""])[0]
        spec = TABLES.get(name)
        if spec is None:
            raise ApiError(404, "Unknown table.")
        rows = read_table(sess.ch, name)
        live = current(spec, rows)
        latest = current(spec, rows, include_removed=True)
        return {"current": list(live.values()),
                "removed": [r for k, r in latest.items() if k not in live],
                "all": rows}, ()

    def api_review(self):
        sess = self.session()
        data = self.read_json()
        note, raw = data.get("note"), data.get("changes")
        if not isinstance(raw, list) or not all(isinstance(c, dict) and isinstance(c.get("row"), dict)
                                                for c in raw):
            raise ApiError(400, "Bad request: changes must be a list of table, op and row.")
        changes = [Change(str(c.get("table")), c.get("op"), c["row"], c.get("base_changed_at"))
                   for c in raw]
        touched = {c.table for c in changes if c.table in TABLES}
        touched |= {"map_bsc_kpi", "map_bsc_objective"}
        ctx_data = {name: read_table(sess.ch, name) for name in TABLES if name in touched}
        hospitals, _ = read_hospitals(sess.ch)
        rows, issues = prepare(changes, note if isinstance(note, str) else "", sess.user,
                               Context(ctx_data, hospitals), sess.ch.server_now())
        out_issues = [{"level": i.level, "table": i.table, "key": jsonable(i.key), "message": i.message}
                      for i in issues]
        can_insert = not any(i["level"] == "error" for i in out_issues)
        review_id = secrets.token_urlsafe(16)
        sess.reviews.clear()  # only the latest review can be inserted
        sess.reviews[review_id] = {"rows": rows, "can_insert": can_insert}
        return {"review_id": review_id, "rows": rows, "issues": out_issues, "can_insert": can_insert}, ()

    def api_insert(self):
        sess = self.session()
        review_id = self.read_json().get("review_id")
        review = sess.reviews.pop(review_id, None) if isinstance(review_id, str) else None
        if review is None or not review["can_insert"]:
            raise ApiError(409, "This review is unknown, already used or has errors: review again.")
        order = [t for t in INSERT_ORDER if review["rows"].get(t)]
        for table in order:
            spec = TABLES[table]
            newest = {}
            for r in read_table(sess.ch, table):
                k = key_of(spec, r)
                newest[k] = max(newest.get(k, ""), r["changed_at"])
            for row in review["rows"][table]:
                if newest.get(key_of(spec, row), "") >= row["changed_at"]:
                    raise ApiError(409, "Changed since review: review again.")
        done = {}
        for i, table in enumerate(order):
            try:
                done[table] = sess.ch.insert(table, review["rows"][table])
            except ClickHouseError as e:
                raise ApiError(502, str(e), {"inserted": done, "failed": table,
                                             "not_inserted": order[i + 1:], "error": str(e)}) from None
        return {"inserted": done}, ()


def make_server(port, ch_url, ch_factory=ClickHouse):
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.daemon_threads = True
    app = App(ch_url, ch_factory)
    app.port = server.server_address[1]
    server.app = app
    return server


def main(argv=None):
    ap = argparse.ArgumentParser(description="BSC settings page (local)")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--url", default="http://172.22.25.214:8123/")
    ap.add_argument("--no-browser", action="store_true")
    args = ap.parse_args(argv)
    server = make_server(args.port, args.url)
    page = "http://127.0.0.1:%d/" % server.server_address[1]
    print("BSC settings page at %s (Ctrl+C to stop)" % page)
    if not args.no_browser:
        webbrowser.open(page)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
