# BSC Settings UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A local web page on the production server where the BI manager views and changes the twelve `default.map_bsc_*` settings tables without writing SQL.

**Architecture:** A Python standard-library HTTP server (`http.server`) bound to 127.0.0.1 serves a vanilla HTML/JS page and a small JSON API. The server talks to ClickHouse over HTTP with an allow-list guard (SELECT, and INSERT into the twelve tables only), computes current values and checks in Python, and inserts only the exact rows a review step returned.

**Tech Stack:** Python 3.12 standard library only (`http.server`, `urllib.request`, `json`, `secrets`, `dataclasses`), pytest for tests, plain HTML/CSS/JS with no external URLs.

**Spec:** `docs/superpowers/specs/2026-10-25-bsc-settings-ui-design.md` (read it; this plan argues from it). Table rules: `docs/bsc_config.md`; columns: `scripts/bsc_config/bsc_config_ddl.sql`.

## Global Constraints

- No installs, no third-party imports in `scripts/bsc_settings/` (pytest only in tests).
- Statements sent to ClickHouse: `SELECT …` or `INSERT INTO default.map_bsc_<one of the twelve> FORMAT JSONEachRow`. Nothing else, ever (no UPDATE, ALTER, DELETE, TRUNCATE, DDL).
- Tests never reach the real ClickHouse (`172.22.25.214`): they use a stub HTTP server or an injected opener. Nothing in this plan inserts into the real ClickHouse; the first real insert is the user's, through the page.
- The password is never written to disk, a log, a response body, the page, a URL or a command line. Auth goes in the `X-ClickHouse-User` / `X-ClickHouse-Key` headers.
- Listen on `127.0.0.1` only. Default port `8765`; ClickHouse URL default `http://172.22.25.214:8123/`.
- UTF-8 everywhere (requests, responses, files). Code page 1252 must not leak in.
- `changed_at` strings are `YYYY-MM-DD HH:MM:SS.fff` (ClickHouse server time zone Asia/Riyadh; compare as strings of that format, never convert time zones).
- Copy shown in the page is English. Banner text: `Signed in to ClickHouse as <user>. Saved changes show in the report tomorrow morning.`
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Branch: `bsc-report` (current).

## Review Focus

1. Non-ASCII text (Arabic, "–") in a note or name: stored and read back unchanged (Task 3 `test_utf8_round_trip`).
2. A number typed as `0,7`, `70%`, ` ` or `abc`: an error naming the column, never stored as 0 or blank (Task 2 `test_bad_numbers_are_errors`).
3. A key typed with spaces (`FIN_DAYS_IN_AR `): trimmed, so it updates the existing key instead of creating a twin (Task 2 `test_keys_are_trimmed`).
4. ClickHouse refuses an insert mid-batch (permission, network): the page says which tables were inserted and which were not; nothing is reported saved that was not (Task 4 `test_insert_failure_reports_partial`).
5. The server restarted or the session expired while the page is open: API answers 401 and the page returns to sign-in with a message, never a blank screen (Task 4 `test_api_needs_session`, Task 5 page handling).

---

### Task 1: Table specs, allowed values and hints

**Files:**
- Create: `scripts/bsc_settings/tables.py`, `scripts/bsc_settings/__init__.py` (empty), `scripts/bsc_settings/tests/conftest.py` (adds `scripts/bsc_settings` to `sys.path`), `scripts/bsc_settings/tests/test_tables.py`
- Modify: `docs/bsc_config.md` (add `signed` to the `chart_hint` list: it is in the data today)

**Interfaces:**
- Produces:
  - `AUDIT = ("changed_at", "changed_by", "change_note", "is_deleted")`
  - `@dataclass(frozen=True) class Column: name: str; kind: Literal["str", "int", "float", "flag"]; label: str; allowed: tuple[str, ...] | None = None; ref: Literal["kpi", "kpi_or_default", "objective", "branch", "branch_or_all"] | None = None; pattern: str | None = None`
  - `@dataclass(frozen=True) class TableSpec: name: str; label: str; group: str; key: tuple[str, ...]; columns: tuple[Column, ...]` (`columns` = every non-audit column in DDL order, keys included); `def to_json(self) -> dict`
  - `TABLES: dict[str, TableSpec]` (12, in menu order), `GROUPS: tuple[str, ...]`
  - `MANUAL_HINTS: dict[str, str]`, `DEFAULT_MANUAL_HINT: str`, `RATE_FORMAT = "pct"`, `COMPLAINTS_KPI = "CUS_COMPLAINT_RATE"`

