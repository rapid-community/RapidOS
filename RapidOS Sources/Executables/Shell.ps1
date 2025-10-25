#Requires -RunAsAdministrator

param (
    [string[]]$Cleanup,
    [string]$Theme,
    [string]$Lockscreen
)

function Clear-Taskbar {
    $unpinVerbBuilder = (New-Object System.Text.StringBuilder 255)
    [WinAPI]::LoadString([WinAPI]::GetModuleHandle('shell32.dll'), 5387, $unpinVerbBuilder, $unpinVerbBuilder.Capacity) *>$null
    $unpinVerb = $unpinVerbBuilder.ToString()

    if ($unpinVerb) {
        $shell = New-Object -ComObject Shell.Application
        $taskbar = $shell.NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}')
        $userPinned = $shell.NameSpace((Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'))

        $edge = $userPinned.Items() | ? {$_.Name -eq 'Microsoft Edge'}
        if ($edge) {($edge.Verbs() | ? {$_.Name -eq $unpinVerb}) | % {$_.DoIt()}}

        $store = $taskbar.Items() | ? {$_.Name -eq 'Microsoft Store'}
        if ($store) {($store.Verbs() | ? {$_.Name -eq $unpinVerb}) | % {$_.DoIt()}}

        $outlook = $taskbar.Items() | ? {$_.Name -match 'Outlook'}
        if ($outlook) {($outlook.Verbs() | ? {$_.Name -eq $unpinVerb}) | % {$_.DoIt()}}

        $copilot = $taskbar.Items() | ? {$_.Name -match 'Copilot'}
        if ($copilot) {($copilot.Verbs() | ? {$_.Name -eq $unpinVerb}) | % {$_.DoIt()}}

        $office = $taskbar.Items() | ? {$_.Name -match 'Office'}
        if ($office) {($office.Verbs() | ? {$_.Name -eq $unpinVerb}) | % {$_.DoIt()}}
    }
}

function Clear-StartMenu {
    taskkill /f /im "StartMenuExperienceHost.exe" *>$null

    $regPattern = 'Volatile Environment|AME_UserHive_'
    $userKeys = gci -Path 'Registry::HKU' | ? {$_.Name -match "S-1-5-21-[\d-]+$|AME_UserHive_"}

    foreach ($userKey in $userKeys) {
        if (!(gci -Path $userKey.PsPath | ? {$_.Name -match $regPattern})) {continue}

        $default = $userKey.Name -match 'AME_UserHive_Default'
        $appData = ''

        if ($default) {
            $guid = [guid]'F1B32785-6FBA-4FCF-9D55-7B8E7F157091'
            $pszPath = [IntPtr]::Zero
            if ([WinAPI]::SHGetKnownFolderPath($guid, 0x8000, -1, [ref]$pszPath) -eq 0) {
                $appData = [Runtime.InteropServices.Marshal]::PtrToStringUni($pszPath)
                [Runtime.InteropServices.Marshal]::FreeCoTaskMem($pszPath)
            }
        }
        else {
            $appData = (Get-ItemProperty "$($userKey.PSPath)\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" -Name 'Local AppData' -EA 0).'Local AppData'
        }

        if ($appData -and (Test-Path $appData)) {
            copy -Path "RapidResources\Layout.xml" -Destination "$appdata\Microsoft\Windows\Shell\LayoutModification.xml" -Force
            if (!$default) {
                gci -Path "$appData\Packages" -Filter *Microsoft.Windows.StartMenuExperienceHost* -Recurse -EA 0 | ? {$_.Name -like 'start*.bin'} | del -Force
            }
        }

        if (!$default) {
            $tileGridPath = "$($userKey.PSPath)\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount"
            if (Test-Path $tileGridPath) {
                gci -Path $tileGridPath -Recurse -EA 0 | ? {$_.Name -match 'start\.tilegrid'} | del -Force -Recurse
            }
        }
        
        Remove-ItemProperty -Path "$($userKey.PSPath)\SOFTWARE\Microsoft\Windows\CurrentVersion\Start" -Name 'Config' -Force -EA 0
    }
}

function Set-Theme {
    $themePath = [System.IO.Path]::GetFullPath($Theme)

if (!('ThemeManagerAPI' -as [type])) {
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
'@
}

    try {
        [ThemeManagerAPI]::ApplyTheme($themePath)
    }
    catch {
        "SystemSettings", "control" | % {taskkill /f /im "$_.exe" *>$null}
        Start-Process -FilePath $themePath
        Start-Sleep -s 10
    }

    if ([System.Environment]::OSVersion.Version.Build -ge 22000) {
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes" -Name "ThemeMRU" -Value "$((@(
            "rapid-dark.theme",
            "rapid-light.theme",
            "dark.theme",
            "aero.theme"
        ) | % {Join-Path $env:WinDir "Resources\Themes\$_"}) -join ';');" -Type String -Force
    }

    "SystemSettings", "control" | % {taskkill /f /im "$_.exe" *>$null}
}

function Set-Lockscreen {
    $temp = Join-Path $env:TEMP "$(New-Guid)$([System.IO.Path]::GetExtension($Lockscreen))"
    copy $Lockscreen $temp -Force

    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime *>$null
        [Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime] *>$null
        [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType=WindowsRuntime] *>$null

        $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? {$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1})[0]
        $asTaskAction = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? {$_.Name -eq 'AsTask' -and !$_.IsGenericMethod -and $_.GetParameters().Count -eq 1})[0]

        $getImgOperation = [Windows.Storage.StorageFile]::GetFileFromPathAsync($temp)
        $img = $asTaskGeneric.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null, @($getImgOperation)).GetAwaiter().GetResult()
        
        $setImgOperation = [Windows.System.UserProfile.LockScreen]::SetImageFileAsync($img)
        $asTaskAction.Invoke($null, @($setImgOperation)).GetAwaiter().GetResult() *>$null
    }
    finally {
        del $temp -Force -EA 0
    }
}

if ($Cleanup) {
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class WinAPI {
    [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr GetModuleHandle(string lpModuleName);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int LoadString(IntPtr hInstance, uint uID, StringBuilder lpBuffer, int nBufferMax);
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern int SHGetKnownFolderPath([MarshalAs(UnmanagedType.LPStruct)] Guid rfid, uint dwFlags, IntPtr hToken, out IntPtr pszPath);
}
"@ -EA 0
}

# ===========================
# Function call based on the argument
# ===========================
$actions = @()
if ($Cleanup) {$actions += $Cleanup}
if ($Theme -and (Test-Path $Theme)) {$actions += 'Theme'}
if ($Lockscreen -and (Test-Path $Lockscreen)) {$actions += 'Lockscreen'}

foreach ($action in $actions) {
    switch ($action) {
        "Taskbar" {Clear-Taskbar}
        "StartMenu" {Clear-StartMenu}
        "Theme" {Set-Theme}
        "Lockscreen" {Set-Lockscreen}
        default {
            Write-Host "Error: Invalid argument `"$action`"" -F Red
        }
    }
}