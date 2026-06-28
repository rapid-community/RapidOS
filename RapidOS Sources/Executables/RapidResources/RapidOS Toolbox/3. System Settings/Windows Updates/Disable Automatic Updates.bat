@echo off

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -c "$f='%~f0'; $lines=Get-Content $f; $idx=$lines.IndexOf(':PS'); iex ($lines[($idx+1)..($lines.Length-1)] -join [Environment]::NewLine)"
exit /b

:PS
$noop = "$env:SystemRoot\System32\systray.exe"
$ifeo = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
$exe = 'Windows10UpgraderApp', 'setupprep', 'Windows10Upgrade', 'WindowsUpdateElevatedInstaller',
       'WindowsUpdateBox', 'Windows11InstallationAssistant', 'SetupHost', 'wuauclt',
       'MoUsoCoreWorker', 'sedlauncher', 'sedsvc', 'updateassistant', 'usoclient'

foreach ($item in $exe) {
    Edit-Registry -Path "$ifeo\$item.exe" -Name 'Debugger' -Value $noop *>$null
    taskkill /im "$item.exe" /t /f *>$null
}

$pause = (Get-Date).AddDays(500).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$today = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$regPath = 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'

Edit-Registry -Path $regPath -Name "PauseUpdatesExpiryTime" -Value $pause
Edit-Registry -Path $regPath -Name "PauseFeatureUpdatesEndTime" -Value $pause
Edit-Registry -Path $regPath -Name "PauseFeatureUpdatesStartTime" -Value $today
Edit-Registry -Path $regPath -Name "PauseQualityUpdatesEndTime" -Value $pause
Edit-Registry -Path $regPath -Name "PauseQualityUpdatesStartTime" -Value $today
Edit-Registry -Path $regPath -Name "PauseUpdatesStartTime" -Value $today

& "$env:SystemRoot\RapidScripts\Set-Pages.cmd" -add windowsupdate *>$null

Write-Host "Automatic Updates have been disabled."
pause
exit