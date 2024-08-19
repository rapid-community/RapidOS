# Ensure administrator privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    exit
}

# Terminate OneDrive process
Write-Output "Terminating OneDrive process"
taskkill.exe /F /IM "OneDrive.exe"

# Start the uninstallation process
Write-Output "Initiating uninstallation"
if (Test-Path "$env:systemroot\System32\OneDriveSetup.exe") {
    & "$env:systemroot\System32\OneDriveSetup.exe" /uninstall
}
if (Test-Path "$env:systemroot\SysWOW64\OneDriveSetup.exe") {
    & "$env:systemroot\SysWOW64\OneDriveSetup.exe" /uninstall
}

# Delete remaining files
Write-Output "Deleting residual files"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:localappdata\Microsoft\OneDrive"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:programdata\Microsoft OneDrive"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "C:\OneDriveTemp"

# Disable OneDrive through Group Policy
Write-Output "Disabling OneDrive via Group Policy"
$keyPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\OneDrive"
if (!(Test-Path $keyPath)) {
    New-Item -Path $keyPath -Force -ErrorAction SilentlyContinue
}
Set-ItemProperty -Path $keyPath -Name "DisableFileSyncNGSC" -Value 1

# Remove any scheduled tasks related to OneDrive
Write-Output "Removing scheduled tasks for OneDrive"
$task = Get-ScheduledTask -TaskPath '\' -TaskName 'OneDrive*' -ErrorAction SilentlyContinue
if ($task) {
    $task | Unregister-ScheduledTask -Confirm:$false
}

# Remove OneDrive from the run registry key
Write-Output "Deleting OneDrive run registry entry"
reg load "hku\Default" "C:\Users\Default\NTUSER.DAT" > $null 2>&1
reg delete "HKEY_USERS\Default\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f > $null 2>&1
reg unload "hku\Default" > $null 2>&1

# Remove OneDrive from the Windows Explorer sidebar
Write-Output "Removing OneDrive from Windows Explorer sidebar"
New-PSDrive -PSProvider "Registry" -Root "HKCU:\Software\Classes" -Name "HKCR" | Out-Null
New-Item -Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name "System.IsPinnedToNameSpaceTree" -Value 0
New-Item -Path "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Force -ErrorAction SilentlyContinue | Out-Null
Set-ItemProperty -Path "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name "System.IsPinnedToNameSpaceTree" -Value 0
Remove-PSDrive "HKCR"

# Remove the OneDrive shortcut from the Start menu
Write-Output "Deleting OneDrive shortcut from Start Menu"
Remove-Item -Force -ErrorAction SilentlyContinue "$env:userprofile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"

# Additional parameters for OneDrive from proper disable
$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"

if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

Set-ItemProperty -Path $registryPath -Name "DisableFileSync" -Value 1 -Type DWord
Set-ItemProperty -Path $registryPath -Name "DisableFileSyncNGSC" -Value 1 -Type DWord
Set-ItemProperty -Path $registryPath -Name "DisableMeteredNetworkFileSync" -Value 0 -Type DWord
Set-ItemProperty -Path $registryPath -Name "DisableLibrariesDefaultSaveToOneDrive" -Value 0 -Type DWord
