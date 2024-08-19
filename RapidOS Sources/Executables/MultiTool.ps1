param (
    [string]$MyArgument
)

# Check if the script is running as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -MyArgument {1}" -f $PSCommandPath, $MyArgument
    Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs
    exit
}

Write-Host "$MyArgument" -ForegroundColor Green

function Optimize-MSEdge {
    # Registry paths
    $edgeKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    $edgeUpdateKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"
    $microsoftKeyPath = "HKLM:\SOFTWARE\Microsoft"
    $edgeExtensionsKeyPath = "HKLM:\SOFTWARE\Microsoft\Edge\Extensions\odfafepnkmbhccpbejgmiehpchacaeak"

    # Create registry key paths if they do not exist
    if (-not (Test-Path $edgeKeyPath)) {
        New-Item -Path $edgeKeyPath -Force | Out-Null
    }

    if (-not (Test-Path $edgeUpdateKeyPath)) {
        New-Item -Path $edgeUpdateKeyPath -Force | Out-Null
    }

    if (-not (Test-Path $microsoftKeyPath)) {
        New-Item -Path $microsoftKeyPath -Force | Out-Null
    }

    if (-not (Test-Path $edgeExtensionsKeyPath)) {
        New-Item -Path $edgeExtensionsKeyPath -Force | Out-Null
    }

    # Edge settings
    $edgeSettings = @{
        "BrowserSignin"                     = 0
        "StartupBoostEnabled"               = 0
        "BingAdsSuppression"                = 1
        "BackgroundModeEnabled"             = 0
        "ComponentUpdatesEnabled"           = 0
        "EdgeShoppingAssistantEnabled"      = 0
        "ForceGoogleSafeSearch"             = 1
        "PersonalizationReportingEnabled"   = 0
        "HubsSidebarEnabled"                = 0
        "CopilotCDPPageContext"             = 0
        "CopilotPageContext"                = 0
        "DiscoverPageContextEnabled"        = 0
        "AutoImportAtFirstRun"              = 4
    }

    # Apply Edge settings
    foreach ($setting in $edgeSettings.GetEnumerator()) {
    Set-ItemProperty -Path $edgeKeyPath -Name $setting.Key -Value $setting.Value -Type DWord
    }

    # Edge Update settings
    $edgeUpdateSettings = @{
        "AutoUpdateCheckPeriodMinutes"      = 0
        "UpdateDefault"                     = 0
        "UpdatePolicy"                      = 0
        "InstallDefault"                    = 0
        "Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}" = 0
        "Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" = 1
    }

    # Apply Edge Update settings
    foreach ($setting in $edgeUpdateSettings.GetEnumerator()) {
    Set-ItemProperty -Path $edgeUpdateKeyPath -Name $setting.Key -Value $setting.Value -Type DWord
    }

    # Set Microsoft key setting
    Set-ItemProperty -Path $microsoftKeyPath -Name "DoNotUpdateToEdgeWithChromium" -Value 1 -Type DWord

    # Add uBlockOrigin extension
    Set-ItemProperty -Path $edgeExtensionsKeyPath -Name "update_url" -Value "https://edge.microsoft.com/extensionwebstorebase/v1/crx" -Type String
}

function Set-RapidOSInfo {
    $build = (Get-WmiObject Win32_OperatingSystem).BuildNumber

    # Set OEM information based on the build number
    switch ($build) {
        "19045" {
            bcdedit /set description "RapidOS 10 22H2"
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "Model" -Value "RapidOS 10 22H2"
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "RegisteredOrganization" -Value "RapidOS 10 22H2"
        }
        "22631" {
            bcdedit /set description "RapidOS 11 23H2"
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "Model" -Value "RapidOS 11 23H2"
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "RegisteredOrganization" -Value "RapidOS 11 23H2"
        }
        "26100" {
            bcdedit /set description "RapidOS 11 24H2"
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "Model" -Value "RapidOS 11 24H2"
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "RegisteredOrganization" -Value "RapidOS 11 24H2"
        }
    }
    # Set the Support URL
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation" -Name "SupportURL" -Value "https://dsc.gg/rapid-community"
}

function Set-SSDConfiguration {
    # Check if the system has an SSD
    $systemDriveLetter = $env:SystemDrive.Substring(0, 1)
    $diskNumber = (Get-Partition -DriveLetter $systemDriveLetter).DiskNumber
    $serialNumber = (Get-Disk -Number $diskNumber).SerialNumber.TrimStart()
    $mediaType = (Get-PhysicalDisk -SerialNumber $serialNumber).MediaType

    # Apply configurations if the drive is an SSD
    if ($mediaType -eq 'SSD') {
        Write-Host "Configuring system settings for SSD..."

        # Disable ReadyBoost (Commented out due to BSOD)
        # Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\rdyboost" -Name "Start" -Value 4 -Type DWord
        # Remove-Item -Path "HKCR:\Drive\shellex\PropertySheetHandlers\{55B3A0BD-4D28-42fe-8CFB-FA3EDFF969B8}" -ErrorAction SilentlyContinue

        # Disable SysMain (Superfetch)
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SysMain" -Name "Start" -Value 4 -Type DWord

        # Disable svsvc service
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\svsvc" -Name "Start" -Value 4 -Type DWord

        # Enable TRIM support for SSDs
        fsutil behavior set disabledeletenotify 0

        # Disable tasks related to HDD
        Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Data Integrity Scan\" -TaskName "Data Integrity Scan"

        Write-Host "Configuration completed."
    } else {
        Write-Host "No SSD drive found."
    }
}

