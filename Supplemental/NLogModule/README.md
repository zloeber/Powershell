#NLogModule

This is a set of wrapper functions for nlog.dll and proxy functions for the following built in cmdlets:

* Write-Host
* Write-Output
* Write-Warning
* Write-Verbose
* Write-Debug
* Write-Error

##Description
The nlog.dll was built for .net 3.5. The exported functions can be used as is for your own logging purposes but for the proxy functions to work you will need to register the module variables. Be certain to unregister them afterwards (or unload the module entirely) to prevent other script output from ending up in your log.

**Example**

    Register-NLog -FileName 'c:\temp\debug.log' -LoggerName 'MyApp'
    Write-Verbose 'My verbose message'
    Write-Warning 'This is a warning! Oh No!'
    Write-Host -ForgroundColor:Green "Writing to the host!"
    UnRegister-NLog

##Other Information
**Author:** Zachary Loeber

**Website:** www.the-little-things.net

**Github:** https://github.com/zloeber/Powershells

##Other credits:
[https://github.com/NLog/NLog](https://github.com/NLog/NLog)

[Original Functions](http://12.mayjestic.net/index.php/20150205/powershell-logging-interface/)
