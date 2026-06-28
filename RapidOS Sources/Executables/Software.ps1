param (
    [string[]]$Software,
    [ValidateSet('Install', 'Download')]
    [string]$Mode = 'Install'
)

if ($PSVersionTable.PSVersion.Major -eq 5) {$Script:ProgressPreference = 'SilentlyContinue'}
$PSDefaultParameterValues['Invoke-WebRequest:UseBasicParsing'] = $true

function Install-Browser {
    param (
        [switch]$Brave,
        [switch]$Vivaldi,
        [switch]$Firefox,
        [switch]$Chrome,
        [switch]$Edge,
        [switch]$Thorium,
        [switch]$Mercury,
        [ValidateSet('Install', 'Download')]
        [string]$Mode = 'Install'
    )

    if (!(Test-Internet)) {Write-Host "Internet connection required." -F Red; return}

    $temp = $env:TEMP
    $download = "$env:SystemRoot\RapidScripts\Deferred"
    mkdir $download -Force *>$null

    switch ($true) {
        $Brave {
            Write-Host "--- Install Brave Browser ---" -F Green
            $arch = Get-Specs -Arch
            if ($arch -eq 'arm64') {$name = 'BraveBrowserStandaloneSetupArm64.exe'}
            else {$name = 'BraveBrowserStandaloneSetup.exe'}
            $exe = "$temp\$name"

            if (!(Test-Path $exe) -or $Mode -eq 'Download') {
                Write-Host "Downloading Brave..." -F DarkGray
                if ($arch -eq 'arm64') {$src1 = 'https://laptop-updates.brave.com/latest/winarm64'}
                else {$src1 = 'https://laptop-updates.brave.com/latest/winx64'}
                $src2 = "https://github.com/brave/brave-browser/releases/latest/download/$name"
                for ($i = 0; $i -lt 3; $i++) {
                    del $exe -Force -EA 0
                    try {Invoke-WebRequest -Uri $src1 -OutFile $exe -EA 1; break} catch {}
                    try {Invoke-WebRequest -Uri $src2 -OutFile $exe -EA 1; break} catch {}
                    Start-Sleep -s 10
                }
            }

            if (Test-Path $exe) {copy $exe "$download\$name" -Force}
            if ($Mode -eq 'Download') {Write-Host "Done."; return}

            Write-Host "Installing Brave..." -F DarkGray
            Start-Process -FilePath $exe -ArgumentList '/silent', '/install' -Wait
            Write-Host "Done."
        }

        $Vivaldi {
            Write-Host "--- Install Vivaldi ---" -F Green
            $arch = Get-Specs -Arch
            $src = 'https://vivaldi.com/download/'
            $data = (Invoke-WebRequest -Uri $src -EA 0).Content

            if ($arch -eq 'arm64') {$pattern = 'href="(https://downloads\.vivaldi\.com/stable/Vivaldi\.[\d.]+\.arm64\.exe)"'}
            else {$pattern = 'href="(https://downloads\.vivaldi\.com/stable/Vivaldi\.[\d.]+\.x64\.exe)"'}

            if ($data -notmatch $pattern) {Write-Host "Failed to parse Vivaldi download link." -F Red; return}

            $name = Split-Path -Path $Matches[1] -Leaf
            $exe = "$temp\$name"

            if (!(Test-Path $exe) -or $Mode -eq 'Download') {
                Write-Host "Downloading Vivaldi..." -F DarkGray
                for ($i = 0; $i -lt 3; $i++) {
                    del $exe -Force -EA 0
                    try {Invoke-WebRequest -Uri $Matches[1] -OutFile $exe -EA 1; break} catch {}
                    Start-Sleep -s 10
                }
            }

            if ($Mode -eq 'Download') {
                if (Test-Path $exe) {copy $exe "$download\$name" -Force}
                Write-Host "Done."
                return
            }

            Write-Host "Installing Vivaldi..." -F DarkGray
            Start-Process -FilePath $exe -ArgumentList '--vivaldi-silent', '--do-not-launch-chrome' -Wait
            Write-Host "Done."
        }

        $Chrome {
            Write-Host "--- Install Google Chrome ---" -F Green
            $arch = Get-Specs -Arch
            if ($arch -eq 'arm64') {$name = 'googlechromestandaloneenterprise_Arm64.msi'}
            else {$name = 'googlechromestandaloneenterprise64.msi'}
            $exe = "$temp\$name"

            if (!(Test-Path $exe) -or $Mode -eq 'Download') {
                Write-Host "Downloading Chrome..." -F DarkGray
                $src = "https://dl.google.com/dl/chrome/install/$name"
                for ($i = 0; $i -lt 3; $i++) {
                    del $exe -Force -EA 0
                    try {Invoke-WebRequest -Uri $src -OutFile $exe -EA 1; break} catch {}
                    Start-Sleep -s 10
                }
            }

            if (Test-Path $exe) {copy $exe "$download\$name" -Force}
            if ($Mode -eq 'Download') {Write-Host "Done."; return}

            Write-Host "Installing Chrome..." -F DarkGray
            Start-Process -FilePath $exe -ArgumentList '/qn' -Wait
            Write-Host "Done."
        }

        $Firefox {
            Write-Host "--- Install Mozilla Firefox ---" -F Green
            $arch = Get-Specs -Arch
            if ($arch -eq 'arm64') {$src = 'https://download.mozilla.org/?product=firefox-latest-ssl&os=win64-aarch64'}
            else {$src = 'https://download.mozilla.org/?product=firefox-latest-ssl&os=win64'}

            $name = 'FirefoxSetup.exe'
            $exe = "$temp\$name"

            if (!(Test-Path $exe) -or $Mode -eq 'Download') {
                Write-Host "Downloading Firefox..." -F DarkGray
                for ($i = 0; $i -lt 3; $i++) {
                    del $exe -Force -EA 0
                    try {Invoke-WebRequest -Uri $src -OutFile $exe -EA 1; break} catch {}
                    Start-Sleep -s 10
                }
            }

            if (Test-Path $exe) {copy $exe "$download\$name" -Force}
            if ($Mode -eq 'Download') {Write-Host "Done."; return}

            Write-Host "Installing Firefox..." -F DarkGray
            Start-Process -FilePath $exe -ArgumentList '/S', '/ALLUSERS=1' -Wait
            Write-Host "Done."
        }

        $Edge {
            Write-Host "--- Install Microsoft Edge ---" -F Green
            $arch = Get-Specs -Arch
            $src = 'https://edgeupdates.microsoft.com/api/products'
            $name = 'EdgeSetup.msi'
            $exe = "$temp\$name"

            $data = Invoke-WebRequest -Uri $src -EA 0 | ConvertFrom-Json
            $entry = ($data | ? Product -eq 'Stable').Releases | ? {$_.Platform -eq 'Windows' -and $_.Architecture -eq $arch -and $_.Artifacts.Count -ne 0} | Select -First 1

            if (!$entry) {Write-Host "Failed to fetch Edge version." -F Red; return}

            $ver = $entry.ProductVersion
            $src = $entry.Artifacts[0].Location

            if (!(Test-Path $exe) -or $Mode -eq 'Download') {
                Write-Host "Downloading Microsoft Edge $ver..." -F DarkGray
                for ($i = 0; $i -lt 3; $i++) {
                    del $exe -Force -EA 0
                    try {Invoke-WebRequest -Uri $src -OutFile $exe -EA 1; break} catch {}
                    Start-Sleep -s 10
                }
            }

            if ($Mode -eq 'Download') {
                if (Test-Path $exe) {copy $exe "$download\$name" -Force}
                Write-Host "Done."
                return
            }

            Write-Host "Installing Microsoft Edge..." -F DarkGray
            Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$exe`" /quiet /norestart" -Wait
            Write-Host "Done."
        }

        $Thorium {
            Write-Host "--- Install Thorium Browser ---" -F Green
            $cpu = CpuInstructions -Best
            $name = "thorium_$($cpu.ToUpper())_mini_installer.exe"
            $exe = "$temp\$name"
            $src = "https://github.com/Alex313031/Thorium-Win/releases/latest/download/$name"
            $fallbacks = @(
                'https://download.rapid-community.ru/files/browsers/Thorium_AVX2_installer.exe',
                'https://download.rapid-community.ru/files/browsers/Thorium_AVX_installer.exe',
                'https://download.rapid-community.ru/files/browsers/Thorium_SSE3_installer.exe',
                'https://download.rapid-community.ru/files/browsers/Thorium_SSE4_installer.exe'
            )

            if (!(Test-Path $exe) -or $Mode -eq 'Download') {
                Write-Host "Downloading Thorium..." -F DarkGray
                for ($i = 0; $i -lt 3; $i++) {
                    del $exe -Force -EA 0
                    try {Invoke-WebRequest -Uri $src -OutFile $exe -EA 1; break} catch {}
                    if ($fallbacks) {
                        $fallback = $fallbacks | ? {$_ -match $cpu} | Select -First 1
                        if ($fallback) {try {Invoke-WebRequest -Uri $fallback -OutFile $exe -EA 1; break} catch {}}
                    }
                    Start-Sleep -s 10
                }
            }

            if (Test-Path $exe) {copy $exe "$download\$name" -Force}
            if ($Mode -eq 'Download') {Write-Host "Done."; return}

            Write-Host "Installing Thorium..." -F DarkGray
            Start-Process -FilePath $exe -ArgumentList '--silent', '--do-not-launch-chrome', '--system-level' -Wait
            Write-Host "Done."
        }

        $Mercury {
            Write-Host "--- Install Mercury Browser ---" -F Green
            $cpu = CpuInstructions -Best
            try {
                $release = ParseGit -Repo "Alex313031/Mercury" -Latest
                $src = $release.Assets | ? {$_ -match "\.exe$" -and $_ -match $cpu} | Select -First 1
            } catch {
                $src = $null
            }
            if (!$src) {
                $fallbacks = @(
                    'https://download.rapid-community.ru/files/browsers/Mercury_AVX2_installer.exe',
                    'https://download.rapid-community.ru/files/browsers/Mercury_AVX_installer.exe',
                    'https://download.rapid-community.ru/files/browsers/Mercury_SSE3_installer.exe',
                    'https://download.rapid-community.ru/files/browsers/Mercury_SSE4_installer.exe'
                )
                $src = $fallbacks | ? {$_ -match $cpu} | Select -First 1
            }
            if (!$src) {Write-Host "Failed to locate Mercury installer." -F Red; return}

            $name = Split-Path $src -Leaf
            $exe = "$temp\$name"

            Write-Host "Downloading Mercury..." -F DarkGray
            for ($i = 0; $i -lt 3; $i++) {
                del $exe -Force -EA 0
                try {Invoke-WebRequest -Uri $src -OutFile $exe -EA 1; break} catch {}
                Start-Sleep -s 10
            }

            if ($Mode -eq 'Download') {
                if (Test-Path $exe) {copy $exe "$download\$name" -Force}
                Write-Host "Done."
                return
            }

            Write-Host "Installing Mercury..." -F DarkGray
            Start-Process -FilePath $exe -ArgumentList '/S' -Wait
            Get-ScheduledTask | ? {$_.TaskName -like "*Mercury*"} | Disable-ScheduledTask *>$null
            Write-Host "Done."
        }
    }
}

function Optimize-Browser {
    param ([switch]$Edge, [switch]$Brave, [switch]$Firefox, [switch]$Chrome)

    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    function Merge ($dest, $src) {
        if (!$dest) {return}
        foreach ($prop in $src.PSObject.Properties) {
            $key = $prop.Name; $val = $prop.Value
            if ($dest.PSObject.Properties[$key]) {
                if ($val -is [pscustomobject] -and $dest.$key -is [pscustomobject]) {Merge $dest.$key $val}
                else {$dest.$key = $val}
            } else {
                $dest | Add-Member -Name $key -Value $val -MemberType NoteProperty
            }
        }
    }

    if ($Edge) {
        Write-Host "Setting up Edge..."

        if ($admin) {
            # === Privacy & QoL policies ===
            $cfg = @{
                "StartupBoostEnabled"                  = 0; "MicrosoftEdgeInsiderPromotionEnabled" = 0
                "BingAdsSuppression"                   = 1; "ShowMicrosoftRewards"                 = 0
                "BackgroundModeEnabled"                = 0; "WebWidgetAllowed"                     = 0
                "EdgeAssetDeliveryServiceEnabled"      = 0; "DiagnosticData"                       = 0
                "WalletDonationEnabled"                = 0; "SpotlightExperiencesAndRecommendationsEnabled" = 0
                "PromotionalTabsEnabled"               = 0; "NewTabPageHideDefaultTopSites"        = 0
                "PersonalizationReportingEnabled"      = 0; "NewTabPagePrerenderEnabled"           = 0
                "NewTabPageQuickLinksEnabled"          = 0; "ShowAcrobatSubscriptionButton"        = 0
                "HideFirstRunExperience"               = 1; "ConfigureDoNotTrack"                  = 1
                "UserFeedbackAllowed"                  = 0; "ShowRecommendationsEnabled"           = 0
                "AlternateErrorPagesEnabled"           = 0; "NewTabPageAppLauncherEnabled"         = 0
                "EdgeCollectionsEnabled"               = 0; "NewTabPageContentEnabled"             = 0
            }

            $edgekey = "HKLM\SOFTWARE\Policies\Microsoft\Edge"
            $mskey = "HKLM\SOFTWARE\Microsoft"
            $extpath = "HKLM\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
            $extval = "odfafepnkmbhccpbejgmiehpchacaeak"

            foreach ($setting in $cfg.GetEnumerator()) {
                Edit-Registry -Path $edgekey -Name $setting.Key -Type DWord -Value $setting.Value
            }

            Edit-Registry -Path $mskey -Name "DoNotUpdateToEdgeWithChromium" -Type DWord -Value 1
            Edit-Registry -Path $extpath -Name 1 -Value $extval
        }
        
        # === Disable Edge tasks ===
        Get-ScheduledTask | ? {$_.TaskName -like "*Edge*"} | Disable-ScheduledTask *>$null
        Get-CimInstance Win32_StartupCommand | ? {$_.Name -like "*Edge*"} | % {Edit-Registry -Path "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" -Name $_.Name -Type Binary -Value ([byte[]](0x03,0,0,0,0,0,0,0))}

        Write-Host "Done."
    }

    if ($Brave) {
        Write-Host "Setting up Brave..."

        # === Paths ===
        $dir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
        $prefs = "$dir\Default\Preferences"
        $state = "$dir\Local State"

        del "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\initial_preferences" -Force 2>&1 | Out-Null
        mkdir "$dir\Default" -Force *>$null

        $utf8 = [Text.UTF8Encoding]::new($false)

        # === Setup preferences ===
        $cfg = @'
{
  "brave": {
    "brave_vpn": {"show_button": false},
    "ai_chat": {
      "context_menu_enabled": false,
      "show_toolbar_button": false,
      "toolbar_button_opens_full_page": false
    },
    "new_tab_page": {
      "hide_all_widgets": true,
      "show_brave_news": false,
      "show_stats": false,
      "show_together": false,
      "show_brave_vpn": false
    },
    "p3a": {"enabled": false, "notice_acknowledged": true},
    "rewards": {
      "inline_tip_buttons_enabled": false,
      "show_brave_rewards_button_in_location_bar": false
    },
    "show_side_panel_button": false,
    "sidebar": {
      "sidebar_show_option": 3
    },
    "stats": {"reporting_enabled": false},
    "wallet": {"show_wallet_icon_on_toolbar": false},
    "webtorrent_enabled": false,
    "shields": {"advanced_view_enabled": true},
    "enable_window_closing_confirm": false
  },
  "browser": {
    "first_run_finished": true,
    "has_seen_welcome_page": true,
    "enable_window_closing_confirm": false
  },
  "enable_do_not_track": true,
  "media_router": {
    "enable_media_router": false
  },
  "user_experience_metrics": {"reporting_enabled": false},
  "privacy_sandbox": {
    "m1": {
      "ad_measurement_enabled": false,
      "fledge_enabled": false,
      "topics_enabled": false
    }
  },
  "profile": {
    "content_settings": {
      "exceptions": {
        "cosmeticFiltering": {
          "*,*": {"last_modified": "13393343067023163", "setting": 2},
          "*https://firstparty": {"last_modified": "13393343067023139", "setting": 2}
        },
        "shieldsAds": {"*,*": {"last_modified": "13393343067023092", "setting": 2}}
      }
    },
    "safety_hub_menu_notifications": {
      "extensions": {"isCurrentlyActive": false},
      "passwords": {"isCurrentlyActive": false},
      "safe-browsing": {"isCurrentlyActive": false},
      "unused-site-permissions": {"isCurrentlyActive": false}
    }
  }
}
'@ | ConvertFrom-Json

        if (Test-Path $prefs) {
            try {
                $existing = Get-Content $prefs -Raw -Encoding UTF8 -EA 1 | ConvertFrom-Json
                Merge $existing $cfg
                [IO.File]::WriteAllText($prefs, ($existing | ConvertTo-Json -Depth 10), $utf8)
            } catch {
                [IO.File]::WriteAllText($prefs, ($cfg | ConvertTo-Json -Depth 10), $utf8)
            }
        } else {
            [IO.File]::WriteAllText($prefs, ($cfg | ConvertTo-Json -Depth 10), $utf8)
        }

        # === Setup local state ===
        $cfg = @'
{
  "background_mode": {"enabled": false},
  "brave": {
    "p3a": {"enabled": false},
    "stats": {"reporting_enabled": false}
  },
  "p3a": {"enabled": false},
  "stats": {"reporting_enabled": false},
  "user_experience_metrics": {"reporting_enabled": false}
}
'@ | ConvertFrom-Json

        if (Test-Path $state) {
            try {
                $existing = Get-Content $state -Raw -Encoding UTF8 -EA 1 | ConvertFrom-Json
                Merge $existing $cfg
                [IO.File]::WriteAllText($state, ($existing | ConvertTo-Json -Depth 10), $utf8)
            } catch {
                [IO.File]::WriteAllText($state, ($cfg | ConvertTo-Json -Depth 10), $utf8)
            }
        } else {
            [IO.File]::WriteAllText($state, ($cfg | ConvertTo-Json -Depth 10), $utf8)
        }

        # === Privacy policies ===
        if ($admin) {
            $policies = @{
                "SafeBrowsingExtendedReportingEnabled"    = 0
                "SafeBrowsingSurveysEnabled"              = 0
                "UrlKeyedAnonymizedDataCollectionEnabled" = 0
                "FeedbackSurveysEnabled"                  = 0
                "DomainReliabilityAllowed"                = 0
                "PrivacySandboxPromptEnabled"             = 0
                "CloudReportingEnabled"                   = 0
                "CloudProfileReportingEnabled"            = 0
                "UserFeedbackAllowed"                     = 0
                "UrlKeyedMetricsAllowed"                  = 0
                "LegacyTechReportAllowlist"               = 0
            }

            foreach ($setting in $policies.GetEnumerator()) {
                Edit-Registry -Path "HKLM\SOFTWARE\Policies\BraveSoftware\Brave" -Name $setting.Key -Type DWord -Value $setting.Value
            }
        }

        # === Disable tasks ===
        Get-ScheduledTask | ? {$_.TaskName -like "*Brave*"} | Disable-ScheduledTask *>$null
        Get-CimInstance Win32_StartupCommand | ? {$_.Name -like "*brave*"} | % {Edit-Registry -Path "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" -Name $_.Name -Type Binary -Value ([byte[]](0x03,0,0,0,0,0,0,0))}

        Write-Host "Done."
    }

    if ($Firefox) {
        if (!$admin) {Write-Host "This action requires admin privileges"; return}
        Write-Host "Setting up Firefox..."

        # === Locate firefox ===
        $paths = "$env:LOCALAPPDATA\Mozilla Firefox", "$env:ProgramFiles\Mozilla Firefox", "${env:ProgramFiles(x86)}\Mozilla Firefox"
        $exe = $null
        foreach ($p in $paths) {if (Test-Path "$p\firefox.exe") {$exe = "$p\firefox.exe"; break}}
        if (!$exe) {return}
        $install = Split-Path $exe -Parent

        $policies = @'
{
  "policies": {
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "DisableFormHistory": true,
    "CaptivePortal": false,
    "FirefoxHome": {
      "SponsoredTopSites": false,
      "SponsoredPocket": false
    },
    "ExtensionSettings": {
      "uBlock0@raymondhill.net": {
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi",
        "installation_mode": "normal_installed"
      }
    }
  }
}
'@
        $dist = "$install\distribution"
        mkdir $dist -Force 2>&1 | Out-Null

        [IO.File]::WriteAllText("$dist\policies.json", $policies, [Text.ASCIIEncoding]::new())

        # === Define settings ===
        $keys = @(
            'browser.startup.page', 'browser.aboutConfig.showWarning', 'browser.fixup.alternate.enabled',
            'browser.search.suggest.enabled', 'browser.sessionstore.privacy_level', 'browser.shell.checkDefaultBrowser',
            'browser.urlbar.quicksuggest.enabled', 'browser.urlbar.speculativeConnect.enabled', 'browser.urlbar.trimURLs',
            'dom.security.https_only_mode', 'browser.tabs.crashReporting.sendReport', 'network.predictor.enabled',
            'network.prefetch-next', 'browser.bookmarks.editDialog.maxRecentFolders', 'browser.bookmarks.max_backups',
            'browser.bookmarks.showMobileBookmarks', 'browser.download.autohideButton', 'browser.download.folderList',
            'browser.pagethumbnails.capturing_disabled', 'browser.search.context.loadInBackground', 'browser.startup.preXulSkeletonUI',
            'browser.tabs.tabMinWidth', 'browser.tabs.warnOnClose', 'browser.tabs.warnOnCloseOtherTabs',
            'browser.tabs.warnOnOpen', 'browser.urlbar.autoFill', 'browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons',
            'browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features', 'privacy.trackingprotection.enabled',
            'privacy.trackingprotection.socialtracking.enabled', 'browser.contentblocking.category'
        )
        $vals = @(
            3, $false, $false,
            $false, 2, $false,
            $false, $false, $false,
            $true, $false, $false,
            $false, 12, 2,
            $true, $false, 2,
            $true, $true, $false,
            120, $false, $false,
            $false, $false, $false,
            $false, $true,
            $true, 'strict'
        )

        # === AutoConfig ===
        $cfg = "// Firefox AutoConfig`n"
        for ($i = 0; $i -lt $keys.Count; $i++) {
            $v = $vals[$i]
            $fmt = if ($v -is [bool]) {$v.ToString().ToLower()} elseif ($v -is [int]) {$v} else {"`"$v`""}
            $cfg += "defaultPref(`"$($keys[$i])`", $fmt);`n"
        }

        mkdir "$install\defaults\pref" -Force 2>&1 | Out-Null

        $js = "pref(`"general.config.filename`", `"mozilla.cfg`");`npref(`"general.config.obscure_value`", 0);"
        $ascii = [Text.ASCIIEncoding]::new()

        [IO.File]::WriteAllText("$install\defaults\pref\local-settings.js", $js, $ascii)
        [IO.File]::WriteAllText("$install\mozilla.cfg", $cfg, $ascii)

        # === Profile injection ===
        $profdir = "$env:APPDATA\Mozilla\Firefox\Profiles"
        if ((Test-Path $profdir) -and !(Get-Process firefox -EA 0)) {
            $mark1 = '// Config start'
            $mark2 = '// Config end'

            $block = "`n$mark1`n"
            for ($i = 0; $i -lt $keys.Count; $i++) {
                $v = $vals[$i]
                $fmt = if ($v -is [bool]) {$v.ToString().ToLower()} elseif ($v -is [int]) {$v} else {"`"$v`""}
                $block += "user_pref(`"$($keys[$i])`", $fmt);`n"
            }
            $block += "$mark2`n"

            foreach ($prof in gci $profdir -Directory -EA 0) {
                $prefs = "$($prof.FullName)\prefs.js"
                if (!(Test-Path $prefs)) {continue}

                $content = [IO.File]::ReadAllText($prefs, $ascii)
                $idx = $content.IndexOf($mark1)
                if ($idx -ge 0) {$content = $content.Substring(0, $idx)}

                [IO.File]::WriteAllText($prefs, $content + $block, $ascii)
            }
        }

        # === Disable tasks ===
        Get-ScheduledTask | ? {$_.TaskName -like "*Firefox*"} | Disable-ScheduledTask -EA 0 *>$null

        Write-Host "Done."
    }

    if ($Chrome) {
        Write-Host "Setting up Chrome..."

        # === Paths ===
        $dir = "$env:LOCALAPPDATA\Google\Chrome\User Data"
        $prefs = "$dir\Default\Preferences"
        $state = "$dir\Local State"

        del "$env:ProgramFiles\Google\Chrome\Application\initial_preferences" -Force 2>&1 | Out-Null
        mkdir "$dir\Default" -Force *>$null

        $utf8 = [Text.UTF8Encoding]::new($false)

        # === Setup preferences ===
        $cfg = @'
{
  "ntp": {
    "num_personal_suggestions": 2
  },
  "privacy_sandbox": {
    "m1": {
      "ad_measurement_enabled": false,
      "fledge_enabled": false,
      "topics_enabled": false,
      "row_notice_acknowledged": true
    }
  },
  "privacy_guide": {
    "viewed": true
  },
  "browser": {
    "has_seen_welcome_page": true,
    "default_browser_infobar_declined_count": 1
  },
  "feature_notifications_enabled": false
}
'@ | ConvertFrom-Json

        if (Test-Path $prefs) {
            try {
                $existing = Get-Content $prefs -Raw -Encoding UTF8 -EA 1 | ConvertFrom-Json
                Merge $existing $cfg
                [IO.File]::WriteAllText($prefs, ($existing | ConvertTo-Json -Depth 10), $utf8)
            } catch {
                [IO.File]::WriteAllText($prefs, ($cfg | ConvertTo-Json -Depth 10), $utf8)
            }
        } else {
            [IO.File]::WriteAllText($prefs, ($cfg | ConvertTo-Json -Depth 10), $utf8)
        }

        # === Setup local state ===
        $cfg = @'
{
  "background_mode": {
    "enabled": false
  },
  "browser": {
    "first_run_finished": true,
    "default_browser_declined_count": 3,
    "pin_infobar_times_shown": 1
  },
  "feature_notifications_enabled": false,
  "profile": {
    "info_cache": {
      "Default": {
        "enterprise_label": ""
      }
    }
  },
  "user_experience_metrics": {
    "reporting_enabled": false
  }
}
'@ | ConvertFrom-Json

        if (Test-Path $state) {
            try {
                $existing = Get-Content $state -Raw -Encoding UTF8 -EA 1 | ConvertFrom-Json
                Merge $existing $cfg
                [IO.File]::WriteAllText($state, ($existing | ConvertTo-Json -Depth 10), $utf8)
            } catch {
                [IO.File]::WriteAllText($state, ($cfg | ConvertTo-Json -Depth 10), $utf8)
            }
        } else {
            [IO.File]::WriteAllText($state, ($cfg | ConvertTo-Json -Depth 10), $utf8)
        }

        # === Privacy policies ===
        if ($admin) {
            $policies = @{
                "PrivacySandboxPromptEnabled"             = 0
                "UrlKeyedAnonymizedDataCollectionEnabled" = 0
                "WebRtcEventLogCollectionAllowed"         = 0
                "CloudReportingEnabled"                   = 0
            }

            foreach ($setting in $policies.GetEnumerator()) {
                Edit-Registry -Path "HKLM\SOFTWARE\Policies\Google\Chrome" -Name $setting.Key -Type DWord -Value $setting.Value
            }

            Edit-Registry -Path "HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" -Name 1 -Value "ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx"
        }

        # === Disable tasks ===
        Get-ScheduledTask | ? {$_.TaskName -like "*Google*"} | Disable-ScheduledTask *>$null

        Write-Host "Done."
    }
}

