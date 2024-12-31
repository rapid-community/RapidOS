param (
    [string[]]$MyArgument
)

# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) { Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow; $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -MyArgument {1}" -f $PSCommandPath, $MyArgument; Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs; exit }

# Function to set registry values
function Set-RegistryValue {
    param (
        [string]$Path,
        [string]$Name,
        [string]$Type,
        [string]$Value
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Type $Type -Value $Value -Force
}

function Set-DriveConfiguration {
    # Check if the system has an SSD
    $systemDriveLetter = $env:SystemDrive.Substring(0, 1)
    $diskNumber = (Get-Partition -DriveLetter $systemDriveLetter).DiskNumber
    $serialNumber = (Get-Disk -Number $diskNumber).SerialNumber.TrimStart()
    $mediaType = (Get-PhysicalDisk -SerialNumber $serialNumber).MediaType

    # Apply configurations if the drive is an SSD
    if ($mediaType -eq 'SSD') {
        Write-Host "Configuring system settings for SSD..."

        # Disable ReadyBoost (BSOD)
        # Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\rdyboost" -Name "Start" -Value 4 -Type DWord
        
        # Disable SysMain (Superfetch)
        # Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SysMain" -Name "Start" -Value 4 -Type DWord

        # Enable TRIM support for SSDs
        fsutil behavior set disabledeletenotify 0

        # Disable tasks related to HDD
        Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Data Integrity Scan\" -TaskName "Data Integrity Scan"

        Write-Host "Configuration for SSD completed."
    } else {
        Write-Host "No SSD drive found. Proceeding with other configurations."
    }

    # Optimize Drives
    Get-Volume -DriveLetter C | Optimize-Volume -NormalPriority -Verbose

    # Set SysMain service to "Below Normal" for all drives
    $sysMainService = Get-CimInstance -ClassName Win32_Service -Filter "Name='SysMain'"
    if ($null -ne $sysMainService) {
        $process = Get-Process -Id $sysMainService.ProcessId
        $process.PriorityClass = "BelowNormal"
        Write-Host "SysMain priority set to Below Normal."
    }
}

function Remove-WindowsInstallationAssistant {
    $installerPath = "$env:ProgramFiles(x86)\WindowsInstallationAssistant\Windows10UpgraderApp.exe"
    $installerDir = "$env:ProgramFiles(x86)\WindowsInstallationAssistant"

    Write-Host "Removing Windows Installation Assistant..."

    # Uninstall and remove directory
    if (Test-Path $installerPath) {
        Start-Process -FilePath $installerPath -ArgumentList "/SunValley /ForceUninstall" -NoNewWindow -RedirectStandardOutput "$null" -RedirectStandardError "$null" -Wait
        Remove-Item -Path $installerDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removal successful."
    } else {
        Write-Host "Windows Installation Assistant not found."
    }
}

function Create-Shortcuts {
    $appPath = "$env:SystemRoot\RapidOS Toolbox"
    $shortcutName = "RapidOS Toolbox.lnk"

    function New-Shortcut {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string]$Source,
            [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string]$Destination,
            [ValidateNotNullOrEmpty()][string]$WorkingDir,
            [ValidateNotNullOrEmpty()][string]$Arguments,
            [ValidateNotNullOrEmpty()][string]$Icon,
            [switch]$IfExist
        )

        if (!(Test-Path $Source) -and !(Get-Command $Source -EA 0)) {
            throw "Source '$Source' not found."
        }

        if ($IfExist -and (Test-Path $Destination)) {
            return
        }

        if (-not $WorkingDir) {
            try {
                $WorkingDir = Split-Path $Source
            } catch {
                $WorkingDir = [Environment]::GetFolderPath('System')
            }
        }

        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($Destination)
        $Shortcut.TargetPath = $Source
        $Shortcut.WorkingDirectory = $WorkingDir
        if ($Icon) { $Shortcut.IconLocation = $Icon }
        if ($Arguments) { $Shortcut.Arguments = $Arguments }
        $Shortcut.Save()
    }

    $currentUserDesktop = "$env:USERPROFILE\Desktop"
    $currentUserShortcut = Join-Path $currentUserDesktop $shortcutName

    if (!(Test-Path $currentUserShortcut)) {
        New-Shortcut -Source $appPath -Destination $currentUserShortcut
    }

    $allUsers = Get-ChildItem "C:\Users" | Where-Object { $_.PSIsContainer -and $_.Name -ne "Public" -and $_.Name -ne "Default" }
    foreach ($user in $allUsers) {
        $userDesktop = Join-Path $user.FullName "Desktop"
        if (Test-Path $userDesktop) {
            Write-Host "Creating shortcut for $($user.Name)..."
            if (!(Test-Path (Join-Path $userDesktop $shortcutName))) {
                Copy-Item $currentUserShortcut -Destination $userDesktop -Force
            }
        } else {
            Write-Host "Desktop not found for $($user.Name)."
        }
    }

    $commonStartMenu = [Environment]::GetFolderPath('CommonStartMenu')
    $commonShortcut = Join-Path $commonStartMenu "Programs\$shortcutName"
    if (!(Test-Path $commonShortcut)) {
        Copy-Item $currentUserShortcut -Destination $commonShortcut -Force
    }
}

