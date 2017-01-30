$adConnector  = "domain.org"
$aadConnector = "tenant.domain.org - AAD"

Import-Module adsync

$AD = Get-ADSyncConnector -Name $adConnector
$AAD = New-Object Microsoft.IdentityManagement.PowerShell.ObjectModel.ConfigurationParameter "Microsoft.Synchronize.ForceFullPasswordSync", String, ConnectorGlobal, $null, $null, $null
$AAD.Value = 1

$AD.GlobalParameters.Remove($AAD.Name)
$AD.GlobalParameters.Add($AAD)
$AD = Add-ADSyncConnector -Connector $AD

Set-ADSyncAADPasswordSyncConfiguration -SourceConnector $adConnector -TargetConnector $aadConnector -Enable $false
Set-ADSyncAADPasswordSyncConfiguration -SourceConnector $adConnector -TargetConnector $aadConnector -Enable $true