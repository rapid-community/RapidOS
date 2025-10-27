#Requires -RunAsAdministrator

param (
    [Parameter(Mandatory = $true)]
    [string[]]$Packages
)

$regKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore'
$allPackages = Get-AppxPackage -AllUsers | Select PackageFullName, PackageFamilyName, PackageUserInformation, NonRemovable

# ==============================
# Resolve and remove packages
# ==============================
for ($i = 0; $i -lt $Packages.Count; $i++) {
    $pattern = $Packages[$i]
    $patternWithWildcards = "*$pattern*"
    $match = $allPackages | ? {$_.PackageFullName -like $patternWithWildcards -or $_.PackageFamilyName -like $patternWithWildcards}
    if (!$match) {continue}

    $match | % {
        $pkg = $_
        $name = $pkg.PackageFullName
        $family = $pkg.PackageFamilyName

        Write-Host "Removing package: $name"

        # === Registry deprovisioning ===
        New-Item -Path (Join-Path $regKey "Deprovisioned\$family") -Force *>$null
        $inbox = Join-Path $regKey "InboxApplications\$name"
        if (Test-Path $inbox) {del $inbox -Force *>$null}

        # === Bypass non-removable flag ===
        if ($pkg.NonRemovable -eq $true) {
            Set-NonRemovableAppsPolicy -Online -PackageFamilyName $family -NonRemovable 0 *>$null
        }

        # === Per-user cleanup ===
        $pkg.PackageUserInformation | % {
            $info = $_
            $sid = $info.UserSecurityID.SID
            if (!$sid) {$sid = $info.UserSecurityId}
            if (!$sid -or $sid -match '^S-1-5-(18|19|20)$') {continue}

            New-Item -Path (Join-Path $regKey "EndOfLife\$sid\$name") -Force *>$null
            try {
                Remove-AppxPackage -Package $name -User $sid
            } catch {}
        }

        # ==============================
        # Deep registry cleanup
        # ==============================
        $pkg.PackageUserInformation | % {
            $sid = $_.UserSecurityID.SID
            if (!$sid) {$sid = $_.UserSecurityId}
            if (!$sid) {continue}

            # === Precise registry paths ===
            $exactPaths = @(
                "HKU:\${sid}_Classes\Extensions\ContractId\Windows.BackgroundTasks\PackageId\$name",
                "HKU:\${sid}_Classes\Extensions\ContractId\Windows.Launch\PackageId\$name",
                "HKU:\${sid}_Classes\Extensions\ContractId\Windows.Protocol\PackageId\$name",
                "HKU:\${sid}_Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppContainer\Storage\$family",
                "HKU:\${sid}_Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\PolicyCache\$family",
                "HKU:\${sid}_Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\$family",
                "HKU:\${sid}_Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages\$name",
                "HKU:\${sid}_Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Families\$family"
            )
            $exactPaths | ? {Test-Path $_} | % {Remove-Item $_ -Recurse -Force *>$null}

            # === Additional PackageId paths ===
            $packageIdRoot = "HKU:\${sid}_Classes\Extensions\ContractId"
            if (Test-Path $packageIdRoot) {
                gci $packageIdRoot -EA 0 | % {
                    gci $_.PSPath -EA 0 | ? {
                        $_.PSChildName -eq "PackageId" -and (
                            $_.GetValueNames() | ? {
                                $value = $_; $value -eq $name -or $value -eq $family
                            }
                        )
                    } | % {Remove-Item $_.PSPath -Recurse -Force *>$null}
                }
            }

            # === HKCR cleanup ===
            $hkcrRoot = "HKCR:\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages"
            if (Test-Path $hkcrRoot) {
                gci $hkcrRoot -EA 0 | ? {
                    $_.PSChildName -eq $name -or $_.PSChildName -eq $family
                } | % {Remove-Item $_.PSPath -Recurse -Force *>$null}
            }
        }

        # ==============================
        # File system cleanup
        # ==============================
        $appRepo = "$env:ProgramData\Microsoft\Windows\AppRepository"
        $winApps = "$env:ProgramFiles\WindowsApps"

        # === Clean AppRepository ===
        gci $appRepo -Filter "*$family*.xml" -EA 0 | % {
            del $_.FullName -Force -EA 0 *>$null
            $pkgFolder = Join-Path (Join-Path $appRepo "Packages") $_.BaseName
            if (Test-Path $pkgFolder) {del $pkgFolder -Force -Recurse *>$null}
        }

        # === Clean AppData ===
        Get-CimInstance -ClassName Win32_UserProfile | % {
            if (!$_.LocalPath -or $_.LocalPath.Trim() -eq '') {continue}
            $userAppData = Join-Path $_.LocalPath "AppData\Local\Packages"
            if (Test-Path $userAppData) {
                gci $userAppData -Filter "*$family*" -EA 0 | % {
                    del $_.FullName -Force -Recurse *>$null
                }
            }
        }

        # === Clean WindowsApps ===
        gci $winApps -Filter "$name*" -EA 0 | % {
            $folder = $_.FullName
            cmd /c takeown /f "$folder" /r /d y *>$null
            cmd /c icacls "$folder" /grant *S-1-5-32-544:F /t /c /q *>$null
            del $folder -Force -Recurse *>$null
        }

        # === Final system-wide removal ===
        try {
            Remove-AppxPackage -Package $name -AllUsers
        } catch {}
    }
}