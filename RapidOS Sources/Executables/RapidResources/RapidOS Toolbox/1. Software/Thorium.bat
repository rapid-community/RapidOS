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
    Write-Host "Thorium Configuration" -F Yellow
    Write-Host
    Write-Host "[1] Install Thorium"
    Write-Host "[2] Tweak Thorium"
    Write-Host "[3] Documentation"
    Write-Host
    
    $choice = Read-Host -Prompt "Select an option"

    switch ($choice) {
        '1' {
            cls
            & "$env:WinDir\RapidScripts\Playbook\Software.ps1" -Software Install-Thorium
        }
        '2' {
            cls
            Write-Host "This browser is already good and there is no need to tweak it."
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