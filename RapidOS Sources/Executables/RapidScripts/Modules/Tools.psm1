function LimitNetwork {
    param ([string[]]$Services)

    $sys = "$env:SystemRoot\System32"
    $exe = 'restricted.exe'
    $dest = "$sys\$exe"

    if (!(Test-Path $dest)) {copy "$sys\svchost.exe" $dest -Force}
    & "$env:SystemRoot\RapidScripts\NetBlock.exe" install $dest *>$null

    foreach ($svc in $Services) {
        $reg = "HKLM:\SYSTEM\CurrentControlSet\Services\$svc"
        $val = (Get-ItemProperty $reg -Name ImagePath -EA 0).ImagePath
        
        if ($val -like "*svchost.exe*" -and $val -notlike "*$exe*") {
            $new = $val -replace "svchost\.exe", $exe
            Edit-Registry -Path $reg -Name ImagePath -Value $new
            Write-Host "Service '$svc' now uses restricted svchost." -F DarkGray
        }
    }
}

function Get-Specs {
    param (
        [switch]$OS, [switch]$Build, [switch]$Arch, [switch]$VM,
        [switch]$Laptop, [switch]$CPU, [switch]$Cores, [switch]$Threads,
        [switch]$RAM, [switch]$GPU
    )

    $All = !$PSBoundParameters.Count

    if ($All -or $OS -or $Build -or $CPU -or $Cores -or $RAM) {
        Add-Type @"
        using System; using System.Runtime.InteropServices;
        public class Sys {
            [DllImport("Winbrand.dll", CharSet=CharSet.Unicode)] static extern string BrandingFormatString(string f);
            public static string OS() {return BrandingFormatString("%WINDOWS_LONG%");}
            [DllImport("kernel32")] static extern bool GlobalMemoryStatusEx(ref M b);
            [StructLayout(LayoutKind.Sequential)] public struct M {public uint l; public uint d; public ulong t; public ulong a; public ulong p; public ulong ap; public ulong v; public ulong av; public ulong x;}
            public static ulong RAM() {var m=new M(); m.l=(uint)Marshal.SizeOf(typeof(M)); GlobalMemoryStatusEx(ref m); return m.t;}
            [DllImport("kernel32")] static extern bool GetLogicalProcessorInformation(IntPtr b, ref uint l);
            public static int Cores() {  
                uint l=0; GetLogicalProcessorInformation(IntPtr.Zero, ref l); 
                var b=Marshal.AllocHGlobal((int)l); GetLogicalProcessorInformation(b, ref l);
                int c=0; int s=IntPtr.Size==8?32:24; long p=b.ToInt64(); 
                for(int i=0;i<l;i+=s) if(Marshal.ReadInt32((IntPtr)(p+i+IntPtr.Size))==0) c++; 
                Marshal.FreeHGlobal(b); return c;  
            }
        }
"@ *>$null
    }

    if ($All -or $OS -or $Build) {
        if ([Sys] -as [type]) {
            $_os = [Sys]::OS()
            if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -EA 0) {
                $props = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -EA 0
                $ver = "$($props.CurrentBuild).$($props.UBR)"
            }
        } elseif ($win = Get-CimInstance Win32_OperatingSystem -EA 0) {
            $_os = $win.Caption
            $ver = "$($win.BuildNumber).$($win.UBR)"
        } elseif (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -EA 0) {
            $props = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -EA 0
            $_os = $props.ProductName
            $ver = "$($props.CurrentBuild).$($props.UBR)"
        }
        $full = "$_os (v$ver)"
    }

    if ($All -or $Arch) {
        if ([Environment]::Is64BitOperatingSystem) {
            $arm = (Get-CimInstance Win32_ComputerSystem -EA 0).SystemType -match 'ARM64' -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64'
            $_arch = if ($arm) {'arm64'} else {'x64'}
        } else {
            $_arch = 'x86'
        }
    }

    if ($All -or $CPU -or $Cores -or $Threads) {
        $obj = Get-CimInstance Win32_Processor -EA 0 | Select -First 1
        if ($obj) {
            $_cpu = ($obj.Name -replace '\(R\)|\(TM\)|\s+',' ').Trim()
            $_cores = [Sys]::Cores()
            $_threads = [Environment]::ProcessorCount
        }
    }

    if ($All -or $RAM) {
        $bytes = [Sys]::RAM()
        $_ram = & {[int64]$b=$args[0]; $u='B','KB','MB','GB'; $i=0
            while ($b -gt 1kb -and $i -lt 3) {$b /= 1kb; $i++}
            "{0:N1} $($u[$i])" -f $b
        } $bytes
    }

    if ($All -or $GPU) {
        $_gpu = Get-CimInstance Win32_VideoController -EA 0 | ? {$_.ConfigManagerErrorCode -eq 0} | Select -ExpandProperty Caption -First 1
        if (!$_gpu) {
            $_gpu = Get-PnpDevice -Class Display -EA 0 | ? {$_.FriendlyName -notmatch 'Microsoft|Basic'} | Select -First 1 -ExpandProperty FriendlyName
        }
    }

    if ($All) {
        "OS: $full"
        "Arch: $_arch"
        "VM: $(Test-VM)"
        "Laptop: $(Test-Laptop)"
        "CPU: $_cpu"
        "Cores: $_cores | Threads: $_threads"
        "RAM: $_ram"
        "GPU: $_gpu"
    } else {
        if ($OS) {$full}
        if ($Build) {$ver}
        if ($Arch) {$_arch}
        if ($VM) {Test-VM}
        if ($Laptop) {Test-Laptop}
        if ($CPU) {$_cpu}
        if ($Cores) {$_cores}
        if ($Threads) {$_threads}
        if ($RAM) {$_ram}
        if ($GPU) {$_gpu}
    }
}

