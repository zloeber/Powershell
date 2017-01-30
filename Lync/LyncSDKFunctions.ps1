# A few Lync SDK example functions

function Load-LyncSDK {
    [CmdLetBinding()]
    param(
        [Parameter(Position=0, HelpMessage='Full SDK location (ie C:\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.dll). If not defined then typical locations will be attempted.')]
        [string]$SDKLocation
    )
    $LyncSDKLoaded = $false
    if (-not (Get-Module -Name Microsoft.Lync.Model)) {
        if (($SDKLocation -eq $null) -or ($SDKLocation -eq '')) {
            try { # Try loading the 32 bit version first
                Import-Module -Name (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "Microsoft Office\Office15\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.dll") -ErrorAction Stop
                $LyncSDKLoaded = $true
            }
            catch {}
            try { # Otherwise try the 64 bit version
                Import-Module -Name (Join-Path -Path ${env:ProgramFiles} -ChildPath "Microsoft Office\Office15\LyncSDK\Assemblies\Desktop\Microsoft.Lync.Model.dll") -ErrorAction Stop
                $LyncSDKLoaded = $true
            }
            catch {}
        }
        else {
            try {
                Import-Module -Name $SDKLocation -ErrorAction Stop
                $LyncSDKLoaded = $true
            }
            catch {}
        }
    }
    else {
        $LyncSDKLoaded = $true
    }
    return $LyncSDKLoaded
}

function Publish-LyncContactInformation {
    <#
    .SYNOPSIS
    Publish-LyncContactInformation is a PowerShell function to configure a set of settings in the Microsoft Lync client.
    .DESCRIPTION
    The purpose of Publish-LyncContactInformation is to demonstrate how PowerShell can be used to interact with the Lync SDK.
    Tested with Lync 2013 only.
    Prerequisites: Lync 2013 SDK - http://www.microsoft.com/en-us/download/details.aspx?id=36824
    .EXAMPLE
    Publish-LyncContactInformation -Availability Available
    .EXAMPLE
    Publish-LyncContactInformation -Availability Away
    .EXAMPLE
    Publish-LyncContactInformation -Availability "Off Work" -ActivityId off-work
    .EXAMPLE
    Publish-LyncContactInformation -PersonalNote test
    .EXAMPLE
    Publish-LyncContactInformation -Availability Available -PersonalNote ("Quote of the day: " + (Get-QOTD))
    .EXAMPLE
    Publish-LyncContactInformation -Location Work
    .NOTES
    For more information, see the related blog post at blog.powershell.no
    .FUNCTIONALITY
    Provides a function to configure Availability, ActivityId and PersonalNote for the Microsoft Lync client.
    #>

    param(
    [ValidateSet("Appear Offline","Available","Away","Busy","Do Not Disturb","Be Right Back","Off Work")]
    [string]$Availability,
    [string]$ActivityId,
    [string]$PersonalNote,
    [string]$Location
    )

    $LyncSDKLoaded = Load-LyncSDK
    if (-not $LyncSDKLoaded) {
        Write-Error "Microsoft.Lync.Model not available, download and install the Lync 2013 SDK http://www.microsoft.com/en-us/download/details.aspx?id=36824"
        break
    }

    $Client = [Microsoft.Lync.Model.LyncClient]::GetClient()

    if ($Client.State -eq "SignedIn") {
        $Self = $Client.Self
        $ContactInfo = New-Object 'System.Collections.Generic.Dictionary[Microsoft.Lync.Model.PublishableContactInformationType, object]'
        switch ($Availability) {
            "Available" {$AvailabilityId = 3000}
            "Appear Offline" {$AvailabilityId = 18000}
            "Away" {$AvailabilityId = 15000}
            "Busy" {$AvailabilityId = 6000}
            "Do Not Disturb" {$AvailabilityId = 9000}
            "Be Right Back" {$AvailabilityId = 12000}
            "Off Work" {$AvailabilityId = 15500}
        }

        if ($Availability) {
            $ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::Availability, $AvailabilityId)
        }

        if ($ActivityId) {
            $ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::ActivityId, $ActivityId)
        }

        if ($PersonalNote) {
            $ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::PersonalNote, $PersonalNote)
        }

        if ($Location) {
            $ContactInfo.Add([Microsoft.Lync.Model.PublishableContactInformationType]::LocationName, $Location)
        }

        if ($ContactInfo.Count -gt 0) {
            $Publish = $Self.BeginPublishContactInformation($ContactInfo, $null, $null)
            $self.EndPublishContactInformation($Publish)
        } 
        else {
            Write-Warning "No options supplied, no action was performed"
        }
    }
    else {
        Write-Warning "Lync is not running or signed in, no action was performed"
    }
}

