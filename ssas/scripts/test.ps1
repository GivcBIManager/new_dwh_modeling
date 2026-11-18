<#
.SYNOPSIS
  Row-count, security, measure, performance and size tests of a deployed HNH_Analytics database (SSAS spec 11).
  Run as an SSAS administrator on HNHANALYTICSSRV. Exit 0 = all passed, 1 = at least one failure.
  The security and performance tests log on as the users in ssas/tests/security.json, with the passwords that
  scripts/create_bi_windows_users.ps1 stored in -CredentialFile (DPAPI: readable only by the account that created it).
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ssas\scripts\test.ps1 -Database HNH_Analytics_Test
#>
param(
    [string]$Server = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [Parameter(Mandatory = $true)][string]$Database,
    [string]$Dsn = 'HNH_Gold',
    [string]$TabularEditorDir = 'C:\Program Files (x86)\Tabular Editor',
    [string]$CredentialFile = 'C:\HNH\secrets\bi_user_credentials.xml',
    [ValidateSet('All', 'RowCounts', 'Security', 'Measures', 'Performance', 'Size')][string[]]$Stage = @('All')
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'HnhSsas.psm1') -Force
Import-HnhTom $TabularEditorDir
$root = Split-Path $PSScriptRoot -Parent
$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force $logDir | Out-Null
Start-Transcript -Path (Join-Path $logDir ('test_{0}_{1:yyyyMMdd_HHmmss}.log' -f $Database, (Get-Date))) | Out-Null
$script:failures = 0

