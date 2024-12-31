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

echo Configuring TCP settings...

netsh int tcp set global initialRto=3000 > nul 2>&1
netsh int tcp set global MaxSynRetransmissions=2 > nul 2>&1
netsh int tcp set global pacingprofile=default > nul 2>&1
netsh int tcp set heuristics enabled > nul 2>&1
netsh int teredo set state type=client > nul 2>&1
netsh int teredo set state servername=default > nul 2>&1
netsh int tcp set supplemental internet congestionprovider=default > nul 2>&1

echo TCP settings have been restored to their default settings!
pause
exit /b