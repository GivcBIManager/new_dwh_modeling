<#
.SYNOPSIS
  Apply the recommended settings for HNHANALYTICSSRV, where SSAS, the SQL Server engine (Power BI Report Server catalog)
  and Power BI Report Server share 256 GB (SSAS spec 9.5, open item O-S5). Run in Windows PowerShell as Administrator:
    powershell -ExecutionPolicy Bypass -File scripts\configure_production_server.ps1 -DryRun   # show current -> target
    powershell -ExecutionPolicy Bypass -File scripts\configure_production_server.ps1           # apply
  All changes take effect without a service restart. It refuses to run while SSAS is processing (use -Force to override).

  1. SSAS memory: LowMemoryLimit 45, TotalMemoryLimit 60, HardMemoryLimit 70, VertiPaqMemoryLimit 55 (percent of RAM),
     QueryMemoryLimit 10 (one query may use about 10% of RAM).
  2. SQL Server engine: max server memory 32768 MB (it only holds the Report Server catalog).
  3. SQL Server Agent: start automatically (Report Server schedules and subscriptions run as Agent jobs).
  4. Windows power plan: High performance.
  5. ReportServerTempDB: shrink the log file (191 GB, under 100 MB used) to 8 GB.
#>
param(
    [string]$SsasServer = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [string]$SqlServer = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [string]$AgentService = 'SQLAgent$REPORTSERVERDB',
    [int]$SqlMaxMemoryMb = 32768,
    [int]$TempDbLogMb = 8192,
    [switch]$DryRun,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
$ssasTargets = [ordered]@{
    'Memory\LowMemoryLimit'      = '45'
    'Memory\TotalMemoryLimit'    = '60'
    'Memory\HardMemoryLimit'     = '70'
    'Memory\VertiPaqMemoryLimit' = '55'
    'Memory\QueryMemoryLimit'    = '10'
}
$highPerformance = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$mode = 'APPLY'; if ($DryRun) { $mode = 'DRY RUN' }
Write-Host "== $mode on $env:COMPUTERNAME"

# Refuse while a processing transaction is open: changing memory limits mid-load can fail it.
$conn = New-Object System.Data.OleDb.OleDbConnection "Provider=MSOLAP;Data Source=$SsasServer"
$conn.Open()
$cmd = $conn.CreateCommand(); $cmd.CommandText = 'SELECT COMMAND_TEXT FROM $SYSTEM.DISCOVER_COMMANDS'
$commands = New-Object System.Data.DataTable; [void](New-Object System.Data.OleDb.OleDbDataAdapter $cmd).Fill($commands); $conn.Close()
$processing = @($commands.Rows | Where-Object { [string]$_[0] -match '<Refresh|<Process|"refresh"' }).Count
if ($processing -gt 0 -and -not $DryRun -and -not $Force) { throw "SSAS is processing ($processing command(s)); run again when it has finished, or pass -Force" }
if ($processing -gt 0) { Write-Host "note: SSAS is processing right now ($processing command(s))" }

# 1. SSAS memory
Add-Type -Path 'C:\Program Files (x86)\Tabular Editor\Microsoft.AnalysisServices.Tabular.dll'
$srv = New-Object Microsoft.AnalysisServices.Tabular.Server
$srv.Connect("Data Source=$SsasServer")
try {
    foreach ($name in $ssasTargets.Keys) {
        $p = $srv.ServerProperties[$name]
        Write-Host ('SSAS {0,-28} {1,6} -> {2}' -f $name, $p.Value, $ssasTargets[$name])
        if (-not $DryRun) { $p.Value = $ssasTargets[$name] }
    }
    if (-not $DryRun) { $srv.Update() }
} finally { $srv.Disconnect() }

# 2 and 5. SQL Server engine
$sql = New-Object System.Data.SqlClient.SqlConnection "Server=$SqlServer;Integrated Security=true;Application Name=hnh-configure"
$sql.Open()
try {
    $q = $sql.CreateCommand()
    $q.CommandText = "SELECT CAST(value_in_use AS int) FROM sys.configurations WHERE name = 'max server memory (MB)'"
    Write-Host ('SQL  max server memory (MB)       {0,6} -> {1}' -f $q.ExecuteScalar(), $SqlMaxMemoryMb)
    $q.CommandText = "SELECT CAST(size * 8 / 1024 AS int) FROM ReportServerTempDB.sys.database_files WHERE type_desc = 'LOG'"
    Write-Host ('SQL  ReportServerTempDB log (MB)  {0,6} -> {1}' -f $q.ExecuteScalar(), $TempDbLogMb)
    if (-not $DryRun) {
        $q.CommandText = "EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'max server memory (MB)', $SqlMaxMemoryMb; RECONFIGURE;"
        [void]$q.ExecuteNonQuery()
        $q.CommandTimeout = 1800
        $q.CommandText = "USE ReportServerTempDB; CHECKPOINT; DECLARE @log sysname = (SELECT name FROM sys.database_files WHERE type_desc = 'LOG'); DBCC SHRINKFILE (@log, $TempDbLogMb) WITH NO_INFOMSGS;"
        [void]$q.ExecuteNonQuery()
    }
} finally { $sql.Close() }

# 3. SQL Server Agent
$agent = Get-Service -Name $AgentService
Write-Host ('SVC  {0,-28} {1,6} -> Automatic' -f $AgentService, $agent.StartType)
if (-not $DryRun) {
    Set-Service -Name $AgentService -StartupType Automatic
    if ($agent.Status -ne 'Running') { Start-Service -Name $AgentService }
}

# 4. Power plan
$active = (powercfg /getactivescheme) -replace '.*GUID:\s*([0-9a-f-]+).*', '$1'
Write-Host ('OS   power plan {0} -> {1} (High performance)' -f $active.Trim(), $highPerformance)
if (-not $DryRun) {
    if (-not ((powercfg /list) -match $highPerformance)) { throw 'High performance power plan not found (powercfg /list)' }
    powercfg /setactive $highPerformance
}

if (-not $DryRun) {
    Write-Host '== after'
    & $PSCommandPath -SsasServer $SsasServer -SqlServer $SqlServer -AgentService $AgentService -SqlMaxMemoryMb $SqlMaxMemoryMb -TempDbLogMb $TempDbLogMb -DryRun -Force
}
