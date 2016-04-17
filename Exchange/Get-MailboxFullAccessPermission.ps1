function Get-MailboxFullAccessPermission {
    <#
    .SYNOPSIS
    Retrieves a list of mailbox full access permissions
    .DESCRIPTION
    Gathers a list of users with full access permissions for a mailbox.
    .PARAMETER MailboxNames
    Array of mailbox names in string format.    
    .PARAMETER MailboxObject
    One or more mailbox objects.
    .PARAMETER ShowAll
    Includes unresolved names (typically deleted accounts).
    .PARAMETER Expand
    Expands results
    .PARAMETER AdditionalUserFilters
    Additional user filters
    .PARAMETER ExpandGroups
    Tests each permission to determine if it is a group and expands it.
    .PARAMETER IncludeNullResults
    Includes mailboxes with all full permissions filtered out. This can be useful for finding mailboxes which are not shared.

    .LINK
    http://www.the-little-things.net   
    .NOTES
    Version
        1.0.0 01/25/2016
        - Initial release
    Author      :   Zachary Loeber

    .EXAMPLE
    Get-MailboxFullAccessPermission -MailboxName "Test User1" -Verbose

    Description
    -----------
    Gets the send-as permissions for "Test User1" and shows verbose information.

    .EXAMPLE
    Get-MailboxFullAccessPermission -MailboxName 'user1' | Format-List

    Description
    -----------
    Gets the send-as permissions for "user1" and returns the info as a format-list.
    
    .EXAMPLE
    $AdditionalUserFilters = @(
        '*\user-admin',
        '*\somearchivingsolutionaccount',
        '*\someoldbackupaccount',
        '*\unifiedmessagingadmin'
    )
    
    $Domain = 'CONTOSO'     # The domain short name (ie. DOMAIN\<username>)
    $perms = Get-Mailbox -ResultSize Unlimited | Get-MailboxFullAccessPermission -AdditionalUserFilters $AdditionalUserFilters -expand -expandgroup -verbose -IncludeNullResults
    $groups = $perms | Sort-Object -Property FullAccess | Group-Object -Property FullAccess -AsString -AsHashTable
    
    $standalonemailboxes = @()
    Write-Host -ForegroundColor Green "The following mailboxes have full permissions on no other mailboxes." 
    Write-Host -ForegroundColor Green "Additionally, no other mailboxes have full access to these mailboxes."
    $perms | Where {$_.FullAccess -eq $null} | Foreach {
        $tmp = "$($Domain)\" + $_.MailboxAlias
        if (($groups.$tmp).Count -eq 0) {
            Write-Host -ForegroundColor Green "    $($_.Mailbox)"
            $standalonemailboxes += $_.Mailbox
        }
    }

    Description
    -----------
    Queries all mailboxes full permission access and filters out results using the default filters plus several custom filters and stores the results in $perm.
    The -expandgroup flag attempts to expand out full access users from groups that may be assigned to mailboxes. IncludeNullResults includes mailboxes for which
    all full access permissions have been filtered out. The expand flag returns one entry for every user. Then we output to the screen all the users which
    in the permissions list along with a count of mailboxes for which they have full access and save the results to $standalonemailboxes.

    #>
    [CmdLetBinding(DefaultParameterSetName='AsString')]
    param(
        [Parameter(ParameterSetName='AsString', Mandatory=$True, ValueFromPipeline=$True, Position=0, HelpMessage="Enter an Exchange mailbox name")]
        [string]$MailboxName,
        [Parameter(ParameterSetName='AsMailbox', Mandatory=$True, ValueFromPipeline=$True, Position=0, HelpMessage="Enter an Exchange mailbox name")]
        [Microsoft.Exchange.Data.Directory.Management.Mailbox]$MailboxObject,
        [Parameter(HelpMessage='Includes unresolved and other common full permission accounts.')]
        [switch]$ShowAll,
        [Parameter(HelpMessage="Additional user filters")]
        [string[]]$AdditionalUserFilters = @(),
        [Parameter(HelpMessage='Expands results.')]
        [switch]$Expand,
        [Parameter(HelpMessage='Expands AD groups.')]
        [switch]$ExpandGroups,
        [Parameter(HelpMessage='Includes mailboxes with all full permissions filtered out.')]
        [switch]$IncludeNullResults
    )
    begin {
        $FunctionName = $FunctionName
        Write-Verbose "$($FunctionName): Begin"
        $Mailboxes = @()
        if (-not $ShowAll) {
            # These are some standard user exceptions you may find in your environment
            # You can supply your own list by including -ShowAll and -AdditionalUserFilters
            # in the same call.
            $UserExceptions = @(
                'S-1-*',
                "*\Organization Management",
                "*\Domain Admins",
                "*\Enterprise Admins",
                "*\Exchange Services",
                "*\Exchange Trusted Subsystem",
                "*\Exchange Servers",
                "*\Exchange View-Only Administrators",
                "*\Exchange Admins",
                "*\Managed Availability Servers",
                "*\Public Folder Administrators",
                "*\Exchange Domain Servers",
                "*\Exchange Organization Administrators",
                "NT AUTHORITY\*")
        }
        else {
            $UserExceptions = @()
        }
        $UserExceptions += $AdditionalUserFilters
        
        if ($UserExceptions.Count -gt 0) {
            # If we have some user exceptions create one big regex to filter against later
            $ExceptionMatches = @($UserExceptions | Foreach {[regex]::Escape($_)})
            $Exceptions = '^(' + ($ExceptionMatches -join '|') + ')$'
            
            # The regex escape will turn '*' into '\*', this next statment turns it into a match all regex of '.*'
            $Exceptions = $Exceptions -replace '\\\*','.*'
        }
        else {
            # If there are no exceptions this will fail to match anything and thus allow all results to be processed.
            $Exceptions = '^()$'
        }
        Write-Verbose "$($FunctionName): Exceptions regex string - $exceptions"
    }
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'AsStringArray' {
                try {
                    $Mailboxes += Get-Mailbox $MailboxName -erroraction Stop
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
        ForEach ($Mailbox in $Mailboxes) {
            Write-Verbose "$($FunctionName): Processing Mailbox $($Mailbox.Name)"
            
            # Initiate our array for this one mailbox to store all the full access users we end up enumerating.
            $FullAccessUsers = @()
            
            # Get all the full access permissions on a mailbox where it is not set to 'denied'
            $fullperms = @($Mailbox | Get-MailboxPermission | Where {($_.AccessRights -like "*FullAccess*") -and (-not $_.Deny)})
            
            # If we have results then continume processing
            if ($fullperms.Count -gt 0) {
                $fullperms | Foreach {
                    # Foreach permission found see if it gets filtered out in our exception list.
                    if ($_.User.RawIdentity -notmatch $Exceptions) {
                        if ($ExpandGroups) {
                            if ($_.User.RawIdentity -match '^(.*\\)(.*)$') {
                                $domstring = $matches[1]
                                $grpstring = $matches[2]
                            }
                            else {
                                $domstring = ''
                                $grpstring = $_.User.RawIdentity
                            }
                            
                            try {
                                $groupmembers = @(Get-ADGroupMember $grpstring -Recursive)
                            }
                            catch {
                                $groupmembers = $null
                            }
                            if ($groupmembers -ne $null) {
                                Write-Verbose "$($FunctionName): $grpstring is a group with $($groupmembers.count) members..."
                                #foreach ($groupmember in $groupmembers) {
                                
                                ($groupmembers).SamAccountName | Foreach {
                                    $memberusername = "$($domstring)$($_)"
                                    if ($memberusername -notmatch $Exceptions) {
                                        $FullAccessUsers += $memberusername
                                    }
                                }
                            }
                            else {
                                Write-Verbose "$($FunctionName): $($_.User.RawIdentity) is a non-filtered user"
                                $FullAccessUsers += $_.User.RawIdentity
                            }
                        }
                        else {
                            $FullAccessUsers += $_.User.RawIdentity
                        }
                    }
                }
                if (($FullAccessUsers.Count -gt 0) -or ($IncludeNullResults)) {
                    $NewObjProp = @{
                        'Mailbox' = $Mailbox.Name
                        'MailboxEmail' = $Mailbox.PrimarySMTPAddress
                        'MailboxAlias' = $Mailbox.Alias
                        'FullAccess' = $null
                    }
                    $FullAccessUsers = $FullAccessUsers | Select -Unique
                    
                    if ($Expand) {
                        if ($FullAccessUsers.Count -eq 0) {
                            New-Object psobject -Property $NewObjProp
                        }
                        else {
                            $FullAccessUsers | Foreach {
                                $NewObjProp.FullAccess = $_
                                New-Object psobject -Property $NewObjProp
                            }
                        }
                    }
                }
                else {
                    if ($FullAccessUsers.Count -eq 0) {
                        New-Object psobject -Property $NewObjProp
                    }
                    else {
                        $NewObjProp.FullAccess = $FullAccessUsers
                        New-Object psobject -Property $NewObjProp
                    }
                }
            }
        }
        Write-Verbose "$($FunctionName): End"
    }
}