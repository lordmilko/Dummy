function Startup($type)
{
    InitializeUnitTestModules
    $global:tester = SetState $type $null
}

function InitializeUnitTestModules
{
    InitializeModules "PrtgAPI.Tests.UnitTests" $PSScriptRoot

    $accelerators = [PowerShell].Assembly.GetType("System.Management.Automation.TypeAccelerators")
    $accelerators::Add("Request", [PrtgAPI.Tests.UnitTests.Support.UnitRequest])
    $accelerators::Add("UrlFlag", [PrtgAPI.Tests.UnitTests.Support.UrlFlag])
}

function Shutdown
{
    $global:tester.SetPrtgSessionState([PrtgAPI.PrtgClient]$null)
    $global:tester = $null
}

function InitializeModules($testProject, $scriptRoot)
{
    $modules = Get-Module prtgapi,$testProject
    
    if($modules.Count -ne 2)
    {
        ImportModules $testProject $scriptRoot
    }

    $global:ErrorActionPreference = "Stop"
}

function ImportModules
{
    param(
        $testProjectName, # e.g. PrtgAPI.Tests.PowerShell
        $scriptRoot       # e.g. C:\PrtgAPI\PrtgAPI.Tests.UnitTests\Support\PowerShell
    )

    $analysis = AnalyzeTestProject $testProjectName $scriptRoot

    $validCandidates = ReduceCandidates $analysis.Candidates

    $selectedCandidate = $validCandidates|Sort-Object LastWriteTime -Descending | select -First 1

    Import-Module $selectedCandidate.PrtgAPIPath
    Import-Module $selectedCandidate.TestProjectDll
}

function AnalyzeTestProject($testProjectName, $scriptRoot)
{
    $solutionFolderEndIndex = $scriptRoot.ToLower().IndexOf($testProjectName.ToLower())

    if($solutionFolderEndIndex -eq -1)
    {
        throw "Could not identify solution folder"
    }

    $solutionFolder = $scriptRoot.Substring(0, $solutionFolderEndIndex)                                  # e.g. C:\PrtgAPI\
    $testProjectFolder = $scriptRoot.Substring(0, $solutionFolderEndIndex + $testProjectName.Length + 1) # e.g. C:\PrtgAPI\PrtgAPI.Tests.UnitTests

    $unitTestFolderCandidates = gci (Join-Path $testProjectFolder "bin") -Recurse "$testProjectName.dll" # e.g. get all folders containing PrtgAPI.Tests.UnitTests.dll

    $candidates = @()

    Write-Verbose "Enumerating build candidates"

    Write-Verbose "############################################################################"

    foreach($candidate in $unitTestFolderCandidates)
    {
        $obj = [PSCustomObject]@{
            Folder             = $candidate.Directory                                          # e.g. Debug (2015) or net461 (2017)
            FolderSuffix       = $candidate.DirectoryName.Substring($testProjectFolder.Length) # e.g. bin\Debug (2015) or bin\Debug\net461 (2017)
            TestProjectDll     = Join-Path $candidate.DirectoryName "$testProjectName.dll"
            FolderPath         = $candidate.DirectoryName                                      # e.g. C:\PrtgAPI\PrtgAPI.Tests.UnitTests\bin\Debug\net461
            Configuration      = $null                                                         # e.g. Debug
            Edition            = $null                                                         # e.g. Desktop or Core
            LastWriteTime      = $candidate.LastWriteTime
            PrtgAPIPath        = $null
        }

        if($obj.Folder.Name -eq "PrtgAPI.Tests")
        {
            $obj.Folder = $obj.Folder.Parent
            $obj.FolderSuffix = $obj.FolderSuffix.Substring(0, $obj.FolderSuffix.Length - "PrtgAPI.Tests".Length - 1) # Get rid of \PrtgAPI.Tests
        }

        #todo: support .net standard powershell dll with .net core unit test dll

        if($obj.Folder.Name.StartsWith("net"))
        {
            $obj.Configuration = $obj.Folder.Parent.Name

            # No point supporting .NET Standard as we're looking for unit test projects - project is either '
            if($obj.Folder.Name.StartsWith("netcore"))
            {
                $obj.Edition = "Core"
            }
            else
            {
                $obj.Edition = "Desktop"
            }
        }
        else
        {
            $obj.Configuration = $obj.Folder.Name
            $obj.Edition = "Desktop"
        }

        $suffix = $obj.FolderSuffix

        if($obj.Edition -eq "Core")
        {
            $suffix -replace "netcoreapp2.1","netstandard2.0"
        }

        $obj.PrtgAPIPath = Join-PathEx $solutionFolder,"PrtgAPI.PowerShell",$suffix,"PrtgAPI"

        foreach($property in $obj.PSObject.Properties)
        {
            Write-Verbose "$($property.Name): $($obj.$($property.Name))"
        }

        Write-Verbose "############################################################################"

        #Write-Verbose $obj

        $candidates += $obj
    }

    $analysis = [PSCustomObject]@{
        SolutionDir = $solutionFolder
        TestProjectDir = $testProjectFolder
        Candidates = $candidates
    }

    Write-Verbose "SolutionDir: $solutionFolder"
    Write-Verbose "TestProjectDir: $testProjectFolder"

    Write-Verbose "############################################################################"

    return $analysis
}

