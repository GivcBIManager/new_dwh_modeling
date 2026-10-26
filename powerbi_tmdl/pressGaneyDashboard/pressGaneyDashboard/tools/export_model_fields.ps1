# Exports the tables, columns and measures visible through the live connection (the perspective) into
# tools/model_fields.json, so tools/build_report.py can verify every column a visual references. Measures are
# exported too, but the build also accepts the measures of the perspective in the repository's TMDL, so a report
# can be built before a model deploy. Read only: DMV queries through the MSOLAP OLE DB provider.
# Run with Windows PowerShell 5.1:  powershell.exe -NoProfile -File tools\export_model_fields.ps1 [-Catalog HNH_Analytics]
param(
    [string]$Server  = "hnhanalyticssrv\reportserverdb",
    [string]$Catalog = "HNH_Analytics_Test",
    [string]$Cube    = "Patient Experience"
)
$ErrorActionPreference = "Stop"
$conn = New-Object System.Data.OleDb.OleDbConnection "Provider=MSOLAP;Data Source=$Server;Initial Catalog=$Catalog;Application Name=hnh-pressganey-export"
$conn.Open()
function Dmv([string]$query) {
    $cmd = $conn.CreateCommand(); $cmd.CommandText = $query; $cmd.CommandTimeout = 120
    $t = New-Object System.Data.DataTable
    [void](New-Object System.Data.OleDb.OleDbDataAdapter $cmd).Fill($t)
    return ,$t
}
# PowerShell names are case-insensitive, so the cube variable must not be called $cube (it would overwrite $Cube).
$tables = [ordered]@{}
$hierarchies = Dmv "SELECT [DIMENSION_UNIQUE_NAME],[HIERARCHY_NAME] FROM `$SYSTEM.MDSCHEMA_HIERARCHIES WHERE [CUBE_NAME] = '$Cube'"
foreach ($h in $hierarchies.Rows) {
    $dim = [string]$h.DIMENSION_UNIQUE_NAME
    if ($dim -eq "[Measures]") { continue }
    $name = $dim.Trim("[", "]")
    if (-not $tables.Contains($name)) { $tables[$name] = [ordered]@{ columns = @(); measures = @() } }
    $tables[$name].columns += [string]$h.HIERARCHY_NAME
}
$measures = Dmv "SELECT [MEASURE_NAME],[MEASUREGROUP_NAME] FROM `$SYSTEM.MDSCHEMA_MEASURES WHERE [CUBE_NAME] = '$Cube'"
foreach ($m in $measures.Rows) {
    $t = [string]$m.MEASUREGROUP_NAME
    if (-not $tables.Contains($t)) { $tables[$t] = [ordered]@{ columns = @(); measures = @() } }
    $tables[$t].measures += [string]$m.MEASURE_NAME
}
$conn.Close()
foreach ($k in @($tables.Keys)) {
    $tables[$k].columns = @($tables[$k].columns | Sort-Object -Unique)
    $tables[$k].measures = @($tables[$k].measures | Sort-Object -Unique)
}
$result = [ordered]@{ server = $Server; catalog = $Catalog; perspective = $Cube; tables = $tables }
$out = Join-Path $PSScriptRoot "model_fields.json"
[IO.File]::WriteAllText($out, (($result | ConvertTo-Json -Depth 6) + "`n"), (New-Object Text.UTF8Encoding $false))
"Wrote $out ($($tables.Count) tables, $(($tables.Values | ForEach-Object { $_.measures.Count } | Measure-Object -Sum).Sum) measures)"
