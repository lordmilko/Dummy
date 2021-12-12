function Simulate-GitHub
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Configuration = "Debug"
    )

    InitializeEnvironment $Configuration

    Clear-GitHubBuild

    Invoke-GitHubInstall
    Invoke-GitHubScript
}

function InitializeEnvironment($configuration)
{
    $env:CONFIGURATION = $configuration
    $env:GITHUB_WORKSPACE = $script:SolutionDir
}