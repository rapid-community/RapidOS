@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild') do set BuildNumber=%%A

echo This script hiding recommendations page on Windows 11 start menu.
echo.
echo Still want to proceed?
pause

if %BuildNumber% GEQ 22000 (
    reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Education" /v IsEducationEnvironment /t REG_DWORD /d 1 /f > nul 2>&1
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecommendedSection /t REG_DWORD /d 1 /f > nul 2>&1
    reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start" /v HideRecommendedSection /t REG_DWORD /d 1 /f > nul 2>&1
) else (
    echo Likely, you are on Windows 10, Windows 11 is required to run this script.
    pause
    exit /b
)

echo Start menu recommendations have been disabled.
pause
exit /b