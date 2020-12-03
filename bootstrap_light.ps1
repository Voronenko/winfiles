function Verify-Elevated {
    # Get the ID and security principal of the current user account
    $myIdentity=[System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myPrincipal=new-object System.Security.Principal.WindowsPrincipal($myIdentity)
    # Check to see if we are currently running "as Administrator"
    return $myPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Refresh-Environment {
    $locations = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
                 'HKCU:\Environment'

    $locations | ForEach-Object {
        $k = Get-Item $_
        $k.GetValueNames() | ForEach-Object {
            $name  = $_
            $value = $k.GetValue($_)
            Set-Item -Path Env:\$name -Value $value
        }
    }

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

if (!(Verify-Elevated)) {
   $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
   $newProcess.Arguments = $myInvocation.MyCommand.Definition;
   $newProcess.Verb = "runas";
   [System.Diagnostics.Process]::Start($newProcess);

   exit
}

iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

Write-Host "Refreshing environment" -ForegroundColor "Yellow"

Refresh-Environment

choco feature enable -n=allowGlobalConfirmation

#Write-Host "Choco installing main components" -ForegroundColor "Yellow"

#choco install git.install

#Write-Host "Refreshing environment for git with Pause" -ForegroundColor "Yellow"

#Start-Sleep -seconds 10

#Refresh-Environment

#Write-Host "Cloning winfiles..." -ForegroundColor "Yellow"

#If (Test-Path c:\batch\winfiles\) {
#    Write-Host "repo c:\batch\winfiles\ already exists" -ForegroundColor "Yellow"
#    cd c:\batch\winfiles\
#    git pull
#}
#Else {
#    Write-Host "git clone https://github.com/Voronenko/winfiles.git c:\batch\winfiles\" -ForegroundColor "Yellow"
#    git clone https://github.com/Voronenko/winfiles.git c:\batch\winfiles\
#}

# todo: detect if gui present

choco install far

# Extra

$reply = Read-Host -Prompt "Configure for ansible winrm ? [y/n]"
if ( $reply -match "[yY]" ) { 
    iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/Voronenko/winfiles/master/setup/ConfigureRemotingForAnsible.ps1'))
}

# For older windows like 2012 nope...
#$reply = Read-Host -Prompt "Configure for winrm over ssh (installs OpenSSH server software and upgrades powershell to 6.0.x) ? [y/n]"
#if ( $reply -match "[yY]" ) {
#    iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/Voronenko/winfiles/master/setup/GetPowershell6LinuxRemoting.ps1'))
#}

