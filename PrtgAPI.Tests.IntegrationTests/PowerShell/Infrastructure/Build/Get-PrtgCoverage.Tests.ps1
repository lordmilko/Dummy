ipmo $PSScriptRoot\..\..\..\..\Tools\PrtgAPI.Build
ipmo $PSScriptRoot\..\..\..\..\Tools\CI\ci.psm1

$testCases = @(
    @{name = "Debug"}
    @{name = "Release"}
)

Describe "Get-PrtgCoverage_IT" -Tag @("PowerShell", "Build_IT") {
    It "gets coverage on core" {

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

    It "gets coverage on desktop" -TestCases $testCases -Skip:(!(Test-IsWindows)) {

        param($name)

        Clear-PrtgBuild -Full

        Invoke-PrtgBuild -Configuration $name -IsCore:$false

        Get-PrtgCoverage -Configuration $name -IsCore:$false -SkipReport
    }
}