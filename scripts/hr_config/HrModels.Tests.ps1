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

# Task 4: fact_hr_dq_record. Every ref and the Oasis staff source are replaced by stub rows (empty unless a test gives
# rows); the as-of date is pinned to 2026-11-15, so the last closed month is 2026-10.
$dqStructs = [ordered]@{
    hnh_dim_employee           = 'employee_key Int64, person_id Nullable(Int64), branch_key UInt8, worker_number Nullable(String), worker_type_code Nullable(String), is_terminated UInt8, termination_date Nullable(Date32), gender Nullable(String), nationality Nullable(String), birth_date Nullable(Date32), hr_department_key Int64, job_key Int64, grade_key Int64, staff_key Int64'
    dim_staff                  = 'staff_key Int64, branch_key UInt8, staff_id Nullable(String), contract_status String, termination_date Nullable(Date32)'
    bridge_employee_staff      = 'employee_key Int64, staff_key Int64, branch_key UInt8, worker_number String'
    stg_fusion__work_measures  = 'assignment_id Nullable(Int64), unit Nullable(String), value Float64, effective_start_date Nullable(Date32)'
    stg_fusion__assignments    = 'assignment_id Int64, person_id Nullable(Int64), is_current UInt8, is_primary UInt8, assignment_status Nullable(String), valid_from Date32, legal_employer_id Nullable(Int64)'
    int_employee_period        = 'person_id Int64, legal_employer_id Nullable(Int64)'
    int_legal_employer_branch  = 'legal_employer_id Int64, legal_employer_name String'
    fact_payroll_monthly       = 'branch_key UInt8, source String, payee_key Int64, employee_key Int64, staff_key Int64, payroll_month Int32, pay_category String, amount Float64'
    fact_leave_balance_monthly = 'branch_key UInt8, employee_key Int64, absence_plan_id Nullable(Int64), accrual_period_date_key Int32, is_closed_period Nullable(UInt8), is_current_balance Nullable(UInt8), is_annual_plan UInt8, monthly_salary Nullable(Float64)'
    fact_absence               = 'branch_key UInt8, employee_key Int64, staff_key Int64, start_date_key Int32, is_counted UInt8, duration_uom Nullable(String), absence_days Float64'
    fact_absence_daily         = 'branch_key UInt8, employee_key Int64, staff_key Int64, date_key Int32'
    hnh_fact_worker_movement   = 'branch_key UInt8, employee_key Int64, staff_key Int64, action_date_key Int32'
}
$dqOasisStaff = 'branch_id Int64, staff_id String'
$dqCodes = @('DQ_EMP_NO_STAFF', 'DQ_STAFF_NO_EMP', 'DQ_STAFF_MANY_EMP', 'DQ_STAFF_ID_FORMAT', 'DQ_EMP_DUP_WORKER_NO', 'DQ_FTE_ZERO',
             'DQ_LEAVE_DUP_PERIOD', 'DQ_ABSENCE_OVERLAP', 'DQ_ABSENCE_ZERO_DAYS', 'DQ_LEAVE_NO_SALARY', 'DQ_PAY_CODE_UNMAPPED',
             'DQ_B8_PAYROLL_COPY', 'DQ_PAYROLL_MONTH_MISSING', 'DQ_LEAVE_BALANCE_STOPS', 'DQ_TERMINATED_WITH_BALANCE',
             'DQ_FUTURE_DATED', 'DQ_NO_HOSPITAL', 'DQ_LEGAL_EMPLOYER_MISMATCH', 'DQ_MISSING_ATTRIBUTE')

