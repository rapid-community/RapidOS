@echo off

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -c "$f='%~f0'; $lines=Get-Content $f; $idx=$lines.IndexOf(':PS'); iex ($lines[($idx+1)..($lines.Length-1)] -join [Environment]::NewLine)"
exit /b

:PS
$memgb = [double]((Get-Specs -RAM) -replace '[^0-9,.]')

$desktop = 'HKCU\Control Panel\Desktop'
$windowmetrics = 'HKCU\Control Panel\Desktop\WindowMetrics'
$advanced = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$dwm = 'HKCU\SOFTWARE\Microsoft\Windows\DWM'
$personalize = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'

Edit-Registry -Path 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Type DWord -Value 3
Edit-Registry -Path $desktop -Name 'UserPreferencesMask' -Type Binary -Value ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00))
Edit-Registry -Path $windowmetrics -Name 'MinAnimate' -Value 0
Edit-Registry -Path $advanced -Name 'TaskbarAnimations' -Type DWord -Value 0
Edit-Registry -Path $dwm -Name 'EnableAeroPeek' -Type DWord -Value 0
Edit-Registry -Path $advanced -Name 'ListviewAlphaSelect' -Type DWord -Value 1
Edit-Registry -Path $personalize -Name 'EnableTransparency' -Type DWord -Value 0
Edit-Registry -Path $advanced -Name 'ListviewShadow' -Type DWord -Value 0
Edit-Registry -Path $desktop -Name 'DragFullWindows' -Value 1
Edit-Registry -Path $dwm -Name 'AlwaysHibernateThumbnails' -Type DWord -Value 0
Edit-Registry -Path $advanced -Name 'IconsOnly' -Type DWord -Value 0
Edit-Registry -Path $desktop -Name 'FontSmoothing' -Value 2

if ($memgb -ge 8) {
    Edit-Registry -Path $desktop -Name 'UserPreferencesMask' -Type Binary -Value ([byte[]](0x90, 0x12, 0x07, 0x80, 0x12, 0x00, 0x00, 0x00))
    Edit-Registry -Path $windowmetrics -Name 'MinAnimate' -Value 1
    Edit-Registry -Path $advanced -Name 'TaskbarAnimations' -Type DWord -Value 1
    Edit-Registry -Path $dwm -Name 'EnableAeroPeek' -Type DWord -Value 1
    Edit-Registry -Path $personalize -Name 'EnableTransparency' -Type DWord -Value 1
}

Write-Host "Visual Effects have been applied."
pause
exit