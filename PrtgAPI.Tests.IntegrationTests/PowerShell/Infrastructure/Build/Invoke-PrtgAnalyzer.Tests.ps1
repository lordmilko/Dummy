ipmo $PSScriptRoot\..\..\..\..\Tools\PrtgAPI.Build

Describe "Invoke-PrtgAnalyzer_IT" -Tag @("PowerShell", "Build_IT") {
    It "analyzes solution" {
        Invoke-PrtgAnalyzer
    }
}