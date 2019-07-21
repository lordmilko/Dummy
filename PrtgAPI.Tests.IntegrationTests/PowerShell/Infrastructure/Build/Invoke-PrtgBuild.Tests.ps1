ipmo $PSScriptRoot\..\..\..\..\Tools\PrtgAPI.Build
ipmo $PSScriptRoot\..\..\..\..\Tools\CI\ci.psm1

$testCases = @(
    @{name = "Debug"}
    @{name = "Release"}
)

Describe "Invoke-PrtgBuild_IT" -Tag @("PowerShell", "Build_IT") {
    
    It "builds on core for <name>" -TestCases $testCases {

        param($name)

        Clear-PrtgBuild -Full

        Invoke-PrtgBuild -Configuration $name
    }
    
    It "builds on desktop for <name>" -TestCases $testCases -Skip:(!(Test-IsWindows)) {

        param($name)

        Clear-PrtgBuild -Full

        Invoke-PrtgBuild -Configuration $name -IsCore:$false
    }
}