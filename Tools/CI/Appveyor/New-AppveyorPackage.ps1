. "$PSScriptRoot\..\..\..\Tools\CI\Helpers\PackageManager.ps1"

$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "Stop"

function New-AppveyorPackage
{
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [switch]$IsCore = $script:APPEYOR_BUILD_CORE
    )

    Write-LogHeader "Building NuGet Package (Core: $IsCore)"

    $config = [PSCustomObject]@{
        SolutionRoot          = "$env:APPVEYOR_BUILD_FOLDER"
        CSharpProjectRoot     = "$env:APPVEYOR_BUILD_FOLDER\PrtgAPI"
        CSharpOutputDir       = "$env:APPVEYOR_BUILD_FOLDER\PrtgAPI\bin\$env:CONFIGURATION"
        PowerShellProjectRoot = "$env:APPVEYOR_BUILD_FOLDER\PrtgAPI.PowerShell"
        PowerShellOutputDir   = Get-PowerShellOutputDir $env:APPVEYOR_BUILD_FOLDER $env:CONFIGURATION $IsCore
        Manager               = New-PackageManager
        IsCore                = $IsCore
    }

    Process-CSharpPackage $config
    Process-PowerShellPackage $config
}

#region C#

function Process-CSharpPackage($config)
{
    Write-LogSubHeader "`tProcessing C# package"

    $config.Manager.InstallCSharpPackageSource()

    $csharpArgs = @{
        BuildFolder = $config.SolutionRoot
        OutputFolder = ([PackageManager]::RepoLocation)
        Version = Get-CSharpVersion $config.IsCore
        Configuration = $env:CONFIGURATION
        IsCore = $config.IsCore
    }

    New-CSharpPackage @csharpArgs
    Test-CSharpPackage $config

    Move-AppveyorPackages $config

    $config.Manager.UninstallCSharpPackageSource()
}

function Get-CSharpVersion($IsCore)
{
    if($env:APPVEYOR)
    {
        # Trim any version qualifiers (-build.2, etc)
        return $env:APPVEYOR_BUILD_VERSION -replace "-.+"
    }
    else
    {
        return GetVersion $IsCore
    }
}

function Test-CSharpPackage($config)
{
    Write-LogInfo "`t`tTesting package"

    $nupkg = Get-CSharpNupkg

    Extract-Package $nupkg {

        param($extractFolder)

        Test-CSharpPackageDefinition $config $extractFolder
        Test-CSharpPackageContents $config $extractFolder
    }

    Test-CSharpPackageInstalls $config
}

function Test-CSharpPackageDefinition($config, $extractFolder)
{
    Write-LogInfo "`t`t`tValidating package definition"

    $nuspec = gci $extractFolder -Filter *.nuspec

    if(!$nuspec)
    {
        throw "Couldn't find nuspec in folder '$extractFolder'"
    }

    [xml]$content = gc $nuspec.FullName
    $metadata = $content.package.metadata

    # Validate release notes

    $version = GetVersion $config.IsCore

    if($metadata.version -ne $version)
    {
        throw "Expected package to have version '$version' but instead had version '$($metadata.version)'"
    }

    $expectedUrl = "https://github.com/lordmilko/PrtgAPI/releases/tag/v$version"

    if(!$metadata.releaseNotes.Contains($expectedUrl))
    {
        throw "Release notes did not contain correct release version. Expected notes to contain URL '$expectedUrl'. Release notes were '$($metadata.releaseNotes)'"
    }

    if($config.IsCore)
    {
        if(!$metadata.repository)
        {
            throw "Package did not contain SourceLink details"
        }
    }
}

