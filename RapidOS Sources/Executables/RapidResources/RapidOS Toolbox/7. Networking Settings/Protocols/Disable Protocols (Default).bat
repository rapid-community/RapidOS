@echo off
setlocal

set "___args="%~f0" %*"
fltmc > nul 2>&1 || (
	powershell -c "Start-Process -Verb RunAs -FilePath 'cmd' -ArgumentList """/c $env:___args"""" 2> nul || (
		echo You must run this script as admin.
		if "%*"=="" pause
		exit /b 1
	)
	exit /b
)

echo Disabling insecure protocols improves security by blocking weak ciphers.
echo These protocols aren't needed by most users, so RapidOS disables them by default.
echo Compatibility issues may arise with older apps, but they're not essential for regular use.
echo.
echo Still want to proceed?
pause

:: Disable anonymous access parameter
echo Disabling anonymous access...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" /v RestrictNullSessAccess /t REG_DWORD /d 1 /f > nul 2>&1

:: Disable insecure RC2 ciphers
echo Disabling insecure RC2 ciphers...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 40/128" /v Enabled /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 56/128" /v Enabled /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 128/128" /v Enabled /t REG_DWORD /d 0 /f > nul 2>&1

:: Disable insecure RC4 ciphers
echo Disabling insecure RC4 ciphers...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 40/128" /v Enabled /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 56/128" /v Enabled /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 64/128" /v Enabled /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 128/128" /v Enabled /t REG_DWORD /d 0 /f > nul 2>&1

:: Disable insecure DES cipher
echo Disabling insecure DES cipher...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\DES 56/56" /v Enabled /t REG_DWORD /d 0 /f > nul 2>&1

:: Disable insecure Triple DES cipher
echo Disabling insecure Triple DES cipher...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\Triple DES 168" /v Enabled /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\Triple DES 168/168" /v Enabled /t REG_DWORD /d 0 /f > nul 2>&1

:: Disable insecure NULL cipher
echo Disabling insecure NULL cipher...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\NULL" /v Enabled /t REG_DWORD /d 0 /f > nul 2>&1

:: Disable insecure connections from .NET apps
echo Disabling insecure connections from .NET apps...
reg add "HKLM\SOFTWARE\Microsoft\.NETFramework\v2.0.50727" /v SchUseStrongCrypto /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v2.0.50727" /v SchUseStrongCrypto /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" /v SchUseStrongCrypto /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319" /v SchUseStrongCrypto /t REG_DWORD /d 1 /f > nul 2>&1

:: Disable insecure renegotiation
echo Disabling insecure renegotiation...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" /v AllowInsecureRenegoClients /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" /v AllowInsecureRenegoServers /t REG_DWORD /d 0 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" /v DisableRenegoOnServer /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" /v DisableRenegoOnClient /t REG_DWORD /d 1 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" /v UseScsvForTls /t REG_DWORD /d 1 /f > nul 2>&1

:: Disable SMB Throttling
echo Disabling SMB Throttling...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v DisableBandwidthThrottling /t REG_DWORD /d 1 /f > nul 2>&1

:: Enable strong key requirement
echo Enabling strong key requirement...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\Diffie-Hellman" /v ServerMinKeyBitLength /t REG_DWORD /d 2048 /f > nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\Diffie-Hellman" /v ClientMinKeyBitLength /t REG_DWORD /d 2048 /f > nul 2>&1

:: Disable Anonymous Enumeration parameters
echo Disabling Anonymous Enumeration...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictAnonymous /t REG_DWORD /d 1 /f > nul 2>&1

echo All unnecessary protocols have been disabled!
pause
exit /b