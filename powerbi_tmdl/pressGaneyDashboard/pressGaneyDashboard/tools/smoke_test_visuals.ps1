# Runs the per-visual DAX produced by tools/smoke_test_visuals.py against the live model and reports
# row counts and timings. Read only (MSOLAP OLE DB). Run with Windows PowerShell 5.1:
#   python tools/smoke_test_visuals.py; powershell.exe -NoProfile -File tools\smoke_test_visuals.ps1 [-Catalog HNH_Analytics]
param(
    [string]$Server  = "hnhanalyticssrv\reportserverdb",
    [string]$Catalog = "HNH_Analytics_Test",
    [string]$Cube    = "Patient Experience",
    [int]$SlowMs     = 5000
)
$ErrorActionPreference = "Stop"
$queries = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot ".visual_queries.json") | ConvertFrom-Json
$conn = New-Object System.Data.OleDb.OleDbConnection "Provider=MSOLAP;Data Source=$Server;Initial Catalog=$Catalog;Cube=$Cube;Application Name=hnh-pressganey-smoke"
$conn.Open()

$failed = 0
foreach ($q in $queries) {
    try {
        $cmd = $conn.CreateCommand(); $cmd.CommandText = $q.countQuery; $cmd.CommandTimeout = 300
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $t = New-Object System.Data.DataTable
        [void](New-Object System.Data.OleDb.OleDbDataAdapter $cmd).Fill($t)
        $rows = $t.Rows[0][0]
        if ($rows -is [DBNull]) { $rows = 0 }
        $sw.Stop()
        # a guard that fires inside the visual returns its message where a number should be: run the sample rows too
        $cmd2 = $conn.CreateCommand(); $cmd2.CommandText = $q.query; $cmd2.CommandTimeout = 300
        $sample = New-Object System.Data.DataTable
        [void](New-Object System.Data.OleDb.OleDbDataAdapter $cmd2).Fill($sample)
        $guarded = @($sample.Rows | ForEach-Object { $r = $_; $sample.Columns | ForEach-Object { [string]$r[$_.ColumnName] } } | Where-Object { $_ -like "*can't be analysed by*" }).Count
        $flag = if ([int]$rows -eq 0) { "  <-- EMPTY" } elseif ($guarded) { "  <-- GUARD: " + (@($sample.Rows | ForEach-Object { $r = $_; $sample.Columns | ForEach-Object { [string]$r[$_.ColumnName] } } | Where-Object { $_ -like "*can't be analysed by*" })[0]) } elseif ($sw.ElapsedMilliseconds -gt $SlowMs) { "  <-- SLOW" } else { "" }
        "{0,-30} {1,-62} {2,7} rows {3,6} ms{4}" -f $q.page, $q.visual, $rows, $sw.ElapsedMilliseconds, $flag
        if ([int]$rows -eq 0 -or $guarded) { $failed++ }
    } catch {
        $failed++
        "{0,-30} {1,-62} ERROR: {2}" -f $q.page, $q.visual, $_.Exception.Message
    }
}
$conn.Close()
if ($failed) { "`n$failed visual(s) failed, returned no rows or showed a guard message"; exit 1 } else { "`nAll $($queries.Count) visual queries returned data" }
