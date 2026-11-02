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

function Test-HnhFsAccountMapping {
    # static_mappings/fs_account_mapping.csv: one row per account for all branches (BRANCH_CODE blank) and at most one
    # row per Fusion branch code (101-109) where that branch maps the account differently.
    param([object[]]$Rows)
    $problems = @()
    $all = @{}
    foreach ($r in $Rows) { if ([string]::IsNullOrEmpty($r.BRANCH_CODE)) { $all[[string]$r.ORACLE_CODE] = $true } }
    foreach ($r in $Rows) {
        $code = [string]$r.ORACLE_CODE
        if ($code -notmatch '^\d{8}$') { $problems += "ORACLE_CODE '$code' is not an 8-digit account"; continue }
        if (-not [string]::IsNullOrEmpty($r.BRANCH_CODE)) {
            if ($r.BRANCH_CODE -notmatch '^10[1-9]$') { $problems += "$($code): BRANCH_CODE '$($r.BRANCH_CODE)' is not a Fusion branch code 101-109" }
            elseif (-not $all.ContainsKey($code)) { $problems += "$code has a branch row but no row for all branches" }
        }
        if ($r.FS_TYPE -notin @('BS', 'IS')) { $problems += "$($code): FS_TYPE '$($r.FS_TYPE)' is not BS or IS" }
        foreach ($level in 'FS_ELEMENT', 'FS_CATEGORY', 'FS_CAPTION', 'FS_LINE') {
            if ([string]::IsNullOrWhiteSpace($r.$level)) { $problems += "$($code): $level is blank" }
        }
    }
    $dupes = @($Rows | Group-Object { "$($_.ORACLE_CODE)/$($_.BRANCH_CODE)" } | Where-Object Count -gt 1 | ForEach-Object Name)
    foreach ($d in $dupes) { $problems += "duplicate $($d.TrimEnd('/'))" }
    return ,$problems
}

# Create the config tables of one dashboard (DDL file) and load their first content (seed file), or with -Update
# add every INSERT of an update file. Shared by scripts\bsc_config\apply_bsc_config.ps1 and scripts\hr_config\apply_hr_config.ps1.
# -DryRun parses the files and prints what would happen, without credentials or a connection.
function Invoke-HnhConfigApply {
    param(
        [Parameter(Mandatory)][string]$Ddl,
        [Parameter(Mandatory)][string]$Seed,
        [string]$Update = '',
        [string]$Url = 'http://172.22.25.214:8123/',
        [switch]$DryRun
    )
    $ErrorActionPreference = 'Stop'
    function Split-Statements([string]$Text) {
        $body = ($Text -replace '(?m)^\s*--.*$', '')
        return @([regex]::Split($body, ';\s*\r?\n') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }

    function ConvertTo-Inserts([string]$Text) {
        foreach ($s in (Split-Statements $Text)) {
            $table = ([regex]::Match($s, 'INSERT INTO default\.(\w+)')).Groups[1].Value
            if ($s -match '\)\s*VALUES\s*\r?\n') {
                $rows = ([regex]::Matches($s, '(?m)^\s{4}\(')).Count
                [pscustomobject]@{ Table = $table; Sql = $s; Rows = $rows; Label = "$rows rows" }
            } else {
                $src = ([regex]::Match($s, '(?i)FROM (\w+\.\w+)')).Groups[1].Value
                [pscustomobject]@{ Table = $table; Sql = $s; Rows = -1; Label = "INSERT ... SELECT from $src" }
            }
        }
    }

    $ddlStatements = Split-Statements ([IO.File]::ReadAllText((Resolve-Path $Ddl)))
    $updating = [bool]$Update
    $inserts = if ($updating) { @(ConvertTo-Inserts ([IO.File]::ReadAllText((Resolve-Path $Update)))) }
               else { @(ConvertTo-Inserts ([IO.File]::ReadAllText((Resolve-Path $Seed)))) }
    $prefix = if ($updating) { 'update ' } else { '' }

    foreach ($d in $ddlStatements) { Write-Host (([regex]::Match($d, 'CREATE TABLE IF NOT EXISTS default\.\w+')).Value) }
    foreach ($s in $inserts) { Write-Host ("{0}default.{1}: {2}" -f $prefix, $s.Table, $s.Label) }
    if ($DryRun) { Write-Host '(dry run) nothing written'; return }

    $admin = Get-Credential -Message 'ClickHouse user that may create tables and insert into database default'
    if (-not $admin) { throw 'No credential entered' }
    $headers = @{ 'X-ClickHouse-User' = $admin.UserName.TrimStart('\'); 'X-ClickHouse-Key' = $admin.GetNetworkCredential().Password }
    function Invoke-Ch([string]$Sql) {
        $body = [Text.Encoding]::UTF8.GetBytes($Sql)
        return Invoke-RestMethod -Uri $Url -Method Post -Headers $headers -Body $body -ContentType 'text/plain; charset=utf-8'
    }
    # Invoke-RestMethod may turn a bare number reply into an Int32, so counts are read as text.
    function Get-Count([string]$Table) { return [long]([string](Invoke-Ch "SELECT count() FROM default.$Table FORMAT TabSeparated")).Trim() }

    foreach ($d in $ddlStatements) { Invoke-Ch $d | Out-Null }
    $before = @{}
    foreach ($s in $inserts) {
        if (-not $before.ContainsKey($s.Table)) { $before[$s.Table] = Get-Count $s.Table }
        if (-not $updating -and $before[$s.Table] -gt 0) { Write-Host "default.$($s.Table): skipped (already has $($before[$s.Table]) rows)"; continue }
        $start = Get-Count $s.Table
        Invoke-Ch $s.Sql | Out-Null
        $added = (Get-Count $s.Table) - $start
        if ($s.Rows -ge 0 -and $added -ne $s.Rows) { throw "default.$($s.Table): expected $($s.Rows) new rows, found $added" }
        Write-Host "${prefix}default.$($s.Table): inserted $added rows"
    }
}

Export-ModuleMember -Function Test-HnhReadOnlySql, Invoke-HnhSelect, ConvertTo-HnhTsvField, Get-HnhContractColumns,
    Compare-HnhColumns, Compare-HnhBscRows, New-HnhTableDdl, Test-HnhGlCutover, Test-HnhFsAccountMapping,
    Invoke-HnhConfigApply
