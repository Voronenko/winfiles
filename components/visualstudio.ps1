# Configure Visual Studio
if ((Test-Path "hklm:\SOFTWARE\Microsoft\VisualStudio\SxS\VS7") -or (Test-Path "hklm:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\SxS\VS7")) {
    # Configure Visual Studio functions
    function Start-VisualStudio ([string] $solutionFile) {
        $devenv = Join-Path $env:DevEnvDir "devenv.exe"
        if (($solutionFile -eq $null) -or ($solutionFile -eq "")) {
            $solutionFile = (Get-ChildItem -Filter "*.sln" | Select-Object -First 1).Name
        }
        if (($solutionFile -ne $null) -and ($solutionFile -ne "") -and (Test-Path $solutionFile)) {
            Start-Process $devenv -ArgumentList $solutionFile
        } else {
            Start-Process $devenv
        }
    }
    Set-Alias -name vs -Value Start-VisualStudio

    function Start-VisualStudioAsAdmin ([string] $solutionFile) {
        $devenv = Join-Path $env:DevEnvDir "devenv.exe"
        if (($solutionFile -eq $null) -or ($solutionFile -eq "")) {
            $solutionFile = (Get-ChildItem -Filter "*.sln" | Select-Object -First 1).Name
        }
        if (($solutionFile -ne $null) -and ($solutionFile -ne "") -and (Test-Path $solutionFile)) {
            Start-Process $devenv -ArgumentList $solutionFile -Verb "runAs"
        } else {
            Start-Process $devenv -Verb "runAs"
        }
    }
    Set-Alias -name vsadmin -Value Start-VisualStudioAsAdmin

    function Install-VSExtension($url) {
        $vsixInstaller = Join-Path $env:DevEnvDir "VSIXInstaller.exe"
        Write-Output "Downloading ${url}"
        $extensionFile = (curlex $url)
        Write-Output "Installing $($extensionFile.Name)"
        $result = Start-Process -FilePath `"$vsixInstaller`" -ArgumentList "/q $($extensionFile.FullName)" -Wait -PassThru;
    }
}
