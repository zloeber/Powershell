<# 
This is a set of functions for refactoring your script code in different ways. Ideally this collection will
eventually include the following:

    Format-ScriptRemoveStatementSeparators
    Format-ScriptRemoveSuperfluousSpaces
    Format-ScriptPadOperators
    Format-ScriptFormatCodeIndentation
    Format-ScriptRemoveSpacesAfterBackTicks - 
    Format-ScriptReplaceIllegalCharacters - Find and replace goofy characters you may have copied from the web
    Format-ScriptReplaceLineEndings - Fix CRLF inconsistencies
    Format-ScriptFormatHashTables - Splits hash assignments out to their own lines
    Remove-StatementSeparators - Removes superfluous semicolons at the end of individual lines of code and splits them into their own lines of code.
    Format-ScriptBlock - A multiple purpose function for reformatting and cleaning up scriptblocks. This includes removing
                        superfluous spaces at the start and end of the scriptblock and expanding or condensing the braces.
    Format-ScriptReplaceAliases - Replace aliases with full commands
    Format-ScriptReplaceTypeDefinitions - Replace type definitions with full types
    Format-ScriptReplaceCommandCase - Updates commands with correct casing
    Format-ScriptSplitLongLines - Any lines past 130 characters (or however many characters you like) are broken into newlines at the pipeline characters if possible
    Format-ScriptReplaceOutNull - Replace piped output to out-null with $null = equivalent
    Format-ScriptFormatOperatorSpacing - places a space before and after every operator
    Format-ScriptFormatArraySpacing - places a space after every comma in an array assignment
    Format-ScriptReplaceHereStrings - Finds herestrings and replaces them with equivalent code to eliminate the herestring
    Format-ScriptFormatTypeNames
    Format-ScriptFormatCommandNames
    Format-ScriptExpandTypeAccelerators
    Format-ScriptCondenseEnclosures
    Format-ScriptConvertKeywordsAndOperatorsToLower
    Format-ScriptExpandAliases
#>



#$testfile = 'C:\Users\Zachary\Dropbox\Zach_Docs\Projects\Git\Powershell\Exchange\EWS\EWSFunctions.ps1'
$testfile = 'C:\temp\test2.ps1'
$test = Get-Content $testfile -raw

$test2 = $test | Format-commandNames | Format-TypeNames | Remove-StatementSeparators | Format-CodeIndentation # Remove-StatementSeparators | Expand-TypeAccelerators -Verbose -AllTypes  | Expand-Aliases -Verbose | Convert-KeywordsAndOperatorsToLower -Verbose | Pad-Operators -Verbose | Indent-Groups | Condense-Enclosures -Verbose
#$test2 = $test |  Indent-Groups  # Remove-StatementSeparators -Verbose | Pad-Operators -Verbose |
#$test2 = $test | Expand-Aliases -Verbose
$test2.Trim() | clip

#$codefile = 'C:\temp\test.ps1'
#$test = Get-Content $codefile -raw
#$tokens = @()
#$errors = @()
##$a = [System.Management.Automation.PSParser]::Tokenize($test,[ref]$null)
#$a = [System.Management.Automation.Language.Parser]::ParseInput($test, [ref]$tokens, [ref] $errors)
#
#$tmp = '';
#$tokens.Extent | foreach {
#    if ($_.StartLineNumber -eq $_.EndLineNumber) {
#        $padding = ' '
#    } 
#    else {
#        $padding = ''
#    }
#    $tmp += $padding + $_
#}