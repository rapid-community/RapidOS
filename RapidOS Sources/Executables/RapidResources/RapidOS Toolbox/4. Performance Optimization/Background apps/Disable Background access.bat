@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo Disabling Background access to apps can break notifications, Windows Spotlight, can cause KGL mismatch in Xbox Game Bar and other problems.
echo.
echo Still want to proceed?
pause

reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BackgroundAppGlobalToggle /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BackgroundAppGlobalToggle /t REG_DWORD /d 0 /f > nul 2>&1

echo Background access to apps has been disabled.
pause
exit /b