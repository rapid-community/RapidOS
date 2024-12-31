@echo off
ping -n 1 8.8.8.8 > nul
if errorlevel 1 (
    echo No internet connection detected!
    pause
    exit /b 1
)

echo.
echo This program is not only intended for downloading applications,
echo but also includes a page with system tweaks.
echo.
echo Using page with system tweaks on RapidOS is not recommended.
echo In this case, this program is here because of the huge number of useful applications.
echo.

pause

powershell -Command "irm raw.githubusercontent.com/emadadel4/ITT/main/itt.ps1 | iex"
if errorlevel 1 (
    echo Failed to run the script from GitHub. Trying alternative source...
    powershell -Command "irm bit.ly/ittea | iex"
    if errorlevel 1 (
        echo Failed to run the script from the alternative source.
        pause
        exit /b 1
    )
)