# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) { $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -MyArgument {1}" -f $PSCommandPath, $MyArgument; Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs; exit }

# Configuration
$config = [PSCustomObject]@{
    RegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    CleanupSettings = @{
        "Active Setup Temp Folders" = 2; "BranchCache" = 2
        "Delivery Optimization Files" = 2; "Device Driver Packages" = 0
        "Downloaded Program Files" = 2; "Internet Cache Files" = 2
        "Offline Pages Files" = 2; "Old ChkDsk Files" = 2
        "Setup Log Files" = 2; "System error memory dump files" = 2
        "System error minidump files" = 2; "Temporary Setup Files" = 2
        "Temporary Sync Files" = 2; "Upgrade Discarded Files" = 2
        "User file versions" = 0; "Windows Defender" = 2
        "Windows Error Reporting Files" = 2; "Windows Reset Log Files" = 2
        "Windows Upgrade Log Files" = 2
    }
    Services = @("bits", "appidsvc", "dps", "wuauserv", "cryptsvc")
    TempPaths = @("$env:TEMP", "$env:LOCALAPPDATA\Temp", "$env:WinDir\Temp")
    SystemTempPaths = @(
        "$env:WinDir\ff*.tmp", "$env:WinDir\History\*", "$env:WinDir\CbsTemp\*"
        "$env:WinDir\System32\SleepStudy\*", "$env:LocalAppData\Microsoft\Windows\INetCache\IE\*"
        "$env:WinDir\Downloaded Program Files\*", "$env:SystemRoot\setupapi.log"
        "$env:SystemRoot\Panther\*", "$env:SystemRoot\INF\setupapi.app.log"
        "$env:SystemRoot\INF\setupapi.dev.log", "$env:SystemRoot\INF\setupapi.offline.log"
        "$env:SystemDrive\Windows\SoftwareDistribution\*"
    )
    Timeout = 120
    RetryLimit = 3
}

function Invoke-DiskCleanup {
    Write-Host "Starting disk cleanup..."

    Get-Process -Name cleanmgr -ErrorAction SilentlyContinue | ForEach-Object {
        $_ | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host "Stopped existing cleanmgr with ID: $($_.Id)"
    }

    $config.CleanupSettings.GetEnumerator() | ForEach-Object {
        $keyPath = Join-Path -Path $config.RegistryPath -ChildPath $_.Key
        if (Test-Path $keyPath) {
            Set-ItemProperty -Path $keyPath -Name "StateFlags1" -Value $_.Value -Type DWORD -Force
        }
    }

    # Run disk cleanup with enhanced monitoring
    $attempts = 0
    while ($attempts -lt $config.RetryLimit) {
        $cleanupProcess = Start-Process -FilePath "$env:SystemRoot\system32\cleanmgr.exe" -ArgumentList "/sagerun:1", "/auto" -Wait:$false -PassThru -WindowStyle Hidden
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $lastCpuUsage = 0
        $lastMemoryUsage = 0

        while ($cleanupProcess -and -not $cleanupProcess.HasExited -and $stopwatch.Elapsed.TotalSeconds -lt $config.Timeout) {
            Start-Sleep -Seconds 5
            $process = Get-Process -Id $cleanupProcess.Id -ErrorAction SilentlyContinue
            if ($process) {
                $cpuUsage = $process.CPU
                $memoryUsage = $process.WS
                if ($cpuUsage -eq $lastCpuUsage -and $memoryUsage -eq $lastMemoryUsage) {
                    Write-Warning "Disk cleanup might be stuck. Restarting..."
                    $cleanupProcess | Stop-Process -Force
                    $attempts++
                    break
                }
                $lastCpuUsage = $cpuUsage
                $lastMemoryUsage = $memoryUsage
            }
        }

        if ($cleanupProcess -and $cleanupProcess.HasExited) {
            Write-Host "Disk cleanup done."
            return
        } elseif ($attempts -ge $config.RetryLimit) {
            Write-Warning "Disk cleanup failed after $config.RetryLimit attempts. Stopping process."
            $cleanupProcess | Stop-Process -Force
            return
        }
    }
}

function Invoke-FileCleanup {
    Write-Host "Starting file cleanup..."

    # Stop running services
    $serviceStates = $config.Services | ForEach-Object { $_, (Get-Service -Name $_).Status } | ConvertFrom-Csv -Header Name, Status
    Write-Host "Stopping services..."
    $serviceStates | Where-Object { $_.Status -eq 'Running' } | ForEach-Object {
        Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue
    }

    # Clean temp files
    Write-Host "Cleaning temp files..."
    ($config.TempPaths + $config.SystemTempPaths) | Where-Object { Test-Path $_ } | ForEach-Object {
        Get-ChildItem -Path $_ -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'AME' } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Restore initially running services
    Write-Host "Restoring services..."
    $serviceStates | Where-Object { $_.Status -eq 'Running' } | ForEach-Object {
        Start-Service -Name $_.Name -ErrorAction SilentlyContinue
    }

    Write-Host "File cleanup done."
}

Invoke-DiskCleanup
Invoke-FileCleanup

Write-Host "Cleanup operations finished."