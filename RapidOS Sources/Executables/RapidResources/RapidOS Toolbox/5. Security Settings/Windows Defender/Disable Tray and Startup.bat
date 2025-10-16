@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

reg add "HKLM\SOFTWARE\Microsoft\Windows Defender Security Center\Systray" /v HideSystray /t REG_DWORD /d 1 /f > nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v SecurityHealth /f > nul 2>&1

echo Remove systray icon and disable startup entry has been completed.
pause
exit /b