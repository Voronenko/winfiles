#
# Copyright (c) Microsoft Corporation.  All rights reserved.
#

<#
.SYNOPSIS
Module with the helper functions for passing the encrypted data through
the CustomData.
#>
$script:ErrorActionPreference = "Stop"

function Copy-Cert
{
<#
.SYNOPSIS
Copy a certificate from one path to another.
#>
    [CmdletBinding()]
    param(
        ## Path of the original cert (including the thumbprint).
        [Parameter(ParameterSetName = "Path", Mandatory=$true)]
        [string] $Path,
        ## The certificate object to copy.
        [Parameter(ParameterSetName = "Certificate", Mandatory=$true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,
        ## The destination path (excluding the thumbprint).
        [Parameter(Mandatory=$true)]
        [string] $Destination
    )

    if (!$Certificate) {
        $Certificate = Get-Item $Path
    }
    if (!$Certificate) {
        throw "The certificate at path '$Path' is not present"
    }

	$store = Get-Item $Destination
	$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
	$store.Add($Certificate)
	$store.Close()
}

function New-AzureVMCert
{
<#
.SYNOPSIS
Create a certificate that can be used as a VM machine cert in Azure,
for HTTPS connection. Installs it locally as a root cert.

.OUTPUT
A hashtable containing the fields:
cert - the newly created certificate object;
secobj - the JSON-formatted secret object in Azure vault.
#>
    [CmdletBinding()]
    param(
        ## Name of the vault to store the secret.
        [Parameter(Mandatory=$true)]
        [string] $VaultName,
        ## Computer name, such as "myvm.westus.cloudapp.azure.com".
        ## Must match the computer name, or HTTPS WinRM will refuse to use it.
        [Parameter(Mandatory=$true)]
        [string] $Computer,
        ## Name of the secret in the vault, by default will be equal to the
        ## computer name. The non-alphanumeric characters (such as dots)
        ## will be replaced with "-".
        [string] $SecretName,
        ## Path to the binary makecert.exe.
        [string] $Makecert = "makecert.exe",
        ## Use the PowerShell created self-signed cert.
        ## Otherwise uses makecert.exe to create the cert.
        ## The certs created by makecert.exe are suitable to obtain
        ## the private key and do the decryption of data with it.
        ## The certs created by PS are suitable for WinRM authentication
        ## and such but not for the arbitrary data decrytion. The PS-created
        ## certs also expire in 1 year, the ones created by makecert don't.
        [switch] $PS,
        ## Install the certificate locally as a root certificate, to allow
        ## the secure PowerShell connections through the HTTPS protocol
        ## to the VM that will be using this certificate.
        ## Requires the administrator elevation.
        [switch] $InstallLocal
    )

    if (!$SecretName) {
        $SecretName  = $Computer
    }
    $SecretName  = $SecretName -replace "[_\W]","-"

    $pwdplain = "abcd" # The password will be included into JSON anyway, not expected to be secret.
    $pwd = ConvertTo-SecureString -AsPlainText $pwdplain -Force
    # The certs can't be created directly in LocalMachine\Root.
    if ($PS) {
        $cert = New-SelfSignedCertificate -CertStoreLocation Cert:\CurrentUser\My\ -DnsName $Computer
    } else {
        $subj = "CN=$Computer"
        $oldThumbs = (dir Cert:\CurrentUser\My | ? { $_.Subject -eq $subj }).Thumbprint
        # EKU values are from http://stackoverflow.com/questions/10019412/certificates-oid-reference-for-extended-key-usages,
        # used here "Server Authentication", "Data Encipherment"
        $out = &"$Makecert" -r -pe -a sha1 -n "$subj" -ss My -sr CurrentUser -len 2048 -sky exchange -sp "Microsoft Enhanced RSA and AES Cryptographic Provider" -sy 24 -eku 1.3.6.1.5.5.7.3.1,1.3.6.1.4.1.311.10.3.4
        if (!$?) {
            throw "makecert.exe failed: $out"
        } else { 
            Write-Verbose $out
        }
        $newThumbs = (dir Cert:\CurrentUser\My | ? { $_.Subject -eq $subj }).Thumbprint
        $thumb = @(foreach ($x in $newThumbs) { if ($x -notin $oldThumbs) { $x } })
        if ($thumb.Count -ne 1) {
            throw ("Unable to discover the thumbprint of the newly created certificate, found: " + ($thumb -join ", "))
        }
        $cert = Get-Item "Cert:\CurrentUser\My\$thumb"
    }
    if ($InstallLocal) {
        Copy-Cert -Certificate $cert -Destination "Cert:\LocalMachine\Root\"
    }
    $cbytes = $cert.Export("Pfx", $pwd)
    $ecbytes = [System.Convert]::ToBase64String($cbytes)
    $jsonObject = @"
{
"data": "$ecbytes",
"dataType" :"pfx",
"password": "$pwdplain"
}
"@
    $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonObject)
    $secret = ConvertTo-SecureString -String ([System.Convert]::ToBase64String($jsonBytes)) -AsPlainText –Force
    # Returns the secret object.
    $secobj = Set-AzureKeyVaultSecret -VaultName $VaultName -Name $SecretName -SecretValue $secret

    @{
        cert = $cert;
        secobj = $secobj;
    }
}

function Protect-CustomString
{
<#
.SYNOPSIS
Encrypt the contents of a string on a certificate, manually constructing an envelope.

.OUTPUT
Either the encoded bytes or the Base64 string with them.
#>
    [CmdletBinding()]
    param(
        ## String to encrypt
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [Parameter(Mandatory=$true)]
        [string] $String,
        ## Cert to encrypt with the public key.
        [Parameter(Mandatory=$true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Cert,
        ## Return the result as a Base64 string. Otehrwise 
        [switch] $Base64
    )

    $sedata = ConvertTo-SecureString -Force -AsPlainText $String
    $key = New-Object byte[](32)
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
    $rng.GetBytes($key)

    # Payload is Base64-encoded
    $payload = ConvertFrom-SecureString -Key $key $sedata
    # Restore it back to bytes
    $paybytes = [Convert]::FromBase64String($payload)

    # Encrypt the one-time key with the public key.
    # $true selects the newer padding mode
    $enkey = $cert.PublicKey.Key.Encrypt($key, $true)

    # Encode the length of the key as bytes.
    $len = @([byte]($enkey.count -band 0xFF), [byte]($enkey.count -shr 8)) 
    Write-Verbose "Symmetric key length is $($enkey.count) bytes"

    # Convert the thumbprint to bytes.
    $thumbytes = New-Object byte[](20)
    $thumb = $Cert.Thumbprint
    for ($i = 0; $i -lt $thumb.Length; $i += 2) {
        $thumbytes[$i/2] = [byte]"0x$($thumb.Substring($i,2))"
    }

    $bytes = $thumbytes + $len + $enkey + $paybytes
    if ($Base64) {
        [System.Convert]::ToBase64String($bytes)
    } else {
        $bytes
    }
}

function Unprotect-CustomString
{
<#
.SYNOPSIS
Decrypt a bunch of bytes on a certificate and decode them into a string.
The same certificate with the
private key must be already installed locally, the decryption will
find it by the thumbprint in the envelope.

.OUTPUT
The decoded string.
#>
    [CmdletBinding()]
    param(
        ## Bytes to decrypt.
        [Parameter(ParameterSetName = "Bytes", Mandatory=$true)]
        [byte[]] $Bytes,
        ## Another option: Base64 string to decrypt.
        [Parameter(ParameterSetName = "String", Mandatory=$true)]
        [string] $String,
        ## Force a particular certificate. By default the cert will be found
        ## by thumbprint.
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Cert
    )

    if ($PsCmdlet.ParameterSetName -eq "String") {
        $Bytes = [Convert]::FromBase64String($String)
    }

    if ($Cert) {
        if (!$Cert.PrivateKey) {
            throw "Explicit certificate with thumbprint $($Cert.Thumbprint) has a null property PrivateKey. Try using a cert with a Crypto provider, not Key Store provider."
        }
    } else {
        $thumbytes = $Bytes[0..19]
        $thumb = ""
        foreach ($b in $thumbytes) {
            $thumb += "{0:X2}" -f $b
        }

        Write-Verbose "Thumbprint is $thumb"

        $Cert = @(dir -Recurse cert:\ | ? { $_.Thumbprint -eq $thumb -and $_.PrivateKey})[0]

        if (!$Cert) {
            throw "Cannot find a certificate with thumbprint $thumb and property PrivateKey in it not null. Try using a cert with a Crypto provider, not Key Store provider."
        }
    }
    Write-Verbose "Using the certificate $($cert.PSPath)"

    $keylen = [uint32]$Bytes[20] + ([uint32]$Bytes[21] -shl 8)
    Write-Verbose "Symmetric key length is $keylen bytes"

    $enkey = $Bytes[22..(22-1+$keylen)]
    $payload = [System.Convert]::ToBase64String( $Bytes[(22+$keylen)..($Bytes.Count)] )
    
    # $true selects the newer padding mode
    $key = $cert.PrivateKey.Decrypt($enkey, $true)

    $sedata = ConvertTo-SecureString -Key $key $payload
    # Convert the SecureString to plain text.
    (New-Object System.Net.NetworkCredential "",$sedata).Password
}


function Protect-CustomFiles
{
<#
.SYNOPSIS
Encrypt the contents of a set of files to a value that
can be used for CustomData, to pass it into the VM.

.OUTPUT
Either the encoded bytes or the Base64 string with them.
#>
    [CmdletBinding()]
    param(
        ## File paths.
        [AllowEmptyString()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [Parameter(Mandatory=$true)]
        [string[]] $Path,
        ## Cert to encrypt with the public key.
        [Parameter(Mandatory=$true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Cert,
        ## Prefix in the file names to drop (the file names that don't match
        ## will be left unchanged).
        [string] $Prefix,
        ## Return the result as a Base64 string. Otehrwise 
        [switch] $Base64
    )

    $pattern = "^" + [Regex]::Escape($Prefix)
    $strings = @(&{
        foreach ($f in $Path) {
            $p = $f -replace $pattern,""
            Write-Verbose "Entering file '$f' as '$p'"

            $p
            [System.Convert]::ToBase64String((Get-Content -Encoding Byte -LiteralPath $f))
        }
    })
    Protect-CustomString -String ($strings -join "`r`n") -Cert $Cert -Base64:$Base64
}

function Unprotect-CustomFiles
{
<#
.SYNOPSIS
Decrypt the contents of a set of files from a CustomData value.

.OUTPUT
The list of full new paths of extracted files.
#>
    [CmdletBinding()]
    param(
        ## Bytes to decrypt.
        [Parameter(ParameterSetName = "Bytes", Mandatory=$true)]
        [byte[]] $Bytes,
        ## Another option: Base64 string to decrypt.
        [Parameter(ParameterSetName = "String", Mandatory=$true)]
        [string] $String,
        ## Another option: path of the CustomData file to decrypt.
        [Parameter(ParameterSetName = "Path", Mandatory=$true)]
        [string] $Path,
        ## Prefix for the file names as they get extracted
        ## (may be empty, then the files will be extracted with
        ## the names as-is, possibly in the relative paths).
        [AllowEmptyString()]
        [AllowNull()]
        [Parameter(Mandatory=$true)]
        [string] $Prefix,
        ## Force a particular certificate. By default the cert will be found
        ## by thumbprint.
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Cert,
        ## Just list the names of files.
        [switch] $List
    )

    if ($Path) {
        $Bytes = Get-Content -Encoding Byte -Path $Path
    }
    if ($Bytes) {
        $string = Unprotect-CustomString -Bytes $Bytes -Cert $Cert
    } else {
        $string = Unprotect-CustomString -String $String -Cert $Cert
    }
    $lines = @($string -split "`r`n")

    for ($i = 0; $i -lt $lines.Count; $i += 2) {
        $f = $lines[$i];
        if ($Prefix) {
            $p = Join-Path $Prefix $f
        } else {
            $p = $f
        }
        Write-Verbose "Extracting '$f' as '$p'."
        $p
        if (!$List) {
            [Convert]::FromBase64String($lines[$i+1]) | Set-Content -Force -Encoding Byte -LiteralPath $p
        }
    }
}

function Unprotect-DockerCerts
{
<#
.SYNOPSIS
Extract the Docker certificates from a CustomData file.
#>
    [CmdletBinding()]
    param(
        ## Path of the CustomData file with the encrypted Docker certs.
        [string] $CustomDataPath = "C:\AzureData\CustomData.bin",
        ## Directory to place the Docker certs into.
        [string] $DockerCertPath = "${env:ProgramData}\Docker\certs.d",
        ## Do not restart the Docker service after extracting the certs.
        [switch] $NoRestart,
        ## Do not open the firewall for Docker.
        [switch] $NoFirewall
    )
    if (!$NoFirewall) {
        # Port for the Docker applications.
        netsh advfirewall firewall add rule name="Http 80" dir=in action=allow protocol=TCP localport=80
        # Port for Docker management.
        netsh advfirewall firewall add rule name="Docker Secure Port" dir=in action=allow protocol=TCP localport=2376
    }
    if (!(Test-Path $DockerCertPath)) {
        $null = New-Item $DockerCertPath -type directory
    }
    Unprotect-CustomFiles -Path $CustomDataPath -Prefix $DockerCertPath
    if (!$NoRestart) {
        Restart-Service Docker
    }
}

function Initialize-DockerCerts
{
<#
.SYNOPSIS
Make sure that the Docker certificate files exist. If they don't exist, generate them.
#>
    [CmdletBinding()]
    param(
        ## Directory for the Docker certificates.
        [Parameter(Mandatory=$true)]
        [string] $Path,
        ## The openssl.exe binary. By default tries to locate it in ${env:path}.
        ## The relative paths will be interpreted relative to -Path.
        [string] $OpensslExePath = "openssl.exe", 
        ## The openssl.cnf configuration file. By default assumes that it's in the
        ## directory for the certificates.
        ## The relative paths will be interpreted relative to -Path.
        [string] $OpensslConfigPath = "openssl.cnf"
    )

    if (!(Test-Path $Path -PathType Container))
    {
        # Creates the certificate directory
        $null = New-Item $Path -type directory
    }

    $PreviousLocation = Get-Location
    Set-Location $Path

    if ((Test-Path ca.pem) -And (Test-Path server-cert.pem) -And (Test-Path server-key.pem) -And (Test-Path cert.pem) -And (Test-Path key.pem))
    {
        # Certs already there, skip generation
        Set-Location $PreviousLocation
        return;
    }

    try {
        $ErrorActionPreference = "Continue"
        Write-Verbose "Generating Docker certificates in $Path ..."

        # Set openssl config file path
        $env:OPENSSL_CONF=$OpensslConfigPath

        # Set random seed file to be generated in current folder to avoid permission issue
        $env:RANDFILE=".rnd"

        # Generate certificates
        & $OpensslExePath genrsa -aes256 -out ca-key.pem -passout pass:Docker123 2048 >$null 2>$null
        & $OpensslExePath req -new -x509 -passin pass:Docker123 -subj "/C=US/ST=WA/L=Redmond/O=Microsoft" -days 365 -key ca-key.pem -sha256 -out ca.pem >$null 2>$null
        & $OpensslExePath genrsa -out server-key.pem 2048 >$null 2>$null
        & $OpensslExePath req -subj "/C=US/ST=WA/L=Redmond/O=Microsoft" -new -key server-key.pem -out server.csr >$null 2>$null

        # Generate certificate with multiple domain names
        "subjectAltName = IP:10.10.10.20,IP:127.0.0.1,DNS.1:*.cloudapp.net,DNS.2:*.*.cloudapp.azure.com" | Out-File extfile.cnf -Encoding ASCII
        & $OpensslExePath x509 -req -days 365 -in server.csr -passin pass:Docker123 -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server-cert.pem -extfile extfile.cnf >$null 2>$null
        & $OpensslExePath genrsa -out key.pem 2048 >$null 2>$null
        & $OpensslExePath req -subj "/CN=client" -new -key key.pem -out client.csr >$null 2>$null
        "extendedKeyUsage = clientAuth" | Out-File extfile.cnf -Encoding ASCII 
        & $OpensslExePath x509 -req -days 365 -in client.csr -passin pass:Docker123 -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out cert.pem -extfile extfile.cnf >$null 2>$null
    } finally {
        # Clean up
        Remove-Item -ea "SilentlyContinue" *.csr,.rnd
        Set-Location $PreviousLocation
    }

    Write-Verbose "Generation completed."
}

function New-NanoServerAzureVM
{
<#
.SYNOPSIS
Create all the bits and pieces needed to start a VM in Azure
and instantiate the VM.

The FQDN of the VM will be $VMName.$ResourceGroupLocation.cloudapp.azure.com.

The Azure module must be already imported before running this function.

A Resource Group that contains the key vault is also used to place the VM.

.EXAMPLE
New-NanoServerAzureVM -Location "West US" -VMName ref005 -AdminUsername "radmin" -VaultName "refaatKV002" -ResourceGroupName "refaatRG002" -Verbose 

Create a VM entirely from the command-line parameters if all the tools are located along with the script. The user will be prompted for the admin password

#>
    [CmdletBinding()]
    param(
        ## Geographic location where the VM is to be instantiated (such as "westus").
        ## If the template parameters file is specified, the value of virtualMachineLocation
        ## in it serves as the default.
        [Parameter(Mandatory=$true)]
        [string] $Location,
        ## Virtual machine name.
        [Parameter(Mandatory=$true)]
        [string] $VMName,
        ## Administrator user name.
        [Parameter(Mandatory=$true)]
        [string] $AdminUsername,
        ## Administrator password. 
        [Parameter(Mandatory=$true)]
        [SecureString] $AdminPassword,
        ## Virtual machine size string.
        ## If not specified anywhere, defaults to "Basic_A1".
        [string] $VMSize = "Basic_A1",
        ## Name of the new storage account to be created to keep the VHDs of this VM.
        ## If not specified, will be auto-generated based on VM name.
        [string] $StorageAccountName,
        ## Name of the resource group that contains the key vault, and will also contain the VM.
        ## This resource group must be created in advance, then can be reused for multiple
        ## VMs. It can be created as:
        ##   Switch-AzureMode AzureResourceManager
        ##   New-AzureResourceGroup -Name "myvaultrg" -Location "West US"
        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,
        ## Name of the key vault where the Windows certificate for the VM will be created.
        ## This key vault must be created in advance, then can be reused for multiple
        ## VMs. It can be created as:
        ##   New-AzureKeyVault -VaultName "myvaultrg" -ResourceGroupName "myvaultrg" -Location "West US" -EnabledForDeployment
        [Parameter(Mandatory=$true)]
        [string] $VaultName,
        ## The name of the VM image to be used for the VM creation.
        ## Defaults to the image provided by Microsoft.
        ## The WS2016 SKU is "2016-Nano-Server", the WS2016 technical preview is "2016-Nano-Server-Technical-Preview".
        [string] $ImageSku = "2016-Nano-Server",
        ## The version of the named VM image to be used for the VM creation.
        [string] $ImageVersion = "latest"
    )


    # Fill in the path defaults.

    $TemplateFile = Join-Path $PSScriptRoot "NanoServerAzureTemplate.json"
    $MakecertExePath = Join-Path $PSScriptRoot "makecert.exe"

    Write-Verbose "TemplateFile: $TemplateFile"
    Write-Verbose "MakecertExePath: $MakecertExePath"

    if (!$StorageAccountName) {
        $StorageAccountName = (($VmName + [System.IO.Path]::GetRandomFileName()) -replace "[^a-z0-9]","")
    }

    # Remove the spaces from the location name, just like Azure does.
    # Need this to create the decent FQDN.
    $location = $location -replace "\s",""

    Write-Verbose "Explicit arg VM name: $VMName"
    Write-Verbose "Explicit arg VM size: $VMSize"
    Write-Verbose "Explicit arg admin user name: $AdminUsername"
    Write-Verbose "Explicit arg storage account name: $StorageAccountName"
    Write-Verbose "Explicit arg VM location: $Location"
    Write-Verbose "Explicit arg key vault name: $VaultName"
    Write-Verbose "Explicit arg resource group name: $ResourceGroupName"
    Write-Verbose "Explicit arg image SKU: $ImageSku"
    Write-Verbose "Explicit arg image version: $ImageVersion"

    # Generate the Windows certificate for the VM.
    $fqdn = "$VmName.$location.cloudapp.azure.com"
    Write-Verbose "FQDN: $fqdn"
    $sec = (New-AzureVMCert -Makecert $MakecertExePath -VaultName $VaultName -Computer $fqdn -InstallLocal)
    Write-Verbose "Generated the Windows cert: $($sec.cert.PSPath)"

    # Build the template arguments 
    # (or overridden explicitly).
    $tpo = @{
        certificateUrl = $sec.secobj.id;
        newStorageAccountName = $StorageAccountName;
        virtualMachineLocation = $Location;
        virtualMachineSize = $VMSize;
        adminUsername = $AdminUsername;
        adminPassword = (New-Object System.Net.NetworkCredential "",$AdminPassword).Password;
        dnsNameForPublicIP = $VMName.ToLower();
        vaultName = $VaultName;
        vaultResourceGroup = $ResourceGroupName;
        imageSku = $ImageSku;
        imageVersion = $ImageVersion;
    }

    # Create or update the resource group using the specified template file 
    #$global:xxxtpo = $tpo # DEBUG

    New-AzureRmResourceGroupDeployment -Name $vmName `
                        -TemplateFile $TemplateFile `
                        -ResourceGroupName $ResourceGroupName `
                        -TemplateParameterObject $tpo `
                        -Force -Verbose

}

function Set-HelperAzureRmCustomScript
{
<#
.SYNOPSIS
Create or set the CustomScript Extension conveniently in the Azure Resource Manager.

.EXAMPLE

Set-HelperAzureRmCustomScript -ResourceGroupName refaatRG002 -VMName ref005 -Location "West US" -NoDownload -FullCommand "echo With NoDownload" -Verbose

Run a plain Windows command, without any scripts to download into the extension.

.EXAMPLE

Set-HelperAzureRmCustomScript -ResourceGroupName refaatRG002 -VMName ref005 -Location "West US" -Account myscript -NewAccount -Container scriptc -NewContainer -Script runme.ps1,x.txt -UploadPath "c:\tmp" -Arguments "With new accounts < x.txt" -Verbose

Upload the PowerShell script and a data file from c:\tmp and run the script. Create the storage account and container if they didn't exist yet.

.EXAMPLE

Set-HelperAzureRmCustomScript -ResourceGroupName refaatRG002 -VMName ref005 -Location "West US" -Account myscript -Container scriptc -Script runme.ps1 -Arguments "Without upload" -Verbose

Run a PowerShell script that has been already uploaded to the Azure storage.

.EXAMPLE

Set-HelperAzureRmCustomScript -ResourceGroupName refaatRG002 -VMName ref005 -Location "West US" -ScriptUri https://raw.githubusercontent.com/My/Dir/master/MyScript.ps1 -Arguments "With URI" -Verbose

Run a PowerShell script downloaded from a public resource.

#>
    [CmdletBinding()]
    param(
        ## The names of the script file(s) that are either already present in the
        ## storage account or will be uploaded to the storage account.
        [Parameter(ParameterSetName = "Storage", Mandatory=$true)]
        [string[]] $Script,
        ## Upload the script files to the storage account from this path.
        ## If not specified, the scripts will be assumed to be already uploaded.
        [Parameter(ParameterSetName = "Storage")]
        [string] $UploadPath,
        ## Name of the storage account for the script file(s).
        [Parameter(ParameterSetName = "Storage", Mandatory=$true)]
        [string] $Account,
        ## If the account doesn't exist, create it.
        [Parameter(ParameterSetName = "Storage")]
        [switch] $NewAccount,
        ## Name of the storage container for the script file(s).
        [Parameter(ParameterSetName = "Storage", Mandatory=$true)]
        [string] $Container,
        ## If the container doesn't exist, create it.
        [Parameter(ParameterSetName = "Storage")]
        [switch] $NewContainer,
        ## The URIs of the pre-uploaded script(s) and whatever other helper
        ## files to be downloaded by the extension.
        [Parameter(ParameterSetName = "Uri", Mandatory=$true)]
        [string[]] $ScriptUri,
        ## Use if there is no file to be downloaded, to just run a plain command.
        [Parameter(ParameterSetName = "NoDownload", Mandatory=$true)]
        [switch] $NoDownload,
        ## Name of the resource group where the VM and the storage account belong.
        [Parameter(Mandatory=$true)]
        [string] $ResourceGroupName,
        ## Name of the VM where to set the extension.
        [Parameter(Mandatory=$true)]
        [string] $VMName,
        ## Location of the VM and of the storage account (like "westus").
        [Parameter(Mandatory=$true)]
        [string] $Location,
        ## The arguments for the command. The first element of -Script will be taken as the
        ## name of the PowerShell script.
        ## The arguments are not private (and making them private
        ## doesn't make that much sense because they may appear in the log).
        ## The options -Arguments and -FullCommand are mutually exclusive.
        [string] $Arguments,
        ## The full command to run, incase if some more unusual command is desired.
        ## The arguments are not private (and making them private
        ## doesn't make that much sense because they may appear in the log).
        ## The options -Arguments and -FullCommand are mutually exclusive.
        [string] $FullCommand,
        ## The version of the extension. For the NanoServer it currently doesn't matter
        ## much, any version gets substituted with the version embedded in the Nano image.
        ## It will get properly supported in the future.
        [string] $Version = "1.8",
        ## Any extra arguments you want to pass in the protected settings.
        ## Finding the file with the settings on the VM and decrypting them is
        ## up to your script.
        [hashtable] $ProtectedSettings
    )

    $isDebug = ($DebugPreference -ne "SilentlyContinue")
    if ($isDebug -and $VerbosePreference -eq "SilentlyContinue") {
        # If the debug mode is enabled, enable the verbosity too.
        $VerbosePreference = "Conitnue"
    }
    $isVerbose = ($VerbosePreference -ne "SilentlyContinue")

    if ($NoDownload -and !$FullCommand) {
        throw "The option -NoDownload requires -FullCommand."
    }

    if ($Arguments -and $FullCommand) {
        throw "The options -Arguments and -FullCommand are mutually exclusive."
    }
    if (!$FullCommand) {
        if ($Script) {
            $cmd = $Script[0]
        } else {
            $cmd = Split-Path -Leaf -Path $ScriptUri[0]
        }
        $FullCommand = "powershell.exe -ExecutionPolicy Unrestricted -File " + $cmd + " " + $Arguments;
    }

    if ($Script) {
        try {
            $sac = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $Account -Verbose:$isVerbose -Debug:$isDebug -ea "Stop"
        } catch {
            if (!$NewAccount) {
                throw
            }
            Write-Verbose "Creating the new account $Account"
            $sac = New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $Account -SkuName "Standard_LRS" -Location $Location -Verbose:$isVerbose -Debug:$isDebug -ea "Stop"
        }
        try {
            $null = Get-AzureStorageContainer -Name $Container -Context $sac.Context -Verbose:$isVerbose -Debug:$isDebug -ea "Stop"
        } catch {
            if (!$NewContainer) {
                throw
            }
            Write-Verbose "Creating the new container $Container"
            $null = New-AzureStorageContainer -Name $Container -Context $sac.Context -Verbose:$isVerbose -Debug:$isDebug -ea "Stop"
        }

        if ($UploadPath) {
            foreach ($s in $Script) {
                Write-Verbose "Uploading the script file $s"
                $null = Set-AzureStorageBlobContent -Force -File (Join-Path $UploadPath $s) -Container $Container -Context $sac.Context -Verbose:$isVerbose -Debug:$isDebug -ea "Stop"
            }
        }

        $ScriptUri = @()
        foreach ($s in $Script) {
            Write-Verbose "Generating the access token for the script file $s"
            [string] $uri = New-AzureStorageBlobSASToken -Container $Container -Blob $s -Permission r -ExpiryTime ((Get-Date).AddDays(1.0)) -Context $sac.Context -FullUri -Verbose:$isVerbose -Debug:$isDebug -ea "Stop"
            $ScriptUri += @(,$uri)
        }
    }

    $public = @{
        fileUris=$ScriptUri;
        commandToExecute=$FullCommand;
    }

    Write-Verbose "Public settings: $($public | fl | Out-String)"

    if ($ProtectedSettings.Count -gt 0) {
        Set-AzureRmVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Location $Location -Name "CustomScript" -Publisher "Microsoft.Compute" -ExtensionType "CustomScriptExtension" -TypeHandlerVersion $Version -Settings $public -ProtectedSettings $ProtectedSettings -Verbose:$isVerbose -Debug:$isDebug -ea "Stop"
    } else {
        Set-AzureRmVMExtension -ResourceGroupName $ResourceGroupName -VMName $VMName -Location $Location -Name "CustomScript" -Publisher "Microsoft.Compute" -ExtensionType "CustomScriptExtension" -TypeHandlerVersion $Version -Settings $public -Verbose:$isVerbose -Debug:$isDebug -ea "Stop"
    }
}
