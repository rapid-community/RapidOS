@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild') do set BuildNumber=%%A

if %BuildNumber% lss 22000 (
    echo Likely, you are on Windows 10, Windows 11 is required to run this script.
    pause
    exit /b
)

reg delete "HKCU\SOFTWARE\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f > nul 2>&1

echo New Context Menu has been enabled.
pause
exit /b