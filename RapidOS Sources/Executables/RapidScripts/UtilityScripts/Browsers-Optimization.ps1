param (
    [string[]]$MyArgument
)

# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) { Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow; $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -MyArgument {1}" -f $PSCommandPath, $MyArgument; Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs; exit }

# Function to set registry values
function Set-RegistryValue {
    param (
        [string]$Path,
        [string]$Name,
        [string]$Type,
        [string]$Value
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Type $Type -Value $Value -Force
}

# Configure Microsoft Edge settings
function Set-MSEdgeConfiguration {
    param (
        [switch]$ConfigurePolicies,
        [switch]$EnableUpdates,
        [switch]$DisableUpdates
    )

    $edgeKeyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    $microsoftKeyPath = "HKLM:\SOFTWARE\Microsoft"
    $extensionPath = "HKCU:\Software\Policies\Microsoft\Edge\ExtensionInstallForcelist"
    $extensionValue = "odfafepnkmbhccpbejgmiehpchacaeak"

    if ($ConfigurePolicies) {
        $edgeSettings = @{
            # "BrowserSignin"                      = 0
            "StartupBoostEnabled"                  = 0
            "BingAdsSuppression"                   = 1
            "BackgroundModeEnabled"                = 0
            "ComponentUpdatesEnabled"              = 0
            "EdgeShoppingAssistantEnabled"         = 0
            "ForceGoogleSafeSearch"                = 1
            "HubsSidebarEnabled"                   = 0
            "CopilotCDPPageContext"                = 0
            "CopilotPageContext"                   = 0
            "AutoImportAtFirstRun"                 = 4
            "ImportOnEachLaunch"                   = 0
            "NewTabPageHideDefaultTopSites"        = 0
            "DefaultBrowserSettingEnabled"         = 0
            "EdgeCollectionsEnabled"               = 0
            "HideFirstRunExperience"               = 1
            "GamerModeEnabled"                     = 1
            "NewTabPageQuickLinksEnabled"          = 0
            "UserFeedbackAllowed"                  = 0
            "NewTabPagePrerenderEnabled"           = 0
            "NewTabPageContentEnabled"             = 0
            "NewTabPageAppLauncherEnabled"         = 0
            "ShowRecommendationsEnabled"           = 0
            "ConfigureDoNotTrack"                  = 1
            "AlternateErrorPagesEnabled"           = 0
            "MicrosoftEdgeInsiderPromotionEnabled" = 0
            "ShowMicrosoftRewards"                 = 0
            "WebWidgetAllowed"                     = 0
            "EdgeAssetDeliveryServiceEnabled"      = 0
            "WalletDonationEnabled"                = 0
            "RestoreOnStartup"                     = 1
        }

        foreach ($setting in $edgeSettings.GetEnumerator()) {
            Set-RegistryValue -Path $edgeKeyPath -Name $setting.Key -Type DWORD -Value $setting.Value
        }

        Set-RegistryValue -Path $microsoftKeyPath -Name "DoNotUpdateToEdgeWithChromium" -Type DWORD -Value 1
        Set-RegistryValue -Path $extensionPath -Name 1 -Type String -Value $extensionValue

        Write-Host "Microsoft Edge policies were applied!" -ForegroundColor Green
    }

    if ($EnableUpdates) {
        <# $edgeUpdatePath = "HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdate"
        $edgeUpdateMPath = "HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdatem"

        # Restore ImagePath if it has "modified" prefix
        if (Test-Path $edgeUpdatePath) {
            $currentImagePath = (Get-ItemProperty -Path $edgeUpdatePath).ImagePath
            if ($currentImagePath -like "modified *") {
                # Remove "modified" prefix
                $originalImagePath = $currentImagePath -replace "^modified ", ""
                Set-RegistryValue -Path $edgeUpdatePath -Name "ImagePath" -Type String -Value $originalImagePath
            }
        }
        if (Test-Path $edgeUpdateMPath) {
            $currentImagePath = (Get-ItemProperty -Path $edgeUpdateMPath).ImagePath
            if ($currentImagePath -like "modified *") {
                # Remove "modified" prefix
                $originalImagePath = $currentImagePath -replace "^modified ", ""
                Set-RegistryValue -Path $edgeUpdateMPath -Name "ImagePath" -Type String -Value $originalImagePath
            }
        }

        # Enable updates by setting Start value to 3
        Set-RegistryValue -Path $edgeUpdatePath -Name Start -Type DWord -Value 3
        Set-RegistryValue -Path $edgeUpdateMPath -Name Start -Type DWord -Value 3 #>

        # Unblock internet access for Microsoft Edge update process
        netsh advfirewall firewall delete rule name="Disable Edge Updates" program="C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe"

        # Get and enable all scheduled tasks related to Microsoft Edge updates
        $edgeTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*Edge*" -or $_.TaskPath -like "*Edge*" }
        
        if ($edgeTasks) {
            foreach ($task in $edgeTasks) {
                Enable-ScheduledTask -TaskName $task.TaskName
                Write-Host "Enabled task: $($task.TaskName)" -ForegroundColor Green
            }
        } else {
            Write-Host "No Microsoft Edge related tasks found to enable." -ForegroundColor Yellow
        }

        # Unlock and rename back Microsoft Edge Update file
        $edgeUpdatePath = "C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe"
        $modifiedEdgeUpdatePath = "C:\Program Files (x86)\Microsoft\EdgeUpdate\modified_MicrosoftEdgeUpdate.exe"
        
        # Unlock and rename back if modified file exists
        if (Test-Path -Path $modifiedEdgeUpdatePath) {
            icacls $modifiedEdgeUpdatePath /grant *S-1-1-0:F
            Rename-Item -Path $modifiedEdgeUpdatePath -NewName "MicrosoftEdgeUpdate.exe"
            Write-Host "File unlocked and renamed back to 'MicrosoftEdgeUpdate.exe'."
        } else {
            Write-Host "Modified file not found: $modifiedEdgeUpdatePath"
        }

        Write-Host "Microsoft Edge updates were enabled!" -ForegroundColor Green
    }

    if ($DisableUpdates) {
        <# $edgeUpdatePath = "HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdate"
        $edgeUpdateMPath = "HKLM:\SYSTEM\CurrentControlSet\Services\edgeupdatem"

        # Add "modified" prefix to ImagePath if it doesn't exist
        if (Test-Path $edgeUpdatePath) {
            $currentImagePath = (Get-ItemProperty -Path $edgeUpdatePath).ImagePath
            if (-not ($currentImagePath -like "modified *")) {
                Set-RegistryValue -Path $edgeUpdatePath -Name "ImagePath" -Type String -Value "modified $($currentImagePath)"
            }
        }
        if (Test-Path $edgeUpdateMPath) {
            $currentImagePath = (Get-ItemProperty -Path $edgeUpdateMPath).ImagePath
            if (-not ($currentImagePath -like "modified *")) {
                Set-RegistryValue -Path $edgeUpdateMPath -Name "ImagePath" -Type String -Value "modified $($currentImagePath)"
            }
        }

        # Disable updates by setting Start value to 4
        Set-RegistryValue -Path $edgeUpdatePath -Name Start -Type DWord -Value 4
        Set-RegistryValue -Path $edgeUpdateMPath -Name Start -Type DWord -Value 4 #>

        # Block internet access for Microsoft Edge update process
        # The script renames MicrosoftEdgeUpdate.exe to a modified version (modified_MicrosoftEdgeUpdate.exe)
        # The netsh command prevents Edge from updating if the original MicrosoftEdgeUpdate.exe comes back
        netsh.exe advfirewall firewall add rule name="Disable Edge Updates" dir=out action=block program="C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe"

        # Get and disable all scheduled tasks related to Microsoft Edge updates
        $edgeTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like "*Edge*" -or $_.TaskPath -like "*Edge*" }

        if ($edgeTasks) {
            foreach ($task in $edgeTasks) {
                Disable-ScheduledTask -TaskName $task.TaskName
                Write-Host "Disabled task: $($task.TaskName)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "No Microsoft Edge related tasks found to disable." -ForegroundColor Green
        }

        # Rename and lock the Microsoft Edge Update file
        $edgeUpdatePath = "C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe"
        $modifiedEdgeUpdatePath = "C:\Program Files (x86)\Microsoft\EdgeUpdate\modified_MicrosoftEdgeUpdate.exe"

        # Rename and lock the file if it exists
        if (Test-Path -Path $edgeUpdatePath) {
            Rename-Item -Path $edgeUpdatePath -NewName "modified_MicrosoftEdgeUpdate.exe"
            icacls $modifiedEdgeUpdatePath /deny *S-1-1-0:F
            Write-Host "File renamed to 'modified_MicrosoftEdgeUpdate.exe' and locked."
        } else {
            Write-Host "File not found: $edgeUpdatePath"
        }

        Write-Host "Microsoft Edge updates were disabled!" -ForegroundColor Green
    }
}

# Configure Firefox settings
function Set-FirefoxConfiguration {
    param (
        [switch]$ConfigurePolicies,
        [switch]$EnableUpdates,
        [switch]$DisableUpdates
    )

    if ($ConfigurePolicies) {
        $filePath = "C:\Program Files\Mozilla Firefox\distribution\policies.json"
        
        <# if (Test-Path $filePath) {
            $overwrite = Read-Host "policies.json already exists. Do you want to overwrite it? (Y/N)"
            if ($overwrite -ne 'Y') {
                return
            }
        } #>

        $policies = @"
{
  "policies": {
    "DisableFormHistory": true,
    "DisableFirefoxAccounts": true,
    "ExtensionSettings": {
      "uBlock0@raymondhill.net": {
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi",
        "installation_mode": "normal_installed"
      },
      "jid1-MnnxcxisBPnSXQ@jetpack": {
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi",
        "installation_mode": "normal_installed"
      }
    },
    "DisableAppUpdate": false,
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
      "browser.safebrowsing.enabled": false,
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
      "network.dns.disableIPv6": false,
      "network.websocket.enabled": true,
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
      "browser.sessionstore.resume_from_crash": true,
      "browser.sessionstore.restore_on_demand": false,
      "browser.sessionstore.restore_tabs_lazily": false,
      "browser.startup.homepage.abouthome_cache.enabled": false,
      "browser.startup.preXulSkeletonUI": false,
      "browser.tabs.tabMinWidth": 120,
      "browser.tabs.warnOnClose": false,
      "browser.tabs.warnOnCloseOtherTabs": false,
      "browser.tabs.warnOnOpen": false,
      "browser.urlbar.autoFill": false,
      "browser.urlbar.autoFill.typed": false,
      "media.autoplay.default": 0,
      "media.autoplay.block-event.enabled": false
    }
  },
  "Permissions": {
    "Autoplay": {
      "Default": "allow-all"
    }
  }
}
"@

        if (-not (Test-Path "C:\Program Files\Mozilla Firefox\distribution")) {
            New-Item -Path "C:\Program Files\Mozilla Firefox\distribution" -ItemType Directory -Force
        }

        $policies | Out-File -FilePath $filePath -Encoding ASCII -Force
        Write-Host "policies.json has been created or overwritten." -ForegroundColor Green
    }

    if ($EnableUpdates) {
        $filePath = "C:\Program Files\Mozilla Firefox\distribution\policies.json"
        
        if (Test-Path $filePath) {
            $jsonContent = Get-Content -Path $filePath -Raw | ConvertFrom-Json
            
            if ($jsonContent.policies.DisableAppUpdate -eq $true) {
                $jsonContent.policies.DisableAppUpdate = $false
                $jsonContent | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Force
                Write-Host "'DisableAppUpdate' has been set to false." -ForegroundColor Green
            } elseif ($jsonContent.policies.DisableAppUpdate -eq $false) {
                Write-Host "'DisableAppUpdate' is already set to false." -ForegroundColor Green
            } else {
                Write-Host "'DisableAppUpdate' is not present or set to a different value." -ForegroundColor Yellow
            }
        } else {
            $policies = @"
{
  "policies": {
    "DisableAppUpdate": false
  }
}
"@

            if (-not (Test-Path "C:\Program Files\Mozilla Firefox\distribution")) {
                New-Item -Path "C:\Program Files\Mozilla Firefox\distribution" -ItemType Directory -Force
            }

            $policies | Out-File -FilePath $filePath -Encoding ASCII -Force
            Write-Host "'DisableAppUpdate' has been set to false and policy file created." -ForegroundColor Green
        }

        Stop-Service -Name 'MozillaMaintenance' -Force; Set-Service -Name 'MozillaMaintenance' -StartupType Manual
        Write-Host "MozillaMaintenance service has been enabled." -ForegroundColor Green
    }

    if ($DisableUpdates) {
        $filePath = "C:\Program Files\Mozilla Firefox\distribution\policies.json"
        
        if (Test-Path $filePath) {
            $jsonContent = Get-Content -Path $filePath -Raw | ConvertFrom-Json
            
            if ($jsonContent.policies.DisableAppUpdate -eq $false) {
                $jsonContent.policies.DisableAppUpdate = $true
                $jsonContent | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Force
                Write-Host "'DisableAppUpdate' has been set to true." -ForegroundColor Green
            } elseif ($jsonContent.policies.DisableAppUpdate -eq $true) {
                Write-Host "'DisableAppUpdate' is already set to true." -ForegroundColor Green
            } else {
                Write-Host "'DisableAppUpdate' is not present or set to a different value." -ForegroundColor Yellow
            }
        } else {
            $policies = @"
{
  "policies": {
    "DisableAppUpdate": true
  }
}
"@

            if (-not (Test-Path "C:\Program Files\Mozilla Firefox\distribution")) {
                New-Item -Path "C:\Program Files\Mozilla Firefox\distribution" -ItemType Directory -Force
            }

            $policies | Out-File -FilePath $filePath -Encoding ASCII -Force
            Write-Host "'DisableAppUpdate' has been set to true and policy file created." -ForegroundColor Green
        }

        Stop-Service -Name 'MozillaMaintenance' -Force; Set-Service -Name 'MozillaMaintenance' -StartupType Disabled
        Write-Host "MozillaMaintenance service has been disabled." -ForegroundColor Green
    }
}

