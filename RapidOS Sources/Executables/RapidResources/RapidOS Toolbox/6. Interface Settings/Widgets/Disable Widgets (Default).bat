@echo off
setlocal

whoami /user | find /i "S-1-5-18" > nul 2>&1 || (
    powershell -C "RunAsTI '%~f0' %*"
    exit /b
)

sc stop UCPD > nul 2>&1
sc config UCPD start= disabled > nul 2>&1

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" /v "EnableFeeds" /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" /v "ShellFeedsTaskbarViewMode" /t REG_DWORD /d 2 /f > nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarDa" /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v "AllowNewsAndInterests" /t REG_DWORD /d 0 /f > nul 2>&1

sc config UCPD start= auto > nul 2>&1

echo Widgets have been disabled.
pause
exit /b