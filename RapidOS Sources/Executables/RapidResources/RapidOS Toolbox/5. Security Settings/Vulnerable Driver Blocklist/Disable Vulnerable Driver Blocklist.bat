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

echo Vulnerable Driver Blocklist proctects you from installing malicious drivers.
echo Some games with kernel-level anti-cheats can stop working if you disable this feature.
echo.
echo Still want to proceed?
pause

reg add "HKLM\SYSTEM\CurrentControlSet\Control\CI\Config" /v VulnerableDriverBlocklistEnable /t REG_DWORD /d 0 /f > nul 2>&1

echo Vulnerable Driver Blocklist has been disabled!
pause
exit /b