# Offline checks of the finance config staging models (plan 2026-11-18-finance-report, task 1).
# Each model is rendered by scripts/render_model_sql.py; its default.map_finance_* source is replaced by inline rows,
# and the SQL runs read-only through DSN HNH_Gold. Nothing is written.
#   powershell -NoProfile -Command "Invoke-Pester -Script scripts\finance_config\FinanceModels.Tests.ps1"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent (Split-Path -Parent $here)
Import-Module (Join-Path $root 'scripts\HnhCh.psm1') -Force

# $Replace maps a ref'd model to inline SQL, written to a temp file for --replace.
function Get-RenderedModel([string]$Model, [hashtable]$Replace = @{}, [string]$Wrap = 'select * from ({model}) order by 1, 2') {
    $pyArgs = @((Join-Path $root 'scripts\render_model_sql.py'), $Model)
    foreach ($k in $Replace.Keys) {
        $f = [IO.Path]::GetTempFileName()
        [IO.File]::WriteAllText($f, $Replace[$k])
        $pyArgs += @('--replace', "$k=$f")
    }
    $pyArgs += @('--wrap', $Wrap)
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

# Task 6: finance KPI list, report columns, targets, year pick and the SSAS display columns.
# A plain macro call (macros/hnh/hnh_finance.sql) is expanded by scripts/render_model_sql.py for the SSAS view checks:
# the views themselves need the dbt adapter, so their expressions are checked through the macros they call.
function Get-MacroSql([string]$Call) {
    $code = "import sys; sys.path.insert(0, sys.argv[1]); import render_model_sql as r; sys.stdout.write(r.render_macro(sys.argv[2]))"
    $sql = (& python -c $code (Join-Path $root 'scripts') $Call) -join "`n"
    if ($LASTEXITCODE -ne 0 -or -not $sql) { throw "macro not rendered: $Call" }
    return $sql
}

Describe 'dim_date year_pick' {
    $hijri = "select toDate('2000-01-01') as date_day, toInt32(1) as hijri_year, toInt32(1) as hijri_month, toInt32(1) as hijri_day, 'x' as hijri_month_name"
    $holiday = "select toDate('2000-01-01') as date_day, 'x' as holiday_name"
    $wrap = 'select toYear(date_day) as y, uniqExact(year_pick) as n, any(year_pick) as pick from ({model}) group by y order by y'
    $rows = Invoke-HnhSelect -Dsn HNH_Gold -Sql ((Get-RenderedModel 'dim_date' @{ stg_ref__hijri_calendar = $hijri; stg_ref__public_holiday = $holiday } $wrap) -replace '(?m)^\s*--.*$', '')
    $ly = Invoke-HnhSelect -Dsn HNH_Gold -Sql 'select toYear(addMonths(toStartOfMonth(today()), -1)) as y'
    $lastClosedYear = [int]$ly[0].y
    It 'year_pick labels the last closed month''s year Current year' {
        @($rows | Where-Object { $_.pick -eq 'Current year' }).Count | Should Be 1
        [int]($rows | Where-Object { $_.pick -eq 'Current year' }).y | Should Be $lastClosedYear
    }
    It 'labels every other year with its number, one label per year' {
        foreach ($r in $rows) {
            [int]$r.n | Should Be 1
            if ([int]$r.y -ne $lastClosedYear) { $r.pick | Should Be ([string]$r.y) }
        }
    }
}

Describe 'gl_fs balance sheet grouping (ssas_fact_gl_fs_monthly)' {
    $vals = "('bs','assets','current assets','cash and bank balances'), ('bs','assets','non current assets','ppe cost'), " +
            "('bs','liabilities','current liabilities','trade payables'), ('bs','liabilities','non current liabilities','long term loans'), " +
            "('bs','equity','equity','retained earnings'), ('is','expenses','direct cost','employee costs'), ('is','revenue','revenue','revenue cash'), " +
            "('bs','assets','not mapped','not mapped'), ('bs','liabilities','not mapped','not mapped'), ('bs','not mapped','not mapped','not mapped')"
    $a3 = "'t.fs_type','t.fs_element','t.fs_category'"
    $sql = "select t.fs_type as fs_type, t.fs_element as fs_element, t.fs_category as fs_category, t.fs_caption as fs_caption, " +
           (Get-MacroSql "hnh_bs_side($a3)") + " as bs_side, " + (Get-MacroSql "hnh_bs_element($a3)") + " as bs_element, " +
           (Get-MacroSql "hnh_bs_category($a3)") + " as bs_category, " + (Get-MacroSql "hnh_bs_caption($a3,'t.fs_caption')") + " as bs_caption, " +
           (Get-MacroSql "hnh_bs_display_sign($a3)") + " as display_sign, " + (Get-MacroSql "hnh_bs_element_order($a3)") + " as eo, " +
           (Get-MacroSql "hnh_bs_category_order($a3)") + " as co " +
           "from values('fs_type String, fs_element String, fs_category String, fs_caption String', $vals) as t"
    $rows = Invoke-HnhSelect -Dsn HNH_Gold -Sql $sql
    $by = @{}; foreach ($r in $rows) { $by["$($r.fs_type)|$($r.fs_element)|$($r.fs_category)|$($r.fs_caption)"] = $r }
    It 'maps IS rows to Equity / Current year profit' {
        foreach ($k in 'is|expenses|direct cost|employee costs', 'is|revenue|revenue|revenue cash') {
            $r = $by[$k]
            $r.bs_side | Should Be 'Liabilities & equity'
            $r.bs_element | Should Be 'Equity'
            $r.bs_category | Should Be 'Equity'
            $r.bs_caption | Should Be 'Current year profit'
            [int]$r.display_sign | Should Be -1
        }
    }
    It 'puts assets on one side and liabilities and equity on the other, title-cased' {
        $a = $by['bs|assets|current assets|cash and bank balances']
        $a.bs_side | Should Be 'Assets'; $a.bs_element | Should Be 'Assets'; $a.bs_category | Should Be 'Current Assets'
        $a.bs_caption | Should Be 'Cash And Bank Balances'; [int]$a.display_sign | Should Be 1
        $l = $by['bs|liabilities|non current liabilities|long term loans']
        $l.bs_side | Should Be 'Liabilities & equity'; $l.bs_element | Should Be 'Liabilities'; $l.bs_category | Should Be 'Non Current Liabilities'
        [int]$l.display_sign | Should Be -1
        $e = $by['bs|equity|equity|retained earnings']
        $e.bs_side | Should Be 'Liabilities & equity'; $e.bs_element | Should Be 'Equity'; $e.bs_category | Should Be 'Equity'
    }
    It 'labels fs_type_name Balance sheet and Income statement' {
        $r = Invoke-HnhSelect -Dsn HNH_Gold -Sql ("select t.fs_type as k, " + (Get-MacroSql "hnh_fs_type_label('t.fs_type')") + " as v from values('fs_type String', ('bs'), ('is'), ('other')) as t order by k")
        $m = @{}; foreach ($x in $r) { $m[$x.k] = $x.v }
        $m['bs'] | Should Be 'Balance sheet'; $m['is'] | Should Be 'Income statement'; $m['other'] | Should Be 'other'
    }
    It 'orders elements and categories, one order per label' {
        [int]$by['bs|assets|current assets|cash and bank balances'].eo | Should Be 1
        [int]$by['bs|liabilities|current liabilities|trade payables'].eo | Should Be 2
        [int]$by['bs|equity|equity|retained earnings'].eo | Should Be 3
        foreach ($g in ($rows | Group-Object bs_element)) { @($g.Group | Select-Object -ExpandProperty eo -Unique).Count | Should Be 1 }
        foreach ($g in ($rows | Group-Object bs_category)) { @($g.Group | Select-Object -ExpandProperty co -Unique).Count | Should Be 1 }
        $c = @{}; foreach ($r in $rows) { $c[$r.bs_category] = [int]$r.co }
        ($c['Current Assets'] -lt $c['Non Current Assets'] -and $c['Non Current Assets'] -lt $c['Current Liabilities'] -and
         $c['Current Liabilities'] -lt $c['Non Current Liabilities'] -and $c['Non Current Liabilities'] -lt $c['Equity']) | Should Be $true
    }
    It 'shows unmapped balance sheet rows as Not mapped on every level' {
        foreach ($k in 'bs|assets|not mapped|not mapped', 'bs|liabilities|not mapped|not mapped', 'bs|not mapped|not mapped|not mapped') {
            $r = $by[$k]
            $r.bs_side | Should Be 'Not mapped'; $r.bs_element | Should Be 'Not mapped'
            $r.bs_category | Should Be 'Not mapped'; $r.bs_caption | Should Be 'Not mapped'
        }
    }
}

Describe 'dim_finance_kpi' {
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'dim_finance_kpi') @{}
    It 'lists 27 KPIs with six cards F1..F6' {
        $rows.Count | Should Be 27
        @($rows | Select-Object -ExpandProperty kpi_code -Unique).Count | Should Be 27
        $cards = @{}; foreach ($r in $rows | Where-Object { $_.card_code -ne '' }) { $cards[$r.card_code] = $r.kpi_code }
        $cards.Count | Should Be 6
        $cards['F1'] | Should Be 'FR_REV_GROWTH'; $cards['F2'] | Should Be 'FR_EBITDA_MARGIN'; $cards['F3'] | Should Be 'FR_NP_VS_BUD'
        $cards['F4'] | Should Be 'FR_AR_DAYS'; $cards['F5'] | Should Be 'FR_REJECTION_RATE'; $cards['F6'] | Should Be 'FR_COST_TO_REV'
    }
    It 'has six groups in order, unit % x or d and direction 1 or -1' {
        @($rows | Select-Object -ExpandProperty kpi_group -Unique).Count | Should Be 6
        @($rows | Where-Object { @('%', 'x', 'd') -notcontains $_.unit -or @(1, -1) -notcontains [int]$_.direction }).Count | Should Be 0
        $sorted = @($rows | Sort-Object { [int]$_.display_order })
        $sorted[0].kpi_code | Should Be 'FR_REV_GROWTH'; $sorted[26].kpi_code | Should Be 'FR_ECL_RATIO'
        $groups = @($sorted | ForEach-Object { [int]$_.group_order })
        (($groups | Sort-Object) -join ',') | Should Be ($groups -join ',')
    }
    It 'uses the design canvas KPI names and group names' {
        $n = @{}; foreach ($r in $rows) { $n[$r.kpi_code] = $r.kpi_name }
        $n['FR_REV_GROWTH'] | Should Be 'Net revenue growth'; $n['FR_REV_VS_BUD'] | Should Be 'Net revenue vs budget'
        $n['FR_NP_GROWTH'] | Should Be 'Net profit growth'; $n['FR_NP_VS_BUD'] | Should Be 'Net profit vs budget'
        $n['FR_CCC'] | Should Be 'Cash conversion cycle'; $n['FR_NET_DEBT_EBITDA'] | Should Be 'Net debt to EBITDA'
        $n['FR_ECL_RATIO'] | Should Be 'Credit loss charge'; $n['FR_REJECTION_RATE'] | Should Be 'Claim rejection rate'
        @($rows | Where-Object { $_.kpi_name -match '%' }).Count | Should Be 0
        $g = @($rows | Sort-Object { [int]$_.group_order } | Select-Object -ExpandProperty kpi_group -Unique) -join '|'
        $g | Should Be 'Growth & budget achievement|Profitability|Liquidity|Efficiency & working capital|Leverage & solvency|Cost structure & revenue cycle'
    }
    It 'sets the lower-is-better and higher-is-better directions' {
        $d = @{}; foreach ($r in $rows) { $d[$r.kpi_code] = [int]$r.direction }
        foreach ($c in 'FR_AR_DAYS', 'FR_INV_DAYS', 'FR_CCC', 'FR_DEBT_EQUITY', 'FR_NET_DEBT_EBITDA', 'FR_COST_TO_REV', 'FR_STAFF_COST_RATIO',
                       'FR_MED_MATERIALS_RATIO', 'FR_REJECTION_RATE', 'FR_ECL_RATIO') { $d[$c] | Should Be -1 }
        foreach ($c in 'FR_AP_DAYS', 'FR_INTEREST_COVER', 'FR_ASSET_TURNOVER', 'FR_CURRENT_RATIO', 'FR_ROE', 'FR_EQUITY_RATIO') { $d[$c] | Should Be 1 }
    }
}

