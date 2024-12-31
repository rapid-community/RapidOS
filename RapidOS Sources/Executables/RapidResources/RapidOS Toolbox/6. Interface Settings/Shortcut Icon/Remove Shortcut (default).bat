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

echo This script will remove the shortcut icon from your desktop shortcuts, which can make it harder to distinguish shortcuts from actual files.
echo.
echo Still want to proceed?
pause

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons" /v "29" /t REG_SZ /d "C:\Windows\RapidScripts\shortcut.ico,0" /f > nul 2>&1

echo Shortcut Icon has been removed!
pause
exit /b