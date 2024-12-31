param (
    [string[]]$MyArgument
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

function Disable-DefenderDataCollection {
    param (
        [switch]$DisableBlockAtFirstSight,
        [switch]$DisableExtendedCloudCheck,
        [switch]$DisableAggressiveCloudProtection,
        [switch]$DisableCloudProtection,
        [switch]$DisableSignatureNotifications,
        [switch]$DisableSampleSubmission
    )

    if ($DisableBlockAtFirstSight) {
        # Parameters for all function
        $propertyName = 'DisableBlockAtFirstSeen'
        $value = [int]$true

        # Check if the setting is already applied
        $mpPreference = 'Get-MpPreference -ErrorAction Ignore'
        if ($mpPreference.$propertyName -eq $value) {
            Write-Host "Skipping. Already found '$propertyName' with '$value' value"
            return
        }

        # Disable 'Block at First Sight'
        try {
            Set-MpPreference -Force -DisableBlockAtFirstSeen $value -ErrorAction Stop
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SpyNet' -Name 'DisableBlockAtFirstSeen' -Type DWord -Value 1
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows Defender\SpyNet' -Name 'DisableBlockAtFirstSeen' -Type DWord -Value 1
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -Name $propertyName -Type DWord -Value $value
            Write-Host "Successfully disabled '$propertyName'"
        }
        catch {
            Write-Host "Failed to configure '$propertyName': $_"
        }
    }

    if ($DisableExtendedCloudCheck) {
        # Parameters for all function
        $propertyName = 'CloudExtendedTimeout'
        $value = 50

        # Check if the setting is already applied
        $mpPreference = 'Get-MpPreference -ErrorAction Ignore'
        if ($mpPreference.$propertyName -eq $value) {
            Write-Host "Skipping. Already found '$propertyName' with '$value' value"
            return
        }

        # Disable 'Cloud Extended Timeout'
        try {
            Set-MpPreference -Force -CloudExtendedTimeout $value -ErrorAction Stop
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine' -Name 'MpBafsExtendedTimeout' -Type DWord -Value $value
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows Defender\MpEngine' -Name 'MpBafsExtendedTimeout' -Type DWord -Value $value
            Write-Host "Successfully disabled '$propertyName'"
        }
        catch {
            Write-Host "Failed to configure '$propertyName': $_"
        }
    }

    if ($DisableAggressiveCloudProtection) {
        # Parameters for all function
        $propertyName = 'CloudBlockLevel'
        $value = '0'

        # Check if the setting is already applied
        $mpPreference = 'Get-MpPreference -ErrorAction Ignore'
        if ($mpPreference.$propertyName -eq $value) {
            Write-Host "Skipping. Already found '$propertyName' with '$value' value"
            return
        }

        # Disable CloudBlockLevel (Aggressive Cloud Protection)
        try {
            Set-MpPreference -Force -CloudBlockLevel $value -ErrorAction Stop
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine' -Name 'MpCloudBlockLevel' -Type DWord -Value $value
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows Defender\MpEngine' -Name 'MpCloudBlockLevel' -Type DWord -Value 2
            Write-Host "Successfully disabled '$propertyName'"
        }
        catch {
            Write-Host "Failed to configure '$propertyName': $_"
        }
    }

    if ($DisableCloudProtection) {
        # Parameters for all function
        $propertyName = 'MAPSReporting'
        $value = '0'

        # Check if the setting is already applied
        $mpPreference = 'Get-MpPreference -ErrorAction Ignore'
        if ($mpPreference.$propertyName -eq $value) {
            Write-Host "Skipping. Already found '$propertyName' with '$value' value"
            return
        }

        # Disable MapsReporting (Cloud Protection)
        try {
            Set-MpPreference -Force -MAPSReporting $value -ErrorAction Stop
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet' -Name 'LocalSettingOverrideSpynetReporting' -Type DWord -Value $value
            Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowCloudProtection' -Name 'value' -Type DWord -Value 0
            Write-Host "Successfully disabled '$propertyName'"
        }
        catch {
            Write-Host "Failed to configure '$propertyName': $_"
        }

    }

    if ($DisableSignatureNotifications) {
        # Disable 'Signature Notifications'
        Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Signature Updates' -Name 'SignatureDisableNotification' -Type DWord -Value 0
        Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Microsoft Antimalware\Signature Updates' -Name 'SignatureDisableNotification' -Type DWord -Value 0
        Write-Host "Successfully disabled Signature Notifications"
    }

    if ($DisableSampleSubmission) {
        # Disable 'Sample Submission'
        Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Samples Submission' -Name 'SubmitSamplesConsent' -Type DWord -Value 2
        Write-Host "Successfully disabled Sample Submission"
    }
}

function Disable-TelemetryRelated {
    param (
        [switch]$ManageTelemetryHosts,
        [switch]$DisableTelemetryScheduledTasks
    )

    if ($ManageTelemetryHosts) {
        # Actions for modifying the hosts file
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

    if ($DisableTelemetryScheduledTasks) {
        # Actions for disabling scheduled tasks
        $scheduledTasks = @(
            # CEIP Tasks
            "Microsoft\Windows\Autochk\Proxy",
            "Microsoft\Windows\Customer Experience Improvement Program\BthSQM",
            "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
            "Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask",
            "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
            "Microsoft\Windows\Application Experience\ProgramDataUpdater",
            # Windows Error Reporting
            "Microsoft\Windows\Windows Error Reporting\QueueReporting",
            "Microsoft\Windows\ErrorDetails\EnableErrorDetailsUpdate",
            # Voice activation for apps and cortana
            "Microsoft\Windows\Speech\SpeechModelDownloadTask",
            # Microsoft Compatibility Appraiser telemetry
            "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
            # Disk Diagnostic telemetry
            "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
            # Windows Feedback and Diagnostics
            "Microsoft\Windows\Feedback\Siuf\DmClient",
            "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
            # Managing app data, backups, startup behavior
            "Microsoft\Windows\Application Experience\AitAgent",
            "Microsoft\Windows\Application Experience\MareBackup",
            "Microsoft\Windows\Application Experience\StartupAppTask",
            "Microsoft\Windows\Application Experience\PcaPatchDbTask",
            # Windows Maps
            "Microsoft\Windows\Maps\MapsUpdateTask",
            # Inventory Collector and Webcam telemetry
            "Microsoft\Windows\Device Information\Device"
            "Microsoft\Windows\Device Information\Device User"
        )

        foreach ($task in $scheduledTasks) {
            schtasks /Change /TN $task /Disable
            Write-Host "Disabled scheduled task: $task"
        }
    }
}

# Function to display usage information
function Show-Usage {
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " .\Configure-DataCollection.ps1 -MyArgument <option>" -ForegroundColor White
    Write-Host ""

    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " - disable_block_at_first_sight       : Disable 'Block at First Sight' in Windows Defender." -ForegroundColor Gray
    Write-Host " - disable_extended_cloud_check       : Disable 'Extended Cloud Check' in Windows Defender." -ForegroundColor Gray
    Write-Host " - disable_aggresive_cloud_protection : Disable 'Aggressive Cloud Protection' in Windows Defender." -ForegroundColor Gray
    Write-Host " - disable_cloud_protection           : Disable 'Cloud Protection' in Windows Defender." -ForegroundColor Gray
    Write-Host " - disable_signature_notifications    : Disable signature notifications in Windows Defender." -ForegroundColor Gray
    Write-Host " - disable_sample_submission          : Disable sample submission in Windows Defender." -ForegroundColor Gray
    Write-Host " - disable_telemetry_with_hosts       : Disable telemetry by modifying the hosts file." -ForegroundColor Gray
    Write-Host " - disable_telemetry_scheduled_tasks  : Disable telemetry-related scheduled tasks." -ForegroundColor Gray
    Write-Host ""

    Write-Host "Example:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " .\Configure-DataCollection.ps1 -MyArgument disable_telemetry_with_hosts" -ForegroundColor White
    Write-Host " .\Configure-DataCollection.ps1 -MyArgument disable_extended_cloud_check, disable_aggresive_cloud_protection" -ForegroundColor White
    Write-Host ""
}

# Check if any arguments were provided
if (-not $MyArgument) {
    Write-Host "Error: No arguments provided." -ForegroundColor Red
    Write-Host ""
    Show-Usage
}

# Function call based on the argument
foreach ($arg in $MyArgument) {
    switch ($arg) {
        # Disable everything related to Defender Data Collection
        "disable_block_at_first_sight" { Disable-DefenderDataCollection -DisableBlockAtFirstSight $true }
        "disable_extended_cloud_check" { Disable-DefenderDataCollection -DisableExtendedCloudCheck $true }
        "disable_aggresive_cloud_protection" { Disable-DefenderDataCollection -DisableAggressiveCloudProtection $true }
        "disable_cloud_protection" { Disable-DefenderDataCollection -DisableCloudProtection $true }
        "disable_signature_notifications" { Disable-DefenderDataCollection -DisableSignatureNotifications $true }
        "disable_sample_submission" { Disable-DefenderDataCollection -DisableSampleSubmission $true }

        # Disable everything related to General Windows telemetry
        "disable_telemetry_with_hosts" { Disable-TelemetryRelated -ManageTelemetryHosts $true }
        "disable_telemetry_scheduled_tasks" { Disable-TelemetryRelated -DisableTelemetryScheduledTasks $true }

        default {
            Write-Host "Error: Invalid argument `"$arg`"" -ForegroundColor Red
            Write-Host ""
            Show-Usage
        }
    }
}