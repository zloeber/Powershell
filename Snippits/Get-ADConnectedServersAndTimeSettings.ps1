# Get all servers in the domain and divide by connectivity
$AllServers = Get-ADComputer -Filter {OperatingSystem -like 'Windows Server*'} -Properties *
$AllConnectedServers = @()
$AllDisconnectedServers = @()
$AllServers | Foreach {
    if (test-connection -computername $_.DNSHostName -count 2 -quiet) {
        Write-Host -ForegroundColor Green "$($_.DNSHostName): Ping Check Succeeded!"
        $AllConnectedServers += $_
    }
    else {
        Write-Host -ForegroundColor Red "$($_.DNSHostName): Ping Check FAILED!"
        $AllDisconnectedServers += $_
    }
}
# Export connected OS information if you like...
# $AllConnectedServers | select Name,OperatingSystem,OperatingSystemVersion,OperatingSystemServicePack | export-csv -NoTypeInformation C:\TEMP\ConnectedServerInfo.csv

# Get time information set on all domain connected computers
$AllServerTimeInfo = @() 
foreach ($server in $AllConnectedServers){ 
    try{ 
        write-host "checking $($server.name)..." 
        $dt = gwmi win32_operatingsystem -computer $server.name
        $sys = gwmi Win32_ComputerSystem -computer $server.name
        $dt_str = $dt.converttodatetime($dt.localdatetime).touniversaltime() 
        $AllServerTimeInfo += new-object psobject -property @{ 
            Server = $server.Name
            Time = $dt_str
            TimeZone = $dt.CurrentTimeZone
            DaylightInEffect = $sys.DaylightInEffect
        }
    } 
    catch {
        Write-Warning '...Unable to connect via wmi :('
        $AllServerTimeInfo += new-object psobject -property @{ 
            Server = $server.Name
            Time = 'Err'
            TimeZone = 'Err'
            DaylightInEffect = 'Err'
        }
    }
}