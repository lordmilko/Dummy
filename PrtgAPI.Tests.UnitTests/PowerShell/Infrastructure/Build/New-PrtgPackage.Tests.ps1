. $PSScriptRoot\..\..\..\Support\PowerShell\Build.ps1

$testCases = @(
    @{name = "Debug"}
    @{name = "Release"}
)

Describe "New-PrtgPackage" -Tag @("PowerShell", "Build") {
    It "creates a C# package on core for <name>" -TestCases $testCases {

        param($name)

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
            "$name"
            "--output"
            $tempRepository
            "/nologo"
            "-p:EnableSourceLink=true;SymbolPackageFormat=snupkg"
        )

        Mock-InvokeProcess $expected {
            New-PrtgPackage -Type C# -Configuration $name
        }
    }

    It "creates a C# package on desktop for <name>" -TestCases $testCases {

        param($name)

        $root = Get-SolutionRoot
        $tempRepository = Join-Path ([IO.Path]::GetTempPath()) "TempRepository"

        Mock "Get-PrtgVersion" {
            return [PSCustomObject]@{
                Package = "1.2.3"
            }
        } -ModuleName PrtgAPI.Build

        $expected = @(
            "&"
            "nuget"
            "pack"
            "$root\PrtgAPI\PrtgAPI.csproj"
            "-Exclude"
            "**/*.tt;**/Resources/*.txt;*PrtgClient.Methods.xml;**/*.json"
            "-outputdirectory"
            $tempRepository
            "-NoPackageAnalysis"
            "-symbols"
            "-version 1.2.3"
            "-properties"
            "Configuration=$name"
        )

        Mock-InvokeProcess $expected {
            New-PrtgPackage -Type C# -IsCore:$false -Configuration $name
        }
    }

    It "creates a PowerShell package on core for <name>" -TestCases $testCases {

        param($name)

        InModuleScope "CI" {

            $empty = {}

            Mock "Publish-Module" $empty
            Mock "Get-PSRepository" $empty
            Mock "Register-PSRepository" $empty
            Mock "Unregister-PSRepository" $empty
            Mock "Remove-Item" $empty
            Mock "Move-Item" $empty
            Mock "New-Item" $empty
            Mock "Get-Item" $empty
            Mock "Test-Path" {
                return $true
            }
            Mock "Get-ChildItem" {
                return [System.IO.DirectoryInfo]"C:\PrtgAPI\bin\Release"
            }
            Mock "Copy-Item" $empty
        }

        New-PrtgPackage -Type PowerShell -Configuration $name
    }

    It "creates a PowerShell package on desktop for <name>" -TestCases $testCases {

        param($name)

        InModuleScope "CI" {

            $empty = {}

            Mock "Publish-Module" $empty
            Mock "Get-PSRepository" $empty
            Mock "Register-PSRepository" $empty
            Mock "Unregister-PSRepository" $empty
            Mock "Remove-Item" $empty
            Mock "Move-Item" $empty
            Mock "New-Item" $empty
            Mock "Get-Item" $empty
            Mock "Test-Path" {
                return $true
            }
            Mock "Get-ChildItem" {
                return [System.IO.DirectoryInfo]"C:\PrtgAPI\bin\Release"
            }
            Mock "Copy-Item" $empty
        }

        New-PrtgPackage -Type PowerShell -IsCore:$false -Configuration $name
    }
}