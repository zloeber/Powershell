function Get-LocalRight { 
<# 
*Privilege names are **case-sensitive**.* Valid privileges are documented on Microsoft's website:  
[Privilege Constants]    (http://msdn.microsoft.com/en-us/library/windows/desktop/bb530716.aspx) 
[Account Right Constants](http://msdn.microsoft.com/en-us/library/windows/desktop/bb545671.aspx) 
#> 
 
[cmdletbinding()] 
Param ( 
    [validateset('SeAssignPrimaryTokenPrivilege','SeAuditPrivilege','SeBackupPrivilege','SeBatchLogonRight', 
    'SeChangeNotifyPrivilege','SeCreateGlobalPrivilege','SeCreatePagefilePrivilege','SeCreatePermanentPrivilege', 
    'SeCreateSymbolicLinkPrivilege','SeCreateTokenPrivilege','SeDebugPrivilege','SeDenyBatchLogonRight', 
    'SeDenyInteractiveLogonRight','SeDenyNetworkLogonRight','SeDenyRemoteInteractiveLogonRight', 
    'SeDenyServiceLogonRight','SeEnableDelegationPrivilege','SeImpersonatePrivilege', 
    'SeIncreaseBasePriorityPrivilege','SeIncreaseQuotaPrivilege','SeIncreaseWorkingSetPrivilege', 
    'SeInteractiveLogonRight','SeLoadDriverPrivilege','SeLockMemoryPrivilege','SeMachineAccountPrivilege', 
    'SeManageVolumePrivilege','SeNetworkLogonRight','SeProfileSingleProcessPrivilege','SeRelabelPrivilege', 
    'SeRemoteInteractiveLogonRight','SeRemoteShutdownPrivilege','SeRestorePrivilege','SeSecurityPrivilege', 
    'SeServiceLogonRight','SeShutdownPrivilege','SeSyncAgentPrivilege','SeSystemEnvironmentPrivilege', 
    'SeSystemProfilePrivilege','SeSystemtimePrivilege','SeTakeOwnershipPrivilege','SeTcbPrivilege', 
    'SeTimeZonePrivilege','SeTrustedCredManAccessPrivilege','SeUndockPrivilege','SeUnsolicitedInputPrivilege')] 
 
    [String[]]$SecurityRight = ('SeTcbPrivilege','SeInteractiveLogonRight','SeRemoteInteractiveLogonRight','SeBackupPrivilege', 
                                'SeSystemtimePrivilege','SeCreateTokenPrivilege','SeDebugPrivilege', 
                                'SeEnableDelegationPrivilege','SeLoadDriverPrivilege','SeBatchLogonRight', 
                                'SeServiceLogonRight','SeSecurityPrivilege','SeSystemEnvironmentPrivilege', 
                                'SeManageVolumePrivilege','SeRestorePrivilege','SeSyncAgentPrivilege','SeRelabelPrivilege', 
                                'SeTakeOwnershipPrivilege') 
) 
 
$c = @' 
// download for definition 
'@ 
 
    try { 
        $t = [LsaSecurity.LsaWrapper] 
    } 
    catch { 
       $t = Add-Type -TypeDefinition $c  
    } 
 
    $d = New-Object -TypeName LsaSecurity.LsaWrapper 
     
     
    $SecurityRight | Foreach-Object { 
        $Right = $_ 
        try { 
            $d.ReadPrivilege($Right) | ForEach-Object { 
                 
                $Current = $_.Translate([System.Security.Principal.NTAccount]) 
 
                New-Object -TypeName psobject -Property @{ 
                    SecurityRight= $Right 
                    Identity     = $Current.value 
                } 
            }#Foreach-Object(NTAccount) 
        }#Try 
        Catch { 
            Write-Warning -Message "No Identites with $Right" 
        }#Catch 
 
 
    }#Foreach-Object(SecurityRight) 
 
}
