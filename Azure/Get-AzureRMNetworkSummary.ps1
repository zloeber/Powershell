<#
    Quick report of ARM based Azure networking that includes:
    - Location (region)
        - Virtual Networks (region based!)
            - Subnets
                - Associated NSGs
                - Virtual Machines (Interfaces)
        - Network Security Groups (and rule counts)
                - Associated Subnets
        - Interfaces
        - Resource Groups
                - Associated Interfaces

    Note: Virtual Networks and interfaces may be associated with different resource groups!

    Author: Zachary Loeber
#>
Login-AzureRmAccount
$sub = Set-AzureRmContext -SubscriptionId (Get-AzureRmSubscription | Out-GridView -Title "Pick A Location" -PassThru).subscriptionid

$AllNSGs= Get-AzureRmNetworkSecurityGroup
$AllInts = Get-AzureRmNetworkInterface
$AllLocations = Get-AzureRmLocation
$SubnetIDToSubnetMap = @{}
$IntIDToIntMap = @{}
$AllInts | ForEach-Object {
    $IntIDToIntMap.($_.Id) = "$($_.Name) ($(($_.IPConfigurations).PrivateIpAddress -join ','))"
}

$Indent = 1
Write-Output "Subscription: $($Sub.Subscription.SubscriptionName)"
Write-Output ''
Foreach ($Location in $AllLocations) {
    $AllNSGInLocation = @($AllNSGs | Where-Object {$_.Location -eq $Location.Location})
    $AllVNsInLocation = Get-AzureRmVirtualNetwork | Where {$_.Location -eq $Location.Location}
    $RGsInLocation = @(Get-AzureRmResourceGroup -Location $Location.Location)
    
    # Start Region Report
    if ( ($AllNSGInLocation.Count -gt 0) -or 
         ($RGsInLocation.Count -gt 0) -or 
         ($AllVNsInLocation.Count -gt 0) ) {
        Write-Output "Azure Region: $($Location.Location)"
        
        # Virtual Network Report
        if ($AllVNsInLocation.Count -gt 0) {
            Foreach ($VN in $AllVNsInLocation) {
                Write-Host "$(' ' * ($Indent * 0))Virtual Network: $($VN.Name) ($(($VN.AddressSpace).AddressPrefixes -join ', '))"

                # Subnet Report
                if (($VN.Subnets).Count -gt 0) {
                    Write-Output "$(' ' * ($Indent * 1))Virtual Network Subnets:"
                    Foreach ($Subnet in ($VN.Subnets)) {
                        $SubnetIDToSubnetMap.($Subnet.ID) = $Subnet.AddressPrefix
                        Write-Output "$(' ' * ($Indent * 2))$($Subnet.Name) ($($Subnet.AddressPrefix))"
                        $NSGsInSubnet = $AllNSGs | Where-Object {@($_.Subnets.Id) -contains $Subnet.Id}

                        # NSGs Linked to Subnet
                        if ($NSGsInSubnet.Count -gt 0) {
                            Write-Output "$(' ' * ($Indent * 3))Associated NSGs:"
                            Foreach ($NSGInSubnet in $NSGsInSubnet) {
                                Write-Output "$(' ' * ($Indent * 3))- $($NSGInSubnet.Name)"
                            }
                        }

                        # Interfaces (VMs) Connected to Subnet
                        $IntsInSubnet = $AllInts | Where-Object {(($_.IpConfigurations).Subnet.Id -join '|') -match $Subnet.ID}
                        if ($IntsInSubnet.Count -gt 0) {
                            Write-Output "$(' ' * ($Indent * 3))Interfaces Linked to Subnet:"
                            $IntsInSubnet | Foreach-Object {
                                Write-Output "$(' ' * ($Indent * 3))- $($_.Name) ($(($_.Ipconfigurations.PrivateIpAddress) -join ', '))"
                            }
                        }
                    }
                }

                Write-Output ''
            }
        }

        # NSG Report
        if ($AllNSGInLocation.Count -gt 0) {
            Write-Output "$(' ' * ($Indent * 0))Network Security Groups in Region:"
            Foreach ($NSG in $AllNSGInLocation) {
                $NSGRuleCount = ($NSG.SecurityRules).Count
                Write-Output "$(' ' * ($Indent * 1))$($NSG.Name) (Rule Count = $($NSGRuleCount))"
                # NSG Subnets
                if (($NSG.Subnets).Count -gt 0) {
                    Write-Output "$(' ' * ($Indent * 2))Associated Subnets:"
                    Foreach ($SubnetID in ($NSG.Subnets).ID) {
                        Write-Output "$(' ' * ($Indent * 3))- $($SubnetIDToSubnetMap.$SubnetID)"
                    }
                }
                # NSG Interfaces
                if (($NSG.NetworkInterfaces).Count -gt 0) {
                    Write-Output "$(' ' * ($Indent * 2))Associated Interfaces:"
                    Foreach ($NSGInt in ($NSG.NetworkInterfaces).ID) {
                        Write-Output "$(' ' * ($Indent * 3))- $($IntIDToIntMap.$NSGInt)"
                    }
                }
            }
            Write-Output ''
        }

        # Resource Groups In Location
        if ($RGsInLocation.Count -gt 0) {
            Write-Output "$(' ' * ($Indent * 1))Resource Groups in Region:"
            Foreach ($RG in $RGsInLocation) {
                Write-Output "$(' ' * ($Indent * 2))$($RG.ResourceGroupName)"
                $AllIntsInRG = Get-AzureRmNetworkInterface -ResourceGroupName $RG.ResourceGroupName
                
                # Interfaces in RG
                if ($AllIntsInRG.count -gt 0) {
                    Write-Output "$(' ' * ($Indent * 3))Interfaces in this Group:"
                    Foreach ($Int in $AllIntsInRG) {
                        $IntIP = $Int[0].IpConfigurations[0].PrivateIpAddress
                        Write-Output "$(' ' * ($Indent * 4))$($Int.Name) ($($IntIP))"
                    }
                }
            }
        }
        Write-Output ''
    }
}
