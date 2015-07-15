Function Get-WindowsProduct {
param ($Targets = [System.Net.Dns]::GetHostName())

function PIDDecoderFromRegistry($digitalProductId) {
New-Variable -Name base24 -Value 'BCDFGHJKMPQRTVWXY2346789' -Option Const
New-Variable -Name cryptedStringLength -Value 24 -Option Const
New-Variable -Name decryptionLength -Value 14 -Option Const
New-Variable -Name decryptedKey -Value ([System.String]::Empty)

$containsN = ($digitalProductId[$decryptionLength] -shr 3) -bAnd 1
$digitalProductId[$decryptionLength] = [System.Byte]($digitalProductId[$decryptionLength] -bAnd 0xF7)
for ($i = $cryptedStringLength; $i -ge 0; $i--)
{
$digitMapIndex = 0
for ($j = $decryptionLength; $j -ge 0; $j--)
{
$digitMapIndex = [System.Int16]($digitMapIndex -shl 8 -bXor $digitalProductId[$j])
$digitalProductId[$j] = [System.Byte][System.Math]::Floor($digitMapIndex / $base24.Length)
$digitMapIndex = [System.Int16]($digitMapIndex % $base24.Length)
}
$decryptedKey = $decryptedKey.Insert(0, $base24[$digitMapIndex])
}
if ([System.Boolean]$containsN)
{
$firstCharIndex = 0
for ($index = 0; $index -lt $cryptedStringLength; $index++)
{
if ($decryptedKey[0] -ne $base24[$index]) {continue}
$firstCharIndex = $index
break
}
$keyWithN = $decryptedKey
$keyWithN = $keyWithN.Remove(0, 1)
$keyWithN = $keyWithN.Substring(0, $firstCharIndex) + 'N' + $keyWithN.Remove(0, $firstCharIndex)
$decryptedKey = $keyWithN;
}
$returnValue = $decryptedKey
for ($t = 20; $t -ge 5; $t -= 5)
{
$returnValue = $returnValue.Insert($t, '-')
}
Return $returnValue
}
## Main
New-Variable -Name hklm -Value 2147483650 -Option Const
New-Variable -Name regPath -Value 'Software\Microsoft\Windows NT\CurrentVersion' -Option Const
New-Variable -Name regValue -Value 'DigitalProductId' -Option Const
Foreach ($target in $Targets) {
$win32os = $null
$wmi = [WMIClass]"\\$target\root\default:stdRegProv"
$binArray = $wmi.GetBinaryValue($hklm,$regPath,$regValue).uValue[52..66]
$win32os = Get-WmiObject -Class 'Win32_OperatingSystem' -ComputerName $target
$product = New-Object -TypeName System.Object
$product | Add-Member -MemberType 'NoteProperty' -Name 'Computer' -Value $target
$product | Add-Member -MemberType 'NoteProperty' -Name 'Caption' -Value $win32os.Caption
$product | Add-Member -MemberType 'NoteProperty' -Name 'CSDVersion' -Value $win32os.CSDVersion
$product | Add-Member -MemberType 'NoteProperty' -Name 'OSArch' -Value $win32os.OSArchitecture
$product | Add-Member -MemberType 'NoteProperty' -Name 'BuildNumber' -Value $win32os.BuildNumber
$product | Add-Member -MemberType 'NoteProperty' -Name 'RegisteredTo' -Value $win32os.RegisteredUser
$product | Add-Member -MemberType 'NoteProperty' -Name 'ProductID' -Value $win32os.SerialNumber
$product | Add-Member -MemberType 'NoteProperty' -Name 'ProductKey' -Value (PIDDecoderFromRegistry($binArray))
Write-Output $product
}
} ## End Get-WindowsProduct