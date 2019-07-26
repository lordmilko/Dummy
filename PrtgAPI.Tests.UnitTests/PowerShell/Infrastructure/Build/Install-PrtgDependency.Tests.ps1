. $PSScriptRoot\..\..\..\Support\PowerShell\Build.ps1

function Mock-Command($name)
{
    $global:prtgCommandName = $name

    Mock "Get-Command" {

        param(
            [string[]]$Name
        )

        if($Name -eq $global:prtgCommandName)
        {
            return
        }

        throw "Get-Command was called with Name: '$Name' but expected '$global:prtgCommandName'"
    } -Verifiable -ParameterFilter { $Name -ne "Invoke-Expression" } -ModuleName "CI"
}

function Mock-ChocolateyCommand($name)
{
    Mock "Get-ChocolateyCommand" {

        if($CommandName -eq "chocolatey")
        {
            return "C:\chocolatey.exe"
        }

        return $null
    } -Verifiable -ModuleName "CI"

    Mock "Get-Item" {
        return [PSCustomObject]@{
            VersionInfo = [PSCustomObject]@{
                FileVersion = "9999.0.0.0"
            }
        }
    } -ModuleName "CI" -ParameterFilter { $Path -eq "C:\chocolatey.exe" }
}

Describe "Install-PrtgDependency" -Tag @("PowerShell", "Build") {

    It "installs chocolatey" {

        InModuleScope "CI" {

            Mock "Get-ChocolateyCommand" {} -Verifiable

            Mock "Invoke-WebRequest" {
                return "iwr-response"
            } -Verifiable

            Mock "Invoke-Expression" {} -ParameterFilter { $Command -eq "iwr-response" } -Verifiable
        }

        Install-PrtgDependency chocolatey

        Assert-VerifiableMocks
    }

    It "upgrades chocolatey" {

        InModuleScope "CI" {
            Mock "Get-ChocolateyCommand" {
                return "C:\chocolatey.exe"
            } -Verifiable

            Mock "Get-Item" {
                return [PSCustomObject]@{
                    VersionInfo = [PSCustomObject]@{
                        FileVersion = "0.0.0.1"
                    }
                }
            } -ParameterFilter { $Path -eq "C:\chocolatey.exe" } -Verifiable
        }    

        Mock-InvokeProcess "choco upgrade chocolatey --limitoutput --no-progress -y" {
            Install-PrtgDependency chocolatey
        }
    }

    It "installs dotnet on Windows" {
        Mock-InstallDotnet -Windows

        Install-PrtgDependency dotnet
    }

    It "installs dotnet on Unix" {
        Mock-InstallDotnet -Unix

        Install-PrtgDependency dotnet
    }

    It "installs codecov" {

        Mock Test-CIIsWindows {
            return $true
        } -ModuleName CI

        Mock-ChocolateyCommand "codecov"

        Mock-InvokeProcess "choco install codecov --limitoutput --no-progress -y" {
            Install-PrtgDependency codecov
        }
    }

    It "installs opencover.portable" {
        Mock-ChocolateyCommand "opencover.console"

        Mock-InvokeProcess "choco install opencover.portable --limitoutput --no-progress -y" {
            Install-PrtgDependency opencover
        }
    }

    It "installs reportgenerator.portable" {
        Mock-ChocolateyCommand "reportgenerator"

        Mock-InvokeProcess "choco install reportgenerator.portable --limitoutput --no-progress -y" {
            Install-PrtgDependency reportgenerator
        }
    }

    It "installs vswhere" {
        Mock-ChocolateyCommand "vswhere"

        Mock-InvokeProcess "choco install vswhere --limitoutput --no-progress -y" {
            Install-PrtgDependency vswhere
        }
    }

    It "installs NuGet" {

        InModuleScope "CI" {
            Mock "Get-PackageProvider" {
                return
            } -Verifiable

            Mock "Install-PackageProvider" {

                param(
                    [string[]]$Name,
                    [string]$MinimumVersion,
                    [switch]$Force
                )

                if($Name -eq "NuGet")
                {
                    $MinimumVersion | Should Be "2.8.5.201" | Out-Null
                    $Force | Should Be $true | Out-Null
                }
                else
                {
                    throw "Install-PackageProvider was called with Name: '$Name', MinimumVersion: '$MinimumVersion', Force: '$Force'"
                }
            } -Verifiable
        }

        Install-PrtgDependency NuGet

        Assert-VerifiableMocks
    }

    It "installs PowerShellGet" {
        InModuleScope "CI" {
            Mock "Get-Module" {
                return
            } -Verifiable

            Mock "Install-Package" {
                param($Name)

                $Name | Should Be "PowerShellGet"
            } -Verifiable
        }

        Install-PrtgDependency PowerShellGet

        Assert-VerifiableMocks
    }

    It "installs Pester without an existing version" {
        InModuleScope "CI" {
            Mock "Get-Module" {
                return
            } -Verifiable

            Mock "Install-Package" {                
                $Name | Should Be "Pester"
                $Version | Should Be "3.4.6"
                $MinimumVersion | Should BeNullOrEmpty
            } -Verifiable
        }

        Install-PrtgDependency Pester

        Assert-VerifiableMocks
    }

    It "installs PSScriptAnalyzer" {
        InModuleScope "CI" {
            Mock "Get-Module" {
                return
            } -Verifiable

            Mock "Install-Package" {
                param($Name)

                $Name | Should Be "PSScriptAnalyzer"
            } -Verifiable
        }

        Install-PrtgDependency PSScriptAnalyzer

        Assert-VerifiableMocks
    }

    It "skips installing a PowerShell Version when the MinimumVersion is already installed" {
        InModuleScope "CI" {
            Mock "Get-Module" {
                return [PSCustomObject]@{
                    Name = "Pester"
                    Version = [Version]"3.4.0"
                }
            } -Verifiable

            Mock "Install-Package" {                
                throw "Should not have attempted to install package"
            }
        }

        Install-PrtgDependency Pester

        Assert-VerifiableMocks
    }

    It "installs expected dependencies" {

        $expected = @(
            # If you add one to the list, make sure you also add an appropriate individual test for it above
            "chocolatey"
            "dotnet"
            "codecov"
            "opencover.portable"
            "reportgenerator.portable"
            "vswhere"
            "NuGet"
            "PowerShellGet"
            "Pester"
            "PSScriptAnalyzer"
        )
        $global:actual = @()

        Mock "Install-Dependency" {

            param($PackageName)

            $global:actual += $PackageName
        } -ModuleName "CI"

        Install-PrtgDependency

        try
        {
            $global:actual | Should Be $expected
        }
        finally
        {
            $global:actual = $null
        }
    }
}