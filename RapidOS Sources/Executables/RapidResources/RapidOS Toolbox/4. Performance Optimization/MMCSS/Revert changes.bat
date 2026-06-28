@echo off

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -c "$f='%~f0'; $lines=Get-Content $f; $idx=$lines.IndexOf(':PS'); iex ($lines[($idx+1)..($lines.Length-1)] -join [Environment]::NewLine)"
exit /b

:PS
$backup = "$env:SystemRoot\RapidScripts\MMCSS.json"
if (Test-Path $backup) {
    Import-RegState -JsonPath $backup
    Write-Host "MMCSS has been successfully reverted."
} else {
    Write-Error "MMCSS backup not found."
}

pause
exit