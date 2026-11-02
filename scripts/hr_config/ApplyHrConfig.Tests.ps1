# Dry run of apply_hr_config.ps1: it parses the DDL and the seed without connecting to ClickHouse.
#   powershell -NoProfile -Command "Invoke-Pester -Script scripts\hr_config\ApplyHrConfig.Tests.ps1"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe 'apply_hr_config.ps1 -DryRun' {
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'apply_hr_config.ps1') -DryRun 6>&1 2>&1) -join "`n"
    It 'creates the 3 config tables' {
        ([regex]::Matches($out, 'CREATE TABLE IF NOT EXISTS default\.map_hr_\w+')).Count | Should Be 3
    }
    It 'counts the seed rows per table' {
        $out | Should Match 'default\.map_hr_kpi: 33 rows'
        $out | Should Match 'default\.map_hr_dq_issue: 19 rows'
    }
    It 'writes nothing' {
        $out | Should Match '\(dry run\) nothing written'
    }
}
