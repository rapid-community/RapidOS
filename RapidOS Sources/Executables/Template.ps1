#Requires -RunAsAdministrator

# === Load YamlDotNet ===
$dll = "$PSScriptRoot\RapidResources\YamlDotNet.dll"
if (!(Test-Path $dll)) {return}
Add-Type -Path $dll

function ConvertFrom-Yaml {
    param ([Parameter(Position = 0)][string]$path)

    $parse = {
        param ($item)
        switch ($item.GetType().Name) {
            'YamlMappingNode' {
                $map = [ordered]@{}
                foreach ($entry in $item) {$map.($entry.Key.Value) = & $parse $entry.Value}
                return $map
            }
            'YamlSequenceNode' {
                $arr = foreach ($entry in $item) {& $parse $entry}
                return , @($arr)
            }
            'YamlScalarNode' {
                $val = $item.Value
                if ($item.Tag -eq 'tag:yaml.org,2002:int' -or $val -match '^-?\d+$') {return [int]$val}
                if ($item.Tag -eq 'tag:yaml.org,2002:bool' -or $val -match '^(?i)(true|false|yes|no|on|off)$') {
                    return [bool]::Parse(($val -replace '(?i)^(yes|on)$', 'true' -replace '(?i)^(no|off)$', 'false'))
                }
                return $val
            }
            default {return $item}
        }
    }

    if (!$path) {return}
    $reader = [IO.File]::OpenText($path)
    try {
        $stream = [YamlDotNet.RepresentationModel.YamlStream]::new()
        $stream.Load([IO.TextReader]$reader)
        if ($stream.Documents.Count -gt 0) {return & $parse $stream.Documents[0].RootNode}
    }
    finally {
        $reader.Close()
    }
}

function Add-HKCU {
    param ([Parameter(Position = 0)][string]$path)
    if ([string]::IsNullOrWhiteSpace($path)) {return}
    $norm = $path.Trim() -replace '(?i)^Registry::', '' -replace '(?i)^HKCU:\\', 'HKCU\'
    if ($norm -notmatch '(?i)^HKCU\\') {return}
    $key = $norm.Substring(5)
    if ($key) {[void]$script:keys.Add($key)}
}

function Read-HKCU {
    param ([Parameter(Position = 0)][string]$cmd)
    if ([string]::IsNullOrWhiteSpace($cmd)) {return}

    $map = @{}
    $lines = $cmd -split "`r?`n"

    foreach ($line in $lines) {
        if ($line.Trim() -match '(?i)\$(\w+)\s*=\s*[''"]((?:Registry::)?HKCU[:\\][^''"]+)[''"]') {
            $map[$Matches[1]] = $Matches[2]
            Add-HKCU $Matches[2]
        }
    }

    foreach ($line in $lines) {
        $ln = $line.Trim()
        foreach ($m in [regex]::Matches($ln, '(?i)(?:Edit-Registry|Set-ItemProperty)\s+-Path\s+[''"]((?:Registry::)?HKCU[:\\][^''"]+)[''"]')) {Add-HKCU $m.Groups[1].Value}
        foreach ($m in [regex]::Matches($ln, '(?i)\breg\s+(?:add|delete)\s+[''"]((?:Registry::)?HKCU[:\\][^''"]+)[''"]')) {Add-HKCU $m.Groups[1].Value}
        foreach ($m in [regex]::Matches($ln, '(?i)(?:Edit-Registry|Set-ItemProperty)\s+-Path\s+\$(\w+)')) {
            $name = $m.Groups[1].Value
            if ($map.ContainsKey($name)) {Add-HKCU $map[$name]}
        }
    }
}

# === Execution ===
$script:keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$src = "$PSScriptRoot\..\Configuration"
$mount = 'Registry::HKU\AME_UserHive_Default'
$opts = Get-Options
$build = [int](Get-Specs -Build).Split('.')[0]

if (!(Test-Path $mount) -or !(Test-Path $src)) {return}

