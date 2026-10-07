<#
.SYNOPSIS
  Row-count, security, measure, performance and size tests of a deployed HNH_Analytics database (SSAS spec 11).
  Run as an SSAS administrator on HNHANALYTICSSRV. Exit 0 = all passed, 1 = at least one failure.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ssas\scripts\test.ps1 -Database HNH_Analytics_Test
#>
param(
    [string]$Server = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [Parameter(Mandatory = $true)][string]$Database,
    [string]$Dsn = 'HNH_Gold',
    [string]$TabularEditorDir = 'C:\Program Files (x86)\Tabular Editor',
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
function Want([string]$Name) { return ($Stage -contains 'All' -or $Stage -contains $Name) }
function Dax([string]$Query, [string]$User) { return Invoke-HnhDax -Server $Server -Database $Database -Query $Query -EffectiveUserName $User }
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

                if ($specialties.Count -eq 0) {
                    # Review focus 1: every fact row of the user's branches is visible (no orphan keys hidden by a row filter).
                    foreach ($f in $facts) {
                        try {
                            $view = Get-HnhAnnotation $f 'hnh_view'
                            if ($branches.Count -eq 0 -or (($payTables -contains $f.Name) -and -not $pay)) { $expected = 0 }
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
                    Report "measure $($check.name)" ([math]::Abs($value - $expected) -le [double]$check.tolerance) "SSAS $value, ClickHouse $expected"
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
                    Report "speed $($check.name)" ($cold -lt 3 -and $warm -lt 1) ('cold {0:N2} s, warm {1:N2} s (connection included)' -f $cold, $warm)
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