function Test-CSharpPackageContents($config, $extractFolder)
{
    $required = @(
        "lib\net452\PrtgAPI.dll"
        "lib\net452\PrtgAPI.xml"
        "package\*"
        "_rels\*"
        "PrtgAPI.nuspec"
        "[Content_Types].xml"
    )

    if($config.IsCore)
    {
        $required += "LICENSE"

        if($env:CONFIGURATION -eq "Release")
        {
            $required += @(
                "lib\net461\PrtgAPI.dll"
                "lib\net461\PrtgAPI.xml"
                "lib\netcoreapp2.1\PrtgAPI.dll"
                "lib\netcoreapp2.1\PrtgAPI.xml"
                "lib\netstandard2.0\PrtgAPI.dll"
                "lib\netstandard2.0\PrtgAPI.xml"
            )
        }
        else
        {
            $debugVersion = Get-DebugTargetFramework

            Write-LogInfo "`t`t`t`tUsing debug build '$debugVersion' for testing nupkg contents"

            $required = $required | foreach {
                if($_ -like "*net452*")
                {
                    $_ -replace "net452",$debugVersion
                }
                else
                {
                    $_
                }
            }
        }
    }

    Test-PackageContents $extractFolder $required
}

function Test-CSharpPackageInstalls($config)
{
    Write-LogInfo "`t`t`tTesting package installs properly"

    $nupkg = Get-CSharpNupkg
    $packageName = $nupkg.Name -replace ".nupkg",""
    $installPath = "$([PackageManager]::PackageLocation)\$packageName"

    if(IsNuGetPackageInstalled $installPath)
    {
        Write-LogInfo "`t`t`t`t'$packageName' is already installed. Uninstalling package"
        Uninstall-CSharpPackageInternal
    }

    Install-CSharpPackageInternal $installPath
    Test-CSharpPackageInstallInternal $config
    Uninstall-CSharpPackageInternal
}

function Get-CSharpNupkg
{
    $nupkg = @(gci ([PackageManager]::RepoLocation) -Filter *.nupkg|where { $_.Name -NotLike "*.symbols.nupkg" -and $_.Name -notlike "*.snupkg" })

    if(!$nupkg)
    {
        throw "Could not find nupkg for project 'PrtgAPI'"
    }

    if($nupkg.Count -gt 1)
    {
        $str = "Found more than one nupkg for project 'PrtgAPI': "

        $names = $nupkg|select -ExpandProperty name|foreach { "'$_'" }

        $str += [string]::Join(", ", $names)

        throw $str
    }

    return $nupkg
}

function IsNuGetPackageInstalled($installPath)
{
    return (Get-Package PrtgAPI -Destination ([PackageManager]::PackageLocation) -ErrorAction SilentlyContinue) -or (Test-Path $installPath)
}

function Install-CSharpPackageInternal($installPath)
{
    Write-LogInfo "`t`t`t`tInstalling package from $([PackageManager]::RepoName)"

    Install-Package PrtgAPI -Source ([PackageManager]::RepoName) -ProviderName NuGet -Destination ([PackageManager]::PackageLocation) -SkipDependencies | Out-Null

    if(!(Test-Path $installPath))
    {
        throw "Package did not install successfully"
    }

    Write-LogInfo "Package successfully installed"
}

function Test-CSharpPackageInstallInternal($config)
{
    Write-LogInfo "`t`t`t`tTesting package"

    $version = GetVersion $config.IsCore

    $folders = gci "$([PackageManager]::PackageLocation)\PrtgAPI.$version\lib\net4*"

    foreach($folder in $folders)
    {
        $dll = Join-Path $folder.FullName "PrtgAPI.dll"

        $result = (powershell -command "Add-Type -Path '$dll'; [PrtgAPI.AuthMode]::Password")

        if($result -ne "Password")
        {
            throw "Module $($folders.Name) was not loaded successfully; attempt to use module returned '$result'"
        }
    }
}

function Uninstall-CSharpPackageInternal
{
    Get-Package PrtgAPI -Provider NuGet -Destination ([PackageManager]::PackageLocation) | Uninstall-Package | Out-Null

    if(Test-Path $installPath)
    {
        throw "Module did not uninstall properly"
    }
}

#endregion
#region PowerShell

