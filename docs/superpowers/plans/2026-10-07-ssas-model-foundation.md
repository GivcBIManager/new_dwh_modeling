# SSAS Tabular Model Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build, deploy and test the `HNH_Analytics` SSAS Tabular model (compatibility level 1700) over the gold layer, with views, security, perspectives, partitions, a calculation group, 16 starter measures and scripted deployment and processing.

**Architecture:** dbt views `gold.ssas_*` shape every column (types, Yes/No flags, dropped ids). A Python generator turns the view columns plus `ssas/tools/model_config.py` into a TMDL folder; roles, the calculation group, measures and hierarchies are hand-written and preserved by the generator. Windows PowerShell 5.1 scripts using the AMO/TOM DLLs of Tabular Editor 2 deploy, partition, process and test the model **on HNHANALYTICSSRV** (the laptop has no network path to it).

**Tech Stack:** dbt-core 1.11 + dbt-clickhouse 1.9.8 (ClickHouse 26.5), Python 3.13 + pytest + clickhouse_connect, Tabular Editor 2.27.2 (TMDL, CLI deploy, Best Practice Analyzer), SQL Server 2025 Analysis Services 17.0.25.218, Windows PowerShell 5.1 + Pester 3.4, MSOLAP OLE DB provider, ClickHouse ODBC driver (system DSN `HNH_Gold`).

**Spec:** `docs/superpowers/specs/2026-10-07-hnh-ssas-tabular-model-design.md` (sections 1–13 and the planning decisions P1–P14 in section 14). The full KPI catalogue (spec 8.1) is a second plan, written after this one is deployed.

## Global Constraints

- Server `HNHANALYTICSSRV\REPORTSERVERDB`; databases `HNH_Analytics` (production) and `HNH_Analytics_Test` (test slot); SSAS 17.0.25.218.
- Model: `compatibilityLevel: 1700`, `compatibilityMode: analysisServices`, culture `en-US`, `discourageImplicitMeasures`, Import mode, no calculated columns, no calculated tables.
- Data source `HNH_Gold` = `provider`, connection string `Provider=MSDASQL.1;Persist Security Info=False;Data Source=HNH_Gold`, `impersonationMode: impersonateServiceAccount`. No credential in git; the password lives only in the system DSN on the server.
- ClickHouse user `ssas_reader`: `readonly = 2`, `max_execution_time = 3600`, `GRANT SELECT ON gold.ssas_*` only.
- Views: dbt folder `hnh_dwh/models/hnh/marts/ssas/`, name `ssas_<gold table name without hnh_>`, `materialized: view`, `sql_security: definer`, `definer: CURRENT_USER`, tag `hnh_ssas`; built by `hnh_ssas_view()` (spec 4.2 + P2, P3).
- Role `HNH Readers` (read); its only member is the local group `HNHANALYTICSSRV\HNH_BI_Users`; `USERNAME()` = `HNHANALYTICSSRV\<user>` = `sec_user_access.login_name`.
- Partitions (large tables): yearly from 2022 to Y−2 (first one open below), monthly for Y−1 and Y, plus `<Table> Later` and `<Table> No date`. Daily = dimensions + last 3 months + Later + No date + small facts, then Calculate; Weekly = full.
- Budgets: model ≤ 10 GB (VertiPaq estimate); report-style queries < 1 s warm, < 3 s cold, run as a single-branch user.
- PowerShell scripts must run in Windows PowerShell 5.1: no ternary, no `??`, no `&&`/`||` pipeline chains, no `-Parallel`. Default Tabular Editor folder `C:\Program Files (x86)\Tabular Editor`.
- Delivery constraints (repo): dbt work stays under `hnh/` folders with `hnh_` macros, no packages, no seeds, no CSV in git; reference data is loaded once by `scripts/load_reference_data.py`.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Fact rows whose staff or patient key is missing from the dimension vanish for every row-filtered user** (a blank dimension member never passes a row filter). Expected: every user without a specialty restriction sees exactly the ClickHouse row count of their branches in every fact. Pinned in Task 14 (security stage "rows" checks) and Task 4 (nullable keys become −1).
2. **Year rollover:** on 1 January the new year's monthly partitions must exist and the oldest monthly year must collapse into one yearly partition without losing or doubling a row. Pinned in Task 12 (Pester: January plan, coverage of edge keys) and Task 14 (row counts).
3. **Arabic text through ODBC → MSDASQL → VertiPaq** must arrive as Unicode, not `?`. Pinned in Task 2 (spike `Max Text Code` = 1606) and Task 14 (Arabic staff name check).
4. **Snapshot measures under time items** (YTD of Headcount, Stock Value, GL Closing Balance) must return the snapshot, not a sum over months. Pinned in Task 11 (measure check "Headcount YTD equals current") and the calculation group exclusion list in Task 10.
5. **A failed or repeated dbt run must not be processed:** the gate opens only for the latest `tag:hnh` run with status `success` that is newer than the last processed one (Weekly ignores "newer"). Pinned in Task 12 (Pester `Test-HnhGate`) and Task 13.

## File Structure

```
scripts/create_ssas_reader.py                         Task 1  ClickHouse read-only user + check
scripts/load_reference_data.py                        Task 3  + map_bi_user_permission (empty when no CSV)
scripts/gen_view_contracts.py                         Task 7  writes the dbt contract YAML of the views
hnh_dwh/dbt_project.yml                               Task 4  ssas folder config
hnh_dwh/macros/hnh/hnh_ssas.sql                       Task 4  hnh_ssas_view / hnh_ssas_column
hnh_dwh/models/hnh/staging/reference/stg_ref__bi_user_permission.sql   Task 3
hnh_dwh/models/hnh/marts/conformed/sec_user_access.sql                 Task 3  + can_see_pay, can_see_pii
hnh_dwh/models/hnh/marts/ssas/ssas_*.sql              Tasks 4–6  79 views
hnh_dwh/models/hnh/marts/ssas/_ssas__sources.yml      Task 6  gold.etl_run_log source
hnh_dwh/models/hnh/marts/ssas/_ssas__models.yml       Task 7  generated contracts
hnh_dwh/tests/hnh/assert_ssas_view_rules.sql          Tasks 4, 7
hnh_dwh/tests/hnh/warn_permission_user_without_access.sql  Task 3
ssas/spike/                                           Task 2  throwaway probe model + spike.ps1
ssas/tools/hnh_tmdl.py, test_hnh_tmdl.py              Task 8  pure TMDL rendering + pytest
ssas/tools/model_config.py, generate.py               Task 9  model layout + generator CLI
ssas/HNH_Analytics/                                   Tasks 9–11 TMDL model (generated + hand-written)
ssas/bpa_rules.json                                   Task 11
ssas/scripts/HnhSsas.psm1, HnhSsas.Tests.ps1          Tasks 12–13
ssas/scripts/partitions.ps1, process.ps1              Task 13
ssas/scripts/test.ps1, ssas/tests/*                   Task 14
ssas/scripts/deploy.ps1, ssas/README.md, .gitignore   Task 15
docs/receiving_project_config.md                      Task 7
```

Tasks 2 and 16 run on HNHANALYTICSSRV: the user runs the commands and pastes the output; the implementer reviews it and fixes the repository.

---

### Task 1: ClickHouse read-only user `ssas_reader`

**Files:**
- Create: `scripts/create_ssas_reader.py`

**Interfaces:**
- Produces: ClickHouse user `ssas_reader` (password = env `HNH_SSAS_READER_PASSWORD`), which the user puts into the server's system DSN `HNH_Gold`. `python scripts/create_ssas_reader.py --check` is reused in Task 7.

- [ ] **Step 1: Write the script**

```python
"""Create or update the read-only ClickHouse user that SSAS reads through (SSAS spec 9.1, decision P8).

The password comes from the HNH_SSAS_READER_PASSWORD environment variable and is never printed or stored.
Statements run as the account resolved by ch_env (the authorised default account). Safe to re-run.

Usage:
  python scripts/create_ssas_reader.py           create or update ssas_reader and its grant
  python scripts/create_ssas_reader.py --check   connect as ssas_reader and check what it can and cannot do
"""
import argparse
import os
import sys

import clickhouse_connect

from ch_env import client, resolve_env

USER = "ssas_reader"


def password():
    value = os.environ.get("HNH_SSAS_READER_PASSWORD", "")
    if len(value) < 16:
        raise SystemExit("Set HNH_SSAS_READER_PASSWORD (at least 16 characters) before running this script")
    return value


def literal(value):
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


def create(pw):
    admin = client()
    for sql in (
        f"CREATE USER IF NOT EXISTS {USER} IDENTIFIED WITH sha256_password BY {literal(pw)}",
        f"ALTER USER {USER} IDENTIFIED WITH sha256_password BY {literal(pw)}",
        f"ALTER USER {USER} SETTINGS readonly = 2, max_execution_time = 3600",
        f"GRANT SELECT ON gold.ssas_* TO {USER}",
    ):
        admin.command(sql)
    print(f"{USER}: created or updated; SELECT on gold.ssas_*")


def refused(action):
    try:
        action()
    except Exception:
        return True
    return False


def first_ssas_view():
    rows = client().query(
        "select name from system.tables where database = 'gold' and startsWith(name, 'ssas_') order by name limit 1"
    ).result_rows
    return rows[0][0] if rows else None


def check(pw):
    env = resolve_env()
    reader = clickhouse_connect.get_client(
        host=env["HNH_CH_HOST"], port=int(env["HNH_CH_PORT"]), username=USER, password=pw
    )
    results = {
        "connects as ssas_reader": reader.query("select currentUser()").result_rows[0][0] == USER,
        "cannot read gold.dim_branch": refused(lambda: reader.query("select count() from gold.dim_branch")),
        "cannot create tables": refused(
            lambda: reader.command("create table default.ssas_reader_probe (a UInt8) engine = Memory")
        ),
    }
    view = first_ssas_view()
    if view:
        results[f"reads gold.{view}"] = not refused(lambda: reader.query(f"select count() from gold.{view}"))
    for name, ok in results.items():
        print(("PASS " if ok else "FAIL ") + name)
    return all(results.values())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    pw = password()
    if args.check:
        return 0 if check(pw) else 1
    create(pw)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run the check before the user exists (must fail)**

The user chooses the password and sets it in the shell (never in a file):

Run (PowerShell): `$env:HNH_SSAS_READER_PASSWORD = '<password chosen by the user>'; python scripts/create_ssas_reader.py --check`
Expected: an authentication error for `ssas_reader` (exception, non-zero exit).

- [ ] **Step 3: Create the user**

Run: `python scripts/create_ssas_reader.py`
Expected: `ssas_reader: created or updated; SELECT on gold.ssas_*`

- [ ] **Step 4: Run the check again**

Run: `python scripts/create_ssas_reader.py --check`
Expected: three `PASS` lines (no `reads gold.ssas_…` line yet: no view exists), exit code 0.

- [ ] **Step 5: Hand-off note to the user**

Tell the user: set the system DSN `HNH_Gold` on HNHANALYTICSSRV (64-bit ODBC Data Sources → System DSN → ClickHouse ODBC Driver (Unicode)) to user `ssas_reader` with this password, database `gold`.

- [ ] **Step 6: Commit**

```bash
git add scripts/create_ssas_reader.py
git commit -m "Add the read-only ClickHouse user for SSAS

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Server feasibility probe (run on HNHANALYTICSSRV by the user)

Throwaway. It proves, before any model work, that: TE2 deploys a 1700 / analysisServices TMDL model; SSAS processes through `MSDASQL` + ClickHouse ODBC with `SaveOptions.MaxParallelism`; Int64, nullable, Decimal, Float, Unicode text, Date and DateTime survive; a hidden fact key with `isAvailableInMdx: false` works in a relationship; the `FALSE()` security-table pattern and `USERNAME()` work through `EffectiveUserName`; `includeAll` perspectives deploy; DAX runs through the MSOLAP OLE DB provider.

**Files:**
- Create: `ssas/spike/Probe/database.tmdl`, `ssas/spike/Probe/dataSources.tmdl`, `ssas/spike/Probe/model.tmdl`, `ssas/spike/Probe/relationships.tmdl`, `ssas/spike/Probe/tables/Probe Dim.tmdl`, `ssas/spike/Probe/tables/Probe Fact.tmdl`, `ssas/spike/Probe/tables/Probe Users.tmdl`, `ssas/spike/Probe/roles/Probe Readers.tmdl`, `ssas/spike/Probe/perspectives/Probe View.tmdl`, `ssas/spike/spike.ps1`

**Interfaces:**
- Consumes: DSN `HNH_Gold` as `ssas_reader` (Task 1), TE2 folder on the server, local group `HNH_BI_Users` with at least one member.
- Produces: a PASS/FAIL report pasted by the user. If `process` or `msolap` fails, **stop and re-plan** (spec 9.1 fallback: Power Query `Odbc.Query`).

- [ ] **Step 1: Write the probe model**

`ssas/spike/Probe/database.tmdl`:
```
database HNH_Probe
	compatibilityLevel: 1700
	compatibilityMode: analysisServices
```

`ssas/spike/Probe/dataSources.tmdl`:
```
dataSource HNH_Gold = provider
	connectionString: Provider=MSDASQL.1;Persist Security Info=False;Data Source=HNH_Gold
	impersonationMode: impersonateServiceAccount
```

`ssas/spike/Probe/model.tmdl`:
```
model Model
	culture: en-US
	discourageImplicitMeasures

ref table 'Probe Dim'
ref table 'Probe Fact'
ref table 'Probe Users'

ref role 'Probe Readers'

ref perspective 'Probe View'
```

`ssas/spike/Probe/relationships.tmdl`:
```
relationship probe_fact__dim_key
	fromColumn: 'Probe Fact'.'Dim Key'
	toColumn: 'Probe Dim'.'Dim Key'
```

`ssas/spike/Probe/tables/Probe Dim.tmdl`:
```
table 'Probe Dim'

	column 'Dim Key'
		dataType: int64
		encodingHint: hash
		summarizeBy: none
		sourceColumn: dim_key

	column 'Dim Name'
		dataType: string
		summarizeBy: none
		sourceColumn: dim_name

	partition 'Probe Dim' = query
		source
			query = select toInt64(1) as dim_key, 'عنصر أول' as dim_name union all select toInt64(2), 'second'
			dataSource: HNH_Gold
```

`ssas/spike/Probe/tables/Probe Fact.tmdl`:
```
table 'Probe Fact'

	measure Amount = SUM ( 'Probe Fact'[Amount Value] )
		formatString: #,0.0000
		displayFolder: Probe

	measure 'Max Text Code' = UNICODE ( MAXX ( 'Probe Fact', 'Probe Fact'[Text Value] ) )
		formatString: 0
		displayFolder: Probe

	column 'Dim Key'
		dataType: int64
		isHidden
		isAvailableInMdx: false
		encodingHint: hash
		summarizeBy: none
		sourceColumn: dim_key

	column 'Date Key'
		dataType: int64
		isHidden
		isAvailableInMdx: false
		encodingHint: value
		summarizeBy: none
		sourceColumn: date_key

	column 'Optional Key'
		dataType: int64
		isHidden
		isAvailableInMdx: false
		summarizeBy: none
		sourceColumn: optional_key

	column 'Amount Value'
		dataType: decimal
		isHidden
		isAvailableInMdx: false
		formatString: #,0.00
		summarizeBy: none
		sourceColumn: amount_value

	column 'Optional Amount'
		dataType: decimal
		isHidden
		isAvailableInMdx: false
		formatString: #,0.00
		summarizeBy: none
		sourceColumn: optional_amount

	column Ratio
		dataType: double
		isHidden
		isAvailableInMdx: false
		formatString: #,0.00
		summarizeBy: none
		sourceColumn: ratio

	column 'Text Value'
		dataType: string
		summarizeBy: none
		sourceColumn: text_value

	column 'Optional Text'
		dataType: string
		summarizeBy: none
		sourceColumn: optional_text

	column Day
		dataType: dateTime
		formatString: yyyy-mm-dd
		summarizeBy: none
		sourceColumn: day

	column Moment
		dataType: dateTime
		formatString: yyyy-mm-dd hh:nn
		summarizeBy: none
		sourceColumn: moment

	column Flag
		dataType: string
		summarizeBy: none
		sourceColumn: flag

	partition 'Probe Fact' = query
		source
			query = select toInt64(1) as dim_key, toInt64(20260131) as date_key, cast(null as Nullable(Int64)) as optional_key, toDecimal64(1234.5678, 4) as amount_value, cast(null as Nullable(Decimal(18, 4))) as optional_amount, toFloat64(0.25) as ratio, 'نص عربي' as text_value, cast(null as Nullable(String)) as optional_text, toDate('2026-01-31') as day, toDateTime('2026-01-31 10:20:30', 'Asia/Riyadh') as moment, 'Yes' as flag union all select toInt64(2), toInt64(20260228), toNullable(toInt64(5)), toDecimal64(-1, 4), toNullable(toDecimal64(2, 4)), toFloat64(1.5), 'b', toNullable('x'), toDate('2026-02-28'), toDateTime('2026-02-28 00:00:00', 'Asia/Riyadh'), 'No'
			dataSource: HNH_Gold
```

`ssas/spike/Probe/tables/Probe Users.tmdl` (the spike script rewrites the query with the test login):
```
table 'Probe Users'
	isHidden

	column 'Login Name'
		dataType: string
		isHidden
		isAvailableInMdx: false
		summarizeBy: none
		sourceColumn: login_name

	column 'Dim Key'
		dataType: int64
		isHidden
		isAvailableInMdx: false
		summarizeBy: none
		sourceColumn: dim_key

	partition 'Probe Users' = query
		source
			query = select 'set-by-spike' as login_name, toInt64(1) as dim_key
			dataSource: HNH_Gold
```

`ssas/spike/Probe/roles/Probe Readers.tmdl`:
```
role 'Probe Readers'
	modelPermission: read

	tablePermission 'Probe Users' = FALSE ()

	tablePermission 'Probe Dim' =
			'Probe Dim'[Dim Key]
				IN CALCULATETABLE (
					VALUES ( 'Probe Users'[Dim Key] ),
					'Probe Users'[Login Name] = USERNAME ()
				)
```

`ssas/spike/Probe/perspectives/Probe View.tmdl`:
```
perspective 'Probe View'

	perspectiveTable 'Probe Fact'
		includeAll
```

- [ ] **Step 2: Validate the probe offline on the laptop**

Run (PowerShell): `& 'C:\Program Files (x86)\Tabular Editor\TabularEditor.exe' ssas\spike\Probe -B "$env:TEMP\hnh_probe.bim" | Out-String; $LASTEXITCODE`
Expected: `Loading model...`, `Building Model.bim file...`, exit code `0`.

- [ ] **Step 3: Write `ssas/spike/spike.ps1`**

```powershell
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
```

- [ ] **Step 4: Commit**

```bash
git add ssas/spike
git commit -m "Add the SSAS feasibility probe

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: The user runs the probe on the server**

Ask the user to: (1) confirm Task 1 step 5 (DSN uses `ssas_reader`); (2) copy the repository's `ssas` folder to the server (e.g. `D:\HNH\ssas`); (3) make sure Tabular Editor 2.27 is at `C:\Program Files (x86)\Tabular Editor` on the server (copy the laptop folder if needed); (4) run, in Windows PowerShell as an SSAS administrator:

`powershell -ExecutionPolicy Bypass -File D:\HNH\ssas\spike\spike.ps1 -TestUser HNHANALYTICSSRV\<a member of HNH_BI_Users>`

Expected: every line `PASS`, `0 failure(s)`. Record the output (versions, column types) in spec section 15 in Task 16.

- [ ] **Step 6: Decide**

All PASS → continue. `process` FAIL → stop and re-plan the data source (Power Query fallback). `msolap` FAIL → the user installs the "Analysis Services OLE DB provider (MSOLAP)" redistributable and re-runs. `username`/`row filter` FAIL → stop: security design must be revisited before Task 10. `odbc` FAIL → fix the DSN, re-run.

---
### Task 3: Pay and PII permissions in `sec_user_access`

**Files:**
- Modify: `scripts/load_reference_data.py` (SMALL_TABLES entry; `load_small` tolerates a missing CSV)
- Modify: `hnh_dwh/models/hnh/staging/reference/_reference__sources.yml` (add `map_bi_user_permission`)
- Modify: `hnh_dwh/models/hnh/staging/reference/_reference__models.yml` (add the staging model and tests)
- Create: `hnh_dwh/models/hnh/staging/reference/stg_ref__bi_user_permission.sql`
- Modify: `hnh_dwh/models/hnh/marts/conformed/sec_user_access.sql`
- Modify: `hnh_dwh/models/hnh/marts/conformed/_security_unit_tests.yml`
- Modify: `hnh_dwh/models/hnh/marts/conformed/_conformed__models.yml` (flag tests on `sec_user_access`)
- Create: `hnh_dwh/tests/hnh/warn_permission_user_without_access.sql`

**Interfaces:**
- Produces: `gold.sec_user_access.can_see_pay UInt8`, `gold.sec_user_access.can_see_pii UInt8` (0 unless listed). Reference table `default.map_bi_user_permission (bi_user_name String, can_see_pay UInt8, can_see_pii UInt8)`, loaded from `static_mappings/bi_user_permission.csv` (header `bi_user_name,can_see_pay,can_see_pii`; gitignored like every CSV). Task 4 exposes these as `ssas_sec_user_access`.

- [ ] **Step 1: Add the failing unit test**

In `hnh_dwh/models/hnh/marts/conformed/_security_unit_tests.yml`, add this input to the existing test `sec_user_access_grants_by_branch_and_specialty` (after the `stg_ref__branch` input):

```yaml
      - input: ref('stg_ref__bi_user_permission')
        format: sql
        rows: |
          select 'nobody' as user_name, toUInt8(0) as can_see_pay, toUInt8(0) as can_see_pii where 0
```

and append a new unit test at the end of the file:

```yaml
  - name: sec_user_access_permission_flags
    description: >
      SSAS spec 6.1. "boss" (admin) is listed with pay but not PII, so every one of boss's rows carries
      can_see_pay 1 and can_see_pii 0. "clerk" is not listed and gets 0 for both (fail closed).
    model: sec_user_access
    given:
      - input: ref('stg_ref__bi_users')
        format: sql
        rows: |
          select u as user_name, if(b = 0, cast(null as Nullable(UInt8)), toNullable(toUInt8(b))) as branch_id, toUInt8(a) as is_admin,
                 cast(null as Nullable(String)) as unified_specialty
          from values('u String, b UInt8, a UInt8', ('DOM\Boss', 0, 1), ('DOM\Clerk', 2, 0))
      - input: ref('stg_ref__branch')
        format: sql
        rows: |
          select toUInt8(b) as branch_id from values('b UInt8', (1), (2))
      - input: ref('stg_ref__bi_user_permission')
        format: sql
        rows: |
          select 'boss' as user_name, toUInt8(1) as can_see_pay, toUInt8(0) as can_see_pii
    expect:
      rows:
        - {user_name: boss, branch_key: 1, can_see_pay: 1, can_see_pii: 0}
        - {user_name: boss, branch_key: 2, can_see_pay: 1, can_see_pii: 0}
        - {user_name: boss, branch_key: 100, can_see_pay: 1, can_see_pii: 0}
        - {user_name: clerk, branch_key: 2, can_see_pay: 0, can_see_pii: 0}
