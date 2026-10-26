"""Guarded ClickHouse HTTP client: the only code that talks to ClickHouse.

It can send exactly two things: a single SELECT, or an INSERT INTO default.<one of the twelve
map_bsc_* tables> FORMAT JSONEachRow. The guard runs before any network call. Credentials go in
headers only and are scrubbed from error text.
"""
import json
import urllib.error
import urllib.parse
import urllib.request

from tables import TABLES

SELECT_SETTINGS = "output_format_json_quote_64bit_integers=0&readonly=2"
INSERT_SETTINGS = "output_format_json_quote_64bit_integers=0"


class ClickHouseError(Exception):
    pass


class ForbiddenStatement(Exception):
    pass


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ClickHouseError("unexpected redirect from ClickHouse")


def _check_url(url: str) -> str:
    err = ClickHouseError("ClickHouse URL must be http(s)://host:port/ with nothing after it")
    if not isinstance(url, str) or "?" in url or "#" in url:
        raise err
    try:
        parts = urllib.parse.urlsplit(url)
        host, _ = parts.hostname, parts.port
    except ValueError:
        raise err from None
    if parts.scheme not in ("http", "https") or not host or "@" in parts.netloc:
        raise err
    if parts.path not in ("", "/") or parts.query or parts.fragment:
        raise err
    return "%s://%s/" % (parts.scheme, parts.netloc)


def _check_credential(value: str) -> str:
    bad = ClickHouseError("user name or password contains characters that cannot be sent")
    if not isinstance(value, str) or any(ord(c) < 0x20 or ord(c) == 0x7F for c in value):
        raise bad
    try:
        value.encode("latin-1")
    except UnicodeEncodeError:
        raise bad from None
    return value


class ClickHouse:
    def __init__(self, url: str, user: str, password: str, timeout: float = 30):
        self.url = _check_url(url)
        self.user = _check_credential(user)
        self._password = _check_credential(password)
        self.timeout = timeout
        # No system proxy: the server is addressed directly.
        self._opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), _NoRedirect)

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

    def _post(self, body: str, settings: str) -> str:
        base = self.url + "?" + settings
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
        out = self._post(text + " FORMAT JSONEachRow", SELECT_SETTINGS)
        return [json.loads(line) for line in out.splitlines() if line.strip()]

    def insert(self, table: str, rows: list) -> int:
        self._check_table(table)
        if not rows:
            return 0
        lines = "\n".join(json.dumps(r, ensure_ascii=False) for r in rows)
        self._post("INSERT INTO default.%s FORMAT JSONEachRow\n%s" % (table, lines), INSERT_SETTINGS)
        return len(rows)

    def server_now(self) -> str:
        return self.select("SELECT toString(now64(3)) AS t")[0]["t"]
