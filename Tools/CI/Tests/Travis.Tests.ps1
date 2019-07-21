Import-Module $PSScriptRoot\..\ci.psm1
Import-Module $PSScriptRoot\..\Travis.psm1 -DisableNameChecking

$skipBuildModule = $true
. $PSScriptRoot\..\..\..\PrtgAPI.Tests.UnitTests\Support\PowerShell\Build.ps1

Describe "Travis" {
    It "simulates Travis" {
        WithoutTestDrive {
            Simulate-Travis
        }
    }
}