function Install-NET3.5 {
    Write-Host "--- Install .NET Framework 3.5 ---" -F Green

    $status = Get-WindowsOptionalFeature -Online -FeatureName NetFx3 -EA 0
    if ($status.State -eq 'Enabled') {Write-Host ".NET Framework 3.5 is already installed."; return}
    if (!(Test-Internet)) {Write-Host "Internet connection required." -F Red; return}

    Write-Host "Enabling feature..." -F DarkGray
    Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -All -NoRestart -EA 0

    $status = Get-WindowsOptionalFeature -Online -FeatureName NetFx3 -EA 0
    if ($status.State -ne 'Enabled') {
        $temp = $env:TEMP
        $build = [int](Get-Specs -Build).Split('.')[0]
        $src = switch ($build) {
            19045 {'https://download.rapid-community.ru/files/components/NetFx3_amd64_19045.cab'}
            22621 {'https://download.rapid-community.ru/files/components/NetFx3_amd64_22621.cab'}
            22631 {'https://download.rapid-community.ru/files/components/NetFx3_amd64_22631.cab'}
            26100 {'https://download.rapid-community.ru/files/components/NetFx3_amd64_26100.cab'}
            26200 {'https://download.rapid-community.ru/files/components/NetFx3_amd64_26200.cab'}
            default {Write-Host "Unsupported build."; return}
        }
        $cab = "$temp\NetFx3.cab"
        Invoke-WebRequest -Uri $src -OutFile $cab -EA 0
        Add-WindowsPackage -Online -PackagePath $cab -NoRestart -IgnoreCheck *>$null
    }

    $status = Get-WindowsOptionalFeature -Online -FeatureName NetFx3 -EA 0
    if ($status.State -eq 'Enabled') {Write-Host "Done."}
    else {Write-Error "Failed to enable .NET Framework 3.5"}
}