Describe 'dim_finance_column' {
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'dim_finance_column') @{}
    # labels carry zero-width spaces (U+200B) per (page, view) so that each label has one sort order (R15e)
    function Visible($label) { return ([string]$label).Replace([string][char]0x200B, '') }
    function Kinds($page, $view, $group = $null) {
        $r = @($rows | Where-Object { $_.page -eq $page -and $_.view -eq $view -and ($null -eq $group -or (Visible $_.group_name) -eq $group) } | Sort-Object { [int]$_.column_order })
        return ($r | ForEach-Object { $_.kind }) -join ','
    }
    It 'has 12 month columns per monthly page' {
        foreach ($p in 'tb', 'is', 'bs', 'kpi') {
            $m = @($rows | Where-Object { $_.page -eq $p -and $_.view -eq 'monthly' -and $_.kind -eq 'month' })
            $m.Count | Should Be 12
            (($m | Sort-Object { [int]$_.month_num } | ForEach-Object { $_.month_num }) -join ',') | Should Be '1,2,3,4,5,6,7,8,9,10,11,12'
            (($m | Sort-Object { [int]$_.column_order } | ForEach-Object { Visible $_.column_name }) -join ',') | Should Be 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec'
        }
    }
    It 'has no month columns on the hospital views and a unique column_key' {
        @($rows | Where-Object { $_.view -eq 'hospital' -and $_.kind -eq 'month' }).Count | Should Be 0
        @($rows | Select-Object -ExpandProperty column_key -Unique).Count | Should Be $rows.Count
        @($rows | Where-Object { [int]$_.month_num -ne 0 -and $_.kind -ne 'month' }).Count | Should Be 0
    }
    It 'lists the groups and kinds per page' {
        Kinds 'tb' 'monthly' 'Period' | Should Be 'opening,opening_journal,debit,credit,closing,cutover'
        Kinds 'tb' 'monthly' 'Closing vs last year and budget' | Should Be 'ly,growth,budget,vs_bud'
        Kinds 'is' 'monthly' 'Period total' | Should Be 'actual,budget,variance,var_pct,ly,growth,pct_rev'
        Kinds 'bs' 'monthly' 'End of period vs last year and budget' | Should Be 'ly,growth,budget,vs_bud,pct_assets'
        Kinds 'kpi' 'monthly' 'Period' | Should Be 'target,actual,status,budget,vs_bud,ly,vs_ly'
        foreach ($p in 'tb', 'is', 'bs', 'kpi') { @($rows | Where-Object { $_.page -eq $p -and $_.view -eq 'hospital' -and (Visible $_.group_name) -ne '' }).Count | Should Be 0 }
        Kinds 'kpi' 'hospital' | Should Be 'actual,vs_bud,vs_ly'
        Kinds 'tb' 'hospital' | Should Be 'closing,ach,growth'
        Kinds 'bs' 'hospital' | Should Be 'closing,ach,growth'
        Kinds 'is' 'hospital' | Should Be 'actual,ach,growth'
    }
    It 'maps every label to one sort order, ignoring case as SSAS does (sortByColumn, R15e)' {
        foreach ($pair in @(@('column_name', 'column_order'), @('group_name', 'group_order'))) {
            $orders = New-Object 'System.Collections.Generic.Dictionary[string, System.Collections.Generic.HashSet[string]]' ([StringComparer]::OrdinalIgnoreCase)
            foreach ($r in $rows) {
                $label = [string]$r.($pair[0])
                if (-not $orders.ContainsKey($label)) { $orders[$label] = New-Object 'System.Collections.Generic.HashSet[string]' }
                [void]$orders[$label].Add([string]$r.($pair[1]))
            }
            $bad = @($orders.Keys | Where-Object { $orders[$_].Count -gt 1 } | ForEach-Object { "$($pair[0]) '$(Visible $_)'" })
            ($bad -join '; ') | Should Be ''
        }
    }
    It 'keeps the visible labels: only zero-width spaces are added, the same count within a page and view' {
        (Visible ($rows | Where-Object { $_.page -eq 'is' -and $_.view -eq 'monthly' -and $_.kind -eq 'budget' }).column_name) | Should Be 'Budget'
        (Visible ($rows | Where-Object { $_.page -eq 'tb' -and $_.view -eq 'monthly' -and $_.kind -eq 'debit' }).group_name) | Should Be 'Period'
        foreach ($g in ($rows | Group-Object { "$($_.page)|$($_.view)" })) {
            $counts = @($g.Group | ForEach-Object { ([string]$_.column_name).Length - (Visible $_.column_name).Length } | Select-Object -Unique)
            $counts.Count | Should Be 1
        }
        @($rows | Where-Object { ([string]$_.column_name).Length -eq (Visible $_.column_name).Length }).Count | Should BeGreaterThan 0
    }
}

