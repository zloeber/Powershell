﻿function New-ZipFile {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]$ZipFilePath,
        [Parameter(Position=1, Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("PSPath","Item")]
        [string[]]$InputObject = $Pwd,
        [Parameter(Position=2)]
        [switch]$Append,
        [Parameter(Position=3)]
        [ValidateSet("Optimal","Fastest","NoCompression")]
        [System.IO.Compression.CompressionLevel]$Compression = "Optimal"
    )
    begin {
        # Make sure the folder already exists
        [string]$File = Split-Path $ZipFilePath -Leaf
        [string]$Folder = $(if($Folder = Split-Path $ZipFilePath) { Resolve-Path $Folder } else { $Pwd })
        $ZipFilePath = Join-Path $Folder $File
        # If they don't want to append, make sure the zip file doesn't already exist.
        if(!$Append) {
            if(Test-Path $ZipFilePath) { 
                Remove-Item $ZipFilePath 
            }
        }
        $Archive = [System.IO.Compression.ZipFile]::Open( $ZipFilePath, "Update" )
    }
    process {
        foreach($path in $InputObject) {
            foreach($item in Resolve-Path $path) {
                # Push-Location so we can use Resolve-Path -Relative 
                Push-Location (Split-Path $item)
                # This will get the file, or all the files in the folder (recursively)
                foreach($file in Get-ChildItem $item -Recurse -File -Force | % FullName) {
                    # Calculate the relative file path
                    $relative = (Resolve-Path $file -Relative).TrimStart(".\")
                    # Add the file to the zip
                    $null = [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive, $file, $relative, $Compression)
                }
                Pop-Location
            }
        }
    }
    end {
        $Archive.Dispose()
        Get-Item $ZipFilePath
    }
}

function New-ReportDelivery {
    [CmdletBinding()]
    param (
        [Parameter( HelpMessage="Report body, typically in HTML format", ValueFromPipeline=$true )]
        [string]$Report,
        [Parameter( HelpMessage="Email server to relay report through")]
        [string]$EmailRelay = ".",
        [Parameter( HelpMessage="Email sender")]
        [string]$EmailSender='systemreport@localhost',
        [Parameter( Mandatory=$true, HelpMessage="Email recipient")]
        [string]$EmailRecipient,
        [Parameter( HelpMessage="Email subject")]
        [string]$EmailSubject='System Report',
        [Parameter( HelpMessage="Email report(s) as attachement")]
        [switch]$EmailAsAttachment,
        [Parameter( HelpMessage="Force email to be sent anonymously?")]
        [switch]$ForceAnonymous,
        [Parameter( HelpMessage="Save the report?")]
        [switch]$SaveReport,
        [Parameter( HelpMessage="Zip the report(s).")]
        [switch]$ZipReport
    )
    $SendMailSplat = @{
        'From' = $EmailSender
        'To' = $EmailRecipient
        'Subject' = $EmailSubject
        'Priority' = 'Normal'
        'smtpServer' = $EmailRelay
        'BodyAsHTML' = $true
    }
    if ($ForceAnonymous) {
        $Pass = ConvertTo-SecureString –String 'anonymous' –AsPlainText -Force
        $Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "NT AUTHORITY\ANONYMOUS LOGON", $pass
        $SendMailSplat.Credential = $creds
    }
    if ($EmailAsAttachment) {
        if ($ZipReport) {
            $ZipName = $ReportName -replace '.html','.zip'
            $Reports | New-ZipFile -ZipFilePath $ZipName -Append
        }
        else {
            $SendMailSplat.Attachments = $Reports
        }
    }
    else {
        $SendMailSplat.Body = $Report
    }
    send-mailmessage @SendMailSplat
}
 
function Get-LPInputFormat{
 
	param([String]$InputType)
 
	switch($InputType.ToLower()){
		"ads"{$inputobj = New-Object -comObject MSUtil.LogQuery.ADSInputFormat}
		"bin"{$inputobj = New-Object -comObject MSUtil.LogQuery.IISBINInputFormat}
		"csv"{$inputobj = New-Object -comObject MSUtil.LogQuery.CSVInputFormat}
		"etw"{$inputobj = New-Object -comObject MSUtil.LogQuery.ETWInputFormat}
		"evt"{$inputobj = New-Object -comObject MSUtil.LogQuery.EventLogInputFormat}
		"fs"{$inputobj = New-Object -comObject MSUtil.LogQuery.FileSystemInputFormat}
		"httperr"{$inputobj = New-Object -comObject MSUtil.LogQuery.HttpErrorInputFormat}
		"iis"{$inputobj = New-Object -comObject MSUtil.LogQuery.IISIISInputFormat}
		"iisodbc"{$inputobj = New-Object -comObject MSUtil.LogQuery.IISODBCInputFormat}
		"ncsa"{$inputobj = New-Object -comObject MSUtil.LogQuery.IISNCSAInputFormat}
		"netmon"{$inputobj = New-Object -comObject MSUtil.LogQuery.NetMonInputFormat}
		"reg"{$inputobj = New-Object -comObject MSUtil.LogQuery.RegistryInputFormat}
		"textline"{$inputobj = New-Object -comObject MSUtil.LogQuery.TextLineInputFormat}
		"textword"{$inputobj = New-Object -comObject MSUtil.LogQuery.TextWordInputFormat}
		"tsv"{$inputobj = New-Object -comObject MSUtil.LogQuery.TSVInputFormat}
		"urlscan"{$inputobj = New-Object -comObject MSUtil.LogQuery.URLScanLogInputFormat}
		"w3c"{$inputobj = New-Object -comObject MSUtil.LogQuery.W3CInputFormat}
		"xml"{$inputobj = New-Object -comObject MSUtil.LogQuery.XMLInputFormat}
	}
	return $inputobj
}

