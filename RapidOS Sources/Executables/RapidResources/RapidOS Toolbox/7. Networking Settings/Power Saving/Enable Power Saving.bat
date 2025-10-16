@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

reg add "HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v DefaultPnPCapabilities /t REG_DWORD /d 0 /f > nul 2>&1

for %%s in (ULPMode EEE EEELinkAdvertisement AdvancedEEE EnableGreenEthernet EeePhyEnable uAPSDSupport EnablePowerManagement EnableSavePowerNow bLowPowerEnable PowerSaveMode PowerSavingMode SavePowerNowEnabled AutoPowerSaveModeEnabled NicAutoPowerSaver SelectiveSuspend) do (
    powershell -C "Get-NetAdapter -Physical | Get-NetAdapterAdvancedProperty | ? {$_.RegistryKeyword -eq '%%s'} | Reset-NetAdapterAdvancedProperty"
)

echo Network power saving has been enabled.
pause
exit /b