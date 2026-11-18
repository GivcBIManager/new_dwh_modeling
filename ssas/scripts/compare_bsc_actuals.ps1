<#
.SYNOPSIS
  Read-only before/after check of the Balanced Scorecard when its finance building blocks change (finance report
  plan, Task 12): [BSC Actual] and [BSC Target] per 'BSC KPI'[KPI Code] x hospital (Branch Key 1-8) for one month,
  written to a CSV, and a comparison of two such CSVs. It only runs DAX (Invoke-HnhDax); it never writes to SSAS.
    powershell -ExecutionPolicy Bypass -File ssas\scripts\compare_bsc_actuals.ps1 -Database HNH_Analytics_Test -YearMonth 202610 -Out C:\HNH\finance\bsc_before.csv
    powershell -ExecutionPolicy Bypass -File ssas\scripts\compare_bsc_actuals.ps1 -Compare C:\HNH\finance\bsc_before.csv,C:\HNH\finance\bsc_after.csv
  CSV columns: kpi_code, hospital, actual, target (invariant culture, round-trip numbers, blank = empty). Every KPI x
  hospital pair is written, blank ones too, so a KPI that turns blank shows in the comparison.
  -Compare prints kpi_code, hospital, before, after, change_pct of -Measure (actual by default, or target) for the
  pairs that differ, sorted by |change_pct| (a pair that appears or turns blank, or moves from 0, first); -PassThru
  returns the rows instead of printing them. -Values '<json>' takes the query's rows (an array of
  {kpi_code, hospital, actual, target}) instead of querying SSAS (tests).
#>
param(
    [string]$Server = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [string]$Database = 'HNH_Analytics_Test',
    [int]$YearMonth = 0,
    [string]$Out = '',
    [string[]]$Compare = @(),
    [ValidateSet('actual', 'target')][string]$Measure = 'actual',
    [switch]$PassThru,
    [string]$Values = ''
)
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture

function Get-BscActualsQuery([int]$YearMonth) {
    # Every KPI x hospital, blank measures included (ADDCOLUMNS keeps the rows SUMMARIZECOLUMNS would drop).
    return @"
EVALUATE
VAR k = VALUES ( 'BSC KPI'[KPI Code] )
VAR b = FILTER ( ALL ( Branch[Branch Key] ), Branch[Branch Key] IN { 1, 2, 3, 4, 5, 6, 7, 8 } )
RETURN
    ADDCOLUMNS (
        CROSSJOIN ( k, b ),
        "@a", CALCULATE ( [BSC Actual], 'Date'[Year Month] = $YearMonth ),
        "@t", CALCULATE ( [BSC Target], 'Date'[Year Month] = $YearMonth )
    )
ORDER BY 'BSC KPI'[KPI Code], Branch[Branch Key]
"@
}

function Format-BscNumber($Value) {
    # Round-trip invariant text of a number; blank (DBNull, null, '') or text (a guard message) -> ''
    if ($null -eq $Value -or $Value -is [System.DBNull]) { return '' }
    if ($Value -is [string]) {
        $d = 0.0
        if ([double]::TryParse($Value, [Globalization.NumberStyles]::Float, $inv, [ref]$d)) { return $d.ToString('R', $inv) }
        return ''
    }
    return ([double]$Value).ToString('R', $inv)
}

function ConvertTo-BscActualRows($Rows) {
    # Rows: objects or DataRows with kpi_code, hospital, actual, target (by position for a DataRow). Sorted by KPI, hospital.
    $list = foreach ($r in $Rows) {
        if ($r -is [System.Data.DataRow]) { $k = $r[0]; $h = $r[1]; $a = $r[2]; $t = $r[3] }
        else { $k = $r.kpi_code; $h = $r.hospital; $a = $r.actual; $t = $r.target }
        [pscustomobject]@{ kpi_code = [string]$k; hospital = [int]$h; actual = (Format-BscNumber $a); target = (Format-BscNumber $t) }
    }
    return @($list | Sort-Object kpi_code, hospital)
}

