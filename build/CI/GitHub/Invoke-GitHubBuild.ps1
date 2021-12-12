function Invoke-GitHubBuild
{
    Write-LogHeader "Building PrtgAPI"

    Invoke-CIBuild $env:GITHUB_WORKSPACE -IsCore:$true
}