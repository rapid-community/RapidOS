#Requires -RunAsAdministrator

param (
    [Parameter(Mandatory = $true, HelpMessage = "Available options: Configure-DeviceInterrupts, Configure-Adapters, Configure-Drive")]
    [string[]]$Device
)

# === Check for VMs ===
if (Test-VM) {return}

function Set-MessageSignaledInterrupt {
    # ==============================
    # MSI mode for core devices
    # ==============================
    $list = @()
    gci 'HKLM:\SYSTEM\CurrentControlSet\Enum\PCI' -Recurse -EA 0 | % {
        $props = Get-ItemProperty -Path $_.PSPath -EA 0
        if ($props.DeviceDesc) {
            # === GPU ===
            if ($props.DeviceDesc -match '(?i)(geforce|radeon|intel hd|iris xe)') {
                $list += @{Role = 'GPU'; RegistryPath = $_.Name}
            }
            # === Audio ===
            elseif ($props.DeviceDesc -match '(?i)High Definition Audio Controller') {
                $list += @{Role = 'Audio'; RegistryPath = $_.Name}
            }
            # === Storage ===
            elseif ($props.DeviceDesc -match '(?i)(NVM|AHCI|SATA|SCSI|RAID) Controller') {
                $list += @{Role = 'Storage'; RegistryPath = $_.Name}
            }
        }
    }

    # === USB ===
    try {
        Get-CimInstance -ClassName Win32_USBController | ? {$_.ConfigManagerErrorCode -ne 22} | % {
            $pnpId = $_.PNPDeviceID.Replace('\', '\\')
            $entry = Get-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpId" -EA 0
            if ($entry) {
                $list += @{Role = 'USB'; RegistryPath = $entry.Name}
            }
        }
    } catch {}

    $list | % {
        $formattedPath = $_.RegistryPath.Replace('HKEY_LOCAL_MACHINE', 'HKLM:')

        $affinityPath = "$formattedPath\Device Parameters\Interrupt Management\Affinity Policy"
        Set-RegistryValue -Path $affinityPath -Name 'DevicePriority' -Type DWORD -Value 3

        if ($_.Role -in @('GPU', 'Audio', 'Storage', 'USB')) {
            $msiPath = "$formattedPath\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            Set-RegistryValue -Path $msiPath -Name 'MSISupported' -Type DWORD -Value 1
            Remove-ItemProperty -Path $msiPath -Name 'MessageNumberLimit' -EA 0
        }
    }
}

function Set-NetConfig {
    # === Vendor Identification ===
    $adapterKeys = gci 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}' | ? {$_.Property -like '*SpeedDuplex*'} | % {"HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}\$($_.PSChildName)"}
    $adapterVendor = (Get-CimInstance Win32_NetworkAdapter).Manufacturer |
    % {
        if ($_ -match 'Realtek') {'Realtek'}
        elseif ($_ -match 'Intel') {'Intel'}
    } | Sort-Object -Unique

    # ==============================
    # Intel configuration
    # ==============================
    # === Adapter settings ===
    if ($adapterVendor -contains 'Intel') {
        $settings = @{
            "*EncapsulatedPacketTaskOffloadNvgre"="1"
            "*EncapsulatedPacketTaskOffloadVxlan"="1"
            "*EncapsulatedPacketTaskOffload"="1"
            "*IPChecksumOffloadIPv4"="3"
            "*LsoV1IPv4"="1"
            "*LsoV2IPv4"="1"
            "*LsoV2IPv6"="1"
            "*TCPChecksumOffloadIPv4"="3"
            "*TCPChecksumOffloadIPv6"="3"
            "*UDPChecksumOffloadIPv4"="3"
            "*UDPChecksumOffloadIPv6"="3"
            "*IPsecOffloadV1IPv4"="3"
            "*IPsecOffloadV2"="3"
            "*IPsecOffloadV2IPv4"="3"
            "*TCPConnectionOffloadIPv4"="3"
            "*TCPConnectionOffloadIPv6"="3"
            "*TCPUDPChecksumOffloadIPv4"="3"
            "*TCPUDPChecksumOffloadIPv6"="3"
            "*UsoIPv4"="1"
            "*UsoIPv6"="1"
            # "*VMQ"="0"
            # "VMQSupported"="0"
            "*RscIPv4"="1"
            "*RscIPv6"="1"
            "*UdpRsc"="1"
            "ForceRscEnabled"="1"
            "*PMARPOffload"="1"
            "*PMNSOffload"="1"
            "*PMWiFiRekeyOffload"="1"
            # "*InterruptModeration"="0"
            "*ReceiveBuffers"="1024"
            "EnableAdaptiveQueuing"="0"
            "StoreBadPackets"="0"
            "DynamicLTR"="0"
            "*TransmitBuffers"="1024"
            "DropHighlyFragmentedPacket"="1"
            "EnableCoalesce"="0"
            "*PacketDirect"="1"
            "AllowFlowControlFrames"="0"
            "*StoreBadPackets"="0"
            "EnableTss"="1"
            # "*FlowControl"="0"
            "*PriorityVLANTag"="0"
        }

        foreach ($key in $adapterKeys) {
            foreach ($name in $settings.Keys) {
                Set-RegistryValue -Path $key -Name $name -Type String -Value $settings[$name]
            }
        }
    }

    # === Power management (Desktop only) ===
    if ($adapterVendor -contains 'Intel' -and !(Test-Laptop)) {
        $settings = @{
            "*ModernStandbyWoLMagicPacket"="0"
            "*SelectiveSuspend"="0"
            "*WakeOnMagicPacket"="0"
            "*WakeOnPattern"="0"
            "EnablePME"="0"
            "LogLinkStateEvent"="0"
            "WaitAutoNegComplete"="0"
            "WakeOnLink"="0"
            "DMACoalescing"="0"
            "EEELinkAdvertisement"="0"
            "*DeviceSleepOnDisconnect"="0"
            "*NicAutoPowerSaver"="0"
            "EnableModernStandby"="0"
            "EnablePowerManagement"="0"
            "ForceWakeFromMagicPacketOnModernStandby"="0"
            "WakeFromS5"="0"
            "WakeOn"="0"
            "LinkNegotiationProcess"="0"
            "WaitForValidPhyIDRead"="0"
            "SleepWhileWaiting"="0"
            "EnableETW"="0"
            "OBFFEnabled"="0"
            "I218DisablePLLShut"="1"
            "I218DisablePLLShutGiga"="1"
            "I219DisableK1Off"="1"
            "DisableIntelRST"="1"
            "ForceLtrValue"="0"
            "EnableDisconnectedStandby"="0"
            "EnableWakeOnManagmentOnTCO"="0"
            "EnablePHYFlexibleSpeed"="0"
            "EnablePHYWakeUp"="0"
            "EnableD0PHYFlexibleSpeed"="0"
            "EnableSavePowerNow"="0"
            "AutoPowerSaveModeEnabled"="0"
            "SipsEnabled"="0"
            "WakeOnFastStartup"="0"
            "*EnableDynamicPowerGating"="0"
            "*EEE"="0"
            "EnableD3ColdInS0"="0"
            "*SSIdleTimeout"="0"
            "SSIdleTimeoutMS"="0"
            "LatencyToleranceReporting"="0"
        }

        foreach ($key in $adapterKeys) {
            foreach ($name in $settings.Keys) {
                Set-RegistryValue -Path $key -Name $name -Type String -Value $settings[$name]
            }
        }
    }

    # ==============================
    # Realtek configuration
    # ==============================
    # === Adapter settings ===
    if ($adapterVendor -contains 'Realtek') {
        $settings = @{
            "*EncapsulatedPacketTaskOffloadNvgre"="1"
            "*EncapsulatedPacketTaskOffloadVxlan"="1"
            "*EncapsulatedPacketTaskOffload"="1"
            "*IPChecksumOffloadIPv4"="3"
            "*LsoV1IPv4"="1"
            "*LsoV2IPv4"="1"
            "*LsoV2IPv6"="1"
            "*TCPChecksumOffloadIPv4"="3"
            "*TCPChecksumOffloadIPv6"="3"
            "*UDPChecksumOffloadIPv4"="3"
            "*UDPChecksumOffloadIPv6"="3"
            "*IPsecOffloadV1IPv4"="3"
            "*IPsecOffloadV2"="3"
            "*IPsecOffloadV2IPv4"="3"
            "*TCPConnectionOffloadIPv4"="3"
            "*TCPConnectionOffloadIPv6"="3"
            "*TCPUDPChecksumOffloadIPv4"="3"
            "*TCPUDPChecksumOffloadIPv6"="3"
            "*UsoIPv4"="1"
            "*UsoIPv6"="1"
            # "*VMQ"="0"
            # "VMQSupported"="0"
            "*RscIPv4"="1"
            "*RscIPv6"="1"
            "*UdpRsc"="1"
            "ForceRscEnabled"="1"
            "*PMARPOffload"="1"
            "*PMNSOffload"="1"
            "*PMWiFiRekeyOffload"="1"
            "*IdleRestriction"="1"
            # "*InterruptModeration"="0"
            "*ReceiveBuffers"="1024"
            "EnableAdaptiveQueuing"="0"
            "StoreBadPackets"="0"
            "DynamicLTR"="0"
            "*TransmitBuffers"="1024"
            "DropHighlyFragmentedPacket"="1"
            "EnableCoalesce"="0"
            "*PacketDirect"="1"
            "AllowFlowControlFrames"="0"
            "*StoreBadPackets"="0"
            "EnableTss"="1"
            # "*FlowControl"="0"
            "*PriorityVLANTag"="0"
        }

        foreach ($key in $adapterKeys) {
            foreach ($name in $settings.Keys) {
                Set-RegistryValue -Path $key -Name $name -Type String -Value $settings[$name]
            }
        }
    }

    # === Power management (Desktop only) ===
    if ($adapterVendor -contains 'Realtek' -and !(Test-Laptop)) {
        $settings = @{
            "*SelectiveSuspend"="0"
            "*WakeOnMagicPacket"="0"
            "*WakeOnPattern"="0"
            "*DeviceSleepOnDisconnect"="0"
            "*SSIdleTimeout"="0"
            "*SSIdleTimeoutScreenOff"="0"
            "*EEE"="0"
            "AdvancedEEE"="0"
            "ASPM"="0"
            "CLKREQ"="0"
            "EEEPlus"="0"
            "EnableAspm"="0"
            "EnableGreenEthernet"="0"
            "GPPSW"="0"
            "EPSDRT"="0"
            "GigaLite"="0"
            "LTROBF"="0"
            "PowerDownPll"="0"
            "PowerSavingMode"="0"
        }

        foreach ($key in $adapterKeys) {
            foreach ($name in $settings.Keys) {
                Set-RegistryValue -Path $key -Name $name -Type String -Value $settings[$name]
            }
        }
    }

    # === Network offload settings ===
    Set-NetOffloadGlobalSetting -ReceiveSegmentCoalescing Enable
    Set-NetOffloadGlobalSetting -PacketCoalescingFilter Disable
}

