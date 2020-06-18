3rd party tools, covered by original license

## Send-File.ps1

This is a function that allows you to send files or recursively send a folder of files over to a remote WinRM session.  This functions breaks apart each file and streams it to the remote session and then pieces it back together again once it's there. It's a handy way to send files over to a point where you might only have WinRM capability like a DMZ.

https://gallery.technet.microsoft.com/scriptcenter/Send-Files-or-Folders-over-273971bf


## ForceImportRootCerts.ps1
Possible cert stores:

if you open Powershell (as admin) and type "set-location cert:" you can then type e.g. "dir" or "dir LocalMachine" to get a list of valid CertStoreLocation values -

PS Cert:> dir LocalMachine
Name : TrustedPublisher
Name : ClientAuthIssuer
Name : Remote Desktop
Name : Root
Name : TrustedDevices
Name : CA
Name : Windows Live ID Token Issuer
Name : eSIM Certification Authorities
Name : AuthRoot
Name : AAD Token Issuer
Name : FlightRoot
Name : TrustedPeople
Name : My
Name : SmartCardRoot
Name : Trust
Name : Disallowed
Name : Homegroup Machine Certificates
Name : SMS

So to import into the local machine trusted root certification authorities store, the command would be:

Import-Certificate -FilePath C:\Path\To\cert.cer -CertStoreLocation Cert:\LocalMachine\Root

Hope that helps :-)


## Convert-PfxToPem.ps1

Windows PowerShell script that converts Windows PFX certificates (PKCS#12) into PEM (PKCS#8) format for use with MongoDB.

To use an X.509 certificate contained in a Windows Certificate Store, export the certificate as a `.pfx` (including the private key) and use this script to convert it into a MongoDB compatible format.

Command line syntax:

`Convert-PfxToPem.ps1 [-PFXFile] <string> [[-PEMFile] <string>] [-Passphrase <string>] [-Overwrite]`

Required parameters:

* `-PFXFile <path>` - Path of the Windows PFX certificate to convert.

Optional parameters:

- `-PEMFile <path>` - Path of the PEM certificate to output.
  * If this is not supplied you will be prompted interactively.
- `-Passphase <passphrase>` - Supply this if the private key of the PFX is password protected.
- `-Overwrite` - Add this switch to overwrite any existing PEMFile.

