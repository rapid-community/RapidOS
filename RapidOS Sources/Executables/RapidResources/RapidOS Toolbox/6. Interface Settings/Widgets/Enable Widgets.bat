@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo A component check will now be performed to enable widgets...
timeout /t 3 /nobreak >nul
cls

set "edgeInstalled=0"
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
    set edgeInstalled=1
)

set "webviewInstalled=0"
for /d %%a in ("%ProgramFiles(x86)%\Microsoft\EdgeWebView\Application\*") do (
    if exist "%%a\msedgewebview2.exe" (
        set webviewInstalled=1
    )
)

set "webexperienceInstalled=0"
powershell -Command "if (Get-AppxPackage -AllUsers *WebExperience* | Where-Object { $_.Name -like '*WebExperience*' }) { exit 1 }"
if errorlevel 1 (
    set webexperienceInstalled=1
)

set "enableFeeds=0"
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" /v EnableFeeds | find "1" > nul 2>&1 && set enableFeeds=1

set "shellFeedsTaskbarViewMode=0"
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" /v ShellFeedsTaskbarViewMode | find "0" > nul 2>&1 && set shellFeedsTaskbarViewMode=1

set "taskbarDa=0"
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa | find "1" > nul 2>&1 && set taskbarDa=1

set "allowNewsAndInterests=0"
reg query "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests | find "1" > nul 2>&1 && set allowNewsAndInterests=1

echo Checking installations:
if "%edgeInstalled%"=="1" (echo Microsoft Edge: INSTALLED) else (echo Microsoft Edge: NOT INSTALLED)
if "%webviewInstalled%"=="1" (echo Edge WebView2: INSTALLED) else (echo Edge WebView2: NOT INSTALLED)
if "%webexperienceInstalled%"=="1" (echo Widgets app: INSTALLED) else (echo Widgets app: NOT INSTALLED)

echo.
echo Checking registry settings:
if "%enableFeeds%"=="1" (echo EnableFeeds: ENABLED) else (echo EnableFeeds: DISABLED)
if "%shellFeedsTaskbarViewMode%"=="1" (echo ShellFeedsTaskbarViewMode: ENABLED) else (echo ShellFeedsTaskbarViewMode: DISABLED)
if "%taskbarDa%"=="1" (echo TaskbarDa: ENABLED) else (echo TaskbarDa: DISABLED)
if "%allowNewsAndInterests%"=="1" (echo AllowNewsAndInterests: ENABLED) else (echo AllowNewsAndInterests: DISABLED)

if "%edgeInstalled%"=="1" if "%webviewInstalled%"=="1" if "%webexperienceInstalled%"=="1" (
    if "%enableFeeds%"=="1" if "%shellFeedsTaskbarViewMode%"=="1" if "%taskbarDa%"=="1" if "%allowNewsAndInterests%"=="1" (
        echo.
        echo All components and registry settings are ENABLED and INSTALLED.
        echo Likely Widgets are enabled on your system.
        pause
        exit /b
    )
)

echo.
set /p userChoice="Install components and enable settings (yes/no)? "
if /i "%userChoice%"=="yes" (
    if %edgeInstalled%==0 (
        ping -n 1 google.com > nul
        if errorlevel 1 (
            echo No internet connection detected!
            pause
            exit /b 1
        )
        powershell -Command "Write-Host 'Downloading Microsoft Edge...'; [Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; md -Path $env:temp\edgeinstall -erroraction SilentlyContinue | Out-Null; $Download = join-path $env:temp\edgeinstall MicrosoftEdgeEnterpriseX64.msi; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest 'http://go.microsoft.com/fwlink/?LinkID=2093437' -OutFile $Download; Start-Process $Download -ArgumentList '/quiet'; Write-Host 'Installed Microsoft Edge!'"
    )

    if %webviewInstalled%==0 (
        ping -n 1 google.com > nul
        if errorlevel 1 (
            echo No internet connection detected!
            pause
            exit /b 1
        )

        echo Downloading Edge WebView...
        curl.exe -Ls "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -o "%TEMP%\webview2_installer.exe"

        if exist "%TEMP%\webview2_installer.exe" (
            echo Installing Edge WebView...
            "%TEMP%\webview2_installer.exe" /silent /install
            if errorlevel 1 (
                echo Installation failed with error code %errorlevel%
            ) else (
                echo Installed Edge WebView!
            )
        ) else (
            echo Error: Download failed, installer not found.
        )
    )

    if %webexperienceInstalled%==0 (
        ping -n 1 google.com > nul
        if errorlevel 1 (
            echo No internet connection detected!
            pause
            exit /b 1
        )
        echo Installing Widgets app...
        winget install -e 9MSSGKG348SP --silent --force --accept-source-agreements --accept-package-agreements > nul 2>&1
        timeout /t 3 /nobreak >nul
        for /f "tokens=*" %%i in ('powershell -Command "Get-AppxPackage -AllUsers *WebExperience* | ForEach-Object { $_.InstallLocation }"') do (
            powershell -Command "Add-AppxPackage -DisableDevelopmentMode -Register \"%%i\AppXManifest.xml\""
        )
    )

    if %enableFeeds%==0 (
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" /v "EnableFeeds" /t REG_DWORD /d 1 /f > nul 2>&1
    )
    if %shellFeedsTaskbarViewMode%==0 (
        sc stop UCPD > nul 2>&1
        sc config UCPD start= disabled > nul 2>&1
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" /v "ShellFeedsTaskbarViewMode" /t REG_DWORD /d 0 /f > nul 2>&1
    )
    if %taskbarDa%==0 (
        sc stop UCPD > nul 2>&1
        sc config UCPD start= disabled > nul 2>&1
        reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarDa" /t REG_DWORD /d 1 /f > nul 2>&1
    )
    if %allowNewsAndInterests%==0 (
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v "AllowNewsAndInterests" /t REG_DWORD /d 1 /f > nul 2>&1
    )

    echo All components and settings have been restored!
) else (
    echo Configuration cancelled by user.
)

pause
exit /b