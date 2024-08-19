param (
    [string]$MyArgument
)

# Function to set registry value
function Set-RegistryValue {
    param (
        [string]$Path,
        [string]$Name,
        [string]$Type,
        [string]$Value
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Type $Type -Value $Value -Force
}

# Function to remove registry value
function Remove-RegistryValue {
    param (
        [string]$Path,
        [string]$Name
    )
    if (Test-Path $Path) {
        Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue
    }
}

if ($MyArgument -eq "enable_power_saving") {
    # Restore all default schemes
    # powercfg.exe /restoredefaultschemes | Out-Null

    # Set the 'Balanced' power plan as active temporarily
    powercfg.exe /setactive 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null

    # Check for the existence and delete the existing power scheme
    $schemeGuid = '12111111-1211-1211-1211-121111111111'
    $existingSchemes = powercfg.exe /list | Select-String -Pattern $schemeGuid
    if ($existingSchemes) {
        Start-Sleep -Seconds 1 # Wait to ensure the 'Balanced' scheme has switched
        powercfg.exe /delete $schemeGuid | Out-Null
    }

    # Import the RapidOS power scheme if someone will need it even on power saving mode
    powercfg.exe /import "$env:WinDir\RapidScripts\RapidOS-Scheme.pow" $schemeGuid | Out-Null

    # Enable USB selective suspend
    $usb_devices = @('Win32_USBController', 'Win32_USBControllerDevice', 'Win32_USBHub')
    $power_device_enable = Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable
    foreach ($power_device in $power_device_enable) {
        $instance_name = $power_device.InstanceName.ToUpper()
        foreach ($device in $usb_devices) {
            foreach ($hub in Get-CimInstance -ClassName $device) {
                $pnp_id = $hub.PNPDeviceID
                if ($instance_name -like "*$pnp_id*") {
                    $power_device.enable = $True
                    $power_device | Set-CimInstance
                }
            }
        }
    }

    # Remove performance parameters if they exist
    Remove-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" -Name "DefaultPnPCapabilities"
    Remove-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "CoalescingTimerInterval"
    Remove-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "CoalescingTimerInterval"
    Remove-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "CoalescingTimerInterval"
    Remove-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "CoalescingTimerInterval"
    Remove-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Executive" -Name "CoalescingTimerInterval"
    Remove-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\ModernSleep" -Name "CoalescingTimerInterval"
    Remove-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "CoalescingTimerInterval"
    Remove-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "PlatformAoAcOverride"
    Remove-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff"

    # Remove KBoost
    Remove-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" -Name "PerfLevelSrc"
    Remove-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" -Name "PowerMizerEnable"
    Remove-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" -Name "PowerMizerLevel"
    Remove-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" -Name "PowerMizerLevelAC"
} 

if ($MyArgument -eq "disable_power_saving") {
    # Restore all default schemes
    # powercfg.exe /restoredefaultschemes | Out-Null

    # Set the 'Balanced' power plan as active temporarily
    powercfg.exe /setactive 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null

    # Check for the existence and delete the existing power scheme
    $schemeGuid = '12111111-1211-1211-1211-121111111111'
    $existingSchemes = powercfg.exe /list | Select-String -Pattern $schemeGuid
    if ($existingSchemes) {
        Start-Sleep -Seconds 1 # Wait to ensure the 'Balanced' scheme has switched
        powercfg.exe /delete $schemeGuid | Out-Null
    }

    # Import the RapidOS power scheme if someone will need it even on power saving mode
    powercfg.exe /import "$env:WinDir\RapidScripts\RapidOS-Scheme.pow" $schemeGuid | Out-Null

    # Import RapidOS Performance power plan
    powercfg.exe /setactive 12111111-1211-1211-1211-121111111111 | Out-Null

    # Disable USB selective suspend
    $usb_devices = @('Win32_USBController', 'Win32_USBControllerDevice', 'Win32_USBHub')
    $power_device_enable = Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable
    foreach ($power_device in $power_device_enable) {
        $instance_name = $power_device.InstanceName.ToUpper()
        foreach ($device in $usb_devices) {
            foreach ($hub in Get-CimInstance -ClassName $device) {
                $pnp_id = $hub.PNPDeviceID
                if ($instance_name -like "*$pnp_id*") {
                    $power_device.enable = $False
                    $power_device | Set-CimInstance
                }
            }
        }
    }

    # Activate performance parameters
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" -Name "DefaultPnPCapabilities" -Type DWORD -Value 24
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "CoalescingTimerInterval" -Type DWORD -Value 0
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "CoalescingTimerInterval" -Type DWORD -Value 0
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "CoalescingTimerInterval" -Type DWORD -Value 0
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "CoalescingTimerInterval" -Type DWORD -Value 0
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Executive" -Name "CoalescingTimerInterval" -Type DWORD -Value 0
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\ModernSleep" -Name "CoalescingTimerInterval" -Type DWORD -Value 0
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "CoalescingTimerInterval" -Type DWORD -Value 0
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "PlatformAoAcOverride" -Type DWORD -Value 0
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Type DWORD -Value 1

    # Enable KBoost
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" -Name "PerfLevelSrc" -Type DWORD -Value 2222
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" -Name "PowerMizerEnable" -Type DWORD -Value 0
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" -Name "PowerMizerLevel" -Type DWORD -Value 0
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" -Name "PowerMizerLevelAC" -Type DWORD -Value 0
}

# Additional registry modifications without an argument
Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" -Name "IdlePowerMode" -Type DWORD -Value 0
Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Storage" -Name "StorageD3InModernStandby" -Type DWORD -Value 0
Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Type DWORD -Value 0