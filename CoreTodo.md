## Project
-what should the prtgapi.tests output path be?
-why are the bin folders release etc all lowercase?

## CI
-appveyor zip file shouldnt include all target folders, just the special final prtgapi folder used for the merged module
-make travis ignore the same files appveyor ignores, e.g. readme, etc
-chmod +x prtgapi.sh on windows and linux somehow
-on all ci test should verify the line endings of prtgapi.sh and check it has +x
-appveyor needs to validate nupkg can be imported into both powershell and pwsh

## PowerShell
-cant launch prtgapi powershell core launch setting on release build. need to make sure all 3 launch options work in debug and release
-does powershellstandard.library explode when doing unit tests or not? cos we're currently using it again

## Tests

### PrtgAPI
-all required dependencies are installed on a fresh machine with empty nuget cache
-a failed mstest stops the build in appveyor
-a failed mstest stops the build in travis
-a failed pester stops the build in appveyor
-a failed pester stops the build in travis

### PrtgAPI.PowerShell
-can debug project and automatically import correct prtgapi/prtgapi.tests modules
-make sure typing a powershell command automatically imports the module
-test using the .net framework dll in pwsh.exe
-Test doing ipmo in PowerShell Core. Seems to copy PrtgAPI.PowerShell to %temp% but doesn't copy PrtgAPI.dll too?
-check git doesn't mess up the line endings of prtgapi.sh
-test prtgapi.sh - in existing console, run from folder, mac and linux
-what if the rootmodule path is always in the prtgapi output folder, and msbuild doesnt know about fullclr/coreclr crap.
 then, when we make packages we do the reshuffling and update the rootmodule path
 new-prtgpackage/new-appveyorpackage should create the zip folder for redistribution and move it to the root
 anything that clears things up needs to remove zip files from the root (but not subfolders)
 new-appveyormodule doesnt need to update the rootmodule manually to do its shenanigans anymore
 ALL OF THIS RESTS ON THE ASSUMPTION that we can do reflection against powershellstandard.library ok
 and that we can run these netstandard2.0 powershell tests in visual studio
 init.ps1 should consider a standard build to be compatible with either core or desktop
 packaging script should copy powershell output dir, create zip and move it before we start removing files like the cmd/sh files
 that we'd want in the zip file. files we dont want in EITHER though should be removed (is there anything like that though?)
 but also...even if we can use netstandard2.0 in windows powershell, unit test project is still gonna be .net core, so we
 cant import it
 todo: need to make init.ps1 smarter about finding "compatible versions" for a given targetframework when the powershell/unit test projects dont have the same version
 if we do remove coreclr/fullclr stuff, need to update init.ps1 as well...in fact, really need to search everywhere for references to them 
 in the new-appveyorpackage need to ensure the import test is run in both powershell.exe and pwsh.exe when iscore is true

## Appveyor (Dummy)
-need to show more exception details when an appveyor crash occurs
-need to re-run all the prtgapi.build tests with/without the chocolatey bin folder there
-duplicate "setting appveyor version" message
-how do you know when the appveyor /logger + --logger are working? with msbuild
-dont re-report skipping installing dependency whenever we verify if its installed. only report if we had to install it?
-maybe have a .gitattributes file that sets all .sh files to be lf?

## Finalization
-Measure compile perf across targets
-xmldoc in nuget works
-test installing into different solution versions - .net standard, core and full
-sourcelink works - .net standard, core and full
-test appveyor logger works when executing core exe's (i.e. the one referenced by the --logger parameter)
-go through all /> space space and replace with /> space where appropriate - after all commits are done

----------------------

# Done (I Think)

## Project
    -unit test that says we dont use \r\n anywhere
    -set default project in v17
    -powershell test that says nobody uses `r`n
    -whenever I create a new file it's added as compile remove
    -when prtgapi.powershell is being compiled for release, its turning into a netcoreapp 2.1.7 or something, instead of a .net 4.6.1
    -crashed compiling release for powershell dll. xmldoc2cmdletdoc (4.5.2) tried to load prtgapi.powershell? (4.6.1) (related to the above)
    -prtgcov failing on connect-prtgserver.tests.ps1. tests pass, but powershelltools testadapter throws nullreferenceexception when showing vstest output

## CI
    -need to make failed dotnet build display the failure reason properly
    -dotnet build -p:EnableSourceLink=true still failing. fails first try, succeeds second
    -have a test in the build script that asserts the prtgapi.dll version is the same as the prtgapi.powershell.dll version
    -osx travis build log is going to my build folder rather than tmp
    -os retrieval warning upon starting travis.tests.ps1
    -merge powershell output together when publishing - net461/netstandard2.0
    -upon creating the nuget package need to also validate now that it has the fullclr/coreclr folders, and they both only have the two dlls in them

## PowerShell
    -update all the get-help -online paths based on the section name changes i made
    -powershell version.tt seems to be running before c# tt's run, resulting in the version being 1 off
    -compiling prtgapi.powershell on osx gives us errors when we try and copy our files to the output folder
    -goprtg color text not working on osx
    -simulate-prtgci -appveyor build followed by simulate-prtgci -appveyor build -iscore:$false causes xmldoc2cmdletdoc to explode without doing a full clean


## Tests

### PrtgAPI
    -compile dependency on codegenerator. visual studio and dotnet.exe
    -change assemblyfileversion/assemblyversion/nuget version on release

### PrtgAPI.PowerShell
    -version.tt/prtgapi.psd1 updates on release
    -resources folder/functions are copied to correct output folder

### PrtgAPI.Tests.UnitTests

----

unsorted

notes from appveyor.tests.ps1:
#todo: make sure this and the travis tests can run; we might need to manually import the write-log file
#todo: once everythings all done, re-run the prtgapi.build integration tests and make sure they all succeed
#todo: why does running invoke-pester on the unit test powershell folder result in a failure in get-prtgversion 

<#
    #todo: test get-prtghelp on linux. in fact, really test every cmdlet manually on linux/macos
    #once we implement new-prtgpackage tests

        Test
            need to test powershell in both desktop and core. need to have a test runner that kicks things off and verifies we're running under the right one
        #>
#todo: we should be showing a progress bar for everything the build module does...and only show text on verbose

    //todo: 
    #todo: get-sensorhistory is failing on linux because powershell resources arent being outputted to correct output dir?
    #todo: when these integration tests about executing invoke-prtgtest/get-prtgtestresult have failed tests, the whole thing should fail?
    # the travis test doesnt result in failure after any failed tests. need to verify both c#/powershell failed tests in appveyor/travis result in the whole thing failing

    tags exists in objectproperty, but our documentation says you cant modify it...so maybe we need to update the set-objectproperty.container.tests and about_objectsettings
    enable parallel mstest2; and how does this interactive with coverage?