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

# fact_pl_report_monthly (task 3): account_name on the Oasis and Fusion rows. Branch 3: Oasis row from fact_gl_fs_monthly
# (name already title-cased there, '' not possible: the model falls back to the code), Fusion from 2026-07.
Describe 'fact_pl_report_monthly account_name' {
    $plFsm = "select toUInt8(3) as branch_key, toDate('2026-06-01') as month_start, 'oasis' as source_system, c as account_code, n as account_name, " +
             "'is' as fs_type, 'revenue' as fs_category, 'revenue cash' as fs_caption, 'revenue cash' as fs_line, toFloat64(-100) as movement " +
             "from values('c String, n String', ('41101', 'Revenue Cash'))"
    $plAcct = "select toInt64(a) as gl_account_key, toUInt32(nat) as natural_account, nn as natural_account_name, toInt64(1) as fs_line_key, " +
              "cast(null as Nullable(String)) as specialty_name, cast(null as Nullable(String)) as service_location_name, cast(null as Nullable(String)) as service_group_name " +
              "from values('a Int64, nat UInt32, nn Nullable(String)', (11, 4100, 'AUDIT FEES'), (12, 4200, ''), (13, 4300, 'CTAS Level 2'))"
    $plBal = "select toUInt8(3) as branch_key, toInt32(202608) as period_key, toInt64(a) as gl_account_key, 'including_unposted' as balance_view, " +
             "toFloat64(px) as period_movement_excl_opening from values('a Int64, px Float64', (11, 60), (12, 4), (13, 7))"
    $plFs = "select toInt64(1) as fs_line_key, 'IS' as fs_type, 'Revenue' as fs_category, 'Revenue Cash' as fs_caption, 'Revenue Cash' as fs_line"
    $plRule = "select '' as source_system, 'revenue' as fs_category, '' as fs_caption, '' as fs_line, 'REV_CASH' as pl_line_code, toUInt8(0) as score"
    $plLine = "select toUInt16(100) as pl_line_key, 'REV_CASH' as pl_line_code, 'Revenue' as section_name, 'detail' as line_kind, cast([] as Array(String)) as subtotal_sections " +
              "union all select toUInt16(199), 'REV_TOTAL', 'Revenue', 'subtotal', ['Revenue']"
    $rep = @{ fact_gl_fs_monthly = $plFsm; stg_ref__gl_cutover = $glCutover; fact_gl_balance_monthly = $plBal; hnh_dim_gl_period = $glPeriod
              hnh_dim_gl_account = $plAcct; dim_fs_line = $plFs; pl_report_line_rule = $plRule; dim_pl_report_line = $plLine }
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'fact_pl_report_monthly' $rep) @{}
    $k = @{}; foreach ($r in $rows) { $k["$($r.source_system)|$($r.pl_line_code)|$($r.account_code)"] = $r }
    It 'carries account_name for Oasis and Fusion rows' {
        $k['oasis|REV_CASH|41101'].account_name | Should Be 'Revenue Cash'
        $k['fusion|REV_CASH|4100'].account_name | Should Be 'Audit Fees'
        $k['fusion|REV_CASH|4300'].account_name | Should Be 'CTAS Level 2'
    }
    It 'falls back to the code and leaves subtotal rows blank' {
        $k['fusion|REV_CASH|4200'].account_name | Should Be '4200'
        $k['fusion|REV_TOTAL|'].account_name | Should Be ''
    }
    It 'keeps the amounts' {
        [double]$k['fusion|REV_CASH|4100'].amount | Should Be -60
        [double]$k['fusion|REV_TOTAL|'].amount | Should Be -71
    }
}

