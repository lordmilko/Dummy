. $PSScriptRoot\..\..\..\Support\PowerShell\Build.ps1

Describe "Clear-PrtgBuild" -Tag @("PowerShell", "Build") {

    $solutionRoot = Get-SolutionRoot

    It "clears core" {

        Mock-InstallDotnet -Windows

        <#Mock-InvokeProcess "dotnet clean `"$(Join-PathEx $solutionRoot PrtgAPIv17.sln)`" -c Debug" {
            Clear-PrtgBuild
        }#>
    }
}