param (
    [string[]]$Cleanup,
    [string]$Theme,
    [string]$Lockscreen,
    [string]$Wallpaper
)

function Clear-Taskbar {
    Add-Type @'
    using System;
    using System.Runtime.InteropServices;
    using System.Text;
    public static class WinAPI {
        [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
        public static extern IntPtr GetModuleHandle(string lpModuleName);
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int LoadString(IntPtr hInstance, uint uID, StringBuilder lpBuffer, int nBufferMax);
    }
'@ *>$null

    $ids = 'WindowsStore', 'OutlookForWindows', 'Copilot', 'OfficeHub'
    $path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband'
    $cloudstore = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store'

    $sb = [Text.StringBuilder]::new(255)
    [WinAPI]::LoadString([WinAPI]::GetModuleHandle('shell32.dll'), 5387, $sb, $sb.Capacity) *>$null
    $verb = $sb.ToString()
    if (!$verb) {return}

    # === Unpin from taskbar ===
    $shell = New-Object -ComObject Shell.Application
    $pinned = $shell.NameSpace("$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar")

    if ($pinned) {
        $edge = $pinned.Items() | ? {$_.Name -match 'Edge'}
        if ($edge) {$edge | % {$_.Verbs() | ? {$_.Name -eq $verb} | % {$_.DoIt()}}}
    }

    $taskbar = $shell.NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}')
    if ($taskbar) {
        $names = 'Store', 'Outlook', 'Copilot', 'Office'
        foreach ($name in $names) {
            $item = $taskbar.Items() | ? {$_.Name -match $name}
            if ($item) {$item | % {$_.Verbs() | ? {$_.Name -eq $verb} | % {$_.DoIt()}}}
        }
    }

    # === Clean registry ===
    $restart = $false
    $data = (Get-ItemProperty -Path $path -Name 'Favorites' -EA 0).Favorites
    if ($data) {
        $changed = $false
        foreach ($id in $ids) {
            foreach ($enc in @([Text.Encoding]::Unicode, [Text.Encoding]::ASCII)) {
                $search = $enc.GetBytes($id)
                $replace = $enc.GetBytes(' ' * $id.Length)
                $idx = 0
                
                while (($idx = [Array]::IndexOf($data, $search[0], $idx)) -ge 0) {
                    if ($idx + $search.Length -gt $data.Length) {break}
                    $match = $true
                    for ($j = 1; $j -lt $search.Length; $j++) {
                        if ($data[$idx + $j] -ne $search[$j]) {$match = $false; break}
                    }
                    
                    if ($match) {
                        for ($j = 0; $j -lt $replace.Length; $j++) {$data[$idx + $j] = $replace[$j]}
                        $changed = $true
                        $idx += $replace.Length
                    } else {$idx++}
                }
            }
        }
        if ($changed) {
            Edit-Registry -Path $path -Name 'Favorites' -Type Binary -Value $data
            $restart = $true
        }
    }

    # === Clean CloudStore ===
    if (Test-Path $cloudstore) {
        $pattern = '(' + ($ids -join '|') + ')'
        gci "$cloudstore\Cache\DefaultAccount" -Recurse -EA 0 | % {
            $val = (Get-ItemProperty $_.PSPath -Name 'Data' -EA 0).Data
            if ($val) {
                $str = [Text.Encoding]::Unicode.GetString($val) -replace '[^\x20-\x7E]', '.'
                if ($str -match $pattern) {
                    del $_.PSPath -Recurse -Force -EA 0
                    $restart = $true
                }
            }
        }
    }

    Refresh
}

