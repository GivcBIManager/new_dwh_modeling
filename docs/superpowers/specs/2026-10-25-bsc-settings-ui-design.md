# BSC settings UI: design

Date: 2026-10-25. Status: approved in conversation (mockup `config-ui.html`); this document is the written design.

## Intent

The balanced scorecard's settings live in twelve ClickHouse change-log tables, `default.map_bsc_*` on `172.22.25.214` (documented in `docs/bsc_config.md`). Today the BI manager changes them by hand-writing `INSERT` statements. That is slow, error-prone (wrong codes, rates typed as 70 instead of 0.70, weights that no longer add up to 1), and hides the gaps: the 2026 missing-data export showed 11 KPIs with no manual values at all.

The UI replaces the hand-written SQL with a small local web page: see the current values, change them in a grid, review the rows that will be inserted, and insert them.

## Who and where (user decisions)

- **One user: the BI manager.** No roles, no user management.
- **On the production server HNHANALYTICSSRV**, used over remote desktop, in the server's browser.
- The screens of the approved mockup (below).

## Goals

1. Every one of the twelve tables can be viewed (current values) and changed (new version of a key, new key, removal) without writing SQL.
2. Manual monthly values are entered as a month grid: the manual KPIs down the side, the hospitals across, numerator and denominator per cell, empty cells highlighted.
3. Weights are edited one profile at a time with the profile's total shown against 1.00.
4. Every save shows the exact rows to be inserted, runs the checks, and inserts only after confirmation.
5. Each key's history can be seen; a change can be undone by re-inserting the previous values.

## Non-goals

- No refresh of the report from the UI: no dbt runs, no SSAS processing (those change production; the banner says changes show the next morning, as `docs/bsc_config.md` describes).
- No editing of KPI formulas (they are SSAS measures).
- No other users, no access from other machines, no hosting as a service.
- No bulk import from Excel/CSV (the memory note: config lives in ClickHouse tables, no CSV).

## Anti-goals (a failure even if it works)

- An `UPDATE`, `ALTER ... DELETE`, `TRUNCATE` or any DDL ever sent to ClickHouse. The tables are insert-only change logs; the UI sends `INSERT` only, plus `SELECT` for reading.
- A password written to disk, the repo, a log, the page source, or a command line.
- The page reachable from another machine.
- A row inserted that the user did not see in the review step.
- Installing software on the production server.

## Constraints

