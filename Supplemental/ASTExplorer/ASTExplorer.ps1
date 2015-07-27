# Based largely on this awesome project (a functionalized winforms version of the same functionality):
#  https://github.com/lzybkr/ShowPSAst
#region Pre-Process
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $CommandLine = $MyInvocation.Line.Replace($MyInvocation.InvocationName, $MyInvocation.MyCommand.Definition)
    Write-Warning 'Script is not running in STA Apartment State.'
    Write-Warning '  Attempting to restart this script with the -Sta flag.....'
    Write-Verbose "  Script: $CommandLine"
    Start-Process -FilePath PowerShell.exe -ArgumentList "$CommandLine -Sta"
    exit
}
#endregion

#region Functions
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

function AddChildNode($child, $nodeList) {
    # A function to add an object to the display tree
    function PopulateNode($object, $nodeList)
    {
        foreach ($child in $object.PSObject.Properties)
        {
            # Skip the Parent node, it's not useful here
            if ($child.Name -eq 'Parent') { continue }

            $childObject = $child.Value

            if ($null -eq $childObject) { continue }

            # Recursively add only Ast nodes.
            if ($childObject -is [System.Management.Automation.Language.Ast])
            {
                AddChildNode $childObject $nodeList
                continue
            }

            # Several Ast properties are collections of Ast, add them all
            # as children of the current node.
            $collection = $childObject -as [System.Management.Automation.Language.Ast[]]
            if ($collection -ne $null)
            {
                for ($i = 0; $i -lt $collection.Length; $i++)
                {
                    AddChildNode ($collection[$i]) $nodeList
                }
                continue
            }

            # A little hack for IfStatementAst and SwitchStatementAst - they have a collection
            # of tuples of Ast.  Both items in the tuple are an Ast, so we want to recurse on both.
            if ($childObject.GetType().FullName -match 'ReadOnlyCollection.*Tuple`2.*Ast.*Ast')
            {
                for ($i = 0; $i -lt $childObject.Count; $i++)
                {
                    AddChildNode ($childObject[$i].Item1) $nodeList
                    AddChildNode ($childObject[$i].Item2) $nodeList
                }
                continue
            }
        }
    }

    # Create the new node to add with the node text of the item type and extent
    $childNode = New-Object System.Windows.Controls.TreeViewItem
    $childNode.Header = $child.GetType().Name + (" [{0},{1}]" -f $child.Extent.StartOffset,$child.Extent.EndOffset)
    $childNode.Tag = $child

    $null = $nodeList.Add($childNode)

    # Recursively add the current nodes children
    PopulateNode $child $childNode.Items

    # If we want the tree fully expanded after construction
    # $childNode.ExpandSubtree()
}

# A function invoked when a node in the tree view is selected.
function OnAfterSelect {
    param($TreeViewEventArgs)

    $script:dataView.Items.Clear()
    $selectedObject = $TreeViewEventArgs.Tag

    foreach ($property in $selectedObject.PSObject.Properties)
    {
        $typeName = [Microsoft.PowerShell.ToStringCodeMethods]::Type([type]$property.TypeNameOfValue)
        if ($typeName -match '.*ReadOnlyCollection\[(.*)\]')
        {
            # Lie about the type to make the display shorter
            $typeName = $matches[1] + '[]'
        }
        # Remove the namespace
        $typeName = $typeName -replace '.*\.',''
        $value = $property.Value
        if ($typeName -eq 'IScriptExtent')
        {
            $file = if ($value.File -eq $null) { "" } else { Split-Path -Leaf $value.File }
            $value = "{0} ({1},{2})-({3},{4})" -f $file, $value.StartLineNumber, $value.StartColumnNumber, $value.EndLineNumber, $value.EndColumnNumber
        }
        $ItemToAdd = New-Object psobject -Property @{
            'Property' = $property.Name
            'Value' = $value
            'Type' = $typeName
        }
        $script:dataView.Items.Add($ItemToAdd)
    }

    $startOffset = $selectedObject.Extent.StartOffset - $script:inputObjectStartOffset
    $startLine = $selectedObject.Extent.StartLineNumber
    $endOffset = $selectedObject.Extent.EndOffset - $script:inputObjectStartOffset

    # Need to do this at least once for some reason for the IsInactiveSelectionHighlightEnabled xaml property to work properly
    $script:scriptView.Focus()
    $script:scriptView.SelectionStart = $startOffset
    $script:scriptView.SelectionLength = $endOffset - $startOffset
    $script:treeView.Focus()
}

