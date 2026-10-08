<#
.SYNOPSIS
  Replace the BI users source of row security with bi_users.csv: default.bi_users (login, branch, admin, specialty)
  and default.map_bi_user_permission (pay and PII flags). Old rows are copied to backup tables, then removed.
  sec_user_access (and gold.ssas_sec_user_access) pick the new users up at the next dbt build of tag:hnh; SSAS at the
  next process.ps1 run after it.
    powershell -ExecutionPolicy Bypass -File scripts\load_bi_users.ps1 [-DryRun]
  It asks for a ClickHouse user that may create, truncate and insert into tables in database default.
#>
param(
    [string]$CsvPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'bi_users.csv'),
    [string]$Url = 'http://172.22.25.214:8123/',
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$machine = $env:COMPUTERNAME

$rows = @(Import-Csv -Path $CsvPath -Encoding UTF8)
$problems = @()
foreach ($r in $rows) {
    if ($r.login_name -notmatch ('^' + [regex]::Escape($machine) + '\\[^\\]+$')) { $problems += "$($r.login_name): login must be $machine\<name>" }
    if ($r.branch_key -and $r.branch_key -notmatch '^[1-8]$') { $problems += "$($r.login_name): branch_key '$($r.branch_key)' is not 1-8" }
    foreach ($flag in 'is_admin', 'can_see_pay', 'can_see_pii') {
        if ($r.$flag -notmatch '^[01]$') { $problems += "$($r.login_name): $flag '$($r.$flag)' is not 0 or 1" }
    }
}
$dupes = @($rows | Group-Object { $_.login_name.ToLower() } | Where-Object Count -gt 1 | ForEach-Object Name)
if ($dupes) { $problems += "duplicate logins: $($dupes -join ', ')" }
if ($problems) { throw ("bi_users.csv:`n" + ($problems -join "`n")) }

function Json([string]$s) { if ($s -eq $null -or $s -eq '') { return 'null' } return '"' + $s.Replace('\', '\\').Replace('"', '\"') + '"' }
# A user without branch_key sees every branch: loaded as IsAdmin = 1, which sec_user_access expands to all branches and
# Head Office. The specialty restriction and the pay/PII flags still apply.
$allBranches = @($rows | Where-Object { -not $_.branch_key -and $_.is_admin -eq '0' } | ForEach-Object login_name)
if ($allBranches) { Write-Host "no branch_key, so all branches: $($allBranches -join ', ')" }
$users = foreach ($r in $rows) {
    $branch = 'null'; $isAdmin = [int]$r.is_admin
    if ($r.branch_key) { $branch = [int]$r.branch_key } else { $isAdmin = 1 }
    '{"UserName":' + (Json $r.login_name) + ',"BRANCH_ID":' + $branch + ',"IsAdmin":' + $isAdmin +
        ',"Unified_Speciality":' + (Json $r.unified_specialty.Trim()) + '}'
}
$perms = foreach ($r in ($rows | Where-Object { $_.can_see_pay -eq '1' -or $_.can_see_pii -eq '1' })) {
    '{"bi_user_name":' + (Json $r.login_name) + ',"can_see_pay":' + [int]$r.can_see_pay + ',"can_see_pii":' + [int]$r.can_see_pii + '}'
}
$perms = @($perms)
Write-Host "bi_users.csv: $($rows.Count) users ($(@($rows | Where-Object { -not $_.branch_key }).Count) see all branches), $($perms.Count) with pay or PII"
Write-Host "  pay: $((@($rows | Where-Object can_see_pay -eq '1') | ForEach-Object login_name) -join ', ')"
Write-Host "  PII: $((@($rows | Where-Object can_see_pii -eq '1') | ForEach-Object login_name) -join ', ')"
if ($DryRun) { Write-Host '(dry run) nothing written'; return }

$admin = Get-Credential -Message 'ClickHouse admin user (for example default)'
if (-not $admin) { throw 'No credential entered' }
$headers = @{ 'X-ClickHouse-User' = $admin.UserName.TrimStart('\'); 'X-ClickHouse-Key' = $admin.GetNetworkCredential().Password }
function Invoke-Ch([string]$Sql, [string[]]$Lines) {
    $uri = $Url + '?query=' + [uri]::EscapeDataString($Sql)
    $body = [byte[]]@()
    if ($Lines) { $body = [Text.Encoding]::UTF8.GetBytes(($Lines -join "`n") + "`n") }
    return Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ContentType 'application/octet-stream'
}
# Invoke-RestMethod turns a bare number reply into an Int32, so the count is read as text.
function Get-ChCount([string]$Table) { return ([string](Invoke-Ch "SELECT count() FROM $Table")).Trim() }

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
foreach ($t in 'bi_users', 'map_bi_user_permission') {
    Invoke-Ch "CREATE TABLE default.${t}_backup_$stamp AS default.$t" | Out-Null
    Invoke-Ch "INSERT INTO default.${t}_backup_$stamp SELECT * FROM default.$t" | Out-Null
    Write-Host "backup: default.${t}_backup_$stamp ($(Get-ChCount "default.${t}_backup_$stamp") rows)"
}
Invoke-Ch 'TRUNCATE TABLE default.bi_users' | Out-Null
Invoke-Ch ("INSERT INTO default.bi_users (UserName, BRANCH_ID, IsAdmin, ModefiedDate, Unified_Speciality) " +
    "SELECT UserName, BRANCH_ID, IsAdmin, now(), Unified_Speciality FROM input('UserName String, BRANCH_ID Nullable(UInt8), " +
    "IsAdmin UInt8, Unified_Speciality Nullable(String)') FORMAT JSONEachRow") $users | Out-Null
Invoke-Ch 'TRUNCATE TABLE default.map_bi_user_permission' | Out-Null
if ($perms.Count -gt 0) { Invoke-Ch 'INSERT INTO default.map_bi_user_permission FORMAT JSONEachRow' $perms | Out-Null }
Write-Host "default.bi_users: $(Get-ChCount 'default.bi_users') rows; default.map_bi_user_permission: $(Get-ChCount 'default.map_bi_user_permission') rows"
Write-Host 'Next: dbt build --select tag:hnh on the dbt server, then process.ps1 -Mode Daily.'
