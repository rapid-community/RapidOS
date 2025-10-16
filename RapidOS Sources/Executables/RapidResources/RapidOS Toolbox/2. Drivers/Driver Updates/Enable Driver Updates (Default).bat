@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" /v "DontSearchWindowsUpdate" /f > nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" /v "DriverUpdateWizardWuSearchEnabled" /f > nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v "ExcludeWUDriversInQualityUpdate" /f > nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v "ExcludeWUDriversInQualityUpdate" /f > nul 2>&1
reg delete "HKCU\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" /v "DontPromptForWindowsUpdate" /f > nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" /v "DontPromptForWindowsUpdate" /f > nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" /v "SearchOrderConfig" /f > nul 2>&1

echo Device driver search from Windows Update has been enabled.
pause
exit /b