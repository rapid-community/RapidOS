@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

ping -n 1 google.com > nul
if errorlevel 1 (
    echo No internet connection detected!
    pause
    exit /b 1
)

echo This installation method is not developed by me. It is sourced from the following repository:
echo https://github.com/NelloKudo/Apple-Mobile-Drivers-Installer/
pause

powershell -C "iex (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/NelloKudo/Apple-Mobile-Drivers-Installer/main/AppleDrivInstaller.ps1')"