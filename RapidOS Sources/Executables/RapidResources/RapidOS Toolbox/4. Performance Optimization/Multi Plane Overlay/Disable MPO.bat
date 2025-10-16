@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

reg add "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayTestMode /t REG_DWORD /d 5 /f > nul 2>&1

echo MPO has been disabled.
pause
exit /b