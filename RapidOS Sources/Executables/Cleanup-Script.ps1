# Ensure administrator privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""; Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs; exit}

# Configuration
$config = [PSCustomObject]@{
    RegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    CleanupSettings = @{
        "Active Setup Temp Folders"     = 2; "BranchCache"                    = 2
        "Delivery Optimization Files"   = 2; "Device Driver Packages"         = 0
        "Downloaded Program Files"      = 2; "Internet Cache Files"           = 2
        "Offline Pages Files"           = 2; "Old ChkDsk Files"               = 2
        "Setup Log Files"               = 2; "System error memory dump files" = 2
        "System error minidump files"   = 2; "Temporary Setup Files"          = 2
        "Temporary Sync Files"          = 2; "Upgrade Discarded Files"        = 2
        "User file versions"            = 0; "Windows Defender"               = 2
        "Windows Error Reporting Files" = 2; "Windows Reset Log Files"        = 2
        "Windows Upgrade Log Files"     = 2; "Recycle Bin"                    = 0
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
    Timeout = 300
    RetryLimit = 3
}

function Invoke-DiskCleanup {
    Write-Host "Starting disk cleanup..."

    Get-Process -Name cleanmgr -EA SilentlyContinue | % {
        $_ | Stop-Process -Force -EA SilentlyContinue
        Write-Host "Stopped existing cleanmgr with ID: $($_.Id)"
    }

    $config.CleanupSettings.GetEnumerator() | % {
        $keyPath = Join-Path -Path $config.RegistryPath -ChildPath $_.Key
        if (Test-Path $keyPath) {
            Set-ItemProperty -Path $keyPath -Name "StateFlags0064" -Value $_.Value -Type DWORD -Force
        }
    }

    # Run disk cleanup with enhanced monitoring
    $attempts = 0
    while ($attempts -lt $config.RetryLimit) {
        $cleanupProcess = Start-Process -FilePath "$env:SystemRoot\system32\cleanmgr.exe" -ArgumentList "/sagerun:64" -Wait:$false -PassThru
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $lastCpuUsage = 0
        $lastMemoryUsage = 0

        while ($cleanupProcess -and !$cleanupProcess.HasExited -and $stopwatch.Elapsed.TotalSeconds -lt $config.Timeout) {
            Start-Sleep -Seconds 10
            $process = Get-Process -Id $cleanupProcess.Id -EA SilentlyContinue
            if ($process) {
                $cpuUsage = $process.CPU
                $memoryUsage = $process.WS
                if ($cpuUsage -eq $lastCpuUsage -and $memoryUsage -eq $lastMemoryUsage) {
                    Write-Warning "Disk cleanup might be stuck. Terminating process."
                    if ($cleanupProcess.MainWindowHandle) {
                        $cleanupProcess.CloseMainWindow() | Out-Null
                        Start-Sleep -Seconds 5
                        if (!$cleanupProcess.HasExited) { $cleanupProcess | Stop-Process -EA SilentlyContinue }
                    } else {
                        $cleanupProcess | Stop-Process -EA SilentlyContinue
                    }
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
            if ($cleanupProcess -and !$cleanupProcess.HasExited) { $cleanupProcess | Stop-Process -EA SilentlyContinue }
            return
        }
    }
}

function Invoke-FileCleanup {
    Write-Host "Starting file cleanup..."

    $serviceStates = $config.Services | % { $_, (Get-Service -Name $_).Status } | ConvertFrom-Csv -Header Name, Status
    Write-Host "Stopping services..."
    $serviceStates | ? { $_.Status -eq 'Running' } | % {
        Stop-Service -Name $_.Name -Force -EA SilentlyContinue
    }

    Write-Host "Cleaning temp files..."
    ($config.TempPaths + $config.SystemTempPaths) | ? { Test-Path $_ } | % {
        gci -Path $_ -Recurse -Force -EA SilentlyContinue | ? { $_.Name -ne 'AME' } | Remove-Item -Recurse -Force -EA SilentlyContinue
    }

    Write-Host "Restoring services..."
    $serviceStates | ? { $_.Status -eq 'Running' } | % {
        Start-Service -Name $_.Name -EA SilentlyContinue
    }

    Write-Host "File cleanup done."
}

# Check for other installations of Windows
# If other Windows installations are found, skip cleanup to avoid touching another drives, because it can risk modifying unintended data
$systemDrive = ($env:SystemDrive).TrimEnd('\') + '\'
$noCleanmgr = $false 
$drives = (Get-PSDrive -PSProvider FileSystem).Root | Where-Object { $_ -ne $systemDrive }
foreach ($drive in $drives) {
    $windowsPath = Join-Path -Path $drive -ChildPath 'Windows'
    if (Test-Path -Path $windowsPath -PathType Container) {
        Write-Output "Not running Disk Cleanup, other Windows drive found: $drive"
        $noCleanmgr = $true
        break
    }
} if (!$noCleanmgr) {Invoke-DiskCleanup}
Invoke-FileCleanup

Write-Host "Cleanup operations finished."