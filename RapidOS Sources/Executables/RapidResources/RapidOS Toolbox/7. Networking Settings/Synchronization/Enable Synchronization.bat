@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync" /v "SyncPolicy" /f > nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Personalization" /v "Enabled" /f > nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\BrowserSettings" /v "Enabled" /f > nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Credentials" /v "Enabled" /f > nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Language" /v "Enabled" /f > nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Accessibility" /v "Enabled" /f > nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Windows" /v "Enabled" /f > nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Messaging" /v "AllowMessageSync" /f > nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "AllowCrossDeviceClipboard" /f > nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration" /v "IsResumeAllowed" /f > nul 2>&1
reg delete "HKLM\System\CurrentControlSet\Control\FeatureManagement\Overrides\8\1387020943" /v "EnabledState" /f > nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "SyncDisabled" /f > nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\mobsync.exe" /v "Debugger" /f > nul 2>&1

sc config OneSyncSvc start= auto > nul 2>&1
net start OneSyncSvc > nul 2>&1

echo Syncing has been enabled.
pause
exit /b