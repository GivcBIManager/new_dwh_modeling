<#
.SYNOPSIS
  Throwaway feasibility probe for the HNH_Analytics model (plan task 2). Deploys HNH_Probe, processes it,
  queries it, deletes it. Run on HNHANALYTICSSRV in Windows PowerShell 5.1 as an SSAS administrator:
    powershell -ExecutionPolicy Bypass -File ssas\spike\spike.ps1 -TestUser HNHANALYTICSSRV\<member of HNH_BI_Users>
  The script asks for the test user's password. The test user must not be an SSAS administrator (administrators bypass
  row filters). Paste the whole output back.
#>
param(
    [string]$Server = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [string]$TabularEditorDir = 'C:\Program Files (x86)\Tabular Editor',
    [string]$Dsn = 'HNH_Gold',
    [Parameter(Mandatory = $true)][string]$TestUser
)
$ErrorActionPreference = 'Stop'
$script:failures = 0
# A credential cannot be passed through powershell -File (it arrives as text), so the password is asked for here.
if ($TestUser -notmatch '^[^\\]+\\[^\\]+$') { throw "TestUser must be MACHINE\user, got '$TestUser'" }
$TestCredential = Get-Credential -UserName $TestUser -Message "Password of the test user $TestUser"
if (-not $TestCredential) { throw 'No password entered for the test user' }
function Report([string]$Name, [bool]$Ok, [string]$Detail) {
    $word = 'PASS'
    if (-not $Ok) { $word = 'FAIL'; $script:failures++ }
    Write-Host ('{0} {1}: {2}' -f $word, $Name, $Detail)
}
# The server is in a workgroup, so EffectiveUserName cannot impersonate; queries for a user run under that user's own logon.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class HnhLogon {
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool LogonUser(string user, string domain, string password, int logonType, int provider, out IntPtr token);
    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr handle);
}
'@
function Invoke-Dax([string]$Query, [pscredential]$Credential) {
    # One connection string per identity, so OLE DB pooling never hands a test user's query the administrator's session
    # (MSOLAP rejects the OLE DB Services keyword that would turn pooling off).
    $cs = "Provider=MSOLAP;Data Source=$Server;Initial Catalog=HNH_Probe;Application Name=hnh-spike-admin"
    $context = $null; $token = [IntPtr]::Zero
    if ($Credential) {
        $cs = $cs.Replace('hnh-spike-admin', "hnh-spike-$($Credential.UserName.Replace('\', '-'))")
        $domain, $name = $Credential.UserName.TrimStart('\').Split('\')
        if (-not $domain -or -not $name -or $name -is [array]) { throw "Cannot log on as '$($Credential.UserName)': expected MACHINE\user" }
        # 8 = LOGON32_LOGON_NETWORK_CLEARTEXT: needs only network access rights and keeps the credential for the SSAS connection.
        if (-not [HnhLogon]::LogonUser($name, $domain, $Credential.GetNetworkCredential().Password, 8, 0, [ref]$token)) {
            throw (New-Object System.ComponentModel.Win32Exception ([Runtime.InteropServices.Marshal]::GetLastWin32Error()))
        }
        $context = [System.Security.Principal.WindowsIdentity]::Impersonate($token)
    }
    try {
        $conn = New-Object System.Data.OleDb.OleDbConnection $cs
        $conn.Open()
        try {
            $cmd = $conn.CreateCommand(); $cmd.CommandText = $Query; $cmd.CommandTimeout = 300
            $table = New-Object System.Data.DataTable
            [void](New-Object System.Data.OleDb.OleDbDataAdapter $cmd).Fill($table)
            return ,$table
        } finally { $conn.Close() }
    } finally {
        if ($context) { $context.Undo() }
        if ($token -ne [IntPtr]::Zero) { [void][HnhLogon]::CloseHandle($token) }
    }
}
function Scalar($Table) {
    if ($Table.Rows.Count -eq 0 -or $Table.Rows[0][0] -is [System.DBNull]) { return $null }
    return $Table.Rows[0][0]
}

Add-Type -Path (Join-Path $TabularEditorDir 'Microsoft.AnalysisServices.Tabular.dll')
$tomVersion = (Get-Item (Join-Path $TabularEditorDir 'Microsoft.AnalysisServices.Tabular.dll')).VersionInfo.FileVersion
$tomServer = New-Object Microsoft.AnalysisServices.Tabular.Server
$tomServer.Connect("Data Source=$Server")
Report 'server' ($tomServer.ServerMode -eq 'Tabular' -and $tomServer.Version -like '17.*') "version $($tomServer.Version), edition $($tomServer.Edition), mode $($tomServer.ServerMode), TOM $tomVersion"

$providers = @((New-Object System.Data.OleDb.OleDbEnumerator).GetElements() | Where-Object { $_.SOURCES_NAME -like 'MSOLAP*' } | ForEach-Object { $_.SOURCES_NAME })
Report 'msolap' ($providers.Count -gt 0) ($providers -join ', ')

try {
    $odbc = New-Object System.Data.Odbc.OdbcConnection "DSN=$Dsn"
    $odbc.Open(); $cmd = $odbc.CreateCommand(); $cmd.CommandText = 'select currentUser()'
    $who = [string]$cmd.ExecuteScalar(); $odbc.Close()
    Report 'odbc' ($who -eq 'bi_user') "DSN $Dsn connects as $who"
} catch { Report 'odbc' $false $_.Exception.Message }

$te = Join-Path $TabularEditorDir 'TabularEditor.exe'
$out = & $te (Join-Path $PSScriptRoot 'Probe') -D $Server HNH_Probe -O -C -P -R -E -V 2>&1 | Out-String
Report 'deploy' ($LASTEXITCODE -eq 0 -and $out -notmatch 'type=error') (($out -replace '\s+', ' ').Trim())

$tomServer.Refresh()
$db = $tomServer.Databases.FindByName('HNH_Probe')
if ($db -eq $null) { Report 'database' $false 'HNH_Probe not found after deploy'; Write-Host "$($script:failures) failure(s)"; exit 1 }
Report 'compatibility' ($db.CompatibilityLevel -eq 1700) "level $($db.CompatibilityLevel), mode $($db.CompatibilityMode)"

$member = New-Object Microsoft.AnalysisServices.Tabular.WindowsModelRoleMember
$member.MemberName = "$env:COMPUTERNAME\HNH_BI_Users"
$db.Model.Roles.Find('Probe Readers').Members.Add($member)
$login = $TestUser.Replace('\', '\\').Replace("'", "\'")
$db.Model.Tables.Find('Probe Users').Partitions[0].Source.Expression = "let`n    Source = Odbc.Query(""dsn=$Dsn"", ""select '$login' as login_name, toInt64(1) as dim_key"")`nin`n    Source"
[void]$db.Model.SaveChanges()
Report 'role member' $true $member.MemberName

try {
    $opts = New-Object Microsoft.AnalysisServices.Tabular.SaveOptions
    $opts.MaxParallelism = 2
    $db.Model.RequestRefresh([Microsoft.AnalysisServices.Tabular.RefreshType]::Full)
    [void]$db.Model.SaveChanges($opts)
    Report 'process' $true 'full refresh through Power Query Odbc.Query with SaveOptions.MaxParallelism'
} catch { Report 'process' $false $_.Exception.ToString() }

try {
    $rows = Invoke-Dax "EVALUATE 'Probe Fact'" $null
    $types = ($rows.Columns | ForEach-Object { "$($_.ColumnName)=$($_.DataType.Name)" }) -join '; '
    Report 'rows' ($rows.Rows.Count -eq 2) $types
    $amount = Scalar (Invoke-Dax 'EVALUATE ROW("v", [Amount])' $null)
    Report 'decimal' ([decimal]$amount -eq [decimal]1233.5678) "Amount = $amount"
    $code = Scalar (Invoke-Dax "EVALUATE ROW(""v"", [Max Text Code])" $null)
    Report 'unicode' ([int]$code -eq 1606) "first character code $code (expected 1606, Arabic noon)"
    $adminDims = Scalar (Invoke-Dax "EVALUATE ROW(""n"", COUNTROWS('Probe Dim'))" $null)
    Report 'admin rows' ([int]$adminDims -eq 2) "admin sees $adminDims dimension rows"
} catch { Report 'dax' $false $_.Exception.Message }

try {
    # USERNAME() is shown only for comparison: the role filters on USERPRINCIPALNAME().
    $ids = (Invoke-Dax 'EVALUATE ROW("upn", USERPRINCIPALNAME(), "un", USERNAME())' $TestCredential).Rows[0]
    Report 'username' ($ids[0] -eq $TestUser) "USERPRINCIPALNAME() = $($ids[0]); USERNAME() = $($ids[1]); login_name = $TestUser"
    $userDims = Scalar (Invoke-Dax "EVALUATE ROW(""n"", COUNTROWS('Probe Dim'))" $TestCredential)
    Report 'row filter' ([int]$userDims -eq 1) "test user sees $userDims dimension rows (FALSE() security table pattern)"
    $userFacts = Scalar (Invoke-Dax "EVALUATE ROW(""n"", COUNTROWS('Probe Fact'))" $TestCredential)
    Report 'filter through relationship' ([int]$userFacts -eq 1) "test user sees $userFacts fact rows (fact key without attribute hierarchy)"
} catch { Report 'test user' $false $_.Exception.Message }

$p = $db.Model.Perspectives.Find('Probe View')
Report 'perspective' ($p -ne $null -and $p.PerspectiveTables[0].IncludeAll) 'includeAll perspective deployed'

$db.Drop()
Report 'cleanup' $true 'HNH_Probe dropped'
$tomServer.Disconnect()
Write-Host "$($script:failures) failure(s)"
if ($script:failures -gt 0) { exit 1 }
