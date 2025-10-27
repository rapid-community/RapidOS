#Requires -RunAsAdministrator

param ([string[]]$Software)
if ($Host.Version.Major -eq 5) {$Script:ProgressPreference = "SilentlyContinue"}

function Install-Browser {
    [CmdletBinding()]
    param (
        [switch]$Brave,
        [switch]$Vivaldi,
        [switch]$Firefox,
        [switch]$Chrome,
        [switch]$Edge,
        [switch]$Thorium,
        [switch]$Mercury
    )

    # === Pre-Checks ===
    if (!(Test-Internet)) {
        Write-Host "Internet connection required." -F Red
        return
    }

    $tempDir = $env:TEMP

    switch ($true) {
        # ===========================
        # Brave Browser
        # ===========================
        $Brave {
            Write-Host "--- Install Brave Browser ---" -F Green
            Write-Host "Silent installation of the latest Brave release`n"

            # === Paths ===
            $exeName = "BraveBrowserStandaloneSilentSetup.exe"
            $fullExePath = Join-Path $tempDir $exeName

            # === Download ===
            Write-Host "Downloading Brave..." -F DarkGray
            try {
                $src = "https://github.com/brave/brave-browser/releases/latest/download/BraveBrowserStandaloneSilentSetup.exe"
                Invoke-WebRequest -Uri $src -OutFile $fullExePath -EA 0
            } catch {
                $release = ParseGit -Repo "brave/brave-browser" -Latest
                $src = $release.Assets | ? {$_ -like "*$exeName"}
                if (!$src) {Write-Host "Failed to fetch Brave installer." -F Red; return}
                Invoke-WebRequest -Uri $src -OutFile $fullExePath -EA 0
            }

            # === Installation ===
            Write-Host "Installing Brave..." -F DarkGray
            $p = Start-Process -FilePath $fullExePath -PassThru -Wait -EA 0

            $exitCode = if ($p) {$p.ExitCode} else {-1}
            if ($exitCode -ne 0) {Write-Warning "Exit code: $exitCode"}
            Write-Host "`nDone."
        }

        # ===========================
        # Vivaldi Browser
        # ===========================
        $Vivaldi {
            Write-Host "--- Install Vivaldi ---" -F Green
            Write-Host "Silent installation of the latest Vivaldi browser`n"

            # === Paths ===
            $srcUrl = 'https://vivaldi.com/download/'
            $data = (Invoke-WebRequest -Uri $srcUrl -EA 0).Content
            if ($data -notmatch '"(https?://[^"]+\.x64\.exe)"') {Write-Host "Failed to fetch Vivaldi installer." -F Red; return}

            $exeName = Split-Path -Path $Matches[1] -Leaf
            $fullExePath = Join-Path $tempDir $exeName

            # === Download ===
            Write-Host "Downloading Vivaldi..." -F DarkGray
            Invoke-WebRequest -Uri $Matches[1] -OutFile $fullExePath -EA 0

            # === Installation ===
            Write-Host "Installing Vivaldi..." -F DarkGray
            $installArgs = @("--vivaldi-silent", "--do-not-launch-chrome")
            $p = Start-Process -FilePath $fullExePath -ArgumentList $installArgs -PassThru -Wait -EA 0

            $exitCode = if ($p) {$p.ExitCode} else {-1}
            if ($exitCode -ne 0) {Write-Warning "Exit code: $exitCode"}
            Write-Host "`nDone."
        }

        # ===========================
        # Chrome Browser
        # ===========================
        $Chrome {
            Write-Host "--- Install Google Chrome ---" -F Green
            Write-Host "Silent installation of Google Chrome`n"

            # === Paths ===
            $srcUrl = 'https://dl.google.com/chrome/install/latest/chrome_installer.exe'
            $exeName = "ChromeStandaloneSetup64.exe"
            $fullExePath = Join-Path $tempDir $exeName

            # === Download ===
            Write-Host "Downloading Chrome..." -F DarkGray
            Invoke-WebRequest -Uri $srcUrl -OutFile $fullExePath -EA 0

            # === Installation ===
            Write-Host "Installing Chrome..." -F DarkGray
            $installArgs = @("/silent", "/install")
            $p = Start-Process -FilePath $fullExePath -ArgumentList $installArgs -PassThru -Wait -EA 0

            $exitCode = if ($p) {$p.ExitCode} else {-1}
            if ($exitCode -ne 0) {Write-Warning "Exit code: $exitCode"}
            Write-Host "`nDone."
        }

        # ===========================
        # Firefox Browser
        # ===========================
        $Firefox {
            Write-Host "--- Install Mozilla Firefox ---" -F Green
            Write-Host "Silent installation of the latest stable Firefox`n"

            # === Paths ===
            $srcUrl = 'https://download.mozilla.org/?product=firefox-latest-ssl&os=win64'
            $exeName = "FirefoxSetup.exe"
            $fullExePath = Join-Path $tempDir $exeName

            # === Download ===
            Write-Host "Downloading Firefox..." -F DarkGray
            Invoke-WebRequest -Uri $srcUrl -OutFile $fullExePath -EA 0

            # === Installation ===
            Write-Host "Installing Firefox..." -F DarkGray
            $installArgs = @("/S", "/MaintenanceService=false")
            $p = Start-Process -FilePath $fullExePath -ArgumentList $installArgs -PassThru -Wait -EA 0

            $exitCode = if ($p) {$p.ExitCode} else {-1}
            if ($exitCode -ne 0) {Write-Warning "Exit code: $exitCode"}
            Write-Host "`nDone."
        }

        # ===========================
        # Microsoft Edge Browser
        # ===========================
        $Edge {
            Write-Host "--- Install Microsoft Edge ---" -F Green
            Write-Host "Silent installation of Microsoft Edge with architecture detection`n"

            # === Paths ===
            $apiUrl = "https://edgeupdates.microsoft.com/api/products"
            $setupFile = "EdgeSetup.msi"

            # === Arch detection ===
            $arch = switch ($true) {
                ([Environment]::Is64BitOperatingSystem) {
                    $arm = (Get-CimInstance Win32_ComputerSystem).SystemType -match "ARM64" -or $env:PROCESSOR_ARCHITECTURE -eq "ARM64"
                    ("x64", "arm64")[$arm]
                }
                default {"x86"}
            }

            # === Fetch version data ===
            $client = New-Object System.Net.WebClient
            $data = ConvertFrom-Json $client.DownloadString($apiUrl)
            $item = ($data | ? Product -eq "Stable").Releases |
                    ? {$_.Platform -eq "Windows" -and $_.Architecture -eq $arch} |
                    ? {$_.Artifacts.Count -ne 0} | Select -First 1

            if (!$item) {Write-Host "Failed to fetch Edge version." -F Red; return}
            $version = $item.ProductVersion
            $url = $item.Artifacts.Location

            # === Installation ===
            Write-Host "Downloading Microsoft Edge $version..." -F DarkGray
            $fullSetupPath = Join-Path $tempDir $setupFile
            $client.DownloadFile($url, $fullSetupPath)

            Write-Host "Installing Microsoft Edge..." -F DarkGray
            $p = Start-Process "msiexec.exe" "/i `"$fullSetupPath`" /quiet /norestart" -PassThru -Wait

            $exitCode = if ($p) {$p.ExitCode} else {-1}
            if ($exitCode -ne 0) {Write-Warning "Exit code: $exitCode"}
            Write-Host "`nDone."
        }

        # ===========================
        # Thorium Browser
        # ===========================
        $Thorium {
            Write-Host "--- Install Thorium Browser ---" -F Green
            Write-Host "Silent installation of Thorium optimized for CPU instruction set`n"

            # === Select best matching asset ===
            $bestInstructionSet = CpuInstructions -Best
            $fileName = "Mercury_${bestInstructionSet}_installer.exe"
            $fullInstallerPath = Join-Path $tempDir $fileName
            try {
                $release = ParseGit -Repo "Alex313031/Thorium-Win" -Latest
                $installerUrl = $release.Assets | ? {$_ -match "win" -and $_ -match "\.exe$" -and $_ -match $bestInstructionSet} | Select -First 1
            } catch {
                $fallback = @(
                    'https://download.rapid-community.ru/download/files/browsers/Thorium_AVX2_installer.exe',
                    'https://download.rapid-community.ru/download/files/browsers/Thorium_AVX_installer.exe',
                    'https://download.rapid-community.ru/download/files/browsers/Thorium_SSE3_installer.exe',
                    'https://download.rapid-community.ru/download/files/browsers/Thorium_SSE4_installer.exe'
                )
                $installerUrl = $fallback | ? {$_ -match $bestInstructionSet} | Select -First 1
            }
            if (!$installerUrl) {Write-Host "Failed to locate Thorium installer." -F Red; return}

            # === Download ===
            Write-Host "Downloading Thorium..." -F DarkGray
            Invoke-WebRequest -Uri $installerUrl -OutFile $fullInstallerPath -EA 0

            # === Installation ===
            Write-Host "Installing Thorium..." -F DarkGray
            $installArgs = @("--do-not-launch-chrome")
            $p = Start-Process -FilePath $fullInstallerPath -ArgumentList $installArgs -PassThru -Wait -EA 0

            $exitCode = if ($p) {$p.ExitCode} else {-1}
            if ($exitCode -ne 0) {Write-Warning "Exit code: $exitCode"}
            Write-Host "`nDone."
        }

        # ===========================
        # Mercury Browser
        # ===========================
        $Mercury {
            Write-Host "--- Install Mercury Browser ---" -F Green
            Write-Host "Silent installation of Mercury optimized for CPU instruction set`n"

            # === Select best matching asset ===
            $bestInstructionSet = CpuInstructions -Best
            $fileName = "Mercury_${bestInstructionSet}_installer.exe"
            $fullInstallerPath = Join-Path $tempDir $fileName
            try {
                $release = ParseGit -Repo "Alex313031/Mercury" -Latest
                $installerUrl = $release.Assets | ? {$_ -match "win" -and $_ -match "\.exe$" -and $_ -match $bestInstructionSet} | Select -First 1
            } catch {
                $fallback = @(
                    'https://download.rapid-community.ru/download/files/browsers/Mercury_AVX2_installer.exe',
                    'https://download.rapid-community.ru/download/files/browsers/Mercury_AVX_installer.exe',
                    'https://download.rapid-community.ru/download/files/browsers/Mercury_SSE3_installer.exe',
                    'https://download.rapid-community.ru/download/files/browsers/Mercury_SSE4_installer.exe'
                )
                $installerUrl = $fallback | ? {$_ -match $bestInstructionSet} | Select -First 1
            }
            if (!$installerUrl) {Write-Host "Failed to locate Mercury installer." -F Red; return}

            # === Download ===
            Write-Host "Downloading Mercury..." -F DarkGray
            Invoke-WebRequest -Uri $installerUrl -OutFile $fullInstallerPath -EA 0

            # === Installation ===
            Write-Host "Installing Mercury..." -F DarkGray
            $installArgs = @("/S")
            $p = Start-Process -FilePath $fullInstallerPath -ArgumentList $installArgs -PassThru -Wait -EA 0

            Get-ScheduledTask | ? {$_.TaskName -like "*Mercury*"} | Disable-ScheduledTask *>$null

            $exitCode = if ($p) {$p.ExitCode} else {-1}
            if ($exitCode -ne 0) {Write-Warning "Exit code: $exitCode"}
            Write-Host "`nDone."
        }
    }
}

