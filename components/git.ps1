if (((Get-Command git -ErrorAction SilentlyContinue) -ne $null) -and (Get-Module -ListAvailable -Name Posh-Git )) {
  Import-Module Posh-Git
  Start-SshAgent -Quiet
}
