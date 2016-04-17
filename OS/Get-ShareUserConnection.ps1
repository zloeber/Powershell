function get-ShareUserConnection {
    <# .SYNOPSIS Get the current users that are connected to shares on a server .DESCRIPTION Get the current users that are connected to shares on a server. This can be filtered to a specific share. .NOTES Function Name : get-shareConnection Author : Adam Stone Requires : PowerShell V2 .LINK http://adadmin.blogspot.com .EXAMPLE Simple usage - get all connections for all shares on server1 PS C:\> get-shareConnection -server Server1
    .EXAMPLE 
    Simple usage - get all connections for the users share on server1
    PS C:\> get-shareConnection -server Server1 -sharename users
    .EXAMPLE 
    Simple usage - get all connections for the users share on server1 (using positional parameters)
    PS C:\>; get-shareConnection Server1 users
    .PARAMETER server 
    The servername to connect to.
    .PARAMETER sharename 
    optional sharename to return users connected to this share
    #>

    param ( 
        [Parameter(HelpMessage="Server name")] 
        [string] $Server = 'localhost',
        [Parameter(Position=1,Mandatory=$false)] 
        [alias("share")]
        [string] $sharename = 'all'
    ) 
    $serverconnection = Get-WmiObject -ComputerName $Server -Class Win32_SessionConnection

    $users = @()
    foreach ($connection in $serverconnection){
        $conn = "" | select "ip","user","share"
        $split = $connection.Dependent.split(",")
        $conn.ip = $split[0].replace("Win32_ServerConnection.computername=","").replace('"','')
        $conn.user = $split[2].replace("UserName=","").replace('"','')
        $conn.share = $split[1].replace("sharename=","").replace('"','')
        if ($sharename -eq "all") {
            $users += $conn
        }
        elseif ($conn.share -eq $sharename){
            $users += $conn
        }
    }
    
    return $users
}