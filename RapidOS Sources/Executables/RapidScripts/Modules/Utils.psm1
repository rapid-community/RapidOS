function Set-RegistryValue {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)][ValidatePattern('(?i)^HK(CU|LM|CR|U|CC):\\')]$Path,
        [Parameter(Mandatory)][AllowEmptyString()]$Name,
        [Parameter(Mandatory)][ValidateSet('String','ExpandString','Binary','DWORD','MultiString','QWord','Unknown')]$Type,
        [Parameter(Mandatory)][AllowNull()][AllowEmptyString()]$Value
    )

    $hives = @{'HKLM'='LocalMachine'; 'HKCU'='CurrentUser'; 'HKCR'='ClassesRoot'; 'HKU'='Users'; 'HKCC'='CurrentConfig'}
    $root, $subkey = $Path -split ':\\', 2
    $regHive = $hives[$root.ToUpper()]
    $regRoot = [Microsoft.Win32.Registry]::$regHive
    $regKey = $null

    try {
        if ($PSCmdlet.ShouldProcess($Path, 'Create registry key if not exists')) {
            $regKey = $regRoot.OpenSubKey($subkey, $true)
            if (!$regKey) {$regKey = $regRoot.CreateSubKey($subkey)}
        }
        else {
            $regKey = $regRoot.OpenSubKey($subkey, $false)
            if (!$regKey) {return}
        }

        if ($PSCmdlet.ShouldProcess("$Path\$Name", "Set $Type value")) {
            switch ($Type) {
                'Binary' {
                    if ($Value -is [string]) {
                        $bytes = $Value -split '\s+' | ? {$_ -ne ''} | % {[Convert]::ToByte($_, 16)}
                        $Value = [byte[]]$bytes
                    }
                    elseif ($Value -isnot [byte[]]) {$Value = [byte[]]@()}
                    $regKey.SetValue($Name, $Value, [Microsoft.Win32.RegistryValueKind]::Binary)
                }
                'DWORD' {
                    if ($null -eq $Value -or $Value -eq '') {$Value = 0}
                    $intValue = [int]$Value
                    $regKey.SetValue($Name, $intValue, [Microsoft.Win32.RegistryValueKind]::DWord)
                }
                'QWord' {
                    if ($null -eq $Value -or $Value -eq '') {$Value = 0}
                    $ulongValue = [UInt64]$Value
                    $regKey.SetValue($Name, $ulongValue, [Microsoft.Win32.RegistryValueKind]::QWord)
                }
                'MultiString' {
                    if ($null -eq $Value) {$Value = @()}
                    elseif ($Value -is [string]) {$Value = @($Value)}
                    elseif ($Value -isnot [string[]]) {$Value = @([string[]]$Value)}
                    $regKey.SetValue($Name, [string[]]$Value, [Microsoft.Win32.RegistryValueKind]::MultiString)
                }
                'ExpandString' {$regKey.SetValue($Name, [string]$Value, [Microsoft.Win32.RegistryValueKind]::ExpandString)}
                'Unknown' {
                    if ($Value -is [string]) {$Value = [System.Text.Encoding]::UTF8.GetBytes($Value)}
                    elseif ($Value -isnot [byte[]]) {$Value = [byte[]]@()}
                    $regKey.SetValue($Name, $Value, [Microsoft.Win32.RegistryValueKind]::Unknown)
                }
                default {
                    if ($null -eq $Value) {$Value = ''}
                    $regKey.SetValue($Name, [string]$Value, [Microsoft.Win32.RegistryValueKind]::String)
                }
            }
        }
    }
    finally {
        if ($regKey) {$regKey.Dispose()}
    }
}

function Test-VM {
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class VM {
    [DllImport("kernel32.dll")]
    public static extern uint GetSystemFirmwareTable(uint signature, uint tableId, IntPtr buffer, uint size);
    
    public static bool IsVirtualMachine() {
        IntPtr buffer = IntPtr.Zero;
        try {
            uint size = GetSystemFirmwareTable(0x52534D42, 0, IntPtr.Zero, 0);
            if (size == 0) return false;
            
            buffer = Marshal.AllocHGlobal((int)size);
            GetSystemFirmwareTable(0x52534D42, 0, buffer, size);
            
            byte[] data = new byte[size];
            Marshal.Copy(buffer, data, 0, (int)size);
            string smbios = Encoding.ASCII.GetString(data);
            
            string[] vmVendors = {"VMware", "VirtualBox", "KVM", "Xen", "Hyper-V", "qemu"};
            foreach (string vendor in vmVendors)
                if (smbios.Contains(vendor)) return true;

            return false;
        }
        finally {if (buffer != IntPtr.Zero) Marshal.FreeHGlobal(buffer);}
    }
}
"@
    return (
        [VM]::IsVirtualMachine() -or
        ((Get-CimInstance -ClassName CIM_ComputerSystem).Model -match "Virtual")
    )
}

