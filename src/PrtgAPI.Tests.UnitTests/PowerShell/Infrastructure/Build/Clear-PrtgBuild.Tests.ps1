. $PSScriptRoot\..\..\..\Support\PowerShell\Build.ps1

Describe "Clear-PrtgBuild" -Tag @("PowerShell", "Build") {

    It "clears core" {

        InModuleScope "CI" {
            Mock Invoke-CIProcess {
                throw "blah"
            }
        }
    }
}