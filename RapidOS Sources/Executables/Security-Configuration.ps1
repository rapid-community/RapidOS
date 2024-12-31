# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) { Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow; $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -MyArgument {1}" -f $PSCommandPath, $MyArgument; Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs; exit }

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

# Disable LLMNR
# https://www.blackhillsinfosec.com/how-to-disable-llmnr-why-you-want-to/
Set-RegistryValue -Path "HKLM:\SOFTWARE\policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Type "DWORD" -Value 0

# Disable NetBIOS
# http://blog.dbsnet.fr/disable-netbios-with-powershell#:~:text=Disabling%20NetBIOS%20over%20TCP%2FIP,connection%2C%20then%20set%20NetbiosOptions%20%3D%202
$key = "HKLM:SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces"
Get-ChildItem $key | ForEach-Object { 
    Write-Host("Modify $key\$($_.pschildname)")
    $NetbiosOptions = (Get-ItemProperty "$key\$($_.pschildname)").NetbiosOptions
    Write-Host("NetbiosOptions updated value is $NetbiosOptions")
}

# Disable WPAD
# https://adsecurity.org/?p=3299
Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Name "WpadOverride" -Type "DWORD" -Value 1
Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Name "WpadOverride" -Type "DWORD" -Value 1

# Enable LSA Protection/Auditing
# https://adsecurity.org/?p=3299
Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\LSASS.exe" -Name "AuditLevel" -Type "DWORD" -Value 8

# Disable Windows Script Host
# https://adsecurity.org/?p=3299
# Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings" -Name "Enabled" -Type "DWORD" -Value 0

# Disable WDigest
# https://adsecurity.org/?p=3299
Set-RegistryValue -Path "HKLM:\System\CurrentControlSet\Control\SecurityProviders\Wdigest" -Name "UseLogonCredential" -Type "DWORD" -Value 0

# Disable Office OLE
# https://adsecurity.org/?p=3299
$officeversions = '16.0', '15.0', '14.0', '12.0'
ForEach ($officeversion in $officeversions) {
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Office\$officeversion\Outlook\Security" -Name "ShowOLEPackageObj" -Type "DWORD" -Value 0
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Office\$officeversion\Outlook\Security" -Name "ShowOLEPackageObj" -Type "DWORD" -Value 0
}