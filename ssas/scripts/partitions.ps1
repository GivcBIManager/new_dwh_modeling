<#
.SYNOPSIS
  Creates, merges and removes the date partitions of every large table (SSAS spec 9.3) and loads the changed ones
  in one transaction. -DryRun lists the changes only; -NoRefresh creates partitions without loading them.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ssas\scripts\partitions.ps1 -Database HNH_Analytics -DryRun
#>
param(
    [string]$Server = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [Parameter(Mandatory = $true)][string]$Database,
    [datetime]$Today = (Get-Date),
    [string]$TabularEditorDir = 'C:\Program Files (x86)\Tabular Editor',
    [switch]$DryRun,
    [switch]$NoRefresh
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'HnhSsas.psm1') -Force
Import-HnhTom $TabularEditorDir
$srv = Connect-HnhServer $Server
try {
    $db = Get-HnhDatabase $srv $Database
    $log = Sync-HnhPartitions -Model $db.Model -Today $Today -DryRun:$DryRun -NoRefresh:$NoRefresh
    if ($log.Count -eq 0) { Write-Host 'Partitions already match the scheme.' } else { $log | ForEach-Object { Write-Host $_ } }
} finally {
    $srv.Disconnect()
}
