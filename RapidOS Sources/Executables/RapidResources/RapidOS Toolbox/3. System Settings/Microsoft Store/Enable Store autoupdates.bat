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
  
reg delete "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v AutoDownload /f > nul 2>&1
reg delete "HKCU\Software\Policies\Microsoft\WindowsStore" /v DisableOSUpgrade /f > nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\WindowsStore" /v DisableOSUpgrade /f > nul 2>&1

echo Microsoft Store updates have been enabled!
pause
exit /b