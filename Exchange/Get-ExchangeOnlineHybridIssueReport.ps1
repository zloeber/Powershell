<#
This is meant to be run from an exchange on premise server that is part of a hybrid o365 configuration.

This script produces the following results in some script variables for further use or processing:
    1. $RemoteOnlyMailboxes
    
    All mailboxes which are found in the o365 tenant which are not found locally as 'remote mailboxes'. These may be on purpose 
    but may also experience issues with autodiscover and cross-premise delivery in a hybrid scenario
    
    2. $AliasMismatches
    
    Mailboxes in the environment with aliases which don't match their primary smtp address. I've personally had issues with 
    RemoteRoutingAddresses being incorrect in these cases. Maybe it was 'just me' though
        
    3. $MismatchedRemoteMailboxes
    Remote mailboxes with RemoteRoutingAddresses which are not in your current federated domains list.
    
    4. $MigrationStatus
    
    A list of current remote move requests and their status on the o365 side. This is combined with the mailboxes on premise to try and 
    get a full report of where we are in the migration process. Can be spit out to excel to make pretty charts for management on your migration status :)
    
 
    Note: This script has only been tested with Exchange 2013 in a hybrid configuration.
#>

# Connect to o365
$upn = ([ADSISEARCHER]"samaccountname=$($env:USERNAME)").Findone().Properties.userprincipalname
$creds = Get-Credential -UserName $upn -Message "Enter password for $upn"
$session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $creds -Authentication Basic -AllowRedirection
Import-PSSession $session -Prefix 'o365'

# Gather our mailbox data
$localMailboxes = Get-Mailbox -ResultSize Unlimited
$o365Mailboxes = Get-o365Mailbox -ResultSize Unlimited
$remoteMailboxes = Get-RemoteMailbox -ResultSize Unlimited

# Get all mailboxes where the alias does not match the samaccountname
$Global:AliasMismatches = $localMailboxes | where {$_.SamAccountName -ne $_.Alias}

$FedDomains = @((Get-OrganizationRelationship | Where {$_.TargetApplicationUri -eq 'outlook.com'}).DomainNames.Domain)
$FedDomainMatches = @($FedDomains | Foreach {[regex]::Escape($_)})
$FedDomainMatches = '^(.*\@' + ($FedDomainMatches -join '|\@') + ')$'
$Global:MismatchedRemoteMailboxes = $remoteMailboxes | Where {$_.remoteroutingaddress -notmatch $FedDomainMatches}



$UPNs = $RemoteMailboxes.WindowsEmailAddress
$Global:RemoteOnlyMailboxes = @()
$o365Mailboxes | Foreach {
    if ($UPNs -notcontains $_.WindowsEmailAddress) {
        $Global:RemoteOnlyMailboxes += $_
    }
}

$batches = Get-o365MigrationBatch
$moverequests = Get-o365MoveRequest
$moverequestaliases = $moverequests.Alias

$global:migrationstatus = @()
$localMailboxes | Foreach {
    if ($moverequestaliases -notcontains $_.Alias) {
        $global:migrationstatus += New-Object PSObject -Property @{
            'Name' = $_.Name
            'Alias' = $_.Alias
            'Status' = 'Not Started'
            'BatchName' = 'NA'
        }
    }
    else {
        $migrationalias = $_.Alias
        $global:migrationstatus += $moverequests | Where {$_.Alias -eq $migrationalias} | Select Name,Alias,Status,BatchName
    }
}

Write-Host ''
Write-Host -ForegroundColor DarkGreen "The following mailboxes seem to exist on o365 but are not seen on premise as a remote mailbox:"
Write-Host -ForegroundColor DarkGreen "You may be able to fix this by running Set-RemoteMailbox -RemoteRoutingAddress <mailbox>"
$Global:RemoteOnlyMailboxes | select Name,WindowsEmailAddress | More

Write-Host ''
Write-Host -ForegroundColor DarkGreen "The following mailboxes have Aliases which do not match with their SamAccountName."
Write-Host -ForegroundColor DarkGreen "You may want to ensure remote routing addresses are set properly after they are migrated."
$Global:AliasMismatches | More

Write-Host ''
Write-Host -ForegroundColor DarkGreen "The following remote mailboxes have remote routing addresses which are not in your federated domains"
Write-Host -ForegroundColor DarkGreen "If you do not update these then autodiscover (among other things) may not work poperly for the account."
$Global:MismatchedRemoteMailboxes | select Name,RemoteRoutingAddress | More

Write-Host ''
Write-Host -ForegroundColor DarkGreen "The remote only mailboxes have been stored in `$RemoteOnlyMailboxes for you to export or do whatever with."
Write-Host -ForegroundColor DarkGreen "The alias mismatches have been stored in `$AliasMismatches for you to export or do whatever with."
Write-Host -ForegroundColor DarkGreen "The mismatched remote mailboxes have been stored in `$MismatchedRemoteMailboxes for you to export or do whatever with."
Write-Host -ForegroundColor DarkGreen "The current migration status has been stored in `$migrationstatus for you to export or do whatever with."

# Disconnect from o365
Remove-PSSession $session