- [ ] **Step 1: Write the failing tests** in `test_tables.py`:
  - `test_twelve_tables_in_menu_order`: `list(TABLES) == ["map_bsc_manual_value", "map_bsc_target", "map_bsc_weight", "map_bsc_threshold", "map_bsc_kpi", "map_bsc_objective", "map_bsc_owner", "map_bsc_hospital_category", "map_bsc_licensed_beds", "map_bsc_budgeted_fte", "map_bsc_parameter", "map_bsc_code_list"]`; groups `("Monthly", "Targets & scoring", "KPI setup", "Hospital facts", "Advanced")`; labels as the spec's menu (`Manual values`, `Targets`, `Weights`, `Thresholds`, `KPIs`, `Objectives & pillars`, `Owners`, `Hospital categories`, `Licensed beds`, `Budgeted FTE`, `Parameters`, `Code lists`).
  - `test_columns_match_the_ddl`: parse `scripts/bsc_config/bsc_config_ddl.sql`; for every table, `[c.name for c in spec.columns] + list(AUDIT)` equals the DDL column order; kinds map String→str, UInt8/UInt16 → int (`flag` for `scale_with_months`), Float64→float.
  - `test_keys_match_the_doc`: keys `map_bsc_target ("kpi_code","branch_id","year","month")`, `map_bsc_weight ("profile","kpi_code")`, `map_bsc_manual_value ("kpi_code","branch_id","year","month")`, `map_bsc_owner ("kpi_code","branch_id")`, `map_bsc_code_list ("list_name","code")`, `map_bsc_budgeted_fte` and `map_bsc_licensed_beds ("branch_id","year")`, others single as in the spec.
  - `test_allowed_values_cover_the_doc`: every backticked value in the "Allowed values" cells of `docs/bsc_config.md` for kpi_type, direction, value_format, chart_hint, status, target_source, value_source, detail_page is in the matching `allowed`; plus pillar `("Financial", "Customer", "Internal Process", "Learning & Growth")`, category `("Scale & Optimize", "Anchor & Protect", "Ramp-Up & Prove")`, list_name `("ancillary_category", "satisfaction_nps_role")`, weight profile `pattern = r"^(corporate|branch:[1-8])$"`, `chart_hint` includes `"signed"`.
  - `test_refs`: `kpi_code` is `ref="kpi"` everywhere except threshold (`"kpi_or_default"`); `objective_code` in map_bsc_kpi is `"objective"`; `branch_id` is `"branch_or_all"` in target and owner, `"branch"` elsewhere.
  - `test_manual_hints`: `MANUAL_HINTS["CUS_COMPLAINT_RATE"] == "Count in numerator, 0 in denominator (the measure divides by OP and ER visits)."`; `DEFAULT_MANUAL_HINT == "Numerator and denominator; for a rate already worked out, the rate in numerator and 1 in denominator."`
- [ ] **Step 2:** `python -m pytest scripts/bsc_settings/tests -q` → FAIL (module missing).
- [ ] **Step 3:** Implement `tables.py`; add `signed` to the doc's chart_hint row.
- [ ] **Step 4:** Same command → PASS.
- [ ] **Step 5:** Commit `BSC settings UI: table specs and allowed values`.

### Task 2: Current values, batch rows and checks

**Files:**
- Create: `scripts/bsc_settings/rules.py`, `scripts/bsc_settings/tests/test_rules.py`