```

- [ ] **Step 2: Run it to see it fail**

Run: `python scripts/run_dbt.py test --select "sec_user_access,test_type:unit"`
Expected: FAIL — `stg_ref__bi_user_permission` does not exist (compilation error: node not found).

- [ ] **Step 3: Loader entry and missing-file handling**

In `scripts/load_reference_data.py`, add to `SMALL_TABLES` after `map_opening_balance_batch`:

```python
    "map_bi_user_permission": (
        "bi_user_permission.csv",
        [("bi_user_name", "String", s), ("can_see_pay", "UInt8", b), ("can_see_pii", "UInt8", b)],
        "bi_user_name",
    ),
```

and in `load_small`, directly after the `if rows_in(client, table) > 0:` block, add:

```python
    if not (SRC / file).exists():
        return f"created empty ({file} not supplied)"
```

- [ ] **Step 4: Source, staging model and tests**

In `_reference__sources.yml`, add `      - name: map_bi_user_permission` after `map_opening_balance_batch`.

Create `stg_ref__bi_user_permission.sql`:

```sql
-- Pay and PII permissions of BI users (SSAS spec 6.1). One row per normalised user name; the source may carry an old
-- domain prefix, as bi_users does. A user who is not listed gets no permission (fail closed in sec_user_access).
select user_name, max(can_see_pay) as can_see_pay, max(can_see_pii) as can_see_pii
from (
    select
        {{ hnh_user_name('bi_user_name') }} as user_name,
        toUInt8(can_see_pay)                as can_see_pay,
        toUInt8(can_see_pii)                as can_see_pii
    from {{ source('reference', 'map_bi_user_permission') }}
)
where user_name != ''
group by user_name
```

In `_reference__models.yml`, add under `models:`:

```yaml
  - name: stg_ref__bi_user_permission
    columns:
      - name: user_name
        tests: [unique, not_null]
```

- [ ] **Step 5: Add the flags to `sec_user_access`**

In `sec_user_access.sql`, replace the final statement (from the last `select` through `{{ hnh_settings() }}`) with:

```sql
select
    a.user_name                                                          as user_name,
    f.source_user_name                                                   as source_user_name,
    concat('{{ var("hnh_ssas_machine_name") }}', char(92), a.user_name)   as login_name,
    a.branch_key                                                         as branch_key,
    a.unified_specialty                                                  as unified_specialty,
    a.is_admin                                                           as is_admin,
    toUInt8(ifNull(p.can_see_pay, 0))                                    as can_see_pay,
    toUInt8(ifNull(p.can_see_pii, 0))                                    as can_see_pii
from (
    select * from admins
    union all
    select * from restricted
    union distinct
    select * from specialty_wide
) as a
inner join first_source_name as f on f.user_name = a.user_name
left join {{ ref('stg_ref__bi_user_permission') }} as p on p.user_name = a.user_name
{{ hnh_settings() }}
```

In `_conformed__models.yml`, under `- name: sec_user_access` → `columns:`, add:

```yaml
      - name: can_see_pay
        tests:
          - not_null
          - accepted_values: {values: [0, 1], quote: false}
      - name: can_see_pii
        tests:
          - not_null
          - accepted_values: {values: [0, 1], quote: false}
```

Create `hnh_dwh/tests/hnh/warn_permission_user_without_access.sql`:

```sql
{{ config(severity='warn') }}
-- SSAS spec 6.1: a user listed in map_bi_user_permission who has no sec_user_access row gets nothing; list them so the
-- BI manager can fix the name.
select p.user_name
from {{ ref('stg_ref__bi_user_permission') }} as p
left join (select distinct user_name from {{ ref('sec_user_access') }}) as s on s.user_name = p.user_name
where s.user_name is null or s.user_name = ''
{{ hnh_settings() }}
```

- [ ] **Step 6: Load the table and build**

Run: `python scripts/load_reference_data.py --only map_bi_user_permission`
Expected: `default.map_bi_user_permission: created empty (bi_user_permission.csv not supplied) -> 0 rows in table` (or `loaded N` if the user already placed the CSV).

Run: `python scripts/run_dbt.py build --select stg_ref__bi_user_permission+ --exclude tag:hnh_ssas`
Expected: both unit tests, the flag tests and `warn_permission_user_without_access` PASS; ERROR=0.

- [ ] **Step 7: Commit**

```bash
git add scripts/load_reference_data.py hnh_dwh/models/hnh/staging/reference hnh_dwh/models/hnh/marts/conformed hnh_dwh/tests/hnh/warn_permission_user_without_access.sql
git commit -m "Add pay and PII permission flags to sec_user_access

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: View macro and dimension views

**Files:**
- Modify: `hnh_dwh/dbt_project.yml`
- Create: `hnh_dwh/macros/hnh/hnh_ssas.sql`
- Create: `hnh_dwh/tests/hnh/assert_ssas_view_rules.sql`
- Create: 41 files in `hnh_dwh/models/hnh/marts/ssas/` (39 dimension views, `ssas_dim_staff_role`, `ssas_sec_user_access`)

**Interfaces:**
- Produces: macro `hnh_ssas_view(model_name, drop=[], decimals=[], floats=[], int_flags=[], extra=[], joins='')`, used by every view in Tasks 5–6. Views `gold.ssas_dim_*`, `gold.ssas_dim_staff_role` and `gold.ssas_sec_user_access` (columns `login_name, branch_key, unified_specialty, is_admin, can_see_pay, can_see_pii`).

- [ ] **Step 1: Folder config**

In `hnh_dwh/dbt_project.yml`, under `models: hnh_dwh: hnh: marts:` (after `+tags: ["hnh_gold"]`), add:

```yaml
        ssas:
          +materialized: view
          +sql_security: definer
          +definer: CURRENT_USER
          +tags: ["hnh_ssas"]
```

- [ ] **Step 2: Write the rules test**

Create `hnh_dwh/tests/hnh/assert_ssas_view_rules.sql`:

```sql
-- SSAS spec 4.2 and planning decisions P2/P3: every gold.ssas_* view exposes Int64 integers, Decimal amounts, no arrays,
-- no legacy or load columns, no nullable non-date keys, and the large line facts carry no line ids. Returns violations.
{% set db = ref('ssas_dim_branch').schema %}
with cols as (
    select table, name, type
    from system.columns
    where database = '{{ db }}' and startsWith(table, 'ssas_')
)
select table, name, type, 'type not allowed' as rule
from cols
where match(type, 'Array|UInt|Int8|Int16|Int32|Float32|Date32|LowCardinality')
union all
select table, name, type, 'legacy or load column'
from cols
where startsWith(name, 'legacy_') or name = '_loaded_at'
union all
select table, name, type, 'amount stored as Float64'
from cols
where type like '%Float64%' and match(name, '(amount|_value$|cost|debit|credit|_pay$|fee|price|salary|_rate$|revenue)')
union all
select table, name, type, 'nullable non-date key'
from cols
where type like 'Nullable%' and endsWith(name, '_key') and not match(name, '(date|time)_key$')
union all
select table, name, type, 'line id kept on a large line fact'
from cols
where table in ('ssas_fact_charge_line', 'ssas_fact_order_line', 'ssas_fact_stock_movement',
                'ssas_fact_patient_consumption', 'ssas_fact_claim_line')
  and name in ('charge_line_key', 'order_line_key', 'movement_key', 'claim_line_key', 'delivery_charge_id',
               'delivery_line', 'invoice_doc_no', 'master_order_no', 'order_line', 'oasis_line_id', 'oasis_doc_no',
               'fusion_transaction_id', 'claim_invoice_no', 'stat_invoice_no', 'visit_id', 'sequence_no', 'lot_number')
```

- [ ] **Step 3: Make it fail with a raw view**

Create `hnh_dwh/models/hnh/marts/ssas/ssas_dim_branch.sql` temporarily as:

```sql
select * from {{ ref('hnh_dim_branch') }}
```

Run: `python scripts/run_dbt.py build --select ssas_dim_branch assert_ssas_view_rules`
Expected: the view builds; `assert_ssas_view_rules` FAILS with rows for `branch_key UInt8` (type not allowed) and `legacy_current_available_beds` (legacy column).

- [ ] **Step 4: Write the macro**

Create `hnh_dwh/macros/hnh/hnh_ssas.sql`:

```jinja
{#
  SSAS spec 4.2 and planning decisions P2/P3. Select list of a gold.ssas_* view over ref(model_name):
  - legacy_* and _loaded_at are always dropped, `drop` lists more; an Array column must be dropped;
  - every Float column must be named in `decimals` (cast to Decimal(18, 4)) or `floats` (kept as Float64);
  - an is_*/has_* UInt8 flag becomes 'Yes'/'No' unless named in `int_flags` (flags that measures sum);
  - every other integer becomes Int64, and a nullable non-date *_key becomes -1 when null;
  - LowCardinality text becomes String, Date32 becomes Date;
  - `extra` appends select expressions; `joins` follows `from <model> as t`.
  A name in drop/decimals/floats/int_flags that is not a column fails compilation (typo guard).
#}
{% macro hnh_ssas_view(model_name, drop=[], decimals=[], floats=[], int_flags=[], extra=[], joins='') -%}
{%- set relation = ref(model_name) -%}
{%- if execute -%}
    {%- set columns = adapter.get_columns_in_relation(relation) -%}
    {%- set names = columns | map(attribute='name') | list -%}
    {%- for listed in drop + decimals + floats + int_flags -%}
        {%- if listed not in names -%}
            {{ exceptions.raise_compiler_error('hnh_ssas_view(' ~ model_name ~ '): unknown column ' ~ listed) }}
        {%- endif -%}
    {%- endfor -%}
    {%- set expressions = [] -%}
    {%- for c in columns -%}
        {%- if c.name not in drop and not c.name.startswith('legacy_') and c.name != '_loaded_at' -%}
            {%- do expressions.append(hnh_ssas_column(model_name, c.name, c.data_type, decimals, floats, int_flags) ~ ' as ' ~ c.name) -%}
        {%- endif -%}
    {%- endfor %}
select
    {{ (expressions + extra) | join(',\n    ') }}
from {{ relation }} as t
{{ joins }}
{%- else %}
select 1 as compile_placeholder from {{ relation }}
{%- endif -%}
{%- endmacro %}

{% macro hnh_ssas_column(model_name, name, data_type, decimals, floats, int_flags) -%}
{%- set ns = namespace(t=data_type, nullable=false, lowcard=false) -%}
{%- if ns.t.startswith('LowCardinality(') -%}{%- set ns.t = ns.t[15:-1] -%}{%- set ns.lowcard = true -%}{%- endif -%}
{%- if ns.t.startswith('Nullable(') -%}{%- set ns.t = ns.t[9:-1] -%}{%- set ns.nullable = true -%}{%- endif -%}
{%- if ns.t.startswith('LowCardinality(') -%}{%- set ns.t = ns.t[15:-1] -%}{%- set ns.lowcard = true -%}{%- endif -%}
{%- set col = 't.' ~ name -%}
{%- if ns.t.startswith('Array(') -%}
    {{ exceptions.raise_compiler_error('hnh_ssas_view(' ~ model_name ~ '): drop array column ' ~ name) }}
{%- elif ns.t.startswith('Float') -%}
    {%- if name in decimals -%}toDecimal64({{ col }}, 4)
    {%- elif name in floats -%}toFloat64({{ col }})
    {%- else -%}{{ exceptions.raise_compiler_error('hnh_ssas_view(' ~ model_name ~ '): list float column ' ~ name ~ ' in decimals or floats') }}
    {%- endif -%}
{%- elif ns.t.startswith('Int') or ns.t.startswith('UInt') -%}
    {%- if name in int_flags -%}toInt64({{ col }})
    {%- elif ns.t == 'UInt8' and (name.startswith('is_') or name.startswith('has_')) -%}if({{ col }} = 1, 'Yes', 'No')
    {%- elif ns.nullable and name.endswith('_key') and not name.endswith('date_key') and not name.endswith('time_key') -%}toInt64(ifNull({{ col }}, -1))
    {%- else -%}toInt64({{ col }})
    {%- endif -%}
{%- elif ns.t == 'Date32' -%}toDate({{ col }})
{%- elif ns.lowcard -%}cast({{ col }} as {{ 'Nullable(String)' if ns.nullable else 'String' }})
{%- else -%}{{ col }}
{%- endif -%}
{%- endmacro %}
```

- [ ] **Step 5: Write the dimension and security views**

Each row gives the complete content of `hnh_dwh/models/hnh/marts/ssas/<file>`. `ssas_dim_branch.sql` replaces the raw view of Step 3. Before writing, confirm each `ref()` name with `ls hnh_dwh/models/hnh/marts/conformed hnh_dwh/models/hnh/marts/experience` (the `hnh_`-prefixed models carry an alias in gold).

| File | Content |
|---|---|
| `ssas_dim_date.sql` | `{{ hnh_ssas_view('dim_date') }}` |
| `ssas_dim_time.sql` | `{{ hnh_ssas_view('dim_time') }}` |
| `ssas_dim_branch.sql` | `{{ hnh_ssas_view('hnh_dim_branch') }}` |
| `ssas_dim_care_type.sql` | `{{ hnh_ssas_view('dim_care_type') }}` |
| `ssas_dim_department.sql` | `{{ hnh_ssas_view('hnh_dim_department') }}` |
| `ssas_dim_staff.sql` | `{{ hnh_ssas_view('dim_staff', drop=['national_id_hash', 'home_department_key'], floats=['clinic_duration_hours', 'slots_per_hour']) }}` |
| `ssas_dim_patient.sql` | `{{ hnh_ssas_view('dim_patient') }}` |
| `ssas_dim_patient_pii.sql` | `{{ hnh_ssas_view('dim_patient_pii') }}` |
| `ssas_dim_payer.sql` | `{{ hnh_ssas_view('dim_payer') }}` |
| `ssas_dim_service.sql` | `{{ hnh_ssas_view('dim_service') }}` |
| `ssas_dim_product_category.sql` | `{{ hnh_ssas_view('dim_product_category') }}` |
| `ssas_dim_admission_source.sql` | `{{ hnh_ssas_view('dim_admission_source') }}` |
| `ssas_dim_appointment_outcome.sql` | `{{ hnh_ssas_view('dim_appointment_outcome') }}` |
| `ssas_dim_discharge_outcome.sql` | `{{ hnh_ssas_view('dim_discharge_outcome') }}` |
| `ssas_dim_eligibility_type.sql` | `{{ hnh_ssas_view('dim_eligibility_type') }}` |
| `ssas_dim_er_priority.sql` | `{{ hnh_ssas_view('dim_er_priority') }}` |
| `ssas_dim_bed.sql` | `{{ hnh_ssas_view('dim_bed', drop=['current_department_key']) }}` |
| `ssas_dim_procedure_type.sql` | `{{ hnh_ssas_view('dim_procedure_type') }}` |
| `ssas_dim_preauth_outcome.sql` | `{{ hnh_ssas_view('dim_preauth_outcome') }}` |
| `ssas_dim_nphies_reason.sql` | `{{ hnh_ssas_view('dim_nphies_reason') }}` |
| `ssas_dim_fs_line.sql` | `{{ hnh_ssas_view('dim_fs_line') }}` |
| `ssas_dim_gl_account.sql` | `{{ hnh_ssas_view('hnh_dim_gl_account', drop=['intercompany_branch_key']) }}` |
| `ssas_dim_gl_period.sql` | `{{ hnh_ssas_view('hnh_dim_gl_period') }}` |
| `ssas_dim_budget_line.sql` | `{{ hnh_ssas_view('dim_budget_line') }}` |
| `ssas_dim_supplier.sql` | `{{ hnh_ssas_view('hnh_dim_supplier', drop=['oasis_branch_key']) }}` |
| `ssas_dim_item.sql` | `{{ hnh_ssas_view('hnh_dim_item') }}` |
| `ssas_dim_store.sql` | `{{ hnh_ssas_view('dim_store', drop=['store_group_key']) }}` |
| `ssas_dim_movement_type.sql` | `{{ hnh_ssas_view('dim_movement_type') }}` |
| `ssas_dim_employee.sql` | `{{ hnh_ssas_view('hnh_dim_employee', drop=['person_id', 'birth_date', 'hr_department_key', 'job_key', 'grade_key', 'position_key', 'location_key', 'staff_key']) }}` |
| `ssas_dim_hr_department.sql` | `{{ hnh_ssas_view('hnh_dim_hr_department') }}` |
| `ssas_dim_job.sql` | `{{ hnh_ssas_view('hnh_dim_job') }}` |
| `ssas_dim_grade.sql` | `{{ hnh_ssas_view('hnh_dim_grade') }}` |
| `ssas_dim_position.sql` | `{{ hnh_ssas_view('hnh_dim_position') }}` |
| `ssas_dim_location.sql` | `{{ hnh_ssas_view('hnh_dim_location') }}` |
| `ssas_dim_worker_action.sql` | `{{ hnh_ssas_view('hnh_dim_worker_action') }}` |
| `ssas_dim_absence_type.sql` | `{{ hnh_ssas_view('hnh_dim_absence_type') }}` |
| `ssas_dim_pay_category.sql` | `{{ hnh_ssas_view('dim_pay_category') }}` |
| `ssas_dim_survey_service.sql` | `{{ hnh_ssas_view('dim_survey_service') }}` |
| `ssas_dim_survey_question.sql` | `{{ hnh_ssas_view('dim_survey_question') }}` |
| `ssas_sec_user_access.sql` | `{{ hnh_ssas_view('sec_user_access', drop=['user_name', 'source_user_name'], int_flags=['is_admin']) }}` |

`ssas_dim_staff_role.sql` (role-playing copies, spec 4.1 and 5.2):

```sql
-- Staff columns for the role-playing copies Booked Doctor, Admission Treating Doctor and Anaesthetist (SSAS spec 5.2).
-- No row filter applies to the copies; their fact rows are already secured through branch and the primary staff role.
select
    toInt64(staff_key)  as staff_key,
    staff_name,
    staff_name_ar,
    staff_grade,
    category,
    specialty,
    unified_specialty
from {{ ref('dim_staff') }}
```

- [ ] **Step 6: Check the typo guard**

Temporarily change `ssas_dim_bed.sql` to `drop=['current_department_kye']`.
Run: `python scripts/run_dbt.py compile --select ssas_dim_bed`
Expected: compilation error `hnh_ssas_view(dim_bed): unknown column current_department_kye`. Restore the file.

- [ ] **Step 7: Build and test**

Run: `python scripts/run_dbt.py build --select tag:hnh_ssas`
Expected: 41 views built, `assert_ssas_view_rules` PASS, ERROR=0.

Run: `python -c "import sys; sys.path.insert(0,'scripts'); import ch_env; print(ch_env.client().query(\"select position(create_table_query, 'SQL SECURITY DEFINER') > 0 from system.tables where database='gold' and name='ssas_dim_branch'\").result_rows)"`
Expected: `[(1,)]`. If the view has no `SQL SECURITY DEFINER`, or creation failed with a DEFINER error: remove `+sql_security`/`+definer` from the folder config, change the grant in `scripts/create_ssas_reader.py` to `GRANT SELECT ON gold.* TO ssas_reader` (and drop the "cannot read gold.dim_branch" check), and record the change in spec section 14.

- [ ] **Step 8: Commit**

