@echo off

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -c "$f='%~f0'; $lines=Get-Content $f; $idx=$lines.IndexOf(':PS'); iex ($lines[($idx+1)..($lines.Length-1)] -join [Environment]::NewLine)"
exit /b

:PS
while ($true) {
    cls
    Write-Host "Media Configuration" -F Yellow
    Write-Host
    Write-Host "[1] Install HEIF & HEVC"
    Write-Host
    
    $choice = Read-Host -Prompt "Select an option"

    switch ($choice) {
        '1' {
            cls
            & "$env:WinDir\RapidScripts\Playbook\Software.ps1" -Software Install-MediaExtensions
        }
        default {
            Write-Host ""
            Write-Host "Invalid choice" -F Red
        }
    }
    $null = Read-Host -Prompt "Press Enter to continue"
}