function Install-DirectX {
    Write-Host "--- Install DirectX ---" -F Green

    if (!(Test-Internet)) {Write-Host "Internet connection required." -F Red; return}

    $temp = $env:TEMP
    $exe = "$temp\directx_Jun2010_redist.exe"
    $extract = "$temp\directx"

    Write-Host "Downloading DirectX package..." -F DarkGray
    Invoke-WebRequest -Uri 'https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe' -OutFile $exe -EA 0

    Write-Host "Extracting files..." -F DarkGray
    Start-Process -FilePath $exe -ArgumentList "/Q /C /T:`"$extract`"" -WindowStyle Hidden -Wait

    Write-Host "Installing DirectX..." -F DarkGray
    Start-Process -FilePath "$extract\DXSETUP.exe" -ArgumentList '/silent' -WindowStyle Hidden -Wait

    Write-Host "Done."
}

function Install-VCRedist {
    Write-Host "--- Install Visual C++ Redistributables ---" -F Green

    if (!(Test-Internet)) {Write-Host "Internet connection required." -F Red; return}

    $temp = "$env:SystemRoot\Temp"

    Write-Host "Downloading packages..." -F DarkGray
    Invoke-WebRequest -Uri 'https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x86.exe' -OutFile "$temp\vcredist2005_x86.exe" -EA 0
    Invoke-WebRequest -Uri 'https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x64.exe' -OutFile "$temp\vcredist2005_x64.exe" -EA 0
    Invoke-WebRequest -Uri 'https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe' -OutFile "$temp\vcredist2008_x86.exe" -EA 0
    Invoke-WebRequest -Uri 'https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x64.exe' -OutFile "$temp\vcredist2008_x64.exe" -EA 0
    Invoke-WebRequest -Uri 'https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe' -OutFile "$temp\vcredist2010_x86.exe" -EA 0
    Invoke-WebRequest -Uri 'https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe' -OutFile "$temp\vcredist2010_x64.exe" -EA 0
    Invoke-WebRequest -Uri 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe' -OutFile "$temp\vcredist2012_x86.exe" -EA 0
    Invoke-WebRequest -Uri 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe' -OutFile "$temp\vcredist2012_x64.exe" -EA 0
    Invoke-WebRequest -Uri 'https://download.microsoft.com/download/2/e/6/2e61cfa4-993b-4dd4-91da-3737cd5cd6e3/vcredist_x86.exe' -OutFile "$temp\vcredist2013_x86.exe" -EA 0
    Invoke-WebRequest -Uri 'https://download.microsoft.com/download/2/e/6/2e61cfa4-993b-4dd4-91da-3737cd5cd6e3/vcredist_x64.exe' -OutFile "$temp\vcredist2013_x64.exe" -EA 0
    Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vc_redist.x86.exe' -OutFile "$temp\vcredist2015_2017_2019_2022_x86.exe" -EA 0
    Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile "$temp\vcredist2015_2017_2019_2022_x64.exe" -EA 0

    Write-Host "Installing..." -F DarkGray
    Start-Process -FilePath "$temp\vcredist2005_x86.exe" -ArgumentList '/Q /C:"msiexec /i vcredist.msi /qn /norestart"' -Wait -WindowStyle Hidden -EA 0
    Start-Process -FilePath "$temp\vcredist2005_x64.exe" -ArgumentList '/Q /C:"msiexec /i vcredist.msi /qn /norestart"' -Wait -WindowStyle Hidden -EA 0
    Start-Process -FilePath "$temp\vcredist2008_x86.exe" -ArgumentList '/q' -Wait -WindowStyle Hidden -EA 0
    Start-Process -FilePath "$temp\vcredist2008_x64.exe" -ArgumentList '/q' -Wait -WindowStyle Hidden -EA 0
    Start-Process -FilePath "$temp\vcredist2010_x86.exe" -ArgumentList '/quiet /norestart' -Wait -WindowStyle Hidden -EA 0
    Start-Process -FilePath "$temp\vcredist2010_x64.exe" -ArgumentList '/quiet /norestart' -Wait -WindowStyle Hidden -EA 0
    Start-Process -FilePath "$temp\vcredist2012_x86.exe" -ArgumentList '/quiet /norestart' -Wait -WindowStyle Hidden -EA 0
    Start-Process -FilePath "$temp\vcredist2012_x64.exe" -ArgumentList '/quiet /norestart' -Wait -WindowStyle Hidden -EA 0
    Start-Process -FilePath "$temp\vcredist2013_x86.exe" -ArgumentList '/quiet /norestart' -Wait -WindowStyle Hidden -EA 0
    Start-Process -FilePath "$temp\vcredist2013_x64.exe" -ArgumentList '/quiet /norestart' -Wait -WindowStyle Hidden -EA 0
    Start-Process -FilePath "$temp\vcredist2015_2017_2019_2022_x86.exe" -ArgumentList '/quiet /norestart' -Wait -WindowStyle Hidden -EA 0
    Start-Process -FilePath "$temp\vcredist2015_2017_2019_2022_x64.exe" -ArgumentList '/quiet /norestart' -Wait -WindowStyle Hidden -EA 0

    Write-Host "Done."
}

function Install-MediaExtensions {
    Write-Host "--- Install HEIF & HEVC ---" -F Green

    # === Pre-checks ===
    if (!(Test-Internet)) {Write-Host "Internet connection required." -F Red; return}
    if (!(Get-AppxPackage -Name 'Microsoft.Windows.Photos' -EA 0)) {Write-Host "Photos app missing." -F DarkGray; return}

    # === Config ===
    $temp = $env:TEMP
    $arch = Get-Specs -Arch
    $apps = 'Microsoft.HEIFImageExtension_8wekyb3d8bbwe', 'Microsoft.HEVCVideoExtension_8wekyb3d8bbwe'

    foreach ($app in $apps) {
        $name = $app.Split('_')[0]
        if (Get-AppxPackage -Name $name -EA 0) {Write-Host "`"$name`" already installed." -F DarkGray; continue}

        # === Fetch package ===
        $body = @{type = 'PackageFamilyName'; url = $app; ring = 'Retail'; lang = 'en-US'}
        $resp = Invoke-RestMethod -Uri 'https://store.rg-adguard.net/api/GetFiles' -Method Post -Body $body -EA 0

        $pkg = $null
        if ($resp) {
            $list = [Collections.ArrayList]::new()
            $pattern = '<tr style.*<a href=\"(?<url>.*)"\s.*>(?<file>.*\.(app|msi)x.*)<\/a>'
            $matches = $resp | Select-String $pattern -AllMatches -EA 0
            foreach ($line in $matches) {
                foreach ($m in $line.Matches) {
                    $parts = $m.Groups['file'].Value -split '_'
                    $list.Add(@{
                        Url = $m.Groups['url'].Value
                        File = $m.Groups['file'].Value
                        Version = $parts[1]
                        Arch = $parts[2].ToLower()
                        Type = ($m.Groups['file'].Value -split '\.')[-1].ToLower()
                    }) *>$null
                }
            }

            $types = 'msixbundle', 'appxbundle', 'msix', 'appx'
            foreach ($type in $types) {
                $match = @($list | ? {$_.Type -eq $type -and ($_.Arch -eq $arch -or $_.Arch -eq 'neutral')} | sort Version -Descending)[0]
                if ($match) {$pkg = $match; break}
            }
        }

        # === Fallback ===
        if (!$pkg) {
            if ($name -eq 'Microsoft.HEIFImageExtension') {
                $pkg = @{Url = 'https://download.rapid-community.ru/files/extensions/Microsoft.HEIFImageExtension.appxbundle'; File = 'Microsoft.HEIFImageExtension.appxbundle'}
            } elseif ($name -eq 'Microsoft.HEVCVideoExtension') {
                $pkg = @{Url = 'https://download.rapid-community.ru/files/extensions/Microsoft.HEVCVideoExtension.appxbundle'; File = 'Microsoft.HEVCVideoExtension.appxbundle'}
            }
        }

        if (!$pkg) {continue}

        $file = "$temp\$($pkg.File)"
        del $file -Force *>$null

        Write-Host "Downloading $($pkg.File)..." -F DarkGray
        Invoke-WebRequest -Uri $pkg.Url -OutFile $file -EA 0

        Write-Host "Installing $name..." -F DarkGray
        Add-AppxPackage -Path $file -EA 0
    }

    Write-Host "Done."
}

