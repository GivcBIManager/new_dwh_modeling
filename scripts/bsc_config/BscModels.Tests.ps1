# Offline checks of the balanced-scorecard staging and gold models (plan 2026-10-20-bsc-dwh-config-and-facts).
# Each model is rendered by scripts/render_model_sql.py; its default.map_bsc_* sources (and, for gold models, its
# refs) are replaced by inline rows, and the SQL runs read-only through DSN HNH_Gold. Nothing is written.
#   powershell -NoProfile -Command "Invoke-Pester -Script scripts\bsc_config\BscModels.Tests.ps1"
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

# Stub staging rows for the gold models (Task 3)
$stgKpi = "select k as kpi_code, toUInt16(n) as kpi_num, k as kpi_name, k as short_label, 'F1' as objective_code, 'Primary' as kpi_type, " +
          "'higher' as direction, 'pct' as value_format, 'line' as chart_hint, toUInt16(n) as display_order, '' as definition, " +
          "st as status, 'fixed' as target_source, 'measure' as value_source, 'revenue' as detail_page, now64(3) as last_changed_at " +
          "from values('k String, n UInt16, st String', ('FIN_NET_REVENUE', 1, 'active'), ('INT_ALOS', 23, 'active'), " +
          "('CUS_NEW_PATIENTS', 15, 'active'), ('INT_HAI_RATE', 38, 'active'), ('FIN_NET_COLLECTION', 7, 'parked'))"
$stgObjective = "select 'F1' as objective_code, 'Financial' as pillar, toUInt8(1) as pillar_order, toFloat64(0.3) as pillar_weight, " +
                "'q' as pillar_question, 'Revenue' as objective_title, 'oq' as objective_question, toUInt8(1) as objective_order, now64(3) as last_changed_at"
$stgThreshold = "select k as kpi_code, toFloat64(b) as score_base, toFloat64(0.6) as score_slope, toFloat64(85) as good_from, " +
                "toFloat64(70) as watch_from, now64(3) as last_changed_at from values('k String, b Float64', ('*', 85), ('INT_ALOS', 80))"
$stgOwner = "select 'FIN_NET_REVENUE' as kpi_code, toUInt8(0) as branch_id, 'CEO' as owner, '' as co_owners, now64(3) as last_changed_at"
$stgWeight = "select p as profile, k as kpi_code, toFloat64(w) as weight, now64(3) as last_changed_at " +
             "from values('p String, k String, w Float64', ('corporate', 'FIN_NET_REVENUE', 0.042), ('corporate', 'INT_ALOS', 0.02), " +
             "('branch:6', 'FIN_NET_REVENUE', 0.05))"
$stgTarget = "select k as kpi_code, toUInt8(b) as branch_id, toUInt16(y) as year, toUInt8(m) as month, toFloat64(v) as target_value, " +
             "toUInt8(0) as scale_with_months, 'x' as source_basis, now64(3) as last_changed_at " +
             "from values('k String, b UInt8, y UInt16, m UInt8, v Float64', ('CUS_NEW_PATIENTS', 6, 2026, 0, 0.7), " +
             "('CUS_NEW_PATIENTS', 1, 2026, 0, 0.3), ('INT_ALOS', 0, 2027, 0, 4), ('INT_ALOS', 0, 2027, 3, 3.5))"

Describe 'dim_bsc_kpi' {
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'dim_bsc_kpi' @{ stg_ref__bsc_kpi = $stgKpi; stg_ref__bsc_objective = $stgObjective;
        stg_ref__bsc_threshold = $stgThreshold; stg_ref__bsc_owner = $stgOwner; stg_ref__bsc_weight = $stgWeight }) @{}
    $k = @{}; foreach ($r in $rows) { $k[$r.kpi_code] = $r }
    It 'has one row per KPI with its pillar' {
        $rows.Count | Should Be 5
        $k['FIN_NET_REVENUE'].pillar | Should Be 'Financial'
    }
    It 'takes a KPI threshold row before the default' {
        [double]$k['INT_ALOS'].score_base | Should Be 80
        [double]$k['FIN_NET_REVENUE'].score_base | Should Be 85
    }
    It 'carries the Corporate owner, the corporate weight and the active flag' {
        $k['FIN_NET_REVENUE'].owner | Should Be 'CEO'
        [double]$k['FIN_NET_REVENUE'].corporate_weight | Should Be 0.042
        [double]$k['INT_HAI_RATE'].corporate_weight | Should Be 0
        [int]$k['FIN_NET_COLLECTION'].is_active | Should Be 0
    }
    It 'keys the KPI like hnh_surrogate_key' {
        $expected = (Invoke-HnhSelect -Dsn HNH_Gold -Sql "select toInt64(bitShiftRight(cityHash64(concat('FIN_NET_REVENUE', '|')), 1)) as k")[0].k
        [int64]$k['FIN_NET_REVENUE'].bsc_kpi_key | Should Be ([int64]$expected)
    }
}

