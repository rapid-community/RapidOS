@echo off
setlocal

:: ========================================================================================= ::
:: This script manages the visibility of settings pages in Windows 10 and 11.                ::
:: It allows adding or removing specific pages to the "SettingsPageVisibility" registry key. ::
::                                                                                           ::
:: Available options:                                                                        ::
::   -add     : Add a page to SettingsPageVisibility                                         ::
::   -remove  : Remove a page from SettingsPageVisibility                                    ::
:: ========================================================================================= ::

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
    echo   Set-Pages.cmd [-add] [-remove]
    echo.
    echo   -add         : Hides a specified page in the Settings app
    echo   -remove      : Makes a previously hidden page visible again
    echo.
    echo   Example:
    echo   ---------
    echo   Set-Pages.cmd -add home
    echo   Set-Pages.cmd -remove privacy
    echo.
) else if /i "%~1" neq "-add" if /i "%~1" neq "-remove" (
    echo Error: Invalid argument "%~1"
    echo.
    echo Usage:
    echo ---------
    echo   Set-Pages.cmd [-add] [-remove]
    echo.
    echo   -add         : Hides a specified page in the Settings app
    echo   -remove      : Makes a previously hidden page visible again
    echo.
    echo   Example:
    echo   ---------
    echo   Set-Pages.cmd -add home
    echo   Set-Pages.cmd -remove privacy
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
if not "%~1"=="-add" if not "%~1"=="-remove" (
    echo.
)

taskkill /f /im SystemSettings.exe > nul 2>&1

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