. $PSScriptRoot\..\..\..\..\PrtgAPI.Tests.UnitTests\Support\PowerShell\Build.ps1

$testCases = @(
    @{name = "Debug"}
    @{name = "Release"}
)

Describe "Get-PrtgTestResult_IT" -Tag @("PowerShell", "Build_IT") {
    
    It "gets test results from desktop for <name>" -TestCases $testCases -Skip:(!(Test-IsWindows)) {

        param($name)

        # Do desktop tests first so we don't lock the PowerShell DLLs in the current process,
        # thereby allowing us to remove them when we run Clear-PrtgBuild on core
        Clear-PrtgBuild -Full

        Invoke-PrtgBuild -Configuration $name -IsCore:$false
        Invoke-PrtgTest -Configuration $name -IsCore:$false -Type C#

        Get-PrtgTestResult -Type C#
    }
    
    It "gets test results from core for <name>" -TestCases $testCases {

        param($name)

        Clear-PrtgBuild -Full

        Invoke-PrtgBuild -Configuration $name

        WithoutTestDrive {
            Invoke-PrtgTest -Configuration $name
        }

        Get-PrtgTestResult
    }
}