param (
    [string]$MyArgument
)

# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) { Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow; $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -MyArgument {1}" -f $PSCommandPath, $MyArgument; Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs; exit }

# Function to display usage information
function Show-Usage {
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " .\Configure-Shell.ps1 -MyArgument <option>" -ForegroundColor White
    Write-Host ""

    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " - clear_shell             : Clears Start Menu and Taskbar." -ForegroundColor Gray
    Write-Host " - disable_recommendations : Removes 'Recommendation' page on Start Menu." -ForegroundColor Gray
    Write-Host ""

    Write-Host "Example:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " .\Configure-Shell.ps1 -MyArgument disable_recommendations" -ForegroundColor White
    Write-Host " .\Configure-Shell.ps1 -MyArgument clear_shell" -ForegroundColor White
    Write-Host ""
}

switch ($MyArgument) {
    "clear_shell" {
        'StartMenuExperienceHost', 'explorer' | ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.Id -Force } }

        # Layout XML for Start Menu and Taskbar
        $layoutXmlContent = @'
<LayoutModificationTemplate xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" Version="1" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
    <LayoutOptions StartTileGroupCellWidth="6" />
    <DefaultLayoutOverride>
        <StartLayoutCollection>
            <defaultlayout:StartLayout GroupCellWidth="6" />
        </StartLayoutCollection>
    </DefaultLayoutOverride>
    <CustomTaskbarLayoutCollection PinListPlacement="Replace">
        <defaultlayout:TaskbarLayout>
            <taskbar:TaskbarPinList>
                <taskbar:DesktopApp DesktopApplicationLinkPath="%APPDATA%\Microsoft\Windows\Start Menu\Programs\File Explorer.lnk" />
            </taskbar:TaskbarPinList>
        </defaultlayout:TaskbarLayout>
    </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
