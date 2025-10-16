@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BackgroundAppGlobalToggle /f > nul 2>&1
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /f > nul 2>&1
reg delete "HCLM\Software\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsRunInBackground /f > nul 2>&1

reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v ContentDeliveryAllowed /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v FeatureManagementEnabled /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContentEnabled /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338387Enabled /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenOverlayEnabled /t REG_DWORD /d 1 /f > nul 2>&1

reg delete "HCLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableCloudOptimizedContent /f > nul 2>&1
reg delete "HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsSpotlightFeatures /f > nul 2>&1
reg delete "HCLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableSoftLanding /f > nul 2>&1

reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" /t REG_DWORD /d 0 /f > nul 2>&1

echo Spotlight has been enabled successfully.
pause
exit /b