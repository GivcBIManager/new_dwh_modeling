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
    $dataSource = $Model.DataSources.Find('HNH_Gold')
    $log = @()
    foreach ($table in @($Model.Tables)) {
        $column = Get-HnhAnnotation $table 'hnh_partition_column'
        if (-not $column) { continue }
        $view = Get-HnhAnnotation $table 'hnh_view'
        $plan = Get-HnhPartitionPlan -Table $table.Name -View $view -Column $column -Today $Today
        $existing = @{}
        foreach ($p in $table.Partitions) { $existing[$p.Name] = $p.Source.Query }
        $diff = Compare-HnhPartitions -Desired $plan -Existing $existing
        foreach ($p in $diff.Add) {
            $log += "add $($p.Name)"
            if ($DryRun) { continue }
            $part = New-Object Microsoft.AnalysisServices.Tabular.Partition
            $part.Name = $p.Name
            $source = New-Object Microsoft.AnalysisServices.Tabular.QueryPartitionSource
            $source.DataSource = $dataSource
            $source.Query = $p.Query
            $part.Source = $source
            $table.Partitions.Add($part)
            if (-not $NoRefresh) { $part.RequestRefresh($dataOnly) }
        }
        foreach ($p in $diff.Update) {
            $log += "update $($p.Name)"
            if ($DryRun) { continue }
            $part = $table.Partitions.Find($p.Name)
            $part.Source.Query = $p.Query
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

function Invoke-HnhDax {
    # DAX through the MSOLAP OLE DB provider; -EffectiveUserName runs the query as that user (SSAS admin only).
    param(
        [Parameter(Mandatory = $true)][string]$Server,
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$Query,
        [string]$EffectiveUserName
    )
    $cs = "Provider=MSOLAP;Data Source=$Server;Initial Catalog=$Database"
    if ($EffectiveUserName) { $cs += ";EffectiveUserName=$EffectiveUserName" }
    $conn = New-Object System.Data.OleDb.OleDbConnection $cs
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand(); $cmd.CommandText = $Query; $cmd.CommandTimeout = 600
        $table = New-Object System.Data.DataTable
        [void](New-Object System.Data.OleDb.OleDbDataAdapter $cmd).Fill($table)
        return ,$table
    } finally { $conn.Close() }
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
