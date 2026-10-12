<#
.SYNOPSIS
  Compare the columns of a bsc model, rendered and described through HNH_Gold, with its contract in _bsc__models.yml.
    powershell -ExecutionPolicy Bypass -File scripts\check_bsc_contract.ps1 -Model bsc_vw_customer [-Inline a,b] [-Replace model=path.sql]
  Exit code 0 when names, types and order match.
#>
param(
    [Parameter(Mandatory = $true)][string]$Model,
    [string[]]$Inline = @(),
    [string[]]$Replace = @()
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'HnhCh.psm1') -Force
$yamlPath = Join-Path $PSScriptRoot '..\hnh_dwh\models\hnh\marts\bsc\_bsc__models.yml'
$expected = Get-HnhContractColumns -YamlText ([IO.File]::ReadAllText($yamlPath)) -Model $Model
if ($expected.Count -eq 0) { throw "no contract for $Model in _bsc__models.yml" }
$out = Join-Path $env:TEMP "hnh_describe_$Model.sql"
$pyArgs = @((Join-Path $PSScriptRoot 'render_model_sql.py'), $Model, '--wrap', 'DESCRIBE ({model})', '--out', $out)
if ($Inline.Count) { $pyArgs += @('--inline', ($Inline -join ',')) }
foreach ($r in $Replace) { $pyArgs += @('--replace', $r) }
& python @pyArgs
if ($LASTEXITCODE -ne 0) { throw "render_model_sql.py failed for $Model" }
# Invoke-HnhSelect returns its rows as one array: assign it, never wrap it in @() or pipe it.
$described = Invoke-HnhSelect -Dsn HNH_Gold -Sql ([IO.File]::ReadAllText($out))
$actual = @(foreach ($d in $described) { [pscustomobject]@{ Name = $d.name; Type = $d.type } })
$problems = Compare-HnhColumns -Expected $expected -Actual $actual
if ($problems.Count) { $problems | ForEach-Object { Write-Host $_ }; exit 1 }
Write-Host "$Model`: $($expected.Count) columns match the contract"