function Uninstall-Edge {
    Write-Host "--- Uninstall Microsoft Edge ---" -F Green
    Write-Host "Removing Edge without any leftover files`n"

    # ==============================
    # Variables
    # ==============================
    $rootkey = "HKLM:\SOFTWARE" + $(if ([Environment]::Is64BitOperatingSystem) {"\WOW6432Node"}) + "\Microsoft"
    $edge = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    $uwp = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
    $del = {param ($path) if (Test-Path $path) {del $path -Force -Recurse -Confirm:$false}}

    # ==============================
    # Find uninstall keys
    # ==============================
    $keys = gci -Path @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    ) -EA 0 | ? {$_ -match "\{\b[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}\b\}"}

    $msi = @()
    foreach ($entry in $keys) {
        $props = Get-ItemProperty $entry.PSPath -EA 0
        if ($props.DisplayName -like "*Microsoft Edge*" -and $props.UninstallString -like "*MsiExec.exe*") {
            $msi += Split-Path $entry.PSPath -Leaf
        }
    }

    # ==============================
    # Uninstall methods
    # ==============================
    $setup = @()
    "LocalApplicationData", "ProgramFilesX86", "ProgramFiles" | % {
        $install = [Environment]::GetFolderPath($_)
        $setup += gci "$install\Microsoft\Edge*\setup.exe" -Recurse -EA 0 |
                  ? {$_ -like "*Edge\Application*" -or $_ -like "*SxS\Application*"}
    }

    $uninstall = (Get-ItemProperty "$rootkey\Windows\CurrentVersion\Uninstall\Microsoft Edge" -EA 0).UninstallString
    $uninstaller = $null; $cmdargs = $null
    if ($uninstall) {
        $parts = $uninstall -split '"' | ? {$_}
        $uninstaller, $cmdargs = $parts | % {[Environment]::ExpandEnvironmentVariables($_.Trim())}
        if (!(Test-Path $uninstaller -PathType Leaf)) {
            $uninstaller = $null
            Write-Host "Invalid uninstall path from registry." -F Red
        }
    }

    if (!$msi -and !$setup -and !$uninstaller) {
        Write-Host "No uninstaller found." -F Red
        if (!(Test-Path $edge)) {Write-Host "Edge likely already uninstalled." -F DarkGray}
        return
    }

    # ==============================
    # Stop processes
    # ==============================
    Write-Host "Terminating Edge processes..." -F DarkGray
    $ErrorActionPreference = "SilentlyContinue"
    "edgeupdate", "edgeupdatem", "MicrosoftEdgeElevationService" | % {Stop-Service $_ -Force}
    "MicrosoftEdgeUpdate", "msedge" | % {taskkill /f /im $_ *>$null}
    Get-Process -Name "MicrosoftEdge*" | ? {$_.Name -notlike "*webview*"} | % {taskkill /f /pid $_.Id *>$null}
    Get-Process -Name "setup" | ? {$_.Path -like "*\Edge*"} | % {taskkill /f /pid $_.Id *>$null}
    $ErrorActionPreference = "Continue"

    Edit-Registry -Path "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\ClientState\{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}" -Name "experiment_control_labels" -Remove
    $devreg = "$rootkey\EdgeUpdateDev"
    mkdir $devreg -Force *>$null
    Edit-Registry -Path $devreg -Name "AllowUninstall" -Value ""

    # ==============================
    # Uninstall block
    # ==============================
    $douninstall = {
        foreach ($id in $msi) {
            Start-Process "msiexec.exe" -ArgumentList "/qn /X$id REBOOT=ReallySuppress /norestart" -Wait
        }
        if ($uninstaller) {
            Start-Process $uninstaller -ArgumentList "$cmdargs --force-uninstall" -Wait -WindowStyle Hidden
        } else {
            foreach ($item in $setup) {
                if (Test-Path $item) {
                    $level = if ($item -like "*\AppData\Local\*") {"--user-level"} else {"--system-level"}
                    Start-Process $item -ArgumentList "--uninstall --msedge $level --channel=stable --verbose-logging --force-uninstall" -Wait
                }
            }
        }
    }

    # ==============================
    # Attempt uninstall methods
    # ==============================
    $fail = $true; $i = 1
    while ($fail -and $i -le 5) {
        switch ($i) {
            1 {
                Write-Host "Method 1: fake UWP file..." -F DarkGray
                $clean = $false
                if (!(Test-Path "$uwp\MicrosoftEdge.exe")) {
                    mkdir $uwp -Force *>$null
                    New-Item "$uwp\MicrosoftEdge.exe" -Force *>$null
                    $clean = $true
                }
                & $douninstall
                if ($clean) {Write-Host "Cleanup method 1..." -F DarkGray; & $del $uwp}
                $fail = Test-Path $edge
            }
            2 {
                Write-Host "Method 2: bypass WinDir feature..." -F DarkGray
                $envreg = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
                $windirprev = (Get-ItemProperty $envreg -Name "WinDir" -EA 0).WinDir
                if (!$windirprev) {$windirprev = "%SystemRoot%"}
                try {
                    Edit-Registry -Path $envreg -Name "WinDir" -Type ExpandString -Value ""
                    $env:WinDir = [Environment]::GetEnvironmentVariable("WinDir", "Machine")
                    & $douninstall
                } finally {
                    Write-Host "Cleanup method 2..." -F DarkGray
                    Edit-Registry -Path $envreg -Name "WinDir" -Type ExpandString -Value $windirprev
                    $env:WinDir = $windirprev
                }
                $fail = Test-Path $edge
            }
            3 {
                Write-Host "Method 3: EU region setting..." -F DarkGray
                $georeg = 'HKU\.DEFAULT\Control Panel\International\Geo'
                $geo = @{"Name"="FR"; "Nation"="84"}
                $suffix = "EdgeSaved"
                try {
                    foreach ($entry in $geo.GetEnumerator()) {
                        $curr = (Get-ItemProperty "Registry::$georeg" -Name $entry.Key -EA 0).($entry.Key)
                        if ($curr) {Edit-Registry -Path "Registry::$georeg" -Name "$($entry.Key)$suffix" -Value $curr}
                        Edit-Registry -Path "Registry::$georeg" -Name $entry.Key -Value $entry.Value
                    }
                    & $douninstall
                } finally {
                    Write-Host "Cleanup method 3..." -F DarkGray
                    foreach ($entry in $geo.GetEnumerator()) {
                        Edit-Registry -Path "Registry::$georeg" -Name $entry.Key -Remove
                        $saved = (Get-ItemProperty "Registry::$georeg" -Name "$($entry.Key)$suffix" -EA 0)."$($entry.Key)$suffix"
                        if ($saved) {
                            Edit-Registry -Path "Registry::$georeg" -Name $entry.Key -Value $saved
                            Edit-Registry -Path "Registry::$georeg" -Name "$($entry.Key)$suffix" -Remove
                        }
                    }
                }
                $fail = Test-Path $edge
            }
            4 {
                Write-Host "Method 4: edit region policy JSON..." -F DarkGray
                $policyfile = "$env:SystemRoot\System32\IntegratedServicesRegionPolicySet.json"
                $backup = "IntegratedServicesRegionPolicySet.json.$([IO.Path]::GetRandomFileName())"
                $clean = $false
                if (Test-Path $policyfile) {
                    try {
                        $clean = $true
                        takeown /f $policyfile /a *>$null
                        icacls $policyfile /grant *S-1-5-32-544:F /t /q *>$null
                        $data = Get-Content $policyfile -Raw | ConvertFrom-Json
                        foreach ($policy in $data.policies) {
                            $comment = $policy.'$comment'
                            if ($comment -like "*Edge*" -and $comment -like "*uninstall*") {
                                $policy.defaultState = "enabled"
                            }
                        }
                        $updated = $data | ConvertTo-Json -Depth 100
                        move $policyfile "$env:SystemRoot\System32\$backup" -Force
                        [IO.File]::WriteAllText($policyfile, $updated, [Text.Encoding]::UTF8)
                    } catch {
                        Write-Host $_
                        $clean = $false
                    }
                }
                try {
                    & $douninstall
                } finally {
                    if ($clean -and (Test-Path "$env:SystemRoot\System32\$backup")) {
                        Write-Host "Cleanup method 4..." -F DarkGray
                        & $del $policyfile *>$null
                        move "$env:SystemRoot\System32\$backup" $policyfile -Force *>$null
                    }
                }
                $fail = Test-Path $edge
            }
            5 {
                Write-Host "Method 5: forced cleanup..." -F DarkGray
                & $del "${env:ProgramFiles(x86)}\Microsoft\Edge"

                $regs = @(
                    "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate", "Registry::HKCR\CLSID\{1FCBE96C-1697-43AF-9140-2897C7C69767}",
                    "Registry::HKCR\AppID\{1FCBE96C-1697-43AF-9140-2897C7C69767}", "Registry::HKCR\Interface\{C9C2B807-7731-4F34-81B7-44FF7779522B}",
                    "Registry::HKCR\TypeLib\{C9C2B807-7731-4F34-81B7-44FF7779522B}", "Registry::HKCR\MSEdgeHTM", "Registry::HKCR\MSEdgePDF", "Registry::HKCR\MSEdgeMHT",
                    "Registry::HKCR\AppID\{628ACE20-B77A-456F-A88D-547DB6CEEDD5}", "HKLM\SOFTWARE\Clients\StartMenuInternet\Microsoft Edge",
                    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe", "Registry::HKCR\AppID\ie_to_edge_bho.dll",
                    "Registry::HKCR\AppID\{31575964-95F7-414B-85E4-0E9A93699E13}", "Registry::HKCR\CLSID\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}",
                    "Registry::HKCR\WOW6432Node\CLSID\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}", "Registry::HKCR\ie_to_edge_bho.IEToEdgeBHO",
                    "Registry::HKCR\ie_to_edge_bho.IEToEdgeBHO.1", "HKLM\SOFTWARE\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{c9abcf16-8dc2-4a95-bae3-24fd98f2ed29}",
                    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\Low Rights\ElevationPolicy\{c9abcf16-8dc2-4a95-bae3-24fd98f2ed29}",
                    "HKLM\SOFTWARE\Microsoft\Internet Explorer\ProtocolExecute\microsoft-edge",
                    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Internet Explorer\ProtocolExecute\microsoft-edge",
                    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}",
                    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}",
                    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Ext\PreApproved\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}",
                    "HKLM\SOFTWARE\Microsoft\Edge", "HKLM\SOFTWARE\WOW6432Node\Microsoft\Edge", "Registry::HKCR\CLSID\{3A84F9C2-6164-485C-A7D9-4B27F8AC009E}",
                    "Registry::HKCR\WOW6432Node\CLSID\{3A84F9C2-6164-485C-A7D9-4B27F8AC009E}", "Registry::HKCR\xmlfile", "HKLM\SOFTWARE\Microsoft\Internet Explorer",
                    "HKLM\SOFTWARE\Microsoft\Active Setup\Installed Components\{9459C573-B17A-45AE-9F64-1857B5D58CEE}",
                    "HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Application\Edge", "HKLM\SOFTWARE\Microsoft\MediaPlayer\ShimInclusionList\msedge.exe",
                    "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge Update", "Registry::HKCR\Applications\iexplore.exe",
                    "HKCU\SOFTWARE\Microsoft\Active Setup\Installed Components\{9459C573-B17A-45AE-9F64-1857B5D58CEE}",
                    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{33C62710-3490-4886-B44F-FD356B5D7489}",
                    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{FBB32221-C1D1-4683-9E92-7E59D69098C2}",
                    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{026D39D0-6A26-4E90-B462-2C5E941940E4}",
                    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{31885611-0000-4000-0000-000000000000}",
                    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Kernel\Resources\Microsoft.MicrosoftEdge_8wekyb3d8bbwe",
                    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppCapabilities\Client\Microsoft.MicrosoftEdge_8wekyb3d8bbwe",
                    "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\Capabilities\microsoftEdge"
                )
                $regs | % {Edit-Registry -Path $_ -Remove}

                $regpaths = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'HKLM\SOFTWARE\RegisteredApplications', 'HKCU\SOFTWARE\RegisteredApplications',
                           'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts', 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts',
                           'HKLM\SOFTWARE\Microsoft\Internet Explorer\Main\EnterpriseMode', 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
                           'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Ext\CLSID', 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PreviewHandlers',
                           'Registry::HKCR\.pdf\ShellEx\{8895b1c6-b41f-4c1c-a562-0d564250836f}', 'HKLM\SOFTWARE\Microsoft\Internet Explorer\EdgeIntegration\AdapterLocations\C:\Program Files (x86)\Microsoft\Edge',
                           'HKLM\SOFTWARE\RegisteredApplications'
                $regnames = 'TaskbarMigratedBrowserPin', 'Microsoft Edge', 'Microsoft Edge',
                           'MSEdgeHTM_microsoft-edge', 'MSEdgeHTM_microsoft-edge',
                           'MSEdgePath', 'Microsoft Edge Update',
                           '{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}', '{3A84F9C2-6164-485C-A7D9-4B27F8AC009E}',
                           '(Default)', 'Application',
                           'Internet Explorer'
                for ($j = 0; $j -lt $regpaths.Count; $j++) {
                    Edit-Registry -Path $regpaths[$j] -Name $regnames[$j] -Remove
                }

                ".htm",".html",".shtml",".svg",".xht",".xhtml",".webp",".xml" | % {
                    Edit-Registry -Path "Registry::HKCR\$_\OpenWithProgIds" -Name "MSEdgeHTM" -Remove
                    Edit-Registry -Path "HKCU\SOFTWARE\Classes\$_\OpenWithProgids" -Name "MSEdgeHTM" -Remove
                }

                $fail = Test-Path $edge
            }
        }
        if (!$fail) {
            Write-Host "Edge removed via method $i." -F DarkGray
            break
        }
        $i++
    }

    if ($fail -and $i -gt 5) {
        Write-Host "All uninstall methods failed." -F Red
        return
    }

    # ==============================
    # Final cleanup
    # ==============================
    Write-Host "Finalizing..." -F DarkGray
    & $del "$([Environment]::GetFolderPath("Desktop"))\Microsoft Edge.lnk"
    & $del "$([Environment]::GetFolderPath("CommonStartMenu"))\Microsoft Edge.lnk"
    & $del "$env:SystemDrive\Users\Public\Desktop\Microsoft Edge.lnk"

    if ((Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowCopilotButton' -EA 0).ShowCopilotButton -eq 1) {
        Refresh -kill
    }

    $appx = "\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore"
    gci "HKLM:$appx\InboxApplications" -EA 0 | ? {$_.PSChildName -like '*Edge*'} | % {Edit-Registry -Path "HKLM$appx\InboxApplications\$($_.PSChildName)" -Remove}
    & "$env:SystemRoot\RapidScripts\Playbook\AppX.ps1" -Packages @('Edge', 'Microsoft.Edge.GameAssist') *>$null

    Get-ScheduledTask | ? {$_.TaskName -like "*Edge*" -or $_.TaskPath -like "*Edge*"} | % {Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false -EA 0}

    Invoke-Profile -All -Action {
        $run = $_.RegKey + '\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
        $approved = $_.RegKey + '\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        $run, $approved | % {
            $path = $_
            $entries = Get-ItemProperty $path -EA 0
            if ($entries) {
                $entries.PSObject.Properties | ? {$_.Name -like '*Edge*'} | % {Edit-Registry -Path $path -Name $_.Name -Remove}
            }
        }
    }

    Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\EdgeUpdate' -Remove

    $destroy = "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate", "${env:ProgramFiles(x86)}\Microsoft\EdgeCore"
    $destroy | % {if (Test-Path $_) {del $_ -Force -Recurse -Confirm:$false -EA 0}}
    "edgeupdate", "edgeupdatem", "MicrosoftEdgeElevationService" | % {Stop-Service $_ -Force -EA 0; sc.exe delete $_ *>$null}

    Write-Host "`nDone."
}

