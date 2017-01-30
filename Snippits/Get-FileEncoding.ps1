function Get-FileEncoding {
    <#
    .SYNOPSIS
    Gets file encoding.
    .DESCRIPTION
    The Get-FileEncoding function determines encoding by looking at Byte Order Mark (BOM).
    Based on port of C# code from http://www.west-wind.com/Weblog/posts/197245.aspx
    .EXAMPLE
    Get-ChildItem  *.ps1 | select FullName, @{n='Encoding';e={Get-FileEncoding $_.FullName}} | where {$_.Encoding -ne 'ASCII'}
    This command gets ps1 files in current directory where encoding is not ASCII
    .EXAMPLE
    Get-ChildItem  *.ps1 | select FullName, @{n='Encoding';e={Get-FileEncoding $_.FullName}} | where {$_.Encoding -ne 'ASCII'} | foreach {(get-content $_.FullName) | set-content $_.FullName -Encoding ASCII}
    Same as previous example but fixes encoding using set-content
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName=$True, ValueFromPipeline=$True)]
        [Alias('FullName')]
        [string]$Path
    )

    process {
        Write-Verbose "Processing File: $Path"
        if (Test-Path $Path) {
            try {
                [byte[]]$byte = get-content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $Path
                if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf )
                { Write-Output 'UTF8' }
                elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff)
                { Write-Output 'Unicode' }
                elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff)
                { Write-Output 'UTF32' }
                elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76)
                { Write-Output 'UTF7'}
                else
                { Write-Output 'ASCII' }
            }
            catch {
                Write-Verbose "Skipping empty or inaccessible file: $Path"
            }
        }
        else {
            Write-Warning "$Path not found!"
        }
    }
}

<#
# Example of finding and updating all non-UTF8 ps1 files
Get-ChildItem .\ -recurse -File | Foreach-Object {
    If ((Get-FileEncoding $_.FullName) -ne 'UTF8') {
        $FullName = $_.FullName
        Write-Output "File without UTF8 encoding: $($FullName)"
        $Content = get-content $FullName 
        $Content | Out-File $FullName -Force -Encoding:utf8
        pause
    }
}
#>