# dim_pl_report_line budget link (task 4). The model and dim_budget_line are rendered as they are (no refs); the sign
# check reads gold read-only for branch 3, 2026 Jan-Sep: sign(budget * budget_sign) = sign(P&L amount).
Describe 'dim_pl_report_line budget link' {
    $lines = Invoke-ModelWithSources (Get-RenderedModel 'dim_pl_report_line') @{}
    $budget = Invoke-ModelWithSources (Get-RenderedModel 'dim_budget_line') @{}
    $byCode = @{}; foreach ($l in $lines) { $byCode[$l.pl_line_code] = $l }
    It 'links every non-subtotal budget line once or lists it as unlinked' {
        $skip = 'REV_OP', 'REV_IP', 'REV_ER', 'REV_UNALLOCATED', 'DIS_REJECTION_INS', 'DIS_REJECTION_MOH', 'UNBUDGETED'
        $bad = @()
        foreach ($b in $budget | Where-Object { [int]$_.is_subtotal -eq 0 -and $skip -notcontains $_.budget_line_code }) {
            $n = @($lines | Where-Object { $_.budget_line_code -eq $b.budget_line_code }).Count
            if ($n -ne 1) { $bad += "$($b.budget_line_code)=$n" }
        }
        $bad -join ',' | Should Be ''
    }
    It 'only links codes that exist in dim_budget_line, with a sign' {
        $codes = @($budget | ForEach-Object { $_.budget_line_code })
        $bad = @($lines | Where-Object { ($_.budget_line_code -ne '' -and $codes -notcontains $_.budget_line_code) -or
            ($_.budget_line_code -eq '' -and [int]$_.budget_sign -ne 0) -or ($_.budget_line_code -ne '' -and [math]::Abs([int]$_.budget_sign) -ne 1) })
        $bad.Count | Should Be 0
    }
    It 'gives budget and actual the same sign' {
        $bud = @{}; foreach ($r in (Invoke-HnhSelect -Dsn HNH_Gold -Sql "select budget_line_code, sum(budget_most_likely) as v from gold.fact_income_statement_monthly where branch_key = 3 and month_start between '2026-01-01' and '2026-09-01' group by 1")) { $bud[$r.budget_line_code] = [double]$r.v }
        $act = @{}; foreach ($r in (Invoke-HnhSelect -Dsn HNH_Gold -Sql "select d.pl_line_code as c, sum(f.amount) as v from gold.fact_pl_report_monthly as f inner join gold.dim_pl_report_line as d on d.pl_line_key = f.pl_line_key where f.branch_key = 3 and f.month_start between '2026-01-01' and '2026-09-01' group by 1")) { $act[$r.c] = [double]$r.v }
        $bad = @()
        foreach ($c in 'NET_REVENUE', 'DIRECT_COST', 'GROSS_PROFIT', 'EBITDA', 'DC_EMPLOYEE', 'NET_PROFIT') {
            $l = $byCode[$c]
            $b = $bud[$l.budget_line_code] * [int]$l.budget_sign
            if ([math]::Sign($b) -ne [math]::Sign($act[$c])) { $bad += "$c budget=$b actual=$($act[$c])" }
        }
        $bad -join ';' | Should Be ''
    }
}

