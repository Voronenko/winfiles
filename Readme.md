winfiles
========

My windows environment. Multi-phase install with optional steps.
It is recommended to install under admin powershell 
(in other case will activate admin mode, but via subprocess launch in popup)

So, to recap, 

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

Check powershell version

```ps
$PSVersionTable.PSVersion
````