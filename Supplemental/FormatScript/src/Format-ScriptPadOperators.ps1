function Format-ScriptPadOperatorsOld {
    <#
    .SYNOPSIS
    Pads powershell operators with single spaces.
    .DESCRIPTION
    Pads powershell operators with single spaces.
    .PARAMETER Code
    Multiple lines of code to analyze
    .PARAMETER Operators
    Array of operator types to look for to pad. Defaults to +=,-=, and =.
    .EXAMPLE
    TBD

    Description
    -----------
    TBD

    .NOTES
    Author: Zachary Loeber
    Site: http://www.the-little-things.net/

    1.0.0 - 01/25/2015
    - Initial release
    #>
    [CmdletBinding()]
    param(
        [parameter(Position=0, ValueFromPipeline=$true, HelpMessage='Lines of code to look for and condense.')]
        [string[]]$Code,
        [parameter(Position=1, HelpMessage='Operator(s) to validate single spaces are around.')]
        [string[]]$Operators = @('+=','-=','=')
    )
    begin {
        $Codeblock = @()
        $ops = @()
        $Operators | foreach {$ops += [Regex]::Escape($_)}
        $Output = @()
        $LineCount = 0
        #$regex = '\w*((\s*)(' + ($ops -join '|') + ')(\s*))\w*'
        $regex = '(\s*)(' + ($ops -join '|') + ')(\s*)'
    }
    process {
        $Codeblock += $Code
    }
    end {
        $FullCodeBlock = ($Codeblock | Out-String).TrimEnd()
        $ScriptBlock = [Scriptblock]::Create($FullCodeBlock)
        $Tokens = [Management.Automation.PSParser]::Tokenize($ScriptBlock, [ref]$null)
        $IgnoredLines = $Tokens | Where {($_.startline -ne $_.endline) -and (($_.Type -eq 'String') -or ($_.Type -eq 'Comment'))}
        Foreach ($CurLine in ($FullCodeBlock -split "`r`n")) {
            $LineCount++
            $ToProcess = $true
            $IgnoredLines | Foreach {   # Skip any multiline comment or here-string/add-type variables
                if (($LineCount -ge $_.startline) -and ($LineCount -le $_.endline)) {
                    $ToProcess = $false
                }
            }
#            if ($Curline -match '#') {  # Skip any line with a comment for now
#                $ToProcess = $false
#            }
            if ($ToProcess -eq $true) {
                $CurLine -ireplace $regex,' $2 '
#                [regex]::Matches($CurLine,$regex) | foreach {
#                    $prespace = $_.groups[2].Value
#                    $matchedop = $_.groups[3].Value
#                    $replacematch = [Regex]::Escape($_.groups[1].Value)
#                    $postspace = $_.groups[4].Value
#                    if (($prespace.length -ne 1) -or ($postspace.length -ne 1)) {
#                        if ($matchedop -ne '=') {
#                            $CurLine = $CurLine -replace $replacematch,(' ' + $matchedop + ' ')
#                        }
#                        else {
#                            $replacer = '(?<!\+|-)' + [Regex]::Escape($matchedop)
#                            $CurLine = $CurLine -replace $replacer,' = '
#                        }
#                        Write-Verbose "Operator padding corrected on line $($LineCount): $($matchedop)"
#                    }
            }
            else {
                $CurLine
            }
           # }
            #$Output += $CurLine
        }
       # return $Output
    }
}

function Format-ScriptPadOperators {
    <#
    .SYNOPSIS

    .DESCRIPTION

    .PARAMETER Code
        Multiline or piped lines of code to process.
    .EXAMPLE
       PS > $testfile = 'C:\temp\test.ps1'
       PS > $test = Get-Content $testfile -raw
       PS > $test | Format-ScriptPadOperators | clip
       
       Description
       -----------
       Takes C:\temp\test.ps1 as input, formats as the function defines and places the result in the clipboard 
       to be pasted elsewhere for review.

    .NOTES
       Author: Zachary Loeber
       Site: http://www.the-little-things.net/
       Requires: Powershell 3.0

       Version History
       1.0.0 - Initial release
    #>
    [CmdletBinding()]
    param(
        [parameter(Position=0, ValueFromPipeline=$true, HelpMessage='Lines of code to process.')]
        [string[]]$Code,
        [parameter(Position=1, HelpMessage='Operator(s) to validate single spaces are around.')]
        [string[]]$Operators = @('+=','-=','=')
    )
    begin {
        $Codeblock = @()
        $ParseError = $null
        $Tokens = $null
        $FunctionName = $MyInvocation.MyCommand.Name
        Write-Verbose "$($FunctionName): Begin."
    }
    process {
        $Codeblock += $Code
    }
    end {
        $ScriptText = $Codeblock | Out-String
        Write-Verbose "$($FunctionName): Attempting to parse AST."
        $AST = [System.Management.Automation.Language.Parser]::ParseInput($ScriptText, [ref]$Tokens, [ref]$ParseError) 
 
        if($ParseError) { 
            $ParseError | Write-Error
            throw "$($FunctionName): Will not work properly with errors in the script, please modify based on the above errors and retry."
        }

        for($t = $Tokens.Count - 2; $t -ge 1; $t--) {
            $token = $tokens[$t]
            
            # Process token replacement or some such
        }
        $ScriptText
        Write-Verbose "$($FunctionName): End."
    }
}