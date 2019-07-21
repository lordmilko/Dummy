function Install-Dependency
{
    [CmdletBinding()]
    param(
        [Alias("Name")]
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$PackageName,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$CommandName,

        [Parameter(Mandatory = $true, ParameterSetName="Dotnet")]
        [switch]$Dotnet,

        [Parameter(Mandatory = $true, ParameterSetName="Chocolatey")]
        [switch]$Chocolatey,

        [Parameter(Mandatory = $false, ParameterSetName="Chocolatey")]
        [Parameter(Mandatory = $true, ParameterSetName="PowerShell")]
        [switch]$PowerShell,

        [Parameter(Mandatory = $false, ParameterSetName="Chocolatey")]
        [switch]$Upgrade,

        [Parameter(Mandatory = $false, ParameterSetName="Chocolatey")]
        [Parameter(Mandatory = $false, ParameterSetName="PowerShell")]
        [string]$Version,

        [Parameter(Mandatory = $true, ParameterSetName="PackageProvider")]
        [switch]$PackageProvider,

        [Parameter(Mandatory = $false, ParameterSetName="PackageProvider")]
        [Parameter(Mandatory = $false, ParameterSetName="PowerShell")]
        [string]$MinimumVersion,

        [Parameter(Mandatory = $false)]
        [switch]$Log
    )

    Get-CallerPreference $PSCmdlet $ExecutionContext.SessionState

    switch($PSCmdlet.ParameterSetName)
    {
        "Dotnet" {
            Install-Dotnet @PSBoundParameters
        }

        "Chocolatey" {
            Install-Chocolatey @PSBoundParameters            
        }

        "PowerShell" {
            Install-PSPackage @PSBoundParameters
        }

        "PackageProvider" {
            Install-PSPackageProvider @PSBoundParameters
        }

        default {
            throw "Implementation missing for parameter set '$_'"
        }
    }
}

