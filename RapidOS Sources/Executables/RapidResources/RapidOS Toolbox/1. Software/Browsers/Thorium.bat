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
echo Thorium Configuration
echo.

echo [1] Install Thorium
echo [2] Tweak Thorium
echo [3] Documentation

set /p choice="Select an option: "

if "%choice%"=="1" (
    echo.
    echo Installing Thorium...
    winget install --id Alex313031.Thorium --silent --force --accept-source-agreements > nul 2>&1
    echo Installed Thorium!
    pause
    goto mainMenu
) else if "%choice%"=="2" (
    echo.
    echo This browser is already good and there is no need to tweak it.
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