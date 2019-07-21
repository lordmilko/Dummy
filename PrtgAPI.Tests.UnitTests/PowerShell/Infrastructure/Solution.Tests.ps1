Describe "Solution" -Tag @("PowerShell", "UnitTest") {

    if(!(Get-Module -ListAvailable PSScriptAnalyzer))
    {
        Install-Package PSScriptAnalyzer -ProviderName PowerShellGet -ForceBootstrap -Force | Out-Null
    }

    It "doesn't use 'sort' alias" {
        $solution = Resolve-Path "$PSScriptRoot\..\..\..\"

        $violations = Invoke-ScriptAnalyzer $solution -IncludeRule PSAvoidUsingCmdletAliases -Recurse

        $sortViolations = $violations | where { $_.Extent.Text -eq "sort" }

        if($sortViolations)
        {
            $str = ($sortViolations|select -expand ScriptName) -join ", "

            throw "Found illegal usages of 'sort' in the following scripts: $str"
        }
    }
}