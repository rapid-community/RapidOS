param ([string]$User = $env:USERNAME)
if ($User) {
    $valid = try {[bool]([Security.Principal.NTAccount]::new($User).Translate([Security.Principal.SecurityIdentifier]))} catch {$false}
    if ($valid -and $env:USERNAME -ne $User) {return}
}

# === Setup user bypass ===
$sid = (Get-ItemProperty 'HKLM:\SOFTWARE\RapidOS\Installation' -Name 'SetupUser' -EA 0).SetupUser
if ($sid -eq [Security.Principal.WindowsIdentity]::GetCurrent().User.Value) {return}

# === Single instance ===
$valid = $false
$mutex = [Threading.Mutex]::new($true, 'Deferred', [ref]$valid)
if (!$valid) {return}

Add-Type @'
    using System;
    using System.Runtime.InteropServices;

    public static class Deferred {
        [DllImport("user32.dll")] public static extern bool ShutdownBlockReasonCreate(IntPtr hWnd, string reason);
        [DllImport("user32.dll")] public static extern bool ShutdownBlockReasonDestroy(IntPtr hWnd);
        [DllImport("dwmapi.dll", PreserveSig = true)] public static extern int DwmSetWindowAttribute(IntPtr hWnd, int attr, ref int value, int size);
    }
'@

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$base = 'HKLM:\SOFTWARE\RapidOS\Installation\Deferred'
$browser = "$base\Browser"
$root = $PSScriptRoot
$state = 'HKCU:\SOFTWARE\RapidOS\Deferred'
$build = [int](Get-Specs -Build).Split('.')[0]
$dark = (Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -EA 0).AppsUseLightTheme -eq 0
$font = if ([Drawing.FontFamily]::Families.Name -contains 'Segoe UI Variable Text') {'Segoe UI Variable Text'} else {'Segoe UI'}
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$script:ready = $false
function Get-Flag {param ([string]$path, [string]$name) (Get-ItemProperty $path -Name $name -EA 0).$name}
function Test-Done {param ([string]$name) (Get-ItemProperty $state -Name $name -EA 0).$name -eq 1}
function Set-Done {param ([string]$name) Edit-Registry -Path $state -Name $name -Type DWord -Value 1}

$pending = $false
foreach ($item in 'Theme', 'ClassicContextMenu', 'StartMenu', 'Taskbar', 'TaskManager') {
    if ((Get-Flag $base $item) -and !(Test-Done $item)) {$pending = $true; break}
}
if (!$pending) {
    foreach ($item in 'Brave', 'Chrome', 'Firefox', 'Thorium') {
        if ((Get-Flag $browser $item) -and !(Test-Done $item)) {$pending = $true; break}
    }
}
if (!$pending) {return}

$logs = "$env:SystemRoot\RapidScripts\Deferred"
$dir = "$logs\" + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')
mkdir $dir -Force *>$null
Start-Transcript -Path "$dir\$env:USERNAME.log" -Append -Force *>$null

$admin

function Set-Status {
    param ([string]$text, [string]$sub = '', [int]$n = -1)

    Write-Host $text
    $script:status.Text = $text
    $script:details.Text = $sub

    if ($n -ge 0) {
        $n = [Math]::Min([Math]::Max($n, 0), 100)
        $script:barFg.Width = [Math]::Round(($script:barBg.Width * $n) / 100)
    }

    [Windows.Forms.Application]::DoEvents()
}

