$script:hives = @{
    HKLM = @{Root = [Microsoft.Win32.Registry]::LocalMachine; Name = 'HKLM'}
    HKEY_LOCAL_MACHINE = @{Root = [Microsoft.Win32.Registry]::LocalMachine; Name = 'HKLM'}
    HKCU = @{Root = [Microsoft.Win32.Registry]::CurrentUser; Name = 'HKCU'}
    HKEY_CURRENT_USER = @{Root = [Microsoft.Win32.Registry]::CurrentUser; Name = 'HKCU'}
    HKCR = @{Root = [Microsoft.Win32.Registry]::ClassesRoot; Name = 'HKCR'}
    HKEY_CLASSES_ROOT = @{Root = [Microsoft.Win32.Registry]::ClassesRoot; Name = 'HKCR'}
    HKU = @{Root = [Microsoft.Win32.Registry]::Users; Name = 'HKU'}
    HKEY_USERS = @{Root = [Microsoft.Win32.Registry]::Users; Name = 'HKU'}
    HKCC = @{Root = [Microsoft.Win32.Registry]::CurrentConfig; Name = 'HKCC'}
    HKEY_CURRENT_CONFIG = @{Root = [Microsoft.Win32.Registry]::CurrentConfig; Name = 'HKCC'}
}

$script:types = @{
    STRING = 'String'; REG_SZ = 'String'; '1' = 'String'
    EXPANDSTRING = 'ExpandString'; REG_EXPAND_SZ = 'ExpandString'; '2' = 'ExpandString'
    BINARY = 'Binary'; REG_BINARY = 'Binary'; '3' = 'Binary'
    DWORD = 'DWord'; REG_DWORD = 'DWord'; '4' = 'DWord'
    MULTISTRING = 'MultiString'; REG_MULTI_SZ = 'MultiString'; '7' = 'MultiString'
    QWORD = 'QWord'; REG_QWORD = 'QWord'; '11' = 'QWord'
}

