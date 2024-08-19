# Ensure administrator privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    exit	
}

# Define features to enable
$enableFeatures = @(
    "LegacyComponents"
    "DirectPlay"
)

# Define features to disable
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

# Common DISM options
$dismOptions = "/Online /NoRestart"

# Enable features
foreach ($feature in $enableFeatures) {
    Write-Host "Enabling feature $feature"
    $dismCommand = "DISM $dismOptions /Enable-Feature /FeatureName:$feature"
    Invoke-Expression $dismCommand
}

# Disable features
foreach ($feature in $disableFeatures) {
    Write-Host "Disabling feature $feature"
    $dismCommand = "DISM $dismOptions /Disable-Feature /FeatureName:$feature"
    Invoke-Expression $dismCommand
}
