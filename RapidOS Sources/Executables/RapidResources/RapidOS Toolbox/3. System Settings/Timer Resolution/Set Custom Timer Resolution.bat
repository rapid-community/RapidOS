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

echo Enter desired timer resolution (in microseconds):
set /p timerResolution="Resolution: "

schtasks /delete /tn "SetTimerResolution" /f > nul 2>&1
powershell -ExecutionPolicy Bypass -File "C:\Windows\RapidScripts\UtilityScripts\Timer-Resolution.ps1" -resolution %timerResolution%

echo Timer resolution has been set to %timerResolution% successfully!
pause
exit /b