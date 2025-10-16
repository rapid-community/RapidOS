@echo off
setlocal

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo Enabling Ai Features means enabling Copilot and Recall.
echo.
echo Still want to proceed?
pause

reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowCopilotButton /f > nul 2>&1
reg delete "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /f > nul 2>&1

reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /f > nul 2>&1

echo Copilot and Recall have been enabled.
pause
exit /b