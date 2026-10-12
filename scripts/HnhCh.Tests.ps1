$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here 'HnhCh.psm1') -Force

Describe 'Test-HnhReadOnlySql' {
    It 'accepts SELECT, WITH, DESCRIBE and SHOW, with leading comments and a trailing semicolon' {
        Test-HnhReadOnlySql -Sql 'select 1' | Should Be $true
        Test-HnhReadOnlySql -Sql "-- note`nWITH x AS (SELECT 1) SELECT * FROM x" | Should Be $true
        Test-HnhReadOnlySql -Sql "DESCRIBE (`nselect 1`n)`nsettings join_use_nulls = 0" | Should Be $true
        Test-HnhReadOnlySql -Sql 'SHOW DATABASES;' | Should Be $true
    }
    It 'rejects writes and a second statement' {
        Test-HnhReadOnlySql -Sql 'INSERT INTO t SELECT 1' | Should Be $false
        Test-HnhReadOnlySql -Sql 'select 1; drop table t' | Should Be $false
        Test-HnhReadOnlySql -Sql 'TRUNCATE TABLE default.x' | Should Be $false
    }
}

Describe 'ConvertTo-HnhTsvField' {
    It 'writes NULL as \N and escapes backslash, tab and newline' {
        ConvertTo-HnhTsvField -Value $null | Should Be '\N'
        ConvertTo-HnhTsvField -Value ([System.DBNull]::Value) | Should Be '\N'
        ConvertTo-HnhTsvField -Value "a`tb" | Should Be 'a\tb'
        ConvertTo-HnhTsvField -Value "x\y`nz" | Should Be 'x\\y\nz'
    }
    It 'formats numbers with the invariant culture' {
        ConvertTo-HnhTsvField -Value 1.5 | Should Be '1.5'
    }
}

Describe 'Get-HnhContractColumns and Compare-HnhColumns' {
    $yaml = "version: 2`nmodels:`n  - name: bsc_a`n    config:`n      contract: {enforced: true}`n    columns:`n" +
            "      - name: id`n        data_type: `"UInt64`"`n      - name: d`n        data_type: `"Nullable(Date32)`"`n" +
            "  - name: bsc_b`n    columns:`n      - name: x`n        data_type: `"String`"`n"
    $cols = Get-HnhContractColumns -YamlText $yaml -Model 'bsc_a'
    It 'reads the columns of one model in order' {
        $cols.Count | Should Be 2
        $cols[1].Name | Should Be 'd'
        $cols[1].Type | Should Be 'Nullable(Date32)'
    }
    It 'reports type, name and count differences' {
        $actual = @([pscustomobject]@{ Name = 'id'; Type = 'UInt64' }, [pscustomobject]@{ Name = 'd'; Type = 'Date32' })
        $p = Compare-HnhColumns -Expected $cols -Actual $actual
        $p.Count | Should Be 1
        $p[0] | Should Be 'column 2: expected d Nullable(Date32), got d Date32'
        (Compare-HnhColumns -Expected $cols -Actual @($actual[0])).Count | Should Be 1
        (Compare-HnhColumns -Expected $cols -Actual @([pscustomobject]@{ Name = 'id'; Type = 'UInt64' },
            [pscustomobject]@{ Name = 'd'; Type = 'Nullable(Date32)' })).Count | Should Be 0
    }
}

Describe 'Compare-HnhBscRows' {
    $old = @([pscustomobject]@{ key_0 = '1'; val_0 = 100.0 }, [pscustomobject]@{ key_0 = '2'; val_0 = 50.0 },
             [pscustomobject]@{ key_0 = '3'; val_0 = $null })
    $new = @([pscustomobject]@{ key_0 = '1'; val_0 = 100.4 }, [pscustomobject]@{ key_0 = '2'; val_0 = 60.0 },
             [pscustomobject]@{ key_0 = '4'; val_0 = 1.0 })
    $d = Compare-HnhBscRows -Old $old -New $new -Keys @('key_0') -Columns @('val_0') -Tolerance 0.005
    It 'lists values beyond the tolerance and keys missing on either side' {
        $d.Count | Should Be 3
        ($d | Where-Object Key -eq '2').Status | Should Be 'differs'
        ($d | Where-Object Key -eq '3').Status | Should Be 'missing in new'
        ($d | Where-Object Key -eq '4').Status | Should Be 'missing in old'
    }
}

Describe 'New-HnhTableDdl and Test-HnhGlCutover' {
    It 'builds a MergeTree DDL with backquoted names' {
        $cols = @([pscustomobject]@{ name = 'a'; type = 'UInt8' }, [pscustomobject]@{ name = 'b'; type = 'Nullable(String)' })
        New-HnhTableDdl -Table 'default.t' -Columns $cols |
            Should Be 'CREATE TABLE IF NOT EXISTS default.t (`a` UInt8, `b` Nullable(String)) ENGINE = MergeTree ORDER BY tuple()'
    }
    It 'checks branch ids, YYYYMM months and duplicates' {
        $ok = @([pscustomobject]@{ BRANCH_ID = '6'; FIRST_FUSION_GL_MONTH = '202605'; NOTE = '' })
        (Test-HnhGlCutover -Rows $ok).Count | Should Be 0
        $bad = @([pscustomobject]@{ BRANCH_ID = '9'; FIRST_FUSION_GL_MONTH = '2026-05'; NOTE = '' },
                 [pscustomobject]@{ BRANCH_ID = '9'; FIRST_FUSION_GL_MONTH = '202613'; NOTE = '' })
        (Test-HnhGlCutover -Rows $bad).Count | Should Be 5
    }
}