function Optimize-Browser {
    [CmdletBinding()]
    param (
        [switch]$Edge,
        [switch]$Brave,
        [switch]$Firefox,
        [switch]$Chrome
    )

    if ($Edge) {
        Write-Host "Setting up Edge..."

        # ===========================
        # Privacy & QoL policies
        # ===========================
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

        $edgeKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
        $microsoftKeyPath = "HKLM:\SOFTWARE\Microsoft"
        $extensionPath = "HKCU:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
        $extensionValue = "odfafepnkmbhccpbejgmiehpchacaeak"

        foreach ($setting in $cfg.GetEnumerator()) {
            Set-RegistryValue -Path $edgeKeyPath -Name $setting.Key -Type DWORD -Value $setting.Value
        }

        Set-RegistryValue -Path $microsoftKeyPath -Name "DoNotUpdateToEdgeWithChromium" -Type DWORD -Value 1
        Set-RegistryValue -Path $extensionPath -Name 1 -Type String -Value $extensionValue
        
        # ===========================
        # Disable Edge tasks
        # ===========================
        Get-ScheduledTask | ? {$_.TaskName -like "*Edge*"} | Disable-ScheduledTask *>$null
        Get-CimInstance Win32_StartupCommand | ? {$_.Name -like "*Edge*"} | % {Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" -Name $_.Name -Value ([byte[]](0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00)) -EA 0}

        Write-Host "Done."
    }

    if ($Brave) {
        Write-Host "Setting up Brave..."

        # ===========================
        # Paths
        # ===========================
        $dir = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
        $prefs = Join-Path $dir "Default\Preferences"
        $localState = Join-Path $dir "Local State"

        New-Item -Path (Split-Path $prefs) -ItemType Directory -Force *>$null
        New-Item -Path (Split-Path $localState) -ItemType Directory -Force *>$null

        $utf8 = [System.Text.UTF8Encoding]::new($false)
        
        function Merge ($dest, $src) {
            if ($null -eq $dest) {return}
            $src.PSObject.Properties | % {
                $key = $_.Name; $val = $_.Value
                if ($dest.PSObject.Properties[$key]) {
                    if ($val -is [pscustomobject] -and $dest.$key -is [pscustomobject]) {
                        Merge $dest.$key $val
                    } else {
                        $dest.$key = $val
                    }
                } else {
                    $dest | Add-Member -Name $key -Value $val -MemberType NoteProperty
                }
            }
        }

        # ===========================
        # Setup Preferences
        # ===========================
        $cfgText = @'
{
  "brave": {
    "brave_vpn": {"show_button": false},
    "new_tab_page": {
      "hide_all_widgets": true,
      "show_brave_news": false, "_comment": "false might not apply here (not sure why)",
      "show_stats": false,
      "show_together": false,
      "show_brave_vpn": false
    },
    "p3a": {"enabled": false, "notice_acknowledged": true},
    "rewards": {
      "inline_tip_buttons_enabled": false,
      "show_brave_rewards_button_in_location_bar": false
    },
    "show_side_panel_button": true,
    "sidebar": {"sidebar_show_option": 3},
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
    }
  }
}
'@

        $cfg = $cfgText | ConvertFrom-Json

        if (Test-Path $prefs) {
            try {
                $existing = Get-Content $prefs -Raw -EA 1 | ConvertFrom-Json
                Merge $existing $cfg
                [System.IO.File]::WriteAllText($prefs, ($existing | ConvertTo-Json -Depth 10), $utf8)
            } catch {
                [System.IO.File]::WriteAllText($prefs, $cfgText, $utf8)
            }
        } else {
            [System.IO.File]::WriteAllText($prefs, $cfgText, $utf8)
        }

        # ===========================
        # Setup LocalState
        # ===========================
        $cfgText = @'
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
'@

        $cfg = $cfgText | ConvertFrom-Json

        if (Test-Path $localState) {
            try {
                $existing = Get-Content $localState -Raw -EA 1 | ConvertFrom-Json
                Merge $existing $cfg
                [System.IO.File]::WriteAllText($localState, ($existing | ConvertTo-Json -Depth 10), $utf8)
            } catch {
                [System.IO.File]::WriteAllText($localState, $cfgText, $utf8)
            }
        } else {
            [System.IO.File]::WriteAllText($localState, $cfgText, $utf8)
        }

        # ===========================
        # Privacy policies
        # ===========================
        $policies = @{
            "SafeBrowsingExtendedReportingEnabled"    = 0
            "SafeBrowsingSurveysEnabled"              = 0
            "UrlKeyedAnonymizedDataCollectionEnabled" = 0
            "FeedbackSurveysEnabled"                  = 0
            "DomainReliabilityAllowed"                = 0
            "PrivacySandboxAdMeasurementEnabled"      = 0
            "PrivacySandboxAdTopicsEnabled"           = 0
            "PrivacySandboxPromptEnabled"             = 0
        }

        foreach ($setting in $policies.GetEnumerator()) {
            Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave" -Name $setting.Key -Type DWORD -Value $setting.Value
        }

        # ===========================
        # Disable Brave tasks
        # ===========================
        Get-ScheduledTask | ? {$_.TaskName -like "*Brave*"} | Disable-ScheduledTask *>$null
        Get-CimInstance Win32_StartupCommand | ? {$_.Name -like "*brave*"} | % {Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" -Name $_.Name -Value ([byte[]](0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00)) -EA 0}

        Write-Host "Done."
    }

    if ($Firefox) {
        Write-Host "Setting up Firefox..."

        # ===========================
        # Privacy & QoL policies
        # ===========================
        $policies = @'
{
  "policies": {
    "ExtensionSettings": {
      "uBlock0@raymondhill.net": {
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi",
        "installation_mode": "normal_installed"
      }
    },
    "FirefoxHome": {
      "SponsoredTopSites": false,
      "SponsoredPocket": false
    },
    "DisableFormHistory": true,
    "DisableFirefoxAccounts": true,
    "CaptivePortal": false,
    "DisableFirefoxStudies": true,
    "DisableTelemetry": true,
    "DisablePocket": true,
    "Preferences": {
      "browser.startup.page": 3,
      "browser.aboutConfig.showWarning": false,
      "browser.cache.offline.enable": true,
      "browser.crashReports.unsubmittedCheck.autoSubmit": false,
      "browser.fixup.alternate.enabled": false,
      "browser.search.suggest.enabled": false,
      "browser.selfsupport.url": "",
      "browser.sessionstore.privacy_level": 2,
      "browser.shell.checkDefaultBrowser": false,
      "browser.urlbar.groupLabels.enabled": false,
      "browser.urlbar.quicksuggest.enabled": false,
      "browser.urlbar.speculativeConnect.enabled": false,
      "browser.urlbar.trimURLs": false,
      "datareporting.policy.dataSubmissionEnabled": false,
      "dom.security.https_only_mode": true,
      "browser.tabs.crashReporting.sendReport": false,
      "network.predictor.enabled": false,
      "network.prefetch-next": false,
      "extensions.pocket.site": "",
      "extensions.pocket.oAuthConsumerKey": "",
      "extensions.pocket.api": "",
      "browser.backspace_action": 0,
      "browser.bookmarks.editDialog.maxRecentFolders": 12,
      "browser.bookmarks.max_backups": 2,
      "browser.bookmarks.showMobileBookmarks": true,
      "browser.bookmarks.showRecentlyBookmarked": true,
      "browser.defaultbrowser.notificationbar": false,
      "browser.download.autohideButton": false,
      "browser.download.folderList": 2,
      "browser.download.hide_plugins_without_extensions": false,
      "browser.download.manager.addToRecentDocs": false,
      "browser.pagethumbnails.capturing_disabled": true,
      "browser.search.context.loadInBackground": true,
      "browser.sessionstore.restore_on_demand": false,
      "browser.sessionstore.restore_tabs_lazily": false,
      "browser.startup.homepage.abouthome_cache.enabled": false,
      "browser.startup.preXulSkeletonUI": false,
      "browser.tabs.tabMinWidth": 120,
      "browser.tabs.warnOnClose": false,
      "browser.tabs.warnOnCloseOtherTabs": false,
      "browser.tabs.warnOnOpen": false,
      "browser.urlbar.autoFill": false,
      "browser.urlbar.autoFill.typed": false
    }
  }
}
'@

        $basePath = if (Test-Path "$env:ProgramFiles\Mozilla Firefox") {
            "$env:ProgramFiles\Mozilla Firefox"
        } else {
            "${env:ProgramFiles(x86)}\Mozilla Firefox"
        }

        $distPath = Join-Path $basePath "distribution"
        $filePath = Join-Path $distPath "policies.json"
        if (!(Test-Path $distPath)) {New-Item -Path $distPath -ItemType Directory -Force *>$null}

        $policies | Out-File -FilePath $filePath -Encoding ASCII -Force

        # ===========================
        # Disable Firefox tasks
        # ===========================
        Get-ScheduledTask | ? {$_.TaskName -like "*Firefox*"} | Disable-ScheduledTask *>$null

        Write-Host "Done."
    }

    if ($Chrome) {
        Write-Host "Setting up Chrome..."

        # ===========================
        # Paths
        # ===========================
        $dir = "$env:LOCALAPPDATA\Google\Chrome\User Data"
        $prefs = Join-Path $dir "Default\Preferences"
        $localState = Join-Path $dir "Local State"

        New-Item -Path (Split-Path $prefs) -ItemType Directory -Force *>$null
        New-Item -Path (Split-Path $localState) -ItemType Directory -Force *>$null

        $utf8 = [System.Text.UTF8Encoding]::new($false)
        
        function Merge ($dest, $src) {
            if ($null -eq $dest) {return}
            $src.PSObject.Properties | % {
                $key = $_.Name; $val = $_.Value
                if ($dest.PSObject.Properties[$key]) {
                    if ($val -is [pscustomobject] -and $dest.$key -is [pscustomobject]) {
                        Merge $dest.$key $val
                    } else {
                        $dest.$key = $val
                    }
                } else {
                    $dest | Add-Member -Name $key -Value $val -MemberType NoteProperty
                }
            }
        }

        # ===========================
        # Setup Preferences
        # ===========================
        $cfgText = @'
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
  }
} 
'@

        $cfg = $cfgText | ConvertFrom-Json

        if (Test-Path $prefs) {
            try {
                $existing = Get-Content $prefs -Raw -EA 1 | ConvertFrom-Json
                Merge $existing $cfg
                [System.IO.File]::WriteAllText($prefs, ($existing | ConvertTo-Json -Depth 10), $utf8)
            } catch {
                [System.IO.File]::WriteAllText($prefs, $cfgText, $utf8)
            }
        } else {
            [System.IO.File]::WriteAllText($prefs, $cfgText, $utf8)
        }

        # ===========================
        # Setup LocalState
        # ===========================
        $cfgText = @'
{
  "background_mode": {
    "enabled": false
  },
  "browser": {
    "first_run_finished": true
  }
}
'@

        $cfg = $cfgText | ConvertFrom-Json

        if (Test-Path $localState) {
            try {
                $existing = Get-Content $localState -Raw -EA 1 | ConvertFrom-Json
                Merge $existing $cfg
                [System.IO.File]::WriteAllText($localState, ($existing | ConvertTo-Json -Depth 10), $utf8)
            } catch {
                [System.IO.File]::WriteAllText($localState, $cfgText, $utf8)
            }
        } else {
            [System.IO.File]::WriteAllText($localState, $cfgText, $utf8)
        }

        # ===========================
        # Privacy policies
        # ===========================
        $policies = @{
            "PrivacySandboxPromptEnabled"             = 0
            "UrlKeyedAnonymizedDataCollectionEnabled" = 0
            "WebRtcEventLogCollectionAllowed"         = 0
            "CloudReportingEnabled"                   = 0
        }

        foreach ($setting in $policies.GetEnumerator()) {
            Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name $setting.Key -Type DWORD -Value $setting.Value
        }

        Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" -Name 1 -Type String -Value "ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx"

        # ===========================
        # Disable Chrome tasks
        # ===========================
        Get-ScheduledTask | ? {$_.TaskName -like "*Google*"} | Disable-ScheduledTask *>$null

        Write-Host "Done."
    }
}

