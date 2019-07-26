function Install-CIDependency
{
    [CmdletBinding()]
    param(
        [string[]]$Name,
        [switch]$Log = $true
    )

    Get-CallerPreference $PSCmdlet $ExecutionContext.SessionState

    $nameInternal = $Name | foreach {
        if($_ -eq "OpenCover" -or $_ -eq "ReportGenerator")
        {
            return $_ += ".portable"
        }

        return $_
    }

    $dependencies = Get-CIDependency

    if($Name)
    {
        $dependencies = $dependencies | where { $_["Name"] -in $nameInternal }
    }

    if(!$dependencies)
    {
        throw "Could not find dependency '$dependencies'"
    }

    $silentSkip = $false

    if($Name)
    {
        $silentSkip = $true
    }

    foreach($dependency in $dependencies)
    {
        Install-Dependency @dependency -Log:$Log -SilentSkip:$silentSkip
    }
}