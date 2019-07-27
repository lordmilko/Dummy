function Invoke-TravisInstall
{
    Write-Host "called install!"
    Install-CIDependency Pester -Log
}