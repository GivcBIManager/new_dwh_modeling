"""In-process stand-in for the ClickHouse HTTP interface (127.0.0.1, random port). Tests only."""
import json
import re
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class StubClickHouse:
    def __init__(self):
        self.requests = []          # dicts: path, headers (dict), body (bytes), text (str)
        self.tables = {}            # table name -> list of row dicts
        self.branches = []          # list of {"branch_key": .., "branch_name": ..}
        self.now = "2026-10-25 09:30:00.123"
        self._fail_next_insert = False
        self._fail_selects = []
        self._rejected = {}         # user -> echo the password in the error body?
        stub = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_POST(self):
                length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(length)
                text = body.decode("utf-8", errors="replace")
                stub.requests.append({
                    "path": self.path,
                    "headers": self.headers,  # case-insensitive mapping
                    "body": body,
                    "text": text,
                })
                status, payload = stub._answer(self.headers, text)
                data = payload.encode("utf-8")
                self.send_response(status)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

        self._server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)
        self._thread.start()
        self.url = "http://127.0.0.1:%d/" % self._server.server_address[1]

    # --- controls -----------------------------------------------------
    def fail_next_insert(self):
        self._fail_next_insert = True

    def fail_select(self, substring):
        """Answer a non-200 error to any SELECT whose text contains `substring`."""
        self._fail_selects.append(substring)

    def reject_user(self, user, echo_password=False):
        """Answer 516 to this user; optionally echo the password in the body (to test scrubbing)."""
        self._rejected[user] = echo_password

    def set_now(self, value):
        self.now = value

    def close(self):
        self._server.shutdown()
        self._server.server_close()
        self._thread.join(timeout=5)

    # --- behaviour ----------------------------------------------------
    def _answer(self, headers, text):
        user = headers.get("X-ClickHouse-User")
        if user in self._rejected:
            msg = "Code: 516. DB::Exception: %s: Authentication failed" % user
            if self._rejected[user]:
                msg += " (password: %s)" % headers.get("X-ClickHouse-Key", "")
            return 516, msg + "\n"
        head = text.lstrip()
        if head.upper().startswith("INSERT INTO"):
            if self._fail_next_insert:
                self._fail_next_insert = False
                return 500, "Code: 1000. DB::Exception: insert failed\n"
            first, _, rest = head.partition("\n")
            m = re.match(r"INSERT INTO default\.(\w+) FORMAT JSONEachRow$", first.strip())
            if not m:
                return 400, "Code: 62. DB::Exception: Syntax error\n"
            rows = [json.loads(line) for line in rest.splitlines() if line.strip()]
            self.tables.setdefault(m.group(1), []).extend(rows)
            return 200, ""
        for sub in self._fail_selects:
            if sub in text:
                return 500, "Code: 60. DB::Exception: Unknown table (%s)\n" % sub
        body = re.sub(r"\s+FORMAT JSONEachRow\s*$", "", head)
        if re.fullmatch(r"SELECT 1", body, re.I):
            return 200, '{"1":1}\n'
        if "toString(now64(3))" in body:
            return 200, json.dumps({"t": self.now}) + "\n"
        if re.search(r"FROM gold\.ssas_dim_branch", body):
            return 200, "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in self.branches)
        m = re.match(r"SELECT \* FROM default\.(\w+)", body, re.I)
        if m:
            rows = self.tables.get(m.group(1), [])
            return 200, "".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows)
        return 400, "Code: 62. DB::Exception: stub does not understand: %s\n" % body
