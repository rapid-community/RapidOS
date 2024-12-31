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

reg add "HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v DefaultPnPCapabilities /t REG_DWORD /d 0 /f > nul 2>&1

for %%s in (ULPMode EEE EEELinkAdvertisement AdvancedEEE EnableGreenEthernet EeePhyEnable uAPSDSupport EnablePowerManagement EnableSavePowerNow bLowPowerEnable PowerSaveMode PowerSavingMode SavePowerNowEnabled AutoPowerSaveModeEnabled NicAutoPowerSaver SelectiveSuspend) do (
    powershell -Command "Get-NetAdapter -Physical | Get-NetAdapterAdvancedProperty | Where-Object { $_.RegistryKeyword -eq '%%s' } | Reset-NetAdapterAdvancedProperty"
)

echo Network power saving has been enabled!
pause
exit /b