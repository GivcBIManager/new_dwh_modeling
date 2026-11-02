# Offline checks of the HR config staging models (plan 2026-11-02-hr-dashboard, Task 2).
# Each model is rendered by scripts/render_model_sql.py; its default.map_hr_* source is replaced by inline rows, and
# the SQL runs read-only through DSN HNH_Gold. Nothing is written.
#   powershell -NoProfile -Command "Invoke-Pester -Script scripts\hr_config\HrModels.Tests.ps1"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent (Split-Path -Parent $here)
Import-Module (Join-Path $root 'scripts\HnhCh.psm1') -Force

# $Replace maps a ref'd model to inline SQL, written to a temp file for --replace.
function Get-RenderedModel([string]$Model, [hashtable]$Replace = @{}) {
    $pyArgs = @((Join-Path $root 'scripts\render_model_sql.py'), $Model)
    foreach ($k in $Replace.Keys) {
        $f = [IO.Path]::GetTempFileName()
        [IO.File]::WriteAllText($f, $Replace[$k])
        $pyArgs += @('--replace', "$k=$f")
    }
    $pyArgs += @('--wrap', 'select * from ({model}) order by 1, 2')
    $sql = (& python @pyArgs) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "render failed: $Model" }
    return $sql
}

function Invoke-ModelWithSources([string]$Sql, [hashtable]$Sources) {
    $Sql = $Sql -replace '(?m)^\s*--.*$', ''
    foreach ($table in $Sources.Keys) { $Sql = $Sql.Replace("default.$table", "($($Sources[$table]))") }
    return @(Invoke-HnhSelect -Dsn HNH_Gold -Sql $Sql)
}

$cl = "now64(3) - toIntervalSecond(s) as changed_at, 'test' as changed_by, '' as change_note"
$dash = [string][char]0x2013

Describe 'stg_ref__hr_target' {
    $src = "select k as kpi_code, toUInt8(b) as branch_id, toUInt16(y) as year, toUInt8(m) as month, v as target_value, v as watch_value, " +
           "toUInt8(0) as scale_with_months, 'HR 2027' as source_basis, $cl, toUInt8(d) as is_deleted " +
           "from values('k String, b UInt8, y UInt16, m UInt8, v Float64, s UInt32, d UInt8', " +
           "('HR_TURNOVER', 0, 2027, 0, 180, 30, 0), ('HR_TURNOVER', 0, 2027, 0, 170, 20, 0), ('HR_TURNOVER', 0, 2027, 0, 160, 10, 1), " +
           "('HR_HEADCOUNT', 0, 2026, 0, 4, 20, 0), ('HR_HEADCOUNT', 0, 2026, 0, 3.8, 10, 0))"
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'stg_ref__hr_target') @{ map_hr_target = $src }
    It 'keeps only the latest row of each key and drops a deleted key' {
        $rows.Count | Should Be 1
        $rows[0].kpi_code | Should Be 'HR_HEADCOUNT'
        [double]$rows[0].target_value | Should Be 3.8
    }
}

Describe 'stg_ref__hr_target flags placeholders' {
    $src = "select k as kpi_code, toUInt8(0) as branch_id, toUInt16(2026) as year, toUInt8(0) as month, toFloat64(1) as target_value, " +
           "toFloat64(2) as watch_value, toUInt8(0) as scale_with_months, sb as source_basis, $cl, toUInt8(0) as is_deleted " +
           "from values('k String, sb String, s UInt32', ('HR_A', 'Placeholder $dash HR to confirm', 10), ('HR_B', 'HR 2027', 10))"
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'stg_ref__hr_target') @{ map_hr_target = $src }
    $r = @{}; foreach ($x in $rows) { $r[$x.kpi_code] = $x }
    It 'gives is_placeholder 1 for a Placeholder basis and 0 for a real one' {
        [int]$r['HR_A'].is_placeholder | Should Be 1
        [int]$r['HR_B'].is_placeholder | Should Be 0
    }
}

