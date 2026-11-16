# Offline checks of the policy / client-company / referral staging models (plan 2026-11-16-charge-line-relationships).
# Each model is rendered by scripts/render_model_sql.py; default.map_policy_client is replaced by inline rows and the
# SQL runs read-only through DSN HNH_Gold. Nothing is written.
#   powershell -NoProfile -Command "Invoke-Pester -Script scripts\policy_config\PolicyModels.Tests.ps1"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent (Split-Path -Parent $here)
Import-Module (Join-Path $root 'scripts\HnhCh.psm1') -Force

# $Replace maps a ref'd model to inline SQL, written to a temp file for --replace.
function Get-RenderedModel([string]$Model, [hashtable]$Replace = @{}) {
    $pyArgs = @((Join-Path $root 'scripts\render_model_sql.py'), $Model)
    foreach ($k in $Replace.Keys) {
        $f = [IO.Path]::GetTempFileName()
        [IO.File]::WriteAllText($f, $Replace[$k])
        $pyArgs += @('--replace', "$k=$f")
    }
    $pyArgs += @('--wrap', 'select * from ({model}) order by 1, 2')
    $sql = (& python @pyArgs) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "render failed: $Model" }
    return $sql
}

function Invoke-ModelWithSources([string]$Sql, [hashtable]$Sources) {
    $Sql = $Sql -replace '(?m)^\s*--.*$', ''
    foreach ($table in $Sources.Keys) { $Sql = $Sql.Replace("default.$table", "($($Sources[$table]))") }
    return @(Invoke-HnhSelect -Dsn HNH_Gold -Sql $Sql)
}

$cl = "now64(3) - toIntervalSecond(s) as changed_at, 'test' as changed_by, '' as change_note"

Describe 'stg_ref__policy_client keeps the newest row of each rule and drops a deleted rule' {
    $src = "select r as rule_id, toUInt8(6) as branch_id, toNullable(toInt64(11)) as purchaser_code, toNullable(toInt64(0)) as policy_code, " +
           "'' as name_pattern, ' ' || c || ' ' as client_company, toNullable(toUInt8(0)) as is_referral, $cl, toUInt8(d) as is_deleted " +
           "from values('r String, c String, s UInt32, d UInt8', " +
           "('PAT-STC', 'STC', 30, 0), ('PAT-STC', 'STC Co', 20, 0), ('PAT-STC', 'STC Group', 10, 0), " +
           "('PAT-X', 'X', 20, 0), ('PAT-X', 'X', 10, 1))"
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'stg_ref__policy_client') @{ map_policy_client = $src }
    It 'returns one row with the newest company, trimmed' {
        $rows.Count | Should Be 1
        $rows[0].rule_id | Should Be 'PAT-STC'
        $rows[0].client_company | Should Be 'STC Group'
    }
}
