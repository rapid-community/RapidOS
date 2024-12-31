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

netsh int tcp set global initialRto=2000 > nul 2>&1
netsh int tcp set global MaxSynRetransmissions=2 > nul 2>&1
netsh int tcp set global pacingprofile=off > nul 2>&1
netsh int tcp set heuristics disabled > nul 2>&1
netsh int teredo set state type=enterpriseclient > nul 2>&1
netsh int teredo set state servername=default > nul 2>&1
netsh int tcp set supplemental internet congestionprovider=default > nul 2>&1

for /f "tokens=3" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuild') do set BuildNumber=%%A
if %BuildNumber% GEQ 26100 (
    netsh int tcp set supplemental internet congestionprovider=cubic > nul 2>&1
)

echo TCP settings configured successfully!
pause
exit /b