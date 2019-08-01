. $PSScriptRoot\..\..\..\..\PrtgAPI.Tests.UnitTests\Support\PowerShell\BuildCore.ps1

$testCases = @(
    @{name = "Debug"}
    @{name = "Release"}
)

Describe "Simulate-PrtgCI_IT" -Tag @("PowerShell", "Build_IT") {

    $path = Resolve-Path "$PSScriptRoot\..\..\..\..\PrtgAPI.Tests.UnitTests\Support\PowerShell\Build.ps1"

    $exe = "pwsh"

    if((Test-IsWindows) -and $PSEdition -ne "Core")
    {
        $exe = "powershell"
    }

    It "simulates Appveyor on core" -Skip:(SkipBuildTest) {

        if(Test-IsWindows)
        {
            & $exe -NonInteractive -Command ". '$path'; Simulate-PrtgCI -Configuration Release" | Write-Host

            if($LASTEXITCODE -ne 0)
            {
                throw "Invocation failed. Check PrtgAPI.Build.log for details"
            }
        }
        else
        {
            { Simulate-PrtgCI -Configuration Release } | Should Throw "Appveyor can only be simulated on Windows"
        }
    }

    It "simulates Appveyor on desktop for <name>" -TestCases $testCases -Skip:(!(Test-IsWindows) -or (SkipBuildTest)) {
        param($name)

        & $exe  -NonInteractive -Command ". '$path'; Simulate-PrtgCI -Configuration $name -IsCore:`$false" | Write-Host

        if($LASTEXITCODE -ne 0)
        {
            throw "Invocation failed. Check PrtgAPI.Build.log for details"
        }
    }

    It "simulates Travis" -Skip:(SkipBuildTest) {

        pwsh -NonInteractive -Command ". '$path'; Simulate-PrtgCI -Travis -Configuration Release" | Write-Host

        if($LASTEXITCODE -ne 0)
        {
            throw "Invocation failed. Check PrtgAPI.Build.log for details"
        }
    }
}