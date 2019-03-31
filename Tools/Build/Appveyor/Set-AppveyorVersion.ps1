#region Get-AppveyorVersion

function Get-AppveyorVersion
{
    Write-Log "Calculating Appveyor build version"

    $assemblyVersion = Get-PrtgVersion
    $lastBuild = Get-LastAppveyorBuild
    $lastRelease = Get-LastAppveyorNuGetVersion

    Write-Log "    Assembly version: $assemblyVersion"
    Write-Log "    Last build: $lastBuild"
    Write-Log "    Last release: $lastRelease"

    if(IsPreview $assemblyVersion $lastRelease) #what are all the combinations possible here based on the 3 values lastrelease could be? i.e. 0.1, 0.1.1 or 0.1-preview.1
    {
        if(IsFirstPreview $lastBuild)
        {
            Reset-BuildVersion
        }

        [Version]$v = $assemblyVersion

        #todo: test this works after we just reset the build
        $result = "$($v.Major).$($v.Minor).$($v.Build + 1)-preview.{build}"
    }
    elseif(IsPreRelease $assemblyVersion $lastBuild $lastRelease)
    {
        if(IsFirstPreRelease $lastBuild)
        {
            Reset-BuildVersion
        }

        $result = "$assemblyVersion-build.{build}"
    }
    elseif(IsFullRelease $assemblyVersion $lastRelease)
    {
        $result = $assemblyVersion
    }
    else
    {
        throw "Failed to determine the type of build"
    }

    Write-Log "Setting Appveyor build to '$result'"

    return $result
}

function IsPreview($assemblyVersion, $lastRelease)
{
    # If this DLL has the same version as the last RELEASE, this should be a preview release
    return $assemblyVersion -eq $lastRelease
}

function IsFirstPreview($lastBuild)
{
    return !$lastBuild.Contains("preview")
}

function IsFullRelease($assemblyVersion, $lastRelease)
{
    if([string]::IsNullOrEmpty($lastRelease))
    {
        return $true
    }

    return ([Version]$assemblyVersion) -gt (CleanVersion $lastRelease)
}

function IsPreRelease($assemblyVersion, $lastBuild, $lastRelease)
{
    if([string]::IsNullOrEmpty(($lastBuild)))
    {
        return $false
    }

    if($lastBuild.Contains("preview"))
    {
        return $false
    }

    [Version]$assemblyVersion = $assemblyVersion

    if([string]::IsNullOrEmpty($lastRelease) -or $assemblyVersion -gt (CleanVersion $lastRelease))
    {
        $lastBuildClean = CleanVersion $lastBuild

        if($assemblyVersion -eq $lastBuildClean)
        {
            # We're the same assembly version as the last build which hasn't
            # been released yet. Therefore we are a pre-release

            return $true
        }
    }

    return $false
}

function CleanVersion($version)
{
    return [Version]($version -replace "-build.+","")
}

function IsFirstPreRelease($lastBuild)
{
    return !$lastBuild.Contains("build")
}

function Get-LastAppveyorBuild
{
    #todo: if we invoke this mid-appveyor, will the first record be the current session, or the last one? if it is the current one we need to detect if we're
    #fake appveyor for unit tests

    $history = Invoke-AppveyorRequest "history?recordsNumber=2"

    $version = ($history.builds | select -last 1).version

    return $version
}

function Get-LastAppveyorNuGetVersion
{
    $deployments = Get-AppveyorDeployment

    $lastNuGet = $deployments|sort datetime -Descending|where Name -eq "NuGet"|select -first 1

    return $lastNuGet.Version
}

function Get-AppveyorDeployment
{
    $response = Invoke-AppveyorRequest "deployments"
    
    $deployments = @()

    foreach($d in $response.deployments)
    {
        $deployments += [PSCustomObject]@{
            DateTIme = [DateTime]$d.started
            Version = $d.build.version
            Name = $d.environment.name -replace "(.+?)( .+)",'$1'
        }
    }

    return $deployments
}

function Reset-BuildVersion
{
    Invoke-AppveyorAction "settings/build-number" @{ nextBuildNumber = 1 }
}

function Invoke-AppveyorRequest
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        $Query = $null
    )

    return Invoke-AppveyorRequestInternal $Query Get
}

function Invoke-AppveyorAction
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        $Query = $null,

        [Parameter(Mandatory = $false, Position = 1)]
        $Body = $null
    )

    $result = Invoke-AppveyorRequestInternal $Query "Put" $Body
}

function Invoke-AppveyorRequestInternal
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        $Query = $null,

        [Parameter(Mandatory = $false, Position = 1)]
        $Method,

        [Parameter(Mandatory = $false, Position = 2)]
        $Body
    )

    $projectURI = "https://ci.appveyor.com/api/projects/$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG"

    if($Query)
    {
        $resourceURI = "$projectURI/$Query"
    }
    else
    {
        $resourceURI = $projectURI
    }

    $headers = @{
        "Content-type" = "application/json"
        "Authorization" = "Bearer $env:APPVEYOR_API_TOKEN"
    }

    $restArgs = @{
        Method = $Method
        Uri = $resourceURI
        Headers = $headers
    }

    if($Body)
    {
        $restArgs.Body = $Body | ConvertTo-Json
    }

    $result = Invoke-RestMethod @restArgs

    return $result
}

#endregion
#region Set-AppveyorVersion

function Set-AppveyorVersion
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [string]$BuildFolder = $env:APPVEYOR_BUILD_FOLDER
    )

    try
    {
        Write-LogInfo "Calculating version"
        #$version = Get-PrtgVersion $BuildFolder
        $version = Get-AppveyorVersion

        Write-LogInfo "`tSetting AppVeyor build to version '$version'"

        if($env:APPVEYOR)
        {
            Update-AppVeyorBuild -Version $version
        }
        else
        {
            $env:APPVEYOR_BUILD_VERSION = $version
        }
    }
    catch
    {
        $host.SetShouldExit(1)
    }
}

#endregion