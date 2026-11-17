<#
.SYNOPSIS
  Create default.map_policy_client on the new server and load its first content
  (docs/superpowers/specs/2026-11-16-charge-line-relationships-design.md): runs policy_config_ddl.sql, then
  policy_config_seed.sql. A table that already has rows is not seeded again: after the first run the BI manager edits
  the table with SQL (docs/policy_client_config.md).
  -Update <file> runs the DDL (new tables only) and then every INSERT of that file, whatever the table holds: an
  update file adds new versions of config rows (insert-only change log), it never seeds.
    powershell -ExecutionPolicy Bypass -File scripts\policy_config\apply_policy_config.ps1 -DryRun
    powershell -ExecutionPolicy Bypass -File scripts\policy_config\apply_policy_config.ps1
    powershell -ExecutionPolicy Bypass -File scripts\policy_config\apply_policy_config.ps1 -Update scripts\policy_config\<update file>.sql
  It asks for a ClickHouse user that may create tables and insert into database default.
#>
param(
    [string]$Url = 'http://172.22.25.214:8123/',
    [string]$Update = '',
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\HnhCh.psm1') -Force
Invoke-HnhConfigApply -Ddl (Join-Path $PSScriptRoot 'policy_config_ddl.sql') -Seed (Join-Path $PSScriptRoot 'policy_config_seed.sql') `
    -Update $Update -Url $Url -DryRun:$DryRun
