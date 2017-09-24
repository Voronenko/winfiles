# These components will be loaded when running Microsoft.Powershell (i.e. Not Visual Studio)

Push-Location (Join-Path (Split-Path -parent $profile) "components")

# From within the ./components directory...
. .\visualstudio.ps1
. .\console.ps1

if (((Get-Command git -ErrorAction SilentlyContinue) -ne $null) -and (Get-Module -ListAvailable -Name z )) {
  Import-Module z
}

Pop-Location
