#Requires -Version 5
function Remove-OldModule {
    <#
    .SYNOPSIS
        A small wrapper for PowerShellGet to remove all older installed modules.
    .DESCRIPTION
        A small wrapper for PowerShellGet to remove all older installed modules.
    .PARAMETER ModuleName
        Name of a module to check and remove old versions of. Default is all modules ('*')
    .PARAMETER Silent
        Do not show progress bar.
    .PARAMETER Force
        Force removal without any confirmation prompts.
    .EXAMPLE
        PS> Remove-OldModules

        Removes old modules installed via PowerShellGet.

    .EXAMPLE
        PS> Remove-OldModules -whatif

        Shows what old modules might be removed via PowerShellGet.

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

        $ModulesToRemove = @()
    }

    Process {
        $Count = 0

        Get-InstalledModule $ModuleName | ForEach-Object {
            $Count ++
            if (-not $Silent) {
                Write-Progress -Activity "Calculating removable modules" -PercentComplete ($Count % 100) -Status "Calculating"
            }
            $ThisModule = Get-InstalledModule $_.Name -AllVersions | Sort-Object Version
            If ($ThisModule.count -gt 1) {
                $ModulesToRemove += $ThisModule | Select-Object -First ($ThisModule.count - 1)
            }
        }

        $Count = 0
        $TotalMods = $ModulesToRemove.Count
        ForEach ($Mod in $ModulesToRemove) {
            $Ver = $Mod.Version.ToString()
            $Count++

            if ($pscmdlet.ShouldProcess("Remove module $($Mod.Name) - $($Ver)", 
            "Remove module $($Mod.Name) - $($Ver)?",
            "Removing module $($Mod.Name) - $($Ver)")) {
                if($Force -Or $PSCmdlet.ShouldContinue("Are you REALLY sure you want to remove '$($Mod.Name) - $($Ver) '?",
                "Removing module '$($Mod.Name) - $($Ver)'",
                [ref]$YesToAll,
                [ref]$NotoAll)) {
                    if (-not $Silent) {
                        $PercentComplete = [math]::Round((100*($Count/$TotalMods)),0)
                        Write-Progress -Activity "Removing Old Module $($Mod.Name) (version: $($Ver))" -PercentComplete $PercentComplete -Status "Removing..."
                    }
                    Uninstall-Module $Mod.Name -RequiredVersion $Ver -Force -Confirm:$false
                }
            }
        }
    }
}