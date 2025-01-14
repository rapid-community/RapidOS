# Find feature/velocity IDs to disable for the 'Accounts' page (AtlasOS)

# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) { Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow; $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -MyArgument {1}" -f $PSCommandPath, $MyArgument; Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs; exit }

# Variables
$WinDir = [Environment]::GetFolderPath('Windows')
$settingsExtensions = (Get-ChildItem "$WinDir\SystemApps" -Recurse).FullName | Where-Object { $_ -like '*wsxpacks\Account\SettingsExtensions.json*' }
if ($settingsExtensions.Count -eq 0) {
    Write-Host "Settings extensions ($settingsExtensions) not found."
    Write-Host "User is likely on Windows 10, nothing to do. Exiting..."
    exit
}

# Finds velocity IDs listed in 'Accounts' wsxpack
function Find-VelocityID($Node) {
    $ids = @()
    if ($Node -is [PSCustomObject]) {
        # If the node is a PSObject, go through through its properties
        foreach ($property in $Node.PSObject.Properties) {
            if ($property.Name -eq 'velocityKey' -and $property.Value.id) {
                $ids += $property.Value.id
            }
            Find-VelocityID -Node $property.Value
        }
    } elseif ($Node -is [Array]) {
        # If the node is an array, go through its elements
        foreach ($element in $Node) {
            Find-VelocityID -Node $element
        }
    }

    return $ids
}
$ids = @()
foreach ($settingsJson in $settingsExtensions) {
    $ids += Find-VelocityID -Node $(Get-Content -Path $settingsJson | ConvertFrom-Json)
}

# No IDs check
if ($ids.Count -le 0) {
    Write-Host "No velocity IDs were found. Exiting."
    exit 1
}

# Disable feature IDs
# Applies next reboot
foreach ($id in $($ids | Sort-Object -Unique)) {
    Write-Host "Disabling feature ID $id..."
    & "$env:WinDir\RapidScripts\ViveTool\ViVeTool.exe" /disable /id:$id | Out-Null
}