function Get-LyncPersonalContactInfo {
    <#
    .EXAMPLE
    Get-LyncPersonalContactInfo 'PersonalNote'
    .EXAMPLE
    Get-LyncPersonalContactInfo
    #>
    param(
        [string[]]$TypeNames
    )

    $LyncSDKLoaded = Load-LyncSDK
    if (-not $LyncSDKLoaded) {
        Write-Error "Microsoft.Lync.Model not available, download and install the Lync 2013 SDK http://www.microsoft.com/en-us/download/details.aspx?id=36824"
        break
    }

    $validtypes = @()
    [System.Enum]::GetNames('Microsoft.Lync.Model.ContactInformationType') | Foreach {$validtypes += $_}
    if ($TypeNames.Count -eq 0) {$TypeNames += $validtypes}
    if ((Compare-Object -ReferenceObject $validtypes -DifferenceObject $TypeNames).SideIndicator -contains '=>') {
        Write-Error 'Invalid contact information type requested!'
        break
    }
    else {
        $client = [Microsoft.Lync.Model.LyncClient]::GetClient()
        if ($client.State -eq "SignedIn") {
            $contact = $client.Self.Contact
            $retvals = @{}
            foreach ($typename in $TypeNames) {
                try {
                    $contact.GetContactInformation([Microsoft.Lync.Model.ContactInformationType]::$typename) | Out-Null
                    if ($TypeNames.Count -gt 1) {
                        $retvals.$typename = $contact.GetContactInformation([Microsoft.Lync.Model.ContactInformationType]::$typename)
                    }
                    else {
                        return $contact.GetContactInformation([Microsoft.Lync.Model.ContactInformationType]::$typename)
                    }
                }
                catch {}
            }
            New-Object psobject -Property $retvals
        }
        else {
            Write-Warning "Lync is not running or signed in, no action was performed"
        }
    }
}

function Get-LyncPersonalContacts {
    <#
    .SYNOPSIS
        Retrieve groups and their contacts from Lync via the Lync SDK.
    .DESCRIPTION
        Retrieve groups and their contacts from Lync via the Lync SDK.
        Tested with Lync 2013 and Skype for Business only.
        Prerequisites: Lync 2013 SDK - http://www.microsoft.com/en-us/download/details.aspx?id=36824
    .EXAMPLE
        Get-LyncPersonalContacts | Export-CSV -NoTypeInformation 'C:\Temp\contacts.csv'
        
        Exports all lync contacts from all groups to C:\Temp\Contacts.csv. There may be duplicates if users are in multiple groups.
    .NOTES
    
    #>
    [CmdLetBinding()]
    param()
    
    $DisplayName = 10
    $PrimaryEmailAddress = 12
    $Title = 14
    $Company = 15
    $Phones = 27
    $FirstName = 37
    $LastName = 38
    <#$LyncSDKLoaded = Load-LyncSDK

    if (-not $LyncSDKLoaded) {
        Write-Error "Microsoft.Lync.Model not available, download and install the Lync 2013 SDK http://www.microsoft.com/en-us/download/details.aspx?id=36824"
        break
    }#>

    try {
        $client = [Microsoft.Lync.Model.LyncClient]::GetClient()
    }
    catch {
        throw "Microsoft.Lync.Model not available, download and install the Lync 2013 SDK http://www.microsoft.com/en-us/download/details.aspx?id=36824"
    }
    if ($client.State -eq "SignedIn") {
        $contactgroups = $client.Self.Contact.ContactManager.Groups
        $retval = @{}

        foreach ($g in $contactgroups) {
            Write-Verbose "Contact Group: $($g.Name)"
            foreach ($contact in $g) {
                $retval.Group = $g.Name
                $retval.LastName = $contact.GetContactInformation($LastName)
                $retval.FirstName = $contact.GetContactInformation($FirstName)
                $retval.Title = $contact.GetContactInformation($Title)
                $retval.Company = $contact.GetContactInformation($Company)
                $retval.PrimaryEmailAddress = $contact.GetContactInformation($PrimaryEmailAddress)
                $eps = $contact.GetContactInformation($Phones)
                foreach ($ep in $eps) {
                    $retval.($ep.Type) = $ep.DisplayName
                }
                New-Object psobject -Property $retval
            }
        }
    }
    else {
        Write-Warning "Lync is not running or signed in, no action was performed"
    }
}