@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

for %%s in (ULPMode EEE EEELinkAdvertisement AdvancedEEE EnableGreenEthernet EeePhyEnable uAPSDSupport EnablePowerManagement EnableSavePowerNow bLowPowerEnable PowerSaveMode PowerSavingMode SavePowerNowEnabled AutoPowerSaveModeEnabled NicAutoPowerSaver SelectiveSuspend) do (
    powershell -C "Get-NetAdapter -Physical | Get-NetAdapterAdvancedProperty | ? {$_.RegistryKeyword -eq '%%s'} | Set-NetAdapterAdvancedProperty -RegistryValue 0"
)

echo Network power saving has been disabled.
pause
exit /b