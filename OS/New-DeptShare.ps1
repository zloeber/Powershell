<#
.SYNOPSIS
Create a new department share on Server1 and setup the DFS share and all permission groups and settings.
.DESCRIPTION
Create a new department share on Server1 and setup the DFS share and all permission groups and settings.
.PARAMETER DeptName
Name of the department which is being setup. This should be without spaces, underline, or hyphen characters (ie. BusDevSales for business development and sales group)
.PARAMETER ShareName
The share name which will be used for the department share. This only needs to be specified if it will differ from the department name.
.NOTES
Version
    1.0.0 01/29/2016
    - Initial release
Author
    Zachary Loeber

.EXAMPLE
New-DeptShare -DeptName "BusDevSales"

Description
-----------
Creates the department share, applies all standard permissions, and sets up the DFS share target for the BusDevSales department.
#>
[CmdLetBinding(DefaultParameterSetName='AsString')]
param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="Enter a department name")]
    [string]$DeptName,
    [Parameter(HelpMessage="Enter a share name")]
    [string]$ShareName = $null,
    [Parameter(HelpMessage="Enter a share folder location.")]
    [string]$ShareLocalPath = 'D:\DeptShares\',
    [Parameter(HelpMessage="Enter an OU to create the new permission groups in.")]
    [string]$ADGroupPath = 'OU=Permission,OU=Service Groups,DC=contoso,DC=com',
    [Parameter(HelpMessage="Enter a FQDN domain name")]
    [string]$FQDNDomain = 'contoso.com',
    [Parameter(HelpMessage="Enter a FQDN domain name")]
    [string]$ShortDomain = 'CONTOSO'
)
Import-Module dfsn
Import-Module dfsr
Import-Module ActiveDirectory

if ([string]::IsNullOrEmpty($ShareName)) {
    $ShareName = $DeptName
}

$sharepath = "$($ShareLocalPath)\$($ShareName)"

# AD Groups
$ReadOnlyGroup = "perm_DeptShare-$($sharename)_ReadOnly"
$FullAccessGroup = "perm_DeptShare-$($sharename)_FullAccess"
$DenyGroup = "perm_DeptShare-$($sharename)_DenyAccess"

Write-Host -ForegroundColor Gray "Read Only Group: $($ReadOnlyGroup)"
Write-Host -ForegroundColor Gray "Full Access Group: $($FullAccessGroup)"
Write-Host -ForegroundColor Gray "Deny Group: $($DenyGroup)"

$smbshares = (Get-SmbShare).Name
$dfsfoldername = "\\$($FQDNDomain)\DeptShare\$($sharename)"
$FullAccessGroups = @('Administrators',$FullAccessGroup)
$dfscmd1 = 'dfsutil property sd grant \\<2>\DeptShare\<0> ISACA\<1>:F protect' -replace '<0>',$sharename -replace '<1>',$FullAccessGroup -replace '<2>',$FQDNDomain
$dfscmd2 = 'dfsutil property sd grant \\<2>\DeptShare\<0> ISACA\<1>:RX protect' -replace '<0>',$sharename -replace '<1>',$ReadOnlyGroup -replace '<2>',$FQDNDomain

# Create Read-Only permission group if it doesn't already exist.
try {
    Get-ADGroup $ReadOnlyGroup
}
catch {
    Write-Host -ForegroundColor:Cyan "Creating $($ReadOnlyGroup)..."
    New-ADGroup -Name $ReadOnlyGroup -SAMAccountName $ReadOnlyGroup -Description "Dept Share $ShareName - Read Only Access" -GroupCategory Security -Path $ADGroupPath -GroupScope Global
}

# Create Deny permission group if it doesn't already exist.
try {
    Get-ADGroup $DenyGroup
}
catch {
    Write-Host -ForegroundColor:Cyan "Creating $($DenyGroup)..."
    New-ADGroup -Name $DenyGroup -SAMAccountName $DenyGroup -Description "Dept Share $ShareName - Deny Access" -GroupCategory Security -Path $ADGroupPath -GroupScope Global
}

