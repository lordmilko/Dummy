function Invoke-TravisTest
{
    Write-LogHeader "Executing tests"

    <#$result = Invoke-CIPowerShellTest $env:TRAVIS_BUILD_DIR (@{ExcludeTag = "Build"}) -IsCore:$true

    if($result.FailedCount -gt 0)
    {
        throw "$($result.FailedCount) Pester tests failed"
    }

    $csharpArgs = @(
        "--filter"
        "TestCategory!=SkipCI"
    )#>

    Invoke-CICSharpTest $env:TRAVIS_BUILD_DIR $csharpArgs $env:CONFIGURATION -IsCore:$true
}