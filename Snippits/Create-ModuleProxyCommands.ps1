# Creates proxy function files for every cmdlet in a module.
Function Create-ProxyFunctionsForModule {
    param (
        [string]$Module
    )
    Import-Module $Module

    Foreach ($Command in (Get-Command -Module $Module)) {
        $Metadata = New-Object System.Management.Automation.CommandMetaData $Command
        [System.Management.Automation.ProxyCommand]::Create($Metadata) | Out-File "$($Command.Name)_proxy.ps1"
    }
}

Function Get-AllParametersForModule {
    param (
        [string]$Module
    )
    Import-Module $Module
    $IgnoredParams = @('Verbose','Debug','ErrorAction','WarningAction','ErrorVariable','WarningVariable','OutVariable','OutBuffer','PipelineVariable','WhatIf','Confirm','PassThru')
    Foreach ($Command in (Get-Command -Module $Module)) {
        $ParamOutput =  @{
            Command = $Command.Name
            DefaultParameterSet = $Command.DefaultParameterSet
        }
        Foreach ($Param in ($Command.ParameterSets.Parameters | Where-Object {$IgnoredParams -notcontains $_.Name})) {
                $ParamOutput.Name = $Param.Name
                $ParamOutput.Type = $Param.ParameterType
                $ParamOutput.Mandatory = $Param.IsMandatory
                $ParamOutput.Position = $Param.Position
                $ParamOutput.ValueFromPipeline = $Param.ValueFromPipeline
                $ParamOutput.ValueFromPipelineByPropertyName = $Param.ValueFromPipelineByPropertyName
                $ParamOutput.ValueFromRemainingArguments = $Param.ValueFromRemainingArguments

                New-Object psobject -Property $ParamOutput
        }
    }
}

