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

for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild') do set BuildNumber=%%A

echo This script manages the visibility of settings pages in Windows 10 and 11. It removes unnecessary pages related to telemetry and ads.
echo.
echo Still want to proceed?
pause

if %BuildNumber% lss 22000 (
    echo Detected Windows 10.
    call "%WinDir%\RapidScripts\UtilityScripts\Set-Pages.cmd" -addRapidWin10Def
) else (
    echo Detected Windows 11.
    call "%WinDir%\RapidScripts\UtilityScripts\Set-Pages.cmd" -addRapidWin11Def
)

echo Unnecessary Settings Pages have been removed!
pause
exit /b