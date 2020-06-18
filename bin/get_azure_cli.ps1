# Check to see if we are currently running "as Administrator"
if (!(Verify-Elevated)) {
   $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
   $newProcess.Arguments = $myInvocation.MyCommand.Definition;
   $newProcess.Verb = "runas";
   [System.Diagnostics.Process]::Start($newProcess);

   exit
}


# https://azure.microsoft.com/en-us/blog/azure-powershell-cross-platform-az-module-replacing-azurerm/

Install-Module -Name Az

# Device Code login - Provides a link to sign into Azure via your web browser
#Connect-AzAccount

# Service Principal login - Use a previously created service principal to log in
#Connect-AzAccount -ServicePrincipal -ApplicationId 'http://my-app' -Credential $PSCredential -TenantId $TenantId