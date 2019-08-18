. $PSScriptRoot\..\..\..\Support\PowerShell\Build.ps1

Describe "Clear-PrtgBuild" -Tag @("PowerShell", "Build") {

    It "clears core" {

        Mock Invoke-CIProcess {
            Write-Host "called"
        } -ModuleName CI

        <#Mock-InvokeProcess "dotnet clean `"$(Join-PathEx $solutionRoot PrtgAPIv17.sln)`" -c Debug" {
            Clear-PrtgBuild
        }#>
    }
}