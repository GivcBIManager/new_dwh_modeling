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

# fact_gl_fs_monthly (task 2): debit, credit and account name. Branch 3: Oasis in 2025-06, Fusion from 2026-07
# (scripts/fixtures/gl_cutover_stub.sql). Every ref is replaced by inline rows.
$glCutover = Get-Content (Join-Path $root 'scripts\fixtures\gl_cutover_stub.sql') -Raw
$glLine = "select toUInt8(3) as branch_key, toInt64(k) as oasis_gl_account_key, toDate('2025-06-01') as month_start, toUInt8(p) as is_posted, " +
          "toUInt8(bf) as is_brought_forward, toFloat64(dr - cr) as amount, toFloat64(dr) as debit, toFloat64(cr) as credit " +
          "from values('k Int64, p UInt8, bf UInt8, dr Float64, cr Float64', " +
          "(1, 1, 0, 100, 0), (1, 1, 0, 0, 30), (1, 1, 1, 500, 0), (1, 0, 0, 7, 0), (2, 1, 0, 5, 0))"
$glOasisAccount = "select toInt64(k) as oasis_gl_account_key, toUInt8(3) as branch_key, c as account_code, 'income' as fs_type, 'revenue' as fs_element, " +
                  "'' as fs_category, '' as fs_caption, '' as fs_line, n as account_name " +
                  "from values('k Int64, c String, n Nullable(String)', (1, '1100001', 'CASH AT BANK'), (2, '1100002', ''))"
$glBalance = "select toUInt8(3) as branch_key, toInt32(pk) as period_key, toInt64(a) as gl_account_key, 'including_unposted' as balance_view, " +
             "toFloat64(0) as opening_balance, toFloat64(pm) as period_movement, toFloat64(px) as period_movement_excl_opening " +
             "from values('pk Int32, a Int64, pm Float64, px Float64', (202608, 11, 1060, 60), (202608, 12, 4, 4))"
$glPeriod = "select toInt32(202608) as period_key, toDate('2026-08-01') as month_start, toUInt8(0) as is_adjustment"
$glAccount = "select toInt64(a) as gl_account_key, toUInt32(nat) as natural_account, nn as natural_account_name, toInt64(1) as fs_line_key " +
             "from values('a Int64, nat UInt32, nn Nullable(String)', (11, 4100, 'Mixed Case Name'), (12, 4200, ''))"
$glFsLine = "select toInt64(1) as fs_line_key, 'INCOME' as fs_type, 'REVENUE' as fs_element, '' as fs_category, '' as fs_caption, '' as fs_line"
$glJournal = "select toUInt8(3) as branch_key, toInt64(a) as gl_account_key, toInt32(202608) as period_key, toFloat64(amt) as amount, " +
             "toUInt8(op) as is_opening_balance_journal, toUInt8(p) as is_posted " +
             "from values('a Int64, amt Float64, op UInt8, p UInt8', (11, 80, 0, 1), (11, -20, 0, 0), (11, 1000, 1, 1), (12, 4, 0, 1))"

Describe 'fact_gl_fs_monthly debit and credit' {
    $rep = @{ stg_ref__gl_cutover = $glCutover; stg_bsc__oasis_gl_line = $glLine; stg_bsc__oasis_gl_account = $glOasisAccount
              fact_gl_balance_monthly = $glBalance; hnh_dim_gl_period = $glPeriod; hnh_dim_gl_account = $glAccount
              dim_fs_line = $glFsLine; hnh_fact_gl_journal_line = $glJournal }
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'fact_gl_fs_monthly' $rep) @{}
    $k = @{}; foreach ($r in $rows) { $k[$r.account_code] = $r }
    It 'splits Oasis movement into debit and credit without brought-forward lines' {
        [double]$k['1100001'].debit | Should Be 100
        [double]$k['1100001'].credit | Should Be 30
        [double]$k['1100001'].movement | Should Be 70
        [double]$k['1100001'].opening_journal_amount | Should Be 500
    }
    It 'takes Fusion debit and credit from journal lines without opening-balance journals' {
        $k['4100'].source_system | Should Be 'fusion'
        [double]$k['4100'].debit | Should Be 80
        [double]$k['4100'].credit | Should Be 20
        [double]$k['4100'].movement | Should Be 60
    }
    It 'title-cases account_name and falls back to the code' {
        $k['1100001'].account_name | Should Be 'Cash At Bank'
        $k['1100002'].account_name | Should Be '1100002'
        $k['4100'].account_name | Should Be 'Mixed Case Name'
        $k['4200'].account_name | Should Be '4200'
    }
}