function Run-Deferred {
    $shell = "$root\Shell.ps1"
    $software = "$root\Software.ps1"

    # === Browsers ===
    $apps = @(
        @{Name = 'Brave'; Args = @('/silent', '/install'); Ext = 'exe'; Optimize = $true}
        @{Name = 'Chrome'; Args = @('/qn'); Ext = 'msi'; Optimize = $true}
        @{Name = 'Firefox'; Args = @('/S', '/ALLUSERS=1'); Ext = 'exe'; Optimize = $true}
        @{Name = 'Thorium'; Args = @('--silent', '--do-not-launch-chrome', '--system-level'); Ext = 'exe'; Optimize = $false}
    )

    foreach ($item in $apps) {
        if (!(Get-Flag $browser $item.Name) -or (Test-Done $item.Name)) {continue}
        Set-Status "Installing $($item.Name)..." 'Running setup' 13

        if ($admin) {
            $data = gci "$env:SystemRoot\RapidScripts\Deferred" -Filter "*$($item.Name)*.$($item.Ext)" -EA 0 | Sort-Object LastWriteTime -Descending | Select -First 1
            if ($data) {
                if ($item.Args.Count -gt 0) {Start-Process -FilePath $data.FullName -ArgumentList $item.Args -Wait -WindowStyle Hidden}
                else {Start-Process -FilePath $data.FullName -Wait -WindowStyle Hidden}
            }
        }

        if ($item.Optimize) {& $software -Software "Optimize-$($item.Name)"}
        Set-Done $item.Name
    }

    # === Theme ===
    if ((Get-Flag $base 'Theme') -and !(Test-Done 'Theme')) {
        Set-Status 'Applying RapidOS theme...' 'Updating wallpapers' 25

        $theme = "$env:SystemRoot\Resources\Themes\RapidOS.theme"
        $lockscreen = "$env:SystemRoot\RapidScripts\Wallpapers\lockscreen.jpg"
        $wallpaper = "$env:SystemRoot\RapidScripts\Wallpapers\desktop.jpg"
        & $shell -Theme $theme -Lockscreen $lockscreen

        $themes = "$env:APPDATA\Microsoft\Windows\Themes"
        copy $wallpaper "$themes\TranscodedWallpaper" -Force
        del "$themes\CachedFiles\*.*" -Force -EA 0
        
        Edit-Registry -Path 'HKCU\Control Panel\Desktop' -Name 'Wallpaper' -Value $wallpaper
        Edit-Registry -Path 'HKCU\Control Panel\Desktop' -Name 'WallpaperStyle' -Value '10'
        Edit-Registry -Path 'HKCU\Control Panel\Desktop' -Name 'TileWallpaper' -Value '0'
        Edit-Registry -Path 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' -Name 'BackgroundType' -Type DWord -Value 0
        
        & $shell -Wallpaper $wallpaper

        Set-Done 'Theme'
    }

    # === Context menu ===
    if ((Get-Flag $base 'ClassicContextMenu') -and !(Test-Done 'ClassicContextMenu')) {
        Set-Status 'Applying classic context menu...' 'Updating explorer settings' 38
        Edit-Registry -Path 'HKCU\SOFTWARE\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' -Name '' -Value ''
        Set-Done 'ClassicContextMenu'
    }

    # === Taskbar ===
    if ((Get-Flag $base 'Taskbar') -and !(Test-Done 'Taskbar')) {
        Set-Status 'Cleaning up taskbar...' 'Removing pinned items' 50

        & $shell -Cleanup Taskbar

        # === Localize File Explorer taskbar pin ===
        $tb = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
        mkdir $tb -Force *>$null
        del "$tb\File Explorer*.lnk" -Force -EA 0
        $ini = "$tb\desktop.ini"
        attrib -s -h $ini 2>&1 | Out-Null
        [IO.File]::WriteAllText($ini, "[LocalizedFileNames]`r`nFile Explorer.lnk=@%SystemRoot%\system32\shell32.dll,-22067`r`n", [Text.UTF8Encoding]::new($false))
        attrib +s +h $ini 2>&1 | Out-Null
        attrib +s $tb 2>&1 | Out-Null

        Set-Done 'Taskbar'
    }

    # === Start Menu ===
    if ((Get-Flag $base 'StartMenu') -and !(Test-Done 'StartMenu')) {
        Set-Status 'Cleaning up start menu...' 'Removing pinned items' 63

        if ($admin -and $build -ge 22000) {
            $q = [char]34
            $arr = @(('{'+$q+'desktopAppId'+$q+':'+$q+'Microsoft.Windows.Explorer'+$q+'}'), ('{'+$q+'packagedAppId'+$q+':'+$q+'windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel'+$q+'}'), ('{'+$q+'packagedAppId'+$q+':'+$q+'Microsoft.WindowsStore_8wekyb3d8bbwe!App'+$q+'}'), ('{'+$q+'packagedAppId'+$q+':'+$q+'Microsoft.WindowsTerminal_8wekyb3d8bbwe!App'+$q+'}'))
            $opts = Get-Options; $sm1 = $env:ProgramData + '\Microsoft\Windows\Start Menu\Programs'; $sm2 = $env:APPDATA + '\Microsoft\Windows\Start Menu\Programs'
            $links = gci $sm1, $sm2 -Filter '*.lnk' -Recurse -EA 0
            function Get-Pin($n, $o, $t, $exes) {$f = ($links | ? {$_.Name -eq $n} | Select -First 1).FullName; if (!$f) {foreach ($exe in $exes) {if ($exe -and (Test-Path $exe)) {$f = $exe; break}}}; if ($f) {if ($f -match '\.exe$') {$lnk = $sm1 + '\' + $n; if (!(Test-Path $lnk)) {$ws = New-Object -ComObject WScript.Shell; $sc = $ws.CreateShortcut($lnk); $sc.TargetPath = $f; $sc.Save()}; $f = $lnk} elseif ($f.StartsWith($sm2)) {$lnk = $sm1 + '\' + $n; copy $f $lnk -Force; $f = $lnk}}; $m = if ($t -eq 'in') {($o -in $opts) -or $f} else {$o -notin $opts}; if ($m -and $f) {$p = $f -replace ('^' + [regex]::Escape(${env:ProgramFiles(x86)})), '%ProgramFiles(x86)%' -replace ('^' + [regex]::Escape($env:ProgramFiles)), '%ProgramFiles%' -replace ('^' + [regex]::Escape($env:LOCALAPPDATA)), '%LOCALAPPDATA%' -replace ('^' + [regex]::Escape($env:SystemRoot)), '%SystemRoot%' -replace ('^' + [regex]::Escape($env:ProgramData)), '%ALLUSERSPROFILE%' -replace ('^' + [regex]::Escape($env:APPDATA)), '%APPDATA%'; '{' + $q + 'desktopAppLink' + $q + ':' + $q + $p.Replace('\', '\\') + $q + '}'}}
            $uwp = 'Microsoft.WindowsCalculator_8wekyb3d8bbwe!App', 'Microsoft.WindowsNotepad_8wekyb3d8bbwe!App', 'Microsoft.Paint_8wekyb3d8bbwe!App'; $lnk = 'Calculator.lnk', 'Notepad.lnk', 'Paint.lnk'
            $exes = @($env:SystemRoot + '\System32\calc.exe', $env:SystemRoot + '\System32\notepad.exe', $env:SystemRoot + '\System32\mspaint.exe')
            for ($i = 0; $i -lt $uwp.Count; $i++) {$pkgName = $uwp[$i].Split('_')[0]; if (Get-AppxPackage -Name $pkgName -EA 0) {$arr += '{' + $q + 'packagedAppId' + $q + ':' + $q + $uwp[$i] + $q + '}'} else {$pin = Get-Pin $lnk[$i] '' 'in' @($exes[$i]); if ($pin) {$arr += $pin}}}
            $pin = Get-Pin 'Microsoft Edge.lnk' 'remove-edge' 'notin' @($env:ProgramFiles + '\Microsoft\Edge\Application\msedge.exe', ${env:ProgramFiles(x86)} + '\Microsoft\Edge\Application\msedge.exe'); if ($pin) {$arr += $pin}
            $pin = Get-Pin 'Brave.lnk' 'install-brave' 'in' @($env:ProgramFiles + '\BraveSoftware\Brave-Browser\Application\brave.exe', $env:LOCALAPPDATA + '\BraveSoftware\Brave-Browser\Application\brave.exe'); if ($pin) {$arr += $pin}
            $pin = Get-Pin 'Firefox.lnk' 'install-firefox' 'in' @($env:ProgramFiles + '\Mozilla Firefox\firefox.exe'); if ($pin) {$arr += $pin}
            $pin = Get-Pin 'Thorium.lnk' 'install-thorium' 'in' @($env:LOCALAPPDATA + '\Thorium\Application\thorium.exe', $env:ProgramFiles + '\Thorium\thorium.exe'); if ($pin) {$arr += $pin}
            $pin = Get-Pin 'Google Chrome.lnk' 'install-chrome' 'in' @($env:ProgramFiles + '\Google\Chrome\Application\chrome.exe', $env:LOCALAPPDATA + '\Google\Chrome\Application\chrome.exe'); if ($pin) {$arr += $pin}
            $defender = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend' -Name Start -EA 0).Start
            if ($null -ne $defender -and $defender -ne 4 -and 'disable-defender' -notin $opts) {$arr += '{'+$q+'packagedAppId'+$q+':'+$q+'Microsoft.SecHealthUI_8wekyb3d8bbwe!SecHealthUI'+$q+'}'}
            $json = '{'+$q+'pinnedList'+$q+':['+($arr -join ',')+']}'
            Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start' -Name 'ConfigureStartPins' -Value $json
            Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start' -Name 'ConfigureStartPins_ProviderSet' -Type DWord -Value 1
        }

        & $shell -Cleanup StartMenu

        # === Reseed taskbar pin from layout ===
        Edit-Registry -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband' -Remove
        Refresh

        Set-Done 'StartMenu'
    }

    # === Task Manager ===
    if ((Get-Flag $base 'TaskManager') -and !(Test-Done 'TaskManager')) {
        Set-Status 'Configuring task manager...' 'Writing settings' 75
        $path = "$env:LOCALAPPDATA\Microsoft\Windows\TaskManager\settings.json"

        if (!(Test-Path $path)) {
            $wshell = New-Object -ComObject WScript.Shell
            $wshell.Run('taskmgr.exe', 0, $false) *>$null
            Start-Sleep -s 5
            taskkill /f /im taskmgr.exe 2>&1 | Out-Null
            Start-Sleep -s 3
        }

        if (Test-Path $path) {
            $i = 0
            while ($i -lt 3) {
                $i++
                $obj = [IO.File]::ReadAllText($path) | ConvertFrom-Json -EA 0
                if ($obj) {
                    $obj | Add-Member -NotePropertyName 'AlwaysOnTop' -NotePropertyValue $true -Force
                    [IO.File]::WriteAllText($path, ($obj | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
                    break
                }
                Start-Sleep -m 500
            }
        }

        Set-Done 'TaskManager'
    }

    # === Defender ===
    if ($admin) {
        if ((Get-Flag $base 'Defender')) {
            Set-Status 'Preparing Defender disable...' 'Staging modifications' 88
            Edit-Registry -Path $base -Name 'Defender' -Remove
            powershell -WindowStyle Hidden -EP Bypass -File "$root\Defender.ps1" -disable_av -silent
        }
    }

    Set-Status 'Finishing up...' 'Almost there' 100
    Start-Sleep -m 700
}

# ==============================
# Form layout
# ==============================
$panel = [Windows.Forms.Panel]@{Dock = 'Fill'}

$title = [Windows.Forms.Label]@{
    Location = [Drawing.Point]::new(20, 22)
    Size     = [Drawing.Size]::new(425, 28)
    Font     = [Drawing.Font]::new('Segoe UI Semibold', 12)
    Text     = 'RapidOS installation'
}

$body = [Windows.Forms.Label]@{
    Location = [Drawing.Point]::new(20, 58)
    Size     = [Drawing.Size]::new(430, 18)
    Text     = 'Please wait while RapidOS finishes setting up this account.'
}

$script:status = [Windows.Forms.Label]@{
    Location = [Drawing.Point]::new(20, 106)
    Size     = [Drawing.Size]::new(430, 22)
    Font     = [Drawing.Font]::new('Segoe UI Semibold', 10)
    Text     = 'Preparing your account...'
}

$script:details = [Windows.Forms.Label]@{
    Location     = [Drawing.Point]::new(20, 130)
    Size         = [Drawing.Size]::new(430, 18)
    AutoEllipsis = $true
}

$script:barBg = [Windows.Forms.Panel]@{
    Location = [Drawing.Point]::new(20, 164)
    Size     = [Drawing.Size]::new(430, 8)
}

$script:barFg = [Windows.Forms.Panel]@{
    Location = [Drawing.Point]::new(0, 0)
    Size     = [Drawing.Size]::new(24, 8)
}

$script:barBg.Controls.Add($script:barFg)
$panel.Controls.AddRange(@($title, $body, $script:status, $script:details, $script:barBg))

$script:form = [Windows.Forms.Form]@{
    Text            = 'RapidOS installation'
    StartPosition   = 'CenterScreen'
    FormBorderStyle = 'FixedDialog'
    ClientSize      = [Drawing.Size]::new(474, 204)
    MaximizeBox     = $false
    MinimizeBox     = $false
    ControlBox      = $false
    ShowIcon        = $false
    ShowInTaskbar   = $false
    TopMost         = $true
    KeyPreview      = $true
    Font            = [Drawing.Font]::new($font, 9)
}
$script:form.Controls.Add($panel)

# === Theme colors ===
if ($dark) {
    $script:form.BackColor = $panel.BackColor = [Drawing.Color]::FromArgb(30, 30, 30)
    $script:barBg.BackColor = [Drawing.Color]::FromArgb(72, 72, 72)
    $script:barFg.BackColor = [Drawing.Color]::FromArgb(96, 165, 250)
    $title.ForeColor = $script:status.ForeColor = [Drawing.Color]::White
    $body.ForeColor = [Drawing.Color]::FromArgb(220, 220, 220)
    $script:details.ForeColor = [Drawing.Color]::FromArgb(170, 170, 170)
} else {
    $script:form.BackColor = $panel.BackColor = [Drawing.Color]::White
    $script:barBg.BackColor = [Drawing.Color]::FromArgb(220, 220, 220)
    $script:barFg.BackColor = [Drawing.Color]::FromArgb(0, 120, 212)
    $title.ForeColor = $script:status.ForeColor = [Drawing.Color]::Black
    $body.ForeColor = [Drawing.Color]::FromArgb(70, 70, 70)
    $script:details.ForeColor = [Drawing.Color]::FromArgb(110, 110, 110)
}

# === Block shutdown / sign-out while we work ===
$script:session = [Microsoft.Win32.SessionEndingEventHandler]{
    param ($s, $e)
    if (!$script:ready) {$e.Cancel = $true}
}
[Microsoft.Win32.SystemEvents]::add_SessionEnding($script:session)

$timer = [Windows.Forms.Timer]@{Interval = 120}

$timer.Add_Tick({
    $timer.Stop()
    try {Run-Deferred} finally {
        if ($script:form.Handle -ne [IntPtr]::Zero) {[void][Deferred]::ShutdownBlockReasonDestroy($script:form.Handle)}
        if ($script:session) {[Microsoft.Win32.SystemEvents]::remove_SessionEnding($script:session)}
        $script:ready = $true
        $script:form.Close()
    }
})

$script:form.Add_Shown({
    $h = $script:form.Handle
    if ($h -ne [IntPtr]::Zero) {
        [void][Deferred]::ShutdownBlockReasonCreate($h, 'RapidOS is still applying settings.')

        if ($build -ge 22000) {
            $v = [int]$dark
            [void][Deferred]::DwmSetWindowAttribute($h, 20, [ref]$v, 4)
            $v = 2
            [void][Deferred]::DwmSetWindowAttribute($h, 33, [ref]$v, 4)
            [void][Deferred]::DwmSetWindowAttribute($h, 38, [ref]$v, 4)
        }

        $script:form.Activate()
        $script:form.BringToFront()
    }
    $timer.Start()
})

$script:form.Add_Deactivate({
    param ($sender, $e)
    if (!$script:ready) {
        $sender.TopMost = $true
        $sender.Activate()
        $sender.BringToFront()
    }
})

$script:form.Add_KeyDown({
    if ($_.Alt -and $_.KeyCode -eq [Windows.Forms.Keys]::F4 -and !$script:ready) {
        $_.Handled = $true
        $_.SuppressKeyPress = $true
    }
})

$script:form.Add_FormClosing({
    if (!$script:ready) {$_.Cancel = $true}
})

[void]$script:form.ShowDialog()
[GC]::KeepAlive($mutex)