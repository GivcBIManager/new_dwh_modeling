<#
.SYNOPSIS
  Deploys HNH_Analytics (SSAS spec 10.2): Validate (Best Practice Analyzer + schema check) -> Test (deploy to
  HNH_Analytics_Test, partition, full process, test.ps1) -> Promote (backup, deploy metadata keeping partitions,
  members and data source, load what is not processed) -> clear the test database. Rollback restores a backup.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage All
  powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage Rollback -BackupFile HNH_Analytics_20261010_220000.abf
#>
param(
    [ValidateSet('All', 'Validate', 'Test', 'Promote', 'Rollback')][string]$Stage = 'All',
    [string]$Server = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [string]$TabularEditorDir = 'C:\Program Files (x86)\Tabular Editor',
    [string]$Dsn = 'HNH_Gold',
    [string]$BackupFile
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$modelDir = Join-Path $root 'HNH_Analytics'
$rules = Join-Path $root 'bpa_rules.json'
$te = Join-Path $TabularEditorDir 'TabularEditor.exe'
$group = "$env:COMPUTERNAME\HNH_BI_Users"
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
function Invoke-Step([string]$Script, [string[]]$Arguments) {
    & (Join-Path $PSScriptRoot $Script) @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Script failed with exit code $LASTEXITCODE" }
}
function Want([string]$Name) { return ($Stage -eq 'All' -or $Stage -eq $Name) }

$exitCode = 0
try {
    if (Want 'Validate') {
        Write-Host '== Validate'
        Invoke-TabularEditor @($modelDir, '-A', $rules, '-SC', '-V')
    }
    if (Want 'Test') {
        Write-Host '== Test: HNH_Analytics_Test'
        Invoke-TabularEditor @($modelDir, '-D', $Server, 'HNH_Analytics_Test', '-O', '-C', '-P', '-R', '-E', '-V')
        $srv = Connect-HnhServer $Server
        [void](Add-HnhRoleMember -Model (Get-HnhDatabase $srv 'HNH_Analytics_Test').Model -Role 'HNH Readers' -Member $group)
        $srv.Disconnect()
        Invoke-Step 'partitions.ps1' @('-Server', $Server, '-Database', 'HNH_Analytics_Test', '-TabularEditorDir', $TabularEditorDir, '-NoRefresh')
        Invoke-Step 'process.ps1' @('-Server', $Server, '-Database', 'HNH_Analytics_Test', '-Mode', 'Weekly', '-Force', '-Dsn', $Dsn, '-TabularEditorDir', $TabularEditorDir)
        Invoke-Step 'test.ps1' @('-Server', $Server, '-Database', 'HNH_Analytics_Test', '-Dsn', $Dsn, '-TabularEditorDir', $TabularEditorDir)
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
        $srv.Disconnect()
        Invoke-Step 'partitions.ps1' @('-Server', $Server, '-Database', 'HNH_Analytics', '-TabularEditorDir', $TabularEditorDir)
        $srv = Connect-HnhServer $Server
        $loaded = Update-HnhUnprocessed -Model (Get-HnhDatabase $srv 'HNH_Analytics').Model
        Write-Host ("loaded {0} unprocessed partition(s): {1}" -f $loaded.Count, ($loaded -join '; '))
        $test = $srv.Databases.FindByName('HNH_Analytics_Test')
        if ($test -ne $null) {
            $test.Model.RequestRefresh([Microsoft.AnalysisServices.Tabular.RefreshType]::ClearValues)
            [void]$test.Model.SaveChanges()
            Write-Host 'HNH_Analytics_Test cleared'
        }
        $srv.Disconnect()
        Write-Host 'Promoted. Tag the deployed commit on the development machine: git tag ssas-YYYY.MM.DD'
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
