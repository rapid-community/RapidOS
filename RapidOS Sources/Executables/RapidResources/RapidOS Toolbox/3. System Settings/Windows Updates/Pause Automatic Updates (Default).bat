@echo off

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -c "$f='%~f0'; $lines=Get-Content $f; $idx=$lines.IndexOf(':PS'); iex ($lines[($idx+1)..($lines.Length-1)] -join [Environment]::NewLine)"
exit /b

:PS
$pause = (Get-Date).AddDays(500).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$today = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$regPath = 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'

Edit-Registry -Path $regPath -Name 'PauseFeatureUpdatesStartTime' -Value $today
Edit-Registry -Path $regPath -Name 'PauseFeatureUpdatesEndTime' -Value $pause
Edit-Registry -Path $regPath -Name 'PauseQualityUpdatesEndTime' -Value $pause
Edit-Registry -Path $regPath -Name 'PauseUpdatesStartTime' -Value $today
Edit-Registry -Path $regPath -Name 'PauseUpdatesExpiryTime' -Value $pause

Write-Host "Automatic Updates have been paused."
pause
exit