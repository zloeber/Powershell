import-module WebApplicationProxy
$ReportDestination = 'C:\Scripts\WAPReport.htm'
Get-WebApplicationProxyConfiguration | 
    Add-Member -membertype scriptproperty -name ServersList -value {$this.ConnectedServersName -join '; '} -passthru -force | 
    convertto-html ServersList,ADFSUrl -title "WAP Stats" -body "<H2>Web Application Proxy Server | Connected Servers</H2>" > $ReportDestination
Get-NetIPAddress -CimSession (New-CimSession -ComputerName ((gwpc).ConnectedServersName)) | 
    convertto-html IPAddress, InterfaceAlias, PrefixLength -title "WAP Stats" -body "<H2>Web Application Proxy Server | IP Addresses</H2>" >> $ReportDestination
Get-Service 'appproxysvc','appproxyctrl','adfssrv' | 
    convertto-html DisplayName, ServiceName,Status -title "WAP Stats" -body "<H2>Web Application Proxy Server | Services Status</H2>" >> $ReportDestination
Get-WebApplicationProxyApplication | 
    convertto-html Name,ExternalURL, BackendServerUrl -title "WAP Stats" -body "<H2>Web Application Proxy Server | Published Applications List</H2>" >> $ReportDestination
Get-WebApplicationProxyAvailableADFSRelyingParty | 
    convertto-html Name,Published, ID -title "WAP Stats" -body "<H2>Web Application Proxy Server | AD FS Relying Party Trusts</H2>" >> $ReportDestination