- **The server is production** (CLAUDE.md). Building and offline tests are fine; any insert into ClickHouse during development or testing needs the user's explicit go-ahead. Tests use a fake ClickHouse (a stub HTTP server or an injected transport), never the real one.
- **No new installs:** Python 3.12 standard library only (no Flask, no clickhouse_connect, no keyring; `pandas` is present but not needed). ClickHouse is reached over its HTTP interface (`http://172.22.25.214:8123/`), as `scripts/bsc_config/apply_bsc_config.ps1` does.
- **Windows PowerShell 5.1**, Windows Server 2025, code page 1252: send and read UTF-8 explicitly (KPI names and notes may contain non-ASCII text, e.g. "–", Arabic).
- **Credentials:** the page asks for a ClickHouse user name and password at sign-in and keeps them in the server process's memory only, for the life of the process. The login needs `SELECT` and `INSERT` on the twelve tables (and `SELECT` on the gold branch dimension for hospital names). Creating such a login is a ClickHouse write and is not part of this work; the user signs in with an existing login that has these rights.
- **Listening:** `127.0.0.1` only, on a fixed free port (builder's choice); started from a desktop shortcut (a `.cmd` or `.ps1` that starts the server and opens the browser). Stopping it: closing its console window.

## How the tables behave (from `docs/bsc_config.md` and the staging models)

- Each table has a key (listed per table in `docs/bsc_config.md`) and ends with `changed_at DateTime64(3)`, `changed_by String`, `change_note String`, `is_deleted UInt8`.
- **Current value of a key** = the row with the greatest `changed_at` for that key (keys compared after trimming spaces, as `stg_ref__bsc_*` do with `trimBoth`); if that row has `is_deleted = 1`, the key is removed and not shown (unless "show removed" is on).
- **Change** = insert a full row for the key with the new values, `changed_at = now64(3)`, `changed_by` = the signed-in ClickHouse user name, `change_note` = the note typed for the batch, `is_deleted = 0`.
- **Remove** = insert the key's current row with `is_deleted = 1`.
- **Undo** (from History) = insert an earlier version's values as a new row.
- The twelve tables and keys: `map_bsc_kpi` (kpi_code), `map_bsc_objective` (objective_code), `map_bsc_target` (kpi_code, branch_id, year, month), `map_bsc_weight` (profile, kpi_code), `map_bsc_threshold` (kpi_code; `*` = default), `map_bsc_owner` (kpi_code, branch_id), `map_bsc_hospital_category` (branch_id), `map_bsc_manual_value` (kpi_code, branch_id, year, month), `map_bsc_code_list` (list_name, code), `map_bsc_budgeted_fte` (branch_id, year), `map_bsc_parameter` (name), `map_bsc_licensed_beds` (branch_id, year). Column lists: `scripts/bsc_config/bsc_config_ddl.sql`.

## Screens (approved mockup)

- **Frame:** left menu grouped Monthly (Manual values) · Targets & scoring (Targets, Weights, Thresholds) · KPI setup (KPIs, Objectives & pillars, Owners) · Hospital facts (Hospital categories, Licensed beds, Budgeted FTE) · Advanced (Parameters, Code lists). A banner: signed-in user, and "Saved changes show in the report tomorrow morning."
- **Manual values:** year and month pickers; a grid of the KPIs whose current `value_source = 'manual'` (rows) × hospitals 1–8 (columns); each cell numerator / denominator; empty cells red; edited cells marked. Each KPI row shows a hint for what to enter, from `docs/bsc_config.md` (a rate already worked out: rate in numerator, 1 in denominator; complaints: count in numerator, 0 in denominator). The cell also holds the optional `note` column.
- **Weights:** a profile picker (`corporate`, `branch:1` … `branch:8`), optional pillar filter; KPI rows with their weight; the profile total, shown red when it is not 1.00 (rounded to 4 decimals). "Copy profile to a hospital" creates `branch:<id>` rows from the current profile (as pending changes, reviewed like any other).
- **Every other table:** a grid of current values with filters on the key columns, inline editing of non-key columns, "+ Add row" for a new key, per-row History and Remove, and a "show removed" switch. Columns with an allowed list are dropdowns; codes are shown with names (KPI code with KPI name, branch_id with hospital name, `0` = "All hospitals", month `0` = "Whole year").
- **Pending changes and review:** edits collect in a pending list (with Discard per item and Discard all). One note for the batch is required. "Review & save" shows, per table, the exact rows to be inserted (all columns, including the four audit columns) and the check results; "Insert" sends them; the result (rows inserted, or the error) is shown and the grid reloads from ClickHouse.

## Checks before insert

Errors block the insert; warnings are shown and the user may insert anyway.

- **Errors:** a value outside the allowed list of `docs/bsc_config.md` (kpi_type, direction, value_format, chart_hint, status, target_source, value_source, detail_page, pillar, category, profile pattern); a key that refers to a missing parent (objective_code not in current objectives, kpi_code not in current KPIs, except `*` in thresholds); branch_id outside 0–8 (0 only where the table allows it: targets, owners), month outside 0–12 (1–12 for manual values), a non-number in a number column; an empty key column; an empty batch note.
- **Warnings:** a weight profile whose total is not 1.00; a rate column (target or manual value of a `pct`-format KPI) above 1, which may be a percent typed as a whole number; a manual value with denominator 0 for a KPI other than complaints; a new KPI (it also needs its SSAS measure; `docs/bsc_config.md` says to add it parked until the measure is deployed).

## Settled after the builder check

Facts (read from ClickHouse on 2026-10-25) and the designer's calls, marked *(my call)*:

- **Hospital names:** `gold.ssas_dim_branch` (`branch_key` Int64, `branch_name`, `is_hospital`). The hospitals are `branch_key` 1–8 with `is_hospital = 'Yes'` (1 Alrabwah, 2 Khamis, 3 Jazan, 4 Unaizah, 5 Madinah, 6 Abha, 7 Ghirnata, 8 Muhayil); `branch_id` in the settings tables is that key. 0 is shown as "All hospitals" (targets, owners). If the gold read fails (login without rights), the page shows "Hospital 1" … "Hospital 8" and a banner line saying so *(my call)*.
- **Table sizes:** the twelve tables hold 0–387 rows each today (`map_bsc_weight` the largest; manual values grow by about 12 × 8 × 12 = 1,150 rows a year). The page reads a table in full and computes the current values and the history in Python *(my call)*; one rule function, unit-tested, mirroring `argMax(..., changed_at)` with trimmed keys.
- **Timestamps:** all rows of one batch share one `changed_at`, computed in Python as the later of ClickHouse's `now64(3)` (read with a `SELECT` just before the insert) and 1 ms after the greatest `changed_at` among the batch's keys, so a new row always wins *(my call)*. The pending list holds at most one change per key: a second edit of the same key replaces the first.
- **Removed keys:** the latest row decides, so a later `is_deleted = 0` row restores a removed key. "+ Add row" for a key whose latest row is removed is allowed and the review shows "restores a key removed on <date>" *(my call)*.
- **Stale data:** at review the page re-reads the batch's tables; a key whose latest row changed since the grid loaded gets a warning naming who changed it and when *(my call)*.
- **Allowed lists and hints:** a Python module holds the allowed values and the manual-entry hints, copied from `docs/bsc_config.md`; a test fails if a value in the doc's tables is missing from the module *(my call)*. `map_bsc_code_list` stays a data table, edited like the others, not the source of the dropdowns.
- **Sign-in and local safety:** a sign-in form posting to `127.0.0.1`; the credentials are tested with a `SELECT 1` and kept in memory. After sign-in a random session token is set as an `HttpOnly`, `SameSite=Strict` cookie; every request needs it, every POST also needs an `Origin`/`Host` of the page's own `127.0.0.1:<port>`. Request bodies and the password are never logged or echoed. Plain HTTP on 127.0.0.1 is acceptable. This matters because other local accounts (the `HNH_BI_Users` test logins) can sign in to this server and reach 127.0.0.1 *(my call)*.
- **Copy weight profile:** "Copy profile to a hospital" makes the target profile identical to the source: a row for every KPI of the source, plus an `is_deleted = 1` row for every KPI the target has and the source lacks. The review lists both *(my call)*.

## Left to the builder

Port number; file layout (suggested: `scripts/bsc_settings/`, with the README in that folder and a link from `docs/bsc_config.md`); page technology (plain HTML/JS served by `http.server`, no external CDN, since the server may not reach the internet); grid behaviour details; how the shortcut is created (documented step for the user, not created by the build); test structure (unit tests for the current-value rule, insert builder and checks; an HTTP test against a stub ClickHouse).
