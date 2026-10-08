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

Describe 'ConvertTo-HnhOdbcExpression' {
    It 'wraps the SQL in Odbc.Query exactly as the generator does (hnh_tmdl.odbc_expression)' {
        ConvertTo-HnhOdbcExpression 'select * from gold.v where d < 20230101' |
            Should Be "let`n    Source = Odbc.Query(""dsn=HNH_Gold"", ""select * from gold.v where d < 20230101"")`nin`n    Source"
    }
    It 'doubles double quotes for M' {
        ConvertTo-HnhOdbcExpression 'select "a"' | Should Be "let`n    Source = Odbc.Query(""dsn=HNH_Gold"", ""select """"a"""""")`nin`n    Source"
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
