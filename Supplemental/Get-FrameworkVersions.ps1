﻿function Get-FrameworkVersions {
# Copied from http://blog.smoothfriction.nl/archive/2011/01/18/powershell-detecting-installed-net-versions.aspx
    function Test-Key([string]$path, [string]$key) {
        if ( -not (Test-Path $path) ) { return $false }
        if ( (Get-ItemProperty $path).$key -eq $null ) { return $false }
        return $true
    }

    $installedFrameworks = @()
    if(Test-Key "HKLM:\Software\Microsoft\.NETFramework\Policy\v1.0" "3705") { $installedFrameworks += "1.0" }
    if(Test-Key "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v1.1.4322" "Install") { $installedFrameworks += "1.1" }
    if(Test-Key "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v2.0.50727" "Install") { $installedFrameworks += "2.0" }
    if(Test-Key "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v3.0\Setup" "InstallSuccess") { $installedFrameworks += "3.0" }
    if(Test-Key "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v3.5" "Install") { $installedFrameworks += "3.5" }
    if(Test-Key "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Client" "Install") { 
        $installedFrameworks += "4.0c"
        if ((Get-ItemProperty "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Client").Version -like "4.5*") { 
            $installedFrameworks += "4.5c"
        }
    }
    if (Test-Key "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Full" "Install") {
        [int32]$intRelease = (Get-ItemProperty "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Full").Release
        switch ($intRelease) {
            "378389" { $installedFrameworks += "4.5" }
            "378675" { $installedFrameworks += "4.5.1" }
            "378758" { $installedFrameworks += "4.5.1" }
        }
    }

    return $installedFrameworks
}
