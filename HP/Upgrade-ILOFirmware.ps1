<# 
    Description: Scan a subnet for iLO interfaces and attempt to upgrade firmware on them

     Requires: 
     - HP Scripting Tools for Windows PowerShell http://h20566.www2.hpe.com/portal/site/hpsc/public/psi/home?sp4ts.oid=5440657
     - Downloaded firmware .bin files for the iLO versions you are upgrading
     
     Note: This whole script would work splendidly if the firmware update module cmdlet did its job :(
            
#>

Import-Module HPiLOCmdlets

# Update to scan whatever ranges you want
$ILOs = Find-HPiLO "10.0.50.2-254"

# Update to point to your firmware versions and .bin file locations
$ILO1_Firmware = @{
    'Version' = 1.96
    'File' = 'C:\c-temp\iLO Firmware\ilo196.bin'
}
$ILO2_Firmware = @{
    'Version' = 2.28
    'File' = 'C:\c-temp\iLO Firmware\ilo2_228.bin'
}
$ILO3_Firmware = @{
    'Version' = 1.85
    'File' = 'C:\c-temp\iLO Firmware\ilo3_185.bin'
}
$ILO4_Firmware = @{
    'Version' = 2.30
    'File' = 'C:\c-temp\iLO Firmware\ilo4_230.bin'
}

#$ILOCred = Get-Credential

$ILO1Upgrades = @()
$ILO2Upgrades = @()
$ILO3Upgrades = @()
$ILO4Upgrades = @()

Foreach ($ILO in $ILOs) {
    Write-Output ""
    Write-Output "ILO Host: $($ILO.IP)"
    Write-Output "-ILO Version: $($ILO.PN)"

    switch ($ILO.PN) {
        'Integrated Lights-Out 1 (iLO 1)' {
            if (-not ($ILO.FWRI -ge $ILO1_Firmware['Version'])) {
                Write-Output "---The existing firmware is NOT up to date!"
                Write-Output "-----Host Firmware Version: $($ILO.FWRI)"
                Write-Output "-----Upgrade Firmware Version: $($ILO1_Firmware['Version'])"
                $ILO1Upgrades += $ILO
            }
            else {
                Write-Output '---Firmware is up to date!'
            }
        }
        'Integrated Lights-Out 2 (iLO 2)' {
            if (-not ($ILO.FWRI -ge $ILO2_Firmware['Version'])) {
                Write-Output "---The existing firmware is NOT up to date!"
                Write-Output "-----Host Firmware Version: $($ILO.FWRI)"
                Write-Output "-----Upgrade Firmware Version: $($ILO2_Firmware['Version'])"
                $ILO2Upgrades += $ILO
                
            }
            else {
                Write-Output '---Firmware is up to date!'
            }
        }
        'Integrated Lights-Out 3 (iLO 3)' {
            if (-not ($ILO.FWRI -ge $ILO3_Firmware['Version'])) {
                Write-Output "---The existing firmware is NOT up to date!"
                Write-Output "-----Host Firmware Version: $($ILO.FWRI)"
                Write-Output "-----Upgrade Firmware Version: $($ILO3_Firmware['Version'])"
                $ILO3Upgrades += $ILO
            }
            else {
                Write-Output '---Firmware is up to date!'
            }
        }
        'Integrated Lights-Out 4 (iLO 4)' {
            if (-not ($ILO.FWRI -ge $ILO4_Firmware['Version'])) {
                Write-Output "---The existing firmware is NOT up to date!"
                Write-Output "-----Host Firmware Version: $($ILO.FWRI)"
                Write-Output "-----Upgrade Firmware Version: $($ILO3_Firmware['Version'])"
                $ILO4Upgrades += $ILO
            }
            else {
                Write-Output '---Firmware is up to date!'
            }
        }
        default {
            Write-Output "Unknown ILO version!"
        }
    }
}

$NotUpgraded = @()
$ILO1Upgrades | Foreach {
    try {
        Write-Output ""
        Write-Output "Attempting to upgrade the ILO1 firmware for $($_.IP)...."
        Update-HPiLOFirmware -Location $ILO1_Firmware['file'] -Credential $ILOCred -Server $_.IP -Verbose
    }
    catch {
        Write-Warning "Was not able to upgrade $($_.IP). Possible a credential issue?"
        $NotUpgraded += $_
    }
}

$ILO2Upgrades | Foreach {
    try {
        Write-Output ""
        Write-Output "Attempting to upgrade the ILO2 firmware for $($_.IP)...."
        Update-HPiLOFirmware -Location $ILO2_Firmware['file'] -Credential $ILOCred -Server $_.IP -Verbose
    }
    catch {
        Write-Warning "Was not able to upgrade $($_.IP). Possible a credential issue?"
        $NotUpgraded += $_
    }
}

$ILO3Upgrades | Foreach {
    try {
        Write-Output ""
        Write-Output "Attempting to upgrade the ILO3 firmware for $($_.IP)...."
        Update-HPiLOFirmware -Location $ILO3_Firmware['file'] -Credential $ILOCred -Server $_.IP -Verbose
    }
    catch {
        Write-Warning "Was not able to upgrade $($_.IP). Possible a credential issue?"
        $NotUpgraded += $_
    }
}

$ILO4Upgrades | Foreach {
    try {
        Write-Output ""
        Write-Output "Attempting to upgrade the ILO4 firmware for $($_.IP)...."
        Update-HPiLOFirmware -Location $ILO4_Firmware['file'] -Credential $ILOCred -Server $_.IP -Verbose
    }
    catch {
        Write-Warning "Was not able to upgrade $($_.IP). Possible a credential issue?"
        $NotUpgraded += $_
    }
}

Write-Output ""
Write-Output " The following detected ILO devices were unable to be upgraded and should be further investigated:"
Write-Output ""

$NotUpgraded