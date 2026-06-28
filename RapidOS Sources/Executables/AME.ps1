#Requires -RunAsAdministrator
param ([switch]$Pin, [switch]$Unpin)

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class WinAPI {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc e, IntPtr p);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int c);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
    public delegate bool EnumWindowsProc(IntPtr h, IntPtr p);
}
"@

$script:handles = [Collections.Generic.List[IntPtr]]::new()

$enum = [WinAPI+EnumWindowsProc] {
    param($h, $p)
    if (![WinAPI]::IsWindowVisible($h)) {return $true}
    $sb = [Text.StringBuilder]::new(256)
    [void][WinAPI]::GetWindowText($h, $sb, 256)
    if ($sb.ToString() -notlike '*AME*') {return $true}
    $script:handles.Add($h)
    $true
}

[void][WinAPI]::EnumWindows($enum, [IntPtr]::Zero)

$flag = if ($Pin) {[IntPtr]::new(-1)} else {[IntPtr]::new(-2)}
foreach ($h in $script:handles) {
    [void][WinAPI]::SetWindowPos($h, $flag, 0, 0, 0, 0, 0x0003)
}

$verb = if ($Pin) {'pinned'} else {'unpinned'}
Write-Host "AME Beta window $verb"