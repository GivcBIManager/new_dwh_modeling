# Dry run of apply_policy_config.ps1: it parses the DDL and the seed without connecting to ClickHouse.
#   powershell -NoProfile -Command "Invoke-Pester -Script scripts\policy_config\ApplyPolicyConfig.Tests.ps1"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Describe 'apply_policy_config.ps1 -DryRun' {
    $out = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'apply_policy_config.ps1') -DryRun 6>&1 2>&1) -join "`n"
    It 'creates the one config table' {
        ([regex]::Matches($out, 'CREATE TABLE IF NOT EXISTS default\.map_policy_client')).Count | Should Be 1
    }
    It 'names the two seed statements' {
        ([regex]::Matches($out, 'default\.map_policy_client: INSERT \.\.\. SELECT from')).Count | Should Be 2
        $out | Should Match 'from default\.map_referral_policies'
    }
    It 'writes nothing' {
        $out | Should Match '\(dry run\) nothing written'
    }
}