'@

        # Save the layout XML to system folder
        $startMenuLayoutPath = Join-Path -Path $env:WinDir -ChildPath "StartMenuLayout.xml"
        $layoutXmlContent | Out-File -FilePath $startMenuLayoutPath -Encoding UTF8
        Write-Host "Saved layout to $startMenuLayoutPath" -ForegroundColor Green

        $userProfiles = Get-ChildItem -Path "C:\Users" | Where-Object { $_.PSIsContainer -and $_.Name -notin @("Public", "Default") }

        foreach ($userProfile in $userProfiles) {
            $localAppData = Join-Path -Path $userProfile.FullName -ChildPath "AppData\Local\Microsoft\Windows\Shell"

           if (Test-Path -Path $localAppData) {
                $layoutPath = Join-Path -Path $localAppData -ChildPath "LayoutModification.xml"
                $layoutXmlContent | Out-File -FilePath $layoutPath -Encoding UTF8
                Write-Host "Created LayoutModification.xml" -ForegroundColor Green
            } else {
                Write-Host "Could not find folder: $localAppData" -ForegroundColor Red
            }

            $registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
            if (-not (Test-Path $registryPath)) {
                New-Item -Path $registryPath -Force | Out-Null
            }
            New-ItemProperty -Path $registryPath -Name "StartLayoutFile" -Value $startMenuLayoutPath -PropertyType String -Force
            Write-Host "Registry set for Start Layout" -ForegroundColor Green

            # Clear start.tilegrid registry entries
            $userSid = (Get-WmiObject Win32_UserAccount | Where-Object { $_.Name -eq $userProfile.Name }).SID
            $tileGridPath = "Registry::HKEY_USERS\$userSid\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount"
            if (Test-Path -Path $tileGridPath) {
                Get-ChildItem -Path $tileGridPath | Where-Object { $_.Name -match "start.tilegrid" } | Remove-Item -Recurse -Force
                Write-Host "Cleared start.tilegrid entries for $userSid" -ForegroundColor Green
            } else {
                Write-Host "No start.tilegrid found for $userSid" -ForegroundColor Red
            }

            # Delete unnecessary Start Menu files
            $userAppdata = [System.Environment]::GetFolderPath('LocalApplicationData')
            $packageDir = Get-ChildItem -Path "$userAppdata\Packages" -Directory | Where-Object { $_.Name -match 'Microsoft.Windows.StartMenuExperienceHost' }

            foreach ($d in $packageDir) {
                $files = Get-ChildItem -Path "$($d.FullName)\LocalState" -File | Where-Object { $_.Name -match 'start.*\.bin|start\.bin' }
                foreach ($e in $files) {
                    Remove-Item -Path $e.FullName -Force
                    Write-Host "Deleted file: $($e.FullName)" -ForegroundColor Green
                }
            }

            # Re-register the Start Menu Experience Host app
            Get-AppxPackage -AllUsers Microsoft.Windows.ShellExperienceHost | ForEach-Object {
                Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue
            }

            # Remove ads from the Start Menu for this user
            $startMenuPath = "Registry::HKEY_USERS\$userSid\SOFTWARE\Microsoft\Windows\CurrentVersion\Start"
            if (Test-Path -Path $startMenuPath) {
                Remove-ItemProperty -Path $startMenuPath -Name "Config" -ErrorAction SilentlyContinue
                Write-Host "Removed Start Menu ads for user SID: $userSid" -ForegroundColor Green
            } else {
                Write-Host "No ads registry found for SID: $userSid" -ForegroundColor Red
            }
        }
    }
    
    ## Credits to NTLite Community:
    ## https://bit.ly/4f28mkW
    "disable_recommendations" {
    # First Part
    $recommendations = @'
function Get-ProductKey {
    <#
    .SYNOPSIS
        Retrieves product keys and OS information from a local or remote system/s.
    .DESCRIPTION
        Retrieves the product key and OS information from a local or remote system/s using WMI and/or ProduKey. Attempts to
        decode the product key from the registry, shows product keys from SoftwareLicensingProduct (SLP), and attempts to use
        ProduKey as well. Enables RemoteRegistry service if required.
        Originally based on this script: https://gallery.technet.microsoft.com/scriptcenter/Get-product-keys-of-local-83b4ce97
    .NOTES   
        Author: Matthew Carras
    #>

    Begin {
        [uint32]$HKLM = 2147483650 # HKEY_LOCAL_MACHINE definition for GetStringValue($hklm, $subkey, $value)

        # Define local function to decode binary product key data in registry
        # VBS Source: https://forums.mydigitallife.net/threads/vbs-windows-oem-slp-key.25284/
        function DecodeProductKeyData{
            param(
                [Parameter(Mandatory = $true)]
                [byte[]]$BinaryValuePID
            )
            Begin {
                # for decoding product key
                $KeyOffset = 52
                $CHARS = "BCDFGHJKMPQRTVWXY2346789" # valid characters in product key
                $insert = 'N' # for Win8 or 10+
            } #end Begin
            Process {
                $ProductKey = ''
                $isWin8_or_10 = [math]::floor($BinaryValuePID[66] / 6) -band 1
                $BinaryValuePID[66] = ($BinaryValuePID[66] -band 0xF7) -bor (($isWin8_or_10 -band 2) * 4)
                for ( $i = 24; $i -ge 0; $i-- ) {
                    $Cur = 0
                    for ( $X = $KeyOffset+14; $X -ge $KeyOffset; $X-- ) {
                        $Cur = $Cur * 256
                        $Cur = $BinaryValuePID[$X] + $Cur
                        $BinaryValuePID[$X] = [math]::Floor([double]($Cur/24))
                        $Cur = $Cur % 24
                    } #end for $X
                    $ProductKey = $CHARS[$Cur] + $ProductKey
                } #end for $i
                If ( $isWin8_or_10 -eq 1 ) {
                    $ProductKey = $ProductKey.Insert($Cur+1, $insert)
                }
                $ProductKey = $ProductKey.Substring(1)
                for ($i = 5; $i -le 26; $i += 6) {
                    $ProductKey = $ProductKey.Insert($i, '-')
                }
                $ProductKey
            } #end Process
        } # end DecodeProductKeyData function
    } # end Begin
    Process {
        $ComputerName = [string[]]$Env:ComputerName
        $WmiSplat = @{ ErrorAction = 'Stop' } # Given to all WMI-related commands
        $remoteReg = Get-WmiObject -List -Namespace 'root\default' -ComputerName $ComputerName @WmiSplat | Where-Object {$_.Name -eq "StdRegProv"}
        # Get OEM info from registry
        $regManufacturer = ($remoteReg.GetStringValue($HKLM, 'SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation','Manufacturer')).sValue
        $regModel = ($remoteReg.GetStringValue($HKLM, 'SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation','Model')).sValue
        If ( $regManufacturer -And -Not $OEMManufacturer ) {
            $OEMManufacturer = $regManufacturer
        }
        If ( $regModel -And -Not $OEMModel ) {
            $OEMModel = $regModel
        }
        # Get & Decode Product Keys from registry
        $getvalue = 'DigitalProductId'
        $regpath = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $key = ($remoteReg.GetBinaryValue($HKLM,$regpath,$getvalue)).uValue
        If ( $key ) {
            $ProductKey = DecodeProductKeyData $key
            $ProductName = ($remoteReg.GetStringValue($HKLM,$regpath,'ProductName')).sValue
            If ( -Not $ProductName ) { $ProductName = '' }
        } # end if
        return $ProductKey
    } # end process
} # end function

Stop-Process -Name 'StartMenuExperienceHost' -Force

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Taskbar {
    [DllImport("user32.dll")]
    public static extern int FindWindow(string className, string windowText);
    [DllImport("user32.dll")]
    public static extern int ShowWindow(int hwnd, int command);
    public const int SW_HIDE = 0;
    public const int SW_SHOW = 5;
    public static void HideTaskbar() {
        int hwnd = FindWindow("Shell_TrayWnd", null);
        ShowWindow(hwnd, SW_HIDE);
    }
    public static void ShowTaskbar() {
        int hwnd = FindWindow("Shell_TrayWnd", null);
        ShowWindow(hwnd, SW_SHOW);
    }
}
"@ -Language CSharp

[Taskbar]::HideTaskbar()

if ((Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer') -eq $false) {
    $null = New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
}
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'HideRecommendedSection' -Value 1

$KMS = @{
    Professional = 'W269N-WFGWX-YVC9B-4J6C9-T83GX'
    ProfessionalWorkstation = 'NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J'
    Enterprise = 'NPPR9-FWDCX-D2C8J-H872K-2YT43'
}

$CurrentKey = Get-ProductKey

# Switch to ProfessionalEducation KMS
& cscript.exe /nologo C:\Windows\system32\slmgr.vbs /ipk 6TP4R-GNPTD-KYYHQ-7B7DP-J447Y

Start-Sleep -Seconds 5
[Taskbar]::ShowTaskbar()
Start-Process -FilePath 'C:\Windows\SystemApps\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\StartMenuExperienceHost.exe'
Start-Sleep -Seconds 1

# Use generic KMS key if we're not activated yet
$CurrentSKU = (Get-WindowsEdition -Online).Edition
if ($CurrentKey -eq '') {
    $CurrentKey = $KMS[$CurrentSKU]
}

# Restore original Product Key
& cscript.exe /nologo C:\Windows\system32\slmgr.vbs /ipk $CurrentKey

exit
'@

    $path = "$env:WinDir\RapidScripts\UtilityScripts\Recommendations\HideRecommended.ps1"
    if (-not (Test-Path -Path (Split-Path -Parent $path))) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force
    }
    $recommendations | Set-Content -Path $path -Force


    # Second Part
    $serviceName = "HideRecommendedService"
    $path = "$env:WinDir\RapidScripts\UtilityScripts\Recommendations\HideRecommended.exe"

    if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
        Stop-Service -Name $serviceName -Force
        sc.exe delete $serviceName
    }

    $service = @"
