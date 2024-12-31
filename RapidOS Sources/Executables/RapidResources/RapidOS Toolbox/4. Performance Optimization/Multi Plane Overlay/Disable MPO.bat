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

for /f "tokens=2 delims==" %%i in ('wmic os get BuildNumber /value') do set build=%%i

if %build% GEQ 26100 (
    echo Your Windows build is %build%, which is 26100 or higher.
    echo Disabling MPO is not recommended for this build.
    set /p continue=Press ENTER to continue and disable MPO anyway, or Ctrl+C to cancel:
    goto :disableMPO
) else (
    echo Your Windows build is %build%, which is below 26100.
    echo Disabling MPO...
    goto :disableMPO
)

:disableMPO
reg add "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayTestMode /t REG_DWORD /d 5 /f > nul 2>&1

echo MPO has been disabled!
pause
exit /b