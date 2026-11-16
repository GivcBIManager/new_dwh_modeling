# Offline checks of the policy / client-company / referral staging models (plan 2026-11-16-charge-line-relationships).
# Each model is rendered by scripts/render_model_sql.py; default.map_policy_client is replaced by inline rows and the
# SQL runs read-only through DSN HNH_Gold. Nothing is written.
#   powershell -NoProfile -Command "Invoke-Pester -Script scripts\policy_config\PolicyModels.Tests.ps1"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent (Split-Path -Parent $here)
Import-Module (Join-Path $root 'scripts\HnhCh.psm1') -Force

# $Replace maps a ref'd model to inline SQL, written to a temp file for --replace.
function Get-RenderedModel([string]$Model, [hashtable]$Replace = @{}, [string]$Wrap = 'select * from ({model}) order by 1, 2') {
    $pyArgs = @((Join-Path $root 'scripts\render_model_sql.py'), $Model)
    foreach ($k in $Replace.Keys) {
        $f = [IO.Path]::GetTempFileName()
        [IO.File]::WriteAllText($f, $Replace[$k])
        $pyArgs += @('--replace', "$k=$f")
    }
    $pyArgs += @('--wrap', $Wrap)
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

# int_policy_client fixtures: policies as (branch, policy code, purchaser, description); rules as
# (rule_id, branch 0 = all, purchaser 0 = any, policy code 0 = pattern rule, pattern, company, referral 9 = no opinion).
function New-PolicySql([string[]]$Rows) {
    return "select toUInt8(b) as branch_id, toInt64(c) as policy_code, toNullable(toInt64(pu)) as purchaser_code, " +
           "cast(null as Nullable(String)) as account_no, toNullable(d) as description, toUInt8(1) as is_active " +
           "from values('b UInt8, c Int64, pu Int64, d String', $($Rows -join ', '))"
}
function New-RuleSql([string[]]$Rows) {
    $values = if ($Rows.Count) { $Rows -join ', ' } else { "('none', 0, 0, 0, '', '', 9)" }
    $where = if ($Rows.Count) { '' } else { ' where 0' }
    return "select r as rule_id, toUInt8(b) as branch_id, if(pu = 0, null, toNullable(toInt64(pu))) as purchaser_code, " +
           "if(pc = 0, null, toNullable(toInt64(pc))) as policy_code, pat as name_pattern, co as client_company, " +
           "if(rf = 9, null, toNullable(toUInt8(rf))) as is_referral " +
           "from values('r String, b UInt8, pu Int64, pc Int64, pat String, co String, rf UInt8', $values)$where"
}
function Get-PolicyClient([string[]]$Policies, [string[]]$Rules = @()) {
    $sql = Get-RenderedModel 'int_policy_client' @{ stg_oasis__policies = (New-PolicySql $Policies); stg_ref__policy_client = (New-RuleSql $Rules) }
    return Invoke-ModelWithSources $sql @{}
}
function Get-Row($Rows, [int]$Branch, [long]$Code) {
    return @($Rows | Where-Object { $_.branch_id -eq $Branch -and $_.policy_code -eq $Code })[0]
}
$stc = "('PAT-STC', 0, 0, 0, 'STC|SAUDI TELECOM', 'STC', 9)"

Describe 'int_policy_client: exact rule beats pattern' {
    $rows = Get-PolicyClient @("(6, 10, 11, 'BUPA - STC PAY (1)')") @($stc, "('EX-10', 6, 0, 10, '', 'STC Pay', 9)")
    It 'takes the exact rule company' {
        $rows.Count | Should Be 1
        $rows[0].client_company | Should Be 'STC Pay'
        $rows[0].policy_name | Should Be 'BUPA - STC PAY (1)'
    }
}

Describe 'int_policy_client: branch rule beats all-branch rule' {
    $rows = Get-PolicyClient @("(6, 20, 11, 'X - ACME CO (5)')", "(5, 20, 11, 'X - ACME CO (5)')") `
        @("('EX-ALL', 0, 0, 20, '', 'Acme All', 0)", "('EX-6', 6, 0, 20, '', 'Acme Six', 1)")
    It 'uses the branch rule on its branch and the all-branch rule elsewhere' {
        (Get-Row $rows 6 20).client_company | Should Be 'Acme Six'
        (Get-Row $rows 6 20).is_referral | Should Be 1
        (Get-Row $rows 5 20).client_company | Should Be 'Acme All'
        (Get-Row $rows 5 20).is_referral | Should Be 0
    }
}

Describe 'int_policy_client: longer pattern wins' {
    $rows = Get-PolicyClient @("(6, 30, 11, 'BUPA - SAUDI ARAMCO SHELL REFINERY CO (45193700)')") `
        @("('PAT-ARAMCO', 0, 0, 0, 'ARAMCO', 'Saudi Aramco', 9)", "('PAT-SASREF', 0, 0, 0, 'SAUDI ARAMCO SHELL', 'SASREF', 9)")
    It 'takes SASREF' { $rows[0].client_company | Should Be 'SASREF' }
}

Describe 'int_policy_client: the longest matched text wins, not the longest pattern' {
    $rows = Get-PolicyClient @("(6, 80, 11, 'TAWUNIYA - STC PAY (2540)')", "(6, 81, 11, 'TAWUNIYA - SAUDI TELECOM CO 2133')") `
        @($stc, "('PAT-STCPAY', 0, 0, 0, 'STC PAY', 'STC Pay', 9)")
    It 'gives STC PAY to STC Pay and SAUDI TELECOM to STC' {
        (Get-Row $rows 6 80).client_company | Should Be 'STC Pay'
        (Get-Row $rows 6 81).client_company | Should Be 'STC'
    }
}

Describe 'int_policy_client: a pattern is literal text, never a regular expression' {
    $rows = Get-PolicyClient @("(6, 90, 11, 'BUPA - C++ SOFTWARE (1)')", "(6, 91, 11, 'BUPA - C SOFTWARE (1)')", "(6, 92, 11, 'BUPA - COX (1)')") `
        @("('PAT-CPP', 0, 0, 0, 'C++', 'Cpp Co', 9)", "('PAT-CO', 0, 0, 0, 'CO.', 'Co Dot', 9)")
    It 'C++ builds and matches only C++' {
        (Get-Row $rows 6 90).client_company | Should Be 'Cpp Co'
        (Get-Row $rows 6 91).client_company | Should Be 'C Software'
    }
    It 'CO. does not match COX' {
        (Get-Row $rows 6 92).client_company | Should Be 'Cox'
    }
}

Describe 'int_policy_client: whole-word pattern does not match WESTCON or MISTCA' {
    $rows = Get-PolicyClient @("(6, 41, 11, 'BUPA - WESTCON SAUDI COMPANY (46084600)')", "(6, 42, 11, 'MEDGULF-MEDIVISA - MISTCA (13194840)')",
                               "(6, 43, 11, 'TAWUNIYA - SAUDI TELECOM CO 2133')") @($stc)
    It 'falls back for WESTCON and MISTCA and matches SAUDI TELECOM' {
        (Get-Row $rows 6 41).client_company | Should Be 'Westcon Saudi Company'
        (Get-Row $rows 6 42).client_company | Should Be 'Mistca'
        (Get-Row $rows 6 43).client_company | Should Be 'STC'
    }
}

Describe 'int_policy_client: company-only exact row keeps a referral from a pattern' {
    $rows = Get-PolicyClient @("(6, 50, 11, 'X - ACME HOLDING (7)')") `
        @("('PAT-ACME', 0, 0, 0, 'ACME', '', 1)", "('EX-50', 6, 0, 50, '', 'Acme Exact', 9)")
    It 'has the exact company and the pattern referral' {
        $rows[0].client_company | Should Be 'Acme Exact'
        $rows[0].is_referral | Should Be 1
    }
}

Describe 'int_policy_client: no rule gives fallback name and not referral' {
    $rows = Get-PolicyClient @("(6, 60, 11, 'TAWUNIYA - STC CHANNELS (2535)')", "(6, 61, 11, 'TAWUNIYA-STC SOLUTIONS(2246)')",
                               "(6, 62, 11, 'TAWUNIYA - STC PAY (2540)')", "(6, 63, 11, 'X - AL-RAJHI BANK')", "(6, 64, 11, 'PLAIN NAME 77')",
                               "(6, 65, 11, 'NCCI - STC MAIN - 2233')", "(6, 66, 11, 'NATIONAL GUARD (0041).')")
    It 'takes the text after the dash, without the number, title-cased' {
        (Get-Row $rows 6 60).client_company | Should Be 'Stc Channels'
        (Get-Row $rows 6 60).is_referral | Should Be 0
        (Get-Row $rows 6 61).client_company | Should Be 'Stc Solutions'
        (Get-Row $rows 6 62).client_company | Should Be 'Stc Pay'
        (Get-Row $rows 6 63).client_company | Should Be 'Al-Rajhi Bank'
        (Get-Row $rows 6 64).client_company | Should Be 'Plain Name'
    }
    It 'drops dots and dashes around the trailing number' {
        (Get-Row $rows 6 65).client_company | Should Be 'Stc Main'
        (Get-Row $rows 6 66).client_company | Should Be 'National Guard'
    }
}

Describe 'int_policy_client: purchaser-limited rule skips other purchasers' {
    $rows = Get-PolicyClient @("(6, 70, 11, 'X - ACME (1)')", "(6, 71, 12, 'X - ACME TWO (2)')") @("('PAT-ACME-11', 0, 11, 0, 'ACME', 'Acme', 1)")
    It 'applies to purchaser 11 only' {
        (Get-Row $rows 6 70).client_company | Should Be 'Acme'
        (Get-Row $rows 6 70).is_referral | Should Be 1
        (Get-Row $rows 6 71).client_company | Should Be 'Acme Two'
        (Get-Row $rows 6 71).is_referral | Should Be 0
    }
}

Describe 'stg_ref__referral_policy reads the resolved referral policies' {
    $int = "select toUInt8(b) as branch_id, toInt64(c) as policy_code, if(pu = 0, null, toNullable(toInt64(pu))) as purchaser_code, toUInt8(r) as is_referral " +
           "from values('b UInt8, c Int64, pu Int64, r UInt8', (6, 1, 11, 1), (6, 2, 11, 0), (5, 1, 11, 1), (6, 3, 0, 1))"
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'stg_ref__referral_policy' @{ int_policy_client = $int }) @{}
    $types = Invoke-ModelWithSources (Get-RenderedModel 'stg_ref__referral_policy' @{ int_policy_client = $int } `
        'select toTypeName(branch_id) as b, toTypeName(purchaser_code) as pu, toTypeName(policy_code) as c from ({model}) limit 1') @{}
    It 'keeps the referral policies, a policy without purchaser as -1' {
        $rows.Count | Should Be 3
        ($rows | ForEach-Object { "$($_.branch_id)/$($_.purchaser_code)/$($_.policy_code)" }) -join ',' | Should Be '5/11/1,6/-1/3,6/11/1'
    }
    It 'keeps the column types UInt8, Int64, Int64' {
        "$($types[0].b),$($types[0].pu),$($types[0].c)" | Should Be 'UInt8,Int64,Int64'
    }
}

