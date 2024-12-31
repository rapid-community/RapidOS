# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) { Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow; $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -MyArgument {1}" -f $PSCommandPath, $MyArgument; Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs; exit }

# Path to add to PATH environment variable
$newPath = "C:\Windows\RapidScripts"

# Get current PATH
$currentPath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::Machine)

# Split PATH into parts
$paths = $currentPath -split ";"

# Check if the path is already included
if ($paths -notcontains $newPath) {
    # Prepend new path to the existing PATH
    $updatedPath = "$newPath;$currentPath"

    # Update PATH environment variable
    [System.Environment]::SetEnvironmentVariable("PATH", $updatedPath, [System.EnvironmentVariableTarget]::Machine)

    # Confirm the change
    Write-Host "PATH updated. New PATH: $updatedPath"
} else {
    Write-Host "Path already exists in PATH."
}

# Update PATH in current session
$env:PATH = $updatedPath