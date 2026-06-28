#Requires -RunAsAdministrator

param (
    [Parameter(Mandatory = $true, HelpMessage = 'Available options: Configure-DeviceInterrupts, Configure-Adapters, Configure-Drives, Configure-Audio')]
    [string[]]$Device
)

# === Check for VMs ===
if (Test-VM) {return}

function Set-MessageSignaledInterrupt {
    $targets = @()

    # === GPU ===
    $gpus = Get-CimInstance -ClassName Win32_PnPEntity -EA 0 | ? {
        $_.PNPDeviceID -like 'PCI\*' -and
        $_.ClassGuid -eq '{4d36e968-e325-11ce-bfc1-08002be10318}' -and
        $_.ConfigManagerErrorCode -eq 0
    }
    foreach ($gpu in $gpus) {$targets += $gpu.PNPDeviceID}

    # === USB ===
    $usb = Get-CimInstance -ClassName Win32_USBController -EA 0 | ? {
        $_.PNPDeviceID -like 'PCI\*' -and
        $_.ConfigManagerErrorCode -ne 22
    }
    foreach ($u in $usb) {if ($u.PNPDeviceID -notin $targets) {$targets += $u.PNPDeviceID}}

    # === Audio ===
    $audio = Get-CimInstance -ClassName Win32_PnPEntity -EA 0 | ? {
        $_.PNPDeviceID -like 'PCI\*' -and
        $_.Service -eq 'HDAudBus' -and
        $_.ConfigManagerErrorCode -eq 0
    }
    foreach ($a in $audio) {if ($a.PNPDeviceID -notin $targets) {$targets += $a.PNPDeviceID}}

    foreach ($id in $targets) {
        $msi = "HKLM\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        Edit-Registry -Path $msi -Name 'MSISupported' -Type DWord -Value 1
    }
}

