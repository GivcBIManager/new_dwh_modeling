# BSC settings page

A small local web page for editing the twelve balanced-scorecard settings tables (`default.map_bsc_*`, see `docs/bsc_config.md`). It runs on this server only and is never shared with other machines (it listens on `127.0.0.1`).

## Start it

Double-click `start_bsc_settings.cmd` (or run `python scripts\bsc_settings\server.py`). The server opens your browser at `http://127.0.0.1:8765/`. Close the window to stop it.

Options: `--port <n>`, `--url <ClickHouse HTTP URL>` (default `http://172.22.25.214:8123/`), `--no-browser`.

## Desktop shortcut (one-time step for you)

1. Right-click the desktop, New, Shortcut.
2. Location: the full path of `start_bsc_settings.cmd` in this folder.
3. Name it `BSC settings`.

## Sign in

Use a ClickHouse user that has SELECT and INSERT on the twelve `default.map_bsc_*` tables and SELECT on `gold.ssas_dim_branch` (for the hospital names; without it the page shows hospital numbers). The password stays in the page server's memory only. A page reload forgets the sign-in: sign in again.

## How a change works

Pick a table, edit cells, add rows or remove rows. Each edit goes into the "changes waiting" list under the grid. Type a note (saved on every row), press Review & save, read the exact rows and any errors or warnings, then Insert. Tables are change logs: nothing is overwritten, History shows every version and can restore one.

Saved changes show in the report the next morning, after the nightly build and SSAS refresh.
