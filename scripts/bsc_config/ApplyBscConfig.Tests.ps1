# Dry run of apply_bsc_config.ps1: it parses the DDL and the seed without connecting to ClickHouse.
#   powershell -NoProfile -Command "Invoke-Pester -Script scripts\bsc_config\ApplyBscConfig.Tests.ps1"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe 'apply_bsc_config.ps1 -DryRun' {
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'apply_bsc_config.ps1') -DryRun 6>&1 2>&1) -join "`n"
    It 'creates the 12 config tables' {
        ([regex]::Matches($out, 'CREATE TABLE IF NOT EXISTS default\.map_bsc_\w+')).Count | Should Be 12
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

Describe 'apply_bsc_config.ps1 -DryRun -Update' {
    $upd = Join-Path $here 'bsc_config_update_2026-10-21.sql'
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'apply_bsc_config.ps1') -DryRun -Update $upd 6>&1 2>&1) -join "`n"
    It 'lists the update rows and writes nothing' {
        $out | Should Match 'update default\.map_bsc_parameter: 3 rows'
        $out | Should Match 'update default\.map_bsc_kpi: 11 rows'
        $out | Should Match 'update default\.map_bsc_licensed_beds: INSERT \.\.\. SELECT from gold\.dim_branch'
        $out | Should Match '\(dry run\) nothing written'
    }
}

Describe 'update of 2026-10-21' {
    It 'formats KPI 13 (NPS points) as a number, not a percentage' {
        $line = (Get-Content (Join-Path $here 'bsc_config_update_2026-10-21.sql') | Where-Object { $_ -match "^\s+\('CUS_PATIENT_SATISFACTION'" })
        $line | Should Match "'higher', 'num',"
    }
}
