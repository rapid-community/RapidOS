param (
    [string]$MyArgument
)

# Registry paths
$searchPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
$searchCurrentPath = "HKLM:\SOFTWARE\Microsoft\Windows Search\CurrentPolicies"

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

# Clear minimal indexing settings
function Clear-MinimalIndexing {
    $policies = @(
        "$searchPolicyPath\DefaultExcludedPaths",
        "$searchPolicyPath\DefaultIndexedPaths",
        "$searchCurrentPath\DefaultExcludedPaths",
        "$searchCurrentPath\DefaultIndexedPaths"
    )
    foreach ($policy in $policies) {
        if (Test-Path $policy) {
            Remove-Item -Path $policy -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -Path $policy -Force | Out-Null
    }
    Remove-RegistryValue -Path $searchPolicyPath -Name "PreventIndexOnBattery"
    Remove-RegistryValue -Path $searchCurrentPath -Name "RespectPowerModes"
}

# Set advanced settings
function Set-AdvancedSettings {
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Search" -Name "SetupCompletedSuccessfully" -Type DWORD -Value 0
    Set-RegistryValue -Path $searchPolicyPath -Name "PreventIndexingOutlook" -Type DWORD -Value 0
    Set-RegistryValue -Path $searchPolicyPath -Name "DisableBackOff" -Type DWORD -Value 1
    Set-RegistryValue -Path $searchPolicyPath -Name "RobotThreadsNumber" -Type DWORD -Value 63
}

# Set minimal settings
function Set-MinimalSettings {
    $paths = @(
        "$env:USERPROFILE\Documents",
        "$env:USERPROFILE\Pictures",
        "$env:USERPROFILE\Music",
        "$env:USERPROFILE\Videos",
        "$env:USERPROFILE\Downloads"
    )
    $registryPaths = @(
        "$searchPolicyPath\DefaultIndexedPaths",
        "$searchCurrentPath\DefaultIndexedPaths"
    )
    foreach ($regPath in $registryPaths) {
        if (Test-Path $regPath) {
            Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -Path $regPath -Force | Out-Null
        foreach ($path in $paths) {
            $filePath = "file:///$($path)/*"
            Set-RegistryValue -Path $regPath -Name "DefaultIndexedPaths" -Type String -Value $filePath
        }
    }

    Set-RegistryValue -Path $searchPolicyPath -Name "RespectPowerModes" -Type DWORD -Value 1
    Set-RegistryValue -Path $searchPolicyPath -Name "PreventIndexOnBattery" -Type DWORD -Value 1
}

# Function to display usage information
function Show-Usage {
    Write-Host "Usage: .\Manage-Indexing.ps1 -MyArgument <option>"
    Write-Host ""
    Write-Host "Options:"
    Write-Host " - enable_indexing    : Enable Windows indexing."
    Write-Host " - disable_indexing   : Disable Windows indexing."
    Write-Host " - minimize_indexing  : Minimize Windows indexing."
    Write-Host ""
}

switch ($MyArgument) {
    "enable_indexing" {
        Write-Host "Enabling indexing..."
        Clear-MinimalIndexing
        Set-AdvancedSettings
        Write-Host "Starting Windows Search service..."
        Set-Service -Name "WSearch" -StartupType "Automatic"
        Start-Service -Name "WSearch"
        Write-Host "Windows Search service started."
    }
    "disable_indexing" {
        Write-Host "Disabling indexing..."
        Clear-MinimalIndexing
        Set-AdvancedSettings
        Write-Host "Stopping Windows Search service..."
        Stop-Service -Name "WSearch" -Force
        Set-Service -Name "WSearch" -StartupType "Disabled"
        Write-Host "Windows Search service stopped and disabled."
    }
    "minimize_indexing" {
        Write-Host "Minimizing indexing..."
        Write-Host "Stopping Windows Search service..."
        Stop-Service -Name "WSearch" -Force
        Set-Service -Name "WSearch" -StartupType "Disabled"
        Clear-MinimalIndexing
        Set-MinimalSettings
        Write-Host "Starting Windows Search service..."
        Set-Service -Name "WSearch" -StartupType "Automatic"
        Start-Service -Name "WSearch"
        Write-Host "Windows Search service started."
    }
    default {
        Write-Host "Error: Invalid argument `"$MyArgument`"" -ForegroundColor Red
        Write-Host ""
        Show-Usage
    }
}

