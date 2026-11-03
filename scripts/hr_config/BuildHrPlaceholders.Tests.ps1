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
function Split-Tuple([string]$Line) {
    # Raw SQL tokens of one VALUES row, as build_hr_placeholders.ps1 splits them
    return @([regex]::Matches($Line.Trim().TrimEnd(',', ';'), "'(?:\\.|[^'\\])*'|now64\(\d+\)|-?[\d.]+") | ForEach-Object { $_.Value })
}
function Get-SeedKpiRows([string]$Text) {
    # code token ('HR_X') -> tokens of its map_hr_kpi row in a seed text
    $out = @{}; $in = $false
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '^\s*--') { continue }
        if ($line -match '^INSERT INTO default\.(\w+)') { $in = ($Matches[1] -eq 'map_hr_kpi'); continue }
        if ($in -and $line -match '^\s{4}\(') { $t = Split-Tuple $line; $out[$t[0]] = $t }
    }
    return $out
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
        ($rows | Where-Object { $_ -match "'HR_SAUDIZATION', 0, 2026, 0, 0\.342, 0\.3078, 0," }).Count | Should Be 1
    }
    It 'marks every row as a placeholder from the seed user' {
        ($rows | Where-Object { $_.Contains("'Placeholder $($script:dash) HR to confirm'") -and $_ -match "'seed'" }).Count | Should Be 4
    }
    It 're-inserts the three leave balance metrics with needs_pay = 1' {
        $k = Get-InsertRows $sql 'map_hr_kpi'
        foreach ($c in 'HR_M_LEAVE_BALANCE', 'HR_M_CURRENT_LEAVE_BALANCE', 'HR_M_AVERAGE_LEAVE_BALANCE') {
            ($k | Where-Object { $_ -match "^\s{4}\('$c', 'metric'," -and $_ -match "'none', 1, 0, 'active', now64\(3\), 'seed', 'Leave Balances is pay-gated by role(; wording: branches include Head Office)?', 0\)" }).Count | Should Be 1
        }
    }
    It 're-inserts the reworded KPI rows as the seed has them now, once per code (minor 3c)' {
        $k = Get-InsertRows $sql 'map_hr_kpi'
        $seed = Get-SeedKpiRows ([IO.File]::ReadAllText((Join-Path $here 'hr_config_seed.sql')))
        $codes = @($k | ForEach-Object { (Split-Tuple $_)[0] })
        $codes.Count | Should Be 21  # 3 pay-gated + 19 reworded, HR_M_LEAVE_BALANCE in both
        @($codes | Select-Object -Unique).Count | Should Be $codes.Count
        foreach ($line in $k) {
            $t = Split-Tuple $line
            $s = $seed[$t[0]]
            $pay = $t[0] -in "'HR_M_LEAVE_BALANCE'", "'HR_M_CURRENT_LEAVE_BALANCE'", "'HR_M_AVERAGE_LEAVE_BALANCE'"
            for ($i = 0; $i -lt $s.Count; $i++) {
                if ($i -eq 21 -or ($i -eq 16 -and $pay)) { continue }
                "$($t[0]) $i $($t[$i])" | Should Be "$($t[0]) $i $($s[$i])"
            }
            if (-not $pay) { $t[21] | Should Be "'wording: branches include Head Office'" }
        }
        ($k | Where-Object { $_ -match "^\s{4}\('HR_TURNOVER', 'kpi',.*'Branch, month'.*'wording: branches include Head Office', 0\)" }).Count | Should Be 1
        ($k | Where-Object { $_ -match "^\s{4}\('HR_M_LEAVE_BALANCE',.* per branch: .*'Leave Balances is pay-gated by role; wording: branches include Head Office', 0\)" }).Count | Should Be 1
    }
    It 'ends each statement so apply_hr_config.ps1 can split them' {
        $sql | Should Match ';\s*\r?\n'
    }
}

