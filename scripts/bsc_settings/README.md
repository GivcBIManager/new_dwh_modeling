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

## Manual values

Menu: **Manual values** under Monthly. Choose the year and month (default: the last full month), then fill numerator and denominator for each KPI and hospital. Cells with no value yet are red; edited cells are outlined. A cell needs both numbers: with only one filled it is marked incomplete and is not added to the changes list. Clearing both numbers of a cell that already has a value drops your edit (it does not remove the stored value). Each cell with a stored value has a History link (restore from there). The note box is optional (reach it with the mouse; Tab skips it).

## Weights

Pick a profile (`corporate` or a hospital) and optionally a pillar. A blank weight means the profile has no row for that KPI; typing a value adds one. The line `Profile total` is red unless the weights add up to 1.0000, and updates as you type.

**Copy profile to a hospital...** copies the shown profile's weights to a chosen hospital profile: every weight that differs becomes a change, and KPIs the hospital has but the source lacks are removed. Nothing is saved until you review. The page then shows the target profile.
