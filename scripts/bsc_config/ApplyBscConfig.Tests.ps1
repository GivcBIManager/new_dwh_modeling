# Dry run of apply_bsc_config.ps1: it parses the DDL and the seed without connecting to ClickHouse.
#   powershell -NoProfile -Command "Invoke-Pester -Script scripts\bsc_config\ApplyBscConfig.Tests.ps1"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe 'apply_bsc_config.ps1 -DryRun' {
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'apply_bsc_config.ps1') -DryRun 6>&1 2>&1) -join "`n"
    It 'creates the 10 config tables' {
        ([regex]::Matches($out, 'CREATE TABLE IF NOT EXISTS default\.map_bsc_\w+')).Count | Should Be 10
    }
    It 'counts the seed rows per table' {
        $out | Should Match 'default\.map_bsc_kpi: 70 rows'
        $out | Should Match 'default\.map_bsc_objective: 17 rows'
        $out | Should Match 'default\.map_bsc_hospital_category: 8 rows'
        $out | Should Match 'default\.map_bsc_manual_value: INSERT \.\.\. SELECT from default\.bsc_patient_satisfaction'
    }
    It 'writes nothing' {
        $out | Should Match '\(dry run\) nothing written'
    }
}