Describe 'build_hr_placeholders.ps1 additive KPIs' {
    $sql = Invoke-Build '{"HR_HEADCOUNT":{"1":812.4,"2":1500,"3":2000,"100":148},"HR_LEAVE_LIABILITY":{"1":1234567.5},"HR_STAFF_COST_PER_FTE":9000,"HR_VACANCY_RATE":null}'
    $rows = Get-InsertRows $sql 'map_hr_target'

    It 'writes one row per branch and year, Head Office (100) included, and no network row' {
        ($rows | Where-Object { $_ -match "'HR_HEADCOUNT'" }).Count | Should Be 8
        ($rows | Where-Object { $_ -match "'HR_HEADCOUNT', 0," }).Count | Should Be 0
        ($rows | Where-Object { $_ -match "'HR_HEADCOUNT', 100, 2026, 0, 148, 163, 0," }).Count | Should Be 1
        ($rows | Where-Object { $_ -match "'HR_LEAVE_LIABILITY', 1, 2027, 0, 1234568, 1358024, 0," }).Count | Should Be 1
    }
    It 'refuses a branch 0 value for an additive KPI (branch_id 0 means every branch)' {
        { Invoke-Build '{"HR_HEADCOUNT":{"0":4300,"1":800}}' } | Should Throw
    }
    It 'rounds a count to a whole number, on target with a watch 10 percent worse' {
        ($rows | Where-Object { $_ -match "'HR_HEADCOUNT', 1, 2026, 0, 812, 894, 0," }).Count | Should Be 1
    }
    It 'annualises staff cost per FTE and rounds to whole SAR' {
        ($rows | Where-Object { $_ -match "'HR_STAFF_COST_PER_FTE', 0, 2026, 0, 12000, 13200, 1," }).Count | Should Be 1
    }
    It 'keeps 2 decimals under 100 and rounds a SAR value of 100 or more to whole numbers' {
        $s2 = Invoke-Build '{"HR_STAFF_TO_BED":1.60,"HR_REVENUE_PER_DOCTOR":1191353.9495,"HR_VISITS_PER_FTE":99.994}'
        $r2 = Get-InsertRows $s2 'map_hr_target'
        ($r2 | Where-Object { $_ -match "'HR_STAFF_TO_BED', 0, 2026, 0, 1\.6, 1\.76, 0," }).Count | Should Be 1
        ($r2 | Where-Object { $_ -match "'HR_VISITS_PER_FTE', 0, 2026, 0, 99\.99, 89\.99, 0," }).Count | Should Be 1
    }
    It 'annualises revenue per doctor, a flow KPI (final review C2: Sep 75,278, Jan-Sep 1,191,354)' {
        $s4 = Invoke-Build '{"HR_REVENUE_PER_DOCTOR":1191353.9495}'
        $r4 = Get-InsertRows $s4 'map_hr_target'
        $r4.Count | Should Be 2
        ($r4 | Where-Object { $_ -match "'HR_REVENUE_PER_DOCTOR', 0, 2026, 0, 1588472, 1429625, 1," }).Count | Should Be 1
        ($r4 | Where-Object { $_ -match "'HR_REVENUE_PER_DOCTOR', 0, 2027, 0, 1588472, 1429625, 1," }).Count | Should Be 1
    }
    It 'rounds a pct to 4 decimals' {
        $s3 = Invoke-Build '{"HR_SICK_LEAVE_RATE":0.0014491631757735921}'
        ((Get-InsertRows $s3 'map_hr_target') | Where-Object { $_ -match "'HR_SICK_LEAVE_RATE', 0, 2026, 0, 0\.0014, 0\.0016, 0," }).Count | Should Be 1
    }
    It 'skips a blank KPI' {
        ($rows | Where-Object { $_ -match "'HR_VACANCY_RATE'" }).Count | Should Be 0
    }
}

