# Check to see if we are currently running "as Administrator"
if (!(Verify-Elevated)) {
   $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
   $newProcess.Arguments = $myInvocation.MyCommand.Definition;
   $newProcess.Verb = "runas";
   [System.Diagnostics.Process]::Start($newProcess);

   exit
}


# Note: use below only in VM scenario to get a bit more resources and speed
# for real box that it risky anti pattern 

# disable realtime av monitoring
Set-MpPreference -DisableRealtimeMonitoring $true

# disable firewal
netsh advfirewall set allprofiles state off