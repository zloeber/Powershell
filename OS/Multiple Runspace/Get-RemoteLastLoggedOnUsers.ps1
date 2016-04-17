Function Get-LastLoggedOnUser {
    Param (
        [Parameter(
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias('ComputerName')]
        [String[]]
        $Name = $env:COMPUTERNAME
    )

    Begin {}

    Process {
        foreach ($n in $Name) {
            Get-WmiObject -Class Win32_UserProfile -Namespace 'root\CimV2' -ComputerName $n -ErrorAction Stop | Sort-Object -Property LastUseTime | ForEach-Object {
                if (-not ($_.Special)) {
                    [PSCustomObject]@{
                        UserName = ([System.Security.Principal.SecurityIdentifier]$_.SID).Translate([System.Security.Principal.NTAccount]).Value
                        LastLoggedOnTimeStamp = $_.ConvertToDateTime($_.LastUseTime)
                        CurrentlyLoggedOn = $_.Loaded
                    }
                }
            } #| Select-Object -Last 1
        }
    }

    End {}
}