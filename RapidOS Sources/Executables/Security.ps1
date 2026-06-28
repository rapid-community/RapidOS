#Requires -RunAsAdministrator

# ==============================
# Secure WinRM
# ==============================
Write-Host 'Configuring WinRM' -F Green

Write-Host 'Getting hostname...' -F DarkGray
try {$hostname = [Net.Dns]::GetHostEntry([Net.Dns]::GetHostName()).HostName} catch {$hostname = 'localhost'}

Write-Host 'Creating trusted certificate...' -F DarkGray
$cert = New-SelfSignedCertificate -CertStoreLocation Cert:\LocalMachine\My -DnsName $hostname -KeyUsage DigitalSignature,KeyEncipherment -TextExtension '2.5.29.37={text}1.3.6.1.5.5.7.3.1'
if (!$cert) {Write-Warning 'Failed to create certificate.'; exit}

$cer = "$env:TEMP\winrm.cer"
Export-Certificate -Cert $cert -FilePath $cer -Type CERT *>$null
Import-Certificate -FilePath $cer -CertStoreLocation Cert:\LocalMachine\Root *>$null
del $cer -Force *>$null

Write-Host 'Creating HTTPS-only listener...' -F DarkGray
if (!(Test-WSMan -EA 0)) {winrm quickconfig -Force *>$null}
winrm delete winrm/config/Listener?Address=*+Transport=HTTP *>$null
winrm delete winrm/config/Listener?Address=*+Transport=HTTPS *>$null
winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$hostname`";CertificateThumbprint=`"$($cert.Thumbprint)`"}" *>$null
winrm set winrm/config/service '@{AllowUnencrypted="false"}' *>$null

Write-Host 'Restricting WinRM firewall to LocalSubnet...' -F DarkGray
Get-NetFirewallRule -DisplayGroup 'Windows Remote Management' -EA 0 | ? {$_.Direction -eq 'Inbound'} | Set-NetFirewallRule -RemoteAddress LocalSubnet

Restart-Service WinRM -Force *>$null

# ==============================
# Secure LanmanServer
# ==============================
Write-Host "`nConfiguring LanmanServer" -F Green

Write-Host 'Forcing NTLMv2-only auth, blocking insecure guest fallback...' -F DarkGray
Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'LmCompatibilityLevel' -Type DWord -Value 5
Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' -Name 'AllowInsecureGuestAuth' -Type DWord -Value 0

Write-Host 'Enforcing SMBv2-only with required signing...' -F DarkGray
Set-SmbServerConfiguration -EnableSMB1Protocol $false -EnableSMB2Protocol $true -RequireSecuritySignature $true -Force

# ==============================
# Harden network & system
# ==============================
Write-Host "`nConfiguring legacy network protocols" -F Green

Write-Host 'Enabling LSA Protection (PPL) + auditing...' -F DarkGray
Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RunAsPPL' -Type DWord -Value 1
Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\LSASS.exe' -Name 'AuditLevel' -Type DWord -Value 8

Write-Host 'Disabling NetBIOS over TCP/IP...' -F DarkGray
Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Services\NetBT\Parameters' -Name 'EnableLMHOSTS' -Type DWord -Value 0
Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' | ? {$null -ne $_.TcpipNetbiosOptions} | % {Invoke-CimMethod -InputObject $_ -MethodName SetTcpipNetbios -Arguments @{TcpipNetbiosOptions = 2} *>$null}

Write-Host 'Disabling LLMNR...' -F DarkGray
Edit-Registry -Path 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' -Name 'EnableMulticast' -Type DWord -Value 0

Write-Host 'Disabling WPAD...' -F DarkGray
Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad' -Name 'WpadOverride' -Type DWord -Value 1
Edit-Registry -Path 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Wpad' -Name 'WpadOverride' -Type DWord -Value 1

Write-Host 'Disabling WDigest credential caching...' -F DarkGray
Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\Wdigest' -Name 'UseLogonCredential' -Type DWord -Value 0

Write-Host 'Disabling Outlook OLE package previews...' -F DarkGray
'16.0', '15.0', '14.0', '12.0' | % {
    Edit-Registry -Path "HKLM\SOFTWARE\Microsoft\Office\$_\Outlook\Security" -Name 'ShowOLEPackageObj' -Type DWord -Value 0
    Edit-Registry -Path "HKCU\SOFTWARE\Microsoft\Office\$_\Outlook\Security" -Name 'ShowOLEPackageObj' -Type DWord -Value 0
}

Write-Host "`nDone."