@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

wmic computersystem get systemtype | findstr /i "ARM64" >nul && set "isArm64=true" || (
    if "%PROCESSOR_ARCHITECTURE%"=="ARM64" (set "isArm64=true") else (set "isArm64=false")
)

if "%isArm64%"=="true" (
    echo This system is ARM64.
	echo.
	echo Fault Tolerant Heap doesn't exist on ARM64 systems.
) else (
	reg add "HKLM\SOFTWARE\Microsoft\FTH" /v Enabled /t REG_DWORD /d 1 /f > nul 2>&1
    echo Fault Tolerant Heap has been enabled.
)

pause
exit /b