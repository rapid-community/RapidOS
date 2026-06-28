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
    Write-Host "Firefox Configuration" -F Yellow
    Write-Host
    Write-Host "[1] Install Firefox"
    Write-Host "[2] Tweak Firefox"
    Write-Host "[3] Documentation"
    Write-Host
    
    $choice = Read-Host -Prompt "Select an option"

    switch ($choice) {
        '1' {
            cls
            & "$env:SystemRoot\RapidScripts\Playbook\Software.ps1" -Software Install-Firefox
        }
        '2' {
            $inTweak = $true
            while ($inTweak) {
                cls
                Write-Host "Tweak Menu" -F Yellow
                Write-Host
                Write-Host "[1] Apply optimizations"
                Write-Host "[2] Remove optimizations"
                Write-Host "[3] Remove uBlock Origin"
                Write-Host "[B] Back to Main Menu"
                Write-Host

                $tweakChoice = Read-Host -Prompt "Select an option"

                switch ($tweakChoice) {
                    '1' {
                        cls
                        & "$env:SystemRoot\RapidScripts\Playbook\Software.ps1" -Software Optimize-Firefox
                        $null = Read-Host "Press Enter to continue"
                    }
                    '2' {
                        $basePath = if (Test-Path "$env:ProgramFiles\Mozilla Firefox") {"$env:ProgramFiles\Mozilla Firefox"} else {"${env:ProgramFiles(x86)}\Mozilla Firefox"}
                        del -Path (Join-Path $basePath "distribution") -Recurse -Force -EA 0
                        Write-Host "Successfully removed Firefox policies."
                        $null = Read-Host "Press Enter to continue"
                    }
                    '3' {
                        $basePath = if (Test-Path "$env:ProgramFiles\Mozilla Firefox") {
                            "$env:ProgramFiles\Mozilla Firefox"
                        } else {
                            "${env:ProgramFiles(x86)}\Mozilla Firefox"
                        }

                        $distPath = Join-Path $basePath "distribution"
                        if (!(Test-Path $distPath)) {
                            Write-Host "Firefox optimizations have already been removed."
                            $null = Read-Host "Press Enter to continue"
                            break
                        }

                        $filePath = Join-Path $distPath "policies.json"
                        if (Test-Path $filePath) {
                            $json = Get-Content -Path $filePath -Raw | ConvertFrom-Json

                            if ($json.policies.PSObject.Properties['ExtensionSettings']) {
                                if ($json.policies.ExtensionSettings.PSObject.Properties['uBlock0@raymondhill.net']) {
                                    $json.policies.ExtensionSettings.PSObject.Properties.Remove('uBlock0@raymondhill.net')
                                }

                                $props = $json.policies.ExtensionSettings.PSObject.Properties | ? {$_.MemberType -eq 'NoteProperty'}
                                if (!$props) {
                                    $json.policies.PSObject.Properties.Remove('ExtensionSettings')
                                }
                            }

                            $json | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding ASCII
                        }

                        Write-Host "Successfully removed uBlock Origin policy."
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
