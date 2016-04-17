$ServerName = 'MyServer'
$PermissionGroup = 'ScanToUserHomeDrives'
$RootFolder = 'U:\HomeDrives'

$objUser_RO = New-Object System.Security.Principal.NTAccount("$ServerName\$PermissionGroup")
$objACE_RO = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser_RO, 'ReadAndExecute, Synchronize', "ContainerInherit,ObjectInherit", 'None', "Allow")

$objUser_Full = New-Object System.Security.Principal.NTAccount('$ServerName\$PermissionGroup')
$objACE_Full = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser_Full, 'FullControl', "ContainerInherit,ObjectInherit", 'None', "Allow")


Get-ChildItem $RootFolder -Directory | foreach {

    $scanpath = "$RootFolder\$($_.Name)\scanned"
    $sharepath = "$RootFolder\$($_.Name)"
    
    if (-not (Test-Path $scanpath)) {
        Write-Host -ForegroundColor Cyan "$scanpath does not exist, creating it now...."
        new-item $scanpath -ItemType:Container
    }
    # get current ACL
    $objShareACL = get-acl $sharepath
    $objScanACL = get-acl $scanpath

    # add the acls to the list
    $objScanACL.AddAccessRule($objACE_Full)
    $objShareACL.AddAccessRule($objACE_RO)

    # apply the ACE
    set-ACL $sharepath $objShareACL
    set-ACL $scanpath $objScanACL
    
    Write-Host -ForegroundColor Green "$scanpath permissions updated!"
}