<#
.SYNOPSIS
  Deploys HNH_Analytics (SSAS spec 10.2): Validate (Best Practice Analyzer) -> Test (HNH_Analytics_Test: when it holds
  data, deploy metadata only, load new or changed tables and refresh the last 3 months; otherwise or with -Full, deploy
  with partitions and process fully; then test.ps1) -> Promote (backup, deploy metadata keeping partitions, members and
  data source, load what is not processed). The test database stays loaded for the next deploy (decision P38).
  Rollback restores a backup.
  Validate = Best Practice Analyzer; schema drift is caught by the enforced dbt contracts and by the Test stage
  (no TE2 -SC: TabularEditor.exe is 32-bit and the server has only the 64-bit ClickHouse ODBC driver; spec P17).
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage All
  powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage All -Full
  powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage Rollback -BackupFile HNH_Analytics_20261010_220000.abf
  powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage TestMeasures
#>
param(
    [ValidateSet('All', 'Validate', 'Test', 'Promote', 'Rollback', 'TestMeasures')][string]$Stage = 'All',
    [string]$Server = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [string]$TabularEditorDir = 'C:\Program Files (x86)\Tabular Editor',
    [string]$Dsn = 'HNH_Gold',
    [string]$BackupFile,
    [switch]$Full
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$modelDir = Join-Path $root 'HNH_Analytics'
$rules = Join-Path $root 'bpa_rules.json'
$te = Join-Path $TabularEditorDir 'TabularEditor.exe'
$group = "$env:COMPUTERNAME\HNH_BI_Users"
# Members of the role 'HNH Admins' (database administrators) on HNH_Analytics and HNH_Analytics_Test.
$admins = @('HNHRIYADH\inmabideveloper', 'HNHRIYADH\inmabimanager')
Import-Module (Join-Path $PSScriptRoot 'HnhSsas.psm1') -Force
Import-HnhTom $TabularEditorDir
$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force $logDir | Out-Null
Start-Transcript -Path (Join-Path $logDir ('deploy_{0}_{1:yyyyMMdd_HHmmss}.log' -f $Stage, (Get-Date))) | Out-Null

function Invoke-TabularEditor([string[]]$Arguments) {
    $out = & $te @Arguments 2>&1 | Out-String
    Write-Host $out
    if ($LASTEXITCODE -ne 0 -or $out -match 'type=error') { throw "Tabular Editor failed: $($Arguments -join ' ')" }
}
function Invoke-Step([string]$Script, [hashtable]$Arguments) {
    # Named parameters through a hashtable splat (Invoke-HnhStep, Deploy.Tests.ps1).
    Invoke-HnhStep -ScriptPath (Join-Path $PSScriptRoot $Script) -Arguments $Arguments
}
function Want([string]$Name) { return ($Stage -eq 'All' -or $Stage -eq $Name) }
function Add-Admins($Model) {
    # A deploy that recreates the database (-Full) drops role members, so they are added after every deploy.
    foreach ($a in $admins) { if (Add-HnhRoleMember -Model $Model -Role 'HNH Admins' -Member $a) { Write-Host "role member $a added to HNH Admins" } }
}

$exitCode = 0
try {
    if (Want 'Validate') {
        Write-Host '== Validate'
        Invoke-TabularEditor @($modelDir, '-A', $rules, '-V')
    }
    if (Want 'Test') {
        Write-Host '== Test: HNH_Analytics_Test'
        $srv = Connect-HnhServer $Server
        $testDb = $srv.Databases.FindByName('HNH_Analytics_Test')
        $ready = 0
        if ($testDb -ne $null) { $ready = Get-HnhReadyPartitionCount -Model $testDb.Model }
        $mode = Select-HnhTestMode -Exists ($testDb -ne $null) -ReadyPartitions $ready -Full $Full.IsPresent
        $srv.Disconnect()
        Write-Host ("test mode: {0} ({1} loaded partitions)" -f $mode, $ready)
        if ($mode -eq 'Full') {
            Invoke-TabularEditor @($modelDir, '-D', $Server, 'HNH_Analytics_Test', '-O', '-C', '-P', '-R', '-E', '-V')
        } else {
            # Metadata only: partitions, data and the data source stay; new or changed tables are loaded below.
            Invoke-TabularEditor @($modelDir, '-D', $Server, 'HNH_Analytics_Test', '-O', '-R', '-E', '-V')
        }
        $srv = Connect-HnhServer $Server
        # Remove the readers group after the tests only if this deploy added it: members put there on purpose stay.
        $readersAdded = Add-HnhRoleMember -Model (Get-HnhDatabase $srv 'HNH_Analytics_Test').Model -Role 'HNH Readers' -Member $group
        Add-Admins (Get-HnhDatabase $srv 'HNH_Analytics_Test').Model
        $srv.Disconnect()
        Invoke-Step 'partitions.ps1' @{ Server = $Server; Database = 'HNH_Analytics_Test'; TabularEditorDir = $TabularEditorDir; NoRefresh = $true }
        if ($mode -eq 'Full') {
            Invoke-Step 'process.ps1' @{ Server = $Server; Database = 'HNH_Analytics_Test'; Mode = 'Weekly'; Force = $true; Dsn = $Dsn; TabularEditorDir = $TabularEditorDir }
        } else {
            $srv = Connect-HnhServer $Server
            $loaded = Update-HnhUnprocessed -Model (Get-HnhDatabase $srv 'HNH_Analytics_Test').Model
            $srv.Disconnect()
            Write-Host ("loaded {0} unprocessed partition(s): {1}" -f $loaded.Count, ($loaded -join '; '))
            Invoke-Step 'process.ps1' @{ Server = $Server; Database = 'HNH_Analytics_Test'; Mode = 'Daily'; Force = $true; Dsn = $Dsn; TabularEditorDir = $TabularEditorDir }
        }
        try {
            Invoke-Step 'test.ps1' @{ Server = $Server; Database = 'HNH_Analytics_Test'; Dsn = $Dsn; TabularEditorDir = $TabularEditorDir }
        } finally {
            if ($readersAdded) {
                $srv = Connect-HnhServer $Server
                if (Remove-HnhRoleMember -Model (Get-HnhDatabase $srv 'HNH_Analytics_Test').Model -Role 'HNH Readers' -Member $group) { Write-Host "role member $group removed from HNH_Analytics_Test" }
                $srv.Disconnect()
            }
        }
    }
    if (Want 'Promote') {
        Write-Host '== Promote: HNH_Analytics'
        $srv = Connect-HnhServer $Server
        $prod = $srv.Databases.FindByName('HNH_Analytics')
        if ($prod -ne $null) {
            $file = 'HNH_Analytics_{0:yyyyMMdd_HHmmss}.abf' -f (Get-Date)
            $prod.Backup($file, $true)
            Write-Host "backup $file"
            $backupDir = $srv.ServerProperties['BackupDir'].Value
            Get-ChildItem $backupDir -Filter 'HNH_Analytics_*.abf' | Sort-Object LastWriteTime -Descending |
                Select-Object -Skip 5 | Remove-Item
            $srv.Disconnect()
            Invoke-TabularEditor @($modelDir, '-D', $Server, 'HNH_Analytics', '-O', '-R', '-E', '-V')
        } else {
            $srv.Disconnect()
            Invoke-TabularEditor @($modelDir, '-D', $Server, 'HNH_Analytics', '-O', '-C', '-P', '-R', '-E', '-V')
        }
        $srv = Connect-HnhServer $Server
        $db = Get-HnhDatabase $srv 'HNH_Analytics'
        if (Add-HnhRoleMember -Model $db.Model -Role 'HNH Readers' -Member $group) { Write-Host "role member $group added" }
        Add-Admins $db.Model
        $srv.Disconnect()
        Invoke-Step 'partitions.ps1' @{ Server = $Server; Database = 'HNH_Analytics'; TabularEditorDir = $TabularEditorDir }
        $srv = Connect-HnhServer $Server
        $loaded = Update-HnhUnprocessed -Model (Get-HnhDatabase $srv 'HNH_Analytics').Model
        Write-Host ("loaded {0} unprocessed partition(s): {1}" -f $loaded.Count, ($loaded -join '; '))
        Write-Host 'HNH_Analytics_Test kept loaded for the next changes-only test (decision P38)'
        $srv.Disconnect()
        Write-Host 'Promoted. Tag the deployed commit on the development machine: git tag ssas-YYYY.MM.DD'
    }
    if ($Stage -eq 'TestMeasures') {
        # Measure work (KPI catalogue plan): metadata to the test database, keeping its partitions and data source, load
        # only what is not processed (everything after a promotion cleared it), then run the measure checks.
        Write-Host '== Validate'
        Invoke-TabularEditor @($modelDir, '-A', $rules, '-V')
        Write-Host '== Measures: HNH_Analytics_Test'
        $srv = Connect-HnhServer $Server
        $exists = ($srv.Databases.FindByName('HNH_Analytics_Test') -ne $null)
        $srv.Disconnect()
        if (-not $exists) { throw 'HNH_Analytics_Test does not exist: run deploy.ps1 -Stage Test first' }
        Invoke-TabularEditor @($modelDir, '-D', $Server, 'HNH_Analytics_Test', '-O', '-R', '-E', '-V')
        $srv = Connect-HnhServer $Server
        $readersAdded = Add-HnhRoleMember -Model (Get-HnhDatabase $srv 'HNH_Analytics_Test').Model -Role 'HNH Readers' -Member $group
        Add-Admins (Get-HnhDatabase $srv 'HNH_Analytics_Test').Model
        $srv.Disconnect()
        Invoke-Step 'partitions.ps1' @{ Server = $Server; Database = 'HNH_Analytics_Test'; TabularEditorDir = $TabularEditorDir; NoRefresh = $true }
        $srv = Connect-HnhServer $Server
        $loaded = Update-HnhUnprocessed -Model (Get-HnhDatabase $srv 'HNH_Analytics_Test').Model
        $srv.Disconnect()
        Write-Host ("loaded {0} unprocessed partition(s)" -f $loaded.Count)
        try {
            Invoke-Step 'test.ps1' @{ Server = $Server; Database = 'HNH_Analytics_Test'; Dsn = $Dsn; TabularEditorDir = $TabularEditorDir; Stage = @('Measures') }
        } finally {
            if ($readersAdded) {
                $srv = Connect-HnhServer $Server
                if (Remove-HnhRoleMember -Model (Get-HnhDatabase $srv 'HNH_Analytics_Test').Model -Role 'HNH Readers' -Member $group) { Write-Host "role member $group removed from HNH_Analytics_Test" }
                $srv.Disconnect()
            }
        }
    }
    if ($Stage -eq 'Rollback') {
        if (-not $BackupFile) { throw 'Rollback needs -BackupFile <file name in the SSAS backup folder>' }
        $srv = Connect-HnhServer $Server
        $srv.Restore($BackupFile, 'HNH_Analytics', $true)
        $srv.Disconnect()
        Write-Host "HNH_Analytics restored from $BackupFile"
    }
} catch {
    Write-Host "ERROR: $($_.Exception.ToString())"
    $exitCode = 1
} finally {
    Stop-Transcript | Out-Null
}
exit $exitCode
