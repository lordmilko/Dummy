ipmo $PSScriptRoot\..\..\..\..\Tools\PrtgAPI.Build
ipmo $PSScriptRoot\..\..\..\..\Tools\CI\ci.psm1

Describe "Update-PrtgVersion_IT" -Tag @("PowerShell", "Build_IT") {
    It "updates version on core" {
        $originalVersion = (Get-PrtgVersion).File

        try
        {
            Update-PrtgVersion

            $newVersion = (Get-PrtgVersion).File

            $newStr = "$($originalVersion.Major).$($originalVersion.Minor).$($originalVersion.Build + 1).$($originalVersion.Revision)"

            $newVersion | Should Be $newStr
        }
        finally
        {
            Set-PrtgVersion $originalVersion
        }
    }

    It "updates version on desktop" -Skip:(!(Test-IsWindows)) {
        $originalVersion = (Get-PrtgVersion -IsCore:$false).File

        try
        {
            Update-PrtgVersion -IsCore:$false

            $newVersion = (Get-PrtgVersion -IsCore:$false).File

            $newStr = "$($originalVersion.Major).$($originalVersion.Minor).$($originalVersion.Build + 1).$($originalVersion.Revision)"

            $newVersion | Should Be $newStr
        }
        finally
        {
            Set-PrtgVersion $originalVersion -IsCore:$false
        }
    }
}