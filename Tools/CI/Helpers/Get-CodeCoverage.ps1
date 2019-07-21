﻿. $PSScriptRoot\..\..\..\PrtgAPI.Tests.UnitTests\Support\PowerShell\Init.ps1

function Get-CodeCoverage
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name = "*",

        [Parameter()]
        [string]$BuildFolder = $env:APPVEYOR_BUILD_FOLDER,

        [Parameter()]
        [string[]]$Type = "All",

        [Parameter()]
        [string]$Configuration = "Debug",

        [Parameter()]
        [switch]$TestOnly,

        [Parameter()]
        [switch]$IsCore
    )

    $coverage = [CodeCoverage]::new($Name, $BuildFolder, $Type, $Configuration, $TestOnly, $IsCore)

    $coverage.GetCoverage()
}

class CodeCoverage
{
    static [string]$OpenCover
    static [string]$Temp
    static [string]$PowerShellAdapter
    static [string]$OpenCoverOutput
    static [string]$PowerShellAdapterDownload

    [string]$Name
    [string]$BuildFolder
    [string[]]$Type
    [string]$Configuration
    [switch]$TestOnly
    [switch]$IsCore

    static CodeCoverage()
    {
        [CodeCoverage]::OpenCover = Get-ChocolateyCommand "OpenCover.Console.exe"
        [CodeCoverage]::Temp = [IO.Path]::GetTempPath()
        [CodeCoverage]::OpenCoverOutput = Join-Path ([CodeCoverage]::Temp) "opencover.xml"
    }

    CodeCoverage($name, $buildFolder, $type, $configuration, $testOnly, $isCore)
    {
        $this.Name = $name
        $this.BuildFolder = $buildFolder
        $this.Type = $type
        $this.Configuration = $configuration
        $this.TestOnly = $testOnly
        $this.IsCore = $isCore
    }

    [void]GetCoverage()
    {
        Install-CIDependency OpenCover

        Write-Host "$(& $([CodeCoverage]::OpenCover) -version)"

        $this.ClearCoverage()

        $this.GetPowerShellCoverage()
        $this.GetCSharpCoverage()
    }

    #region C#

    [void]GetCSharpCoverage()
    {
        if(!$this.RequireCSharpCoverage())
        {
            return
        }

        $testRunner = $this.GetCSharpTestRunner()
        $testParams = $this.GetCSharpTestParams()

        if($this.TestOnly)
        {
            Write-LogInfo "`t`tExecuting $testRunner $testParams"
            Invoke-Process { & $testRunner @testParams } -WriteHost
        }
        else
        {
            $opencoverParams = $this.GetCSharpOpenCoverParams($testRunner, $testParams)

            Write-LogInfo "`t`tExecuting '$([CodeCoverage]::OpenCover) $opencoverParams'"
            Invoke-Process { & ([CodeCoverage]::OpenCover) @opencoverParams } -WriteHost
        }
    }

    [string]GetCSharpTestRunner()
    {
        if($this.IsCore)
        {
            Install-CIDependency dotnet

            return (gcm dotnet).Source
        }
        else
        {
            return Get-VSTest
        }
    }

    [object]GetCSharpTestParams()
    {
        $nameFilter = $null

        $trimmedName = $this.name.Trim('*')

        if(![string]::IsNullOrEmpty($trimmedName))
        {
            $nameFilter = "&FullyQualifiedName~$trimmedName"
        }

        $filter = "TestCategory!=SlowCoverage&TestCategory!=SkipCI$nameFilter"

        $testParams = @()

        if($this.IsCore)
        {
            $testParams = @(
                "test"
                "--filter"
                $filter
                "`"$($this.BuildFolder)PrtgAPI.Tests.UnitTests\PrtgAPIv17.Tests.UnitTests.csproj`""
                "--verbosity:n"
                "--no-build"
                "-c"
                $this.Configuration
            )
        }
        else
        {
            $testParams = @(
                "/TestCaseFilter:$filter"
                "\`"$($this.BuildFolder)PrtgAPI.Tests.UnitTests\bin\$($this.Configuration)\PrtgAPI.Tests.UnitTests.dll\`""
            )
        }

        if($this.TestOnly)
        {
            # Replace the cmd escaped quotes with PowerShell escaped quotes, and then add an additional quote at the end of the TestCaseFilter to separate the arguments.
            # Trim any quotes from the end of the string, since PowerShell will add its own quote for us
            $testParams = $testParams | foreach {
                ($_ -replace "\\`"","`" `"").Trim("`" `"")
            }
        }

        return $testParams
    }

