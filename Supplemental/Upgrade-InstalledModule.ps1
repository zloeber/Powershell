#Requires -Version 5
Function Upgrade-InstalledModule {
    <#
    .SYNOPSIS
        A small wrapper for PowerShellGet to upgrade installed modules.
    .DESCRIPTION
        A small wrapper for PowerShellGet to upgrade installed modules.
    .PARAMETER ModuleName
        Show modules which would get upgraded.
    .PARAMETER Silent
        Do not show progress bar.
    .PARAMETER Force
        Force an upgrade without any confirmation prompts.
    .EXAMPLE
        PS> Upgrade-InstalledModule -Force

        Updates modules installed via PowerShellGet. Shows a progress bar.
    .NOTES
        Author: Zachary Loeber
        Site: http://www.the-little-things.net/
        Requires: Powershell 5.0

        Version History
        1.0.0 - Initial release
    #>

    [CmdletBinding( SupportsShouldProcess=$True, ConfirmImpact='Medium' )]
    Param (
        [Parameter(HelpMessage = 'Name of a module to check and remove old versions of.')]
        [string]$ModuleName = '*',
        [Parameter(HelpMessage = 'Force upgrade modules without confirmation.')]
        [Switch]$Force,
        [Parameter(HelpMessage = 'Do not write progress.')]
        [Switch]$Silent
    )
    Begin {
        try {
            Import-Module PowerShellGet
        }
        catch {
            Write-Warning 'Unable to load PowerShellGet. This script only works with PowerShell 5 and greater.'
            return
        }

        $YesToAll = $false
        $NoToAll = $false
    }

    Process {
        $Count = 0

        if (-not $Silent) {
            Write-Progress -Activity "Retrieving installed modules" -PercentComplete 1 -Status "Processing"
        }
        $InstalledModules = @(Get-InstalledModule $ModuleName)
        $TotalMods = $InstalledModules.Count
        ForEach ($Mod in (Get-InstalledModule $ModuleName)) {
            $count++
            if (-not $Silent) {
                $PercentComplete = [math]::Round((100*($count/$TotalMods)),0)
                Write-Progress -Activity "Processing Module $($Mod.Name)" -PercentComplete $PercentComplete -Status "Checking Module For Updates"
            }
            $OnlineModule = Find-Module $Mod.Name
            if ($OnlineModule.Version -gt $Mod.Version) {
                if ($pscmdlet.ShouldProcess("Upgraded module $($Mod.Name) from $($Mod.Version.ToString()) to $($OnlineModule.Version.ToString())", 
                "Upgrade module $($Mod.Name) from $($Mod.Version.ToString()) to $($OnlineModule.Version.ToString())?",
                "Upgrading module $($Mod.Name)")) {
                    if($Force -Or $PSCmdlet.ShouldContinue("Are you REALLY sure you want to upgrade '$($Mod.Name)'?",
                    "Upgrading module '$($Mod.Name)'",
                    [ref]$YesToAll,
                    [ref]$NotoAll)) {
                        if (-not $Silent) {
                            Write-Progress -Activity "Upgrading Module $($Mod.Name)" -PercentComplete $PercentComplete -Status "Upgrading Module"
                        }
                        Update-Module $Mod.Name -Force -Confirm:$false
                    }
                }
            }
        }
    }
}