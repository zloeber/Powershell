# This forces the powershellget module to start using the online repo instead of its own locally installed version.
Remove-Module Powershellget -ErrorAction:SilentlyContinue
Remove-Module PackageManagement -ErrorAction:SilentlyContinue
install-module powershellget -force
install-module PackageManagement -force