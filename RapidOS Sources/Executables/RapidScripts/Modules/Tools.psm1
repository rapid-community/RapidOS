function Export-RegState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$JsonPath
    )

    if (Test-Path $JsonPath) {return}

    function Get-KeyDataRecursive {
        param ($keyPath)

        $item = Get-Item -Path $keyPath -EA 0
        if (!$item) {return $null}

        $data = @{_values = @{}; _keys = @{}}

        foreach ($regVal in $item.GetValueNames()) {
            $value = $item.GetValue($regVal)
            $type = $item.GetValueKind($regVal).ToString().ToUpper()

            if ($type -eq 'QWORD' -and $value -gt 9007199254740991) {$value = "$value"}

            $data._values[$regVal] = @{
                Value = $value
                Type  = $type
            }
        }
        
        gci -Path $keyPath -EA 0 | % {
            $data._keys[$_.Name] = Get-KeyDataRecursive -keyPath $_.PSPath
        }
        return $data
    }

    $rootItem = Get-Item -Path $Path -EA 1
    $rootKeyName = $rootItem.Name
    $backup = @{$rootKeyName = Get-KeyDataRecursive -keyPath $Path}

    if ($backup[$rootKeyName]) {
        $backup | ConvertTo-Json -Depth 32 -Compress | Set-Content -Path $JsonPath -Encoding UTF8 -Force
    }

    Write-Host "Export successful." -F Green
}

