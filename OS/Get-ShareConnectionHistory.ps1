$datastore = 'c:\temp\shareusage.csv'

function Get-ShareConnection {
    <#
    .Synopsis
       Query share connection numbers
    .DESCRIPTION
       Returns the number of connections to Shares on local or remote systems
    .EXAMPLE
       Get-ShareConnection -ComputerName Server1,Server2
    .EXAMPLE
       Get-ShareConnection -CN Localhost
    .INPUTS
       A String or Array of ComputerNames
    .OUTPUTS
       An OBJECT with the following properties is returned from this function
       ComputerName,Share(Name),Connections(number)
    .NOTES
       General
    .FUNCTIONALITY
       Using WMI to query the number of open connections to Shares on local or remote systems
    #>
    Param (
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false)]
        [Alias("cn")]
        [String[]]$ComputerName
    )

    Begin {
        $rundate = Get-Date
    }
    Process {
        $ComputerName | ForEach-Object {
            $Computer = $_
            try {
                $ShareHash = @{}
                Get-WmiObject Win32_Share | Foreach  { $ShareHash.($_.Name) = 0 }
                $ConnectionCount = Get-WmiObject -Class Win32_ConnectionShare -Namespace root\cimv2 -ComputerName $Computer -EA Stop | 
                Group-Object Antecedent | Foreach {
                    $ShareHash.((($_.Name -split "=") | Select-Object -Index 1).trim('"')) = $_.Count
                }
                $ShareHash.Keys | Foreach {
                    New-Object PSObject -Property @{
                        'Time' = $rundate
                        'ComputerName' = $Computer
                        'Share' = $_
                        'Connections' = $ShareHash.$_
                    }
                }
            }
            catch {
                Write-Host "Cannot connect to $Computer" -BackgroundColor White -ForegroundColor Red
            }
        }
    }
}

if (Test-Path $datastore) {
    $usage = @(Import-csv $datastore)
}
else {
    $usage = @()
}
$newusage = @(Get-ShareConnection localhost)
$usage += $newusage
$usage | export-csv -notypeinformation $datastore