function Invoke-TravisTest
{
    Write-LogHeader "Executing tests"

    Invoke-CIPowerShellTest $env:TRAVIS_BUILD_DIR (@{ExcludeTag = "Build"}) -IsCore:$true | Out-Null

    $csharpArgs = @(
        "--filter"
        "TestCategory!=SkipCI"
    )

    Invoke-CICSharpTest $env:TRAVIS_BUILD_DIR $csharpArgs $env:CONFIGURATION -IsCore:$true
}