Describe 'stg_ref__hr_kpi' {
    $src = "select k as kpi_code, 'kpi' as kind, ' Turnover ' as kpi_name, 'Turnover' as short_label, 'Flow' as area, '' as definition, " +
           "'' as formula, 'Fusion' as source_system, '' as grain, '' as caveats, 'lower' as direction, 'pct' as value_format, " +
           "toUInt16(1) as display_order, 'BSC Turnover' as measure_name, '' as bsc_kpi_code, 'bsc' as target_source, toUInt8(0) as needs_pay, " +
           "toUInt8(1) as is_home_tile, 'active' as status, $cl, toUInt8(0) as is_deleted " +
           "from values('k String, s UInt32', (' HR_TURNOVER ', 10))"
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'stg_ref__hr_kpi') @{ map_hr_kpi = $src }
    It 'trims codes and text' {
        $rows.Count | Should Be 1
        $rows[0].kpi_code | Should Be 'HR_TURNOVER'
        $rows[0].kpi_name | Should Be 'Turnover'
    }
}

Describe 'stg_ref__hr_dq_issue' {
    $src = "select ' DQ_FTE_ZERO ' as issue_code, 'FTE zero' as issue_name, 'Data' as area, 'Fusion' as fix_in, 'HR' as owner, " +
           "'Medium' as severity, 'Fix it' as how_to_fix, toUInt16(1) as display_order, st as status, $cl, toUInt8(0) as is_deleted " +
           "from values('st String, s UInt32', ('active', 20), ('parked', 10))"
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'stg_ref__hr_dq_issue') @{ map_hr_dq_issue = $src }
    It 'takes the latest row, trims the code' {
        $rows.Count | Should Be 1
        $rows[0].issue_code | Should Be 'DQ_FTE_ZERO'
        $rows[0].status | Should Be 'parked'
    }
}

# Task 3 marts. Gold refs are replaced by inline rows; the as-of date is pinned to 2027-06-30 so that 2027 is a current year.
$hrKpiRows = "select k as kpi_code, 'kpi' as kind, k as kpi_name, k as short_label, 'Flow' as area, '' as definition, '' as formula, 'Fusion' as source_system, " +
             "'' as grain, '' as caveats, 'lower' as direction, 'pct' as value_format, 'M' as measure_name, ts as target_source, toUInt8(0) as needs_pay, " +
             "toUInt8(0) as is_home_tile, st as status, bk as bsc_kpi_code, toUInt16(1) as display_order, now64(3) as last_changed_at " +
             "from values('k String, ts String, st String, bk String', ('HR_TURNOVER', 'fixed', 'active', ''), " +
             "('HR_REVENUE_PER_FTE', 'bsc', 'active', 'FIN_REV_FTE'), ('HR_PARKED', 'fixed', 'parked', ''))"
function Get-HrTargets([string]$Rows) {
    $t = "select k as kpi_code, toUInt8(b) as branch_id, toUInt16(y) as year, toUInt8(m) as month, toFloat64(v) as target_value, " +
         "toFloat64(w) as watch_value, toUInt8(0) as scale_with_months, 'HR' as source_basis, toUInt8(0) as is_placeholder, now64(3) as last_changed_at " +
         "from values('k String, b UInt8, y UInt16, m UInt8, v Float64, w Float64', $Rows)"
    $sql = (Get-RenderedModel 'fact_hr_target_monthly' @{ stg_ref__hr_target = $t; stg_ref__hr_kpi = $hrKpiRows }).Replace("toDateOrNull('')", "toDateOrNull('2027-06-30')")
    return @(Invoke-ModelWithSources $sql @{})
}
function Get-HrKey([string]$Code) {
    return [int64](Invoke-HnhSelect -Dsn HNH_Gold -Sql "select toInt64(bitShiftRight(cityHash64(concat('$Code', '|')), 1)) as k")[0].k
}

