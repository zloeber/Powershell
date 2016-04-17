function Export-PSCredential {
    <#
    .SYNOPSIS
        Export credential to file.
    .DESCRIPTION
        Export credential to file which is only able to be used on the system which it was created.
    .PARAMETER FilePath
        File to export credentials.
    .PARAMETER UserName
        Username for credential.
    .PARAMETER Password
        Password for credential.
    .PARAMETER Domain
        Optional domain for credential.
    .PARAMETER Creds
        Pre-populated credential object.
    .EXAMPLE
        Export-PSCredential -FilePath c:\Temp\testcred.cred -Domain 'domain' -Password 'pass' -UserName 'user'

        Description
        -----------
        Export the credentials of the domain user and password specified.

    .EXAMPLE
        $Creds = Get-Credential
        Export-PSCredential -Creds $Creds

        Description
        -----------
        Export the credentials of the $Creds input from user prompt.

    .LINK
        http://the-little-things.net/
    .NOTES
        Author:  Zachary Loeber
        Created: 08/29/2104
    #>
    [CmdLetBinding(DefaultParameterSetName='Default')]
    param (
        [parameter(Mandatory=$True, ParameterSetName='Default',HelpMessage='Saved xml credential file.')]
        [parameter(Mandatory=$True, ParameterSetName='CredStrings',HelpMessage='Saved xml credential file.')]
        [ValidateScript({
            Test-Path ($_ -replace $ExecutionContext.SessionState.Path.ParseChildName($_), '')
        })]
        [string]$FilePath='',
        [parameter(Mandatory=$True, ParameterSetName='CredStrings', HelpMessage='Username')]
        [string]$UserName,
        [parameter(Mandatory=$True, ParameterSetName='CredStrings', HelpMessage='Password')]
        [string]$Password,
        [parameter(ParameterSetName='CredStrings', HelpMessage='Domain')]
        [string]$Domain = '',
        [parameter(Mandatory=$True, ParameterSetName='Default',HelpMessage='Full credential')]
        [System.Management.Automation.PSCredential]$Creds
    )

    if ($PSCmdlet.ParameterSetName -ne 'Default') {
        if ($Domain -ne '') {
            $DomUser = "$Domain\$UserName"
        }
        else {
            $DomUser = $UserName
        }
        $EncPass = ConvertTo-SecureString -String $Password -AsPlainText -Force -Erroraction Stop
        $Creds = New-Object System.Management.Automation.PSCredential -ArgumentList $DomUser, $EncPass -ErrorAction Stop
    }
    try {
        $ExportCreds = '' | Select-Object Username, EncryptedPassword
        $ExportCreds.EncryptedPassword =  $Creds.Password | ConvertFrom-SecureString
        $ExportCreds.Username = $Creds.Username
        $ExportCreds.PSObject.TypeNames.Insert(0,'ExportedPSCredential')
        $ExportCreds | Export-Clixml $FilePath -ErrorAction Stop
    }
    catch {
        throw 'Export-PSCredential: Save Failed!'
    }
}