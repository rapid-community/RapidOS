@echo off
setlocal

set "___args="%~f0" %*"
fltmc > nul 2>&1 || (
	powershell -c "Start-Process -Verb RunAs -FilePath 'cmd' -ArgumentList """/c $env:___args"""" 2> nul || (
		echo You must run this script as admin.
		if "%*"=="" pause
		exit /b 1
	)
	exit /b
)

ping -n 1 8.8.8.8 > nul
if errorlevel 1 (
    echo No internet connection detected!
    pause
    exit /b 1
)

echo Please note: This installation method is not developed by me. It is sourced from the following repository:
echo https://github.com/NelloKudo/Apple-Mobile-Drivers-Installer/
pause

cls
powershell -ExecutionPolicy Bypass -Command "iex (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/NelloKudo/Apple-Mobile-Drivers-Installer/main/AppleDrivInstaller.ps1')"
pause