function Get-DqSql([hashtable]$Rows, [string]$Parked = '') {
    $replace = @{}
    foreach ($k in $dqStructs.Keys) {
        if ($Rows.ContainsKey($k)) { $replace[$k] = "select * from values('$($dqStructs[$k])', $($Rows[$k]))" }
        else { $replace[$k] = "select * from null('$($dqStructs[$k])')" }
    }
    $issues = ($dqCodes | ForEach-Object { if ($_ -eq $Parked) { "('$_', 'parked')" } else { "('$_', 'active')" } }) -join ', '
    $replace['dim_hr_dq_issue'] = "select toInt64(bitShiftRight(cityHash64(concat(c, '|')), 1)) as hr_dq_issue_key, c as issue_code, st as status " +
                                  "from values('c String, st String', $issues)"
    $oasis = "select * from null('$dqOasisStaff')"
    if ($Rows.ContainsKey('staff_master_data')) { $oasis = "select * from values('$dqOasisStaff', $($Rows['staff_master_data']))" }
    $sql = (Get-RenderedModel 'fact_hr_dq_record' $replace).Replace("toDateOrNull('')", "toDateOrNull('2026-11-15')")
    if (-not $sql.Contains('oasis.staff_master_data final')) { throw 'fact_hr_dq_record: Oasis staff source not found' }
    return $sql.Replace('oasis.staff_master_data final', "($oasis)")
}
function Get-DqRecords([hashtable]$Rows, [string]$Parked = '') { return @(Invoke-ModelWithSources (Get-DqSql $Rows $Parked) @{}) }
function Of($rows, [string]$Code) { return ,@($rows | Where-Object { $_.issue_code -eq $Code }) }
function Day($value) { return ([datetime]$value).ToString('yyyy-MM-dd') }
# One hnh_dim_employee row (key, person id, branch, worker number, worker type, terminated, staff key) with every attribute set.
function Emp([long]$Key, [string]$Person, [int]$Branch, [string]$Wn, [string]$Type = 'EMP', [int]$Term = 0, [long]$Staff = -1) {
    $termDate = 'null'
    if ($Term) { $termDate = "'2026-05-31'" }
    return "($Key, $Person, $Branch, '$Wn', '$Type', $Term, $termDate, 'M', 'SA', '1980-01-01', 1, 1, 1, $Staff)"
}

Describe 'fact_hr_dq_record columns' {
    $sql = (Get-DqSql @{}) -replace '(?m)^\s*--.*$', ''
    $i = $sql.LastIndexOf("`nsettings ")
    $cols = Invoke-HnhSelect -Dsn HNH_Gold -Sql ('describe (' + $sql.Substring(0, $i) + "`n)" + $sql.Substring($i))
    It 'has the interface columns and types, and no name or amount column' {
        (@($cols | ForEach-Object { "$($_.name) $($_.type)" }) -join '; ') | Should Be ('hr_dq_issue_key Int64; issue_code String; branch_key UInt8; ' +
            'employee_key Int64; staff_key Int64; worker_number Nullable(String); staff_id Nullable(String); field_name String; ' +
            'value_found Nullable(String); record_date Nullable(Date)')
    }
}

Describe 'DQ_EMP_NO_STAFF' {
    $e = ((Emp 11 '1001' 3 'W1'), (Emp 12 '1002' 3 'W2' -Staff 21), (Emp 13 '1003' 3 'W3' -Term 1), (Emp 14 '1004' 0 'W4')) -join ', '
    $rows = Of (Get-DqRecords @{ hnh_dim_employee = $e }) 'DQ_EMP_NO_STAFF'
    It 'returns the active hospital employee with no staff link' {
        $rows.Count | Should Be 1
        [int64]$rows[0].employee_key | Should Be 11
        [int]$rows[0].branch_key | Should Be 3
        $rows[0].field_name | Should Be 'worker_number'
        $rows[0].worker_number | Should Be 'W1'
        [int64]$rows[0].hr_dq_issue_key | Should Be (Get-HrKey 'DQ_EMP_NO_STAFF')
    }
}

Describe 'DQ_STAFF_NO_EMP' {
    $rows = Of (Get-DqRecords @{
        dim_staff = "(21, 3, 'S21', 'Active', null), (22, 3, 'S22', 'Active', null), (23, 3, 'S23', 'Terminated', '2025-01-31'), (24, 3, 'S24', 'No contract', null)"
        bridge_employee_staff = "(12, 21, 3, 'S21')" }) 'DQ_STAFF_NO_EMP'
    It 'returns the active staff member with no bridge row' {
        $rows.Count | Should Be 1
        [int64]$rows[0].staff_key | Should Be 22
        [int64]$rows[0].employee_key | Should Be -1
        [int]$rows[0].branch_key | Should Be 3
        $rows[0].field_name | Should Be 'staff_id'
        $rows[0].staff_id | Should Be 'S22'
    }
}

