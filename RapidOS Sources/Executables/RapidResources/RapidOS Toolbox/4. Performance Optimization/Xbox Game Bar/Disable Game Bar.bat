@echo off
setlocal

whoami /user | find /i "S-1-5-18" > nul 2>&1 || (
	call MinSudo.exe -Ti -P "%~f0" %* | more +3
	exit /b
)

echo Disabling these Game Bar features might affect performance on AMD Ryzen 7000 and 9000 series processors. However, this does not mean it won't affect other processors. Proceed with caution.
echo.
echo Still want to proceed?
pause

reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f > nul 2>&1

reg add "HKCU\Software\Microsoft\GameBar" /v GamePanelStartupTipIndex /t REG_DWORD /d 3 /f > nul 2>&1
reg add "HKCU\Software\Microsoft\GameBar" /v ShowStartupPanel /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKCU\Software\Microsoft\GameBar" /v UseNexusForGameBarEnabled /t REG_DWORD /d 0 /f > nul 2>&1

reg add "HKLM\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter" /v ActivationType /t REG_DWORD /d 0 /f > nul 2>&1

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR" /v value /t REG_DWORD /d 0 /f > nul 2>&1

echo Game Bar features have been disabled!
pause
exit /b