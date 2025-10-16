@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild') do set BuildNumber=%%A

if %BuildNumber% GEQ 22000 (
    reg delete "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Education" /v IsEducationEnvironment /f > nul 2>&1
    reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v HideRecommendedSection /f > nul 2>&1
    reg delete "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start" /v HideRecommendedSection /f > nul 2>&1
) else (
    echo Likely, you are on Windows 10, Windows 11 is required to run this script.
    pause
    exit /b
)

echo Start menu recommendations have been enabled.
pause
exit /b