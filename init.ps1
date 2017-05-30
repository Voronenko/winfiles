if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

$username=$env:USERNAME

$dir="c:\batch\winfiles\"
$oldfiles="c:\batch\winfilesold"

$profileDir="C:\Users\$username\Documents\WindowsPowerShell"

$olddir="~/winfiles_old" # old winfiles backup directory

$files="aliases components components-nuget components-shell exports functions Microsoft.PowerShell_profile NuGet_profile profile"
$components="console git visualstudio"
$dotfiles="gitconfig jshintrc jscsrc editorconfig hgrc"

New-Item -ItemType Directory -Force -Path $oldfiles
New-Item -ItemType Directory -Force -Path $oldfiles\components
New-Item -ItemType Directory -Force -Path $oldfiles\home
New-Item -ItemType Directory -Force -Path $profileDir\components
New-Item -ItemType Directory -Force -Path $profileDir\home

$profileExist = Test-Path $profile

if (!$profileExist) {

  $files.Split(" ") | ForEach {
    if (Test-Path $profileDir\$_.ps1) { Copy-Item $profileDir\$_.ps1 $oldfiles }
    echo "New-Item -Path $profileDir\$_.ps1 -ItemType SymbolicLink -Value $dir\$_.ps1"
    New-Item -Path $profileDir\$_.ps1 -ItemType SymbolicLink -Value $dir\$_.ps1
  }

  $components.Split(" ") | ForEach {
    if (Test-Path $profileDir\components\$_.ps1) { Copy-Item $profileDir\components\$_.ps1 $oldfiles\components }
    New-Item -Path $profileDir\components\$_.ps1 -ItemType SymbolicLink -Value $dir\components\$_.ps1
  }

  $dotfiles.Split(" ") | ForEach {
    if (Test-Path $profileDir\home\.$_) { Copy-Item $profileDir\home\.$_ $oldfiles\home }
    New-Item -Path $profileDir\home\.$_ -ItemType SymbolicLink -Value $dir\home\$_
  }


} 
