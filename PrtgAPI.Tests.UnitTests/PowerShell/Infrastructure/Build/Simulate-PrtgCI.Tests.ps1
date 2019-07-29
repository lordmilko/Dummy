. $PSScriptRoot\..\..\..\Support\PowerShell\Build.ps1

Describe "Simulate-PrtgCI" -Tag @("PowerShell", "Build") {

    Context "Appveyor" {

        It "restores packages" {

            $root = Get-SolutionRoot

            $expected = @(
                "dotnet"
                "restore"
                "`"$root\PrtgAPIv17.sln`""
                "`"-p:EnableSourceLink=true`""
            )

            Mock-InvokeProcess $expected {
                Simulate-PrtgCI -Appveyor -Task Restore
            } -ModuleScope "Appveyor"
        }

        It "builds" {

            Mock-InstallDotnet -Windows

            $root = Get-SolutionRoot

            $expected = @(
                "dotnet"
                "build"
                "$root\PrtgAPIv17.sln"
                "-nologo"
                "-c"
                "Debug"
                "-p:EnableSourceLink=true"
                "--no-restore"
            )

            Mock-InvokeProcess $expected {
                Simulate-PrtgCI -Appveyor -Task Build
            }
        }

        It "creates nupkg" {

            Mock-InstallDotnet -Windows

            InModuleScope "CI" {
                $empty = {}

                Mock "Copy-Item" $empty
                Mock "Remove-Item" $empty
                Mock "Get-PackageSourceEx" $empty
                Mock "Register-PackageSourceEx" $empty
                Mock "Unregister-PackageSourceEx" $empty
                Mock "Get-PSRepositoryEx" $empty
                Mock "Register-PSRepositoryEx" $empty
                Mock "Unregister-PSRepositoryEx" $empty
                Mock "New-Item" $empty
                Mock "Publish-ModuleEx" $empty
                Mock "Compress-Archive" $empty
                Mock "Get-ChildItem" {
                    return [PSCustomObject]@{
                        FullName = "C:\"
                    }
                }
            }

            InModuleScope "Appveyor" {

                $empty = {}

                Mock "Test-PackageContents" $empty
                Mock "Clear-Repo" $empty
                Mock "Test-CSharpPackageInstalls" $empty
                Mock "Test-PowerShellPackageInstalls" $empty
                Mock "Test-PowerShellPackageInstallsInternal" $empty
                Mock "Get-Item" $empty

                Mock "Get-ChildItem" {
                    param(
                        $Path,
                        $Filter
                    )

                    if($Path -match ".+net4\*")
                    {
                        # GetPowerShellOutputDir
                        return [System.IO.DirectoryInfo]"$env:APPVEYOR_BUILD_FOLDER\PrtgAPI.PowerShell\bin\$env:CONFIGURATION\netcoreapp2.1"
                    }
                    elseif($Path -like "*\TempRepository" -and $Filter -eq "*.nupkg")
                    {
                        return [System.IO.DirectoryInfo]"$Path\PrtgAPI.1.2.3.nupkg"
                    }
                    elseif($Filter -eq "*.nuspec")
                    {
                        return [System.IO.DirectoryInfo]"$Path\PrtgAPI.nuspec"
                    }

                    throw "path and filter were $Path and $Filter"
                }

                Mock "Extract-Package" $empty

                Mock "GetVersion" {
                    return [PSCustomObject]@{
                        Package = "1.2.3"
                        Assembly = "1.2.0.0"
                        File = "1.2.3.4"
                        Module = "1.2.3"
                        ModuleTag = "v1.2.3"
                        PreviousTag = "v1.2.3"
                    }
                }
            }

            $root = Get-SolutionRoot

            $tempRepository = Join-Path ([IO.Path]::GetTempPath()) "TempRepository"

            $expected = @(
                "&"
                "dotnet"
                "pack"
                "$root\PrtgAPI\PrtgAPIv17.csproj"
                "--include-symbols"
                "--no-restore"
                "--no-build"
                "-c"
                "Debug"
                "--output"
                $tempRepository
                "/nologo"
                "-p:EnableSourceLink=true;SymbolPackageFormat=snupkg"
            )

            Mock-InvokeProcess $expected {
                Simulate-PrtgCI -Appveyor -Task Package
            }
        }

        It "tests" {

            Mock-InstallDotnet -Windows

            $root = Get-SolutionRoot

            try
            {
                $env:APPVEYOR = $true

                InModuleScope "CI" {
                    Mock "Invoke-Pester" {
                    } -Verifiable
                }

                function global:Add-AppveyorTest { }

                $expected = @(
                    "&"
                    "`"dotnet`""
                    "test"
                    "$root\PrtgAPI.Tests.UnitTests\PrtgAPIv17.Tests.UnitTests.csproj"
                    "-nologo"
                    "--no-restore"
                    "--no-build"
                    "--verbosity:n"
                    "-c"
                    "Debug"
                    "--filter"
                    "TestCategory!=SkipCI"
                )

                Mock-InvokeProcess $expected {
                    Simulate-PrtgCI -Appveyor -Task Test
                }
            }
            finally
            {
                $env:APPVEYOR = $null
            }
        }
        
        It "creates coverage" {

            Mock-InstallDotnet -Windows
            MockGetChocolateyCommand

            Mock Get-VSTest {
                return "C:\vstest.console.exe"
            } -ModuleName CI

            $dotnet = (gcm dotnet).Source
            $temp = [IO.Path]::GetTempPath()

            $root = Get-SolutionRoot

            $expected1 = @(
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

            $expected2 = @(
                "&"
                "`"C:\ProgramData\chocolatey\bin\OpenCover.Console.exe`""
                "-target:$dotnet"
                "-targetargs:test --filter TestCategory!=SlowCoverage&TestCategory!=SkipCI `"$root\PrtgAPI.Tests.UnitTests\PrtgAPIv17.Tests.UnitTests.csproj`" --verbosity:n --no-build -c Debug"
                "-output:`"$($temp)opencover.xml`""
                "-filter:+`"[PrtgAPI*]* -[PrtgAPI.Tests*]*`""
                "-excludebyattribute:System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute"
                "-hideskipped:attribute"
                "-register"
                "-mergeoutput"
                "-oldstyle"
            )

            $expected3 = @(
                "&"
                "C:\ProgramData\chocolatey\bin\reportgenerator.exe"
                "-reports:$($temp)opencover.xml"
                "-reporttypes:CsvSummary"
                "-targetdir:$($temp)report"
                "-verbosity:off"
            )

            InModuleScope "CI" {
                Mock "Import-Csv" {
                    return [PSCustomObject]@{
                        Property = "Line coverage:"
                        Value = "97%"
                    }
                }

                Mock "Get-ChildItem" {
                    param(
                        $Path,
                        $Filter
                    )

                    if($Filter -eq "*.Tests.ps1")
                    {
                        $original = Get-Command Get-ChildItem -CommandType Cmdlet
                        return & $original -Path $Path -Filter $Filter -Recurse
                    }

                    if($Filter -eq "PrtgAPI.Tests.UnitTests.dll")
                    {
                        return [System.IO.FileInfo]"$env:APPVEYOR_BUILD_FOLDER\PrtgAPI.Tests.UnitTests\bin\$env:CONFIGURATION\net461\PrtgAPI.Tests.UnitTests.dll"
                    }

                    throw "path and filter were $Path and $Filter"
                }

                Mock "Test-Path" {
                    return $true
                } -ParameterFilter { $Path -notlike "*dotnet*" }

                Mock "Remove-Item" {}
            }

            Mock-InvokeProcess $expected1,$expected2,$expected3 {
                Simulate-PrtgCI -Appveyor -Task Coverage
            } -Operator "Match"
        }

        It "installs dependencies" {

            Mock-InstallDotnet -Windows

            InModuleScope "CI" {
                Mock "Get-Module" {

                    param(
                        [string[]]$Name,
                        [switch]$ListAvailable
                    )

                    if($Name -eq "Pester")
                    {
                        return [PSCustomObject]@{
                            Name = "Pester"
                            Version = "3.4.5"
                        }
                    }
                    elseif($Name -eq "PSScriptAnalyzer")
                    {
                        return [PSCustomObject]@{
                            Name = "PSScriptAnalyzer"
                            Version = "1.18.1"
                        }
                    }
                    elseif($Name -eq "PowerShellGet")
                    {
                        return $null
                    }

                    throw "Get-Module was called with Name: '$Name', ListAvailable: '$ListAvailable'"
                } -Verifiable

                Mock "Get-Command" {

                    param(
                        [string[]]$Name
                    )

                    $allowed = @(
                        "dotnet"

                        # These are called to get the version of the command once its installed
                        "codecov"
                        "opencover.console"
                        "reportgenerator"
                        "vswhere"
                    )

                    if($Name -in $allowed)
                    {
                        return $null
                    }

                    throw "Get-Command was called with Name: '$Name'"
                } -ParameterFilter { $Name -ne "Invoke-Expression" } -Verifiable

                Mock "Get-ChocolateyCommand" {

                    $allowed = @(
                        "codecov"
                        "opencover.console"
                        "reportgenerator"
                        "vswhere"
                    )

                    if($CommandName -eq "chocolatey")
                    {
                        return "C:\chocolatey.exe"
                    }

                    if($CommandName -in $allowed)
                    {
                        return $null
                    }

                    throw "Get-ChocolateyCommand was called with Name: '$CommandName'"
                } -Verifiable

                Mock "Get-Item" {
                    return [PSCustomObject]@{
                        VersionInfo = [PSCustomObject]@{
                            FileVersion = "9999.0.0.0"
                        }
                    }
                } -ModuleName "CI" -ParameterFilter { $Path -eq "C:\chocolatey.exe" }

                Mock "Get-PackageProvider" {
                    return $null
                } -Verifiable

                Mock "Install-Package" {

                    param(
                        $Name,
                        $RequiredVersion,
                        $MinimumVersion,
                        $AllowClobber,
                        $Force,
                        $ForceBootstrap,
                        $ProviderName
                    )

                    if($Name -eq "PowerShellGet")
                    {
                        $Name | Should Be "PowerShellGet" | Out-Null
                        $MinimumVersion | Should Be "2.0.0" | Out-Null
                        $Force | Should Be $true | Out-Null
                        $ForceBootstrap | Should Be $true
                        $ProviderName | Should Be "PowerShellGet" | Out-Null

                        return
                    }

                    if($Name -eq "Pester")
                    {
                        $Name | Should Be "Pester" | Out-Null
                        $RequiredVersion | Should Be "3.4.6" | Out-Null
                        $Force | Should Be $true | Out-Null
                        $ForceBootstrap | Should Be $true
                        $ProviderName | Should Be "PowerShellGet" | Out-Null

                        return
                    }

                    if($Name -eq "PSScriptAnalyzer")
                    {
                        $Name | Should Be "PSScriptAnalyzer"
                        $Force | Should Be $true | Out-Null
                        $ForceBootstrap | Should Be $true
                        $ProviderName | Should Be "PowerShellGet" | Out-Null

                        return
                    }

                    $strs = @(
                        "Name: '$Name'"
                        "RequiredVersion: '$RequiredVersion'"
                        "MinimumVersion: '$MinimumVersion'"
                        "AllowClobber: '$AllowClobber'"
                        "Force: '$Force'"
                        "ForceBootstrap: '$ForceBootstrap'"
                        "ProviderName: '$ProviderName'"
                    )

                    throw "Install-Package was called with $($strs -join ", ")"
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

            $codecov = @("choco install codecov --limitoutput --no-progress -y")
            $opencover = @("choco install opencover.portable --limitoutput --no-progress -y")
            $reportgenerator = @("choco install reportgenerator.portable --limitoutput --no-progress -y")
            $vswhere = @("choco install vswhere --limitoutput --no-progress -y")

            Mock-InvokeProcess $codecov,$opencover,$reportgenerator,$vswhere {
                Simulate-PrtgCI -Appveyor -Task Install
            }
        }

        It "skips installing dependencies" {
            InModuleScope "CI" {
                Mock Invoke-Process { throw "Invoke-Process should not have been called with args $args" }
                Mock Install-Package { throw "Install-Package should not have been called with args $args" }
                Mock Install-PackageProvider { throw "Install-PackageProvider should not have been called with args $args" }

                Mock "Get-Module" {

                    param(
                        [string[]]$Name,
                        [switch]$ListAvailable
                    )

                    if($Name -eq "Pester")
                    {
                        return [PSCustomObject]@{
                            Name = "Pester"
                            Version = "3.4.6"
                        }
                    }
                    elseif($Name -eq "PowerShellGet")
                    {
                        return [PSCustomObject]@{
                            Name = "PowerShellGet"
                            Version = "2.0.0"
                        }
                    }
                    elseif($Name -eq "PSScriptAnalyzer")
                    {
                        return [PSCustomobject]@{
                            Name = "PSScriptAnalyzer"
                            Version = "1.18.1"
                        }
                    }

                    throw "Get-Module was called with Name: '$Name', ListAvailable: '$ListAvailable'"
                } -Verifiable

                Mock "Get-Command" {

                    param(
                        [string[]]$Name
                    )

                    $allowed = @(
                        "dotnet"
                        "codecov"
                        "opencover.console"
                        "reportgenerator"
                        "vswhere"
                    )

                    if($Name -in $allowed)
                    {
                        return [PSCustomObject]@{
                            Name = $Name[0]
                            Source = "C:\$($Name[0])"
                        }
                    }

                    throw "Get-Command was called with Name: '$Name'"
                } -ParameterFilter { $Name -ne "Invoke-Expression" } -Verifiable

                Mock "Get-Item" {
                    return [PSCustomObject]@{
                        VersionInfo = [PSCustomObject]@{
                            FileVersion = "9999.0.0.0"
                        }
                    }
                } -ModuleName "CI" -ParameterFilter { $Path -eq "C:\chocolatey.exe" }

                Mock "Get-PackageProvider" {

                    return [PSCustomObject]@{
                        Name = "NuGet"
                    }
                } -Verifiable

                Mock "Get-ChocolateyCommand" {
                    param($CommandName)

                    if(!$CommandName.EndsWith(".exe"))
                    {
                        $CommandName = "$CommandName.exe"
                    }

                    return "C:\ProgramData\chocolatey\bin\$CommandName"
                }
            }

            Simulate-PrtgCI -Appveyor -Task Install
        }
    }

    Context "Travis" {

        function GetTravisCommands
        {
            $root = Get-SolutionRoot

            $clean = @(
                "dotnet"
                "clean"
                "`"$root\PrtgAPIv17.sln`""
                "-c"
                "Debug"
            )

            $build = @(
                "dotnet"
                "build"
                "$root\PrtgAPIv17.sln"
                "-nologo"
                "-c"
                "Debug"
            )

            $test = @(
                "&"
                "`"dotnet`""
                "test"
                "$root\PrtgAPI.Tests.UnitTests\PrtgAPIv17.Tests.UnitTests.csproj"
                "-nologo"
                "--no-restore"
                "--no-build"
                "--verbosity:n"
                "-c"
                "Debug"
                "--filter"
                "TestCategory!=SkipCI"
            )

            return $clean,$build,$test
        }

        It "executes with core" {

            Mock-InstallDotnet -Unix

            $commands = GetTravisCommands

            Mock Invoke-Pester {} -ModuleName "CI" -Verifiable

            Mock-InvokeProcess $commands {
                Simulate-PrtgCI -Travis -IsCore:$true
            }
        }

        It "executes with desktop" {

            Mock-InstallDotnet -Unix

            $commands = GetTravisCommands

            Mock Invoke-Pester {

            } -ModuleName "CI" -Verifiable

            Mock-InvokeProcess $commands {
                Simulate-PrtgCI -Travis -IsCore:$false
            }
        }
    }
}