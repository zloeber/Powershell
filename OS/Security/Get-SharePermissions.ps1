function Get-SharePermission {
<#
           .SYNOPSIS 
           This script will list all shares on a computer, and list all the share permissions for each share.

           .DESCRIPTION
           The script will take a list all shares on a local or remote computer.
    
           .PARAMETER Computer
           Specifies the computer or array of computers to process

           .INPUTS
           Get-SharePermissions accepts pipeline of computer name(s)

           .OUTPUTS
           Produces an array object for each share found.

           .EXAMPLE
           C:\PS> .\Get-SharePermissions # Operates against local computer.

           .EXAMPLE
           C:\PS> 'computerName' | .\Get-SharePermissions

           .EXAMPLE
           C:\PS> Get-Content 'computerlist.txt' | .\Get-SharePermissions | Out-File 'SharePermissions.txt'

           .EXAMPLE
           Get-Help .\Get-SharePermissions -Full
#>

# Written by BigTeddy November 15, 2011
# Last updated 9 September 2012 
# Ver. 2.0 
# Thanks to Michal Gajda for input with the ACE handling.
 
    [cmdletbinding()]
    Param (
        [Parameter(ValueFromPipeline=$True, ValueFromPipelineByPropertyName=$True)]
        $Computer = '.'
    ) 

    $shares = gwmi -Class win32_share -ComputerName $computer | select -ExpandProperty Name 
    
    foreach ($share in $shares) { 
        $acl = $Null
        Write-Verbose $share 
 
        $objShareSec = Get-WMIObject -Class Win32_LogicalShareSecuritySetting -Filter "name='$Share'"  -ComputerName $computer
        try {
            $SD = $objShareSec.GetSecurityDescriptor().Descriptor   
            foreach($ace in $SD.DACL){  
                $UserName = $ace.Trustee.Name     
                If ($ace.Trustee.Domain -ne $Null) {$UserName = "$($ace.Trustee.Domain)\$UserName"}   
                If ($ace.Trustee.Name -eq $Null) {$UserName = $ace.Trustee.SIDString }     
                [Array]$ACL += New-Object Security.AccessControl.FileSystemAccessRule($UserName, $ace.AccessMask, $ace.AceType) 
                }        
            } 
        catch {
            Write-Warning "Unable to obtain permissions for $share"
        } 
        $ACL | Select @{'n'='ShareName';e={$Share}},FileSystemRights,AccessControlType,IdentityReference,IsInherited,InheritanceFlags,PropagationFlags
    }
}