. $PSScriptRoot\..\..\..\Support\PowerShell\Build.ps1

Describe "Invoke-PrtgBuild" -Tag @("PowerShell", "Build") {
    It "executes with core" {

        Mock-InstallDotnet -Windows

        $expected = @(
            "dotnet"
            "build"
            "$(Get-SolutionRoot)\PrtgAPIv17.sln"
            "-nologo"
            "-c"
            "Debug"
            "-p:EnableSourceLink=true"
        )

        Mock-InvokeProcess $expected {
            Invoke-PrtgBuild
        }
    }

    It "executes with desktop" {

        Mock Get-MSBuild {
            return "C:\msbuild.exe"
        } -ModuleName CI

        $expected = @(
            "&"
            "C:\msbuild.exe"
            "$(Get-SolutionRoot)\PrtgAPI.sln"
            "/verbosity:minimal"
            "/p:Configuration=Debug"
        )

        Mock-InvokeProcess $expected {
            Invoke-PrtgBuild -IsCore:$false
        }
    }

    It "executes with core on Linux" {
        Mock-InstallDotnet -Unix

        $expected = @(
            "dotnet"
            "build"
            "$(Get-SolutionRoot)\PrtgAPIv17.sln"
            "-nologo"
            "-c"
            "Debug"
        )

        Mock-InvokeProcess $expected {
            Invoke-PrtgBuild
        }
    }

    It "specifies the project to build with core" {

        Mock-InstallDotnet -Windows

        $expected = @(
            "dotnet"
            "build"
            "$(Get-SolutionRoot)\PrtgAPI\PrtgAPIv17.csproj"
            "-nologo"
            "-c"
            "Debug"
            "-p:EnableSourceLink=true"
        )

        Mock-InvokeProcess $expected {
            Invoke-PrtgBuild prtgapiv17
        }
    }

    It "specifies the project to build with desktop" {

        Mock Get-MSBuild {
            return "C:\msbuild.exe"
        } -ModuleName CI

        $expected = @(
            "&"
            "C:\msbuild.exe"
            "$(Get-SolutionRoot)\PrtgAPI\PrtgAPI.csproj"
            "/verbosity:minimal"
            "/p:Configuration=Debug"
        )

        Mock-InvokeProcess $expected {
            Invoke-PrtgBuild prtgapi -IsCore:$false
        }
    }

    It "throws when more than one project is specified" {
        { Invoke-PrtgBuild *test* } | Should Throw "Can only specify one project at a time, however wildcard '*test*' matched multiple projects: PrtgAPIv17.Tests.IntegrationTests, PrtgAPIv17.Tests.UnitTests"
    }

    It "executes MSBuild in debug mode on core" {
        
        $root = Get-SolutionRoot
        
        $expected1 = @(
            "dotnet"
            "build"
            "$root\PrtgAPIv17.sln"
            "-nologo"
            "-c"
            "Debug"
            "-p:EnableSourceLink=true"
            "/bl:$root\msbuild.binlog"
        )

        $expected2 = "$root\msbuild.binlog"

        Mock-AllProcess $expected1,$expected2 {
            Invoke-PrtgBuild -DebugMode
        }
    }

    It "executes MSBuild in debug mode on desktop" {
        Mock Get-MSBuild {
            return "C:\msbuild.exe"
        } -ModuleName CI
        $root = Get-SolutionRoot

        $expected1 = @(
            "&"
            "C:\msbuild.exe"
            "$(Get-SolutionRoot)\PrtgAPI\PrtgAPI.csproj"
            "/verbosity:minimal"
            "/p:Configuration=Debug"
            "/bl:$root\msbuild.binlog"
        )

        $expected2 = "$root\msbuild.binlog"

        Mock-AllProcess $expected1,$expected2 {
            Invoke-PrtgBuild prtgapi -IsCore:$false -DebugMode
        }
    }

    It "executes with Release build on core" {
        $expected = @(
            "dotnet"
            "build"
            "$(Get-SolutionRoot)\PrtgAPIv17.sln"
            "-nologo"
            "-c"
            "Release"
            "-p:EnableSourceLink=true"
        )

        Mock-InvokeProcess $expected {
            Invoke-PrtgBuild -Configuration Release
        }
    }

    It "executes with Release build on desktop" {
        Mock Get-MSBuild {
            return "C:\msbuild.exe"
        } -ModuleName CI

        $expected = @(
            "&"
            "C:\msbuild.exe"
            "$(Get-SolutionRoot)\PrtgAPI.sln"
            "/verbosity:minimal"
            "/p:Configuration=Release"
        )

        Mock-InvokeProcess $expected {
            Invoke-PrtgBuild -IsCore:$false -Configuration Release
        }
    }

    It "processes additional arguments" {
        $expected = @(
            "dotnet"
            "build"
            "$(Get-SolutionRoot)\PrtgAPIv17.sln"
            "-nologo"
            "-c"
            "Debug"
            "-p:EnableSourceLink=true"
            "first"
            "second"
        )

        Mock-InvokeProcess $expected {
            Invoke-PrtgBuild -Args "first","second"
        }
    }
}