Describe 'DQ_STAFF_MANY_EMP' {
    $rows = Of (Get-DqRecords @{ bridge_employee_staff = "(11, 21, 4, 'S21'), (12, 21, 4, 'S21'), (13, 22, 4, 'S22')" }) 'DQ_STAFF_MANY_EMP'
    It 'returns one row per employee of the staff record linked to several' {
        $rows.Count | Should Be 2
        @($rows | Where-Object { [int64]$_.staff_key -eq 21 }).Count | Should Be 2
        (@($rows | ForEach-Object { [int64]$_.employee_key }) | Sort-Object) -join ',' | Should Be '11,12'
        [int]$rows[0].branch_key | Should Be 4
        $rows[0].field_name | Should Be 'staff_id'
        $rows[0].staff_id | Should Be 'S21'
    }
}

Describe 'DQ_STAFF_MANY_EMP leaves duplicate worker numbers to DQ_EMP_DUP_WORKER_NO (final review M1)' {
    # 11 and 12 share worker number W1 in branch 4 and link to staff 21 with 15 (W9); 13 alone on staff 22
    $e = ((Emp 11 '1001' 4 'W1' -Staff 21), (Emp 12 '1002' 4 'W1' -Staff 21), (Emp 15 '1005' 4 'W9' -Staff 21), (Emp 13 '1003' 4 'S22' -Staff 22)) -join ', '
    $all = Get-DqRecords @{ hnh_dim_employee = $e
        bridge_employee_staff = "(11, 21, 4, 'W1'), (12, 21, 4, 'W1'), (15, 21, 4, 'W9'), (13, 22, 4, 'S22')" }
    $many = Of $all 'DQ_STAFF_MANY_EMP'
    $dup = Of $all 'DQ_EMP_DUP_WORKER_NO'
    It 'lists the duplicate-worker-number employees once, under DQ_EMP_DUP_WORKER_NO' {
        (@($dup | ForEach-Object { [int64]$_.employee_key }) | Sort-Object) -join ',' | Should Be '11,12'
        @($many | Where-Object { [int64]$_.employee_key -in 11, 12 }).Count | Should Be 0
    }
    It 'keeps the other employee of the staff record linked to several' {
        (@($many | ForEach-Object { [int64]$_.employee_key }) | Sort-Object) -join ',' | Should Be '15'
        [int64]$many[0].staff_key | Should Be 21
    }
}

Describe 'DQ_STAFF_ID_FORMAT' {
    $rows = Of (Get-DqRecords @{
        staff_master_data = "(3, 'A1'), (3, ' a1'), (3, 'A1'), (3, 'B2'), (4, 'A1')"
        dim_staff = "(21, 3, 'A1', 'Active', null)" }) 'DQ_STAFF_ID_FORMAT'
    It 'returns each raw id of a branch whose ids differ only in format' {
        $rows.Count | Should Be 2
        (@($rows | ForEach-Object { "[$($_.staff_id)]" }) | Sort-Object) -join ',' | Should Be '[ a1],[A1]'
        foreach ($r in $rows) {
            [int]$r.branch_key | Should Be 3
            [int64]$r.staff_key | Should Be 21
            $r.field_name | Should Be 'staff_id'
        }
    }
}

Describe 'DQ_EMP_DUP_WORKER_NO' {
    $e = ((Emp 11 '1001' 3 'W1' -Staff 21), (Emp 12 '1002' 3 'W1' -Staff 21), (Emp 13 '1003' 4 'W1' -Staff 22)) -join ', '
    $rows = Of (Get-DqRecords @{ hnh_dim_employee = $e }) 'DQ_EMP_DUP_WORKER_NO'
    It 'returns the employees sharing a worker number in one branch' {
        $rows.Count | Should Be 2
        (@($rows | ForEach-Object { [int64]$_.employee_key }) | Sort-Object) -join ',' | Should Be '11,12'
        [int]$rows[0].branch_key | Should Be 3
        $rows[0].field_name | Should Be 'worker_number'
        $rows[0].value_found | Should Be 'W1'
    }
}

