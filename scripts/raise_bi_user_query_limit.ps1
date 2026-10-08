<#
.SYNOPSIS
  Raise max_execution_time of the ClickHouse settings profile readonly_profile (used only by bi_user, the login of
  the HNH_Gold DSN) from 600 to 3600 seconds, so SSAS can load a full year partition (spec O-S6, P24).
  Run in Windows PowerShell on HNHANALYTICSSRV; it asks for a ClickHouse user that may alter settings profiles:
    powershell -ExecutionPolicy Bypass -File scripts\raise_bi_user_query_limit.ps1
#>
param(
    [string]$Url = 'http://172.22.25.214:8123/',
    [int]$Seconds = 3600
)
$ErrorActionPreference = 'Stop'
$admin = Get-Credential -Message 'ClickHouse admin user (for example default)'
if (-not $admin) { throw 'No credential entered' }
$headers = @{
    'X-ClickHouse-User' = $admin.UserName.TrimStart('\')
    'X-ClickHouse-Key'  = $admin.GetNetworkCredential().Password
}
function Invoke-Ch([string]$Sql) {
    return Invoke-RestMethod -Uri $Url -Method Post -Headers $headers -Body $Sql -ContentType 'text/plain; charset=utf-8'
}

# SETTINGS replaces the profile's whole list, so the other two settings are restated unchanged.
Invoke-Ch "ALTER SETTINGS PROFILE readonly_profile SETTINGS readonly = 2, max_execution_time = $Seconds, max_memory_usage = 10000000000" | Out-Null
Write-Host 'readonly_profile now:'
Write-Host (Invoke-Ch "SELECT setting_name, value FROM system.settings_profile_elements WHERE profile_name = 'readonly_profile' ORDER BY setting_name FORMAT TSV")
Write-Host 'Users of the profile (expect only bi_user):'
Write-Host (Invoke-Ch "SELECT user_name FROM system.settings_profile_elements WHERE inherit_profile = 'readonly_profile' FORMAT TSV")
