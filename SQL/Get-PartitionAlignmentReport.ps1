
<#
.PARAMETER OpenInNotepad
Value passed as $True or $False. Defaults to $False.
#>

<#
Source: http://www.sqlsolutionsgroup.com/improve-io-performance/#codesyntax_2

MODIFICATION LOG

2012-08-09 WGS Initial Creation.
2012-08-11 WGS Modified to work with PowerShell v1.
2013-02-05 WGS Modified to get Drive Letter.
2014-01-27 WGS Modified to return volume blocksize.
#> 
param (
    [switch] $OpenInNotepad
)
 
cls
 
FUNCTION Get-DriveLetter($PartPath) {
    #Get the logical disk mapping
    $LogicalDisks = Get-WMIObject Win32_LogicalDiskToPartition | `
        Where-Object {$_.Antecedent -eq $PartPath}
    $LogicalDrive = Get-WMIObject Win32_LogicalDisk | `
        Where-Object {$_.__PATH -eq $LogicalDisks.Dependent}
    $LogicalDrive.DeviceID
}
 
FUNCTION Get-VolumeBlockSize($PartPath) {
    $Drive = Get-DriveLetter($PartPath)
    IF ($Drive -gt "") {
        #Get the BlockSize of the volume
        $Volume = Get-WMIObject Win32_Volume | `
            Where-Object {$_.DriveLetter -eq  $Drive}
        $Volume.BlockSize
    }
}
 
FUNCTION Get-PartitionAlignment {
    Get-WMIObject Win32_DiskPartition | `
        Sort-Object DiskIndex, Index | `
        Select-Object -Property `
            @{Expression = {$_.DiskIndex};Label="Disk"},`
            @{Expression = {$_.Index};Label="Partition"},`
            @{Expression = {Get-DriveLetter($_.__PATH)};Label="Drive"},`
            @{Expression = {$_.BootPartition};Label="BootPartition"},`
            @{Expression = {"{0:N3}" -f ($_.Size/1Gb)};Label="Size_GB"},`
            @{Expression = {"{0:N0}" -f ($_.BlockSize)};Label="Partition_BlockSize"},`
            @{Expression = {Get-VolumeBlockSize($_.__PATH)};Label="Volume_BlockSize"},
            @{Expression = {"{0:N0}" -f ($_.StartingOffset/1Kb)};Label="Offset_KB"},`
            @{Expression = {"{0:N0}" -f ($_.StartingOffset/$_.BlockSize)}; Label="OffsetSectors"},`
            @{Expression = {IF (($_.StartingOffset % 64KB) -EQ 0) {" Yes"} ELSE {"  No"}};Label="64KB"}
}
 
 
# Hash table to set the alignment of the properties in the format-table
$b = `
@{Expression = {$_.Disk};Label="Disk"},`
@{Expression = {$_.Partition};Label="Partition"},`
@{Expression = {$_.Drive};Label="Drive"},`
@{Expression = {$_.BootPartition};Label="BootPartition"},`
@{Expression = {"{0:N3}" -f ($_.Size_GB)};Label="Size_GB";align="right"},`
@{Expression = {"{0:N0}" -f ($_.Partition_BlockSize)};Label="PartitionBlockSize";align="right"},`
@{Expression = {"{0:N0}" -f ($_.Volume_BlockSize)};Label="VolumeBlockSize";align="right"},`
@{Expression = {"{0:N0}" -f ($_.Offset_KB)};Label="Offset_KB";align="right"},`
@{Expression = {"{0:N0}" -f ($_.OffsetSectors)};Label="OffsetSectors";align="right"},`
@{Expression = {$_.{64KB}};Label="64KB"}
 
 
$a = Get-PartitionAlignment
 
 
# Display formatted data on the screen
$a | Sort-Object Drive, Disk, Partition | Format-Table $b -AutoSize
 
if ($OpenInNotepad) {
    # Export to a pipe-delimited file
    $a | Sort-Object Drive, Disk, Partition | Export-CSV $ENV:temp\PartInfo.txt -Delimiter "|" -NoTypeInformation
 
    # Open the file in NotePad
    Notepad $ENV:temp\PartInfo.txt
}
