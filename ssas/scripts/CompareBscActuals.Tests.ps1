# compare_bsc_actuals.ps1 with -Values (no SSAS query) and -Compare -PassThru on inline tables.
#   powershell -NoProfile -Command "Invoke-Pester -Script ssas\scripts\CompareBscActuals.Tests.ps1"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $here 'compare_bsc_actuals.ps1'

function New-TempCsv([string[]]$Lines) {
    $f = Join-Path ([IO.Path]::GetTempPath()) ("bsc_cmp_{0}.csv" -f [guid]::NewGuid().ToString('N'))
    [IO.File]::WriteAllText($f, ($Lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding $false))
    return $f
}

Describe 'compare_bsc_actuals.ps1 -Out' {
    $out = Join-Path ([IO.Path]::GetTempPath()) ("bsc_out_{0}.csv" -f [guid]::NewGuid().ToString('N'))
    try {
        $json = '[{"kpi_code":"FIN_ROA","hospital":2,"actual":0.0123456789,"target":null},' +
                '{"kpi_code":"FIN_NET_REVENUE","hospital":6,"actual":12345678.5,"target":13000000},' +
                '{"kpi_code":"FIN_NET_REVENUE","hospital":1,"actual":null,"target":null},' +
                '{"kpi_code":"FIN_EBITDA","hospital":3,"actual":"\"BSC Actual\" can''t be analysed by Branch","target":-5}]'
        & $script -Out $out -Values $json 6>&1 | Out-Null
        $lines = @([IO.File]::ReadAllLines($out))
    } finally { if (Test-Path $out) { Remove-Item $out -Force } }

    It 'writes the header kpi_code,hospital,actual,target and one row per pair' {
        $lines[0] | Should Be 'kpi_code,hospital,actual,target'
        $lines.Count | Should Be 5
    }
    It 'sorts by KPI code, then hospital' {
        $lines[1] | Should Match '^FIN_EBITDA,3,'
        $lines[2] | Should Match '^FIN_NET_REVENUE,1,'
        $lines[3] | Should Match '^FIN_NET_REVENUE,6,'
        $lines[4] | Should Match '^FIN_ROA,2,'
    }
    It 'writes invariant round-trip numbers and blanks as empty' {
        $lines[3] | Should Be 'FIN_NET_REVENUE,6,12345678.5,13000000'
        $lines[2] | Should Be 'FIN_NET_REVENUE,1,,'
        $lines[4] | Should Be 'FIN_ROA,2,0.0123456789,'
    }
    It 'writes a text value (a guard message) as empty, never as text' {
        $lines[1] | Should Be 'FIN_EBITDA,3,,-5'
    }
}

Describe 'compare_bsc_actuals.ps1 -Compare' {
    $before = New-TempCsv @(
        'kpi_code,hospital,actual,target',
        'FIN_EBITDA_MARGIN,1,0.10,0.2',
        'FIN_EBITDA_MARGIN,2,0.20,0.2',
        'FIN_NET_REVENUE,1,1000,900',
        'FIN_ROA,1,,0.05',
        'FIN_GA_RATIO,1,0,0.1',
        'FIN_OPEX_RATIO,1,0.5,0.3'
    )
    $after = New-TempCsv @(
        'kpi_code,hospital,actual,target',
        'FIN_EBITDA_MARGIN,1,0.11,0.2',
        'FIN_EBITDA_MARGIN,2,0.15,0.25',
        'FIN_NET_REVENUE,1,1000,900',
        'FIN_ROA,1,0.01,0.05',
        'FIN_GA_RATIO,1,0.2,0.1',
        'FIN_DAYS_AR,3,45,'
    )
    try {
        $rows = @(& $script -Compare "$before,$after" -PassThru)
        $targets = @(& $script -Compare $before, $after -Measure target -PassThru)
    } finally { Remove-Item $before, $after -Force }

    It 'lists only the pairs that differ, with kpi_code, hospital, before, after, change_pct' {
        $rows.Count | Should Be 6
        ($rows[0].PSObject.Properties.Name -join ',') | Should Be 'kpi_code,hospital,before,after,change_pct'
        @($rows | Where-Object { $_.kpi_code -eq 'FIN_NET_REVENUE' }).Count | Should Be 0
    }
    It 'puts appearing, vanishing and from-zero pairs first (no change %), then sorts by |change %|' {
        @($rows[0..3] | ForEach-Object { $_.change_pct -eq $null }) -contains $false | Should Be $false
        @($rows[0..3] | ForEach-Object { "$($_.kpi_code)|$($_.hospital)" } | Sort-Object) -join ' ' |
            Should Be 'FIN_DAYS_AR|3 FIN_GA_RATIO|1 FIN_OPEX_RATIO|1 FIN_ROA|1'
        $rows[4].kpi_code | Should Be 'FIN_EBITDA_MARGIN'
        $rows[4].hospital | Should Be 2
        [Math]::Round($rows[4].change_pct, 6) | Should Be -0.25
        $rows[5].hospital | Should Be 1
        [Math]::Round($rows[5].change_pct, 6) | Should Be 0.1
    }
    It 'shows blank as empty in before / after' {
        $roa = $rows | Where-Object { $_.kpi_code -eq 'FIN_ROA' }
        $roa.before | Should Be ''
        $roa.after | Should Be '0.01'
        $opex = $rows | Where-Object { $_.kpi_code -eq 'FIN_OPEX_RATIO' }
        $opex.after | Should Be ''
    }
    It 'compares the target column with -Measure target' {
        $targets.Count | Should Be 2
        $targets[0].kpi_code | Should Be 'FIN_OPEX_RATIO'
        $targets[0].after | Should Be ''
        $targets[1].kpi_code | Should Be 'FIN_EBITDA_MARGIN'
        $targets[1].before | Should Be '0.2'
        $targets[1].after | Should Be '0.25'
        [Math]::Round($targets[1].change_pct, 6) | Should Be 0.25
    }
}
