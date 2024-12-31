param (
    [string]$MyArgument
)

# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) { Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow; $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -MyArgument {1}" -f $PSCommandPath, $MyArgument; Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs; exit }

# Function to set registry values
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

# Function to remove registry values
function Remove-RegistryValue {
    param (
        [string]$Path,
        [string]$Name
    )
    if (Test-Path $Path) {
        Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue
    }
}

function Show-Usage {
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " .\Power-Optimizer.ps1 -MyArgument <option>" -ForegroundColor White
    Write-Host ""

    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " - balanced_performance :  Balanced scheme; without performance parameters." -ForegroundColor Gray
    Write-Host " - high_performance : Ultimate Performance scheme; with performance parameters." -ForegroundColor Gray
    Write-Host " - maximized_performance : AMD, Intel for Win10 and 11 schemes (may be unstable); with performance parameters." -ForegroundColor Gray
    Write-Host ""

    Write-Host "Example:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " .\Power-Optimizer.ps1 -MyArgument high_performance" -ForegroundColor White
    Write-Host " .\Power-Optimizer.ps1 -MyArgument maximized_performance" -ForegroundColor White
    Write-Host ""
}

switch ($MyArgument) {
    "balanced_performance" {
        # Use Balanced scheme
        powercfg.exe /setactive 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null

        # Check for existing power scheme and delete it if found
        $schemeGuid = '12111111-1211-1211-1211-121111111111'
        if (powercfg.exe /list | Select-String -Pattern $schemeGuid) {
            Start-Sleep -Seconds 1
            powercfg.exe /delete $schemeGuid | Out-Null
        }

        # Enable USB selective suspend
        $usb_devices = @('Win32_USBController', 'Win32_USBControllerDevice', 'Win32_USBHub')
        $power_device_status = Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable
        foreach ($device_status in $power_device_status) {
            $instance_name = $device_status.InstanceName.ToUpper()
            foreach ($usb_device in $usb_devices) {
                foreach ($hub_device in Get-CimInstance -ClassName $usb_device) {
                    $pnp_id = $hub_device.PNPDeviceID
                    if ($instance_name -like "*$pnp_id*") {
                        $device_status.enable = $True
                        $device_status | Set-CimInstance
                    }
                }
            }
        }

        # Enable network power-saving
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" -Name "DefaultPnPCapabilities" -Value 0
        Get-NetAdapter -Physical | Get-NetAdapterAdvancedProperty | Where-Object { @(
            "ULPMode", "EEE", "EEELinkAdvertisement", "AdvancedEEE", "EnableGreenEthernet", "EeePhyEnable", "uAPSDSupport", 
            "EnablePowerManagement", "EnableSavePowerNow", "bLowPowerEnable", "PowerSaveMode", "PowerSavingMode", 
            "SavePowerNowEnabled", "AutoPowerSaveModeEnabled", "NicAutoPowerSaver", "SelectiveSuspend"
        ) -contains $_.RegistryKeyword } | Reset-NetAdapterAdvancedProperty

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
    "high_performance" {
        # Get the processor manufacturer
        $manufacturer = (Get-WmiObject Win32_Processor).Manufacturer

        # Activate the Balanced power plan temporarily
        powercfg.exe /setactive 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null

        # Check for existing power scheme and delete it if found
        $schemeGuid = "12111111-1211-1211-1211-121111111111"
        if (powercfg.exe /list | Select-String -Pattern $schemeGuid) {
            Start-Sleep -Seconds 1
            powercfg.exe /delete $schemeGuid | Out-Null
        }

        # Use Ultimate Performance scheme
        powercfg.exe /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 $schemeGuid | Out-Null
        powercfg.exe /setactive $schemeGuid

        # Disable USB selective suspend
        $usb_devices = @('Win32_USBController', 'Win32_USBControllerDevice', 'Win32_USBHub')
        $power_device_status = Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable
        foreach ($device_status in $power_device_status) {
            $instance_name = $device_status.InstanceName.ToUpper()
            foreach ($usb_device in $usb_devices) {
                foreach ($hub_device in Get-CimInstance -ClassName $usb_device) {
                    $pnp_id = $hub_device.PNPDeviceID
                    if ($instance_name -like "*$pnp_id*") {
                        $device_status.enable = $False
                        $device_status | Set-CimInstance
                    }
                }
            }
        }

        # Configure various power settings
        powercfg.exe /setacvalueindex scheme_current 0012ee47-9041-4b5d-9b77-535fba8b1442 d3d55efd-c1ff-424e-9dc3-441be7833010 0
        powercfg.exe /setacvalueindex scheme_current 0012ee47-9041-4b5d-9b77-535fba8b1442 d639518a-e56d-4345-8af2-b9f32fb26109 0
        powercfg.exe /setacvalueindex scheme_current 0012ee47-9041-4b5d-9b77-535fba8b1442 fc7372b6-ab2d-43ee-8797-15e9841f2cca 0
        powercfg.exe /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 0853a681-27c8-4100-a2fd-82013e970683 0
        powercfg.exe /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        powercfg.exe /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 0
        powercfg.exe /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 3b04d4fd-1cc7-4f23-ab1c-d1337819c4bb 0
        powercfg.exe /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 17aaa29b-8b43-4b94-aafe-35f64daaf1ee 0
        powercfg.exe /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 0
        powercfg.exe /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 4d2b0152-7d5c-498b-88e2-34345392a2c5 200 

        # Disable network power-saving
        $properties = Get-NetAdapter -Physical | Get-NetAdapterAdvancedProperty
        foreach ($setting in @("ULPMode", "EEE", "EEELinkAdvertisement", "AdvancedEEE", "EnableGreenEthernet", "EeePhyEnable", "uAPSDSupport", "EnablePowerManagement", "EnableSavePowerNow", "bLowPowerEnable", "PowerSaveMode", "PowerSavingMode", "SavePowerNowEnabled", "AutoPowerSaveModeEnabled", "NicAutoPowerSaver", "SelectiveSuspend")) {
            $properties | Where-Object { $_.RegistryKeyword -eq "*$setting" -or $_.RegistryKeyword -eq $setting } | Set-NetAdapterAdvancedProperty -RegistryValue 0
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
    "maximized_performance" {
        # Get the processor manufacturer
        $manufacturer = (Get-WmiObject Win32_Processor).Manufacturer

        # Activate the Balanced power plan temporarily
        powercfg.exe /setactive 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null

        # Check for existing power scheme and delete it if found
        $schemeGuid = "12111111-1211-1211-1211-121111111111"
        if (powercfg.exe /list | Select-String -Pattern $schemeGuid) {
            Start-Sleep -Seconds 1
            powercfg.exe /delete $schemeGuid | Out-Null
        }
        
        # Intel Schemes
        # Discord: @Kivarri
        # AMD Scheme
        # GitHub: https://github.com/ZEFIR001/Extreme-Low-Latency-Windows-Power-Plan-AMD
        
        # Import power schemes based on the processor type
        $build = (Get-WmiObject Win32_OperatingSystem).BuildNumber
        if ($manufacturer -eq 'AuthenticAMD') {
            powercfg.exe /import "$env:WinDir\RapidScripts\Power Configurations\AMD-ZEFIR001.V2.pow" $schemeGuid | Out-Null
            powercfg.exe /setactive $schemeGuid
        } elseif ($manufacturer -eq 'GenuineIntel') {
            if ($build -le 19045) {
                # Windows 10 (build 19045 or lower)
                powercfg.exe /import "$env:WinDir\RapidScripts\Power Configurations\Intel-@Kivarri-Win10.pow" $schemeGuid | Out-Null
                powercfg.exe /setactive $schemeGuid
            } elseif ($build -ge 22000) {
                # Windows 11 (build 22000 or higher)
                powercfg.exe /import "$env:WinDir\RapidScripts\Power Configurations\Intel-@Kivarri-Win11.pow" $schemeGuid | Out-Null
                powercfg.exe /setactive $schemeGuid
            } else {
                # Use modified Ultimate Performance scheme if manufacturer not found
                powercfg.exe /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 $schemeGuid | Out-Null
                powercfg.exe /setactive $schemeGuid

                # Configure various power settings
                powercfg.exe /setacvalueindex scheme_current 0012ee47-9041-4b5d-9b77-535fba8b1442 d3d55efd-c1ff-424e-9dc3-441be7833010 0
                powercfg.exe /setacvalueindex scheme_current 0012ee47-9041-4b5d-9b77-535fba8b1442 d639518a-e56d-4345-8af2-b9f32fb26109 0
                powercfg.exe /setacvalueindex scheme_current 0012ee47-9041-4b5d-9b77-535fba8b1442 fc7372b6-ab2d-43ee-8797-15e9841f2cca 0
                powercfg.exe /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 0853a681-27c8-4100-a2fd-82013e970683 0
                powercfg.exe /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
                powercfg.exe /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 0
                powercfg.exe /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 3b04d4fd-1cc7-4f23-ab1c-d1337819c4bb 0
                powercfg.exe /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 17aaa29b-8b43-4b94-aafe-35f64daaf1ee 0
                powercfg.exe /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 0
                powercfg.exe /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 4d2b0152-7d5c-498b-88e2-34345392a2c5 200
            }
        }

        # Disable network power-saving
        $properties = Get-NetAdapter -Physical | Get-NetAdapterAdvancedProperty
        foreach ($setting in @("ULPMode", "EEE", "EEELinkAdvertisement", "AdvancedEEE", "EnableGreenEthernet", "EeePhyEnable", "uAPSDSupport", "EnablePowerManagement", "EnableSavePowerNow", "bLowPowerEnable", "PowerSaveMode", "PowerSavingMode", "SavePowerNowEnabled", "AutoPowerSaveModeEnabled", "NicAutoPowerSaver", "SelectiveSuspend")) {
            $properties | Where-Object { $_.RegistryKeyword -eq "*$setting" -or $_.RegistryKeyword -eq $setting } | Set-NetAdapterAdvancedProperty -RegistryValue 0
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
    default {
        Write-Host "Error: Invalid argument "$MyArgument"" -ForegroundColor Red
        Write-Host ""
        Show-Usage
    }
}

# Additional modifications without an argument
Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" -Name "IdlePowerMode" -Type DWORD -Value 0
Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Storage" -Name "StorageD3InModernStandby" -Type DWORD -Value 0
Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Type DWORD -Value 0

wevtutil sl Microsoft-Windows-SleepStudy/Diagnostic /q:false | Out-Null
wevtutil sl Microsoft-Windows-Kernel-Processor-Power/Diagnostic /q:false | Out-Null
wevtutil sl Microsoft-Windows-UserModePowerService/Diagnostic /q:false | Out-Null