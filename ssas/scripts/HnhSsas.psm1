# Shared functions of the HNH_Analytics scripts (SSAS plan tasks 12-15). Windows PowerShell 5.1.

function Get-HnhPartitionPlan {
    # Desired partitions of one large table on a given day (SSAS spec 9.3, decision P9).
    param(
        [Parameter(Mandatory = $true)][string]$Table,
        [Parameter(Mandatory = $true)][string]$View,
        [Parameter(Mandatory = $true)][string]$Column,
        [Parameter(Mandatory = $true)][datetime]$Today,
        [int]$FirstYear = 2022
    )
    $year = $Today.Year
    $ranges = New-Object System.Collections.Generic.List[object]
    for ($y = $FirstYear; $y -le $year - 2; $y++) {
        $ranges.Add(@{ Name = "$Table $y"; Lo = [int]('{0}0101' -f $y); Hi = [int]('{0}0101' -f ($y + 1)) })
    }
    foreach ($y in @(($year - 1), $year)) {
        if ($y -lt $FirstYear) { continue }
        for ($m = 1; $m -le 12; $m++) {
            $start = New-Object datetime $y, $m, 1
            $ranges.Add(@{
                Name = ('{0} {1}' -f $Table, $start.ToString('yyyy-MM'))
                Lo   = [int]$start.ToString('yyyyMMdd')
                Hi   = [int]$start.AddMonths(1).ToString('yyyyMMdd')
            })
        }
    }
    $ranges[0].Lo = $null
    $plan = @()
    foreach ($r in $ranges) {
        if ($r.Lo -eq $null) { $where = "$Column < $($r.Hi)" } else { $where = "$Column >= $($r.Lo) and $Column < $($r.Hi)" }
        $plan += [pscustomobject]@{ Name = $r.Name; Lo = $r.Lo; Hi = $r.Hi; IsNull = $false; Query = "select * from gold.$View where $where" }
    }
    $later = [int]('{0}0101' -f ($year + 1))
    $plan += [pscustomobject]@{ Name = "$Table Later"; Lo = $later; Hi = $null; IsNull = $false; Query = "select * from gold.$View where $Column >= $later" }
    $plan += [pscustomobject]@{ Name = "$Table No date"; Lo = $null; Hi = $null; IsNull = $true; Query = "select * from gold.$View where $Column is null" }
    return ,$plan
}

function Get-HnhDailyPartitionNames {
    # Partitions reloaded by the daily run: this month, the two before it, Later and No date (SSAS spec 9.4).
    param([Parameter(Mandatory = $true)][string]$Table, [Parameter(Mandatory = $true)][datetime]$Today)
    $first = New-Object datetime $Today.Year, $Today.Month, 1
    $names = @()
    foreach ($k in 0, 1, 2) { $names += ('{0} {1}' -f $Table, $first.AddMonths(-$k).ToString('yyyy-MM')) }
    $names += "$Table Later"
    $names += "$Table No date"
    return ,$names
}

function Compare-HnhPartitions {
    param([Parameter(Mandatory = $true)][object[]]$Desired, [Parameter(Mandatory = $true)][hashtable]$Existing)
    $add = @(); $update = @(); $remove = @(); $wanted = @{}
    foreach ($p in $Desired) {
        $wanted[$p.Name] = $true
        if (-not $Existing.ContainsKey($p.Name)) { $add += $p }
        elseif ($Existing[$p.Name] -ne $p.Query) { $update += $p }
    }
    foreach ($name in @($Existing.Keys)) { if (-not $wanted.ContainsKey($name)) { $remove += $name } }
    return [pscustomobject]@{ Add = $add; Update = $update; Remove = $remove }
}

function ConvertTo-HnhOdbcExpression {
    # Power Query partition expression for one SQL query through the DSN; same text as hnh_tmdl.odbc_expression (decision P24).
    param([Parameter(Mandatory = $true)][string]$Query, [string]$Dsn = 'HNH_Gold')
    $sql = $Query.Replace('"', '""')   # outside the string: "" inside an expandable string collapses to one quote
    return "let`n    Source = Odbc.Query(""dsn=$Dsn"", ""$sql"")`nin`n    Source"
}

function Test-HnhGate {
    # SSAS spec 9.4: process only the latest successful tag:hnh run, and only once.
    param([string]$Status, [Nullable[datetime]]$FinishedAt, [Nullable[datetime]]$LastProcessedRunAt)
    if ($Status -ne 'success' -or $FinishedAt -eq $null) { return $false }
    if ($LastProcessedRunAt -eq $null) { return $true }
    return ($FinishedAt -gt $LastProcessedRunAt)
}