### I'm working on resolving the issue because Brave isn't applying my policy, and Chrome is blocking the policies set in the registry
<#
# Configure Brave settings
function Optimize-Brave {
    $jsonConfig = @"
{
  "brave": {
      "brave_vpn": {
          "show_button": false
      },
      "new_tab_page": {
          "hide_all_widgets": true
      },
      "p3a": {
          "enabled": false,
          "notice_acknowledged": true
      },
      "rewards": {
          "inline_tip_buttons_enabled": false,
          "show_brave_rewards_button_in_location_bar": false
      },
      "show_side_panel_button": false,
      "sidebar": {
          "sidebar_show_option": 0
      },
      "stats": {
          "reporting_enabled": false
      },
      "wallet": {
          "show_wallet_icon_on_toolbar": false
      },
      "webtorrent_enabled": false
  },
  "browser": {
      "first_run_finished": true,
      "has_seen_welcome_page": true
  },
  "user_experience_metrics": {
      "reporting_enabled": false
  }
}
"@

    $localAppDataPath = [System.IO.Path]::Combine($env:LOCALAPPDATA, "BraveSoftware", "Brave-Browser", "Application", "initial_preferences")
    $programFilesPath = [System.IO.Path]::Combine($env:ProgramFiles, "BraveSoftware", "Brave-Browser", "Application", "initial_preferences")

    if (-not (Test-Path -Path (Split-Path -Path $localAppDataPath -Parent))) {
        New-Item -Path (Split-Path -Path $localAppDataPath -Parent) -ItemType Directory -Force
    }
    $jsonConfig | Set-Content -Path $localAppDataPath
    Write-Host "Config file saved to: $localAppDataPath"

    if (-not (Test-Path -Path (Split-Path -Path $programFilesPath -Parent))) {
        New-Item -Path (Split-Path -Path $programFilesPath -Parent) -ItemType Directory -Force
    }
    $jsonConfig | Set-Content -Path $programFilesPath
    Write-Host "Config file saved to: $programFilesPath"

    Write-Host "Brave configuration completed successfully!" -ForegroundColor Green
}