function Install-Dotnet
{
    if($env:CI)
    {
        # dotnet SDK should be managed by CI system, not by us
        return
    }

    $root = Get-SolutionRoot
    $installDir = Join-Path $root "packages\dotnet-sdk"

    $dotnetPath = gcm dotnet -ErrorAction SilentlyContinue

    if($dotnetPath)
    {
        Write-Verbose "Using 'dotnet' executable on PATH from '$($dotnetPath.Source)'"
        return
    }
    else
    {
        if((Test-Path $installDir) -and (Test-Path (Join-Path $installDir "dotnet*")))
        {
            Write-Verbose "Using 'dotnet' executable from '$installDir'"

            $delim = ":"

            if(Test-IsWindows)
            {
                $delim = ";"
            }

            $env:PATH = "$env:PATH$delim$installDir"

            return
        }
    }

    $baseUrl = "https://dot.net/v1/"

    $temp = [IO.Path]::GetTempPath()

    if(Test-IsWindows)
    {
        $fileName = "dotnet-install.ps1"
    }
    else
    {
        $fileName = "dotnet-install.sh"
    }

    $url = "$baseUrl$fileName"
    $outFile = Join-Path $temp $fileName

    if($PSEdition -ne "Core")
    {
        # Microsoft requires TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }

    Invoke-WebRequest $url -OutFile "$outFile"

    if(Test-IsWindows)
    {
        Unblock-File $outFile

        Invoke-Expression "& '$outFile' -InstallDir '$installDir' -NoPath"
    }
    else
    {
        Invoke-Expression "chmod +x '$outFile'; & '$outFile' --install-dir '$installDir' --no-path"
    }

    Write-Verbose "Using 'dotnet' executable from '$installDir'"

    $delim = ":"

    if(Test-IsWindows)
    {
        $delim = ";"
    }

    $env:PATH = "$env:PATH$delim$installDir"
}

function Install-Chocolatey
{
    if(!(Test-IsWindows))
    {
        throw "Cannot install package '$PackageName': package is only supported on Windows"
    }

    if([string]::IsNullOrWhiteSpace($CommandName))
    {
        $CommandName = $PackageName
    }

    $action = "install"

    if($Upgrade)
    {
        $action = "upgrade"
    }

    $splat = @(
        $action
        $PackageName
        "--limitoutput"
        "--no-progress"
        "-y"
    )

    if(![string]::IsNullOrWhiteSpace($Version))
    {
        $splat += @(
            "--version"
            $Version
        )
    }

    if(!$Upgrade)
    {
        $installed = $false

        $versionWildcard = $Version

        if(!$versionWildcard)
        {
            $versionWildcard = "*"
        }

        $existingVersion = $null

        if($PowerShell)
        {
            $existingModule = gmo $PackageName -ListAvailable|where Version -Like $versionWildcard

            if($existingModule)
            {
                $existingVersion = ($existingModule|select -First 1).Version
                $installed = $true
            }
        }
        else
        {
            $existingCommand = gcm $CommandName -ErrorAction SilentlyContinue

            if($existingCommand)
            {
                $existingVersion = $existingCommand.Version
                $installed = $true
            }
        }

        if($installed)
        {
            $versionStr = ""

            if($Version)
            {
                $versionStr = " version $version"
            }

            if($Log)
            {
                Write-LogInfo "`tSkipping installing package '$PackageName'$versionStr as it is already installed"
            }
            else
            {
                WriteDependencyResult $PackageName "Chocolatey" $existingVersion "Skipped"
            }
            
            return
        }
    }

    if($Log)
    {
        Write-LogInfo "`tExecuting 'choco $splat'"
    }

    Invoke-Process {
        choco @splat
    }

    if($PowerShell)
    {
        $existingVersion = (gmo $PackageName -ListAvailable).Version
    }
    else
    {
        $existingVersion = (gcm $CommandName).Version
    }

    WriteDependencyResult $PackageName "Chocolatey" $existingVersion "Success"
}

function Install-PSPackage
{
    $packageArgs = @{
        Name = $PackageName
        Force = $true
        ForceBootstrap = $true
        ProviderName = "PowerShellGet"
    }

    if($Version)
    {
        $packageArgs.RequiredVersion = $Version
    }

    if($MinimumVersion)
    {
        $packageArgs.MinimumVersion = $MinimumVersion
    }

    $installedModules = Get-Module -ListAvailable $PackageName

    if($MinimumVersion)
    {
        $installedModules = $installedModules|where { $_.Version -ge [Version]$MinimumVersion}
    }
    else
    {
        if($Version)
        {
            $installedModules = $installedModules|where { $_.Version -eq [Version]$Version }
        }
    }

    if(!$installedModules)
    {
        $result = Install-Package @packageArgs

        if(!$Log)
        {
            WriteDependencyResult $PackageName "PSPackage" $result.Version "Success"
        }
    }
    else
    {
        if($Log)
        {
            Write-LogInfo "`tSkipping installing package '$PackageName' as it is already installed"
        }
        else
        {
            WriteDependencyResult $PackageName "PSModule" ($installedModules|select -first 1).Version "Skipped"
        }
    }
}

function Install-PSPackageProvider
{
    $packageArgs = @{
        Name = $PackageName
        Force = $true
    }

    if($MinimumVersion)
    {
        $packageArgs.MinimumVersion = $MinimumVersion
    }

    $provider = Get-PackageProvider | where name -eq $PackageName

    if(!$provider)
    {
        if($Log)
        {
            Write-LogInfo "`tInstalling $PackageName package provider"
        }
        
        $result = Install-PackageProvider @packageArgs

        if(!$Log)
        {
            WriteDependencyResult $PackageName "PackageProvider" $provider.Version "Success"
        }
    }
    else
    {
        if($Log)
        {
            Write-LogInfo "`tSkipping installing '$PackageName' package provider as it is already installed"
        }
        else
        {
            WriteDependencyResult $PackageName "PackageProvider" $provider.Version "Skipped"
        }
    }
}

function WriteDependencyResult($name, $type, $version, $action)
{
    [PSCustomObject]@{
        Name = $name
        Type = $type
        Version = $version
        Action = $action
    }
}