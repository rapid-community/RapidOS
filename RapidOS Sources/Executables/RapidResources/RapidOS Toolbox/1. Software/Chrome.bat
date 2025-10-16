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
    Write-Host "Chrome Configuration" -F Yellow
    Write-Host
    Write-Host "[1] Install Chrome"
    Write-Host "[2] Tweak Chrome"
    Write-Host "[3] Documentation"
    Write-Host
    
    $choice = Read-Host -Prompt "Select an option"

    switch ($choice) {
        '1' {
            cls
            & "$env:WinDir\RapidScripts\Playbook\Software.ps1" -Software Install-Chrome
        }
        '2' {
            $inTweak = $true
            while ($inTweak) {
                cls
                Write-Host "Tweak Menu" -F Yellow
                Write-Host
                Write-Host "[1] Apply optimizations"
                Write-Host "[2] Remove uBlock Origin Lite"
                Write-Host "[B] Back to Main Menu"
                Write-Host

                $tweakChoice = Read-Host -Prompt "Select an option"

                switch ($tweakChoice) {
                    '1' {
                        cls
                        & "$env:WinDir\RapidScripts\Playbook\Software.ps1" -Software Optimize-Chrome
                        $null = Read-Host "Press Enter to continue"
                    }
                    '2' {
                        reg delete "HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" /f *>$null
                        Write-Host "Successfully removed uBlock Origin Lite policy."
                        $null = Read-Host "Press Enter to continue"
                    }
                    'B' {$inTweak = $false}
                    default {
                        Write-Host "Invalid choice in Tweak Menu" -F Red
                        $null = Read-Host "Press Enter to continue"
                    }
                }
            }
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