**Interfaces:**
- Consumes: `TABLES`, `TableSpec`, `Column`, `AUDIT`, `MANUAL_HINTS`, `RATE_FORMAT`, `COMPLAINTS_KPI` (Task 1).
- Produces:
  - `def key_of(spec: TableSpec, row: dict) -> tuple` (strings trimmed, ints as int)
  - `def current(spec: TableSpec, rows: list[dict], include_removed: bool = False) -> dict[tuple, dict]` (latest `changed_at` per key; on equal `changed_at` the later row in the list wins; removed keys dropped unless asked)
  - `def history(spec: TableSpec, rows: list[dict], key: tuple) -> list[dict]` (newest first, removed rows included)
  - `def batch_changed_at(server_now: str, latest: list[str]) -> str` (the later of `server_now` and max(`latest`) + 1 ms; same string format)
  - `@dataclass class Change: table: str; op: Literal["upsert", "remove"]; row: dict; base_changed_at: str | None = None`
  - `@dataclass class Issue: level: Literal["error", "warning"]; table: str; key: tuple; message: str`
  - `@dataclass class Context: data: dict[str, list[dict]]; hospitals: dict[int, str]` (`data` = every row of every table, as read)
  - `def prepare(changes: list[Change], note: str, user: str, ctx: Context, server_now: str) -> tuple[dict[str, list[dict]], list[Issue]]` → rows to insert per table (all columns incl. audit, values coerced to the column kinds) and the issues.

- [ ] **Step 1: Write the failing tests** (`test_rules.py`), with small in-memory tables:
  - `test_current_takes_the_latest_and_drops_removed`: three versions of one target key and a removed key → one current row with the latest value; `include_removed=True` returns the removed key too.
  - `test_keys_are_trimmed` (Review Focus 3): a row keyed `"FIN_DAYS_IN_AR "` and one `"FIN_DAYS_IN_AR"` are the same key in `current`; `prepare` of an upsert with `kpi_code=" FIN_DAYS_IN_AR "` inserts `kpi_code == "FIN_DAYS_IN_AR"`.
  - `test_history_newest_first`.
  - `test_batch_changed_at`: `batch_changed_at("2026-10-25 10:00:00.000", ["2026-10-25 10:00:00.000"]) == "2026-10-25 10:00:00.001"`; `batch_changed_at("2026-10-25 10:00:05.000", ["2026-10-25 10:00:00.000"]) == "2026-10-25 10:00:05.000"`.
  - `test_upsert_row_has_audit_columns`: one inserted row with `changed_by == user`, `change_note == note`, `is_deleted == 0`, `changed_at` from `batch_changed_at`, every column of the spec present.
  - `test_remove_copies_the_current_row`: `op="remove"` with only the key → the current row's values with `is_deleted == 1`; remove of a key that has no current row → error `"nothing to remove"`.
  - `test_restoring_a_removed_key_is_a_warning`: upsert of a key whose latest row is removed → warning containing `"restores a key removed on"`.
  - `test_errors_block`: each gives level `error` and a message naming the column: direction `"up"`; status `"Active"`; profile `"branch:9"`; manual value `branch_id` 0; manual `month` 0; target `month` 13; target `branch_id` 9; `objective_code` not in current objectives; `kpi_code` not in current KPIs (threshold `"*"` allowed); empty key column; empty `note` (error `"note is required"`); two changes with the same table and key (error `"changed twice"`).
  - `test_bad_numbers_are_errors` (Review Focus 2): `target_value` of `"0,7"`, `"70%"`, `" "`, `"abc"` → error naming `target_value`; `"0.7"` and `0.7` pass.
  - `test_warnings`: weight profile whose current total after the batch is 1.01 → warning `"total 1.0100, should be 1.0000"`; target `1.5` for a KPI with `value_format == "pct"` → warning `"above 1"`; manual value numerator 70, denominator 1 for a pct KPI → same warning; manual denominator 0 for a KPI other than `CUS_COMPLAINT_RATE` → warning `"denominator 0"` (none for complaints); a new kpi_code in map_bsc_kpi → warning `"needs its SSAS measure"`.
  - `test_stale_base_is_a_warning`: a change with `base_changed_at` older than the key's latest `changed_at` → warning naming the latest row's `changed_by` and `changed_at`.
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** Implement `rules.py`. Weight totals are computed per profile over the current rows with the batch applied (rounded to 4 decimals). Number parsing accepts int/float or a string matching `^-?\d+(\.\d+)?$` after strip.
- [ ] **Step 4:** run → PASS (all tests in `scripts/bsc_settings/tests`).
- [ ] **Step 5:** Commit `BSC settings UI: current values, batch rows and checks`.

