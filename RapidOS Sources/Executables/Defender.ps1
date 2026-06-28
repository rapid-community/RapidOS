param (
    [switch]$enable_av,
    [switch]$disable_av,
    [switch]$delayedrestart,
    [switch]$silent,
    [switch]$skipbackup,
    [switch]$forcebackup
)

$interactive = (!$enable_av -and !$disable_av) -and !$silent

# === Prerequisite ===
& "$env:SystemRoot\RapidScripts\EnvSetup.ps1"

RunAsTI

if ($silent) {
    Add-Type @'
    using System;
    using System.Runtime.InteropServices;
    public static class Silent {
        [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    }
'@
    $hwnd = [Silent]::GetConsoleWindow()
    if ($hwnd -ne [IntPtr]::Zero) {[Silent]::ShowWindow($hwnd, 0) *>$null}
}

$global:safemode = Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Option'
if (!$silent -and !$global:safemode) {
    Add-Type @"
    using System; using System.Runtime.InteropServices;
    public class ConsoleManager {
        [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
        [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
        [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
        public static void QuickEditOFF() {IntPtr hConIn = GetStdHandle(-10); uint m; if(GetConsoleMode(hConIn, out m)) SetConsoleMode(hConIn, (m | 0x80U) & ~0x40U);}
        public static void QuickEditON() {IntPtr hConIn = GetStdHandle(-10); uint m; if(GetConsoleMode(hConIn, out m)) SetConsoleMode(hConIn, (m | 0x40U) & ~0x80U);}
    }
"@
    function QuickEditOFF {[ConsoleManager]::QuickEditOFF()}
    function QuickEditON {[ConsoleManager]::QuickEditON()}
} else {function QuickEditOFF {}; function QuickEditON {}}

function AdjustDesign {
    Add-Type @"
    using System; using System.Runtime.InteropServices;
    public class ConsoleDesign {
        [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
        [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int nStdHandle);
        [DllImport("kernel32.dll")] public static extern bool SetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFO_EX lpConsoleCurrentFontEx);
        [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

        [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
        public struct CONSOLE_FONT_INFO_EX {
            public uint cbSize; public uint nFont; public COORD dwFontSize; public int FontFamily; public int FontWeight;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string FaceName;
        }
        [StructLayout(LayoutKind.Sequential)] public struct COORD {public short X; public short Y;}
        [StructLayout(LayoutKind.Sequential)] public struct RECT {public int Left; public int Top; public int Right; public int Bottom;}

        public const int STD_OUTPUT_HANDLE = -11;
        public static void ResizeWindow(int w, int h) {MoveWindow(GetConsoleWindow(), 0, 0, w, h, true);}
        public static void SetConsoleFont(string name, short size) {
            CONSOLE_FONT_INFO_EX info = new CONSOLE_FONT_INFO_EX();
            info.cbSize = (uint)Marshal.SizeOf(typeof(CONSOLE_FONT_INFO_EX));
            info.FaceName = name; info.dwFontSize = new COORD {X = size, Y = size}; info.FontFamily = 54; info.FontWeight = 400;
            SetCurrentConsoleFontEx(GetStdHandle(STD_OUTPUT_HANDLE), false, ref info);
        }
    }
"@
    Add-Type -AssemblyName System.Windows.Forms
    $host.PrivateData.WarningBackgroundColor = "Black"
    $host.PrivateData.ErrorBackgroundColor = "Black"
    $host.PrivateData.VerboseBackgroundColor = "Black"
    $host.PrivateData.DebugBackgroundColor = "Black"
    $host.UI.RawUI.BackgroundColor = [ConsoleColor]::Black
    $host.UI.RawUI.ForegroundColor = [ConsoleColor]::White

    QuickEditOFF
    [ConsoleDesign]::ResizeWindow(850, 550)
    [ConsoleDesign]::SetConsoleFont("Consolas", 16)
    $hwnd = [ConsoleDesign]::GetConsoleWindow()
    $rect = [ConsoleDesign+RECT]::new()
    [ConsoleDesign]::GetWindowRect($hwnd, [ref]$rect) *>$null

    $sw = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
    $sh = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
    $ww = $rect.Right - $rect.Left
    $wh = $rect.Bottom - $rect.Top
    $newX = [Math]::Max(0, [Math]::Round(($sw - $ww) / 2))
    $newY = [Math]::Max(0, [Math]::Round(($sh - $wh) / 2))
    [ConsoleDesign]::MoveWindow($hwnd, $newX, $newY, $ww, $wh, $true) *>$null
}

function Write-Block {
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
        [switch]$Prompt
    )
    if (!$Content -and !$Prompt) {return}
    if ($Prompt) {
        if (!$Content) {$Content = '?'}
        if (!$PSBoundParameters.ContainsKey('BracketColor')) {$BracketColor = 'Yellow'}
        if (!$PSBoundParameters.ContainsKey('TextColor')) {$TextColor = $BracketColor}
        if (!$PSBoundParameters.ContainsKey('Indent')) {$Indent = 2}
        Write-Host
    }

    $spaces = ' ' * $Indent
    $line = if ($Description) {"{0,-$TitleWidth}" -f $Title + $Separator + $Description} else {$Title}

    $ansi = @{
        'Black'=30;'DarkBlue'=34;'DarkGreen'=32;'DarkCyan'=36;'DarkRed'=31;'DarkMagenta'=35;'DarkYellow'=33;'Gray'=37
        'DarkGray'=90;'Blue'=94;'Green'=92;'Cyan'=96;'Red'=91;'Magenta'=95;'Yellow'=93;'White'=97
    }
    $e = [char]27
    $cB = if ($ansi.ContainsKey($BracketColor)) {"$e[$($ansi[$BracketColor])m"} else {"$e[97m"}
    $cC = if ($ansi.ContainsKey($ContentColor)) {"$e[$($ansi[$ContentColor])m"} else {"$e[97m"}
    $cT = if ($ansi.ContainsKey($TextColor)) {"$e[$($ansi[$TextColor])m"} else {"$e[97m"}
    $rst = "$e[0m"

    Write-Host "$spaces$cB$LeftBracket$cC$Content$cB$RightBracket $cT$line$rst"
    if (!$Prompt) {return}

    Write-Host "$spaces    ${e}[90mPress ${e}[92m[Y]${e}[90m/${e}[91m[N]${e}[90m: ${e}[0m" -NoNewline
    $host.UI.RawUI.FlushInputBuffer()
    while ($true) {
        if ($host.UI.RawUI.KeyAvailable) {
            $k = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            if ($k.VirtualKeyCode -eq 0x59) {Write-Host 'Yes' -F Green; Write-Host ''; return $true}
            if ($k.VirtualKeyCode -eq 0x4E) {Write-Host 'No' -F Red; Write-Host ''; return $false}
        }
        Start-Sleep -m 50
    }
}

function Init-Log {
    $reg = 'HKLM:\SOFTWARE\RapidOS\Defender'
    $dir = (Get-ItemProperty $reg -Name 'CurrentLogDir' -EA 0).CurrentLogDir
    if (!$dir -or !(Test-Path $dir)) {
        $dir = "$env:SystemRoot\RapidScripts\DefenderSwitcher\$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
        mkdir $dir -Force *>$null
        Edit-Registry -Path $reg -Name 'CurrentLogDir' -Value $dir
    }
    Start-Transcript -Path "$dir\DefenderSwitcher.log" -Append -Force *>$null
}

function DefenderStatus {
    $val = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend' -Name 'Start' -EA 0).Start
    $cab = Get-WindowsPackage -Online -EA 0 | ? {$_.PackageName -match 'AntiBlocker|Defender'}
    $rpc = $true
    try {Get-MpComputerStatus -EA 1 >$null} catch {$rpc = $false}

    if ($cab -or $val -eq 4) {$global:status = 'disabled'}
    elseif ($val -lt 4 -and !$rpc -and !$global:safemode) {$global:status = 'corrupted'}
    else {$global:status = 'enabled'}
}

function MainMenu {
    cls
    DefenderStatus
    Write-Host "`n`n`n`n"
    Write-Host "         ______________________________________________________________" -F DarkGray
    Write-Host
    Write-Host "                               Defender Switcher"
    Write-Host
    Write-Host "                                Current Status:" -F Yellow
    if ($status -eq "enabled")
    {Write-Host "                          Windows Defender is ENABLED" -F Green}
    elseif ($status -eq "corrupted")
    {Write-Host "                         Windows Defender is CORRUPTED" -F Yellow}
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

    QuickEditOFF

    $host.UI.RawUI.FlushInputBuffer()
    $vk = 0
    while ($vk -lt 0x31 -or $vk -gt 0x34) {
        if ($host.UI.RawUI.KeyAvailable) {
            $vk = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').VirtualKeyCode
        }
        Start-Sleep -m 100
    }
    switch ($vk) {
        0x31 {EnableDefender}
        0x32 {DisableDefender}
        0x33 {ShowInformation}
        0x34 {Start-Sleep -m 300; exit}
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

    $host.UI.RawUI.FlushInputBuffer()
    $vk = 0
    while ($vk -ne 0x51) {
        while (($vk -lt 0x31 -or $vk -gt 0x36) -and $vk -ne 0x51) {
            if ($host.UI.RawUI.KeyAvailable) {
                $vk = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').VirtualKeyCode
            }
            Start-Sleep -m 100
        }
        switch ($vk) {
            0x31 {Start-Process "https://github.com/lostzombie/AchillesScript"}
            0x32 {Start-Process "https://github.com/AveYo/LeanAndMean"}
            0x33 {Start-Process "https://github.com/massgravel/Microsoft-Activation-Scripts"}
            0x34 {Start-Process "https://github.com/instead1337/Defender-Switcher"}
            0x35 {Start-Process "https://discord.rapid-community.ru"}
            0x36 {Start-Process "https://rapid-community.ru"}
            0x51 {MainMenu; return}
        }
    }
}

function EnableDefender {
    cls
    DefenderStatus
    switch ($status) {
        "enabled" {
            Write-Block -Content "INFO" -Title "Defender is already enabled."
        }
        default {
            QuickEditON
            Safeboot -Enable $true
        }
    }
    if ($interactive) {
        pause
        MainMenu
    } else {
        exit
    }
}

function DisableDefender {
    cls
    DefenderStatus
    switch ($status) {
        "disabled" {
            Write-Block -Content "INFO" -Title "Defender is already disabled."
        }
        default {
            QuickEditON
            Safeboot -Enable $false
        }
    }
    if ($interactive) {
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

    $reg = 'HKLM:\SOFTWARE\RapidOS\Defender'
    $work = "$env:SystemRoot\RapidScripts\DefenderSwitcher"

    if (!$global:safemode) {
        if (Test-Path $reg) {
            $entry = (Get-ItemProperty -Path $reg -Name "SafeBootGuid" -EA 0).SafeBootGuid
            if ($entry) {
                bcdedit /enum $entry 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Block -Content "INFO" -Title "$verb_ing Microsoft Defender will take effect after restart."
                    Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\CommitStatus' -Name 'NoCommit' -Type DWord -Value 1
                    if ($interactive) {
                        if (Write-Block -Prompt -Title 'Restart system now?') {shutdown /r /f /t 0} else {MainMenu}
                    } elseif (!$delayedrestart) {shutdown /r /f /t 0}
                    exit
                }
            }

            $config = Get-ItemProperty -Path $reg -EA 0
            if ($config.SvcName) {
                Edit-Registry -Path "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\$($config.SvcName)" -Remove
                sc.exe delete $config.SvcName 2>&1 | Out-Null
                del "$work\$($config.SvcName).exe" -Force *>$null
            }
            Edit-Registry -Path $reg -Remove
        }
    }

    Init-Log

    if (!$global:safemode) {
        Write-Block -Content "INFO" -Title "Preparing..."

        # === Configuration ===
        mkdir -Force -Path $work *>$null
        $backup = "$work\backup.json"
        if ($Enable) {
            $apply = 0
            if (Test-Path $backup) {
                $valid = Test-Path "$backup.valid"
                $time = (Get-Item $backup).LastWriteTime.ToString('yyyy-MM-dd HH:mm')

                if ($forcebackup) {
                    $apply = 1
                } elseif (!$skipbackup -and $interactive) {
                    $color = if ($valid) {'Green'} else {'Yellow'}
                    $tail = if ($valid) {''} else {' (saved during broken state)'}
                    $apply = [int](Write-Block -Prompt -Title "Apply Defender backup from ${time}${tail}?" -BracketColor $color)
                } elseif (!$skipbackup) {
                    $apply = [int]$valid
                    if (!$valid) {Write-Block -Content 'WARNING' -Title "Won't apply backup, it was saved during a broken state." -ContentColor 'Yellow'}
                }
            }
            Edit-Registry -Path $reg -Name 'ApplyBackup' -Type DWord -Value $apply
        } else {
            DefenderStatus
            $valid = $status -eq 'enabled'
            $found = Test-Path $backup
            $write = $false

            if (!$skipbackup) {
                if (!$found -and ($valid -or $forcebackup)) {
                    $write = $true
                } elseif (!$found) {
                    Write-Block -Content 'WARNING' -Title "Defender is $status, no backup made." -ContentColor 'Yellow'
                } elseif ($forcebackup -and !$valid -and (Test-Path "$backup.valid")) {
                    if ($interactive) {
                        Write-Block -Content 'WARNING' -Title "You already have a saved backup of a working Defender. Overwriting it now will replace it with the current $status state and you'll lose the clean restore point." -ContentColor 'Yellow'
                        $write = Write-Block -Prompt -Title 'Overwrite anyway?'
                    } else {
                        Write-Block -Content 'WARNING' -Title "Kept old backup, current Defender is $status." -ContentColor 'Yellow'
                    }
                } elseif ($forcebackup) {
                    $write = $true
                }
            }

            if ($write) {
                del $backup, "$backup.valid" -EA 0
                $paths = @(
                    'HKLM\SYSTEM\CurrentControlSet\Control\Ubpm'
                    'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderApiLogger'
                    'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DefenderAuditLogger'
                    'HKLM\SYSTEM\CurrentControlSet\Services\KslD'
                    'HKLM\SYSTEM\CurrentControlSet\Services\MDCoreSvc'
                    'HKLM\SYSTEM\CurrentControlSet\Services\MsSecCore'
                    'HKLM\SYSTEM\CurrentControlSet\Services\MsSecFlt'
                    'HKLM\SYSTEM\CurrentControlSet\Services\MsSecWfp'
                    'HKLM\SYSTEM\CurrentControlSet\Services\SecurityHealthService'
                    'HKLM\SYSTEM\CurrentControlSet\Services\Sense'
                    'HKLM\SYSTEM\CurrentControlSet\Services\SgrmAgent'
                    'HKLM\SYSTEM\CurrentControlSet\Services\SgrmBroker'
                    'HKLM\SYSTEM\CurrentControlSet\Services\WdBoot'
                    'HKLM\SYSTEM\CurrentControlSet\Services\WdDevFlt'
                    'HKLM\SYSTEM\CurrentControlSet\Services\WdFilter'
                    'HKLM\SYSTEM\CurrentControlSet\Services\WdNisDrv'
                    'HKLM\SYSTEM\CurrentControlSet\Services\WdNisSvc'
                    'HKLM\SYSTEM\CurrentControlSet\Services\webthreatdefsvc'
                    'HKLM\SYSTEM\CurrentControlSet\Services\webthreatdefusersvc'
                    'HKLM\SYSTEM\CurrentControlSet\Services\WinDefend'
                    'HKLM\SYSTEM\CurrentControlSet\Services\wscsvc'
                    'HKLM\SYSTEM\CurrentControlSet\Services\wtd'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Associations'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS'
                    'HKLM\SOFTWARE\Policies\Microsoft\Edge'
                    'HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter'
                    'HKLM\SOFTWARE\Policies\Microsoft\MRT'
                    'HKLM\SOFTWARE\Policies\Microsoft\Windows\System'
                    'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center'
                    'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender'
                    'HKLM\SOFTWARE\Microsoft\RemovalTools\MpGears'
                    'HKLM\SYSTEM\CurrentControlSet\Policies\EarlyLaunch'
                    'HKLM\SOFTWARE\Microsoft\Windows Defender'
                    'HKLM\SOFTWARE\Microsoft\Security Center'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Security-Adminless\Operational'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Security-Audit-Configuration-Client\Operational'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Security-EnterpriseData-FileRevocationManager\Operational'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Security-LessPrivilegedAppContainer\Operational'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Security-Netlogon\Operational'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Security-SPP-UX-GenuineCenter-Logging\Operational'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Security-SPP-UX-Notifications\ActionCenter'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Security-UserConsentVerifier\Audit'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-SecurityMitigationsBroker\Operational'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-SENSE\Operational'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-SenseIR\Operational'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-WDAG-PolicyEvaluator-CSP\Operational'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-WDAG-PolicyEvaluator-GP\Operational'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Windows Defender\Operational'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Windows Defender\WHC'
                    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Windows Firewall With Advanced Security\ConnectionSecurity'
                )
                Export-RegState -Path $paths -JsonPath $backup
                if ($valid) {New-Item "$backup.valid" -Force *>$null}
            }
        }

        $random = (New-Guid).ToString('N').Substring(0, 16)
        $exe = "$work\$random.exe"
        $obj = "Global\$random"

        Edit-Registry -Path $reg -Name "SyncMutex" -Value $obj
        Edit-Registry -Path $reg -Name "SvcName" -Value $random

        $timeout = (bcdedit /enum "{bootmgr}" 2>$null | Select-String -Pattern 'timeout' -SimpleMatch | Select -First 1 | % {($_ -replace '.*timeout\s+','').Trim()}) -join ''
        $displaybootmenu = (bcdedit /enum "{bootmgr}" 2>$null | Select-String -Pattern 'displaybootmenu' -SimpleMatch | Select -First 1 | % {($_ -replace '.*displaybootmenu\s+','').Trim()}) -join ''
        $defaultGuid = (bcdedit /v 2>$null | Select-String -Pattern 'default\s+(\{[a-f0-9\-]+\})' | Select -First 1 | % {$_.Matches[0].Groups[1].Value}) -join ''

        if ($timeout) {Edit-Registry -Path $reg -Name "Timeout" -Type DWord -Value $timeout} else {Edit-Registry -Path $reg -Name "Timeout" -Type DWord -Value 30}
        if ($displaybootmenu) {Edit-Registry -Path $reg -Name "DisplayBootMenu" -Value $displaybootmenu} else {Edit-Registry -Path $reg -Name "DisplayBootMenu" -Value "DELETE"}
        if ($defaultGuid) {Edit-Registry -Path $reg -Name "DefaultGuid" -Value $defaultGuid}

        $guid = (cmd /c 'bcdedit /copy {current} /d "Safe Mode"' 2>$null | Select-String "\{[a-f0-9\-]+\}" | Select -First 1) -replace ".*(\{[a-f0-9\-]+\}).*", '$1'
        if (!$guid) {
            $guid = (cmd /c 'bcdedit /copy {default} /d "Safe Mode"' 2>$null | Select-String "\{[a-f0-9\-]+\}" | Select -First 1) -replace ".*(\{[a-f0-9\-]+\}).*", '$1'
            if (!$guid) {
                Write-Block -Content "ERROR" -Title "Safe boot configuration failed." -ContentColor "Red"
                if ($interactive) {pause; MainMenu} else {[Environment]::Exit(0)}
            }
        }
        Edit-Registry -Path $reg -Name "SafeBootGuid" -Value $guid

        # === BCD setup ===
        bcdedit /set $guid safeboot minimal 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {bcdedit /set safeboot minimal 2>&1 | Out-Null}
        if ($LASTEXITCODE -ne 0) {
            Write-Block -Content "ERROR" -Title "Failed to enable safe boot." -ContentColor "Red"
            if ($interactive) {pause; MainMenu} else {[Environment]::Exit(0)}
        }

        bcdedit /set $guid device partition=$env:SystemDrive 2>&1 | Out-Null
        bcdedit /set $guid osdevice partition=$env:SystemDrive 2>&1 | Out-Null

        bcdedit /set "{bootmgr}" bootstatuspolicy IgnoreAllFailures 2>&1 | Out-Null
        bcdedit /set $guid bootstatuspolicy IgnoreAllFailures 2>&1 | Out-Null
        bcdedit /set $guid bootmenupolicy Legacy 2>&1 | Out-Null
        bcdedit /set $guid quietboot Yes 2>&1 | Out-Null
        bcdedit /set $guid bootux Disabled 2>&1 | Out-Null

        bcdedit /bootsequence $guid 2>&1 | Out-Null
        bcdedit /timeout 0 2>&1 | Out-Null

        # === Scripts & Service ===
        $script = $PSCommandPath
        $ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $argsList = "-EP Bypass -File `"$script`" $av_param"
        $cmd = "`"$ps`" $argsList"
        $literal = $argsList.Replace('"', '""')

        $code = @'
using System; using System.Runtime.InteropServices; using System.ServiceProcess; using System.Threading; using Microsoft.Win32;
namespace Checker {
public sealed class Service : ServiceBase {
    const string Root = @"HKEY_LOCAL_MACHINE\SOFTWARE\RapidOS\Defender";
    const int PollMs = 500, ProbeMs = 500;
    static readonly TimeSpan AppearTimeout = TimeSpan.FromMinutes(2), TotalTimeout = TimeSpan.FromMinutes(15), RelaunchDelay = TimeSpan.FromSeconds(10);
    public Service() {ServiceName = "{{svc}}"; AutoLog = true;}
    public static void Main() {ServiceBase.Run(new Service());}
    protected override void OnStart(string[] args) {new Thread(RunCheck) {IsBackground = true}.Start();}
    void RunCheck() {
        if (Registry.GetValue(@"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SafeBoot\Option", "OptionValue", null) == null) {Stop(); return;}
        string mtx = (string)Registry.GetValue(Root, "SyncMutex", ""), cmd = @"{{cmd}}";
        if (string.IsNullOrEmpty(mtx) || string.IsNullOrEmpty(cmd)) {Stop(); return;}
        DateTime appearBy = DateTime.UtcNow + AppearTimeout, stopBy = DateTime.UtcNow + TotalTimeout, nextLaunch = DateTime.MinValue, now; Mutex h;
        while ((now = DateTime.UtcNow) < stopBy) {
            if (Done()) {Stop(); return;}
            try {if (Mutex.TryOpenExisting(mtx, out h)) using (h) {
                    bool owned = false; try {
                        try {owned = h.WaitOne(ProbeMs);} catch (AbandonedMutexException) {owned = true;}
                        if (owned && now >= nextLaunch && !Done()) {Launch(cmd); nextLaunch = now + RelaunchDelay;}
                    } finally {if (owned) try {h.ReleaseMutex();} catch {}}
                }
                else if (now >= appearBy && now >= nextLaunch) {Launch(cmd); nextLaunch = now + RelaunchDelay;}
            } catch {} Thread.Sleep(PollMs);
        } Stop();
    }
    static bool Done() {return Registry.GetValue(Root, "Executed", null) != null;}
    static void Launch(string cmd) {ShellExecuteW(IntPtr.Zero, "open", Environment.ExpandEnvironmentVariables(@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"), cmd, null, 0);}
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)] static extern IntPtr ShellExecuteW(IntPtr hwnd, string op, string file, string param, string dir, int show);
}}
'@
        $code = $code.Replace('{{svc}}', $random).Replace('{{cmd}}', $literal)
        try {
            Add-Type $code -OutputAssembly $exe -ReferencedAssemblies 'System', 'System.ServiceProcess' -EA 1
            sc.exe delete $random 2>&1 | Out-Null
            sc.exe create $random type= own start= auto error= ignore obj= "LocalSystem" binPath= "$exe" 2>&1 | Out-Null
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\$random" /ve /t REG_SZ /d "Service" /f 2>&1 | Out-Null
        } catch {
            Write-Block -Content "ERROR" -Title "Failed to compile service. Aborting safe boot." -ContentColor "Red"

            Edit-Registry -Path "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\$random" -Remove
            sc.exe delete $random 2>&1 | Out-Null
            del $exe -Force *>$null
            if ($displaybootmenu -eq "DELETE") {bcdedit /deletevalue {bootmgr} displaybootmenu 2>&1 | Out-Null} else {bcdedit /set {bootmgr} displaybootmenu $displaybootmenu 2>&1 | Out-Null}
            bcdedit /timeout $timeout 2>&1 | Out-Null
            bcdedit /default $defaultGuid 2>&1 | Out-Null
            bcdedit /delete $guid /f 2>&1 | Out-Null

            Edit-Registry -Path $reg -Remove

            if ($interactive) {pause; MainMenu} else {[Environment]::Exit(0)}
        }

        Edit-Registry -Path "HKLM\SYSTEM\Setup" -Name "SetupType" -Type DWord -Value 1
        Edit-Registry -Path "HKLM\SYSTEM\Setup" -Name "CmdLine" -Type String -Value $cmd
        Edit-Registry -Path "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\WinDefend" -Remove

        $bde = Get-BitLockerVolume -MountPoint $env:SystemDrive
        if ($bde -and $bde.ProtectionStatus -eq 'On') {
            manage-bde.exe -protectors -disable $env:SystemDrive -RebootCount 2 2>&1 | Out-Null
        }

        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\CommitStatus' -Name 'NoCommit' -Type DWord -Value 1

        if ($interactive -and !$delayedrestart) {
            Write-Block -Content "INFO" -Title "Rebooting in 5 sec..."
            Start-Sleep -s 5
        }

        if (!$delayedrestart) {
            shutdown /r /f /t 0
        } else {
            Write-Block -Content "INFO" -Title "$verb_ing Microsoft Defender will take effect after restart."
            Start-Sleep -s 2
            if ($interactive) {pause; MainMenu} else {[Environment]::Exit(0)}
        }
    }
    else {
        # === Cleanup & Restore ===
        $hash = (Get-ItemProperty -Path $reg -Name "SyncMutex" -EA 0).SyncMutex
        $handle = $null; $owned = $false

        if ($hash) {
            $created = $false; $handle = [Threading.Mutex]::new($true, $hash, [ref]$created); $owned = $created
            if (!$owned) {try {$owned = $handle.WaitOne(30000)} catch [Threading.AbandonedMutexException] {$owned = $true}}
            if (!$owned) {
                $handle.Dispose()
                [Environment]::Exit(0)
            }
        }

        try {
            if ((Get-ItemProperty -Path $reg -Name "Executed" -EA 0).Executed) {return}

            Write-Block -Content "INFO" -Title "Restoring boot configuration..."
            Edit-Registry -Path "HKLM\SYSTEM\Setup" -Name "SetupType" -Type DWord -Value 0
            Edit-Registry -Path "HKLM\SYSTEM\Setup" -Name "CmdLine" -Type String -Value ""
            Edit-Registry -Path "HKLM\SYSTEM\Setup" -Name "SystemSetupInProgress" -Type DWord -Value 0
            Edit-Registry -Path "HKLM\SYSTEM\Setup" -Name "SetupShutdownRequired" -Type DWord -Value 1
            Edit-Registry -Path "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\WinDefend" -Name "" -Value "Service"

            bcdedit /deletevalue safeboot 2>&1 | Out-Null
            if (Test-Path $reg) {
                $config = Get-ItemProperty -Path $reg
                $random = $config.SvcName
                $exe = "$work\$random.exe"

                bcdedit /timeout $config.Timeout 2>&1 | Out-Null
                bcdedit /default $config.DefaultGuid 2>&1 | Out-Null
                bcdedit /delete $config.SafeBootGuid /f 2>&1 | Out-Null
                if ($config.DisplayBootMenu -eq "DELETE") {
                    bcdedit /deletevalue {bootmgr} displaybootmenu 2>&1 | Out-Null
                } else {
                    bcdedit /set {bootmgr} displaybootmenu $config.DisplayBootMenu 2>&1 | Out-Null
                }
            } else {
                bcdedit /timeout 15 2>&1 | Out-Null
                bcdedit /deletevalue {bootmgr} displaybootmenu 2>&1 | Out-Null
            }

            if ($Enable) {
                ProcessDefender -Enable $true
            } else {
                ProcessDefender -Disable $true
            }

            if ($random) {
                if ($exe) {Edit-Registry -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "DefenderCleanup" -Value "cmd /c del /f /q `"$exe`" & reg delete `"HKLM\SOFTWARE\Microsoft\WindowsUpdate\CommitStatus`" /v NoCommit /f & reg delete `"HKLM\SOFTWARE\RapidOS\Defender`" /f"}

                sc.exe stop $random 2>&1 | Out-Null
                Edit-Registry -Path "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\$random" -Remove
                sc.exe delete $random 2>&1 | Out-Null
            }

            Edit-Registry -Path $reg -Name "Executed" -Value "1"

            DefenderStatus
            switch ($status) {
                "$verb_ed" {
                    Write-Block -Content "INFO" -Title "Defender has been $verb_ed."
                }
                default {
                    Write-Block -Content "ERROR" -Title "Failed to $verb_base Defender." -ContentColor "Red"
                }
            }

        } finally {
            if ($owned -and $handle) {$handle.ReleaseMutex()}
            if ($handle) {$handle.Dispose()}
            [Environment]::Exit(0)
        }
    }
}

function ProcessDefender {
    param ([switch]$Enable, [switch]$Disable)

    # === Variables ===
    $work = "$env:SystemRoot\RapidScripts\DefenderSwitcher"
    $backup = "$work\backup.json"
    $src = "$env:ProgramFiles\Windows Defender"
    $dest = "$env:ProgramFiles\Windows Defender Advanced Threat Protection\Classification"
    $sys = "$env:SystemRoot\System32"
    $map = @{
        'WinDefend' = 2; 'MDCoreSvc' = 2; 'WdNisSvc' = 3; 'Sense' = 3
        'webthreatdefsvc' = 3; 'webthreatdefusersvc' = 2; 'WdNisDrv' = 3
        'WdBoot' = 0; 'WdDevFlt' = 1; 'WdFilter' = 0
        'SgrmBroker' = 2; 'SgrmAgent' = 0; 'MsSecWfp' = 3
        'MsSecFlt' = 3; 'MsSecCore' = 0; 'wtd' = 2; 'KslD' = 3
    }
    $list = 'shellext.dll', 'AMMonitoringProvider.dll', 'DefenderCSP.dll', 'MpOAV.dll', 'MpProvider.dll', 'MpUxAgent.dll', 'MsMpCom.dll', 'ProtectionManagement.dll'
    $list2 = 'cmicarabicwordbreaker.dll', 'korwbrkr.dll', 'mce.dll', 'upe.dll'
    $list3 = 'ieapfltr.dll', 'ThreatResponseEngine.dll', 'webthreatdefsvc.dll'
    $proc = 'SecurityHealthService.exe', 'SecurityHealthSystray.exe', 'SecurityHealthHost.exe'
    $log = 'DefenderApiLogger', 'DefenderAuditLogger'
    $tasks = 'Cache Maintenance', 'Cleanup', 'Scheduled Scan', 'Verification', 'Update'
    $fw = 'HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\Static\System'
    $sc = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center'
    $pol = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender'
    $wd = 'HKLM\SOFTWARE\Microsoft\Windows Defender'
    $rules = @{
        'WebThreatDefSvc_Allow_In' = 'v2.0|Action=Allow|Dir=In|App=%SystemRoot%\system32\svchost.exe|Svc=WebThreatDefSvc|LPort=443|Protocol=6|Name=Allow WebThreatDefSvc to receive from port 443|'
        'WebThreatDefSvc_Allow_Out' = 'v2.0|Action=Allow|Dir=Out|App=%SystemRoot%\system32\svchost.exe|Svc=WebThreatDefSvc|RPort=443|Protocol=6|Name=Allow WebThreatDefSvc to send to port 443|'
        'WebThreatDefSvc_Block_In' = 'v2.0|Action=Block|Dir=In|App=%SystemRoot%\system32\svchost.exe|Svc=WebThreatDefSvc|Name=Block inbound traffic to WebThreatDefSvc|'
        'WebThreatDefSvc_Block_Out' = 'v2.0|Action=Block|Dir=Out|App=%SystemRoot%\system32\svchost.exe|Svc=WebThreatDefSvc|Name=Block outbound traffic to WebThreatDefSvc|'
        'WindowsDefender-1' = 'v2.0|Action=Allow|Active=TRUE|Dir=Out|Protocol=6|App=%ProgramFiles%\Windows Defender\MsMpEng.exe|Svc=WinDefend|Name=Allow Out TCP traffic from WinDef|'
        'WindowsDefender-2' = 'v2.0|Action=Block|Active=TRUE|Dir=In|App=%ProgramFiles%\Windows Defender\MsMpEng.exe|Svc=WinDefend|Name=Block All In traffic to WinDef|'
        'WindowsDefender-3' = 'v2.0|Action=Block|Active=TRUE|Dir=Out|App=%ProgramFiles%\Windows Defender\MsMpEng.exe|Svc=WinDefend|Name=Block All Out traffic from WinDef|'
    }
    $channels = @(
        'Microsoft-Windows-Security-Adminless\Operational'
        'Microsoft-Windows-Security-Audit-Configuration-Client\Operational'
        'Microsoft-Windows-Security-EnterpriseData-FileRevocationManager\Operational'
        'Microsoft-Windows-Security-LessPrivilegedAppContainer\Operational'
        'Microsoft-Windows-Security-Netlogon\Operational'
        'Microsoft-Windows-Security-SPP-UX-GenuineCenter-Logging\Operational'
        'Microsoft-Windows-Security-SPP-UX-Notifications\ActionCenter'
        'Microsoft-Windows-Security-UserConsentVerifier\Audit'
        'Microsoft-Windows-SecurityMitigationsBroker\Operational'
        'Microsoft-Windows-SENSE\Operational'
        'Microsoft-Windows-SenseIR\Operational'
        'Microsoft-Windows-WDAG-PolicyEvaluator-CSP\Operational'
        'Microsoft-Windows-WDAG-PolicyEvaluator-GP\Operational'
        'Microsoft-Windows-Windows Defender\Operational'
        'Microsoft-Windows-Windows Defender\WHC'
        'Microsoft-Windows-Windows Firewall With Advanced Security\ConnectionSecurity'
    )

    # === Enable Defender ===
    if ($Enable) {
        $obj = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend' -Name 'ImagePath' -EA 0
        if ($obj) {
            $path = Split-Path $obj.ImagePath.Trim('"')
            if (Test-Path "$path\off.exe") {
                move "$path\off.exe" "$path\MpCmdRun.exe" -Force 2>&1 | Out-Null
            }
        }

        Write-Block -Content 'INFO' -Title 'Configuring services...'
        foreach ($entry in $map.GetEnumerator()) {Edit-Registry -Path "HKLM\SYSTEM\CurrentControlSet\Services\$($entry.Key)" -Name 'Start' -Type DWord -Value $entry.Value}

        Write-Block -Content 'INFO' -Title 'Registering DLLs...'
        foreach ($dll in $list) {regsvr32 /s "$src\$dll" 2>&1 | Out-Null}
        if (Test-Path $dest) {foreach ($dll in $list2) {regsvr32 /s "$dest\$dll" 2>&1 | Out-Null}}
        foreach ($dll in $list3) {regsvr32 /s "$sys\$dll" 2>&1 | Out-Null}

        Write-Block -Content 'INFO' -Title 'Restoring components...'
        Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Control\Ubpm' -Name 'CriticalMaintenance_DefenderCleanup' -Type String -Value 'NT Task\Microsoft\Windows\Windows Defender\Windows Defender Cleanup'
        Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Control\Ubpm' -Name 'CriticalMaintenance_DefenderVerification' -Type String -Value 'NT Task\Microsoft\Windows\Windows Defender\Windows Defender Verification'
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Svchost' -Name 'WebThreatDefense' -Type MultiString -Value 'webthreatdefsvc'
        foreach ($l in $log) {Edit-Registry -Path "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$l" -Name 'Start' -Type DWord -Value 1}
        foreach ($ch in $channels) {Edit-Registry -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\$ch" -Name 'Enabled' -Type DWord -Value 1}
        foreach ($rule in $rules.GetEnumerator()) {Edit-Registry -Path $fw -Name $rule.Key -Type String -Value $rule.Value}

        Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Services\WdFilter\Instances\WdFilter Instance' -Name 'Altitude' -Value '328010'
        Edit-Registry -Path "$wd\Features" -Name 'TamperProtection' -Type DWord -Value 1
        Edit-Registry -Path "$wd\Features" -Name 'TamperProtectionSource' -Type DWord -Value 5
        Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy' -Name 'VerifiedAndReputablePolicyState' -Remove

        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\FeatureFlags' -Name 'TelemetryCallsEnabled' -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components' -Name 'ServiceEnabled' -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components' -Name 'NotifyUnsafeApp' -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components' -Name 'NotifyPasswordReuse' -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components' -Name 'NotifyMalicious' -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components' -Name 'CaptureThreatWindow' -Remove

        @(
            'HKLM\SOFTWARE\Policies\Microsoft\Edge'
            'HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter'
            'HKLM\SOFTWARE\Policies\Microsoft\MRT'
            'HKLM\SOFTWARE\Policies\Microsoft\Windows\System'
            'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments'
            'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Associations'
            'HKLM\SOFTWARE\Policies\Microsoft\Windows\WTDS\Components'
            "$sc\Device security"
            "$pol\Device Control"
            "$pol\Exclusions"
            "$pol\Features"
            "$pol\MpEngine"
            "$pol\NIS"
            "$pol\Policy Manager"
            "$pol\Real-Time Protection"
            "$pol\Remediation"
            "$pol\Reporting"
            "$pol\Scan"
            "$pol\Signature Updates"
            "$pol\Spynet"
            "$pol\UX Configuration"
        ) | % {Edit-Registry -Path $_ -Remove}

        Edit-Registry -Path $pol -Name 'DisableLocalAdminMerge' -Remove
        Edit-Registry -Path $pol -Name 'DisableRoutinelyTakingAction' -Remove
        Edit-Registry -Path $pol -Name 'AllowFastServiceStartup' -Remove
        Edit-Registry -Path $pol -Name 'PUAProtection' -Remove
        Edit-Registry -Path $pol -Name 'RandomizeScheduleTaskTimes' -Remove
        Edit-Registry -Path $pol -Name 'ServiceKeepAlive' -Remove
        Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Policies\EarlyLaunch' -Name 'DriverLoadPolicy' -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\RemovalTools\MpGears' -Remove

        Edit-Registry -Path $wd -Name 'ProductStatus' -Type DWord -Value 0
        Edit-Registry -Path $wd -Name 'ProductType' -Type DWord -Value 2
        Edit-Registry -Path $wd -Name 'PUAProtection' -Type DWord -Value 1
        Edit-Registry -Path $wd -Name 'SmartLockerMode' -Remove
        Edit-Registry -Path "$wd\CoreService" -Name 'DisableCoreService1DSTelemetry' -Type DWord -Value 0
        Edit-Registry -Path "$wd\CoreService" -Name 'DisableCoreServiceECSIntegration' -Type DWord -Value 0
        Edit-Registry -Path "$wd\CoreService" -Name 'MdDisableResController' -Type DWord -Value 0
        Edit-Registry -Path "$wd\Real-Time Protection" -Name 'DisableAsyncScanOnOpen' -Remove
        Edit-Registry -Path "$wd\Real-Time Protection" -Name 'DisableRealtimeMonitoring' -Remove
        Edit-Registry -Path "$wd\Real-Time Protection" -Name 'DpaDisabled' -Type DWord -Value 0
        Edit-Registry -Path "$wd\Scan" -Name 'DisableArchiveScanning' -Remove
        Edit-Registry -Path "$wd\Scan" -Name 'DisableEmailScanning' -Remove
        Edit-Registry -Path "$wd\Scan" -Name 'DisableRemovableDriveScanning' -Remove
        Edit-Registry -Path "$wd\Scan" -Name 'DisableScanningMappedNetworkDrivesForFullScan' -Remove
        Edit-Registry -Path "$wd\Scan" -Name 'DisableScanningNetworkFiles' -Remove
        Edit-Registry -Path "$wd\Scan" -Name 'AvgCPULoadFactor' -Remove
        Edit-Registry -Path "$wd\Scan" -Name 'LowCpuPriority' -Remove
        Edit-Registry -Path "$wd\Spynet" -Name 'MAPSconcurrency' -Type DWord -Value 1
        Edit-Registry -Path "$wd\Threats\ThreatSeverityDefaultAction" -Name '1' -Remove
        Edit-Registry -Path "$wd\Threats\ThreatSeverityDefaultAction" -Name '2' -Remove
        Edit-Registry -Path "$wd\Threats\ThreatSeverityDefaultAction" -Name '4' -Remove
        Edit-Registry -Path "$wd\Threats\ThreatSeverityDefaultAction" -Name '5' -Remove

        Edit-Registry -Path "$sc\Notifications" -Name 'DisableNotifications' -Remove
        Edit-Registry -Path "$sc\Virus and threat protection" -Name 'UILockdown' -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'SecurityHealth' -Type ExpandString -Value '%SystemRoot%\System32\SecurityHealthSystray.exe'

        Write-Block -Content 'INFO' -Title 'Enabling SmartScreen...'
        Edit-Registry -Path "$pol\SmartScreen" -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'SmartScreenEnabled' -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Classes\exefile\shell\open' -Name 'NoSmartScreen' -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Classes\exefile\shell\runas' -Name 'NoSmartScreen' -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Classes\exefile\shell\runasuser' -Name 'NoSmartScreen' -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'AicEnabled' -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' -Name 'ProcessCreationIncludeCmdLine_Enabled' -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost' -Name 'EnableWebContentEvaluation' -Type DWord -Value 1
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost' -Name 'PreventOverride' -Type DWord -Value 0

        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Security Center' -Name 'AntiVirusOverride' -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Security Center' -Name 'FirewallOverride' -Remove
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Security Center' -Name 'FirstRunDisabled' -Remove

        $sids = @(gci Registry::HKU | ? {$_.Name -like 'S-1-5-21-*'}) + (Get-Item 'Registry::HKU\.DEFAULT')
        foreach ($sid in $sids) {
            $id = $sid.PSChildName
            $path = "Registry::HKU\$id\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost"
            Edit-Registry -Path $path -Name 'EnableWebContentEvaluation' -Type DWord -Value 1
            Edit-Registry -Path $path -Name 'PreventOverride' -Type DWord -Value 0

            $path2 = "Registry::HKU\$id\SOFTWARE\Microsoft\Windows Security Health\State"
            Edit-Registry -Path $path2 -Name 'AppAndBrowser_StoreAppsSmartScreenOff' -Type DWord -Value 0
            Edit-Registry -Path $path2 -Name 'AppAndBrowser_EdgeSmartScreenOff' -Type DWord -Value 0
            Edit-Registry -Path $path2 -Name 'AppAndBrowser_PuaSmartScreenOff' -Remove
            Edit-Registry -Path $path2 -Name 'AccountProtection_MicrosoftAccountConnectionState' -Remove

            $pAtt = "Registry::HKU\$id\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments"
            $pAss = "Registry::HKU\$id\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Associations"
            Edit-Registry -Path $pAtt -Name 'SaveZoneInformation' -Remove
            Edit-Registry -Path $pAtt -Name 'HideZoneInfoOnProperties' -Remove
            Edit-Registry -Path $pAss -Name 'LowRiskFileTypes' -Remove

            Edit-Registry -Path "Registry::HKU\$id\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" -Name 'Enabled' -Remove
        }

        Write-Block -Content 'INFO' -Title 'Enabling scheduled tasks...'
        foreach ($task in $tasks) {
            $file = "$env:SystemRoot\System32\Tasks\Microsoft\Windows\Windows Defender\Windows Defender $task"
            $json = "$work\$task.json"
            $xml = "$work\$task.xml"

            Import-RegState -JsonPath $json
            move $xml $file -Force -EA 0
            del $json -Force -EA 0
        }

        foreach ($p in $proc) {
            $ifeo = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$p\PerfOptions"
            'CpuPriorityClass', 'IoPriority', 'PagePriority', 'EcoQoS', 'WorkingSetLimitInKB' | % {Edit-Registry -Path $ifeo -Name $_ -Remove}
        }

        if ((Get-ItemProperty 'HKLM:\SOFTWARE\RapidOS\Defender' -Name 'ApplyBackup' -EA 0).ApplyBackup -eq 1 -and (Test-Path $backup)) {
            Write-Block -Content 'INFO' -Title 'Restoring Defender backup...'
            Import-RegState -JsonPath $backup
        }
    }

    # === Disable Defender ===
    if ($Disable) {
        $obj = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend' -Name 'ImagePath' -EA 0
        if ($obj) {
            $path = Split-Path $obj.ImagePath.Trim('"')
            if (Test-Path "$path\MpCmdRun.exe") {
                move "$path\MpCmdRun.exe" "$path\off.exe" -Force 2>&1 | Out-Null
            }
        }

        Write-Block -Content 'INFO' -Title 'Applying registry changes...'
        foreach ($svc in $map.Keys) {
            Edit-Registry -Path "HKLM\SYSTEM\CurrentControlSet\Services\$svc" -Name 'Start' -Type DWord -Value 4
            Edit-Registry -Path "HKLM\SYSTEM\CurrentControlSet\Services\$svc" -Name 'FailureActions' -Type Binary -Value ([byte[]]::new(24))
        }

        Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Control\Ubpm' -Name 'CriticalMaintenance_DefenderCleanup' -Remove
        Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Control\Ubpm' -Name 'CriticalMaintenance_DefenderVerification' -Remove

        Edit-Registry -Path 'HKLM\SOFTWARE\Policies\Microsoft\MRT' -Name 'DontOfferThroughWUAU' -Type DWord -Value 1
        Edit-Registry -Path 'HKLM\SOFTWARE\Policies\Microsoft\MRT' -Name 'DontReportInfectionInformation' -Type DWord -Value 1

        Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Services\WdFilter\Instances\WdFilter Instance' -Name 'Altitude' -Remove
        Edit-Registry -Path "$wd\Features" -Name 'TamperProtection' -Type DWord -Value 4
        Edit-Registry -Path "$wd\Features" -Name 'TamperProtectionSource' -Type DWord -Value 2
        Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy' -Name 'VerifiedAndReputablePolicyState' -Type DWord -Value 0

        Edit-Registry -Path "$sc\Device security" -Name 'UILockdown' -Type DWord -Value 1
        Edit-Registry -Path "$sc\Notifications" -Name 'DisableNotifications' -Type DWord -Value 1
        Edit-Registry -Path "$sc\Virus and threat protection" -Name 'UILockdown' -Type DWord -Value 1

        Edit-Registry -Path $pol -Name 'DisableLocalAdminMerge' -Type DWord -Value 1
        Edit-Registry -Path $pol -Name 'DisableRoutinelyTakingAction' -Type DWord -Value 1
        Edit-Registry -Path $pol -Name 'AllowFastServiceStartup' -Type DWord -Value 0
        Edit-Registry -Path $pol -Name 'PUAProtection' -Type DWord -Value 0
        Edit-Registry -Path $pol -Name 'RandomizeScheduleTaskTimes' -Type DWord -Value 0
        Edit-Registry -Path $pol -Name 'ServiceKeepAlive' -Type DWord -Value 0

        Edit-Registry -Path "$pol\Exclusions" -Name 'DisableAutoExclusions' -Type DWord -Value 1
        Edit-Registry -Path "$pol\Features" -Name 'DeviceControlEnabled' -Type DWord -Value 0
        Edit-Registry -Path "$pol\Features" -Name 'PassiveRemediation' -Type DWord -Value 0
        Edit-Registry -Path "$pol\Features" -Name 'TDTFeatureEnabled' -Type DWord -Value 0

        $nis = "$pol\NIS"
        Edit-Registry -Path $nis -Name 'DisableDatagramProcessing' -Type DWord -Value 1
        Edit-Registry -Path $nis -Name 'DisableProtocolRecognition' -Type DWord -Value 1
        Edit-Registry -Path "$nis\Consumers\IPS" -Name 'DisableProtocolRecognition' -Type DWord -Value 1
        Edit-Registry -Path "$nis\Consumers\IPS" -Name 'DisableSignatureRetirement' -Type DWord -Value 1

        Edit-Registry -Path "$pol\Policy Manager" -Name 'DisableScanningNetworkFiles' -Type DWord -Value 1

        $rtp = "$pol\Real-Time Protection"
        Edit-Registry -Path $rtp -Name 'DisableBehaviorMonitoring' -Type DWord -Value 1
        Edit-Registry -Path $rtp -Name 'DisableInformationProtectionControl' -Type DWord -Value 1
        Edit-Registry -Path $rtp -Name 'DisableIntrusionPreventionSystem' -Type DWord -Value 1
        Edit-Registry -Path $rtp -Name 'DisableIOAVProtection' -Type DWord -Value 1
        Edit-Registry -Path $rtp -Name 'DisableOnAccessProtection' -Type DWord -Value 1
        Edit-Registry -Path $rtp -Name 'DisableRawWriteNotification' -Type DWord -Value 1
        Edit-Registry -Path $rtp -Name 'DisableRealtimeMonitoring' -Type DWord -Value 1
        Edit-Registry -Path $rtp -Name 'DisableScanOnRealtimeEnable' -Type DWord -Value 1
        Edit-Registry -Path $rtp -Name 'DisableScriptScanning' -Type DWord -Value 1

        $rep = "$pol\Reporting"
        Edit-Registry -Path $rep -Name 'DisableEnhancedNotifications' -Type DWord -Value 1
        Edit-Registry -Path $rep -Name 'DisableGenericRePorts' -Type DWord -Value 1

        $scan = "$pol\Scan"
        Edit-Registry -Path $scan -Name 'DisableArchiveScanning' -Type DWord -Value 1
        Edit-Registry -Path $scan -Name 'DisableCatchupFullScan' -Type DWord -Value 1
        Edit-Registry -Path $scan -Name 'DisableCatchupQuickScan' -Type DWord -Value 1
        Edit-Registry -Path $scan -Name 'DisableEmailScanning' -Type DWord -Value 1
        Edit-Registry -Path $scan -Name 'DisableHeuristics' -Type DWord -Value 1
        Edit-Registry -Path $scan -Name 'DisablePackedExeScanning' -Type DWord -Value 1
        Edit-Registry -Path $scan -Name 'DisableRemovableDriveScanning' -Type DWord -Value 1
        Edit-Registry -Path $scan -Name 'DisableReparsePointScanning' -Type DWord -Value 1
        Edit-Registry -Path $scan -Name 'DisableRestorePoint' -Type DWord -Value 1
        Edit-Registry -Path $scan -Name 'DisableScanningMappedNetworkDrivesForFullScan' -Type DWord -Value 1
        Edit-Registry -Path $scan -Name 'DisableScanningNetworkFiles' -Type DWord -Value 1

        $sig = "$pol\Signature Updates"
        Edit-Registry -Path $sig -Name 'DisableScanOnUpdate' -Type DWord -Value 1
        Edit-Registry -Path $sig -Name 'DisableScheduledSignatureUpdateOnBattery' -Type DWord -Value 1
        Edit-Registry -Path $sig -Name 'DisableUpdateOnStartupWithoutEngine' -Type DWord -Value 1

        $spy = "$pol\Spynet"
        Edit-Registry -Path $spy -Name 'DisableBlockAtFirstSeen' -Type DWord -Value 1
        Edit-Registry -Path $spy -Name 'SpynetReporting' -Type DWord -Value 0
        Edit-Registry -Path $spy -Name 'SubmitSamplesConsent' -Type DWord -Value 2

        Edit-Registry -Path 'HKLM\SYSTEM\CurrentControlSet\Policies\EarlyLaunch' -Name 'DriverLoadPolicy' -Type DWord -Value 7

        Edit-Registry -Path $wd -Name 'ProductStatus' -Type DWord -Value 2
        Edit-Registry -Path $wd -Name 'ProductType' -Type DWord -Value 0
        Edit-Registry -Path $wd -Name 'PUAProtection' -Type DWord -Value 0
        Edit-Registry -Path $wd -Name 'SmartLockerMode' -Type DWord -Value 0
        Edit-Registry -Path "$wd\CoreService" -Name 'DisableCoreService1DSTelemetry' -Type DWord -Value 1
        Edit-Registry -Path "$wd\CoreService" -Name 'DisableCoreServiceECSIntegration' -Type DWord -Value 1
        Edit-Registry -Path "$wd\CoreService" -Name 'MdDisableResController' -Type DWord -Value 1
        Edit-Registry -Path "$wd\Spynet" -Name 'MAPSconcurrency' -Type DWord -Value 0
        Edit-Registry -Path "$wd\Spynet" -Name 'SubmitSamplesConsent' -Type DWord -Value 0
        Edit-Registry -Path "$wd\Threats\ThreatSeverityDefaultAction" -Name '1' -Type String -Value '9'
        Edit-Registry -Path "$wd\Threats\ThreatSeverityDefaultAction" -Name '2' -Type String -Value '9'
        Edit-Registry -Path "$wd\Threats\ThreatSeverityDefaultAction" -Name '4' -Type String -Value '9'
        Edit-Registry -Path "$wd\Threats\ThreatSeverityDefaultAction" -Name '5' -Type String -Value '9'

        Write-Block -Content 'INFO' -Title 'Unregistering DLLs...'
        foreach ($dll in $list) {regsvr32 /u /s "$src\$dll" 2>&1 | Out-Null}
        if (Test-Path $dest) {foreach ($dll in $list2) {regsvr32 /u /s "$dest\$dll" 2>&1 | Out-Null}}
        foreach ($dll in $list3) {regsvr32 /u /s "$sys\$dll" 2>&1 | Out-Null}

        Write-Block -Content 'INFO' -Title 'Disabling SmartScreen...'
        Edit-Registry -Path "$pol\SmartScreen" -Name 'ConfigureAppInstallControl' -Type String -Value 'Anywhere'
        Edit-Registry -Path "$pol\SmartScreen" -Name 'ConfigureAppInstallControlEnabled' -Type DWord -Value 1
        Edit-Registry -Path 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'EnableSmartScreen' -Type DWord -Value 0
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'SmartScreenEnabled' -Value 'Off'
        Edit-Registry -Path 'HKLM\SOFTWARE\Policies\Microsoft\Edge' -Name 'SmartScreenEnabled' -Type DWord -Value 0
        Edit-Registry -Path 'HKLM\SOFTWARE\Policies\Microsoft\Edge' -Name 'SmartScreenPuaEnabled' -Type DWord -Value 0
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments' -Name 'SaveZoneInformation' -Type DWord -Value 1
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments' -Name 'HideZoneInfoOnProperties' -Type DWord -Value 1
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Associations' -Name 'LowRiskFileTypes' -Type String -Value '.exe;.bat;.cmd;.vbs;.msi;.reg;.ps1'

        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost' -Name 'EnableWebContentEvaluation' -Type DWord -Value 0
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost' -Name 'PreventOverride' -Type DWord -Value 0
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\FeatureFlags' -Name 'TelemetryCallsEnabled' -Type DWord -Value 0

        $sids = @(gci Registry::HKU | ? {$_.Name -like 'S-1-5-21-*'}) + (Get-Item 'Registry::HKU\.DEFAULT')
        foreach ($sid in $sids) {
            $id = $sid.PSChildName
            $path = "Registry::HKU\$id\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost"
            Edit-Registry -Path $path -Name 'EnableWebContentEvaluation' -Type DWord -Value 0
            Edit-Registry -Path $path -Name 'PreventOverride' -Type DWord -Value 0

            $path2 = "Registry::HKU\$id\SOFTWARE\Microsoft\Windows Security Health\State"
            Edit-Registry -Path $path2 -Name 'AppAndBrowser_StoreAppsSmartScreenOff' -Type DWord -Value 1
            Edit-Registry -Path $path2 -Name 'AppAndBrowser_EdgeSmartScreenOff' -Type DWord -Value 1
            Edit-Registry -Path $path2 -Name 'AppAndBrowser_PuaSmartScreenOff' -Type DWord -Value 1
            Edit-Registry -Path $path2 -Name 'AccountProtection_MicrosoftAccountConnectionState' -Type DWord -Value 1

            $pAtt = "Registry::HKU\$id\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments"
            $pAss = "Registry::HKU\$id\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Associations"
            Edit-Registry -Path $pAtt -Name 'SaveZoneInformation' -Type DWord -Value 1
            Edit-Registry -Path $pAtt -Name 'HideZoneInfoOnProperties' -Type DWord -Value 1
            Edit-Registry -Path $pAss -Name 'LowRiskFileTypes' -Type String -Value '.exe;.bat;.cmd;.vbs;.msi;.reg;.ps1'

            Edit-Registry -Path "Registry::HKU\$id\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" -Name 'Enabled' -Type DWord -Value 0
        }

        Edit-Registry -Path 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WTDS\Components' -Name 'ServiceEnabled' -Type DWord -Value 0
        Edit-Registry -Path 'HKLM\SOFTWARE\Classes\exefile\shell\open' -Name 'NoSmartScreen' -Type String -Value ''
        Edit-Registry -Path 'HKLM\SOFTWARE\Classes\exefile\shell\runas' -Name 'NoSmartScreen' -Type String -Value ''
        Edit-Registry -Path 'HKLM\SOFTWARE\Classes\exefile\shell\runasuser' -Name 'NoSmartScreen' -Type String -Value ''
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'AicEnabled' -Type DWord -Value 0

        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Security Center' -Name 'AntiVirusOverride' -Type DWord -Value 1
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Security Center' -Name 'FirewallOverride' -Type DWord -Value 1
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Security Center' -Name 'FirstRunDisabled' -Type DWord -Value 1

        Write-Block -Content 'INFO' -Title 'Disabling scheduled tasks...'
        foreach ($task in $tasks) {
            $reg1 = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\Microsoft\Windows\Windows Defender\Windows Defender $task"
            $id = (Get-ItemProperty $reg1 -Name Id -EA 0).Id
            if (!$id) {continue}

            $reg2 = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\$id"
            $file = "$env:SystemRoot\System32\Tasks\Microsoft\Windows\Windows Defender\Windows Defender $task"
            $json = "$work\$task.json"
            $xml = "$work\$task.xml"

            Export-RegState -Path $reg1, $reg2 -JsonPath $json
            copy $file $xml -Force -EA 0

            Edit-Registry -Path $reg1 -Remove
            Edit-Registry -Path $reg2 -Remove
            del $file -Force -EA 0
        }

        Write-Block -Content 'INFO' -Title 'Disabling logs and firewall rules...'
        foreach ($l in $log) {Edit-Registry -Path "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$l" -Name 'Start' -Type DWord -Value 0}
        foreach ($ch in $channels) {Edit-Registry -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\$ch" -Name 'Enabled' -Type DWord -Value 0}
        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Svchost' -Name 'WebThreatDefense' -Remove
        foreach ($key in $rules.Keys) {Edit-Registry -Path $fw -Name $key -Remove}

        Write-Block -Content 'INFO' -Title 'Cleaning up leftover data...'
        del 'HKLM:\SOFTWARE\Microsoft\Windows Security Health\State\Persist' -Recurse -Force 2>&1 | Out-Null
        del "$env:ProgramData\Microsoft\Windows Defender\Scans\mpenginedb.db" -Force 2>&1 | Out-Null
        del "$env:ProgramData\Microsoft\Windows Defender\Scans\History\Service" -Recurse -Force 2>&1 | Out-Null

        Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'SecurityHealth' -Remove

        foreach ($p in $proc) {
            $ifeo = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$p\PerfOptions"
            Edit-Registry -Path $ifeo -Name 'CpuPriorityClass' -Type DWord -Value 1
            Edit-Registry -Path $ifeo -Name 'IoPriority' -Type DWord -Value 0
            Edit-Registry -Path $ifeo -Name 'PagePriority' -Type DWord -Value 0
            Edit-Registry -Path $ifeo -Name 'EcoQoS' -Type DWord -Value 1
            Edit-Registry -Path $ifeo -Name 'WorkingSetLimitInKB' -Type DWord -Value 65536
        }
    }

    # === Refresh Defender state ===
    if (Test-Path "$env:SystemRoot\System32\deviceenroller.exe") {& "$env:SystemRoot\System32\deviceenroller.exe" /ConfigRefresh /o 'enterprise' *>$null}
    Add-Type "using System; using System.Runtime.InteropServices; public class WNF {[DllImport(`"ntdll.dll`")] public static extern int NtUpdateWnfStateData(ref ulong sn, IntPtr buf, int len, IntPtr tid, IntPtr es, int mts, int cs);}"
    try {$data = 0x13920028A3BCF075; $null = [WNF]::NtUpdateWnfStateData([ref]$data, [IntPtr]::Zero, 0, [IntPtr]::Zero, [IntPtr]::Zero, 0, 0)} catch {}
    sc.exe control WinDefend paramchange 2>&1 | Out-Null
}

if ($enable_av) {EnableDefender}
elseif ($disable_av) {DisableDefender}
elseif ($interactive) {AdjustDesign; MainMenu}