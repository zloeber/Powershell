function Get-LyncAndUMInfo {
    <#
    .SYNOPSIS
    Gather lync enabled user information for current domain.
    .DESCRIPTION
    Gather lync enabled user information for current domain. This is meant to be run on a Lync server and uses both the Lync
    and AD modules. Exchange UM information is pulled directly from AD attributes. Information gathered incluedes:
        Name                    -> AD account name
        Enabled                 -> AD enabled state
        FirstName               -> First Name
        LastName                -> Last Name
        Email                   -> Email as seen in AD
        SipAddress              -> Primary sip address
        EnterpriseVoiceEnabled  -> If the account is enterprise voice enabled or not
        DialPlan                -> Lync dial plan
        VoicePolicy             -> Lync voice policy
        LyncPinSet              -> If a Lync pin is set
        LyncTelURI              -> Full Lync phone URI
        LyncPhone               -> Primary phone of URI (tel:+#########)
        LyncPhoneExt            -> Extension of URI (;ext=####)
        VoicemailEnabled        -> If the account is voicemail enabled
        VoicemailExtension      -> The voicemail extension (EUM smtp proxy address)
    .EXAMPLE
    $Users = Get-LyncAndUMInfo
    $Users | Export-Csv AllLyncEnabledUserInfo.csv -NoTypeInformation
    $Users | where {(-not $_.Enabled) -and $_.EnterpriseVoiceEnabled} | Export-Csv DisabledWithLyncNumbersStillAssigned.csv -NoTypeInformation
    $Users | where {$_.Enabled -and $_.EnterpriseVoiceEnabled -and (-not $_.LyncPinSet)} | Export-Csv EnabledWithLyncNumbersAssignedButNoPINSet.csv -NoTypeInformation
    $Users | where {$_.Enabled -and $_.EnterpriseVoiceEnabled -and (-not $_.VoicemailEnabled)} | Export-Csv EnabledWithLyncNumbersAssignedButNoVoicemailConfigured.csv -NoTypeInformation

    Description
    -----------
    Collects information about all Lync enabled users in the domain and creates 4 reports.

    1. AllLyncEnabledUserInfo.csv -> All information gathered with this function
    2. DisabledWithLyncNumbersStillAssigned.csv -> All disabled accounts still enterprise voice enabled
    3. EnabledWithLyncNumbersAssignedButNoPINSet.csv -> All enterprise voice enabled accounts without a set pin
    4. EnabledWithLyncNumbersAssignedButNoVoicemailConfigured.csv -> All enterprise voice enabled accounts without voicemail boxes configured

    .OUTPUTS
    PSObject
    .LINK
    http://the-little-things.net/
    https://github.com/zloeber/Powershell
    .NOTES
    Author:  Zachary Loeber
    Created: 11/09/2014
    #>
    $ADProperties = @('Name','SamAccountName','mail','proxyAddresses','msRTCSIP-UserEnabled','msRTCSIP-Line','msExchUMEnabledFlags','msExchUMDtmfMap','msRTCSIP-PrimaryUserAddress')
    Get-ADUser -Filter '*' -Properties $ADProperties | Where {($_.'msRTCSIP-UserEnabled' -ne $null) -and ($_.'msRTCSIP-UserEnabled' -ne $false)} | Foreach {
        Write-Host "Get-LyncAndUMInfo: Processing User - $($_.Name)($($_.'msRTCSIP-PrimaryUserAddress'))"
        $LyncInfo = Get-CSUser $_.'msRTCSIP-PrimaryUserAddress' | Select SipAddress,EnterpriseVoiceEnabled,ExUmEnabled,DialPlan,VoicePolicy, `
                                                @{'n'='LyncPINSet';'e'={if ($_.EnterpriseVoiceEnabled){($_ | Get-CSClientPinInfo).IsPinSet} else {$false}}}
        if ($LyncInfo.ExUmEnabled)
        {
            $VoicemailExtension = $_.proxyAddresses | Where {$_ -match '^eum:(\d+).*$'} | Foreach {$Matches[1]}
        }
        else
        {
            $VoicemailExtension = $null
        }
        $UserProps = @{
            'Name' = $_.Name
            'Enabled' = $_.Enabled
            'FirstName' = $_.GivenName
            'LastName' = $_.Surname
            'Email' = $_.mail
            'SipAddress' = $LyncInfo.SipAddress
            'EnterpriseVoiceEnabled' = $LyncInfo.EnterpriseVoiceEnabled
            'DialPlan' = $LyncInfo.DialPlan
            'VoicePolicy' = $LyncInfo.VoicePolicy
            'LyncPinSet' = $LyncInfo.LyncPinSet
            'LyncTelURI' = $_.'msRTCSIP-Line'
            'LyncPhone' = if ($_.'msRTCSIP-Line' -match '^tel:(\+\d+).*$'){$matches[1]} else {$null}
            'LyncPhoneExt' = if ($_.'msRTCSIP-Line' -match '^.*ext=(.*)$'){$matches[1]} else {$null}
            'VoicemailEnabled' = $LyncInfo.ExUmEnabled #if ($_.msExchUMEnabledFlags -ne $null){$true} else {$false}
            'VoicemailExtension' = $VoicemailExtension
        }
        New-Object PSObject -Property $UserProps
    }
}