function Get-UserPath {
    param (
        [string]$ID = 'B4BFCC3A-DB2C-424C-B029-7FE99A87C641',
        [IntPtr]$Token = -1,
        [int]$Flags = 0x00008000
    )

    $guid = [guid]::new($ID)
    if (!$guid) {Write-Error "Invalid FolderID"}

    Add-Type @'
    using System;
    using System.Runtime.InteropServices;
    public class ShellDir {
        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        public static extern int SHGetKnownFolderPath(
            [MarshalAs(UnmanagedType.LPStruct)] Guid rfid,
            uint dwFlags,
            IntPtr hToken,
            out IntPtr pszPath
        );
    }
'@ *>$null

    $ptr = [IntPtr]::Zero
    $res = [ShellDir]::SHGetKnownFolderPath($guid, $Flags, $Token, [ref]$ptr)

    if ($res -eq 0 -and $ptr -ne [IntPtr]::Zero) {
        $path = [Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
        [Runtime.InteropServices.Marshal]::FreeCoTaskMem($ptr)
        return $path
    }
}

function Invoke-Profile {
    param (
        [scriptblock]$Action,
        [string]$Sid = $null,
        [switch]$All
    )
    
    if ($All -and (Test-Path 'Registry::HKU\AME_UserHive_Default')) {
        @{RegKey = 'Registry::HKU\AME_UserHive_Default'; ProfileDir = $null} | % $Action
    }

    $profs = Get-CimInstance Win32_UserProfile -EA 0
    $users = gci "$env:SystemDrive\Users" -Directory -EA 0 | ? {$_.Name -notin 'Default','Public','All Users','Default User','WDAGUtilityAccount' -and $_.Name -notmatch '^defaultuser'}
    
    foreach ($user in $users) {
        $dir = $user.FullName
        $wp = $profs | ? {$_.LocalPath -eq $dir} | Select -First 1
        
        if (!$wp) {continue}
        if ($Sid -and $wp.SID -ne $Sid) {continue}
        if (!$All -and !$wp.Loaded -and !$Sid) {continue}

        if ($wp.Loaded) {
            @{RegKey = "Registry::HKU\$($wp.SID)"; ProfileDir = $dir} | % $Action
        } else {
            $tag = 'TPL_' + [guid]::NewGuid().Guid.Substring(0, 8)
            reg load "HKU\$tag" "$dir\NTUSER.DAT" *>$null
            
            if ($LASTEXITCODE -eq 0) {
                try {
                    @{RegKey = "Registry::HKU\$tag"; ProfileDir = $dir} | % $Action
                } finally {
                    [GC]::Collect()
                    [GC]::WaitForPendingFinalizers()
                    reg unload "HKU\$tag" *>$null
                }
            }
        }
    }
}

function Test-VM {
    Add-Type @"
    using System; using System.Runtime.InteropServices; using System.Text;
    public static class SysHw {
        [DllImport("kernel32.dll")] public static extern uint GetSystemFirmwareTable(uint p, uint i, IntPtr b, uint s);
        public static string[] GetStrings() {
            uint s = GetSystemFirmwareTable(0x52534D42, 0, IntPtr.Zero, 0);
            if (s == 0) return new string[] {"", ""};
            IntPtr b = Marshal.AllocHGlobal((int)s);
            try {
                GetSystemFirmwareTable(0x52534D42, 0, b, s); byte[] d = new byte[s]; Marshal.Copy(b, d, 0, (int)s);
                for (int i = 0; i < s;) {
                    if (d[i] == 1 && i + 5 < s) return new string[] {GetString(d, i + d[i+1], d[i+4]), GetString(d, i + d[i+1], d[i+5])};
                    i += d[i+1]; while (i < s - 1 && (d[i] != 0 || d[i+1] != 0)) i++; i += 2;
                }
            } finally {Marshal.FreeHGlobal(b);} return new string[] {"", ""};
        }
        private static string GetString(byte[] d, int s, int t) {
            if (t == 0) return ""; int c = 1, i = s;
            while (i < d.Length && c <= t) {
                int e = i; while (e < d.Length && d[e] != 0) e++;
                if (c == t) return Encoding.ASCII.GetString(d, i, e - i);
                i = e + 1; c++;
            } return "";
        }
    }
"@ *>$null

    $data = [SysHw]::GetStrings()
    $list = @('QEMU', 'KVM', 'VirtualBox', 'VBox', 'VMware', 'Parallels', 'Bochs', 'Xen', 'Virtio', 'Red Hat')
    $found = $false
    foreach ($item in $list) {if ($data[0] -match $item -or $data[1] -match $item) {$found = $true; break}}
    $info = (Get-CimInstance -ClassName CIM_ComputerSystem -EA 0).Model
    return ($found -or ($info -match 'Virtual'))
}

function Test-Internet {
    $addr = @("1.1.1.1", "8.8.8.8", "9.9.9.9")
    $port = 443
    $timeout = 500

    foreach ($a in $addr) {
        $tcp = [Net.Sockets.TcpClient]::new()
        try {
            $connect = $tcp.BeginConnect($a, $port, $null, $null)
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

    public static class UIMsg {
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern int MessageBoxW(IntPtr hWnd, string text, string caption, uint type);
        [DllImport("user32.dll")]
        static extern IntPtr GetActiveWindow();
        [DllImport("kernel32.dll")]
        static extern IntPtr GetConsoleWindow();

        const uint MB_YESNO = 0x4,MB_ICONERROR = 0x10,MB_ICONQUESTION = 0x20,MB_ICONWARNING = 0x30,MB_ICONINFORMATION = 0x40,MB_SETFOREGROUND = 0x10000,MB_TOPMOST = 0x40000;

        static uint Icon(string type) {
            switch (type) {
                case "Error": return MB_ICONERROR;
                case "Information": return MB_ICONINFORMATION;
                case "Question": return MB_ICONQUESTION;
                default: return MB_ICONWARNING;
            }
        }
        public static int Show(string message, string title, string type, bool yesno) {
            uint flags = MB_SETFOREGROUND | MB_TOPMOST | Icon(type) | (yesno ? MB_YESNO : 0);
            IntPtr hWnd = GetActiveWindow();
            if (hWnd == IntPtr.Zero) hWnd = GetConsoleWindow();
            int result = MessageBoxW(hWnd, message, title, flags);
            return result != 0 || hWnd == IntPtr.Zero ? result : MessageBoxW(IntPtr.Zero, message, title, flags);
        }
    }
'@ *>$null

    $res = [UIMsg]::Show($Message, $Title, $Type, $YesNo.IsPresent)
    if ($YesNo) {return ($res -eq 6)}
}

function CpuInstructions {
    param (
        [switch]$Table,
        [switch]$Best
    )

    # === CPUID/XGETBV ===
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;

    public static class CpuId {
        [DllImport("kernel32.dll", SetLastError=true)]
        private static extern IntPtr VirtualAlloc(IntPtr lpAddress, UIntPtr dwSize, uint flAllocationType, uint flProtect);

        private const uint MEM_COMMIT = 0x1000;
        private const uint MEM_RESERVE = 0x2000;
        private const uint PAGE_EXECUTE_READWRITE = 0x40;

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate void IdFn(int eax, int ecx, IntPtr pOut);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate ulong XcrFn();

        private static readonly IdFn _id;
        private static readonly XcrFn _xcr;

        static CpuId() {
            byte[] codeId;
            byte[] codeXcr;

            if (Environment.Is64BitProcess) {
                codeId = new byte[] {
                    0x53, 0x8B, 0xC1, 0x8B, 0xCA, 0x0F, 0xA2,
                    0x41, 0x89, 0x00, 0x41, 0x89, 0x58, 0x04,
                    0x41, 0x89, 0x48, 0x08, 0x41, 0x89, 0x50,
                    0x0C, 0x5B, 0xC3
                };
                codeXcr = new byte[] {
                    0x31, 0xC9, 0x0F, 0x01, 0xD0,
                    0x48, 0xC1, 0xE2, 0x20, 0x48, 0x09, 0xD0, 0xC3
                };
            }
            else {
                codeId = new byte[] {
                    0x55, 0x8B, 0xEC, 0x53,
                    0x8B, 0x45, 0x08, 0x8B, 0x4D, 0x0C,
                    0x0F, 0xA2, 0x8B, 0x75, 0x10,
                    0x89, 0x06, 0x89, 0x5E, 0x04,
                    0x89, 0x4E, 0x08, 0x89, 0x56, 0x0C,
                    0x5B, 0x8B, 0xE5, 0x5D, 0xC3
                };
                codeXcr = new byte[] {
                    0x31, 0xC9, 0x0F, 0x01, 0xD0, 0xC3
                };
            }

            IntPtr p1 = VirtualAlloc(IntPtr.Zero, new UIntPtr((uint)codeId.Length),
                                     MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
            Marshal.Copy(codeId, 0, p1, codeId.Length);
            _id = (IdFn)Marshal.GetDelegateForFunctionPointer(p1, typeof(IdFn));

            IntPtr p2 = VirtualAlloc(IntPtr.Zero, new UIntPtr((uint)codeXcr.Length),
                                     MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
            Marshal.Copy(codeXcr, 0, p2, codeXcr.Length);
            _xcr = (XcrFn)Marshal.GetDelegateForFunctionPointer(p2, typeof(XcrFn));
        }

        public static int[] Id(int eax, int ecx) {
            int[] buf = new int[4];
            GCHandle h = GCHandle.Alloc(buf, GCHandleType.Pinned);
            try {_id(eax, ecx, h.AddrOfPinnedObject());}
            finally {h.Free();}
            return buf;
        }

        public static ulong Xcr0() {
            return _xcr();
        }
    }
"@ *>$null

    # === Logic ===
    $id0 = [CpuId]::Id(0,0)
    $max = ($id0[0] -band 0xFFFFFFFF)

    $id1 = if ($max -ge 1) {[CpuId]::Id(1,0)} else {@(0,0,0,0)}
    $ecx1 = ($id1[2] -band 0xFFFFFFFF)

    $sse3 = (($ecx1 -band (1 -shl 0)) -ne 0)
    $sse41 = (($ecx1 -band (1 -shl 19)) -ne 0)
    $sse42 = (($ecx1 -band (1 -shl 20)) -ne 0)
    $sse4 = ($sse41 -or $sse42)

    $osxsave = (($ecx1 -band (1 -shl 27)) -ne 0)
    $avxBit = (($ecx1 -band (1 -shl 28)) -ne 0)
    $xcr0 = 0
    if ($osxsave) {$xcr0 = [CpuId]::Xcr0()}
    $ymmEnable = (($xcr0 -band 0x6) -eq 0x6)

    $id7 = if ($max -ge 7) {[CpuId]::Id(7,0)} else {@(0,0,0,0)}
    $ebx7 = ($id7[1] -band 0xFFFFFFFF)
    $avx2Bit = (($ebx7 -band (1 -shl 5)) -ne 0)

    $avx = ($avxBit -and $osxsave -and $ymmEnable)
    $avx2 = ($avx2Bit -and $osxsave -and $ymmEnable)

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
    param (
        [Parameter(Mandatory = $true)][string]$Repo,
        [string]$Token,
        [switch]$Latest,
        [string]$Tag,
        [switch]$Prerelease,
        [int]$Limit = 0
    )

    $base = "https://api.github.com/repos/$Repo/releases"
    if ($Latest -and !$Tag) {$url = "$base/latest"}
    elseif ($Tag) {$url = "$base/tags/$Tag"}
    else {$url = $base}

    $hdr = @{'User-Agent' = 'PowerShell'}
    if ($Token) {$hdr['Authorization'] = "token $Token"}

    $data = Invoke-RestMethod -Uri $url -Headers $hdr
    if ($Latest -and !($data -is [Collections.IEnumerable])) {$rels = @($data)}
    else {$rels = $data}

    if (!$Prerelease) {$rels = $rels | ? {!$_.prerelease}}
    if ($Limit -gt 0) {$rels = $rels | Select -First $Limit}

    return $rels | % {
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
    $chassis = (Get-CimInstance -ClassName Win32_SystemEnclosure -EA 0).ChassisTypes
    if ($chassis -match '^(8|9|10|11|12|14|18|21|30|31|32)$') {return $true}
    if ($chassis -match '^(3|4|5|6|7|13|35)$') {return $false}

    if ($chassis -match '^(1|2)$') {
        if ((Get-CimInstance -ClassName Win32_ComputerSystem -EA 0).PCSystemType -match '^(2|8)$') {return $true}
    }

    return [bool](Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams -EA 0)
}

function Get-Options {
    $item = Get-Item 'HKLM:\SOFTWARE\RapidOS\Installation\Options' -EA 0
    if (!$item) {return @()}
    @($item.Property)
}

function Refresh {
    param ([switch]$kill)

    $id = [Diagnostics.Process]::GetCurrentProcess().SessionId
    $running = Get-Process explorer -EA 0

    if ($running -and ($running.SessionId -contains $id)) {
        taskkill /f /fi "Session eq $id" /im explorer.exe *>$null
        $i = 0
        while ((Get-Process explorer -EA 0 | ? {$_.SessionId -eq $id}) -and $i -lt 30) {
            Start-Sleep -m 100
            $i++
        }
    }

    if ($kill -or ($env:USERNAME -eq 'defaultuser0')) {return}

    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine="explorer.exe"} *>$null
}

Export-ModuleMember -Function *