Describe 'DQ_FTE_ZERO' {
    $rows = Of (Get-DqRecords @{
        stg_fusion__work_measures = "(501, 'FTE', 0, '2026-03-01'), (502, 'FTE', 1, '2026-03-01'), (503, 'HEAD', 0, '2026-03-01'), (504, 'FTE', 0, '2026-04-01')"
        stg_fusion__assignments = "(501, 1001, 1, 1, 'ACTIVE', '2026-01-01', 900), (502, 1002, 1, 1, 'ACTIVE', '2026-01-01', 900), (503, 1002, 1, 0, 'ACTIVE', '2026-01-01', 900)"
        hnh_dim_employee = ((Emp 11 '1001' 5 'W1' -Staff 21), (Emp 12 '1002' 5 'W2')) -join ', '
        dim_staff = "(21, 5, 'W1', 'Active', null)" }) 'DQ_FTE_ZERO'
    $byKey = @{}; foreach ($r in $rows) { $byKey[[string]$r.employee_key] = $r }
    It 'returns the FTE work measure out of range, on the employee''s branch' {
        $rows.Count | Should Be 2
        [int]$byKey['11'].branch_key | Should Be 5
        $byKey['11'].field_name | Should Be 'fte'
        $byKey['11'].value_found | Should Be '0'
        Day $byKey['11'].record_date | Should Be '2026-03-01'
    }
    It 'fills the worker number and staff link from the employee' {
        $byKey['11'].worker_number | Should Be 'W1'
        [int64]$byKey['11'].staff_key | Should Be 21
        $byKey['11'].staff_id | Should Be 'W1'
    }
    It 'puts a measure with no employee under Head Office' {
        [int]$byKey['-1'].branch_key | Should Be 100
        [int64]$byKey['-1'].staff_key | Should Be -1
        $byKey['-1'].worker_number | Should BeNullOrEmpty
    }
}

Describe 'DQ_LEAVE_DUP_PERIOD' {
    $lb = "(6, 11, 7, 20260831, 1, 0, 1, 5000), (6, 11, 7, 20260831, 1, 1, 1, 5000), (6, 12, 7, 20260831, 1, 1, 1, 5000)"
    $rows = Of (Get-DqRecords @{ fact_leave_balance_monthly = $lb }) 'DQ_LEAVE_DUP_PERIOD'
    It 'returns the employee, plan and period with two entries' {
        $rows.Count | Should Be 1
        [int64]$rows[0].employee_key | Should Be 11
        [int]$rows[0].branch_key | Should Be 6
        $rows[0].field_name | Should Be 'balance_entries'
        $rows[0].value_found | Should Be '2'
        Day $rows[0].record_date | Should Be '2026-08-31'
    }
}

Describe 'DQ_ABSENCE_OVERLAP' {
    $rows = Of (Get-DqRecords @{ fact_absence_daily = "(2, 11, 21, 20260310), (2, 11, 21, 20260310), (2, 12, 22, 20260310)" }) 'DQ_ABSENCE_OVERLAP'
    It 'returns the employee-day with two counted absence rows' {
        $rows.Count | Should Be 1
        [int64]$rows[0].employee_key | Should Be 11
        [int64]$rows[0].staff_key | Should Be 21
        [int]$rows[0].branch_key | Should Be 2
        $rows[0].field_name | Should Be 'absence_entries'
        Day $rows[0].record_date | Should Be '2026-03-10'
    }
}

