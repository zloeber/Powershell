# Get all servers in the domain and divide by connectivity
$AllWorkstations = Get-ADComputer -Filter {OperatingSystem -notlike 'Windows Server*'} -Properties *
$AllWorkstationModelInfo = @()

Foreach ($workstation in $AllWorkstations) {
    $WorkstationInfo = @{
        Workstation = $workstation.Name
        DNSHostName = $workstation.DNSHostName
        IPv4Address = $workstation.IPv4Address
        CreatedInAD = $workstation.WhenCreated
        PasswordLastSet = $workstation.PasswordLastSet
        PasswordExpired = $workstation.PasswordExpired
        OS = $workstation.OperatingSystem
        Manufacturer = $null
        Model = $null
        PrimaryOwnerName = $null
    }
    if (test-connection -computername $workstation.DNSHostName -count 2 -quiet) {
        Write-Host -ForegroundColor Green "$($_.DNSHostName): Ping Check Succeeded!"
        try{ 
            $sysinfo = Get-WmiObject -Class:Win32_ComputerSystem -ComputerName $workstation.name
            $WorkstationInfo.Manufacturer = $sysinfo.Manufacturer
            $WorkstationInfo.Model = $sysinfo.Model
            $WorkstationInfo.PrimaryOwnerName = $sysinfo.PrimaryOwnerName
        }
        catch {
            write-warning "Unable to connect via WMI to $($workstation.name)..." 
        }
    } 
    $AllWorkstationModelInfo += New-Object psobject -Property $WorkstationInfo
}

$AllWorkstationModelInfo | Export-Csv -NoTypeInformation 'WorkstationModels.csv'