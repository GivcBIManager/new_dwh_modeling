<#
.SYNOPSIS
  Throwaway feasibility probe for the HNH_Analytics model (plan task 2). Deploys HNH_Probe, processes it,
  queries it, deletes it. Run on HNHANALYTICSSRV in Windows PowerShell 5.1 as an SSAS administrator:
    powershell -ExecutionPolicy Bypass -File ssas\spike\spike.ps1 -TestUser HNHANALYTICSSRV\<member of HNH_BI_Users>
  Paste the whole output back.
#>
param(
    [string]$Server = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [string]$TabularEditorDir = 'C:\Program Files (x86)\Tabular Editor',
    [string]$Dsn = 'HNH_Gold',
    [Parameter(Mandatory = $true)][string]$TestUser
)
$ErrorActionPreference = 'Stop'
$script:failures = 0
function Report([string]$Name, [bool]$Ok, [string]$Detail) {
    $word = 'PASS'
    if (-not $Ok) { $word = 'FAIL'; $script:failures++ }
    Write-Host ('{0} {1}: {2}' -f $word, $Name, $Detail)
}
function Invoke-Dax([string]$Query, [string]$User) {
    $cs = "Provider=MSOLAP;Data Source=$Server;Initial Catalog=HNH_Probe"
    if ($User) { $cs += ";EffectiveUserName=$User" }
    $conn = New-Object System.Data.OleDb.OleDbConnection $cs
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand(); $cmd.CommandText = $Query; $cmd.CommandTimeout = 300
        $table = New-Object System.Data.DataTable
        [void](New-Object System.Data.OleDb.OleDbDataAdapter $cmd).Fill($table)
        return ,$table
    } finally { $conn.Close() }
}
function Scalar($Table) {
    if ($Table.Rows.Count -eq 0 -or $Table.Rows[0][0] -is [System.DBNull]) { return $null }
    return $Table.Rows[0][0]
}

Add-Type -Path (Join-Path $TabularEditorDir 'Microsoft.AnalysisServices.Tabular.dll')
$tomVersion = (Get-Item (Join-Path $TabularEditorDir 'Microsoft.AnalysisServices.Tabular.dll')).VersionInfo.FileVersion
$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("Data Source=$Server")
Report 'server' ($server.ServerMode -eq 'Tabular' -and $server.Version -like '17.*') "version $($server.Version), edition $($server.Edition), mode $($server.ServerMode), TOM $tomVersion"

$providers = @((New-Object System.Data.OleDb.OleDbEnumerator).GetElements() | Where-Object { $_.SOURCES_NAME -like 'MSOLAP*' } | ForEach-Object { $_.SOURCES_NAME })
Report 'msolap' ($providers.Count -gt 0) ($providers -join ', ')

try {
    $odbc = New-Object System.Data.Odbc.OdbcConnection "DSN=$Dsn"
    $odbc.Open(); $cmd = $odbc.CreateCommand(); $cmd.CommandText = 'select currentUser()'
    $who = [string]$cmd.ExecuteScalar(); $odbc.Close()
    Report 'odbc' ($who -eq 'ssas_reader') "DSN $Dsn connects as $who"
} catch { Report 'odbc' $false $_.Exception.Message }

$te = Join-Path $TabularEditorDir 'TabularEditor.exe'
$out = & $te (Join-Path $PSScriptRoot 'Probe') -D $Server HNH_Probe -O -C -P -R -E -V 2>&1 | Out-String
Report 'deploy' ($LASTEXITCODE -eq 0 -and $out -notmatch 'type=error') (($out -replace '\s+', ' ').Trim())

$server.Refresh()
$db = $server.Databases.FindByName('HNH_Probe')
if ($db -eq $null) { Report 'database' $false 'HNH_Probe not found after deploy'; exit 1 }
Report 'compatibility' ($db.CompatibilityLevel -eq 1700) "level $($db.CompatibilityLevel), mode $($db.CompatibilityMode)"

$member = New-Object Microsoft.AnalysisServices.Tabular.WindowsModelRoleMember
$member.MemberName = "$env:COMPUTERNAME\HNH_BI_Users"
$db.Model.Roles.Find('Probe Readers').Members.Add($member)
$login = $TestUser.Replace('\', '\\').Replace("'", "\'")
$db.Model.Tables.Find('Probe Users').Partitions[0].Source.Query = "select '$login' as login_name, toInt64(1) as dim_key"
[void]$db.Model.SaveChanges()
Report 'role member' $true $member.MemberName

try {
    $opts = New-Object Microsoft.AnalysisServices.Tabular.SaveOptions
    $opts.MaxParallelism = 2
    $db.Model.RequestRefresh([Microsoft.AnalysisServices.Tabular.RefreshType]::Full)
    [void]$db.Model.SaveChanges($opts)
    Report 'process' $true 'full refresh through MSDASQL with SaveOptions.MaxParallelism'
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
    $who = Scalar (Invoke-Dax 'EVALUATE ROW("u", USERNAME())' $TestUser)
    Report 'username' ($who -eq $TestUser) "USERNAME() = $who"
    $userDims = Scalar (Invoke-Dax "EVALUATE ROW(""n"", COUNTROWS('Probe Dim'))" $TestUser)
    Report 'row filter' ([int]$userDims -eq 1) "test user sees $userDims dimension rows (FALSE() security table pattern)"
    $userFacts = Scalar (Invoke-Dax "EVALUATE ROW(""n"", COUNTROWS('Probe Fact'))" $TestUser)
    Report 'filter through relationship' ([int]$userFacts -eq 1) "test user sees $userFacts fact rows (fact key without attribute hierarchy)"
} catch { Report 'dax' $false $_.Exception.Message }

$p = $db.Model.Perspectives.Find('Probe View')
Report 'perspective' ($p -ne $null -and $p.PerspectiveTables[0].IncludeAll) 'includeAll perspective deployed'

$db.Drop()
Report 'cleanup' $true 'HNH_Probe dropped'
$server.Disconnect()
Write-Host "$($script:failures) failure(s)"
if ($script:failures -gt 0) { exit 1 }
