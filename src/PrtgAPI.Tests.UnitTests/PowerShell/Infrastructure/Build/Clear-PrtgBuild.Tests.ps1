ipmo $PSScriptRoot\..\..\..\..\..\build\CI\ci.psm1 -Scope Local

Describe "Clear-PrtgBuild" -Tag @("PowerShell", "Build") {

    It "clears core" {

        InModuleScope "CI" {
            Mock Invoke-CIProcess {
                throw "blah"
            }
        }
    }
}