Describe 'DQ_ABSENCE_ZERO_DAYS' {
    $a = "(2, 11, -1, 20260310, 1, 'C', 0), (2, 12, -1, 20260310, 1, 'C', 2), (2, 13, -1, 20260310, 0, 'C', 0), (2, 14, -1, 20260310, 1, 'H', 0)"
    $rows = Of (Get-DqRecords @{ fact_absence = $a }) 'DQ_ABSENCE_ZERO_DAYS'
    It 'returns the counted day-unit absence with zero days' {
        $rows.Count | Should Be 1
        [int64]$rows[0].employee_key | Should Be 11
        [int]$rows[0].branch_key | Should Be 2
        $rows[0].field_name | Should Be 'absence_days'
        $rows[0].value_found | Should Be '0'
        Day $rows[0].record_date | Should Be '2026-03-10'
    }
}

Describe 'DQ_LEAVE_NO_SALARY' {
    $lb = "(4, 11, 7, 20261031, 1, 1, 1, null), (4, 12, 7, 20261031, 1, 1, 1, 5000), (4, 13, 8, 20261031, 1, 1, 0, null), (4, 14, 7, 20260930, 1, 0, 1, null)"
    $rows = Of (Get-DqRecords @{ fact_leave_balance_monthly = $lb }) 'DQ_LEAVE_NO_SALARY'
    It 'returns the current annual balance with no salary' {
        $rows.Count | Should Be 1
        [int64]$rows[0].employee_key | Should Be 11
        [int]$rows[0].branch_key | Should Be 4
        $rows[0].field_name | Should Be 'monthly_salary'
        $rows[0].value_found | Should BeNullOrEmpty
    }
}

Describe 'DQ_PAY_CODE_UNMAPPED' {
    $p = "(6, 'fusion', 1, 11, -1, 202609, 'Unmapped', 10), (6, 'fusion', 2, 12, -1, 202609, 'Basic', 10)"
    $rows = Of (Get-DqRecords @{ fact_payroll_monthly = $p }) 'DQ_PAY_CODE_UNMAPPED'
    It 'returns the payroll row with no pay category' {
        $rows.Count | Should Be 1
        [int64]$rows[0].employee_key | Should Be 11
        [int]$rows[0].branch_key | Should Be 6
        $rows[0].field_name | Should Be 'pay_category'
        Day $rows[0].record_date | Should Be '2026-09-01'
    }
}

Describe 'DQ_B8_PAYROLL_COPY' {
    $p = "(7, 'oasis', 1, -1, -1, 202602, 'Basic', 100), (8, 'oasis', 2, -1, -1, 202602, 'Basic', 100), " +
         "(7, 'oasis', 1, -1, -1, 202603, 'Basic', 100), (8, 'oasis', 2, -1, -1, 202603, 'Basic', 90)"
    $rows = Of (Get-DqRecords @{ fact_payroll_monthly = $p }) 'DQ_B8_PAYROLL_COPY'
    It 'returns the branch 8 month equal to branch 7' {
        $rows.Count | Should Be 1
        [int]$rows[0].branch_key | Should Be 8
        $rows[0].field_name | Should Be 'payroll_month'
        $rows[0].value_found | Should Be '202602'
        Day $rows[0].record_date | Should Be '2026-02-01'
    }
}

Describe 'DQ_PAYROLL_MONTH_MISSING' {
    # Last closed month 202610: no hospital has it yet, so it is not a gap. Branch 2 misses 202608, which branch 3 has.
    $p = "(2, 'fusion', 1, 11, -1, 202607, 'Basic', 1), (2, 'fusion', 1, 11, -1, 202609, 'Basic', 1), " +
         "(3, 'fusion', 2, 12, -1, 202608, 'Basic', 1), (3, 'fusion', 2, 12, -1, 202609, 'Basic', 1), (0, 'fusion', 3, 13, -1, 202601, 'Basic', 1)"
    $rows = Of (Get-DqRecords @{ fact_payroll_monthly = $p }) 'DQ_PAYROLL_MONTH_MISSING'
    It 'returns the hospital-month with no payroll that another hospital has, up to the last closed month' {
        $rows.Count | Should Be 1
        [int]$rows[0].branch_key | Should Be 2
        [int64]$rows[0].employee_key | Should Be -1
        $rows[0].field_name | Should Be 'payroll_month'
        $rows[0].value_found | Should Be '202608'
        Day $rows[0].record_date | Should Be '2026-08-01'
    }
    It 'does not flag a month no hospital has payroll for yet' {
        @($rows | Where-Object { $_.value_found -eq '202610' }).Count | Should Be 0
    }
}