function Uninstall-OneDrive {
    Write-Host '--- Uninstall OneDrive ---' -F Green
    Write-Host "Uninstalling OneDrive with deep system cleanup`n"

    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    namespace WinAPI {
        public class DeleteFiles {
            [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
            public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, int dwFlags);
            public static bool MarkFileDelete(string src) {
                return MoveFileEx(src, null, 4);
            }
        }
    }
"@ *>$null

    # === Stop processes ===
    Write-Host 'Terminating OneDrive processes...' -F DarkGray
    'OneDrive.exe', 'OneDriveSetup.exe', 'FileCoAuth.exe', 'OneDriveStandaloneUpdater.exe' | % {taskkill /f /im $_ *>$null}

    # === Run uninstall ===
    Write-Host 'Executing OneDrive uninstall...' -F DarkGray
    $paths = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
             "$env:SystemRoot\System32\OneDriveSetup.exe",
             "${env:ProgramFiles(x86)}\Microsoft OneDrive\*\OneDriveSetup.exe",
             "$env:ProgramFiles\Microsoft OneDrive\*\OneDriveSetup.exe"

    $exe = $null
    foreach ($p in $paths) {
        $found = gci $p -EA 0 | Select -First 1
        if ($found) {$exe = $found.FullName; break}
    }
    if ($exe) {Start-Process -FilePath $exe -ArgumentList '/uninstall /allusers' -Wait}

    # === Remove user data ===
    Write-Host 'Removing OneDrive user data...' -F DarkGray
    if ($env:OneDrive) {
        del $env:OneDrive -Recurse -Force -EA 0
        gci $env:OneDrive -Recurse -Force -EA 0 | % {[WinAPI.DeleteFiles]::MarkFileDelete($_.FullName) *>$null}
    }

    # === Clear system ===
    Write-Host 'Clearing registry, tasks, and folders...' -F DarkGray
    'OneDrive', 'OneDriveConsumer' | % {Edit-Registry -Path 'HKCU\Environment' -Name $_ -Remove}
    'OneDrive', 'OneDriveSetup' | % {
        Edit-Registry -Path 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name $_ -Remove
        Edit-Registry -Path 'HKLM\Software\Microsoft\Windows\CurrentVersion\Run' -Name $_ -Remove
    }

    $clsid = '{018D5C66-4533-4307-9B53-224DE2ED1FE6}'
    Edit-Registry -Path "HKCU\SOFTWARE\Classes\CLSID\$clsid" -Remove
    Edit-Registry -Path "HKCU\SOFTWARE\Classes\Wow6432Node\CLSID\$clsid" -Remove

    Edit-Registry -Path 'HKCU\SOFTWARE\Microsoft\OneDrive' -Remove
    Edit-Registry -Path 'HKLM\SOFTWARE\Microsoft\OneDrive' -Remove
    del "$env:ProgramData\Microsoft OneDrive", "$env:LOCALAPPDATA\Microsoft\OneDrive", "$env:LOCALAPPDATA\OneDrive" -Recurse -Force -EA 0
    Get-ScheduledTask | ? {$_.TaskName -like '*OneDrive*'} | % {Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false -EA 0}

    # === Process DLLs ===
    Write-Host 'Unregistering and removing DLLs...' -F DarkGray
    "$env:ProgramFiles\Microsoft OneDrive", "${env:ProgramFiles(x86)}\Microsoft OneDrive" | % {
        gci "$_\*\FileSyncShell*.dll" -Force -EA 0 | % {
            regsvr32.exe /u /s $_.FullName *>$null
            del $_.FullName -Force -EA 0
            if (Test-Path $_.FullName) {[WinAPI.DeleteFiles]::MarkFileDelete($_.FullName) *>$null}
        }
    }

    # === Final cleanup ===
    Write-Host 'Cleaning up remaining files...' -F DarkGray
    gci "$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -EA 0 | % {
        del $_.FullName -Force -EA 0
        if (Test-Path $_.FullName) {[WinAPI.DeleteFiles]::MarkFileDelete($_.FullName) *>$null}
    }

    $lnk = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk",
           "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk",
           'C:\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk'
    del $lnk -Force -EA 0

    gci 'C:\Users' -Directory -EA 0 | ? {$_.Name -notin 'Default','Public','All Users','Default User','WDAGUtilityAccount' -and $_.Name -notlike 'defaultuser*'} | % {
        del "$($_.FullName)\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk" -Force -EA 0
    }

    del "$env:ProgramFiles\Microsoft OneDrive", "${env:ProgramFiles(x86)}\Microsoft OneDrive" -Recurse -Force -EA 0

    Write-Host "`nDone."
}

