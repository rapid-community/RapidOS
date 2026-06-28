#Requires -RunAsAdministrator

param ([switch]$Cleanmgr, [switch]$Manual)
if (!$Cleanmgr -and !$Manual) {$Cleanmgr = $true; $Manual = $true}

Write-Host "--- System cleanup ---" -F Green
Write-Host "Removing disk clutter and logs`n"

# ==============================
# Configuration
# ==============================
$config = @{
    cleanup = @{
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
    svcs = 'bits', 'appidsvc', 'dps', 'wuauserv', 'cryptsvc'
    temps = "$env:TEMP", "$env:SystemRoot\Temp"
    logs = @(
        "$env:SystemRoot\DtcInstall.log",
        "$env:SystemRoot\comsetup.log",
        "$env:SystemRoot\PFRO.log",
        "$env:SystemRoot\Performance\WinSAT\winsat.log",
        "$env:SystemRoot\debug\PASSWD.LOG",
        "$env:SystemRoot\Logs\SIH\*",
        "$env:LOCALAPPDATA\Microsoft\CLR_v4.0\UsageTraces\*",
        "$env:LOCALAPPDATA\Microsoft\CLR_v4.0_32\UsageTraces\*",
        "$env:SystemRoot\Logs\NetSetup\*",
        "$env:SystemRoot\ff*.tmp",
        "$env:SystemRoot\System32\SleepStudy\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
        "$env:LOCALAPPDATA\IconCache.db"
    )
    timeout = 300
    retries = 3
}

# ==============================
# Disk Cleanup
# ==============================
function Invoke-DiskCleanup {
    Write-Host "Starting disk cleanup"
    taskkill /f /im cleanmgr.exe *>$null

    Write-Host "Setting cleanup keys..." -F DarkGray
    foreach ($item in $config.cleanup.GetEnumerator()) {
        Edit-Registry -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\$($item.Key)" -Name 'StateFlags0042' -Type DWord -Value $item.Value
    }

    Write-Host "Starting cleanmgr.exe..." -F DarkGray
    $i = 0
    while ($i -lt $config.retries) {
        $proc = Start-Process "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList '/sagerun:42' -PassThru
        $hider = Start-Job {
            Add-Type -Name W32 -Namespace H -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);' *>$null
            while (Get-Process cleanmgr -EA 0) {
                Get-Process cleanmgr -EA 0 | ? {$_.MainWindowHandle -ne 0} | % {[H.W32]::ShowWindow($_.MainWindowHandle, 0) *>$null}
                Start-Sleep -m 300
            }
        }

        $timer = [Diagnostics.Stopwatch]::StartNew()
        $cpu = -1; $mem = -1
        $stuck = $false
        while (!$proc.HasExited -and $timer.Elapsed.TotalSeconds -lt $config.timeout) {
            Start-Sleep -s 10
            $p = Get-Process -Id $proc.Id -EA 0
            if (!$p) {break}
            if ($p.CPU -eq $cpu -and $p.WS -eq $mem) {$stuck = $true; break}
            $cpu = $p.CPU; $mem = $p.WS
        }
        $hider | Remove-Job -Force *>$null

        if ($proc.HasExited) {
            Write-Host "Disk cleanup done."
            return
        }

        if ($stuck) {Write-Warning "Disk cleanup might be stuck. Terminating process."}
        if ($proc.MainWindowHandle -ne 0) {
            $proc.CloseMainWindow() *>$null
            Start-Sleep -s 5
        }
        if (!$proc.HasExited) {taskkill /f /pid $proc.Id *>$null}
        if ($stuck) {break}
        $i++
    }
}

# ==============================
# File Cleanup
# ==============================
function Invoke-FileCleanup {
    Write-Host "`nStarting file cleanup"
    foreach ($svc in $config.svcs) {taskkill /F /FI "SERVICES eq $svc" *>$null}

    Write-Host "Cleaning temp files..." -F DarkGray
    foreach ($path in $config.temps) {gci $path -Recurse -Force -EA 0 | ? {$_.Name -ne 'AME'} | del -Recurse -Force -EA 0}

    Write-Host "Cleaning log files..." -F DarkGray
    foreach ($path in $config.logs) {del $path -Recurse -Force -EA 0}

    Write-Host "File cleanup done."
}

# ==============================
# Entry Point
# ==============================
if ($Cleanmgr) {
    $sysdrive = $env:SystemDrive
    $skip = $false
    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ? {$_.DeviceID -ne $sysdrive} | Select -ExpandProperty DeviceID

    # === Check for other installations of Windows ===
    foreach ($drive in $drives) {
        $hive = "$drive\Windows\System32\config\SYSTEM"
        if (Test-Path $hive -PathType Leaf) {
            Write-Host "Not running Disk Cleanup, other Windows drive found: $drive"
            $skip = $true
            break
        }
    }
    if (!$skip) {Invoke-DiskCleanup}
}
if ($Manual) {Invoke-FileCleanup}

Write-Host "`nDone."