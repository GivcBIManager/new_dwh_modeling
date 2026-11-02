<#
.SYNOPSIS
  Create the HR dashboard config tables in database default on the new server and load their first content
  (docs/superpowers/specs/2026-11-02-hr-dashboard-design.md): runs hr_config_ddl.sql, then hr_config_seed.sql.
  A table that already has rows is not seeded again: after the first run the BI manager edits the tables with SQL.
  -Update <file> runs the DDL (new tables only) and then every INSERT of that file, whatever the tables hold: an
  update file adds new versions of config rows (insert-only change logs), it never seeds.
    powershell -ExecutionPolicy Bypass -File scripts\hr_config\apply_hr_config.ps1 -DryRun
    powershell -ExecutionPolicy Bypass -File scripts\hr_config\apply_hr_config.ps1
    powershell -ExecutionPolicy Bypass -File scripts\hr_config\apply_hr_config.ps1 -Update scripts\hr_config\<update file>.sql
  It asks for a ClickHouse user that may create tables and insert into database default.
#>
param(
    [string]$Url = 'http://172.22.25.214:8123/',
    [string]$Update = '',
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\HnhCh.psm1') -Force
Invoke-HnhConfigApply -Ddl (Join-Path $PSScriptRoot 'hr_config_ddl.sql') -Seed (Join-Path $PSScriptRoot 'hr_config_seed.sql') `
    -Update $Update -Url $Url -DryRun:$DryRun
