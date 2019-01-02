$msilink= 'https://github.com/PowerShell/PowerShell/releases/download/v6.1.1/PowerShell-6.1.1-win-x86.msi'
$msifile= 'c:\PowerShell-6.1.1-win-x86.msi' 
$arguments= '' 

$client = New-Object System.Net.WebClient
$client.DownloadFile($link, $msifile)

Start-Process `
     -file  $msifile `
     -arg $arguments `
     -passthru | wait-process