function Import-RegState {
    [CmdletBinding()]
    param ([Parameter(Mandatory)][string]$JsonPath)

    if (!(Test-Path $JsonPath)) {Write-Host "`"$JsonPath`" not found." -F Red; return}
    
    $backup = Get-Content -Path $JsonPath -Encoding UTF8 -Raw | ConvertFrom-Json
    $rootKeyName = ($backup.PSObject.Properties | Select -First 1).Name

    function Restore-KeyRecursive {
        param ($keyPath, $keyData)
        
        $map = @{
            'HKEY_LOCAL_MACHINE'  = 'HKLM:'; 'HKEY_CURRENT_USER'   = 'HKCU:';
            'HKEY_CLASSES_ROOT'   = 'HKCR:'; 'HKEY_USERS'          = 'HKU:';
            'HKEY_CURRENT_CONFIG' = 'HKCC:'
        }
        $hive, $subPath = $keyPath.Split('\', 2)
        $path = $map[$hive] + $(if ($subPath) {'\' + $subPath} else {''})

        if (!(Test-Path $path)) {New-Item -Path $path -Force -EA 1 *>$null}

        $restoredKeys = $keyData._keys.PSObject.Properties | % {$_.Name}
        gci -Path $path -EA 0 | % {
            if ($_.Name -notin $restoredKeys) {Remove-Item -Path $_.PSPath -Recurse -Force -EA 1}
        }

        $restoredValues = $keyData._values.PSObject.Properties.Name
        (Get-Item -Path $path).GetValueNames() | % {
            if ($_ -notin $restoredValues) {Remove-ItemProperty -Path $path -Name $_ -Force -EA 1}
        }

        foreach ($regVal in $restoredValues) {
            $info = $keyData._values.$regVal
            $val = $info.Value
            $type = $info.Type
            if ($type -eq 'Binary') {$val = [byte[]]$val}
            if ($type -eq 'QWORD' -and $val -is [string]) {$val = [UInt64]::Parse($val)}
            Set-RegistryValue -Path $path -Name $regVal -Value $val -Type $type -EA 1
        }

        foreach ($subKeyName in $restoredKeys) {
            Restore-KeyRecursive -keyPath $subKeyName -keyData $keyData._keys.$subKeyName
        }
    }
    
    Restore-KeyRecursive -keyPath $rootKeyName -keyData $backup.$rootKeyName
    Write-Host "Restore successful." -F Green
}

function LimitNetwork {
    param ([string[]]$Services)

    $sysDir = "$env:WinDir\System32"
    $src = Join-Path $sysDir "svchost.exe"
    $restrictedExe = "restricted.exe"
    $dest = Join-Path $sysDir $restrictedExe

    if (!(Test-Path $dest)) {copy $src $dest -Force}
    & "$env:WinDir\RapidScripts\NetBlock.exe" install "$dest" *>$null

    $Services | % {
        $svcName = $_
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$svcName"
        $currentPath = (Get-ItemProperty $regPath -Name ImagePath -EA 0).ImagePath
        
        if ($currentPath -like "*svchost.exe*" -and $currentPath -notlike "*$restrictedExe*") {
            $updatedPath = $currentPath -replace "svchost\.exe", $restrictedExe
            Set-ItemProperty $regPath -Name ImagePath -Value $updatedPath
            Write-Host "Service '$svcName' now uses restricted svchost." -F DarkGray
        }
    }
}

function Get-Specs {
    [CmdletBinding()]
    param (
        [switch]$OS,
        [switch]$CPU,
        [switch]$RAM,
        [switch]$GPU
    )

    # === Bytes to readable format ===
    $toReadable = {[int64]$b=$args[0];$u='B','KB','MB','GB';$i=0
        while($b -gt 1kb -and $i -lt 3){$b/=1kb;$i++}
        "{0:N1} $($u[$i])" -f $b
    }

    # === Get the real Windows version like %SystemRoot%\system32\winver.exe relies on ===
    if (!("OSInfo" -as [type]) -and (Test-Path 'C:\Windows\System32\Winbrand.dll' -EA 0)) {
$cs = @"
using System;
using System.Runtime.InteropServices;
public class OSInfo {
    [DllImport("Winbrand.dll", CharSet=CharSet.Unicode)]
    static extern string BrandingFormatString(string fmt);
    public static string GetOSName() { 
        return BrandingFormatString("%WINDOWS_LONG%") ?? "Unknown OS";
    }
}
"@
    Add-Type -TypeDefinition $cs -Language CSharp
}

    # ===========================
    # Get OS info
    # ===========================
    switch ($true) {
        {[OSInfo] -as [type]} {
            $osName = [OSInfo]::GetOSName()
            $osVer = ''
            if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -EA 0) {
                $v = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -EA 0
                $osVer = "$($v.CurrentBuild).$($v.UBR)"
            }
            break
        }
        {(Get-CimInstance Win32_OperatingSystem -EA 0)} {
            $win = Get-CimInstance Win32_OperatingSystem -EA 0
            $osName = $win.Caption
            $osVer = "$($win.BuildNumber).$($win.UBR)"
            break
        }
        {Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -EA 0} {
            $k = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -EA 0
            $osName = $k.ProductName
            $osVer = "$($k.CurrentBuild).$($k.UBR)"
            break
        }
        default {
            $osName = 'Unknown OS'
            $osVer = ''
        }
    }
    $fullOS = "$osName (v$osVer)"

    # ===========================
    # Get CPU info
    # ===========================
    $proc = Get-CimInstance Win32_Processor -EA 0 | Select -First 1
    switch ($null -ne $proc) {
        $true {
            $cpuName = ($proc.Name -replace '\(R\)|\(TM\)|\s+',' ').Trim()
            $cores = $proc.NumberOfCores
            $threads = $proc.ThreadCount
        }
        default {
            $cpuName = 'Unknown CPU'
            $cores = 0
            $threads = 0
        }
    }

    # ===========================
    # Get RAM info
    # ===========================
    $mem = Get-CimInstance Win32_PhysicalMemory -EA 0
    if (!$mem) {$mem = Get-WmiObject Win32_PhysicalMemory -EA 0}
    $sum = ($mem | Measure-Object -Property Capacity -Sum).Sum
    $ramStr = if ($sum) {& $toReadable $sum} else {'0 B'}

    # ===========================
    # Get GPU info
    # ===========================
    $gpuStr = Get-CimInstance Win32_VideoController -EA 0 | 
        ? {$_.ConfigManagerErrorCode -eq 0} |
        Select -ExpandProperty Caption -First 1
    if (!$gpuStr) {
        $gpuStr = Get-PnpDevice -Class Display -EA 0 |
            ? {$_.FriendlyName -notmatch 'Microsoft|Basic'} |
            Select -First 1 -ExpandProperty FriendlyName
    }

    $gpuName = if ($gpuStr) {$gpuStr} else {'Unknown GPU'}

    # ===========================
    # Output info
    # ===========================
    $all = !$PSBoundParameters.Count
    foreach ($flag in 'OS','CPU','RAM','GPU') {
        if ($all -or $PSBoundParameters[$flag]) {
            switch ($flag) {
                'OS' {
                    Write-Output "OS: $fullOS"
                    Write-Output "VM: $(Test-VM)"
                }
                'CPU' {
                    Write-Output "CPU: $cpuName"
                    Write-Output "Cores: $cores | Threads: $threads"
                }
                'RAM' {
                    Write-Output "RAM: $ramStr"
                }
                'GPU' {
                    Write-Output "GPU: $gpuName"
                }
            }
        }
    }
}

Export-ModuleMember -Function Export-RegState, Import-RegState, LimitNetwork, Get-Specs