choco install pwsh
choco install openssh -params '"/SSHServerFeature"' -y
choco install curl
refreshenv

New-Item -Path c:\pwsh -ItemType SymbolicLink -Value "C:\Program Files\PowerShell\6" -force

cd $env:USERPROFILE; mkdir .ssh; cd .ssh; New-Item authorized_keys
curl https://api.github.com/users/voronenko/keys | jq -r '.[].key' > $env:USERPROFILE/.ssh/authorized_keys

# tune sshd_config, if needed
Restart-Service sshd
