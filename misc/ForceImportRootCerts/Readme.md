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
