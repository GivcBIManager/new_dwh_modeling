# build_hr_placeholders.ps1 with -Values (no SSAS query): the placeholder target rows and the pay-gated leave metric rows.
#   powershell -NoProfile -Command "Invoke-Pester -Script scripts\hr_config\BuildHrPlaceholders.Tests.ps1"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:dash = [string][char]0x2013

function Invoke-Build([string]$Json) {
    $out = Join-Path ([IO.Path]::GetTempPath()) ("hr_ph_{0}.sql" -f [guid]::NewGuid().ToString('N'))
    try {
        & (Join-Path $here 'build_hr_placeholders.ps1') -Out $out -Values $Json 6>&1 | Out-Null
        return [IO.File]::ReadAllText($out)
    } finally { if (Test-Path $out) { Remove-Item $out -Force } }
}
function Get-InsertRows([string]$Sql, [string]$Table) {
    $stmt = ($Sql -split ';\s*\r?\n') | Where-Object { $_ -match "INSERT INTO default\.$Table " } | Select-Object -First 1
    return @($stmt -split "`r?`n" | Where-Object { $_ -match '^\s{4}\(' })
}

Describe 'build_hr_placeholders.ps1' {
    $sql = Invoke-Build '{"HR_TURNOVER":0.045,"HR_SAUDIZATION":0.342}'
    $rows = Get-InsertRows $sql 'map_hr_target'

    It 'writes 4 target rows: 2 KPIs by 2 years' {
        $rows.Count | Should Be 4
    }
    It 'annualises a flow KPI (x 12/9) and sets the watch 10 percent worse' {
        ($rows | Where-Object { $_ -match "'HR_TURNOVER', 0, 2026, 0, 0\.06, 0\.066, 1," }).Count | Should Be 1
        ($rows | Where-Object { $_ -match "'HR_TURNOVER', 0, 2027, 0, 0\.06, 0\.066, 1," }).Count | Should Be 1
    }
    It 'keeps a stock KPI and sets the higher-is-better watch at x 0.9' {
        ($rows | Where-Object { $_ -match "'HR_SAUDIZATION', 0, 2026, 0, 0\.342, 0\.308, 0," }).Count | Should Be 1
    }
    It 'marks every row as a placeholder from the seed user' {
        ($rows | Where-Object { $_.Contains("'Placeholder $($script:dash) HR to confirm'") -and $_ -match "'seed'" }).Count | Should Be 4
    }
    It 're-inserts the three leave balance metrics with needs_pay = 1' {
        $k = Get-InsertRows $sql 'map_hr_kpi'
        $k.Count | Should Be 3
        foreach ($c in 'HR_M_LEAVE_BALANCE', 'HR_M_CURRENT_LEAVE_BALANCE', 'HR_M_AVERAGE_LEAVE_BALANCE') {
            ($k | Where-Object { $_ -match "^\s{4}\('$c', 'metric'," -and $_ -match "'none', 1, 0, 'active', now64\(3\), 'seed', 'Leave Balances is pay-gated by role', 0\)" }).Count | Should Be 1
        }
    }
    It 'ends each statement so apply_hr_config.ps1 can split them' {
        $sql | Should Match ';\s*\r?\n'
    }
}

Describe 'build_hr_placeholders.ps1 additive KPIs' {
    $sql = Invoke-Build '{"HR_HEADCOUNT":{"1":812.4,"2":1500,"3":2000},"HR_LEAVE_LIABILITY":{"1":1234567.5},"HR_STAFF_COST_PER_FTE":9000,"HR_VACANCY_RATE":null}'
    $rows = Get-InsertRows $sql 'map_hr_target'

    It 'writes one row per hospital and year, and no network row' {
        ($rows | Where-Object { $_ -match "'HR_HEADCOUNT'" }).Count | Should Be 6
        ($rows | Where-Object { $_ -match "'HR_HEADCOUNT', 0," }).Count | Should Be 0
        ($rows | Where-Object { $_ -match "'HR_LEAVE_LIABILITY', 1, 2027, 0, 1234568, 1358025, 0," }).Count | Should Be 1
    }
    It 'rounds a count to a whole number, on target with a watch 10 percent worse' {
        ($rows | Where-Object { $_ -match "'HR_HEADCOUNT', 1, 2026, 0, 812, 893, 0," }).Count | Should Be 1
    }
    It 'annualises staff cost per FTE and rounds to whole SAR' {
        ($rows | Where-Object { $_ -match "'HR_STAFF_COST_PER_FTE', 0, 2026, 0, 12000, 13200, 1," }).Count | Should Be 1
    }
    It 'skips a blank KPI' {
        ($rows | Where-Object { $_ -match "'HR_VACANCY_RATE'" }).Count | Should Be 0
    }
}