function Set-NetConfig {
    # ==============================
    # Variables
    # ==============================
    $laptop = Test-Laptop
    $val = if ($laptop) {'1'} else {'0'}
    $reg = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}'

    # ==============================
    # Adapters
    # ==============================
    $adapters = gci $reg -EA 0 | ? {$_.PSChildName -match '^\d{4}$'}
    foreach ($adapter in $adapters) {
        $path = "$reg\$($adapter.PSChildName)"
        $data = Get-ItemProperty -Path $path -EA 0
        $dev = $data.MatchingDeviceId

        # === Validation ===
        if ([string]::IsNullOrWhiteSpace($dev) -or $dev -notmatch '^PCI\\') {continue}

        # === Hardware ID ===
        if ($dev -match 'VEN_([0-9A-F]{4})') {
            $id = $Matches[1].ToUpper()
        } else {continue}

        # === Cleanup ===
        Edit-Registry -Path $path -Name '*SpeedDuplex' -Remove
        Edit-Registry -Path $path -Name 'SpeedDuplex' -Remove

        # ==============================
        # NDIS
        # ==============================
        # === Common ===
        $config = [ordered]@{
            "*DeviceSleepOnDisconnect"="0"; "*EncapsulatedPacketTaskOffload"="1";
            "*EncapsulatedPacketTaskOffloadNvgre"="1"; "*EncapsulatedPacketTaskOffloadVxlan"="1";
            "*FlowControl"="0"; "*IPChecksumOffloadIPv4"="3"; "*IPsecOffloadV1IPv4"="3";
            "*IPsecOffloadV2"="3"; "*IPsecOffloadV2IPv4"="3"; "*LsoV1IPv4"="1";
            "*PMARPOffload"="1"; "*PMNSOffload"="1"; "*PMWiFiRekeyOffload"="1";
            "*PacketDirect"="1"; "*RscIPv4"="0"; "*RscIPv6"="0";
            "*TCPChecksumOffloadIPv4"="3"; "*TCPChecksumOffloadIPv6"="3";
            "*TCPConnectionOffloadIPv4"="3"; "*TCPConnectionOffloadIPv6"="3";
            "*TCPUDPChecksumOffloadIPv4"="3"; "*TCPUDPChecksumOffloadIPv6"="3";
            "*UDPChecksumOffloadIPv4"="3"; "*UDPChecksumOffloadIPv6"="3";
            "*UdpRsc"="1"; "*UsoIPv4"="1"; "*UsoIPv6"="1"; "ForceRscEnabled"="0";
            "*EEE"="0"; "EEELinkAdvertisement"="0"; "EnableGreenEthernet"="0"
        }

        # === Vendor ===
        switch ($id) {
            '8086' { # INTEL
                $map = @{
                    "*InterruptModeration"=$val; "*LsoV2IPv4"="1"; "*LsoV2IPv6"="1";
                    "*WakeOnMagicPacket"="0"; "*WakeOnPattern"="0"; "EnablePME"="0"; "LogLinkStateEvent"="0";
                    "WaitAutoNegComplete"="0"; "WakeOnLink"="0"; "DMACoalescing"="0";
                    "WakeFromS5"="0"; "WakeOn"="0"; "LinkNegotiationProcess"="0"; "WaitForValidPhyIDRead"="0";
                    "SleepWhileWaiting"="0"; "EnableETW"="0"; "OBFFEnabled"="0"; "I218DisablePLLShut"="1";
                    "I218DisablePLLShutGiga"="1"; "I219DisableK1Off"="1"; "ForceLtrValue"="0";
                    "EnableWakeOnManagmentOnTCO"="0"; "EnablePHYFlexibleSpeed"="0"; "EnablePHYWakeUp"="0";
                    "EnableD0PHYFlexibleSpeed"="0"; "EnableSavePowerNow"="0"; "SipsEnabled"="0"; "WakeOnFastStartup"="0";
                    "EnableD3ColdInS0"="0"; "*SSIdleTimeout"="0"; "SSIdleTimeoutMS"="0";
                    "LatencyToleranceReporting"="0"; "*VMQ"="0"; "VMQSupported"="0";
                    "EnableAdaptiveQueuing"="0"; "StoreBadPackets"="0"; "DropHighlyFragmentedPacket"="1";
                    "EnableCoalesce"="0"; "AllowFlowControlFrames"="0"; "*StoreBadPackets"="0"; "EnableTss"="1";
                    "*PriorityVLANTag"="0"
                }
                # === Desktop ===
                if (!$laptop) {
                    $map += @{
                        "DynamicLTR"="0";
                        "*ModernStandbyWoLMagicPacket"="0"; "*SelectiveSuspend"="0"; "EnableModernStandby"="0";
                        "EnablePowerManagement"="0"; "ForceWakeFromMagicPacketOnModernStandby"="0";
                        "EnableDisconnectedStandby"="0"; "*EnableDynamicPowerGating"="0";
                        "*NicAutoPowerSaver"="0"; "AutoPowerSaveModeEnabled"="0"; "DisableIntelRST"="1"
                    }
                }
                $config += $map
            }
            '10EC' { # REALTEK
                $map = @{
                    "*InterruptModeration"=$val; "*LsoV2IPv4"="0"; "*LsoV2IPv6"="0";
                    "*VMQ"="0"; "VMQSupported"="0"; "EnableAdaptiveQueuing"="0";
                    "StoreBadPackets"="0"; "DropHighlyFragmentedPacket"="1"; "EnableCoalesce"="0";
                    "AllowFlowControlFrames"="0"; "*StoreBadPackets"="0"; "EnableTss"="1"; "*PriorityVLANTag"="0";
                    "*WakeOnMagicPacket"="0"; "*WakeOnPattern"="0"; "*JumboPacket"="1514";
                    "*NumRssQueues"="1"; "S5WakeOnLan"="0"; "WolShutdownLinkSpeed"="2"; "*SSIdleTimeout"="0";
                    "*SSIdleTimeoutScreenOff"="0"; "AdvancedEEE"="0"; "CLKREQ"="0"; "EEEPlus"="0";
                    "GPPSW"="0"; "EPSDRT"="0"; "GigaLite"="0"; "PnPCapabilities"="36"
                }
                # === Desktop ===
                if (!$laptop) {
                    $map += @{
                        "DynamicLTR"="0";
                        "*IdleRestriction"="1"; "*SelectiveSuspend"="0"; "*ModernStandbyWoLMagicPacket"="0";
                        "ASPM"="0"; "EnableAspm"="0"; "PowerSavingMode"="0"; "PowerDownPll"="0"; "LTROBF"="0"
                    }
                }
                $config += $map
            }
            '15B3' { # MELLANOX
                $map = @{
                    "*InterruptModeration"=$val; "*LsoV2IPv4"="1"; "*LsoV2IPv6"="1";
                    "*SelectiveSuspend"="0"; "*NicAutoPowerSaver"="0"; "*JumboPacket"="1514"; "WakeOnPattern"="0";
                    "WakeOnMagicPacket"="0"; "FwTracerEnabled"="0"; "VfCpuMonEnable"="0"; "VFAllowedRelaxedOrdering"="0";
                    "*QOS"="0"; "AllowPacketDirect"="1"; "EnableGpuDirect"="1"; "RxIntModeration"="0";
                    "ThreadedDpcEnable"="0"; "TxIntModeration"="0"; "TxThreadedDpcEnable"="0"; "EnableCmAntiSpoofing"="0"
                }
                $config += $map
            }
            '11AB' { # MARVELL
                $map = @{
                    "*InterruptModeration"=$val; "*NicAutoPowerSaver"="0"; "*JumboPacket"="1514";
                    "WakeFromPowerOff"="0"; "WakeOnLink"="0"; "WakeOnPing"="0"; "WakeOnPattern"="0"; "WakeOnMagicPacket"="0"
                }
                if (!$laptop) {$map += @{"ThermalMonitoring"="0"}}
                $config += $map
            }
        }

        # === Apply ===
        foreach ($key in $config.Keys) {
            Edit-Registry -Path $path -Name $key -Type DWord -Value $config[$key]
        }
    }

    # ==============================
    # Global TCP
    # ==============================
    # === Coalescing ===
    Set-NetOffloadGlobalSetting -ReceiveSegmentCoalescing Disable -EA 0
    Set-NetOffloadGlobalSetting -PacketCoalescingFilter Disable -EA 0

    # === Ack ===
    $netadapters = Get-NetAdapter -EA 0
    foreach ($adapter in $netadapters) {
        $guid = $adapter.InterfaceGuid
        $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
        if (Test-Path $path) {
            Edit-Registry -Path $path -Name 'TcpAckFrequency' -Type DWord -Value 1
            Edit-Registry -Path $path -Name 'TcpDelAckTicks' -Type DWord -Value 0
        }
    }
}

