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

function EnableDefender {
    # Stop services and kill processes
    Stop-Service "wscsvc" -force -ea 0 >'' 2>''
    Stop-Process -name "OFFmeansOFF", "MpCmdRun" -force -ea 0

    # Enable Windows Defender services
    Push-Location "$env:programfiles\Windows Defender"
    $mpcmdrun = ("OFFmeansOFF.exe", "MpCmdRun.exe")[(test-path "MpCmdRun.exe")]
    Start-Process -wait $mpcmdrun -args "-EnableService -HighPriority"

    # Rename MpCmdRun.exe back to original name
    Push-Location (split-path $(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend" ImagePath -ea 0).ImagePath.Trim('"'))
    Rename-Item OFFmeansOFF.exe MpCmdRun.exe -force -ea 0

    # Remove registry values for Windows Defender
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "AllowFastServiceStartup"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Microsoft Antimalware" -Name "DisableAntiVirus"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiVirus"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableSpecialRunningModes"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "ServiceKeepAlive"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" -Name "MpEnablePus"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" -Name "DisableEnhancedNotifications"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SpyNet" -Name "DisableBlockAtFirstSeen"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SpyNet" -Name "SpynetReporting"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SpyNet" -Name "SubmitSamplesConsent"

    # Real-Time Protection specific settings
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRealtimeMonitoring"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableBehaviorMonitoring"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableOnAccessProtection"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableScanOnRealtimeEnable"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableIOAVProtection"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "LocalSettingOverrideDisableOnAccessProtection"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "LocalSettingOverrideRealtimeScanDirection"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "LocalSettingOverrideDisableIOAVProtection"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "LocalSettingOverrideDisableBehaviorMonitoring"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "LocalSettingOverrideDisableIntrusionPreventionSystem"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "LocalSettingOverrideDisableRealtimeMonitoring"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "RealtimeScanDirection"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "IOAVMaxSize"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableInformationProtectionControl"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableIntrusionPreventionSystem"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRawWriteNotification"

    # Disable SmartScreen 
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\System" -Name "EnableSmartScreen"

    # Additional Defender settings
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowBehaviorMonitoring" -Name "value"
    Remove-RegistryValue -Path "HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\Windows Defender" -Name "DisableRoutinelyTakingAction"

    # Update Group Policy
    gpupdate /force

    Write-Host "Microsoft Defender is enabled." -f Green
}

function DisableDefender {
    # Stop services and kill processes
    Stop-Service "wscsvc" -force -ea 0 >'' 2>''
    Stop-Process -name "OFFmeansOFF", "MpCmdRun" -force -ea 0

    # Disable Windows Defender services
    Push-Location "$env:programfiles\Windows Defender"
    $mpcmdrun = ("OFFmeansOFF.exe", "MpCmdRun.exe")[(test-path "MpCmdRun.exe")]
    Start-Process -wait $mpcmdrun -args "-DisableService -HighPriority"

    # Rename MpCmdRun.exe
    Push-Location (split-path $(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend" ImagePath -ea 0).ImagePath.Trim('"'))
    Rename-Item MpCmdRun.exe OFFmeansOFF.exe -force -ea 0

    # Kill MsMpEng process
    Stop-Process -name "MsMpEng" -force -ea 0

    # Modify registry parameters
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "AllowFastServiceStartup" -Type DWord -Value 0
    # Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Type DWord -Value 1 # Breaks system stability on 26100 builds
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Microsoft Antimalware" -Name "DisableAntiVirus" -Type DWord -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiVirus" -Type DWord -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableSpecialRunningModes" -Type DWord -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "ServiceKeepAlive" -Type DWord -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableRoutinelyTakingAction" -Type DWord -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableLocalAdminMerge" -Type DWord -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" -Name "MpEnablePus" -Type DWord -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" -Name "DisableEnhancedNotifications" -Type DWord -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SpyNet" -Name "DisableBlockAtFirstSeen" -Type DWord -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SpyNet" -Name "SpynetReporting" -Type DWord -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SpyNet" -Name "SubmitSamplesConsent" -Type DWord -Value 2

    # Real-Time Protection specific settings
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRealtimeMonitoring" -Type DWord -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableBehaviorMonitoring" -Type DWord -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableOnAccessProtection" -Type DWord -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableScanOnRealtimeEnable" -Type DWord -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableIOAVProtection" -Type DWord -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "LocalSettingOverrideDisableOnAccessProtection" -Type DWord -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "LocalSettingOverrideRealtimeScanDirection" -Type DWord -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "LocalSettingOverrideDisableIOAVProtection" -Type DWord -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "LocalSettingOverrideDisableBehaviorMonitoring" -Type DWord -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "LocalSettingOverrideDisableIntrusionPreventionSystem" -Type DWord -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "LocalSettingOverrideDisableRealtimeMonitoring" -Type DWord -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "RealtimeScanDirection" -Type DWord -Value 2
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "IOAVMaxSize" -Type DWord -Value 1280
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableInformationProtectionControl" -Type DWord -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableIntrusionPreventionSystem" -Type DWord -Value 1
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRawWriteNotification" -Type DWord -Value 1

    # Disable SmartScreen 
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Type DWord -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\System" -Name "EnableSmartScreen" -Type DWord -Value 0

    # Additional Defender settings
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Defender\AllowBehaviorMonitoring" -Name "value" -Type DWord -Value 0
    Set-RegistryValue -Path "HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\Windows Defender" -Name "DisableRoutinelyTakingAction" -Type DWord -Value 1

    Write-Host "Microsoft Defender is defeated." -f Green
}

switch ($MyArgument) {
    "enable_windows_defender" { EnableDefender }
    "disable_windows_defender" { DisableDefender }
    default { Write-Host "Invalid argument." }
}