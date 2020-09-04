winfiles
========

My windows environment. Multi-phase install with optional steps.
It is recommended to install under admin powershell
(in other case will activate admin mode, but via subprocess launch in popup)

So, to recap,

# If it is remote box, but you have initial ps shell

```ps
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy Bypass -Scope Process -Force;
iex ((New-Object System.Net.WebClient).DownloadString('https://bit.ly/winfiles'))

```

`https://bit.ly/winfiles` -> `https://raw.githubusercontent.com/Voronenko/winfiles/master/bootstrap.ps1`

Then proceed usually or unusually using cloned repo in `c:\batch\winfiles`


# Some facts on your box

Installed powershell version

```ps
$PSVersionTable.PSVersion
````

Get box network addresses

```ps

(Get-NetIPAddress).IPAddress

```

# init.ps1

the `./init.ps1` script will:

* Back up any existing winfiles in your powershell directory to ~/winfiles_old/
* Create symlinks to the ps1 in ~/winfiles/ in your powershell directory

# windows.ps1

For new windows box

`./setup/windows.ps1` will configure box for privacy

Please review quickly before run to see if it matches your expectations

# software.ps1

For new windows box

`./setup/software.ps1` will install necessary s/w development software

* Will update help
* Powershell modules: `Posh-Git` , `PSWindowsUpdate`
* Chocolatey (via Package Provider or classic `https://chocolatey.org/install.ps1` (default))
* System and cli (`curl`, `nuget.commandline`, `webpi`, `git`, `nvm.portable`, `ruby`)
* Additional Browsers (`GoogleChrome`) - more optionals commented out
* Dev tools and frameworks (`atom`, `vscode`, `Fiddler4`, `winmerge` )
* Activate nvm (+ npm gulp node-inspector yarn)
* Install Python 2.7.9
* Configure host for ASP.NET development

# Configuring for ansible remote provisioning

ConfigureRemotingForAnsible.ps1 , example:

`powershell.exe -File ConfigureRemotingForAnsible.ps1 -SkipNetworkProfileCheck  -EnableCredSSP -CertValidityDays 3650`

or

```ps
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://bit.ly/ansible_remoting'))

```

or

```ps
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/Voronenko/winfiles/master/setup/ConfigureRemotingForAnsible.ps1'))

```

Depending on a software you will be installing with choco, on some rare situations you might also face

Depending on your OS, you might also face

https://support.microsoft.com/en-us/help/2842230/out-of-memory-error-on-a-computer-that-has-a-customized-maxmemorypersh

also you might face limit  https://github.com/ansible/ansible/issues/39327

which can be changed with additional override

```ps1
# 2048 4096 8192 this is the max mem in MB
Set-Item -Path WSMan:\localhost\Shell\MaxMemoryPerShellMB -Value 2048
Restart-Service -Name WinRM
```


# Confirming, that ansible setup is ready

Dependency - python pywinrm package
```
pip install pywinrm
```

hostsfile can be kind of
```
[win]
192.168.2.145

[win:vars]
ansible_user=vagrant
ansible_password=password
ansible_connection=winrm
ansible_winrm_server_cert_validation=ignore
```

```
ansible windows -i hosts -m win_ping


192.168.2.145 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}

```


# Getting connection from linux up - option A - using powershell over ssh transport

If for whatever reasons you want to connect interactively from linux box, things get more complicated.

So  you need to install Powershell 6.x on remote server together with OpenSSHServer using `setup/GetPowershell6LinuxRemoting.ps1`

than you need also to install Powershell 6.x for ubuntu

```
## Download the Microsoft repository GPG keys
wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb

## Register the Microsoft repository GPG keys
sudo dpkg -i packages-microsoft-prod.deb

## Update the list of products
sudo apt-get update

## Install PowerShell
sudo apt-get install -y powershell

## Start PowerShell
pwsh
```

If you configured everything right, you should be able to invoke:

```
$session = New-PSSession -HostName 192.168.2.145 -UserName Administrator


 $session
 Id Name            Transport ComputerName    ComputerType    State         Con
                                                                            fig
                                                                            ura
                                                                            tio
                                                                            nNa
                                                                            me
 -- ----            --------- ------------    ------------    -----         ---
  2 Runspace1       SSH       192.168.2.145   RemoteMachine   Opened        Def


PS /home/slavko> Enter-PSSession $session
[Administrator@192.168.2.145]: PS C:\Users\Administrator\Documents>

Mode                LastWriteTime         Length Name
----                -------------         ------ ----
d-----         1/2/2019   6:51 AM                WindowsPowerShell

```

But if you do not need to use some specific powershell functionality,
you also can do smth as simple as

`ssh administrator@192.168.2.145`


# Getting connection from linux up - option B - using embedded SSH server

```ps1

Get-WindowsCapability -Online | ? Name -like 'OpenSSH*'

Name  : OpenSSH.Client~~~~0.0.1.0
State : Installed

Name  : OpenSSH.Server~~~~0.0.1.0
State : NotPresent
```

If server component is not installed - let's install it

```ps1
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```

Once added start SSH server (as a Windows Service) and check if it's running.

```ps1
Start-Service sshd
Get-Service sshd
```

Since it's a Windows Service you can see it as "OpenSSH SSH Server" in services.msc as well, or


```ps1
Set-Service -Name sshd -StartupType 'Automatic'
```

Remember that we SSH over port 22 so you'll have a firewall rule incoming on 22 at this point.
SSH.  Windows.  Think twice to open any windows port to the world. I would always limit by ip.

Now,

```
ssh slavko@windows2016eval

Microsoft Windows [Version 10.0.17763.379]
(c) 2018 Microsoft Corporation. All rights reserved.

slavko@MSEDGEWIN10 C:\Users\Slavko>

```

We are set

## Unsorted notes

### Running console as system interactively

```
psexec.exe -i -s -d cmd.exe
```

### Running console as system in ConEmu

Create launch item `Shells::cmd(System)`

```
cmd.exe -new_console:aA
```

You can always check who are you by invoking

```
echo %USERDOMAIN%\%USERNAME%
```

or in powershell

```
write-host $env:userdomain\$env:username
```

### Powershell extra tools

https://github.com/Pscx/Pscx

Pscx is hosted on the PowerShell Gallery. You can install Pscx with the following command:

```ps1
Install-Module Pscx -Scope CurrentUser
```

You may be prompted to trust the PSGallery. Respond with a 'y' (for yes) to proceed with the install.

If you already have installed Pscx from the PowerShell Gallery, you can update Pscx with the command:

```ps1
Update-Module Pscx
```

It has multiple functions, in particular ones

```ps1
Invoke-BatchFile "${env:ProgramFiles(x86)}\Microsoft Visual Studio 12.0\VC\vcvarsall.bat"
```
PSCX also has an Import-VisualStudioVars function:

```ps1
Import-VisualStudioVars -VisualStudioVersion 2017
```