```bash
git add hnh_dwh/dbt_project.yml hnh_dwh/macros/hnh/hnh_ssas.sql hnh_dwh/tests/hnh/assert_ssas_view_rules.sql hnh_dwh/models/hnh/marts/ssas
git commit -m "Add the SSAS view macro and the dimension and security views

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Fact views — patient flow, revenue cycle, claims

**Files:**
- Create: 16 files in `hnh_dwh/models/hnh/marts/ssas/`

**Interfaces:**
- Consumes: `hnh_ssas_view` (Task 4).
- Produces: the views below. The partition columns used later (Task 9 `model_config.py`) are kept in every view: `delivery_date_key`, `order_date_key`, `statement_end_date_key`, `receipt_date_key`, `request_date_key`, `encounter_date_key`, `start_date_key`, `invoice_date_key`, `date_key`, `last_delivery_date_key`.

The drop lists apply spec 4.2 rules 1–3 and 8 and decision D8 (document numbers only on document-level facts).

- [ ] **Step 1: Write the views**

| File | Content |
|---|---|
| `ssas_fact_encounter.sql` | `{{ hnh_ssas_view('fact_encounter', drop=['encounter_key', 'episode_key', 'wait_minutes_raw', 'door_to_triage_minutes_raw', 'service_minutes_raw', 'er_los_minutes_raw']) }}` |
| `ssas_fact_episode.sql` | `{{ hnh_ssas_view('fact_episode', drop=['episode_key']) }}` |
| `ssas_fact_admission.sql` | `{{ hnh_ssas_view('fact_admission', drop=['admission_key', 'encounter_key', 'episode_key', 'admitted_at', 'physical_discharge_at', 'planned_admit_at'], floats=['los_hours', 'los_days', 'los_days_to_date', 'critical_bed_hours']) }}` |
| `ssas_fact_bed_occupancy_daily.sql` | `{{ hnh_ssas_view('fact_bed_occupancy_daily', drop=['patient_key', 'admission_key'], int_flags=['is_available', 'is_occupied']) }}` |
| `ssas_fact_surgery.sql` | `{{ hnh_ssas_view('fact_surgery', drop=['surgery_key', 'episode_key', 'operation_seq', 'hall_to_theatre_minutes_raw', 'anaesthesia_minutes_raw', 'operating_minutes_raw', 'recovery_handover_minutes_raw']) }}` |
| `ssas_agg_clinic_capacity_daily.sql` | `{{ hnh_ssas_view('agg_clinic_capacity_daily') }}` |
| `ssas_fact_target_daily.sql` | `{{ hnh_ssas_view('fact_target_daily', decimals=['target_revenue', 'target_cost_total', 'target_cost_per_episode'], floats=['target_census', 'target_episodes', 'target_patient_days', 'target_alos']) }}` |
| `ssas_fact_charge_line.sql` | `{{ hnh_ssas_view('fact_charge_line', drop=['charge_line_key', 'episode_key', 'encounter_key', 'admission_key', 'delivery_charge_id', 'delivery_line', 'encounter_id', 'admission_no', 'invoice_doc_no', 'package_id', 'billed_purchaser_code', 'episode_purchaser_code', 'cancel_reason_code'], decimals=['net_amount', 'line_discount_amount', 'gross_amount', 'vat_amount', 'revenue_amount', 'package_content_amount', 'claimable_amount'], floats=['units']) }}` |
| `ssas_fact_order_line.sql` | `{{ hnh_ssas_view('fact_order_line', drop=['order_line_key', 'episode_key', 'master_order_no', 'order_line', 'status_reason'], decimals=['ordered_value', 'charged_amount'], floats=['unit_fulfilment_ratio', 'units_ordered', 'units_delivered']) }}` |
| `ssas_fact_invoice.sql` | `{{ hnh_ssas_view('fact_invoice', drop=['invoice_key', 'episode_key'], decimals=['gross_amount', 'discount_amount', 'net_amount', 'vat_amount', 'total_amount']) }}` |
| `ssas_fact_cash_receipt.sql` | `{{ hnh_ssas_view('fact_cash_receipt', drop=['receipt_key', 'episode_key', 'doc_id', 'doc_no'], decimals=['receipt_amount']) }}` |
| `ssas_fact_revenue_adjustment.sql` | `{{ hnh_ssas_view('fact_revenue_adjustment', drop=['adjustment_key', 'episode_key', 'doc_id'], decimals=['adjustment_amount', 'base_invoice_net_amount']) }}` |
| `ssas_agg_episode_billing.sql` | `{{ hnh_ssas_view('agg_episode_billing', drop=['episode_key'], decimals=['claimable_amount', 'invoiced_net_amount', 'unbilled_amount', 'overbilled_amount']) }}` |
| `ssas_fact_preauth_line.sql` | `{{ hnh_ssas_view('fact_preauth_line', drop=['preauth_line_key', 'episode_key', 'request_to_sent_minutes_raw', 'sent_to_response_minutes_raw', 'total_turnaround_minutes_raw', 'line_natural_id', 'authorisation_no', 'api_trans_id', 'item_no', 'requested_at', 'first_sent_at', 'final_responded_at', 'last_responded_at', 'payer_comment', 'reason_codes', 'preauth_reference', 'preauth_valid_from', 'preauth_valid_to', 'episode_match_count', 'pull_count'], decimals=['approved_estimated_amount', 'estimated_amount', 'nphies_approved_amount', 'payer_eligible_amount', 'payer_approved_amount'], floats=['requested_qty', 'approved_qty', 'used_qty']) }}` |
| `ssas_fact_claim_line.sql` | `{{ hnh_ssas_view('fact_claim_line', drop=['claim_line_key', 'episode_key', 'invoice_key', 'visit_id', 'sequence_no', 'claim_invoice_no', 'stat_invoice_no', 'service_code', 'reason_codes'], decimals=['claimed_amount', 'submitted_amount', 'eligible_amount', 'approved_amount', 'copay_amount', 'deductible_amount', 'patient_share_amount', 'tax_amount', 'rejected_amount'], floats=['approved_qty']) }}` |
| `ssas_fact_claim_payment.sql` | `{{ hnh_ssas_view('fact_claim_payment', drop=['claim_payment_key', 'episode_key', 'invoice_key', 'visit_id', 'claim_api_trans_id', 'payer_claim_response_id', 'reconciliation_id'], decimals=['payment_amount', 'payment_component', 'early_fee', 'nphies_fee']) }}` |

- [ ] **Step 2: Build and test**

Run: `python scripts/run_dbt.py build --select tag:hnh_ssas`
Expected: 57 views, `assert_ssas_view_rules` PASS, ERROR=0. A compilation error `list float column X in decimals or floats` or `unknown column X` means gold changed since planning: add the column to the right list (amounts → `decimals`) or remove the stale name, and say so in the task report.

- [ ] **Step 3: Spot-check row counts**

Run: `python -c "import sys; sys.path.insert(0,'scripts'); import ch_env; c=ch_env.client(); print([(v, c.query(f'select (select count() from gold.ssas_{v}) = (select count() from gold.{v})').result_rows[0][0]) for v in ['fact_charge_line','fact_claim_line','fact_encounter','agg_episode_billing']])"`
Expected: every pair ends with `1`.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/ssas
git commit -m "Add SSAS views for patient flow, revenue cycle and claims facts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Fact views — finance, workforce, supply chain, patient experience; run-log view

**Files:**
- Create: 21 fact views and `ssas_etl_run_log.sql` in `hnh_dwh/models/hnh/marts/ssas/`
- Create: `hnh_dwh/models/hnh/marts/ssas/_ssas__sources.yml`

**Interfaces:**
- Produces: `gold.ssas_fact_gl_balance_monthly.period_end_date_key Int64` (spec 4.2 rule 9); `gold.ssas_etl_run_log (invocation_id, run_started_at, run_finished_at, status, models_built, nodes_failed, selected)` read by `process.ps1` (Task 13).

- [ ] **Step 1: Write the views**

| File | Content |
|---|---|
| `ssas_fact_gl_journal_line.sql` | `{{ hnh_ssas_view('hnh_fact_gl_journal_line', drop=['gl_journal_line_key', 'je_header_id', 'je_line_num', 'intercompany_branch_key', 'ledger_id', 'je_batch_id', 'line_description'], decimals=['debit', 'credit', 'amount']) }}` |
| `ssas_fact_income_statement_monthly.sql` | `{{ hnh_ssas_view('fact_income_statement_monthly', drop=['income_statement_key', 'month_start', 'budget_line_code'], decimals=['actual_posted', 'actual_including_unposted', 'actual_excl_opening', 'budget_most_likely', 'budget_worst_case']) }}` |
| `ssas_fact_budget_monthly.sql` | `{{ hnh_ssas_view('fact_budget_monthly', drop=['budget_month_key', 'budget_line_code', 'month_start'], decimals=['budget_amount']) }}` |
| `ssas_fact_ap_invoice_line.sql` | `{{ hnh_ssas_view('fact_ap_invoice_line', drop=['ap_invoice_line_key', 'accounting_date_key_nn', 'invoice_id', 'po_distribution_id', 'rcv_transaction_id'], decimals=['amount', 'spend_amount', 'tax_amount', 'prepayment_amount']) }}` |
| `ssas_fact_ap_open_item.sql` | `{{ hnh_ssas_view('fact_ap_open_item', drop=['ap_open_item_key', 'invoice_id'], decimals=['gross_amount', 'amount_remaining']) }}` |
| `ssas_fact_ap_payment.sql` | `{{ hnh_ssas_view('hnh_fact_ap_payment', drop=['ap_payment_key', 'invoice_payment_id', 'payment_date_key_nn', 'bank_account_id', 'invoice_id'], decimals=['amount']) }}` |
| `ssas_fact_headcount_monthly.sql` | `{{ hnh_ssas_view('fact_headcount_monthly', drop=['headcount_key', 'month_end'], floats=['fte']) }}` |
| `ssas_fact_worker_movement.sql` | `{{ hnh_ssas_view('hnh_fact_worker_movement', drop=['movement_key', 'previous_branch_key', 'action_code']) }}` |
| `ssas_fact_payroll_monthly.sql` | `{{ hnh_ssas_view('fact_payroll_monthly', drop=['payroll_key', 'payee_key', 'paid_person_key', 'pay_category', 'payroll_month'], decimals=['amount', 'cost_amount', 'gross_pay']) }}` |
| `ssas_fact_leave_balance_monthly.sql` | `{{ hnh_ssas_view('fact_leave_balance_monthly', drop=['leave_balance_key', 'absence_plan_id'], decimals=['monthly_salary', 'daily_rate', 'leave_liability_amount'], floats=['begin_balance', 'accrued', 'used', 'end_balance']) }}` |
| `ssas_fact_absence.sql` | `{{ hnh_ssas_view('fact_absence', drop=['absence_key'], floats=['absence_days', 'absence_hours']) }}` |
| `ssas_fact_absence_daily.sql` | `{{ hnh_ssas_view('fact_absence_daily', drop=['absence_day_key']) }}` |
| `ssas_agg_staff_productivity_monthly.sql` | `{{ hnh_ssas_view('agg_staff_productivity_monthly', drop=['month_start'], decimals=['revenue_amount', 'payroll_cost', 'gross_pay'], floats=['fte', 'absence_days']) }}` |
| `ssas_fact_stock_movement.sql` | `{{ hnh_ssas_view('fact_stock_movement', drop=['movement_key', 'movement_type', 'oasis_line_id', 'oasis_doc_no', 'oasis_product_code', 'fusion_transaction_id', 'fusion_transaction_date_key', 'unit_cost', 'lot_number', 'expiry_date'], decimals=['cost_amount', 'oasis_cost_amount', 'consumption_cost'], floats=['primary_quantity', 'consumption_quantity']) }}` |
| `ssas_fact_patient_consumption.sql` | `{{ hnh_ssas_view('fact_patient_consumption', drop=['movement_key', 'movement_type', 'encounter_key', 'episode_key', 'charge_line_key'], decimals=['cost_amount', 'consumption_cost', 'revenue_amount', 'oasis_cost_amount'], floats=['primary_quantity', 'consumption_quantity']) }}` |
| `ssas_fact_stock_monthly.sql` | `{{ hnh_ssas_view('fact_stock_monthly', drop=['stock_monthly_key', 'month_end'], decimals=['stock_value', 'consumption_cost'], floats=['quantity', 'consumption_quantity']) }}` |
| `ssas_fact_purchase_line.sql` | `{{ hnh_ssas_view('fact_purchase_line', drop=['purchase_line_key', 'fusion_line_location_id', 'oasis_line_id'], decimals=['unit_price', 'ordered_value', 'gross_ordered_value', 'received_value', 'ap_matched_amount'], floats=['quantity_ordered', 'quantity_received', 'quantity_cancelled', 'quantity_billed']) }}` |
| `ssas_fact_goods_receipt.sql` | `{{ hnh_ssas_view('fact_goods_receipt', drop=['goods_receipt_key', 'purchase_line_key', 'oasis_line_id', 'fusion_transaction_id'], decimals=['unit_price', 'received_value'], floats=['quantity', 'free_quantity']) }}` |
| `ssas_fact_survey_response.sql` | `{{ hnh_ssas_view('fact_survey_response', drop=['surveycode', 'encounter_key', 'episode_key', 'encounter_id'], floats=['nps_score', 'physician_nps_score']) }}` |
| `ssas_fact_survey_answer.sql` | `{{ hnh_ssas_view('fact_survey_answer', drop=['surveycode', 'question_code', 'encounter_key'], floats=['answer_score'], int_flags=['is_promoter', 'is_passive', 'is_detractor']) }}` |

`ssas_fact_gl_balance_monthly.sql` (spec 4.2 rule 9; an adjustment period carries its quarter's end date):

```sql
{{ hnh_ssas_view('fact_gl_balance_monthly',
    decimals=['opening_balance', 'period_debit', 'period_credit', 'period_movement', 'period_movement_excl_opening', 'closing_balance'],
    extra=['toInt64(p.end_date_key) as period_end_date_key'],
    joins='inner join ' ~ ref('hnh_dim_gl_period') ~ ' as p on p.period_key = t.period_key') }}
```

`_ssas__sources.yml`:

```yaml
version: 2

sources:
  - name: hnh_log
    schema: gold
    description: Run log appended by the hnh_log_run on-run-end hook (not a dbt model).
    tables:
      - name: etl_run_log
```

`ssas_etl_run_log.sql`:

```sql
-- Processing gate for SSAS (spec 9.4): process.ps1 reads the latest tag:hnh run through the ssas_reader grant.
select
    invocation_id,
    run_started_at,
    run_finished_at,
    cast(status as String)  as status,
    toInt64(models_built)   as models_built,
    toInt64(nodes_failed)   as nodes_failed,
    selected
from {{ source('hnh_log', 'etl_run_log') }}
```

- [ ] **Step 2: Build and test**

Run: `python scripts/run_dbt.py build --select tag:hnh_ssas`
Expected: 79 views, `assert_ssas_view_rules` PASS, ERROR=0 (same handling of compile errors as Task 5 Step 2).

- [ ] **Step 3: Check the GL balance join keeps every row**

Run: `python -c "import sys; sys.path.insert(0,'scripts'); import ch_env; print(ch_env.client().query('select (select count() from gold.ssas_fact_gl_balance_monthly) = (select count() from gold.fact_gl_balance_monthly), (select countIf(period_end_date_key = 0) from gold.ssas_fact_gl_balance_monthly)').result_rows)"`
Expected: `[(1, 0)]`.

- [ ] **Step 4: Commit**

```bash
git add hnh_dwh/models/hnh/marts/ssas
git commit -m "Add SSAS views for finance, workforce, supply and experience facts and the run log

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: View contracts, complete rules test, receiving-project notes

**Files:**
- Create: `scripts/gen_view_contracts.py`
- Create: `hnh_dwh/models/hnh/marts/ssas/_ssas__models.yml` (generated)
- Modify: `hnh_dwh/tests/hnh/assert_ssas_view_rules.sql` (view count)
- Modify: `docs/receiving_project_config.md`

**Interfaces:**
- Produces: enforced dbt contracts on all 79 views, so a gold change that alters a view's columns fails `dbt build` (spec 4.2 rule 10).

- [ ] **Step 1: Add the view-count check (fails now if a view is missing)**

Append to `assert_ssas_view_rules.sql`:

```sql
union all
select 'gold' as table, toString(count()) as name, 'views' as type, 'expected 79 ssas_ views' as rule
from system.tables
where database = '{{ db }}' and startsWith(name, 'ssas_')
having count() != 79
```

Run: `python scripts/run_dbt.py test --select assert_ssas_view_rules`
Expected: PASS (79 views exist after Task 6). If it fails, list the views and find the missing file.

- [ ] **Step 2: Write the contract generator**

```python
"""Write the dbt contracts (column names and ClickHouse types) of every gold.ssas_* view (SSAS plan task 7).

Run after `dbt build --select tag:hnh_ssas` whenever a view's columns change on purpose, then commit the YAML.
Usage: python scripts/gen_view_contracts.py
"""
from pathlib import Path

from ch_env import client

OUT = Path(__file__).resolve().parent.parent / "hnh_dwh" / "models" / "hnh" / "marts" / "ssas" / "_ssas__models.yml"


def main():
    rows = client().query(
        "select table, name, type from system.columns "
        "where database = 'gold' and startsWith(table, 'ssas_') order by table, position"
    ).result_rows
    lines = ["version: 2", "", "# Generated by scripts/gen_view_contracts.py from the built views; do not edit by hand.", "models:"]
    current = None
    for table, name, typ in rows:
        if table != current:
            lines += [f"  - name: {table}", "    config:", "      contract: {enforced: true}", "    columns:"]
            current = table
        lines += [f"      - name: {name}", f'        data_type: "{typ}"']
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"{OUT}: {len({r[0] for r in rows})} views, {len(rows)} columns")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Generate and build with contracts**

Run: `python scripts/gen_view_contracts.py`
Expected: `…_ssas__models.yml: 79 views, N columns`.

Run: `python scripts/run_dbt.py build --select tag:hnh_ssas`
Expected: PASS, ERROR=0. If dbt reports a contract type mismatch whose only difference is formatting (for example `Decimal(18, 4)` vs `Decimal(18,4)`), change the generator to write the form dbt expects and regenerate.

- [ ] **Step 4: Prove the contract bites**

Temporarily add `'units'` to the `drop` list of `ssas_fact_charge_line.sql`.
Run: `python scripts/run_dbt.py build --select ssas_fact_charge_line`
Expected: ERROR — contract mismatch (column `units` missing). Revert the change and re-run: PASS.

- [ ] **Step 5: Check the reader grant on a real view**

Run (PowerShell, password in the session as in Task 1): `python scripts/create_ssas_reader.py --check`
Expected: four `PASS` lines including `reads gold.ssas_agg_clinic_capacity_daily` (the first view by name).

- [ ] **Step 6: Receiving-project notes**

In `docs/receiving_project_config.md`:
1. In the "Add to `dbt/dbt_project.yml`" block, under `marts:` add the same `ssas:` folder config as Task 4 Step 1.
2. Add a section `## SSAS views and access (2026-10-07)` with these bullets:
   - `models/hnh/marts/ssas/` builds 79 `gold.ssas_*` views (tag `hnh_ssas`, `SQL SECURITY DEFINER`, enforced contracts). SSAS reads only these views.
   - After changing a view's columns on purpose, run `python scripts/gen_view_contracts.py` in the development repository and copy the regenerated `_ssas__models.yml`.
   - Reference table `default.map_bi_user_permission (bi_user_name, can_see_pay, can_see_pii)` holds the pay and PII permissions; a user not listed has neither (fail closed). Load it with `scripts/load_reference_data.py --only map_bi_user_permission`.
   - ClickHouse user `ssas_reader` (`readonly = 2`, `SELECT ON gold.ssas_*`) is created by `scripts/create_ssas_reader.py`; the SSAS server's system DSN `HNH_Gold` uses it.

- [ ] **Step 7: Commit**

```bash
git add scripts/gen_view_contracts.py hnh_dwh/models/hnh/marts/ssas/_ssas__models.yml hnh_dwh/tests/hnh/assert_ssas_view_rules.sql docs/receiving_project_config.md
git commit -m "Enforce contracts on the SSAS views and document them for the receiving project

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: TMDL rendering library (pure Python, pytest)

**Files:**
- Create: `ssas/tools/test_hnh_tmdl.py`
- Create: `ssas/tools/hnh_tmdl.py`

**Interfaces:**
- Produces (used by `generate.py` in Task 9):
  - dataclasses `Table(view, name, kind, description, partition_column=None)` with `kind` in `date | dim | role_copy | security | fact`; `Column(name, ch_type)`; `Relationship(from_table, from_column, to_table, to_column, active=True, one_to_one_both=False)`.
  - `friendly(name) -> str`, `q(name) -> str`, `unwrap(ch_type) -> (base, nullable)`, `tmdl_type(ch_type) -> str`, `display_name(table, column, overrides) -> str`
  - `column_lines(table, col, overrides, sort_by) -> list[str]`, `partition_lines(table) -> list[str]`, `kept_blocks(text) -> list[str]`, `render_table(table, columns, overrides, sort_by, kept) -> str`
  - `derive_relationships(table, columns, cfg) -> list[Relationship]` where `cfg` has `ROLE_KEYS`, `NO_RELATIONSHIP`, `ACTIVE_DATE`, `ACTIVE_TIME`, `DIM_KEYS`; `check_relationships(rels, tables) -> None`
  - `relationship_name(rel) -> str`, `render_relationships(rels, col_display) -> str`, `perspective_tables(facts, rels, extra) -> list[str]`, `render_perspective(name, tables) -> str`, `render_model(table_names, role_names, perspective_names) -> str`
  - constants `DATABASE_TMDL`, `DATA_SOURCES_TMDL`

- [ ] **Step 1: Write the failing tests**

Create `ssas/tools/test_hnh_tmdl.py`:

```python
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))

import hnh_tmdl as t  # noqa: E402

FACT = t.Table("ssas_fact_charge_line", "Charge Lines", "fact", "One charge line.", "delivery_date_key")
DIM = t.Table("ssas_dim_branch", "Branch", "dim", "Branches.")
DATE = t.Table("ssas_dim_date", "Date", "date", "Days.")

CFG = SimpleNamespace(
    DIM_KEYS={"branch_key": ("Branch", "branch_key"), "staff_key": ("Staff", "staff_key")},
    ROLE_KEYS={("Charge Lines", "episode_payer_key"): ("Payer", "payer_key", False),
               ("Charge Lines", "billed_payer_key"): ("Payer", "payer_key", True)},
    NO_RELATIONSHIP={("Charge Lines", "order_key")},
    ACTIVE_DATE={"Charge Lines": "delivery_date_key"},
    ACTIVE_TIME={"Charge Lines": "delivery_time_key"},
)


def test_friendly_names_and_acronyms():
    assert t.friendly("los_days") == "LOS Days"
    assert t.friendly("staff_name_ar") == "Staff Name AR"
    assert t.friendly("can_see_pii") == "Can See PII"
    assert t.friendly("is_icu_readmission_48h") == "Is ICU Readmission 48h"


def test_quoting():
    assert t.q("Branch") == "Branch"
    assert t.q("Charge Lines") == "'Charge Lines'"
    assert t.q("Patient's") == "'Patient''s'"


def test_types():
    assert t.unwrap("LowCardinality(Nullable(String))") == ("String", True)
    assert t.tmdl_type("Nullable(Int64)") == "int64"
    assert t.tmdl_type("Decimal(18, 4)") == "decimal"
    assert t.tmdl_type("Float64") == "double"
    assert t.tmdl_type("DateTime('Asia/Riyadh')") == "dateTime"
    with pytest.raises(ValueError):
        t.tmdl_type("Array(String)")


def test_fact_amount_is_hidden_without_attribute_hierarchy():
    lines = t.column_lines(FACT, t.Column("revenue_amount", "Decimal(18, 4)"), {}, {})
    assert lines[0] == "\tcolumn 'Revenue Amount'"
    assert "\t\tdataType: decimal" in lines
    assert "\t\tisHidden" in lines
    assert "\t\tisAvailableInMdx: false" in lines
    assert "\t\tformatString: #,0.00" in lines
    assert lines[-1] == "\t\tsourceColumn: revenue_amount"


def test_fact_text_stays_visible():
    lines = t.column_lines(FACT, t.Column("charge_status", "String"), {}, {})
    assert "\t\tisHidden" not in lines


def test_key_encoding_hints():
    surrogate = t.column_lines(FACT, t.Column("staff_key", "Int64"), {}, {})
    date_key = t.column_lines(FACT, t.Column("delivery_date_key", "Int64"), {}, {})
    assert "\t\tencodingHint: hash" in surrogate
    assert "\t\tencodingHint: value" in date_key


def test_dimension_key_keeps_attribute_hierarchy():
    lines = t.column_lines(DIM, t.Column("branch_key", "Int64"), {}, {})
    assert "\t\tisHidden" in lines
    assert "\t\tisAvailableInMdx: false" not in lines


def test_date_key_column_override_and_sort():
    overrides = {("ssas_dim_date", "date_day"): "Date"}
    day = t.column_lines(DATE, t.Column("date_day", "Date"), overrides, {})
    assert day[0] == "\tcolumn Date" and "\t\tisKey" in day and "\t\tformatString: yyyy-mm-dd" in day
    month = t.column_lines(DATE, t.Column("month_name", "String"), overrides, {("ssas_dim_date", "month_name"): "month"})
    assert "\t\tsortByColumn: Month" in month


def test_partitions():
    assert t.partition_lines(FACT)[2] == "\t\t\tquery = select * from gold.ssas_fact_charge_line where 1 = 0"
    assert t.partition_lines(FACT)[0] == "\tpartition 'Charge Lines template' = query"
    assert t.partition_lines(DIM)[2] == "\t\t\tquery = select * from gold.ssas_dim_branch"