function Uninstall-PCHealthCheck {
    Write-Host "--- Uninstall PC Health Check ---" -F Green

    # === Find GUID and uninstall ===
    Write-Host "Searching for installed app..." -F DarkGray
    $apps = Get-CimInstance -ClassName Win32_Product | ? {$_.Name -like "*PC Health Check*"}
    if ($apps) {
        foreach ($app in $apps) {
            $id = $app.IdentifyingNumber
            if ($id) {Start-Process msiexec.exe -ArgumentList "/x $id /quiet /norestart" -Wait *>$null}
        }
    } else {
        Write-Host "App not found." -F DarkGray
    }

    # === Block reinstall ===
    Write-Host "Blocking future reinstall..." -F DarkGray
    $reg = "HKLM\SOFTWARE\Microsoft\PCHC"
    mkdir $reg -Force *>$null
    Edit-Registry -Path $reg -Name "PreviousUninstall" -Type DWord -Value 1

    Write-Host "Done."
}

function Uninstall-InstallationAssistant {
    Write-Host "--- Remove Windows Installation Assistant ---" -F Green

    # === Uninstall assistant ===
    Write-Host "Searching for installation assistant..." -F DarkGray
    $dir = "${env:ProgramFiles(x86)}\WindowsInstallationAssistant"
    $exe = "$dir\Windows10UpgraderApp.exe"

    if (Test-Path $exe) {
        Start-Process $exe -ArgumentList "/SunValley /ForceUninstall" -Wait
        del $dir -Recurse -Force *>$null
        Write-Host "Removal successful." -F DarkGray
    } else {
        Write-Host "Windows Installation Assistant not found." -F DarkGray
    }

    Write-Host "Done."
}

