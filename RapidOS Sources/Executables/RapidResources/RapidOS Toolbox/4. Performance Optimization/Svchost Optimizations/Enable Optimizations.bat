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

echo Optimization of svchost (specifically its parameter SvcHostSplitThresholdInKB) can break XboxGipSvc.
echo However, this doesn't mean that svchost optimization won't break other applications as well, so proceed with caution at your own risk.
echo.
echo Still want to proceed?
pause

for /f "tokens=2 delims==" %%i in ('wmic computersystem get TotalPhysicalMemory /value') do set ram=%%i
set /a ram=ram / 1024

reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v SvcHostSplitThresholdInKB /t REG_DWORD /d %ram% /f > nul 2>&1

del /f /q "%PROGRAMDATA%\Microsoft\Diagnosis\ETLLogs\AutoLogger\AutoLogger-Diagtrack-Listener.etl" > nul 2>&1

set "icaclsCommand=icacls ""%PROGRAMDATA%\Microsoft\Diagnosis\ETLLogs\AutoLogger"" /deny SYSTEM:`"(OI)(CI)F`"" 
%icaclsCommand% >nul 2>&1

echo SvcHost processes has been optimized!
pause
exit /b