# Final review M4: the builder's KPI lists stay in step with the model and the seed (C2 was a flow KPI missing here).
Describe 'build_hr_placeholders.ps1 KPI lists' {
    $root = Split-Path (Split-Path $here -Parent) -Parent
    $script = [IO.File]::ReadAllText((Join-Path $here 'build_hr_placeholders.ps1'))
    function Get-ScriptList([string]$Name) {
        $m = [regex]::Match($script, '(?m)^\$' + $Name + ' = @\(([^)]*)\)')
        return @([regex]::Matches($m.Groups[1].Value, "'([A-Z_]+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
    }
    # The nature of every active fixed KPI of hr_config_seed.sql, checked 2026-11-03 on HNH_Analytics_Test by the
    # value of Sep 2026 against Jan-Sep 2026 (hospitals; final-fix-report.md has the table):
    #   flow      grows with the months (a sum over the months): the builder annualises it, scale_with_months = 1
    #   ratio     a ratio or average of the months, about the size of one month
    #   snapshot  the last closed month of the period (hnh_snapshot = 1 or the Time Calculation snapshot list)
    # A new fixed KPI fails 'classifies every fixed KPI' until it is added here with its nature.
    $Nature = @{
        HR_HEADCOUNT = 'snapshot'; HR_CONTINGENT_SHARE = 'snapshot'; HR_SAUDIZATION = 'snapshot'; HR_FEMALE_SHARE = 'snapshot'
        HR_LEAVE_LIABILITY = 'snapshot'; HR_VACANCY_RATE = 'snapshot'
        HR_TURNOVER = 'flow'; HR_NEW_HIRE_TURNOVER = 'flow'; HR_STAFF_COST_PER_FTE = 'flow'; HR_REVENUE_PER_DOCTOR = 'flow'
        HR_OVERTIME_SHARE = 'ratio'; HR_SICK_LEAVE_RATE = 'ratio'; HR_TIME_TO_FILL = 'ratio'; HR_STAFF_TO_BED = 'ratio'
        HR_CLINICAL_TO_DOCTOR = 'ratio'; HR_VISITS_PER_FTE = 'ratio'; HR_REVENUE_PER_PAYROLL_SAR = 'ratio'
    }
    $fixed = @([regex]::Matches([IO.File]::ReadAllText((Join-Path $here 'hr_config_seed.sql')),
            "(?m)^\s{4}\('([A-Z_]+)', 'kpi',.*?, '(fixed|bsc|none)', \d, \d, '(active|parked)',") |
        Where-Object { $_.Groups[2].Value -eq 'fixed' -and $_.Groups[3].Value -eq 'active' } |
        ForEach-Object { $_.Groups[1].Value } | Sort-Object)

    It 'finds the fixed KPIs of the seed' {
        $fixed.Count | Should Be 17
    }
    It 'classifies every fixed KPI of the seed' {
        @($fixed | Where-Object { -not $Nature.ContainsKey($_) }) -join ', ' | Should Be ''
    }
    It 'annualises exactly the flow KPIs ($FlowKpis)' {
        (Get-ScriptList 'FlowKpis') -join ', ' | Should Be ((@($Nature.Keys | Where-Object { $Nature[$_] -eq 'flow' }) | Sort-Object) -join ', ')
    }
    It 'queries every branch, Head Office included: no Is Hospital filter (user decision 2026-11-03)' {
        $script | Should Not Match 'Is Hospital'
        $script | Should Match 'Branch\[Branch Key\] <> 0'
    }
    It 'leaves out Group (0) in the non-additive query too, as the additive path (minor 3f)' {
        $script | Should Match "\`$n = Get-DaxValue \`$k\.Measure 'Branch\[Branch Key\] <> 0'"
        $script | Should Not Match '(?m)^\s*\$n = Get-DaxValue \$k\.Measure\s*$'
    }
    It 'lists in $WordingKpis exactly the rows whose text differs from the seed as loaded at GATE G1 (4119ad1)' {
        $loaded = (& git -C $root show '4119ad1:scripts/hr_config/hr_config_seed.sql') -join "`n"
        if ($LASTEXITCODE -ne 0) { throw 'git show 4119ad1 failed' }
        $was = Get-SeedKpiRows $loaded
        $now = Get-SeedKpiRows ([IO.File]::ReadAllText((Join-Path $here 'hr_config_seed.sql')))
        $changed = @($now.Keys | Where-Object { ($now[$_] -join '|') -ne ($was[$_] -join '|') } | ForEach-Object { $_.Trim("'") } | Sort-Object)
        $changed.Count | Should Be 19
        (Get-ScriptList 'WordingKpis') -join ', ' | Should Be ($changed -join ', ')
    }
    It 'leaves no hospital wording in a seed Grain or definition, but the hospitals 1 to 5 / 6 to 8 of turnover' {
        $now = Get-SeedKpiRows ([IO.File]::ReadAllText((Join-Path $here 'hr_config_seed.sql')))
        foreach ($code in $now.Keys) {
            foreach ($i in 5, 8) {
                $text = $now[$code][$i] -replace 'hospitals \d to \d', ''
                "$code $text" | Should Not Match '(?i)hospital'
            }
        }
    }
    It 'writes per-branch rows for the codes of measure HR KPI Is Additive ($AdditiveKpis)' {
        $measures = [IO.File]::ReadAllText((Join-Path $root 'ssas\HNH_Analytics\tables\_Measures.tmdl'))
        $block = [regex]::Match($measures, "(?s)measure 'HR KPI Is Additive' =.*?IN \{([^}]*)\}")
        $block.Success | Should Be $true
        $dax = @([regex]::Matches($block.Groups[1].Value, '"([A-Z_]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
        $dax.Count | Should BeGreaterThan 0
        (Get-ScriptList 'AdditiveKpis') -join ', ' | Should Be ($dax -join ', ')
    }
}
