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

for /f "delims=" %%G in ('powershell -NoProfile -Command "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB -as [int]"') do set TotalMemoryGB=%%G

echo Configuring visual effects

rem Show icons with text
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v IconsOnly /t REG_DWORD /d 0 /f > nul 2>&1

rem Enable listview shadows
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ListviewShadow /t REG_DWORD /d 1 /f > nul 2>&1

rem Enable full window drag
reg add "HKCU\Control Panel\Desktop" /v DragFullWindows /t REG_DWORD /d 1 /f > nul 2>&1

rem Disable Aero Peek
reg add "HKCU\Software\Microsoft\Windows\DWM" /v EnableAeroPeek /t REG_DWORD /d 0 /f > nul 2>&1

rem Enable ClearType font smoothing
reg add "HKCU\Control Panel\Desktop" /v FontSmoothing /t REG_DWORD /d 2 /f > nul 2>&1

rem Set visual effects and performance balance
reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f > nul 2>&1

rem Set balanced visual effects
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 3 /f > nul 2>&1

if %TotalMemoryGB% LSS 8 (
    echo System has less than 8GB of RAM. Applying performance settings.

    rem Disable taskbar animations
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 0 /f > nul 2>&1

    rem Disable thumbnail previews
    reg add "HKCU\Software\Microsoft\Windows\DWM" /v AlwaysHibernateThumbnails /t REG_DWORD /d 0 /f > nul 2>&1

    rem Disable window minimize animations
    reg add "HKCU\Control Panel\Desktop" /v MinAnimate /t REG_DWORD /d 0 /f > nul 2>&1
) else (
    echo System has 8GB or more RAM. Applying aesthetics settings.

    rem Enable taskbar animations
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 1 /f > nul 2>&1

    rem Enable thumbnail previews
    reg add "HKCU\Software\Microsoft\Windows\DWM" /v AlwaysHibernateThumbnails /t REG_DWORD /d 1 /f > nul 2>&1

    rem Enable window minimize animations
    reg add "HKCU\Control Panel\Desktop" /v MinAnimate /t REG_DWORD /d 1 /f > nul 2>&1
)

echo Visual Effects have been applied!
pause
exit /b