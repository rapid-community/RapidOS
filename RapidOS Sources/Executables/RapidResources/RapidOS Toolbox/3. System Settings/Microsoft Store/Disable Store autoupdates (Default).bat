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
  
reg add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v AutoDownload /t REG_DWORD /d 4 /f > nul 2>&1
reg add "HKCU\Software\Policies\Microsoft\WindowsStore" /v DisableOSUpgrade /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v DisableOSUpgrade /t REG_DWORD /d 1 /f > nul 2>&1

echo Microsoft Store updates have been disabled!
pause
exit /b