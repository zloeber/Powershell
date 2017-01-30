function Connect-ActiveDirectory {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName='Credential')]
        [Parameter(ParameterSetName='CredentialObject')]
        [Parameter(ParameterSetName='Default')]
        [string]$ComputerName,
        
        [Parameter(ParameterSetName='Credential')]
        [string]$DomainName,
        
        [Parameter(ParameterSetName='Credential', Mandatory=$true)]
        [string]$UserName,
        
        [Parameter(ParameterSetName='Credential', HelpMessage='Password for Username in remote domain.', Mandatory=$true)]
        [string]$Password,
        
        [parameter(ParameterSetName='CredentialObject',HelpMessage='Full credential object',Mandatory=$True)]
        [System.Management.Automation.PSCredential]$Creds,
        
        [Parameter(HelpMessage='Context to return, forest, domain, or DirectoryEntry.')]
        [ValidateSet('Domain','Forest','DirectoryEntry','ADContext')]
        [string]$ADContextType = 'ADContext'
    )
    
    $UsingAltCred = $false
    
    # If the username was passed in domain\<username> or username@domain then gank the domain name for later use
    if (($UserName -split "\\").Count -gt 1) {
        $DomainName = ($UserName -split "\\")[0]
        $UserName = ($UserName -split "\\")[1]
    }
    if (($UserName -split "\@").Count -gt 1) {
        $DomainName = ($UserName -split "\@")[1]
        $UserName = ($UserName -split "\@")[0]
    }
    
    switch ($PSCmdlet.ParameterSetName) {
        'CredentialObject' {
            if ($Creds.GetNetworkCredential().Domain -ne '')  {
                $UserName= $Creds.GetNetworkCredential().UserName
                $Password = $Creds.GetNetworkCredential().Password
                $DomainName = $Creds.GetNetworkCredential().Domain
                $UsingAltCred = $true
            }
            else {
                throw 'The credential object must include a defined domain.'
            }
        }
        'Credential' {
            if (-not $DomainName) {
                Write-Error 'Username must be in @domainname.com or <domainname>\<username> format or the domain name must be manually passed in the DomainName parameter'
                return $null
            }
            else {
                $UserName = $DomainName + '\' + $UserName
                $UsingAltCred = $true
            }
        }
    }

    $ADServer = ''
    
    # If a computer name was specified then we will attempt to perform a remote connection
    if ($ComputerName) {
        # If a computername was specified then we are connecting remotely
        $ADServer = "LDAP://$($ComputerName)"
        $ContextType = [System.DirectoryServices.ActiveDirectory.DirectoryContextType]::DirectoryServer

        if ($UsingAltCred) {
            $ADContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext $ContextType, $ComputerName, $UserName, $Password
        }
        else {
            if ($ComputerName) {
                $ADContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext $ContextType, $ComputerName
            }
            else {
                $ADContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext $ContextType
            }
        }
        
        try {
            switch ($ADContextType) {
                'ADContext' {
                    return $ADContext
                }
                'DirectoryEntry' {
                    if ($UsingAltCred) {
                        return New-Object System.DirectoryServices.DirectoryEntry($ADServer ,$UserName, $Password)
                    }
                    else {
                        return New-Object -TypeName System.DirectoryServices.DirectoryEntry $ADServer
                    }
                }
                'Forest' {
                    return [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($ADContext)
                }
                'Domain' {
                    return [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($ADContext)
                }
            }
        }
        catch {
            throw
        }
    }
    
    # If using just an alternate credential without specifying a remote computer (dc) to connect they
    # try connecting to the locally joined domain with the credentials.
    if ($UsingAltCred) {
        # *** FINISH ME ***
    }
    # We have not specified another computer or credential so connect to the local domain if possible.
    try {
        $ContextType = [System.DirectoryServices.ActiveDirectory.DirectoryContextType]::Domain
    }
    catch {
        throw 'Unable to connect to a default domain. Is this a domain joined account?'
    }
    try {
        switch ($ADContextType) {
            'ADContext' {
                return New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext $ContextType
            }
            'DirectoryEntry' {
                return [System.DirectoryServices.DirectoryEntry]''
            }
            'Forest' {
                return [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
            }
            'Domain' {
                return [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
            }
        }
    }
    catch {
        throw
    }
}

function Search-AD {
    # Original Author (largely unmodified btw): 
    #  http://becomelotr.wordpress.com/2012/11/02/quick-active-directory-search-with-pure-powershell/
    [CmdletBinding()]
    param (
        [string[]]$Filter,
        [string[]]$Properties = @('Name','ADSPath'),
        [string]$SearchRoot='',
        [switch]$DontJoinAttributeValues,
        [System.DirectoryServices.DirectoryEntry]$DirectoryEntry = $null
    )

    if ($DirectoryEntry -ne $null) {
        if ($SearchRoot -ne '') {
            $DirectoryEntry.set_Path($SearchRoot)
        }
    }
    else {
        $DirectoryEntry = [System.DirectoryServices.DirectoryEntry]$SearchRoot
    }

    if ($Filter) {
        $LDAP = "(&({0}))" -f ($Filter -join ')(')
    }
    else {
        $LDAP = "(name=*)"
    }
    try {
        (New-Object System.DirectoryServices.DirectorySearcher -ArgumentList @(
            $DirectoryEntry,
            $LDAP,
            $Properties
        ) -Property @{
            PageSize = 1000
        }).FindAll() | ForEach-Object {
            $ObjectProps = @{}
            $_.Properties.GetEnumerator() |
                Foreach-Object {
                    $Val = @($_.Value)
                    if ($_.Name -ne $null) {
                        if ($DontJoinAttributeValues -and ($Val.Count -gt 1)) {
                            $ObjectProps.Add($_.Name,$_.Value)
                        }
                        else {
                            $ObjectProps.Add($_.Name,(-join $_.Value))
                        }
                    }
                }
            if ($ObjectProps.psbase.keys.count -ge 1) {
                New-Object PSObject -Property $ObjectProps | Select $Properties
            }
        }
    }
    catch {
        Write-Warning -Message ('Search-AD: Filter - {0}: Root - {1}: Error - {2}' -f $LDAP,$Root.Path,$_.Exception.Message)
    }
}

function Format-LyncADAccount {
    [cmdletbinding()]
    param(
        [Parameter(HelpMessage='User or users to process.', Mandatory=$true, ValueFromPipeline=$true)]
        [psobject]$User,
        [Parameter(HelpMessage='Type of account.')]
        [string]$PhoneType = ''
    )
    begin {}
    process {
        $userinfo = @{
            UserName = $User.Name
            UserLogin = $User.SamAccountName
            SID = $User.SID
            dn = $User.distinguishedName
            Enabled = $null
            SIPAddress = $User.'msrtcsip-primaryuseraddress'
            PhoneType = ''
            LyncEnabled = $null
            UMEnabled = $null
            OU = $User.distinguishedName -replace "$(($User.distinguishedName -split ',')[0]),",''
            Extension = $null
            email = $User.mail
            DID = $null
            DDI = $null
            PrivateDID = $null
            ADPhoneNumber = $User.telephoneNumber
            department = $User.department
            office = $User.physicalDeliveryOfficeName
            Notes = ''
        }
        if ($User.useraccountcontrol -ne $null) {
            $userinfo.Enabled = -not (Convert-ADUserAccountControl $User.useraccountcontrol).ACCOUNTDISABLE
        }
        $userinfo.LyncEnabled = if ($User.'msRTCSIP-UserEnabled') {$true} else {$false}
        $userinfo.UMEnabled = if ($User.msExchUMEnabledFlags -ne $null) {$true} else {$false}
        $userinfo.Extension = if ($User.'msRTCSIP-Line' -match '^.*ext=(.*)$') {$matches[1]}
        $userinfo.DID = if ($User.'msRTCSIP-Line' -ne $null) {$User.'msRTCSIP-Line'}
        $userinfo.DDI = if ($User.'msRTCSIP-Line' -match '^tel:\+*(.*).*$') {$Matches[1]} `
        $userinfo.PrivateDID = if ($User.'msRTCSIP-PrivateLine' -ne $null) {$User.'msRTCSIP-PrivateLine'}
        switch ($User.'msrtcsip-ownerurn') {
            'urn:application:Caa' {
                $userinfo.PhoneType = 'DialIn Conferencing'
            }
            'msrtcsip-ownerurn' {
                $userinfo.PhoneType = 'RGS Workflow'
            }
            'urn:device:commonareaphone' {
                $userinfo.PhoneType = 'Common Area'
            }
            
            default {
                $userinfo.PhoneType = $PhoneType
            }
        }

        New-Object psobject -Property $userinfo
    }
    end {}
}

function Convert-ADUserAccountControl {
    <#
        author: Zachary Loeber
        http://support.microsoft.com/kb/305144
        http://msdn.microsoft.com/en-us/library/cc245514.aspx
        
        Takes the useraccesscontrol property, evaluates it, and spits out an object with all set UAC properties
    #>
    [cmdletbinding()]
    param(
        [Parameter(HelpMessage='User or users to process.', Mandatory=$true, ValueFromPipeline=$true)]
        [string]$UACProperty
    )

    Add-Type -TypeDefinition @"
    [System.Flags]
    public enum userAccountControlFlags {
        SCRIPT                                  = 0x0000001,
        ACCOUNTDISABLE                          = 0x0000002,
        NOT_USED                                = 0x0000004,
        HOMEDIR_REQUIRED                        = 0x0000008,
        LOCKOUT                                 = 0x0000010,
        PASSWD_NOTREQD                          = 0x0000020,
        PASSWD_CANT_CHANGE                      = 0x0000040,
        ENCRYPTED_TEXT_PASSWORD_ALLOWED         = 0x0000080,
        TEMP_DUPLICATE_ACCOUNT                  = 0x0000100,
        NORMAL_ACCOUNT                          = 0x0000200,
        INTERDOMAIN_TRUST_ACCOUNT               = 0x0000800,
        WORKSTATION_TRUST_ACCOUNT               = 0x0001000,
        SERVER_TRUST_ACCOUNT                    = 0x0002000,
        DONT_EXPIRE_PASSWD                      = 0x0010000,
        MNS_LOGON_ACCOUNT                       = 0x0020000,
        SMARTCARD_REQUIRED                      = 0x0040000,
        TRUSTED_FOR_DELEGATION                  = 0x0080000,
        NOT_DELEGATED                           = 0x0100000,
        USE_DES_KEY_ONLY                        = 0x0200000,
        DONT_REQUIRE_PREAUTH                    = 0x0400000,
        PASSWORD_EXPIRED                        = 0x0800000,
        TRUSTED_TO_AUTH_FOR_DELEGATION          = 0x1000000
    }
"@
    $UACAttribs = @(
        'SCRIPT',
        'ACCOUNTDISABLE',
        'NOT_USED',
        'HOMEDIR_REQUIRED',
        'LOCKOUT',
        'PASSWD_NOTREQD',
        'PASSWD_CANT_CHANGE',
        'ENCRYPTED_TEXT_PASSWORD_ALLOWED',
        'TEMP_DUPLICATE_ACCOUNT',
        'NORMAL_ACCOUNT',
        'INTERDOMAIN_TRUST_ACCOUNT',
        'WORKSTATION_TRUST_ACCOUNT',
        'SERVER_TRUST_ACCOUNT',
        'DONT_EXPIRE_PASSWD',
        'MNS_LOGON_ACCOUNT',
        'SMARTCARD_REQUIRED',
        'TRUSTED_FOR_DELEGATION',
        'NOT_DELEGATED',
        'USE_DES_KEY_ONLY',
        'DONT_REQUIRE_PREAUTH',
        'PASSWORD_EXPIRED',
        'TRUSTED_TO_AUTH_FOR_DELEGATION',
        'PARTIAL_SECRETS_ACCOUNT'
    )

    try {
        Write-Verbose ('Convert-ADUserAccountControl: Converting UAC.')
        $UACOutput = New-Object psobject
        $UAC = [Enum]::Parse('userAccountControlFlags', $UACProperty)
        $UACAttribs | Foreach {
            Add-Member -InputObject $UACOutput -MemberType NoteProperty -Name $_ -Value ($UAC -match $_) -Force
        }
        Write-Output $UACOutput
    }
    catch {
        Write-Warning -Message ('Convert-ADUserAccountControl: {0}' -f $_.Exception.Message)
    }
}

function Append-ADUserAccountControl {
    <#
        author: Zachary Loeber
        http://support.microsoft.com/kb/305144
        http://msdn.microsoft.com/en-us/library/cc245514.aspx
        
        Takes an object containing the useraccesscontrol property, evaluates it, and appends all set UAC properties
    #>
    [cmdletbinding()]
    param(
        [Parameter(HelpMessage='User or users to process.', Mandatory=$true, ValueFromPipeline=$true)]
        [psobject[]]$User
    )

    begin {
        Add-Type -TypeDefinition @" 
        [System.Flags]
        public enum userAccountControlFlags {
            SCRIPT                                  = 0x0000001,
            ACCOUNTDISABLE                          = 0x0000002,
            NOT_USED                                = 0x0000004,
            HOMEDIR_REQUIRED                        = 0x0000008,
            LOCKOUT                                 = 0x0000010,
            PASSWD_NOTREQD                          = 0x0000020,
            PASSWD_CANT_CHANGE                      = 0x0000040,
            ENCRYPTED_TEXT_PASSWORD_ALLOWED         = 0x0000080,
            TEMP_DUPLICATE_ACCOUNT                  = 0x0000100,
            NORMAL_ACCOUNT                          = 0x0000200,
            INTERDOMAIN_TRUST_ACCOUNT               = 0x0000800,
            WORKSTATION_TRUST_ACCOUNT               = 0x0001000,
            SERVER_TRUST_ACCOUNT                    = 0x0002000,
            DONT_EXPIRE_PASSWD                      = 0x0010000,
            MNS_LOGON_ACCOUNT                       = 0x0020000,
            SMARTCARD_REQUIRED                      = 0x0040000,
            TRUSTED_FOR_DELEGATION                  = 0x0080000,
            NOT_DELEGATED                           = 0x0100000,
            USE_DES_KEY_ONLY                        = 0x0200000,
            DONT_REQUIRE_PREAUTH                    = 0x0400000,
            PASSWORD_EXPIRED                        = 0x0800000,
            TRUSTED_TO_AUTH_FOR_DELEGATION          = 0x1000000
        }
"@
        $Users = @()
        $UACAttribs = @(
            'SCRIPT',
            'ACCOUNTDISABLE',
            'NOT_USED',
            'HOMEDIR_REQUIRED',
            'LOCKOUT',
            'PASSWD_NOTREQD',
            'PASSWD_CANT_CHANGE',
            'ENCRYPTED_TEXT_PASSWORD_ALLOWED',
            'TEMP_DUPLICATE_ACCOUNT',
            'NORMAL_ACCOUNT',
            'INTERDOMAIN_TRUST_ACCOUNT',
            'WORKSTATION_TRUST_ACCOUNT',
            'SERVER_TRUST_ACCOUNT',
            'DONT_EXPIRE_PASSWD',
            'MNS_LOGON_ACCOUNT',
            'SMARTCARD_REQUIRED',
            'TRUSTED_FOR_DELEGATION',
            'NOT_DELEGATED',
            'USE_DES_KEY_ONLY',
            'DONT_REQUIRE_PREAUTH',
            'PASSWORD_EXPIRED',
            'TRUSTED_TO_AUTH_FOR_DELEGATION',
            'PARTIAL_SECRETS_ACCOUNT'
        )
    }
    process {
        $Users += $User
    }
    end {
        foreach ($usr in $Users) {
            if ($usr.PSObject.Properties.Match('useraccountcontrol').Count) {
                try {
                    Write-Verbose ('Append-ADUserAccountControl: Found useraccountcontrol property, enumerating.')
                    $UAC = [Enum]::Parse('userAccountControlFlags', $usr.useraccountcontrol)
                    $UACAttribs | Foreach {
                        Add-Member -InputObject $usr -MemberType NoteProperty -Name $_ -Value ($UAC -match $_) -Force
                    }
                    Write-Output $usr
                }
                catch {
                    Write-Warning -Message ('Append-ADUserAccountControl: {0}' -f $_.Exception.Message)
                }
            }
            else {
                # if the uac property does not exist add all the uac properties to maintain like output
                $UACAttribs | Foreach {
                    Write-Verbose ('Append-ADUserAccountControl: useraccountcontrol property NOT found.')
                    Add-Member -InputObject $usr -MemberType NoteProperty -Name $_ -Value $null -Force
                }
                Write-Output $usr
            }
        }
    }
}

function Get-LyncEnabledObjectsFromAD {
    [cmdletbinding()]
    param(
        [Parameter(HelpMessage='Base of AD to search.')]
        $SearchBase = ''
    )

    try {
        $conn = Connect-ActiveDirectory -ADContextType:DirectoryEntry
        $DomainDN = $conn.distinguishedName
        $ConfigurationDN = 'CN=Configuration,' + $DomainDN
        if ($SearchBase -eq '') {
            $SearchBase = [string]$DomainDN
        }
    }
    catch {
        Write-Warning 'Unabled to connect to AD!'
        $conn = $null
    }
    if ($conn -ne $null) {
        $LyncContacts = @()
        $LyncUsers = @()
        $Properties = @('Name','SamAccountName','SID','distinguishedName','useraccountcontrol','msRTCSIP-UserEnabled','msExchUMEnabledFlags','msRTCSIP-Line','msrtcsip-ownerurn','msRTCSIP-PrivateLine','msrtcsip-primaryuseraddress','telephoneNumber','OfficePhone','mail','department','physicalDeliveryOfficeName')

        #$Users = @(Search-AD -DirectoryEntry $conn -Filter '(objectCategory=person)(objectClass=user)(!(useraccountcontrol:1.2.840.113556.1.4.803:=2))(msRTCSIP-Line=*)' -Properties $Properties -SearchRoot ('LDAP://' + $SearchBase))
        $LyncUsers = @(Search-AD -DirectoryEntry $conn -Filter '(objectCategory=person)(objectClass=user)(|(msRTCSIP-Line=*)(msRTCSIP-PrivateLine=*))' -Properties $Properties -SearchRoot ('LDAP://' + $SearchBase))
        $LyncUsers = $LyncUsers | Format-LyncADAccount -PhoneType 'LyncUser'

        # Get configuration partition Lync enabled items (conference and RGS numbers)
        $LyncContacts = @(Search-AD -DirectoryEntry $conn -Filter '(ObjectClass=contact)(msRTCSIP-Line=*)' -Properties $Properties -SearchRoot ('LDAP://' + $SearchBase) | Format-LyncADAccount)

        # Get UM auto-attendant numbers assigned in exchange (from AD)
        $AANumbers = @(Search-AD -DontJoinAttributeValues -DirectoryEntry $conn -Filter '(ObjectClass=msExchUMAutoAttendant)' -Properties * -SearchRoot ('LDAP://' + $ConfigurationDN) | 
        Where {$_.msExchUMAutoAttendantDialedNumbers} | Select -ExpandProperty msExchUMAutoAttendantDialedNumbers)
        $AAMatchNumbers = @($AANumbers | Foreach {[regex]::Escape($_)})
        $AAMatchNumbers = '^(' + ($AAMatchNumbers -join '|') + ')$'

        # Get all UM voicemail numbers assigned in exchange (from AD)
        $VMNumbers = @(Search-AD -DontJoinAttributeValues -DirectoryEntry $conn -Filter '(ObjectClass=msExchUMDialPlan)' -Properties * -SearchRoot ('LDAP://' + $ConfigurationDN) | 
        Where {($_.msExchUMVoiceMailPilotNumbers).Count -gt 0} | Select -ExpandProperty msExchUMVoiceMailPilotNumbers)
        $VMMatchNumbers = @($VMNumbers | Foreach {[regex]::Escape($_)})
        $VMMatchNumbers = '^(' + ($VMMatchNumbers -join '|') + ')$'

        # Look for voicemail and AA enabled contacts by matching them up with what you found in ad
        $LyncContacts | Foreach {
            $tmpURI = $_.DID -replace 'tel:',''
            if ($tmpURI -match $AAMatchNumbers) {
                $_.PhoneType = 'UM Auto Attendant'
            }
            elseif ($tmpURI -match $VMMatchNumbers) {
                $_.PhoneType = 'UM Voicemail'
            }
        }

        Write-Output $LyncUsers
        Write-Output $LyncContacts
    }
}
