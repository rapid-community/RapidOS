@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /f
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BackgroundAppGlobalToggle /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BackgroundAppGlobalToggle /f

echo Background access to apps has been enabled.
pause
exit /b