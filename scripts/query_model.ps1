<#
.SYNOPSIS
  Render a dbt model (scripts\render_model_sql.py), place it inside a read-only query and run it through a DSN.
    powershell -ExecutionPolicy Bypass -File scripts\query_model.ps1 -Model bsc_vw_customer `
        -Wrap "select count() from ({model})" [-Inline a,b] [-Replace model=path.sql] [-Dsn HNH_Gold]
#>
param(
    [Parameter(Mandatory = $true)][string]$Model,
    [Parameter(Mandatory = $true)][string]$Wrap,
    [string[]]$Inline = @(),
    [string[]]$Replace = @(),
    [string]$Dsn = 'HNH_Gold'
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'HnhCh.psm1') -Force
$out = Join-Path $env:TEMP "hnh_query_$Model.sql"
$pyArgs = @((Join-Path $PSScriptRoot 'render_model_sql.py'), $Model, '--wrap', $Wrap, '--out', $out)
if ($Inline.Count) { $pyArgs += @('--inline', ($Inline -join ',')) }
foreach ($r in $Replace) { $pyArgs += @('--replace', $r) }
& python @pyArgs
if ($LASTEXITCODE -ne 0) { throw "render_model_sql.py failed for $Model" }
Invoke-HnhSelect -Dsn $Dsn -Sql ([IO.File]::ReadAllText($out)) | Format-Table -AutoSize | Out-String -Width 400
