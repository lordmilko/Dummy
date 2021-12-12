function Clear-GitHubBuild
{
    [CmdletBinding()]
    param(
        [switch]$NuGetOnly
    )

    $clearArgs = @{
        BuildFolder = $env:GITHUB_WORKSPACE
        Configuration = $env:CONFIGURATION
        IsCore = $true
        NuGetOnly = $NuGetOnly
    }

    Clear-CIBuild @clearArgs
}