#Requires -RunAsAdministrator

# ========================================================================= #
# --- Secure WinRT ---                                                      #
# Code below configures WinRM for secure HTTPS operation.                   #
# It creates a selfsigned certificate, sets up a listener, disables         #
# unencrypted connections, and restricts access via firewall if enabled.    #
# Made to keep the service (WinRM - which is unsafe but necessary for some) #
# enabled, but limiting it's functionality to make it much safer.           #
# ========================================================================= #

Write-Host "Configuring WinRT"

Write-Host "Getting hostname..." -F DarkGray
try {$hostname = [System.Net.Dns]::GetHostEntry([System.Net.Dns]::GetHostName()).HostName} catch {$hostname = "localhost"}

Write-Host "Creating trusted certificate..." -F DarkGray                                                                               # -TextExtension ensures Server Authentication OID
$cert = New-SelfSignedCertificate -CertStoreLocation Cert:\LocalMachine\My -DnsName $hostname -KeyUsage DigitalSignature,KeyEncipherment -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.1"); if (!$cert) {Write-Warning "Failed to create certificate."; exit}
Export-Certificate -Cert $cert -FilePath "$env:TEMP\winrm.cer" -Type CERT *>$null
Import-Certificate -FilePath "$env:TEMP\winrm.cer" -CertStoreLocation Cert:\LocalMachine\Root *>$null
Remove-Item "$env:TEMP\winrm.cer" -Force *>$null

Write-Host "Creating secure HTTPS listener..." -F DarkGray
if (!(Test-WSMan -EA 0)) {& winrm quickconfig -Force *>$null}
$l = & winrm enumerate winrm/config/Listener | ? {$_ -match "Transport = HTTPS"}
# Remove existing HTTPS listener to avoid conflicts
if ($l) {winrm delete winrm/config/Listener?Address=*+Transport=HTTPS *>$null}
winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$hostname`";CertificateThumbprint=`"$($cert.Thumbprint)`"}" *>$null
winrm set winrm/config/service '@{AllowUnencrypted="false"}' *>$null

Restart-Service -Name WinRM -Force *>$null

# ========================================================================= #
# --- Secure LanmanServer ---                                               #
# Code below remove LanmanServer's outdated protocols, to eliminate         #
# outdated vulnerabilities. Playbook sets service at 'Manual' state, so it  #
# becomes more secure. SMBv1 is disabled and only SMBv2/SMBv3 are allowed.  #
# This approach minimize risks while still supporting file/printer sharing. #
# ========================================================================= #

Write-Host "`nConfiguring LanmanServer"

Write-Host "Disabling SMBv1, Guest Account; forcing NTLMv2-only authentication..." -F DarkGray
Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -Type DWORD -Value 0
Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "EnableGuestAccount" -Type DWORD -Value 0
Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -Type DWORD -Value 5

Write-Host "Enabling SMBv2; requiring verification (signing) for data transmitted over SMB..." -F DarkGray
Set-SmbServerConfiguration -EnableSMB2Protocol $true -EnableSMB1Protocol $false -Force
Set-SmbServerConfiguration -RequireSecuritySignature $true -Force

# ========================================================================= #
# --- Harden Network & System Security ---                                  #
# Disables legacy/insecure protocols (NetBIOS, LLMNR, mDNS, WPAD) and       #
# other attack vectors (WDigest, Office OLE) to reduce the system's         #
# overall attack surface while maintaining core functionality.              #
# ========================================================================= #

Write-Host "`nConfiguring legacy network protocols"

Write-Host "Enabling LSA Protection/Auditing..." -F DarkGray
Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\LSASS.exe" -Name "AuditLevel" -Type "DWORD" -Value 8

Write-Host "Disabling NetBIOS over TCP/IP..." -F DarkGray
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters" -Name "EnableLMHOSTS" -Type DWORD -Value 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces" -Name "NetbiosOptions" -Type DWORD -Value 2
$adapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True"
foreach ($adapter in $adapters) {
    if ($null -ne $adapter.TcpipNetbiosOptions) {
        Invoke-CimMethod -InputObject $adapter -MethodName SetTcpipNetbios -Arguments @{TcpipNetbiosOptions = 2} *>$null
    }
}

Write-Host "Disabling LLMNR..." -F DarkGray
Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Type DWORD -Value 0
Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "EnableMulticast" -Type DWORD -Value 0

Write-Host "Disabling mDNS..." -F DarkGray
if (Get-Service -Name "FDResPub" -EA 0) {
    Stop-Service -Name "FDResPub" -Force -EA 0
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\FDResPub" -Name "Start" -Type DWORD -Value 4
}

Write-Host "Disabling WPAD..." -F DarkGray
Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Name "WpadOverride" -Type "DWORD" -Value 1
Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad" -Name "WpadOverride" -Type "DWORD" -Value 1

Write-Host "Disabling WDigest..." -F DarkGray
Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\Wdigest" -Name "UseLogonCredential" -Type "DWORD" -Value 0

Write-Host "Disabling Office OLE..." -F DarkGray
$versions = '16.0', '15.0', '14.0', '12.0'
foreach ($version in $versions) {
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Office\$version\Outlook\Security" -Name "ShowOLEPackageObj" -Type "DWORD" -Value 0
    Set-RegistryValue -Path "HKCU:\SOFTWARE\Microsoft\Office\$version\Outlook\Security" -Name "ShowOLEPackageObj" -Type "DWORD" -Value 0
}

Write-Host "`nDone."