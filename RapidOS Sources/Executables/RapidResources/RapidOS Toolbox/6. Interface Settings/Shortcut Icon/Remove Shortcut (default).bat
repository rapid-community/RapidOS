@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo This script will remove the shortcut icon from your desktop shortcuts, which can make it harder to distinguish shortcuts from actual files.
echo.
echo Still want to proceed?
pause

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons" /v "29" /t REG_SZ /d "%WinDir%\RapidScripts\shortcut.ico,0" /f > nul 2>&1

echo Shortcut Icon has been removed.
pause
exit /b