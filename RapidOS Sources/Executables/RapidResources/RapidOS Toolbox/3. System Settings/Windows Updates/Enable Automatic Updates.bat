@echo off

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -c "$f='%~f0'; $lines=Get-Content $f; $idx=$lines.IndexOf(':PS'); iex ($lines[($idx+1)..($lines.Length-1)] -join [Environment]::NewLine)"
exit /b

:PS
$exe = 'Windows10UpgraderApp', 'setupprep', 'Windows10Upgrade', 'WindowsUpdateElevatedInstaller',
       'WindowsUpdateBox', 'Windows11InstallationAssistant', 'SetupHost', 'wuauclt',
       'MoUsoCoreWorker', 'sedlauncher', 'sedsvc', 'updateassistant', 'usoclient'

foreach ($item in $exe) {
    reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$item.exe" /v "Debugger" /f *>$null
}

$regPath = 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
reg delete "$regPath" /v "PauseFeatureUpdatesStartTime" /f *>$null
reg delete "$regPath" /v "PauseFeatureUpdatesEndTime" /f *>$null
reg delete "$regPath" /v "PauseQualityUpdatesStartTime" /f *>$null
reg delete "$regPath" /v "PauseQualityUpdatesEndTime" /f *>$null
reg delete "$regPath" /v "PauseUpdatesStartTime" /f *>$null
reg delete "$regPath" /v "PauseUpdatesExpiryTime" /f *>$null

reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "UseWUServer" /f *>$null

& "$env:WinDir\RapidScripts\Set-Pages.cmd" -remove windowsupdate *>$null

Write-Host "Automatic Updates have been enabled."
pause
exit