def test_kept_blocks_keep_measures_and_hierarchies_verbatim():
    text = (
        "/// One charge line.\n"
        "table 'Charge Lines'\n"
        "\n"
        "\t/// Recognised revenue.\n"
        "\tmeasure Revenue =\n"
        "\t\t\tSUM ( 'Charge Lines'[Revenue Amount] )\n"
        "\t\tformatString: #,0\n"
        "\n"
        "\t\tformatStringDefinition = \"#,0\"\n"
        "\n"
        "\t/// a column description that must not be kept\n"
        "\tcolumn 'Revenue Amount'\n"
        "\t\tdataType: decimal\n"
        "\n"
        "\thierarchy Calendar\n"
        "\n"
        "\t\tlevel Year\n"
        "\t\t\tcolumn: Year\n"
    )
    blocks = t.kept_blocks(text)
    assert blocks[0].startswith("\t/// Recognised revenue.\n\tmeasure Revenue =")
    assert blocks[0].endswith('formatStringDefinition = "#,0"')
    assert "column 'Revenue Amount'" not in blocks[0]
    assert blocks[1].startswith("\thierarchy Calendar") and blocks[1].endswith("\t\t\tcolumn: Year")
    assert len(blocks) == 2


def test_render_table_puts_kept_blocks_first_and_annotations_last():
    text = t.render_table(FACT, [t.Column("delivery_date_key", "Int64")], {}, {}, ["\tmeasure X = 1"])
    lines = text.splitlines()
    assert lines[0] == "/// One charge line." and lines[1] == "table 'Charge Lines'"
    assert lines.index("\tmeasure X = 1") < lines.index("\tcolumn 'Delivery Date Key'")
    assert lines[-1] == "\tannotation hnh_partition_column = delivery_date_key"
    with pytest.raises(ValueError):
        t.render_table(FACT, [t.Column("branch_key", "Int64")], {}, {}, [])


def test_derive_relationships():
    cols = [t.Column(n, "Int64") for n in
            ["branch_key", "delivery_date_key", "posted_date_key", "delivery_time_key", "billed_payer_key",
             "episode_payer_key", "order_key", "units"]]
    rels = {(r.from_column, r.to_table, r.active) for r in t.derive_relationships(FACT, cols, CFG)}
    assert rels == {
        ("branch_key", "Branch", True), ("delivery_date_key", "Date", True), ("posted_date_key", "Date", False),
        ("delivery_time_key", "Time", True), ("billed_payer_key", "Payer", True), ("episode_payer_key", "Payer", False),
    }
    with pytest.raises(ValueError):
        t.derive_relationships(FACT, [t.Column("mystery_key", "Int64")], CFG)
    assert t.derive_relationships(DIM, [t.Column("branch_key", "Int64")], CFG) == []


def test_check_relationships():
    ok = [t.Relationship("Charge Lines", "delivery_date_key", "Date", "date_key")]
    t.check_relationships(ok, [FACT])
    twice = ok + [t.Relationship("Charge Lines", "posted_date_key", "Date", "date_key")]
    with pytest.raises(ValueError):
        t.check_relationships(twice, [FACT])
    no_active = [t.Relationship("Charge Lines", "posted_date_key", "Date", "date_key", active=False)]
    with pytest.raises(ValueError):
        t.check_relationships(no_active, [FACT])


def test_render_relationships():
    rels = [t.Relationship("Charge Lines", "episode_payer_key", "Payer", "payer_key", active=False),
            t.Relationship("Patient Details", "patient_key", "Patient", "patient_key", one_to_one_both=True)]
    text = t.render_relationships(rels, lambda table, col: t.friendly(col))
    assert "relationship charge_lines_episode_payer_key\n\tisActive: false\n" in text
    assert "\tfromColumn: 'Charge Lines'.'Episode Payer Key'\n\ttoColumn: Payer.'Payer Key'" in text
    assert "\tcrossFilteringBehavior: bothDirections\n\tfromCardinality: one" in text


def test_perspective_closure_follows_snowflake_but_not_one_to_one():
    rels = [t.Relationship("GL Balances", "gl_account_key", "GL Account", "gl_account_key"),
            t.Relationship("GL Account", "fs_line_key", "FS Line", "fs_line_key"),
            t.Relationship("Patient Details", "patient_key", "Patient", "patient_key", one_to_one_both=True)]
    assert t.perspective_tables(["GL Balances"], rels, []) == ["FS Line", "GL Account", "GL Balances"]
    assert t.perspective_tables([], rels, ["Patient Details"]) == ["Patient Details"]
    text = t.render_perspective("Finance", ["GL Balances"])
    assert text == "perspective Finance\n\n\tperspectiveTable 'GL Balances'\n\t\tincludeAll\n"


def test_render_model():
    text = t.render_model(["Branch", "Charge Lines"], ["HNH Readers"], ["Finance"])
    assert text.startswith("model Model\n\tculture: en-US\n\tdiscourageImplicitMeasures\n")
    assert "ref table 'Charge Lines'\n" in text and "ref role 'HNH Readers'\n" in text
    assert text.endswith("ref perspective Finance\n")
    assert "compatibilityMode: analysisServices" in t.DATABASE_TMDL
```

- [ ] **Step 2: Run to see it fail**

Run: `python -m pytest ssas/tools -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'hnh_tmdl'`.

- [ ] **Step 3: Implement `ssas/tools/hnh_tmdl.py`**

```python
"""Pure TMDL rendering for the HNH_Analytics model (SSAS spec 4.3, 5, 7; planning decisions P4, P5, P7, P11).

generate.py does the I/O. Nothing here talks to ClickHouse, so the rules are unit-tested in test_hnh_tmdl.py.
"""
import re
from dataclasses import dataclass
from typing import Optional

ACRONYMS = {
    "abc", "alos", "ap", "ar", "cchi", "ctas", "dama", "er", "fs", "fte", "gl", "grn", "hhc", "hr", "icu", "id",
    "ios", "ip", "je", "los", "ltc", "moh", "mrn", "nphies", "nps", "op", "pg", "pii", "po", "sar", "scfhs", "sms",
    "tpa", "uom", "vat",
}
DATA_SOURCE = "HNH_Gold"
GOLD = "gold"

DATABASE_TMDL = (
    "database HNH_Analytics\n"
    "\tcompatibilityLevel: 1700\n"
    "\tcompatibilityMode: analysisServices\n"
)
DATA_SOURCES_TMDL = (
    f"dataSource {DATA_SOURCE} = provider\n"
    "\tconnectionString: Provider=MSDASQL.1;Persist Security Info=False;Data Source=HNH_Gold\n"
    "\timpersonationMode: impersonateServiceAccount\n"
)


@dataclass(frozen=True)
class Table:
    view: str
    name: str
    kind: str  # date | dim | role_copy | security | fact
    description: str
    partition_column: Optional[str] = None


@dataclass(frozen=True)
class Column:
    name: str
    ch_type: str


@dataclass(frozen=True)
class Relationship:
    from_table: str
    from_column: str
    to_table: str
    to_column: str
    active: bool = True
    one_to_one_both: bool = False


def friendly(name: str) -> str:
    """'los_days' -> 'LOS Days', 'staff_name_ar' -> 'Staff Name AR'."""
    words = [w for w in name.split("_") if w]
    return " ".join(w.upper() if w in ACRONYMS else w[:1].upper() + w[1:] for w in words)


def q(name: str) -> str:
    """TMDL object name, single-quoted unless it is a plain identifier."""
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
        return name
    return "'" + name.replace("'", "''") + "'"


def unwrap(ch_type: str) -> tuple[str, bool]:
    """Strip LowCardinality(...) and Nullable(...) wrappers; return (base type, nullable)."""
    base, nullable, changed = ch_type, False, True
    while changed:
        changed = False
        for wrapper in ("LowCardinality(", "Nullable("):
            if base.startswith(wrapper):
                base, changed = base[len(wrapper):-1], True
                nullable = nullable or wrapper == "Nullable("
    return base, nullable


def tmdl_type(ch_type: str) -> str:
    base, _ = unwrap(ch_type)
    if base.startswith(("Int", "UInt")):
        return "int64"
    if base.startswith("Decimal"):
        return "decimal"
    if base.startswith("Float"):
        return "double"
    if base.startswith(("DateTime", "Date")):
        return "dateTime"
    if base == "String":
        return "string"
    raise ValueError(f"unsupported ClickHouse type {ch_type}")


def display_name(table: Table, column: str, overrides: dict) -> str:
    return overrides.get((table.view, column)) or friendly(column)


def _format_string(dtype: str, base: str, hidden: bool) -> Optional[str]:
    if dtype in ("decimal", "double"):
        return "#,0.00"
    if dtype == "dateTime":
        return "yyyy-mm-dd" if base == "Date" else "yyyy-mm-dd hh:nn"
    if dtype == "int64" and not hidden:
        return "0"
    return None


def column_lines(table: Table, col: Column, overrides: dict, sort_by: dict) -> list[str]:
    dtype = tmdl_type(col.ch_type)
    base, _ = unwrap(col.ch_type)
    is_key = col.name.endswith("_key")
    numeric = dtype in ("int64", "decimal", "double")
    hidden = table.kind == "security" or is_key or (table.kind == "fact" and numeric)
    lines = [f"\tcolumn {q(display_name(table, col.name, overrides))}", f"\t\tdataType: {dtype}"]
    if hidden:
        lines.append("\t\tisHidden")
        if table.kind in ("fact", "security"):
            lines.append("\t\tisAvailableInMdx: false")
    if is_key and dtype == "int64":
        lines.append("\t\tencodingHint: " + ("value" if col.name.endswith(("date_key", "time_key")) else "hash"))
    if table.kind == "date" and col.name == "date_day":
        lines.append("\t\tisKey")
    fmt = _format_string(dtype, base, hidden)
    if fmt:
        lines.append(f"\t\tformatString: {fmt}")
    lines.append("\t\tsummarizeBy: none")
    sort = sort_by.get((table.view, col.name))
    if sort:
        lines.append(f"\t\tsortByColumn: {q(display_name(table, sort, overrides))}")
    lines.append(f"\t\tsourceColumn: {col.name}")
    return lines


def partition_lines(table: Table) -> list[str]:
    if table.partition_column:
        name, where = f"{table.name} template", " where 1 = 0"
    else:
        name, where = table.name, ""
    return [
        f"\tpartition {q(name)} = query",
        "\t\tsource",
        f"\t\t\tquery = select * from {GOLD}.{table.view}{where}",
        f"\t\t\tdataSource: {DATA_SOURCE}",
    ]


def kept_blocks(text: str) -> list[str]:
    """Measure and hierarchy blocks (with their /// descriptions) of an existing table file, verbatim."""
    blocks, current, doc = [], None, []
    for line in text.splitlines():
        top = line.startswith("\t") and not line.startswith("\t\t")
        outer = not line.startswith("\t") and line.strip() != ""
        if top or outer:
            if current is not None:
                blocks.append("\n".join(current).rstrip())
                current = None
            body = line[1:] if top else ""
            if top and body.startswith("///"):
                doc.append(line)
                continue
            if top and body.startswith(("measure ", "hierarchy ")):
                current = doc + [line]
            doc = []
        elif current is not None:
            current.append(line)
    if current is not None:
        blocks.append("\n".join(current).rstrip())
    return blocks


def render_table(table: Table, columns: list[Column], overrides: dict, sort_by: dict, kept: list[str]) -> str:
    if table.partition_column and table.partition_column not in [c.name for c in columns]:
        raise ValueError(f"{table.name}: partition column {table.partition_column} is not in {table.view}")
    out = [f"/// {table.description}", f"table {q(table.name)}"]
    if table.kind == "security":
        out.append("\tisHidden")
    if table.kind == "date":
        out.append("\tdataCategory: Time")
    for block in kept:
        out += ["", block]
    for col in columns:
        out += [""] + column_lines(table, col, overrides, sort_by)
    out += [""] + partition_lines(table)
    out += ["", f"\tannotation hnh_kind = {table.kind}", f"\tannotation hnh_view = {table.view}"]
    if table.partition_column:
        out.append(f"\tannotation hnh_partition_column = {table.partition_column}")
    return "\n".join(out) + "\n"


def derive_relationships(table: Table, columns: list[Column], cfg) -> list[Relationship]:
    rels = []
    for col in columns:
        key = (table.name, col.name)
        if key in cfg.ROLE_KEYS:
            to_table, to_column, active = cfg.ROLE_KEYS[key]
        elif table.kind != "fact" or not col.name.endswith("_key") or key in cfg.NO_RELATIONSHIP:
            continue
        elif col.name.endswith("date_key"):
            to_table, to_column, active = "Date", "date_key", cfg.ACTIVE_DATE.get(table.name) == col.name
        elif col.name.endswith("time_key"):
            to_table, to_column, active = "Time", "time_key", cfg.ACTIVE_TIME.get(table.name) == col.name
        elif col.name in cfg.DIM_KEYS:
            (to_table, to_column), active = cfg.DIM_KEYS[col.name], True
        else:
            raise ValueError(
                f"{table.name}.{col.name}: no relationship rule (add it to DIM_KEYS, ROLE_KEYS or NO_RELATIONSHIP)"
            )
        rels.append(Relationship(table.name, col.name, to_table, to_column, active))
    return rels


def check_relationships(rels: list[Relationship], tables: list[Table]) -> None:
    active = {}
    for r in rels:
        if r.active:
            pair = (r.from_table, r.to_table)
            if pair in active:
                raise ValueError(f"two active relationships {pair[0]} -> {pair[1]}: {active[pair]} and {r.from_column}")
            active[pair] = r.from_column
    for table in tables:
        has_date = any(r.from_table == table.name and r.to_table == "Date" for r in rels)
        if table.kind == "fact" and has_date and (table.name, "Date") not in active:
            raise ValueError(f"{table.name}: no active date relationship (set ACTIVE_DATE)")


def relationship_name(rel: Relationship) -> str:
    return re.sub(r"[^a-z0-9]+", "_", f"{rel.from_table} {rel.from_column}".lower()).strip("_")


def render_relationships(rels: list[Relationship], col_display) -> str:
    out = []
    for r in sorted(rels, key=relationship_name):
        out.append(f"relationship {relationship_name(r)}")
        if not r.active:
            out.append("\tisActive: false")
        if r.one_to_one_both:
            out += ["\tcrossFilteringBehavior: bothDirections", "\tfromCardinality: one"]
        out.append(f"\tfromColumn: {q(r.from_table)}.{q(col_display(r.from_table, r.from_column))}")
        out.append(f"\ttoColumn: {q(r.to_table)}.{q(col_display(r.to_table, r.to_column))}")
        out.append("")
    return "\n".join(out)


def perspective_tables(facts: list[str], rels: list[Relationship], extra: list[str]) -> list[str]:
    tables = set(facts) | set(extra)
    changed = True
    while changed:
        changed = False
        for r in rels:
            if r.from_table in tables and r.to_table not in tables and not r.one_to_one_both:
                tables.add(r.to_table)
                changed = True
    return sorted(tables)


def render_perspective(name: str, tables: list[str]) -> str:
    out = [f"perspective {q(name)}"]
    for table in tables:
        out += ["", f"\tperspectiveTable {q(table)}", "\t\tincludeAll"]
    return "\n".join(out) + "\n"


def render_model(table_names: list[str], role_names: list[str], perspective_names: list[str]) -> str:
    out = ["model Model", "\tculture: en-US", "\tdiscourageImplicitMeasures", ""]
    out += [f"ref table {q(n)}" for n in table_names]
    if role_names:
        out += [""] + [f"ref role {q(n)}" for n in role_names]
    if perspective_names:
        out += [""] + [f"ref perspective {q(n)}" for n in perspective_names]
    return "\n".join(out) + "\n"
