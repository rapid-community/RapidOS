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

echo This script hiding recommendations page on Windows 11 Start Menu.
echo.
echo Still want to proceed?
pause

if %BuildNumber% GEQ 22000 (
    call "%WinDir%\RapidScripts\UtilityScripts\Recommendations\Schedule_RunHide.cmd" > nul 2>&1
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowRecent /t REG_DWORD /d 0 /f > nul 2>&1
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowFrequent /t REG_DWORD /d 0 /f > nul 2>&1
    reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v HideRecentlyAddedApps /t REG_DWORD /d 1 /f > nul 2>&1
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoStartMenuMFUprogramsList /t REG_DWORD /d 1 /f > nul 2>&1
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v ShowOrHideMostUsedApps /t REG_DWORD /d 2 /f > nul 2>&1
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /t REG_DWORD /d 0 /f > nul 2>&1
    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoStartMenuMorePrograms /t REG_DWORD /d 0 /f > nul 2>&1
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoStartMenuMorePrograms /t REG_DWORD /d 0 /f > nul 2>&1
) else (
    echo Likely, you are on Windows 10, Windows 11 is required to run this script.
    pause
    exit /b
)

echo Start menu recommendations have been disabled!
pause
exit /b