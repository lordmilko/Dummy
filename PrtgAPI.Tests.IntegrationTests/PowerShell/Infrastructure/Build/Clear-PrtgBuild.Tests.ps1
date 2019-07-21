ipmo $PSScriptRoot\..\..\..\..\Tools\PrtgAPI.Build
ipmo $PSScriptRoot\..\..\..\..\Tools\CI\ci.psm1

$testCases = @(
    @{name = "Debug"}
    @{name = "Release"}
)

Describe "Clear-PrtgBuild_IT" -Tag @("PowerShell", "Build_IT") {
    It "clears the last build on core for <name>" -TestCases $testCases {

        param($name)

        Clear-PrtgBuild -Full

        Invoke-PrtgBuild -Configuration $name

        Clear-PrtgBuild -Configuration $name
    }

    It "clears the last build on desktop for <name>" -TestCases $testCases -Skip:(!(Test-IsWindows)) {

        param($name)

        Clear-PrtgBuild -Full

        Invoke-PrtgBuild -Configuration $name -IsCore:$false

        Clear-PrtgBuild -Configuration $name -IsCore:$false
    }

    It "clears all files" {
        Clear-PrtgBuild -Full

        Invoke-PrtgBuild

        Clear-PrtgBuild -Full
    }
}