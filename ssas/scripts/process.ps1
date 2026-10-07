<#
.SYNOPSIS
  Processes HNH_Analytics after a successful dbt run (SSAS spec 9.4).
  Daily: partitions in line with today, dimensions + last 3 months + Later + No date of each large table + small facts, then Calculate.
  Weekly: full refresh. One transaction each. Exit 0 = processed, 2 = gate closed (nothing done), 1 = error.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ssas\scripts\process.ps1 -Mode Daily
#>
param(
    [string]$Server = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [string]$Database = 'HNH_Analytics',
    [ValidateSet('Daily', 'Weekly')][string]$Mode = 'Daily',
    [string]$Dsn = 'HNH_Gold',
    [string]$TabularEditorDir = 'C:\Program Files (x86)\Tabular Editor',
    [datetime]$Today = (Get-Date),
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'HnhSsas.psm1') -Force
$root = Split-Path $PSScriptRoot -Parent
$logDir = Join-Path $root 'logs'
$stateDir = Join-Path $root 'state'
New-Item -ItemType Directory -Force $logDir, $stateDir | Out-Null
Start-Transcript -Path (Join-Path $logDir ('process_{0}_{1:yyyyMMdd_HHmmss}.log' -f $Database, (Get-Date))) | Out-Null
$exitCode = 0
try {
    $format = 'yyyy-MM-dd HH:mm:ss'
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $statePath = Join-Path $stateDir "$Database.json"
    $lastRun = $null
    if (Test-Path $statePath) {
        $state = Get-Content $statePath -Raw | ConvertFrom-Json
        if ($state.run_finished_at) { $lastRun = [datetime]::ParseExact($state.run_finished_at, $format, $culture) }
    }
    $run = Invoke-HnhOdbc -Dsn $Dsn -Query "select status, formatDateTime(run_finished_at, '%Y-%m-%d %H:%i:%S') as finished from gold.ssas_etl_run_log where selected = 'tag:hnh' order by run_finished_at desc limit 1"
    $status = ''; $finished = $null; $finishedText = $null
    if ($run.Rows.Count -gt 0) {
        $status = [string]$run.Rows[0]['status']
        $finishedText = [string]$run.Rows[0]['finished']
        $finished = [datetime]::ParseExact($finishedText, $format, $culture)
    }
    $since = $lastRun
    if ($Mode -eq 'Weekly') { $since = $null }
    if (-not $Force -and -not (Test-HnhGate -Status $status -FinishedAt $finished -LastProcessedRunAt $since)) {
        Write-Host "Gate closed: latest tag:hnh run status '$status' finished '$finishedText'; last processed run '$lastRun'. Nothing processed."
        $exitCode = 2
    } else {
        Import-HnhTom $TabularEditorDir
        $srv = Connect-HnhServer $Server
        try {
            $db = Get-HnhDatabase $srv $Database
            $model = $db.Model
            $log = Sync-HnhPartitions -Model $model -Today $Today -NoRefresh -NoSave
            $log | ForEach-Object { Write-Host "partition $_" }
            $watch = [Diagnostics.Stopwatch]::StartNew()
            $dataOnly = [Microsoft.AnalysisServices.Tabular.RefreshType]::DataOnly
            if ($Mode -eq 'Weekly') {
                $model.RequestRefresh([Microsoft.AnalysisServices.Tabular.RefreshType]::Full)
            } else {
                foreach ($table in @($model.Tables)) {
                    $kind = Get-HnhAnnotation $table 'hnh_kind'
                    if ($kind -eq 'calculation_group') { continue }
                    if ($kind -eq $null) { Write-Host "WARNING: table $($table.Name) has no hnh_kind annotation; not refreshed"; continue }
                    $column = Get-HnhAnnotation $table 'hnh_partition_column'
                    if ($column) {
                        foreach ($name in (Get-HnhDailyPartitionNames -Table $table.Name -Today $Today)) {
                            $part = $table.Partitions.Find($name)
                            if ($part -eq $null) { throw "Partition $name is missing: run partitions.ps1" }
                            $part.RequestRefresh($dataOnly)
                        }
                    } else {
                        $table.RequestRefresh($dataOnly)
                    }
                }
                # Partitions created above (a new month or year) are empty until loaded.
                foreach ($line in $log) {
                    if ($line -like 'add *' -or $line -like 'update *') {
                        $name = $line.Substring($line.IndexOf(' ') + 1)
                        foreach ($table in @($model.Tables)) {
                            $part = $table.Partitions.Find($name)
                            if ($part -ne $null) { $part.RequestRefresh($dataOnly) }
                        }
                    }
                }
                $model.RequestRefresh([Microsoft.AnalysisServices.Tabular.RefreshType]::Calculate)
            }
            Save-HnhModel $model
            Write-Host ('{0} processing of {1} committed in {2:N1} minutes' -f $Mode, $Database, $watch.Elapsed.TotalMinutes)
            if ($status -eq 'success' -and $finishedText) {
                @{ run_finished_at = $finishedText; processed_at = (Get-Date).ToString($format); mode = $Mode } |
                    ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8
            }
        } finally {
            $srv.Disconnect()
        }
    }
} catch {
    Write-Host "ERROR: $($_.Exception.ToString())"
    $exitCode = 1
} finally {
    Stop-Transcript | Out-Null
}
exit $exitCode
