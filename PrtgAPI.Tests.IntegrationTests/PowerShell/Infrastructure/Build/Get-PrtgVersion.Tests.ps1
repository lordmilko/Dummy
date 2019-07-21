ipmo $PSScriptRoot\..\..\..\..\Tools\PrtgAPI.Build
ipmo $PSScriptRoot\..\..\..\..\Tools\CI\ci.psm1

Describe "Get-PrtgVersion_IT" -Tag @("PowerShell", "Build_IT") {
    It "gets the version on core" {
        Get-PrtgVersion
    }

    It "gets the version on desktop" -Skip:(!(Test-IsWindows)) {
        Get-PrtgVersion -IsCore:$false
    }
}