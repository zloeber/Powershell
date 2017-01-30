$RetCodeLookup = @{
    0 = 'ERROR_SUCCESS'
    13 = 'ERROR_INVALID_DATA'
    87 = 'ERROR_INVALID_PARAMETER'
    120 = 'ERROR_CALL_NOT_IMPLEMENTED'
    1259 = 'ERROR_APPHELP_BLOCK'
    1601 = 'ERROR_INSTALL_SERVICE_FAILURE'
    1602 = 'ERROR_INSTALL_USEREXIT'
    1603 = 'ERROR_INSTALL_FAILURE'
    1604 = 'ERROR_INSTALL_SUSPEND'
    1605 = 'ERROR_UNKNOWN_PRODUCT'
    1606 = 'ERROR_UNKNOWN_FEATURE'
    1607 = 'ERROR_UNKNOWN_COMPONENT'
    1608 = 'ERROR_UNKNOWN_PROPERTY'
    1609 = 'ERROR_INVALID_HANDLE_STATE'
    1610 = 'ERROR_BAD_CONFIGURATION'
    1611 = 'ERROR_INDEX_ABSENT'
    1612 = 'ERROR_INSTALL_SOURCE_ABSENT'
    1613 = 'ERROR_INSTALL_PACKAGE_VERSION'
    1614 = 'ERROR_PRODUCT_UNINSTALLED'
    1615 = 'ERROR_BAD_QUERY_SYNTAX'
    1616 = 'ERROR_INVALID_FIELD'
    1618 = 'ERROR_INSTALL_ALREADY_RUNNING'
    1619 = 'ERROR_INSTALL_PACKAGE_OPEN_FAILED'
    1620 = 'ERROR_INSTALL_PACKAGE_INVALID'
    1621 = 'ERROR_INSTALL_UI_FAILURE'
    1622 = 'ERROR_INSTALL_LOG_FAILURE'
    1623 = 'ERROR_INSTALL_LANGUAGE_UNSUPPORTED'
    1624 = 'ERROR_INSTALL_TRANSFORM_FAILURE'
    1625 = 'ERROR_INSTALL_PACKAGE_REJECTED'
    1626 = 'ERROR_FUNCTION_NOT_CALLED'
    1627 = 'ERROR_FUNCTION_FAILED'
    1628 = 'ERROR_INVALID_TABLE'
    1629 = 'ERROR_DATATYPE_MISMATCH'
    1630 = 'ERROR_UNSUPPORTED_TYPE'
    1631 = 'ERROR_CREATE_FAILED'
    1632 = 'ERROR_INSTALL_TEMP_UNWRITABLE'
    1633 = 'ERROR_INSTALL_PLATFORM_UNSUPPORTED'
    1634 = 'ERROR_INSTALL_NOTUSED'
    1635 = 'ERROR_PATCH_PACKAGE_OPEN_FAILED'
    1636 = 'ERROR_PATCH_PACKAGE_INVALID'
    1637 = 'ERROR_PATCH_PACKAGE_UNSUPPORTED'
    1638 = 'ERROR_PRODUCT_VERSION'
    1639 = 'ERROR_INVALID_COMMAND_LINE'
    1640 = 'ERROR_INSTALL_REMOTE_DISALLOWED'
    1641 = 'ERROR_SUCCESS_REBOOT_INITIATED'
    1642 = 'ERROR_PATCH_TARGET_NOT_FOUND'
    1643 = 'ERROR_PATCH_PACKAGE_REJECTED'
    1644 = 'ERROR_INSTALL_TRANSFORM_REJECTED'
    1645 = 'ERROR_INSTALL_REMOTE_PROHIBITED'
    1646 = 'ERROR_PATCH_REMOVAL_UNSUPPORTED'
    1647 = 'ERROR_UNKNOWN_PATCH'
    1648 = 'ERROR_PATCH_NO_SEQUENCE'
    1649 = 'ERROR_PATCH_REMOVAL_DISALLOWED'
    1650 = 'ERROR_INVALID_PATCH_XML'
    1651 = 'ERROR_PATCH_MANAGED_ADVERTISED_PRODUCT'
    1652 = 'ERROR_INSTALL_SERVICE_SAFEBOOT'
    1653 = 'ERROR_ROLLBACK_DISABLED'
    1654 = 'ERROR_INSTALL_REJECTED'
    3010 = 'ERROR_SUCCESS_REBOOT_REQUIRED'
}

$Workstations = @('Workstation1','Workstation2','Workstation3','Workstation4')
$Workstations | Foreach {
    Write-Host -ForegroundColor Yellow "Checking For InTune on $($_)..."
    Get-WmiObject -Class Win32_Product  -ComputerName $_ -Filter "Name LIKE '%InTune%'" | Foreach {
        if (-not [string]::IsNullOrEmpty($_.Name)) {
            Write-Host -ForegroundColor Green "    Found $($_.Name)"
            Write-Host -NoNewLine "        Uninstalling...."
            $result = $_.Uninstall()
            if ($Result.ReturnValue -eq 0) {
                Write-Host -Foregroundcolor Green 'Success!'
            }
            else {
                Write-Host -Foregroundcolor Red "Failure ($($RetCodeLookup[$Result.ReturnValue]))"
            }
        }
    }
    Write-Host -ForegroundColor Yellow "Checking For SCOM on $($_)..."
    Get-WmiObject -Class Win32_Product  -ComputerName $_ -Filter "Name LIKE 'System Center 2012 - Operations Manager Agent'" | Foreach {
        if (-not [string]::IsNullOrEmpty($_.Name)) {
            Write-Host -ForegroundColor Green "    Found $($_.Name)"
            Write-Host -NoNewLine "        Uninstalling...."
            $result = $_.Uninstall()
            if ($Result.ReturnValue -eq 0) {
                Write-Host -Foregroundcolor Green 'Success!'
            }
            else {
                Write-Host -Foregroundcolor Red "Failure ($($RetCodeLookup[$Result.ReturnValue]))"
            }
        }
    }
    Write-Host -ForegroundColor Yellow "Checking For MS Policy Platform on $($_)..."
    Get-WmiObject -Class Win32_Product  -ComputerName $_ -Filter "Name='Microsoft Policy Platform'" | Foreach {
        if (-not [string]::IsNullOrEmpty($_.Name)) {
            Write-Host -ForegroundColor Green "    Found $($_.Name)"
            Write-Host -NoNewLine "        Uninstalling...."
            $result = $_.Uninstall()
            if ($Result.ReturnValue -eq 0) {
                Write-Host -Foregroundcolor Green 'Success!'
            }
            else {
                Write-Host -Foregroundcolor Red "Failure ($($RetCodeLookup[$Result.ReturnValue]))"
            }
        }
    }    
}
