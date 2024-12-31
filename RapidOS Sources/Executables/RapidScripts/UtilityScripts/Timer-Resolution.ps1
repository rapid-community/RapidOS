param (
    [int]$resolution = 6000
)

# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) { 
    Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -resolution {1}" -f $PSCommandPath, $resolution
    Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs
    exit 
}

# Enable Global Timer Resolution
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "GlobalTimerResolutionRequests" -Value 1 -Force

# Task details and XML
$taskName = "SetTimerResolution"
$taskDescription = "Adjusts system timer resolution to $resolution"
$executablePath = "$env:WinDir\RapidScripts\SetTimerResolution.exe"
$arguments = "--resolution $resolution --no-console"

# Create task XML
$taskXML = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>$(Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fff")</Date>
    <Author>RapidOS</Author>
    <Description>$taskDescription</Description>
    <URI>\Set Timer Resolution</URI>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="SystemPrincipal">
      <UserId>S-1-5-18</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions>
    <Exec>
      <Command>$executablePath</Command>
      <Arguments>$arguments</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# Save XML to file
$taskXmlPath = "$env:WinDir\RapidScripts\TimerResolutionTask.xml"
$taskXML | Out-File -FilePath $taskXmlPath -Encoding UTF8

$ErrorActionPreference = 'SilentlyContinue'

Register-ScheduledTask -Xml (Get-Content -Path $taskXmlPath | Out-String) -TaskName $taskName > $null 2>&1

Write-Host "Scheduled Task '$taskName' has been created"