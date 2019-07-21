. $PSScriptRoot\..\..\..\Support\PowerShell\Build.ps1

function MockInvokePester($action)
{
    InModuleScope CI {
        Mock Invoke-Pester {

            $root = Get-SolutionRoot

            $ExcludeTag | Should Be "Build"
            $PassThru | Should be $true
            $OutputFile | Should BeLike (Join-Path $root "PrtgAPI.Tests.UnitTests\TestResults\PrtgAPI_PowerShell_*.xml")
            $OutputFormat | Should Be "NUnitXml"
            $Script | Should Be (Join-Path $root "PrtgAPI.Tests.UnitTests\PowerShell")

        } -Verifiable
    }

    & $action

    Assert-VerifiableMocks
}

Describe "Invoke-PrtgTest" -Tag @("PowerShell", "Build") {

    It "executes C# with core" {

        Mock-InstallDotnet -Windows

        $solutionRoot = Get-SolutionRoot

        $expected = @(
            "& `"dotnet`""
            "test"
            "$solutionRoot\PrtgAPI.Tests.UnitTests\PrtgAPIv17.Tests.UnitTests.csproj"
            "-nologo"
            "--no-restore"
            "--no-build"
            "--verbosity:n"
            "-c"
            "Debug"
            "--logger"
            "trx;LogFileName=PrtgAPI_C#.trx"
            "--filter"
            "FullyQualifiedName~dynamic"
        )

        Mock-InvokeProcess $expected {
            Invoke-PrtgTest *dynamic* -Type C#
        }
    }

    It "executes C# with desktop" {

        Mock Get-VSTest {
            return "C:\vstest.console.exe"
        } -ModuleName CI

        $solutionRoot = Get-SolutionRoot

        $expected = @(
            "& C:\vstest.console.exe"
            "$solutionRoot\PrtgAPI.Tests.UnitTests\bin\Debug\PrtgAPI.Tests.UnitTests.dll"
            "/logger:trx;LogFileName=PrtgAPI_C#.trx"
            "/TestCaseFilter:FullyQualifiedName~dynamic"
        )

        Mock-InvokeProcess $expected {
            Invoke-PrtgTest *dynamic* -Type C# -IsCore:$false
        }
    }

    It "executes PowerShell with core" {

        MockInvokePester {
            Invoke-PrtgTest -Type PowerShell
        }
    }

    It "executes PowerShell with desktop" {
        MockInvokePester {
            Invoke-PrtgTest -Type PowerShell -IsCore:$false
        }
    }

    It "executes with Release build" {
        $solutionRoot = Get-SolutionRoot

        $expected = @(
            "& `"dotnet`""
            "test"
            "$solutionRoot\PrtgAPI.Tests.UnitTests\PrtgAPIv17.Tests.UnitTests.csproj"
            "-nologo"
            "--no-restore"
            "--no-build"
            "--verbosity:n"
            "-c"
            "Release"
            "--logger"
            "trx;LogFileName=PrtgAPI_C#.trx"
            "--filter"
            "FullyQualifiedName~dynamic"
        )

        Mock-InvokeProcess $expected {
            Invoke-PrtgTest *dynamic* -Type C# -c Release
        }
    }

    It "specifies multiple C# limits" {
        $solutionRoot = Get-SolutionRoot

        $expected = @(
            "& `"dotnet`""
            "test"
            "$solutionRoot\PrtgAPI.Tests.UnitTests\PrtgAPIv17.Tests.UnitTests.csproj"
            "-nologo"
            "--no-restore"
            "--no-build"
            "--verbosity:n"
            "-c"
            "Debug"
            "--logger"
            "trx;LogFileName=PrtgAPI_C#.trx"
            "--filter"
            "FullyQualifiedName~dynamic|FullyQualifiedName~potato"
        )

        Mock-InvokeProcess $expected {
            Invoke-PrtgTest *dynamic*,*potato* -Type C#
        }
    }

    It "specifies multiple PowerShell limits" {

        InModuleScope CI {
            Mock Invoke-Pester {

                param($TestName)

                $TestName -join "," | Should Be "*dynamic*,*potato*"
            }
        }

        Invoke-PrtgTest *dynamic*,*potato* -Type PowerShell
    }

    It "executes c# integration tests" {
        
        $solutionRoot = Get-SolutionRoot
        
        $expected = @(
            "& `"dotnet`""
            "test"
            "$solutionRoot\PrtgAPI.Tests.IntegrationTests\PrtgAPIv17.Tests.IntegrationTests.csproj"
            "-nologo"
            "--no-restore"
            "--no-build"
            "--verbosity:n"
            "-c"
            "Debug"
            "--logger"
            "trx;LogFileName=PrtgAPI_C#.trx"
            "--filter"
            "FullyQualifiedName~dynamic"
        )

        Mock-InvokeProcess $expected {
            Invoke-PrtgTest *dynamic* -Type C# -Integration
        }
    }
}