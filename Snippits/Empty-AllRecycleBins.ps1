Get-PSProvider -PSProvider FileSystem `
| select -expand drives `
| ?{$_.DisplayRoot -notlike "\\*"} `
| select -expand root `
| %{Get-ChildItem "$_`$Recycle.bin\" -Recurse -Force | Remove-Item -force -Confirm:$false -Recurse -ErrorAction:SilentlyContinue}