function Install-NET3.5 {
    Write-Host "--- Install .NET Framework 3.5 ---" -F Green
    Write-Host "Enable .NET 3.5 feature using native cmdlets`n"

    # === Pre-Checks ===
    $status = Get-WindowsOptionalFeature -Online -FeatureName NetFx3 -EA 0
    if ($status.State -eq 'Enabled') {
        Write-Host ".NET Framework 3.5 is already installed."
        return
    }
    if (!(Test-Internet)) {
        Write-Host "Internet connection required." -F Red
        return
    }

    # === Installation ===
    Write-Host "Enabling feature..." -F DarkGray
    try {
        Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -All -NoRestart *>$null
    } catch {
        $tempDir = $env:TEMP
        $netfx = Join-Path $tempDir 'NetFx3.cab'
        $build = (Get-WmiObject Win32_OperatingSystem).BuildNumber
        switch ($build) {
            19045 {$url = "https://download.rapid-community.ru/download/files/components/NetFx3_amd64_19045.cab"}
            22621 {$url = "https://download.rapid-community.ru/download/files/components/NetFx3_amd64_22621.cab"}
            22631 {$url = "https://download.rapid-community.ru/download/files/components/NetFx3_amd64_22631.cab"}
            26100 {$url = "https://download.rapid-community.ru/download/files/components/NetFx3_amd64_26100.cab"}
            26200 {$url = "https://download.rapid-community.ru/download/files/components/NetFx3_amd64_26200.cab"}
            default {Write-Host "Build is not supported"; return}
        }
        Invoke-WebRequest -Uri $url -OutFile $netfx -EA 0
        Add-WindowsPackage -Online -PackagePath $netfx -NoRestart -IgnoreCheck *>$null
    }

    $status = Get-WindowsOptionalFeature -Online -FeatureName NetFx3
    if ($status.State -eq 'Enabled') {
        Write-Host "`nDone."
    } else {
        Write-Error "Failed to enable .NET Framework 3.5"
    }
}

