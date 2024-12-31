param (
    [string[]]$MyArgument
)

# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) { Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow; $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -MyArgument {1}" -f $PSCommandPath, $MyArgument; Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs; exit }

function Install-Winget {
    Write-Host "Starting installation of dependencies and Winget..."

    # Temporary directory for downloads
    $tempDir = "$env:TEMP\WinGet-Install"
    if (-not (Test-Path -Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir | Out-Null
    }

    # Define URL for the latest release of winget
    $repoApiUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"

    try {
        $response = Invoke-RestMethod -Uri $repoApiUrl
    } catch {
        Write-Host "Failed to retrieve release info. Error: $_" -ForegroundColor Red
        Start-Sleep -Seconds 5
        return
    }

    $msixUrl = $response.assets | Where-Object { $_.name -match ".msixbundle$" } | Select-Object -ExpandProperty browser_download_url
    $licenseUrl = $response.assets | Where-Object { $_.name -match "License.*\.xml$" } | Select-Object -ExpandProperty browser_download_url

    $msixFilePath = "$tempDir\Microsoft.DesktopAppInstaller.msixbundle"
    $licenseFilePath = "$tempDir\winget_license.xml"

    # Download and install VCLibs package
    try {
        Write-Host "Installing VCLibs package..."
        Add-AppxPackage "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -Verbose -ErrorAction Ignore
    } catch {
        Write-Host "VCLibs installation failed. Error: $_" -ForegroundColor Red
    }

    # Download UI XAML package
    try {
        Write-Host "Downloading XAML package..."
        & curl.exe -LSs "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6" -o "$tempDir\microsoft.ui.xaml.2.8.6.zip"
    } catch {
        Write-Host "XAML package download failed. Error: $_" -ForegroundColor Red
    }

    # Extract UI XAML package
    try {
        Write-Host "Extracting XAML package..."
        Expand-Archive "$tempDir\microsoft.ui.xaml.2.8.6.zip" -DestinationPath "$tempDir\XAMLExtracted" -Force
    } catch {
        Write-Host "XAML extraction failed. Error: $_" -ForegroundColor Red
    }

    # Install UI XAML package
    try {
        Write-Host "Installing XAML package..."
        Add-AppPackage "$tempDir\XAMLExtracted\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.8.appx" -Verbose
    } catch {
        Write-Host "XAML installation failed. Error: $_" -ForegroundColor Red
    }

    Write-Host "Dependencies installed successfully."

    # Download the Winget msix
    try {
        Write-Host "Downloading Winget package..."
        & curl.exe -LSs $msixUrl -o $msixFilePath
    } catch {
        Write-Host "Winget package download failed. Error: $_" -ForegroundColor Red
    }

    # Download the License file
    try {
        Write-Host "Downloading Winget license file..."
        & curl.exe -LSs $licenseUrl -o $licenseFilePath
    } catch {
        Write-Host "License file download failed. Error: $_" -ForegroundColor Red
    }

    # Install Winget
    try {
        Write-Host "Installing Winget..."
        Add-AppxProvisionedPackage -Online -PackagePath $msixFilePath -LicensePath $licenseFilePath -Verbose > $null 2>&1
    } catch {
        Write-Host "Winget installation failed. Error: $_" -ForegroundColor Red
    }

    # Remove downloaded install files
    Write-Host "Cleaning up downloaded files..."
    Remove-Item -Path $tempDir -Recurse -Force
    Write-Host "Winget installed successfully."
}

function Install-ViveTool {
    Write-Host "Starting installation of ViveTool..."

    # Define URL for the latest release of ViveTool
    $viveApiUrl = "https://api.github.com/repos/thebookisclosed/ViVe/releases/latest"

    try {
        $response = Invoke-RestMethod -Uri $viveApiUrl
    } catch {
        Write-Host "Failed to retrieve ViVeTool release info. Error: $_" -ForegroundColor Red
        Start-Sleep -Seconds 5
        return
    }

    $isArm64 = ((Get-CimInstance -Class Win32_ComputerSystem).SystemType -match 'ARM64') -or ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64')

    if ($isArm64) {
        $viveToolUrl = $response.assets | Where-Object { $_.name -match "-ARM64CLR.zip$" } | Select-Object -ExpandProperty browser_download_url
    } else {
        $viveToolUrl = $response.assets | Where-Object { $_.name -match ".zip$" -and $_.name -notmatch "-ARM64CLR.zip$" } | Select-Object -ExpandProperty browser_download_url
    }

    $viveToolFilePath = "$env:TEMP\ViVeTool.zip"

    # Download ViVeTool
    try {
        Write-Host "Downloading ViVeTool..."
        & curl.exe -LSs $viveToolUrl -o $viveToolFilePath
    } catch {
        Write-Host "ViVeTool download failed. Error: $_" -ForegroundColor Red
        return
    }

    # Extract ViVeTool
    try {
        Write-Host "Extracting ViVeTool..."
        Expand-Archive -Path $viveToolFilePath -DestinationPath "$env:WinDir\RapidScripts\ViveTool" -Force -ErrorAction Stop
    } catch {
        Write-Host "ViVeTool extraction failed. Error: $_" -ForegroundColor Red
        return
    }

    Write-Host "Cleaning up downloaded files..."
    Remove-Item -Path $viveToolFilePath -Force

    Write-Host "ViVeTool installed successfully."
}

function Install-DefenderSwitcher {
    Write-Host "Starting installation of Defender Switcher..."

    # Define the destination directory
    $destinationDir = Join-Path -Path $env:WinDir -ChildPath "RapidScripts\UtilityScripts"
    if (-not (Test-Path -Path $destinationDir)) {
        try {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        } catch {
            Write-Host "Failed to create directory. Error: $_" -ForegroundColor Red
            return
        }
    }

    # Define URL for the latest release
    $repoApiUrl = "https://api.github.com/repos/instead1337/Defender-Switcher/releases/latest"

    try {
        $response = Invoke-RestMethod -Uri $repoApiUrl
    } catch {
        Write-Host "Failed to retrieve release info. Error: $_" -ForegroundColor Red
        Start-Sleep -Seconds 5
        return
    }

    $exeUrl = $response.assets | Where-Object { $_.name -eq "DefenderSwitcher.exe" } | Select-Object -ExpandProperty browser_download_url

    $exeFilePath = Join-Path -Path $destinationDir -ChildPath "DefenderSwitcher.exe"

    # Download the DefenderSwitcher.exe
    try {
        Write-Host "Downloading Defender Switcher..."
        Invoke-WebRequest -Uri $exeUrl -OutFile $exeFilePath -UseBasicParsing
    } catch {
        Write-Host "DefenderSwitcher.exe download failed. Error: $_" -ForegroundColor Red
        return
    }

    # Check if Windows Defender is running before adding exclusions
    if (Get-Service -Name WinDefend -ErrorAction SilentlyContinue) {
        try {
            Write-Host "Adding DefenderSwitcher.exe to Windows Defender exclusions..."
            Add-MpPreference -ExclusionPath $exeFilePath
            Write-Host "DefenderSwitcher.exe added to exclusions successfully."
        } catch {
            Write-Host "Failed to add DefenderSwitcher.exe to exclusions. Error: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Windows Defender service not found or not running. Skipping adding exclusions."
    }

    Write-Host "DefenderSwitcher installed successfully."
}

function Install-DotNet3.5 {
    # Check if .NET Framework 3.5 is already installed
    $dotNetInstalled = Get-WindowsPackage -Online | Where-Object { $_.PackageName -like "*NetFx3*" }

    if ($dotNetInstalled) {
        Write-Host ".NET Framework 3.5 is already installed." -ForegroundColor Green
        return
    }

    $build = (Get-WmiObject Win32_OperatingSystem).BuildNumber

    $isArm64 = ((Get-CimInstance -Class Win32_ComputerSystem).SystemType -match 'ARM64') -or ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64')
    if ($isArm64) {
        Write-Host "ARM64 system detected. Support is not available at the moment."
        Start-Sleep -Seconds 5
        return
    }

    # Determine the download URL based on the build number
    switch ($build) {
        19045 { $url = "https://rapid-community.ru/downloads/RapidOS-Entries/NetFx3-amd64-19045.cab" }
        22621 { $url = "https://rapid-community.ru/downloads/RapidOS-Entries/NetFx3-amd64-22621.cab" }
        22631 { $url = "https://rapid-community.ru/downloads/RapidOS-Entries/NetFx3-amd64-22631.cab" }
        26100 { $url = "https://rapid-community.ru/downloads/RapidOS-Entries/NetFx3-amd64-26100.cab" }
        default { Write-Host "Build not supported"; return }
    }
    $downloadPath = "$env:SystemRoot\RapidScripts\NetFx3.cab"

    if (!(Test-Path -Path $env:SystemRoot\RapidScripts)) {
        New-Item -ItemType Directory -Path $env:SystemRoot\RapidScripts | Out-Null
    }

    # Download the .NET 3.5 package
    try {
        Write-Host "Downloading .NET 3.5 package..."
        & curl.exe -LSs $url -o $downloadPath
    } catch {
        Write-Host ".NET 3.5 package download failed. Error: $_" -ForegroundColor Red
        return
    }

    # Install the downloaded package
    try {
        Write-Host "Installing .NET 3.5 package..."
        Add-WindowsPackage -Online -PackagePath $downloadPath -NoRestart -IgnoreCheck > $null 2>&1
    } catch {
        Write-Host ".NET 3.5 installation failed. Error: $_" -ForegroundColor Red
        return
    }

    Write-Host "Cleaning up downloaded files..."
    'dism', 'wusa' | ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.Id -Force } }
    Remove-Item -Path $downloadPath -Force

    Write-Host ".NET 3.5 installed successfully."
}

