<#
.SYNOPSIS
  Load the bsc reference tables into database default on the new server (bsc spec 4.3):
    map_gl_cutover            static_mappings\gl_cutover.csv (BRANCH_ID, FIRST_FUSION_GL_MONTH as YYYYMM, NOTE)
    map_budget_line_item      copy of budget.income_statement_line_items on the old server (DSN chDWH)
    bsc_targets               copy of bsc.targets on the old server
    bsc_patient_satisfaction  copy of bsc.patient_satisfaction on the old server
  Copies keep the old column types. A table that already has rows is skipped; name it in -Replace to truncate and
  reload it. -DryRun reads the sources and prints what would be loaded; it does not connect to the new server.
    powershell -ExecutionPolicy Bypass -File scripts\load_bsc_reference.ps1 -DryRun
    powershell -ExecutionPolicy Bypass -File scripts\load_bsc_reference.ps1 [-Replace map_gl_cutover,bsc_targets]
  It asks for a ClickHouse user that may create, truncate and insert into tables in database default.
#>
param(
    [string]$CutoverCsv = (Join-Path (Split-Path -Parent $PSScriptRoot) 'static_mappings\gl_cutover.csv'),
    [string]$Url = 'http://172.22.25.214:8123/',
    [switch]$DryRun,
    [string[]]$Replace = @()
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'HnhCh.psm1') -Force
# powershell -File passes a,b as one string: split the list
$Replace = @($Replace | ForEach-Object { $_ -split ',' } | Where-Object { $_ })

$loads = @()
$cut = @(Import-Csv -Path $CutoverCsv -Encoding UTF8)
$problems = Test-HnhGlCutover -Rows $cut
if ($problems.Count) { throw ("gl_cutover.csv:`n" + ($problems -join "`n")) }
$loads += @{
    Table   = 'map_gl_cutover'
    Columns = @([pscustomobject]@{ name = 'BRANCH_ID'; type = 'UInt8' },
                [pscustomobject]@{ name = 'FIRST_FUSION_GL_MONTH'; type = 'UInt32' },
                [pscustomobject]@{ name = 'NOTE'; type = 'String' })
    Lines   = @($cut | ForEach-Object { (ConvertTo-HnhTsvField $_.BRANCH_ID), (ConvertTo-HnhTsvField $_.FIRST_FUSION_GL_MONTH), (ConvertTo-HnhTsvField $_.NOTE) -join "`t" })
}
foreach ($copy in @(@('budget', 'income_statement_line_items', 'map_budget_line_item'),
                    @('bsc', 'targets', 'bsc_targets'),
                    @('bsc', 'patient_satisfaction', 'bsc_patient_satisfaction'))) {
    $db = $copy[0]; $name = $copy[1]
    $cols = (Invoke-HnhSelect -Dsn chDWH -Sql "SELECT name, type FROM system.columns WHERE database = '$db' AND table = '$name' ORDER BY position")
    # Every value travels as text (toString), so decimals, booleans and dates arrive exactly as stored.
    $select = ($cols | ForEach-Object { "toString(``$($_.name)``) AS ``$($_.name)``" }) -join ', '
    $rows = (Invoke-HnhSelect -Dsn chDWH -Sql "SELECT $select FROM $db.$name")
    $loads += @{
        Table   = $copy[2]
        Columns = $cols
        Lines   = @($rows | ForEach-Object { $row = $_; ($cols | ForEach-Object { ConvertTo-HnhTsvField $row.($_.name) }) -join "`t" })
    }
}
foreach ($l in $loads) { Write-Host ("default.{0}: {1} rows, {2} columns" -f $l.Table, $l.Lines.Count, $l.Columns.Count) }
if ($Replace.Count) { Write-Host "replace: $($Replace -join ', ') ($($Replace.Count) tables)" }
if ($DryRun) { Write-Host '(dry run) nothing written'; return }

$admin = Get-Credential -Message 'ClickHouse user that may create, truncate and insert into tables in database default'
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
foreach ($l in $loads) {
    Invoke-Ch (New-HnhTableDdl -Table "default.$($l.Table)" -Columns $l.Columns) | Out-Null
    $before = Get-Count $l.Table
    if ($before -gt 0 -and $Replace -notcontains $l.Table) { Write-Host "default.$($l.Table): skipped ($before rows; use -Replace $($l.Table))"; continue }
    if ($before -gt 0) { Invoke-Ch "TRUNCATE TABLE default.$($l.Table)" | Out-Null }
    Invoke-Ch "INSERT INTO default.$($l.Table) FORMAT TabSeparated" $l.Lines | Out-Null
    $after = Get-Count $l.Table
    if ($after -ne $l.Lines.Count) { throw "default.$($l.Table): expected $($l.Lines.Count) rows, found $after" }
    Write-Host "default.$($l.Table): loaded $after rows"
}