# Configure Chrome settings
function Optimize-Chrome {
    $basechromereg = "HKLM:\SOFTWARE\Policies\Google\Chrome"
    # Apply optimization tweaks
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\DisallowRun" -Name "software_reporter_tool.exe" -Type String -Value 1
    Set-RegistryValue -Path $basechromereg -Name "MetricsReportingEnabled" -Type DWORD -Value 0
    Set-RegistryValue -Path $basechromereg -Name "DefaultPopupsSetting" -Type DWORD -Value 0
    Set-RegistryValue -Path $basechromereg -Name "DefaultSensorsSetting" -Type DWORD -Value 0
    Set-RegistryValue -Path $basechromereg -Name "UserFeedbackAllowed" -Type DWORD -Value 0
    Set-RegistryValue -Path $basechromereg -Name "SpellCheckServiceEnabled" -Type DWORD -Value 0
    Set-RegistryValue -Path $basechromereg -Name "SpellcheckEnabled" -Type DWORD -Value 0
    Set-RegistryValue -Path $basechromereg -Name "HomepageIsNewTabPage" -Type DWORD -Value 0
    Set-RegistryValue -Path $basechromereg -Name "BackgroundModeEnabled" -Type DWORD -Value 0
    Set-RegistryValue -Path $basechromereg -Name "RestoreOnStartup" -Type DWORD -Value 1

    # Install uBlockOrigin
    $basePath = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
    $extensionId = "ddkjiahejlhfcafbddmgiahcphecmpfh"
    $extensionURL = "https://clients2.google.com/service/update2/crx"

    Set-RegistryValue -Path $basePath -Name "1" -Type String -Value "$extensionId;$extensionURL"

    Write-Host "Chrome configuration completed successfully!" -ForegroundColor Green
} #>