function Optimize-InternetParameters {
    Write-Output "Optimizing Internet Parameters..."

    # Refresh network settings
    ipconfig /release
    ipconfig /renew
    ipconfig /flushdns

    # Modify network adapter power settings
    $networkAdapters = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}"
    foreach ($adapter in $networkAdapters) {
        $keyPath = $adapter.PSPath

        Set-ItemProperty -Path $keyPath -Name "AutoPowerSaveModeEnabled" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "AutoDisableGigabit" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "AdvancedEEE" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "DisableDelayedPowerUp" -Type String -Value "2" -Force
        Set-ItemProperty -Path $keyPath -Name "*EEE" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "EEE" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "EnablePME" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "EEELinkAdvertisement" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "EnableGreenEthernet" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "EnableSavePowerNow" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "EnablePowerManagement" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "EnableDynamicPowerGating" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "EnableConnectedPowerGating" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "EnableWakeOnLan" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "GigaLite" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "NicAutoPowerSaver" -Type String -Value "2" -Force
        Set-ItemProperty -Path $keyPath -Name "PowerDownPll" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "PowerSavingMode" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "ReduceSpeedOnPowerDown" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "SmartPowerDownEnable" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "S5NicKeepOverrideMacAddrV2" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "S5WakeOnLan" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "ULPMode" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "WakeOnDisconnect" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "*WakeOnMagicPacket" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "*WakeOnPattern" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "WakeOnLink" -Type String -Value "0" -Force
        Set-ItemProperty -Path $keyPath -Name "WolShutdownLinkSpeed" -Type String -Value "2" -Force
    }

    # Enable WeakHost Send and Receive
    Write-Output "Enabling WeakHost Send and Receive..."
    powershell -Command "Get-NetAdapter -IncludeHidden | Set-NetIPInterface -WeakHostSend Enabled -WeakHostReceive Enabled -ErrorAction SilentlyContinue"

    Write-Output "Optimization completed."
}

function Remove-WindowsInstallationAssistant {
    $installerPath = "$env:ProgramFiles(x86)\WindowsInstallationAssistant\Windows10UpgraderApp.exe"
    $installerDir = "$env:ProgramFiles(x86)\WindowsInstallationAssistant"

    Write-Output "Removing Windows Installation Assistant..."

    # Uninstall and remove directory
    if (Test-Path $installerPath) {
        Start-Process -FilePath $installerPath -ArgumentList "/SunValley /ForceUninstall" -NoNewWindow -RedirectStandardOutput "$null" -RedirectStandardError "$null" -Wait
        Remove-Item -Path $installerDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Output "Removal successful."
    } else {
        Write-Host "Windows Installation Assistant not found."
    }
}

