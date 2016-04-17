do {
    $url = "http://checkip.dyndns.com"  
    $webclient = New-Object System.Net.WebClient 
    $Ip = $webclient.DownloadString($url) 
    $IP = ($Ip.ToString()).Split(" ")
    $IP = $IP[5]
    $IP = ($IP.replace("</body>","")).replace("</html>","")
    $IP
    #$ip3 = $Ip2.Split(" ") 
    #$ip4 = $ip3[5]
    #$ip5 = $ip4.replace("</body>","") 
    #$FinalIPAddress = $ip5.replace("</html>","") 

    #Write Ip Addres to the console 
   # $FinalIPAddress
    sleep -Seconds 3
} while ($true)