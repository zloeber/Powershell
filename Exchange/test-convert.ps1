# Grant 'Send on behalf' rights on a shared mailbox for an AD group of users
$SharedMailbox = 'mailboxname'
$GroupToAdd = 'ADGroupName'

$ValidSendOnBehalfUsers = @()
Get-ADGroupMember $GroupToAdd | ForEach {
    Get-ADUser $_.distinguishedName -Properties SamAccountName,mail | Where {$_.Enabled -and ($_.mail -ne $null)} | ForEach {
        $mailbox = Get-Mailbox $_.distinguishedName -ErrorAction:SilentlyContinue
        if ($mailbox -ne $null) {
            $ValidSendOnBehalfUsers += [string]$mailbox.PrimarySmtpAddress
        }
    }
}
if ($ValidSendOnBehalfUsers.Count -gt 0) {
    Set-Mailbox $SharedMailbox -GrantSendOnBehalfTo @{Add=$ValidSendOnBehalfUsers}
}

# Display send on behalf permissions for the shared mailbox
Get-Mailbox $SharedMailbox | Select -expand grantsend* | Select Name