function Set-DrivesConfiguration {
    # === Check if the system has an SSD ===
    $letter = $env:SystemDrive.Substring(0, 1)
    $disk = (Get-Partition -DriveLetter $letter).DiskNumber
    $serial = (Get-Disk -Number $disk).SerialNumber.TrimStart()
    $media = (Get-PhysicalDisk -SerialNumber $serial).MediaType

    # ==============================
    # Apply if the drive is an SSD
    # ==============================
    if ($media -eq 'SSD') {
        Write-Host "Configuring system settings for SSD..."

        # === Disable hibernation ===
        if (!(Test-Laptop)) {
            powercfg /h off
            Edit-Registry -Path 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'HiberbootEnabled' -Type DWord -Value 0
            Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Type DWord -Value 0
            Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings' -Name 'ShowHibernateOption' -Type DWord -Value 0
            Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Control\Power' -Name 'HibernateEnabled' -Type DWord -Value 0
        } else {
            powercfg /h /type reduced
            powercfg hibernate size 0
            powercfg /h /type reduced
        }

        # === Enable TRIM support ===
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

function Set-AudioPowerConfig {
    if (Test-Laptop) {return}

    $reg = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96c-e325-11ce-bfc1-08002be10318}'
    $val = [byte[]](0x00, 0x00, 0x00, 0x00)

    if (!(Test-Path $reg)) {return}

    $entries = gci $reg -EA 0 | ? {$_.PSChildName -match '^\d{4}$'}
    foreach ($entry in $entries) {
        $path = "$reg\$($entry.PSChildName)\PowerSettings"
        if (!(Test-Path $path)) {continue}

        Edit-Registry -Path $path -Name 'ConservationIdleTime' -Type Binary -Value $val
        Edit-Registry -Path $path -Name 'PerformanceIdleTime' -Type Binary -Value $val
    }
}

# === Disable device power saving on desktops ===
if (!(Test-Laptop)) {
    Set-CimInstance -Namespace 'root\wmi' -Query 'SELECT * FROM MSPower_DeviceEnable' -Property @{Enable = $false}
}

foreach ($arg in $Device) {
    switch ($arg) {
        "Configure-DeviceInterrupts" {Set-MessageSignaledInterrupt}
        "Configure-Adapters" {Set-NetConfig}
        "Configure-Drives" {Set-DrivesConfiguration}
        "Configure-Audio" {Set-AudioPowerConfig}
        default {Write-Host "Error: Invalid argument `"$arg`"" -F Red}
    }
}