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

reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v "GlobalTimerResolutionRequests" /f > nul 2>&1
taskkill /f /im SetTimerResolution.exe > nul 2>&1
schtasks /delete /tn "SetTimerResolution" /f > nul 2>&1

echo Timer resolution has been disabled successfully!
pause
exit /b