using System;
using System.ServiceProcess;
using System.Diagnostics;
using System.Threading;

public class CustomService : ServiceBase
{
    public CustomService()
    {
        ServiceName = "HideRecommendedService";
        CanStop = true;
        CanPauseAndContinue = false;
        AutoLog = true;
    }

    static void Main()
    {
        ServiceBase.Run(new CustomService());
    }

    protected override void OnStart(string[] args)
    {
        int timeout = 30000;
        int elapsedTime = 0;
        bool logonuiFinished = false;

        while (elapsedTime < timeout)
        {
            if (Process.GetProcessesByName("logonui").Length == 0)
            {
                logonuiFinished = true;
                break;
            }
            Thread.Sleep(100);
            elapsedTime += 100;
        }

        if (!logonuiFinished)
        {
            Process.Start("powershell.exe", "-ExecutionPolicy Bypass -File \"" + @"C:\Windows\RapidScripts\UtilityScripts\Recommendations\HideRecommended.ps1" + "\"");
        }
        else
        {
            string psScriptPath = @"C:\Windows\RapidScripts\UtilityScripts\Recommendations\HideRecommended.ps1";
        
            ProcessStartInfo psStartInfo = new ProcessStartInfo()
            {
                FileName = "powershell.exe",
                Arguments = "-ExecutionPolicy Bypass -File \"" + psScriptPath + "\"",
                CreateNoWindow = true,
                UseShellExecute = false
            };

            var process = Process.Start(psStartInfo);
            process.WaitForExit();

            if (process.ExitCode == 0)
            {
                Thread.Sleep(2000);
                Process.Start(psStartInfo);
            }
        }

        try { Environment.Exit(0); } catch { }
    }

    protected override void OnStop() { }
}
"@

        Add-Type -TypeDefinition $service -Language CSharp -OutputAssembly $path -ReferencedAssemblies 'System.ServiceProcess'
        New-Service -Name $serviceName -BinaryPathName $path -DisplayName "HideRecommendedService" -StartupType Automatic
        Start-Service -Name $serviceName -ErrorAction SilentlyContinue
    }

    default {
        Write-Host "Error: Invalid argument `"$MyArgument`"" -ForegroundColor Red
        Show-Usage
    }
}