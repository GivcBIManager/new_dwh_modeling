# Offline checks of the balanced-scorecard staging and gold models (plan 2026-10-20-bsc-dwh-config-and-facts).
# Each model is rendered by scripts/render_model_sql.py; its default.map_bsc_* sources (and, for gold models, its
# refs) are replaced by inline rows, and the SQL runs read-only through DSN HNH_Gold. Nothing is written.
#   powershell -NoProfile -Command "Invoke-Pester -Script scripts\bsc_config\BscModels.Tests.ps1"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent (Split-Path -Parent $here)
Import-Module (Join-Path $root 'scripts\HnhCh.psm1') -Force

function Get-RenderedModel([string]$Model, [hashtable]$Replace = @{}) {
    $args = @((Join-Path $root 'scripts\render_model_sql.py'), $Model)
    foreach ($k in $Replace.Keys) { $args += @('--replace', "$k=$($Replace[$k])") }
    $sql = (& python @args) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "render failed: $Model" }
    return $sql
}

function Invoke-ModelWithSources([string]$Sql, [hashtable]$Sources) {
    $Sql = $Sql -replace '(?m)^\s*--.*$', ''
    foreach ($table in $Sources.Keys) { $Sql = $Sql.Replace("default.$table", "($($Sources[$table]))") }
    return @(Invoke-HnhSelect -Dsn HNH_Gold -Sql "select * from ($Sql) order by 1, 2")
}

$cl = "now64(3) - toIntervalSecond(s) as changed_at, 'test' as changed_by, '' as change_note"

Describe 'stg_ref__bsc_target' {
    $src = "select k as kpi_code, toUInt8(b) as branch_id, toUInt16(y) as year, toUInt8(m) as month, v as target_value, " +
           "toUInt8(0) as scale_with_months, '' as source_basis, $cl, toUInt8(d) as is_deleted " +
           "from values('k String, b UInt8, y UInt16, m UInt8, v Float64, s UInt32, d UInt8', " +
           "('FIN_DAYS_IN_AR', 0, 2027, 0, 180, 30, 0), ('FIN_DAYS_IN_AR', 0, 2027, 0, 170, 20, 0), ('FIN_DAYS_IN_AR', 0, 2027, 0, 160, 10, 1), " +
           "('INT_ALOS', 0, 2026, 0, 4, 20, 0), ('INT_ALOS', 0, 2026, 0, 3.8, 10, 0))"
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'stg_ref__bsc_target') @{ map_bsc_target = $src }
    It 'keeps only the latest row of each key and drops a deleted key' {
        $rows.Count | Should Be 1
        $rows[0].kpi_code | Should Be 'INT_ALOS'
        [double]$rows[0].target_value | Should Be 3.8
    }
}

Describe 'stg_ref__bsc_kpi' {
    $src = "select k as kpi_code, toUInt16(1) as kpi_num, ' Net revenue ' as kpi_name, 'x' as short_label, 'F1' as objective_code, " +
           "'Primary' as kpi_type, 'higher' as direction, 'sar' as value_format, 'line' as chart_hint, toUInt16(1) as display_order, " +
           "'' as definition, st as status, 'budget' as target_source, 'measure' as value_source, 'revenue' as detail_page, $cl, toUInt8(0) as is_deleted " +
           "from values('k String, st String, s UInt32', ('FIN_NET_REVENUE', 'active', 20), ('FIN_NET_REVENUE', 'parked', 10))"
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'stg_ref__bsc_kpi') @{ map_bsc_kpi = $src }
    It 'takes the latest status and trims text' {
        $rows.Count | Should Be 1
        $rows[0].status | Should Be 'parked'
        $rows[0].kpi_name | Should Be 'Net revenue'
    }
}
