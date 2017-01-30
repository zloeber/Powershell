<#
.SYNOPSIS     
    The script finds the GPP Drive Maps in your domain. 
.NOTES     
    Author   : Johan Dahlbom, johan[at]dahlbom.eu (with small modifications for odering and such by Zachary Loeber)  
    Blog: 365lab.net
    The script are provided “AS IS” with no guarantees, no warranties, and it confer no rights.
#>

Function Get-GPODriveMapping {
    try {
        Import-Module GroupPolicy -ErrorAction Stop
    }
    catch {
        throw "Module GroupPolicy not Installed"
    }
    $GPO = Get-GPO -All

    foreach ($Policy in $GPO) {
        $GPOID = $Policy.Id
        $GPODom = $Policy.DomainName
        $GPODisp = $Policy.DisplayName

        if (Test-Path "\\$($GPODom)\SYSVOL\$($GPODom)\Policies\{$($GPOID)}\User\Preferences\Drives\Drives.xml") {
            [xml]$DriveXML = Get-Content "\\$($GPODom)\SYSVOL\$($GPODom)\Policies\{$($GPOID)}\User\Preferences\Drives\Drives.xml"
            
            $DriveOrder = 0

            foreach ( $drivemap in $DriveXML.Drives.Drive ) {
                $DriveOrder++
                $FilterUsers = ''
                $UserOrder = 0
                if ($drivemap.filters.FilterUser -ne $null) {
                    $drivemap.filters.FilterUser | Foreach {
                        $UserOrder++
                        if ($UserOrder -gt 1) { $FilterUsers +=  "`n" }
                        $FilterUsers += "$($UserOrder).) " + "$($_.bool) User " + $(if ($_.not -eq 1) {"NOT "} else {"IS "}) + $_.name
                    }
                }
                
                $FilterGroups = ''
                $GroupOrder = 0
                if ($drivemap.filters.FilterGroup -ne $null) {
                    $drivemap.filters.FilterGroup | Foreach {
                        $GroupOrder++
                        if ($GroupOrder -gt 1) { $FilterGroups +=  "`n" }
                        $FilterGroups += "$($GroupOrder).) " + "$($_.bool) Group " + $(if ($_.not -eq 1) {"NOT "} else {"IS "}) + $_.name
                    }
                }
                New-Object PSObject -Property @{
                    GPOName = $GPODisp
                    Order = $DriveOrder
                    LastChanged = $drivemap.Changed
                    DriveLetter = $drivemap.Properties.Letter + ":"
                    DrivePath = $drivemap.Properties.Path
                    DriveAction = $drivemap.Properties.action.Replace("U","Update").Replace("C","Create").Replace("D","Delete").Replace("R","Replace")
                    DriveLabel = $drivemap.Properties.label
                    DrivePersistent = $drivemap.Properties.persistent.Replace("0","False").Replace("1","True")
                    DriveFilterGroup = $FilterGroups
                    DriveFilterUser = $FilterUsers
                } | Select GPOName, Order, LastChanged, DriveLetter, DrivePath, DriveAction, DriveLabel, DrivePersistent, DriveFilterGroup, DriveFilterUser
            }
        }
    }
}