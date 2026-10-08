<#
.SYNOPSIS
  Create the BI report users of bi_users.csv as local Windows accounts on HNHANALYTICSSRV, put every one in
  HNH_BI_Users (the member of the SSAS role HNH Readers), in a department group HNH_BI_<dep> and in the branch group
  HNH_BI_Branch_<branch> of every branch the user can see (all eight when branch_key is empty).
  Safe to re-run: existing accounts keep their password; names, descriptions and group memberships are brought in line.
    powershell -ExecutionPolicy Bypass -File scripts\create_bi_windows_users.ps1 [-DryRun]
  New passwords are random (20 characters) and never expire (a PBIRS user cannot change an expired password from the
  browser). They are written outside git to $SecretsDir, readable by Administrators and SYSTEM only:
    bi_user_passwords.csv        to hand out
    bi_user_credentials.xml      PSCredential per login, DPAPI-encrypted for the account that ran this script;
                                 ssas/scripts/test.ps1 reads it to log on as the security test users
#>
param(
    [string]$CsvPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'bi_users.csv'),
    [string]$SecretsDir = 'C:\HNH\secrets',
    [string]$AllUsersGroup = 'HNH_BI_Users',
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$machine = $env:COMPUTERNAME

function New-HnhPassword {
    # 20 characters with upper, lower, digit and symbol; no look-alike characters (0 O 1 l I).
    $sets = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!#%+=?@')
    $all = -join $sets
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $byte = New-Object byte[] 1
    $pick = {
        param([string]$from)
        do { $rng.GetBytes($byte) } while ($byte[0] -ge (256 - (256 % $from.Length)))
        $from[$byte[0] % $from.Length]
    }
    do {
        $chars = 1..20 | ForEach-Object { & $pick $all }
        $text = -join $chars
    } until (($sets | Where-Object { $text.IndexOfAny($_.ToCharArray()) -lt 0 }).Count -eq 0)
    return $text
}

# Hospital branches of gold.dim_branch (branch_key 1-8). Branch group HNH_BI_Branch_<name> holds every user who can see
# that branch: users of that branch_key and users without branch_key (they see every branch, spec P25).
$Branches = [ordered]@{ '1' = 'Rabwah'; '2' = 'KhamisMushait'; '3' = 'Jazan'; '4' = 'Unaizah'; '5' = 'Madinah'; '6' = 'Abha'; '7' = 'Ghirnata'; '8' = 'Muhayil' }
function Get-BranchGroups([string]$BranchKey) {
    if ($BranchKey) { return @("HNH_BI_Branch_$($Branches[$BranchKey])") }
    return @($Branches.Values | ForEach-Object { "HNH_BI_Branch_$_" })
}

function Get-DepartmentGroup([string]$Dep) {
    $clean = ($Dep.Trim() -replace '[^A-Za-z0-9]', '')
    return 'HNH_BI_' + $clean.Substring(0, 1).ToUpper() + $clean.Substring(1)
}

function Set-SecretsAcl([string]$Path) {
    # Administrators and SYSTEM only, no inheritance.
    $acl = New-Object System.Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($sid in 'S-1-5-32-544', 'S-1-5-18') {
        $id = (New-Object System.Security.Principal.SecurityIdentifier $sid)
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule $id, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
    }
    Set-Acl -Path $Path -AclObject $acl
}

