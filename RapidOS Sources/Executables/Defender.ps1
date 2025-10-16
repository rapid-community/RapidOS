param (
    [switch]$enable_av,
    [switch]$disable_av,
    [switch]$silent
)
$interactiveMode = (!$enable_av -and !$disable_av) -and !$silent

# === Acquiring the highest privileges ===
$arg = ( 
    ($PSBoundParameters.GetEnumerator() |
        % {
            if ($_.Value -is [switch] -and $_.Value.IsPresent) {"-$($_.Key)"}
            elseif ($_.Value -isnot [switch]) {"-$($_.Key) `"$($_.Value -replace '"','""')`""}
        }
    ) + 
    ($args | % {"`"$($_ -replace '"','""')`""})
) -join ' '

if (!(whoami /user | findstr "S-1-5-18").Length -gt 0) {
    $exe = if ($PSVersionTable.PSVersion.Major -gt 5) {"pwsh.exe"} else {"powershell.exe"}
    $script = if ($MyInvocation.PSCommandPath) {$MyInvocation.PSCommandPath} else {$PSCommandPath}
    RunAsTI $exe "-EP Bypass -File `"$script`" $arg"
    exit
}

# === Check system integrity ===
function CheckSystemIntegrity {
    function HandleError {
        param ($message)
        Write-Host "Error: $message" -F Red
        pause
        if ((Read-Host "Do you want to run 'sfc /scannow' for system recovery? (Y/N)") -match '^(Y|y)$') {
            Write-Host "Starting system scan..." -F Yellow
            [Diagnostics.Process]::Start("cmd.exe","/c sfc /scannow & pause").WaitForExit()
        } else {
            Write-Host "Skipping. Consider reinstalling Windows" -F Red
            pause
        }
        exit
    }

    $ErrorActionPreference = "SilentlyContinue"

    if (!(Get-Command Add-WindowsPackage -EA 0)) {
        if (!(Test-Path "C:\Windows\System32\WindowsPowerShell\v1.0\Modules")) {
            HandleError "Modules directory missing"
        } else {
            HandleError "Add-WindowsPackage not found"
        }
    }

    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\SideBySide" | % {if (!(Test-Path $_)) {HandleError "Missing: $_"}}

    "TrustedInstaller", "wuauserv", "bits", "cryptsvc" | % {if (!(Get-Service $_ -EA 0)) {HandleError "Missing service: $_"}}

    $ErrorActionPreference = "Continue"
}

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
    if ($hwnd -ne [IntPtr]::Zero) {[Win]::ShowWindow($hwnd,0) *>$null}
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class ConsoleManager {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll")]
    public static extern bool SetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFO_EX lpConsoleCurrentFontEx);
    [DllImport("kernel32.dll")]
    public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
    [DllImport("kernel32.dll")]
    public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct CONSOLE_FONT_INFO_EX {
        public uint cbSize;
        public uint nFont;
        public COORD dwFontSize;
        public int FontFamily;
        public int FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)]
        public string FaceName;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct COORD {public short X; public short Y;}
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {public int Left; public int Top; public int Right; public int Bottom;}
    public const int STD_OUTPUT_HANDLE = -11;
    public static void ResizeWindow(int w, int h) {
        MoveWindow(GetConsoleWindow(), 0, 0, w, h, true);
    }
    public static void SetConsoleFont(string name, short size) {
        CONSOLE_FONT_INFO_EX info = new CONSOLE_FONT_INFO_EX();
        info.cbSize = (uint)Marshal.SizeOf(typeof(CONSOLE_FONT_INFO_EX));
        info.FaceName = name;
        info.dwFontSize = new COORD {X = size, Y = size};
        info.FontFamily = 54;
        info.FontWeight = 400;
        SetCurrentConsoleFontEx(GetStdHandle(STD_OUTPUT_HANDLE), false, ref info);
    }
    public static void QuickEditOFF() {
        IntPtr hConIn = GetStdHandle(-10);
        uint m;
        if (GetConsoleMode(hConIn, out m))
            SetConsoleMode(hConIn, (m | 0x80U) & ~0x40U);
    }
    public static void QuickEditON() {
        IntPtr hConIn = GetStdHandle(-10);
        uint m;
        if (GetConsoleMode(hConIn, out m))
            SetConsoleMode(hConIn, (m | 0x40U) & ~0x80U);
    }
}
"@

function AdjustDesign {
    Add-Type -AssemblyName System.Windows.Forms
    $host.PrivateData.WarningBackgroundColor = "Black"
    $host.PrivateData.ErrorBackgroundColor   = "Black"
    $host.PrivateData.VerboseBackgroundColor = "Black"
    $host.PrivateData.DebugBackgroundColor   = "Black"
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
        [int]$Indent          = 0,
        [string]$Content      = '',
        [string]$Title        = '',
        [string]$Description  = '',
        [int]$TitleWidth      = 24,
        [string]$LeftBracket  = '[',
        [string]$RightBracket = ']',
        [string]$Separator    = ' | ',
        [string]$BracketColor = 'Green',
        [string]$ContentColor = 'White',
        [string]$TextColor    = 'White',
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

function CheckDefenderStatus {
    $packageResult = (Get-WindowsPackage -Online | ? {$_.PackageName -like "*AntiBlocker*"})
    $svcResult = (Get-Service -Name WinDefend -EA 0 | Select -ExpandProperty StartType)
    $svcResult = $svcResult -replace "`r`n", ""

    if ($packageResult -or $svcResult -eq "Disabled") {
        $global:status = "disabled"
    } else {
        $global:status = "enabled"
    }
}

$addresses = @("1.1.1.1", "8.8.8.8", "9.9.9.9")
$port = 443
$timeout = 500
$ping = $false
foreach ($address in $addresses) {
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $connect = $tcp.BeginConnect($address, $port, $null, $null)
        if ($connect.AsyncWaitHandle.WaitOne($timeout)) {
            $tcp.EndConnect($connect)
            $tcp.Close()
            $ping = $true
            break
        }
    } catch {}
    $tcp.Close()
}

$file = if (Test-Path "$env:WinDir\DefenderSwitcher") {gci "$env:WinDir\DefenderSwitcher" -Filter "*AntiBlocker*" -File} else {$null}
$programUsable = $false

switch ($true) {
    ($null -eq $file) {
        if ($ping) {
            $dir = "$env:WinDir\DefenderSwitcher"
            $name = "Z-RapidOS-AntiBlocker-Package31bf3856ad364e35amd641.0.0.0.cab"
            $dst = "$dir\$name"
            $url = "https://rapid-community.ru/downloads/$name"
            if (!(Test-Path $dir)) {New-Item $dir -ItemType Directory *>$null}
            Add-MpPreference -ExclusionPath $dir *>$null
            curl.exe -s -o $dst $url *>$null
            if (Test-Path $dst) {$programUsable = $true}
        }
        break
    }
    default {
        $programUsable = $true
        $dir = "$env:WinDir\DefenderSwitcher"
        $name = "Z-RapidOS-AntiBlocker-Package31bf3856ad364e35amd641.0.0.0.cab"
        $dst = "$dir\$name"
        $url = "https://rapid-community.ru/downloads/$name"
        $tmp = "$env:TEMP\$name"
        curl.exe -s -o $tmp $url *>$null
        if ((Test-Path $tmp) -and (Test-Path $dst)) {
            $h1 = (Get-FileHash $tmp).Hash
            $h2 = (Get-FileHash $dst).Hash
            if ($h1 -ne $h2) {Move-Item $tmp $dst -Force} else {Remove-Item $tmp}
        }
        break
    }
}

function MainMenu {
    cls
    CheckDefenderStatus;
    Write-Host "`n`n`n`n"
    Write-Host "         ______________________________________________________________" -F DarkGray
    Write-Host
    Write-Host "                               Defender Switcher"
    Write-Host
    Write-Host "                                Current Status:" -F Yellow
    if ($status -eq "enabled")
    {Write-Host "                          Windows Defender is ENABLED" -F Green}
else{Write-Host "                          Windows Defender's DISABLED" -F Red}
    if ($programUsable -eq $true) 
    {Write-Host "                            Defender can be toggled" -F Green}
else{Write-Host "                            Connect to the Internet" -F Red}
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
    $choice = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
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
    Write-Host ""
    Write-Host "                               Defender Switcher"
    Write-Host ""
    Write-Host "               Credits:" -F Yellow
    Write-Host ""
    Write-Block -Content "1" -Title "AtlasOS CAB method" -Indent 15
    Write-Block -Content "2" -Title "AveYo's TI elevation" -Indent 15
    Write-Block -Content "3" -Title "MAS-Based design" -Indent 15
    Write-Host ""
    Write-Host "               __________________________________________________" -F DarkGray
    Write-Host ""
    Write-Host "               Our links:" -F Yellow
    Write-Host ""
    Write-Block -Content "4" -Title "GitHub" -Indent 15
    Write-Block -Content "5" -Title "Discord" -Indent 15
    Write-Block -Content "6" -Title "Website" -Indent 15
    Write-Host ""
    Write-Host "               __________________________________________________" -F DarkGray
    Write-Host ""
    Write-Host "           Choose a menu option using your keyboard [1,2,3,4,5,6,q] :" -F Green
    Write-Host ""
    Write-Host "         ______________________________________________________________" -F DarkGray
    $choice = ""
    while ($choice -ne 'q') {
        $choice = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown').Character
        switch ($choice) {
            '1' {Start-Process "https://github.com/Atlas-OS/Atlas"}
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
    CheckDefenderStatus;
    switch ($status) {
        "enabled" {
            Write-Block -Content "INFO" -Title "Defender is already enabled."
        }
        default {
            [ConsoleManager]::QuickEditON()
            Write-Block -Content "INFO" -Title "Enabling Defender..."

            reg add "HKLM\SYSTEM\CurrentControlSet\Services\WdFilter\Instances\WdFilter Instance" /v Altitude /t REG_SZ /d 328010 /f *>$null

            Write-Block -Content "PROCESSING" -Title "Removing CAB..."
            $ProgressPreference = "SilentlyContinue"; $WarningPreference = "SilentlyContinue"
            Get-WindowsPackage -Online | ? {$_.PackageName -like "*AntiBlocker*"} | % {
                Remove-WindowsPackage -Online -PackageName $_.PackageName -NoRestart
            } *>$null
            $ProgressPreference = "Continue"; $WarningPreference = "Continue"

            Write-Block -Content "PROCESSING" -Title "Removing RepairSrc..."
            $path = [Environment]::ExpandEnvironmentVariables("%WinDir%\DefenderSwitcher\WinSxS")
            if (Test-Path $path) {del $path -Recurse -Force -EA 0}
            $regKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Servicing"
            if (Test-Path $regKey) {Remove-ItemProperty -Path $regKey -Name "LocalSourcePath" -EA 0}

            CheckDefenderStatus;
            switch ($status) {
                "enabled" {
                    Write-Block -Content "INFO" -Title "Defender has been enabled."
                }
                default {
                    Write-Block -Content "ERROR" -Title "Failed to enable Defender." -ContentColor "Red"
                    Write-Host "`nTry to reboot your PC and try again."
                    Write-Host "If error occurs, try to use program in safe boot with ethernet option."
                    Write-Host "If nothing helped, please, make an issue on GitHub or write in Rapid Community's discord server for help."
                }
            }
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
    CheckDefenderStatus;
    switch ($status) {
        "disabled" {
            Write-Block -Content "INFO" -Title "Defender is already disabled."
        }
        default {
            [ConsoleManager]::QuickEditON()
            if ($programUsable -eq $true) {
                Write-Block -Content "INFO" -Title "Disabling Defender..."

                # === Bypasses Tamper Protection if WdFilter is vulnerable ===
                # https://www.alteredsecurity.com/post/disabling-tamper-protection-and-other-defender-mde-components
                reg delete "HKLM\SYSTEM\CurrentControlSet\Services\WdFilter\Instances\WdFilter Instance" /v Altitude /f *>$null
                reg add "HKLM\SOFTWARE\Microsoft\Windows Defender\Features" /v TamperProtection /t REG_DWORD /d 4 /f *>$null

                ProcessDefender -InstallCAB $true
                ProcessDefender -LinkManifests $true

                CheckDefenderStatus;
                switch ($status) {
                    "disabled" {
                        Write-Block -Content "INFO" -Title "Defender has been disabled."
                    }
                    default {
                        Write-Block -Content "ERROR" -Title "Failed to disable Defender." -ContentColor "Red"
                        Write-Host "---"
                        Write-Host "Try to reboot your PC and try again."
                        Write-Host "If error occurs, try to use program in safe boot with ethernet option."
                        Write-Host "If nothing helped, please, make an issue on GitHub or write in Rapid Community's discord server for help."
                        Write-Host "---"

                        reg add "HKLM\SYSTEM\CurrentControlSet\Services\WdFilter\Instances\WdFilter Instance" /v Altitude /t REG_SZ /d 328010 /f *>$null
                    }
                }
            } else {
                Write-Block -Content "ERROR" -Title "Connect to the internet and restart Defender Switcher to proceed." -ContentColor "Red"
            }
        }
    }
    if ($interactiveMode) {
        pause
        MainMenu
    } else {
        exit
    }
}

function ProcessDefender {
    param ([switch]$InstallCAB, [switch]$LinkManifests)

    if ($InstallCAB) {
        $item = gci "$env:WinDir\DefenderSwitcher" -Filter "*AntiBlocker*" -File
        if (!$item) {return}

        $path = $item.FullName
        $cert = (Get-AuthenticodeSignature $path).SignerCertificate
        if (!$cert -or $cert.Extensions.EnhancedKeyUsages.Value -ne "1.3.6.1.4.1.311.10.3.6") {return}
        
        Write-Block -Content "PROCESSING" -Title "Installing CAB..."

        $ProgressPreference = "SilentlyContinue"
        try {
            Add-WindowsPackage -Online -PackagePath $path -NoRestart -IgnoreCheck -LogLevel 1 *>$null
        } catch {
            Write-Block -Content "PROCESSING" -Title "Using DISM fallback..."
            DISM /Online /Add-Package /PackagePath:$path /NoRestart *>$null
        }
        $ProgressPreference = "Continue"
    }

    if ($LinkManifests) {
        CheckDefenderStatus; if ($status -ne "disabled") {return}

        $version = "38655.38527.65535.65535"
        $src = [Environment]::ExpandEnvironmentVariables("%WinDir%\DefenderSwitcher\WinSxS")
        $list = gci "$env:WinDir\WinSxS\Manifests" -File -Filter "*$version*"
        if (!$list) {return}

        if (Test-Path $src) {del $src -Recurse -Force}
        mkdir "$src\Manifests" -Force *>$null

        Write-Block -Content "PROCESSING" -Title "Linking manifests..."
        $list | % {New-Item -ItemType HardLink -Path "$src\Manifests\$($_.Name)" -Target $_.FullName *>$null}

        $regKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Servicing"
        if (!(Test-Path $regKey)) {mkdir $regKey -Force *>$null}
        Set-ItemProperty -Path $regKey -Name "LocalSourcePath" -Value "%WinDir%\DefenderSwitcher\WinSxS" -Type ExpandString -Force
    }
}

if ($enable_av) {EnableDefender}
if ($disable_av) {DisableDefender}
if ($interactiveMode) {CheckSystemIntegrity; AdjustDesign; MainMenu} else {exit}