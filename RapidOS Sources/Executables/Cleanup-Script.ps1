function Invoke-CustomDiskCleanup {
    # Terminate existing cleanmgr, set up cleanup options
    Get-Process -Name cleanmgr -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    $registryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    $cleanupSettings = @{
        "Active Setup Temp Folders"             = 2
        "BranchCache"                           = 2
        "Delivery Optimization Files"           = 2
        "Device Driver Packages"                = 2
        "Diagnostic Data Viewer database files" = 2
        "Downloaded Program Files"              = 2
        "Internet Cache Files"                  = 2
        "Language Pack"                         = 0
        "Offline Pages Files"                   = 2
        "Old ChkDsk Files"                      = 2
        "Setup Log Files"                       = 2
        "System error memory dump files"        = 2
        "System error minidump files"           = 2
        "Temporary Setup Files"                 = 2
        "Temporary Sync Files"                  = 2
        "Update Cleanup"                        = 0
        "Upgrade Discarded Files"               = 2
        "User file versions"                    = 2
        "Windows Defender"                      = 2
        "Windows Error Reporting Files"         = 2
        "Windows Reset Log Files"               = 2
        "Windows Upgrade Log Files"             = 2
    }

    # Apply cleanup settings to registry
    foreach ($entry in $cleanupSettings.GetEnumerator()) {
        $keyPath = Join-Path -Path $registryPath -ChildPath $entry.Key
        if (Test-Path $keyPath) {
            Set-ItemProperty -Path $keyPath -Name "StateFlags1" -Value $entry.Value -Type DWORD -Force
        } else {
            Write-Host "'$($entry.Key)' not found in registry."
        }
    }

    # Run disk cleanup with timeout and hang detection
    $cleanupProcess = Start-Process -FilePath "$env:SystemRoot\system32\cleanmgr.exe" -ArgumentList "/sagerun:1", "/auto" -PassThru -WindowStyle Hidden
    $timeout = 120
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    while ($cleanupProcess -and -not $cleanupProcess.HasExited -and $stopwatch.Elapsed.TotalSeconds -lt $timeout) {
        Start-Sleep -Seconds 5
        $cpuUsage = (Get-Process -Id $cleanupProcess.Id -ErrorAction SilentlyContinue).CPU
        if ($null -eq $cpuUsage -or $cpuUsage -eq 0) {
            Write-Warning "cleanmgr might be stuck, waiting for additional time."
            Start-Sleep -Seconds 30
        }
    }

    if ($cleanupProcess -and -not $cleanupProcess.HasExited) {
        Write-Warning "Disk cleanup did not complete within $timeout seconds. Terminating process."
        $cleanupProcess | Stop-Process -Force
    }
}

function Invoke-CustomFileCleanup {
    # Stop services and clean temporary directories
    Stop-Service -Name bits, appidsvc, dps, wuauserv, cryptsvc -Force -ErrorAction SilentlyContinue

    # Clean user temp directories
    $tempPaths = @("$env:TEMP", "$env:LOCALAPPDATA\Temp", "$env:WinDir\Temp")
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            Write-Host "Cleaning: $path"
            Get-ChildItem -Path $path | Where-Object { $_.Name -ne 'AME' } | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        } else {
            Write-Host "Folder $path not found."
        }
    }

    # Clean system temp files
    $systemTempPaths = @(
        "$env:WinDir\ff*.tmp",
        "$env:WinDir\History\*",
        # "$env:WinDir\Cookies\*",
        "$env:WinDir\CbsTemp\*",
        "$env:WinDir\System32\SleepStudy\*",
        "$env:LocalAppData\Microsoft\Windows\INetCache\IE\*",
        "$env:WinDir\Downloaded Program Files\*",
        "$env:SystemRoot\setupapi.log",
        "$env:SystemRoot\Panther\*",
        "$env:SystemRoot\INF\setupapi.app.log",
        "$env:SystemRoot\INF\setupapi.dev.log",
        "$env:SystemRoot\INF\setupapi.offline.log",
        "$env:SystemDrive\Windows\SoftwareDistribution\*"
    )

    foreach ($path in $systemTempPaths) {
        if (Test-Path $path) {
            Write-Host "Cleaning: $path"
            Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
        } else {
            Write-Host "Path $path not found."
        }
    }
}

# Execute cleanup functions
Invoke-CustomDiskCleanup
Invoke-CustomFileCleanup