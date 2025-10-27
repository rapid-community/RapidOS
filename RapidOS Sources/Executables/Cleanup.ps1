#Requires -RunAsAdministrator

Write-Host "--- System cleanup ---" -F Green
Write-Host "Removing disk clutter and logs`n"

# ===========================
# Configuration
# ===========================
$config = [PSCustomObject]@{
    CleanupSettings = @{
        "Active Setup Temp Folders"         = 2; "BranchCache"                           = 2
        "D3D Shader Cache"                  = 2; "Delivery Optimization Files"           = 2
        "Device Driver Packages"            = 0; "Diagnostic Data Viewer database files" = 0
        "Downloaded Program Files"          = 2; "Internet Cache Files"                  = 2
        "Language Pack"                     = 0; "Offline Pages Files"                   = 2
        "Old ChkDsk Files"                  = 2; "Recycle Bin"                           = 0
        "RetailDemo Offline Content"        = 0; "Setup Log Files"                       = 2
        "System error memory dump files"    = 0; "System error minidump files"           = 0
        "Temporary Files"                   = 0; "Temporary Setup Files"                 = 2
        "Temporary Sync Files"              = 2; "Thumbnail Cache"                       = 2
        "Update Cleanup"                    = 2; "Upgrade Discarded Files"               = 2
        "User file versions"                = 0; "Windows Defender"                      = 2
        "Windows Error Reporting Files"     = 2; "Windows Reset Log Files"               = 2
        "Windows Upgrade Log Files"         = 2
    }
    Services = @("bits", "appidsvc", "dps", "wuauserv", "cryptsvc")
    TempPaths = @("$env:TEMP", "$env:LOCALAPPDATA\Temp", "$env:WinDir\Temp")
    LogPaths = @(
        "$env:WinDir\DtcInstall.log",
        "$env:WinDir\comsetup.log",
        "$env:WinDir\PFRO.log",
        "$env:WinDir\Performance\WinSAT\winsat.log",
        "$env:WinDir\debug\PASSWD.LOG",
        "$env:WinDir\Logs\SIH\*",
        "$env:LOCALAPPDATA\Microsoft\CLR_v4.0\UsageTraces\*",
        "$env:LOCALAPPDATA\Microsoft\CLR_v4.0_32\UsageTraces\*",
        "$env:WinDir\Logs\NetSetup\*",
        "$env:WinDir\ff*.tmp",
        "$env:WinDir\System32\SleepStudy\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
        "$env:LOCALAPPDATA\IconCache.db"
    )
    Timeout = 300
    RetryLimit = 3
}

# ===========================
# Disk Cleanup
# ===========================
function Invoke-DiskCleanup {
    Write-Host "Starting disk cleanup"
    taskkill /f /im cleanmgr.exe *>$null
    
    Write-Host "Setting cleanup keys..." -F DarkGray
    $config.CleanupSettings.GetEnumerator() | % {
        $keyPath = Join-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches' $_.Key;
        if (Test-Path $keyPath) {Set-RegistryValue -Path $keyPath -Name "StateFlags0042" -Type DWORD -Value $_.Value} 
    }

    $i = 0
    while ($i -lt $config.RetryLimit) {
        $cleanupProcess = Start-Process -FilePath "$env:WinDir\system32\cleanmgr.exe" -ArgumentList "/sagerun:42" -PassThru
Start-Job {Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd,int nCmdShow);
}
"@; $SW_HIDE=0; while (Get-Process -Name cleanmgr -EA 0) {Get-Process -Name cleanmgr -EA 0 | % {try {if ($_.MainWindowHandle -ne 0) {[Win32]::ShowWindow($_.MainWindowHandle,$SW_HIDE)*>$null}} catch {}}; Start-Sleep -Milliseconds 100}} *>$null
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $lastCpuUsage = 0
        $lastMemoryUsage = 0
        while ($cleanupProcess -and !$cleanupProcess.HasExited -and $stopwatch.Elapsed.TotalSeconds -lt $config.Timeout) {
            Start-Sleep -Seconds 10
            $process = Get-Process -Id $cleanupProcess.Id -EA 0
            if ($process) {
                $cpuUsage = $process.CPU
                $memoryUsage = $process.WS
                if ($cpuUsage -eq $lastCpuUsage -and $memoryUsage -eq $lastMemoryUsage) {
                    Write-Warning "Disk cleanup might be stuck. Terminating process."
                    if ($cleanupProcess.MainWindowHandle -ne 0) {$cleanupProcess.CloseMainWindow()*>$null;Start-Sleep -Seconds 5}
                    if (!$cleanupProcess.HasExited) {taskkill /f /pid $cleanupProcess.Id *>$null}
                    $i++
                    break
                }
                $lastCpuUsage = $cpuUsage
                $lastMemoryUsage = $memoryUsage
            }
        }
        if ($cleanupProcess -and $cleanupProcess.HasExited) {
            Write-Host "Disk cleanup done."
            return
        }
        if ($i -ge $config.RetryLimit) {
            Write-Warning "Disk cleanup failed after $config.RetryLimit attempts. Stopping process."
            if ($cleanupProcess -and !$cleanupProcess.HasExited) {taskkill /f /pid $cleanupProcess.Id *>$null}
            return
        }
    }
}

# ===========================
# File Cleanup
# ===========================
function Invoke-FileCleanup {
    Write-Host "`nStarting file cleanup"
    $config.Services | % {Stop-Service -Name $_ -Force -EA 0}

    Write-Host "Cleaning temp files..." -F DarkGray
    $config.TempPaths | ? {Test-Path $_} | % {gci -Path $_ -Recurse -Force -EA 0 | ? {$_.Name -ne 'AME'} | del -Recurse -Force -EA 0}

    Write-Host "Clearing log files..." -F DarkGray
    $config.LogPaths | ? {Test-Path $_} | % {del -Path $_ -Recurse -Force -EA 0}

    $config.Services | % {Start-Service -Name $_ -EA 0}

    Write-Host "File cleanup done."
}

# ===========================
# Entry Point
# ===========================
$systemDrive = ($env:SystemDrive).TrimEnd('\') + '\'
$noCleanmgr = $false 
$drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select -Expand DeviceID | % {($_.TrimEnd('\') + '\')} | ? {$_ -ne $systemDrive}

# === Check for other installations of Windows ===
# If other Windows installations are found, skip cleanup to avoid touching another drives, because it can risk modifying unintended data
foreach ($drive in $drives) {
    $systemHive = Join-Path $drive 'Windows\System32\config\SYSTEM'
    if (Test-Path -Path $systemHive -PathType Leaf -EA 0) {
        Write-Host "Not running Disk Cleanup, other Windows drive found: $drive"
        $noCleanmgr = $true
        break
    }
} if (!$noCleanmgr) {Invoke-DiskCleanup}

Invoke-FileCleanup

Write-Host "`nDone."