function Clear-StartMenu {
    taskkill /f /im StartMenuExperienceHost.exe 2>&1 | Out-Null

    $pkg = gci "$env:LOCALAPPDATA\Packages" -Directory -EA 0 | ? {$_.Name -match 'StartMenuExperienceHost'}
    if ($pkg) {del "$($pkg.FullName)\LocalState\*.bin" -Force -EA 0}

    $build = [int](Get-Specs -Build).Split('.')[0]

    $layout = @"
<LayoutModificationTemplate
  xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout"
  xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout"
  xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" Version="1"
  xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification">
  <LayoutOptions StartTileGroupCellWidth="6" />
$(if ($build -lt 22000) {'  <DefaultLayoutOverride><StartLayoutCollection><defaultlayout:StartLayout GroupCellWidth="6" /></StartLayoutCollection></DefaultLayoutOverride>'})
  <CustomTaskbarLayoutCollection PinListPlacement="Replace">
    <defaultlayout:TaskbarLayout>
      <taskbar:TaskbarPinList>
        <taskbar:DesktopApp DesktopApplicationLinkPath="%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\File Explorer.lnk" />
      </taskbar:TaskbarPinList>
    </defaultlayout:TaskbarLayout>
  </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@

    $shell = "$env:LOCALAPPDATA\Microsoft\Windows\Shell"
    [IO.File]::WriteAllText("$shell\LayoutModification.xml", $layout, [Text.UTF8Encoding]::new($false))

    gci 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount' -Recurse -EA 0 | ? {$_.PSChildName -match 'start\.tilegrid'} | del -Force -Recurse -EA 0
    Edit-Registry -Path 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Start' -Name 'Config' -Remove
}

