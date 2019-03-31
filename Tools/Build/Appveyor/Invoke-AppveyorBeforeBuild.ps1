function Invoke-AppveyorBeforeBuild
{
    param(
        [Parameter(Position = 0)]
        [switch]$IsCore = $script:APPEYOR_BUILD_CORE
    )

    if($env:APPVEYOR)
    {
        $hash = (git log -1 --format=format:"%H").Substring(0, 8)

        Update-AppveyorBuild -Version "Build $hash"
    }

    Write-LogHeader "Restoring NuGet Packages (Core: $IsCore)"

    if($IsCore)
    {
        throw ".NET Core is not currently supported"
    }
    else
    {
        Invoke-Process { nuget restore $env:APPVEYOR_BUILD_FOLDER\Dummy.sln }
    }
}