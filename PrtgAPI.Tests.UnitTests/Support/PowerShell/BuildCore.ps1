if(!$skipBuildModule)
{
    ipmo $PSScriptRoot\..\..\..\Tools\PrtgAPI.Build
}

ipmo $PSScriptRoot\..\..\..\Tools\CI\ci.psm1

function WithoutTestDrive($script)
{
    $drive = Get-PSDrive TestDrive -Scope Global

    $drive | Remove-PSDrive -Force
    Remove-Variable $drive.Name -Scope Global -Force

    try
    {
        & $script
    }
    finally
    {
        New-PSDrive $drive.Name -PSProvider $drive.Provider -Root $drive.Root -Scope Global
        New-Variable $drive.Name -Scope Global -Value $drive.Root
    }
}

function Get-SolutionRoot
{
    return Resolve-Path "$PSScriptRoot\..\..\.."
}

function Get-ProcessTree
{
    $all = gwmi win32_process

    $list = @()

    while($true)
    {
        if($me -eq $null)
        {
            if($list.Count -eq 0)
            {
                $me = $all|where ProcessID -eq $pid
            }
            else
            {
                break
            }
        }
        else
        {
            $me = $all|where ProcessID -eq $me.ParentProcessID
        }

        $list += $me
    }

    return $list
}

function IsChildOf
{
    param(
        [string[]]$Name
    )

    if(Test-IsWindows)
    {
        $tree = Get-ProcessTree

        foreach($item in $tree)
        {
            foreach($n in $Name)
            {
                if($n -eq $item.Name)
                {
                    return $true
                }
            }
        }

        return $false
    }
    else
    {
        return $false
    }
}

function SkipBuildTest
{
    IsChildOf devenv.exe
}