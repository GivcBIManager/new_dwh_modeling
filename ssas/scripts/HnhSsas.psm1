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