Describe 'fact_hr_target_monthly' {
    $key = Get-HrKey 'HR_TURNOVER'
    $base = Get-HrTargets "('HR_TURNOVER', 0, 2026, 0, 0.06, 0.07)"
    $over = Get-HrTargets "('HR_TURNOVER', 0, 2026, 0, 0.06, 0.07), ('HR_TURNOVER', 6, 2026, 3, 0.05, 0.06)"
    $carry = Get-HrTargets "('HR_TURNOVER', 0, 2026, 0, 0.06, 0.07), ('HR_REVENUE_PER_FTE', 0, 2026, 0, 1, 2), ('HR_PARKED', 0, 2026, 0, 1, 2)"
    function Cell($rows, $b, $d) { @($rows | Where-Object { [int]$_.branch_key -eq $b -and [int]$_.month_date_key -eq $d }) }
    It 'fallback_branch0_fills_all_hospitals' {
        @($base | Where-Object { [int]$_.month_date_key -lt 20270101 }).Count | Should Be 96
        foreach ($r in @($base | Where-Object { [int]$_.month_date_key -lt 20270101 })) { [double]$r.target_value | Should Be 0.06 }
        [double](Cell $base 3 20260901)[0].watch_value | Should Be 0.07
        [int64](Cell $base 3 20260901)[0].hr_kpi_key | Should Be $key
    }
    It 'branch_month_wins' {
        [double](Cell $over 6 20260301)[0].target_value | Should Be 0.05
        [double](Cell $over 6 20260301)[0].watch_value | Should Be 0.06
        [double](Cell $over 6 20260401)[0].target_value | Should Be 0.06
        [double](Cell $over 5 20260301)[0].target_value | Should Be 0.06
        @($over | Where-Object { [double]$_.target_value -eq 0.05 }).Count | Should Be 1
    }
    It 'earlier_year_carries_forward' {
        $rows2027 = @($base | Where-Object { [int]$_.month_date_key -ge 20270101 })
        $rows2027.Count | Should Be 96
        [double](Cell $base 1 20270501)[0].target_value | Should Be 0.06
    }
    It 'bsc_sourced_kpi_has_no_target_rows' {
        @($carry | Where-Object { [int64]$_.hr_kpi_key -eq (Get-HrKey 'HR_REVENUE_PER_FTE') }).Count | Should Be 0
        @($carry | Where-Object { [int64]$_.hr_kpi_key -eq (Get-HrKey 'HR_PARKED') }).Count | Should Be 0
        @($carry | Where-Object { [int64]$_.hr_kpi_key -eq $key }).Count | Should Be 192
    }
}

Describe 'dim_hr_kpi and dim_hr_dq_issue' {
    $kpi = Invoke-ModelWithSources (Get-RenderedModel 'dim_hr_kpi' @{ stg_ref__hr_kpi = $hrKpiRows }) @{}
    $byCode = @{}; foreach ($x in $kpi) { $byCode[$x.kpi_code] = $x }
    It 'keys the KPI and links the BSC KPI with the dim_bsc_kpi hash, or -1' {
        [int64]$byCode['HR_TURNOVER'].hr_kpi_key | Should Be (Get-HrKey 'HR_TURNOVER')
        [int64]$byCode['HR_TURNOVER'].bsc_kpi_key | Should Be -1
        [int64]$byCode['HR_REVENUE_PER_FTE'].bsc_kpi_key | Should Be (Get-HrKey 'FIN_REV_FTE')
    }
    $iss = "select 'DQ_FTE_ZERO' as issue_code, 'FTE zero' as issue_name, 'Data' as area, 'Fusion' as fix_in, 'HR' as owner, 'Medium' as severity, " +
           "'Fix it' as how_to_fix, toUInt16(1) as display_order, 'active' as status, now64(3) as last_changed_at"
    $d = Invoke-ModelWithSources (Get-RenderedModel 'dim_hr_dq_issue' @{ stg_ref__hr_dq_issue = $iss }) @{}
    It 'keys the issue by its code' {
        $d.Count | Should Be 1
        [int64]$d[0].hr_dq_issue_key | Should Be (Get-HrKey 'DQ_FTE_ZERO')
        $d[0].issue_name | Should Be 'FTE zero'
    }
}
