# List all powershell profile paths in your existing profile and report on which ones exist
# The first one found technically is the one that should have been processed.

# This is the order which profiles check for existence 
#  and which are processed if found
#   https://technet.microsoft.com/en-us/library/hh847857.aspx
$profprec = @(
    'CurrentUserCurrentHost',
    'CurrentUserAllHosts',
    'AllUsersCurrentHost',
    'AllUsersAllHosts'
)
$profhash = @{}

# Get all the profile paths
($PROFILE | Get-Member -MemberType noteproperty).Name | Foreach {
    $profhash.$_ = $profile.$_
}

$profprec | foreach {
    Write-Host "$_ - " -NoNewline
    if (Test-Path $profhash.$_){
        Write-Host 'Exists!' -ForegroundColor Green
        Write-Host "     $($profhash.$_)"
    }
    else {
        Write-Host 'Not Found!' -ForegroundColor Red
    }
}