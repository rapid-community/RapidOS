# Ensure administrator privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    exit
}

# Path to Layout.xml
$layoutFilePath = Join-Path -Path (Join-Path -Path $env:WinDir -ChildPath "RapidScripts") -ChildPath "Layout.xml"

# Get user profiles
$userProfiles = Get-ChildItem -Path "C:\Users" | Where-Object { $_.PSIsContainer -and $_.Name -ne "Public" -and $_.Name -ne "Default" }

foreach ($userProfile in $userProfiles) {
    $localAppData = Join-Path -Path $userProfile.FullName -ChildPath "AppData\Local\Microsoft\Windows\Shell"

    if (Test-Path -Path $localAppData) {
        $layoutPath = Join-Path -Path $localAppData -ChildPath "LayoutModification.xml"
        
        try {
            # Copy Layout.xml
            Copy-Item -Path $layoutFilePath -Destination $layoutPath -Force
            Write-Output "Copied Layout.xml to $layoutPath"
        } catch {
            Write-Output "Failed to copy Layout.xml to $layoutPath"
        }
    }

    # Clear start.tilegrid
    $userSid = (Get-WmiObject Win32_UserAccount | Where-Object { $_.Name -eq $userProfile.Name }).SID
    $tileGridPath = "Registry::HKEY_USERS\$userSid\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount"

    try {
        $tileGridKeys = Get-ChildItem -Path $tileGridPath | Where-Object { $_.Name -match "start.tilegrid" }
        foreach ($key in $tileGridKeys) {
            Remove-Item -Path $key.PSPath -Recurse -Force
            Write-Output "Cleared start.tilegrid"
        }
    } catch {
        Write-Output "Failed to clear start.tilegrid"
    }
}

# Get the path to AppData
$userAppdata = [System.Environment]::GetFolderPath('LocalApplicationData')

# Find Microsoft.Windows.StartMenuExperienceHost package
$packageDir = Get-ChildItem -Path "$userAppdata\Packages" -Directory | Where-Object { $_.Name -match 'Microsoft.Windows.StartMenuExperienceHost' }

foreach ($d in $packageDir) {
    $files = Get-ChildItem -Path "$($d.FullName)\LocalState" -File | Where-Object { $_.Name -match 'start.*\.bin|start\.bin' }
    
    foreach ($e in $files) {
        # Delete the found files
        Remove-Item -Path $e.FullName -Force -ErrorAction SilentlyContinue
        Write-Output "Deleted file $($e.FullName)"
    }
}

Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Start" -Name "Config" -ErrorAction SilentlyContinue

# Get all Appx packages for all users
<# Breaks W11 Start Menu
$packages = Get-AppxPackage -AllUsers

foreach ($package in $packages) {
    if ($package.PackageFamilyName -like "Microsoft.Windows.Start*") {
        try {
            # Try using Reset-AppxPackage (for Windows 11)
            Reset-AppxPackage $package.PackageFullName -ErrorAction Stop
            Write-Output "Successfully reset package"
        } catch {
            Write-Output "Failed to reset package"
        }
    }
}
#>