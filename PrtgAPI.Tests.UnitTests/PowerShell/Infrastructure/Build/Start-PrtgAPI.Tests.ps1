. $PSScriptRoot\..\..\..\Support\PowerShell\Build.ps1

function Mock-StartProcess($exe, $expected, $isCore, $additionalArguments)
{
    $root = Get-SolutionRoot

    Mock Start-Process {

        param(
            [string]$FilePath,
            [string[]]$ArgumentList
        )

        $powerShell = "$exe -executionpolicy bypass -noexit -command ipmo"

        $Filepath + " " + $ArgumentList -join " " | Should Be "$powerShell $root\$expected; cd ~"
    }.GetNewClosure() -Verifiable -ModuleName "PrtgAPI.Build"

    if($additionalArguments)
    {
        Start-PrtgAPI -IsCore:$isCore @additionalArguments
    }
    else
    {
        Start-PrtgAPI -IsCore:$isCore
    }

    Assert-VerifiableMocks
}

function Mock-ImportModule($path, $scriptBlock)
{
    Mock Import-Module {
        param($Name)

        $Name | Should Be $path
    }.GetNewClosure() -Verifiable -ModuleName "PrtgAPI.Build"

    & $scriptBlock

    Assert-VerifiableMocks
}

function WithoutWindows($scriptBlock) {
    InModuleScope "CI" {
        Mock "Test-CIIsWindows" {
            return $false
        }
    }

    & $scriptBlock
}

