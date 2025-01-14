@echo off
setlocal

whoami /user | find /i "S-1-5-18" > nul 2>&1 || (
	call RunAsTI.cmd "%~f0" %*
	exit /b
)

for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild') do set BuildNumber=%%A

if %BuildNumber% GEQ 22000 (
    sc.exe delete HideRecommendedService > nul 2>&1
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowRecent /f > nul 2>&1
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowFrequent /f > nul 2>&1
    reg delete "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v HideRecentlyAddedApps /f > nul 2>&1
    reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoStartMenuMFUprogramsList /f > nul 2>&1
    reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v ShowOrHideMostUsedApps /f > nul 2>&1
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /f > nul 2>&1
    reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoStartMenuMorePrograms /f > nul 2>&1
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoStartMenuMorePrograms /f > nul 2>&1
) else (
    echo Likely, you are on Windows 10, Windows 11 is required to run this script.
    pause
    exit /b
)

echo Start menu recommendations have been enabled!
pause
exit /b