function Process-PowerShellPackage($config)
{
    Write-LogSubHeader "`tProcessing PowerShell package"

    $config.Manager.InstallPowerShellRepository()

    if($env:APPVEYOR)
    {
        Update-ModuleManifest "$($config.PowerShellOutputDir)\PrtgAPI.psd1"
    }    

    $powershellArgs = @{
        OutputDir = $config.PowerShellOutputDir
        RepoManager = $config.Manager
        Configuration = $env:CONFIGURATION
        IsCore = $config.IsCore
    }

    New-PowerShellPackage @powershellArgs

    Test-PowerShellPackage $config

    Move-AppveyorPackages $config "_PowerShell"

    $config.Manager.UninstallPowerShellRepository()
}

function Test-PowerShellPackage
{
    Write-LogInfo "`t`tTesting package"

    $nupkg = Get-CSharpNupkg

    Extract-Package $nupkg {

        param($extractFolder)

        Test-PowerShellPackageDefinition $config $extractFolder
        Test-PowerShellPackageContents $config $extractFolder
    }

    Test-PowerShellPackageInstalls
}

function Test-PowerShellPackageDefinition($config, $extractFolder)
{
    Write-LogInfo "`t`t`tValidating package definition"

    $psd1Path = "$extractFolder\PrtgAPI.psd1"

    # Dynamic expression on RootModule checking the PSEdition cannot be parsed by
    # Import-PowerShellDataFile; as such, we need to remove this property

    $fullModule = "fullclr\PrtgAPI.PowerShell.dll"
    $coreModule = "coreclr\PrtgAPI.PowerShell.dll"

    $rootModule = $coreModule

    if($PSEdition -eq "Desktop")
    {
        $rootModule = $fullModule

        if(!(Test-Path $fullModule))
        {
            $rootModule = $coreModule
        }
    }

    Update-ModuleManifest $psd1Path -RootModule $rootModule

    $psd1 = Import-PowerShellDataFile $psd1Path

    $version = GetVersion $config.IsCore

    $expectedUrl = "https://github.com/lordmilko/PrtgAPI/releases/tag/v$version"

    if(!$psd1.PrivateData.PSData.ReleaseNotes.Contains($expectedUrl))
    {
        throw "Release notes did not contain correct release version. Expected notes to contain URL '$expectedUrl'. Release notes were '$($psd1.PrivateData.PSData.ReleaseNotes)'"
    }

    if($env:APPVEYOR)
    {
        if($psd1.CmdletsToExport -eq "*" -or !($psd1.CmdletsToExport -contains "Get-Sensor"))
        {
            throw "Module manifest was not updated to specify exported cmdlets"
        }

        if($psd1.AliasesToExport -eq "*" -or !($psd1.AliasesToExport -contains "Add-Trigger"))
        {
            throw "Module manifest was not updated to specify exported aliases"
        }
    }
}

function Test-PowerShellPackageContents($config, $extractFolder)
{
    $required = @(
        "fullclr\PrtgAPI.dll"
        "fullclr\PrtgAPI.PowerShell.dll"
        "Functions\New-Credential.ps1"
        "package\*"
        "_rels\*"
        "PrtgAPI.nuspec"
        "about_ChannelSettings.help.txt"
        "about_ObjectSettings.help.txt"
        "about_PrtgAPI.help.txt"
        "about_SensorParameters.help.txt"
        "about_SensorSettings.help.txt"
        "PrtgAPI.Format.ps1xml"
        "PrtgAPI.PowerShell.dll-Help.xml"
        "PrtgAPI.psd1"
        "PrtgAPI.psm1"
        "[Content_Types].xml"
    )

    if($config.IsCore)
    {
        if($env:CONFIGURATION -eq "Release")
        {
            $required += @(
                "coreclr\PrtgAPI.dll"
                "coreclr\PrtgAPI.PowerShell.dll"
            )
        }
        else
        {
            $debugVersion = Get-DebugTargetFramework

            if($debugVersion -notlike "net4*")
            {
                Write-LogInfo "`t`t`t`tUsing debug build '$debugVersion' for testing nupkg contents"

                $required = $required | foreach {

                    if($_ -like "fullclr*")
                    {
                        $_ -replace "fullclr","coreclr"
                    }
                    else
                    {
                        $_
                    }
                } | where { $_ -notlike "*-Help.xml" } # XmlDoc2CmdletDoc is .NET Framework only
            }
        }
    }

    Test-PackageContents $extractFolder $required
}