function Set-Theme {
    $theme = [IO.Path]::GetFullPath($Theme)

    Add-Type @'
    using System;
    using System.Runtime.CompilerServices;
    using System.Runtime.InteropServices;
    public static class ThemeManagerAPI {
        public static void ApplyTheme(string themeFilePath) {
            IThemeManager themeManager = new ThemeManagerClass();
            themeManager.ApplyTheme(themeFilePath);
        }
        [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        [Guid("D23CC733-5522-406D-8DFB-B3CF5EF52A71")]
        [ComImport]
        public interface ITheme {}
        [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        [Guid("0646EBBE-C1B7-4045-8FD0-FFD65D3FC792")]
        [ComImport]
        public interface IThemeManager {
            [DispId(1610678272)]
            ITheme CurrentTheme {get;}
            [MethodImpl(MethodImplOptions.InternalCall, MethodCodeType = MethodCodeType.Runtime)]
            void ApplyTheme([MarshalAs(UnmanagedType.BStr)] string themeFilePath);
        }
        [TypeLibType(TypeLibTypeFlags.FCanCreate)]
        [Guid("C04B329E-5823-4415-9C93-BA44688947B0")]
        [ClassInterface(ClassInterfaceType.None)]
        [ComImport]
        public class ThemeManagerClass : IThemeManager {
            [DispId(1610678272)]
            public virtual extern ITheme CurrentTheme {[MethodImpl(MethodImplOptions.InternalCall, MethodCodeType = MethodCodeType.Runtime)] get;}
            [MethodImpl(MethodImplOptions.InternalCall, MethodCodeType = MethodCodeType.Runtime)]
            public virtual extern void ApplyTheme([MarshalAs(UnmanagedType.BStr)] string themeFilePath);
        }
    }
'@ *>$null

    try {
        [ThemeManagerAPI]::ApplyTheme($theme)
    } catch {
        'SystemSettings', 'control' | % {taskkill /f /im "$_.exe" 2>&1 | Out-Null}
        & $theme
    }
    Start-Sleep -s 10

    'SystemSettings', 'control' | % {taskkill /f /im "$_.exe" 2>&1 | Out-Null}
}

function Set-Lockscreen {
    $state = 'HKLM:\SOFTWARE\RapidOS\Installation'
    $valsrc = 'LockScreen_SourceHash'
    $valsys = 'LockScreen_SystemHash'

    if (!(Test-Path $Lockscreen)) {return}

    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Lockscreen)
    $srchash = [BitConverter]::ToString($sha.ComputeHash($stream)) -replace '-'
    $stream.Dispose()

    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    [Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime] *>$null
    [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType=WindowsRuntime] *>$null
    [Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType=WindowsRuntime] *>$null

    $astaskgen = ([WindowsRuntimeSystemExtensions].GetMethods() | ? {$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1})[0]
    $astaskact = ([WindowsRuntimeSystemExtensions].GetMethods() | ? {$_.Name -eq 'AsTask' -and !$_.IsGenericMethod -and $_.GetParameters().Count -eq 1})[0]

    $syshash = $null
    try {
        $curstream = [Windows.System.UserProfile.LockScreen]::GetImageStream()
        if ($curstream) {
            $reader = [Windows.Storage.Streams.DataReader]::new($curstream.GetInputStreamAt(0))
            $loadop = $reader.LoadAsync($curstream.Size)
            $null = $astaskgen.MakeGenericMethod([uint32]).Invoke($null, @($loadop)).GetAwaiter().GetResult()

            $sysbytes = [byte[]]::new($curstream.Size)
            $reader.ReadBytes($sysbytes)
            $syshash = [BitConverter]::ToString($sha.ComputeHash($sysbytes)) -replace '-'
            $curstream.Dispose()
        }
    } catch {$syshash = 'UNKNOWN'}

    if (Test-Path $state) {
        $lastsrc = (Get-ItemProperty $state -Name $valsrc -EA 0).$valsrc
        $lastsys = (Get-ItemProperty $state -Name $valsys -EA 0).$valsys
        if ($srchash -eq $lastsrc -and $syshash -eq $lastsys) {
            $sha.Dispose()
            return
        }
    }

    $temp = "$env:TEMP\$(New-Guid)$([IO.Path]::GetExtension($Lockscreen))"
    copy $Lockscreen $temp -Force

    try {
        $getop = [Windows.Storage.StorageFile]::GetFileFromPathAsync($temp)
        $img = $astaskgen.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null, @($getop)).GetAwaiter().GetResult()

        $setop = [Windows.System.UserProfile.LockScreen]::SetImageFileAsync($img)
        $astaskact.Invoke($null, @($setop)).GetAwaiter().GetResult() *>$null

        $finalhash = $null
        try {
            $newstream = [Windows.System.UserProfile.LockScreen]::GetImageStream()
            if ($newstream) {
                $reader = [Windows.Storage.Streams.DataReader]::new($newstream.GetInputStreamAt(0))
                $loadop = $reader.LoadAsync($newstream.Size)
                $null = $astaskgen.MakeGenericMethod([uint32]).Invoke($null, @($loadop)).GetAwaiter().GetResult()

                $newbytes = [byte[]]::new($newstream.Size)
                $reader.ReadBytes($newbytes)
                $finalhash = [BitConverter]::ToString($sha.ComputeHash($newbytes)) -replace '-'
                $newstream.Dispose()
            }
        } catch {}

        Edit-Registry -Path $state -Name $valsrc -Value $srchash
        if ($finalhash) {Edit-Registry -Path $state -Name $valsys -Value $finalhash}
    } finally {
        del $temp -Force -EA 0
        $sha.Dispose()
    }
}

function Set-Wallpaper {
    $path = [IO.Path]::GetFullPath($Wallpaper)

    Add-Type @'
    using System.Runtime.InteropServices;
    public static class WallpaperAPI {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    }
'@ *>$null

    [WallpaperAPI]::SystemParametersInfo(20, 0, $path, 3) *>$null
}

$actions = @()
if ($Cleanup) {$actions += $Cleanup}
if ($Theme -and (Test-Path $Theme)) {$actions += 'Theme'}
if ($Lockscreen -and (Test-Path $Lockscreen)) {$actions += 'Lockscreen'}
if ($Wallpaper -and (Test-Path $Wallpaper)) {$actions += 'Wallpaper'}

foreach ($action in $actions) {
    switch ($action) {
        'Taskbar' {Clear-Taskbar}
        'StartMenu' {Clear-StartMenu}
        'Theme' {Set-Theme}
        'Lockscreen' {Set-Lockscreen}
        'Wallpaper' {Set-Wallpaper}
        default {Write-Host "Error: Invalid argument `"$action`"" -F Red}
    }
}