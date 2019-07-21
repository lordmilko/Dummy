<#
.SYNOPSIS
Executes tests on a PrtgAPI build.

.DESCRIPTION
The Invoke-PrtgTest cmdlet executes tests on previously generated builds of PrtgAPI. By default
both C# and PowerShell tests will be executed against the last Debug build. Tests can be limited
to a specific platform by specifying a value to the -Type parameter, and can also be limited to
those whose name matches a specified wildcard expression via the -Name parameter.

Tests executed by Invoke-PrtgTest are automatically logged in the TRX format (C#) and NUnitXml
format (PowerShell) under the PrtgAPI.Tests.UnitTests\TestResults folder of the PrtgAPI solution.
Test results in this directory can be evaluated and filtered after the fact using the Get-PrtgTestResult
cmdlet. Note that upon compiling a new build of PrtgAPI.Tests.UnitTests, all items in this test results
folder will automatically be deleted.

.PARAMETER Name
Wildcard used to specify tests to execute. If no value is specified, all tests will be executed.

.PARAMETER Type
Type of tests to execute. If no value is specified, both C# and PowerShell tests will be executed.

.PARAMETER IsCore
Specifies whether to test PrtgAPI using the .NET Core CLI.

.PARAMETER Configuration
Build configuration to test. If no value is specified, the last Debug build will be tested.

.PARAMETER Integration
Specifies to run integration tests instead of unit tests.

.EXAMPLE
C:\> Invoke-PrtgTest
Executes all unit tests on the last PrtgAPI build.

.EXAMPLE
C:\> Invoke-PrtgTest *dynamic*
Executes all tests whose name contains the word "dynamic".

.EXAMPLE
C:\> Invoke-PrtgTest -Type PowerShell
Executes all PowerShell tests only.

.EXAMPLE
C:\> Invoke-PrtgTest -Configuration Release
Executes tests on the Release build of PrtgAPI.

C:\> Invoke-PrtgTest -Integration
Invoke all integration tests on the last PrtgAPI build.

.LINK
Invoke-PrtgBuild
Get-PrtgTestResult
#>
function Invoke-PrtgTest
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string[]]$Name,

        [Parameter(Mandatory = $false)]
        [ValidateSet('C#', 'PowerShell', 'All')]
        [string[]]$Type = "All",

        [Parameter(Mandatory = $false)]
        [switch]$IsCore = $true,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Debug", "Release")]
        [string]$Configuration = "Debug",

        [Parameter(Mandatory = $false)]
        [switch]$Integration
    )

    $testArgs = @{
        Name = $Name
        Type = $Type
        IsCore = $IsCore
        Configuration = $Configuration
        Integration = $Integration
    }

    InvokeCSharpTest @testArgs
    InvokePowerShellTest @testArgs
}

function InvokeCSharpTest($name, $type, $isCore, $configuration, $integration)
{
    if("All" -in $type -or "C#" -in $type)
    {
        $additionalArgs = @()

        $additionalArgs += GetLoggerArgs $isCore
        $additionalArgs += GetLoggerFilters $name $isCore

        $testArgs = @{
            BuildFolder = Get-SolutionRoot
            AdditionalArgs = $additionalArgs
            Configuration = $configuration
            IsCore = $isCore
            Integration = $integration
        }

        Invoke-CICSharpTest @testArgs -Verbose
    }
}

function InvokePowerShellTest($name, $type, $isCore, $configuration, $integration)
{
    if("All" -in $type -or "PowerShell" -in $type)
    {
        $projectDir = Join-Path (Get-SolutionRoot) (Get-TestProject $isCore $integration).Directory
        $testResultsDir = Join-Path $projectDir "TestResults"

        if(!(Test-Path $testResultsDir))
        {
            New-Item $testResultsDir -ItemType Directory | Out-Null
        }

        $dateTime = (get-date).tostring("yyyy-MM-dd_HH-mm-ss-fff")

        $additionalArgs = @{
            OutputFile = "$testResultsDir\PrtgAPI_PowerShell_$dateTime.xml"
            OutputFormat = "NUnitXml"
        }

        if($name -ne $null)
        {
            $additionalArgs.TestName = $name
        }

        $testArgs = @{
            BuildFolder = Get-SolutionRoot
            AdditionalArgs = $additionalArgs
            IsCore = $isCore
            Integration = $integration
        }

        Invoke-CIPowerShellTest @testArgs | Out-Null
    }
}

function GetLoggerArgs($IsCore)
{
    $loggerTarget = "trx;LogFileName=PrtgAPI_C#.trx"

    if($IsCore)
    {
        return @(
            "--logger"
            $loggerTarget
        )
    }
    else
    {
        return "/logger:$loggerTarget"
    }
}

function GetLoggerFilters($name, $IsCore)
{
    if($name -ne $null -and $name -ne "")
    {
        $filter = ($name | foreach { "FullyQualifiedName~$($_.Trim('*'))" }) -join "|"

        if($IsCore)
        {
            return @(
                "--filter"
                $filter
            )
        }
        else
        {
            return "/TestCaseFilter:$filter"
        }
    }
}