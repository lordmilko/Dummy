function Invoke-TravisTest
{
    Write-LogHeader "Executing tests"

    Invoke-CIPowerShellTest $env:TRAVIS_BUILD_DIR (@{ExcludeTag = "Build"}) -IsCore:$true | Out-Null
    Invoke-CICSharpTest $env:TRAVIS_BUILD_DIR $null $env:CONFIGURATION -IsCore:$true
}