function Compare-BscActualRows($Before, $After, [string]$Measure = 'actual') {
    # Pairs whose value differs; change_pct = (after - before) / |before|, blank when before is blank or 0.
    $b = @{}; foreach ($r in $Before) { $b["$($r.kpi_code)|$([int]$r.hospital)"] = $r }
    $a = @{}; foreach ($r in $After) { $a["$($r.kpi_code)|$([int]$r.hospital)"] = $r }
    $keys = @($b.Keys) + @($a.Keys | Where-Object { -not $b.ContainsKey($_) })
    $rows = foreach ($key in $keys) {
        $bv = ''; $av = ''
        if ($b.ContainsKey($key)) { $bv = [string]$b[$key].$Measure }
        if ($a.ContainsKey($key)) { $av = [string]$a[$key].$Measure }
        if ($bv -eq $av) { continue }
        $pct = $null; $rank = [double]::PositiveInfinity
        if ($bv -ne '' -and $av -ne '' -and [double]::Parse($bv, $inv) -ne 0) {
            $x = [double]::Parse($bv, $inv); $y = [double]::Parse($av, $inv)
            $pct = ($y - $x) / [Math]::Abs($x)
            $rank = [Math]::Abs($pct)
        }
        $kpi, $hosp = $key.Split('|')
        [pscustomobject]@{ kpi_code = $kpi; hospital = [int]$hosp; before = $bv; after = $av; change_pct = $pct; _rank = $rank }
    }
    return @($rows | Sort-Object @{ Expression = '_rank'; Descending = $true }, kpi_code, hospital |
        Select-Object kpi_code, hospital, before, after, change_pct)
}

if ($Compare.Count) {
    $Compare = @($Compare | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
    if ($Compare.Count -ne 2) { throw '-Compare takes two files: <before.csv>,<after.csv>' }
    $result = Compare-BscActualRows -Before (Import-Csv $Compare[0]) -After (Import-Csv $Compare[1]) -Measure $Measure
    if ($PassThru) { return $result }
    Write-Host ("{0}: {1} KPI x hospital pairs differ ({2} -> {3})" -f $Measure, $result.Count, $Compare[0], $Compare[1])
    $result | Select-Object kpi_code, hospital, before, after,
        @{ Name = 'change %'; Expression = { if ($null -eq $_.change_pct) { '' } else { ($_.change_pct * 100).ToString('0.0', $inv) } } } |
        Format-Table -AutoSize | Out-String -Width 250 | Write-Host
    return
}

if (-not $Out) { throw 'Give -Out <csv> (with -Database and -YearMonth) or -Compare <before.csv>,<after.csv>' }
if ($Values) {
    $raw = @(($Values | ConvertFrom-Json) | ForEach-Object { $_ })   # PS 5.1 emits a JSON array as one object: unroll it
} else {
    if ($YearMonth -lt 200001 -or $YearMonth -gt 209912) { throw "-YearMonth must be yyyymm, got $YearMonth" }
    Import-Module (Join-Path $PSScriptRoot 'HnhSsas.psm1') -Force
    $table = Invoke-HnhDax -Server $Server -Database $Database -Query (Get-BscActualsQuery $YearMonth)
    $raw = @($table.Rows)
}
$rows = ConvertTo-BscActualRows $raw
$dir = Split-Path -Parent $Out
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
$lines = @('kpi_code,hospital,actual,target') + @($rows | ForEach-Object { '{0},{1},{2},{3}' -f $_.kpi_code, $_.hospital, $_.actual, $_.target })
[IO.File]::WriteAllText($Out, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding $false))
Write-Host ("wrote {0} ({1} rows, {2} with an actual)" -f $Out, $rows.Count, @($rows | Where-Object { $_.actual -ne '' }).Count)
