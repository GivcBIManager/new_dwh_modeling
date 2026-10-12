# ClickHouse helpers for the bsc work on HNHANALYTICSSRV, which has no Python ClickHouse driver. Queries go through
# the system ODBC DSNs: HNH_Gold (new server, 172.22.25.214) and chDWH (old server, 172.22.25.165). Invoke-HnhSelect
# runs read-only statements only; writes go through scripts that ask for a credential (load_bsc_reference.ps1).

function Test-HnhReadOnlySql {
    param([Parameter(Mandatory = $true)][string]$Sql)
    $body = ($Sql -replace '(?m)^\s*--.*$', '').Trim().TrimEnd(';').Trim()
    if ($body -match ';') { return $false }
    return [bool]($body -match '(?i)^(SELECT|WITH|DESCRIBE|DESC|SHOW|EXISTS)\b')
}

function Invoke-HnhSelect {
    param(
        [Parameter(Mandatory = $true)][string]$Dsn,
        [Parameter(Mandatory = $true)][string]$Sql,
        [int]$TimeoutSeconds = 900
    )
    if (-not (Test-HnhReadOnlySql -Sql $Sql)) { throw 'Invoke-HnhSelect runs one read-only statement (SELECT, WITH, DESCRIBE, SHOW).' }
    $c = New-Object System.Data.Odbc.OdbcConnection("DSN=$Dsn")
    $c.Open()
    try {
        $cmd = $c.CreateCommand()
        $cmd.CommandText = $Sql
        $cmd.CommandTimeout = $TimeoutSeconds
        $r = $cmd.ExecuteReader()
        $rows = New-Object System.Collections.Generic.List[object]
        while ($r.Read()) {
            $o = [ordered]@{}
            for ($i = 0; $i -lt $r.FieldCount; $i++) {
                if ($r.IsDBNull($i)) { $o[$r.GetName($i)] = $null } else { $o[$r.GetName($i)] = $r.GetValue($i) }
            }
            $rows.Add([pscustomobject]$o)
        }
        $r.Close()
        return ,$rows.ToArray()
    } finally {
        $c.Close()
    }
}

function ConvertTo-HnhTsvField {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value -or $Value -is [System.DBNull]) { return '\N' }
    $s = [System.Convert]::ToString($Value, [System.Globalization.CultureInfo]::InvariantCulture)
    return $s.Replace('\', '\\').Replace("`t", '\t').Replace("`n", '\n').Replace("`r", '\r')
}

function Get-HnhContractColumns {
    param([Parameter(Mandatory = $true)][string]$YamlText, [Parameter(Mandatory = $true)][string]$Model)
    $columns = @()
    $inModel = $false
    $name = $null
    foreach ($line in ($YamlText -split "`r?`n")) {
        if ($line -match '^  - name: (\S+)\s*$') { $inModel = ($Matches[1] -eq $Model); continue }
        if (-not $inModel) { continue }
        if ($line -match '^      - name: (\S+)\s*$') { $name = $Matches[1]; continue }
        if ($name -and $line -match '^        data_type: "(.*)"\s*$') {
            $columns += [pscustomobject]@{ Name = $name; Type = $Matches[1] }
            $name = $null
        }
    }
    return ,$columns
}

function Compare-HnhColumns {
    param([object[]]$Expected, [object[]]$Actual)
    $problems = @()
    $max = [Math]::Max($Expected.Count, $Actual.Count)
    for ($i = 0; $i -lt $max; $i++) {
        $e = $null; $a = $null
        if ($i -lt $Expected.Count) { $e = $Expected[$i] }
        if ($i -lt $Actual.Count) { $a = $Actual[$i] }
        if ($null -eq $e) { $problems += "column $($i + 1): unexpected $($a.Name) $($a.Type)"; continue }
        if ($null -eq $a) { $problems += "column $($i + 1): missing $($e.Name) $($e.Type)"; continue }
        if ($e.Name -cne $a.Name -or $e.Type -cne $a.Type) {
            $problems += "column $($i + 1): expected $($e.Name) $($e.Type), got $($a.Name) $($a.Type)"
        }
    }
    return ,$problems
}

function Compare-HnhBscRows {
    param([object[]]$Old, [object[]]$New, [string[]]$Keys, [string[]]$Columns, [double]$Tolerance = 0.005)
    $index = @{}
    foreach ($n in $New) { $index[(($Keys | ForEach-Object { [string]$n.$_ }) -join '|')] = $n }
    $seen = @{}
    $out = @()
    foreach ($o in $Old) {
        $k = ($Keys | ForEach-Object { [string]$o.$_ }) -join '|'
        $seen[$k] = $true
        $n = $index[$k]
        if ($null -eq $n) { $out += [pscustomobject]@{ Key = $k; Column = '*'; Old = $null; New = $null; Status = 'missing in new' }; continue }
        foreach ($c in $Columns) {
            $ov = 0.0; $nv = 0.0
            if ($null -ne $o.$c) { $ov = [double]$o.$c }
            if ($null -ne $n.$c) { $nv = [double]$n.$c }
            $scale = [Math]::Max([Math]::Abs($ov), 1.0)
            if ([Math]::Abs($nv - $ov) / $scale -gt $Tolerance) {
                $out += [pscustomobject]@{ Key = $k; Column = $c; Old = $ov; New = $nv; Status = 'differs' }
            }
        }
    }
    foreach ($k in $index.Keys) {
        if (-not $seen.ContainsKey($k)) { $out += [pscustomobject]@{ Key = $k; Column = '*'; Old = $null; New = $null; Status = 'missing in old' } }
    }
    return ,$out
}

function New-HnhTableDdl {
    param([Parameter(Mandatory = $true)][string]$Table, [Parameter(Mandatory = $true)][object[]]$Columns)
    $cols = ($Columns | ForEach-Object { "``$($_.name)`` $($_.type)" }) -join ', '
    return "CREATE TABLE IF NOT EXISTS $Table ($cols) ENGINE = MergeTree ORDER BY tuple()"
}

function Test-HnhGlCutover {
    param([object[]]$Rows)
    $problems = @()
    foreach ($r in $Rows) {
        if ($r.BRANCH_ID -notmatch '^[1-8]$') { $problems += "BRANCH_ID '$($r.BRANCH_ID)' is not 1-8" }
        if ($r.FIRST_FUSION_GL_MONTH -notmatch '^20\d\d(0[1-9]|1[0-2])$') {
            $problems += "branch $($r.BRANCH_ID): FIRST_FUSION_GL_MONTH '$($r.FIRST_FUSION_GL_MONTH)' is not YYYYMM"
        }
    }
    $dupes = @($Rows | Group-Object BRANCH_ID | Where-Object Count -gt 1 | ForEach-Object Name)
    if ($dupes.Count) { $problems += "duplicate BRANCH_ID: $($dupes -join ', ')" }
    return ,$problems
}

Export-ModuleMember -Function Test-HnhReadOnlySql, Invoke-HnhSelect, ConvertTo-HnhTsvField, Get-HnhContractColumns,
    Compare-HnhColumns, Compare-HnhBscRows, New-HnhTableDdl, Test-HnhGlCutover