function Set-DrivesConfiguration {
    # === Check if the system has an SSD ===
    $systemDriveLetter = $env:SystemDrive.Substring(0, 1)
    $diskNumber = (Get-Partition -DriveLetter $systemDriveLetter).DiskNumber
    $serialNumber = (Get-Disk -Number $diskNumber).SerialNumber.TrimStart()
    $mediaType = (Get-PhysicalDisk -SerialNumber $serialNumber).MediaType

    # ==============================
    # Apply if the drive is an SSD
    # ==============================
    if ($mediaType -eq 'SSD') {
        Write-Host "Configuring system settings for SSD..."

        # === Disable hibernation ===
        if (!(Test-Laptop)) {
            powercfg /h off
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'HiberbootEnabled' -Type DWORD -Value 0
            Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Type DWORD -Value 0
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings' -Name 'ShowHibernateOption' -Type DWORD -Value 0
            Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -Name 'HibernateEnabled' -Type DWORD -Value 0
        } else {
            powercfg /h /type reduced
            powercfg hibernate size 0
            powercfg /h /type reduced
        }

        # === Enable TRIM support for SSDs ===
        fsutil behavior set disabledeletenotify 0 *>$null

        # === Disable task related to HDD ===
        Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Data Integrity Scan\" -TaskName "Data Integrity Scan" *>$null

        Write-Host "Configuration for SSD completed."
    } else {
        Write-Host "No SSD drive found."
    }

    # === Optimize C:\ ===
    Get-Volume -DriveLetter C | Optimize-Volume
}

# === Disables device power saving on desktops ===
if (!(Test-Laptop)) {
    Set-CimInstance -Namespace 'root\wmi' -Query 'SELECT * FROM MSPower_DeviceEnable' -Property @{Enable = $false}
}

# === Function call based on the argument ===
foreach ($arg in $Device) {
    switch ($arg) {
        "Configure-DeviceInterrupts" {Set-MessageSignaledInterrupt}
        "Configure-Adapters" {Set-NetConfig}
        "Configure-Drives" {Set-DrivesConfiguration}
        default {
            Write-Host "Error: Invalid argument `"$arg`"" -F Red
        }
    }
}