Describe 'DQ_LEAVE_BALANCE_STOPS' {
    $e = ((Emp 11 '1001' 1 'W1'), (Emp 12 '1002' 1 'W2'), (Emp 13 '1003' 1 'W3'), (Emp 14 '1004' 3 'W4'), (Emp 15 '1005' 3 'W5')) -join ', '
    $lb = "(1, 11, 7, 20260829, 1, 1, 1, 1), (1, 12, 7, 20260829, 1, 1, 1, 1), (1, 13, 7, 20261031, 1, 1, 1, 1), " +
          "(3, 14, 7, 20260926, 1, 1, 1, 1), (3, 15, 7, 20261031, 1, 1, 1, 1), (3, 15, 7, 20271031, 0, 0, 1, 1)"
    $rows = Of (Get-DqRecords @{ hnh_dim_employee = $e; fact_leave_balance_monthly = $lb }) 'DQ_LEAVE_BALANCE_STOPS'
    It 'returns the hospital whose balances stop two months or more before the network' {
        $rows.Count | Should Be 1
        [int]$rows[0].branch_key | Should Be 1
        [int64]$rows[0].employee_key | Should Be -1
        $rows[0].field_name | Should Be 'accrual_period'
        $rows[0].value_found | Should Be '202608'
    }
}

Describe 'DQ_TERMINATED_WITH_BALANCE' {
    $e = ((Emp 11 '1001' 4 'W1' -Term 1), (Emp 12 '1002' 4 'W2')) -join ', '
    $lb = "(4, 11, 7, 20261031, 1, 1, 1, 1), (4, 11, 7, 20260930, 1, 0, 1, 1), (4, 12, 7, 20261031, 1, 1, 1, 1)"
    $rows = Of (Get-DqRecords @{ hnh_dim_employee = $e; fact_leave_balance_monthly = $lb }) 'DQ_TERMINATED_WITH_BALANCE'
    It 'returns the current balance of the terminated employee' {
        $rows.Count | Should Be 1
        [int64]$rows[0].employee_key | Should Be 11
        [int]$rows[0].branch_key | Should Be 4
        $rows[0].field_name | Should Be 'termination_date'
        $rows[0].value_found | Should Be '2026-05-31'
        Day $rows[0].record_date | Should Be '2026-10-31'
    }
}

Describe 'DQ_FUTURE_DATED' {
    $rows = Of (Get-DqRecords @{
        hnh_fact_worker_movement = "(5, 11, -1, 20271201), (5, 12, -1, 20261201), (5, 16, -1, 20261001)"
        fact_absence = "(5, 13, -1, 20280110, 1, 'C', 1), (5, 14, -1, 20270601, 1, 'C', 1), (5, 15, -1, 20280110, 0, 'C', 1)" }) 'DQ_FUTURE_DATED'
    # As of 2026-11-15: only dates after 2027-11-15 count; planned leave and pending actions within 12 months do not.
    It 'returns the movement and the counted absence dated more than 12 months ahead' {
        $rows.Count | Should Be 2
        (@($rows | ForEach-Object { "$([int64]$_.employee_key):$($_.field_name)" }) | Sort-Object) -join ',' | Should Be '11:action_date,13:start_date'
        foreach ($r in $rows) { [int]$r.branch_key | Should Be 5 }
    }
}

Describe 'DQ_NO_HOSPITAL' {
    $e = ((Emp 11 '1001' 0 'C1' 'CWK'), (Emp 12 '1002' 0 'C2' 'CWK' -Term 1), (Emp 13 '1003' 2 'C3' 'CWK')) -join ', '
    $rows = Of (Get-DqRecords @{ hnh_dim_employee = $e }) 'DQ_NO_HOSPITAL'
    It 'no_hospital_goes_to_head_office' {
        $rows.Count | Should Be 1
        [int64]$rows[0].employee_key | Should Be 11
        [int]$rows[0].branch_key | Should Be 100
        $rows[0].field_name | Should Be 'branch'
        $rows[0].value_found | Should Be '0'
    }
}

