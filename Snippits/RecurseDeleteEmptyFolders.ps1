
$Directory = 'C:\temp'
do {
    $DeletedCount = 0
    Get-ChildItem $Directory -Recurse -Directory | Foreach-Object {
        if ( (Get-ChildItem $_.fullname -recurse | Measure-Object | Select-Object -expand count ) -eq 0  ){
            $DeletedCount++
            Write-Host "Removing empty directory: $($_.FullName)"
            Remove-Item $_.fullname -Force
        }  
    }
} until ($DeletedCount -eq 0)
