. $PSScriptRoot\..\..\..\Support\PowerShell\Build.ps1

function GetPowerShellCommand
{
    Mock Get-VSTest {
        return "C:\vstest.console.exe"
    } -ModuleName CI

    $temp = [IO.Path]::GetTempPath()

    $root = Get-SolutionRoot

    $expected = @(
        "&"
        "`"C:\ProgramData\chocolatey\bin\OpenCover.Console.exe`""
        "-target:C:\vstest.console.exe"
        "-targetargs:<regex>.+?</regex>"
        "/TestAdapterPath:\`"$root\Tools\PowerShell.TestAdapter\bin\Release\netstandard2.0\`""
        "-output:`"$($temp)opencover.xml`""
        "-filter:+`"[PrtgAPI*]* -[PrtgAPI.Tests*]*`""
        "-excludebyattribute:System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute"
        "-hideskipped:attribute"
        "-register"
    )

    return $expected
}

function GetCSharpCoreCommand($configuration = "Debug")
{
    $dotnet = (gcm dotnet).Source

    ( $dotnet | Should Not BeNullOrEmpty ) | Out-Null

    $temp = [IO.Path]::GetTempPath()

    $root = Get-SolutionRoot

    return @(
        "&"
        "`"C:\ProgramData\chocolatey\bin\OpenCover.Console.exe`""
        "-target:$dotnet"
        "-targetargs:test --filter TestCategory!=SlowCoverage&TestCategory!=SkipCI `"$root\PrtgAPI.Tests.UnitTests\PrtgAPIv17.Tests.UnitTests.csproj`" --verbosity:n --no-build -c $configuration"
        "-output:`"$($temp)opencover.xml`""
        "-filter:+`"[PrtgAPI*]* -[PrtgAPI.Tests*]*`""
        "-excludebyattribute:System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute"
        "-hideskipped:attribute"
        "-register"
        "-mergeoutput"
        "-oldstyle"
    )
}

function GetCSharpFullCommand($configuration = "Debug")
{
    Mock Get-VSTest {
        return "C:\vstest.console.exe"
    } -ModuleName CI

    $root = Get-SolutionRoot
    $temp = [IO.Path]::GetTempPath()

    $expected = @(
        "`"C:\ProgramData\chocolatey\bin\OpenCover.Console.exe`""
        "-target:C:\vstest.console.exe"
        "-targetargs:/TestCaseFilter:TestCategory!=SlowCoverage&TestCategory!=SkipCI \`"$root\PrtgAPI.Tests.UnitTests\bin\$configuration\PrtgAPI.Tests.UnitTests.dll\`""
        "-output:`"$($temp)opencover.xml`""
        "-filter:+`"[PrtgAPI*]* -[PrtgAPI.Tests*]*`""
        "-excludebyattribute:System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute"
        "-hideskipped:attribute"
        "-register:path32"
        "-mergeoutput"
    )

    return $expected
}

function GetReportCommands
{
    $temp = [IO.Path]::GetTempPath()

    $expected1 = @(
        "&"
        "C:\ProgramData\chocolatey\bin\reportgenerator.exe"
        "-reports:$($temp)opencover.xml"
        "-reporttypes:Html"
        "-targetdir:$($temp)PrtgCoverage_<regex>\d\d\d\d-\d\d-\d\d_\d\d-\d\d-\d\d</regex>"
        "-verbosity:off"
    )

    $expected2 = @(
        "$($temp)PrtgCoverage_<regex>\d\d\d\d-\d\d-\d\d_\d\d-\d\d-\d\d</regex>\index.htm"
    )

    return $expected1,$expected2
}

function MockCore
{
    InModuleScope "CI" {
        Mock "Get-ChildItem" {
            param(
                $Path,
                $Filter
            )

            if($Filter -eq "PrtgAPI.Tests.UnitTests.dll")
            {
                return [System.IO.FileInfo]"$Path\bin\$env:CONFIGURATION\net461\PrtgAPI.Tests.UnitTests.dll"
            }

            throw "path and filter were $Path and $Filter"
        } -ParameterFilter { $Filter -ne "*.Tests.ps1" }

        Mock "Test-Path" {
            return $true
        } -ParameterFilter { $Path -notlike "*dotnet*" }

        Mock "Remove-Item" {}

        MockGetChocolateyCommand
    }
}

function MockDesktop
{
    InModuleScope "CI" {
        Mock "Get-ChildItem" {
            param(
                $Path,
                $Filter
            )

            if($Filter -eq "PrtgAPI.Tests.UnitTests.dll")
            {
                return [System.IO.FileInfo]"$Path\bin\$env:CONFIGURATION\PrtgAPI.Tests.UnitTests.dll"
            }

            throw "path and filter were $Path and $Filter"
        } -ParameterFilter { $Filter -ne "*.Tests.ps1" }

        Mock "Test-Path" {
            return $true
        } -ParameterFilter { $Path -notlike "*dotnet*" }

        Mock "Remove-Item" {}
    }
}

Describe "Get-PrtgCoverage" -Tag @("PowerShell", "Build") {

    It "executes with core" {

        Mock-InstallDotnet -Windows
        MockCore

        $expected1 = GetPowerShellCommand
        $expected2 = GetCSharpCoreCommand
        $expected3 = GetReportCommands

        $expected = ,$expected1 + ,$expected2 + $expected3

        Mock-AllProcess $expected {
            Get-PrtgCoverage
        }
    }

    It "executes with desktop" {

        MockDesktop

        $expected1 = GetPowerShellCommand
        $expected2 = GetCSharpFullCommand
        $expected3 = GetReportCommands

        $expected = ,$expected1 + ,$expected2 + $expected3

        Mock-AllProcess $expected {
            Get-PrtgCoverage -IsCore:$false
        }
    }

    It "calculates C# coverage only" {

        MockCore

        $expected1 = GetCSharpCoreCommand
        $expected2 = GetReportCommands

        $expected = ,$expected1 + $expected2

        Mock-AllProcess $expected {
            Get-PrtgCoverage -Type C#
        }
    }

    It "calculates PowerShell coverage only" {

        MockCore

        $expected1 = GetPowerShellCommand
        $expected2 = GetReportCommands

        $expected = ,$expected1 + $expected2

        Mock-AllProcess $expected {
            Get-PrtgCoverage -Type PowerShell
        }
    }

    It "filters to specific C# tests" {

        MockCore

        $dotnet = (gcm dotnet).Source
        $temp = [IO.Path]::GetTempPath()
        $root = Get-SolutionRoot

        $expected1 = @(
            "&"
            "`"C:\ProgramData\chocolatey\bin\OpenCover.Console.exe`""
            "-target:$dotnet"
            "-targetargs:test --filter TestCategory!=SlowCoverage&TestCategory!=SkipCI&FullyQualifiedName~dynamic `"$root\PrtgAPI.Tests.UnitTests\PrtgAPIv17.Tests.UnitTests.csproj`" --verbosity:n --no-build -c Debug"
            "-output:`"$($temp)opencover.xml`""
            "-filter:+`"[PrtgAPI*]* -[PrtgAPI.Tests*]*`""
            "-excludebyattribute:System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute"
            "-hideskipped:attribute"
            "-register"
            "-mergeoutput"
            "-oldstyle"
        )

        $expected2 = GetReportCommands

        $expected = ,$expected1 + $expected2

        Mock-AllProcess $expected {
            Get-PrtgCoverage *dynamic* -Type C#
        }
    }

    It "filters to specific PowerShell tests" {
        MockDesktop

        Mock Get-VSTest {
            return "C:\vstest.console.exe"
        } -ModuleName CI

        $temp = [IO.Path]::GetTempPath()
        $root = Get-SolutionRoot

        $expected1 = @(
            "&"
            "`"C:\ProgramData\chocolatey\bin\OpenCover.Console.exe`""
            "-target:C:\vstest.console.exe"
            "-targetargs:\`"$root\PrtgAPI.Tests.UnitTests\PowerShell\ObjectManipulation\New-SensorParameters.Tests.ps1\`""
            "/TestAdapterPath:\`"$root\Tools\PowerShell.TestAdapter\bin\Release\netstandard2.0\`""
            "-output:`"$($temp)opencover.xml`""
            "-filter:+`"[PrtgAPI*]* -[PrtgAPI.Tests*]*`""
            "-excludebyattribute:System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute"
            "-hideskipped:attribute"
            "-register"
        )

        $expected2 = GetReportCommands

        $expected = ,$expected1 + $expected2

        Mock-AllProcess $expected {
            Get-PrtgCoverage *SensorParameters* -Type PowerShell
        }
    }

    It "executes with Release build on core" {
        MockCore

        $expected1 = GetPowerShellCommand
        $expected2 = GetCSharpCoreCommand "Release"
        $expected3 = GetReportCommands

        $expected = ,$expected1 + ,$expected2 + $expected3

        Mock-AllProcess $expected {
            Get-PrtgCoverage -Configuration "Release"
        }
    }

    It "executes with Release build on desktop" {
        MockDesktop

        $expected1 = GetPowerShellCommand
        $expected2 = GetCSharpFullCommand "Release"
        $expected3 = GetReportCommands

        $expected = ,$expected1 + ,$expected2 + $expected3

        Mock-AllProcess $expected {
            Get-PrtgCoverage -IsCore:$false -Configuration "Release"
        }
    }

    It "throws when not running on Windows" {
        InModuleScope "CI" {
            Mock "Test-CIIsWindows" {
                return $false
            }
        }

        { Get-PrtgCoverage } | Should Throw "Code coverage is only supported on Windows"
    }
}