# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) { Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow; $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -MyArgument {1}" -f $PSCommandPath, $MyArgument; Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs; exit }

# Terminate OneDrive and initiate uninstallation
Write-Host "Terminating OneDrive process and initiating uninstallation"
taskkill.exe /F /IM "OneDrive.exe"
if (Test-Path "$env:SYSTEMROOT\System32\OneDriveSetup.exe") { & "$env:SYSTEMROOT\System32\OneDriveSetup.exe" /uninstall }
if (Test-Path "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe") { & "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe" /uninstall }

# Remove remaining files
Write-Host "Deleting residual OneDrive files"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:LOCALAPPDATA\Microsoft\OneDrive"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "$env:PROGRAMDATA\Microsoft OneDrive"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "C:\OneDriveTemp"

<# Disable OneDrive in Group Policy
Write-Host "Applying Group Policy settings to disable OneDrive"
$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
if (!(Test-Path $registryPath)) { New-Item -Path $registryPath -Force | Out-Null }
Set-ItemProperty -Path $registryPath -Name "DisableFileSync" -Value 1
Set-ItemProperty -Path $registryPath -Name "DisableFileSyncNGSC" -Value 1
Set-ItemProperty -Path $registryPath -Name "DisableMeteredNetworkFileSync" -Value 0
Set-ItemProperty -Path $registryPath -Name "DisableLibrariesDefaultSaveToOneDrive" -Value 0 #>

# Remove OneDrive from startup and Explorer sidebar
Write-Host "Cleaning up registry and Explorer settings"
reg load "hku\Default" "C:\Users\Default\NTUSER.DAT" > $null 2>&1
reg delete "HKEY_USERS\Default\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "OneDriveSetup" /f > $null 2>&1
reg unload "hku\Default" > $null 2>&1

New-PSDrive -PSProvider "Registry" -Root "HKCU:\Software\Classes" -Name "HKCR" | Out-Null
New-Item -Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Force | Out-Null
Set-ItemProperty -Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name "System.IsPinnedToNameSpaceTree" -Value 0
New-Item -Path "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Force | Out-Null
Set-ItemProperty -Path "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name "System.IsPinnedToNameSpaceTree" -Value 0
Remove-PSDrive "HKCR"

# Delete OneDrive shortcut from Start Menu
Write-Host "Removing OneDrive shortcut from Start Menu"
Remove-Item -Force -ErrorAction SilentlyContinue "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk"

# Get and delete all scheduled tasks related to OneDrive
$onedriveTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*OneDrive*" -or $_.TaskPath -like "*OneDrive*" }
if ($onedriveTasks) {
    foreach ($task in $onedriveTasks) {
        Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
        Write-Host "Deleted task: $($task.TaskName)" -ForegroundColor Red
    }
} else {
    Write-Host "No OneDrive related tasks found to delete." -ForegroundColor Yellow
}