# Pester 3.4 tests of the deploy.ps1 sub-script calls (final review C1). Windows PowerShell 5.1.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $here 'HnhSsas.psm1') -Force

Describe 'Invoke-HnhStep' {
    $stub = Join-Path $TestDrive 'stub.ps1'
    $out = Join-Path $TestDrive 'bound.txt'
    Set-Content -Path $stub -Value @(
        'param([string]$Server, [string]$Database, [switch]$NoRefresh, [int]$ExitCode = 0)',
        ('Set-Content -Path ''{0}'' -Value @(("Server=" + $Server), ("Database=" + $Database), ("NoRefresh=" + [bool]$NoRefresh))' -f $out),
        'exit $ExitCode'
    )

    It 'binds the arguments by name, in any order' {
        Invoke-HnhStep -ScriptPath $stub -Arguments @{ NoRefresh = $true; Database = 'HNH_Analytics_Test'; Server = 'srv1' }
        $bound = Get-Content $out
        $bound[0] | Should Be 'Server=srv1'
        $bound[1] | Should Be 'Database=HNH_Analytics_Test'
        $bound[2] | Should Be 'NoRefresh=True'
    }

    It 'leaves a switch off when the hashtable omits it (the Promote call)' {
        Invoke-HnhStep -ScriptPath $stub -Arguments @{ Server = 'srv1'; Database = 'HNH_Analytics' }
        $bound = Get-Content $out
        $bound[1] | Should Be 'Database=HNH_Analytics'
        $bound[2] | Should Be 'NoRefresh=False'
    }

    It 'throws when the script exits non-zero' {
        { Invoke-HnhStep -ScriptPath $stub -Arguments @{ Server = 'srv1'; ExitCode = 3 } } | Should Throw 'failed with exit code 3'
    }
}
