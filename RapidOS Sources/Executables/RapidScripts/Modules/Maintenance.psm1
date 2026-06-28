# ==============================
# Diagnostics
# ==============================
function Defender {
    Write-Host "Checking Microsoft Defender..."
    $issues = @()

    $gpo = @{
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" = "DisableAntiSpyware"
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" = "DisableRealtimeMonitoring", "DisableBehaviorMonitoring", "DisableOnAccessProtection", "DisableScanOnRealtimeEnable"
    }
    foreach ($path in $gpo.Keys) {
        $reg = Get-ItemProperty $path -EA 0
        $gpo[$path] | % {if ($reg.$_ -eq 1) {$issues += "GPO: $_"}}
    }

    "WinDefend", "WdFilter", "WdNisSvc", "WdNisDrv", "WdBoot", "SecurityHealthService", "wscsvc" | % {
        $r = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$_" -Name Start -EA 0
        if ($r.Start -eq 4) {$issues += "Disabled: $_"}
    }

    $policy = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "SettingsPageVisibility" -EA 0
    if ($policy -and ($policy.SettingsPageVisibility -match "hide:windowsdefender")) {
        $issues += "Settings page hidden via UI policy."
    }

    if ($issues) {
        Write-Host "Defender modifications detected:"
        $issues | % {Write-Host "- $_"}
    } else {
        Write-Host "Microsoft Defender is enabled."
    }
}

function EventLogs {
    $dir = "$env:SystemRoot\RapidScripts"
    $out = "$dir\EventLog.log"
    $logs = "System", "Application", "Setup"
    $reg = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog"

    if (!(Test-Path $reg)) {
        Write-Host "EventLog service not found. Event logging wont work."
        return
    }
    $start = Get-ItemProperty $reg -Name Start -EA 0
    if ($start.Start -eq 4) {Edit-Registry -Path $reg -Name Start -Type DWord -Value 3}
    Start-Service EventLog *>$null

    $all = foreach ($log in $logs) {
        "--- $log ---"
        $entry = Get-WinEvent -LogName $log -EA 0 | ? {$_.Level -eq 2}
        if ($entry) {
            $entry | % {"[$($_.TimeCreated)] [$log] EventID:$($_.Id) Source:$($_.ProviderName)`r`n$($_.Message)`r`n"}
        } else {
            "[No error events found]"
        }
    }
    $all | Out-File $out -Encoding UTF8
}

function PendingReboot {
    $wua = New-Object -ComObject Microsoft.Update.SystemInfo -EA 0
    $pending = ($wua -and $wua.RebootRequired) -or (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA 0)
    if ($wua) {[Runtime.InteropServices.Marshal]::ReleaseComObject($wua) *>$null}
    if ($pending) {
        Write-Host "A reboot is pending."
        MessageBox -Message "A reboot is pending, restart your PC to continue." -Title "Attention!"
        exit 1
    }
    $false
}