function Remove-NewOutlook {
    New-Item -Path "$env:APPDATA\NewOutlook" -ItemType Directory -Force | Out-Null
    $manifestPath = switch ($env:PROCESSOR_ARCHITECTURE) { 
        "AMD64" { "RapidResources\AppxManifest.xml" }; 
        "x86" { "RapidResources\AppxManifestx86.xml" }; 
        "ARM64" { "RapidResources\AppxManifest-ARM64.xml" }; 
    }
    Copy-Item $manifestPath -Destination "$env:APPDATA\NewOutlook\AppxManifest.xml" -Force
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Type DWORD -Value 1 -Force
    Get-AppxPackage -AllUsers Microsoft.OutlookForWindows | Remove-AppxPackage -AllUsers
    Add-AppxPackage -Register "$env:APPDATA\NewOutlook\AppxManifest.xml"
}

function Optimize-SvchostProcesses {
    # Groups or splits svchost.exe processes based on the amount of physical memory in the system to optimize performance
    $ram = (Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1kb
    Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Type DWord -Value $ram -Force

    $autoLoggerDir = "$env:PROGRAMDATA\Microsoft\Diagnosis\ETLLogs\AutoLogger"
    If (Test-Path "$autoLoggerDir\AutoLogger-Diagtrack-Listener.etl") {
        Remove-Item "$autoLoggerDir\AutoLogger-Diagtrack-Listener.etl"
    }

    $icaclsCommand = "icacls `"$autoLoggerDir`" /deny SYSTEM:`"(OI)(CI)F`""
    Invoke-Expression $icaclsCommand | Out-Null
}

function Configure-Autologgers {
    Write-Host "Configuring autologgers"

    $autologgers = @(
        'Circular Kernel Context Logger',
        'CloudExperienceHostOobe',
        'Diagtrack-Listener',
        'LwtNetLog',
        'Microsoft-Windows-Rdp-Graphics-RdpIdd-Trace',
        'NtfsLog',
        'RdrLog',
        'SpoolerLogger',
        'UBPM',
        'WiFiSession'
    )

    foreach ($logger in $autologgers) {
        $regPath = "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$logger"
        try {
            New-Item -Path $regPath -Force | Out-Null
            [Microsoft.Win32.Registry]::SetValue($regPath, "Start", 0, [Microsoft.Win32.RegistryValueKind]::DWord)
        } catch {
            Write-Host "Failed to set key for: $logger"
        }
    }     
  
    # Fix Task Manager not responding when exiting
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DiagLog" /v Start /t REG_DWORD /d 1 /f
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WdiContextLog" /v Start /t REG_DWORD /d 1 /f

    Write-Host "Autologgers setup complete."
}

function Set-VisualEffects {
    Write-Host "Configuring visual effects"
    $TotalMemoryGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)

    # Show icons with text
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'IconsOnly' -Type DWORD -Value 0  

    # Enable listview shadows
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ListviewShadow' -Type DWORD -Value 1  

    # Enable full window drag
    Set-RegistryValue -Path 'HKCU:\Control Panel\Desktop' -Name 'DragFullWindows' -Type DWORD -Value 1  

    # Disable Aero Peek
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'EnableAeroPeek' -Type DWORD -Value 0  

    # Enable ClearType font smoothing
    Set-RegistryValue -Path 'HKCU:\Control Panel\Desktop' -Name 'FontSmoothing' -Type DWORD -Value 2  

    # Set visual effects and performance balance
    reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f  

    # Set balanced visual effects
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Type DWORD -Value 3  

    if ($TotalMemoryGB -lt 8) {
        Write-Host "System has less than 8GB of RAM. Applying performance settings."

        # Disable taskbar animations
        Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAnimations' -Type DWORD -Value 0  
        # Disable thumbnail previews
        Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'AlwaysHibernateThumbnails' -Type DWORD -Value 0  
        # Disable window minimize animations
        Set-RegistryValue -Path 'HKCU:\Control Panel\Desktop' -Name 'MinAnimate' -Type DWORD -Value 0  

    } else {
        Write-Host "System has 8GB or more RAM. Applying aesthetics settings."

        # Enable taskbar animations
        Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAnimations' -Type DWORD -Value 1  
        # Enable thumbnail previews
        Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name 'AlwaysHibernateThumbnails' -Type DWORD -Value 1  
        # Enable window minimize animations
        Set-RegistryValue -Path 'HKCU:\Control Panel\Desktop' -Name 'MinAnimate' -Type DWORD -Value 1  

    }

    Write-Host "Visual effects applied."
}

