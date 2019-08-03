. $PSScriptRoot\BuildCore.ps1

function Describe
{
    param(
        [Parameter(Position = 0)]
        $Name,

        [Parameter(Position = 1)]
        $ScriptBlock,

        [Parameter(Mandatory = $false)]
        [string[]]$Tag
    )

    Pester\Describe $Name -Tag:$Tag {
        if(!$skipBuildModule)
        {
            Mock "Write-Log" {} -ModuleName "CI"
        }

        & $ScriptBlock
    }
}

function It
{
    [CmdletBinding(DefaultParameterSetName = 'Normal')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$name,

        [Parameter(Mandatory = $true, Position = 1)]
        [ScriptBlock] $script,

        [Parameter(Mandatory = $false)]
        [System.Collections.IDictionary[]] $TestCases,

        [Parameter(Mandatory = $false)]
        [switch]$Skip
    )

    Pester\It $name -TestCases $TestCases -Skip:$Skip {

        Write-LogInfo "Processing test '$name'"

        try
        {
            & $script @args
        }
        catch
        {
            Write-LogError "Error: $($_.Exception.Message)"

            throw
        }
        finally
        {
            #RemoveMocks
        }
    }
}

function RemoveMocks
{
    $pester = gmo pester

    if($pester.Version.Major -ne 3)
    {
        Write-Warning "Not removing It mocks as Pester is running $($pester.Version) instead of version 3"

        return
    }

    InModuleScope "Pester" {

        $currentScope = $pester.Scope

        $scriptBlock =
        {
            param (
                [string] $CommandName,
                [string] $Scope,
                [string] $Alias
            )
            $ExecutionContext.InvokeProvider.Item.Remove("Function:\$CommandName", $false, $true, $true)
            if ($ExecutionContext.InvokeProvider.Item.Exists("Function:\PesterIsMocking_$CommandName", $true, $true))
            {
                $ExecutionContext.InvokeProvider.Item.Rename([System.Management.Automation.WildcardPattern]::Escape("Function:\PesterIsMocking_$CommandName"), "$Scope$CommandName", $true)
            }

            if ($Alias -and $ExecutionContext.InvokeProvider.Item.Exists("Alias:$Alias", $true, $true))
            {
                $ExecutionContext.InvokeProvider.Item.Remove("Alias:$Alias", $false, $true, $true)
            }
        }

        $mockKeys = [string[]]$mockTable.Keys

        foreach ($mockKey in $mockKeys)
        {
            $mock = $mockTable[$mockKey]
            $mock.Blocks = @($mock.Blocks | & $SafeCommands['Where-Object'] {$_.Scope -ne $currentScope})

            $null = Invoke-InMockScope -SessionState $mock.SessionState -ScriptBlock $scriptBlock -ArgumentList $mock.CommandName, $mock.FunctionScope, $mock.Alias
            $mockTable.Remove($mockKey)
        }
    }
}

function global:EvaluateExpression($expr, $ie)
{
    # Get the full command (with arguments) that will be executed
    $trimmed = $expr.ToString().Trim()

    $str = $trimmed.TrimStart('&').Trim()

    $space = $str.IndexOf(' ')

    if($space -gt 0)
    {
        $command = $str.Substring(0, $space)
        $arguments = $str.Substring($space + 1) #todo: test a command that has no arguments
    }
    else
    {
        $command = $str
        $arguments = $null
    }

    $command = EscapeString $command 
    $arguments = EscapeString $arguments

    $command = & $ie "`"$command`""

    if($arguments.StartsWith("@"))
    {
        $table = & $ie $arguments

        $arguments = $table -join " "
    }
    else
    {
        $arguments = & $ie "`"$arguments`""
    }

    $result = $command

    if($arguments -ne $null)
    {
        $result += " $arguments"
    }

    if($trimmed.StartsWith("&"))
    {
        $result = "& $result"
    }

    return $result
}

