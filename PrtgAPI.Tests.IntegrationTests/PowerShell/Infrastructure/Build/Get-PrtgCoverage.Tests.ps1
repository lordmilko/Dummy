. $PSScriptRoot\..\..\..\..\PrtgAPI.Tests.UnitTests\Support\PowerShell\BuildCore.ps1

$testCases = @(
    @{name = "Debug"}
    @{name = "Release"}
)

Describe "Get-PrtgCoverage_IT" -Tag @("PowerShell", "Build_IT") {
    It "gets coverage on core" -Skip:(SkipBuildTest) {

        Clear-PrtgBuild -Full

        Invoke-PrtgBuild -Configuration Release

        if(Test-IsWindows)
        {
            Get-PrtgCoverage -Configuration Release -SkipReport
        }
        else
        {
            { Get-PrtgCoverage -Configuration Release -SkipReport } | Should Throw "Code coverage is only supported on Windows"
        }
    }

    It "gets coverage on desktop" -TestCases $testCases -Skip:(!(Test-IsWindows) -or (SkipBuildTest)) {

        param($name)

        Clear-PrtgBuild -Full

        Invoke-PrtgBuild -Configuration $name -IsCore:$false

        Get-PrtgCoverage -Configuration $name -IsCore:$false -SkipReport
    }
}