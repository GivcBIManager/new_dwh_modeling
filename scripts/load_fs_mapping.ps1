<#
.SYNOPSIS
  Load the FS mapping tables into database default on the new server from static_mappings\:
    map_fs_account       fs_account_mapping.csv (built by scripts\build_fs_account_mapping.py; BRANCH_CODE blank = all branches)
    map_fs_line_order    fs_line_order.csv
    map_budget_fs_line   budget_fs_line_mapping.csv
  Every run adds the BRANCH_CODE column to map_fs_account if the table lacks it (the models from 2026-10-14 read it).
  A table that already has rows is skipped; name it in -Replace to truncate and reload it. -DryRun checks the files
  and prints what would be loaded; it does not connect.
    powershell -ExecutionPolicy Bypass -File scripts\load_fs_mapping.ps1 -DryRun
    powershell -ExecutionPolicy Bypass -File scripts\load_fs_mapping.ps1 [-Replace map_fs_account,map_fs_line_order,map_budget_fs_line]
  Order on a model change: run it once without -Replace (adds the column), deploy the dbt models, then run it with
  -Replace and build stg_ref__fs_account+ stg_ref__fs_line_order+ stg_ref__budget_fs_line+ straight away.
  It asks for a ClickHouse user that may alter, truncate and insert into tables in database default.
#>
param(
    [string]$Folder = (Join-Path (Split-Path -Parent $PSScriptRoot) 'static_mappings'),
    [string]$Url = 'http://172.22.25.214:8123/',
    [switch]$DryRun,
    [string[]]$Replace = @()
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'HnhCh.psm1') -Force
# powershell -File passes a,b as one string: split the list
$Replace = @($Replace | ForEach-Object { $_ -split ',' } | Where-Object { $_ })

function Col([string]$Name, [string]$Type) { [pscustomobject]@{ name = $Name; type = $Type } }
$tables = @(
    @{ Table = 'map_fs_account'; File = 'fs_account_mapping.csv'
       Columns = @((Col 'ORACLE_CODE' 'UInt32'), (Col 'BRANCH_CODE' 'Nullable(UInt16)'), (Col 'FS_TYPE' 'LowCardinality(String)'),
                   (Col 'FS_ELEMENT' 'LowCardinality(String)'), (Col 'FS_CATEGORY' 'LowCardinality(String)'),
                   (Col 'FS_CAPTION' 'String'), (Col 'FS_LINE' 'String'), (Col 'MAPPED_IN' 'LowCardinality(String)')) },
    @{ Table = 'map_fs_line_order'; File = 'fs_line_order.csv'
       Columns = @((Col 'LEVEL' 'LowCardinality(String)'), (Col 'VALUE' 'String'), (Col 'SORT_ORDER' 'UInt16'),
                   (Col 'STATEMENT_GROUP' 'String')) },
    @{ Table = 'map_budget_fs_line'; File = 'budget_fs_line_mapping.csv'
       Columns = @((Col 'LINE_ITEM_CODE' 'LowCardinality(String)'), (Col 'MATCH_LEVEL' 'LowCardinality(String)'),
                   (Col 'MATCH_VALUE' 'String'), (Col 'CARE_TYPE' 'String')) }
)
foreach ($t in $tables) {
    $rows = @(Import-Csv -Path (Join-Path $Folder $t.File) -Encoding UTF8)
    if ($t.Table -eq 'map_fs_account') {
        $problems = Test-HnhFsAccountMapping -Rows $rows
        if ($problems.Count) { throw ("$($t.File):`n" + ($problems -join "`n")) }
    }
    $names = @($t.Columns | ForEach-Object name)
    # A blank BRANCH_CODE is NULL (all branches); blank text columns stay empty strings, as the first load had them.
    $t.Lines = @($rows | ForEach-Object {
        $row = $_
        ($names | ForEach-Object { if ($_ -eq 'BRANCH_CODE' -and $row.$_ -eq '') { '\N' } else { ConvertTo-HnhTsvField $row.$_ } }) -join "`t"
    })
    Write-Host ("default.{0}: {1} rows from {2}" -f $t.Table, $t.Lines.Count, $t.File)
}
if ($Replace.Count) { Write-Host "replace: $($Replace -join ', ')" }
if ($DryRun) { Write-Host '(dry run) nothing written'; return }

$admin = Get-Credential -Message 'ClickHouse user that may alter, truncate and insert into tables in database default'
if (-not $admin) { throw 'No credential entered' }
$headers = @{ 'X-ClickHouse-User' = $admin.UserName.TrimStart('\'); 'X-ClickHouse-Key' = $admin.GetNetworkCredential().Password }
function Invoke-Ch([string]$Sql, [string[]]$Lines) {
    $uri = $Url + '?query=' + [uri]::EscapeDataString($Sql)
    $body = [byte[]]@()
    if ($Lines) { $body = [Text.Encoding]::UTF8.GetBytes(($Lines -join "`n") + "`n") }
    return Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ContentType 'application/octet-stream'
}
# Invoke-RestMethod may turn a bare number reply into an Int32, so counts are read as text.
function Get-Count([string]$Table) { return [long]([string](Invoke-Ch "SELECT count() FROM default.$Table FORMAT TabSeparated")).Trim() }
foreach ($t in $tables) {
    Invoke-Ch (New-HnhTableDdl -Table "default.$($t.Table)" -Columns $t.Columns) | Out-Null
    if ($t.Table -eq 'map_fs_account') {
        Invoke-Ch 'ALTER TABLE default.map_fs_account ADD COLUMN IF NOT EXISTS BRANCH_CODE Nullable(UInt16) AFTER ORACLE_CODE' | Out-Null
    }
    $before = Get-Count $t.Table
    if ($before -gt 0 -and $Replace -notcontains $t.Table) { Write-Host "default.$($t.Table): skipped ($before rows; use -Replace $($t.Table))"; continue }
    if ($before -gt 0) { Invoke-Ch "TRUNCATE TABLE default.$($t.Table)" | Out-Null }
    $cols = ($t.Columns | ForEach-Object { "``$($_.name)``" }) -join ', '
    Invoke-Ch "INSERT INTO default.$($t.Table) ($cols) FORMAT TabSeparated" $t.Lines | Out-Null
    $after = Get-Count $t.Table
    if ($after -ne $t.Lines.Count) { throw "default.$($t.Table): expected $($t.Lines.Count) rows, found $after" }
    Write-Host "default.$($t.Table): loaded $after rows"
}