function ReduceCandidates($candidates)
{
    $newCandidates = $candidates| where {
        if(!(Test-Path $_.PrtgAPIPath))
        {
            $alternatePrtgAPIPath = $null

            if($_.PrtgAPIPath -like "*net461*")
            {
                $alternatePrtgAPIPath = $_.PrtgAPIPath -replace "net461","net452"
            }
            elseif($_.PrtgAPIPath -like "*netcoreapp*")
            {
                $alternatePrtgAPIPath = $_.PrtgAPIPath -replace "netcoreapp.\..","netstandard2.0"
            }

            if($alternatePrtgAPIPath -ne $null -and (Test-Path $alternatePrtgAPIPath))
            {
                $_.PrtgAPIPath = $alternatePrtgAPIPath
            }
            else
            {
                Write-Verbose "Eliminating candidate '$($_.TestProjectDll)' as folder '$($_.PrtgAPIPath)' does not exist"
                return $false
            }
            
        }

        $subFolder = "fullclr"

        if($_.Edition -eq "Core")
        {
            $subFolder = "coreclr"
        }

        $dll = Join-PathEx $_.PrtgAPIPath,$subFolder,"PrtgAPI.PowerShell.dll"

        if(!(Test-Path $dll))
        {
            Write-Verbose "Eliminating candidate DLL '$dll' as file does not exist"
            return $false
        }

        if($PSEdition -ne $_.Edition)
        {
            Write-Verbose "Eliminating candidate '$($_.TestProjectDll)' as candidate edition '$_.Edition' does not match required edition '$PSEdition'"
            return $false
        }

        return $true
    }

    if(!$newCandidates)
    {
        throw "Could not find any valid build candidates for PowerShell $($PSEdition)"
    }

    return $newCandidates
}

function Join-PathEx
{
    param(
        [string[]]$arr
    )

    $result = $null

    foreach($str in $arr)
    {
        if($result -ne $null)
        {
            $result = Join-Path $result $str
        }
        else
        {
            $result = $str
        }
    }

    $result
}

function SetState($objectType, $items)
{
    $tester = $null

    if(!$items)
    {
        $tester = (New-Object PrtgAPI.Tests.UnitTests.ObjectData.$($objectType)Tests)
    }
    else
    {
        $tester = New-Object "PrtgAPI.Tests.UnitTests.ObjectData.$($objectType)Tests" -ArgumentList ($items)
    }
    
    $tester.SetPrtgSessionState()

    return $tester
}

function GetSensorTypeContexts($filePath, $allowEnhancedDescription)
{
    $contextNames = GetScriptContexts $filePath | foreach { $_.ToLower() }

    $sensorTypes = [enum]::GetNames([PrtgAPI.SensorType]) | foreach { $_.ToLower() }

    $excludedTypes = @("SqlServerDb") | foreach { $_.ToLower() }

    $sensorTypes = $sensorTypes|where { $_ -notin $excludedTypes }

    $missingTypes = $null

    if($allowEnhancedDescription)
    {
        $missingTypes = @()

        foreach($type in $sensorTypes)
        {
            $found = $false

            foreach($context in $contextNames)
            {
                if($context -eq $type -or $context -like "$($type):*")
                {
                    $found = $true
                    break
                }
            }

            if(!$found)
            {
                $missingTypes += $type
            }
        }
    }
    else
    {
        $missingTypes = $sensorTypes|where { $_ -notin $contextNames }
    }

    if($missingTypes)
    {
        $str = $missingTypes -join ", "

        throw "Missing contexts/tests for the following sensor types: $str"
    }
}

function GetScriptContexts($filePath)
{
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $filePath,
        [ref]$null,
        [ref]$null
    )

    $commands = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)

    $contexts = $commands|where {
        $_.CommandElements.Count -ge 2 -and $_.CommandElements[0].Value -eq "Context"
    }

    $contextNames = $contexts | foreach {
        $_.FindAll({ $args[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $args[0].StringConstantType -ne "BareWord" }, $false) | select -ExpandProperty Value
    }

    return $contextNames
}