function Install-uBlockOriginforChrome {
    # Install uBlockOrigin
    $basePath = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
    $extensionId = "ddkjiahejlhfcafbddmgiahcphecmpfh"
    $extensionURL = "https://clients2.google.com/service/update2/crx"

    Set-RegistryValue -Path $basePath -Name "1" -Type String -Value "$extensionId;$extensionURL"
}

# Function to display usage information
function Show-Usage {
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " .\Browsers-Optimization.ps1 -MyArgument <option>" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " - configure_msedge_policies  : Configure Microsoft Edge settings" -ForegroundColor Gray
    Write-Host " - enable_msedge_updates      : Enable Microsoft Edge updates" -ForegroundColor Gray
    Write-Host " - disable_msedge_updates     : Disable Microsoft Edge updates" -ForegroundColor Gray
    Write-Host " - configure_firefox_policies : Configure Firefox browser settings" -ForegroundColor Gray
    Write-Host " - enable_firefox_updates     : Enable Firefox browser updates" -ForegroundColor Gray
    Write-Host " - disable_firefox_updates    : Disable Firefox browser updates" -ForegroundColor Gray
    # Write-Host " - optimize_brave            : Optimize Brave browser settings" -ForegroundColor Gray
    # Write-Host " - optimize_chrome           : Optimize Chrome browser settings" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Example:" -ForegroundColor Cyan
    Write-Host "---------" -ForegroundColor Cyan
    Write-Host " .\Browsers-Optimization.ps1 -MyArgument configure_firefox_policies" -ForegroundColor White
    Write-Host " .\Browsers-Optimization.ps1 -MyArgument enable_msedge_updates, configure_msedge_policies" -ForegroundColor White
    Write-Host ""
}