# Create Full Access permission group if it doesn't already exist.
try {
    Get-ADGroup $FullAccessGroup
}
catch {
    Write-Host -ForegroundColor:Cyan "Creating $($FullAccessGroup)..."
    New-ADGroup -Name $FullAccessGroup -SAMAccountName $FullAccessGroup -Description "Dept Share $ShareName - Full Access" -GroupCategory Security -Path $ADGroupPath -GroupScope Global
}

if ($smbshares -notcontains $share.NewShareName) {
    Write-Host -ForegroundColor:Cyan "Attempting to create share: $($sharename)"
    Write-Host
    if (-not (Test-Path $sharepath)) {
        New-Item -Path $sharepath -Type Container
        $objUser_RO = New-Object System.Security.Principal.NTAccount("$($ShortDomain)\$($ReadOnlyGroup)")
        $objUser_Full = New-Object System.Security.Principal.NTAccount("$($ShortDomain)\$($FullAccessGroup)")
        $objUser_Deny = New-Object System.Security.Principal.NTAccount("$($ShortDomain)\$($DenyGroup)")

        #combine the variables into a single filesystem access rule
        $objACE_RO = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser_RO, 'ReadAndExecute, Synchronize', "ContainerInherit,ObjectInherit", 'None', "Allow")
        $objACE_Full = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser_Full, 'FullControl', "ContainerInherit,ObjectInherit", 'InheritOnly', "Allow")
        $objACE_Deny = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser_Deny, 'FullControl', "ContainerInherit,ObjectInherit", 'None', "Deny")

        #get the current ACL from the folder
        $objACL = get-acl $sharepath

        $objACL.AddAccessRule($objACE_RO)
        $objACL.AddAccessRule($objACE_Full)
        $objACL.AddAccessRule($objACE_Deny)

        #add the access permissions from the ACL variable
        set-ACL $sharepath $objACL
    }
    if (Test-Path $sharepath) {
        New-SmbShare -Name $sharename -Path $sharepath -FullAccess $FullAccessGroups -ReadAccess $ReadOnlyGroup -NoAccess $DenyGroup
    }
    else {
        Write-Host -ForegroundColor DarkMagenta "Unable to find Path: $($sharepath)"
    }
    if (Test-Path $sharepath) {
        $dfsnfolder = Get-DfsnFolder $dfsfoldername -ErrorAction:Ignore
        if ($dfsnfolder -eq $null) {
           # $dfsnPath = $share.FutureShare -replace '\\\\',''
            Write-Host -ForegroundColor:DarkGreen "DFS Folder Not Found: $($dfsfoldername)"
            Write-Host -ForegroundColor:DarkGreen "...Attempting to create now:"
            Write-Host ""
            New-DfsnFolder -Path $dfsfoldername -TargetPath "\\Server1\$($sharename)"
            #New-DfsnFolderTarget -Path $share.FutureShare -TargetPath "\\$($share.NewServer)\$($share.NewShareName)"
            #New-DfsReplicationGroup -GroupName $dfsnPath | new-DfsReplicatedFolder -FolderName $share.NewShareName -DfsnPath $share.FutureShare
            #Add-DfsrMember -GroupName $dfsnPath -ComputerName $share.SourceServer
            #Add-DfsrMember -GroupName $dfsnPath -ComputerName $share.NewServer
            #Add-DfsrConnection -GroupName $dfsnPath -SourceComputerName $share.SourceServer -DestinationComputerName $share.NewServer
            #Set-DfsrMembership -GroupName $dfsnPath -FolderName $share.NewShareName -ContentPath $share.SourcePath -ComputerName $share.SourceServer -PrimaryMember $True -Force
            #Set-DfsrMembership -GroupName $dfsnPath -FolderName $share.NewShareName -ContentPath $sharepath -ComputerName $share.NewServer -Force
            
            Write-Host -ForegroundColor:DarkCyan "Configuring access based enumeration on the DFS share..."
            Invoke-Expression -Command $dfscmd1
            Invoke-Expression -Command $dfscmd2
            
            Write-Host -ForegroundColor Green "Processing Complete!"
            Write-Host -ForegroundColor Green "Please remember to assign the appropriate resource groups to the newly created permission groups in order to access the new share at: $($dfsfoldername)"
        }
        else {
            Write-Host -ForegroundColor:Yellow "DFS path already exists: $($sharename)"
        }
    }
}
else {
    Write-Warning "The share at $sharepath already exists! Doing Nothing!"
}