function Install-DirectX {
    Write-Host "--- Install DirectX ---" -ForegroundColor Green
    Write-Host "Silent installation of legacy DirectX runtime components`n"

    # === Pre-Checks ===
    if (!(Test-Internet)) {
        Write-Host "Internet connection required." -F Red
        return
    }

    # === Variables ===
    $tempDir = $env:TEMP
    $directxExe = Join-Path $tempDir 'directx.exe'
    $extractDir = Join-Path $tempDir 'directx'

    # === Download ===
    Write-Host "Downloading DirectX package..." -ForegroundColor DarkGray
    Invoke-WebRequest -Uri "https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe" -OutFile $directxExe -UseBasicParsing

    Write-Host "Extracting files..." -ForegroundColor DarkGray
    Start-Process -FilePath $directxExe -ArgumentList "/Q /C /T:`"$extractDir`"" -WindowStyle Hidden -Wait

    # === Installation ===
    Write-Host "Installing DirectX..." -ForegroundColor DarkGray
    Start-Process -FilePath (Join-Path $extractDir 'DXSETUP.exe') -ArgumentList '/silent' -WindowStyle Hidden -Wait

    Write-Host "`nDone."
}

function Install-VCRedist {
    Write-Host "--- Install Visual C++ Redistributables ---" -F Green
    Write-Host "Silent installation of all VC++ runtime packages`n"
    
    # === Pre-Checks ===
    if (!(Test-Internet)) {
        Write-Host "Internet connection required." -F Red
        return
    }

    # === Variables ===
    $tempDir = $env:TEMP
    $src = 'https://kutt.it/vcpp'
    $exe = 'VisualCppRedist_AIO_x86_x64.exe'
    $exePath = Join-Path $tempDir $exe

    # === Download ===
    Write-Host "Downloading AIO package..." -F DarkGray
    Invoke-WebRequest -Uri $src -OutFile $exePath -UseBasicParsing -EA 0

    # === Installation ===
    Write-Host "Installing..." -F DarkGray
    $p = Start-Process -FilePath $exePath -ArgumentList @('/ai','/gm2') -PassThru -Wait -EA 0
    $exitCode = if ($p) {$p.ExitCode} else {-1}
    if ($exitCode -ne 0) {Write-Warning "Exit code: $exitCode"}

    Write-Host "`nDone."
}