# Function to display usage information
function Show-Usage {
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " .\Install-Software.ps1 -MyArgument <option>" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " - install_winget   : Install latest version of WinGet" -ForegroundColor Gray
    Write-Host " - install_vivetool : Install latest version of ViveTool" -ForegroundColor Gray
    Write-Host " - install_defswitcher : Install latest version of Defender Switcher" -ForegroundColor Gray
    Write-Host " - install_dotnet : Install DotNet cabinet files based on the build number" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Example:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " .\Install-Software.ps1 -MyArgument install_winget" -ForegroundColor White
    Write-Host " .\Install-Software.ps1 -MyArgument install_vivetool" -ForegroundColor White
    Write-Host ""
}

# Check if no arguments were provided
if (-not $MyArgument) {
    Write-Host "Error: No arguments provided." -ForegroundColor Red
    Write-Host ""
    Show-Usage
}

# Function call based on the argument
switch ($MyArgument) {
    "install_winget" { Install-Winget }
    "install_vivetool" { Install-ViVeTool }
    "install_defswitcher" { Install-DefenderSwitcher }
    "install_dotnet" { Install-DotNet3.5 }
        
    default {
        Write-Host "Error: Invalid argument `"$MyArgument`"" -ForegroundColor Red
        Write-Host ""
        Show-Usage
    }
}