$rows = @(Import-Csv -Path $CsvPath -Encoding UTF8)
$problems = @()
foreach ($r in $rows) {
    $parts = $r.login_name.Split('\')
    if ($parts.Count -ne 2 -or $parts[0] -ne $machine) { $problems += "$($r.login_name): login must be $machine\<name>" }
    elseif ($parts[1].Length -gt 20 -or $parts[1] -notmatch '^[A-Za-z0-9_.-]+$') { $problems += "$($r.login_name): name must be 1-20 of A-Z 0-9 _ . -" }
    if (-not $r.dep.Trim()) { $problems += "$($r.login_name): no dep" }
    if ($r.branch_key -and -not $Branches.Contains($r.branch_key)) { $problems += "$($r.login_name): branch_key '$($r.branch_key)' is not 1-8" }
}
if ($problems) { throw ("bi_users.csv:`n" + ($problems -join "`n")) }

$created = @(); $updated = 0; $joined = 0; $newGroups = @()
$passwords = @{}
# The built-in Administrator (SID ...-500) keeps its own name and gets no department group.
$builtInName = (Get-LocalUser | Where-Object { $_.SID.Value -like '*-500' }).Name
$deptRows = @($rows | Where-Object { $_.login_name.Split('\')[1] -ne $builtInName })
$groups = @($AllUsersGroup) + @($deptRows | ForEach-Object { Get-DepartmentGroup $_.dep } | Sort-Object -Unique) +
    @($Branches.Values | ForEach-Object { "HNH_BI_Branch_$_" })
foreach ($g in $groups) {
    if (-not (Get-LocalGroup -Name $g -ErrorAction SilentlyContinue)) {
        $newGroups += $g
        if (-not $DryRun) { [void](New-LocalGroup -Name $g -Description 'HNH BI report users (bi_users.csv)') }
    }
}

foreach ($r in $rows) {
    $name = $r.login_name.Split('\')[1]
    $fullName = $r.'FULL NAME'.Trim()
    $description = $r.Description.Trim()
    if ($description.Length -gt 48) { $description = $description.Substring(0, 47) + [char]0x2026 }   # local accounts allow 48
    $user = Get-LocalUser -Name $name -ErrorAction SilentlyContinue
    $builtIn = $user -and $user.SID.Value -like '*-500'
    if (-not $user) {
        $created += $name
        if (-not $DryRun) {
            $plain = New-HnhPassword
            $secure = ConvertTo-SecureString $plain -AsPlainText -Force
            [void](New-LocalUser -Name $name -Password $secure -FullName $fullName -Description $description -PasswordNeverExpires)
            $passwords[$name] = $plain
        }
    } elseif (-not $builtIn -and ($user.FullName -ne $fullName -or $user.Description -ne $description)) {
        $updated++
        if (-not $DryRun) { Set-LocalUser -Name $name -FullName $fullName -Description $description }
    }
    $wanted = @($AllUsersGroup)
    if (-not $builtIn) { $wanted += @(Get-DepartmentGroup $r.dep) + @(Get-BranchGroups $r.branch_key) }
    foreach ($g in $wanted) {
        $isMember = $false
        if (-not ($newGroups -contains $g)) {
            $isMember = @(Get-LocalGroupMember -Group $g | Where-Object { $_.Name -eq "$machine\$name" }).Count -gt 0
        }
        if (-not $isMember) {
            $joined++
            if (-not $DryRun) { Add-LocalGroupMember -Group $g -Member $name }
        }
    }
}

if ($passwords.Count -gt 0) {
    if (-not (Test-Path $SecretsDir)) { [void](New-Item -ItemType Directory -Path $SecretsDir) }
    Set-SecretsAcl $SecretsDir
    $listPath = Join-Path $SecretsDir 'bi_user_passwords.csv'
    $credPath = Join-Path $SecretsDir 'bi_user_credentials.xml'
    $list = @(); if (Test-Path $listPath) { $list = @(Import-Csv $listPath) }
    $creds = @{}; if (Test-Path $credPath) { $creds = Import-Clixml $credPath }
    foreach ($name in ($passwords.Keys | Sort-Object)) {
        $login = "$machine\$name"
        $list = @($list | Where-Object { $_.login_name -ne $login }) + [pscustomobject]@{ login_name = $login; password = $passwords[$name]; created = (Get-Date -Format 'yyyy-MM-dd') }
        $creds[$login] = New-Object pscredential $login, (ConvertTo-SecureString $passwords[$name] -AsPlainText -Force)
    }
    $list | Sort-Object login_name | Export-Csv -Path $listPath -NoTypeInformation -Encoding UTF8
    $creds | Export-Clixml -Path $credPath
}

$mode = ''; if ($DryRun) { $mode = '(dry run) ' }
Write-Host "$mode$($rows.Count) rows: $($created.Count) accounts created, $updated updated, $joined group memberships added, $($newGroups.Count) groups created"
if ($newGroups) { Write-Host "  groups: $($newGroups -join ', ')" }
if ($created) { Write-Host "  new accounts: $($created -join ', ')" }
if ($passwords.Count -gt 0) { Write-Host "  passwords: $SecretsDir (Administrators only)" }
