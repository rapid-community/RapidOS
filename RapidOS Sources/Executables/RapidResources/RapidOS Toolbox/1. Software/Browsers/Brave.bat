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

:mainMenu
cls
echo Brave Configuration
echo.

echo [1] Install Brave
echo [2] Tweak Brave
echo [3] Documentation

set /p choice="Select an option: "

if "%choice%"=="1" (
    echo.
    echo Installing Brave...
    winget install --id Brave.Brave --silent --force --accept-source-agreements --accept-package-agreements > nul 2>&1
    echo Installed Brave!
    pause
    goto mainMenu
) else if "%choice%"=="2" (
    echo.
    echo Optimization for Chromium browsers will be soon.
    pause
    goto mainMenu
) else if "%choice%"=="3" (
    start "" "https://docs.rapid-community.ru/post-installation/browsers/"
    goto mainMenu
) else (
    echo.
    echo Invalid choice
    pause
    goto mainMenu
)

exit /b