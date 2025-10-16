@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" /v "DontSearchWindowsUpdate" /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" /v "DriverUpdateWizardWuSearchEnabled" /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v "ExcludeWUDriversInQualityUpdate" /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v "ExcludeWUDriversInQualityUpdate" /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" /v "DontPromptForWindowsUpdate" /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" /v "DontPromptForWindowsUpdate" /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" /v "PreventDeviceMetadataFromNetwork" /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" /v "PreventDeviceMetadataFromNetwork" /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" /v "SearchOrderConfig" /t REG_DWORD /d 0 /f > nul 2>&1

echo Device driver search from Windows Update has been disabled.
pause
exit /b