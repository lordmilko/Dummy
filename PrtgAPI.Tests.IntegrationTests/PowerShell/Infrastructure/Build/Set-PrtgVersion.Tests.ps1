ipmo $PSScriptRoot\..\..\..\..\Tools\PrtgAPI.Build
ipmo $PSScriptRoot\..\..\..\..\Tools\CI\ci.psm1

Describe "Set-PrtgVersion_IT" -Tag @("PowerShell", "Build_IT") {
    It "sets version on core" {
        $originalVersion = Get-PrtgVersion

        try
        {
            Set-PrtgVersion 1.2.3

            $newVersion = Get-PrtgVersion

            $newVersion.Package | Should Be "1.2.3"
        }
        finally
        {
            Set-PrtgVersion $originalVersion.File
        }
    }

    It "sets version on desktop" -Skip:(!(Test-IsWindows)) {
        $originalVersion = Get-PrtgVersion -IsCore:$false

        try
        {
            Set-PrtgVersion 1.2.3 -IsCore:$false

            $newVersion = Get-PrtgVersion -IsCore:$false

            $newVersion.Package | Should Be "1.2.3"
        }
        finally
        {
            Set-PrtgVersion $originalVersion.File -IsCore:$false
        }
    }
}