Describe 'dim_finance_target' {
    $src = "select k as kpi_code, toUInt8(b) as branch_id, toUInt16(2026) as year, toFloat64(v) as target_value, toFloat64(0.05) as watch_pct, now() as last_changed_at " +
           "from values('k String, b UInt8, v Float64', ('FR_AR_DAYS', 0, 60), ('FR_AR_DAYS', 3, 45), ('FR_ROE', 0, 12))"
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'dim_finance_target' @{ stg_ref__finance_target = $src }) @{}
    It 'keeps both the hospital row and the branch 0 row of a KPI' {
        $rows.Count | Should Be 3
        $ar = @($rows | Where-Object { $_.kpi_code -eq 'FR_AR_DAYS' } | Sort-Object { [int]$_.branch_id })
        $ar.Count | Should Be 2
        [double]$ar[0].target_value | Should Be 60
        [double]$ar[1].target_value | Should Be 45
    }
}

Describe 'finance SSAS contracts' {
    $yaml = [IO.File]::ReadAllText((Join-Path $root 'hnh_dwh\models\hnh\marts\ssas\_ssas__models.yml'))
    function Names($model) { return @(Get-HnhContractColumns -YamlText $yaml -Model $model) | ForEach-Object { $_.Name } }
    foreach ($pair in @(@('dim_finance_kpi', 'ssas_dim_finance_kpi'), @('dim_finance_column', 'ssas_dim_finance_column'))) {
        It "lists every column of $($pair[0]) in $($pair[1])" {
            $sql = (Get-RenderedModel $pair[0] @{} 'describe ({model})') -replace '(?m)^\s*--.*$', ''
            $mart = @(Invoke-HnhSelect -Dsn HNH_Gold -Sql $sql) | ForEach-Object { $_.name }
            ((Names $pair[1]) -join ',') | Should Be ($mart -join ',')
        }
    }
    It 'lists every column of dim_finance_target in ssas_dim_finance_target' {
        ((Names 'ssas_dim_finance_target') -join ',') | Should Be 'kpi_code,branch_id,year,target_value,watch_pct'
    }
    It 'lists the new gl_fs, pl report and budget columns' {
        $gl = Names 'ssas_fact_gl_fs_monthly'
        foreach ($c in 'debit', 'credit', 'account_name', 'fs_caption_name', 'bs_side', 'bs_caption', 'display_sign', 'bs_element_order', 'bs_category_order') { ($gl -contains $c) | Should Be $true }
        ((Names 'ssas_fact_pl_report_monthly') -contains 'account_name') | Should Be $true
        $pl = Names 'ssas_dim_pl_report_line'
        foreach ($c in 'budget_line_code', 'budget_sign', 'budget_kind') { ($pl -contains $c) | Should Be $true }
        ((Names 'ssas_dim_date') -contains 'year_pick') | Should Be $true
        (Names 'ssas_fact_finance_budget_monthly') -join ',' | Should Be 'branch_key,month_date_key,statement,pl_line_key,pl_line_code,bs_caption,amount,source'
    }
}