    [object]GetCSharpOpenCoverParams($testRunner, $testParams)
    {
        $opencoverParams = $this.GetCommonOpenCoverParams($testRunner, $testParams)

        $opencoverParams += "-mergeoutput"

        if($this.IsCore)
        {
            $opencoverParams += "-oldstyle"
        }

        return $opencoverParams
    }

    [bool]RequireCSharpCoverage()
    {
        return "All" -in $this.Type -or "C#" -in $this.Type
    }

    #endregion
    #region PowerShell

    [void]GetPowerShellCoverage()
    {
        if(!$this.RequirePowerShellCoverage())
        {
            return
        }

        $tests = $this.GetPowerShellTests()

        if($tests.Count -eq 0)
        {
            Write-LogInfo "`t`tNo tests matched the specified name '$($this.Name)'; skipping PowerShell coverage"
            return
        }

        $this.AssertHasPowerShellDll()

        Write-LogInfo "going to check for test runner"

        $testRunner = $this.GetPowerShellTestRunner()

        Write-LogInfo "going to do stuff with test params"

        $testParams = $this.GetPowerShellTestParams($tests)

        if($this.TestOnly)
        {
            Write-LogInfo "`t`tExecuting $testRunner $testParams"
            Invoke-Process { & $testRunner @testParams } -WriteHost
        }
        else
        {
            $opencoverParams = $this.GetPowerShellOpenCoverParams($testRunner, $testParams)

            Write-LogInfo "`t`tExecuting $([CodeCoverage]::OpenCover) $opencoverParams"
            Invoke-Process { & ([CodeCoverage]::OpenCover) @opencoverParams } -WriteHost
        }
    }

    [void]AssertHasPowerShellDll()
    {
        Write-LogInfo "checking has powershell dll"

        $candidates = @((AnalyzeTestProject "PrtgAPI.Tests.UnitTests" (Resolve-Path "$PSScriptRoot\..\..\..\PrtgAPI.Tests.UnitTests\Support\PowerShell").Path).Candidates)

        if(!($candidates|where Edition -EQ "Desktop"))
        {
            $str = "Found $($candidates.Count) build candidates"

            if($candidates.Count -gt 0)
            {
                $str += ": "

                $strs = $candidates | foreach {
                    "'$($_.FolderSuffix) ($($_.Edition))'"
                }

                $str += $strs -join ", "
            }

            throw "Cannot run PowerShell tests as test project has not been compiled for PowerShell Desktop. $str"
        }

        # As we run tests under vstest.console, we require a PowerShell Desktop DLL

        $dll = $candidates|where Edition -eq Desktop|select -first 1|select -ExpandProperty TestProjectDll

        if(!(Test-Path $dll))
        {
            throw "PrtgAPI for PowerShell Desktop is required to run PowerShell tests however '$dll' is missing. Has PrtgAPI been compiled?"
        }

        Write-LogInfo "finished checking has powershell dll"
    }

    [string]GetPowerShellTestRunner()
    {
        return Get-VSTest
    }

