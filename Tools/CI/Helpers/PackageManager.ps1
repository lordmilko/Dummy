function New-PackageManager
{
    return [PackageManager]::new()
}

function PackageManager
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = "RepoName")]
        [switch]$RepoName,

        [Parameter(Mandatory = $true, ParameterSetName = "RepoLocation")]
        [switch]$RepoLocation,

        [Parameter(Mandatory = $true, ParameterSetName = "PackageLocation")]
        [switch]$PackageLocation
    )

    $temp = [IO.Path]::GetTempPath()

    switch($PSCmdlet.ParameterSetName)
    {
        "RepoName" {
            "TempRepository"
        }
        "RepoLocation" {
            Join-Path $temp "TempRepository"
        }
        "PackageLocation" {
            Join-Path $temp "TempPackages"
        }
    }
}

# Package management cmdlets do not play nice with Pester's mocking system. Get-PackageSource
# doesn't know what parameter set it should belong to, and both PowerShell and NuGet package
# management cmdlets add a significant delay when both adding and calling their mocks. As a solution,
# we wrap our invocations to these cmdlets and mock our wrappers instead

function Get-PackageSourceEx { Get-PackageSource }
function Register-PackageSourceEx {

    $registerArgs = @{
        Name = (PackageManager -RepoName)
        Location = (PackageManager -RepoLocation)
        ProviderName = "NuGet"
        Trusted = $true
    }

    Register-PackageSource @registerArgs
}
function Unregister-PackageSourceEx {
    $unregisterArgs = @{
        Name = (PackageManager -RepoName)
        Location = (PackageManager -RepoLocation)
        ProviderName = "NuGet"
        Force = $true
    }

    Unregister-PackageSource @unregisterArgs -ErrorAction SilentlyContinue
}

function Get-PSRepositoryEx { Get-PSRepository }
function Register-PSRepositoryEx {
    $registerArgs = @{
        Name = (PackageManager -RepoName)
        SourceLocation = (PackageManager -RepoLocation)
        PublishLocation = (PackageManager -RepoLocation)
        InstallationPolicy = "Trusted"
    }

    Register-PSRepository @registerArgs
}
function Unregister-PSRepositoryEx { Unregister-PSRepository (PackageManager -RepoName) }

class PackageManager
{
    #region C#

    [void]InstallCSharpPackageSource()
    {
        $this.InstallPackageSource(
            "CSharp",
            { Get-PackageSourceEx },
            { Register-PackageSourceEx },
            { Unregister-PackageSourceEx }
        )
    }

    [void]UninstallCSharpPackageSource()
    {
        $this.UninstallPackageSource(
            "CSharp",
            { Unregister-PackageSourceEx }
        )
    }

    #endregion
    #region PowerShell

    [void]InstallPowerShellRepository()
    {
        $this.InstallPackageSource(
            "PowerShell",
            { Get-PSRepositoryEx },
            { Register-PSRepositoryEx },
            { Unregister-PSRepositoryEx }
        )
    }

    [void]UninstallPowerShellRepository()
    {
        $this.UninstallPackageSource(
            "PowerShell",
            { Unregister-PSRepositoryEx }
        )
    }

    #endregion
    #region Generic Package Source

    [void]InstallPackageSource($language, $exists, $register, $unregister)
    {
        Write-LogInfo "`t`tInstalling temp $language repository"

        if(Test-Path (PackageManager -RepoLocation))
        {
            Write-LogError "`t`t`tRemoving repository folder left over from previous run..."

            Remove-Item (PackageManager -RepoLocation) -Recurse -Force
        }

        Write-LogInfo "`t`t`tCreating repository folder"
        New-Item -ItemType Directory (PackageManager -RepoLocation) | Out-Null

        if((& $exists) | where name -eq (PackageManager -RepoName))
        {
            Write-LogError "`t`t`tRemoving repository left over from previous run..."
            & $unregister
        }

        Write-LogInfo "`t`t`tRegistering temp repository"
        & $register | Out-Null
    }

    [void]UninstallPackageSource($language, $unregister)
    {
        Write-LogInfo "`t`tUninstalling temp $language repository"

        Write-LogInfo "`t`t`tUnregistering temp repository"
        & $unregister

        Write-LogInfo "`t`t`tRemoving temp repository folder"
        Remove-Item (PackageManager -RepoLocation) -Recurse -Force
    }

    #endregion

    [void]WithTempCopy($folderName, $script)
    {
        $tempPath = Join-Path (PackageManager -RepoLocation) "TempOutput\$(Split-Path $folderName -Leaf)"

        Copy-Item -Path $folderName -Destination $tempPath -Recurse -Force

        try
        {
            & $script $tempPath
        }
        finally
        {
            Remove-Item "$(PackageManager -RepoLocation)\TempOutput" -Recurse -Force
        }
    }
}