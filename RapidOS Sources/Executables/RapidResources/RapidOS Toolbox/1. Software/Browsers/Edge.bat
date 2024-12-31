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

:mainMenu
cls
echo Edge Configuration
echo.

echo [1] Install Edge
echo [2] Tweak Edge
echo [3] Documentation

set /p choice="Select an option: "

if "%choice%"=="1" (
    echo.
    echo Installing Edge...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; md -Path $env:temp\edgeinstall -erroraction SilentlyContinue | Out-Null; $Download = join-path $env:temp\edgeinstall MicrosoftEdgeEnterpriseX64.msi; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest 'http://go.microsoft.com/fwlink/?LinkID=2093437' -OutFile $Download; Start-Process $Download -ArgumentList '/quiet'"
    echo Installed Edge!
    pause
    goto mainMenu
) else if "%choice%"=="2" (
    :tweakMenu
    cls
    echo Tweak Menu
    echo.

    echo [1] Apply custom QoL policies
    echo [2] Remove custom QoL policies
    echo [3] Enable autoupdates
    echo [4] Disable autoupdates
    echo [5] Back to Main Menu

    set /p tweakChoice="Select an option: "
    
    if "%tweakChoice%"=="1" (
        powershell -ExecutionPolicy Bypass -File "C:\Windows\RapidScripts\UtilityScripts\Browsers-Optimization.ps1" -MyArgument configure_msedge_policies
        pause
        goto tweakMenu
    ) else if "%tweakChoice%"=="2" (
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge" /f > nul 2>&1
        echo Successfully removed Microsoft Edge policies!
        pause
        goto tweakMenu
    ) else if "%tweakChoice%"=="3" (
        powershell -ExecutionPolicy Bypass -File "C:\Windows\RapidScripts\UtilityScripts\Browsers-Optimization.ps1" -MyArgument enable_msedge_updates
        pause
        goto tweakMenu
    ) else if "%tweakChoice%"=="4" (
        powershell -ExecutionPolicy Bypass -File "C:\Windows\RapidScripts\UtilityScripts\Browsers-Optimization.ps1" -MyArgument disable_msedge_updates
        pause
        goto tweakMenu
    ) else if "%tweakChoice%"=="5" (
        goto mainMenu
    ) else (
        echo.
        echo Invalid choice in Tweak Menu.
        pause
        goto tweakMenu
    )
) else if "%choice%"=="3" (
    start "" "https://docs.rapid-community.ru/post-installation/browsers/"
    goto mainMenu
) else (
    echo.
    echo Invalid choice
    pause
    goto mainMenu
)

exit /b