gci $env:TEMP | ? {$_.Name -ne 'AME'} | del -Recurse -Force -EA 0

foreach ($arg in $Software) {
    switch ($arg) {
        # === Microsoft Edge ===
        "Install-Edge" {Install-Browser -Edge -Mode $Mode}
        "Remove-Edge" {Uninstall-Edge}
        "Optimize-Edge" {Optimize-Browser -Edge}

        # === OneDrive ===
        "Remove-OneDrive" {Uninstall-OneDrive}

        # === PC Health Check ===
        "Remove-PCHealthCheck" {Uninstall-PCHealthCheck}

        # === Windows Installation Assistant ===
        "Remove-InstallationAssistant" {Uninstall-InstallationAssistant}

        # === HEVC & HEIF Extensions ===
        "Install-MediaExtensions" {Install-MediaExtensions}

        # === Brave Browser ===
        "Install-Brave" {Install-Browser -Brave -Mode $Mode}
        "Optimize-Brave" {Optimize-Browser -Brave}

        # === Vivaldi Browser ===
        "Install-Vivaldi" {Install-Browser -Vivaldi -Mode $Mode}

        # === Firefox Browser ===
        "Install-Firefox" {Install-Browser -Firefox -Mode $Mode}
        "Optimize-Firefox" {Optimize-Browser -Firefox}

        # === Chrome Browser ===
        "Install-Chrome" {Install-Browser -Chrome -Mode $Mode}
        "Optimize-Chrome" {Optimize-Browser -Chrome}

        # === Thorium Browser ===
        "Install-Thorium" {Install-Browser -Thorium -Mode $Mode}

        # === Mercury Browser ===
        "Install-Mercury" {Install-Browser -Mercury -Mode $Mode}

        # === .NET Framework 3.5 ===
        "Install-NET3.5" {Install-NET3.5}

        # === DirectX ===
        "Install-DirectX" {Install-DirectX}

        # === VC++ 2005-2022 ===
        "Install-VCRedist" {Install-VCRedist}

        default {
            Write-Host "Error: Invalid argument `"$arg`"" -F Red
        }
    }
}