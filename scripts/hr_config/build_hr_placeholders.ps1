<#
.SYNOPSIS
  Build the placeholder HR targets (docs/superpowers/specs/2026-11-02-hr-dashboard-design.md): every active
  kind='kpi' row of hr_config_seed.sql with target_source = 'fixed' gets a target equal to the Jan-Sep 2026 level of the
  KPI, for 2026 and 2027, so the dashboard shows a status until HR confirms real targets.
  Writes an update file for apply_hr_config.ps1 -Update. Read-only: it only runs DAX against the SSAS database.
    powershell -ExecutionPolicy Bypass -File scripts\hr_config\build_hr_placeholders.ps1 -Database HNH_Analytics_Test -Out <file>.sql
  -Values '<json>' takes a JSON object of KPI code -> value instead of querying SSAS (tests). For an additive KPI the
  value is an object of branch id -> value. null or a missing code means blank.

  Value of a KPI: the measure behind [HR KPI Actual] (measure_name in the seed, the SWITCH in 'HR KPI Actual') over
  'Date'[Year Month] 202601 to 202609 and every branch, Head Office (100) included (user decision 2026-11-03), which
  is what [HR KPI Actual] returns for those months. It is queried through the measure itself because [HR KPI Actual]
  needs the HR tables deployed in the model.
  - Flow KPIs (scale_with_months = 1) hold a 9-month figure that the model pro-rates from an annual target, so the
    value is annualised x 12/9.
  - Additive KPIs (HR KPI Is Additive in ssas\HNH_Analytics\tables\_Measures.tmdl) are written per branch
    (branch_id 1 to 8 and 100, each branch's own level), because the model sums the branch targets. Others get one
    row per year with branch_id 0, which applies to every branch, Head Office included. Branch 0 of the Branch
    table (Group) is never queried or written as an additive branch: branch_id 0 means every branch.
  - Rounding: 4 decimals for pct (0.01 percentage point); every other format (num, days, sar) to a whole number when
    the absolute value is 100 or more, else to 2 decimals. The watch value is 10 percent worse than the UNROUNDED
    target in the KPI's direction (x 0.9 for higher, x 1.1 for lower, ceiling and on_target), then rounded by the same rule.

  The same update file re-inserts the 3 leave balance metrics with needs_pay = 1 (leave balance in days is pay-gated by role),
  and the map_hr_kpi rows whose wording changed in the seed after it was loaded ($WordingKpis: "Hospital, month" and
  "per hospital" became "Branch, month" and "per branch" once Head Office was included), each as the seed has it now.
  A code in both lists is written once, with needs_pay = 1 and the new wording.
#>
param(
    [string]$Server = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [string]$Database = 'HNH_Analytics_Test',
    [Parameter(Mandatory)][string]$Out,
    [string]$Values = ''
)
$ErrorActionPreference = 'Stop'
$inv = [Globalization.CultureInfo]::InvariantCulture
$dash = [string][char]0x2013

# Flow KPIs: scale_with_months = 1, annualised x 12/9. The one list of them in this script: a KPI whose value over
# several months grows with the months (a sum of the months over a level), checked 2026-11-03 by Sep 2026 against
# Jan-Sep 2026 (BSC Turnover 0.4% / 4.5%, Payroll Cost per FTE 9,289 / 85,589, BSC Revenue per Doctor 75,278 /
# 1,191,354). BuildHrPlaceholders.Tests.ps1 keeps the nature of every fixed KPI of the seed and fails on a new one.
$FlowKpis = @('HR_TURNOVER', 'HR_NEW_HIRE_TURNOVER', 'HR_STAFF_COST_PER_FTE', 'HR_REVENUE_PER_DOCTOR')
# Additive KPIs: per branch rows (hospitals and Head Office). Same two codes as measure 'HR KPI Is Additive' in ssas\HNH_Analytics\tables\_Measures.tmdl.
$AdditiveKpis = @('HR_HEADCOUNT', 'HR_LEAVE_LIABILITY')
# Metrics re-inserted with needs_pay = 1.
$PayGatedMetrics = @('HR_M_LEAVE_BALANCE', 'HR_M_CURRENT_LEAVE_BALANCE', 'HR_M_AVERAGE_LEAVE_BALANCE')
$PayGatedNote = 'Leave Balances is pay-gated by role'
# Rows whose Grain or definition changed in hr_config_seed.sql after the seed was loaded (GATE G1, 2026-11-02): the
# figures cover every branch, Head Office included (user decision 2026-11-03). Re-inserted from the seed as it is now.
# BuildHrPlaceholders.Tests.ps1 checks the list against the seed as loaded.
$WordingKpis = @('HR_SAUDIZATION', 'HR_TURNOVER', 'HR_STAFF_COST_PER_FTE', 'HR_REVENUE_PER_FTE', 'HR_OVERTIME_SHARE',
                 'HR_SICK_LEAVE_RATE', 'HR_LEAVE_LIABILITY', 'HR_VACANCY_RATE', 'HR_STAFF_TO_BED', 'HR_CLINICAL_TO_DOCTOR',
                 'HR_REVENUE_PER_DOCTOR', 'HR_VISITS_PER_FTE', 'HR_REVENUE_PER_PAYROLL_SAR', 'HR_M_FTE', 'HR_M_PAYROLL_COST',
                 'HR_M_GROSS_PAY', 'HR_M_GROSS_PAY_OPEN', 'HR_M_LEAVE_BALANCE', 'HR_M_PAYROLL_COST_PER_VISIT')
$WordingNote = 'wording: branches include Head Office'
$Years = @(2026, 2027)
$SourceBasis = "Placeholder $dash HR to confirm"
$ChangeNote = "placeholder: Jan${dash}Sep 2026 level"

# --- the KPI rows of the seed -------------------------------------------------------------------------------------------
function Split-SqlTuple([string]$Line) {
    # Raw SQL tokens of one VALUES row: 'text' (with \' escapes), numbers, now64(3).
    $m = [regex]::Matches($Line.Trim().TrimEnd(',', ';'), "'(?:\\.|[^'\\])*'|now64\(\d+\)|-?[\d.]+")
    return @($m | ForEach-Object { $_.Value })
}
function Get-SqlText([string]$Token) { return $Token.Substring(1, $Token.Length - 2).Replace("\'", "'") }

$seedPath = Join-Path $PSScriptRoot 'hr_config_seed.sql'
$seedLines = [IO.File]::ReadAllText($seedPath) -split "`r?`n"
$inKpi = $false
$kpiRows = @()
foreach ($line in $seedLines) {
    if ($line -match '^\s*--') { continue }
    if ($line -match '^INSERT INTO default\.(\w+)') { $inKpi = ($Matches[1] -eq 'map_hr_kpi'); continue }
    if ($inKpi -and $line -match '^\s{4}\(') {
        $t = Split-SqlTuple $line
        # column order of hr_config_ddl.sql: 0 kpi_code, 1 kind, 10 direction, 11 value_format, 13 measure_name, 15 target_source, 16 needs_pay, 18 status, 21 change_note
        $kpiRows += [pscustomobject]@{
            Code = Get-SqlText $t[0]; Kind = Get-SqlText $t[1]; Direction = Get-SqlText $t[10]; Format = Get-SqlText $t[11]
            Measure = Get-SqlText $t[13]; TargetSource = Get-SqlText $t[15]; Status = Get-SqlText $t[18]; Tokens = $t
        }
    }
}
$kpis = @($kpiRows | Where-Object { $_.Kind -eq 'kpi' -and $_.TargetSource -eq 'fixed' -and $_.Status -eq 'active' })
if (-not $kpis.Count) { throw "No active fixed KPI found in $seedPath" }

# --- values -------------------------------------------------------------------------------------------------------------
function ConvertTo-Number($v) {
    if ($null -eq $v -or $v -is [System.DBNull]) { return $null }
    if ($v -is [string]) {
        $d = 0.0
        # a string that is not a number is a guard message: treated as blank
        if ([double]::TryParse($v, [Globalization.NumberStyles]::Float, $inv, [ref]$d)) { return $d }
        return $null
    }
    return [double]$v
}

$valueOf = @{}      # code -> double, or code -> @{ branch -> double } for an additive KPI
if ($Values) {
    $json = $Values | ConvertFrom-Json
    foreach ($k in $kpis) {
        $v = $json.PSObject.Properties[$k.Code]
        if (-not $v) { continue }
        if ($AdditiveKpis -contains $k.Code) {
            if ($null -eq $v.Value) { continue }
            $h = @{}
            foreach ($p in $v.Value.PSObject.Properties) {
                if ([int]$p.Name -eq 0) { throw "$($k.Code): branch 0 is not a branch (branch_id 0 means every branch); give the branches' own values" }
                $n = ConvertTo-Number $p.Value; if ($null -ne $n) { $h[[int]$p.Name] = $n }
            }
            if ($h.Count) { $valueOf[$k.Code] = $h }
        } else {
            $n = ConvertTo-Number $v.Value
            if ($null -ne $n) { $valueOf[$k.Code] = $n }
        }
    }
} else {
    Import-Module (Join-Path $PSScriptRoot '..\..\ssas\scripts\HnhSsas.psm1') -Force
    $window = "'Date'[Year Month] >= 202601, 'Date'[Year Month] <= 202609"
    function Get-DaxValue([string]$Measure, [string]$Filters = '') {
        $more = if ($Filters) { ", $Filters" } else { '' }
        $q = "EVALUATE ROW ( ""v"", CALCULATE ( [$Measure], $window$more ) )"
        # a measure that is not in the deployed model fails the query: reported and treated as blank
        try { $t = Invoke-HnhDax -Server $Server -Database $Database -Query $q }
        catch { Write-Warning ("[{0}]: {1}" -f $Measure, $_.Exception.Message); return $null }
        if ($t.Rows.Count -eq 0) { return $null }
        return ConvertTo-Number $t.Rows[0][0]
    }
    # every branch but the Group member (0): the hospitals and Head Office (100)
    $bq = 'EVALUATE SELECTCOLUMNS ( FILTER ( Branch, Branch[Branch Key] <> 0 ), "k", Branch[Branch Key] )'
    $branches = @((Invoke-HnhDax -Server $Server -Database $Database -Query $bq).Rows | ForEach-Object { [int]$_[0] } | Sort-Object)
    foreach ($k in $kpis) {
        Write-Host ("querying {0} ({1})" -f $k.Code, $k.Measure)
        if ($AdditiveKpis -contains $k.Code) {
            $h = @{}
            foreach ($b in $branches) {
                $n = Get-DaxValue $k.Measure "Branch[Branch Key] = $b"
                if ($null -ne $n) { $h[$b] = $n }
            }
            if ($h.Count) { $valueOf[$k.Code] = $h }
        } else {
            # the network over every branch, Head Office included, as [HR KPI Actual] on the report's pages (their
            # branches filter keeps Group out; Group has no HR data). Branch 0 left out as in the additive path.
            $n = Get-DaxValue $k.Measure 'Branch[Branch Key] <> 0'
            if ($null -ne $n) { $valueOf[$k.Code] = $n }
        }
    }
}

# --- rows ---------------------------------------------------------------------------------------------------------------
function Format-Num([double]$x) { return $x.ToString('R', $inv) }
function Get-Rounded([double]$x, [string]$format) {
    $d = if ($format -eq 'pct') { 4 } elseif ([Math]::Abs($x) -ge 100) { 0 } else { 2 }
    return [Math]::Round($x, $d, [MidpointRounding]::AwayFromZero)
}

$targetRows = New-Object System.Collections.Generic.List[string]
$blank = New-Object System.Collections.Generic.List[string]
$summary = New-Object System.Collections.Generic.List[string]
function Add-Rows($k, [int]$branch, [double]$raw) {
    $flow = [int]($FlowKpis -contains $k.Code)
    $value = $raw
    if ($flow) { $value = $raw * 12 / 9 }
    $target = Get-Rounded $value $k.Format
    $factor = if ($k.Direction -eq 'higher') { 0.9 } else { 1.1 }
    $watch = Get-Rounded ($value * $factor) $k.Format
    foreach ($y in $Years) {
        $targetRows.Add(("    ('{0}', {1}, {2}, 0, {3}, {4}, {5}, '{6}', now64(3), 'seed', '{7}', 0)" -f $k.Code, $branch, $y, (Format-Num $target), (Format-Num $watch), $flow, $SourceBasis, $ChangeNote))
    }
    $summary.Add(("{0,-28} branch {1}  value {2,14}  target {3,14}  watch {4,14}" -f $k.Code, $branch, (Format-Num $raw), (Format-Num $target), (Format-Num $watch)))
}
foreach ($k in $kpis) {
    if (-not $valueOf.ContainsKey($k.Code)) { $blank.Add($k.Code); continue }
    if ($AdditiveKpis -contains $k.Code) {
        foreach ($b in ($valueOf[$k.Code].Keys | Sort-Object)) { Add-Rows $k $b $valueOf[$k.Code][$b] }
    } else {
        Add-Rows $k 0 $valueOf[$k.Code]
    }
}

# --- map_hr_kpi rows: pay-gated leave balance metrics, new wording -------------------------------------------------------
$metricRows = New-Object System.Collections.Generic.List[string]
foreach ($code in @($PayGatedMetrics + $WordingKpis)) {
    if (-not ($kpiRows | Where-Object { $_.Code -eq $code })) { throw "KPI $code is not in $seedPath" }
}
foreach ($row in $kpiRows) {
    $pay = $PayGatedMetrics -contains $row.Code
    $wording = $WordingKpis -contains $row.Code
    if (-not ($pay -or $wording)) { continue }
    $t = @($row.Tokens)
    $notes = @()
    if ($pay) { $t[16] = '1'; $notes += $PayGatedNote }
    if ($wording) { $notes += $WordingNote }
    $t[21] = "'" + ($notes -join '; ') + "'"
    $metricRows.Add('    (' + ($t -join ', ') + ')')
}

$kpiCols = 'kpi_code, kind, kpi_name, short_label, area, definition, formula, source_system, grain, caveats, direction, value_format, display_order, measure_name, bsc_kpi_code, target_source, needs_pay, is_home_tile, status, changed_at, changed_by, change_note, is_deleted'
$targetCols = 'kpi_code, branch_id, year, month, target_value, watch_value, scale_with_months, source_basis, changed_at, changed_by, change_note, is_deleted'
$lines = @(
    "-- HR placeholder update $((Get-Date).ToString('yyyy-MM-dd')): the target of each fixed KPI is its Jan-Sep 2026 level (flow KPIs x 12/9), for 2026 and 2027,",
    "-- until HR confirms real targets (source_basis starts with Placeholder). Additive KPIs have one row per branch (hospitals",
    "-- and Head Office 100); the others one branch_id 0 row, which applies to every branch, Head Office included.",
    "-- The leave balance metrics become pay-gated (needs_pay = 1); KPI rows whose Grain or definition now say branch",
    "-- (Head Office included) are re-inserted as the seed has them. Built by build_hr_placeholders.ps1.",
    "-- Applied with apply_hr_config.ps1 -Update; insert-only, the latest row per key wins.",
    "",
    "INSERT INTO default.map_hr_target ($targetCols) VALUES",
    ($targetRows -join ",`n") + ";",
    "",
    "INSERT INTO default.map_hr_kpi ($kpiCols) VALUES",
    ($metricRows -join ",`n") + ";",
    ""
)
[IO.File]::WriteAllText($Out, ($lines -join "`n"), (New-Object Text.UTF8Encoding($false)))

$summary | ForEach-Object { Write-Host $_ }
if ($blank.Count) { Write-Host ("Skipped, blank value: " + ($blank -join ', ')) }
Write-Host ("Wrote {0} target rows and {1} map_hr_kpi rows to {2}" -f $targetRows.Count, $metricRows.Count, $Out)
