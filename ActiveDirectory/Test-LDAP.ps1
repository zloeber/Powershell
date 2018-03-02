function Test-LDAP {
    <#
    .SYNOPSIS
    Test LDAP binding of one or more remote systems.
    
    .DESCRIPTION
    Test LDAP binding of one or more remote systems.
    
    .PARAMETER ComputerName
    Computer to test network port against.
    
    .PARAMETER Filter
    Filter to attempt to test binding for.

    .PARAMETER Scope
    AD scope.
  
    .EXAMPLE
    Test-LDAP -ComputerName DC1 -Verbose

    Description
    -----------
    Test LDAP bind against DC1, be verbose about what it is doing, show the default results.
    
    .LINK
    http://the-little-things.net/
 
    .NOTES
    Author:  Zachary Loeber
    Created: 07/07/2014
    #>
    [CmdLetBinding(DefaultParameterSetName='AsString')]
    param(
        [Parameter(ParameterSetName='AsStringArray', Mandatory=$True, ValueFromPipeline=$True, Position=0, HelpMessage='Server to attempt to bind to.')]
        [string[]]$ComputerNames,
        [Parameter(ParameterSetName='AsString', Mandatory=$True, ValueFromPipeline=$True, Position=0, HelpMessage='Server to attempt to bind to.')]
        [string]$ComputerName,
        [Parameter(HelpMessage='Filter to attempt to test binding for.')]
        [string]$Filter = '(cn=krbtgt)',
        [Parameter(HelpMessage='AD scope (default is Subtree).')]
        [ValidateSet("Base","Subtree","OneLevel")]
        [string]$Scope = 'Subtree'
    )
    begin {
        Write-Verbose "$($MyInvocation.MyCommand): Begin"
        $Servers = @()
    }
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'AsStringArray' {
                $Servers = @($ComputerNames)
            }
            'AsString' {
                $Servers = @($ComputerName)
            }
        }
        $Servers | Foreach {
            $domain = 'LDAP://' + $_
            $root = New-Object DirectoryServices.DirectoryEntry $domain
            $searcher = New-Object DirectoryServices.DirectorySearcher
            $searcher.SearchRoot = $root
            $searcher.PageSize = 1
            $searcher.Filter = $Filter
            $result = @{
                'ComputerName' = $_
                'Connected' = $false
                'Exception' = $null
            }
            try {
                Write-Verbose ('$($MyInvocation.MyCommand): Trying to LDAP bind - {0}' -f $server)
                $adObjects = $searcher.FindOne()
                Write-Verbose ('$($MyInvocation.MyCommand): LDAP Server {0} is up (object path = {1})' -f $server, $adObjects.Item(0).Path)
                $result.Connected = $true
            }
            catch {}
            
            New-Object psobject -Property $result
        }
    }
    end {
        Write-Verbose "$($MyInvocation.MyCommand): End"
    }
}
