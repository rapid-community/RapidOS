param (
    [string]$MyArgument
)

# Show usage
function Show-Usage {
    Write-Host "Usage:"
    Write-Host ".\Control-Mitigations.ps1 -MyArgument enable_mitigations|disable_mitigations"
    Write-Host " - enable_mitigations : Enable CPU vulnerability mitigations."
    Write-Host " - disable_mitigations : Disable CPU vulnerability mitigations."
}

switch ($MyArgument) {
    "enable_mitigations" {
        # Enable Spectre/Meltdown mitigations
        Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'FeatureSettingsOverride' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'FeatureSettingsOverrideMask' -ErrorAction SilentlyContinue
        
        # Enable SEHOP
        Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' -Name 'DisableExceptionChainValidation' -ErrorAction SilentlyContinue
        
        # Reset mitigations
        Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' -Name 'MitigationAuditOptions' -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' -Name 'MitigationOptions' -ErrorAction SilentlyContinue
        
        # DEP for OS components
        bcdedit /set nx OptIn > $null
        
        # Enable file system mitigations
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'ProtectionMode' -Value 1 -Type DWord
        
        # Default Hyper-V settings
        Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization' -Name 'MinVmVersionForCpuBasedMitigations' -ErrorAction SilentlyContinue
        
        Write-Host "Mitigations enabled for the system." -ForegroundColor Green
    }

    "disable_mitigations" {
        # Disable Spectre/Meltdown mitigations
        $manufacturer = (Get-WmiObject Win32_Processor).Manufacturer

        if ($manufacturer -eq 'GenuineIntel') {
            Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'FeatureSettingsOverride' -Value 3 -Type DWord
            Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'FeatureSettingsOverrideMask' -Value 3 -Type DWord

            # Disable SEHOP
            Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' -Name 'DisableExceptionChainValidation' -Value 1 -Type DWord
            
            # Disable CFG
            Set-ProcessMitigation -System -Disable CFG
            
            # Disable all process mitigations
            $mitigationMask = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' -Name 'MitigationAuditOptions').MitigationAuditOptions
            $mitigationMask = [string]$mitigationMask -replace '[0-9]', '2'
            
            # List of games known to require specific mitigations (CFG, DEP, etc.)
            $gamesRequiringMitigations = @(
                "Valorant", "valorant-win64-shipping", "vgtray", # Valorant needs these for anti-cheat
                "Fortnite", "FortniteClient-Win64-Shipping", "FortniteClient-Win64-Shipping_BE", "FortniteClient-Win64-Shipping_EAC", "FortniteLauncher", # Fortnite needs these for anti-cheat
                "FACEIT", "faceitclient", # Faceit needs these for anti-cheat
                "Apex Legends",           # Has performance issues without CFG
                "Final Fantasy XV",       # Stuttering issues fixed by disabling CFG
                "The Witcher 3",          # Performance benefits from disabling CFG
                "Far Cry 5"               # Performance benefits from disabling CFG
            )

            # Enable CFG for games that require it even with mitigations disabled
            foreach ($game in $gamesRequiringMitigations) {
                $gameExe = "$game.exe"
                Set-ProcessMitigation -Name $gameExe -Enable CFG -ErrorAction SilentlyContinue
            }
            
            # DEP only for OS components
            bcdedit /set nx OptIn > $null
            
            # Apply mitigation mask
            Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' -Name 'MitigationAuditOptions' -Value ([byte[]]::new(8) + $mitigationMask) -Type Binary
            Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' -Name 'MitigationOptions' -Value ([byte[]]::new(8) + $mitigationMask) -Type Binary
            
            # Disable file system mitigations
            Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'ProtectionMode' -Value 0 -Type DWord
            
            Write-Host "Mitigations disabled for the system. CFG enabled for specific games." -ForegroundColor Green
        } else {
            Write-Host "Mitigation disabling not fully supported for this CPU type." -ForegroundColor Red
            Write-Host "The performance gain from disabling such mitigations might be minimal on AMD systems compared to Intel, as AMD's approach to these vulnerabilities can differ."
        }
    }

    default {
        Write-Host "Error: Invalid argument `"$MyArgument`"" -ForegroundColor Red
        Show-Usage
    }
}