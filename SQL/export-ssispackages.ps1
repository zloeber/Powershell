[CmdletBinding()] 
param( 
	[Parameter(Position=0)]
	[string]$SQLInstance = "localhost",
	[Parameter(Position=1)]
	[string]$OutputDir = 'Y:\SSISPackages',
	[Parameter(Position=2)]
	[switch]$SQL2005
	
)

add-pssnapin sqlserverprovidersnapin100 -ErrorAction SilentlyContinue
add-pssnapin sqlservercmdletsnapin100 -ErrorAction SilentlyContinue

if ($SQL2005) {
$Packages =  @(Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query "WITH cte AS (
          SELECT    cast(foldername as varchar(max)) as folderpath, folderid
          FROM    msdb..sysdtspackagefolders90
          WHERE    parentfolderid IS NULL
          UNION    ALL
          SELECT    cast(c.folderpath + '\' + f.foldername  as varchar(max)), f.folderid
          FROM    msdb..sysdtspackagefolders90  f
          INNER    JOIN cte c        ON    c.folderid = f.parentfolderid
      )
      SELECT    c.folderpath,p.name,CAST(CAST(packagedata AS VARBINARY(MAX)) AS VARCHAR(MAX)) as pkg
      FROM    cte c
      INNER    JOIN msdb..sysdtspackages90  p    ON    c.folderid = p.folderid
      WHERE    c.folderpath NOT LIKE 'Data Collector%'")
}

else {
$Packages =  @(Invoke-Sqlcmd -MaxCharLength 10000000 -ServerInstance $SQLInstance -Query "WITH cte AS (
	SELECT    cast(foldername as varchar(max)) as folderpath, folderid
	FROM    msdb..sysssispackagefolders
	WHERE    parentfolderid = '00000000-0000-0000-0000-000000000000'
	UNION    ALL
	SELECT    cast(c.folderpath + '\' + f.foldername  as varchar(max)), f.folderid
	FROM    msdb..sysssispackagefolders f
	INNER    JOIN cte c        ON    c.folderid = f.parentfolderid
)
SELECT    c.folderpath,p.name,CAST(CAST(packagedata AS VARBINARY(MAX)) AS VARCHAR(MAX)) as pkg
FROM    cte c
INNER    JOIN msdb..sysssispackages p    ON    c.folderid = p.folderid
WHERE    c.folderpath NOT LIKE 'Data Collector%'")
}  

if ($Packages.Count -gt 0) {
    if(-not (test-path -path "$($OutputDir)\$($SQLInstance)")) {
        mkdir "$($OutputDir)\$($SQLInstance)" | Out-Null
    }

    Foreach ($pkg in $Packages) {
        $pkgName = $Pkg.name
        $folderPath = $Pkg.folderpath
        $fullfolderPath = "$($OutputDir)\$($SQLInstance)\$($folderPath)\"
        if(-not (test-path -path $fullfolderPath)) {
            mkdir $fullfolderPath | Out-Null
        }
        $pkg.pkg | Out-File -Force -encoding ascii -FilePath "$fullfolderPath\$pkgName.dtsx"
    }
}
else {
    Write-Output 'No packages found!'
}
