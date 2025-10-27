# ===========================
# Diagnostics
# ===========================
function Defender {
    Write-Host "Checking Microsoft Defender..."

    $sysDir = Join-Path -Path $env:WinDir -ChildPath "System32"
    $issues = @()
    $disabled = $false

    $files = @(
        (Join-Path $sysDir "smartscreen.exe"),
        (Join-Path $sysDir "SecurityHealthSystray.exe"),
        (Join-Path $sysDir "CompatTelRunner.exe")
    )
    $missing = $files | ? {!(Test-Path $_ -EA 0)}
    if ($missing) {
        $fileNames = $missing | % {Split-Path $_ -Leaf}
        $issues += "Missing system files: " + ($fileNames -join ", ")
        $disabled = $true
    }

    $uiPolicy = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "SettingsPageVisibility" -EA 0
    if ($uiPolicy -and ($uiPolicy.SettingsPageVisibility -match "hide:windowsdefender")) {
        $issues += "Settings page hidden via UI policy."
        $disabled = $true
    }

    if (!(Get-CimInstance -ClassName AntiVirusProduct -Namespace root/SecurityCenter2 -EA 0)) {
        $issues += "Antivirus not registered in SecurityCenter2."
        $disabled = $true
    }

    $svcList = "WinDefend", "SecurityHealthService", "wscsvc", "WdFilter"
    $running = (Get-Service -Name $svcList -EA 0) | ? {$_.Status -eq "Running"} | Select -Expand Name
    $notRunning = $svcList | ? {$running -notcontains $_}
    if ($notRunning.Count) {
        $issues += "Stopped services: " + ($notRunning -join ", ")
        $disabled = $true
    }

    $mp = Get-Command Get-MpPreference -EA 0 | % {Get-MpPreference -EA 0}
    if (!$mp) {
        $issues += "Unable to retrieve MpPreference."
        $disabled = $true
    } elseif ($null -eq $mp.EnableControlledFolderAccess) {
        $issues += "Controlled Folder Access state unknown."
        $disabled = $true
    }
            
    $gpo1 = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -EA 0
    if ($gpo1 -and ($gpo1.DisableAntiSpyware -eq 1)) {
        $issues += "AntiSpyware is disabled."
        $disabled = $true
    }

    $gpo2 = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRealtimeMonitoring", "DisableBehaviorMonitoring" -EA 0
    if ($gpo2 -and ($gpo2.DisableRealtimeMonitoring -eq 1)) {
        $issues += "Realtime Monitoring is disabled."
        $disabled = $true
    }
    if ($gpo2 -and ($gpo2.DisableBehaviorMonitoring -eq 1)) {
        $issues += "Behavior Monitoring is disabled."
        $disabled = $true
    }

    if ($disabled) {
        Write-Host "Microsoft Defender is broken:"
        $issues | % {Write-Host "- " + $_}
    } else {
         Write-Host "Microsoft Defender is enabled."
    }
}

function EventLogs {
    $rapidscripts = Join-Path $env:WinDir "RapidScripts"
    $outFile = Join-Path $rapidscripts "EventLog.log"
    $logs = "System","Application","Setup"
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog"

    if (!(Test-Path $regPath)) {
        Write-Host "EventLog service not found. Event logging wont work."
        return
    }
    $startType = Get-ItemProperty -Path $regPath -Name Start -EA 0
    if ($startType.Start -eq 4) {
        Set-RegistryValue -Path $regPath -Name Start -Type DWORD -Value 3
    }; Start-Service EventLog *>$null

    $all = foreach ($log in $logs) {
        Write-Output ("--- $log ---")
        $entry = Get-WinEvent -LogName $log -EA 0 | ? {$_.Level -eq 2}
        if ($entry) {
            $entry | % {
                "[" + $_.TimeCreated + "] [" + $log + "] EventID:" + $_.Id + " Source:" + $_.ProviderName + "`r`n" + $_.Message + "`r`n"
            }
        } else {
            "[No error events found]"
        }
    }
    $all | Out-File -FilePath $outFile -Encoding UTF8
}

function PendingReboot {
    $k = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    )
    if ($k | ? {Test-Path $_}) {
        MessageBox -Message "A reboot is pending, restart your PC to continue." -Title "Attention!"
        exit 1
    }
}

function Specifications {
    $osInfo = Get-Specs; $osInfo | % {Write-Host $_}
    $osLine = $osInfo | ? {$_ -match "OS:"}
    $osBuild = [regex]::Match($osLine, '\(v(\d+)').Groups[1].Value
    $supportedBuilds = "19045", "22621", "22631", "26100", "26200"

    if ($osBuild -notin $supportedBuilds) {
        Write-Host ("Unsupported Windows build detected ($osBuild).")
        if (!(MessageBox -Message "Installation cannot proceed. Your Windows version is not supported by RapidOS ($osBuild)." -Title "Attention!" -Type "Error")) {
            exit 1
        }
    }

    if ($osLine -match "IoT") {
        Write-Host "LTSC/IoT build detected."
        if (!(MessageBox -Message "You are on an LTSC/IoT version of Windows. RapidOS has not been thoroughly tested on this version. Do you want to continue?" -Title "Attention!" -Type "Question" -YesNo)) {
            exit 1
        }
    }

    if ($osLine -match "Home") {
        Write-Host "Windows Home detected."
        if (!(MessageBox -Message "RapidOS is not officially supported on Windows Home. Unstable behavior or errors may occur. Do you want to continue?" -Title "Attention!" -Type "Question" -YesNo)) {
            exit 1
        }
    }
}