function Test-PowerShellPackageInstalls
{
    Write-LogInfo "`t`t`tInstalling Package"

    Hide-Module "PrtgAPI" {

        if(!(Install-Package PrtgAPI -Source ([PackageManager]::RepoName) -AllowClobber)) # TShell has a Get-Device cmdlet
        {
            throw "PrtgAPI did not install properly"
        }

        Write-LogInfo "`t`t`t`tTesting Package cmdlets"

        try
        {
            $exe = Get-PowerShellExecutable

            $resultCmdlet =   (& $exe -command '&{ import-module PrtgAPI; try { Get-Sensor } catch [exception] { $_.exception.message }}')
            $resultFunction = (& $exe -command '&{ import-module PrtgAPI; (New-Credential a b).ToString() }')
        }
        finally
        {
            Write-LogInfo "`t`t`t`tUninstalling Package"

            if(!(Uninstall-Package PrtgAPI))
            {
                throw "PrtgAPI did not uninstall properly"
            }
        }

        Write-LogInfo "`t`t`t`tValidating cmdlet output"

        if($resultCmdlet -ne "You are not connected to a PRTG Server. Please connect first using Connect-PrtgServer.")
        {
            throw $resultCmdlet
        }

        $str = [string]::Join("", $resultFunction)

        if($resultFunction -ne "System.Management.Automation.PSCredential")
        {
            throw $resultFunction
        }
    }
}

function Get-PowerShellExecutable
{
    $package = Get-Module PrtgAPI -ListAvailable

    if($PSEdition -eq "Core")
    {
        return "pwsh.exe"
    }
    else
    {
        $dllPath = Join-Path (Split-Path $package.Path -Parent) "fullclr"

        if(Test-Path $dllPath)
        {
            return "powershell.exe"
        }
        
        return "pwsh.exe"
    }
}

function Hide-Module($name, $script)
{
    $hidden = $false

    $module = Get-Module $name -ListAvailable

    try
    {
        if($module)
        {
            $hidden = $true

            Write-LogInfo "`t`t`t`tRenaming module info files"

            foreach($m in $module)
            {
                # Rename the module info file so the package manager doesn't find it even inside
                # the renamed folder

                $moduleInfo = $m.Path -replace "PrtgAPI.psd1","PSGetModuleInfo.xml"

                if(Test-Path $moduleInfo)
                {
                    Rename-Item $moduleInfo "PSGetModuleInfo_bak.xml"
                }
            }

            Write-LogInfo "`t`t`t`tRenaming module directories"

            foreach($m in $module)
            {
                $path = Get-ModuleFolder $m

                # Check if we haven't already renamed the folder as part of a previous module
                if(Test-Path $path)
                {
                    try
                    {
                        Rename-Item $path "PrtgAPI_bak"
                    }
                    catch
                    {
                        throw "$path could not be renamed to 'PrtgAPI_bak' properly: $($_.Exception.Message)"
                    }

                    if(Test-Path $path)
                    {
                        throw "$path did not rename properly"
                    }
                }
            }
        }

        Write-LogInfo "`t`t`t`tInvoking script"

        & $script
    }
    finally
    {
        if($hidden)
        {
            Write-LogInfo "`t`t`t`tRestoring module directories"

            foreach($m in $module)
            {
                $path = (split-path (Get-ModuleFolder $m) -parent) + "\PrtgAPI_bak"

                # Check if we haven't already renamed the folder as part of a previous module
                if(Test-Path $path)
                {
                    Rename-Item $path "PrtgAPI"
                }
            }

            Write-LogInfo "`t`t`t`tRestoring module info files"

            foreach($m in $module)
            {
                $moduleInfo = $m.Path -replace "PrtgAPI.psd1","PSGetModuleInfo_bak.xml"

                if(Test-Path $moduleInfo)
                {
                    Rename-Item $moduleInfo "PSGetModuleInfo.xml"
                }
            }
        }
    }
}

