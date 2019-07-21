# Tools

This folder contains tools utilized by the PrtgAPI project. These items include:

* **CI** - Common CI code, as well as Appveyor and Travis modules used when running under each respective system
* **PrtgAPI.Build** - module for managing all aspects of the PrtgAPI development lifecycle. Open using `build.cmd` and `build.sh` in the repo root
* **PowerShell.TestAdapter** - `netstandard2.0` port of [PowerShellTools.TestAdapter](https://github.com/adamdriscoll/poshtools/tree/dev/PowerShellTools.TestAdapter) that is compatible with the version of `vstest.console` shipped with Visual Studio 2019/nuget.org. Used when calculating PowerShell code coverage
* **PrtgAPI.CodeGenerator** - module for generating code from XML documents. Used by PrtgAPI to generate synchronous, asynchronous, streaming and `CancellationToken` based overloads on `PrtgClient`