function Send-EnhancedMailMessage {
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage='Report body, typically in HTML format')]
        [string]$EmailBody,
        [Parameter(HelpMessage='Email server to relay report through')]
        [string]$EmailRelay = '.',
        [Parameter(HelpMessage='Email sender')]
        [string]$EmailSender='systemreport@localhost',
        [Parameter(Mandatory=$true, HelpMessage='Email recipient')]
        [string]$EmailRecipient,
        [Parameter(HelpMessage='Email subject')]
        [string]$EmailSubject='Report',
        [Parameter(HelpMessage='Paths to email attachments')]
        [string[]]$Attachments,
        [Parameter(HelpMessage='Force email to be sent anonymously?')]
        [switch]$ForceAnonymous
    )
    $SendMailSplat = @{
        'From' = $EmailSender
        'To' = $EmailRecipient
        'Subject' = $EmailSubject
        'Priority' = 'Normal'
        'SMTPServer' = $EmailRelay
        'BodyAsHTML' = $true
        'Body' = $EmailBody
    }
    if ($ForceAnonymous) {
        $Pass = ConvertTo-SecureString -String 'anonymous' -AsPlainText -Force
        $Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList 'NT AUTHORITY\ANONYMOUS LOGON', $pass
        $SendMailSplat.Credential = $creds
    }
    if ($Attachments.Count -ge 1) {
        $SendMailSplat.Attachments = $Attachments
    }

    Send-MailMessage @SendMailSplat
}
