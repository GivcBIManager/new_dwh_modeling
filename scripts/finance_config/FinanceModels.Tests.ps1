# Offline checks of the finance config staging models (plan 2026-11-18-finance-report, task 1).
# Each model is rendered by scripts/render_model_sql.py; its default.map_finance_* source is replaced by inline rows,
# and the SQL runs read-only through DSN HNH_Gold. Nothing is written.
#   powershell -NoProfile -Command "Invoke-Pester -Script scripts\finance_config\FinanceModels.Tests.ps1"
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

Describe 'stg_ref__finance_budget' {
    $src = "select toUInt8(b) as branch_id, toUInt16(y) as year, toUInt8(m) as month, st as statement, lc as line_code, a as amount, $cl, toUInt8(d) as is_deleted " +
           "from values('b UInt8, y UInt16, m UInt8, st String, lc String, a Float64, s UInt32, d UInt8', " +
           "(1, 2026, 1, 'IS', 'DC_EMPLOYEE', 100, 30, 0), (1, 2026, 1, 'IS', 'DC_EMPLOYEE', 110, 20, 0), (1, 2026, 1, 'IS', 'DC_EMPLOYEE', 120, 10, 1), " +
           "(1, 2026, 1, 'IS', 'DC_OTHER', 5, 20, 0), (1, 2026, 1, 'IS', 'DC_OTHER', 7, 10, 0), " +
           "(2, 2026, 2, ' is ', ' DC_SPACE ', 9, 10, 0))"
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'stg_ref__finance_budget') @{ map_finance_budget = $src }
    $k = @{}; foreach ($r in $rows) { $k[$r.line_code] = $r }
    It 'keeps the latest row per key and drops a deleted key' {
        $rows.Count | Should Be 2
        $k.ContainsKey('DC_EMPLOYEE') | Should Be $false
        [double]$k['DC_OTHER'].amount | Should Be 7
    }
    It 'upper-cases statement and trims line_code' {
        $k['DC_SPACE'].statement | Should Be 'IS'
        $k.ContainsKey(' DC_SPACE ') | Should Be $false
    }
}

Describe 'stg_ref__finance_target' {
    $src = "select k as kpi_code, toUInt8(0) as branch_id, toUInt16(2026) as year, toFloat64(1) as target_value, toFloat64(w) as watch_pct, $cl, toUInt8(0) as is_deleted " +
           "from values('k String, w Float64, s UInt32', ('FIN_A', 0, 10), ('FIN_B', 0.1, 10))"
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'stg_ref__finance_target') @{ map_finance_target = $src }
    $k = @{}; foreach ($r in $rows) { $k[$r.kpi_code] = $r }
    It 'defaults watch_pct 0 to 0.05' {
        [double]$k['FIN_A'].watch_pct | Should Be 0.05
        [double]$k['FIN_B'].watch_pct | Should Be 0.1
    }
}