Describe 'dim_policy has three fixed members per branch and the Unknown row' {
    $int = "select toUInt8(6) as branch_id, toInt64(10) as policy_code, toNullable(toInt64(11)) as purchaser_code, " +
           "toNullable('BUPA - STC PAY (1)') as policy_name, 'STC' as client_company, toUInt8(1) as is_referral, toUInt8(1) as is_active"
    $payer = "select toUInt8(6) as branch_key, toNullable(toInt64(11)) as purchaser_code, 'Bupa' as company"
    $branch = "select toUInt8(b) as branch_key from values('b UInt8', 0, 5, 6)"
    $rows = Invoke-ModelWithSources (Get-RenderedModel 'dim_policy' @{ int_policy_client = $int; dim_payer = $payer; hnh_dim_branch = $branch }) @{}
    It 'has the policy with its insurer and title-cased name' {
        $p = @($rows | Where-Object { $_.policy_code -eq 10 })[0]
        $p.policy_name | Should Be 'Bupa - Stc Pay (1)'
        $p.insurer | Should Be 'Bupa'
        $p.client_company | Should Be 'STC'
        $p.branch_key | Should Be 6
    }
    It 'has Cash, Deductible and Not Recorded for a branch without policies' {
        $b5 = @($rows | Where-Object { $_.branch_key -eq 5 } | Sort-Object policy_code)
        ($b5 | ForEach-Object { "$($_.policy_code):$($_.policy_name):$($_.insurer):$($_.client_company)" }) -join ',' |
            Should Be '-3:Deductible:Deductible:Deductible,-2:Cash:Cash:Cash,-1:Not Recorded:Not Recorded:Not Recorded'
    }
    It 'has one Unknown row with key -1 and unique keys' {
        $u = @($rows | Where-Object { $_.policy_key -eq -1 })
        $u.Count | Should Be 1
        $u[0].policy_name | Should Be 'Unknown'
        $u[0].branch_key | Should Be 0
        @($rows | Select-Object -ExpandProperty policy_key -Unique).Count | Should Be $rows.Count
    }
}