### Task 3: Guarded ClickHouse client

**Files:**
- Create: `scripts/bsc_settings/clickhouse.py`, `scripts/bsc_settings/tests/stub_clickhouse.py`, `scripts/bsc_settings/tests/test_clickhouse.py`

**Interfaces:**
- Consumes: `TABLES` (Task 1).
- Produces:
  - `class ClickHouseError(Exception)`, `class ForbiddenStatement(Exception)`
  - `class ClickHouse: def __init__(self, url: str, user: str, password: str, timeout: float = 30)`; `def select(self, sql: str) -> list[dict]` (appends ` FORMAT JSONEachRow`, settings `output_format_json_quote_64bit_integers=0`); `def insert(self, table: str, rows: list[dict]) -> int` (body `INSERT INTO default.<table> FORMAT JSONEachRow\n` + one JSON line per row; returns the row count); `def server_now(self) -> str` (`SELECT toString(now64(3)) AS t`)
  - `class StubClickHouse` (tests): a `ThreadingHTTPServer` on 127.0.0.1:0 that records each request (headers, body), answers SELECTs from an in-memory dict of tables (enough for `SELECT * FROM default.<t>`, `SELECT 1`, `now64(3)`, and the branch query of Task 4), appends inserted rows, can be told to fail the next insert or reject a user, and exposes `url`, `requests`, `tables`.

- [ ] **Step 1: Write the failing tests:**
  - `test_guard`: `select("UPDATE …")`, `select("SELECT 1; DROP TABLE x")`, `insert("map_bsc_foo", [...])`, `insert("bsc_targets", [...])` raise `ForbiddenStatement` before any request (stub records none); `select("  select 1")` is allowed.
  - `test_auth_in_headers_only`: requests carry `X-ClickHouse-User`/`X-ClickHouse-Key`; the password appears in no URL and no body.
  - `test_insert_body`: `insert("map_bsc_parameter", [row])` sends exactly `INSERT INTO default.map_bsc_parameter FORMAT JSONEachRow\n{"name": …}` and returns 1.
  - `test_utf8_round_trip` (Review Focus 1): a note `"تقرير مكافحة العدوى – سبتمبر"` inserted then selected comes back equal; request bodies are UTF-8 bytes.
  - `test_errors_scrub_the_password`: the stub answers 516 with a body containing the password → `ClickHouseError` whose text does not contain it.
- [ ] **Step 2:** run → FAIL. **Step 3:** implement (`urllib.request`, POST, query in the body). **Step 4:** run → PASS.
- [ ] **Step 5:** Commit `BSC settings UI: guarded ClickHouse client`.

### Task 4: Local server and API

**Files:**
- Create: `scripts/bsc_settings/server.py`, `scripts/bsc_settings/static/index.html` (placeholder with `<div id="app">` and `<script src="/static/app.js">`, finished in Task 5), `scripts/bsc_settings/tests/test_server.py`