# Config typos (final review): BS captions are lower-cased, and rows with a month outside 1..12 or a branch outside 1..8 / 100 are
# ignored by fact_finance_budget_monthly (and listed by the warn test assert_finance_budget_config_valid), not a build failure.
Describe 'stg_ref__finance_budget BS caption' {
    $src = "select toUInt8(1) as branch_id, toUInt16(2026) as year, toUInt8(1) as month, st as statement, lc as line_code, toFloat64(5) as amount, $cl, toUInt8(0) as is_deleted " +
           "from values('st String, lc String, s UInt32', ('bs', ' Trade Receivables, Net ', 10), ('IS', 'DC_Employee', 10))"
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'stg_ref__finance_budget') @{ map_finance_budget = $src }
    $k = @{}; foreach ($r in $rows) { $k[$r.statement] = $r }
    It 'lower-cases the line_code of BS rows only' {
        $k['BS'].line_code | Should Be 'trade receivables, net'
        $k['IS'].line_code | Should Be 'DC_Employee'
    }
}

Describe 'fact_finance_budget_monthly ignores impossible months and branches' {
    $fim = "select toUInt8(1) as branch_key, toDate('2026-01-01') as month_start, 'DC_EMPLOYEE' as budget_line_code, toFloat64(100) as budget_most_likely"
    $plLine = "select toUInt16(300) as pl_line_key, 'DC_EMPLOYEE' as pl_line_code, 'Direct Cost' as section_name, 'detail' as line_kind, " +
              "cast([] as Array(String)) as subtotal_sections, 'DC_EMPLOYEE' as budget_line_code, toInt8(-1) as budget_sign"
    $stg = "select toUInt8(b) as branch_id, toUInt16(2026) as year, toUInt8(m) as month, st as statement, lc as line_code, toFloat64(a) as amount, now() as last_changed_at " +
           "from values('b UInt8, m UInt8, st String, lc String, a Float64', (1, 1, 'IS', 'DC_EMPLOYEE', 120), (1, 13, 'IS', 'DC_EMPLOYEE', 7), " +
           "(1, 0, 'BS', 'cash', 8), (9, 1, 'IS', 'DC_EMPLOYEE', 9), (100, 2, 'BS', 'cash', 50))"
    $rep = @{ fact_income_statement_monthly = $fim; dim_pl_report_line = $plLine; stg_ref__finance_budget = $stg }
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'fact_finance_budget_monthly' $rep) @{}
    It 'keeps the valid override and the Head Office balance sheet row, drops month 13, month 0 and branch 9' {
        $rows.Count | Should Be 2
        $is = @($rows | Where-Object { $_.statement -eq 'IS' })
        $is.Count | Should Be 1
        [double]$is[0].amount | Should Be -120
        $bs = @($rows | Where-Object { $_.statement -eq 'BS' })
        $bs.Count | Should Be 1
        $bs[0].branch_key | Should Be 100
    }
}

