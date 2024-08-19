function Set-DiskCleanupSettings {
    param (
        [int]$sageSetNumber = 1
    )
    
    $categories = @{
        "Active Setup Temp Folders" = 2
        "BranchCache" = 2
        "Delivery Optimization Files" = 2
        "Device Driver Packages" = 2
        "Diagnostic Data Viewer database files" = 2
        "Downloaded Program Files" = 2
        "Internet Cache Files" = 2
        "Language Pack" = 2
        "Offline Pages Files" = 2
        "Old ChkDsk Files" = 2
        "Setup Log Files" = 2
        "System error memory dump files" = 2
        "System error minidump files" = 2
        "Temporary Setup Files" = 2
        "Temporary Sync Files" = 2
        "Update Cleanup" = 2
        "Upgrade Discarded Files" = 2
        "User file versions" = 2
        "Windows Defender" = 2
        "Windows Error Reporting Files" = 2
        "Windows Reset Log Files" = 2
        "Windows Upgrade Log Files" = 2
    }
    
    $registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
    
    foreach ($item in $categories.GetEnumerator()) {
        $keyPath = Join-Path -Path $registryPath -ChildPath $item.Key
        if (Test-Path $keyPath) {
            Set-ItemProperty -Path $keyPath -Name "StateFlags$sageSetNumber" -Value $item.Value -Type DWORD -Force
        } else {
            Write-Warning "Category '$($item.Key)' not found in the registry."
        }
    }
}

$ErrorActionPreference = 'SilentlyContinue'

function CustomFileCleanup {
    # Exclude the AME folder when deleting directories in the temporary user folder
    Get-ChildItem -Path "$env:TEMP" | Where-Object { $_.Name -ne 'AME' } | Remove-Item -Force -Recurse

    # List of paths to clean up
    $cleanupPaths = @(
        "$env:WinDir\Temp\*"
        "$env:WinDir\Temp"
        "$env:WinDir\ff*.tmp"
        "$env:WinDir\History\*"
        "$env:WinDir\Cookies\*"
        "$env:WinDir\Recent\*"
        "$env:WinDir\Spool\Printers\*"
        "$env:WinDir\Prefetch\*"
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\IE\*"
        "$env:WinDir\Downloaded Program Files\*"
        "$env:SYSTEMDRIVE\$Recycle.Bin\*"
        "$env:SystemRoot\setupapi.log"
        "$env:SystemRoot\Panther\*"
        "$env:SystemRoot\INF\setupapi.app.log"
        "$env:SystemRoot\INF\setupapi.dev.log"
        "$env:SystemRoot\INF\setupapi.offline.log"
    )

    foreach ($path in $cleanupPaths) {
        if (Test-Path $path) {
            Write-Host "Cleaning up $path"
            Get-ChildItem -Path $path -Force -Recurse -ErrorAction SilentlyContinue -Verbose | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue -Verbose
        } else {
            Write-Host "Path $path not found"
        }
    }
}

# Set disk cleanup settings in the registry
Set-DiskCleanupSettings -sageSetNumber 1

# Start disk cleanup utility with configured settings
$cleanupProcess = Start-Process -FilePath "$env:SystemRoot\system32\cleanmgr.exe" -ArgumentList "/sagerun:1" -PassThru

# Wait for the process to complete or time out
$timeout = 60 # Timeout in seconds
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

while (-not $cleanupProcess.HasExited -and $stopwatch.Elapsed.TotalSeconds -lt $timeout) {
    Start-Sleep -Seconds 5
}

if (-not $cleanupProcess.HasExited) {
    Write-Warning "Disk Cleanup did not complete in $timeout seconds. Terminating process."
    Stop-Process -Id $cleanupProcess.Id -Force
}

# Perform custom cleanup tasks
CustomFileCleanup

# Clear event logs
Get-EventLog -List | ForEach-Object { Clear-EventLog $_.Log } 2>&1 | Out-Null