function Format-ScriptRemoveSuperfluousSpaces {
    <#
        .SYNOPSIS
        Removes superfluous spaces at the end of individual lines of code.
        .DESCRIPTION
        Removes superfluous spaces at the end of individual lines of code.
        .PARAMETER Code
        Multiple lines of code to analyze. Ignores all herestrings.

        .EXAMPLE
        $testfile = 'C:\temp\test.ps1'
        $test = Get-Content $testfile -raw
        $test | Format-ScriptRemoveSuperfluousSpaces | Clip
        
        Description
        -----------
        Removes all additional spaces and whitespace from the end of every non-herestring in C:\temp\test.ps1

        .NOTES
        Author: Zachary Loeber
        Site: http://www.the-little-things.net/

        1.0.0 - Initial release
    #>
    [CmdletBinding()]
    param(
        [parameter(Position=0, ValueFromPipeline=$true, HelpMessage='Lines of code to process.')]
        [string[]]$Code
    )
    begin {
        $Codeblock = @()
        $FunctionName = $MyInvocation.MyCommand.Name
        Write-Verbose "$($FunctionName): Begin."
    }
    process {
        $Codeblock += ($Code -split "`r`n")
    }
    end {
        try {
            $KindLines = $Codeblock | Format-ScriptGetKindLines -Kind "HereString*"
        }
        catch {
            throw
        }
        $currline = 0
        foreach ($codeline in ($Codeblock -split "`r`n")) {
            $currline++
            $isherestringline = $false
            $KindLines | Foreach {
                if (($currline -ge $_.Start) -and ($currline -le $_.End)) {
                    $isherestringline = $true
                }
            }
            if ($isherestringline -eq $true) {
                $codeline
            }
            else {
                $codeline.TrimEnd()
            }
        }
        Write-Verbose "$($FunctionName): End."
    }
}