function Format-HnhTableRef {
    param([Parameter(Mandatory = $true)][string]$Name)
    return "'" + $Name.Replace("'", "''") + "'"
}

function Import-HnhTom {
    param([string]$TabularEditorDir = 'C:\Program Files (x86)\Tabular Editor')
    $dll = Join-Path $TabularEditorDir 'Microsoft.AnalysisServices.Tabular.dll'
    if (-not (Test-Path $dll)) { throw "Tabular Editor 2 not found in $TabularEditorDir (copy its folder there or pass -TabularEditorDir)" }
    Add-Type -Path $dll
}

function Connect-HnhServer {
    param([Parameter(Mandatory = $true)][string]$Server)
    $srv = New-Object Microsoft.AnalysisServices.Tabular.Server
    $srv.Connect("Data Source=$Server")
    return $srv
}

function Get-HnhDatabase {
    param([Parameter(Mandatory = $true)]$ServerObject, [Parameter(Mandatory = $true)][string]$Database)
    $db = $ServerObject.Databases.FindByName($Database)
    if ($db -eq $null) { throw "Database $Database not found on $($ServerObject.Name)" }
    return $db
}

function Get-HnhAnnotation {
    param([Parameter(Mandatory = $true)]$Object, [Parameter(Mandatory = $true)][string]$Name)
    $a = $Object.Annotations.Find($Name)
    if ($a -eq $null) { return $null }
    return $a.Value
}

function Save-HnhModel {
    # One SaveChanges = one transaction: users keep the old data until it commits (SSAS spec 9.4).
    param([Parameter(Mandatory = $true)]$Model, [int]$MaxParallelism = 6)
    $opts = New-Object Microsoft.AnalysisServices.Tabular.SaveOptions
    $opts.MaxParallelism = $MaxParallelism
    [void]$Model.SaveChanges($opts)
}

function Sync-HnhPartitions {
    # Bring every table that has an hnh_partition_column annotation to the partition plan of $Today.
    # -NoSave leaves the changes pending on $Model (no Calculate, no SaveChanges) so the caller commits them in its own single transaction.
    param([Parameter(Mandatory = $true)]$Model, [Parameter(Mandatory = $true)][datetime]$Today, [switch]$DryRun, [switch]$NoRefresh, [switch]$NoSave)
    $dataOnly = [Microsoft.AnalysisServices.Tabular.RefreshType]::DataOnly
    $log = @()
    foreach ($table in @($Model.Tables)) {
        $column = Get-HnhAnnotation $table 'hnh_partition_column'
        if (-not $column) { continue }
        $view = Get-HnhAnnotation $table 'hnh_view'
        $plan = Get-HnhPartitionPlan -Table $table.Name -View $view -Column $column -Today $Today
        # Partitions are Power Query (M) partitions: compare and write whole expressions, not SQL.
        $desired = @($plan | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Query = (ConvertTo-HnhOdbcExpression $_.Query) } })
        $existing = @{}
        foreach ($p in $table.Partitions) { $existing[$p.Name] = ([string]$p.Source.Expression).Replace("`r`n", "`n") }
        $diff = Compare-HnhPartitions -Desired $desired -Existing $existing
        foreach ($p in $diff.Add) {
            $log += "add $($p.Name)"
            if ($DryRun) { continue }
            $part = New-Object Microsoft.AnalysisServices.Tabular.Partition
            $part.Name = $p.Name
            $source = New-Object Microsoft.AnalysisServices.Tabular.MPartitionSource
            $source.Expression = $p.Query
            $part.Source = $source
            $table.Partitions.Add($part)
            if (-not $NoRefresh) { $part.RequestRefresh($dataOnly) }
        }
        foreach ($p in $diff.Update) {
            $log += "update $($p.Name)"
            if ($DryRun) { continue }
            $part = $table.Partitions.Find($p.Name)
            $part.Source.Expression = $p.Query
            if (-not $NoRefresh) { $part.RequestRefresh($dataOnly) }
        }
        foreach ($name in $diff.Remove) {
            $log += "remove $name"
            if (-not $DryRun) { [void]$table.Partitions.Remove($table.Partitions.Find($name)) }
        }
    }
    if ($log.Count -gt 0 -and -not $DryRun -and -not $NoSave) {
        if (-not $NoRefresh) { $Model.RequestRefresh([Microsoft.AnalysisServices.Tabular.RefreshType]::Calculate) }
        Save-HnhModel $Model
    }
    return ,$log
}

