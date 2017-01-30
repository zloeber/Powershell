$Connectors = Get-ReceiveConnector | Where {$_.Identity -like "*Relay"}
$Output = @()
Foreach ($connector in $Connectors) {
	#Get-ADPermission $connector.Identity
	$connector.RemoteIPRanges | Where {$_.RangeFormat -eq 'SingleAddress'} | Foreach {
		$IsLive = Test-Connection $_.LowerBound.ToString() -Count 2 -Quiet
		$Output += New-Object psobject -Property @{
			'Connector' = $connector.Identity
			'AllowedIP' = $_.LowerBound.ToString()
			'IsLive' = $IsLive
		}
	}
} 

$Output | Export-Csv -NoTypeInformation ResponsiveAllowedRelayIPs.csv