# Check if no arguments were provided
if (-not $MyArgument) {
    Write-Host "Error: No arguments provided." -ForegroundColor Red
    Write-Host ""
    Show-Usage
}

# Function call based on the argument
foreach ($arg in $MyArgument) {
    switch ($arg) {
        # Configure Microsoft Edge settings
        "configure_msedge_policies" { Set-MSEdgeConfiguration -ConfigurePolicies }
        "enable_msedge_updates" { Set-MSEdgeConfiguration -EnableUpdates }
        "disable_msedge_updates" { Set-MSEdgeConfiguration -DisableUpdates }
        
        # Configure Firefox settings
        "configure_firefox_policies" { Set-FirefoxConfiguration -ConfigurePolicies }
        "enable_firefox_updates" { Set-FirefoxConfiguration -EnableUpdates }
        "disable_firefox_updates" { Set-FirefoxConfiguration -DisableUpdates }

        # Install uBlockOrigin Lite extension for Chrome
        "install_ublockorigin" { Install-uBlockOriginforChrome }
        
        # Configure Brave settings
        # "optimize_brave" { Optimize-Brave }

        # Configure Chrome settings
        # "optimize_chrome" { Optimize-Chrome }
        
        default {
            Write-Host "Error: Invalid argument `"$arg`"" -ForegroundColor Red
            Write-Host ""
            Show-Usage
        }
    }
}