function Set-DeprovisionedApps {
    Write-Host "Setting deprovisioned apps"

    $keys = @(
        'Microsoft.Advertising.Xaml_8wekyb3d8bbwe',
        'Microsoft.WindowsAlarms_8wekyb3d8bbwe',
        'Microsoft.549981C3F5F10_8wekyb3d8bbwe',
        'Microsoft.BingNews_8wekyb3d8bbwe',
        'Microsoft.BingWeather_8wekyb3d8bbwe',
        'Microsoft.WindowsCalculator_8wekyb3d8bbwe',
        'Microsoft.WindowsCamera_8wekyb3d8bbwe',
        'clipchamp.clipchamp_yxz26nhyzhsrt',
        'Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy',
        'Microsoft.Windows.DevHome_8wekyb3d8bbwe',
        'Microsoft.ECApp_8wekyb3d8bbwe',
        'Microsoft.MicrosoftEdge.Stable_8wekyb3d8bbwe',
        'Microsoft.MicrosoftEdge_8wekyb3d8bbwe',
        'Microsoft.MicrosoftEdgeDevToolsClient_8wekyb3d8bbwe',
        'MicrosoftCorporationII.MicrosoftFamily_8wekyb3d8bbwe',
        'Microsoft.WindowsFeedbackHub_8wekyb3d8bbwe',
        'Microsoft.GetHelp_8wekyb3d8bbwe',
        'Microsoft.Getstarted_8wekyb3d8bbwe',
        'MicrosoftCorporationII.MailforSurfaceHub_8wekyb3d8bbwe',
        'microsoft.windowscommunicationsapps_8wekyb3d8bbwe',
        'Microsoft.WindowsMaps_8wekyb3d8bbwe',
        'Microsoft.MicrosoftPowerBIForWindows_8wekyb3d8bbwe',
        'Microsoft.MicrosoftTeamsforSurfaceHub_8wekyb3d8bbwe',
        'MSTeams_8wekyb3d8bbwe',
        'Microsoft.MixedReality.Portal_8wekyb3d8bbwe',
        'Microsoft.WindowsNotepad_8wekyb3d8bbwe',
        'Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe',
        'Microsoft.Office.OneNote_8wekyb3d8bbwe',
        'Microsoft.Office.Excel_8wekyb3d8bbwe',
        'Microsoft.Office.PowerPoint_8wekyb3d8bbwe',
        'Microsoft.Office.Word_8wekyb3d8bbwe',
        'Microsoft.OutlookForWindows_8wekyb3d8bbwe',
        'Microsoft.MSPaint_8wekyb3d8bbwe',
        'Microsoft.Paint_8wekyb3d8bbwe',
        'Microsoft.People_8wekyb3d8bbwe',
        'Microsoft.Windows.PeopleExperienceHost_cw5n1h2txyewy',
        'Microsoft.Windows.Photos_8wekyb3d8bbwe',
        'Microsoft.PowerAutomateDesktop_8wekyb3d8bbwe',
        'MicrosoftCorporationII.QuickAssist_8wekyb3d8bbwe',
        'microsoft.microsoftskydrive_8wekyb3d8bbwe',
        'Microsoft.SkypeApp_kzf8qxf38zg5c',
        'Microsoft.Windows.Apprep.ChxApp_cw5n1h2txyewy',
        'Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe',
        'Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe',
        'Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe',
        'Microsoft.Windows.SecureAssessmentBrowser_cw5n1h2txyewy',
        'Microsoft.Todos_8wekyb3d8bbwe',
        'MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy',
        'Microsoft.Whiteboard_8wekyb3d8bbwe',
        'Microsoft.ZuneMusic_8wekyb3d8bbwe',
        'Microsoft.ZuneVideo_8wekyb3d8bbwe',
        'Microsoft.Microsoft3DViewer_8wekyb3d8bbwe'
    )

    foreach ($key in $keys) {
        $regPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\$key"
        try {
            [Microsoft.Win32.Registry]::SetValue($regPath, "", 0, [Microsoft.Win32.RegistryValueKind]::DWord)
        } catch {
            Write-Host "Failed to set key for: $key"
        }
    }

    Write-Host "Deprovisioned apps setup complete."
}

