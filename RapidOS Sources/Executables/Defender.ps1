param (
    [switch]$enable_av,
    [switch]$disable_av,
    [switch]$delayedRestart,
    [switch]$silent  
)
$interactiveMode = (!$enable_av -and !$disable_av) -and !$silent

$arg = ( 
    ($PSBoundParameters.GetEnumerator() |
        % {
            if ($_.Value -is [switch] -and $_.Value.IsPresent) {"-$($_.Key)"}
            elseif ($_.Value -isnot [switch]) {"-$($_.Key) `"$($_.Value -replace '"','""')`""}
        }
    ) + 
    ($args | % {"`"$($_ -replace '"','""')`""})
) -join ' '

# === Prerequisite ===
if ($silent) {
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Win {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
'@
    $hwnd = [Win]::GetConsoleWindow()
    if ($hwnd -ne [IntPtr]::Zero) {[Win]::ShowWindow($hwnd, 0) *>$null}
}

if (!(whoami /user | findstr "S-1-5-18").Length -gt 0) {
    $exe = if ($PSVersionTable.PSVersion.Major -gt 5) {"pwsh.exe"} else {"powershell.exe"}
    $script = if ($MyInvocation.PSCommandPath) {$MyInvocation.PSCommandPath} else {$PSCommandPath}
    RunAsTI $exe "-EP Bypass -File `"$script`" $arg"
    exit
}

Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public class ConsoleManager {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd,int X,int Y,int nWidth,int nHeight,bool bRepaint);
    [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll")] public static extern bool SetCurrentConsoleFontEx(IntPtr hConsoleOutput,bool bMaximumWindow,ref CONSOLE_FONT_INFO_EX lpConsoleCurrentFontEx);
    [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr hConsoleHandle,out uint lpMode);
    [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr hConsoleHandle,uint dwMode);
    [DllImport("user32.dll",CharSet=CharSet.Auto,SetLastError=true)] public static extern bool GetWindowRect(IntPtr hWnd,out RECT lpRect);

    [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]
    public struct CONSOLE_FONT_INFO_EX {
        public uint cbSize; public uint nFont; public COORD dwFontSize; public int FontFamily; public int FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string FaceName;
    }
    [StructLayout(LayoutKind.Sequential)] public struct COORD {public short X; public short Y;}
    [StructLayout(LayoutKind.Sequential)] public struct RECT {public int Left; public int Top; public int Right; public int Bottom;}

    public const int STD_OUTPUT_HANDLE=-11;
    public static void ResizeWindow(int w,int h){MoveWindow(GetConsoleWindow(),0,0,w,h,true);}
    public static void SetConsoleFont(string name,short size){
        CONSOLE_FONT_INFO_EX info=new CONSOLE_FONT_INFO_EX();
        info.cbSize=(uint)Marshal.SizeOf(typeof(CONSOLE_FONT_INFO_EX));
        info.FaceName=name; info.dwFontSize=new COORD{X=size,Y=size}; info.FontFamily=54; info.FontWeight=400;
        SetCurrentConsoleFontEx(GetStdHandle(STD_OUTPUT_HANDLE),false,ref info);
    }
    public static void QuickEditOFF(){IntPtr hConIn=GetStdHandle(-10); uint m; if(GetConsoleMode(hConIn,out m)) SetConsoleMode(hConIn,(m|0x80U)&~0x40U);}
    public static void QuickEditON(){IntPtr hConIn=GetStdHandle(-10); uint m; if(GetConsoleMode(hConIn,out m)) SetConsoleMode(hConIn,(m|0x40U)&~0x80U);}
}
"@

function AdjustDesign {
    Add-Type -AssemblyName System.Windows.Forms
    $host.PrivateData.WarningBackgroundColor = "Black"
    $host.PrivateData.ErrorBackgroundColor = "Black"
    $host.PrivateData.VerboseBackgroundColor = "Black"
    $host.PrivateData.DebugBackgroundColor = "Black"
    $host.UI.RawUI.BackgroundColor = [ConsoleColor]::Black
    $host.UI.RawUI.ForegroundColor = [ConsoleColor]::White

    [ConsoleManager]::QuickEditOFF()
    [ConsoleManager]::ResizeWindow(850, 550)
    [ConsoleManager]::SetConsoleFont("Consolas", 16)
    $hwnd = [ConsoleManager]::GetConsoleWindow()
    $rect = New-Object ConsoleManager+RECT
    [ConsoleManager]::GetWindowRect($hwnd, [ref]$rect) *>$null

    $sw = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $sh = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
    $ww = $rect.Right - $rect.Left
    $wh = $rect.Bottom - $rect.Top
    $newX = [Math]::Max(0, [Math]::Round(($sw - $ww) / 2))
    $newY = [Math]::Max(0, [Math]::Round(($sh - $wh) / 2))
    [ConsoleManager]::MoveWindow($hwnd, $newX, $newY, $ww, $wh, $true) *>$null
}

function Write-Block {
    [CmdletBinding()]
    param (
        [int]$Indent = 0,
        [string]$Content = '',
        [string]$Title = '',
        [string]$Description = '',
        [int]$TitleWidth = 24,
        [string]$LeftBracket = '[',
        [string]$RightBracket = ']',
        [string]$Separator = ' | ',
        [string]$BracketColor = 'Green',
        [string]$ContentColor = 'White',
        [string]$TextColor = 'White',
        [switch]$NoNewLine
    )
    if (!$Content) {return}

    $spaces = ' ' * $Indent
    $line = if ($Description) {"{0,-$TitleWidth}" -f $Title + $Separator + $Description} else {$Title}
    $prefix = if ($NoNewLine) {"`r$spaces$LeftBracket"} else {"$spaces$LeftBracket"}

    Write-Host -NoNewline $prefix -F $BracketColor
    Write-Host -NoNewline $Content -F $ContentColor
    Write-Host -NoNewline "$RightBracket " -F $BracketColor
    if ($NoNewLine) {Write-Host -NoNewline $line -F $TextColor} else {Write-Host $line -F $TextColor}
}

function DefenderStatus {
    $packageResult = (Get-WindowsPackage -Online | ? {$_.PackageName -like "*AntiBlocker*"})
    $svcResult = (Get-Service -Name WinDefend -EA 0 | Select -ExpandProperty StartType)
    $svcResult = $svcResult -replace "`r`n", ""

    if ($packageResult -or $svcResult -eq "Disabled") {
        $global:status = "disabled"
    } else {
        $global:status = "enabled"
    }
}

function MainMenu {
    cls
    DefenderStatus;
    Write-Host "`n`n`n`n"
    Write-Host "         ______________________________________________________________" -F DarkGray
    Write-Host
    Write-Host "                               Defender Switcher"
    Write-Host
    Write-Host "                                Current Status:" -F Yellow
    if ($status -eq "enabled")
    {Write-Host "                          Windows Defender is ENABLED" -F Green}
else{Write-Host "                          Windows Defender's DISABLED" -F Red}
    Write-Host "               __________________________________________________" -F DarkGray
    Write-Host
    Write-Host "                               Choose an option:" -F Yellow
    Write-Block -Content "1" -Title "Enable Windows Defender" -Description "Restore Protection" -Indent 15 -TitleWidth 24
    Write-Block -Content "2" -Title "Disable Windows Defender" -Description "Turn Off Protection" -Indent 15 -TitleWidth 24
    Write-Block -Content "3" -Title "Information" -Description "Useful Information" -Indent 15 -TitleWidth 24
    Write-Block -Content "4" -Title "Exit" -Description "Close Program" -Indent 15 -TitleWidth 24
    Write-Host
    Write-Host "               __________________________________________________" -F DarkGray
    Write-Host
    Write-Host "              Choose a menu option using your keyboard [1,2,3,4] :" -F Green
    Write-Host
    Write-Host "         ______________________________________________________________" -F DarkGray
    Write-Host

    [ConsoleManager]::QuickEditOFF()
    $host.UI.RawUI.KeyAvailable >$null 2>&1
    $choice = $host.UI.RawUI.ReadKey('NoEcho, IncludeKeyDown').Character
    switch ($choice) {
        '1' {EnableDefender}
        '2' {DisableDefender}
        '3' {ShowInformation}
        '4' {Start-Sleep -Seconds 1; exit}
        default {MainMenu}
    }
}

function ShowInformation {
    cls
    Write-Host "`n`n`n"
    Write-Host "         ______________________________________________________________" -F DarkGray
    Write-Host
    Write-Host "                               Defender Switcher"
    Write-Host
    Write-Host "               Credits:" -F Yellow
    Write-Host
    Write-Block -Content "1" -Title "Achilles Script" -Indent 15
    Write-Block -Content "2" -Title "AveYo's TI elevation" -Indent 15
    Write-Block -Content "3" -Title "MAS-based design" -Indent 15
    Write-Host
    Write-Host "               __________________________________________________" -F DarkGray
    Write-Host
    Write-Host "               Our links:" -F Yellow
    Write-Host
    Write-Block -Content "4" -Title "GitHub" -Indent 15
    Write-Block -Content "5" -Title "Discord" -Indent 15
    Write-Block -Content "6" -Title "Website" -Indent 15
    Write-Host
    Write-Host "               __________________________________________________" -F DarkGray
    Write-Host
    Write-Host "           Choose a menu option using your keyboard [1,2,3,4,5,6,q] :" -F Green
    Write-Host
    Write-Host "         ______________________________________________________________" -F DarkGray
    $choice = ""
    while ($choice -ne 'q') {
        $choice = $host.UI.RawUI.ReadKey('NoEcho, IncludeKeyDown').Character
        switch ($choice) {
            '1' {Start-Process "https://github.com/lostzombie/AchillesScript"}
            '2' {Start-Process "https://github.com/AveYo/LeanAndMean"}
            '3' {Start-Process "https://github.com/massgravel/Microsoft-Activation-Scripts"}
            '4' {Start-Process "https://github.com/instead1337/Defender-Switcher"}
            '5' {Start-Process "https://dsc.gg/rapid-community"}
            '6' {Start-Process "https://rapid-community.ru"}
            'q' {MainMenu}
        }
    }
}

function EnableDefender {
    cls
    DefenderStatus;
    switch ($status) {
        "enabled" {
            Write-Block -Content "INFO" -Title "Defender is already enabled."
        }
        default {
            [ConsoleManager]::QuickEditON()
            if (!$delayedRestart) {
                Write-Block -Content "INFO" -Title "Enabling Defender..."
            }
            Safeboot -Enable $true
        }
    }
    if ($interactiveMode) {
        pause
        MainMenu
    } else {
        exit
    }
}

function DisableDefender {
    cls
    DefenderStatus;
    switch ($status) {
        "disabled" {
            Write-Block -Content "INFO" -Title "Defender is already disabled."
        }
        default {
            [ConsoleManager]::QuickEditON()
            if (!$delayedRestart) {
                Write-Block -Content "INFO" -Title "Disabling Defender..."
            }
            Safeboot -Enable $false
        }
    }
    if ($interactiveMode) {
        pause
        MainMenu
    } else {
        exit
    }
}

function Safeboot {
    param (
        [Parameter(Mandatory=$true)]
        [bool]$Enable
    )

    if ($Enable) {
        $av_param = "-enable_av"
        $verb_ing = "Enabling"
        $verb_ed = "enabled"
        $verb_base = "enable"
    } else {
        $av_param = "-disable_av"
        $verb_ing = "Disabling"
        $verb_ed = "disabled"
        $verb_base = "disable"
    }

    $RapidOS = "HKLM:\SOFTWARE\RapidOS"
    $inSafeMode = Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Option"

    if (!$inSafeMode) {
        New-Item -Path $RapidOS -Force -EA 0 *>$null
        $folder = Join-Path $env:WinDir 'RapidScripts'
        if (!(Test-Path $folder)) {md $folder -Force *>$null}

        $timeout = (cmd /c "bcdedit /enum {bootmgr}" | Select-String -Pattern 'timeout' -SimpleMatch | Select -First 1 | % {($_ -replace '.*timeout\s+','').Trim()}) -join ''
        $displaybootmenu = (cmd /c "bcdedit /enum {bootmgr}" | Select-String -Pattern 'displaybootmenu' -SimpleMatch | Select -First 1 | % {($_ -replace '.*displaybootmenu\s+','').Trim()}) -join ''
        $defaultGuid = (bcdedit /v | Select-String -Pattern 'default\s+({[a-f0-9-]+})' | Select -First 1 | % {$_.Matches[0].Groups[1].Value}) -join ''

        if ($timeout) {Set-ItemProperty -Path $RapidOS -Name "Timeout" -Value $timeout -Force} else {Set-ItemProperty -Path $RapidOS -Name "Timeout" -Value 30 -Force}
        if ($displaybootmenu) {Set-ItemProperty -Path $RapidOS -Name "DisplayBootMenu" -Value $displaybootmenu -Force} else {Set-ItemProperty -Path $RapidOS -Name "DisplayBootMenu" -Value "DELETE" -Force}
        Set-ItemProperty -Path $RapidOS -Name "DefaultGuid" -Value $defaultGuid -Force

        $guid = (cmd /c "bcdedit /copy {current} /d `"Safe Mode"`" 2>$null | Select-String "{[a-f0-9-]+}") -replace ".*{([a-f0-9-]+)}.*", '{${1}}'
        if (!$guid) {
            $guid = (cmd /c "bcdedit /copy {default} /d `"Safe Mode"`" 2>$null | Select-String "{[a-f0-9-]+}") -replace ".*{([a-f0-9-]+)}.*", '{${1}}'
            if (!$guid) {
                Write-Block -Content "ERROR" -Title "Safe boot configuration failed." -ContentColor "Red"
                if ($interactiveMode) {pause; MainMenu} else {exit}
            }
        } else {
            Set-ItemProperty -Path $RapidOS -Name "SafeBootGuid" -Value $guid -Force
        }

        bcdedit /set $guid safeboot minimal *>$null
        if ($LASTEXITCODE -ne 0) {bcdedit /set safeboot minimal *>$null}
        if ($LASTEXITCODE -ne 0) {
            Write-Block -Content "ERROR" -Title "Failed to enable safe boot." -ContentColor "Red"
            if ($interactiveMode) {pause; MainMenu} else {exit}
        }

        bcdedit /set $guid bootmenupolicy Legacy *>$null
        bcdedit /set $guid hypervisorlaunchtype off *>$null
        bcdedit /default $guid *>$null

        bcdedit /timeout 2 *>$null
        bcdedit /set {bootmgr} displaybootmenu Yes *>$null

        $startupPath = Join-Path $env:WinDir 'RapidScripts\startup.bat'
        Set-Content -Path $startupPath -Value "sc start RapidOS" -Force

        $winlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
        $originalUserinit = (Get-ItemProperty -Path $winlogonPath -Name 'Userinit' -EA 0).Userinit
        Set-ItemProperty -Path $RapidOS -Name 'OriginalUserinit' -Value $originalUserinit -Force

        $newUserinit = "$originalUserinit,$startupPath"
        Set-ItemProperty -Path $winlogonPath -Name 'Userinit' -Value $newUserinit -Force

        $serviceName = "RapidOS"
        $assemblyPath = Join-Path $env:WinDir 'RapidScripts\RapidOS.exe'

        $service = @'
using System; using System.Runtime.InteropServices; using System.ServiceProcess;
namespace RapidOS
{
    public class Service : ServiceBase
    {
        public Service() {ServiceName = "RapidOS"; AutoLog = true;}
        protected override void OnStart(string[] args) {while (System.Diagnostics.Process.GetProcessesByName("logonui").Length == 0) System.Threading.Thread.Sleep(500); ShellExecuteW(IntPtr.Zero, "open", "powershell.exe", @"{{path}}", null, 0); Stop();}
        protected override void OnStop() {}
        public static void Main() {ServiceBase.Run(new Service());}

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        static extern IntPtr ShellExecuteW(IntPtr hwnd, string op, string file, string param, string dir, int show);
    }
}
'@

        $scriptPath = $PSCommandPath
        $path = ("-EP Bypass -File ""$scriptPath"" $av_param").Replace('"', '""')
        $code = $service -replace '{{path}}', $path

        Add-Type -TypeDefinition $code -Language CSharp -OutputAssembly $assemblyPath -ReferencedAssemblies 'System', 'System.ServiceProcess'

        sc.exe delete $serviceName *>$null
        sc.exe create $serviceName type= own start= auto error= ignore obj= "LocalSystem" binPath= "$assemblyPath" *>$null

        reg add "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\$serviceName" /ve /t REG_SZ /d "Service" /f *>$null

        if ($interactiveMode -and !$delayedRestart) {
            Write-Block -Content "INFO" -Title "Rebooting in 5 sec..."
            Start-Sleep -s 5
        }

        if (!$delayedRestart) {
            shutdown /r /f /t 0
        } else {
            Write-Block -Content "INFO" -Title "$verb_ing Microsoft Defender will take effect after restart."
            Start-Sleep -s 2
            if ($interactiveMode) {pause; MainMenu} else {exit}
        }
    }
    else {
        bcdedit /deletevalue safeboot *>$null

        sc.exe delete RapidOS *>$null
        del "$env:WinDir\RapidScripts\RapidOS.exe" -Force
        del "$env:WinDir\RapidScripts\startup.bat" -Force

        if (Test-Path $RapidOS) {
            $backup = Get-ItemProperty -Path $RapidOS

            bcdedit /timeout $backup.Timeout *>$null
            bcdedit /default $backup.DefaultGuid *>$null
            bcdedit /delete $backup.SafeBootGuid /f *>$null
            if ($backup.DisplayBootMenu -eq "DELETE") {
                bcdedit /deletevalue {bootmgr} displaybootmenu *>$null
            } else {
                bcdedit /set {bootmgr} displaybootmenu $backup.DisplayBootMenu *>$null
            }
            if ($backup.OriginalUserinit) {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name 'Userinit' -Value $backup.OriginalUserinit -Force
            } else {
                Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name 'Userinit' -Value "$($env:WinDir)\system32\userinit.exe," -Force
            }

            del -Path $RapidOS -Recurse -Force *>$null
        } else {
            bcdedit /timeout 15 *>$null
            bcdedit /deletevalue {bootmgr} displaybootmenu *>$null
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name 'Userinit' -Value "$($env:WinDir)\system32\userinit.exe," -Force
        }
        
        if ($Enable) {
            ProcessDefender -Enable $true
        } else {
            ProcessDefender -Disable $true
        }

        DefenderStatus;
        switch ($status) {
            "$verb_ed" {
                Write-Block -Content "INFO" -Title "Defender has been $verb_ed."
            }
            default {
                Write-Block -Content "ERROR" -Title "Failed to $verb_base Defender." -ContentColor "Red"
            }
        }

        Write-Block -Content "INFO" -Title "Rebooting..."
        Start-Sleep -s 1
        shutdown /r /f /t 0
    }
}

function ProcessDefender {
    param ([switch]$Enable, [switch]$Disable)

    # ==============================
    # Configuration
    # ==============================
    $config = [PSCustomObject]@{
        defenderPath = Join-Path $env:ProgramFiles 'Windows Defender'
        svc = 'wscsvc'
        proc = 'MsMpEng.exe'
        exe = 'MpCmdRun.exe'
        backupExe = 'off.exe'
        services = @{
            WinDefend = 2
            MDCoreSvc = 2
            WdNisSvc = 3
            Sense = 3
            webthreatdefsvc = 3
            webthreatdefusersvc = 2
            WdNisDrv = 3
            WdBoot = 0
            WdDevFlt = 1
            WdFilter = 0
        }
        regSettings = @{
            ServiceKeepAlive = 0
            PreviousRunningMode = 0
            IsServiceRunning = 0
            DisableAntiSpyware = 1
            DisableAntiVirus = 1
            PassiveMode = 1
        }
    }

    if ($Enable) {
        Stop-Service $config.svc -Force -EA 0
        taskkill /f /im $config.backupExe *>$null
        taskkill /f /im $config.exe *>$null
        taskkill /f /im $config.proc *>$null

        $svcImagePath = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend" -Name ImagePath -EA 0).ImagePath.Trim('"')
        $svcPath = Split-Path $svcImagePath
        if (Test-Path (Join-Path $svcPath $config.backupExe)) {
            Rename-Item (Join-Path $svcPath $config.backupExe) $config.exe -Force -EA 0
        }

        foreach ($svc in $config.services.GetEnumerator()) {
            $regKey = "HKLM\SYSTEM\CurrentControlSet\Services\$($svc.Key)"
            reg add $regKey /v "Start" /t REG_DWORD /d $($svc.Value) /f *>$null
        }

        foreach ($entry in $config.regSettings.GetEnumerator()) {
            reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v $($entry.Key) /f *>$null
        }

        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" /v "DisableNotifications" /f *>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Virus and threat protection" /v "UILockdown" /f *>$null

        reg add "HKLM\SYSTEM\CurrentControlSet\Services\WdFilter\Instances\WdFilter Instance" /v Altitude /t REG_SZ /d 328010 /f *>$null
        reg add "HKLM\SOFTWARE\Microsoft\Windows Defender\Features" /v "TamperProtection" /t REG_DWORD /d 1 /f *>$null
        reg add "HKLM\SOFTWARE\Microsoft\Windows Defender\Features" /v "TamperProtectionSource" /t REG_DWORD /d 5 /f *>$null

        reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "SmartScreenEnabled" /f *>$null
        reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "SmartScreenEnabled" /f *>$null
        reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\smartscreen.exe" /v "Debugger" /f *>$null

        reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\SecurityHealthService.exe\PerfOptions" /f *>$null
        reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\SecurityHealthSystray.exe\PerfOptions" /f *>$null

        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v SecurityHealth /t REG_EXPAND_SZ /d "%WinDir%\System32\SecurityHealthSystray.exe" /f *>$null
    }

    if ($Disable) {
        Stop-Service $config.svc -Force -EA 0
        taskkill /f /im $config.backupExe *>$null
        taskkill /f /im $config.exe *>$null
        taskkill /f /im $config.proc *>$null

        reg delete "HKLM\SYSTEM\CurrentControlSet\Services\WdFilter\Instances\WdFilter Instance" /v "Altitude" /f *>$null
        reg add "HKLM\SOFTWARE\Microsoft\Windows Defender\Features" /v "TamperProtection" /t REG_DWORD /d 4 /f *>$null
        reg add "HKLM\SOFTWARE\Microsoft\Windows Defender\Features" /v "TamperProtectionSource" /t REG_DWORD /d 2 /f *>$null

        foreach ($entry in $config.regSettings.GetEnumerator()) {
            reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v $entry.Key /t REG_DWORD /d $entry.Value /f *>$null
        }

        $svcImagePath = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend" -Name ImagePath -EA 0).ImagePath.Trim('"')
        $svcPath = Split-Path $svcImagePath
        if (Test-Path (Join-Path $svcPath $config.exe)) {
            Rename-Item (Join-Path $svcPath $config.exe) $config.backupExe -Force -EA 0
        }

        foreach ($svc in $config.services.GetEnumerator()) {
            $regKey = "HKLM\SYSTEM\CurrentControlSet\Services\$($svc.Key)"
            reg add $regKey /v "Start" /t REG_DWORD /d 4 /f *>$null
        }

        reg delete "HKLM\SOFTWARE\Microsoft\Windows Security Health\State\Persist" /f *>$null
        del (Join-Path $env:ProgramData 'Microsoft\Windows Defender\Scans\mpenginedb.db') -Force -EA 0 *>$null
        del (Join-Path $env:ProgramData 'Microsoft\Windows Defender\Scans\History\Service') -Recurse -Force -EA 0 *>$null

        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v "SmartScreenEnabled" /t REG_SZ /d "Off" /f *>$null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "SmartScreenEnabled" /t REG_DWORD /d 0 /f *>$null
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\smartscreen.exe" /v "Debugger" /t REG_SZ /d "%WinDir%\System32\taskkill.exe" /f *>$null

        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" /v "DisableNotifications" /t REG_DWORD /d 1 /f *>$null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Virus and threat protection" /v "UILockdown" /t REG_DWORD /d 1 /f *>$null

        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\SecurityHealthService.exe\PerfOptions" /v "CpuPriorityClass" /t REG_SZ /d "1" /f *>$null
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\SecurityHealthSystray.exe\PerfOptions" /v "CpuPriorityClass" /t REG_SZ /d "1" /f *>$null

        reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v SecurityHealth /f *>$null
    }
}

if ($enable_av) {EnableDefender}
elseif ($disable_av) {DisableDefender}
elseif ($interactiveMode) {AdjustDesign; MainMenu}