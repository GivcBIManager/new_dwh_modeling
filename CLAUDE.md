# HNH data warehouse modelling

dbt models for the `hnh` gold layer (`hnh_dwh/`, deployed into the receiving project described in `docs/receiving_project_config.md`) and the SSAS Tabular model `HNH_Analytics` (`ssas/`, see `ssas/README.md`). Designs and plans are in `docs/superpowers/specs/` and `docs/superpowers/plans/`.

## Modelling rules

- **Source names and text are title-cased in the marts.** A mart column (`hnh_dwh/models/hnh/marts/`) that carries a name or wording from a source system wraps it in `{{ hnh_title(...) }}` (`hnh_dwh/macros/hnh/hnh_core.sql`). This covers descriptions, person / department / store / supplier / service / item names, and statuses or types as entered in Oasis or Fusion. Text written in one case is title-cased (`PANADOL 500MG TAB` → `Panadol 500mg Tab`); text that already mixes cases (`CTAS Level 2`, `JAZ Nuclear Medicine Specialist`) is kept. Apply it at the mart's output, to a qualified column (`{{ hnh_title('s.service_name') }}`), with any placeholder outside: `ifNull({{ hnh_title('description') }}, 'Not named')`. Column names stay snake_case.
  - **Not title-cased:**
    - labels this repo defines (CASE expressions, `hnh_rules*.sql` macros, mapping CSVs). Tests, `rec_*`/`bsc` SQL, measure-test SQL and key hashes match their exact values, and ClickHouse comparisons are case-sensitive.
    - codes, ids and logins.
    - long free-text sentences (payer comments, survey questions).
    - staging and intermediate models, whose joins compare raw values.
    - the `bsc` models, which keep the old server's values.
  - **Check:** `tests/hnh/assert_mart_text_title_case.sql` checks every built mart's `*description*`, `*_desc`, `*_name`, `*_name_en/_ar` and `full_name*` text column automatically, plus its `extra` list. When adding a model, wrap such columns or, for a repo label or code, add the column to the test's `excluded` list. Add other source-text columns to `extra`.
  - **Pitfall:** `{{ hnh_title('x') }} as x` changes every other unqualified `x` in the same select, because the alias wins over the column. Qualify the references or title-case in the final select.

## This machine is the production server

This checkout (`D:\new_dwh_modeling`) is on **HNHANALYTICSSRV, the production server**. It hosts the production SSAS instance `HNHANALYTICSSRV\REPORTSERVERDB` and Power BI Report Server, which real users depend on. It reaches the production ClickHouse (`172.22.25.214:8123`) through the system ODBC DSNs.

Ask the user before anything that changes the server or the live data:

- deploying, processing, restoring or dropping any SSAS database (`HNH_Analytics`, the test slot `HNH_Analytics_Test`, the spike's `HNH_Probe`), and changing role members;
- running `ssas/scripts/deploy.ps1`, `process.ps1` or `partitions.ps1` (without `-DryRun`), or `ssas/spike/spike.ps1`;
- creating or editing ODBC DSNs, local users or groups (`HNH_BI_Users`), services, server or SSAS settings, or installing software;
- any write to ClickHouse (DDL, grants, `scripts/create_ssas_reader.py` without `--check`).

Read-only work needs no confirmation: SSAS DMVs and DAX queries, `Get-OdbcDsn`, `SELECT` through a DSN, offline checks (`python -m pytest ssas/tools`, Pester, Tabular Editor `-A` BPA runs).

Never write a password into the repository or into a command that echoes it. DSN passwords live only in the server's registry. The BI users' Windows passwords live only in `C:\HNH\secrets\` (Administrators only); never print or copy them.

## Server facts that affect the design

- Workgroup machine, no Active Directory: SSAS `EffectiveUserName` fails ("your domain isn't available"). Run a test as a user by logging in as that local account.
- An SSAS server administrator bypasses row filters. Security tests need a non-admin member of `HNH_BI_Users`.
- System ANSI code page 1252. Through `MSDASQL`, the ClickHouse ODBC driver (1.4.3) reports `String` as `SQL_VARCHAR`, so Arabic text arrives as UTF-8 bytes read as 1252. It also reports `Decimal` with scale 0, so fractions are truncated (spike 2026-10-08).
- Python 3.12 is installed for all users in `C:\Program Files\Python312` (on the machine PATH). `ssas/tools/generate.py` also needs `clickhouse_connect` and the `HNH_CH_*` environment variables.
- Windows PowerShell 5.1. Tabular Editor 2.27 is 32-bit, in `C:\Program Files (x86)\Tabular Editor`. Only 64-bit ODBC drivers are installed.
