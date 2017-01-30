function Install-RemoteUpdate {
    <#
        .SYNOPSIS 
        Installs an MSI/MSU from a remote share to a remote server silently.

        .DESCRIPTION
        Installs an MSI/MSU from a remote share to a remote server silently.

        .PARAMETER ComputerName
        Specifies the computer to process.
        
        .PARAMETER SourceUpdate
        Specifies the path of the MSI/MSU to copy to the remote computer.
        
        .PARAMETER RemotePath
        Specifies the path to copy the MSI/MSU to on the remote computer.
        
        .EXAMPLE
        TBD

    #>
    [cmdletbinding()]
    Param (
        [Parameter(ValueFromPipeline=$True, Mandatory=$True)]
        [string]$ComputerName,
        
        [Parameter(Mandatory=$True)]
        [ValidateScript({
                if ((Test-Path $_) -and (($_ -like '*.msi') -or ($_ -like '*.msu'))) {
                    $true
                }
                else {
                    throw 'Invalid file path or name (must be an msi or msu)'
                }
            }
        )]
        [string]$SourceUpdate,

        [Parameter()]
        [string]$RemotePath = 'C:\Temp'
    )
    Begin {
        $RemoteNetworkPath = $RemotePath -replace ':','$'
        Write-Verbose "Remote network path is: $($RemoteNetworkPath)"

        $destinationFolder = "\\$($computername)\$($RemoteNetworkPath)"
        Write-Verbose "Destination folder for update: $($destinationFolder)"

        $Update = Split-Path -Leaf $SourceUpdate
        Write-Verbose "Update which will be installed: $($Update)"

        $UpdateLocalPath = Join-Path $RemotePath $Update
        Write-Verbose "Update Local Path will be: $($UpdateLocalPath)"
    }
    Process {
        #This section will copy the $SourceUpdate to the $destinationfolder. If the Folder does not exist it will create it.
        if (-not (Test-Path -path $destinationFolder)) {
            Write-Verbose 'Destination folder is not there, creating it...'
            New-Item $destinationFolder -Type Directory
        }
        if (-not (Test-Path (Join-Path $destinationFolder $Update ))) {
            Write-Verbose 'Copying over update file'
            Copy-Item -Path $SourceUpdate -Destination $destinationFolder
        }

        if ($Update -like '*.msi') {
            Write-Verbose 'Invoking msiexec for msi file'
            Invoke-Command -ComputerName $ComputerName -ScriptBlock { param($MSIPath) & cmd /c "msiexec.exe /i $MSIPath" /qn ADVANCED_OPTIONS=1 CHANNEL=100} -ArgumentList $UpdateLocalPath
        }
        elseif ($Update -like '*.msu') {
            Write-Verbose 'Invoking wusa for msu file'
            $WUSAScriptFullPath = "$($destinationFolder)\wusascript.cmd"
            $TaskScript = Join-Path $RemotePath 'wusascript.cmd'
            $WUSAScript = "wusa.exe $($UpdateLocalPath) /quiet /norestart"
            $WUSAScript | Out-File $WUSAScriptFullPath
            $CurrTime = (Get-Date).AddMinutes(5)
            $TaskTime = (Get-Date $CurrTime -Format HH:mm:ss).ToString()
            Write-Verbose "Proposed Start Time for Task: $TaskTime"
            try {
                Write-Verbose "Adding task for $ComputerName"
                & cmd /c "schtasks.exe /s $ComputerName /ru SYSTEM /Create /SC Once /ST $TaskTime /TN OneTimeUpdate /TR $TaskScript /F /Z /V1"
            }
            catch {
                Write-Error "Unable to schedule task for $ComputerName"
            }
        }
    }
}

$a = Import-CSV 'servers.csv'
$a.DNSHostName | Select -Unique | Foreach {
     Install-RemoteUpdate -ComputerName $_ -SourceUpdate 'C:\Temp\Windows6.1-KB2520155-x64.msu' -RemotePath 'c:\temp' -Verbose
 }

 Install-RemoteUpdate -ComputerName 'Servername' -SourceUpdate 'C:\Temp\Windows6.1-KB2520155-x64.msu' -RemotePath 'c:\temp' -Verbose
