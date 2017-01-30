#PowerShell: DownloadIspac.ps1
################################
########## PARAMETERS ##########
################################ 
# Change Server, folder, project and download folder
$SsisServer = "localhost" # Mandatory
$FolderName = ""         # Can be empty to download multiple projects
$ProjectName = ""       # Can be empty to download multiple projects
$DownloadFolder = "D:\MyIspacs\" # Mandatory
$CreateSubfolders = $true        # Mandatory
$UnzipIspac = $false             # Mandatory
 
 
#################################################
########## DO NOT EDIT BELOW THIS LINE ##########
#################################################
clear
Write-Host "========================================================================================================================================================"
Write-Host "== Used parameters =="
Write-Host "========================================================================================================================================================"
Write-Host "SSIS Server             :" $SsisServer
Write-Host "Folder Name             :" $FolderName
Write-Host "Project Name            :" $ProjectName
Write-Host "Local Download Folder   :" $DownloadFolder
Write-Host "Create Subfolders       :" $CreateSubfolders
Write-Host "Unzip ISPAC (> .NET4.5) :" $UnzipIspac
Write-Host "========================================================================================================================================================"
 
 
##########################################
########## Mandatory parameters ##########
##########################################
if ($SsisServer -eq "")
{
    Throw [System.Exception] "SsisServer parameter is mandatory"
}
if ($DownloadFolder -eq "")
{
    Throw [System.Exception] "DownloadFolder parameter is mandatory"
}
elseif (-not $DownloadFolder.EndsWith("\"))
{
    # Make sure the download path ends with an slash
    # so we can concatenate an subfolder and filename
    $DownloadFolder = $DownloadFolder = "\"
}
 
 
############################
########## SERVER ##########
############################
# Load the Integration Services Assembly
Write-Host "Connecting to server $SsisServer "
$SsisNamespace = "Microsoft.SqlServer.Management.IntegrationServices"
[System.Reflection.Assembly]::LoadWithPartialName($SsisNamespace) | Out-Null;
 
# Create a connection to the server
$SqlConnectionstring = "Data Source=" + $SsisServer + ";Initial Catalog=master;Integrated Security=SSPI;"
$SqlConnection = New-Object System.Data.SqlClient.SqlConnection $SqlConnectionstring
 
# Create the Integration Services object
$IntegrationServices = New-Object $SsisNamespace".IntegrationServices" $SqlConnection
 
# Check if connection succeeded
if (-not $IntegrationServices)
{
    Throw [System.Exception] "Failed to connect to server $SsisServer "
}
else
{
    Write-Host "Connected to server" $SsisServer
}
 
 
#############################
########## CATALOG ##########
#############################
# Create object for SSISDB Catalog
$Catalog = $IntegrationServices.Catalogs["SSISDB"]
 
# Check if the SSISDB Catalog exists
if (-not $Catalog)
{
    # Catalog doesn't exists. Different name used?
    Throw [System.Exception] "SSISDB catalog doesn't exist."
}
else
{
    Write-Host "Catalog SSISDB found"
}
 
 
############################
########## FOLDER ##########
############################
if ($FolderName -ne "")
{
    # Create object to the folder
    $Folder = $Catalog.Folders[$FolderName]
    # Check if folder exists
    if (-not $Folder)
    {
        # Folder doesn't exists, so throw error.
        Write-Host "Folder" $FolderName "not found"
        Throw [System.Exception] "Aborting, folder not found"
    }
    else
    {
        Write-Host "Folder" $FolderName "found"
    }
}
 
 
#############################
########## Project ##########
#############################
if ($ProjectName -ne "" -and $FolderName -ne "")
{
    $Project = $Folder.Projects[$ProjectName]
    # Check if project already exists
    if (-not $Project)
    {
        # Project doesn't exists, so throw error.
        Write-Host "Project" $ProjectName "not found"
        Throw [System.Exception] "Aborting, project not found"
    }
    else
    {
        Write-Host "Project" $ProjectName "found"
    }
}
 
 
##############################
########## DOWNLOAD ##########
##############################
Function DownloadIspac
{
    Param($DownloadFolder, $Project, $CreateSubfolders, $UnzipIspac)
    if ($CreateSubfolders)
    {
        $DownloadFolder = ($DownloadFolder + $Project.Parent.Name)
    }
 
    # Create download folder if it doesn't exist
    New-Item -ItemType Directory -Path $DownloadFolder -Force > $null
 
    # Check if new ispac already exists
    if (Test-Path ($DownloadFolder + $Project.Name + ".ispac"))
    {
        Write-Host ("Downloading [" + $Project.Name + ".ispac" + "] to " + $DownloadFolder + " (Warning: replacing existing file)")
    }
    else
    {
        Write-Host ("Downloading [" + $Project.Name + ".ispac" + "] to " + $DownloadFolder)
    }
 
    # Download ispac
    $ISPAC = $Project.GetProjectBytes()
    [System.IO.File]::WriteAllBytes(($DownloadFolder + "\" + $Project.Name + ".ispac"),$ISPAC)
    if ($UnzipIspac)
    {
        # Add reference to compression namespace
        Add-Type -assembly "system.io.compression.filesystem"
 
        # Extract ispac file to temporary location (.NET Framework 4.5) 
        Write-Host ("Unzipping [" + $Project.Name + ".ispac" + "]")
 
        # Delete unzip folder if it already exists
        if (Test-Path ($DownloadFolder + "\" + $Project.Name))
        {
            [System.IO.Directory]::Delete(($DownloadFolder + "\" + $Project.Name), $true)
        }
 
        # Unzip ispac
        [io.compression.zipfile]::ExtractToDirectory(($DownloadFolder + "\" + $Project.Name + ".ispac"), ($DownloadFolder + "\" + $Project.Name))
 
        # Delete ispac
        Write-Host ("Deleting [" + $Project.Name + ".ispac" + "]")
        [System.IO.File]::Delete(($DownloadFolder + "\" + $Project.Name + ".ispac"))
    }
    Write-Host ""
}
 
 
#############################
########## LOOPING ##########
#############################
# Counter for logging purposes
$ProjectCount = 0
 
# Finding projects to download
if ($FolderName -ne "" -and $ProjectName -ne "")
{
    # We have folder and project
    $ProjectCount++
    DownloadIspac $DownloadFolder $Project $CreateSubfolders $UnzipIspac
}
elseif ($FolderName -ne "" -and $ProjectName -eq "")
{
    # We have folder, but no project => loop projects
    foreach ($Project in $Folder.Projects)
    {
        $ProjectCount++
        DownloadIspac $DownloadFolder $Project $CreateSubfolders $UnzipIspac
    }
}
elseif ($FolderName -eq "" -and $ProjectName -ne "")
{
    # We only have a projectname, so search
    # in all folders
    foreach ($Folder in $Catalog.Folders)
    {
        foreach ($Project in $Folder.Projects)
        {
            if ($Project.Name -eq $ProjectName)
            {
                Write-Host "Project" $ProjectName "found in" $Folder.Name
                $ProjectCount++
                DownloadIspac $DownloadFolder $Project $CreateSubfolders $UnzipIspac
            }
        }
    }
}
else
{
    # Download all projects in all folders
    foreach ($Folder in $Catalog.Folders)
    {
        foreach ($Project in $Folder.Projects)
        {
            $ProjectCount++
            DownloadIspac $DownloadFolder $Project $CreateSubfolders $UnzipIspac
        }
    }
}
 
###########################
########## READY ##########
###########################
# Kill connection to SSIS
$IntegrationServices = $null
Write-Host "Finished, total downloads" $ProjectCount