function Edit-Registry {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Set')]
    param (
        [Parameter(Mandatory, Position = 0)][string]$Path,
        [Parameter(ParameterSetName = 'Set', Mandatory, Position = 1)]
        [Parameter(ParameterSetName = 'Remove', Position = 1)][AllowEmptyString()][string]$Name,
        [Parameter(ParameterSetName = 'Set')][string]$Type = 'String',
        [Parameter(ParameterSetName = 'Set', Position = 2)][AllowNull()]$Value,
        [Parameter(ParameterSetName = 'Remove')][switch]$Remove
    )

    process {
        $Path = ($Path -replace '^(?i)Registry::', '').Replace('/', '\')
        $parts = $Path -split '[:\\/]+', 2
        $rootkey = [string]$parts[0].ToUpperInvariant()
        $entry = $script:hives[$rootkey]
        $sub = if ($parts.Count -gt 1) {$parts[1].Trim('\').Replace('/', '\')} else {''}

        if (!$entry -or !$sub) {Write-Error 'ERROR: Invalid key name.'; return}

        $root = $entry.Root
        $target = if (!$PSBoundParameters.ContainsKey('name')) {$Path} elseif ($Name -eq '') {"$Path\(Default)"} else {"$Path\$Name"}

        $sync = $false; $syncsub = $null
        if ($rootkey -eq 'HKCU' -or $rootkey -eq 'HKEY_CURRENT_USER') {
            $probe = [Microsoft.Win32.Registry]::Users.OpenSubKey('AME_UserHive_Default')
            if ($probe) {
                $sync = $true
                $syncsub = if ($sub) {"AME_UserHive_Default\$sub"} else {'AME_UserHive_Default'}
                $probe.Dispose()
            }
        }
        $syncroot = [Microsoft.Win32.Registry]::Users
        $key = $null; $synckey = $null; $msg = $null

        if ($Remove) {
            if (!$PSBoundParameters.ContainsKey('name')) {
                if ($PSCmdlet.ShouldProcess($Path)) {
                    try {$root.DeleteSubKeyTree($sub, $false)} catch {}
                    if ($sync) {try {$syncroot.DeleteSubKeyTree($syncsub, $false)} catch {}}
                }
                return
            }

            try {
                if ($PSCmdlet.ShouldProcess($target)) {
                    $key = $root.OpenSubKey($sub, $true); if ($sync) {$synckey = $syncroot.OpenSubKey($syncsub, $true)}
                    if ($key) {$key.DeleteValue($Name, $false)}; if ($synckey) {$synckey.DeleteValue($Name, $false)}
                }
            } catch {$msg = $_.Exception.Message} finally {if ($key) {$key.Dispose()}; if ($synckey) {$synckey.Dispose()}}
            if ($msg) {Write-Error $msg}
            return
        }

        $typename = $script:types[[string]$Type.ToUpperInvariant()]
        if (!$typename) {Write-Error 'ERROR: Invalid syntax. Specify valid registry type.'; return}

        $kind = $null; $data = $null

        switch ($typename) {
            'String' {$kind = [Microsoft.Win32.RegistryValueKind]::String; $data = [string]$Value}
            'ExpandString' {$kind = [Microsoft.Win32.RegistryValueKind]::ExpandString; $data = [string]$Value}

            'MultiString' {
                $kind = [Microsoft.Win32.RegistryValueKind]::MultiString
                if ($null -eq $Value) {$data = [string[]]@()}
                elseif ($Value -is [string[]]) {$data = $Value}
                elseif ($Value -is [string] -or !($Value -is [Collections.IEnumerable])) {$data = [string[]]@([string]$Value)}
                else {$data = [string[]]@($Value | % {[string]$_})}
            }

            'Binary' {
                $kind = [Microsoft.Win32.RegistryValueKind]::Binary
                if ($null -eq $Value) {$data = [byte[]]@()}
                elseif ($Value -is [byte[]]) {$data = $Value}
                elseif ($Value -is [string]) {
                    $list = [Collections.Generic.List[byte]]::new()
                    foreach ($item in ($Value -split '[,\s;:\-]+' | ? {$_})) {
                        $hex = $item -replace '^(?i)\+?0x', ''
                        if ($hex -notmatch '^[0-9a-fA-F]+$') {$msg = 'ERROR: Invalid syntax. Specify valid hex value.'; break}
                        if ($hex.Length % 2) {$hex = '0' + $hex}
                        for ($i = 0; $i -lt $hex.Length; $i += 2) {$list.Add([Convert]::ToByte($hex.Substring($i, 2), 16))}
                    }
                    if (!$msg) {$data = $list.ToArray()}
                }
                elseif ($Value -is [Collections.IEnumerable]) {
                    $list = [Collections.Generic.List[byte]]::new()
                    try {foreach ($item in $Value) {$list.Add([byte]$item)}; $data = $list.ToArray()}
                    catch {$msg = 'ERROR: Invalid syntax. Specify valid binary data.'}
                }
                else {try {$data = [byte[]]@([byte]$Value)} catch {$msg = 'ERROR: Invalid syntax. Specify valid byte value.'}}
            }

            default {
                $isq = $typename -eq 'QWord'
                $kind = if ($isq) {[Microsoft.Win32.RegistryValueKind]::QWord} else {[Microsoft.Win32.RegistryValueKind]::DWord}
                $text = if ($null -eq $Value) {'0'} else {([string]$Value).Trim()}
                if (!$text) {$text = '0'}

                try {
                    if ($text -match '^([+-]?)0x([0-9a-fA-F]+)$') {
                        $n = [Convert]::ToUInt64($matches[2], 16)
                        if ($matches[1] -eq '-') {
                            if ($isq) {$data = if ($n -eq [uint64]9223372036854775808) {[int64]::MinValue} else {-[int64]$n}}
                            else {$data = if ($n -eq [uint64]2147483648) {[int32]::MinValue} else {[int32](-[int64]$n)}}
                        } elseif ($isq) {$data = [BitConverter]::ToInt64([BitConverter]::GetBytes($n), 0)}
                        else {$data = [BitConverter]::ToInt32([BitConverter]::GetBytes([uint32]$n), 0)}
                    } elseif ($text.StartsWith('-')) {
                        if ($isq) {$data = [int64]$text} else {$data = [int32]$text}
                    } elseif ($isq) {$data = [BitConverter]::ToInt64([BitConverter]::GetBytes([uint64]$text), 0)}
                    else {$data = [BitConverter]::ToInt32([BitConverter]::GetBytes([uint32]$text), 0)}
                } catch {$msg = 'ERROR: Invalid syntax. Specify valid numeric value.'}
            }
        }

        if ($msg) {Write-Error $msg; return}

        try {
            if ($PSCmdlet.ShouldProcess($target, "Set $typename")) {
                $key = $root.CreateSubKey($sub, $true)
                if (!$key) {$msg = "ERROR: Cannot create registry key: $Path"}
                elseif ($sync) {
                    $synckey = $syncroot.CreateSubKey($syncsub, $true)
                    if (!$synckey) {$msg = "ERROR: Cannot create sync registry key: HKU\$syncsub"}
                }
                if (!$msg) {$key.SetValue($Name, $data, $kind); if ($synckey) {$synckey.SetValue($Name, $data, $kind)}}
            }
        } catch {$msg = $_.Exception.Message} finally {if ($key) {$key.Dispose()}; if ($synckey) {$synckey.Dispose()}}

        if ($msg) {Write-Error $msg}
    }
}

function Export-RegState {
    param (
        [Parameter(Mandatory)][string[]]$Path,
        [Parameter(Mandatory)][string]$JsonPath
    )

    if (Test-Path $JsonPath) {return}

    $output = [ordered]@{}

    foreach ($p in $Path) {
        $clean = ($p -replace '^(?i)Registry::', '').Replace('/', '\')
        $parts = $clean -split '[:\\/]+', 2
        $rootkey = [string]$parts[0].ToUpperInvariant()
        $entry = $script:hives[$rootkey]
        $sub = if ($parts.Count -gt 1) {$parts[1].Trim('\').Replace('/', '\')} else {''}

        if (!$entry -or !$sub) {continue}
        $handle = $entry.Root.OpenSubKey($sub, $false)
        if (!$handle) {continue}

        $fullpath = "$($entry.Name)\$sub"
        $data = [ordered]@{Values = @(); Keys = @()}
        $stack = [Collections.Generic.Stack[object]]::new()
        $stack.Push([pscustomobject]@{Key = $handle; Data = $data})

        while ($stack.Count -gt 0) {
            $node = $stack.Pop()
            $values = [Collections.Generic.List[object]]::new()
            $keys = [Collections.Generic.List[object]]::new()

            try {
                foreach ($regval in ($node.Key.GetValueNames() | Sort-Object)) {
                    $kind = $node.Key.GetValueKind($regval).ToString()
                    $Value = $node.Key.GetValue($regval, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)

                    switch ($kind) {
                        'Binary' {$Value = [byte[]]$Value}
                        'MultiString' {$Value = [string[]]$Value}
                        'DWord' {$Value = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$Value), 0).ToString([Globalization.CultureInfo]::InvariantCulture)}
                        'QWord' {$Value = [BitConverter]::ToUInt64([BitConverter]::GetBytes([long]$Value), 0).ToString([Globalization.CultureInfo]::InvariantCulture)}
                    }

                    $values.Add([pscustomobject]@{Name = $regval; Type = $kind; Value = $Value})
                }

                foreach ($item in ($node.Key.GetSubKeyNames() | Sort-Object)) {
                    $child = $node.Key.OpenSubKey($item, $false)
                    if (!$child) {continue}
                    $childdata = [ordered]@{Values = @(); Keys = @()}
                    $keys.Add([pscustomobject]@{Name = $item; Data = $childdata})
                    $stack.Push([pscustomobject]@{Key = $child; Data = $childdata})
                }

                $node.Data.Values = $values.ToArray(); $node.Data.Keys = $keys.ToArray()
            } finally {$node.Key.Dispose()}
        }

        $output[$fullpath] = $data
    }

    if (!$output.Count) {return}

    $dest = Split-Path $JsonPath -Parent
    if ($dest) {mkdir -Force $dest *>$null}
    [IO.File]::WriteAllText($JsonPath, ([pscustomobject]$output | ConvertTo-Json -Depth 99 -Compress), [Text.UTF8Encoding]::new($false))
}

function Import-RegState {
    param ([Parameter(Mandatory)][string]$JsonPath)

    if (!(Test-Path $JsonPath)) {Write-Host "Backup not found: $JsonPath" -F Red; return}

    $backup = Get-Content -Path $JsonPath -Encoding UTF8 -Raw | ConvertFrom-Json -EA 1
    $stack = [Collections.Generic.Stack[object]]::new()

    if ($backup.PSObject.Properties['Path'] -and $backup.PSObject.Properties['Data']) {
        $stack.Push([pscustomobject]@{Path = [string]$backup.Path; Data = $backup.Data})
    } else {
        foreach ($prop in $backup.PSObject.Properties) {$stack.Push([pscustomobject]@{Path = $prop.Name; Data = $prop.Value})}
    }

    while ($stack.Count -gt 0) {
        $node = $stack.Pop()
        $clean = ([string]$node.Path -replace '^(?i)Registry::', '').Replace('/', '\')
        $parts = $clean -split '[:\\/]+', 2
        $rootkey = [string]$parts[0].ToUpperInvariant()
        $entry = $script:hives[$rootkey]
        $sub = if ($parts.Count -gt 1) {$parts[1].Trim('\').Replace('/', '\')} else {''}

        if (!$entry -or !$sub) {Write-Error 'Invalid registry key path.'; return}

        $Path = "$($entry.Name)\$sub"
        $created = $entry.Root.CreateSubKey($sub, $true)
        if (!$created) {Write-Error "Could not create registry key: $Path"; return}
        $created.Dispose()

        $values = @{}; $keys = @{}
        $data = $node.Data

        if ($data.PSObject.Properties['Values']) {
            foreach ($item in @($data.Values)) {if ($item) {$values[[string]$item.Name] = [pscustomobject]@{Type = [string]$item.Type; Value = $item.Value}}}
        }
        if ($data.PSObject.Properties['Keys']) {
            foreach ($item in @($data.Keys)) {if ($item) {$keys[[string]$item.Name] = $item.Data}}
        }

        $handle = $entry.Root.OpenSubKey($sub, $true)
        foreach ($item in $handle.GetSubKeyNames()) {if (!$keys.ContainsKey($item)) {Edit-Registry -Path "$Path\$item" -Remove}}
        foreach ($regval in $handle.GetValueNames()) {if (!$values.ContainsKey($regval)) {Edit-Registry -Path $Path -Name $regval -Remove}}
        $handle.Dispose()

        foreach ($regval in ($values.Keys | Sort-Object)) {
            $Type = [string]$values[$regval].Type
            $Value = $values[$regval].Value

            switch ($Type) {
                'Binary' {$Value = if ($null -eq $Value) {[byte[]]@()} else {[byte[]]@($Value)}}
                'MultiString' {$Value = if ($null -eq $Value) {[string[]]@()} else {[string[]]@($Value)}}
                'DWord' {$Value = if ($null -eq $Value) {'0'} else {[string]$Value}}
                'QWord' {$Value = if ($null -eq $Value) {'0'} else {[string]$Value}}
            }

            Edit-Registry -Path $Path -Name $regval -Type $Type -Value $Value -EA 1
        }

        foreach ($item in ($keys.Keys | Sort-Object -Descending)) {$stack.Push([pscustomobject]@{Path = "$Path\$item"; Data = $keys[$item]})}
    }
}

Export-ModuleMember -Function *