**Interfaces:**
- Consumes: `ClickHouse` (Task 3), `TABLES` (Task 1), `current`, `prepare`, `Change`, `Context`, `Issue` (Task 2).
- Produces (HTTP, JSON bodies, all API responses `Cache-Control: no-store`):
  - `GET /` and `GET /static/<file>`: the page (no session needed). Other paths 404.
  - `POST /api/signin {"user", "password"}` → runs `SELECT 1`; 200 `{"user"}` + `Set-Cookie: bsc_session=<secrets.token_urlsafe(32)>; HttpOnly; SameSite=Strict; Path=/`; 401 `{"error": "Sign-in failed: <ClickHouse message>"}`.
  - `GET /api/meta` → `{"user", "tables": [spec.to_json()…], "groups", "hospitals": {"1": "Alrabwah", …}, "hospitals_fallback": bool, "kpis": [current map_bsc_kpi rows], "objectives": [current rows], "manual_hints", "default_manual_hint"}`. Hospitals from `SELECT branch_key, branch_name FROM gold.ssas_dim_branch WHERE is_hospital = 'Yes' ORDER BY branch_key`; on failure `{"1": "Hospital 1", …}` and `hospitals_fallback: true`.
  - `GET /api/table?name=<t>` → `{"current": [rows incl. changed_at/changed_by/change_note], "removed": [current-with-removed minus current], "all": [every row]}`; unknown name 404.
  - `POST /api/review {"note", "changes": [{"table", "op", "row", "base_changed_at"}]}` → re-reads every table the batch touches plus map_bsc_kpi and map_bsc_objective, calls `prepare` with `server_now()`; stores the rows under a single-use `review_id` in the session; 200 `{"review_id", "rows": {table: [rows]}, "issues": [{level, table, key, message}], "can_insert": no errors}`.
  - `POST /api/insert {"review_id"}` → 409 if unknown/used or the review had errors; inserts table by table in menu order; 200 `{"inserted": {table: n}}`; on a failure 502 `{"inserted": {done tables}, "failed": table, "not_inserted": [remaining tables], "error"}`.
  - `def make_server(port: int, ch_url: str, ch_factory=ClickHouse) -> ThreadingHTTPServer` (binds `127.0.0.1`), `def main(argv=None)` (`--port 8765`, `--url http://172.22.25.214:8123/`, `--no-browser`; opens `http://127.0.0.1:<port>/` with `webbrowser`).
  - Request rules: `Host` must be `127.0.0.1:<port>` or `localhost:<port>` (else 403); every `/api/*` except signin needs a known session cookie (else 401 `{"error": "Signed out: sign in again."}`); every POST needs `Origin` equal to `http://127.0.0.1:<port>` or `http://localhost:<port>` (else 403); `log_message` logs method, path and status only.

- [ ] **Step 1: Write the failing tests** (`test_server.py`, server on port 0 against `StubClickHouse` seeded with a few rows per table):
  - `test_binds_localhost_only`: `server.server_address[0] == "127.0.0.1"`.
  - `test_api_needs_session` (Review Focus 5): `/api/meta` without cookie → 401 with `"Signed out"`.
  - `test_signin_sets_cookie_and_never_echoes_password`: cookie flags as above; no response body or log line (capture stderr) contains the password; bad password → 401.
  - `test_host_and_origin_checks`: wrong `Host` → 403; POST without or with a foreign `Origin` → 403.
  - `test_meta_hospitals_and_fallback`: names from the stub's branch table; when the stub fails that query → `Hospital 1…8` and `hospitals_fallback`.
  - `test_review_then_insert`: a manual-value upsert → review rows equal what `prepare` returns; insert writes exactly those rows to the stub; the same `review_id` again → 409.
  - `test_review_with_errors_cannot_insert`: `can_insert` false and insert → 409, stub received no insert.
  - `test_insert_failure_reports_partial` (Review Focus 4): a batch touching two tables, stub fails the second → 502 with the first in `inserted`, the second as `failed`.
  - `test_only_select_and_insert_reach_clickhouse`: after the whole flow, every stub request body starts with `SELECT` or `INSERT INTO default.map_bsc_`.
- [ ] **Step 2:** run → FAIL. **Step 3:** implement. **Step 4:** run → PASS.
- [ ] **Step 5:** Commit `BSC settings UI: local server and API`.

### Task 5: The page: frame, sign-in, table grids, pending changes, review

**Files:**
- Modify: `scripts/bsc_settings/static/index.html`
- Create: `scripts/bsc_settings/static/app.js`, `scripts/bsc_settings/static/app.css`, `scripts/bsc_settings/start_bsc_settings.cmd`, `scripts/bsc_settings/README.md`, `scripts/bsc_settings/tests/test_page.py`
- Modify: `docs/bsc_config.md` (one line under "How a change works": the settings page, link to the README)

**Interfaces:**
- Consumes: the Task 4 API.
- Produces (for Task 6, in `app.js`): `state = {meta, tables: {name: {current, removed, all}}, pending: Map<"table|key-json", Change>, view}`, `api(method, path, body)` (on 401 shows sign-in with the message), `addPending(change)` (replaces a pending change with the same table and key), `renderPending()`, `openReview()`, `showHistory(table, key)`, `registerView(table, renderFn)` (a table with a registered view renders with it instead of the generic grid).

