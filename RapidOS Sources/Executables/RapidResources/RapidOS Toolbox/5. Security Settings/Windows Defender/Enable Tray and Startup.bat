@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray" /v HideSystray /f > nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v SecurityHealth /t REG_EXPAND_SZ /d "%WinDir%\System32\SecurityHealthSystray.exe" /f > nul 2>&1

echo Revert systray icon and startup entry has been completed.
pause
exit /b