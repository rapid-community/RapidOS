# Ensure administrator privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    exit
}

# Define common variables
$ErrorActionPreference = "Stop"
$regView = [Microsoft.Win32.RegistryView]::Registry32
$microsoft = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $regView).
OpenSubKey('SOFTWARE\Microsoft', $true)

# Function to stop Edge processes
function Stop-EdgeProcesses {
    Stop-Process -Name msedge, MicrosoftEdgeUpdate, msedgewebview2 -Force -ErrorAction SilentlyContinue
}

# Function to uninstall Edge components
function Uninstall-EdgeComponents {
    $edgeUWP = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
    $uninstallRegKey = $microsoft.OpenSubKey('Windows\CurrentVersion\Uninstall\Microsoft Edge')
    $uninstallString = $uninstallRegKey.GetValue('UninstallString') + ' --force-uninstall'

    # Remove Edge folder and executable
    [void](New-Item $edgeUWP -ItemType Directory -ErrorVariable fail -ErrorAction SilentlyContinue)
    [void](New-Item "$edgeUWP\MicrosoftEdge.exe" -ErrorAction Continue)
    Start-Process cmd.exe "/c $uninstallString" -WindowStyle Hidden -Wait
    [void](Remove-Item "$edgeUWP\MicrosoftEdge.exe" -ErrorAction Continue)

    if (-not $fail) {
        [void](Remove-Item "$edgeUWP")
    }
}

# Function to handle Edge update
function Remove-EdgeUpdate {
    # Remove Edge Update client settings
    $edgeClient = $microsoft.OpenSubKey('EdgeUpdate\ClientState\{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}', $true)
    if ($null -ne $edgeClient.GetValue('experiment_control_labels')) {
        $edgeClient.DeleteValue('experiment_control_labels')
    }
    $microsoft.CreateSubKey('EdgeUpdateDev').SetValue('AllowUninstall', '')
}

Stop-EdgeProcesses
Uninstall-EdgeComponents
Remove-EdgeUpdate