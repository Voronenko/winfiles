# Check to see if we are currently running "as Administrator"
if (!(Verify-Elevated)) {
   $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
   $newProcess.Arguments = $myInvocation.MyCommand.Definition;
   $newProcess.Verb = "runas";
   [System.Diagnostics.Process]::Start($newProcess);

   exit
}

### Update Help for Modules
Write-Host "Updating Help..." -ForegroundColor "Yellow"
Update-Help -Force


### Package Providers
Write-Host "Installing Package Providers..." -ForegroundColor "Yellow"
Get-PackageProvider NuGet -Force | Out-Null
# Chocolatey Provider is not ready yet. Use normal Chocolatey
#Get-PackageProvider Chocolatey -Force
#Set-PackageSource -Name chocolatey -Trusted

### Chocolatey
Write-Host "Installing Desktop Utilities..." -ForegroundColor "Yellow"
if ((which cinst) -eq $null) {
    iex (new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')
    Refresh-Environment
    choco feature enable -n=allowGlobalConfirmation
}


### Install PowerShell Modules
Write-Host "Installing PowerShell Modules..." -ForegroundColor "Yellow"
Install-Module Posh-Git -Scope CurrentUser -Force
Install-Module PSWindowsUpdate -Scope CurrentUser -Force
Install-Module z -AllowClobber -Scope CurrentUser -Force

# system and cli
choco install curl                --limit-output
choco install nuget.commandline   --limit-output
choco install webpi               --limit-output
choco install git.install         --limit-output -params '"/GitAndUnixToolsOnPath /NoShellIntegration"'
choco install nvm.portable        --limit-output
choco install ruby                --limit-output

# browsers
choco install GoogleChrome        --limit-output
# choco install GoogleChrome.Canary --limit-output
# choco install Firefox             --limit-output
# choco install Opera               --limit-output

# dev tools and frameworks
choco install atom                --limit-output
choco install visualstudiocode    --limit-output
choco install Fiddler4            --limit-output
#choco install vim                 --limit-output
choco install winmerge            --limit-output

Refresh-Environment

# nvm on
# $nodeLtsVersion = choco search nodejs-lts --limit-output | ConvertFrom-String -TemplateContent "{Name:package-name}\|{Version:1.11.1}" | Select -ExpandProperty "Version"
# nvm install $nodeLtsVersion
# nvm use $nodeLtsVersion
# Remove-Variable nodeLtsVersion

# gem pristine --all --env-shebang

### Windows Features
Write-Host "Installing Windows Features..." -ForegroundColor "Yellow"
# IIS Base Configuration
Enable-WindowsOptionalFeature -Online -All -FeatureName `
    "IIS-BasicAuthentication", `
    "IIS-DefaultDocument", `
    "IIS-DirectoryBrowsing", `
    "IIS-HttpCompressionDynamic", `
    "IIS-HttpCompressionStatic", `
    "IIS-HttpErrors", `
    "IIS-HttpLogging", `
    "IIS-ISAPIExtensions", `
    "IIS-ISAPIFilter", `
    "IIS-ManagementConsole", `
    "IIS-RequestFiltering", `
    "IIS-StaticContent", `
    "IIS-WebSockets", `
    "IIS-WindowsAuthentication" `
    -NoRestart | Out-Null

# ASP.NET Base Configuration
Enable-WindowsOptionalFeature -Online -All -FeatureName `
    "NetFx3", `
    "NetFx4-AdvSrvs", `
    "NetFx4Extended-ASPNET45", `
    "IIS-NetFxExtensibility", `
    "IIS-NetFxExtensibility45", `
   "IIS-ASPNET", `
   "IIS-ASPNET45" `
   -NoRestart | Out-Null

# Web Platform Installer for remaining Windows features
webpicmd /Install /AcceptEula /Products:"UrlRewrite2"
webpicmd /Install /AcceptEula /Products:"NETFramework452"
webpicmd /Install /AcceptEula /Products:"Python279"

### Node Packages
Write-Host "Installing Node Packages..." -ForegroundColor "Yellow"
if (which npm) {
    npm update npm
    npm install -g gulp
    npm install -g node-inspector
    npm install -g yarn
}


### Visual Studio Plugins
if (which Install-VSExtension) {
    ### Visual Studio 2015
    # VsVim
    # Install-VSExtension https://visualstudiogallery.msdn.microsoft.com/59ca71b3-a4a3-46ca-8fe1-0e90e3f79329/file/6390/57/VsVim.vsix
    # Productivity Power Tools 2015
    # Install-VSExtension https://visualstudiogallery.msdn.microsoft.com/34ebc6a2-2777-421d-8914-e29c1dfa7f5d/file/169971/1/ProPowerTools.vsix
}

# https://github.com/Microsoft/vswhere
choco install vswhere
