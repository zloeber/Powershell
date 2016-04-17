$servers = get-content 'C:\servers.txt'

$servers | %{
$snaps = get-content \\$_\C$\windows\system32\drivers\etc\hosts
foreach ($line in $snaps)
    {

        if ($line.StartsWith("#"))
        {

        }
        else
        {
            $snapObject = new-object system.Management.Automation.PSObject
            $snapObject | add-member -membertype noteproperty -name "Host Entries" -value $($line)
            $snapObject | add-member -membertype noteproperty -name "Server" -value $($_)
            $snapObjects += $snapObject
        }
}
}
$snapobjects