function Update-HnhUnprocessed {
    # After a metadata deploy: load every partition that is not Ready (new tables, changed columns), then recalculate.
    param([Parameter(Mandatory = $true)]$Model)
    $names = @()
    foreach ($table in @($Model.Tables)) {
        foreach ($p in $table.Partitions) {
            if ($p.SourceType -eq [Microsoft.AnalysisServices.Tabular.PartitionSourceType]::CalculationGroup) { continue }
            if ($p.State -ne [Microsoft.AnalysisServices.Tabular.ObjectState]::Ready) {
                $p.RequestRefresh([Microsoft.AnalysisServices.Tabular.RefreshType]::DataOnly)
                $names += "$($table.Name) / $($p.Name)"
            }
        }
    }
    $Model.RequestRefresh([Microsoft.AnalysisServices.Tabular.RefreshType]::Calculate)
    Save-HnhModel $Model
    return ,$names
}

function Add-HnhRoleMember {
    param([Parameter(Mandatory = $true)]$Model, [Parameter(Mandatory = $true)][string]$Role, [Parameter(Mandatory = $true)][string]$Member)
    $r = $Model.Roles.Find($Role)
    if ($r -eq $null) { throw "Role $Role not found" }
    foreach ($m in $r.Members) { if ($m.MemberName -eq $Member) { return $false } }
    $wm = New-Object Microsoft.AnalysisServices.Tabular.WindowsModelRoleMember
    $wm.MemberName = $Member
    [void]$r.Members.Add($wm)
    [void]$Model.SaveChanges()
    return $true
}

if (-not ('HnhLogon' -as [type])) {
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
}

function Invoke-HnhDax {
    # DAX through the MSOLAP OLE DB provider. With -Credential the query runs under that user's own Windows logon: the
    # server is in a workgroup, so EffectiveUserName cannot impersonate (spec O-S10).
    param(
        [Parameter(Mandatory = $true)][string]$Server,
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$Query,
        [pscredential]$Credential
    )
    # One connection string per identity, so OLE DB pooling never hands a user's query the administrator's session
    # (MSOLAP rejects the OLE DB Services keyword that would turn pooling off).
    $app = 'hnh-admin'
    $context = $null; $token = [IntPtr]::Zero
    if ($Credential) {
        $domain, $name = $Credential.UserName.TrimStart('\').Split('\')
        if (-not $domain -or -not $name -or $name -is [array]) { throw "Cannot log on as '$($Credential.UserName)': expected MACHINE\user" }
        $app = 'hnh-' + $name
        # 8 = LOGON32_LOGON_NETWORK_CLEARTEXT: needs only network access rights and keeps the credential for the SSAS connection.
        if (-not [HnhLogon]::LogonUser($name, $domain, $Credential.GetNetworkCredential().Password, 8, 0, [ref]$token)) {
            throw (New-Object System.ComponentModel.Win32Exception ([Runtime.InteropServices.Marshal]::GetLastWin32Error()))
        }
        $context = [System.Security.Principal.WindowsIdentity]::Impersonate($token)
    }
    try {
        $conn = New-Object System.Data.OleDb.OleDbConnection "Provider=MSOLAP;Data Source=$Server;Initial Catalog=$Database;Application Name=$app"
        $conn.Open()
        try {
            $cmd = $conn.CreateCommand(); $cmd.CommandText = $Query; $cmd.CommandTimeout = 600
            $table = New-Object System.Data.DataTable
            [void](New-Object System.Data.OleDb.OleDbDataAdapter $cmd).Fill($table)
            return ,$table
        } finally { $conn.Close() }
    } finally {
        if ($context) { $context.Undo() }
        if ($token -ne [IntPtr]::Zero) { [void][HnhLogon]::CloseHandle($token) }
    }
}

function Invoke-HnhOdbc {
    param([string]$Dsn = 'HNH_Gold', [Parameter(Mandatory = $true)][string]$Query)
    $conn = New-Object System.Data.Odbc.OdbcConnection "DSN=$Dsn"
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand(); $cmd.CommandText = $Query; $cmd.CommandTimeout = 1800
        $table = New-Object System.Data.DataTable
        [void](New-Object System.Data.Odbc.OdbcDataAdapter $cmd).Fill($table)
        return ,$table
    } finally { $conn.Close() }
}

function Get-HnhScalar {
    param($Table)
    if ($Table.Rows.Count -eq 0 -or $Table.Rows[0][0] -is [System.DBNull]) { return [double]0 }
    return [double]$Table.Rows[0][0]
}

function Invoke-HnhStep {
    # Runs a child script with named parameters. Splat a hashtable: in PS 5.1 an array splat binds every element by position (final review C1).
    param([Parameter(Mandatory = $true)][string]$ScriptPath, [hashtable]$Arguments = @{})
    & $ScriptPath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$ScriptPath failed with exit code $LASTEXITCODE" }
}
