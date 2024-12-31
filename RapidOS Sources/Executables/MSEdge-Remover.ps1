# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) { Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow; $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -MyArgument {1}" -f $PSCommandPath, $MyArgument; Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs; exit }

# Define common variables
$ErrorActionPreference = "Stop"
$regView = [Microsoft.Win32.RegistryView]::Registry32
$microsoft = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $regView).
OpenSubKey('SOFTWARE\Microsoft', $true)

# Stop Edge processes
function Stop-EdgeProcesses {
    Stop-Process -Name msedge, MicrosoftEdgeUpdate, msedgewebview2 -Force -ErrorAction SilentlyContinue
}

# Uninstall Edge components
function Uninstall-EdgeComponents {
    $edgeUWP = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
    $uninstallRegKey = $microsoft.OpenSubKey('Windows\CurrentVersion\Uninstall\Microsoft Edge')

    if ($null -eq $uninstallRegKey) {
        Write-Host "Uninstall registry key for Microsoft Edge not found." -ForegroundColor Red
        return
    }

    $uninstallString = $uninstallRegKey.GetValue('UninstallString')
    if ($null -eq $uninstallString) {
        Write-Host "Uninstall string not found in registry." -ForegroundColor Red
        return
    }
    
    $uninstallString += ' --force-uninstall'

    # Remove Edge folders
    [void](New-Item $edgeUWP -ItemType Directory -ErrorVariable fail -ErrorAction SilentlyContinue)
    [void](New-Item "$edgeUWP\MicrosoftEdge.exe" -ErrorAction Continue)
    Start-Process cmd.exe "/c $uninstallString" -WindowStyle Hidden -Wait
    [void](Remove-Item "$edgeUWP\MicrosoftEdge.exe" -ErrorAction Continue)

    if (-not $fail) {
        [void](Remove-Item "$edgeUWP")
    }

    # Remove residual files
    if (Test-Path "C:\Program Files (x86)\Microsoft\Edge") {
        Remove-Item -Path "C:\Program Files (x86)\Microsoft\Edge" -Recurse -Force -ErrorAction Continue
    }
    <#
    if (Test-Path "C:\Program Files (x86)\Microsoft\EdgeWebView") {
        Remove-Item -Path "C:\Program Files (x86)\Microsoft\EdgeWebView" -Recurse -Force -ErrorAction Continue
    }
    #>
    if (Test-Path "C:\Program Files (x86)\Microsoft\EdgeCore") {
        Remove-Item -Path "C:\Program Files (x86)\Microsoft\EdgeCore" -Recurse -Force -ErrorAction Continue
    }

    # Get and delete all scheduled tasks related to Microsoft Edge
    $edgeTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*Edge*" -or $_.TaskPath -like "*Edge*" }
    if ($edgeTasks) {
        foreach ($task in $edgeTasks) {
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
            Write-Host "Deleted task: $($task.TaskName)" -ForegroundColor Red
        }
    } else {
        Write-Host "No Microsoft Edge related tasks found to delete." -ForegroundColor Yellow
    }
}

# Handle Edge update
function Remove-EdgeUpdate {
    # Remove Edge Update client settings
    $edgeClient = $microsoft.OpenSubKey('EdgeUpdate\ClientState\{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}', $true)
    if ($null -ne $edgeClient) {
        if ($null -ne $edgeClient.GetValue('experiment_control_labels')) {
            $edgeClient.DeleteValue('experiment_control_labels')
        }
        $microsoft.CreateSubKey('EdgeUpdateDev').SetValue('AllowUninstall', '')
    }
    if (Test-Path "C:\Program Files (x86)\Microsoft\EdgeUpdate") {
        Remove-Item -Path "C:\Program Files (x86)\Microsoft\EdgeUpdate" -Recurse -Force -ErrorAction Continue
    }

    # Define registry paths for checking autostart
    $registryPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
    )
    # Check registry entries
    foreach ($path in $registryPaths) {
        $entries = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
        if ($entries) {
            foreach ($entry in $entries.PSObject.Properties) {
                if ($entry.Name -like "*Edge*") {
                    Write-Host "Found autostart entry: $($entry.Name) = $($entry.Value) in $path" -ForegroundColor Green
                }
            }
        } else {
            Write-Host "No autostart entries found in $path" -ForegroundColor Yellow
        }
    }

    # Paths to services in registry
    $services = "HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdate", "HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdatem"
    
    # Remove services if they exist
    $services | ForEach-Object {
        if (Test-Path $_) {
            Remove-Item $_ -Recurse -Force
            Write-Host "$_ removed."
        } else {
            Write-Host "$_ not found."
        }
    }
}

Stop-EdgeProcesses
Remove-EdgeUpdate
Uninstall-EdgeComponents