function Disable-TelemetryUsingHosts {
    $hostspath = "$env:windir\System32\drivers\etc\hosts"
    $telemetryHosts = @(
        "vortex.data.microsoft.com",
        "vortex-win.data.microsoft.com",
        "telecommand.telemetry.microsoft.com",
        "telecommand.telemetry.microsoft.com.nsatc.net",
        "oca.telemetry.microsoft.com",
        "oca.telemetry.microsoft.com.nsatc.net",
        "sqm.telemetry.microsoft.com",
        "sqm.telemetry.microsoft.com.nsatc.net",
        "watson.telemetry.microsoft.com",
        "watson.telemetry.microsoft.com.nsatc.net",
        "redir.metaservices.microsoft.com",
        "choice.microsoft.com",
        "choice.microsoft.com.nsatc.net",
        "df.telemetry.microsoft.com",
        "reports.wes.df.telemetry.microsoft.com",
        "services.wes.df.telemetry.microsoft.com",
        "sqm.df.telemetry.microsoft.com",
        "telemetry.microsoft.com",
        "watson.ppe.telemetry.microsoft.com",
        "telemetry.appex.bing.net",
        "telemetry.urs.microsoft.com",
        "telemetry.appex.bing.net:443",
        "vortex-sandbox.data.microsoft.com",
        "settings-sandbox.data.microsoft.com",
        "vortex.data.microsoft.com",
        "vortex-win.data.microsoft.com",
        "telecommand.telemetry.microsoft.com",
        "telecommand.telemetry.microsoft.com.nsatc.net",
        "oca.telemetry.microsoft.com",
        "oca.telemetry.microsoft.com.nsatc.net",
        "sqm.telemetry.microsoft.com",
        "sqm.telemetry.microsoft.com.nsatc.net",
        "watson.telemetry.microsoft.com",
        "watson.telemetry.microsoft.com.nsatc.net",
        "redir.metaservices.microsoft.com",
        "choice.microsoft.com",
        "choice.microsoft.com.nsatc.net",
        "vortex-sandbox.data.microsoft.com",
        "settings-sandbox.data.microsoft.com",
        "df.telemetry.microsoft.com",
        "reports.wes.df.telemetry.microsoft.com",
        "sqm.df.telemetry.microsoft.com",
        "telemetry.microsoft.com",
        "watson.microsoft.com",
        "watson.ppe.telemetry.microsoft.com",
        "wes.df.telemetry.microsoft.com",
        "telemetry.appex.bing.net",
        "telemetry.urs.microsoft.com",
        "survey.watson.microsoft.com",
        "watson.live.com",
        "services.wes.df.telemetry.microsoft.com",
        "telemetry.appex.bing.net",
        "vortex.data.microsoft.com",
        "vortex-win.data.microsoft.com",
        "telecommand.telemetry.microsoft.com",
        "telecommand.telemetry.microsoft.com.nsatc.net",
        "oca.telemetry.microsoft.com",
        "oca.telemetry.microsoft.com.nsatc.net",
        "sqm.telemetry.microsoft.com",
        "sqm.telemetry.microsoft.com.nsatc.net",
        "watson.telemetry.microsoft.com",
        "watson.telemetry.microsoft.com.nsatc.net",
        "redir.metaservices.microsoft.com",
        "choice.microsoft.com",
        "choice.microsoft.com.nsatc.net",
        "df.telemetry.microsoft.com",
        "reports.wes.df.telemetry.microsoft.com",
        "wes.df.telemetry.microsoft.com",
        "services.wes.df.telemetry.microsoft.com",
        "sqm.df.telemetry.microsoft.com",
        "telemetry.microsoft.com",
        "watson.ppe.telemetry.microsoft.com",
        "telemetry.appex.bing.net",
        "telemetry.urs.microsoft.com",
        "telemetry.appex.bing.net:443",
        "settings-sandbox.data.microsoft.com",
        "vortex-sandbox.data.microsoft.com",
        "survey.watson.microsoft.com",
        "watson.live.com",
        "watson.microsoft.com",
        "statsfe2.ws.microsoft.com",
        "corpext.msitadfs.glbdns2.microsoft.com",
        "compatexchange.cloudapp.net",
        "cs1.wpc.v0cdn.net",
        "a-0001.a-msedge.net",
        "a-0002.a-msedge.net",
        "a-0003.a-msedge.net",
        "a-0004.a-msedge.net",
        "a-0005.a-msedge.net",
        "a-0006.a-msedge.net",
        "a-0007.a-msedge.net",
        "a-0008.a-msedge.net",
        "a-0009.a-msedge.net",
        "msedge.net",
        "a-msedge.net",
        "statsfe2.update.microsoft.com.akadns.net",
        "sls.update.microsoft.com.akadns.net",
        "fe2.update.microsoft.com.akadns.net",
        "diagnostics.support.microsoft.com",
        "corp.sts.microsoft.com",
        "statsfe1.ws.microsoft.com",
        "pre.footprintpredict.com",
        "i1.services.social.microsoft.com",
        "i1.services.social.microsoft.com.nsatc.net",
        "feedback.windows.com",
        "feedback.microsoft-hohm.com",
        "feedback.search.microsoft.com",
        "live.rads.msn.com",
        "ads1.msn.com",
        "static.2mdn.net",
        "g.msn.com",
        "a.ads2.msads.net",
        "b.ads2.msads.net",
        "ad.doubleclick.net",
        "ac3.msn.com",
        "rad.msn.com",
        "msntest.serving-sys.com",
        "bs.serving-sys.com1",
        "flex.msn.com",
        "ec.atdmt.com",
        "cdn.atdmt.com",
        "db3aqu.atdmt.com",
        "cds26.ams9.msecn.net",
        "sO.2mdn.net",
        "aka-cdn-ns.adtech.de",
        "secure.flashtalking.com",
        "adnexus.net",
        "adnxs.com",
        "*.rad.msn.com",
        "*.msads.net",
        "*.msecn.net"
    )

    Write-Host "Attempting to write to hosts file: $hostspath"

    try {
        foreach ($telemetryHost in $telemetryHosts) {
            Add-Content -Path $hostspath -Value "127.0.0.1 $telemetryHost" -ErrorAction Stop
            Write-Host "Added entry for $telemetryHost"
        }
    } catch {
        Write-Host "Error writing to hosts file: $($Error[0].Message)"
    }
}

switch ($MyArgument) {
    "optimize_msedge" { Optimize-MSEdge }
    "set_rapidos_information" { Set-RapidOSInfo }
    "configure_ssd" { Set-SSDConfiguration }
    "optimize_internet" { Optimize-InternetParameters }
    "remove_installation_assistant" { Remove-WindowsInstallationAssistant }
    "disable-telemetry-using-hosts" { Disable-TelemetryUsingHosts }
    default { Write-Host "Invalid argument." }
}