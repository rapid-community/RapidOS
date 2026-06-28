@echo off

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -c "$f='%~f0'; $lines=Get-Content $f; $idx=$lines.IndexOf(':PS'); iex ($lines[($idx+1)..($lines.Length-1)] -join [Environment]::NewLine)"
exit /b

:PS
Import-RegState -JsonPath "$env:SystemRoot\RapidScripts\MMCSS.json" *>$null;
$mmcss = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile";
Edit-Registry -Path $mmcss -Name "SystemResponsiveness" -Type DWord -Value 10;
        
Edit-Registry -Path "$mmcss\Tasks\Audio" -Name "Scheduling Category" -Value "Medium";
Edit-Registry -Path "$mmcss\Tasks\Audio" -Name "Priority" -Type DWord -Value 1;
Edit-Registry -Path "$mmcss\Tasks\Audio" -Name "Priority When Yielded" -Type DWord -Value 1;

Edit-Registry -Path "$mmcss\Tasks\Pro Audio" -Name "Scheduling Category" -Value "Medium";
Edit-Registry -Path "$mmcss\Tasks\Pro Audio" -Name "Priority" -Type DWord -Value 1;
Edit-Registry -Path "$mmcss\Tasks\Pro Audio" -Name "Priority When Yielded" -Type DWord -Value 1;

Edit-Registry -Path "$mmcss\Tasks\Games" -Name "Scheduling Category" -Value "High";

if (!(Test-Laptop)) {
    Edit-Registry -Path $mmcss -Name "NetworkThrottlingIndex" -Type DWord -Value 4294967295;
    Edit-Registry -Path $mmcss -Name "SchedulerPeriod" -Type DWord -Value 1000000;
    Edit-Registry -Path $mmcss -Name "LazyModeTimeout" -Type DWord -Value 25000
}

Write-Host "MMCSS has been successfully configured."
pause
exit