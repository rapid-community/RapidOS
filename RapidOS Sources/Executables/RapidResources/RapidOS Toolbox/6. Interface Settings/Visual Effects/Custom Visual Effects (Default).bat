@echo off

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -c "$f='%~f0'; $lines=Get-Content $f; $idx=$lines.IndexOf(':PS'); iex ($lines[($idx+1)..($lines.Length-1)] -join [Environment]::NewLine)"
exit /b

:PS
$memGB = [math]::Round(((Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum) / 1GB)

$visualEffectsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
$desktopPath = 'HKCU:\Control Panel\Desktop'
$windowMetricsPath = 'HKCU:\Control Panel\Desktop\WindowMetrics'
$advancedExplorerPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$dwmPath = 'HKCU:\Software\Microsoft\Windows\DWM'
$personalizePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

Set-RegistryValue -Path $visualEffectsPath -Name 'VisualFXSetting' -Type DWORD -Value 3
Set-RegistryValue -Path $desktopPath -Name 'UserPreferencesMask' -Type Binary -Value ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00))
Set-RegistryValue -Path $windowMetricsPath -Name 'MinAnimate' -Type String -Value 0
Set-RegistryValue -Path $advancedExplorerPath -Name 'TaskbarAnimations' -Type DWORD -Value 0
Set-RegistryValue -Path $dwmPath -Name 'EnableAeroPeek' -Type DWORD -Value 0
Set-RegistryValue -Path $advancedExplorerPath -Name 'ListviewAlphaSelect' -Type DWORD -Value 1
Set-RegistryValue -Path $personalizePath -Name 'EnableTransparency' -Type DWORD -Value 0
Set-RegistryValue -Path $advancedExplorerPath -Name 'ListviewShadow' -Type DWORD -Value 0
Set-RegistryValue -Path $desktopPath -Name 'DragFullWindows' -Type String -Value 1
Set-RegistryValue -Path $dwmPath -Name 'AlwaysHibernateThumbnails' -Type DWORD -Value 0
Set-RegistryValue -Path $advancedExplorerPath -Name 'IconsOnly' -Type DWORD -Value 0
Set-RegistryValue -Path $desktopPath -Name 'FontSmoothing' -Type String -Value 2

if ($memGB -ge 8) {
    Set-RegistryValue -Path $desktopPath -Name 'UserPreferencesMask' -Type Binary -Value ([byte[]](0x90, 0x12, 0x07, 0x80, 0x12, 0x00, 0x00, 0x00))
    Set-RegistryValue -Path $windowMetricsPath -Name 'MinAnimate' -Type String -Value 1
    Set-RegistryValue -Path $advancedExplorerPath -Name 'TaskbarAnimations' -Type DWORD -Value 1
    Set-RegistryValue -Path $dwmPath -Name 'EnableAeroPeek' -Type DWORD -Value 1
    Set-RegistryValue -Path $personalizePath -Name 'EnableTransparency' -Type DWORD -Value 1
}

Write-Host "Visual Effects have been applied."
pause
exit