function LoadASTData {
    $AST = [System.Management.Automation.Language.Parser]::ParseFile($script:CurrentScriptFile, [ref]$null, [ref]$null)
    $script:treeView.Items.Clear()
    AddChildNode $AST $script:treeView.Items
    $script:inputObjectStartOffset = $AST.Extent.StartOffset
    $script:scriptView.Text = $AST.Extent.Text
}
#endregion

#region global variables
$inputObjectStartOffset = 0
$CurrentScriptFile = ''
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$xamlMain = @'
<Window x:Name="windowMain"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AST Explorer" Height="328.4" Width="525"
        FocusManager.FocusedElement="{Binding ElementName=scriptView}">
    <Grid Margin="0,0,0.4,-4.6">
        <Grid.RowDefinitions>
            <RowDefinition Height="55*"/>
            <RowDefinition Height="52*"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="134*"/>
            <ColumnDefinition Width="125*"/>
        </Grid.ColumnDefinitions>
        <TreeView x:Name="treeView" Margin="10,10,0,5">
        </TreeView>
        <TextBox x:Name="scriptView"  SelectionBrush="Pink" 
                 IsInactiveSelectionHighlightEnabled="True"  
                 VerticalScrollBarVisibility="Auto" 
                 HorizontalScrollBarVisibility="Auto" 
                 IsReadOnly="True" Grid.Column="1" 
                 Margin="0,10,10.4,34.2" Grid.RowSpan="2" 
                 TextWrapping="NoWrap" 
                 IsReadOnlyCaretVisible="True"
                  FocusManager.IsFocusScope="True">
            <TextBox.Resources>
                <SolidColorBrush x:Key="{x:Static SystemColors.InactiveSelectionHighlightBrushKey}">Pink</SolidColorBrush>
            </TextBox.Resources>
        </TextBox>
        <Button x:Name="btnLoad" Content="Load Script" Margin="10,0,0,10.2" Grid.Row="1" Height="19" VerticalAlignment="Bottom" HorizontalAlignment="Left" Width="113"/>
        <TextBlock Grid.Column="1" HorizontalAlignment="Right" Height="19" Margin="0,0,10.4,10.2" Grid.Row="1" TextWrapping="Wrap" VerticalAlignment="Bottom" Width="154">
            <Hyperlink x:Name="hyperlinkHome" FontWeight="Black" Foreground="#0066B3" NavigateUri="http://www.the-little-things.net">www.the-little-things.net</Hyperlink>
        </TextBlock>
        <ListView x:Name="dataView" Margin="10,0,0,34.2" Grid.Row="1">
            <ListView.ItemContainerStyle>
                <Style TargetType="{x:Type ListViewItem}">
                    <Setter Property="BorderBrush" Value="LightGray" />
                    <Setter Property="BorderThickness" Value="0,0,0,1" />
                </Style>
            </ListView.ItemContainerStyle>
            <ListView.View>
                <GridView>
                    <GridViewColumn Header="Property">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding Property}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="Value">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding Value}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="Type">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding Type}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                </GridView>
            </ListView.View>
        </ListView>
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
#endregion

#region Form Hyperlinks
$hyperlinkHome.add_RequestNavigate({
    start $this.NavigateUri.AbsoluteUri
})
#endregion

#region Form state altering events
$treeView.add_SelectedItemChanged({ 
    OnAfterSelect $script:treeView.SelectedItem
})

#$scriptView.add_SelectionChanged({ 
#    $this.ScrollToLine($script:treeView.SelectedItem.Tag.Extent.StartLineNumber)
#})


#endregion

#region Buttons, buttons, buttons!
$btnLoad.add_Click({
    $filename = Get-FileFromDialog -fileFilter 'PS1 file (*.ps1)|*.ps1' -titleDialog "Select A PowerShell script:"
    if (($filename -ne '') -and (Test-Path $filename)) {
        $script:CurrentScriptFile = $filename
        LoadASTData
    }
})

#endregion

#region Main

# Show the dialog
# Due to some bizarre bug with showdialog and xaml we need to invoke this asynchronously to prevent a segfault
$async = $windowMain.Dispatcher.InvokeAsync({
    $windowMain.ShowDialog() | Out-Null
})
$async.Wait() | Out-Null

# Clear out previously created variables for every named xaml element to be nice...
Select-Xml $xamlMain -Namespace $namespace -xpath $xpath_formobjects | Foreach {
    $_.Node | Foreach {
        Remove-Variable -Name ($_.Name)
    }
}
#endregion