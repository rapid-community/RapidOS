@echo off
setlocal

:: ----------------------------------------------------------------------------------------- ::
:: This script manages the visibility of settings pages in Windows 10 and 11.                ::
:: It allows adding or removing specific pages to the "SettingsPageVisibility" registry key. ::
::                                                                                           ::
:: Available options:                                                                        ::
::   -add              : Add a page to SettingsPageVisibility                                ::
::   -remove           : Remove a page from SettingsPageVisibility                           ::
::   -addRapidWin10Def : Add RapidOS default settings for Windows 10                         ::
::   -addRapidWin11Def : Add RapidOS default settings for Windows 11                         ::
::                                                                                           ::
:: Note: I'm not as strong in batch scripting as I am in PowerShell, so the code             ::
:: may seem a bit rough, but it works perfectly for it's intended purpose.                   ::
:: ----------------------------------------------------------------------------------------- ::

:: Ensure administrator privileges
set "___args="%~f0" %*"
fltmc > nul 2>&1 || (
	powershell -c "Start-Process -Verb RunAs -FilePath 'cmd' -ArgumentList """/c $env:___args"""" 2> nul || (
		echo You must run this script as admin.
		if "%*"=="" pause
		exit /b 1
	)
	exit /b
)

if "%~1"=="" (
    echo.
    echo Usage:
    echo ---------
    echo  Set-Pages.cmd [-add] [-remove] [-addRapidWin10Def] [-addRapidWin11Def]
    echo.
    echo  -add         : Add a new page to the SettingsPageVisibility key
    echo  -remove      : Remove a page from the SettingsPageVisibility key
    echo  -addRapidWin10Def : Add Windows 10 default settings to the SettingsPageVisibility key
    echo  -addRapidWin11Def : Add Windows 11 default settings to the SettingsPageVisibility key
    echo.
    echo  Example:
    echo  ---------
    echo  Set-Pages.cmd -add home
    echo  Set-Pages.cmd -remove privacy
    echo  Set-Pages.cmd -addRapidWin10Def
    echo  Set-Pages.cmd -addRapidWin11Def
    echo.
) else if /i "%~1" neq "-add" if /i "%~1" neq "-remove" if /i "%~1" neq "-addRapidWin10Def" if /i "%~1" neq "-addRapidWin11Def" (
    echo Error: Invalid argument "%~1"
    echo.
    echo Usage:
    echo ---------
    echo  Set-Pages.cmd [-add] [-remove] [-addRapidWin10Def] [-addRapidWin11Def]
    echo.
    echo  -add         : Add a new page to the SettingsPageVisibility registry key
    echo  -remove      : Remove a page from the SettingsPageVisibility registry key
    echo  -addRapidWin10Def : Add RapidOS 10 default settings to the SettingsPageVisibility registry key
    echo  -addRapidWin11Def : Add RapidOS 11 default settings to the SettingsPageVisibility registry key
    echo.
    echo  Example:
    echo  ---------
    echo  Set-Pages.cmd -add home
    echo  Set-Pages.cmd -remove privacy
    echo  Set-Pages.cmd -addRapidWin10Def
    echo  Set-Pages.cmd -addRapidWin11Def
    echo.
)

set "___pageKey=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
set ___currentPages=

(for /f "usebackq tokens=3*" %%a in (`reg query "%___pageKey%" /v "SettingsPageVisibility"`) do (set "___currentPages=%%a%%b")) > nul 2>&1
if defined ___currentPages set "___currentPages=%___currentPages: =%"

if "%~1"=="-add" (
    if "%~2"=="" (
        echo.
    ) else (
        call :addPage "%~2"
    )
)
if "%~1"=="-remove" (
    if "%~2"=="" (
        echo.
    ) else (
        call :removePage "%~2"
    )
)
if "%~1"=="-addRapidWin10Def" call :addRapidWin10Def
if "%~1"=="-addRapidWin11Def" call :addRapidWin11Def
if not "%~1"=="-add" if not "%~1"=="-remove" if not "%~1"=="-addRapidWin10Def" if not "%~1"=="-addRapidWin11Def" (
    echo.
)

taskkill /f /im SystemSettings.exe > nul 2>&1

if /i "%~1" neq "-addRapidWin10Def" if /i "%~1" neq "-addRapidWin11Def" (
    pause
)
goto :eof

:addPage
    echo Adding %~1...
    if not defined ___currentPages (
        set "___newValue=hide:%~1"
    ) else (
        echo %___currentPages% | find "%~1" > nul && (
            echo This parameter has already been added.
            goto :eof
        )
        set "___newValue=%___currentPages%;%~1"
    )
    reg add "%___pageKey%" /v "SettingsPageVisibility" /t REG_SZ /d "%___newValue%" /f > nul
    reg query "%___pageKey%" /v "SettingsPageVisibility" | find "%___newValue%" > nul 2>&1 && echo Successful || echo Failed
    goto :eof

:removePage
    echo Removing %~1...
    if not defined ___currentPages exit /b

    set "___page=%~1"
    call set "___newPages=%%___currentPages:%___page%=%%"
    set "___newPages=%___newPages:;;=;%"
    set "___newPages=%___newPages:;;=;%"
    if "%___newPages:~-1%"==";" set "___newPages=%___newPages:~0,-1%"
    if "%___newPages:~-1%"==" " set "___newPages=%___newPages:~0,-1%"
    if "%___newPages%"=="%___currentPages%" (
        echo This parameter does not exist.
        goto :eof
    )
    reg add "%___pageKey%" /v "SettingsPageVisibility" /t REG_SZ /d "%___newPages%" /f > nul
    reg query "%___pageKey%" /v "SettingsPageVisibility" | find "%___newPages%" > nul 2>&1 && echo Successful || echo Failed
    goto :eof

:addRapidWin10Def
    echo Adding RapidOS 10 default settings...
    reg add "%___pageKey%" /v "SettingsPageVisibility" /t REG_SZ /d "hide:backup;maps;maps-downloadmaps;mobile-devices;mobile-devices-addphone;privacy;privacy-activityhistory;privacy-feedback;privacy-general;privacy-speech;privacy-speechtyping;recovery;search-permissions;workplace" /f > nul
    reg query "%___pageKey%" /v "SettingsPageVisibility" | find "hide:backup;maps;maps-downloadmaps;mobile-devices;mobile-devices-addphone;privacy;privacy-activityhistory;privacy-feedback;privacy-general;privacy-speech;privacy-speechtyping;recovery;search-permissions;workplace" > nul 2>&1 && echo Successful || echo Failed
    goto :eof

:addRapidWin11Def
    echo Adding RapidOS 11 default settings...
    reg add "%___pageKey%" /v "SettingsPageVisibility" /t REG_SZ /d "hide:deviceusage;family-group;home;maps;maps-downloadmaps;privacy;privacy-activityhistory;privacy-feedback;privacy-general;recovery;search-permissions;workplace" /f > nul
    reg query "%___pageKey%" /v "SettingsPageVisibility" | find "hide:deviceusage;family-group;home;maps;maps-downloadmaps;privacy;privacy-activityhistory;privacy-feedback;privacy-general;recovery;search-permissions;workplace" > nul 2>&1 && echo Successful || echo Failed
    goto :eof