# https://github.com/Andrew-J-Larson/OS-Scripts/blob/main/Windows/Apple/Enable-HEIC-Extension-Feature.ps1
function Install-MediaExtensions {
    Write-Host "--- Install HEIF & HEVC ---" -F Green
    Write-Host "Installing media extensions for free`n"

    # === Configuration ===
    $config = [PSCustomObject]@{
        Apps = @{
            HEIF = @{Name = "Microsoft.HEIFImageExtension_8wekyb3d8bbwe"}
            HEVC = @{Name = "Microsoft.HEVCVideoExtension_8wekyb3d8bbwe"}
        }
        Photos = "Microsoft.Windows.Photos_8wekyb3d8bbwe"
        TempDir = $env:TEMP
        Arch = switch ($env:PROCESSOR_ARCHITECTURE) {
            "x86" {"x86"}
            {"x64", "amd64" -contains $_} {"x64"}
            default {"neutral"}
        }
    }

    # === Pre-checks ===
    if (!(Test-Internet)) {
        Write-Host "Internet connection required." -F Red
        return
    }

    if (!(Get-AppxPackage -Name $config.Photos.Split("_")[0] -EA 0)) {
        Write-Host "Photos app missing." -F DarkGray
        return
    }

    # === Fetch package ===
    function Get-Package {
        param ($name)
        $params = @{type = "PackageFamilyName"; url = $name; ring = "Retail"; lang = "en-US"}
        $resp = Invoke-RestMethod "https://store.rg-adguard.net/api/GetFiles" -Method Post -Body $params -EA 0
        if (!$resp) {return $null}

        $list = New-Object Collections.ArrayList
        $pattern = '<tr style.*<a href=\"(?<url>.*)"\s.*>(?<file>.*\.(app|msi)x.*)<\/a>'
        $resp | Select-String $pattern -AllMatches | % {
            $_.Matches | % {
                $parts = $_.Groups["file"].Value -split "_"
                $list.Add(@{
                    Url = $_.Groups["url"].Value
                    File = $_.Groups["file"].Value
                    Version = $parts[1]
                    Arch = $parts[2].ToLower()
                    Type = ($_.Groups["file"].Value -split "\.")[-1].ToLower()
                }) *>$null
            }
        }

        $types = "msixbundle", "appxbundle", "msix", "appx"
        foreach ($type in $types) {
            $pkg = $list | ? {$_.Type -eq $type -and ($_.Arch -eq $config.Arch -or $_.Arch -eq "neutral")} | 
                   Sort Version -Descending | Select -First 1
            if ($pkg) {return $pkg}
        }
        $null
    }

    # === Installation ===
    foreach ($app in $config.Apps.Values) {
        $name = $app.Name.Split("_")[0]
        if (Get-AppxPackage -Name $name -EA 0) {
            Write-Host "`"$name`" already installed." -F DarkGray
            continue
        }

        try {
            $pkg = Get-Package $app.Name
        } catch {
            $pkg = $null
        }

        if (!$pkg) {
            if ($app.Name -like "Microsoft.HEIFImageExtension*") {
                $pkg = @{
                    Url  = 'https://download.rapid-community.ru/download/files/extensions/Microsoft.HEIFImageExtension.appxbundle'
                    File = 'Microsoft.HEIFImageExtension.appxbundle'
                }
            }
            elseif ($app.Name -like "Microsoft.HEVCVideoExtension*") {
                $pkg = @{
                    Url  = 'https://download.rapid-community.ru/download/files/extensions/Microsoft.HEVCVideoExtension.appxbundle'
                    File = 'Microsoft.HEVCVideoExtension.appxbundle'
                }
            }
        }

        $path = Join-Path $config.TempDir $pkg.File
        if (Test-Path $path) {del $path -Force -Recurse *>$null}

        Write-Host "Downloading $($pkg.File)..." -F DarkGray
        Invoke-WebRequest $pkg.Url -OutFile $path -EA 0

        Write-Host "Installing $name..." -F DarkGray
        Add-AppxPackage -Path $path -EA 0
    }

    Write-Host "`nDone."
}

function Uninstall-Edge {
    Write-Host "--- Uninstall Microsoft Edge ---" -F Green
    Write-Host "Removing Edge without any leftover files`n"

    # === Variables ===
    $baseKey = "HKLM:\SOFTWARE" + $(if ([Environment]::Is64BitOperatingSystem) {"\WOW6432Node"}) + "\Microsoft"
    $edgeExe = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    $uwpDir = "$env:WinDir\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
    $del = {param ($path) if (Test-Path $path) {del $path -Force -Recurse -Confirm:$false}}

    # === Stop processes ===
    $ErrorActionPreference = "SilentlyContinue"
    gci -Name "*edge*" | ? {(Get-Service $_).DisplayName -like "*Microsoft Edge*"} | % {Stop-Service $_ -Force}
    tasklist | ? {
        $_.Path -like "${env:ProgramFiles(x86)}\Microsoft\*" -or
        $_.Name -like "*msedge*"
    } | % {taskkill $_.Id -Force}
    $ErrorActionPreference = "Continue"

    # === Find uninstall keys ===
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

    # === Uninstall methods ===
    $setup = @()
    "LocalApplicationData", "ProgramFilesX86", "ProgramFiles" | % {
        $installDir = [Environment]::GetFolderPath($_)
        $setup += gci "$installDir\Microsoft\Edge*\setup.exe" -Recurse -EA 0 |
                  ? {$_ -like "*Edge\Application*" -or $_ -like "*SxS\Application*"}
    }

    $uninst = (Get-ItemProperty "$baseKey\Windows\CurrentVersion\Uninstall\Microsoft Edge" -EA 0).UninstallString
    $uninstExe = $null; $uninstArgs = $null
    if ($uninst) {
        $parts = $uninst -split '"' | ? {$_}
        $uninstExe, $uninstArgs = $parts | % {[Environment]::ExpandEnvironmentVariables($_.Trim())}
        if (!(Test-Path $uninstExe -PathType Leaf)) {
            $uninstExe = $null
            Write-Host "Invalid uninstall path from registry." -F Red
        }
    }

    if (!$msi -and !$setup -and !$uninstExe) {
        Write-Host "No uninstaller found." -F Red
        if (!(Test-Path $edgeExe)) {Write-Host "Edge likely already uninstalled." -F DarkGray}
        return
    }

    Write-Host "Found Edge uninstallers." -F DarkGray
    reg delete "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\ClientState\{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}" /v "experiment_control_labels" /f *>$null
    $devKey = "$baseKey\EdgeUpdateDev"
    if (!(Test-Path $devKey)) {mkdir $devKey -Force *>$null}
    Set-RegistryValue -Path $devKey -Name "AllowUninstall" -Type String -Value ""

    # === Attempt uninstall methods ===
    $fail = $true; $i = 1
    while ($fail -and $i -le 4) {
        switch ($i) {
            1 {
                Write-Host "Method 1: fake UWP file..." -F DarkGray
                $clean = $false
                if (!(Test-Path "$uwpDir\MicrosoftEdge.exe")) {
                    mkdir $uwpDir *>$null
                    New-Item "$uwpDir\MicrosoftEdge.exe" *>$null
                    $clean = $true
                }
                foreach ($id in $msi) {
                    Start-Process "msiexec.exe" -ArgumentList "/qn /X$id REBOOT=ReallySuppress /norestart" -Wait
                }
                if ($uninstExe) {
                    Start-Process $uninstExe -ArgumentList "$uninstArgs --force-uninstall" -Wait -WindowStyle Hidden
                } else {
                    foreach ($item in $setup) {
                        if (Test-Path $item) {
                            $level = if ($item -like "*\AppData\Local\*") {"--user-level"} else {"--system-level"}
                            Start-Process $item -ArgumentList "--uninstall --msedge $level --channel=stable --verbose-logging --force-uninstall" -Wait
                        }
                    }
                }
                if ($clean) {Write-Host "Cleanup method 1..." -F DarkGray; & $del $uwpDir}
                $fail = Test-Path $edgeExe
            }
            2 {
                Write-Host "Method 2: bypass WinDir feature..." -F DarkGray
                $envKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
                Set-RegistryValue -Path $envKey -Name "WinDir" -Type ExpandString -Value ""
                $env:WinDir = [Environment]::GetEnvironmentVariable("WinDir", "Machine")
                foreach ($id in $msi) {
                    Start-Process "msiexec.exe" -ArgumentList "/qn /X$id REBOOT=ReallySuppress /norestart" -Wait
                }
                if ($uninstExe) {
                    Start-Process $uninstExe -ArgumentList "$uninstArgs --force-uninstall" -Wait -WindowStyle Hidden
                } else {
                    foreach ($item in $setup) {
                        if (Test-Path $item) {
                            $level = if ($item -like "*\AppData\Local\*") {"--user-level"} else {"--system-level"}
                            Start-Process $item -ArgumentList "--uninstall --msedge $level --channel=stable --verbose-logging --force-uninstall" -Wait
                        }
                    }
                }
                Write-Host "Cleanup method 2..." -F DarkGray
                Set-RegistryValue -Path $envKey -Name "WinDir" -Type ExpandString -Value "%SystemRoot%"
                $fail = Test-Path $edgeExe
            }
            3 {
                Write-Host "Method 3: EU region setting..." -F DarkGray
                $geoKey = "HKU:\.DEFAULT\Control Panel\International\Geo"
                $geoVals = @{"Name"="FR"; "Nation"="84"}
                $suffix = "EdgeSaved"
                foreach ($entry in $geoVals.GetEnumerator()) {
                    reg delete $geoKey /v $entry.Key /f *>$null
                    reg delete $geoKey /v "$($entry.Key)$suffix" /f *>$null
                }
                foreach ($id in $msi) {
                    Start-Process "msiexec.exe" -ArgumentList "/qn /X$id REBOOT=ReallySuppress /norestart" -Wait
                }
                if ($uninstExe) {
                    Start-Process $uninstExe -ArgumentList "$uninstArgs --force-uninstall" -Wait -WindowStyle Hidden
                } else {
                    foreach ($item in $setup) {
                        if (Test-Path $item) {
                            $level = if ($item -like "*\AppData\Local\*") {"--user-level"} else {"--system-level"}
                            Start-Process $item -ArgumentList "--uninstall --msedge $level --channel=stable --verbose-logging --force-uninstall" -Wait
                        }
                    }
                }
                Write-Host "Cleanup method 3..." -F DarkGray
                foreach ($entry in $geoVals.GetEnumerator()) {
                    reg delete $geoKey /v $entry.Key /f *>$null
                    reg delete $geoKey /v "$($entry.Key)$suffix" /f *>$null
                }
                $fail = Test-Path $edgeExe
            }
            4 {
                Write-Host "Method 4: edit region policy JSON..." -F DarkGray
                $jsonFile = "$env:WinDir\System32\IntegratedServicesRegionPolicySet.json"
                $clean = $false
                if (Test-Path $jsonFile) {
                    $clean = $true
                    try {
                        takeown /f $jsonFile /a *>$null
                        icacls $jsonFile /grant *S-1-5-32-544:F /t /q *>$null
                        $data = type $jsonFile | ConvertFrom-Json
                        foreach ($policy in $data.policies) {
                            if ($policy.'$comment' -like "*Edge*" -and $policy.'$comment' -like "*uninstall*") {
                                $policy.defaultState = "enabled"
                            }
                        }
                        $newJson = $data | ConvertTo-Json -Depth 100
                        $backup = "IntegratedServicesRegionPolicySet.json.$([IO.Path]::GetRandomFileName())"
                        move $jsonFile $backup -Force
                        Set-Content $jsonFile $newJson -Encoding UTF8
                    } catch {
                        Write-Host $_
                    }
                }
                foreach ($id in $msi) {
                    Start-Process "msiexec.exe" -ArgumentList "/qn /X$id REBOOT=ReallySuppress /norestart" -Wait
                }
                if ($uninstExe) {
                    Start-Process $uninstExe -ArgumentList "$uninstArgs --force-uninstall" -Wait -WindowStyle Hidden
                } else {
                    foreach ($item in $setup) {
                        if (Test-Path $item) {
                            $level = if ($item -like "*\AppData\Local\*") {"--user-level"} else {"--system-level"}
                            Start-Process $item -ArgumentList "--uninstall --msedge $level --channel=stable --verbose-logging --force-uninstall" -Wait
                        }
                    }
                }
                if ($clean) {
                    Write-Host "Cleanup method 4..." -F DarkGray
                    & $del $jsonFile *>$null
                    move "$env:WinDir\System32\$backup" $jsonFile -Force *>$null
                }
                $fail = Test-Path $edgeExe
            }
        }
        if (!$fail) {
            Write-Host "Edge removed via method $i." -F DarkGray
            break
        }
        $i++
    }

    if ($fail -and $i -gt 4) {
        Write-Host "All uninstall methods failed." -F Red
        return
    }

    # === Final cleanup ===
    & $del "$([Environment]::GetFolderPath("Desktop"))\Microsoft Edge.lnk"
    & $del "$([Environment]::GetFolderPath("CommonStartMenu"))\Microsoft Edge.lnk"
    if ((Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -EA 0).ShowCopilotButton -eq 1) {
        taskkill /f /im explorer.exe *>$null
    }

    $sid = (New-Object Security.Principal.NTAccount([Environment]::UserName)).Translate([Security.Principal.SecurityIdentifier]).Value
    $appx = "\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore"
    $appxRoot = "HKLM:$appx"
    $inboxPath = Join-Path $appxRoot 'InboxApplications'
    $eolRoot = Join-Path (Join-Path $appxRoot 'EndOfLife') $sid

    gci $inboxPath -EA 0 | ? {$_.PSChildName -like '*Edge*'} | % {reg delete "HKLM$appx\InboxApplications\$($_.PSChildName)" /f *>$null}
    
    $edgePkgs = Get-AppxPackage -AllUsers -EA 0 | ? {
        $_.Name -like '*Edge*' -or 
        $_.PackageFamilyName -like '*Edge*' -or 
        $_.Name -like '*Microsoft.Edge.GameAssist*'
    } | Select PackageFullName, PackageFamilyName, NonRemovable, PackageUserInformation

    if ($edgePkgs) {
        $families = $edgePkgs | Select -Expand PackageFamilyName | Sort-Object -Unique
        $families | % {mkdir (Join-Path $eolRoot $_) -Force *>$null}
    }

    $ErrorActionPreference = 'SilentlyContinue'
    if ($edgePkgs) {
        ($edgePkgs | Select -Expand PackageFamilyName | Sort-Object -Unique) | % {Set-NonRemovableAppsPolicy -Online -PackageFamilyName $_ -NonRemovable 0 *>$null}
        $prov = Get-AppxProvisionedPackage -Online -EA 0 | ? {$_.PackageName -like '*Edge*' -or $_.DisplayName -like '*Edge*' -or $_.DisplayName -like '*Microsoft.Edge.GameAssist*'}
        if ($prov) {$prov | % {Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName *>$null}}
        $edgePkgs | % {
            $pkgName = $_.PackageFullName
            if ($pkgName -and $pkgName.Trim() -ne '') {Remove-AppxPackage -Package $pkgName -AllUsers *>$null}
            $pui = $_.PackageUserInformation
            if ($pui) {
                $pui | % {
                    $sidUser = $_.UserSecurityID.SID
                    if (!$sidUser) {$sidUser = $_.UserSecurityId}
                    if (!$sidUser -or $sidUser -match '^S-1-5-(18|19|20)$') {return}
                    Remove-AppxPackage -Package $pkgName -User $sidUser *>$null
                }
            }
        }
    }
    $ErrorActionPreference = 'Continue'

    if ($families) {
        if ($del) {
            $families | % {& $del (Join-Path $eolRoot $_) *>$null}
        } else {
            $families | % {del (Join-Path $eolRoot $_) -Recurse -Force -EA 0 *>$null}
        }
    }

    Get-ScheduledTask | ? {$_.TaskName -like "*Edge*" -or $_.TaskPath -like "*Edge*"} | % {Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false -EA 0}

    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" | % {
        $entries = Get-ItemProperty $_ -EA 0
        if ($entries) {
            $entries.PSObject.Properties | ? {$_.Name -like "*Edge*"} | % {Remove-ItemProperty $_ $_.Name -Force *>$null}
        }
    }

    Write-Host "`nDone."
}

function Uninstall-OneDrive {
    Write-Host "--- Uninstall OneDrive ---" -F Green
    Write-Host "Uninstalling OneDrive with deep system cleanup`n"

if (!("WinAPI.DeleteFiles" -as [type])) {
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
"@
}

    # === Stop processes ===
    Write-Host "Terminating OneDrive processes" -F DarkGray
    "OneDrive.exe", "OneDriveSetup.exe", "FileCoAuth.exe" | % {taskkill /f /im $_ *>$null}

    # === Run uninstall ===
    $uninstallString = Get-Package -Name "Microsoft OneDrive" -ProviderName Programs -EA 0 | % -Process {$_.Meta.Attributes["UninstallString"]}
    if (!$uninstallString) {
        Write-Host "Uninstall string not found." -F Red
        return
    }

    Write-Host "Executing OneDrive uninstall..." -F DarkGray
    $params = ($uninstallString -replace '\s*/', ',/') -split ',' | % {$_.Trim()}
    switch ($params.Count) {
        2 {Start-Process -FilePath $params[0] -ArgumentList $params[1] -Wait -EA 0}
        default {Start-Process -FilePath $params[0] -ArgumentList $params[1..2] -Wait -EA 0}
    }
    $installDir = (Split-Path (Split-Path $params[0] -Parent)) -replace '"', ''

    # === Clean user folder ===
    Write-Host "Removing OneDrive user data..." -F DarkGray
    if ($env:OneDrive -and (Test-Path $env:OneDrive)) {
        del $env:OneDrive -Recurse -Force -EA 0
        gci $env:OneDrive -Recurse -Force -EA 0 | % {[WinAPI.DeleteFiles]::MarkFileDelete($_.FullName) *>$null}
    }

    # === Clean system ===
    Write-Host "Clearing registry, tasks, and folders..." -F DarkGray
    Remove-ItemProperty -Path "HKCU:\Environment" -Name OneDrive,OneDriveConsumer -Force -EA 0
    $paths = @(
        "HKCU:\SOFTWARE\Microsoft\OneDrive",
        "$env:ProgramData\Microsoft OneDrive"
    )
    del $paths -Recurse -Force -EA 0
    Unregister-ScheduledTask -TaskName "*OneDrive*" -Confirm:$false -EA 0

    # === Process DLLs ===
    Write-Host "Unregistering and removing DLLs..." -F DarkGray
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoRestartShell" -Type DWORD -Value 0
    taskkill /f /im explorer.exe *>$null
    Start-Sleep -s 4
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoRestartShell" -Type DWORD -Value 1
    $dlls = gci "$installDir\*FileSyncShell64.dll" -Force -EA 0
    $dlls | % {
        Start-Process "$env:WinDir\System32\regsvr32.exe" -ArgumentList "/u /s $_" -Wait -EA 0
        del $_ -Force -EA 0
        if (Test-Path $_) {[WinAPI.DeleteFiles]::MarkFileDelete($_) *>$null}
    }
    Start-Process "$env:WinDir\explorer.exe"

    # === Final cleanup ===
    Write-Host "Cleaning up remaining files..." -F DarkGray
    if ($installDir -and (Test-Path $installDir)) {
        del $installDir -Recurse -Force -EA 0
    }

    Write-Host "`nDone."
}

function Uninstall-PCHealthCheck {
    Write-Host "--- Uninstall PC Health Check ---" -F Green
    Write-Host "Uninstalling PC Health Check with permanent block`n"

    # === Find GUID and uninstall ===
    Write-Host "Searching for installed app..." -F DarkGray
    $apps = Get-CimInstance -ClassName Win32_Product | ? {$_.Name -like "*PC Health Check*"}
    if ($apps) {
        $apps | % {
            $id = $_.IdentifyingNumber
            if ($id) {
                Start-Process "msiexec.exe" -ArgumentList "/x $id /quiet /norestart" -Wait *>$null
            }
        }
    } else {
        Write-Host "App not found." -F DarkGray
    }

    # === Block reinstall ===
    Write-Host "Blocking future reinstall..." -F DarkGray
    $regKey = "HKLM:\SOFTWARE\Microsoft\PCHC"
    if (!(Test-Path $regKey)) {
        mkdir $regKey -EA 0 *>$null
    }
    Set-RegistryValue -Path $regKey -Name "PreviousUninstall" -Type DWORD -Value 1

    Write-Host "`nDone."
}

function Uninstall-InstallationAssistant {
    Write-Host "--- Remove Windows Installation Assistant ---" -F Green
    Write-Host "Uninstalling Installation Assistant completely`n"

    # === Uninstall assistant ===
    Write-Host "Searching for installation assistant..." -F DarkGray
    $path = Join-Path ${env:ProgramFiles(x86)} "WindowsInstallationAssistant"
    $exePath = Join-Path $path "Windows10UpgraderApp.exe"

    if (Test-Path $exePath) {
        Start-Process -FilePath $exePath -ArgumentList "/SunValley /ForceUninstall" -NoNewWindow -Wait
        del $path -Recurse -Force -EA 0 *>$null
        Write-Host "Removal successful." -F DarkGray
    } else {
        Write-Host "Windows Installation Assistant not found." -F DarkGray
    }

    Write-Host "`nDone."
}

gci -Path $env:TEMP | ? {$_.Name -ne 'AME'} | del -Recurse -Force -EA 0

# ===========================
# Function call based on the argument
# ===========================
foreach ($arg in $Software) {
    switch ($arg) {
        # === Microsoft Edge ===
        "Install-Edge" {Install-Browser -Edge}
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
        "Install-Brave" {Install-Browser -Brave}
        "Optimize-Brave" {Optimize-Browser -Brave}

        # === Vivaldi Browser ===
        "Install-Vivaldi" {Install-Browser -Vivaldi}

        # === Firefox Browser ===
        "Install-Firefox" {Install-Browser -Firefox}
        "Optimize-Firefox" {Optimize-Browser -Firefox}

        # === Chrome Browser ===
        "Install-Chrome" {Install-Browser -Chrome}
        "Optimize-Chrome" {Optimize-Browser -Chrome}

        # === Thorium Browser ===
        "Install-Thorium" {Install-Browser -Thorium}

        # === Mercury Browser ===
        "Install-Mercury" {Install-Browser -Mercury}

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