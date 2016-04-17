function Get-MailboxForwardAndRedirectRule {
    <#
    .SYNOPSIS
    Retrieves a list of mailbox rules which forward or redirect email elsewhere.
    .DESCRIPTION
    Retrieves a list of mailbox rules which forward or redirect email elsewhere.
    .PARAMETER MailboxNames
    Array of mailbox names in string format.    
    .PARAMETER MailboxObject
    One or more mailbox objects.
    .EXAMPLE
    Get-MailboxForwardAndRedirectRule -MailboxName "Test User1"
    
    Description
    -----------
    List test user1 forwarding and redirect rules.

    .EXAMPLE
    Get-Mailbox -ResultSize Unlimited | Get-MailboxForwardAndRedirectRule
    
    Description
    -----------
    List entire organization's inbox forwarding and redirecting rules.
    
    .LINK
    http://www.the-little-things.net
    .NOTES
    Last edit   :   11/04/2014
    Version     :   
    1.2.0 09/22/2015
    - Due to the moronic double pipeline limitations of Exchange 2010 I restructured the code
      to do all the processing in the end block (cause the process block is a pipeline after all...)
    - Added additional information to output (like AD disabled state and rule descriptions)
    1.1.0 11/04/2014
    - Minor structual changes and input parameter updates
    1.0.0 10/04/2014
    - Initial release
    Author      :   Zachary Loeber
    Original Author: https://gallery.technet.microsoft.com/PowerShell-Script-To-Get-0f1bb6a7/
    #>
    [CmdLetBinding(DefaultParameterSetName='AsMailbox')]
    param(
        [Parameter(ParameterSetName='AsStringArray', Mandatory=$True, ValueFromPipeline=$True, Position=0, HelpMessage="Enter an Exchange mailbox name")]
        [string[]]$MailboxNames,
        [Parameter(ParameterSetName='AsMailbox', Mandatory=$True, ValueFromPipeline=$True, Position=0, HelpMessage="Enter an Exchange mailbox name")]
        $MailboxObject
    )
    begin {
        $FunctionName = $MyInvocation.MyCommand.Name
        Write-Verbose "$($FunctionName): Begin"
        $Mailboxes = @()
    }
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'AsStringArray' {
                try {
                    $Mailboxes = @($MailboxNames | Foreach {Get-Mailbox $_ -erroraction Stop})
                }
                catch {
                    Write-Warning = "$($FunctionName): $_.Exception.Message"
                }
            }
            'AsMailbox' {
               $Mailboxes += @($MailboxObject)
            }
        }
    }
    end {
        foreach ($Mailbox in $Mailboxes) {
            $UserInfo = Get-User $Mailbox.DistinguishedName 
            Write-Verbose "$($FunctionName): Checking $($Mailbox.Name)"
            Get-InboxRule -mailbox $Mailbox.DistinguishedName | Where-Object {
                    ($_.forwardto -ne $null) -or 
                    ($_.redirectto -ne $null) -or 
                    ($_.ForwardAsAttachmentTo -ne $null) -and 
                    ($_.ForwardTo -notmatch "EX:/") -and 
                    ($_.RedirectTo -notmatch "EX:/") -and 
                    ($_.ForwardAsAttachmentTo -notmatch "EX:/")} | 
                Select-Object @{n="Mailbox";e={($Mailbox.Name)}}, `
                       @{n="SAMAccountName";e={$UserInfo.SAMAccountName}}, `
                       @{n="ADAccountEnabled";e={-not ($UserInfo.UserAccountControl -match 'AccountDisabled')}}, `
                       @{n="DistinguishedName";e={($Mailbox.DistinguishedName)}}, `
                       @{n="RuleName";e={$_.name}}, `
                       @{n="Identity";e={$_.Identity}}, `
                       @{n="RuleEnabled";e={$_.Enabled}}, `
                       @{n="RuleDescription";e={$_.Description}}, `
                       @{Name="ForwardTo";Expression={[string]::join(";",($_.forwardTo))}}, `
                       @{Name="RedirectTo";Expression={[string]::join(";",($_.redirectTo))}}, `
                       @{Name="ForwardAsAttachmentTo";Expression={[string]::join(";",($_.ForwardAsAttachmentTo))}}
        }
        Write-Verbose "$($FunctionName): End"
    }
}