"""Guarded ClickHouse HTTP client: the only code that talks to ClickHouse.

It can send exactly two things: a single SELECT, or an INSERT INTO default.<one of the twelve
map_bsc_* tables> FORMAT JSONEachRow. The guard runs before any network call. Credentials go in
headers only and are scrubbed from error text.
"""
import json
import urllib.error
import urllib.request

from tables import TABLES

SETTINGS = "output_format_json_quote_64bit_integers=0"


class ClickHouseError(Exception):
    pass


class ForbiddenStatement(Exception):
    pass


class ClickHouse:
    def __init__(self, url: str, user: str, password: str, timeout: float = 30):
        self.url = url
        self.user = user
        self._password = password
        self.timeout = timeout
        # No system proxy: the server is addressed directly.
        self._opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    # --- guard --------------------------------------------------------
    @staticmethod
    def _check_select(sql: str) -> str:
        text = sql.strip()
        if text.endswith(";"):
            text = text[:-1].rstrip()
        if ";" in text:
            raise ForbiddenStatement("Only a single statement is allowed.")
        if text.upper().split(None, 1)[:1] != ["SELECT"]:
            raise ForbiddenStatement("Only SELECT statements are allowed.")
        return text

    @staticmethod
    def _check_table(table: str) -> str:
        if table not in TABLES:
            raise ForbiddenStatement("Table is not one of the BSC settings tables.")
        return table

    # --- transport ----------------------------------------------------
    def _scrub(self, text: str) -> str:
        if self._password:
            text = text.replace(self._password, "***")
        return text

    def _post(self, body: str) -> str:
        base = self.url + ("&" if "?" in self.url else "?") + SETTINGS
        req = urllib.request.Request(
            base,
            data=body.encode("utf-8"),
            method="POST",
            headers={
                "X-ClickHouse-User": self.user,
                "X-ClickHouse-Key": self._password,
                "Content-Type": "text/plain; charset=utf-8",
            },
        )
        try:
            with self._opener.open(req, timeout=self.timeout) as resp:
                return resp.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", errors="replace").strip()
            raise ClickHouseError(self._scrub("ClickHouse answered HTTP %d: %s" % (e.code, detail))) from None
        except (urllib.error.URLError, OSError) as e:
            raise ClickHouseError(self._scrub("Cannot reach ClickHouse: %s" % (getattr(e, "reason", None) or e))) from None

    # --- API ----------------------------------------------------------
    def select(self, sql: str) -> list:
        text = self._check_select(sql)
        out = self._post(text + " FORMAT JSONEachRow")
        return [json.loads(line) for line in out.splitlines() if line.strip()]

    def insert(self, table: str, rows: list) -> int:
        self._check_table(table)
        if not rows:
            return 0
        lines = "\n".join(json.dumps(r, ensure_ascii=False) for r in rows)
        self._post("INSERT INTO default.%s FORMAT JSONEachRow\n%s" % (table, lines))
        return len(rows)

    def server_now(self) -> str:
        return self.select("SELECT toString(now64(3)) AS t")[0]["t"]
