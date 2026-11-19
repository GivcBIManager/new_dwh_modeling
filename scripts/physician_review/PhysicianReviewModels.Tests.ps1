# Offline checks of the physician contract review models (plan 2026-11-19-physician-contract-review).
# Each model is rendered by scripts/render_model_sql.py with its refs replaced by inline rows, and the SQL runs read-only
# through DSN HNH_Gold. Nothing is written.
#   powershell -NoProfile -Command "Invoke-Pester -Script scripts\physician_review\PhysicianReviewModels.Tests.ps1"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent (Split-Path -Parent $here)
Import-Module (Join-Path $root 'scripts\HnhCh.psm1') -Force

# $Replace maps a ref'd model to inline SQL, written to a temp file for --replace.
function Get-RenderedModel([string]$Model, [hashtable]$Replace = @{}, [string]$Wrap = 'select * from ({model}) order by 1') {
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

function Invoke-Sql([string]$Sql) {
    return @(Invoke-HnhSelect -Dsn HNH_Gold -Sql ($Sql -replace '(?m)^\s*--.*$', ''))
}

# Staff rows (staff_key = branch * 100 + person), invented names. Person A: physician home row in branch 1 (101); unlinked
# rows of the same staff id: branch 2 (same national id, another name), 3 (id missing, name agrees), 4 (id differs),
# 5 (id missing, one shared name token), 6 (id missing, two shared tokens but another first token), 7 (id missing, name
# agrees after dropping "Dr.", case and punctuation); a linked nurse row in branch 8 (801).
# B: doctor with a nurse job (102) and its branch-2 row (202). C: one staff record shared by two employees (103) and its
# branch-2 row (203). D: contingent (104). E: part-time specialist, home id missing (105), branch-2 row with an id and an
# agreeing name (205). F: physician in branches 1 and 5 (106, 506) and an unlinked branch-6 row (606), same names.
# G: a nurse with a physician job (107). H: an unlinked doctor (708). -1: the Unknown row.
$staff = "select toInt64(k) as staff_key, toUInt8(b) as branch_key, sid as staff_id, cat as category, h as national_id_hash, nm as staff_name " +
         "from values('k Int64, b UInt8, sid Nullable(String), cat Nullable(String), h Nullable(Int64), nm Nullable(String)', " +
         "(101, 1, 'A1', 'DOCTORS', 1001, 'Zorvan Keltri Amsod'), (201, 2, 'A1', 'DOCTORS', 1001, 'Quillon Barth'), " +
         "(301, 3, 'A1', 'DOCTORS', NULL, 'zorvan  amsod'), (401, 4, 'A1', 'DOCTORS', 9999, 'Zorvan Keltri Amsod'), " +
         "(501, 5, 'A1', 'DOCTORS', NULL, 'Zorvan Pellig'), (601, 6, 'A1', 'DOCTORS', NULL, 'Keltri Amsod Zorvan'), " +
         "(701, 7, 'A1', 'DOCTORS', NULL, 'Dr. ZORVAN K. Keltri'), (801, 8, 'A1', 'NURSE', 1001, 'Zorvan Keltri Amsod'), " +
         "(102, 1, 'B1', 'DOCTORS', NULL, 'Staff B'), (202, 2, 'B1', 'DOCTORS', NULL, 'Staff B'), " +
         "(103, 1, 'C1', 'DOCTORS', NULL, 'Staff C'), (203, 2, 'C1', 'DOCTORS', NULL, 'Staff C'), (104, 1, 'D1', 'DOCTORS', NULL, 'Staff D'), " +
         "(105, 1, 'E1', 'DOCTORS', NULL, 'Merrow Tastin Vogel'), (205, 2, 'E1', 'DOCTORS', 5555, 'Merrow Vogel'), " +
         "(106, 1, 'F1', 'DOCTORS', NULL, 'Fennix Oradu'), (506, 5, 'F1', 'DOCTORS', NULL, 'Fennix Oradu'), (606, 6, 'F1', 'DOCTORS', NULL, 'Fennix Oradu'), " +
         "(107, 1, 'G1', 'NURSE', NULL, 'Staff G'), (708, 7, 'H1', 'DOCTORS', NULL, 'Staff H'), (-1, 0, NULL, NULL, NULL, 'Unknown'))"
$bridge = "select toInt64(e) as employee_key, toInt64(k) as staff_key, toUInt8(b) as branch_key from values('e Int64, k Int64, b UInt8', " +
          "(1, 101, 1), (2, 102, 1), (3, 103, 1), (4, 103, 1), (5, 104, 1), (6, 105, 1), (7, 106, 1), (8, 506, 5), (9, 107, 1), (10, 801, 8))"
$employee = "select toInt64(e) as employee_key, toInt64(j) as job_key, toInt64(g) as grade_key, toUInt8(p) as is_part_time, hd as hire_date, wt as worker_type_code " +
            "from values('e Int64, j Int64, g Int64, p UInt8, hd Nullable(Date32), wt Nullable(String)', " +
            "(1, 1, 1, 0, '2020-01-05', 'EMP'), (2, 2, 2, 0, '2019-03-01', 'EMP'), (3, 1, 1, 0, '2018-01-01', 'EMP'), (4, 1, 1, 0, '2018-01-01', 'EMP'), " +
            "(5, 1, 1, 0, '2021-01-01', 'CWK'), (6, 3, 1, 1, '2022-02-02', 'EMP'), (7, 4, 2, 0, '2017-07-07', 'EMP'), (8, 5, 2, 0, '2016-06-06', 'EMP'), " +
            "(9, 1, 1, 0, '2015-05-05', 'EMP'), (10, 2, 2, 0, '2014-04-04', 'EMP'), (-1, -1, -1, 0, NULL, NULL))"
$job = "select toInt64(j) as job_key, n as job_name from values('j Int64, n Nullable(String)', " +
       "(1, 'CONSULTANT'), (2, 'Nurse'), (3, 'Specialist'), (4, 'Registrar Doctor'), (5, 'registrar doctor'), (-1, 'Unknown'))"
$grade = "select toInt64(g) as grade_key, n as grade_name from values('g Int64, n Nullable(String)', (1, 'G7-3'), (2, 'G5-1'), (-1, 'Unknown'))"
$physicianRefs = @{ dim_staff = $staff; bridge_employee_staff = $bridge; hnh_dim_employee = $employee; hnh_dim_job = $job; hnh_dim_grade = $grade }

Describe 'dim_review_physician' {
    $rows = Invoke-Sql (Get-RenderedModel 'dim_review_physician' $physicianRefs)
    $k = @{}; foreach ($r in $rows) { $k[[string]$r.staff_key] = $r }
    It 'has one row per dim_staff row' {
        $rows.Count | Should Be 21
        $k.Count | Should Be 21
    }
    It 'flags a linked doctor with a physician job as a home row' {
        [int]$k['101'].is_review_physician | Should Be 1
        [int64]$k['101'].review_physician_key | Should Be 101
        $k['101'].job_title | Should Be 'Consultant'
        $k['101'].employment_type | Should Be 'Full-time'
        $k['101'].pay_grade | Should Be 'G7-3'
        ([datetime]$k['101'].hire_date).ToString('yyyy-MM-dd') | Should Be '2020-01-05'
    }
    It 'leaves out a doctor with a non-physician job' {
        [int]$k['102'].is_review_physician | Should Be 0
        [int64]$k['102'].review_physician_key | Should Be -1
        $k['102'].job_title | Should Be 'Nurse'
        [int64]$k['202'].review_physician_key | Should Be -1
    }
    It 'leaves out a staff record shared by two employees' {
        [int]$k['103'].is_review_physician | Should Be 0
        [int64]$k['103'].review_physician_key | Should Be -1
        $k['103'].employment_type | Should Be 'Not linked'
        [int64]$k['203'].review_physician_key | Should Be -1
    }
    It 'leaves out a contingent worker' {
        [int]$k['104'].is_review_physician | Should Be 0
        [int64]$k['104'].review_physician_key | Should Be -1
    }
    It 'leaves out a non-doctor with a physician job' {
        [int]$k['107'].is_review_physician | Should Be 0
        [int64]$k['107'].review_physician_key | Should Be -1
    }
    It 'attaches another hospital''s row when the national id agrees, whatever the names' {
        [int]$k['201'].is_review_physician | Should Be 0
        [int64]$k['201'].review_physician_key | Should Be 101
        $k['201'].job_title | Should Be 'Not linked'
    }
    It 'attaches another hospital''s row when the national id is missing on either side and the names agree' {
        [int64]$k['301'].review_physician_key | Should Be 101
        [int64]$k['205'].review_physician_key | Should Be 105
    }
    It 'does not attach a row with the id missing whose name shares only one token' {
        [int64]$k['501'].review_physician_key | Should Be -1
    }
    It 'does not attach a row with the id missing whose name shares two tokens but not the first' {
        [int64]$k['601'].review_physician_key | Should Be -1
    }
    It 'compares names without case, punctuation, single letters and Dr.' {
        [int64]$k['701'].review_physician_key | Should Be 101
    }
    It 'does not attach a row whose national id differs, or a row linked to HR itself' {
        [int64]$k['401'].review_physician_key | Should Be -1
        [int64]$k['801'].review_physician_key | Should Be -1
        $k['801'].job_title | Should Be 'Nurse'
    }
    It 'attaches a row with two candidate homes to neither' {
        [int]$k['106'].is_review_physician | Should Be 1
        [int64]$k['106'].review_physician_key | Should Be 106
        [int]$k['506'].is_review_physician | Should Be 1
        [int64]$k['506'].review_physician_key | Should Be 506
        $k['506'].job_title | Should Be 'Registrar Doctor'
        [int64]$k['606'].review_physician_key | Should Be -1
    }
    It 'labels a part-time physician' {
        [int]$k['105'].is_review_physician | Should Be 1
        $k['105'].employment_type | Should Be 'Part-time'
        $k['105'].job_title | Should Be 'Specialist'
    }
    It 'gives an unlinked row the Not linked defaults' {
        foreach ($s in '708', '-1') {
            [int]$k[$s].is_review_physician | Should Be 0
            $k[$s].job_title | Should Be 'Not linked'
            $k[$s].pay_grade | Should Be 'Not linked'
            $k[$s].employment_type | Should Be 'Not linked'
            $k[$s].hire_date | Should BeNullOrEmpty
            [int64]$k[$s].review_physician_key | Should Be -1
        }
    }
    It 'has the column types of the interface' {
        $types = @{}
        foreach ($c in (Invoke-Sql (Get-RenderedModel 'dim_review_physician' $physicianRefs 'describe ({model})'))) { $types[$c.name] = $c.type }
        $types['staff_key'] | Should Be 'Int64'
        $types['is_review_physician'] | Should Be 'UInt8'
        $types['job_title'] | Should Be 'String'
        $types['pay_grade'] | Should Be 'String'
        $types['employment_type'] | Should Be 'String'
        $types['hire_date'] | Should Be 'Nullable(Date)'
        $types['review_physician_key'] | Should Be 'Int64'
    }
}

Describe 'assert_review_physician_key_has_one_home_row' {
    # key 1: one home row and an attached row (fine); key 2: two home rows; key 3: no home row.
    $rp = "(select toInt64(k) as staff_key, toUInt8(f) as is_review_physician, toInt64(rk) as review_physician_key " +
          "from values('k Int64, f UInt8, rk Int64', (1, 1, 1), (11, 0, 1), (2, 1, 2), (22, 1, 2), (33, 0, 3), (44, 0, -1), (55, 0, -1)))"
    $sql = (Get-Content (Join-Path $root 'hnh_dwh\tests\hnh\assert_review_physician_key_has_one_home_row.sql') -Raw)
    $sql = $sql.Replace("{{ ref('dim_review_physician') }}", $rp)
    $rows = Invoke-Sql $sql
    It 'returns the keys with two home rows or none, not a good key or -1' {
        (@($rows | ForEach-Object { [int64]$_.review_physician_key } | Sort-Object) -join ',') | Should Be '2,3'
    }
}

Describe 'list_review_matches' {
    # The list runs on the model rendered from the rows above (its settings move to the end of the list).
    $model = (Get-RenderedModel 'dim_review_physician' $physicianRefs '{model}') -replace '(?s)\n\s*settings join_use_nulls = 1\s*$', ''
    $listRefs = @{ dim_review_physician = $model; dim_staff = $staff; bridge_employee_staff = $bridge }
    $rows = Invoke-Sql (Get-RenderedModel (Join-Path $root 'scripts\physician_review\list_review_matches.sql') $listRefs '{model}')
    $k = @{}; foreach ($r in $rows) { $k["$($r.home_staff_key)|$($r.other_staff_key)"] = $r }
    It 'lists every candidate pair, not a contradicting id or a row linked to HR' {
        $rows.Count | Should Be 8
        (@($k.Keys | Sort-Object) -join ',') | Should Be '101|201,101|301,101|501,101|601,101|701,105|205,106|606,506|606'
        [int]$k['101|201'].home_branch_key | Should Be 1
        [int]$k['101|201'].other_branch_key | Should Be 2
    }
    It 'says whether a pair is attached and why' {
        "$($k['101|201'].attached) $($k['101|201'].reason)" | Should Be '1 national id'
        "$($k['101|301'].attached) $($k['101|301'].reason)" | Should Be '1 name agrees'
        "$($k['101|701'].attached) $($k['101|701'].reason)" | Should Be '1 name agrees'
        "$($k['105|205'].attached) $($k['105|205'].reason)" | Should Be '1 name agrees'
        "$($k['101|501'].attached) $($k['101|501'].reason)" | Should Be '0 name differs'
        "$($k['101|601'].attached) $($k['101|601'].reason)" | Should Be '0 name differs'
        "$($k['106|606'].attached) $($k['106|606'].reason)" | Should Be '0 name agrees'
        "$($k['506|606'].attached) $($k['506|606'].reason)" | Should Be '0 name agrees'
    }
    It 'lists the pairs that are not attached first' {
        (@($rows | ForEach-Object { [int]$_.attached }) -join '') | Should Be '00001111'
    }
}

Describe 'hnh_name_tokens' {
    $code = "import sys; sys.path.insert(0, sys.argv[1]); import render_model_sql as r; sys.stdout.write(r.render_macro(sys.argv[2]))"
    $expr = (& python -c $code (Join-Path $root 'scripts') "hnh_name_tokens('t.n')") -join "`n"
    It 'drops case, punctuation, single letters and the particles dr, al, el, bin, abu, abd' {
        $r = Invoke-Sql "select arrayStringConcat($expr, ',') as v from (select 'Dr. ABU Yarel  el-Q. M bin Abd Al Tovin' as n) as t"
        $r[0].v | Should Be 'yarel,elq,tovin'
    }
}

Describe 'physician columns in ssas_dim_staff' {
    $yaml = [IO.File]::ReadAllText((Join-Path $root 'hnh_dwh\models\hnh\marts\ssas\_ssas__models.yml'))
    $list = Get-HnhContractColumns -YamlText $yaml -Model 'ssas_dim_staff'
    $cols = @{}; foreach ($c in $list) { $cols[$c.Name] = $c.Type }
    It 'lists the six columns with their types' {
        $cols['is_review_physician'] | Should Be 'Int64'
        $cols['job_title'] | Should Be 'String'
        $cols['pay_grade'] | Should Be 'String'
        $cols['employment_type'] | Should Be 'String'
        $cols['hire_date'] | Should Be 'Nullable(Date)'
        $cols['review_physician_key'] | Should Be 'Int64'
    }
    It 'joins dim_review_physician in the view and leaves the role view alone' {
        $view = [IO.File]::ReadAllText((Join-Path $root 'hnh_dwh\models\hnh\marts\ssas\ssas_dim_staff.sql'))
        $view -match "ref\('dim_review_physician'\)" | Should Be $true
        $role = [IO.File]::ReadAllText((Join-Path $root 'hnh_dwh\models\hnh\marts\ssas\ssas_dim_staff_role.sql'))
        $role -match 'review_physician' | Should Be $false
    }
}

Describe 'staff_key on fact_claim_line' {
    # fact_claim_line holds {% set %} lines and macros the offline renderer does not handle, so the test renders the model file
    # itself after stubbing those (the date-key, care-type, status-key, outcome and note-reason macros do not touch staff_key).
    $text = [IO.File]::ReadAllText((Join-Path $root 'hnh_dwh\models\hnh\marts\revenue\fact_claim_line.sql'))
    $text = $text -replace '(?m)^\{%.*%\}\s*$', ''
    $text = $text.Replace('{{ first_at }}', "toDateTime('2020-01-01 00:00:00', 'Asia/Riyadh')").Replace('{{ last_day }}', "toDate('2030-12-31')")
    $text = $text -replace "\{\{ hnh_reason_from_notes\([^}]*\) \}\}", 'cast(null as Nullable(String))'
    $text = $text -replace "\{\{ hnh_care_type\([^}]*\) \}\}", "'Unknown'"
    $text = $text -replace "\{\{ hnh_date_key_in_range\([^}]*\) \}\}", 'cast(null as Nullable(Int64))'
    $text = $text -replace "\{\{ hnh_care_type_key\([^}]*\) \}\}", 'toInt64(0)'
    $text = $text -replace "\{\{ hnh_claim_status_key\([^}]*\) \}\}", 'toInt64(0)'
    $text = $text.Replace("{{ hnh_surrogate_key(['d.branch_id', 'ifNull(d.purchaser_code, toInt64(9999))']) }}", 'toInt64(1)')  # the renderer splits arguments at commas
    $text = $text -replace "\{\{ hnh_nphies_outcome\([^}]*\) \}\}", "'Unknown'"
    $modelFile = [IO.Path]::GetTempFileName() -replace '\.tmp$', '.sql'
    [IO.File]::WriteAllText($modelFile, $text)

    # dim_staff keys exactly as dim_staff.sql builds them (hnh_surrogate_key of branch_id and staff_id).
    $key = "if(isNull(b) or isNull(s), toInt64(-1), toInt64(bitShiftRight(cityHash64(concat(toString(assumeNotNull(b)), '|', toString(assumeNotNull(s)), '|')), 1)))"
    $dimStaff = "select $key as staff_key from (select toUInt8(b) as b, toNullable(s) as s from values('b UInt8, s String', (1, 'D1'), (1, 'D2'), (2, 'D9')))"
    $services = "select toUInt8(b) as branch_id, toInt64(v) as visit_id, toInt64(q) as sequence_no, toNullable(toInt64(500)) as ios, toNullable('S') as service_code, " +
                "toFloat64(10) as net_amount, cast(null as Nullable(String)) as outcome, cast(null as Nullable(String)) as notes " +
                "from values('b UInt8, v Int64, q Int64', (1, 10, 1), (1, 10, 2), (1, 20, 1), (1, 30, 1), (1, 40, 1), (1, 50, 1), (2, 10, 1))"
    $submission = "select toUInt8(b) as branch_id, toInt64(v) as visit_id, toNullable(toInt64(v)) as claim_invoice_no, toNullable('S1') as stat_invoice_no, " +
                  "toNullable(toInt64(1)) as patient_id, toNullable(toInt64(1)) as episode_no, toNullable(toInt64(300)) as purchaser_code, toNullable('O') as claim_type, " +
                  "toNullable(toInt64(v)) as api_trans_id, toNullable(toDateTime('2026-06-01 09:00:00', 'Asia/Riyadh')) as request_at, " +
                  "toNullable(toDateTime('2026-06-30 00:00:00', 'Asia/Riyadh')) as statement_end_at, toUInt8(0) as is_cancelled, toUInt64(1) as submission_number, " +
                  "toUInt8(1) as is_latest_submission, toUInt8(1) as is_sent, cast(null as Nullable(Int64)) as final_response_id, " +
                  "cast(null as Nullable(DateTime('Asia/Riyadh'))) as final_responded_at, 'No response' as adjudication_status " +
                  "from values('b UInt8, v Int64', (1, 10), (1, 20), (1, 30), (1, 40), (1, 50), (2, 10))"
    # Visit 10: known doctor; 20: code not in dim_staff; 30: no code; 40: two visit rows (the later one counts); 50: no visit row;
    # branch 2 visit 10 has code D1, which only exists in branch 1.
    $visits = "select toUInt8(b) as branch_id, toInt64(v) as visit_id, if(d = '', cast(null as Nullable(String)), toNullable(d)) as doctor_code, " +
              "toNullable(toDateTime(c, 'Asia/Riyadh')) as created_at " +
              "from values('b UInt8, v Int64, d String, c String', (1, 10, 'D1', '2026-06-01 08:00:00'), (1, 20, 'ZZ', '2026-06-01 08:00:00'), " +
              "(1, 30, '', '2026-06-01 08:00:00'), (1, 40, 'D1', '2026-06-01 08:00:00'), (1, 40, 'D2', '2026-06-02 08:00:00'), (2, 10, 'D1', '2026-06-01 08:00:00'))"
    $empty = @{
        stg_oasis__episode_invoices = "select toUInt8(1) as branch_id, toInt64(1) as invoice_no, toNullable(toInt64(1)) as api_trans_id, toNullable('S1') as stat_invoice_no where 0"
        stg_oasis__invoice_statements = "select toUInt8(1) as branch_id, 'S1' as stat_invoice_no where 0"
        int_nphies_adjudication = "select toUInt8(1) as branch_id, toInt64(1) as response_id, toInt64(1) as item_sequence, 'Claim' as response_kind, 'x' as outcome, " +
            "toNullable(toFloat64(1)) as submitted, toNullable(toFloat64(1)) as eligible, toNullable(toFloat64(1)) as benefit, toNullable(toFloat64(1)) as copay, " +
            "toNullable(toFloat64(1)) as deductible, toNullable(toFloat64(1)) as tax, toNullable(toFloat64(1)) as patient_share, toNullable(toFloat64(1)) as approved_qty, " +
            "cast([] as Array(String)) as reason_codes, cast(null as Nullable(String)) as primary_reason_code, cast(null as Nullable(Float64)) as legacy_reason_amount where 0"
        int_episode = "select toUInt8(1) as branch_id, toInt64(1) as patient_id, toInt64(1) as episode_no, 'OP' as care_type"
        dim_patient = 'select toInt64(-1) as patient_key'
        dim_payer = 'select toInt64(-1) as payer_key'
        dim_service = 'select toInt64(-1) as service_key'
        dim_nphies_reason = 'select toInt64(-1) as nphies_reason_key'
        int_invoice_claim_status = "select toUInt8(1) as branch_id, toInt64(1) as invoice_no, toInt64(1) as claim_status_key where 0"
    }
    $refs = @{ stg_oasis__claim_services = $services; int_claim_submission = $submission; stg_oasis__claim_visits = $visits; dim_staff = $dimStaff }
    foreach ($e in $empty.GetEnumerator()) { $refs[$e.Key] = $e.Value }
    $rows = Invoke-Sql (Get-RenderedModel $modelFile $refs 'select branch_key, visit_id, sequence_no, staff_key from ({model}) order by branch_key, visit_id, sequence_no')
    $keyOf = @{ D1 = (Invoke-Sql "select $key as k from (select toUInt8(1) as b, toNullable('D1') as s)")[0].k; D2 = (Invoke-Sql "select $key as k from (select toUInt8(1) as b, toNullable('D2') as s)")[0].k }
    function Line([int]$b, [int]$v, [int]$q) { return @($rows | Where-Object { [int]$_.branch_key -eq $b -and [int]$_.visit_id -eq $v -and [int]$_.sequence_no -eq $q })[0] }
    It 'keeps one row per claim line whatever the number of visit rows' {
        $rows.Count | Should Be 7
    }
    It 'gives every line of a visit with a known doctor that doctor''s dim_staff key' {
        [string](Line 1 10 1).staff_key | Should Be ([string]$keyOf.D1)
        [string](Line 1 10 2).staff_key | Should Be ([string]$keyOf.D1)
    }
    It 'uses the later visit row when a visit has two, without duplicating lines' {
        [string](Line 1 40 1).staff_key | Should Be ([string]$keyOf.D2)
    }
    It 'gives -1 for a code that is not in dim_staff, a visit without a code and a visit without a row' {
        [int64](Line 1 20 1).staff_key | Should Be -1
        [int64](Line 1 30 1).staff_key | Should Be -1
        [int64](Line 1 50 1).staff_key | Should Be -1
    }
    It 'matches the doctor within the line''s own branch' {
        [int64](Line 2 10 1).staff_key | Should Be -1
    }
    It 'has staff_key as Int64 and a relationships test to dim_staff' {
        $types = @{}
        foreach ($c in (Invoke-Sql (Get-RenderedModel $modelFile $refs 'describe (select * from ({model}))'))) { $types[$c.name] = $c.type }
        $types['staff_key'] | Should Be 'Int64'
        $yml = [IO.File]::ReadAllText((Join-Path $root 'hnh_dwh\models\hnh\marts\revenue\_revenue_marts__models.yml'))
        $yml -match "(?s)- name: fact_claim_line\b.*?- name: staff_key\s+description: [^\n]*\s+tests:\s+- relationships: \{to: ref\('dim_staff'\), field: staff_key\}" | Should Be $true
    }
    It 'exposes staff_key on ssas_fact_claim_line' {
        $yaml = [IO.File]::ReadAllText((Join-Path $root 'hnh_dwh\models\hnh\marts\ssas\_ssas__models.yml'))
        $list = Get-HnhContractColumns -YamlText $yaml -Model 'ssas_fact_claim_line'
        $found = @(foreach ($col in $list) { if ($col.Name -eq 'staff_key') { $col } })
        $found.Count | Should Be 1
        $found[0].Type | Should Be 'Int64'
    }
}

Describe 'dim_physician_review_metric' {
    $rows = Invoke-Sql (Get-RenderedModel 'dim_physician_review_metric')
    $k = @{}; foreach ($r in $rows) { $k[[string]$r.metric_code] = $r }
    It 'has nine metrics with unique codes' {
        $rows.Count | Should Be 9
        $k.Count | Should Be 9
    }
    It 'has only the Salary and Income sections and directions -1, 0, 1' {
        foreach ($r in $rows) {
            @('Salary', 'Income') -contains [string]$r.section | Should Be $true
            @(-1, 0, 1) -contains [int]$r.direction | Should Be $true
        }
    }
    It 'lists the metrics in order with their units' {
        (@($rows | Sort-Object { [int]$_.display_order } | ForEach-Object { $_.metric_code }) -join ',') |
            Should Be 'PR_PACKAGE,PR_REVENUE,PR_REJECTION,PR_OP_VISITS,PR_ADMISSIONS,PR_SURGERIES,PR_REV_PER_PATIENT,PR_GROWTH,PR_REV_TO_PAY'
        (@($rows | Sort-Object { [int]$_.display_order } | ForEach-Object { $_.unit }) -join ',') | Should Be 'sar,sar,%,n,n,n,sar,%,x'
        $k['PR_PACKAGE'].metric_name | Should Be 'Monthly package'
        $k['PR_PACKAGE'].section | Should Be 'Salary'
        [int]$k['PR_REJECTION'].direction | Should Be -1
        [int]$k['PR_PACKAGE'].direction | Should Be 0
        $k['PR_REV_TO_PAY'].metric_name | Should Be 'Revenue-to-salary ratio'
    }
}

Describe 'dim_peer_scope' {
    $rows = Invoke-Sql (Get-RenderedModel 'dim_peer_scope')
    $k = @{}; foreach ($r in $rows) { $k[[string]$r.scope_code] = $r }
    It 'has the two scopes' {
        $rows.Count | Should Be 2
        "$($k['HOSPITAL'].scope_name)|$($k['HOSPITAL'].display_order)" | Should Be 'Same hospital|1'
        "$($k['GROUP'].scope_name)|$($k['GROUP'].display_order)" | Should Be 'Group|2'
    }
}

Describe 'review list views' {
    $yaml = [IO.File]::ReadAllText((Join-Path $root 'hnh_dwh\models\hnh\marts\ssas\_ssas__models.yml'))
    It 'declares the metric view columns' {
        $c = @{}; foreach ($x in (Get-HnhContractColumns -YamlText $yaml -Model 'ssas_dim_physician_review_metric')) { $c[$x.Name] = $x.Type }
        (@($c.Keys | Sort-Object) -join ',') | Should Be 'direction,display_order,metric_code,metric_name,section,unit'
        $c['direction'] | Should Be 'Int64'
        $c['display_order'] | Should Be 'Int64'
        $c['metric_code'] | Should Be 'String'
    }
    It 'declares the scope view columns' {
        $c = @{}; foreach ($x in (Get-HnhContractColumns -YamlText $yaml -Model 'ssas_dim_peer_scope')) { $c[$x.Name] = $x.Type }
        (@($c.Keys | Sort-Object) -join ',') | Should Be 'display_order,scope_code,scope_name'
        $c['display_order'] | Should Be 'Int64'
    }
    It 'has both view files' {
        foreach ($m in 'dim_physician_review_metric', 'dim_peer_scope') {
            [IO.File]::ReadAllText((Join-Path $root "hnh_dwh\models\hnh\marts\ssas\ssas_$m.sql")).Trim() | Should Be "{{ hnh_ssas_view('$m') }}"
        }
    }
}
