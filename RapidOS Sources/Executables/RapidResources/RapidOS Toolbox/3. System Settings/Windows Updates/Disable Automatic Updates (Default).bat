@echo off

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -c "$f='%~f0'; $lines=Get-Content $f; $idx=$lines.IndexOf(':PS'); iex ($lines[($idx+1)..($lines.Length-1)] -join [Environment]::NewLine)"
exit /b

:PS
$noop = Join-Path $env:WinDir 'system32\systray.exe'
$ifeo = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
$exe = 'Windows10UpgraderApp', 'setupprep', 'Windows10Upgrade', 'WindowsUpdateElevatedInstaller',
       'WindowsUpdateBox', 'Windows11InstallationAssistant', 'SetupHost', 'wuauclt',
       'MoUsoCoreWorker', 'sedlauncher', 'sedsvc', 'updateassistant', 'usoclient'

foreach ($item in $exe) {
    Set-RegistryValue -Path "$ifeo\$item.exe" -Name "Debugger" -Type String -Value $noop *>$null
    taskkill.exe /im "$item.exe" /t /f *>$null
}

$pause = (Get-Date).AddDays(500).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$today = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$regPath = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'

Set-RegistryValue -Path $regPath -Name "PauseUpdatesExpiryTime" -Type String -Value $pause
Set-RegistryValue -Path $regPath -Name "PauseFeatureUpdatesEndTime" -Type String -Value $pause
Set-RegistryValue -Path $regPath -Name "PauseFeatureUpdatesStartTime" -Type String -Value $today
Set-RegistryValue -Path $regPath -Name "PauseQualityUpdatesEndTime" -Type String -Value $pause
Set-RegistryValue -Path $regPath -Name "PauseQualityUpdatesStartTime" -Type String -Value $today
Set-RegistryValue -Path $regPath -Name "PauseUpdatesStartTime" -Type String -Value $today

Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" -Type DWORD -Value 1

& "$env:WinDir\RapidScripts\Set-Pages.cmd" -add windowsupdate *>$null

Write-Host "Automatic Updates have been disabled."
pause
exit