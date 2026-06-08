# Define the registry path and value to retrieve the Windows product key
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform"
$registryValue = "BackupProductKeyDefault"

# Function to retrieve the Windows product key
function Get-WindowsProductKey {
    param(
        [string]$registryPath,
        [string]$registryValue
    )
    
    try {
        # Check if the registry path exists
        if (Test-Path -Path $registryPath) {
            # Retrieve the product key from the registry
            $productKey = Get-ItemProperty -Path $registryPath | Select-Object -ExpandProperty $registryValue
            
            if ($productKey) {
                Write-Host "Your Windows product key is: $productKey"
                return $productKey
            }
            else {
                # Alternative method using WMI if the registry key is empty
                $key = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
                if ($key) {
                    Write-Host "Your Windows product key is: $key"
                    return $key
                }
                else {
                    Write-Host "Unable to find the Windows product key."
                    return $null
                }
            }
        }
        else {
            Write-Host "The registry path does not exist."
            return $null
        }
    }
    catch {
        Write-Host "An error occurred: $_"
        return $null
    }
}

# Call the function to get the product key
$productKey = Get-WindowsProductKey -registryPath $registryPath -registryValue $registryValue

# Ask the user if they want to save the product key to a text file
if ($productKey) {
    Write-Host "Do you want to save the product key to a text file? (Y/N)"
    $userInput = Read-Host

    if ($userInput -eq "Y" -or $userInput -eq "y") {
        # Get the current directory where the script is located
        $currentDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition

        # Specify the file path in the current directory
        $filePath = Join-Path -Path $currentDirectory -ChildPath "WindowsProductKey.txt"

        try {
            # Save the product key to the text file
            $productKey | Out-File -FilePath $filePath -Encoding UTF8
            Write-Host "The product key has been saved to $filePath"
        }
        catch {
            Write-Host "An error occurred while saving the file: $_"
        }
    }
    else {
        Write-Host "The product key was not saved."
    }
}