# fact_finance_budget_monthly (task 5). dim_pl_report_line is rendered as it is; fact_income_statement_monthly and
# stg_ref__finance_budget are inline rows. Branch 1, 2026-01: budget DC_EMPLOYEE 100, TOTAL_DC 100, REV_NET 1000, GROSS_PROFIT 900,
# GA_OTHER 25, GA_MARKETING 10, GA_HO_CHARGES 5, TOTAL_GA 40, EBITDA 860, NET_PROFIT 860. Branch 2 has no budget. Branch 7 has none.
Describe 'fact_finance_budget_monthly' {
    $fim = "select toUInt8(b) as branch_key, toDate('2026-01-01') as month_start, c as budget_line_code, toFloat64(a) as budget_most_likely " +
           "from values('b UInt8, c String, a Float64', " +
           "(1, 'DC_EMPLOYEE', 100), (1, 'TOTAL_DC', 100), (1, 'REV_NET', 1000), (1, 'GROSS_PROFIT', 900), (1, 'GA_OTHER', 25), (1, 'GA_MARKETING', 10), " +
           "(1, 'GA_HO_CHARGES', 5), (1, 'TOTAL_GA', 40), (1, 'EBITDA', 860), (1, 'NET_PROFIT', 860), (2, 'DC_EMPLOYEE', 0))"
    $stg = "select toUInt8(b) as branch_id, toUInt16(2026) as year, toUInt8(1) as month, st as statement, lc as line_code, toFloat64(a) as amount, now() as last_changed_at " +
           "from values('b UInt8, st String, lc String, a Float64', " +
           "(1, 'IS', 'DC_EMPLOYEE', 120), (1, 'IS', 'EBITDA', 9999), (1, 'IS', 'REV_CASH', 50), (1, 'BS', 'cash', 500), (7, 'IS', 'REV_CASH', 50), (7, 'IS', 'DC_EMPLOYEE', 30))"
    $rep = @{ fact_income_statement_monthly = $fim; stg_ref__finance_budget = $stg; dim_pl_report_line = (Get-RenderedModel 'dim_pl_report_line') }
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'fact_finance_budget_monthly' $rep) @{}
    $k = @{}; foreach ($r in $rows) { $k["$($r.branch_key)|$($r.statement)|$($r.pl_line_code)$($r.bs_caption)"] = $r }
    It 'signs linked lines by budget_sign' {
        [double]$k['1|IS|GA_OTHER'].amount | Should Be -25
        [double]$k['1|IS|SM'].amount | Should Be -10
        [double]$k['1|IS|NET_REVENUE'].amount | Should Be 1000
        $k['1|IS|NET_REVENUE'].source | Should Be 'budget'
        $k['1|IS|GROSS_PROFIT'].pl_line_key | Should Be 699
    }
    It 'replaces a line by its override and moves EBITDA and NET_PROFIT by the difference' {
        [double]$k['1|IS|DC_EMPLOYEE'].amount | Should Be -120
        $k['1|IS|DC_EMPLOYEE'].source | Should Be 'override'
        [double]$k['1|IS|DIRECT_COST'].amount | Should Be -120
        [double]$k['1|IS|GROSS_PROFIT'].amount | Should Be 880
        [double]$k['1|IS|EBITDA'].amount | Should Be 840
        [double]$k['1|IS|NET_PROFIT'].amount | Should Be 840
        $k['1|IS|EBITDA'].source | Should Be 'override'
    }
    It 'builds subtotals from overrides for a hospital without budget' {
        [double]$k['7|IS|REV_CASH'].amount | Should Be 50
        [double]$k['7|IS|DC_EMPLOYEE'].amount | Should Be -30
        [double]$k['7|IS|NET_REVENUE'].amount | Should Be 50
        [double]$k['7|IS|EBITDA'].amount | Should Be 20
        $k['7|IS|EBITDA'].source | Should Be 'rollup'
    }
    It 'ignores a subtotal override and gives a branch-month without budget no rows' {
        @($rows | Where-Object { $_.branch_key -eq 2 }).Count | Should Be 0
        [double]$k['1|IS|EBITDA'].amount | Should Not Be 9999
    }
    It 'keeps BS overrides as entered' {
        $r = $k['1|BS|cash']
        [double]$r.amount | Should Be 500
        [int]$r.pl_line_key | Should Be 0
        $r.pl_line_code | Should Be ''
        $r.bs_caption | Should Be 'cash'
        [int64]$r.month_date_key | Should Be 20260101
    }
    It 'leaves a linked subtotal alone for an unlinked override and rolls up the unlinked subtotal' {
        [double]$k['1|IS|REV_CASH'].amount | Should Be 50
        [double]$k['1|IS|NET_REVENUE'].amount | Should Be 1000
        $k['1|IS|NET_REVENUE'].source | Should Be 'budget'
        [double]$k['1|IS|REV_TOTAL'].amount | Should Be 50
        $k['1|IS|REV_TOTAL'].source | Should Be 'rollup'
    }
    It 'gives GA_TOTAL the budget less marketing and head office charges' {
        [double]$k['1|IS|GA_TOTAL'].amount | Should Be -25
    }
}

# Task 5 sign check (read-only gold, branch 3, 2026 Jan-Sep): for every linked line sign(budget * budget_sign) = sign(P&L amount)
# wherever both are non-zero. GA_TOTAL budget = TOTAL_GA - GA_MARKETING - GA_HO_CHARGES.
Describe 'budget_sign against the P&L on gold' {
    $lines = Invoke-ModelWithSources (Get-RenderedModel 'dim_pl_report_line') @{}
    $bud = @{}; foreach ($r in (Invoke-HnhSelect -Dsn HNH_Gold -Sql "select budget_line_code, sum(budget_most_likely) as v from gold.fact_income_statement_monthly where branch_key = 3 and month_start between '2026-01-01' and '2026-09-01' group by 1")) { $bud[$r.budget_line_code] = [double]$r.v }
    $bud['GA_TOTAL'] = $bud['TOTAL_GA'] - $bud['GA_MARKETING'] - $bud['GA_HO_CHARGES']
    $act = @{}; foreach ($r in (Invoke-HnhSelect -Dsn HNH_Gold -Sql "select d.pl_line_code as c, sum(f.amount) as v from gold.fact_pl_report_monthly as f inner join gold.dim_pl_report_line as d on d.pl_line_key = f.pl_line_key where f.branch_key = 3 and f.month_start between '2026-01-01' and '2026-09-01' group by 1")) { $act[$r.c] = [double]$r.v }
    It 'agrees for every linked line' {
        $bad = @()
        foreach ($l in $lines | Where-Object { $_.budget_line_code -ne '' }) {
            $key = if ($l.pl_line_code -eq 'GA_TOTAL') { 'GA_TOTAL' } else { $l.budget_line_code }
            $b = [double]$bud[$key] * [int]$l.budget_sign; $a = [double]$act[$l.pl_line_code]
            if ($b -ne 0 -and $a -ne 0 -and [math]::Sign($b) -ne [math]::Sign($a)) { $bad += "$($l.pl_line_code) budget=$b actual=$a" }
        }
        $bad -join ';' | Should Be ''
    }
}