Describe 'fact_bsc_target_monthly' {
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'fact_bsc_target_monthly' @{ stg_ref__bsc_target = $stgTarget }) @{}
    $key = (Invoke-HnhSelect -Dsn HNH_Gold -Sql "select toInt64(bitShiftRight(cityHash64(concat('INT_ALOS', '|')), 1)) as k")[0].k
    $np = (Invoke-HnhSelect -Dsn HNH_Gold -Sql "select toInt64(bitShiftRight(cityHash64(concat('CUS_NEW_PATIENTS', '|')), 1)) as k")[0].k
    function T($k, $b, $d) { @($rows | Where-Object { [int64]$_.bsc_kpi_key -eq [int64]$k -and [int]$_.branch_key -eq $b -and [int]$_.month_date_key -eq $d }) }
    It 'uses a branch row for that branch only' {
        [double](T $np 6 20260301)[0].target_value | Should Be 0.7
        [double](T $np 1 20260301)[0].target_value | Should Be 0.3
        @(T $np 2 20260301).Count | Should Be 0
    }
    It 'repeats an annual target on every month and lets a monthly row replace one month' {
        [double](T $key 2 20270201)[0].target_value | Should Be 4
        [double](T $key 2 20270301)[0].target_value | Should Be 3.5
        @($rows | Where-Object { [int64]$_.bsc_kpi_key -eq [int64]$key -and [int]$_.branch_key -eq 2 }).Count | Should Be 12
        @($rows | Where-Object { [int64]$_.bsc_kpi_key -eq [int64]$key }).Count | Should Be 96
    }
}

Describe 'fact_bsc_weight' {
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'fact_bsc_weight' @{ stg_ref__bsc_kpi = $stgKpi; stg_ref__bsc_weight = $stgWeight }) @{}
    $fin = (Invoke-HnhSelect -Dsn HNH_Gold -Sql "select toInt64(bitShiftRight(cityHash64(concat('FIN_NET_REVENUE', '|')), 1)) as k")[0].k
    $alos = (Invoke-HnhSelect -Dsn HNH_Gold -Sql "select toInt64(bitShiftRight(cityHash64(concat('INT_ALOS', '|')), 1)) as k")[0].k
    function W($k, $b) { [double](@($rows | Where-Object { [int64]$_.bsc_kpi_key -eq [int64]$k -and [int]$_.branch_key -eq $b })[0].weight) }
    It 'covers every active KPI on every hospital' {
        $rows.Count | Should Be 32
    }
    It 'uses the branch profile where the branch has one, 0 for a KPI it leaves out' {
        W $fin 6 | Should Be 0.05
        W $alos 6 | Should Be 0
    }
    It 'falls back to the corporate profile for a branch without a profile' {
        W $fin 1 | Should Be 0.042
        W $alos 1 | Should Be 0.02
    }
}

Describe 'dim_branch (scorecard columns)' {
    $cat = "select toUInt8(b) as branch_id, c as category, now64(3) as last_changed_at " +
           "from values('b UInt8, c String', (6, 'Ramp-Up & Prove'), (1, 'Scale & Optimize'))"
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'hnh_dim_branch' @{ stg_ref__bsc_hospital_category = $cat }) @{}
    $b = @{}; foreach ($r in $rows) { $b[[int]$r.branch_key] = $r }
    It 'carries the scorecard category and the hospital flag' {
        $b[6].bsc_category | Should Be 'Ramp-Up & Prove'
        [int]$b[6].is_hospital | Should Be 1
        $b[2].bsc_category | Should Be 'None'
        $b[100].bsc_category | Should Be 'None'
        [int]$b[100].is_hospital | Should Be 0
        [int]$b[0].is_hospital | Should Be 0
    }
}
