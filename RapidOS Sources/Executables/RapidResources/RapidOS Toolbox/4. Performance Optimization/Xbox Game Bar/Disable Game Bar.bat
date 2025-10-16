@echo off

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -c "$f='%~f0'; $lines=Get-Content $f; $idx=$lines.IndexOf(':PS'); iex ($lines[($idx+1)..($lines.Length-1)] -join [Environment]::NewLine)"
exit /b

echo Disabling Game Bar will definitely reduce performance on Dual-CCD AMD Ryzen 7000 and 9000 series processors. However, this does not mean it won't affect other processors. Proceed with caution.
echo.
echo Still want to proceed?
pause

:PS
Get-AppxPackage *XboxGamingOverlay* | Remove-AppxPackage
Get-AppxPackage *Microsoft.Edge.GameAssist* | Remove-AppxPackage

Write-Host "Game Bar has been disabled."
pause
exit