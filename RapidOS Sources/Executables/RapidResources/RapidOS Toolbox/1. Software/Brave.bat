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
    Write-Host "Brave Configuration" -F Yellow
    Write-Host
    Write-Host "[1] Install Brave"
    Write-Host "[2] Tweak Brave"
    Write-Host "[3] Documentation"
    Write-Host
    
    $choice = Read-Host -Prompt "Select an option"

    switch ($choice) {
        '1' {
            cls
            & "$env:WinDir\RapidScripts\Playbook\Software.ps1" -Software Install-Brave
        }
        '2' {
            cls
            & "$env:WinDir\RapidScripts\Playbook\Software.ps1" -Software Optimize-Brave
        }
        '3' {
            Start-Process "https://docs.rapid-community.ru/post-installation/browsers/"
        }
        default {
            Write-Host ""
            Write-Host "Invalid choice" -F Red
        }
    }
    $null = Read-Host -Prompt "Press Enter to continue"
}