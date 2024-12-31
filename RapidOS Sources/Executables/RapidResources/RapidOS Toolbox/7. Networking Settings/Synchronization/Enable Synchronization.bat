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

reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\SettingSync" /f > nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /f > nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Credentials" /f > nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Language" /f > nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\SettingSync\Groups\DesktopTheme" /f > nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\SettingSync\Groups\BrowserSettings" /f > nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Accessibility" /f > nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Windows" /f > nul 2>&1 
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\SettingSync\Groups\StartLayout" /f > nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\PolicyManager\default\Experience\AllowSyncMySettings" /f > nul 2>&1
reg delete "HKCU\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy" /f> nul 2>&1

sc config OneSyncSvc start= auto > nul 2>&1
net start OneSyncSvc > nul 2>&1

echo Syncing has been enabled!
pause
exit /b