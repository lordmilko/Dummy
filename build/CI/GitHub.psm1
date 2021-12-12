ipmo $PSScriptRoot\ci.psm1 -Scope Local

$script:SolutionDir = $script:SolutionDir = Get-SolutionRoot

. $PSScriptRoot\Helpers\Import-ModuleFunctions.ps1
. Import-ModuleFunctions "$PSScriptRoot\GitHub"

$env:CONFIGURATION = "Release"

if($env:GITHUB_WORKFLOW)
{
    # No need to show progress bars when actually running under GitHub Actions
    $global:ProgressPreference = "SilentlyContinue"
}