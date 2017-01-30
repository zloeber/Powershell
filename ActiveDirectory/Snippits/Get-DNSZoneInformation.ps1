function Get-DNSZones
{
    param(
    [String]$ComputerName = "."
    )

    $enumZonesExpression = "dnscmd $ComputerName /enumzones"
    $dnscmdOut = Invoke-Expression $enumZonesExpression
    if(-not($dnscmdOut[$dnscmdOut.Count - 2] -match "Command completed successfully."))
    {
        Write-Error "Failed to enumerate zones"
        return $false
    }
    else
    {
        # The output header can be found on the fifth line: 
        $zoneHeader = $dnscmdOut[4]

        # Let's define the the index, or starting point, of each attribute: 
        $d1 = $zoneHeader.IndexOf("Zone name")
        $d2 = $zoneHeader.IndexOf("Type")
        $d3 = $zoneHeader.IndexOf("Storage")
        $d4 = $zoneHeader.IndexOf("Properties")

        # Finally, let's put all the rows in a new array:
        $zoneList = $dnscmdOut[6..($dnscmdOut.Count - 5)]

        # This will store the zone objects when we are done:
        $zones = @()

        # Let's go through all the rows and extrapolate the information we need:
        foreach($zoneString in $zoneList) {
            $zoneInfo = @{
				Computer   =   $ComputerName
                Name       =   $zoneString.SubString($d1,$d2-$d1).Trim();
                ZoneType   =   $zoneString.SubString($d2,$d3-$d2).Trim();
                Storage    =   $zoneString.SubString($d3,$d4-$d3).Trim();
                Properties = @($zoneString.SubString($d4).Trim() -split " ")
            }
            $zoneObject = New-Object PSObject -Property $zoneInfo
            $zones += $zoneObject
        }

        return $zones
    }
}

$Servers = @('DC1','DC2')
$AllDNSZones = @()
$Servers | Foreach {
	$AllDNSZones += Get-DNSZones $_
}