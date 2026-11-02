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
