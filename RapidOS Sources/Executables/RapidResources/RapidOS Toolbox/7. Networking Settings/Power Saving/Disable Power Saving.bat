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

for %%s in (ULPMode EEE EEELinkAdvertisement AdvancedEEE EnableGreenEthernet EeePhyEnable uAPSDSupport EnablePowerManagement EnableSavePowerNow bLowPowerEnable PowerSaveMode PowerSavingMode SavePowerNowEnabled AutoPowerSaveModeEnabled NicAutoPowerSaver SelectiveSuspend) do (
    powershell -Command "Get-NetAdapter -Physical | Get-NetAdapterAdvancedProperty | Where-Object { $_.RegistryKeyword -eq '%%s' } | Set-NetAdapterAdvancedProperty -RegistryValue 0"
)

echo Network power saving has been disabled!
pause
exit /b