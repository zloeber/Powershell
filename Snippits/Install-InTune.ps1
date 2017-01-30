Function New-RemoteWMIProcess {
    Param (
        $target = ".",
        $command = "dir",
        [switch]$WaitForCompletion
    )
    $cmdResult = ([WmiClass]"\\$target\ROOT\CIMV2:Win32_Process").create($command)
    Switch ($cmdresult.returnvalue) {
        0 {$resultTxt = "Successful"}
        2 {$resultTxt = "Access denied"}
        3 {$resultTxt = "Insufficient privilege"}
        8 {$resultTxt = "Unknown failure"}
        9 {$resultTxt = "Path not found"}
        21 {$resultTxt = "Invalid parameter"}
        default {$resultTxt = "Unhandled error"}
    } 
    $processId = $cmdresult.processId
    $processStatus = "unknown"
    if ($WaitForCompletion) {
        $wait = $true
        While ($wait) {
            Start-Sleep -Milliseconds 250
            $test = Get-WmiObject -query "select * from Win32_Process Where ProcessId='$processId'"
            if ((Measure-Object -InputObject $test).count -eq 0) {
                $wait = $false
            }
        }
        $processStatus = "completed"
    }
    $obj = New-Object Object
    $obj | Add-Member Noteproperty Target -value $target
    $obj | Add-Member Noteproperty Command -value $command
    $obj | Add-Member Noteproperty Result -value $($cmdresult.returnvalue)
    $obj | Add-Member Noteproperty ProcessStart -value $resultTxt
    $obj | Add-Member Noteproperty ProcessId -value $processId
    $obj | Add-Member Noteproperty ProcessStatus -value $processStatus
    $obj
}


$path = '\\dc1.contoso.org\netlogon\InTune\RemotePush'
$pathleaf = split-path $path -leaf
$LogPath = 'C:\Windows\temp\' + $pathleaf + '\intuneinstall.log' 
$parameters = '/qb REBOOT=ReallySuppress /log ' + $LogPath

$packageinstall= 'Microsoft_Intune_X64.msi'

$Workstations = @('Workstation1','Workstation2','Workstation3','Workstation4')

$Workstations | where{ test-connection $_ -quiet -count 1 } | ForEach-Object {

    try {
        copy-item $path -Recurse "\\$_\c$\Windows\temp\" -force
        $RemoteCommand = 'msiexec.exe /i "C:\Windows\temp\' + $pathleaf + '\' + $packageinstall + '" ' + $parameters
        New-RemoteWMIProcess -Target $_ -WaitForCompletion -command $RemoteCommand
    }
    catch {
        Write-Error 'Unable to copy source files to remote system temp drive...'
    }
}
