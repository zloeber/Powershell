<#
.SYNOPSIS
    A simple exchange log level gui manipulation tool.
.DESCRIPTION
    A simple exchange log level gui manipulation tool.
.PARAMETER ComputerName
    If you are running this on exchange 2010 you may need to use this flag to force load the snapin after starting an admin powershell console in STA mode.
.EXAMPLE
    ExchangeLogLevelGUI.ps1
.INPUTS
.OUTPUTS
.LINK
    http://the-little-things.net/
.COMPONENT
    Networking, Exchange
.NOTES
    Author:  Zachary Loeber
    Created: 07/07/2014
    Versions: 
        1.0.1 - Fixed initial exchange server name gathering to work properly on posh 2.0 systems
        1.0.0 - Initial release
#>
[CmdletBinding()]
param (
	[Parameter(HelpMessage='If you are running this on exchange 2010 you may need to use this flag to force load the snapin.')]
	[switch]$Exchange2010Mode
)

begin {
    # Supposedly we need STA mode to run xaml properly
    if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne "STA") 
    {               
        Write-Warning "Run PowerShell.exe with -Sta switch, then run this script (likely with the -Exchange2010Mode flag)"
        Write-Warning "Example:"             
        Write-Warning "    PowerShell.exe -noprofile -Sta"
        exit
    }

    if ($Exchange2010Mode)
    {
        Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010 -ErrorAction SilentlyContinue
    }

    [void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
    [xml]$xaml = @'
    <Window x:Name="MainForm"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Exchange Log Level GUI" Height="590" Width="540" MinHeight="260" MaxHeight="700" MaxWidth="700" MinWidth="525" ResizeMode="NoResize" WindowStartupLocation="CenterScreen">
        <Grid Margin="0,0,-2.6,-2.6" MinHeight="300" MinWidth="525" MaxWidth="700">
            <ComboBox x:Name="comboServers" HorizontalAlignment="Left" Margin="10,10,0,0" VerticalAlignment="Top" Width="234"/>
            <Button x:Name="btnLoad" Content="Load" HorizontalAlignment="Left" Margin="249,10,0,0" VerticalAlignment="Top" Width="75" Height="22"/>
            <ListView x:Name="listviewExchangeLogs" Margin="10,37,0,0" Height="485" VerticalAlignment="Top" HorizontalAlignment="Left" Width="505">
                <ListView.View>
                    <GridView AllowsColumnReorder="False">
                        <GridViewColumn Header="Category">
                            <GridViewColumn.CellTemplate>
                                <DataTemplate>
                                    <Label Content = "{Binding Category}"/>
                                </DataTemplate>
                            </GridViewColumn.CellTemplate>
                        </GridViewColumn>
                        <GridViewColumn Header="Exchange Component">
                            <GridViewColumn.CellTemplate>
                                <DataTemplate>
                                    <Label Content = "{Binding ExchangeComponent}"/>
                                </DataTemplate>
                            </GridViewColumn.CellTemplate>
                        </GridViewColumn>
                        <GridViewColumn Header="Log Level">
                            <GridViewColumn.CellTemplate>
                                <DataTemplate>
                                    <ComboBox ItemsSource="{Binding LogLevels}" SelectedItem="{Binding CurrentLogLevel}" IsEditable="False">
                                    </ComboBox>
                                </DataTemplate>
                            </GridViewColumn.CellTemplate>
                        </GridViewColumn>
                    </GridView>
                </ListView.View>
            </ListView>
            <Button x:Name="btnCancel" Content="Cancel" HorizontalAlignment="Left" Margin="440,527,0,0" VerticalAlignment="Top" Width="75" IsCancel="True"/>
            <Button x:Name="btnApply" Content="Apply" HorizontalAlignment="Left" Margin="360,527,0,0" VerticalAlignment="Top" Width="75"/>
        </Grid>
    </Window>
'@

    #Read XAML
    $reader=(New-Object System.Xml.XmlNodeReader $xaml) 
    $window=[Windows.Markup.XamlReader]::Load( $reader )

    $namespace = @{ x = 'http://schemas.microsoft.com/winfx/2006/xaml' }
    $xpath_formobjects = "//*[@*[contains(translate(name(.),'n','N'),'Name')]]" 

    # Create a variable for every named xaml element
    Select-Xml $xaml -Namespace $namespace -xpath $xpath_formobjects | Foreach {
        $_.Node | Foreach {
            Set-Variable -Name ($_.Name) -Value $window.FindName($_.Name)
        }
    }

    #Define default combobox items
    $loglevels = @('Lowest',
    	'Low',
    	'Medium',
    	'High',
    	'Expert')

    # We always track the last loaded server in case the combobox
    # is changed but never loaded.
    $CurrentServer = ''

    #Buttons (Apply, Cancel, et cetera)
    $window.add_KeyDown({
        if ($args[1].key -eq 'Return') {
            #Apply-Changes
        }
        elseif ($args[1].key -eq 'Escape') {
            $window.Close()        
        }
    })

    $btnCancel.add_Click({$window.Close()})

    # Fill the list view
    Function FillListView($Computer)
    {
        # Start with an empty array for the datasource
        $script:emptyarray = New-Object System.Collections.ArrayList

        try 
        {
            Get-EventLogLevel -Server $Computer | Foreach {
                if ($_.Identity -match "\\([^\\]*)$") # a '\', followed by zero or more characters other than a '\', followed by the end of the string
                {
                    $ExchangeComponent = $Matches[1]
                }
                else
                {
                    $ExchangeComponent = ''
                }
                if ($_.Identity -match "(.*?)\\[^\\]*$") # like the prior match but for all the stuff before that match
                {
                    $Category = $Matches[1]
                }
                else
                {
                    $Category = ''
                }
                $tmpObj = New-Object psobject -Property @{
                    'Identity' = $_.Identity
                    'Category' = $Category
                    'ExchangeComponent' = $ExchangeComponent
                    'CurrentLogLevel' = [string]$_.EventLevel
                    'LastLogLevel' = [string]$_.EventLevel
                    'LogLevels' = $loglevels
                }
                $script:emptyarray += $tmpObj
            }
        }
        catch
        {
            # Apparently something failed, oh well...
        }

        $listviewExchangeLogs.ItemsSource = $script:emptyarray
    }

    # Load server button event
    $btnLoad.Add_Click({
        # If a server is selected then load the ListView
        if ($comboServers.Text -ne '')
        {
            FillListView -Computer $comboServers.Text
            $script:CurrentServer = $comboServers.Text
        }
    })

    # Start button event
    $btnApply.Add_Click({
        $ItemsUpdated = $false
        foreach($item in $script:emptyarray)
        {
            if($item.CurrentLogLevel -ne $item.LastLogLevel)
            {
                Set-EventLogLevel $item.Identity -LogLevel $item.CurrentLogLevel
                Write-Host "Updating $($item.Identity) from level of $($item.LastLogLevel) to new level of $($item.CurrentLogLevel)"
                $ItemsUpdated = $true
            }
        }
        if ($ItemsUpdated)
        {
            FillListView -Computer $script:CurrentServer
        }
    })

    # Get Exchange servers (non 2003 based)
    $ExchangeServers = @((Get-ExchangeServer | where {$_.ExchangeVersion -notlike "0.0*"}| select Name).Name)
    $comboServers.ItemsSource = $ExchangeServers
}
process {}
end {
    # Start the show
    $window.ShowDialog() | out-null
}