- [ ] **Step 1: Write the failing tests** (`test_page.py`): `/` serves `index.html` with `app.js` and `app.css`; no `http://` or `https://` URL appears in the three static files (no CDN); `node --check scripts/bsc_settings/static/app.js` exits 0 (skip if `node` is missing); `start_bsc_settings.cmd` runs `python "%~dp0server.py"`.
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** Build the page as the approved mockup (`.superpowers/brainstorm/11087-1792914712/content/config-ui.html`, screens 3 and 4, colours `#1478BE`, `#F3F6FA`, `#FDE9E5`):
  - sign-in form (user, password; Enter submits; the password field is cleared after the request);
  - left menu by group; the banner text of the Global Constraints, plus `Hospital names could not be read; showing numbers.` when `hospitals_fallback`;
  - generic grid: current rows, filters on key columns, inline edit of non-key cells (dropdown when `allowed`, KPI/objective/hospital pickers for refs showing `code · name`, `0` shown as `All hospitals` / `Whole year`), `+ Add row`, per row `History` and `Remove`, `show removed` switch; edited cells marked;
  - pending bar: count, one line per change, Discard per item and all, the required note field, `Review & save`;
  - review dialog: per table the exact rows (all columns), errors in red, warnings in amber, `Insert` disabled when `can_insert` is false; after insert, the result or the partial-failure message, then reload the touched tables;
  - History dialog: versions newest first, `Restore this version` adds an upsert with those values;
  - `start_bsc_settings.cmd` and README: how to start, how to make the desktop shortcut (a step for the user), what the login needs (SELECT + INSERT on the twelve tables, SELECT on `gold.ssas_dim_branch`), that changes show next morning.
- [ ] **Step 4:** run → PASS; start `python scripts/bsc_settings/server.py --no-browser --url http://127.0.0.1:<stub port>/` against a `StubClickHouse` seeded from fixtures and check the page loads (curl `/`, `/static/app.js`). Do not point it at the real ClickHouse.
- [ ] **Step 5:** Commit `BSC settings UI: page, grids, pending changes and review`.

### Task 6: Manual values grid, weights view, copy profile

**Files:**
- Modify: `scripts/bsc_settings/static/app.js`, `scripts/bsc_settings/static/app.css`, `scripts/bsc_settings/README.md`
- Test: `scripts/bsc_settings/tests/test_page.py` (`node --check` still passes)

**Interfaces:**
- Consumes: Task 5's `state`, `api`, `addPending`, `registerView`, `showHistory`.

- [ ] **Step 1:** Add to `test_page.py`: `app.js` registers views for `map_bsc_manual_value` and `map_bsc_weight` (grep `registerView("map_bsc_manual_value"` and `registerView("map_bsc_weight"`).
- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3:** Implement, as mockup screens 1 and 2:
  - **Manual values:** year (current year default) and month (last full month default) pickers; rows = current KPIs with `value_source == "manual"` and `status == "active"`, by `kpi_num`, each with its hint (`manual_hints[code]` or the default); columns = hospitals 1–8; cell = numerator / denominator inputs and an optional note; empty cells red (`#FDE9E5`), edited cells marked; each edited cell becomes an upsert of `map_bsc_manual_value` with `base_changed_at` of the shown row; cell `History`.
  - **Weights:** profile picker (`corporate`, `branch:1`…`branch:8` with hospital names), pillar filter; rows = current KPIs with the profile's weight (blank when the profile has no row); total line, red unless it rounds to 1.0000; `Copy profile to a hospital…` → pick a target `branch:<id>` → pending upserts for every KPI of the source plus removes for KPIs only in the target.
- [ ] **Step 4:** run → PASS; repeat the stub smoke check of Task 5.
- [ ] **Step 5:** Commit `BSC settings UI: manual values grid and weights view`.

### Task 7: First run with the user (user step)

Not for an implementer. The controller asks the user to start the page from the shortcut and sign in with their ClickHouse login; the controller may watch only through read-only checks. The first insert (suggested: one manual value the user has ready) is the user's action through the page, followed by a read-only `SELECT … ORDER BY changed_at DESC LIMIT 5` on that table to confirm the row and its audit columns.
