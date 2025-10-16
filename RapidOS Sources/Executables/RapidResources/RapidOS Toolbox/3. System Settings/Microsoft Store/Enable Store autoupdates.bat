@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)
  
reg delete "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v AutoDownload /f > nul 2>&1

echo Microsoft Store updates have been enabled.
pause
exit /b