# Use an old function I wrote with the ActiveDirectory Module to get a report of all domain computer
# local administrator group members.

Function Get-RemoteGroupMembership {
    <#
    .SYNOPSIS
       Gather list of all assigned users in all local groups on a computer.  
    .DESCRIPTION
       Gather list of all assigned users in all local groups on a computer.  
    .PARAMETER ComputerName
       Specifies the target computer for data query.
    .PARAMETER IncludeEmptyGroups
       Include local groups without any user membership.
    .PARAMETER ThrottleLimit
       Specifies the maximum number of systems to inventory simultaneously 
    .PARAMETER Timeout
       Specifies the maximum time in second command can run in background before terminating this thread.
    .PARAMETER ShowProgress
       Show progress bar information

    .EXAMPLE
       PS > (Get-RemoteGroupMembership -verbose).GroupMembership

       <output>
       
       Description
       -----------
       List all group membership of the local machine.

    .NOTES
       Author: Zachary Loeber
       Site: http://www.the-little-things.net/
       Requires: Powershell 2.0

       Version History
       1.0.0 - 09/09/2013
        - Initial release
    #>
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage="Computer or computers to gather information from", ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [Alias('DNSHostName','PSComputerName')]
        [string[]]$ComputerName=$env:computername,

        [Parameter(HelpMessage="Name of group to return members for.", Position=1)]
        [string]$GroupName = '*',
        
        [Parameter(HelpMessage="Include empty groups in results")]
        [switch]$IncludeEmptyGroups,
       
        [Parameter(HelpMessage="Maximum number of concurrent threads")]
        [ValidateRange(1,65535)]
        [int32]$ThrottleLimit = 32,
 
        [Parameter(HelpMessage="Timeout before a thread stops trying to gather the information")]
        [ValidateRange(1,65535)]
        [int32]$Timeout = 120,
 
        [Parameter(HelpMessage="Display progress of function")]
        [switch]$ShowProgress,
        
        [Parameter(HelpMessage="Set this if you want the function to prompt for alternate credentials")]
        [switch]$PromptForCredential,
        
        [Parameter(HelpMessage="Set this if you want to provide your own alternate credentials")]
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    Begin {
        # Gather possible local host names and IPs to prevent credential utilization in some cases
        Write-Verbose -Message 'Local Group Membership: Creating local hostname list'
        $IPAddresses = [net.dns]::GetHostAddresses($env:COMPUTERNAME) | Select-Object -ExpandProperty IpAddressToString
        $HostNames = $IPAddresses | ForEach-Object {
            try {
                [net.dns]::GetHostByAddress($_)
            } catch {
                # We do not care about errors here...
            }
        } | Select-Object -ExpandProperty HostName -Unique
        $LocalHost = @('', '.', 'localhost', $env:COMPUTERNAME, '::1', '127.0.0.1') + $IPAddresses + $HostNames
 
        Write-Verbose -Message 'Local Group Membership: Creating initial variables'
        $runspacetimers       = [HashTable]::Synchronized(@{})
        $runspaces            = New-Object -TypeName System.Collections.ArrayList
        $bgRunspaceCounter    = 0
        
        if ($PromptForCredential) {
            $Credential = Get-Credential
        }
        
        Write-Verbose -Message 'Local Group Membership: Creating Initial Session State'
        $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        foreach ($ExternalVariable in ('runspacetimers', 'Credential', 'LocalHost')) {
            Write-Verbose -Message "Local Group Membership: Adding variable $ExternalVariable to initial session state"
            $iss.Variables.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $ExternalVariable, (Get-Variable -Name $ExternalVariable -ValueOnly), ''))
        }
        
        Write-Verbose -Message 'Local Group Membership: Creating runspace pool'
        $rp = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $ThrottleLimit, $iss, $Host)
        $rp.ApartmentState = 'STA'
        $rp.Open()
 
        # This is the actual code called for each computer
        Write-Verbose -Message 'Local Group Membership: Defining background runspaces scriptblock'
        $ScriptBlock = {
            [CmdletBinding()]
            param (
                [Parameter(Position=0)]
                [string]$ComputerName,
                [Parameter(Position=1)]
                [int]$bgRunspaceID,
                [Parameter(Position=2)]
                [switch]$IncludeEmptyGroups,
                [Parameter(Position=3)]
                [string]$GroupName
            )
            $runspacetimers.$bgRunspaceID = Get-Date
            
            try {
                Write-Verbose -Message ('Local Group Membership: Runspace {0}: Start' -f $ComputerName)
                $WMIHast = @{
                    ComputerName = $ComputerName
                    ErrorAction = 'Stop'
                }
                if (($LocalHost -notcontains $ComputerName) -and ($Credential -ne $null)) {
                    $WMIHast.Credential = $Credential
                }

                # General variables
                $GroupMembership = @()
                $PSDateTime = Get-Date
                
                #region Group Information
                Write-Verbose -Message ('Local Group Membership: Runspace {0}: Group memberhsip information' -f $ComputerName)

                # Modify this variable to change your default set of display properties
                $defaultProperties    = @('ComputerName','GroupMembership')
                $wmi_groups = Get-WmiObject @WMIHast -Class win32_group -filter "Domain = '$ComputerName'"
                if (-not [string]::IsNullOrEmpty($GroupName)) {
                    $wmi_groups = $wmi_groups | Where {$_.Name -like $GroupName}
                }
                foreach ($group in $wmi_groups) {
                    $Query = "SELECT * FROM Win32_GroupUser WHERE GroupComponent = `"Win32_Group.Domain='$ComputerName',Name='$($group.name)'`""
                    $wmi_users = Get-WmiObject @WMIHast -query $Query
                    if (($wmi_users -eq $null) -and ($IncludeEmptyGroups)) {
                        $MembershipProperty = @{
                            'Group' = $group.Name
                            'GroupMember' = ''
                            'MemberType' = ''
                        }
                        $GroupMembership += New-Object PSObject -Property $MembershipProperty
                    }
                    else {
                        foreach ($user in $wmi_users.partcomponent) {
                            if ($user -match 'Win32_UserAccount') {
                                $Type = 'User Account'
                            }
                            elseif ($user -match 'Win32_Group') {
                                $Type = 'Group'
                            }
                            elseif ($user -match 'Win32_SystemAccount') {
                                $Type = 'System Account'
                            }
                            else {
                                $Type = 'Other'
                            }
                            $MembershipProperty = @{
                                'Group' = $group.Name
                                'GroupMember' = ($user.replace("Domain="," , ").replace(",Name=","\").replace("\\",",").replace('"','').split(","))[2]
                                'MemberType' = $Type
                            }
                            $GroupMembership += New-Object PSObject -Property $MembershipProperty
                        }
                    }
                }
                
                $ResultProperty = @{
                    'PSComputerName' = $ComputerName
                    'PSDateTime' = $PSDateTime
                    'ComputerName' = $ComputerName
                    'GroupMembership' = $GroupMembership
                }
                $ResultObject = New-Object -TypeName PSObject -Property $ResultProperty
                
                # Setup the default properties for output
                $ResultObject.PSObject.TypeNames.Insert(0,'My.GroupMembership.Info')
                $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet',[string[]]$defaultProperties)
                $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
                $ResultObject | Add-Member MemberSet PSStandardMembers $PSStandardMembers
                Write-Output -InputObject $ResultObject
                #endregion Group Information
            }
            catch {
                Write-Warning -Message ('Local Group Membership: {0}: {1}' -f $ComputerName, $_.Exception.Message)
            }
            Write-Verbose -Message ('Local Group Membership: Runspace {0}: End' -f $ComputerName)
        }
 
        Function Get-Result {
            [CmdletBinding()]
            Param (
                [switch]$Wait
            )
            do {
                $More = $false
                foreach ($runspace in $runspaces) {
                    $StartTime = $runspacetimers[$runspace.ID]
                    if ($runspace.Handle.isCompleted) {
                        Write-Verbose -Message ('Local Group Membership: Thread done for {0}' -f $runspace.IObject)
                        $runspace.PowerShell.EndInvoke($runspace.Handle)
                        $runspace.PowerShell.Dispose()
                        $runspace.PowerShell = $null
                        $runspace.Handle = $null
                    }
                    elseif ($runspace.Handle -ne $null) {
                        $More = $true
                    }
                    if ($Timeout -and $StartTime) {
                        if ((New-TimeSpan -Start $StartTime).TotalSeconds -ge $Timeout -and $runspace.PowerShell) {
                            Write-Warning -Message ('Timeout {0}' -f $runspace.IObject)
                            $runspace.PowerShell.Dispose()
                            $runspace.PowerShell = $null
                            $runspace.Handle = $null
                        }
                    }
                }
                if ($More -and $PSBoundParameters['Wait']) {
                    Start-Sleep -Milliseconds 100
                }
                foreach ($threat in $runspaces.Clone()) {
                    if ( -not $threat.handle) {
                        Write-Verbose -Message ('Local Group Membership: Removing {0} from runspaces' -f $threat.IObject)
                        $runspaces.Remove($threat)
                    }
                }
                if ($ShowProgress) {
                    $ProgressSplatting = @{
                        Activity = 'Local Group Membership: Getting info'
                        Status = 'Local Group Membership: {0} of {1} total threads done' -f ($bgRunspaceCounter - $runspaces.Count), $bgRunspaceCounter
                        PercentComplete = ($bgRunspaceCounter - $runspaces.Count) / $bgRunspaceCounter * 100
                    }
                    Write-Progress @ProgressSplatting
                }
            }
            while ($More -and $PSBoundParameters['Wait'])
        }
    }
    process {
        foreach ($Computer in $ComputerName) {
            $bgRunspaceCounter++
            $psCMD = [System.Management.Automation.PowerShell]::Create().AddScript($ScriptBlock)
            $null = $psCMD.AddParameter('ComputerName',$Computer)
            $null = $psCMD.AddParameter('bgRunspaceID',$bgRunspaceCounter)
            $null = $psCMD.AddParameter('IncludeEmptyGroups',$IncludeEmptyGroups)
            $null = $psCMD.AddParameter('GroupName',$GroupName)
            $null = $psCMD.AddParameter('Verbose',$VerbosePreference)
            $psCMD.RunspacePool = $rp
 
            Write-Verbose -Message ('Local Group Membership: Starting {0}' -f $Computer)
            
            [void]$runspaces.Add(@{
                Handle = $psCMD.BeginInvoke()
                PowerShell = $psCMD
                IObject = $Computer
                ID = $bgRunspaceCounter
           })
           Get-Result
        }
    }
     END {
        Get-Result -Wait
        if ($ShowProgress) {
            Write-Progress -Activity 'Local Group Membership: Getting local group information' -Status 'Done' -Completed
        }
        Write-Verbose -Message "Local Group Membership: Closing runspace pool"
        $rp.Close()
        $rp.Dispose()
    }
}

Import-Module ActiveDirectory

$ActiveHosts = @()
Get-ADComputer -Filter * | Foreach {
    if (Test-Connection -ComputerName $_.DNSHostName  -Count 1 -Quiet) {
        $ActiveHosts += $_.Name
    }
}

$Groups = Get-RemoteGroupMembership -ComputerName $ActiveHosts -GroupName 'Admin*'

$b = $Groups | Where {$_.GroupMembership} | Foreach {
    $Computer = $_.ComputerName
    $a = $_.GroupMembership | Select *
    $a | Add-Member -MemberType:NoteProperty -Name 'ComputerName' -Value $Computer
    $a
}

$b
