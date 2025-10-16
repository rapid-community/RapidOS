#Requires -RunAsAdministrator

param (
    [switch]$Pin,
    [switch]$Unpin
)

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class WinAPI {
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_SHOWWINDOW = 0x0040;
}
"@

$ameWindows = New-Object System.Collections.Generic.List[IntPtr]
$callback = [WinAPI+EnumWindowsProc] {
    param ([IntPtr]$hWnd, [IntPtr]$lParam)
    if ([WinAPI]::IsWindowVisible($hWnd)) {
        $titleLen = [WinAPI]::GetWindowTextLength($hWnd)
        if ($titleLen -gt 0) {
            $sb = New-Object System.Text.StringBuilder($titleLen + 1)
            [WinAPI]::GetWindowText($hWnd, $sb, $sb.Capacity)
            if ($sb.ToString() -like "*AME*") {
                $ameWindows.Add($hWnd)
            }
        }
    }
    return $true
}

[WinAPI]::EnumWindows($callback, [IntPtr]::Zero) *>$null

if ($pin) {
    $hWndInsertAfter = [WinAPI]::HWND_TOPMOST
    $action = "pinned"
} elseif ($unpin) {
    $hWndInsertAfter = [WinAPI]::HWND_NOTOPMOST
    $action = "unpinned"
}

$failed = 0
$ameWindows | % {
    $success = [WinAPI]::SetWindowPos($_, $hWndInsertAfter, 0, 0, 0, 0, 
        [WinAPI]::SWP_NOMOVE -bor [WinAPI]::SWP_NOSIZE -bor [WinAPI]::SWP_SHOWWINDOW)
    if (!$success) {$failed++}
}

if ($failed -eq 0) {
    Write-Host "AME Beta windows $action" -F Green
} else {
    Write-Warning "Failed to $action AME Beta window"
}