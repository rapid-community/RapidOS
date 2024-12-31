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

powershell -ExecutionPolicy Bypass -File "C:\Windows\RapidScripts\UtilityScripts\Manage-Indexing.ps1" -MyArgument enable_indexing

echo Indexing has been enabled successfully!
pause
exit /b