# HNH data warehouse modelling

dbt models for the `hnh` gold layer (`hnh_dwh/`, deployed into the receiving project described in `docs/receiving_project_config.md`) and the SSAS Tabular model `HNH_Analytics` (`ssas/`, see `ssas/README.md`). Designs and plans are in `docs/superpowers/specs/` and `docs/superpowers/plans/`.

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
