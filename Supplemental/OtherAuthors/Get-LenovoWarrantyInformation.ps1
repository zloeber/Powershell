function Get-LenovoWarrantyInformation {
    <#
    .SYNOPSIS
        Get warranty information for a Lenovo system
    .DESCRIPTION
        This script will parse through the warranty information webpage for a particular Lenovo system. Required information is the model and serialnumber of the system.
    .PARAMETER Model
        Specify the model information
    .PARAMETER SerialNumber
        Specify the SerialNumber
    .PARAMETER ShowProgress
        Show a progressbar displaying the current operation
    .EXAMPLE
        .\Get-LenovoWarrantyInformation.ps1 -Model "XXXXXXXXXX" -SerialNumber "XXXXXXXX" -ShowProgress
        Get warranty information for a Lenovo system with Model 'XXXXXXXXXX' and SerialNumber 'XXXXXXXX' and show the progress: 
    .NOTES
        Script name: Get-LenovoWarrantyInformation.ps1
        Author:      Nickolaj Andersen
        Contact:     @NickolajA
        DateCreated: 2015-03-21
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true, HelpMessage="Specify the model information")]
        [ValidateNotNullOrEmpty()]
        [string]$Model,
        [parameter(Mandatory=$true, HelpMessage="Specify the SerialNumber")]
        [ValidateNotNullOrEmpty()]
        [string]$SerialNumber,
        [parameter(Mandatory=$false, HelpMessage="Show a progressbar displaying the current operation")]
        [switch]$ShowProgress
    )
    Begin {
        # Not used
    }
    Process {
        if ($PSBoundParameters["ShowProgress"]) {
            $ProgressCount = 0
        }
        $URL = "https://services.lenovo.com/ibapp/il/WarrantyStatus.jsp?type=$($Model)&serial=$($SerialNumber)"
        $WebRequestResult = Invoke-WebRequest -Uri $URL
        $TDTagNames = $WebRequestResult.ParsedHtml.getElementsByTagName("TD")
        $TDTagNamesCount = ($TDTagNames | Measure-Object).Count
        $YearList = New-Object -TypeName System.Collections.ArrayList
        foreach ($TDTagName in $TDTagNames) {
            if ($PSBoundParameters) {
                $ProgressCount++
                Write-Progress -Activity "Parsing HTML document" -Id 1 -Status "Processing TD tag $($ProgressCount) / $($TDTagNamesCount)" -PercentComplete (($ProgressCount / $TDTagNamesCount) * 100)
            }
            if (($TDTagName.innerHTML -match "\d{4}-\d{2}-\d{2}") -and ($TDTagName.width -eq 120)) {
                $ExpirationDate = $TDTagName.innerHTML
                $YearList.Add($ExpirationDate) | Out-Null
            }
            if ($Location -eq $null) {
                if (($TDTagName.innerHTML -notmatch "<") -and ($TDTagName.cellIndex -eq 4) -and ($TDTagName.width -eq 140) -and ($TDTagName.innerHTML -notmatch "\d")) {
                    $Location = $TDTagName.innerHTML
                }
            }
            if (($TDTagName.innerHTML -match "(This).*") -and ($TDTagName.uniqueNumber -eq 5)) {
                $Description = $TDTagName.innerHTML
            }
        }
        Write-Progress -Activity "Parsing HTML document" -Id 1 -Completed
        $PSObject = [PSCustomObject]@{
            Model = $Model
            SerialNumber = $SerialNumber
            ExpirationDate = $YearList[0]
            Location = $Location
            Description = $Description
        }
        Write-Output $PSObject
    }
}
