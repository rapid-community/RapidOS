# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    exit
}

# Layout content
$layoutXmlContent = @'
<LayoutModificationTemplate xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" Version="1" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
    <LayoutOptions StartTileGroupCellWidth="6" />
    <DefaultLayoutOverride>
        <StartLayoutCollection>
            <defaultlayout:StartLayout GroupCellWidth="6" />
        </StartLayoutCollection>
    </DefaultLayoutOverride>
    <CustomTaskbarLayoutCollection PinListPlacement="Replace">
        <defaultlayout:TaskbarLayout>
            <taskbar:TaskbarPinList>
                <taskbar:DesktopApp DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\File Explorer.lnk" />
            </taskbar:TaskbarPinList>
        </defaultlayout:TaskbarLayout>
    </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
'@

# Define the path to save StartMenuLayout.xml in the Windows directory
$startMenuLayoutPath = Join-Path -Path $env:WinDir -ChildPath "StartMenuLayout.xml"

# Save the layout XML content to the specified path
$layoutXmlContent | Out-File -FilePath $startMenuLayoutPath -Encoding UTF8
Write-Host "Saved Layout XML content to $startMenuLayoutPath" -ForegroundColor Green

# Retrieve user profiles, excluding Public and Default
$userProfiles = Get-ChildItem -Path "C:\Users" | Where-Object { $_.PSIsContainer -and $_.Name -notin @("Public", "Default") }

foreach ($userProfile in $userProfiles) {
    # Define path for the user's Shell directory
    $localAppData = Join-Path -Path $userProfile.FullName -ChildPath "AppData\Local\Microsoft\Windows\Shell"

    # Check if the directory exists and create LayoutModification.xml for each user
    if (Test-Path -Path $localAppData) {
        $layoutPath = Join-Path -Path $localAppData -ChildPath "LayoutModification.xml"
        $layoutXmlContent | Out-File -FilePath $layoutPath -Encoding UTF8
        Write-Host "Created LayoutModification.xml at $layoutPath" -ForegroundColor Green
    } else {
        Write-Host "Path does not exist: $localAppData" -ForegroundColor Red
    }

    # Set registry entry for the Start Menu Layout for each user
    $registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    if (-not (Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }
    New-ItemProperty -Path $registryPath -Name "StartLayoutFile" -Value $startMenuLayoutPath -PropertyType String -Force
    Write-Host "Added registry entries for Start Menu Layout for $($userProfile.Name)" -ForegroundColor Green

    # Clear start.tilegrid registry entries
    $userSid = (Get-WmiObject Win32_UserAccount | Where-Object { $_.Name -eq $userProfile.Name }).SID
    $tileGridPath = "Registry::HKEY_USERS\$userSid\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount"
    if (Test-Path -Path $tileGridPath) {
        Get-ChildItem -Path $tileGridPath | Where-Object { $_.Name -match "start.tilegrid" } | Remove-Item -Recurse -Force
        Write-Host "Cleared start.tilegrid entries for SID $userSid" -ForegroundColor Green
    } else {
        Write-Host "Registry path does not exist: $tileGridPath" -ForegroundColor Red
    }
}

# Delete start menu files associated with StartMenuExperienceHost
$userAppdata = [System.Environment]::GetFolderPath('LocalApplicationData')
$packageDir = Get-ChildItem -Path "$userAppdata\Packages" -Directory | Where-Object { $_.Name -match 'Microsoft.Windows.StartMenuExperienceHost' }
Get-AppxPackage -AllUsers Microsoft.Windows.ShellExperienceHost | ForEach-Object {
    Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"
}

foreach ($d in $packageDir) {
    $files = Get-ChildItem -Path "$($d.FullName)\LocalState" -File | Where-Object { $_.Name -match 'start.*\.bin|start\.bin' }
    foreach ($e in $files) {
        Remove-Item -Path $e.FullName -Force
        Write-Host "Deleted file $($e.FullName)" -ForegroundColor Green
    }
}

# Remove Start Menu ads
$startMenuPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Start"
if (Test-Path -Path $startMenuPath) {
    Remove-ItemProperty -Path $startMenuPath -Name "Config" -ErrorAction SilentlyContinue
    Write-Host "Removed Start menu config registry entry from $startMenuPath" -ForegroundColor Green
} else {
    Write-Host "Registry path does not exist: $startMenuPath" -ForegroundColor Red
}

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