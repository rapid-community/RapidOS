#Requires -RunAsAdministrator

param (
    [Parameter(Mandatory = $true)]
    [string]$Name
)

Add-Type -ReferencedAssemblies 'System.Management.dll' -Language CSharp -TypeDefinition @"
using System.Management;
using System.Runtime.InteropServices;
public class RP {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    struct RPINFO {
        public int eventType, restorePtType;
        public long seqNumber;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string desc;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct SMSTATUS {public int status; public long seqNumber;}
    [DllImport("srclient.dll", CharSet=CharSet.Unicode)]
    static extern bool SRSetRestorePoint(ref RPINFO rpInfo, out SMSTATUS status);
    public static bool Create(string desc) {
        try {
            var scope = new ManagementScope(@"\\.\root\default");
            scope.Connect();
            var mc = new ManagementClass(scope, new ManagementPath("SystemRestore"), null);
            var param = mc.GetMethodParameters("Enable");
            param["Drive"] = "C:\\";
            mc.InvokeMethod("Enable", param, null);
        } catch {}
        RPINFO info = new RPINFO {eventType=100, restorePtType=0, seqNumber=0, desc=desc};
        SMSTATUS status;
        if (!SRSetRestorePoint(ref info, out status)) return false;
        info.eventType = 101;
        return SRSetRestorePoint(ref info, out status);
    }
}
"@

$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\VSS'
if (!(Test-Path $regPath)) {
    Write-Host "VSS service not found. Restore points cannot be created."
    return
}
$startType = Get-ItemProperty -Path $regPath -Name Start -EA 0
if ($startType.Start -eq 4) {
    Set-RegistryValue -Path $regPath -Name Start -Type DWORD -Value 3
}; Start-Service -Name VSS *>$null
Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore' -Name 'DisableConfig' -EA 0
Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore' -Name 'DisableSR' -EA 0

Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name SystemRestorePointCreationFrequency -Type DWORD -Value 0
Enable-ComputerRestore -Drive "C:\" *>$null
vssadmin.exe resize shadowstorage /for=C: /on=C: /maxsize=5GB *>$null
[RP]::Create("$Name") *>$null
Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name SystemRestorePointCreationFrequency -Type DWORD -Value 1440