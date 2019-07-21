. $PSScriptRoot\..\..\..\..\PrtgAPI.Tests.UnitTests\Support\PowerShell\Build.ps1

$testCases = @(
    @{name = "Debug"}
    @{name = "Release"}
)

Describe "Invoke-PrtgTest_IT" -Tag @("PowerShell", "Build_IT") {
    
    It "tests on desktop for <name>" -Skip:(!(Test-IsWindows)) {

        param($name)

        # Do desktop tests first so we don't lock the PowerShell DLLs in the current process,
        # thereby allowing us to remove them when we run Clear-PrtgBuild on core
        Clear-PrtgBuild -Full

        Invoke-PrtgBuild -IsCore:$false -Configuration $name

        Invoke-PrtgTest -IsCore:$false -Type C# -Configuration $name
    }
    
    It "tests on core" {
        Clear-PrtgBuild -Full

        # Need a PowerShell Desktop build candidate for running this file in Windows PowerShell
        Invoke-PrtgBuild -Configuration Release

        WithoutTestDrive {
            Invoke-PrtgTest -Configuration Release
        }
    }
}