function Get-LPOutputFormat{
	param([String]$OutputType)

	switch($OutputType.ToLower()){
		"csv"{$outputobj = New-Object -comObject MSUtil.LogQuery.CSVOutputFormat}
		"chart"{$outputobj = New-Object -comObject MSUtil.LogQuery.ChartOutputFormat}
		"iis"{$outputobj = New-Object -comObject MSUtil.LogQuery.IISOutputFormat}
		"sql"{$outputobj = New-Object -comObject MSUtil.LogQuery.SQLOutputFormat}
		"syslog"{$outputobj = New-Object -comObject MSUtil.LogQuery.SYSLOGOutputFormat}
		"tsv"{$outputobj = New-Object -comObject MSUtil.LogQuery.TSVOutputFormat}
		"w3c"{$outputobj = New-Object -comObject MSUtil.LogQuery.W3COutputFormat}
		"tpl"{$outputobj = New-Object -comObject MSUtil.LogQuery.TemplateOutputFormat} 
	}
	return $outputobj
}

function Invoke-LPExecute{
	param([string] $query, $inputtype)
    $LPQuery = new-object -com MSUtil.LogQuery
	if($inputtype){
    	$LPRecordSet = $LPQuery.Execute($query, $inputtype)	
	}
	else {
		$LPRecordSet = $LPQuery.Execute($query)
	}
    return $LPRecordSet
}

function Invoke-LPExecuteBatch{
	param([string]$query, $inputtype, $outputtype)
    $LPQuery = new-object -com MSUtil.LogQuery
    $result = $LPQuery.ExecuteBatch($query, $inputtype, $outputtype)
    return $result
}

function Get-LPRecord{
	param($LPRecordSet)
	$LPRecord = new-Object System.Management.Automation.PSObject
	if( -not $LPRecordSet.atEnd() ) {
		$Record = $LPRecordSet.getRecord()
		for($i = 0; $i -lt $LPRecordSet.getColumnCount();$i++) {
			$LPRecord | add-member NoteProperty $LPRecordSet.getColumnName($i) -value $Record.getValue($i)
		}
	}
	return $LPRecord
}

function Get-LPRecordSet{ 
	param([string]$query)

	# Execute Query
	$LPRecordSet = Invoke-LPExecute $query
	$LPRecords = new-object System.Management.Automation.PSObject[] 0
	for(; -not $LPRecordSet.atEnd(); $LPRecordSet.moveNext()) {
		# Add record
		$LPRecord = Get-LPRecord($LPRecordSet)
		$LPRecords += new-Object System.Management.Automation.PSObject	
        $RecordCount = $LPQueryResult.length-1
        $LPRecords[$RecordCount] = $LPRecord
	}
	$LPRecordSet.Close();
	return $LPRecords
}

# Set your server IIS log file locations here (replace the examples)
$FileLocations = @('\\server1\c$\inetpub\logs\LogFiles\W3SVC1',
                   '\\server2\c$\inetpub\logs\LogFiles\W3SVC1')
$LogFiles = @()
# Only process files this many days old
$DaysOld = 1
$Currdate = Get-Date
$Logfiles += (Get-ChildItem -Path $FileLocations | Where {$_.LastWriteTime -ge ($Currdate.AddDays(-$DaysOld)) -and (-not $_.PsIsContainer)}).FullName
$LogQuery = New-Object -ComObject "MSUtil.LogQuery"
$InputFormat = Get-LPInputFormat "iis"

# Change this to be any query which you'd like to run. This example is for failed auth attempts.
$SQLQuery = "SELECT cs-username, sc-status, COUNT(*) AS Total FROM " + ($LogFiles -join ',') + " WHERE cs-username IS NOT NULL AND sc-status BETWEEN 401 AND 403 GROUP BY cs-username,sc-status, cs-uri-stem ORDER BY Total DESC "

# Example 2:  TOP 25 Slowest Url requests

#$SQLQuery = 'SELECT TOP 25 cs-uri-stem as URL, MAX(time-taken) As Max, MIN(time-taken) As Min, Avg(time-taken) As Average FROM ' + ($LogFiles -join ',') +' GROUP BY URL ORDER By Average DESC'

[string]$Report = Get-LPRecordSet $SQLQuery $inputformat | ConvertTo-Html

# Uncomment to save a copy of the report
#$Report | Out-File c:\Scripts\AuthErr_Report.html

New-ReportDelivery -EmailSender 'server1@contoso.com' `
                   -EmailRecipient 'admin@contoso.com' `
                   -EmailSubject "Yesterday's Exchange Auth Failures" `
                   -EmailRelay 'server1.contoso.com' `
                   -ForceAnonymous -Report $Report
