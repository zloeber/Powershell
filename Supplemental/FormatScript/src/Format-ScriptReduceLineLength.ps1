function Format-ScriptReduceLineLength {
    <#
    .SYNOPSIS
        Attempt to shorten long lines if possible.
    .DESCRIPTION
        Attempt to shorten long lines if possible.
    .PARAMETER Code
        Multiline or piped lines of code to process.
    .PARAMETER Length
        Number of characters to shorten long lines to. Default is 115 characters as this is best practice.
    .EXAMPLE
       PS > $testfile = 'C:\temp\test.ps1'
       PS > $test = Get-Content $testfile -raw
       PS > $test | Format-ScriptReduceLineLength | clip
       
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
        [parameter(Position=1, HelpMessage='Number of characters to shorten long lines to. Default is 115 characters.')]
        [int]$Length = 115
    )
    begin {
        $Codeblock = @()
        $ParseError = $null
        $Tokens = $null
        $FunctionName = $MyInvocation.MyCommand.Name
        Function Get-TokensOnLineNumber {
            [CmdletBinding()]
            param(
                [parameter(Position=0, ValueFromPipeline=$true, Mandatory=$true, HelpMessage='Tokens to process.')]
                [System.Management.Automation.Language.Token[]]$Tokens,
                [parameter(Position=1, Mandatory=$true, HelpMessage='Line Number')]
                [int]$LineNumber
            )
            begin {
                $AllTokens = @()
            }
            process {
                $AllTokens += $Tokens
            }
            end {
                $AllTokens | Where {($_.Extent.StartLineNumber -eq $_.Extent.EndLineNumber) -and 
                ($_.Extent.StartLineNumber -eq $LineNumber)}
            }
        }
        
        Function Get-BreakableTokens {
            [CmdletBinding()]
            param(
                [parameter(Position=0, ValueFromPipeline=$true, Mandatory=$true, HelpMessage='Tokens to process.')]
                [System.Management.Automation.Language.Token[]]$Tokens
            )
            begin {
                $Kinds = @('Pipe')
                # Flags found here: https://msdn.microsoft.com/en-us/library/system.management.automation.language.tokenflags(v=vs.85).aspx
                $TokenFlags = @('BinaryPrecedenceAdd','BinaryPrecedenceMultiply','BinaryPrecedenceLogical')
                $Kinds_regex = '^(' + (($Kinds | %{[regex]::Escape($_)}) -join '|') + ')$'
                $TokenFlags_regex = '(' + (($TokenFlags | %{[regex]::Escape($_)}) -join '|') + ')'
                $Results = @()
                $AllTokens = @()
            }
            process {
                $AllTokens += $Tokens
            }
            end {
                Foreach ($Token in $AllTokens) {
                    if (($Token.Kind -match $Kinds_regex) -or ($Token.TokenFlags -match $TokenFlags_regex)) {
                        $Results += $Token
                    }
                }
                $Results
            }
        }
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

        $LongLines = @()
        $LongLinecount = 0
        $SplitScriptText = @($ScriptText -split "`r`n")
        $OutputScript = @()
        for($t = 0; $t -lt $SplitScriptText.Count; $t++) {
            [string]$CurrentLine = $SplitScriptText[$t]
            if ($CurrentLine.Length -gt $Length) {
        
                $CurrentLineLength = $CurrentLine.Length

                # find spaces at the beginning of our line.
                if ($CurrentLine -match '^([\s]*).*$') {
                    $Padding = $Matches[1]
                    $PaddingLength = $Matches[1].length
                }
                else {
                    $Padding = ''
                    $PaddingLength = 0
                }
                $AdjustedLineLength = $Length - $PaddingLength
                $AllTokensOnLine = $Tokens | Get-TokensOnLineNumber -LineNumber ($t+1)
                $BreakableTokens = @($AllTokensOnLine | Get-BreakableTokens)
                $DesiredBreakPoints = [Math]::Round($SplitScriptText[$t].Length / $AdjustedLineLength)
                if ($BreakableTokens.Count -gt 0) {
                    Write-Verbose "$($FunctionName): Total String Length: $($CurrentLineLength)"
                    Write-Verbose "$($FunctionName): Breakpoint Locations: $($BreakableTokens.Extent.EndColumnNumber -join ', ')"
                    Write-Verbose "$($FunctionName): Padding: $($PaddingLength)"
                    Write-Verbose "$($FunctionName): Desired Breakpoints: $($DesiredBreakPoints)"
                    if (($BreakableTokens.Count -eq 1) -or ($DesiredBreakPoints -ge $BreakableTokens.Count)) {
                        # if we only have a single breakpoint or the total breakpoints available is equal or less than our desired breakpoints 
                        # then simply split the line at every breakpoint.
                        $TempBreakableTokens = @()
                        $TempBreakableTokens += 0
                        $TempBreakableTokens += $BreakableTokens | Foreach { $_.Extent.EndColumnNumber - 1 }
                        $TempBreakableTokens += $CurrentLine.Length
                        for($t2 = 0; $t2 -lt $TempBreakableTokens.Count - 1; $t2++) {
                            $OutputScript += $Padding + ($CurrentLine.substring($TempBreakableTokens[$t2],($TempBreakableTokens[$t2 + 1] - $TempBreakableTokens[$t2]))).Trim()
                        }
                    }
                    else {
                        # Otherwise we need to selectively break the lines down
                        $TempBreakableTokens = @(0) # Start at the beginning always
                        
                        # We need to adjust our segment length to account for padding we will be including into each segment
                        # to keep the resulting output aligned at the same column it started in.
                        $TotalAdjustedLength = $CurrentLineLength + ($DesiredBreakPoints * $PaddingLength)
                        $SegmentMedianLength = [Math]::Round($TotalAdjustedLength/($DesiredBreakPoints + 1))
                        
                        $TokenStartOffset = 0   # starting at the beginning of the string
                        for($t2 = 0; $t2 -lt $BreakableTokens.Count; $t2++) {
                            $TokenStart = $BreakableTokens[$t2].Extent.EndColumnNumber
                            $NextTokenStart = $BreakableTokens[$t2 + 1].Extent.EndColumnNumber
                            if ($t2 -eq 0) { $TokenSize = $TokenStart }
                            else { $TokenSize = $TokenStart - $BreakableTokens[$t2 - 1].Extent.EndColumnNumber }
                            $NextTokenSize = $NextTokenStart - $TokenStart
                            
                            if ((($TokenStartOffset + $TokenSize) -ge $SegmentMedianLength) -or 
                            ($NextTokenSize -ge ($SegmentMedianLength - $TokenSize)) -or 
                            (($TokenStartOffset + $TokenSize + $NextTokenSize) -gt $SegmentMedianLength)) {
                                $TempBreakableTokens += $BreakableTokens[$t2].Extent.EndColumnNumber - 1
                                $TokenStartOffset = 0
                            }
                            else {
                                $TokenStartOffset = $TokenStartOffset + $TokenSize
                            }
                        }
                        $TempBreakableTokens += $CurrentLine.Length
                        for($t2 = 0; $t2 -lt $TempBreakableTokens.Count - 1; $t2++) {
                            Write-Verbose "$($FunctionName): Inserting break in line $($t) at column $($TempBreakableTokens[$t2])"
                            $OutputScript += $Padding + ($CurrentLine.substring($TempBreakableTokens[$t2],($TempBreakableTokens[$t2 + 1] - $TempBreakableTokens[$t2]))).Trim()
                        }
                    }
                }
            }
            else {
               $OutputScript += $CurrentLine
            }
        }

        $OutputScript
        Write-Verbose "$($FunctionName): End."
    }
}

Get-Content 'c:\Temp\test4.ps1' -Raw | Format-ScriptReduceLineLength -Verbose | clip