Describe 'assert_finance_budget_config_valid' {
    $stg = "select toUInt8(b) as branch_id, toUInt16(2026) as year, toUInt8(m) as month, st as statement, 'x' as line_code, toFloat64(1) as amount " +
           "from values('b UInt8, m UInt8, st String', (1, 1, 'IS'), (1, 13, 'IS'), (9, 1, 'IS'), (100, 12, 'BS'), (2, 3, 'XX'))"
    $sql = (Get-Content (Join-Path $root 'hnh_dwh\tests\hnh\assert_finance_budget_config_valid.sql') -Raw)
    $sql = ($sql -replace '(?m)^\{\{ config.*$', '') -replace '\{\{ ref\(''stg_ref__finance_budget''\) \}\}', "($stg)"
    $rows = Invoke-ModelWithSources $sql @{}
    It 'lists month 13, branch 9 and an unknown statement, not the valid rows' {
        $rows.Count | Should Be 3
    }
}

# assert_pl_line_budget_link (final review): the "linked exactly once" branch used a correlated count() that is NULL, not 0, for an
# unmatched key on ClickHouse 26.5, so an unlinked budget line was never flagged.
Describe 'assert_pl_line_budget_link linked-exactly-once branch' {
    $b = "(select c as budget_line_code, toUInt8(0) as is_subtotal from values('c String', ('A_UNLINKED'), ('B_ONCE'), ('C_TWICE'), ('UNBUDGETED')))"
    $l = "(select l as pl_line_code, c as budget_line_code, toInt8(if(c = '', 0, 1)) as budget_sign, 'detail' as line_kind " +
         "from values('l String, c String', ('L1', 'B_ONCE'), ('L2', 'C_TWICE'), ('L3', 'C_TWICE'), ('L4', '')))"
    $sql = (Get-Content (Join-Path $root 'hnh_dwh\tests\hnh\assert_pl_line_budget_link.sql') -Raw)
    $sql = $sql.Replace("{{ ref('dim_budget_line') }}", $b).Replace("{{ ref('dim_pl_report_line') }}", $l)
    $rows = Invoke-ModelWithSources $sql @{}
    $found = @($rows | ForEach-Object { $_.detail })
    It 'flags an unlinked and a twice-linked budget line, not a once-linked or an excepted one' {
        $found -contains 'A_UNLINKED' | Should Be $true
        $found -contains 'C_TWICE' | Should Be $true
        $found -contains 'B_ONCE' | Should Be $false
        $found -contains 'UNBUDGETED' | Should Be $false
        $rows.Count | Should Be 2
    }
}
