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
echo Chrome Configuration
echo.

echo [1] Install Chrome
echo [2] Tweak Chrome
echo [3] Documentation

set /p choice="Select an option: "

if "%choice%"=="1" (
    echo.
    echo Installing Chrome...
    winget install --id Google.Chrome --silent --force --accept-source-agreements --accept-package-agreements > nul 2>&1
    echo Installed Chrome!
    pause
    goto mainMenu
) else if "%choice%"=="2" (
    echo.
    echo Optimization for Chromium browsers will be soon.
    echo But you can install uBlockOrigin Lite on it.
    echo.
    echo Press any key if you want to continue.
    pause
    echo Installing uBlockOrigin on Chrome
    powershell -ExecutionPolicy Bypass -File "C:\Windows\RapidScripts\UtilityScripts\Browsers-Optimization.ps1" -MyArgument install_ublockorigin
    echo uBlockOrigin has been installed!
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