function Test-Internet {
    $addresses = @("1.1.1.1", "8.8.8.8", "9.9.9.9")
    $port = 443
    $timeout = 500

    # === Connection validation ===
    foreach ($address in $addresses) {
        $tcp = New-Object System.Net.Sockets.TcpClient
        try {
            $connect = $tcp.BeginConnect($address, $port, $null, $null)
            if ($connect.AsyncWaitHandle.WaitOne($timeout)) {
                $tcp.EndConnect($connect)
                $tcp.Close()
                return $true
            }
        } catch {}
        $tcp.Close()
    }
    return $false
}

function MessageBox {
    param (
        [string]$Message,
        [string]$Title,
        [ValidateSet('Error', 'Warning', 'Information', 'Question')]
        [string]$Type = 'Warning',
        [switch]$YesNo
    )

Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class Alert {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    static extern int MessageBox(IntPtr hWnd, string text, string caption, uint type);

    const uint MB_OK = 0x0;
    const uint MB_YESNO = 0x4;
    const uint MB_ICONERROR = 0x10;
    const uint MB_ICONWARNING = 0x30;
    const uint MB_ICONINFORMATION = 0x40;
    const uint MB_ICONQUESTION = 0x20;
    const uint MB_TOPMOST = 0x40000;
    const uint MB_SYSTEMMODAL = 0x1000;

    public static int Show(string message, string title, string type, bool yesno) {
        uint flags = MB_TOPMOST | MB_SYSTEMMODAL | (yesno ? MB_YESNO : MB_OK);
        switch (type) {
            case "Error": flags |= MB_ICONERROR; break;
            case "Information": flags |= MB_ICONINFORMATION; break;
            case "Question": flags |= MB_ICONQUESTION; break;
            default: flags |= MB_ICONWARNING; break;
        }
        return MessageBox(IntPtr.Zero, message, title, flags);
    }
}
'@

    $result = [Alert]::Show($Message, $Title, $Type, $YesNo.IsPresent)
    if ($YesNo) {return ($result -eq 6)}
}