function Specifications {
    $info = Get-Specs; $info | % {Write-Host $_}
    $os = $info | ? {$_ -match "OS:"}
    $build = [regex]::Match($os, '\(v(\d+)').Groups[1].Value
    $builds = "19045", "22621", "22631", "26100", "26200"

    $state = if (Test-Path 'HKLM:\SOFTWARE\RapidOS') {'installed'} else {'not installed'}
    Write-Host "RapidOS: $state"

    if ($build -notin $builds) {
        Write-Host "Unsupported Windows build detected ($build)."
        MessageBox -Message "Installation cannot proceed. Your Windows version is not supported by RapidOS ($build)." -Title "Attention!" -Type "Error"
        exit 1
    }

    if ($os -match "Home") {
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
        "Ghost Toolbox"     = "$env:SystemRoot\System32\migwiz\dlmanifests\run.ghost.cmd"
        "Win 10 Tweaker"    = "HKCU:\SOFTWARE\Win 10 Tweaker"
        BoosterX            = @("$env:ProgramFiles\GameModeX\GameModeX.exe", "HKCU:\SOFTWARE\BoosterX")
        "Defender Control"  = "$env:APPDATA\Defender Control"
        "Defender Switch"   = "$env:ProgramData\DSW"
        "WinterOS Tweaker"  = {gci "$env:SystemRoot\WinterOS*" -EA 0}
        WinCry              = "$env:SystemRoot\TempCleaner.exe"
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
        ZOICWARE            = {Test-Path "$env:SystemDrive\_FOLDERMUSTBEONCDRIVE" -EA 0}
    }

    $regex = '\b(\w+OS)\b'
    $found = @()
    $local = @()

    $checks = @{
        registry = {
            $paths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation"
            )
            foreach ($p in $paths) {
                if (Test-Path $p) {
                    $props = Get-ItemProperty $p -EA 0
                    if ($p -eq "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion") {
                        $val = $props.RegisteredOrganization
                        if ($val) {
                            $m = [Regex]::Match($val, $regex)
                            if ($m.Success) {$local += $m.Groups[1].Value}
                        }
                    }
                    if ($p -eq "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation") {
                        $val = $props.Model
                        if ($val) {
                            $m = [Regex]::Match($val, $regex)
                            if ($m.Success) {$local += $m.Groups[1].Value}
                        }
                    }
                }
            } return ($local | Select -Unique)
        }
        bcd = {
            $out = bcdedit /enum ALL 2>$null
            if ($LASTEXITCODE -eq 0) {
                ($out -split [Environment]::NewLine) | % {
                    $m = [Regex]::Match($_, 'description\s+(.*)')
                    if ($m.Success) {
                        $desc = $m.Groups[1].Value.Trim()
                        if ($desc) {
                            $m2 = [Regex]::Match($desc, $regex)
                            if ($m2.Success) {$local += $m2.Groups[1].Value}
                        }
                    }
                }
                return ($local | Select -Unique)
            } return @()
        }
        power = {
            $plans = Get-CimInstance -ClassName Win32_PowerPlan -EA 0
            if ($plans) {
                $plans | % {
                    if ($_.ElementName) {
                        $m = [Regex]::Match($_.ElementName, $regex)
                        if ($m.Success) {$local += $m.Groups[1].Value}
                    }
                }
                return ($local | Select -Unique)
            } return @()
        }
    }
    $ame = {
        $applied = gci 'HKLM:\SOFTWARE\AME\Playbooks\Applied' -EA 0
        foreach ($k in $applied) {
            $name = (Get-ItemProperty $k.PSPath -EA 0).Name
            if ($name -match '\S') {return [string]$name}
        }
    }

    foreach ($name in $tweakers.Keys) {
        $check = $tweakers[$name]
        switch ($check.GetType().Name) {
            ScriptBlock {
                if (& $check) {$found += $name}
            }
            Object[] {
                foreach ($path in $check) {
                    if (Test-Path $path) {$found += $name; break}
                }
            }
            default {
                if (Test-Path $check) {$found += $name}
            }
        }
    }
    $detected = @()
    foreach ($key in $checks.Keys) {
        & $checks.$key | % {$detected += $_}
    }
    $amefound = & $ame
    if ($amefound -and ($found -notcontains $amefound)) {$found += $amefound}
    $unique = $detected | ? {$_ -and $_.Trim()} | Select -Unique
    foreach ($os in $unique) {
        if ($found -notcontains $os) {$found += $os}
    }
    
    $found = $found | ? {$_ -ne "RapidOS"} | Select -Unique
    if ($found.Count) {
        $found | % {Write-Host "Found: $_"}
        $list = ($found | Select -Unique) -join ", "
        if (!(MessageBox -Message "Third-party tweaks detected ($list). We recommend installing RapidOS on a clean system. Do you want to continue?" -Title "Attention!" -Type "Question" -YesNo)) {
            exit 1
        }
    }
}

# ==============================
# Repairs
# ==============================
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
    # ==============================
    # Remove 3rd-party firewall rules
    # ==============================
    Write-Host "Removing third-party firewall rules..."

    $rules = Get-NetFirewallRule -DisplayName "Block.MSFT*", "Blocker MicrosoftTelemetry*", "Blocker MicrosoftExtra*", "windowsSpyBlocker*" -EA 0
    if ($rules) {
        $rules | Remove-NetFirewallRule -EA 0
        Write-Host "Removed firewall rules blocking MS services"
    } else {
        Write-Host "No telemetry firewall rules found`n"
    }

    # ==============================
    # Clean 3rd-party hosts' entries
    # ==============================
    Write-Host "Removing third-party hosts..."

    $path = "$env:SystemRoot\System32\drivers\etc\hosts"
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
    foreach ($src in $sources) {
        $data = (Invoke-WebRequest -Uri $src -UseBasicParsing -EA 0).Content
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
    foreach ($line in $hosts) {
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

Export-ModuleMember -Function *