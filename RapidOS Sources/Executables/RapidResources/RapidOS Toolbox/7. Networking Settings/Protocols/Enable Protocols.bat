@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Re-enable anonymous access
echo Re-enabling anonymous access...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" /v RestrictNullSessAccess /t REG_DWORD /d 0 /f > nul 2>&1

:: Re-enable insecure RC2 ciphers
echo Re-enabling insecure RC2 ciphers...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 40/128" /v Enabled /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 56/128" /v Enabled /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 128/128" /v Enabled /t REG_DWORD /d 1 /f > nul 2>&1

:: Re-enable insecure RC4 ciphers
echo Re-enabling insecure RC4 ciphers...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 40/128" /v Enabled /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 56/128" /v Enabled /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 64/128" /v Enabled /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 128/128" /v Enabled /t REG_DWORD /d 1 /f > nul 2>&1

:: Re-enable insecure DES cipher
echo Re-enabling insecure DES cipher...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\DES 56/56" /v Enabled /t REG_DWORD /d 1 /f > nul 2>&1

:: Re-enable insecure Triple DES cipher
echo Re-enabling insecure Triple DES cipher...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\Triple DES 168" /v Enabled /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\Triple DES 168/168" /v Enabled /t REG_DWORD /d 1 /f > nul 2>&1

:: Re-enable insecure NULL cipher
echo Re-enabling insecure NULL cipher...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\NULL" /v Enabled /t REG_DWORD /d 1 /f > nul 2>&1

:: Re-enable insecure connections from .NET apps
echo Re-enabling insecure connections from .NET apps...
reg add "HKLM\SOFTWARE\Microsoft\.NETFramework\v2.0.50727" /v SchUseStrongCrypto /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v2.0.50727" /v SchUseStrongCrypto /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" /v SchUseStrongCrypto /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319" /v SchUseStrongCrypto /t REG_DWORD /d 0 /f > nul 2>&1

:: Re-enable insecure renegotiation
echo Re-enabling insecure renegotiation...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" /v AllowInsecureRenegoClients /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" /v AllowInsecureRenegoServers /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" /v DisableRenegoOnServer /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" /v DisableRenegoOnClient /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" /v UseScsvForTls /t REG_DWORD /d 0 /f > nul 2>&1

:: Re-enable SMB Throttling
echo Re-enabling SMB Throttling...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v DisableBandwidthThrottling /t REG_DWORD /d 0 /f > nul 2>&1

:: Re-enable weak key requirement
echo Re-enabling weak key requirement...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\Diffie-Hellman" /v ServerMinKeyBitLength /t REG_DWORD /d 1024 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\Diffie-Hellman" /v ClientMinKeyBitLength /t REG_DWORD /d 1024 /f > nul 2>&1

:: Re-enable Anonymous Enumeration parameters
echo Re-enabling Anonymous Enumeration...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictAnonymous /t REG_DWORD /d 0 /f > nul 2>&1

echo All protocols have been restored to their default settings.
pause
exit /b