function Report([string]$Name, [bool]$Ok, [string]$Detail) {
    $word = 'PASS'
    if (-not $Ok) { $word = 'FAIL'; $script:failures++ }
    Write-Host ('{0} {1}: {2}' -f $word, $Name, $Detail)
}
function Skip([string]$Name, [string]$Detail) { Write-Host ('SKIP {0}: {1}' -f $Name, $Detail) }
# DBNull, blank or non-numeric text -> $null (so a blank cell is a failed comparison, not an exception); else a double
function ConvertTo-HnhNumber($Value) {
    if ($Value -eq $null -or $Value -is [System.DBNull] -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    $n = 0.0
    if ([double]::TryParse([string]$Value, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { return $n }
    return $null
}
function Want([string]$Name) { return ($Stage -contains 'All' -or $Stage -contains $Name) }
$script:credentials = $null
function Dax([string]$Query, [string]$User) {
    if (-not $User) { return Invoke-HnhDax -Server $Server -Database $Database -Query $Query }
    if ($script:credentials -eq $null) {
        if (-not (Test-Path $CredentialFile)) { throw "No credential file $CredentialFile (scripts/create_bi_windows_users.ps1 writes it)" }
        $script:credentials = Import-Clixml $CredentialFile
    }
    $key = @($script:credentials.Keys | Where-Object { $_ -eq $User })   # hashtable keys from Import-Clixml: case-insensitive match
    if ($key.Count -eq 0) { throw "No stored password for $User in $CredentialFile" }
    return Invoke-HnhDax -Server $Server -Database $Database -Query $Query -Credential $script:credentials[$key[0]]
}
function Sql([string]$Query) { return Invoke-HnhOdbc -Dsn $Dsn -Query $Query }
function ChString([string]$Value) { return "'" + $Value.Replace('\', '\\').Replace("'", "\'") + "'" }
function CountRows([string]$TableName, [string]$User) {
    return Get-HnhScalar (Dax ('EVALUATE ROW("n", COUNTROWS({0}))' -f (Format-HnhTableRef $TableName)) $User)
}

$srv = $null
try {
    $srv = Connect-HnhServer $Server
    $db = Get-HnhDatabase $srv $Database
    $tables = @($db.Model.Tables | Where-Object { (Get-HnhAnnotation $_ 'hnh_view') -ne $null })
    $facts = @($tables | Where-Object { (Get-HnhAnnotation $_ 'hnh_kind') -eq 'fact' })
    $payTables = @('Payroll', 'Leave Balances', 'Staff Productivity')
    $hasHrKpi = @($db.Model.Tables | Where-Object { $_.Name -eq 'HR KPI' }).Count -gt 0   # the HR dashboard tables are deployed
    $hasFinance = (@($db.Model.Tables | Where-Object { $_.Name -eq 'P&L Report' }).Count -gt 0) -and (@($db.Model.Tables | Where-Object { $_.Name -eq 'Finance KPI' }).Count -gt 0)   # the finance report tables are deployed
    $securityConfig = Get-Content (Join-Path $root 'tests\security.json') -Raw | ConvertFrom-Json

    if (Want 'RowCounts') {
        foreach ($t in $tables) {
            try {
                $view = Get-HnhAnnotation $t 'hnh_view'
                $inSsas = CountRows $t.Name $null
                $inCh = Get-HnhScalar (Sql "select count() from gold.$view")
                Report "rows $($t.Name)" ($inSsas -eq $inCh) "SSAS $inSsas, ClickHouse $inCh"
            } catch {
                Report "rows $($t.Name)" $false $_.Exception.Message
            }
        }
        try {
            $code = Get-HnhScalar (Dax 'EVALUATE ROW("c", UNICODE(MAXX(FILTER(Staff, NOT ISBLANK(Staff[Staff Name AR])), Staff[Staff Name AR])))' $null)
            Report 'arabic text' ($code -ge 1536 -and $code -le 1791) "first character code $code (Arabic block 1536-1791)"
        } catch {
            Report 'arabic text' $false $_.Exception.Message
        }
    }

    if (Want 'Security') {
        foreach ($p in $securityConfig.PSObject.Properties) {
            $login = [string]$p.Value
            if ([string]::IsNullOrWhiteSpace($login)) { Report "security $($p.Name)" $false 'login not set in ssas/tests/security.json'; continue }
            try {
                $grant = Sql ("select branch_key, ifNull(unified_specialty, '') as specialty, can_see_pay, can_see_pii from gold.ssas_sec_user_access where lower(login_name) = lower({0})" -f (ChString $login))
                $branches = @($grant.Rows | ForEach-Object { [int64]$_['branch_key'] } | Sort-Object -Unique)
                $specialties = @($grant.Rows | ForEach-Object { [string]$_['specialty'] } | Where-Object { $_ -ne '' } | Sort-Object -Unique)
                $allRestricted = ($grant.Rows.Count -gt 0) -and (@($grant.Rows | Where-Object { [string]$_['specialty'] -eq '' }).Count -eq 0)
                $pay = @($grant.Rows | Where-Object { [int64]$_['can_see_pay'] -eq 1 }).Count -gt 0
                $pii = @($grant.Rows | Where-Object { [int64]$_['can_see_pii'] -eq 1 }).Count -gt 0

                $seen = @((Dax 'EVALUATE VALUES(Branch[Branch Key])' $login).Rows | ForEach-Object { [int64]$_[0] } | Sort-Object -Unique)
                Report "$($p.Name) branches" (($seen -join ',') -eq ($branches -join ',')) "sees [$($seen -join ',')], granted [$($branches -join ',')]"

                if ($branches.Count -gt 0) {
                    $outside = Get-HnhScalar (Dax ('EVALUATE ROW("n", COUNTROWS(FILTER(Patient, Patient[Patient Key] <> -1 && NOT (Patient[Branch Key] IN {{ {0} }}))))' -f ($branches -join ', ')) $login)
                    Report "$($p.Name) patient filter" ($outside -eq 0) "$outside patients outside the user's branches"
                }

                if ($allRestricted) {
                    $list = ($specialties | ForEach-Object { '"' + $_.Replace('"', '""') + '"' }) -join ', '
                    $bad = Get-HnhScalar (Dax ('EVALUATE ROW("n", COUNTROWS(FILTER(Staff, Staff[Staff Key] <> -1 && NOT (Staff[Unified Specialty] IN {{ {0} }}))))' -f $list) $login)
                    Report "$($p.Name) specialty filter" ($bad -eq 0) "$bad staff rows outside [$($specialties -join ', ')]"
                }

                $payRows = CountRows 'Pay Category' $login
                Report "$($p.Name) pay" (($payRows -gt 0) -eq $pay) "pay categories visible: $payRows, can_see_pay: $pay"
                $piiRows = CountRows 'Patient Details' $login
                Report "$($p.Name) PII" (($piiRows -gt 0) -eq ($pii -and $branches.Count -gt 0)) "patient details visible: $piiRows, can_see_pii: $pii"
                $employeeRows = CountRows 'Employee Details' $login
                $employeeExpected = 0
                if ($pay -and $branches.Count -gt 0) {
                    $employeeExpected = Get-HnhScalar (Sql ('select count() from gold.ssas_dim_employee_pii where branch_key in ({0})' -f ($branches -join ',')))
                }
                Report "$($p.Name) employee names" ($employeeRows -eq $employeeExpected) "employee details visible: $employeeRows, expected $employeeExpected (can_see_pay: $pay)"

                if ($hasHrKpi) {
                    # HR dashboard final review C1: a pay KPI's target and watch value are pay levels. Without pay access
                    # they are blank and the texts say Requires pay access; with pay access the texts never do (and the notice is "").
                    $rpa = '"Requires pay access"'
                    if ($pay) { $want = "NOT EXACT([HR KPI Target Text], $rpa) && NOT EXACT([HR KPI Watch Text], $rpa) && EXACT([HR KPI Pay Notice], """")" }
                    else { $want = "ISBLANK([HR KPI Target]) && ISBLANK([HR KPI Watch]) && ISBLANK([HR KPI Variance]) && EXACT([HR KPI Target Text], $rpa) && EXACT([HR KPI Watch Text], $rpa) && EXACT([HR KPI Variance Text], $rpa) && EXACT([HR KPI Pay Notice], $rpa)" }
                    $payKpis = "CALCULATETABLE(VALUES('HR KPI'[KPI Code]), 'HR KPI'[Kind] = ""kpi"", 'HR KPI'[Needs Pay] = 1)"
                    $hrQuery = 'EVALUATE ROW("bad", COUNTROWS(FILTER({0}, CALCULATE(NOT ({1}), ''Date''[Year] = 2026))) + 0, "kpis", COUNTROWS({0}))' -f $payKpis, $want
                    $hrResult = (Dax $hrQuery $login).Rows[0]
                    Report "$($p.Name) HR pay targets" (([int64]$hrResult[0] -eq 0) -and ([int64]$hrResult[1] -gt 0)) "$($hrResult[0]) of $($hrResult[1]) pay KPIs show a target, watch or variance against can_see_pay: $pay"
                    # HNH Readers row filter (user decision 2026-11-04): the HR Targets rows of a pay KPI need Can See Pay,
                    # so a no-pay reader can't read the hidden target and watch columns through Excel or DAX either.
                    $payTargetRows = Get-HnhScalar (Dax 'EVALUATE ROW("n", COUNTROWS(FILTER(''HR Targets'', RELATED(''HR KPI''[Needs Pay]) = 1)) + 0)' $login)
                    $payTargetExpected = 0
                    if ($pay -and $branches.Count -gt 0) {
                        $payTargetExpected = Get-HnhScalar (Sql ('select count() from gold.ssas_fact_hr_target_monthly where branch_key in ({0}) and hr_kpi_key in (select hr_kpi_key from gold.ssas_dim_hr_kpi where needs_pay = 1)' -f ($branches -join ',')))
                    }
                    Report "$($p.Name) HR pay target rows" ($payTargetRows -eq $payTargetExpected) "pay KPI target rows visible: $payTargetRows, expected $payTargetExpected (can_see_pay: $pay)"
                }

                if ($hasFinance -and $branches.Count -eq 1) {
                    # Finance report review focus 5: a one-hospital reader sees the P&L of their hospital only. "All" (no branch
                    # filter) is their hospital, the other hospitals read blank, for [FR Actual] and for the EBITDA margin KPI.
                    $own = $branches[0]
                    # the "other" hospital is one that has NET_REVENUE rows, so a blank read is the row filter and not an empty branch
                    $otherKey = Get-HnhScalar (Sql ('select min(branch_key) from gold.ssas_fact_pl_report_monthly where pl_line_code = ''NET_REVENUE'' and branch_key between 1 and 8 and branch_key <> {0}' -f $own))
                    $plNet = "'P&L Line'[PL Line Code] = ""NET_REVENUE"""
                    $kpiMargin = "'Finance KPI'[KPI Code] = ""FR_EBITDA_MARGIN"""
                    $frExpected = Get-HnhScalar (Sql ("select sum(amount) from gold.ssas_fact_pl_report_monthly where pl_line_code = 'NET_REVENUE' and branch_key = $own and month_date_key <= toYYYYMMDD(today())"))
                    if ([string]::IsNullOrWhiteSpace([string]$otherKey) -or $otherKey -is [System.DBNull]) {
                        Skip "$($p.Name) FR Actual / KPI" "no other hospital has NET_REVENUE rows in gold.ssas_fact_pl_report_monthly"
                    } else {
                    $frQuery = 'EVALUATE ROW("own", CALCULATE([FR Actual], {0}, Branch[Branch Key] = {1}), "all", CALCULATE([FR Actual], {0}), "other", CALCULATE([FR Actual], {0}, Branch[Branch Key] = {2}) + 0)' -f $plNet, $own, $otherKey
                    $fr = (Dax $frQuery $login).Rows[0]
                    $frOwn = ConvertTo-HnhNumber $fr[0]; $frAll = ConvertTo-HnhNumber $fr[1]; $frOther = ConvertTo-HnhNumber $fr[2]
                    $expectedNum = ConvertTo-HnhNumber $frExpected
                    # a blank read is a FAIL; a SKIP when ClickHouse itself holds no NET_REVENUE for the own branch (nothing to compare)
                    if ($expectedNum -eq $null -or $expectedNum -eq 0) {
                        Skip "$($p.Name) FR Actual own branch" "ClickHouse holds no NET_REVENUE for branch $own (expected $frExpected); nothing to compare"
                    } else {
                        Report "$($p.Name) FR Actual own branch" (($frOwn -ne $null) -and [math]::Abs($frOwn - $expectedNum) -le 0.01) "branch $own sees '$($fr[0])', ClickHouse $frExpected"
                    }
                    Report "$($p.Name) FR Actual All is the own branch" (($frOwn -ne $null) -and ($frAll -ne $null) -and [math]::Abs($frAll - $frOwn) -le 0.01) "all branches '$($fr[1])', own branch '$($fr[0])'"
                    Report "$($p.Name) FR Actual other branch blank" (($frOther -eq $null) -or ($frOther -eq 0)) "branch $otherKey reads '$($fr[2])' (0 means blank)"
                    $kpiQuery = 'EVALUATE ROW("own", CALCULATE([FR KPI Value], {0}, Branch[Branch Key] = {1}), "all", CALCULATE([FR KPI Value], {0}), "other", CALCULATE([FR KPI Value], {0}, Branch[Branch Key] = {2}))' -f $kpiMargin, $own, $otherKey
                    $kpi = (Dax $kpiQuery $login).Rows[0]
                    $kpiOwn = ConvertTo-HnhNumber $kpi[0]; $kpiAll = ConvertTo-HnhNumber $kpi[1]
                    $kpiOk = ($kpiOwn -ne $null) -and ($kpiAll -ne $null) -and ([math]::Abs($kpiAll - $kpiOwn) -le 0.000001) -and [string]::IsNullOrWhiteSpace([string]$kpi[2])
                    Report "$($p.Name) FR KPI Value EBITDA margin" $kpiOk "own '$($kpi[0])', all '$($kpi[1])', branch $otherKey '$($kpi[2])' (must be blank)"
                    }
                }

                if ($specialties.Count -eq 0) {
                    # Review focus 1: every fact row of the user's branches is visible (no orphan keys hidden by a row filter).
                    foreach ($f in $facts) {
                        try {
                            $view = Get-HnhAnnotation $f 'hnh_view'
                            if ($branches.Count -eq 0 -or (($payTables -contains $f.Name) -and -not $pay)) { $expected = 0 }
                            elseif ($f.Name -eq 'HR Targets' -and -not $pay) {
                                $expected = Get-HnhScalar (Sql ('select count() from gold.{0} where branch_key in ({1}) and hr_kpi_key in (select hr_kpi_key from gold.ssas_dim_hr_kpi where needs_pay = 0)' -f $view, ($branches -join ',')))
                            }
                            else { $expected = Get-HnhScalar (Sql ('select count() from gold.{0} where branch_key in ({1})' -f $view, ($branches -join ','))) }
                            $got = CountRows $f.Name $login
                            Report "$($p.Name) rows $($f.Name)" ($got -eq $expected) "sees $got, expected $expected"
                        } catch {
                            Report "$($p.Name) rows $($f.Name)" $false $_.Exception.Message
                        }
                    }
                }
            } catch {
                Report "security $($p.Name)" $false $_.Exception.Message
            }
        }
    }

    if (Want 'Measures') {
        foreach ($file in Get-ChildItem (Join-Path $root 'tests\measures') -Filter *.json) {
            foreach ($check in (Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json)) {
                try {
                    $value = Get-HnhScalar (Dax $check.dax $null)
                    $expected = Get-HnhScalar (Sql $check.sql)
                    # Review focus 1 (KPI catalogue plan): blank becomes 0, so two zeros prove nothing unless blank is the answer.
                    $bothZero = ($value -eq 0) -and ($expected -eq 0) -and -not $check.allow_zero
                    $detail = "SSAS $value, ClickHouse $expected"
                    if ($bothZero) { $detail += ' (both zero: pick a filter with data, or set allow_zero)' }
                    Report "measure $($check.name)" ((-not $bothZero) -and ([math]::Abs($value - $expected) -le [double]$check.tolerance)) $detail
                } catch {
                    Report "measure $($check.name)" $false $_.Exception.Message
                }
            }
        }
    }

    if (Want 'Performance') {
        $user = [string]$securityConfig.single_branch
        if ([string]::IsNullOrWhiteSpace($user)) { Report 'performance user' $false 'single_branch not set in ssas/tests/security.json' }
        else {
            $clear = '<ClearCache xmlns="http://schemas.microsoft.com/analysisservices/2003/engine"><Object><DatabaseID>{0}</DatabaseID></Object></ClearCache>' -f $db.ID
            foreach ($check in (Get-Content (Join-Path $root 'tests\performance.json') -Raw -Encoding UTF8 | ConvertFrom-Json)) {
                try {
                    # Server.Execute does not throw on XMLA errors; a rejected ClearCache would make the cold timing a warm one.
                    $result = $srv.Execute($clear)
                    if ($result.ContainsErrors) {
                        $messages = @($result | ForEach-Object { $_.Messages } | ForEach-Object { $_.Description }) -join '; '
                        Report "speed $($check.name)" $false "ClearCache failed: $messages"
                        continue
                    }
                    $watch = [Diagnostics.Stopwatch]::StartNew()
                    [void](Dax $check.dax $user)
                    $cold = $watch.Elapsed.TotalSeconds
                    $watch.Restart()
                    [void](Dax $check.dax $user)
                    $warm = $watch.Elapsed.TotalSeconds
                    Report "speed $($check.name)" (Test-HnhSpeed -Cold $cold -Warm $warm -Check $check) ('cold {0:N2} s, warm {1:N2} s (connection included)' -f $cold, $warm)
                } catch {
                    Report "speed $($check.name)" $false $_.Exception.Message
                }
            }
        }
    }

    if (Want 'Size') {
        $srv.Disconnect()
        $srv = Connect-HnhServer $Server
        $db = Get-HnhDatabase $srv $Database
        $gb = $db.EstimatedSize / 1GB
        Report 'model size' ($gb -le 10) ('{0:N2} GB (budget 10 GB)' -f $gb)
    }
} catch {
    # A failure outside the per-check handlers (connection, model read) still ends with the summary and a non-zero exit.
    Report 'test run' $false $_.Exception.Message
} finally {
    if ($srv -ne $null) { $srv.Disconnect() }
    Write-Host "$($script:failures) failure(s)"
    Stop-Transcript | Out-Null
}
if ($script:failures -gt 0) { exit 1 }
exit 0
