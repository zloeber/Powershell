function Get-LyncADMatchDialog {
    <#
    .SYNOPSIS
    A self contained WPF/XAML treeview organizational unit selection dialog box.
    .DESCRIPTION
    A self contained WPF/XAML treeview organizational unit selection dialog box. No AD modules required, just need to be joined to the domain.
    .EXAMPLE
    $OU = Get-OUDialog
    .NOTES
    Author: Zachary Loeber
    Requires: Powershell 4.0
    Version History
    1.0.0 - 06/08/2015
        - Initial release (the function is a bit overbloated because I'm simply embedding some of my prior functions directly
          in the thing instead of customizing the code for the function. Meh, it gets the job done...
    .LINK
    https://github.com/zloeber/Powershell/blob/master/ActiveDirectory/Select-OU/Get-OUDialog.ps1
    .LINK
    http://www.the-little-things.net
    #>
    [CmdletBinding()]
    param(
        [parameter(Position=0,ValueFromPipeline=$true, HelpMessage='Existing number ranges to check against.')]
        [psobject]$InputDIDRanges
    )
    
    begin {
        if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {               
            Write-Warning 'Run PowerShell.exe with -Sta switch, then run this script.'
            Write-Warning 'Example:'
            Write-Warning '    PowerShell.exe -noprofile -Sta'
            return $false
        }

        [void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
        [xml]$xamlMain = @'
<Window x:Name="WindowADMatch"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="DID to AD Matching" Height="533.6" Width="683.2">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="136*"/>
            <RowDefinition Height="121*"/>
        </Grid.RowDefinitions>
        <DataGrid x:Name="datagridDIDs" Margin="10,3,9.8,29">
            <DataGrid.ContextMenu>
                <ContextMenu x:Name="dgContextMenu"  StaysOpen="true">
                    <MenuItem Header="Copy All" x:Name="dgContextMenu_MenuItemCopyAllResults"/>
                    <MenuItem Header="Copy Selected" x:Name="dgContextMenu_MenuItemCopySelectedResults"/>
                    <MenuItem Header="Clear All" x:Name ="dgContextMenu_MenuItemClearAllResults"/>
                </ContextMenu>
            </DataGrid.ContextMenu>
            <DataGrid.Columns>
                <DataGridTextColumn Header="Site" Binding="{Binding SiteName}"></DataGridTextColumn>
                <DataGridTextColumn Header="Site Code" Binding="{Binding SiteCode}"></DataGridTextColumn>
                <DataGridTextColumn Header="Private" Binding="{Binding Private}"></DataGridTextColumn>
                <DataGridTextColumn Header="Local" Binding="{Binding Local}"></DataGridTextColumn>
                <DataGridTextColumn Header="LineURI" Binding="{Binding LineURI}"></DataGridTextColumn>
                <DataGridTextColumn Header="DDI" Binding="{Binding DDI}"></DataGridTextColumn>
                <DataGridTextColumn Header="Ext" Binding="{Binding Ext}"></DataGridTextColumn>
                <DataGridTextColumn Header="Name" Binding="{Binding Name}"></DataGridTextColumn>
                <DataGridTextColumn Header="First Name" Binding="{Binding FirstName}"></DataGridTextColumn>
                <DataGridTextColumn Header="Last Name" Binding="{Binding LastName}"></DataGridTextColumn>
                <DataGridTextColumn Header="Sip Address" Binding="{Binding SipAddress}"></DataGridTextColumn>
                <DataGridTextColumn Header="Type" Binding="{Binding Type}"></DataGridTextColumn>
                <DataGridTextColumn Header="Notes" Binding="{Binding Notes}"></DataGridTextColumn>
            </DataGrid.Columns>
        </DataGrid>
        <Separator Height="12" Margin="9,0,10.8,0" VerticalAlignment="Top" Grid.Row="1"/>
        <ScrollViewer Margin="10,33.6,9.8,38" VerticalScrollBarVisibility="Auto" Grid.Row="1">
            <TextBlock x:Name="txtblockWarnings" TextWrapping="Wrap" ScrollViewer.VerticalScrollBarVisibility="Auto" Background="#FFFFFED2" IsManipulationEnabled="True" Height="244"/>
        </ScrollViewer>
        <TextBox x:Name="txtOU" TextWrapping="Wrap" Margin="183,0,86.8,3.4" IsEnabled="False" Height="21" VerticalAlignment="Bottom" TabIndex="6"/>
        <Button x:Name="btnSelectOU" Content="Select OU" Margin="118,0,0,3.4" TabIndex="2" Height="21" VerticalAlignment="Bottom" HorizontalAlignment="Left" Width="60"/>
        <Button x:Name="btnMatch" Content="Match Now" HorizontalAlignment="Right" Margin="0,0,11,3" Width="70.8" UseLayoutRounding="False" TabIndex="2" Height="21.2" VerticalAlignment="Bottom"/>
        <Button x:Name="btnSaveDIDMatches" Content="Save" HorizontalAlignment="Left" Margin="65,0,0,3" Width="48" UseLayoutRounding="False" TabIndex="1" Height="21" VerticalAlignment="Bottom"/>
        <Button x:Name="btnLoadDIDMatches" Content="Load" HorizontalAlignment="Left" Margin="12,0,0,3.4" Width="48" TabIndex="0" Height="21" VerticalAlignment="Bottom"/>
        <Label Content="Information/Warnings" Margin="10,7.8,10.8,0" FontWeight="Bold" Grid.Row="1" Height="26" VerticalAlignment="Top"/>
        <Button x:Name="btnExit" Content="Exit" Margin="0,0,9.8,10" UseLayoutRounding="False" TabIndex="4" Height="21.2" VerticalAlignment="Bottom" Grid.Row="1" IsCancel="True" HorizontalAlignment="Right" Width="70.8"/>

    </Grid>
</Window>
'@
        
        # Read XAML
        $reader=(New-Object System.Xml.XmlNodeReader $xamlMain) 
        $window=[Windows.Markup.XamlReader]::Load( $reader )

        $namespace = @{ x = 'http://schemas.microsoft.com/winfx/2006/xaml' }
        $xpath_formobjects = "//*[@*[contains(translate(name(.),'n','N'),'Name')]]" 

        # Create a variable for every named xaml element
        Select-Xml $xamlMain -Namespace $namespace -xpath $xpath_formobjects | Foreach {
            $_.Node | Foreach {
                Set-Variable -Name ($_.Name) -Value $window.FindName($_.Name)
            }
        }
        #region functions
        function New-Popup {
            param (
                [Parameter(Position=0,Mandatory=$True,HelpMessage="Enter a message for the popup")]
                [ValidateNotNullorEmpty()]
                [string]$Message,
                [Parameter(Position=1,Mandatory=$True,HelpMessage="Enter a title for the popup")]
                [ValidateNotNullorEmpty()]
                [string]$Title,
                [Parameter(Position=2,HelpMessage="How many seconds to display? Use 0 require a button click.")]
                [ValidateScript({$_ -ge 0})]
                [int]$Time=0,
                [Parameter(Position=3,HelpMessage="Enter a button group")]
                [ValidateNotNullorEmpty()]
                [ValidateSet("OK","OKCancel","AbortRetryIgnore","YesNo","YesNoCancel","RetryCancel")]
                [string]$Buttons="OK",
                [Parameter(Position=4,HelpMessage="Enter an icon set")]
                [ValidateNotNullorEmpty()]
                [ValidateSet("Stop","Question","Exclamation","Information" )]
                [string]$Icon="Information"
            )

            #convert buttons to their integer equivalents
            switch ($Buttons) {
                "OK"               {$ButtonValue = 0}
                "OKCancel"         {$ButtonValue = 1}
                "AbortRetryIgnore" {$ButtonValue = 2}
                "YesNo"            {$ButtonValue = 4}
                "YesNoCancel"      {$ButtonValue = 3}
                "RetryCancel"      {$ButtonValue = 5}
            }

            #set an integer value for Icon type
            switch ($Icon) {
                "Stop"        {$iconValue = 16}
                "Question"    {$iconValue = 32}
                "Exclamation" {$iconValue = 48}
                "Information" {$iconValue = 64}
            }

            #create the COM Object
            Try {
                $wshell = New-Object -ComObject Wscript.Shell -ErrorAction Stop
                #Button and icon type values are added together to create an integer value
                $wshell.Popup($Message,$Time,$Title,$ButtonValue+$iconValue)
            }
            Catch {
                Write-Warning "Failed to create Wscript.Shell COM object"
                Write-Warning $_.exception.message
            }
        }

        function Set-ClipBoard{
          param(
            [string]$text
          )
          process{
            Add-Type -AssemblyName System.Windows.Forms
            $tb = New-Object System.Windows.Forms.TextBox
            $tb.Multiline = $true
            $tb.Text = $text
            $tb.SelectAll()
            $tb.Copy()
          }
        }

        function Get-FileFromDialog {
            # Example: 
            #  $fileName = Get-FileFromDialog -fileFilter 'CSV file (*.csv)|*.csv' -titleDialog "Select A CSV File:"
            [CmdletBinding()] 
            param (
                [Parameter(Position=0)]
                [string]$initialDirectory = './',
                [Parameter(Position=1)]
                [string]$fileFilter = 'All files (*.*)| *.*',
                [Parameter(Position=2)] 
                [string]$titleDialog = '',
                [Parameter(Position=3)] 
                [switch]$AllowMultiSelect=$false
            )
            [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

            $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $OpenFileDialog.initialDirectory = $initialDirectory
            $OpenFileDialog.filter = $fileFilter
            $OpenFileDialog.Title = $titleDialog
            $OpenFileDialog.ShowHelp = if ($Host.name -eq 'ConsoleHost') {$true} else {$false}
            if ($AllowMultiSelect) { $openFileDialog.MultiSelect = $true } 
            $OpenFileDialog.ShowDialog() | Out-Null
            if ($AllowMultiSelect) { return $openFileDialog.Filenames } else { return $openFileDialog.Filename }
        }

        function Save-FileFromDialog {
            # Example: 
            #  $fileName = Save-FileFromDialog -defaultfilename 'backup.csv' -titleDialog 'Backup to a CSV file:'
            [CmdletBinding()] 
            param (
                [Parameter(Position=0)]
                [string]$initialDirectory = './',
                [Parameter(Position=1)]
                [string]$defaultfilename = '',
                [Parameter(Position=2)]
                [string]$fileFilter = 'All files (*.*)| *.*',
                [Parameter(Position=3)] 
                [string]$titleDialog = ''
            )
            [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

            $SetBackupLocation = New-Object System.Windows.Forms.SaveFileDialog
            $SetBackupLocation.initialDirectory = $initialDirectory
            $SetBackupLocation.filter = $fileFilter
            $SetBackupLocation.FilterIndex = 2
            $SetBackupLocation.Title = $titleDialog
            $SetBackupLocation.RestoreDirectory = $true
            $SetBackupLocation.ShowHelp = if ($Host.name -eq 'ConsoleHost') {$true} else {$false}
            $SetBackupLocation.filename = $defaultfilename
            $SetBackupLocation.ShowDialog() | Out-Null
            return $SetBackupLocation.Filename
        }

        function Add-Array2Clipboard {
          param (
            [PSObject[]]$ConvertObject,
            [switch]$Header
          )
          process{
            $array = @()

            if ($Header) {
              $line =""
              $ConvertObject | Get-Member -MemberType Property,NoteProperty,CodeProperty | Select -Property Name | %{
                $line += ($_.Name.tostring() + "`t")
              }
              $array += ($line.TrimEnd("`t") + "`r")
            }
            foreach($row in $ConvertObject){
                $line =""
                $row | Get-Member -MemberType Property,NoteProperty | %{
                  $Name = $_.Name
                  if(!$Row.$Name){$Row.$Name = ""}
                  $line += ([string]$Row.$Name + "`t")
                }
                $array += ($line.TrimEnd("`t") + "`r")
            }
            Set-ClipBoard $array
          }
        }
        
        function Get-OUDialog {
            <#
            .SYNOPSIS
            A self contained WPF/XAML treeview organizational unit selection dialog box.
            .DESCRIPTION
            A self contained WPF/XAML treeview organizational unit selection dialog box. No AD modules required, just need to be joined to the domain.
            .EXAMPLE
            $OU = Get-OUDialog
            .NOTES
            Author: Zachary Loeber
            Requires: Powershell 4.0
            Version History
            1.0.0 - 03/21/2015
                - Initial release (the function is a bit overbloated because I'm simply embedding some of my prior functions directly
                  in the thing instead of customizing the code for the function. Meh, it gets the job done...
            .LINK
            https://github.com/zloeber/Powershell/blob/master/ActiveDirectory/Select-OU/Get-OUDialog.ps1
            .LINK
            http://www.the-little-things.net
            #>
            [CmdletBinding()]
            param()
            
            function Get-ChildOUStructure {
                <#
                .SYNOPSIS
                Create JSON exportable tree view of AD OU (or other) structures.
                .DESCRIPTION
                Create JSON exportable tree view of AD OU (or other) structures in Canonical Name format.
                .PARAMETER ouarray
                Array of OUs in CanonicalName format (ie. domain/ou1/ou2)
                .PARAMETER oubase
                Base of OU
                .EXAMPLE
                $OUs = @(Get-ADObject -Filter {(ObjectClass -eq "OrganizationalUnit")} -Properties CanonicalName).CanonicalName
                $test = $OUs | Get-ChildOUStructure | ConvertTo-Json -Depth 20
                .NOTES
                Author: Zachary Loeber
                Requires: Powershell 3.0, Lync
                Version History
                1.0.0 - 12/24/2014
                    - Initial release
                .LINK
                https://github.com/zloeber/Powershell/blob/master/ActiveDirectory/Get-ChildOUStructure.ps1
                .LINK
                http://www.the-little-things.net
                #>
                [CmdletBinding()]
                param(
                    [Parameter(Position=0, ValueFromPipeline=$true, Mandatory=$true, HelpMessage='Array of OUs in CanonicalName formate (ie. domain/ou1/ou2)')]
                    [string[]]$ouarray,
                    [Parameter(Position=1, HelpMessage='Base of OU.')]
                    [string]$oubase = ''
                )
                begin {
                    $newarray = @()
                    $base = ''
                    $firstset = $false
                    $ouarraylist = @()
                }
                process {
                    $ouarraylist += $ouarray
                }
                end {
                    $ouarraylist = $ouarraylist | Where {($_ -ne $null) -and ($_ -ne '')} | Select -Unique | Sort-Object
                    if ($ouarraylist.count -gt 0) {
                        $ouarraylist | Foreach {
                           # $prioroupath = if ($oubase -ne '') {$oubase + '/' + $_} else {''}
                            $firstelement = @($_ -split '/')[0]
                            $regex = "`^`($firstelement`?`)"
                            $tmp = $_ -replace $regex,'' -replace "^(\/?)",''

                            if (-not $firstset) {
                                $base = $firstelement
                                $firstset = $true
                            }
                            else {
                                if (($base -ne $firstelement) -or ($tmp -eq '')) {
                                    Write-Verbose "Processing Subtree for: $base"
                                    $fulloupath = if ($oubase -ne '') {$oubase + '/' + $base} else {$base}
                                    New-Object psobject -Property @{
                                        'name' = $base
                                        'path' = $fulloupath
                                        'children' = if ($newarray.Count -gt 0) {,@(Get-ChildOUStructure -ouarray $newarray -oubase $fulloupath)} else {$null}
                                    }
                                    $base = $firstelement
                                    $newarray = @()
                                    $firstset = $false
                                }
                            }
                            if ($tmp -ne '') {
                                $newarray += $tmp
                            }
                        }
                        Write-Verbose "Processing Subtree for: $base"
                        $fulloupath = if ($oubase -ne '') {$oubase + '/' + $base} else {$base}
                        New-Object psobject -Property @{
                            'name' = $base
                            'path' = $fulloupath
                            'children' = if ($newarray.Count -gt 0) {,@(Get-ChildOUStructure -ouarray $newarray -oubase $fulloupath)} else {$null}
                        }
                    }
                }
            }
    
            function Convert-CNToDN {
                param([string]$CN)
                $SplitCN = $CN -split '/'
                if ($SplitCN.Count -eq 1) {
                    return 'DC=' + (($SplitCN)[0] -replace '\.',',DC=')
                }
                else {
                    $basedn = '.'+($SplitCN)[0] -replace '\.',',DC='
                    [array]::Reverse($SplitCN)
                    $ous = ''
                    for ($index = 0; $index -lt ($SplitCN.count - 1); $index++) {
                        $ous += 'OU=' + $SplitCN[$index] + ','
                    }
                    $result = ($ous + $basedn) -replace ',,',','
                    return $result
                }
            }

            function Add-TreeItem {
                param(
                      $TreeObj,
                      $Name,
                      $Parent,
                      $Tag
                      )

                $ChildItem = New-Object System.Windows.Controls.TreeViewItem
                $ChildItem.Header = $Name
                $ChildItem.Tag = $Tag
                $Parent.Items.Add($ChildItem) | Out-Null

                if (($TreeObj.children).Count -gt 0) {
                    foreach ($ou in $TreeObj.children) {
                        $treeparent = Add-TreeItem -TreeObj $ou -Name $ou.Name -Parent $ChildItem -Tag $ou.path
                    }
                }
            }

            if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {               
                Write-Warning 'Run PowerShell.exe with -Sta switch, then run this script.'
                Write-Warning 'Example:'
                Write-Warning '    PowerShell.exe -noprofile -Sta'
                break
            }

            [void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
            [xml]$xamlMain = @'
        <Window x:Name="windowSelectOU"
                xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                Title="Select OU" Height="350" Width="525">
            <Grid>
                <TreeView x:Name="treeviewOUs" Margin="10,10,10.4,33.8"/>
                <Button x:Name="btnCancel" Content="Cancel" Margin="0,0,10.4,5.8" ToolTip="Filter" Height="23" VerticalAlignment="Bottom" HorizontalAlignment="Right" Width="71" IsCancel="True"/>
                <Button x:Name="btnSelect" Content="Select" Margin="0,0,86.4,5.8" ToolTip="Filter" HorizontalAlignment="Right" Width="71" Height="23" VerticalAlignment="Bottom" IsDefault="True"/>
                <TextBlock x:Name="txtSelectedOU" Margin="10,0,162.4,5.8" TextWrapping="Wrap" VerticalAlignment="Bottom" Height="23" Background="{DynamicResource {x:Static SystemColors.ControlBrushKey}}" IsEnabled="False"/>
            </Grid>
        </Window>
'@

            # Read XAML
            $reader=(New-Object System.Xml.XmlNodeReader $xamlMain) 
            $window=[Windows.Markup.XamlReader]::Load( $reader )

            $namespace = @{ x = 'http://schemas.microsoft.com/winfx/2006/xaml' }
            $xpath_formobjects = "//*[@*[contains(translate(name(.),'n','N'),'Name')]]" 

            # Create a variable for every named xaml element
            Select-Xml $xamlMain -Namespace $namespace -xpath $xpath_formobjects | Foreach {
                $_.Node | Foreach {
                    Set-Variable -Name ($_.Name) -Value $window.FindName($_.Name)
                }
            }

            $conn = Connect-ActiveDirectory -ADContextType:DirectoryEntry
            $domstruct = @(Search-AD -DirectoryEntry $conn -Filter '(ObjectClass=organizationalUnit)' -Properties CanonicalName).CanonicalName | sort | Get-ChildOUStructure

            Add-TreeItem -TreeObj $domstruct -Name $domstruct.Name -Parent $treeviewOUs -Tag $domstruct.path

            $treeviewOUs.add_SelectedItemChanged({
                $txtSelectedOU.Text = Convert-CNToDN $this.SelectedItem.Tag
            })

            $btnSelect.add_Click({
                $script:DialogResult = $txtSelectedOU.Text
                $windowSelectOU.Close()
            })
            $btnCancel.add_Click({
                $script:DialogResult = $null
            })

            # Due to some bizarre bug with showdialog and xaml we need to invoke this asynchronously 
            #  to prevent a segfault
            $async = $windowSelectOU.Dispatcher.InvokeAsync({
                $retval = $windowSelectOU.ShowDialog()
            })
            $async.Wait() | Out-Null

            # Clear out previously created variables for every named xaml element to be nice...
            Select-Xml $xamlMain -Namespace $namespace -xpath $xpath_formobjects | Foreach {
                $_.Node | Foreach {
                    Remove-Variable -Name ($_.Name)
                }
            }
            return $DialogResult
        }

        function Connect-ActiveDirectory {
            [CmdletBinding()]
            param (
                [Parameter(ParameterSetName='Credential')]
                [Parameter(ParameterSetName='CredentialObject')]
                [Parameter(ParameterSetName='Default')]
                [string]$ComputerName,
                
                [Parameter(ParameterSetName='Credential')]
                [string]$DomainName,
                
                [Parameter(ParameterSetName='Credential', Mandatory=$true)]
                [string]$UserName,
                
                [Parameter(ParameterSetName='Credential', HelpMessage='Password for Username in remote domain.', Mandatory=$true)]
                [string]$Password,
                
                [parameter(ParameterSetName='CredentialObject',HelpMessage='Full credential object',Mandatory=$True)]
                [System.Management.Automation.PSCredential]$Creds,
                
                [Parameter(HelpMessage='Context to return, forest, domain, or DirectoryEntry.')]
                [ValidateSet('Domain','Forest','DirectoryEntry','ADContext')]
                [string]$ADContextType = 'ADContext'
            )
            
            $UsingAltCred = $false
            
            # If the username was passed in domain\<username> or username@domain then gank the domain name for later use
            if (($UserName -split "\\").Count -gt 1) {
                $DomainName = ($UserName -split "\\")[0]
                $UserName = ($UserName -split "\\")[1]
            }
            if (($UserName -split "\@").Count -gt 1) {
                $DomainName = ($UserName -split "\@")[1]
                $UserName = ($UserName -split "\@")[0]
            }
            
            switch ($PSCmdlet.ParameterSetName) {
                'CredentialObject' {
                    if ($Creds.GetNetworkCredential().Domain -ne '')  {
                        $UserName= $Creds.GetNetworkCredential().UserName
                        $Password = $Creds.GetNetworkCredential().Password
                        $DomainName = $Creds.GetNetworkCredential().Domain
                        $UsingAltCred = $true
                    }
                    else {
                        throw 'The credential object must include a defined domain.'
                    }
                }
                'Credential' {
                    if (-not $DomainName) {
                        Write-Error 'Username must be in @domainname.com or <domainname>\<username> format or the domain name must be manually passed in the DomainName parameter'
                        return $null
                    }
                    else {
                        $UserName = $DomainName + '\' + $UserName
                        $UsingAltCred = $true
                    }
                }
            }

            $ADServer = ''
            
            # If a computer name was specified then we will attempt to perform a remote connection
            if ($ComputerName) {
                # If a computername was specified then we are connecting remotely
                $ADServer = "LDAP://$($ComputerName)"
                $ContextType = [System.DirectoryServices.ActiveDirectory.DirectoryContextType]::DirectoryServer

                if ($UsingAltCred) {
                    $ADContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext $ContextType, $ComputerName, $UserName, $Password
                }
                else {
                    if ($ComputerName) {
                        $ADContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext $ContextType, $ComputerName
                    }
                    else {
                        $ADContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext $ContextType
                    }
                }
                
                try {
                    switch ($ADContextType) {
                        'ADContext' {
                            return $ADContext
                        }
                        'DirectoryEntry' {
                            if ($UsingAltCred) {
                                return New-Object System.DirectoryServices.DirectoryEntry($ADServer ,$UserName, $Password)
                            }
                            else {
                                return New-Object -TypeName System.DirectoryServices.DirectoryEntry $ADServer
                            }
                        }
                        'Forest' {
                            return [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($ADContext)
                        }
                        'Domain' {
                            return [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($ADContext)
                        }
                    }
                }
                catch {
                    throw
                }
            }
            
            # If using just an alternate credential without specifying a remote computer (dc) to connect they
            # try connecting to the locally joined domain with the credentials.
            if ($UsingAltCred) {
                # *** FINISH ME ***
            }
            # We have not specified another computer or credential so connect to the local domain if possible.
            try {
                $ContextType = [System.DirectoryServices.ActiveDirectory.DirectoryContextType]::Domain
            }
            catch {
                throw 'Unable to connect to a default domain. Is this a domain joined account?'
            }
            try {
                switch ($ADContextType) {
                    'ADContext' {
                        return New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext $ContextType
                    }
                    'DirectoryEntry' {
                        return [System.DirectoryServices.DirectoryEntry]''
                    }
                    'Forest' {
                        return [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
                    }
                    'Domain' {
                        return [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
                    }
                }
            }
            catch {
                throw
            }
        }

        function Search-AD {
            # Original Author (largely unmodified btw): 
            #  http://becomelotr.wordpress.com/2012/11/02/quick-active-directory-search-with-pure-powershell/
            [CmdletBinding()]
            param (
                [string[]]$Filter,
                [string[]]$Properties = @('Name','ADSPath'),
                [string]$SearchRoot='',
                [switch]$DontJoinAttributeValues,
                [System.DirectoryServices.DirectoryEntry]$DirectoryEntry = $null
            )

            if ($DirectoryEntry -ne $null) {
                if ($SearchRoot -ne '') {
                    $DirectoryEntry.set_Path($SearchRoot)
                }
            }
            else {
                $DirectoryEntry = [System.DirectoryServices.DirectoryEntry]$SearchRoot
            }

            if ($Filter) {
                $LDAP = "(&({0}))" -f ($Filter -join ')(')
            }
            else {
                $LDAP = "(name=*)"
            }
            try {
                (New-Object System.DirectoryServices.DirectorySearcher -ArgumentList @(
                    $DirectoryEntry,
                    $LDAP,
                    $Properties
                ) -Property @{
                    PageSize = 1000
                }).FindAll() | ForEach-Object {
                    $ObjectProps = @{}
                    $_.Properties.GetEnumerator() |
                        Foreach-Object {
                            $Val = @($_.Value)
                            if ($_.Name -ne $null) {
                                if ($DontJoinAttributeValues -and ($Val.Count -gt 1)) {
                                    $ObjectProps.Add($_.Name,$_.Value)
                                }
                                else {
                                    $ObjectProps.Add($_.Name,(-join $_.Value))
                                }
                            }
                        }
                    if ($ObjectProps.psbase.keys.count -ge 1) {
                        New-Object PSObject -Property $ObjectProps | Select $Properties
                    }
                }
            }
            catch {
                Write-Warning -Message ('Search-AD: Filter - {0}: Root - {1}: Error - {2}' -f $LDAP,$Root.Path,$_.Exception.Message)
            }
        }

        function Format-LyncADAccount {
            [cmdletbinding()]
            param(
                [Parameter(HelpMessage='User or users to process.', Mandatory=$true, ValueFromPipeline=$true)]
                [psobject]$User,
                [Parameter(HelpMessage='Type of account.')]
                [string]$PhoneType = ''
            )
            begin {}
            process {
                $userinfo = @{
                    UserName = $User.Name
                    UserLogin = $User.SamAccountName
                    SID = $User.SID
                    dn = $User.distinguishedName
                    Enabled = $null
                    SIPAddress = $User.'msrtcsip-primaryuseraddress'
                    PhoneType = ''
                    LyncEnabled = $null
                    UMEnabled = $null
                    OU = $User.distinguishedName -replace "$(($User.distinguishedName -split ',')[0]),",''
                    Extension = $null
                    email = $User.mail
                    DID = $null
                    DDI = $null
                    PrivateDID = $null
                    ADPhoneNumber = $User.telephoneNumber
                    department = $User.department
                    office = $User.physicalDeliveryOfficeName
                    Notes = ''
                }
                if ($User.useraccountcontrol -ne $null) {
                    $userinfo.Enabled = -not (Convert-ADUserAccountControl $User.useraccountcontrol).ACCOUNTDISABLE
                }
                $userinfo.LyncEnabled = if ($User.'msRTCSIP-UserEnabled') {$true} else {$false}
                $userinfo.UMEnabled = if ($User.msExchUMEnabledFlags -ne $null) {$true} else {$false}
                $userinfo.Extension = if ($User.'msRTCSIP-Line' -match '^.*ext=(.*)$') {$matches[1]}
                $userinfo.DID = if ($User.'msRTCSIP-Line' -ne $null) {$User.'msRTCSIP-Line'}
                $userinfo.DDI = if ($User.'msRTCSIP-Line' -match '^tel:\+*(.*).*$') {$Matches[1]} `
                $userinfo.PrivateDID = if ($User.'msRTCSIP-PrivateLine' -ne $null) {$User.'msRTCSIP-PrivateLine'}
                switch ($User.'msrtcsip-ownerurn') {
                    'urn:application:Caa' {
                        $userinfo.PhoneType = 'DialIn Conferencing'
                    }
                    'msrtcsip-ownerurn' {
                        $userinfo.PhoneType = 'RGS Workflow'
                    }
                    'urn:device:commonareaphone' {
                        $userinfo.PhoneType = 'Common Area'
                    }
                    
                    default {
                        $userinfo.PhoneType = $PhoneType
                    }
                }

                New-Object psobject -Property $userinfo
            }
            end {}
        }

        function Convert-ADUserAccountControl 
        {
            <#
                author: Zachary Loeber
                http://support.microsoft.com/kb/305144
                http://msdn.microsoft.com/en-us/library/cc245514.aspx
                
                Takes the useraccesscontrol property, evaluates it, and spits out an object with all set UAC properties
            #>
            [cmdletbinding()]
            param(
                [Parameter(HelpMessage='User or users to process.', Mandatory=$true, ValueFromPipeline=$true)]
                [string]$UACProperty
            )

            Add-Type -TypeDefinition @"
            [System.Flags]
            public enum userAccountControlFlags {
                SCRIPT                                  = 0x0000001,
                ACCOUNTDISABLE                          = 0x0000002,
                NOT_USED                                = 0x0000004,
                HOMEDIR_REQUIRED                        = 0x0000008,
                LOCKOUT                                 = 0x0000010,
                PASSWD_NOTREQD                          = 0x0000020,
                PASSWD_CANT_CHANGE                      = 0x0000040,
                ENCRYPTED_TEXT_PASSWORD_ALLOWED         = 0x0000080,
                TEMP_DUPLICATE_ACCOUNT                  = 0x0000100,
                NORMAL_ACCOUNT                          = 0x0000200,
                INTERDOMAIN_TRUST_ACCOUNT               = 0x0000800,
                WORKSTATION_TRUST_ACCOUNT               = 0x0001000,
                SERVER_TRUST_ACCOUNT                    = 0x0002000,
                DONT_EXPIRE_PASSWD                      = 0x0010000,
                MNS_LOGON_ACCOUNT                       = 0x0020000,
                SMARTCARD_REQUIRED                      = 0x0040000,
                TRUSTED_FOR_DELEGATION                  = 0x0080000,
                NOT_DELEGATED                           = 0x0100000,
                USE_DES_KEY_ONLY                        = 0x0200000,
                DONT_REQUIRE_PREAUTH                    = 0x0400000,
                PASSWORD_EXPIRED                        = 0x0800000,
                TRUSTED_TO_AUTH_FOR_DELEGATION          = 0x1000000
            }
"@
            $UACAttribs = @(
                'SCRIPT',
                'ACCOUNTDISABLE',
                'NOT_USED',
                'HOMEDIR_REQUIRED',
                'LOCKOUT',
                'PASSWD_NOTREQD',
                'PASSWD_CANT_CHANGE',
                'ENCRYPTED_TEXT_PASSWORD_ALLOWED',
                'TEMP_DUPLICATE_ACCOUNT',
                'NORMAL_ACCOUNT',
                'INTERDOMAIN_TRUST_ACCOUNT',
                'WORKSTATION_TRUST_ACCOUNT',
                'SERVER_TRUST_ACCOUNT',
                'DONT_EXPIRE_PASSWD',
                'MNS_LOGON_ACCOUNT',
                'SMARTCARD_REQUIRED',
                'TRUSTED_FOR_DELEGATION',
                'NOT_DELEGATED',
                'USE_DES_KEY_ONLY',
                'DONT_REQUIRE_PREAUTH',
                'PASSWORD_EXPIRED',
                'TRUSTED_TO_AUTH_FOR_DELEGATION',
                'PARTIAL_SECRETS_ACCOUNT'
            )

            try {
                Write-Verbose ('Convert-ADUserAccountControl: Converting UAC.')
                $UACOutput = New-Object psobject
                $UAC = [Enum]::Parse('userAccountControlFlags', $UACProperty)
                $UACAttribs | Foreach {
                    Add-Member -InputObject $UACOutput -MemberType NoteProperty -Name $_ -Value ($UAC -match $_) -Force
                }
                Write-Output $UACOutput
            }
            catch {
                Write-Warning -Message ('Convert-ADUserAccountControl: {0}' -f $_.Exception.Message)
            }
        }

        function Append-ADUserAccountControl {
            <#
                author: Zachary Loeber
                http://support.microsoft.com/kb/305144
                http://msdn.microsoft.com/en-us/library/cc245514.aspx
                
                Takes an object containing the useraccesscontrol property, evaluates it, and appends all set UAC properties
            #>
            [cmdletbinding()]
            param(
                [Parameter(HelpMessage='User or users to process.', Mandatory=$true, ValueFromPipeline=$true)]
                [psobject[]]$User
            )

            begin {
                Add-Type -TypeDefinition @" 
                [System.Flags]
                public enum userAccountControlFlags {
                    SCRIPT                                  = 0x0000001,
                    ACCOUNTDISABLE                          = 0x0000002,
                    NOT_USED                                = 0x0000004,
                    HOMEDIR_REQUIRED                        = 0x0000008,
                    LOCKOUT                                 = 0x0000010,
                    PASSWD_NOTREQD                          = 0x0000020,
                    PASSWD_CANT_CHANGE                      = 0x0000040,
                    ENCRYPTED_TEXT_PASSWORD_ALLOWED         = 0x0000080,
                    TEMP_DUPLICATE_ACCOUNT                  = 0x0000100,
                    NORMAL_ACCOUNT                          = 0x0000200,
                    INTERDOMAIN_TRUST_ACCOUNT               = 0x0000800,
                    WORKSTATION_TRUST_ACCOUNT               = 0x0001000,
                    SERVER_TRUST_ACCOUNT                    = 0x0002000,
                    DONT_EXPIRE_PASSWD                      = 0x0010000,
                    MNS_LOGON_ACCOUNT                       = 0x0020000,
                    SMARTCARD_REQUIRED                      = 0x0040000,
                    TRUSTED_FOR_DELEGATION                  = 0x0080000,
                    NOT_DELEGATED                           = 0x0100000,
                    USE_DES_KEY_ONLY                        = 0x0200000,
                    DONT_REQUIRE_PREAUTH                    = 0x0400000,
                    PASSWORD_EXPIRED                        = 0x0800000,
                    TRUSTED_TO_AUTH_FOR_DELEGATION          = 0x1000000
                }
"@
                $Users = @()
                $UACAttribs = @(
                    'SCRIPT',
                    'ACCOUNTDISABLE',
                    'NOT_USED',
                    'HOMEDIR_REQUIRED',
                    'LOCKOUT',
                    'PASSWD_NOTREQD',
                    'PASSWD_CANT_CHANGE',
                    'ENCRYPTED_TEXT_PASSWORD_ALLOWED',
                    'TEMP_DUPLICATE_ACCOUNT',
                    'NORMAL_ACCOUNT',
                    'INTERDOMAIN_TRUST_ACCOUNT',
                    'WORKSTATION_TRUST_ACCOUNT',
                    'SERVER_TRUST_ACCOUNT',
                    'DONT_EXPIRE_PASSWD',
                    'MNS_LOGON_ACCOUNT',
                    'SMARTCARD_REQUIRED',
                    'TRUSTED_FOR_DELEGATION',
                    'NOT_DELEGATED',
                    'USE_DES_KEY_ONLY',
                    'DONT_REQUIRE_PREAUTH',
                    'PASSWORD_EXPIRED',
                    'TRUSTED_TO_AUTH_FOR_DELEGATION',
                    'PARTIAL_SECRETS_ACCOUNT'
                )
            }
            process {
                $Users += $User
            }
            end {
                foreach ($usr in $Users) {
                    if ($usr.PSObject.Properties.Match('useraccountcontrol').Count) {
                        try {
                            Write-Verbose ('Append-ADUserAccountControl: Found useraccountcontrol property, enumerating.')
                            $UAC = [Enum]::Parse('userAccountControlFlags', $usr.useraccountcontrol)
                            $UACAttribs | Foreach {
                                Add-Member -InputObject $usr -MemberType NoteProperty -Name $_ -Value ($UAC -match $_) -Force
                            }
                            Write-Output $usr
                        }
                        catch {
                            Write-Warning -Message ('Append-ADUserAccountControl: {0}' -f $_.Exception.Message)
                        }
                    }
                    else {
                        # if the uac property does not exist add all the uac properties to maintain like output
                        $UACAttribs | Foreach {
                            Write-Verbose ('Append-ADUserAccountControl: useraccountcontrol property NOT found.')
                            Add-Member -InputObject $usr -MemberType NoteProperty -Name $_ -Value $null -Force
                        }
                        Write-Output $usr
                    }
                }
            }
        }

        function Get-LyncEnabledObjectsFromAD {
            [cmdletbinding()]
            param(
                [Parameter(HelpMessage='Base of AD to search.')]
                $SearchBase = ''
            )

            try {
                $conn = Connect-ActiveDirectory -ADContextType:DirectoryEntry
                $DomainDN = $conn.distinguishedName
                $ConfigurationDN = 'CN=Configuration,' + $DomainDN
                if ($SearchBase -eq '') {
                    $SearchBase = [string]$DomainDN
                }
            }
            catch {
                Write-Warning 'Unabled to connect to AD!'
                $conn = $null
            }
            if ($conn -ne $null) {
                $LyncContacts = @()
                $LyncUsers = @()
                $Properties = @('Name','SamAccountName','SID','distinguishedName','useraccountcontrol','msRTCSIP-UserEnabled','msExchUMEnabledFlags','msRTCSIP-Line','msrtcsip-ownerurn','msRTCSIP-PrivateLine','msrtcsip-primaryuseraddress','telephoneNumber','OfficePhone','mail','department','physicalDeliveryOfficeName')

                #$Users = @(Search-AD -DirectoryEntry $conn -Filter '(objectCategory=person)(objectClass=user)(!(useraccountcontrol:1.2.840.113556.1.4.803:=2))(msRTCSIP-Line=*)' -Properties $Properties -SearchRoot ('LDAP://' + $SearchBase))
                $LyncUsers = @(Search-AD -DirectoryEntry $conn -Filter '(objectCategory=person)(objectClass=user)(|(msRTCSIP-Line=*)(msRTCSIP-PrivateLine=*))' -Properties $Properties -SearchRoot ('LDAP://' + $SearchBase))
                $LyncUsers = $LyncUsers | Format-LyncADAccount -PhoneType 'LyncUser'

                # Get configuration partition Lync enabled items (conference and RGS numbers)
                $LyncContacts = @(Search-AD -DirectoryEntry $conn -Filter '(ObjectClass=contact)(msRTCSIP-Line=*)' -Properties $Properties -SearchRoot ('LDAP://' + $SearchBase) | Format-LyncADAccount)

                # Get UM auto-attendant numbers assigned in exchange (from AD)
                $AANumbers = @(Search-AD -DontJoinAttributeValues -DirectoryEntry $conn -Filter '(ObjectClass=msExchUMAutoAttendant)' -Properties * -SearchRoot ('LDAP://' + $ConfigurationDN) | 
                    Where {$_.msExchUMAutoAttendantDialedNumbers} | Select -ExpandProperty msExchUMAutoAttendantDialedNumbers)
                $AAMatchNumbers = @($AANumbers | Foreach {[regex]::Escape($_)})
                $AAMatchNumbers = '^(' + ($AAMatchNumbers -join '|') + ')$'

                # Get all UM voicemail numbers assigned in exchange (from AD)
                $VMNumbers = @(Search-AD -DontJoinAttributeValues -DirectoryEntry $conn -Filter '(ObjectClass=msExchUMDialPlan)' -Properties * -SearchRoot ('LDAP://' + $ConfigurationDN) | 
                Where {($_.msExchUMVoiceMailPilotNumbers).Count -gt 0} | Select -ExpandProperty msExchUMVoiceMailPilotNumbers)
                $VMMatchNumbers = @($VMNumbers | Foreach {[regex]::Escape($_)})
                $VMMatchNumbers = '^(' + ($VMMatchNumbers -join '|') + ')$'

                # Look for voicemail and AA enabled contacts by matching them up with what you found in ad
                $LyncContacts | Foreach {
                    $tmpURI = $_.DID -replace 'tel:',''
                    if ($tmpURI -match $AAMatchNumbers) {
                        $_.PhoneType = 'UM Auto Attendant'
                    }
                    elseif ($tmpURI -match $VMMatchNumbers) {
                        $_.PhoneType = 'UM Voicemail'
                    }
                }
                
                Write-Output $LyncUsers
                Write-Output $LyncContacts
            }
        }

        #endregion functions
        #region Form events    
        $btnExit.add_Click({
            $script:DialogResult = $null
        })
        
        $dgContextMenu_MenuItemClearAllResults.add_Click({
            $datagridDIDs.Items.Clear()
        })

        $dgContextMenu_MenuItemCopyAllResults.add_Click({
            if ($datagridDIDs.Items.Count -gt 0) {
                $InputItems = $datagridDIDs.Items | Select *
                Add-Array2Clipboard -ConvertObject $InputItems -Header
            }
        })

        $dgContextMenu_MenuItemCopySelectedResults.add_Click({
            if ($datagridDIDs.Items.Count -gt 0) {
                $InputItems = $datagridDIDs.SelectedItems | Select *
                Add-Array2Clipboard -ConvertObject $InputItems -Header
            }
        })
        #endregion Form events
        
        $InputDIDRangeData = @()
    
    }
    
    process {
        $InputDIDRangeData += $InputDIDRanges
    }
    
    end {
        #region Populate Form Elements
        $InputDIDRangeData | Foreach { 
            $datagridDIDs.Items.Add($_)
        }
        #endregion
        # Due to some bizarre bug with showdialog and xaml we need to invoke this asynchronously 
        #  to prevent a segfault
        $async = $WindowADMatch.Dispatcher.InvokeAsync({
            $retval = $WindowADMatch.ShowDialog()
        })
        $async.Wait() | Out-Null

        # Clear out previously created variables for every named xaml element to be nice...
        Select-Xml $xamlMain -Namespace $namespace -xpath $xpath_formobjects | Foreach {
            $_.Node | Foreach {
                Remove-Variable -Name ($_.Name)
            }
        }
        return $DialogResult
    }
}
$test = New-Object psobject -Property @{
    SiteName = 'testsite'
    SiteCode = 10
    Private = $true
    Local = $false
    LineURI = 'tel:+16307301764;ext=1764'
    DDI=16307301764
    Ext=1764
    Name='Zachary Loeber'
    FirstName = 'Zachary'
    LastName = 'Loeber'
    SipAddress = 'sip:zloeber@psclistens.com'
    Type='User'
    Notes='Notes on this user'
}
$test | Get-LyncADMatchDialog
