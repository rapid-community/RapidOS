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

powershell -ExecutionPolicy Bypass -Command "& $env:WinDir\RapidScripts\UtilityScripts\Power-Optimizer.ps1 -MyArgument maximized_performance"

echo Maximized Performance mode has been enabled!
pause
exit /b