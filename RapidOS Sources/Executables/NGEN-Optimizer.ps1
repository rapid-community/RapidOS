# Ensure administrator privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    exit	
}

# Add the.NET runtime directory to the process PATH
$dotnetRuntimeDir = "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319"
$env:PATH = $env:PATH + ";$dotnetRuntimeDir"

# Get all loaded assemblies
$assemblies = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {$_.Location} | Select-Object -ExpandProperty Location

# Install native image for each assembly
foreach ($assembly in $assemblies) {
    Write-Host "NGENing: $assembly"
    & "$dotnetRuntimeDir\ngen.exe" install $assembly
}

# Run NGEN tasks in the background to ensure all assemblies are ngened
Start-Process -FilePath "schtasks.exe" -ArgumentList "/Run", "/TN", "\Microsoft\Windows\.NET Framework\.NET Framework NGEN v4.0.30319" -PassThru
Start-Process -FilePath "schtasks.exe" -ArgumentList "/Run", "/TN", "\Microsoft\Windows\.NET Framework\.NET Framework NGEN v4.0.30319 64" -PassThru