```

- [ ] **Step 4: Run the tests**

Run: `python -m pytest ssas/tools -q`
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add ssas/tools/hnh_tmdl.py ssas/tools/test_hnh_tmdl.py
git commit -m "Add the TMDL rendering library for the SSAS model

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Model layout and first generation of the TMDL folder

**Files:**
- Create: `ssas/tools/model_config.py`
- Create: `ssas/tools/generate.py`
- Create (generated): `ssas/HNH_Analytics/database.tmdl`, `dataSources.tmdl`, `model.tmdl`, `relationships.tmdl`, `tables/*.tmdl` (80 files), `perspectives/*.tmdl` (9 files)

**Interfaces:**
- Consumes: `hnh_tmdl` (Task 8), the 79 views (Tasks 4–7), `scripts/ch_env.py`.
- Produces: table names used by every later task (`Charge Lines`, `Encounters`, `Headcount`, `User Access`, …); table annotations `hnh_kind`, `hnh_view`, `hnh_partition_column` read by the PowerShell scripts (Tasks 12–14). Re-running `python ssas/tools/generate.py` is safe at any time: it keeps measure and hierarchy blocks, `roles/` and `tables/Time Calculation.tmdl`.

- [ ] **Step 1: Write `ssas/tools/model_config.py`**

```python
"""Layout of the HNH_Analytics model: tables, relationship rules, display names and perspectives
(SSAS spec 4, 5, 7 and planning decisions P11, P13). generate.py combines this with the gold.ssas_* columns."""
from hnh_tmdl import Relationship, Table

TABLES = [
    Table("ssas_dim_date", "Date", "date", "Calendar days 2008-2028 with Gregorian and Hijri attributes; the date table."),
    Table("ssas_dim_time", "Time", "dim", "Minutes of the day with hour, quarter hour and shift."),
    Table("ssas_dim_branch", "Branch", "dim", "Hospital branches 1-8 and Head Office (100)."),
    Table("ssas_dim_care_type", "Care Type", "dim", "Outpatient, emergency, inpatient and other care types."),
    Table("ssas_dim_department", "Department", "dim", "Oasis clinics, wards and service departments with unified department."),
    Table("ssas_dim_staff", "Staff", "dim", "Oasis staff and doctors with specialty; filtered to the user's branches and specialties."),
    Table("ssas_dim_staff_role", "Booked Doctor", "role_copy", "Doctor the encounter was booked with (copy of Staff for this role)."),
    Table("ssas_dim_staff_role", "Admission Treating Doctor", "role_copy", "Treating doctor of the admission (copy of Staff for this role)."),
    Table("ssas_dim_staff_role", "Anaesthetist", "role_copy", "Anaesthetist of the surgery (copy of Staff for this role)."),
    Table("ssas_dim_patient", "Patient", "dim", "Patients per branch without personal identifiers; filtered to the user's branches."),
    Table("ssas_dim_patient_pii", "Patient Details", "dim", "Patient names and identifiers; visible only to users with PII access."),
    Table("ssas_dim_payer", "Payer", "dim", "Purchasers (insurers, companies, cash) with category and MOH flag."),
    Table("ssas_dim_service", "Service", "dim", "Billable services (IOS) with product groups."),
    Table("ssas_dim_product_category", "Product Category", "dim", "Product categories with unified and high-level departments."),
    Table("ssas_dim_admission_source", "Admission Source", "dim", "How the patient was admitted."),
    Table("ssas_dim_appointment_outcome", "Appointment Outcome", "dim", "Appointment and visit outcomes."),
    Table("ssas_dim_discharge_outcome", "Discharge Outcome", "dim", "Discharge outcomes with MOH codes."),
    Table("ssas_dim_eligibility_type", "Eligibility Type", "dim", "Visit eligibility types and free follow-up days."),
    Table("ssas_dim_er_priority", "ER Priority", "dim", "Emergency triage priorities (CTAS) with target minutes."),
    Table("ssas_dim_bed", "Bed", "dim", "Beds with class, classification and critical flag."),
    Table("ssas_dim_procedure_type", "Procedure Type", "dim", "Surgery procedure types."),
    Table("ssas_dim_preauth_outcome", "Pre-auth Outcome", "dim", "Final outcomes of pre-authorisation lines."),
    Table("ssas_dim_nphies_reason", "NPHIES Reason", "dim", "NPHIES adjudication and rejection reasons."),
    Table("ssas_dim_fs_line", "FS Line", "dim", "Financial statement lines with sort orders and display sign."),
    Table("ssas_dim_gl_account", "GL Account", "dim", "Fusion code combinations with natural account and FS line."),
    Table("ssas_dim_gl_period", "GL Period", "dim", "Fusion accounting periods including quarterly adjustment periods."),
    Table("ssas_dim_budget_line", "Budget Line", "dim", "Income statement budget lines and subtotals."),
    Table("ssas_dim_supplier", "Supplier", "dim", "Suppliers from Fusion and Oasis."),
    Table("ssas_dim_item", "Item", "dim", "Inventory items from Fusion and Oasis with item group."),
    Table("ssas_dim_store", "Store", "dim", "Stores and subinventories with store type."),
    Table("ssas_dim_movement_type", "Movement Type", "dim", "Stock movement types with direction and consumption flag."),
    Table("ssas_dim_employee", "Employee", "dim", "Fusion workers (current state) with age and tenure bands."),
    Table("ssas_dim_hr_department", "HR Department", "dim", "Fusion HR departments with unified department."),
    Table("ssas_dim_job", "Job", "dim", "Fusion jobs."),
    Table("ssas_dim_grade", "Grade", "dim", "Fusion grades."),
    Table("ssas_dim_position", "Position", "dim", "Fusion positions."),
    Table("ssas_dim_location", "Location", "dim", "Fusion work locations."),
    Table("ssas_dim_worker_action", "Worker Action", "dim", "HR actions and reasons with movement group."),
    Table("ssas_dim_absence_type", "Absence Type", "dim", "Absence types and plans."),
    Table("ssas_dim_pay_category", "Pay Category", "dim", "Pay categories; visible only to users with pay access."),
    Table("ssas_dim_survey_service", "Survey Service", "dim", "Press Ganey survey services."),
    Table("ssas_dim_survey_question", "Survey Question", "dim", "Survey questions with domain, scale and NPS role."),
    Table("ssas_sec_user_access", "User Access", "security", "Branches, specialties and pay/PII permissions per login (security table)."),
    # Facts and aggregates; the fifth field is the partition column of the large tables (spec 9.3).
    Table("ssas_fact_charge_line", "Charge Lines", "fact", "One Oasis charge line (delivered service or item).", "delivery_date_key"),
    Table("ssas_fact_order_line", "Order Lines", "fact", "One order line with its fulfilment status.", "order_date_key"),
    Table("ssas_fact_stock_movement", "Stock Movements", "fact", "One stock movement line from Oasis or Fusion.", "date_key"),
    Table("ssas_fact_patient_consumption", "Patient Consumption", "fact", "Items consumed by patients with cost and revenue.", "date_key"),
    Table("ssas_fact_claim_line", "Claim Lines", "fact", "One NPHIES claim line per submission.", "statement_end_date_key"),
    Table("ssas_fact_claim_payment", "Claim Payments", "fact", "Payer remittance and advances from NPHIES."),
    Table("ssas_fact_cash_receipt", "Cash Receipts", "fact", "Patient receipts, cancellations and refunds.", "receipt_date_key"),
    Table("ssas_fact_invoice", "Invoices", "fact", "One invoice with statement and approval status."),
    Table("ssas_fact_revenue_adjustment", "Revenue Adjustments", "fact", "Post-invoice revenue adjustments."),
    Table("ssas_fact_preauth_line", "Pre-auth Lines", "fact", "One pre-authorisation line or payer advance authorisation.", "request_date_key"),
    Table("ssas_agg_episode_billing", "Episode Billing", "fact", "Claimable versus invoiced amount per episode.", "last_delivery_date_key"),
    Table("ssas_fact_encounter", "Encounters", "fact", "One outpatient, emergency or inpatient encounter.", "encounter_date_key"),
    Table("ssas_fact_episode", "Episodes", "fact", "One Oasis episode.", "start_date_key"),
    Table("ssas_fact_admission", "Admissions", "fact", "One inpatient admission with length of stay and outcomes."),
    Table("ssas_fact_bed_occupancy_daily", "Bed Occupancy", "fact", "One bed per day: available and occupied.", "date_key"),
    Table("ssas_fact_surgery", "Surgeries", "fact", "One surgery with times and team."),
    Table("ssas_agg_clinic_capacity_daily", "Clinic Capacity", "fact", "Clinic slots per doctor and day.", "date_key"),
    Table("ssas_fact_target_daily", "Targets", "fact", "Daily targets from the budget.", "date_key"),
    Table("ssas_fact_survey_response", "Survey Responses", "fact", "One Press Ganey survey invitation and its response."),
    Table("ssas_fact_survey_answer", "Survey Answers", "fact", "One answered survey question with NPS band."),
    Table("ssas_fact_gl_journal_line", "GL Journal Lines", "fact", "One Fusion journal line.", "accounting_date_key"),
    Table("ssas_fact_gl_balance_monthly", "GL Balances", "fact", "Monthly opening, movement and closing balance per account."),
    Table("ssas_fact_income_statement_monthly", "Income Statement", "fact", "Monthly actual and budget per budget line."),
    Table("ssas_fact_budget_monthly", "Budget", "fact", "Monthly budget per budget line."),
    Table("ssas_fact_ap_invoice_line", "AP Invoice Lines", "fact", "One payables invoice distribution line."),
    Table("ssas_fact_ap_open_item", "AP Open Items", "fact", "Open payables at the last refresh with ageing bucket."),
    Table("ssas_fact_ap_payment", "AP Payments", "fact", "One supplier payment."),
    Table("ssas_fact_stock_monthly", "Stock Monthly", "fact", "Month-end stock per store and item."),
    Table("ssas_fact_purchase_line", "Purchase Lines", "fact", "One purchase order line."),
    Table("ssas_fact_goods_receipt", "Goods Receipts", "fact", "One goods receipt or return line."),
    Table("ssas_fact_headcount_monthly", "Headcount", "fact", "Month-end headcount snapshot per employee."),
    Table("ssas_fact_worker_movement", "Worker Movements", "fact", "Hires, leavers and changes of employees."),
    Table("ssas_fact_payroll_monthly", "Payroll", "fact", "Monthly pay per employee and pay category; pay access only.", "month_date_key"),
    Table("ssas_fact_leave_balance_monthly", "Leave Balances", "fact", "Leave accrual periods with balance and liability; pay access only."),
    Table("ssas_fact_absence", "Absences", "fact", "One absence entry."),
    Table("ssas_fact_absence_daily", "Absence Days", "fact", "One counted absence day per employee."),
    Table("ssas_agg_staff_productivity_monthly", "Staff Productivity", "fact", "Monthly encounters, revenue and payroll per linked doctor or nurse; pay access only."),
]

DIM_KEYS = {
    "branch_key": ("Branch", "branch_key"),
    "patient_key": ("Patient", "patient_key"),
    "care_type_key": ("Care Type", "care_type_key"),
    "service_key": ("Service", "service_key"),
    "department_key": ("Department", "department_key"),
    "payer_key": ("Payer", "payer_key"),
    "product_category_key": ("Product Category", "product_category_key"),
    "staff_key": ("Staff", "staff_key"),
    "item_key": ("Item", "item_key"),
    "store_key": ("Store", "store_key"),
    "supplier_key": ("Supplier", "supplier_key"),
    "gl_account_key": ("GL Account", "gl_account_key"),
    "period_key": ("GL Period", "period_key"),
    "employee_key": ("Employee", "employee_key"),
    "hr_department_key": ("HR Department", "hr_department_key"),
    "job_key": ("Job", "job_key"),
    "grade_key": ("Grade", "grade_key"),
    "position_key": ("Position", "position_key"),
    "location_key": ("Location", "location_key"),
    "pay_category_key": ("Pay Category", "pay_category_key"),
    "absence_type_key": ("Absence Type", "absence_type_key"),
    "movement_type_key": ("Movement Type", "movement_type_key"),
    "worker_action_key": ("Worker Action", "worker_action_key"),
    "budget_line_key": ("Budget Line", "budget_line_key"),
    "survey_service_key": ("Survey Service", "survey_service_key"),
    "question_key": ("Survey Question", "question_key"),
    "nphies_reason_key": ("NPHIES Reason", "nphies_reason_key"),
    "preauth_outcome_key": ("Pre-auth Outcome", "preauth_outcome_key"),
    "procedure_type_key": ("Procedure Type", "procedure_type_key"),
    "eligibility_type_key": ("Eligibility Type", "eligibility_type_key"),
    "outcome_key": ("Appointment Outcome", "outcome_key"),
    "er_priority_key": ("ER Priority", "er_priority_key"),
    "admission_source_key": ("Admission Source", "admission_source_key"),
    "discharge_outcome_key": ("Discharge Outcome", "discharge_outcome_key"),
    "bed_key": ("Bed", "bed_key"),
}

# (table, column) -> (dimension table, dimension key, active). Spec 5.1 role-playing; 5.2 staff copies.
ROLE_KEYS = {
    ("Charge Lines", "billed_payer_key"): ("Payer", "payer_key", True),
    ("Charge Lines", "episode_payer_key"): ("Payer", "payer_key", False),
    ("Order Lines", "ordering_staff_key"): ("Staff", "staff_key", True),
    ("Order Lines", "ordering_department_key"): ("Department", "department_key", True),
    ("Patient Consumption", "treating_staff_key"): ("Staff", "staff_key", True),
    ("Patient Consumption", "billed_payer_key"): ("Payer", "payer_key", True),
    ("Stock Movements", "transfer_store_key"): ("Store", "store_key", False),
    ("Revenue Adjustments", "billed_payer_key"): ("Payer", "payer_key", True),
    ("Pre-auth Lines", "requesting_staff_key"): ("Staff", "staff_key", True),
    ("Encounters", "treating_staff_key"): ("Staff", "staff_key", True),
    ("Encounters", "booked_staff_key"): ("Booked Doctor", "staff_key", True),
    ("Episodes", "consultant_staff_key"): ("Staff", "staff_key", True),
    ("Admissions", "consultant_staff_key"): ("Staff", "staff_key", True),
    ("Admissions", "treating_staff_key"): ("Admission Treating Doctor", "staff_key", True),
    ("Admissions", "first_department_key"): ("Department", "department_key", True),
    ("Admissions", "last_department_key"): ("Department", "department_key", False),
    ("Admissions", "last_bed_key"): ("Bed", "bed_key", True),
    ("Surgeries", "surgeon_staff_key"): ("Staff", "staff_key", True),
    ("Surgeries", "anaesthetist_staff_key"): ("Anaesthetist", "staff_key", True),
    ("Purchase Lines", "ship_to_store_key"): ("Store", "store_key", True),
    ("Worker Movements", "previous_hr_department_key"): ("HR Department", "hr_department_key", False),
    ("Worker Movements", "previous_job_key"): ("Job", "job_key", False),
    ("Worker Movements", "previous_grade_key"): ("Grade", "grade_key", False),
    ("Worker Movements", "previous_position_key"): ("Position", "position_key", False),
    ("Worker Movements", "previous_location_key"): ("Location", "location_key", False),
    ("GL Account", "fs_line_key"): ("FS Line", "fs_line_key", True),
}

# Spec 5.3: one-to-one, both directions; the security filter flows only Patient -> Patient Details.
EXTRA_RELATIONSHIPS = [Relationship("Patient Details", "patient_key", "Patient", "patient_key", True, True)]

# Facts keep these keys hidden, with no relationship (spec 5: facts are never related to each other).
NO_RELATIONSHIP = {
    ("Order Lines", "order_key"),
    ("Survey Responses", "survey_response_key"),
    ("Survey Answers", "survey_response_key"),
}

ACTIVE_DATE = {
    "Charge Lines": "delivery_date_key", "Order Lines": "order_date_key", "Stock Movements": "date_key",
    "Patient Consumption": "date_key", "Claim Lines": "statement_end_date_key", "Claim Payments": "payment_date_key",
    "Cash Receipts": "receipt_date_key", "Invoices": "invoice_date_key", "Revenue Adjustments": "adjustment_date_key",
    "Pre-auth Lines": "request_date_key", "Episode Billing": "last_delivery_date_key",
    "Encounters": "encounter_date_key", "Episodes": "start_date_key", "Admissions": "admit_date_key",
    "Bed Occupancy": "date_key", "Surgeries": "operation_date_key", "Clinic Capacity": "date_key", "Targets": "date_key",
    "Survey Responses": "visit_date_key", "Survey Answers": "visit_date_key",
    "GL Journal Lines": "accounting_date_key", "GL Balances": "period_end_date_key",
    "Income Statement": "month_date_key", "Budget": "month_date_key", "AP Invoice Lines": "accounting_date_key",
    "AP Open Items": "invoice_date_key", "AP Payments": "payment_date_key", "Stock Monthly": "month_date_key",
    "Purchase Lines": "po_date_key", "Goods Receipts": "date_key", "Headcount": "month_date_key",
    "Worker Movements": "action_date_key", "Payroll": "month_date_key",
    "Leave Balances": "accrual_period_date_key", "Absences": "start_date_key", "Absence Days": "date_key",
    "Staff Productivity": "month_date_key",
}

ACTIVE_TIME = {
    "Charge Lines": "delivery_time_key", "Order Lines": "order_time_key", "Cash Receipts": "receipt_time_key",
    "Encounters": "encounter_time_key", "Admissions": "admit_time_key", "Surgeries": "operation_time_key",
}

# Decision P13: explicit display names (date column; columns whose friendly name equals a measure in the same table).
COLUMN_NAMES = {
    ("ssas_dim_date", "date_day"): "Date",
    ("ssas_fact_headcount_monthly", "headcount"): "Headcount Units",
    ("ssas_fact_stock_monthly", "stock_value"): "Stock Value Amount",
    ("ssas_fact_stock_movement", "consumption_cost"): "Consumption Cost Amount",
    ("ssas_fact_claim_line", "claimed_amount"): "Line Claimed Amount",
}

# (view, column) -> sort column. generate.py checks each pair is one-to-one in the data.
SORT_BY = {
    ("ssas_dim_date", "month_name"): "month",
    ("ssas_dim_date", "month_short"): "month",
    ("ssas_dim_date", "day_name"): "day_of_week",
    ("ssas_dim_date", "quarter_name"): "quarter",
    ("ssas_dim_date", "year_month_name"): "year_month",
    ("ssas_dim_date", "hijri_month_name"): "hijri_month",
    ("ssas_dim_time", "time_label"): "time_key",
    ("ssas_dim_budget_line", "budget_line_name"): "sort_order",
    ("ssas_dim_pay_category", "pay_category"): "sort_order",
    ("ssas_dim_movement_type", "movement_type"): "sort_order",
    ("ssas_dim_fs_line", "fs_type"): "type_sort",
    ("ssas_dim_fs_line", "fs_element"): "element_sort",
    ("ssas_dim_fs_line", "fs_category"): "category_sort",
    ("ssas_dim_fs_line", "fs_caption"): "caption_sort",
    ("ssas_dim_fs_line", "fs_line"): "line_sort",
}

# Spec 7. Each perspective gets its facts, every dimension they reach, and Time Calculation.
PERSPECTIVES = {
    "Executive": ["Encounters", "Admissions", "Charge Lines", "Invoices", "Claim Lines", "Income Statement", "Budget",
                  "Targets", "Headcount", "Survey Responses"],
    "Patient Flow": ["Encounters", "Admissions", "Episodes", "Bed Occupancy", "Surgeries", "Clinic Capacity", "Targets"],
    "Revenue Cycle": ["Charge Lines", "Order Lines", "Invoices", "Cash Receipts", "Revenue Adjustments", "Episode Billing"],
    "Claims & Pre-auth": ["Claim Lines", "Claim Payments", "Pre-auth Lines"],
    "Finance": ["GL Journal Lines", "GL Balances", "Income Statement", "Budget", "AP Invoice Lines", "AP Open Items",
                "AP Payments"],
    "Workforce": ["Headcount", "Worker Movements", "Absences", "Absence Days", "Payroll", "Leave Balances",
                  "Staff Productivity"],
    "Supply Chain": ["Stock Movements", "Stock Monthly", "Patient Consumption", "Purchase Lines", "Goods Receipts"],
    "Patient Experience": ["Survey Responses", "Survey Answers"],
    "Patient Details": ["Encounters", "Admissions", "Episodes", "Invoices"],
}
PERSPECTIVE_EXTRA = {"Patient Details": ["Patient Details"]}
```

- [ ] **Step 2: Write `ssas/tools/generate.py`**

```python
"""Write the TMDL folder ssas/HNH_Analytics from the gold.ssas_* views and model_config.py (SSAS plan task 9).

Usage: python ssas/tools/generate.py
Keeps measure and hierarchy blocks of existing table files; never touches roles/ or tables/Time Calculation.tmdl.
"""
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(TOOLS))

import hnh_tmdl as t  # noqa: E402
import model_config as cfg  # noqa: E402
from ch_env import client  # noqa: E402

MODEL_DIR = ROOT / "ssas" / "HNH_Analytics"
CALC_GROUP = "Time Calculation"


def read_columns(ch, view):
    rows = ch.query(
        "select name, type from system.columns where database = 'gold' and table = {v:String} order by position",
        parameters={"v": view},
    ).result_rows
    if not rows:
        raise SystemExit(f"gold.{view} not found: build the ssas views first (dbt build --select tag:hnh_ssas)")
    return [t.Column(name, typ) for name, typ in rows]


def check_sort_pairs(ch):
    for (view, column), sort in cfg.SORT_BY.items():
        bad = ch.query(
            f"select count() from (select {column} from gold.{view} group by {column} having uniqExact({sort}) > 1)"
        ).result_rows[0][0]
        if bad:
            raise SystemExit(f"sortByColumn {view}.{column} -> {sort}: {bad} values have more than one sort value")


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def main():
    ch = client()
    by_name = {table.name: table for table in cfg.TABLES}
    columns = {table.name: read_columns(ch, table.view) for table in cfg.TABLES}
    check_sort_pairs(ch)

    rels = list(cfg.EXTRA_RELATIONSHIPS)
    for table in cfg.TABLES:
        rels += t.derive_relationships(table, columns[table.name], cfg)
    t.check_relationships(rels, cfg.TABLES)

    def col_display(table_name, column):
        return t.display_name(by_name[table_name], column, cfg.COLUMN_NAMES)

    tables_dir = MODEL_DIR / "tables"
    for table in cfg.TABLES:
        path = tables_dir / f"{table.name}.tmdl"
        kept = t.kept_blocks(path.read_text(encoding="utf-8")) if path.exists() else []
        write(path, t.render_table(table, columns[table.name], cfg.COLUMN_NAMES, cfg.SORT_BY, kept))
    write(MODEL_DIR / "relationships.tmdl", t.render_relationships(rels, col_display))

    has_calc_group = (tables_dir / f"{CALC_GROUP}.tmdl").exists()
    for name, facts in cfg.PERSPECTIVES.items():
        tables = t.perspective_tables(facts, rels, cfg.PERSPECTIVE_EXTRA.get(name, []))
        write(MODEL_DIR / "perspectives" / f"{name}.tmdl",
              t.render_perspective(name, tables + ([CALC_GROUP] if has_calc_group else [])))

    write(MODEL_DIR / "database.tmdl", t.DATABASE_TMDL)
    write(MODEL_DIR / "dataSources.tmdl", t.DATA_SOURCES_TMDL)
    table_names = sorted(p.stem for p in tables_dir.glob("*.tmdl"))
    role_names = sorted(p.stem for p in (MODEL_DIR / "roles").glob("*.tmdl"))
    write(MODEL_DIR / "model.tmdl", t.render_model(table_names, role_names, list(cfg.PERSPECTIVES)))
    print(f"{len(cfg.TABLES)} tables, {len(rels)} relationships, {len(cfg.PERSPECTIVES)} perspectives -> {MODEL_DIR}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Generate**

Run: `python ssas/tools/generate.py`
Expected: `80 tables, N relationships, 9 perspectives -> …\ssas\HNH_Analytics` with N around 200. A `ValueError: … no relationship rule` names a fact key that Tasks 5–6 kept but the config does not cover: add it to `DIM_KEYS`/`ROLE_KEYS`, or drop it in the view if it is a fact-to-fact key (spec 4.2 rule 2). A `sortByColumn … more than one sort value` error: delete that pair from `SORT_BY` and say so in the task report.

- [ ] **Step 4: Add the Date hierarchy (hand-written, kept on regeneration)**

In `ssas/HNH_Analytics/tables/Date.tmdl`, insert directly after the `dataCategory: Time` line:

```

	hierarchy Calendar

		level Year
			column: Year

		level Quarter
			column: 'Quarter Name'

		level Month
			column: 'Month Name'

		level Day
			column: Date
```

Run `python ssas/tools/generate.py` again and confirm with `git diff --stat` that `Date.tmdl` still contains the hierarchy (`grep -c "hierarchy Calendar" ssas/HNH_Analytics/tables/Date.tmdl` → `1`).

- [ ] **Step 5: Load the model in Tabular Editor 2**

Run (PowerShell): `& 'C:\Program Files (x86)\Tabular Editor\TabularEditor.exe' ssas\HNH_Analytics -B "$env:TEMP\hnh_check.bim" | Out-String; $LASTEXITCODE`
Expected: `Loading model...`, `Building Model.bim file...`, exit code `0`. Any error names the file and line to fix (in the generator or config, never by hand in generated parts).

- [ ] **Step 6: Commit**

```bash
git add ssas/tools/model_config.py ssas/tools/generate.py ssas/HNH_Analytics
git commit -m "Generate the HNH_Analytics TMDL model from the SSAS views

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Security role and calculation group

**Files:**
- Create: `ssas/HNH_Analytics/roles/HNH Readers.tmdl`
- Create: `ssas/HNH_Analytics/tables/Time Calculation.tmdl`
- Modify (regenerated): `ssas/HNH_Analytics/model.tmdl`, `ssas/HNH_Analytics/perspectives/*.tmdl`

**Interfaces:**
- Consumes: table and column names from Task 9 (`'User Access'[Login Name]`, `[Branch Key]`, `[Unified Specialty]`, `[Can See Pay]`, `[Can See PII]`; `Staff[Staff Key]`, `Staff[Branch Key]`, `Staff[Unified Specialty]`; `Patient[Patient Key]`, `Patient[Branch Key]`).
- Produces: role `HNH Readers`; calculation group table `Time Calculation` with column `Time Calculation` and items `Current, MTD, QTD, YTD, PY, PY YTD, YoY Δ, YoY %, MoM Δ, MoM %, Rolling 12M`. The snapshot list `[Headcount], [Stock Value], [GL Closing Balance]` refers to measures created in Task 11; Tabular Editor loads DAX without evaluating it, so the model loads before they exist, and the Best Practice and server checks in Tasks 11 and 16 cover the references.

- [ ] **Step 1: Write the role (spec 6.2 + decision P6)**

`ssas/HNH_Analytics/roles/HNH Readers.tmdl`:

```
role 'HNH Readers'
	modelPermission: read

	tablePermission 'User Access' = FALSE ()

	tablePermission Branch =
			Branch[Branch Key]
				IN CALCULATETABLE (
					VALUES ( 'User Access'[Branch Key] ),
					'User Access'[Login Name] = USERNAME ()
				)

	tablePermission Staff =
			VAR UserRows =
				CALCULATETABLE (
					SUMMARIZE ( 'User Access', 'User Access'[Branch Key], 'User Access'[Unified Specialty] ),
					'User Access'[Login Name] = USERNAME ()
				)
			RETURN
				Staff[Staff Key] = -1
					|| NOT ISEMPTY (
						FILTER (
							UserRows,
							'User Access'[Branch Key] = Staff[Branch Key]
								&& (
									ISBLANK ( 'User Access'[Unified Specialty] )
										|| 'User Access'[Unified Specialty] = Staff[Unified Specialty]
								)
						)
					)

	tablePermission Patient =
			Patient[Patient Key] = -1
				|| Patient[Branch Key]
					IN CALCULATETABLE (
						VALUES ( 'User Access'[Branch Key] ),
						'User Access'[Login Name] = USERNAME ()
					)

	tablePermission 'Pay Category' =
			NOT ISEMPTY (
				CALCULATETABLE (
					'User Access',
					'User Access'[Login Name] = USERNAME (),
					'User Access'[Can See Pay] = 1
				)
			)

	tablePermission 'Leave Balances' =
			NOT ISEMPTY (
				CALCULATETABLE (
					'User Access',
					'User Access'[Login Name] = USERNAME (),
					'User Access'[Can See Pay] = 1
				)
			)

	tablePermission 'Staff Productivity' =
			NOT ISEMPTY (
				CALCULATETABLE (
					'User Access',
					'User Access'[Login Name] = USERNAME (),
					'User Access'[Can See Pay] = 1
				)
			)

	tablePermission 'Patient Details' =
			NOT ISEMPTY (
				CALCULATETABLE (
					'User Access',
					'User Access'[Login Name] = USERNAME (),
					'User Access'[Can See PII] = 1
				)
			)
```

- [ ] **Step 2: Write the calculation group (spec 8.3)**

`ssas/HNH_Analytics/tables/Time Calculation.tmdl`:

```
/// Time intelligence for any measure: pick one item (SSAS spec 8.3). Snapshot measures keep their month-end value under MTD, QTD, YTD and Rolling 12M.
table 'Time Calculation'

	calculationGroup
		precedence: 1

		calculationItem Current = SELECTEDMEASURE ()

		calculationItem MTD =
				-- Snapshot measures: keep this list identical in MTD, QTD, YTD, PY YTD and Rolling 12M
				IF (
					ISSELECTEDMEASURE ( [Headcount], [Stock Value], [GL Closing Balance] ),
					SELECTEDMEASURE (),
					CALCULATE ( SELECTEDMEASURE (), DATESMTD ( 'Date'[Date] ) )
				)

		calculationItem QTD =
				-- Snapshot measures: keep this list identical in MTD, QTD, YTD, PY YTD and Rolling 12M
				IF (
					ISSELECTEDMEASURE ( [Headcount], [Stock Value], [GL Closing Balance] ),
					SELECTEDMEASURE (),
					CALCULATE ( SELECTEDMEASURE (), DATESQTD ( 'Date'[Date] ) )
				)

		calculationItem YTD =
				-- Snapshot measures: keep this list identical in MTD, QTD, YTD, PY YTD and Rolling 12M
				IF (
					ISSELECTEDMEASURE ( [Headcount], [Stock Value], [GL Closing Balance] ),
					SELECTEDMEASURE (),
					CALCULATE ( SELECTEDMEASURE (), DATESYTD ( 'Date'[Date] ) )
				)

		calculationItem PY = CALCULATE ( SELECTEDMEASURE (), SAMEPERIODLASTYEAR ( 'Date'[Date] ) )

		calculationItem 'PY YTD' =
				-- Snapshot measures: keep this list identical in MTD, QTD, YTD, PY YTD and Rolling 12M
				IF (
					ISSELECTEDMEASURE ( [Headcount], [Stock Value], [GL Closing Balance] ),
					CALCULATE ( SELECTEDMEASURE (), SAMEPERIODLASTYEAR ( 'Date'[Date] ) ),
					CALCULATE ( SELECTEDMEASURE (), DATESYTD ( SAMEPERIODLASTYEAR ( 'Date'[Date] ) ) )
				)

		calculationItem 'YoY Δ' =
				VAR Cur = SELECTEDMEASURE ()
				VAR Prev = CALCULATE ( SELECTEDMEASURE (), SAMEPERIODLASTYEAR ( 'Date'[Date] ) )
				RETURN IF ( NOT ISBLANK ( Cur ) && NOT ISBLANK ( Prev ), Cur - Prev )

		calculationItem 'YoY %' =
				VAR Cur = SELECTEDMEASURE ()
				VAR Prev = CALCULATE ( SELECTEDMEASURE (), SAMEPERIODLASTYEAR ( 'Date'[Date] ) )
				RETURN IF ( NOT ISBLANK ( Cur ) && NOT ISBLANK ( Prev ), DIVIDE ( Cur - Prev, ABS ( Prev ) ) )

			formatStringDefinition = "0.0%"

		calculationItem 'MoM Δ' =
				VAR Cur = SELECTEDMEASURE ()
				VAR Prev = CALCULATE ( SELECTEDMEASURE (), DATEADD ( 'Date'[Date], -1, MONTH ) )
				RETURN IF ( NOT ISBLANK ( Cur ) && NOT ISBLANK ( Prev ), Cur - Prev )

		calculationItem 'MoM %' =
				VAR Cur = SELECTEDMEASURE ()
				VAR Prev = CALCULATE ( SELECTEDMEASURE (), DATEADD ( 'Date'[Date], -1, MONTH ) )
				RETURN IF ( NOT ISBLANK ( Cur ) && NOT ISBLANK ( Prev ), DIVIDE ( Cur - Prev, ABS ( Prev ) ) )

			formatStringDefinition = "0.0%"

		calculationItem 'Rolling 12M' =
				-- Snapshot measures: keep this list identical in MTD, QTD, YTD, PY YTD and Rolling 12M
				IF (
					ISSELECTEDMEASURE ( [Headcount], [Stock Value], [GL Closing Balance] ),
					SELECTEDMEASURE (),
					CALCULATE ( SELECTEDMEASURE (), DATESINPERIOD ( 'Date'[Date], MAX ( 'Date'[Date] ), -12, MONTH ) )
				)

	column 'Time Calculation'
		dataType: string
		summarizeBy: none
		sourceColumn: Name
		sortByColumn: Ordinal

	column Ordinal
		dataType: int64
		isHidden
		summarizeBy: none
		sourceColumn: Ordinal

	partition 'Time Calculation' = calculationGroup

	annotation hnh_kind = calculation_group
```

- [ ] **Step 3: Regenerate and validate**

Run: `python ssas/tools/generate.py`
Expected: `model.tmdl` now lists `ref table 'Time Calculation'` and `ref role 'HNH Readers'`; every perspective file ends with `perspectiveTable 'Time Calculation'`.

Run (PowerShell): `& 'C:\Program Files (x86)\Tabular Editor\TabularEditor.exe' ssas\HNH_Analytics -B "$env:TEMP\hnh_check.bim" | Out-String; $LASTEXITCODE`
Expected: exit code `0`. Tabular Editor loads DAX without evaluating it, so the snapshot measure names that Task 11 adds do not stop the load. If it reports a DAX parse error, fix the expression shown.

- [ ] **Step 4: Commit**

```bash
git add ssas/HNH_Analytics
git commit -m "Add the HNH Readers role and the Time Calculation group

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Starter measures, Best Practice rules and measure checks

**Files:**
- Modify: 15 table files in `ssas/HNH_Analytics/tables/` (insert measure blocks)
- Create: `ssas/bpa_rules.json`
- Create: `ssas/tests/measures/starter.json`

**Interfaces:**
- Produces: measures `[Revenue]`, `[Billed Amount]`, `[Patient Collections]`, `[OP Visits]`, `[Admissions]`, `[Bed Occupancy %]`, `[Claimed Amount]`, `[Headcount]`, `[Payroll Cost]`, `[Consumption Cost]`, `[Stock Value]`, `[GL Closing Balance]`, `[Hospital NPS (5-point)]`, `[Invitations]`, `[Response Rate %]`, `[Current User]`. Measure check file format used by `test.ps1` (Task 14): JSON array of `{name, dax, sql, tolerance}`; `dax` returns one value, `sql` returns one value from `gold.ssas_*` views.

- [ ] **Step 1: Write the Best Practice rules first**

`ssas/bpa_rules.json` (severity 3 = error; spec 10.1 and decision P10):

```json
[
  {
    "ID": "HNH_AMOUNT_FIXED_DECIMAL",
    "Name": "Amount columns use fixed decimal, not floating point",
    "Category": "HNH",
    "Severity": 3,
    "Scope": "DataColumn",
    "Expression": "DataType = \"Double\" and RegEx.IsMatch(Name, \"(Amount|Cost|Value|Debit|Credit|Pay|Fee|Price|Salary|Rate|Revenue)$\")"
  },
  {
    "ID": "HNH_FACT_HIDDEN_NO_MDX",
    "Name": "Hidden fact columns have no attribute hierarchy",
    "Category": "HNH",
    "Severity": 3,
    "Scope": "DataColumn",
    "Expression": "IsHidden and IsAvailableInMDX and Table.GetAnnotation(\"hnh_kind\") = \"fact\""
  },
  {
    "ID": "HNH_NO_IMPLICIT_MEASURES",
    "Name": "Implicit measures are switched off",
    "Category": "HNH",
    "Severity": 3,
    "Scope": "Model",
    "Expression": "not DiscourageImplicitMeasures"
  },
  {
    "ID": "HNH_NO_CALCULATED_COLUMNS",
    "Name": "No calculated columns (logic belongs in dbt)",
    "Category": "HNH",
    "Severity": 3,
    "Scope": "CalculatedColumn",
    "Expression": "true"
  },
  {
    "ID": "HNH_NO_CALCULATED_TABLES",
    "Name": "No calculated tables",
    "Category": "HNH",
    "Severity": 3,
    "Scope": "CalculatedTable",
    "Expression": "true"
  },
  {
    "ID": "HNH_MEASURE_FORMAT_FOLDER",
    "Name": "Measures have a format string and a display folder",
    "Category": "HNH",
    "Severity": 3,
    "Scope": "Measure",
    "Expression": "(string.IsNullOrEmpty(FormatString) and string.IsNullOrEmpty(FormatStringExpression)) or string.IsNullOrEmpty(DisplayFolder)"
  },
  {
    "ID": "HNH_DESCRIPTIONS",
    "Name": "Visible tables and measures have a description",
    "Category": "HNH",
    "Severity": 3,
    "Scope": "Table, Measure",
    "Expression": "not IsHidden and string.IsNullOrEmpty(Description)"
  },
  {
    "ID": "HNH_SINGLE_DIRECTION",
    "Name": "Relationships filter in one direction (except Patient Details)",
    "Category": "HNH",
    "Severity": 3,
    "Scope": "Relationship",
    "Expression": "CrossFilteringBehavior = \"BothDirections\" and FromTable.Name <> \"Patient Details\""
  },
  {
    "ID": "HNH_NO_ITERATOR_OVER_LARGE_FACT",
    "Name": "No FILTER or X-iterator over a fact with more than 1M rows",
    "Category": "HNH",
    "Severity": 3,
    "Scope": "Measure",
    "Expression": "RegEx.IsMatch(Expression, \"(?i)(FILTER|SUMX|AVERAGEX|COUNTX|MINX|MAXX)\\s*\\(\\s*'?(Charge Lines|Order Lines|Stock Movements|Patient Consumption|Claim Lines|Cash Receipts|GL Journal Lines|Pre-auth Lines|Encounters|Episodes|Invoices|Bed Occupancy|Episode Billing|Clinic Capacity|Targets|Payroll)'?\\s*,\")"
  }
]
```

Run (PowerShell): `& 'C:\Program Files (x86)\Tabular Editor\TabularEditor.exe' ssas\HNH_Analytics -A ssas\bpa_rules.json -V | Out-String`
Expected: no rule errors except, possibly, `HNH_DESCRIPTIONS` for nothing (all tables carry `///` descriptions). If the output shows a rule-expression parse error, fix that rule's expression (Tabular Editor prints the offending rule ID).

- [ ] **Step 2: Insert the measures**

Insert each block directly after the `table …` header line (before the first column) of the named file. The generator keeps these blocks from now on.

`tables/Charge Lines.tmdl`:
```

	/// Recognised revenue in SAR: Σ revenue_amount (Phase 2 spec section 8, "Revenue").
	measure Revenue = SUM ( 'Charge Lines'[Revenue Amount] )
		formatString: #,0
		displayFolder: Revenue
```

`tables/Invoices.tmdl`:
```

	/// Billed amount in SAR: Σ net_amount of invoices (Phase 2 spec section 8).
	measure 'Billed Amount' = SUM ( Invoices[Net Amount] )
		formatString: #,0
		displayFolder: Billing
```

`tables/Cash Receipts.tmdl`:
```

	/// Patient collections in SAR: Σ receipt_amount; cancellations and refunds count as recorded (Phase 2 spec section 8).
	measure 'Patient Collections' = SUM ( 'Cash Receipts'[Receipt Amount] )
		formatString: #,0
		displayFolder: Collections
```

`tables/Encounters.tmdl`:
```

	/// Outpatient visits: arrived, not cancelled OP encounters (gold spec section 8).
	measure 'OP Visits' =
			CALCULATE (
				COUNTROWS ( Encounters ),
				KEEPFILTERS ( Encounters[Encounter Type] = "OP" ),
				Encounters[Is Arrived] = "Yes",
				Encounters[Is Cancelled] = "No"
			)
		formatString: #,0
		displayFolder: Visits
```

`tables/Admissions.tmdl`:
```

	/// Countable admissions by admit date (gold spec section 8).
	measure Admissions = CALCULATE ( COUNTROWS ( Admissions ), Admissions[Is Countable] = "Yes" )
		formatString: #,0
		displayFolder: Admissions
```

`tables/Bed Occupancy.tmdl`:
```

	/// Occupied ÷ available bed-days on inpatient wards that are not excluded (gold spec section 8; receiving notes).
	measure 'Bed Occupancy %' =
			CALCULATE (
				DIVIDE ( SUM ( 'Bed Occupancy'[Is Occupied] ), SUM ( 'Bed Occupancy'[Is Available] ) ),
				'Bed Occupancy'[Is Inpatient Ward] = "Yes",
				'Bed Occupancy'[Is Excluded Ward] = "No"
			)
		formatString: 0.0%
		displayFolder: Occupancy
```

`tables/Claim Lines.tmdl`:
```

	/// Claimed amount in SAR of the latest, not cancelled submission (Phase 2B spec section 7; receiving notes).
	measure 'Claimed Amount' =
			CALCULATE (
				SUM ( 'Claim Lines'[Line Claimed Amount] ),
				'Claim Lines'[Is Latest Submission] = "Yes",
				'Claim Lines'[Is Cancelled Claim] = "No"
			)
		formatString: #,0
		displayFolder: Claims
```

`tables/Headcount.tmdl`:
```

	/// Month-end headcount of the last month in the selection, contingent workers excluded (Phase 4 spec section 7). Snapshot: never summed over months.
	measure Headcount =
			VAR LastMonth = MAX ( Headcount[Month Date Key] )
			RETURN
				CALCULATE (
					SUM ( Headcount[Headcount Units] ),
					Headcount[Month Date Key] = LastMonth,
					Headcount[Is Contingent] = "No"
				)
		formatString: #,0
		displayFolder: Headcount
```

`tables/Payroll.tmdl`:
```

	/// Payroll cost in SAR: Σ cost_amount; parallel-run rows are already excluded (Phase 4 spec section 7).
	measure 'Payroll Cost' = SUM ( Payroll[Cost Amount] )
		formatString: #,0
		displayFolder: Payroll
```

`tables/Stock Movements.tmdl`:
```

	/// Consumption cost in SAR: Σ consumption_cost of consumption movements (Phase 5 spec section 7).
	measure 'Consumption Cost' =
			CALCULATE ( SUM ( 'Stock Movements'[Consumption Cost Amount] ), 'Stock Movements'[Is Consumption] = "Yes" )
		formatString: #,0
		displayFolder: Consumption
```

`tables/Stock Monthly.tmdl`:
```

	/// Stock value in SAR at the last month-end of the selection, expiry stores excluded (Phase 5 spec section 7). Snapshot.
	measure 'Stock Value' =
			VAR LastMonth = MAX ( 'Stock Monthly'[Month Date Key] )
			RETURN
				CALCULATE (
					SUM ( 'Stock Monthly'[Stock Value Amount] ),
					'Stock Monthly'[Month Date Key] = LastMonth,
					'Stock Monthly'[Is Expiry Store] = "No"
				)
		formatString: #,0
		displayFolder: Stock
```

`tables/GL Balances.tmdl`:
```

	/// Posted closing balance in SAR at the last period of the selection (an adjustment period wins over its month), signed for display (Phase 3 spec section 8). Snapshot.
	measure 'GL Closing Balance' =
			VAR LastPeriod = MAX ( 'GL Balances'[Period Key] )
			RETURN
				CALCULATE (
					SUMX ( 'GL Balances', 'GL Balances'[Closing Balance] * RELATED ( 'FS Line'[Display Sign] ) ),
					'GL Balances'[Period Key] = LastPeriod,
					'GL Balances'[Balance View] = "posted"
				)
		formatString: #,0
		displayFolder: Balances
```

`tables/Survey Answers.tmdl`:
```

	/// Hospital NPS on the 5-point "recommend" question: (promoters − detractors) ÷ answers × 100; under 30 answers shows "insufficient sample" (Phase 6 spec section 7).
	measure 'Hospital NPS (5-point)' =
			VAR Answers = CALCULATE ( COUNTROWS ( 'Survey Answers' ), 'Survey Answers'[NPS Role] = "Hospital NPS" )
			VAR Net =
				CALCULATE (
					SUM ( 'Survey Answers'[Is Promoter] ) - SUM ( 'Survey Answers'[Is Detractor] ),
					'Survey Answers'[NPS Role] = "Hospital NPS"
				)
			RETURN IF ( Answers > 0, DIVIDE ( Net, Answers ) * 100 )
		displayFolder: NPS

		formatStringDefinition =
				VAR Answers = CALCULATE ( COUNTROWS ( 'Survey Answers' ), 'Survey Answers'[NPS Role] = "Hospital NPS" )
				RETURN IF ( Answers < 30, """insufficient sample""", "0.0" )
```

`tables/Survey Responses.tmdl`:
```

	/// Primary survey invitations (Phase 6 spec section 7.1).
	measure Invitations = CALCULATE ( COUNTROWS ( 'Survey Responses' ), 'Survey Responses'[Is Primary For Encounter] = "Yes" )
		formatString: #,0
		displayFolder: Survey Quality

	/// Responded ÷ primary invitations with an SMS sent (Phase 6 spec section 7.1).
	measure 'Response Rate %' =
			VAR Sent =
				CALCULATE (
					COUNTROWS ( 'Survey Responses' ),
					'Survey Responses'[Is Primary For Encounter] = "Yes",
					'Survey Responses'[Is SMS Sent] = "Yes"
				)
			VAR Responded =
				CALCULATE (
					COUNTROWS ( 'Survey Responses' ),
					'Survey Responses'[Is Primary For Encounter] = "Yes",
					'Survey Responses'[Is SMS Sent] = "Yes",
					'Survey Responses'[Is Responded] = "Yes"
				)
			RETURN DIVIDE ( Responded, Sent )
		formatString: 0.0%
		displayFolder: Survey Quality
```

`tables/Branch.tmdl`:
```

	/// The login SSAS sees for this connection; use it to check row-level security from a report.
	measure 'Current User' = USERNAME ()
		formatString: General
		displayFolder: Diagnostics
```

Before inserting, confirm each referenced column exists in its file (for example `grep -n "column 'Is SMS Sent'" "ssas/HNH_Analytics/tables/Survey Responses.tmdl"`). A missing column means the friendly name differs: fix the measure, not the generated column.

- [ ] **Step 3: Regenerate, load, analyse**

Run: `python ssas/tools/generate.py` then `git diff --stat ssas/HNH_Analytics/tables` — the measure blocks must still be present (`grep -c "^\tmeasure " ssas/HNH_Analytics/tables/*.tmdl | grep -v ":0"` lists 15 files with 16 measures).

Run (PowerShell): `& 'C:\Program Files (x86)\Tabular Editor\TabularEditor.exe' ssas\HNH_Analytics -A ssas\bpa_rules.json -V | Out-String; $LASTEXITCODE`
Expected: `No objects in violation of Best Practices.` (no `type=error` line), exit code `0`.

- [ ] **Step 4: Write the measure checks**

`ssas/tests/measures/starter.json` (branch 1, August 2026 unless stated; SQL reads the same views SSAS loads):

```json
[
  {"name": "Revenue, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Revenue], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(revenue_amount) from gold.ssas_fact_charge_line where branch_key = 1 and delivery_date_key >= 20260801 and delivery_date_key < 20260901"},
  {"name": "Revenue, all branches, 2025", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Revenue], 'Date'[Year] = 2025))",
   "sql": "select sum(revenue_amount) from gold.ssas_fact_charge_line where delivery_date_key >= 20250101 and delivery_date_key < 20260101"},
  {"name": "Billed Amount, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Billed Amount], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(net_amount) from gold.ssas_fact_invoice where branch_key = 1 and invoice_date_key >= 20260801 and invoice_date_key < 20260901"},
  {"name": "Patient Collections, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Patient Collections], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(receipt_amount) from gold.ssas_fact_cash_receipt where branch_key = 1 and receipt_date_key >= 20260801 and receipt_date_key < 20260901"},
  {"name": "OP Visits, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([OP Visits], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select count() from gold.ssas_fact_encounter where branch_key = 1 and encounter_type = 'OP' and is_arrived = 'Yes' and is_cancelled = 'No' and encounter_date_key >= 20260801 and encounter_date_key < 20260901"},
  {"name": "Admissions, branch 1, 2026-08", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Admissions], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select count() from gold.ssas_fact_admission where branch_key = 1 and is_countable = 'Yes' and admit_date_key >= 20260801 and admit_date_key < 20260901"},
  {"name": "Bed Occupancy %, branch 1, 2026-08", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Bed Occupancy %], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(is_occupied) / sum(is_available) from gold.ssas_fact_bed_occupancy_daily where branch_key = 1 and is_inpatient_ward = 'Yes' and is_excluded_ward = 'No' and date_key >= 20260801 and date_key < 20260901"},
  {"name": "Claimed Amount, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Claimed Amount], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(claimed_amount) from gold.ssas_fact_claim_line where branch_key = 1 and is_latest_submission = 'Yes' and is_cancelled_claim = 'No' and statement_end_date_key >= 20260801 and statement_end_date_key < 20260901"},
  {"name": "Headcount, 2026-09", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Headcount], 'Date'[Year Month] = 202609))",
   "sql": "select sum(headcount) from gold.ssas_fact_headcount_monthly where month_date_key = 20260930 and is_contingent = 'No'"},
  {"name": "Headcount YTD equals the September snapshot (review focus 4)", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Headcount], 'Date'[Year Month] = 202609, 'Time Calculation'[Time Calculation] = \"YTD\"))",
   "sql": "select sum(headcount) from gold.ssas_fact_headcount_monthly where month_date_key = 20260930 and is_contingent = 'No'"},
  {"name": "Payroll Cost, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Payroll Cost], 'Date'[Year Month] = 202608))",
   "sql": "select sum(cost_amount) from gold.ssas_fact_payroll_monthly where month_date_key = 20260831"},
  {"name": "Consumption Cost, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Consumption Cost], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(consumption_cost) from gold.ssas_fact_stock_movement where branch_key = 1 and is_consumption = 'Yes' and date_key >= 20260801 and date_key < 20260901"},
  {"name": "Stock Value, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Stock Value], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(stock_value) from gold.ssas_fact_stock_monthly where branch_key = 1 and month_date_key = 20260831 and is_expiry_store = 'No'"},
  {"name": "GL Closing Balance, branch 1, 2026-08", "tolerance": 0.01,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([GL Closing Balance], Branch[Branch Key] = 1, 'Date'[Year Month] = 202608))",
   "sql": "select sum(b.closing_balance * f.display_sign) from gold.ssas_fact_gl_balance_monthly as b inner join gold.ssas_dim_gl_account as a on a.gl_account_key = b.gl_account_key inner join gold.ssas_dim_fs_line as f on f.fs_line_key = a.fs_line_key where b.branch_key = 1 and b.balance_view = 'posted' and b.period_key = (select max(period_key) from gold.ssas_fact_gl_balance_monthly where branch_key = 1 and period_end_date_key >= 20260801 and period_end_date_key < 20260901)"},
  {"name": "Hospital NPS (5-point), 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Hospital NPS (5-point)], 'Date'[Year] = 2026))",
   "sql": "select (sum(is_promoter) - sum(is_detractor)) * 100 / count() from gold.ssas_fact_survey_answer where nps_role = 'Hospital NPS' and visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "Invitations, 2026", "tolerance": 0,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Invitations], 'Date'[Year] = 2026))",
   "sql": "select count() from gold.ssas_fact_survey_response where is_primary_for_encounter = 'Yes' and visit_date_key >= 20260101 and visit_date_key < 20270101"},
  {"name": "Response Rate %, 2026", "tolerance": 0.0001,
   "dax": "EVALUATE ROW(\"v\", CALCULATE([Response Rate %], 'Date'[Year] = 2026))",
   "sql": "select countIf(is_responded = 'Yes') / count() from gold.ssas_fact_survey_response where is_primary_for_encounter = 'Yes' and is_sms_sent = 'Yes' and visit_date_key >= 20260101 and visit_date_key < 20270101"}
]
```

Check each SQL now against ClickHouse (it must run and return one number):

Run: `python -c "import json,sys; sys.path.insert(0,'scripts'); import ch_env; c=ch_env.client(); [print(x['name'], c.query(x['sql']).result_rows[0][0]) for x in json.load(open('ssas/tests/measures/starter.json', encoding='utf-8'))]"`
Expected: 17 lines, each with a number (Hospital NPS 2026 close to 68.0).

- [ ] **Step 5: Commit**

```bash
git add ssas/HNH_Analytics ssas/bpa_rules.json ssas/tests/measures/starter.json
git commit -m "Add the starter measures, Best Practice rules and measure checks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: PowerShell module — partition planner and gate (Pester)

**Files:**
- Create: `ssas/scripts/HnhSsas.Tests.ps1`
- Create: `ssas/scripts/HnhSsas.psm1`

**Interfaces:**
- Produces (pure functions, used by Tasks 13–15):
  - `Get-HnhPartitionPlan -Table <string> -View <string> -Column <string> -Today <datetime> [-FirstYear 2022]` → array of `[pscustomobject]@{Name; Lo; Hi; IsNull; Query}` (Lo/Hi are yyyyMMdd ints or `$null`).
  - `Get-HnhDailyPartitionNames -Table <string> -Today <datetime>` → `string[]` (3 months + Later + No date).
  - `Compare-HnhPartitions -Desired <object[]> -Existing <hashtable name→query>` → `[pscustomobject]@{Add; Update; Remove}`.
  - `Test-HnhGate -Status <string> -FinishedAt <Nullable[datetime]> -LastProcessedRunAt <Nullable[datetime]>` → `bool`.
  - `Format-HnhTableRef -Name <string>` → `'Name'` with quotes doubled.

- [ ] **Step 1: Write the failing Pester tests**

`ssas/scripts/HnhSsas.Tests.ps1` (Pester 3.4 syntax, ships with Windows):

```powershell
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here 'HnhSsas.psm1') -Force

Describe 'Get-HnhPartitionPlan' {
    $plan = Get-HnhPartitionPlan -Table 'Charge Lines' -View 'ssas_fact_charge_line' -Column 'delivery_date_key' -Today (Get-Date '2026-10-07')

    It 'has three yearly, 24 monthly, Later and No date partitions' {
        $plan.Count | Should Be 29
        $plan[0].Name | Should Be 'Charge Lines 2022'
        $plan[2].Name | Should Be 'Charge Lines 2024'
        $plan[3].Name | Should Be 'Charge Lines 2025-01'
        $plan[26].Name | Should Be 'Charge Lines 2026-12'
        $plan[27].Name | Should Be 'Charge Lines Later'
        $plan[28].Name | Should Be 'Charge Lines No date'
    }

    It 'opens the first partition below and bounds the others' {
        $plan[0].Query | Should Be 'select * from gold.ssas_fact_charge_line where delivery_date_key < 20230101'
        $plan[1].Query | Should Be 'select * from gold.ssas_fact_charge_line where delivery_date_key >= 20230101 and delivery_date_key < 20240101'
        $plan[14].Query | Should Be 'select * from gold.ssas_fact_charge_line where delivery_date_key >= 20251201 and delivery_date_key < 20260101'
        $plan[27].Query | Should Be 'select * from gold.ssas_fact_charge_line where delivery_date_key >= 20270101'
        $plan[28].Query | Should Be 'select * from gold.ssas_fact_charge_line where delivery_date_key is null'
    }

    It 'puts every date key in exactly one partition (review focus 2)' {
        foreach ($key in 19000101, 20221231, 20230101, 20241231, 20250101, 20251215, 20260131, 20261231, 20270101, 99991231) {
            $hits = @($plan | Where-Object { -not $_.IsNull -and ($_.Lo -eq $null -or $key -ge $_.Lo) -and ($_.Hi -eq $null -or $key -lt $_.Hi) })
            $hits.Count | Should Be 1
        }
    }

    It 'turns the oldest monthly year into a yearly partition in January (review focus 2)' {
        $jan = Get-HnhPartitionPlan -Table 'T' -View 'v' -Column 'd' -Today (Get-Date '2027-01-05')
        $jan.Count | Should Be 30
        $jan[3].Name | Should Be 'T 2025'
        $jan[3].Query | Should Be 'select * from gold.v where d >= 20250101 and d < 20260101'
        $jan[4].Name | Should Be 'T 2026-01'
        $jan[28].Name | Should Be 'T Later'
        $jan[28].Query | Should Be 'select * from gold.v where d >= 20280101'
    }
}

Describe 'Get-HnhDailyPartitionNames' {
    It 'returns this month, the two before, Later and No date' {
        $names = Get-HnhDailyPartitionNames -Table 'T' -Today (Get-Date '2027-01-10')
        ($names -join '|') | Should Be 'T 2027-01|T 2026-12|T 2026-11|T Later|T No date'
    }
}

Describe 'Compare-HnhPartitions' {
    It 'adds missing, updates changed and removes unwanted partitions' {
        $desired = @(
            [pscustomobject]@{ Name = 'A'; Query = 'q1' },
            [pscustomobject]@{ Name = 'B'; Query = 'q2' },
            [pscustomobject]@{ Name = 'D'; Query = 'q4' }
        )
        $diff = Compare-HnhPartitions -Desired $desired -Existing @{ 'A' = 'q1'; 'B' = 'old'; 'C template' = 'q3' }
        (@($diff.Add) | ForEach-Object { $_.Name }) -join ',' | Should Be 'D'
        (@($diff.Update) | ForEach-Object { $_.Name }) -join ',' | Should Be 'B'
        (@($diff.Remove)) -join ',' | Should Be 'C template'
    }
}

Describe 'Test-HnhGate (review focus 5)' {
    $run = Get-Date '2026-10-07 09:30:00'
    It 'opens for a successful run never processed before' { Test-HnhGate -Status 'success' -FinishedAt $run -LastProcessedRunAt $null | Should Be $true }
    It 'opens for a newer successful run' { Test-HnhGate -Status 'success' -FinishedAt $run -LastProcessedRunAt $run.AddDays(-1) | Should Be $true }
    It 'stays closed for a failed run' { Test-HnhGate -Status 'failed' -FinishedAt $run -LastProcessedRunAt $null | Should Be $false }
    It 'stays closed for a run already processed' { Test-HnhGate -Status 'success' -FinishedAt $run -LastProcessedRunAt $run | Should Be $false }
    It 'stays closed when there is no run' { Test-HnhGate -Status '' -FinishedAt $null -LastProcessedRunAt $null | Should Be $false }
}

Describe 'Format-HnhTableRef' {
    It 'quotes table names for DAX' { Format-HnhTableRef "Patient's" | Should Be "'Patient''s'" }
}
```

- [ ] **Step 2: Run to see it fail**

Run (from the repo root, PowerShell): `powershell.exe -NoProfile -Command "Invoke-Pester -Script ssas\scripts\HnhSsas.Tests.ps1 -EnableExit"`
Expected: FAIL — the module file does not exist.

- [ ] **Step 3: Write the pure part of `ssas/scripts/HnhSsas.psm1`**

```powershell
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
```

- [ ] **Step 4: Run the tests**

Run: `powershell.exe -NoProfile -Command "Invoke-Pester -Script ssas\scripts\HnhSsas.Tests.ps1 -EnableExit"`
Expected: `Passed: 12 Failed: 0`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add ssas/scripts/HnhSsas.psm1 ssas/scripts/HnhSsas.Tests.ps1
git commit -m "Add the partition planner and processing gate for SSAS

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Server functions, `partitions.ps1` and `process.ps1`

**Files:**
- Modify: `ssas/scripts/HnhSsas.psm1` (append TOM, DAX and ODBC functions)
- Create: `ssas/scripts/partitions.ps1`
- Create: `ssas/scripts/process.ps1`

**Interfaces:**
- Produces: `Import-HnhTom [-TabularEditorDir]`, `Connect-HnhServer -Server` → `Microsoft.AnalysisServices.Tabular.Server`, `Get-HnhDatabase $server $name`, `Get-HnhAnnotation $object $name` → string or `$null`, `Save-HnhModel $model [-MaxParallelism 6]`, `Sync-HnhPartitions -Model -Today [-DryRun] [-NoRefresh]` → `string[]` log, `Update-HnhUnprocessed -Model` → `string[]`, `Add-HnhRoleMember -Model -Role -Member` → `bool`, `Invoke-HnhDax -Server -Database -Query [-EffectiveUserName]` → `DataTable`, `Invoke-HnhOdbc [-Dsn] -Query` → `DataTable`, `Get-HnhScalar $table` → `double` (blank → 0).
- Script contracts: `partitions.ps1 -Database <db> [-Server] [-Today] [-DryRun] [-NoRefresh]`; `process.ps1 [-Database HNH_Analytics] -Mode Daily|Weekly [-Force] [-Today]`, exit 0 = processed, 2 = gate closed, 1 = error. State file `ssas/state/<Database>.json` = `{"run_finished_at": "yyyy-MM-dd HH:mm:ss", "processed_at": "...", "mode": "..."}`.

These functions need an SSAS server, so they are verified on HNHANALYTICSSRV in Task 16; here they are syntax-checked and the pure tests re-run.

- [ ] **Step 1: Append the server functions to `HnhSsas.psm1`**

```powershell
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
    param([Parameter(Mandatory = $true)]$Model, [Parameter(Mandatory = $true)][datetime]$Today, [switch]$DryRun, [switch]$NoRefresh)
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
    if ($log.Count -gt 0 -and -not $DryRun) {
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
    $r.Members.Add($wm)
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
```

- [ ] **Step 2: Write `ssas/scripts/partitions.ps1`**

```powershell
<#
.SYNOPSIS
  Creates, merges and removes the date partitions of every large table (SSAS spec 9.3) and loads the changed ones
  in one transaction. -DryRun lists the changes only; -NoRefresh creates partitions without loading them.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ssas\scripts\partitions.ps1 -Database HNH_Analytics -DryRun
#>
param(
    [string]$Server = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [Parameter(Mandatory = $true)][string]$Database,
    [datetime]$Today = (Get-Date),
    [string]$TabularEditorDir = 'C:\Program Files (x86)\Tabular Editor',
    [switch]$DryRun,
    [switch]$NoRefresh
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'HnhSsas.psm1') -Force
Import-HnhTom $TabularEditorDir
$srv = Connect-HnhServer $Server
try {
    $db = Get-HnhDatabase $srv $Database
    $log = Sync-HnhPartitions -Model $db.Model -Today $Today -DryRun:$DryRun -NoRefresh:$NoRefresh
    if ($log.Count -eq 0) { Write-Host 'Partitions already match the scheme.' } else { $log | ForEach-Object { Write-Host $_ } }
} finally {
    $srv.Disconnect()
}
```

- [ ] **Step 3: Write `ssas/scripts/process.ps1`**

```powershell
<#
.SYNOPSIS
  Processes HNH_Analytics after a successful dbt run (SSAS spec 9.4).
  Daily: partitions in line with today, dimensions + last 3 months + Later + No date of each large table + small facts, then Calculate.
  Weekly: full refresh. One transaction each. Exit 0 = processed, 2 = gate closed (nothing done), 1 = error.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ssas\scripts\process.ps1 -Mode Daily
#>
param(
    [string]$Server = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [string]$Database = 'HNH_Analytics',
    [ValidateSet('Daily', 'Weekly')][string]$Mode = 'Daily',
    [string]$Dsn = 'HNH_Gold',
    [string]$TabularEditorDir = 'C:\Program Files (x86)\Tabular Editor',
    [datetime]$Today = (Get-Date),
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'HnhSsas.psm1') -Force
$root = Split-Path $PSScriptRoot -Parent
$logDir = Join-Path $root 'logs'
$stateDir = Join-Path $root 'state'
New-Item -ItemType Directory -Force $logDir, $stateDir | Out-Null
Start-Transcript -Path (Join-Path $logDir ('process_{0}_{1:yyyyMMdd_HHmmss}.log' -f $Database, (Get-Date))) | Out-Null
$exitCode = 0
try {
    $format = 'yyyy-MM-dd HH:mm:ss'
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $statePath = Join-Path $stateDir "$Database.json"
    $lastRun = $null
    if (Test-Path $statePath) {
        $state = Get-Content $statePath -Raw | ConvertFrom-Json
        if ($state.run_finished_at) { $lastRun = [datetime]::ParseExact($state.run_finished_at, $format, $culture) }
    }
    $run = Invoke-HnhOdbc -Dsn $Dsn -Query "select status, formatDateTime(run_finished_at, '%Y-%m-%d %H:%i:%S') as finished from gold.ssas_etl_run_log where selected = 'tag:hnh' order by run_finished_at desc limit 1"
    $status = ''; $finished = $null; $finishedText = $null
    if ($run.Rows.Count -gt 0) {
        $status = [string]$run.Rows[0]['status']
        $finishedText = [string]$run.Rows[0]['finished']
        $finished = [datetime]::ParseExact($finishedText, $format, $culture)
    }
    $since = $lastRun
    if ($Mode -eq 'Weekly') { $since = $null }
    if (-not $Force -and -not (Test-HnhGate -Status $status -FinishedAt $finished -LastProcessedRunAt $since)) {
        Write-Host "Gate closed: latest tag:hnh run status '$status' finished '$finishedText'; last processed run '$lastRun'. Nothing processed."
        $exitCode = 2
    } else {
        Import-HnhTom $TabularEditorDir
        $srv = Connect-HnhServer $Server
        try {
            $db = Get-HnhDatabase $srv $Database
            $model = $db.Model
            $log = Sync-HnhPartitions -Model $model -Today $Today -NoRefresh
            $log | ForEach-Object { Write-Host "partition $_" }
            $watch = [Diagnostics.Stopwatch]::StartNew()
            $dataOnly = [Microsoft.AnalysisServices.Tabular.RefreshType]::DataOnly
            if ($Mode -eq 'Weekly') {
                $model.RequestRefresh([Microsoft.AnalysisServices.Tabular.RefreshType]::Full)
            } else {
                foreach ($table in @($model.Tables)) {
                    $kind = Get-HnhAnnotation $table 'hnh_kind'
                    if ($kind -eq $null -or $kind -eq 'calculation_group') { continue }
                    $column = Get-HnhAnnotation $table 'hnh_partition_column'
                    if ($column) {
                        foreach ($name in (Get-HnhDailyPartitionNames -Table $table.Name -Today $Today)) {
                            $part = $table.Partitions.Find($name)
                            if ($part -eq $null) { throw "Partition $name is missing: run partitions.ps1" }
                            $part.RequestRefresh($dataOnly)
                        }
                    } else {
                        $table.RequestRefresh($dataOnly)
                    }
                }
                # Partitions created above (a new month or year) are empty until loaded.
                foreach ($line in $log) {
                    if ($line -like 'add *' -or $line -like 'update *') {
                        $name = $line.Substring($line.IndexOf(' ') + 1)
                        foreach ($table in @($model.Tables)) {
                            $part = $table.Partitions.Find($name)
                            if ($part -ne $null) { $part.RequestRefresh($dataOnly) }
                        }
                    }
                }
                $model.RequestRefresh([Microsoft.AnalysisServices.Tabular.RefreshType]::Calculate)
            }
            Save-HnhModel $model
            Write-Host ('{0} processing of {1} committed in {2:N1} minutes' -f $Mode, $Database, $watch.Elapsed.TotalMinutes)
            if ($finishedText) {
                @{ run_finished_at = $finishedText; processed_at = (Get-Date).ToString($format); mode = $Mode } |
                    ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8
            }
        } finally {
            $srv.Disconnect()
        }
    }
} catch {
    Write-Host "ERROR: $($_.Exception.ToString())"
    $exitCode = 1
} finally {
    Stop-Transcript | Out-Null
}
exit $exitCode
```

- [ ] **Step 4: Syntax-check the scripts and re-run Pester**

Run: `powershell.exe -NoProfile -Command "foreach ($f in 'ssas\scripts\HnhSsas.psm1','ssas\scripts\partitions.ps1','ssas\scripts\process.ps1') { $e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f), [ref]$null, [ref]$e); \"$f : $($e.Count) parse errors\" }"`
Expected: `0 parse errors` for each file.

Run: `powershell.exe -NoProfile -Command "Invoke-Pester -Script ssas\scripts\HnhSsas.Tests.ps1 -EnableExit"`
Expected: `Passed: 12 Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add ssas/scripts
git commit -m "Add the SSAS partition and processing scripts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Test script and test definitions

**Files:**
- Create: `ssas/scripts/test.ps1`
- Create: `ssas/tests/security.json`
- Create: `ssas/tests/performance.json`

**Interfaces:**
- Consumes: module functions (Tasks 12–13), `ssas/tests/measures/*.json` (Task 11).
- Produces: `test.ps1 -Database <db> [-Stage All|RowCounts|Security|Measures|Performance|Size]`, exit 0 = all passed, 1 = a failure; log in `ssas/logs/`. `security.json` keys: `admin`, `single_branch`, `specialty`, `pay`, `no_pay`, `pii`, `no_pii`, `no_access` → full logins `HNHANALYTICSSRV\<user>`, filled on the server in Task 16 (each must be a member of `HNH_BI_Users`; `no_access` must not be in `bi_users`).

- [ ] **Step 1: Write the test definitions**

`ssas/tests/security.json` (filled on the server; empty values make the security stage fail on purpose):

```json
{
  "admin": "",
  "single_branch": "",
  "specialty": "",
  "pay": "",
  "no_pay": "",
  "pii": "",
  "no_pii": "",
  "no_access": ""
}
```

`ssas/tests/performance.json` (run as the `single_branch` user, decision P14):

```json
[
  {"name": "Executive: revenue, visits and admissions by branch, one month",
   "dax": "EVALUATE SUMMARIZECOLUMNS ( Branch[Branch Name], TREATAS ( { 202608 }, 'Date'[Year Month] ), \"Revenue\", [Revenue], \"OP Visits\", [OP Visits], \"Admissions\", [Admissions] )"},
  {"name": "Revenue cycle: revenue YTD by payer category",
   "dax": "EVALUATE SUMMARIZECOLUMNS ( Payer[Category], TREATAS ( { 202608 }, 'Date'[Year Month] ), TREATAS ( { \"YTD\" }, 'Time Calculation'[Time Calculation] ), \"Revenue YTD\", [Revenue] )"},
  {"name": "Patient flow: occupancy by department",
   "dax": "EVALUATE SUMMARIZECOLUMNS ( Department[Department Name], TREATAS ( { 202608 }, 'Date'[Year Month] ), \"Occupancy\", [Bed Occupancy %] )"},
  {"name": "Claims: claimed amount by purchaser",
   "dax": "EVALUATE SUMMARIZECOLUMNS ( Payer[Purchaser Name], TREATAS ( { 202608 }, 'Date'[Year Month] ), \"Claimed\", [Claimed Amount] )"},
  {"name": "Finance: closing balance by FS line",
   "dax": "EVALUATE SUMMARIZECOLUMNS ( 'FS Line'[FS Line], TREATAS ( { 202608 }, 'Date'[Year Month] ), \"Balance\", [GL Closing Balance] )"},
  {"name": "Workforce: headcount and payroll by HR department",
   "dax": "EVALUATE SUMMARIZECOLUMNS ( 'HR Department'[Department Name], TREATAS ( { 202608 }, 'Date'[Year Month] ), \"Headcount\", [Headcount], \"Payroll\", [Payroll Cost] )"},
  {"name": "Supply chain: consumption and stock by item group",
   "dax": "EVALUATE SUMMARIZECOLUMNS ( Item[Item Group], TREATAS ( { 202608 }, 'Date'[Year Month] ), \"Consumption\", [Consumption Cost], \"Stock\", [Stock Value] )"},
  {"name": "Patient experience: NPS and response rate by branch",
   "dax": "EVALUATE SUMMARIZECOLUMNS ( Branch[Branch Name], TREATAS ( { 2026 }, 'Date'[Year] ), \"NPS\", [Hospital NPS (5-point)], \"Response rate\", [Response Rate %] )"}
]
```

Check the column names used exist: `grep -n "column 'Branch Name'\|column Category\|column 'Purchaser Name'\|column 'FS Line'\|column 'Item Group'\|column 'Department Name'\|column 'Year Month'" ssas/HNH_Analytics/tables/*.tmdl` must show each one in the expected table.

- [ ] **Step 2: Write `ssas/scripts/test.ps1`**

```powershell
<#
.SYNOPSIS
  Row-count, security, measure, performance and size tests of a deployed HNH_Analytics database (SSAS spec 11).
  Run as an SSAS administrator on HNHANALYTICSSRV. Exit 0 = all passed, 1 = at least one failure.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ssas\scripts\test.ps1 -Database HNH_Analytics_Test
#>
param(
    [string]$Server = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [Parameter(Mandatory = $true)][string]$Database,
    [string]$Dsn = 'HNH_Gold',
    [string]$TabularEditorDir = 'C:\Program Files (x86)\Tabular Editor',
    [ValidateSet('All', 'RowCounts', 'Security', 'Measures', 'Performance', 'Size')][string[]]$Stage = @('All')
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'HnhSsas.psm1') -Force
Import-HnhTom $TabularEditorDir
$root = Split-Path $PSScriptRoot -Parent
$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force $logDir | Out-Null
Start-Transcript -Path (Join-Path $logDir ('test_{0}_{1:yyyyMMdd_HHmmss}.log' -f $Database, (Get-Date))) | Out-Null
$script:failures = 0

function Report([string]$Name, [bool]$Ok, [string]$Detail) {
    $word = 'PASS'
    if (-not $Ok) { $word = 'FAIL'; $script:failures++ }
    Write-Host ('{0} {1}: {2}' -f $word, $Name, $Detail)
}
function Want([string]$Name) { return ($Stage -contains 'All' -or $Stage -contains $Name) }
function Dax([string]$Query, [string]$User) { return Invoke-HnhDax -Server $Server -Database $Database -Query $Query -EffectiveUserName $User }
function Sql([string]$Query) { return Invoke-HnhOdbc -Dsn $Dsn -Query $Query }
function ChString([string]$Value) { return "'" + $Value.Replace('\', '\\').Replace("'", "\'") + "'" }
function CountRows([string]$TableName, [string]$User) {
    return Get-HnhScalar (Dax ('EVALUATE ROW("n", COUNTROWS({0}))' -f (Format-HnhTableRef $TableName)) $User)
}

$srv = Connect-HnhServer $Server
$db = Get-HnhDatabase $srv $Database
$tables = @($db.Model.Tables | Where-Object { (Get-HnhAnnotation $_ 'hnh_view') -ne $null })
$facts = @($tables | Where-Object { (Get-HnhAnnotation $_ 'hnh_kind') -eq 'fact' })
$payTables = @('Payroll', 'Leave Balances', 'Staff Productivity')
$securityConfig = Get-Content (Join-Path $root 'tests\security.json') -Raw | ConvertFrom-Json

if (Want 'RowCounts') {
    foreach ($t in $tables) {
        $view = Get-HnhAnnotation $t 'hnh_view'
        $inSsas = CountRows $t.Name $null
        $inCh = Get-HnhScalar (Sql "select count() from gold.$view")
        Report "rows $($t.Name)" ($inSsas -eq $inCh) "SSAS $inSsas, ClickHouse $inCh"
    }
    $code = Get-HnhScalar (Dax 'EVALUATE ROW("c", UNICODE(MAXX(FILTER(Staff, NOT ISBLANK(Staff[Staff Name AR])), Staff[Staff Name AR])))' $null)
    Report 'arabic text' ($code -ge 1536 -and $code -le 1791) "first character code $code (Arabic block 1536-1791)"
}

if (Want 'Security') {
    foreach ($p in $securityConfig.PSObject.Properties) {
        $login = [string]$p.Value
        if ([string]::IsNullOrWhiteSpace($login)) { Report "security $($p.Name)" $false 'login not set in ssas/tests/security.json'; continue }
        try {
            $grant = Sql ("select branch_key, ifNull(unified_specialty, '') as specialty, can_see_pay, can_see_pii from gold.ssas_sec_user_access where lower(login_name) = lower({0})" -f (ChString $login))
            $branches = @($grant.Rows | ForEach-Object { [int64]$_['branch_key'] } | Sort-Object -Unique)
            $specialties = @($grant.Rows | ForEach-Object { [string]$_['specialty'] } | Where-Object { $_ -ne '' } | Sort-Object -Unique)
            $allRestricted = ($grant.Rows.Count -gt 0) -and (@($grant.Rows | Where-Object { [string]$_['specialty'] -eq '' }).Count -eq 0)
            $pay = @($grant.Rows | Where-Object { [int64]$_['can_see_pay'] -eq 1 }).Count -gt 0
            $pii = @($grant.Rows | Where-Object { [int64]$_['can_see_pii'] -eq 1 }).Count -gt 0

            $seen = @((Dax 'EVALUATE VALUES(Branch[Branch Key])' $login).Rows | ForEach-Object { [int64]$_[0] } | Sort-Object -Unique)
            Report "$($p.Name) branches" (($seen -join ',') -eq ($branches -join ',')) "sees [$($seen -join ',')], granted [$($branches -join ',')]"

            if ($branches.Count -gt 0) {
                $outside = Get-HnhScalar (Dax ('EVALUATE ROW("n", COUNTROWS(FILTER(Patient, Patient[Patient Key] <> -1 && NOT (Patient[Branch Key] IN {{ {0} }}))))' -f ($branches -join ', ')) $login)
                Report "$($p.Name) patient filter" ($outside -eq 0) "$outside patients outside the user's branches"
            }

            if ($allRestricted) {
                $list = ($specialties | ForEach-Object { '"' + $_.Replace('"', '""') + '"' }) -join ', '
                $bad = Get-HnhScalar (Dax ('EVALUATE ROW("n", COUNTROWS(FILTER(Staff, Staff[Staff Key] <> -1 && NOT (Staff[Unified Specialty] IN {{ {0} }}))))' -f $list) $login)
                Report "$($p.Name) specialty filter" ($bad -eq 0) "$bad staff rows outside [$($specialties -join ', ')]"
            }

            $payRows = CountRows 'Pay Category' $login
            Report "$($p.Name) pay" (($payRows -gt 0) -eq $pay) "pay categories visible: $payRows, can_see_pay: $pay"
            $piiRows = CountRows 'Patient Details' $login
            Report "$($p.Name) PII" (($piiRows -gt 0) -eq ($pii -and $branches.Count -gt 0)) "patient details visible: $piiRows, can_see_pii: $pii"

            if ($specialties.Count -eq 0) {
                # Review focus 1: every fact row of the user's branches is visible (no orphan keys hidden by a row filter).
                foreach ($f in $facts) {
                    $view = Get-HnhAnnotation $f 'hnh_view'
                    if ($branches.Count -eq 0 -or (($payTables -contains $f.Name) -and -not $pay)) { $expected = 0 }
                    else { $expected = Get-HnhScalar (Sql ('select count() from gold.{0} where branch_key in ({1})' -f $view, ($branches -join ','))) }
                    $got = CountRows $f.Name $login
                    Report "$($p.Name) rows $($f.Name)" ($got -eq $expected) "sees $got, expected $expected"
                }
            }
        } catch {
            Report "security $($p.Name)" $false $_.Exception.Message
        }
    }
}

if (Want 'Measures') {
    foreach ($file in Get-ChildItem (Join-Path $root 'tests\measures') -Filter *.json) {
        foreach ($check in (Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json)) {
            try {
                $value = Get-HnhScalar (Dax $check.dax $null)
                $expected = Get-HnhScalar (Sql $check.sql)
                Report "measure $($check.name)" ([math]::Abs($value - $expected) -le [double]$check.tolerance) "SSAS $value, ClickHouse $expected"
            } catch {
                Report "measure $($check.name)" $false $_.Exception.Message
            }
        }
    }
}

if (Want 'Performance') {
    $user = [string]$securityConfig.single_branch
    if ([string]::IsNullOrWhiteSpace($user)) { Report 'performance user' $false 'single_branch not set in ssas/tests/security.json' }
    else {
        $clear = '<ClearCache xmlns="http://schemas.microsoft.com/analysisservices/2003/engine"><Object><DatabaseID>{0}</DatabaseID></Object></ClearCache>' -f $db.ID
        foreach ($check in (Get-Content (Join-Path $root 'tests\performance.json') -Raw -Encoding UTF8 | ConvertFrom-Json)) {
            try {
                [void]$srv.Execute($clear)
                $watch = [Diagnostics.Stopwatch]::StartNew()
                [void](Dax $check.dax $user)
                $cold = $watch.Elapsed.TotalSeconds
                $watch.Restart()
                [void](Dax $check.dax $user)
                $warm = $watch.Elapsed.TotalSeconds
                Report "speed $($check.name)" ($cold -lt 3 -and $warm -lt 1) ('cold {0:N2} s, warm {1:N2} s (connection included)' -f $cold, $warm)
            } catch {
                Report "speed $($check.name)" $false $_.Exception.Message
            }
        }
    }
}

if (Want 'Size') {
    $srv.Disconnect()
    $srv = Connect-HnhServer $Server
    $db = Get-HnhDatabase $srv $Database
    $gb = $db.EstimatedSize / 1GB
    Report 'model size' ($gb -le 10) ('{0:N2} GB (budget 10 GB)' -f $gb)
}

$srv.Disconnect()
Write-Host "$($script:failures) failure(s)"
Stop-Transcript | Out-Null
if ($script:failures -gt 0) { exit 1 }
exit 0
```

- [ ] **Step 3: Syntax-check**

Run: `powershell.exe -NoProfile -Command "$e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'ssas\scripts\test.ps1'), [ref]$null, [ref]$e); \"$($e.Count) parse errors\""`
Expected: `0 parse errors`.

Run: `python -c "import json; [json.load(open(f, encoding='utf-8')) for f in ['ssas/tests/security.json', 'ssas/tests/performance.json', 'ssas/tests/measures/starter.json']]; print('json ok')"`
Expected: `json ok`.

- [ ] **Step 4: Commit**

```bash
git add ssas/scripts/test.ps1 ssas/tests
git commit -m "Add the SSAS row-count, security, measure, speed and size tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: Deployment script, operator guide, ignore rules

**Files:**
- Create: `ssas/scripts/deploy.ps1`
- Create: `ssas/README.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: everything above.
- Produces: `deploy.ps1 -Stage All|Validate|Test|Promote|Rollback [-BackupFile <name.abf>]` (spec 10.2). `All` = Validate → Test → Promote and stops at the first failure, leaving production untouched.

- [ ] **Step 1: Write `ssas/scripts/deploy.ps1`**

```powershell
<#
.SYNOPSIS
  Deploys HNH_Analytics (SSAS spec 10.2): Validate (Best Practice Analyzer + schema check) -> Test (deploy to
  HNH_Analytics_Test, partition, full process, test.ps1) -> Promote (backup, deploy metadata keeping partitions,
  members and data source, load what is not processed) -> clear the test database. Rollback restores a backup.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage All
  powershell -ExecutionPolicy Bypass -File ssas\scripts\deploy.ps1 -Stage Rollback -BackupFile HNH_Analytics_20261010_220000.abf
#>
param(
    [ValidateSet('All', 'Validate', 'Test', 'Promote', 'Rollback')][string]$Stage = 'All',
    [string]$Server = 'HNHANALYTICSSRV\REPORTSERVERDB',
    [string]$TabularEditorDir = 'C:\Program Files (x86)\Tabular Editor',
    [string]$Dsn = 'HNH_Gold',
    [string]$BackupFile
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$modelDir = Join-Path $root 'HNH_Analytics'
$rules = Join-Path $root 'bpa_rules.json'
$te = Join-Path $TabularEditorDir 'TabularEditor.exe'
$group = "$env:COMPUTERNAME\HNH_BI_Users"
Import-Module (Join-Path $PSScriptRoot 'HnhSsas.psm1') -Force
Import-HnhTom $TabularEditorDir
$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force $logDir | Out-Null
Start-Transcript -Path (Join-Path $logDir ('deploy_{0}_{1:yyyyMMdd_HHmmss}.log' -f $Stage, (Get-Date))) | Out-Null

function Invoke-TabularEditor([string[]]$Arguments) {
    $out = & $te @Arguments 2>&1 | Out-String
    Write-Host $out
    if ($LASTEXITCODE -ne 0 -or $out -match 'type=error') { throw "Tabular Editor failed: $($Arguments -join ' ')" }
}
function Invoke-Step([string]$Script, [string[]]$Arguments) {
    & (Join-Path $PSScriptRoot $Script) @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Script failed with exit code $LASTEXITCODE" }
}
function Want([string]$Name) { return ($Stage -eq 'All' -or $Stage -eq $Name) }

$exitCode = 0
try {
    if (Want 'Validate') {
        Write-Host '== Validate'
        Invoke-TabularEditor @($modelDir, '-A', $rules, '-SC', '-V')
    }
    if (Want 'Test') {
        Write-Host '== Test: HNH_Analytics_Test'
        Invoke-TabularEditor @($modelDir, '-D', $Server, 'HNH_Analytics_Test', '-O', '-C', '-P', '-R', '-E', '-V')
        $srv = Connect-HnhServer $Server
        [void](Add-HnhRoleMember -Model (Get-HnhDatabase $srv 'HNH_Analytics_Test').Model -Role 'HNH Readers' -Member $group)
        $srv.Disconnect()
        Invoke-Step 'partitions.ps1' @('-Server', $Server, '-Database', 'HNH_Analytics_Test', '-TabularEditorDir', $TabularEditorDir, '-NoRefresh')
        Invoke-Step 'process.ps1' @('-Server', $Server, '-Database', 'HNH_Analytics_Test', '-Mode', 'Weekly', '-Force', '-Dsn', $Dsn, '-TabularEditorDir', $TabularEditorDir)
        Invoke-Step 'test.ps1' @('-Server', $Server, '-Database', 'HNH_Analytics_Test', '-Dsn', $Dsn, '-TabularEditorDir', $TabularEditorDir)
    }
    if (Want 'Promote') {
        Write-Host '== Promote: HNH_Analytics'
        $srv = Connect-HnhServer $Server
        $prod = $srv.Databases.FindByName('HNH_Analytics')
        if ($prod -ne $null) {
            $file = 'HNH_Analytics_{0:yyyyMMdd_HHmmss}.abf' -f (Get-Date)
            $prod.Backup($file, $true)
            Write-Host "backup $file"
            $backupDir = $srv.ServerProperties['BackupDir'].Value
            Get-ChildItem $backupDir -Filter 'HNH_Analytics_*.abf' | Sort-Object LastWriteTime -Descending |
                Select-Object -Skip 5 | Remove-Item
            $srv.Disconnect()
            Invoke-TabularEditor @($modelDir, '-D', $Server, 'HNH_Analytics', '-O', '-R', '-E', '-V')
        } else {
            $srv.Disconnect()
            Invoke-TabularEditor @($modelDir, '-D', $Server, 'HNH_Analytics', '-O', '-C', '-P', '-R', '-E', '-V')
        }
        $srv = Connect-HnhServer $Server
        $db = Get-HnhDatabase $srv 'HNH_Analytics'
        if (Add-HnhRoleMember -Model $db.Model -Role 'HNH Readers' -Member $group) { Write-Host "role member $group added" }
        $srv.Disconnect()
        Invoke-Step 'partitions.ps1' @('-Server', $Server, '-Database', 'HNH_Analytics', '-TabularEditorDir', $TabularEditorDir)
        $srv = Connect-HnhServer $Server
        $loaded = Update-HnhUnprocessed -Model (Get-HnhDatabase $srv 'HNH_Analytics').Model
        Write-Host ("loaded {0} unprocessed partition(s): {1}" -f $loaded.Count, ($loaded -join '; '))
        $test = $srv.Databases.FindByName('HNH_Analytics_Test')
        if ($test -ne $null) {
            $test.Model.RequestRefresh([Microsoft.AnalysisServices.Tabular.RefreshType]::ClearValues)
            [void]$test.Model.SaveChanges()
            Write-Host 'HNH_Analytics_Test cleared'
        }
        $srv.Disconnect()
        Write-Host 'Promoted. Tag the deployed commit on the development machine: git tag ssas-YYYY.MM.DD'
    }
    if ($Stage -eq 'Rollback') {
        if (-not $BackupFile) { throw 'Rollback needs -BackupFile <file name in the SSAS backup folder>' }
        $srv = Connect-HnhServer $Server
        $srv.Restore($BackupFile, 'HNH_Analytics', $true)
        $srv.Disconnect()
        Write-Host "HNH_Analytics restored from $BackupFile"
    }
} catch {
    Write-Host "ERROR: $($_.Exception.ToString())"
    $exitCode = 1
} finally {
    Stop-Transcript | Out-Null
}
exit $exitCode
```

- [ ] **Step 2: Write `ssas/README.md`**

```markdown
# HNH_Analytics — SSAS Tabular model

Spec: `docs/superpowers/specs/2026-10-07-hnh-ssas-tabular-model-design.md`. Server `HNHANALYTICSSRV\REPORTSERVERDB`
(SQL Server 2025 Analysis Services, compatibility level 1700). Power BI Report Server reports connect live.

## Layout

| Path | What |
|---|---|
| `HNH_Analytics/` | TMDL model. Tables, relationships, perspectives, `model.tmdl` and `database.tmdl` are generated by `tools/generate.py`; `roles/`, `tables/Time Calculation.tmdl`, measures and hierarchies are hand-written and kept by the generator. |
| `tools/` | `model_config.py` (tables, relationship rules, perspectives), `generate.py`, `hnh_tmdl.py` + tests (`python -m pytest ssas/tools`). |
| `bpa_rules.json` | Best Practice Analyzer rules; any error stops a deploy. |
| `scripts/` | `deploy.ps1`, `partitions.ps1`, `process.ps1`, `test.ps1`, module `HnhSsas.psm1` + Pester tests. Windows PowerShell 5.1. |
| `tests/` | `security.json` (test logins), `measures/*.json` (DAX vs SQL checks), `performance.json`. |
| `logs/`, `state/` | Created on the server, not in git. |

## Prerequisites on the server

- Tabular Editor 2.27 in `C:\Program Files (x86)\Tabular Editor` (or pass `-TabularEditorDir`).
- ClickHouse ODBC driver (64-bit) and system DSN `HNH_Gold` → database `gold`, user `ssas_reader`.
- MSOLAP OLE DB provider (installed with SSMS or the AS client libraries).
- Local group `HNHANALYTICSSRV\HNH_BI_Users`; every report user is a member and has rows in `gold.sec_user_access`.
- Run every script in Windows PowerShell as an SSAS server administrator: `powershell -ExecutionPolicy Bypass -File ssas\scripts\<script>.ps1 …`.

## Change the model

1. Columns changed in a `gold.ssas_*` view → `python scripts/gen_view_contracts.py`, then `python ssas/tools/generate.py`.
2. Measures: edit the table file (`measure` blocks, `///` description, `formatString`, `displayFolder`). New snapshot measures must be added to the list in every `ISSELECTEDMEASURE` of `tables/Time Calculation.tmdl`.
3. Check offline: `TabularEditor.exe ssas\HNH_Analytics -A ssas\bpa_rules.json -V` (no `type=error`), `python -m pytest ssas/tools`, `Invoke-Pester -Script ssas\scripts\HnhSsas.Tests.ps1`.
4. Copy `ssas/` to the server and run `deploy.ps1 -Stage All`.

## Run

| Task | Command |
|---|---|
| Deploy (validate, test, promote) | `deploy.ps1 -Stage All` |
| After each successful dbt run | `process.ps1 -Mode Daily` (exit 2 = gate closed: no new successful `tag:hnh` run) |
| Friday | `process.ps1 -Mode Weekly` |
| Test production | `test.ps1 -Database HNH_Analytics` |
| Partition preview | `partitions.ps1 -Database HNH_Analytics -DryRun` |
| Roll back | `deploy.ps1 -Stage Rollback -BackupFile HNH_Analytics_<timestamp>.abf` (last 5 backups kept in the SSAS backup folder) |

## Give a user access

1. Add the Windows user to `HNHANALYTICSSRV\HNH_BI_Users`.
2. Add the user's branches and specialties to the BI users source (`default.bi_users`); for pay or PII add a row to `default.map_bi_user_permission`.
3. After the next dbt build and `process.ps1 -Mode Daily`, the measure `Branch[Current User]` in a report shows `HNHANALYTICSSRV\<user>`.
```

- [ ] **Step 3: Ignore runtime folders**

Append to `.gitignore`:

```
# SSAS runtime output on the server
/ssas/logs/
/ssas/state/
```

- [ ] **Step 4: Syntax-check and commit**

Run: `powershell.exe -NoProfile -Command "$e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'ssas\scripts\deploy.ps1'), [ref]$null, [ref]$e); \"$($e.Count) parse errors\""`
Expected: `0 parse errors`.

```bash
git add ssas/scripts/deploy.ps1 ssas/README.md .gitignore
git commit -m "Add the SSAS deployment script and operator guide

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: First deployment on HNHANALYTICSSRV (user runs, implementer reviews)

**Files:**
- Modify: `ssas/tests/security.json` (on the server only, unless the user wants the test logins in git)
- Modify: `docs/superpowers/specs/2026-10-07-hnh-ssas-tabular-model-design.md` (new section 15 "Implementation results")
- Modify: anything the server run shows to be wrong (fix in the repository, then re-run)

**Interfaces:**
- Consumes: Tasks 1–15, Task 2 spike results.
- Produces: `HNH_Analytics` in production, processed and tested; results recorded in spec section 15.

- [ ] **Step 1: Prepare the server (user)**

1. Copy the repository's `ssas` folder to the server (e.g. `D:\HNH\ssas`), replacing the copy from Task 2.
2. Fill `D:\HNH\ssas\tests\security.json` with eight real logins (`HNHANALYTICSSRV\<user>`), all members of `HNH_BI_Users`: an admin; a single-branch user without specialty; a user whose every row has a specialty; a user with and one without `can_see_pay`; one with and one without `can_see_pii`; and a member of the group who has no row in `bi_users` (`no_access`). If the pay/PII lists (open item O-S4) are not loaded yet, load `static_mappings/bi_user_permission.csv` with `python scripts/load_reference_data.py --only map_bi_user_permission` and run `python scripts/run_dbt.py build --select sec_user_access+` first.

- [ ] **Step 2: Validate and test (user)**

Run on the server: `powershell -ExecutionPolicy Bypass -File D:\HNH\ssas\scripts\deploy.ps1 -Stage Validate`, then `-Stage Test`.
Expected: Validate prints no `type=error`; Test ends with `0 failure(s)` from `test.ps1`. The user pastes `ssas\logs\deploy_*.log` and `test_*.log`.

- [ ] **Step 3: Review and fix (implementer)**

For every FAIL: find the cause (view, generator config, measure DAX, role DAX or script), fix it in the repository with its own commit, and ask the user to copy `ssas` again and re-run Step 2. Typical causes: a measure check whose SQL filter differs from the DAX filter; an orphan fact key (review focus 1: fix the gold model or the view, never hide it); a speed failure (record server timings with DAX Studio, then decide with the user whether to accept or change the measure).

- [ ] **Step 4: Promote (user)**

Run on the server: `powershell -ExecutionPolicy Bypass -File D:\HNH\ssas\scripts\deploy.ps1 -Stage Promote`
Expected: `role member HNHANALYTICSSRV\HNH_BI_Users added` (first deployment), partition lines, `loaded N unprocessed partition(s)`, `HNH_Analytics_Test cleared`, `Promoted.`

Then: `powershell -ExecutionPolicy Bypass -File D:\HNH\ssas\scripts\test.ps1 -Database HNH_Analytics -Stage RowCounts,Measures,Size`
Expected: `0 failure(s)`.

- [ ] **Step 5: Daily run with the gate (user)**

After the next `dbt build --select tag:hnh` on the receiving project: `process.ps1 -Mode Daily` → `Daily processing of HNH_Analytics committed in … minutes`. Run it a second time → exit code 2 and `Gate closed: …` (review focus 5).

- [ ] **Step 6: PBIRS identity check (user, spec 6.3, open item O-S3)**

In Power BI Desktop for Report Server (May 2026): Get data → SQL Server Analysis Services → server `HNHANALYTICSSRV\REPORTSERVERDB`, database `HNH_Analytics`, **Connect live**; add a card with `Branch[Current User]` and a table of `Branch[Branch Name]`; save to PBIRS. Open it in the browser as a non-admin test user.
Expected: the card shows `HNHANALYTICSSRV\<that user>` and the table lists only that user's branches.
If the card shows another account or the report fails to connect: in PBIRS → Manage → Data sources, set "Use the following credentials" (Windows) with a service account that is an SSAS administrator and tick "Impersonate the authenticated user after a connection has been made", then repeat the check.

- [ ] **Step 7: Record the results (implementer)**

Append to the spec:

```markdown
---

## 15. Implementation results (fill in dates and numbers from the logs)

| Item | Result |
|---|---|
| Spike (Task 2) | server/TOM versions, column types returned, all checks |
| Model size | VertiPaq estimate in GB (budget 10 GB) |
| First full process | duration in minutes |
| Daily process | duration in minutes |
| Tests | row counts, security, measures: pass/fail counts |
| Speed | slowest cold and warm query |
| PBIRS identity | Windows integrated or stored credential + impersonation |
| Open items closed | O-S1 … O-S9 with dates |
```

Fill every row from the pasted logs (no placeholders left), commit:

```bash
git add docs/superpowers/specs/2026-10-07-hnh-ssas-tabular-model-design.md
git commit -m "Record the first SSAS deployment results

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 8: Next plan**

Hand over to a new brainstorming/planning cycle for the full measure catalogue (spec 8.1, about 180 KPIs), written against the deployed column names.
