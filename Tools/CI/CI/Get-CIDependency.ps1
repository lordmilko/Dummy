function Get-CIDependency
{
    # If you add a new entry here also make sure to add it to Simulate-PrtgCI.Tests.ps1, Install-PrtgDependency.ps1 and
    # Install-PrtgDependency.Tests.ps1 (including both the standalone test and the test as part of all dependencies)
    $dependencies = @(
        #@{ Name = "chocolatey";               Chocolatey = $true;      Upgrade = $true }
        @{ Name = "dotnet";                   Dotnet     = $true } #todo; add to all the other places too
        @{ Name = "codecov";                  Chocolatey = $true }
        @{ Name = "opencover.portable";       Chocolatey = $true;      CommandName = "opencover.console" }
        @{ Name = "reportgenerator.portable"; Chocolatey = $true;      CommandName = "reportgenerator" }
        @{ Name = "vswhere";                  Chocolatey = $true }
        @{ Name = "NuGet";                    PackageProvider = $true; MinimumVersion = "2.8.5.201" }
        @{ Name = "PowerShellGet";            PowerShell = $true;      MinimumVersion = "2.0.0" }
        @{ Name = "Pester";                   PowerShell = $true;      Version = "3.4.6" }
        @{ Name = "PSScriptAnalyzer";         PowerShell = $true }
    )

    return $dependencies
}
