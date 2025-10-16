@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync" /v "SyncPolicy" /t REG_DWORD /d 5 /f > nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Personalization" /v "Enabled" /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\BrowserSettings" /v "Enabled" /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Credentials" /v "Enabled" /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Language" /v "Enabled" /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Accessibility" /v "Enabled" /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Windows" /v "Enabled" /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Messaging" /v "AllowMessageSync" /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "AllowCrossDeviceClipboard" /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration" /v "IsResumeAllowed" /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\System\CurrentControlSet\Control\FeatureManagement\Overrides\8\1387020943" /v "EnabledState" /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "SyncDisabled" /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\mobsync.exe" /v "Debugger" /t REG_SZ /d "%WinDir%\System32\taskkill.exe" /f > nul 2>&1

net stop OneSyncSvc > nul 2>&1
sc config OneSyncSvc start= disabled > nul 2>&1

echo Syncing has been disabled.
pause
exit /b