# Function to display usage information
function Show-Usage {
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " .\MultiTool.ps1 -MyArgument <option>" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " - configure_drives              : Configure system settings for all drives" -ForegroundColor Gray
    Write-Host " - remove_installation_assistant : Remove Windows Installation Assistant if present" -ForegroundColor Gray
    Write-Host " - optimize_svchost              : Optimize svchost processes based on system RAM" -ForegroundColor Gray
    Write-Host " - set_visualeffects             : Set aesthetic or performance visual effects based on RAM" -ForegroundColor Gray
    Write-Host " - set_deprovisioned_apps        : Set registry keys to deprovision pre-installed apps" -ForegroundColor Gray
    Write-Host " - rapidos_toolbox               : Makes RapidOS Toolbox shortcut on desktop and start menu" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Example:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " .\MultiTool.ps1 -MyArgument remove_installation_assistant" -ForegroundColor White
    Write-Host " .\MultiTool.ps1 -MyArgument optimize_svchost, configure_drives" -ForegroundColor White
    Write-Host ""
}

# Check if no arguments were provided
if (-not $MyArgument) {
    Write-Host "Error: No arguments provided." -ForegroundColor Red
    Write-Host ""
    Show-Usage
}

# Function call based on the argument
foreach ($arg in $MyArgument) {
    switch ($arg) {
        "configure_drives" { Set-DriveConfiguration }
        "remove_installation_assistant" { Remove-WindowsInstallationAssistant }
        "optimize_svchost" { Optimize-SvchostProcesses }
        "configure_autologgers" { Configure-Autologgers }
        "set_visualeffects" { Set-VisualEffects }
        "set_deprovisioned_apps" { Set-DeprovisionedApps }
        "rapidos_toolbox" { Create-Shortcuts }
        "remove_outlook" { Remove-NewOutlook }

        default {
            Write-Host "Error: Invalid argument `"$arg`"" -ForegroundColor Red
            Write-Host ""
            Show-Usage
        }
    }
}