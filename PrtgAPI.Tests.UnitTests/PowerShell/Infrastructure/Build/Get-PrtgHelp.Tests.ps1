. $PSScriptRoot\..\..\..\Support\PowerShell\Build.ps1

Describe "Get-PrtgHelp" -Tag @("PowerShell", "Build") {
    It "opens the PrtgAPI Wiki" {
        InModuleScope PrtgAPI.Build {
            Mock Start-Process {
                $args -join " " | Should Be "-FilePath: https://github.com/lordmilko/PrtgAPI/wiki/Compilation"
            } -Verifiable
        }

        Get-PrtgHelp

        Assert-VerifiableMocks
    }
}