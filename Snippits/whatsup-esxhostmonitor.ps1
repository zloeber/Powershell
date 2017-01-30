import-module CimCmdlets

# Get the credentials
$VMuser = $Context.GetProperty("CredVMware:Username");
$VMpass = $Context.GetProperty("CredVMware:Password");
$pwd = convertto-securestring $VMpass -asplaintext -force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $VMuser,$pwd

# Get server
$esxi = $Context.GetProperty("Address");

#Heatlh State value translations
$HealthState0 = "Unknown"
$HealthState5 = "OK"
$HealthState10 = "Degraded/Warning"
$HealthState15 = "Minor failure"
$HealthState20 = "Major failure"
$HealthState25 = "Critical failure"
$HealthState30 = "Non-recoverable error"

#Set Session Options
$CIOpt = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -Encoding Utf8 -UseSsl
$Session = New-CimSession -Authentication Basic -Credential $cred -ComputerName $esxi -port 443 -SessionOption $CIOpt

#print device info to log
#$Chassis = Get-CimInstance -CimSession $Session -ClassName CIM_Chassis
#$sMessage = $sMessage + "`r`nModel:" + $Chassis.Manufacturer + " " + $Chassis.Model + "`r`n"
#$sMessage = $sMessage + "Serial:" + $Chassis.SerialNumber + "`r`n";

#Find sensors not in normal state
$bDown = $false

#Processors
$sensors = Get-CimInstance -CimSession $Session -ClassName CIM_Processor | Where {$_.HealthState -ge 0} | Select Caption, HealthState
foreach ($sensor in $sensors) {
    If ($sensor.HealthState -ne 5) {
        $sensor.HealthState = $sensor.HealthState -replace "10", $HealthState10
        $sensor.HealthState = $sensor.HealthState -replace "15", $HealthState15
        $sensor.HealthState = $sensor.HealthState -replace "20", $HealthState20
        $sensor.HealthState = $sensor.HealthState -replace "30", $HealthState30
        $sensor.HealthState = $sensor.HealthState -replace "0", $HealthState0
        $sDownMessage = $sDownMessage + $sensor.Caption + ": " + $sensor.HealthState + "`r`n"
        $sMessage = $sMessage + $sensor.Caption + ": " + $sensor.HealthState + "`r`n"
        $bDown = $true
    }
    Else {
        $sMessage = $sMessage + $sensor.Caption + ": " + $HealthState5 + "`r`n" 
    }
}

#Physical Memory
$sensors = Get-CimInstance -CimSession $Session -ClassName CIM_Memory | Where {$_.HealthState -ge 0 -and $_.ElementName -notlike '*Cache*'} | Select ElementName, HealthState
foreach ($sensor in $sensors) {
    If ($sensor.HealthState -ne 5) {
        $sensor.HealthState = $sensor.HealthState -replace "10", $HealthState10
        $sensor.HealthState = $sensor.HealthState -replace "15", $HealthState15
        $sensor.HealthState = $sensor.HealthState -replace "20", $HealthState20
        $sensor.HealthState = $sensor.HealthState -replace "30", $HealthState30
        $sensor.HealthState = $sensor.HealthState -replace "0", $HealthState0
        $sDownMessage = $sDownMessage + $sensor.ElementName + ": " + $sensor.HealthState + "`r`n"
        $sMessage = $sMessage + $sensor.ElementName + ": " + $sensor.HealthState + "`r`n"
        $bDown = $true
    }
    Else {
        $sMessage = $sMessage + $sensor.ElementName + ": " + $HealthState5 + "`r`n"
    }
}

#All vendor specific sensors
$sensors = Get-CimInstance -CimSession $Session -ClassName CIM_Sensor | Where {$_.HealthState -ge 0} | Select Caption, HealthState
foreach ($sensor in $sensors) {
    If ($sensor.HealthState -ne 5) {
        $sensor.HealthState = $sensor.HealthState -replace "10", $HealthState10
        $sensor.HealthState = $sensor.HealthState -replace "15", $HealthState15
        $sensor.HealthState = $sensor.HealthState -replace "20", $HealthState20
        $sensor.HealthState = $sensor.HealthState -replace "30", $HealthState30
        $sensor.HealthState = $sensor.HealthState -replace "0", $HealthState0
        $sDownMessage = $sDownMessage + $sensor.Caption + ": " + $sensor.HealthState + "`r`n"
        $sMessage = $sMessage + $sensor.Caption + ": " + $sensor.HealthState + "`r`n"
        $bDown = $true
    }
    Else {
        $sMessage = $sMessage + $sensor.Caption + ": " + $HealthState5 + "`r`n"
    }
}

#If down flag thrown, set down else set up
$sUpMessage = "All sensors were found to be in the 'OK' state."
If ($bDown) {
    $Context.SetResult(1, "Down! One or more sensors was found to not be in the 'OK' state`r`n" + $sDownMessage)
}
Else {
    $Context.SetResult(0, $sMessage + "`r`nUP! " + $sUpMessage)
}

#Remove the CIMSession
Remove-CimSession -CimSession $Session | Out-Null