function CpuInstructions {
    [CmdletBinding()]
    param (
        [switch]$Table,
        [switch]$Best
    )

    # ==============================
    # Native CPUID/XGETBV loader
    # ==============================
    $ns = 'CpuCheck'; $cls = 'CpuIdNative'; $full = "$ns.$cls"
    $type = $full -as [type]
    if (!$type) {
$code = @"
using System;
using System.Runtime.InteropServices;
using System.Runtime.CompilerServices;

namespace $ns {
    public static class $cls
    {
        [DllImport("kernel32.dll", SetLastError=true)]
        private static extern IntPtr VirtualAlloc(IntPtr lpAddress, UIntPtr dwSize, uint flAllocationType, uint flProtect);

        private const uint MEM_COMMIT = 0x1000;
        private const uint MEM_RESERVE = 0x2000;
        private const uint PAGE_EXECUTE_READWRITE = 0x40;

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate void CpuidFn(int eax, int ecx, IntPtr pOut);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate ulong XgetbvFn();

        private static readonly CpuidFn _cpuid;
        private static readonly XgetbvFn _xgetbv;

        static $cls()
        {
            byte[] codeCpuid;
            byte[] codeXgetbv;

            if (Environment.Is64BitProcess)
            {
                codeCpuid = new byte[] {
                    0x53, 0x8B, 0xC1, 0x8B, 0xCA, 0x0F, 0xA2,
                    0x41, 0x89, 0x00, 0x41, 0x89, 0x58, 0x04,
                    0x41, 0x89, 0x48, 0x08, 0x41, 0x89, 0x50,
                    0x0C, 0x5B, 0xC3
                };
                codeXgetbv = new byte[] {
                    0x31, 0xC9, 0x0F, 0x01, 0xD0,
                    0x48, 0xC1, 0xE2, 0x20, 0x48, 0x09, 0xD0, 0xC3
                };
            }
            else
            {
                codeCpuid = new byte[] {
                    0x55, 0x8B, 0xEC, 0x53,
                    0x8B, 0x45, 0x08, 0x8B, 0x4D, 0x0C,
                    0x0F, 0xA2, 0x8B, 0x75, 0x10,
                    0x89, 0x06, 0x89, 0x5E, 0x04,
                    0x89, 0x4E, 0x08, 0x89, 0x56, 0x0C,
                    0x5B, 0x8B, 0xE5, 0x5D, 0xC3
                };
                codeXgetbv = new byte[] {
                    0x31, 0xC9, 0x0F, 0x01, 0xD0, 0xC3
                };
            }

            IntPtr p1 = VirtualAlloc(IntPtr.Zero, new UIntPtr((uint)codeCpuid.Length),
                                     MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
            Marshal.Copy(codeCpuid, 0, p1, codeCpuid.Length);
            _cpuid = (CpuidFn)Marshal.GetDelegateForFunctionPointer(p1, typeof(CpuidFn));

            IntPtr p2 = VirtualAlloc(IntPtr.Zero, new UIntPtr((uint)codeXgetbv.Length),
                                     MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
            Marshal.Copy(codeXgetbv, 0, p2, codeXgetbv.Length);
            _xgetbv = (XgetbvFn)Marshal.GetDelegateForFunctionPointer(p2, typeof(XgetbvFn));
        }

        public static int[] Cpuid(int eax, int ecx)
        {
            int[] buf = new int[4];
            GCHandle h = GCHandle.Alloc(buf, GCHandleType.Pinned);
            try {_cpuid(eax, ecx, h.AddrOfPinnedObject());}
            finally {h.Free();}
            return buf;
        }

        public static ulong Xgetbv0()
        {
            return _xgetbv();
        }
    }
}
"@
        Add-Type -Language CSharp -TypeDefinition $code -EA 0 *>$null
        $type = $full -as [type]
    }

    if (!$type) {return}

    # ==============================
    # CPUID logic
    # ==============================
    $leaf0 = $type::Cpuid(0,0)
    $maxLeaf = ($leaf0[0] -band 0xFFFFFFFF)

    $leaf1 = if ($maxLeaf -ge 1) {$type::Cpuid(1,0)} else {@(0,0,0,0)}
    $ecx1 = ($leaf1[2] -band 0xFFFFFFFF)

    $sse3 = (($ecx1 -band (1 -shl 0)) -ne 0)
    $sse41 = (($ecx1 -band (1 -shl 19)) -ne 0)
    $sse42 = (($ecx1 -band (1 -shl 20)) -ne 0)
    $sse4 = ($sse41 -or $sse42)

    $osxsave = (($ecx1 -band (1 -shl 27)) -ne 0)
    $avxBit = (($ecx1 -band (1 -shl 28)) -ne 0)
    $xcr0 = 0
    if ($osxsave) {$xcr0=$type::Xgetbv0()}
    $ymmEnable = (($xcr0 -band 0x6) -eq 0x6)

    $leaf7 = if ($maxLeaf -ge 7) {$type::Cpuid(7,0)} else {@(0,0,0,0)}
    $ebx7 = ($leaf7[1] -band 0xFFFFFFFF)
    $avx2Bit = (($ebx7 -band (1 -shl 5)) -ne 0)

    $avx = ($avxBit -and $osxsave -and $ymmEnable)
    $avx2 = ($avx2Bit -and $osxsave -and $ymmEnable)

    # ==============================
    # Output
    # ==============================
    if ($Table) {
        @(
            [PSCustomObject]@{Architecture = 'SSE3'; Supported = if ($sse3) {'Yes'} else {'No'}}
            [PSCustomObject]@{Architecture = 'SSE4'; Supported = if ($sse4) {'Yes'} else {'No'}}
            [PSCustomObject]@{Architecture = 'AVX';  Supported = if ($avx)  {'Yes'} else {'No'}}
            [PSCustomObject]@{Architecture = 'AVX2'; Supported = if ($avx2) {'Yes'} else {'No'}}
        )
        return
    }

    if ($Best) {
        switch ($true) {
            {$avx2} {return 'AVX2'}
            {$avx}  {return 'AVX'}
            {$sse4} {return 'SSE4'}
            {$sse3} {return 'SSE3'}
            default {return 'None'}
        }
    }
}

function ParseGit {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$Repo,
        [string]$Token,
        [switch]$Latest,
        [string]$Tag,
        [switch]$Prerelease,
        [int]$Limit = 0
    )

    # $Token = "..."
    $base = "https://api.github.com/repos/$Repo/releases"
    if ($Latest -and !$Tag) {$url = "$base/latest"}
    elseif ($Tag) {$url = "$base/tags/$Tag"}
    else {$url = $base}

    $headers = @{'User-Agent' = 'PowerShell'}
    if ($Token) {$headers['Authorization'] = "token $Token"}

    $data = Invoke-RestMethod -Uri $url -Headers $headers

    if ($Latest -and !($data -is [System.Collections.IEnumerable])) {
        $releases = @($data)
    } else {
        $releases = $data
    }
    if (!$Prerelease) {
        $releases = $releases | ? {!$_.prerelease}
    }
    if ($Limit -gt 0) {
        $releases = $releases | Select -First $Limit
    }

    return $releases | % {
        [PSCustomObject]@{
            Tag    = $_.tag_name
            Name   = $_.name
            Date   = $_.published_at
            Url    = $_.html_url
            Assets = @($_.assets | % {$_.browser_download_url})
        }
    }
}

function Test-Laptop {
    $laptopTypes = @(
        8,   # Portable
        9,   # Laptop
        10,  # Notebook
        11,  # Hand Held
        12,  # Docking Station
        14,  # Sub Notebook
        13,  # All in One
        30,  # Tablet
        31,  # Convertible
        32   # Detachable
    )

    $chassisTypes = (Get-CimInstance Win32_SystemEnclosure -EA 0).ChassisTypes
    ($laptopTypes | ? {$chassisTypes -contains $_}).Count -gt 0
}

Export-ModuleMember -Function Set-RegistryValue, Test-VM, Test-Internet, MessageBox, CpuInstructions, ParseGit, Test-Laptop