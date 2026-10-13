<#
.SYNOPSIS
  Read-only side-by-side check of the bsc views (bsc spec 9.3): old server (DSN chDWH) against new (DSN HNH_Gold),
  for the given months and one whole year. Numeric columns are summed per key; a relative difference above
  -Tolerance (default 0.5%) is listed. Writes docs\reconciliation_bsc_differences.md for attribution in
  docs\reconciliation_bsc.md. Run after the new bsc views are built.
    powershell -ExecutionPolicy Bypass -File scripts\compare_bsc.ps1 [-Months 2026-08-01,2026-09-01] [-Year 2025] [-Only vw_rcm,vw_hospital]
  -NewDsn chDWH compares the old server with itself (a smoke test of the script: every view must show 0 differences).
  -CsvPath <file> also writes every key x column (equal ones too) with old and new value, data source and status;
  scriptssc_comparison_xlsx.py turns it into the Excel comparison.
#>
param([string[]]$Months = @('2026-08-01', '2026-09-01'), [int]$Year = 2025, [double]$Tolerance = 0.005, [int]$MaxRows = 200,
      [string[]]$Only = @(), [string]$NewDsn = 'HNH_Gold', [string]$CsvPath = '')
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'HnhCh.psm1') -Force
$csv = New-Object System.Collections.Generic.List[object]
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$glKeys = @('BranchId', 'Period', 'AccountType', 'FS_ELEMENT', 'FS_CATEGORY', 'FS_CAPTION', 'FS_LINE')
$views = @(
    @{ View = 'vw_customer'; Keys = @('branch_id', 'period'); Date = 'period' },
    @{ View = 'vw_financial'; Keys = @('branch_id', 'month_date'); Date = 'month_date' },
    @{ View = 'vw_gl_transactions'; Keys = $glKeys; Date = 'Period' },
    @{ View = 'vw_gl_openning_balance'; Keys = $glKeys; Date = 'Period' },
    @{ View = 'vw_hospital_beds_utilization'; Keys = @('hospital_id', 'period'); Date = 'period' },
    @{ View = 'vw_rcm'; Keys = @('hospital_id', 'period'); Date = 'period' },
    @{ View = 'vw_work_force'; Keys = @('branch_id', 'period'); Date = 'period' },
    @{ View = 'vw_income_statement_budget'; Keys = @('branch_id', 'line_item_code', 'month_date'); Date = 'month_date' },
    @{ View = 'vw_hospital'; Keys = @('Id', 'Hospital', 'City'); Date = $null },
    @{ View = 'vw_date_dim'; Keys = @('Date'); Date = 'Date' },
    @{ View = 'targets'; Keys = @('hospital_id', 'period_id', 'kpi_no', 'strategy_segment'); Date = $null },
    @{ View = 'patient_satisfaction'; Keys = @('hospital_id', 'period_id'); Date = $null }
)
# powershell -File passes a,b as one string: split the list parameters
$Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$Months = @($Months | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
if ($Only.Count) { $views = @($views | Where-Object { $Only -contains $_.View }) }
$monthList = ($Months | ForEach-Object { "'$_'" }) -join ', '
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# bsc views: old server against new (generated)')
$lines.Add('')
$lines.Add("Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm') by scripts/compare_bsc.ps1. Months: $($Months -join ', ') and the year $Year. Tolerance: $($Tolerance * 100)% relative (absolute below 1). Attribution: docs/reconciliation_bsc.md.")
foreach ($v in $views) {
    $types = Invoke-HnhSelect -Dsn chDWH -Sql "SELECT name, type FROM system.columns WHERE database = 'bsc' AND table = '$($v.View)' ORDER BY position"
    $numeric = @($types | Where-Object { $v.Keys -notcontains $_.name -and $_.type -match 'Int|Float|Decimal' } | ForEach-Object { $_.name })
    $keySql = @(for ($i = 0; $i -lt $v.Keys.Count; $i++) { "toString(``$($v.Keys[$i])``) AS key_$i" })
    $valSql = @(for ($i = 0; $i -lt $numeric.Count; $i++) { "toFloat64(sum(``$($numeric[$i])``)) AS val_$i" })
    $keyNames = @(for ($i = 0; $i -lt $v.Keys.Count; $i++) { "key_$i" })
    $valNames = @(for ($i = 0; $i -lt $numeric.Count; $i++) { "val_$i" })
    $where = ''
    if ($v.Date) {
        $d = "toDate(``$($v.Date)``)"
        $where = "WHERE toStartOfMonth($d) IN ($monthList) OR toYear($d) = $Year"
    }
    $sql = "SELECT $(($keySql + $valSql) -join ', ') FROM bsc.``$($v.View)`` $where GROUP BY $($keyNames -join ', ')"
    # these functions return their rows as one array: assign, never wrap in @() (it would nest the array)
    try {
        $old = Invoke-HnhSelect -Dsn chDWH -Sql $sql
        $new = Invoke-HnhSelect -Dsn $NewDsn -Sql $sql
    } catch {
        # the old vw_financial can run past the DSN timeout: record it and go on with the other views
        $lines.Add('')
        $lines.Add("## $($v.View)")
        $lines.Add('')
        $lines.Add("Not compared: $(($_.Exception.Message -split "`n")[0])")
        Write-Host "$($v.View): not compared ($($_.Exception.Message))"
        continue
    }
    $diffs = Compare-HnhBscRows -Old $old -New $new -Keys $keyNames -Columns $valNames -Tolerance $Tolerance
    # data_source (oasis / fusion / both) of each key on the new server, when the view has it
    $sourceOf = @{}
    $hasSource = Invoke-HnhSelect -Dsn $NewDsn -Sql "SELECT count() AS n FROM system.columns WHERE database = 'bsc' AND table = '$($v.View)' AND name = 'data_source'"
    if (($diffs.Count -or $CsvPath) -and $hasSource[0].n -gt 0) {
        $srcRows = Invoke-HnhSelect -Dsn $NewDsn -Sql "SELECT $($keySql -join ', '), arrayStringConcat(arraySort(groupUniqArray(toString(data_source))), '+') AS src FROM bsc.``$($v.View)`` $where GROUP BY $($keyNames -join ', ')"
        foreach ($sr in $srcRows) { $sourceOf[(($keyNames | ForEach-Object { [string]$sr.$_ }) -join '|')] = $sr.src }
    }
    if ($CsvPath) {
        # every key x column, with the same tolerance rule as Compare-HnhBscRows
        $oi = @{}; foreach ($r in $old) { $oi[(($keyNames | ForEach-Object { [string]$r.$_ }) -join '|')] = $r }
        $ni = @{}; foreach ($r in $new) { $ni[(($keyNames | ForEach-Object { [string]$r.$_ }) -join '|')] = $r }
        $allKeys = @($oi.Keys) + @($ni.Keys | Where-Object { -not $oi.ContainsKey($_) })
        $cols = $valNames
        if ($cols.Count -eq 0) { $cols = @('*') }
        foreach ($k in $allKeys) {
            $o = $oi[$k]; $n = $ni[$k]
            foreach ($c in $cols) {
                $name = '*'
                if ($c -ne '*') { $name = $numeric[[int]($c.Substring(4))] }
                $ov = ''; $nv = ''
                if ($null -ne $o -and $c -ne '*' -and $null -ne $o.$c) { $ov = ([double]$o.$c).ToString('R', $inv) }
                if ($null -ne $n -and $c -ne '*' -and $null -ne $n.$c) { $nv = ([double]$n.$c).ToString('R', $inv) }
                if ($null -eq $o) { $status = 'only new' }
                elseif ($null -eq $n) { $status = 'only old' }
                elseif ($c -eq '*') { $status = 'equal' }
                else {
                    $a = 0.0; $b = 0.0
                    if ($ov -ne '') { $a = [double]$o.$c }
                    if ($nv -ne '') { $b = [double]$n.$c }
                    $status = 'equal'
                    if ([Math]::Abs($b - $a) / [Math]::Max([Math]::Abs($a), 1.0) -gt $Tolerance) { $status = 'differs' }
                }
                $csv.Add([pscustomobject]@{ view = $v.View; key = $k; source = [string]$sourceOf[$k]; column = $name; old = $ov; new = $nv; status = $status })
            }
        }
    }
    $lines.Add('')
    $lines.Add("## $($v.View)")
    $lines.Add('')
    $lines.Add("Keys ($($v.Keys -join ', ')): old $($old.Count), new $($new.Count). Differences: $($diffs.Count).")
    if ($diffs.Count -eq 0) { continue }
    $lines.Add('')
    $lines.Add('| Key | Source | Column | Old | New | Status |')
    $lines.Add('|---|---|---|---|---|---|')
    foreach ($d in ($diffs | Select-Object -First $MaxRows)) {
        $col = $d.Column
        if ($col -like 'val_*') { $col = $numeric[[int]($col.Substring(4))] }
        $lines.Add("| $($d.Key) | $($sourceOf[$d.Key]) | $col | $($d.Old) | $($d.New) | $($d.Status) |")
    }
    if ($diffs.Count -gt $MaxRows) { $lines.Add("| ... | | $($diffs.Count - $MaxRows) more | | | |") }
}
$out = Join-Path $PSScriptRoot '..\docs\reconciliation_bsc_differences.md'
[IO.File]::WriteAllText($out, ($lines -join "`n") + "`n", (New-Object System.Text.UTF8Encoding $false))
Write-Host "wrote $out"
if ($CsvPath) {
    $csv | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "wrote $CsvPath ($($csv.Count) rows)"
}
