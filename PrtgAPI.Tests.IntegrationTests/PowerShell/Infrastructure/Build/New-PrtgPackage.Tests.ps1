. $PSScriptRoot\..\..\..\..\PrtgAPI.Tests.UnitTests\Support\PowerShell\BuildCore.ps1

$testCases = @(
    @{name = "Debug"}
    @{name = "Release"}
)

Describe "New-PrtgPackage_IT" -Tag @("PowerShell", "Build_IT") {
    It "creates packages on core for <name>" -TestCases $testCases -Skip:(SkipBuildTest) {

        param($name)

        Clear-PrtgBuild -Full

        Invoke-PrtgBuild -Configuration $name

        New-PrtgPackage -Configuration $name
    }

    It "creates packages on desktop for <name>" -TestCases $testCases -Skip:(!(Test-IsWindows) -or (SkipBuildTest)) {

        param($name)

        Clear-PrtgBuild -Full

        Invoke-PrtgBuild -Configuration $name -IsCore:$false

        New-PrtgPackage -Configuration $name -IsCore:$false
    }
}