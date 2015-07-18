function Format-ScriptFormatTypeNames {
    <#
    .SYNOPSIS
        Converts typenames within code to be properly formated.
    .DESCRIPTION
        Converts typenames within code to be properly formated 
        (ie. [bool] becomes [Bool] and [system.string] becomes [System.String]).
    .PARAMETER Code
        Multiline or piped lines of code to process.
    .EXAMPLE
       PS > $testfile = 'C:\temp\test.ps1'
       PS > $test = Get-Content $testfile -raw
       PS > $test | Format-ScriptFormatTypeNames | clip
       
       Description
       -----------
       Takes C:\temp\test.ps1 as input, formats any typenames found and places the result in the clipboard 
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
        [string[]]$Code
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
        Write-Verbose "$($FunctionName): Attempting to parse TypeExpressions within AST."
        $types = $ast.FindAll({$args[0] -is [System.Management.Automation.Language.TypeExpressionAst] -or $args[0] -is [System.Management.Automation.Language.TypeConstraintAst]}, $true)

        for($t = $types.Count - 1; $t -ge 0; $t--) {
            $type = $types[$t]
            
            $typeName = $type.TypeName.Name
            $extent = $type.TypeName.Extent
    		$FullTypeName = Invoke-Expression "$type"
            if ($typeName -eq $FullTypeName.Name) {
                $NameCompare = ($typeName -cne $FullTypeName.Name)
                $Replacement = $FullTypeName.Name
            } 
            else {
                $NameCompare = ($typeName -cne $FullTypeName.FullName)
                $Replacement = $FullTypeName.FullName
            }
            if (($FullTypeName -ne $null) -and ($NameCompare)) {
                $RemoveStart = $extent.StartOffset
                $RemoveEnd = $extent.EndOffset - $RemoveStart
                $ScriptText = $ScriptText.Remove($RemoveStart,$RemoveEnd).Insert($RemoveStart,$Replacement)
                Write-Verbose "$($FunctionName): Replaced $($typeName) with $($Replacement)."
            }
        }
        $ScriptText
        Write-Verbose "$($FunctionName): End."
    }
}