Describe "Start-PrtgAPI" -Tag @("PowerShell", "Build") {
    It "opens PrtgAPI in Windows PowerShell on Windows on core" {

        InModuleScope "PrtgAPI.Build" {
            Mock "Get-ChildItem" {
                return [System.IO.DirectoryInfo]"$root\PrtgAPI.PowerShell\bin\Debug\netcoreapp2.1"
            }

            Mock "Test-Path" {
                return $true
            }
        }

        Mock-StartProcess "pwsh" "PrtgAPI.PowerShell\bin\Debug\netcoreapp2.1\PrtgAPI\PrtgAPI.psd1" $true
    }

    It "opens PrtgAPI in Windows PowerShell on Windows on desktop" {

        Mock "Test-Path" {
            return $true
        } -ModuleName "PrtgAPI.Build"

        Mock-StartProcess "powershell" "PrtgAPI.PowerShell\bin\Debug\PrtgAPI\PrtgAPI.psd1" $false
    }
    
    It "starts a Release build on core" {

        $root = Get-SolutionRoot

        InModuleScope "PrtgAPI.Build" {
            Mock "Get-ChildItem" {
                return [System.IO.DirectoryInfo]"$root\PrtgAPI.PowerShell\bin\Release\netcoreapp2.1"
            }

            Mock "Test-Path" {
                return $true
            }
        }

        Mock-StartProcess "pwsh" "PrtgAPI.PowerShell\bin\Release\netcoreapp2.1\PrtgAPI\PrtgAPI.psd1" $true @{
            Configuration = "Release"
        }
    }

    It "starts a Release build on desktop" {

        $root = Get-SolutionRoot

        InModuleScope "PrtgAPI.Build" {
            Mock "Get-ChildItem" {
                return [System.IO.DirectoryInfo]"$root\PrtgAPI.PowerShell\bin\Release"
            }

            Mock "Test-Path" {
                return $true
            }
        }

        Mock-StartProcess "powershell" "PrtgAPI.PowerShell\bin\Release\PrtgAPI\PrtgAPI.psd1" $false @{
            Configuration = "Release"
        }
    }

    It "throws when PrtgAPI has not been compiled on desktop" {
        InModuleScope "PrtgAPI.Build" {
            Mock "Test-Path" {
                return $false
            }
        }

        { Start-PrtgAPI -IsCore:$false } | Should Throw "Cannot start PrtgAPI: solution has not been compiled for 'Debug' build"
    }

    It "throws when PrtgAPI has not been compiled on core" {
        InModuleScope "PrtgAPI.Build" {
            Mock "Test-Path" {
                return $false
            }

            Mock "Get-ChildItem" {
                return @()
            }
        }

        { Start-PrtgAPI } | Should Throw "Cannot find any build candidates under folder"
    }

    It "throws when multiple target frameworks exist on core" {

        $root = Get-SolutionRoot

        InModuleScope "PrtgAPI.Build" {
            Mock "Get-ChildItem" {
                return @(
                    [System.IO.DirectoryInfo]"$root\PrtgAPI.PowerShell\bin\Debug\netcoreapp2.1"
                    [System.IO.DirectoryInfo]"$root\PrtgAPI.PowerShell\bin\Debug\netstandard2.0"
                )
            }
        }

        { Start-PrtgAPI } | Should Throw "Unable to determine which TargetFramework to use. Please specify one of netcoreapp2.1, netstandard2.0"
    }

    It "specifies a target framework" {
        $root = Get-SolutionRoot

        InModuleScope "PrtgAPI.Build" {
            Mock "Get-ChildItem" {
                return @(
                    [System.IO.DirectoryInfo]"$root\PrtgAPI.PowerShell\bin\Debug\netcoreapp2.1"
                    [System.IO.DirectoryInfo]"$root\PrtgAPI.PowerShell\bin\Debug\netstandard2.0"
                )
            }

            Mock "Test-Path" {
                return $true
            }
        }

        Mock-StartProcess "pwsh" "PrtgAPI.PowerShell\bin\Debug\netcoreapp2.1\PrtgAPI\PrtgAPI.psd1" $true @{
            Target = "netcoreapp2.1"
        }
    }

    It "specifies an invalid target framework when other frameworks are known" {
        InModuleScope "PrtgAPI.Build" {
            Mock "Get-ChildItem" {
                return @(
                    [System.IO.DirectoryInfo]"$root\PrtgAPI.PowerShell\bin\Debug\netcoreapp2.1"
                    [System.IO.DirectoryInfo]"$root\PrtgAPI.PowerShell\bin\Debug\netstandard2.0"
                )
            }

            Mock "Test-Path" {

                param($Path)

                if($Path -like "*banana*")
                {
                    return $false
                }

                return $true
            }
        }

        { Start-PrtgAPI -Target banana } | Should Throw "Cannot start PrtgAPI: target framework 'banana' does not exist. Please ensure PrtgAPI has been compiled for the specified TargetFramework and Configuration. Known target frameworks: netcoreapp2.1, netstandard2.0."
    }

    It "specifies an invalid target framework when no frameworks have been compiled" {
        InModuleScope "PrtgAPI.Build" {
            Mock "Get-ChildItem" {
                return @()
            }

            Mock "Test-Path" {

                return $false
            }
        }

        $root = Get-SolutionRoot

        { Start-PrtgAPI -Target banana } | Should Throw "Cannot start PrtgAPI: target folder '$root\PrtgAPI.PowerShell\bin\Debug\banana' does not exist. Please ensure PrtgAPI has been compiled for the specified TargetFramework and Configuration."
    }

    It "opens PrtgAPI on Linux" {
        $root = Get-SolutionRoot

        Mock "Test-Path" {
            return $true
        } -ModuleName "PrtgAPI.Build"

        Mock "Get-ChildItem" {
            return [System.IO.DirectoryInfo]"$root\PrtgAPI.PowerShell\bin\Debug\netcoreapp2.1"
        }.GetNewClosure() -ModuleName "PrtgAPI.Build"

        WithoutWindows {
            $path = Join-Path $root "PrtgAPI.PowerShell\bin\Debug\netcoreapp2.1\PrtgAPI\PrtgAPI.psd1"

            Mock-ImportModule $path {
                Start-PrtgAPI
            }
        }
    }
}