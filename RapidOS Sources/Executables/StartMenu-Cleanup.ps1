# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) { Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow; $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -MyArgument {1}" -f $PSCommandPath, $MyArgument; Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs; exit }

# Layout XML for Start Menu and Taskbar (yes, taskbar included)
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

# Save the layout XML to system folder
$startMenuLayoutPath = Join-Path -Path $env:WinDir -ChildPath "StartMenuLayout.xml"
$layoutXmlContent | Out-File -FilePath $startMenuLayoutPath -Encoding UTF8
Write-Host "Saved layout to $startMenuLayoutPath" -ForegroundColor Green

# Get user profiles (exclude Public and Default)
$userProfiles = Get-ChildItem -Path "C:\Users" | Where-Object { $_.PSIsContainer -and $_.Name -notin @("Public", "Default") }

foreach ($userProfile in $userProfiles) {
    # Path to the user's shell folder
    $localAppData = Join-Path -Path $userProfile.FullName -ChildPath "AppData\Local\Microsoft\Windows\Shell"

    # If the shell folder exists, create the user's LayoutModification.xml
    if (Test-Path -Path $localAppData) {
        $layoutPath = Join-Path -Path $localAppData -ChildPath "LayoutModification.xml"
        $layoutXmlContent | Out-File -FilePath $layoutPath -Encoding UTF8
        Write-Host "Created LayoutModification.xml" -ForegroundColor Green
    } else {
        Write-Host "Could not find folder: $localAppData" -ForegroundColor Red
    }

    # Set registry value for the Start Menu layout
    $registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
    if (-not (Test-Path $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }
    New-ItemProperty -Path $registryPath -Name "StartLayoutFile" -Value $startMenuLayoutPath -PropertyType String -Force
    Write-Host "Registry set for Start Layout" -ForegroundColor Green

    # Clear start.tilegrid registry entries
    $userSid = (Get-WmiObject Win32_UserAccount | Where-Object { $_.Name -eq $userProfile.Name }).SID
    $tileGridPath = "Registry::HKEY_USERS\$userSid\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount"
    if (Test-Path -Path $tileGridPath) {
        Get-ChildItem -Path $tileGridPath | Where-Object { $_.Name -match "start.tilegrid" } | Remove-Item -Recurse -Force
        Write-Host "Cleared start.tilegrid entries for $userSid" -ForegroundColor Green
    } else {
        Write-Host "No start.tilegrid found for $userSid" -ForegroundColor Red
    }

    # Delete unnecessary Start Menu files
    $userAppdata = [System.Environment]::GetFolderPath('LocalApplicationData')
    $packageDir = Get-ChildItem -Path "$userAppdata\Packages" -Directory | Where-Object { $_.Name -match 'Microsoft.Windows.StartMenuExperienceHost' }

    foreach ($d in $packageDir) {
        $files = Get-ChildItem -Path "$($d.FullName)\LocalState" -File | Where-Object { $_.Name -match 'start.*\.bin|start\.bin' }
        foreach ($e in $files) {
            Remove-Item -Path $e.FullName -Force
            Write-Host "Deleted file: $($e.FullName)" -ForegroundColor Green
        }
    }

    # Re-register the Start Menu Experience Host app
    Get-AppxPackage -AllUsers Microsoft.Windows.ShellExperienceHost | ForEach-Object {
        Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"
    }

    # Remove ads from the Start Menu for this user
    $startMenuPath = "Registry::HKEY_USERS\$userSid\SOFTWARE\Microsoft\Windows\CurrentVersion\Start"
    if (Test-Path -Path $startMenuPath) {
        Remove-ItemProperty -Path $startMenuPath -Name "Config" -ErrorAction SilentlyContinue
        Write-Host "Removed Start Menu ads for user SID: $userSid" -ForegroundColor Green
    } else {
        Write-Host "No ads registry found for SID: $userSid" -ForegroundColor Red
    }
}