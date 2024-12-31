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

wmic computersystem get systemtype | findstr /i "ARM64" >nul && set "isArm64=true" || (
    if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (set "isArm64=true") else (set "isArm64=false")
)

if "%isArm64%"=="true" (
    echo This system is ARM64.
	echo.
	echo Fault Tolerant Heap doesn't exist on ARM64 systems.
	pause
    exit /b
) else (
	reg add "HKLM\SOFTWARE\Microsoft\FTH" /v Enabled /t REG_DWORD /d 0 /f > nul 2>&1
    echo Fault Tolerant Heap has been disabled!
    pause
    exit /b
)