function Get-ModuleFolder($module)
{
    $path = $m.Path -replace "PrtgAPI.psd1",""

    $versionFolder = "$($m.Version)\"

    if($path.EndsWith($versionFolder))
    {
        $path = $path.Substring(0, $path.Length - $versionFolder.Length)
    }

    return $path
}

#endregion

function Move-AppveyorPackages($suffix, $config)
{
   if($env:APPVEYOR)
   {
        if(!$suffix)
        {
            $suffix = ""
        }

        Move-Packages $suffix $config.SolutionRoot | Out-Null
    }
    else
    {
        Write-LogInfo "`t`t`t`tClearing repo (not running under Appveyor)"
        Clear-Repo
    } 
}

function Clear-Repo
{
    gci -recurse ([PackageManager]::RepoLocation)|remove-item -Recurse -Force
}

function Extract-Package($package, $script)
{
    $originalExtension = $package.Extension
    $newName = $package.Name -replace $originalExtension,".zip"

    $extractFolder = $package.FullName -replace $package.Extension,""

    $newItem = $null

    try
    {
        $newItem = Rename-Item -Path $package.FullName -NewName $newName -PassThru
        Expand-Archive $newItem.FullName $extractFolder

        & $script $extractFolder
    }
    finally
    {
        Remove-Item $extractFolder -Recurse -Force
        Rename-Item $newItem.FullName $package.Name
    }
}

function Test-PackageContents($folder, $required)
{
    Write-LogInfo "`t`t`tValidating package contents"

    $pathWithoutTrailingSlash = $folder.TrimEnd("\", "/")

    $existing = gci $folder -Recurse|foreach {
        [PSCustomObject]@{
            Name = $_.fullname.substring($pathWithoutTrailingSlash.length + 1)
            IsFolder = $_.PSIsContainer
        }
    }

    $found = @()
    $illegal = @()

    foreach($item in $existing)
    {
        if($item.IsFolder)
        {
            # Do we have a folder that contains a wildcard that matches this folder? (e.g. packages\* covers packages\foo)
            $match = $required | where { $item.Name -like $_ }

            if(!$match)
            {
                # There isn't a wildcard that covers this folder, but if there are actually any items contained under this folder
                # then transitively this folder is allowed

                $match = $required | where { $_ -like "$($item.Name)\*" }

                # If there is a match, we don't care - we don't whitelist empty folders, so we'll leave it up to the file processing block
                # to decide whether the required files have been found or not
                if(!$match)
                {
                    $illegal += $item.Name
                }
            }
            else
            {
                # Add our wildcard folder (e.g. packages\*)
                $found += $match
            }
        }
        else
        {
            # If there isnt a required item that case insensitively matches a file that appears
            # to exist, then that file must be "extra" and is therefore considered illegal
            $match = $required | where { $_ -eq $item.Name }

            if(!$match)
            {
                # We don't have a direct matchm however maybe we have a folder that contains a wildcard
                # that matches this file (e.g. packages\* covers packages\foo.txt)
                $match = $required | where { $item.Name -like $_ }
            }

            if(!$match)
            {
                $illegal += $item.Name
            }
            else
            {
                $found += $match
            }
        }
    }

    if($illegal)
    {
        $str = ($illegal | Sort-Object | foreach { "'$_'" }) -join "`n"
        throw "Package contained illegal items:`n$str"
    }

    $missing = $required | where { $_ -notin $found }

    if($missing)
    {
        $str = ($missing | Sort-Object | foreach { "'$_'" }) -join "`n"
        throw "Package is missing required items:`n$str"
    }
}