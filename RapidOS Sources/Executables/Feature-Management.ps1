# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) { Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow; $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -MyArgument {1}" -f $PSCommandPath, $MyArgument; Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs; exit }

# Features to enable
$enableFeatures = @(
    "LegacyComponents"
    "DirectPlay"
)

# Features to disable
$disableFeatures = @(
    "MicrosoftWindowsPowerShellV2Root"
    "MicrosoftWindowsPowerShellV2"
    "WorkFolders-Client"
    "Printing-Foundation-Features"
    "Printing-Foundation-InternetPrinting-Client"
    # "SmbDirect"
    "MSRDC-Infrastructure"
    # "Microsoft-Windows-MediaPlayer"
)

# Enable specified features
foreach ($feature in $enableFeatures) {
    Write-Host "Enabling feature: $feature"
    Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart
}

# Disable specified features
foreach ($feature in $disableFeatures) {
    Write-Host "Disabling feature: $feature"
    Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart
}

# Disable Reserved Storage for Windows Updates
DISM /Online /NoRestart /Set-ReservedStorageState /State:Disabled