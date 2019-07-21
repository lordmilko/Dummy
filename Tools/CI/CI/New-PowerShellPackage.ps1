function New-PowerShellPackage
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputDir,

        [Parameter(Mandatory = $true)]
        $RepoManager,

        [Parameter(Mandatory = $true)]
        [string]$Configuration,

        [Parameter(Mandatory = $true)]
        [switch]$IsCore
    )

    if($Configuration -eq "Release" -and $IsCore)
    {
        # When we're building Release, instead of copying the normal folder we copied two folders up so we
        # have both the net452 and netstandard2.0 folders so we can merge them together
        $OutputDir = Join-Path $OutputDir "..\.."
    }

    $RepoManager.WithTempCopy(
        $OutputDir,
        {
            param($tempPath)

            $list = @(
                "*.cmd"
                "*.pdb"
                "*.sh"
                "*.json"
                "PrtgAPI.xml"
                "PrtgAPI.PowerShell.xml"
            )

            gci $tempPath -Include $list -Recurse | Remove-Item -Force

            if($IsCore)
            {
                if($Configuration -eq "Release" -and $IsCore)
                {
                    if(Test-IsWindows)
                    {
                        $coreclr = Join-Path $tempPath "netstandard2.0\PrtgAPI\coreclr"
                        $net452PrtgAPI = Join-Path $tempPath "net452\PrtgAPI"

                        Write-LogInfo "`t`tMerging coreclr/fullclr builds"

                        Move-Item $coreclr $net452PrtgAPI

                        $tempPath = $net452PrtgAPI
                    }
                    else
                    {
                        Write-LogError "Skipping merging coreclr/fullclr builds as not running on Windows"
                        $tempPath = Join-Path $tempPath "netcoreapp2.1\PrtgAPI"
                    }
                }
            }
            else
            {
                $helpXml = Join-Path $tempPath "fullclr\PrtgAPI.PowerShell.dll-Help.xml"

                Move-Item $helpXml $tempPath
            }

            Write-LogInfo "`t`tPublishing module to $([PackageManager]::RepoName)"

            $expr = "Publish-Module -Path '$tempPath' -Repository $([PackageManager]::RepoName) -WarningAction SilentlyContinue"

            # PowerShell Core currently has a bug wherein attempting to execute Start-Process -Wait doesn't work on Windows 7.
            # Work around this by diverting to Windows PowerShell
            if($PSEdition -eq "Core" -and (Test-IsWindows))
            {
                Write-Verbose "Executing powershell -command '$expr'"
                # Clear the PSModulePath to prevent PowerShell Core specific directories contaminating Publish-Module's inner cmdlet lookups
                powershell -command "`$env:PSModulePath = '$env:ProgramFiles\WindowsPowerShell\Modules;$env:SystemRoot\WindowsPowerShell\v1.0\Modules'; $expr"
            }
            else
            {
                Write-Verbose "Executing '$expr'"
                Invoke-Expression $expr
            }
        }
    )
}