function global:EscapeString($str)
{
    # Convert a command like "blahblah (Get-Stuff) blahblah" to ""blahblah" $(Get-Stuff) "blahblah""
    return $str -replace "(.*?)(\(.+?\))(.*?)",'$1"$$$2"$3' -replace "`"","```""
}

function Mock-AllProcess($expected, $scriptBlock) {
    InModuleScope PrtgAPI.Build {

        $mockBlock = Get-MockProcessScriptBlock

        Mock Start-Process $mockBlock -Verifiable
    }

    Mock-InvokeProcess $expected $scriptBlock  -Operator "Match"
}

function Mock-InvokeProcess
{
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        $Expected,

        [Parameter(Mandatory = $true, Position = 1)]
        $ScriptBlock,

        [Parameter(Mandatory = $false)]
        $Operator = "Be",

        [Parameter(Mandatory = $false)]
        $ModuleScope = "CI"
    )

    if(!($Expected[0] -is [array]))
    {
        # Create a multi dimensional array
        $Expected = ,@($Expected)
    }

    for($i = 0; $i -lt $Expected.Length; $i++)
    {
        if($Operator -eq "Match")
        {
            $escaped = [regex]::Escape($Expected[$i])

            $regexExpressions = [regex]::Matches($escaped, "<regex>.+?</regex>")

            foreach($match in $regexExpressions)
            {
                $escaped = $escaped.Replace($match.Value, [regex]::Unescape($match.Value))
            }

            $escaped = $escaped -replace "<regex>","" -replace "</regex>",""

            $Expected[$i] = $escaped.Replace("/", "\/")
        }
    }

    $global:expected = $Expected
    $global:expectedIndex = 0
    $global:operator = $Operator

    InModuleScope $ModuleScope {

        $mockBlock = Get-MockProcessScriptBlock

        Mock Invoke-Process $mockBlock -Verifiable
    }

    & $ScriptBlock

    Assert-VerifiableMocks
}

function global:Get-MockProcessScriptBlock
{
    $mockBlock = {

        $result = EvaluateExpression $args[1] {
            param($v)

            if($v.StartsWith("@"))
            {
                $value = Get-Variable $v.TrimStart("@") -ValueOnly

                return $value
            }

            $ie = Get-Command Invoke-Expression -CommandType Cmdlet

            & $ie $v
        }

        if($global:expectedIndex -ge $global:expected.Length)
        {
            throw "Did not expect command '$result' to be executed"
        }

        $expectedValue = $global:expected[$global:expectedIndex]

        if($expectedValue -is [array])
        {
            $expectedValue = $expectedValue -join " "
        }

        $result | Should $global:operator $expectedValue | Out-Null

        $global:expectedIndex++
    }

    return $mockBlock
}

function Mock-InstallDotnet
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = "Windows")]
        [switch]$Windows,

        [Parameter(Mandatory = $true, ParameterSetName = "Unix")]
        [switch]$Unix
    )

    if($Windows)
    {
        InModuleScope "CI" {
            Mock Invoke-WebRequest {
                param($Uri)

                $Uri | Should Be "https://dot.net/v1/dotnet-install.ps1"
            }

            Mock Unblock-File { }

            Mock Invoke-Expression {
                param($Command)

                $temp = [IO.Path]::GetTempPath()
                $dotnetInstall = Join-Path $temp "dotnet-install.ps1"
                $root = Get-SolutionRoot
                $dotnetSdk = Join-Path $root "packages\dotnet-sdk"

                $Command | Should Be "& '$dotnetInstall' -InstallDir '$dotnetSdk' -NoPath"
            } -ParameterFilter { $Command -like "*dotnet*" }

            Mock "Test-CIIsWindows" {
                return $true
            }
        }
    }
    else
    {
        InModuleScope "CI" {
            Mock Invoke-WebRequest {
                param($Uri)

                $Uri | Should Be "https://dot.net/v1/dotnet-install.sh"
            } -Verifiable

            Mock Test-CIIsWindows {
                return $false
            }

            Mock Invoke-Expression {
                param($Command)

                $temp = [IO.Path]::GetTempPath()
                $dotnetInstall = Join-Path $temp "dotnet-install.sh"
                $root = Get-SolutionRoot
                $dotnetSdk = Join-Path $root "packages\dotnet-sdk"

                $Command | Should Be "chmod +x '$dotnetInstall'; & '$dotnetInstall' --install-dir '$dotnetSdk' --no-path"
            } -ParameterFilter { $Command -like "*dotnet*" }
        }
    }

    Mock Test-Path {
        return $false
    } -ModuleName CI -ParameterFilter { $Path -like "*dotnet*" }

    $mockCommandArgs = @{
        CommandName = "Get-Command"
        MockWith = {
            param($Name)

            if($ErrorActionPreference -eq "SilentlyContinue")
            {
                # We're checking whether dotnet.exe exists so we can install it if necessary
                return
            }

            return [PSCustomObject]@{
                CommandType = "Application"
                Name = "dotnet.exe"
                Source = "C:\dotnet.exe"
            }
        }
        ParameterFilter = { $Name -eq "dotnet" }
    }

    Mock @mockCommandArgs -ModuleName CI
    Mock @mockCommandArgs -ModuleName PrtgAPI.Build
    Mock @mockCommandArgs
}

function global:MockGetChocolateyCommand
{
    Mock "Get-ChocolateyCommand" {
        param($CommandName)

        if(!$CommandName.EndsWith(".exe"))
        {
            $CommandName = "$CommandName.exe"
        }

        return "C:\ProgramData\chocolatey\bin\$CommandName"
    } -ModuleName CI

    Mock "Get-Item" {
        return [PSCustomObject]@{
            VersionInfo = [PSCustomObject]@{
                FileVersion = "9999.0.0.0"
            }
        }
    } -ModuleName "CI" -ParameterFilter { $Path -like "*chocolatey*" }
}