foreach ($item in gci $src -Filter *.yml -Recurse) {
    $data = ConvertFrom-Yaml $item.FullName
    if (!$data.actions) {continue}

    foreach ($entry in $data.actions) {
        if ($entry.builds) {
            if (@($entry.builds) -contains '<22000') {if ($build -ge 22000) {continue}}
            elseif ($build -lt 22000) {continue}
        }

        if ($entry.option) {
            $opt = [string]$entry.option
            if ($opt.StartsWith('!')) {if ($opts -contains $opt.Substring(1)) {continue}}
            elseif ($opts -notcontains $opt) {continue}
        }

        if ($entry.options) {
            $found = $false
            foreach ($opt in @($entry.options)) {
                $val = [string]$opt
                if (!$val) {continue}
                if ($val.StartsWith('!')) {if ($opts -notcontains $val.Substring(1)) {$found = $true; break}}
                elseif ($opts -contains $val) {$found = $true; break}
            }
            if (!$found) {continue}
        }

        switch ($entry.oobe) {
            $false {continue}
            $true {}
            'only' {}
            default {if ($entry.iso -eq $true -or $entry.iso -eq 'only') {continue}}
        }

        if ($entry.path) {foreach ($val in @($entry.path)) {Add-HKCU $val}}
        if ($entry.command) {Read-HKCU ([string]$entry.command)}
    }
}

$user = $env:USERNAME
$sid = (Get-ItemProperty 'HKLM:\SOFTWARE\RapidOS\Installation' -Name 'SetupUser' -EA 0).SetupUser
$profiles = Get-CimInstance Win32_UserProfile -EA 0

$targets = [Collections.Generic.List[hashtable]]::new()
$targets.Add(@{Path = $mount; Loaded = $true; Tag = $null})

$dirs = gci "$env:SystemDrive\Users" -Directory -EA 0 | ? {$_.Name -ne $user -and $_.Name -notin 'Default', 'Public', 'All Users', 'Default User', 'WDAGUtilityAccount' -and $_.Name -notmatch '^defaultuser'}

foreach ($d in $dirs) {
    $dir = $d.FullName
    $wp = $profiles | ? {$_.LocalPath -eq $dir} | Select -First 1
    
    if ($wp -and ($wp.Special -or $wp.SID -eq $sid)) {continue}

    if ($wp -and $wp.Loaded) {
        $targets.Add(@{Path = ("Registry::HKU\" + $wp.SID); Loaded = $true; Tag = $null})
    }
    else {
        $hive = $dir + '\NTUSER.DAT'
        if (!(Test-Path $hive)) {continue}
        $tag = 'TPL_' + [guid]::NewGuid().Guid.Substring(0, 8)
        reg load "HKU\$tag" "$hive" *>$null
        if ($LASTEXITCODE -ne 0) {continue}
        $targets.Add(@{Path = ("Registry::HKU\$tag"); Loaded = $false; Tag = $tag})
    }
}

del 'HKCU:\SOFTWARE\RapidOS\Deferred' -Recurse -Force -EA 0
foreach ($target in $targets) {del "$($target.Path)\SOFTWARE\RapidOS\Deferred" -Recurse -Force -EA 0}

try {
    foreach ($key in $script:keys) {
        $regsrc = "HKCU:\$key"
        if (!(Test-Path $regsrc)) {continue}
        $sk = Get-Item $regsrc -EA 0
        if (!$sk) {continue}

        $names = $sk.GetValueNames()
        if (!$names -or $names.Count -eq 0) {continue}

        foreach ($t in $targets) {
            $regdest = $t.Path + '\' + $key
            foreach ($name in $names) {
                $data = $sk.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $kind = $sk.GetValueKind($name).ToString()
                try {
                    Edit-Registry -Path $regdest -Name $name -Type $kind -Value $data -EA 1
                } catch {
                    $val = if ($data -is [byte[]]) {'<binary>'} else {[string]$data}
                    if ($val.Length -gt 40) {$val = $val.Substring(0, 40) + '...'}
                    Write-Warning "$regdest\$name ($kind=$val) - $($_.Exception.Message)"
                }
            }
        }
    }
}
finally {
    foreach ($t in $targets) {
        if (!$t.Loaded -and $t.Tag) {
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            reg unload "HKU\$($t.Tag)" *>$null
        }
    }
}