    [object]GetPowerShellTestParams($tests)
    {
        $this.InstallPowerShellAdapter()

        $testsStr = $tests -join " "
        $vstestParams = $null

        $testAdapterPath = Join-Path $this.BuildFolder "Tools\PowerShell.TestAdapter\bin\Release\netstandard2.0"

        $testParams = "/TestAdapterPath:\`"$testAdapterPath\`""

        if($this.TestOnly)
        {
            return @(
                $tests | foreach { $_ -replace "\\`"","`"" }
                $testParams -replace "\\`"","`""
            )
        }
        else
        {
            $testParams = "$testsStr $testParams"
        }

        return $testParams
    }

    [object]GetPowerShellTests()
    {
        $testRoot = Join-Path $this.BuildFolder "PrtgAPI.Tests.UnitTests\PowerShell"

        $tests = gci $testRoot -Recurse -Filter *.Tests.ps1 | where {
            # Blacklist Solution.Tests.ps1 as this invokes Invoke-PrtgAnalyzer which causes vstest.console to hang on completion
            # Also blacklist build tests as these do not pertain to the PrtgAPI assemblies
            $_.BaseName -like $this.Name -and $_.DirectoryName -notlike "*Infrastructure\Build*" -and $_.BaseName -ne "Solution.Tests"
        } | foreach {"\`"$($_.FullName)\`""}

        if($tests -eq $null -or $tests.Count -eq 0)
        {
            if($tests -eq $null)
            {
                $tests = @()
            }

            if($this.Name -eq "*")
            {
                throw "Couldn't find any PowerShell tests"
            }
        }
        else
        {
            Write-LogInfo "`t`tFound $($tests.Count) PowerShell tests"
        }

        return $tests
    }

    [object]GetPowerShellOpenCoverParams($testRunner, $testParams)
    {
        return $this.GetCommonOpenCoverParams($testRunner, $testParams)
    }

    [void]InstallPowerShellAdapter()
    {
        $adapterPath = Join-Path $this.BuildFolder "Tools\PowerShell.TestAdapter\bin\Release\netstandard2.0\PowerShell.TestAdapter.dll"

        if(!(Test-Path $adapterPath))
        {
            $csproj = Join-Path $this.BuildFolder "Tools\PowerShell.TestAdapter\PowerShell.TestAdapter.csproj"

            Write-Host $csproj

            Install-CIDependency dotnet

            Invoke-Process {
               dotnet build $csproj -c Release
            } -WriteHost
        }
    }

    [bool]RequirePowerShellCoverage()
    {
        return "All" -in $this.Type -or "PowerShell" -in $this.Type
    }

    #endregion
    #region OpenCover

    [void]ClearCoverage()
    {
        if(Test-Path ([CodeCoverage]::OpenCoverOutput))
        {
            Remove-Item ([CodeCoverage]::OpenCoverOutput) -Force
        }
    }

    [object]GetCommonOpenCoverParams($testRunner, $testParams)
    {
        $opencoverParams = @(
            "-target:$testRunner"
            "-targetargs:$testParams"
            "-output:`"$($([CodeCoverage]::OpenCoverOutput))`""
            "-filter:+`"[PrtgAPI*]* -[PrtgAPI.Tests*]*`""
            "-excludebyattribute:System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute"
            "-hideskipped:attribute"
        )

        if($this.IsCore)
        {
            $opencoverParams += "-register"
        }
        else
        {
            $opencoverParams += "-register:path32"
        }

        return $opencoverParams
    }

    #endregion
}

function New-CoverageReport
{
    [CmdletBinding()]
    param(
        [string]$Types = "Html",
        [string]$TargetDir = (Join-Path ([IO.Path]::GetTempPath()) "report")
    )

    Write-LogHeader "Generating a coverage report"

    Install-CIDependency ReportGenerator

    $reportParams = @(
        "-reports:$([CodeCoverage]::OpenCoverOutput)"
        "-reporttypes:$Types"
        "-targetdir:$TargetDir"
        "-verbosity:off"
    )

    $reportgenerator = Get-ChocolateyCommand "reportgenerator"

    Write-LogInfo "`t`tExecuting '$reportgenerator $reportParams'"
    Invoke-Process { & $reportgenerator @reportParams }
}

function Get-LineCoverage
{
    New-CoverageReport CsvSummary

    $csv = Import-Csv $env:temp\report\Summary.csv -Delimiter ';' -Header "Property","Value"

    $val = ($csv|where property -eq "Line coverage:"|select -expand value).Trim("%")

    return [double]$val
}

Export-ModuleMember New-CoverageReport,Get-LineCoverage