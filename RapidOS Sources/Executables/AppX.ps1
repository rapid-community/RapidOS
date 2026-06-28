#Requires -RunAsAdministrator

param ([Parameter(Mandatory=$true)][string[]]$Packages)

$reg = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore'
$left = $false

# ==============================
# Remove packages
# ==============================
for ($i = 0; $i -lt $Packages.Count; $i++) {
    $pattern = "*$($Packages[$i])*"

    $provisioned = Get-AppxProvisionedPackage -Online | ? {$_.DisplayName -like $pattern -or $_.PackageName -like $pattern} | Sort PackageName -Unique
    foreach ($pkg in $provisioned) {
        Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -AllUsers *>$null
    }

    $installed = @(Get-AppxPackage -AllUsers -PackageTypeFilter Bundle; Get-AppxPackage -AllUsers) | ? {$_.PackageFullName -like $pattern -or $_.PackageFamilyName -like $pattern} | Sort PackageFullName -Unique
    foreach ($pkg in $installed) {
        $name = $pkg.PackageFullName
        $family = $pkg.PackageFamilyName
        $sids = @($pkg.PackageUserInformation.UserSecurityId.Sid) | ? {$_}

        Write-Host "Removing: $name"

        if ($family) {
            Edit-Registry -Path "$reg\Deprovisioned\$family" -Name '' -Value ''
            Set-NonRemovableAppsPolicy -Online -PackageFamilyName $family -NonRemovable 0 *>$null
        }

        foreach ($sid in $sids) {Edit-Registry -Path "$reg\EndOfLife\$sid\$name" -Name '' -Value ''}
        Edit-Registry -Path "$reg\EndOfLife\.DEFAULT\$name" -Name '' -Value ''

        Remove-AppxPackage -Package $name -AllUsers *>$null
        Remove-AppxPackage -Package $name *>$null
    }
}

# ==============================
# Verify removal
# ==============================
for ($i = 0; $i -lt $Packages.Count; $i++) {
    $pattern = "*$($Packages[$i])*"
    if (Get-AppxProvisionedPackage -Online | ? {$_.DisplayName -like $pattern -or $_.PackageName -like $pattern}) {$left = $true; break}
    if (@(Get-AppxPackage -AllUsers -PackageTypeFilter Bundle; Get-AppxPackage -AllUsers) | ? {$_.PackageFullName -like $pattern -or $_.PackageFamilyName -like $pattern}) {$left = $true; break}
}

if ($left) {exit 1}