Describe 'DQ_LEGAL_EMPLOYER_MISMATCH' {
    $rows = Of (Get-DqRecords @{
        hnh_dim_employee = ((Emp 11 '1001' 3 'W1'), (Emp 12 '1002' 3 'W2')) -join ', '
        int_employee_period = "(1001, 900), (1002, 900)"
        int_legal_employer_branch = "(900, 'HNH Jazan'), (901, 'HNH Abha')"
        stg_fusion__assignments = "(601, 1001, 1, 1, 'ACTIVE', '2026-01-01', 901), (602, 1002, 1, 1, 'ACTIVE', '2026-01-01', 900), " +
                                  "(603, 1002, 0, 1, 'ACTIVE', '2025-01-01', 901)" }) 'DQ_LEGAL_EMPLOYER_MISMATCH'
    It 'returns the employee whose current assignment has another legal employer' {
        $rows.Count | Should Be 1
        [int64]$rows[0].employee_key | Should Be 11
        [int]$rows[0].branch_key | Should Be 3
        $rows[0].field_name | Should Be 'legal_employer'
        $rows[0].value_found | Should Be 'HNH Abha'
    }
}

Describe 'DQ_MISSING_ATTRIBUTE' {
    $e = "(11, 1001, 2, 'W1', 'EMP', 0, null, null, 'SA', '1980-01-01', 1, -1, 1, -1), " + (Emp 12 '1002' 2 'W2') +
         ", (13, 1003, 2, 'W3', 'CWK', 0, null, null, 'SA', '1980-01-01', 1, 1, 1, -1)" +
         ", (14, 1004, 2, 'W4', 'EMP', 1, '2026-01-31', null, 'SA', '1980-01-01', 1, 1, 1, -1)"
    $rows = Of (Get-DqRecords @{ hnh_dim_employee = $e }) 'DQ_MISSING_ATTRIBUTE'
    It 'returns one row per missing field of the active EMP employee' {
        $rows.Count | Should Be 2
        (@($rows | ForEach-Object { $_.field_name }) | Sort-Object) -join ',' | Should Be 'gender,job_key'
        foreach ($r in $rows) {
            [int64]$r.employee_key | Should Be 11
            [int]$r.branch_key | Should Be 2
        }
    }
}

Describe 'fact_hr_dq_record keeps only active issues' {
    $e = Emp 11 '1001' 0 'C1' 'CWK'
    It 'drops the records of a parked issue' {
        (Of (Get-DqRecords @{ hnh_dim_employee = $e }) 'DQ_NO_HOSPITAL').Count | Should Be 1
        (Of (Get-DqRecords @{ hnh_dim_employee = $e } 'DQ_NO_HOSPITAL') 'DQ_NO_HOSPITAL').Count | Should Be 0
    }
}

Describe 'dim_date month_pick (ruling R21)' {
    $sql = (& python (Join-Path $root 'scripts\render_model_sql.py') 'dim_date' '--wrap' (
        'select month_offset, year_month_name, month_pick, count() as days from ({model}) ' +
        'where month_offset between 0 and 13 group by month_offset, year_month_name, month_pick order by month_offset')) -join "`n"
    # Invoke-HnhSelect returns the row array as one object, so it is not wrapped in @() here.
    $rows = Invoke-HnhSelect -Dsn HNH_Gold -Sql ($sql -replace '(?m)^\s*--.*$', '')
    It 'reads Last closed month for the month before this one only' {
        $rows.Count | Should Be 14
        @($rows | Where-Object { [int]$_.days -lt 28 }).Count | Should Be 0
        @($rows | Where-Object { $_.month_pick -eq 'Last closed month' }).Count | Should Be 1
        [int]($rows | Where-Object { $_.month_pick -eq 'Last closed month' }).month_offset | Should Be 1
    }
    It 'reads the year-month name for every other month' {
        foreach ($r in $rows | Where-Object { [int]$_.month_offset -ne 1 }) { $r.month_pick | Should BeExactly $r.year_month_name }
    }
}