function Tweakers {
    Write-Host "Checking for third-party tweakers..."
    $tweakers = @{
        Windows10Debloater  = "$env:SystemDrive\Temp\Windows10Debloater"
        Win10BloatRemover   = "$env:TEMP\.net\Win10BloatRemover"
        "Bloatware Removal" = {gci "$env:SystemDrive\BRU\Bloatware-Removal*.log" -EA 0}
        "Ghost Toolbox"     = "$env:WinDir\System32\migwiz\dlmanifests\run.ghost.cmd"
        "Win 10 Tweaker"    = "HKCU:\SOFTWARE\Win 10 Tweaker"
        BoosterX            = @("$env:ProgramFiles\GameModeX\GameModeX.exe", "HKCU:\SOFTWARE\BoosterX")
        "Defender Control"  = "$env:APPDATA\Defender Control"
        "Defender Switch"   = "$env:ProgramData\DSW"
        "WinterOS Tweaker"  = {gci "$env:WinDir\WinterOS*" -EA 0}
        WinCry              = "$env:WinDir\TempCleaner.exe"
        WinClean            = "$env:ProgramFiles\WinClean Plus Apps"
        KirbyOS             = "$env:ProgramData\KirbyOS"
        PCNP                = "HKCU:\SOFTWARE\PCNP"
        Tron                = "$env:SystemDrive\logs\tron"
        Hone                = "$env:LOCALAPPDATA\Programs\Hone"
        AutoSettingsPS      = {Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths" -EA 0 | % {$_ | Get-Member -MemberType NoteProperty | ? {$_.Name -match "AutoSettingsPS"}}}
        Flibustier          = {Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\.NETFramework\Performance" -EA 0 | Get-Member -MemberType NoteProperty | ? {$_.Name -match "flibustier"}}
        Winpilot            = {(Get-ItemProperty "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" -EA 0).PSObject.Properties.Value -contains "Winpilot"}
        Bloatynosy          = {(Get-ItemProperty "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" -EA 0).PSObject.Properties.Value -contains "BloatynosyNue"}
        "xd-AntiSpy"        = {(Get-ItemProperty "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" -EA 0).PSObject.Properties.Value -contains "xd-AntiSpy"}
        "Modern Tweaker"    = {(Get-ItemProperty "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" -EA 0).PSObject.Properties.Value -contains "Modern Tweaker"}
        winutil             = {Get-CimInstance -ClassName Win32_PowerPlan -EA 0 | ? {$_.ElementName -match "ChrisTitus"}}
        ChlorideOS          = {Get-Volume -EA 0 | ? {$_.FileSystemLabel -eq "ChlorideOS"}}
        ZOICWARE            = {Test-Path (Join-Path -Path $env:SystemDrive -ChildPath "_FOLDERMUSTBEONCDRIVE") -EA 0}
    }
    $osChecks = @{
        registry = {
            $orgPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation"
            )
            $foundOS = @()
            $orgPaths | % {
                if (Test-Path $_) {
                    $props = Get-ItemProperty -Path $_ -EA 0
                    if ($_ -eq "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion") {
                        $orgValue = $props.RegisteredOrganization
                        if ($orgValue -and $orgValue -match "(\w+OS)") {
                            $foundOS += $matches[1]
                        }
                    }
                    if ($_ -eq "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation") {
                        $modelValue = $props.Model
                        if ($modelValue -and $modelValue -match "(\w+OS)") {
                            $foundOS += $matches[1]
                        }
                    }
                }
            }
            return ($foundOS | Select -Unique)
        }
        bcd = {
            $bcdOutput = bcdedit /enum ALL 2>$null
            if ($LASTEXITCODE -eq 0) {
                $foundOS = @()
                ($bcdOutput -split [System.Environment]::NewLine) | % {
                    if ($_ -match "description\s+(.*)") {
                        $desc = $matches[1].Trim()
                        if ($desc -match "(\w+OS)") {
                            $foundOS += $matches[1]
                        }
                    }
                }
                return ($foundOS | Select -Unique)
            }
            return @()
        }
        power = {
            $plans = Get-CimInstance -ClassName Win32_PowerPlan -EA 0
            if ($plans) {
                $foundOS = @()
                $plans | % {
                    if ($_.ElementName -match "(\w+OS)") {
                        $foundOS += $matches[1]
                    }
                }
                return ($foundOS | Select -Unique)
            }
            return @()
        }
    }
    $ameCheck = {
        $basePath = "HKLM:\SOFTWARE\AME\Playbooks\Applied"
        if (Test-Path $basePath) {
            $subKeys = Get-ChildItem -Path $basePath -EA 0
            $subKeys | % {
                $props = Get-ItemProperty -Path $_.PSPath -EA 0
                if ($props.Name -and $props.Name -ne "RapidOS" -and $props.Name -match "\w+") {
                    return $props.Name
                }
            }
        }
        return $null
    }
    $found = @()
    $tweakers.Keys | % {
        $name = $_
        $check = $tweakers[$name]
        switch ($check.GetType().Name) {
            ScriptBlock {
                if (& $check) {$found += $name; Write-Host "Found: $name"}
            }
            Object[] {
                foreach ($path in $check) {
                    if (Test-Path $path) {$found += $name; Write-Host "Found: $name"; break}
                }
            }
            default {
                if (Test-Path $check) {$found += $name; Write-Host "Found: $name"}
            }
        }
    }
    $detectedOS = @()
    $osChecks.Keys | % {
        $result = & $osChecks.$_
        if ($result) {
            $detectedOS += $result
        }
    }
    $ameResult = & $ameCheck
    if ($ameResult) {
        if ($found -notcontains $ameResult) {
            $found += $ameResult
            Write-Host "Found: $ameResult"
        }
    }
    $uniqueOS = $detectedOS | ? {$_ -and $_.Trim()} | Select -Unique
    $uniqueOS | % {
        if ($found -notcontains $_) {
            $found += $_
            Write-Host "Found: $_"
        }
    }
    if ($found.Count) {
        $tweakersList = ($found | Select -Unique) -join ", "
        if (!(MessageBox -Message "Third-party tweaks detected ($tweakersList). We recommend installing RapidOS on a clean system. Do you want to continue?" -Title "Attention!" -Type "Question" -YesNo)) {
            exit 1
        }
    }
}

# ===========================
# Repairs
# ===========================
function ComponentStore {
    $state = (Repair-WindowsImage -Online -CheckHealth).ImageHealthState
    switch ($state) {
        "Healthy" {Write-Host "Component Store is healthy."; return}
        "Repairable" {
            Write-Host "Component Store is repairable, attempting restore..."
            Repair-WindowsImage -Online -RestoreHealth
            $state = (Repair-WindowsImage -Online -CheckHealth).ImageHealthState
            if ($state -ne "Healthy") {Write-Host "Repair failed."}
        }
        "NonRepairable" {
            Write-Host "Component Store is broken."
            if (!(MessageBox -Message "The component store is non-repairable. We recommend reinstalling Windows and NOT continuing the setup. Do you want to continue?" -Title "Attention!" -Type "Error" -YesNo)) {
                exit 1
            }
        }
    }
}

function ExternalBlocks {
    # === Remove 3rd-party firewall rules ===
    Write-Host "Removing third-party firewall rules..."

    $rules = Get-NetFirewallRule -DisplayName "Block.MSFT*", "Blocker MicrosoftTelemetry*", "Blocker MicrosoftExtra*", "windowsSpyBlocker*" -EA 0
    if ($rules) {
        $rules | Remove-NetFirewallRule -EA 0
        Write-Host "Removed firewall rules blocking MS services"
    } else {
        Write-Host "No telemetry firewall rules found`n"
    }

    # === Clean 3rd-party hosts' entries ===
    Write-Host "Removing third-party hosts..."

    $path = Join-Path -Path $env:WinDir -ChildPath "System32\drivers\etc\hosts"
    $hosts = Get-Content $path -Force -EA 0
    if (!($hosts | ? {$_ -match "^\s*[^#\s]"})) {
        Write-Host "Hosts file is empty or has no active entries"
        return
    }

    $sources = @(
        "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/extra.txt",
        "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/extra_v6.txt",
        "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt",
        "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy_v6.txt",
        "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/update.txt",
        "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/update_v6.txt",
        "https://raw.githubusercontent.com/schrebra/Windows.10.DNS.Block.List/main/hosts.txt"
    )
    $list = @()
    $sources | % {
        $data = (Invoke-WebRequest -Uri $_ -UseBasicParsing -EA 0).Content
        if ($data) {$list += $data -split "`r?`n"}
    }
    if (!$list.Count) {
        Write-Host "Failed to download block lists"
        return
    }

    $map = @{}
    $list | ? {$_ -and $_ -notmatch "^\s*#"} | % {
        $entry = ($_ -split "#")[0].Trim()
        if ($entry) {
            $parts = $entry -split "\s+", 2
            if ($parts.Count -gt 1) {$map[$parts[1].Trim()] = $true}
        }
    }
    $clean = @()
    $found = $false
    $hosts | % {
        $line = $_
        $trim = ($line -split "#")[0].Trim()
        if ($trim) {
            $parts = $trim -split "\s+", 2
            if ($parts.Count -gt 1 -and $map.ContainsKey($parts[1].Trim())) {
                $found = $true
            } else {
                $clean += $line
            }
        } else {$clean += $line}
    }

    if ($found) {
        $clean | Set-Content -Path $path -Encoding Default -Force -EA 0
        Write-Host "Cleaned third-party entries from hosts file"
    } else {
        Write-Host "No blocked entries found in hosts file"
    }
}