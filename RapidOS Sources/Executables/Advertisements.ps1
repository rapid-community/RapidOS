#Requires -RunAsAdministrator

$path = gci "$env:WinDir\SystemApps" -r | ? {$_.Name -eq 'SettingsExtensions.json'} | Select -First 1 -Expand FullName
if (!$path) {
    Write-Host "User is likely on Windows 10. Exiting..." -F DarkGray
    exit
}

"SystemSettings", "ShellExperienceHost" | % {taskkill /f /im "${_}.exe" *>$null}

# ==============================
# File operations
# ==============================
$bakDir = "$env:WinDir\RapidScripts"
$bak = Join-Path $bakDir "SettingsExtensions.json"
if (!(Test-Path $bakDir)) {mkdir $bakDir -Force *>$null}
if (!(Test-Path $bak)) {copy $path $bak -Force}

takeown /f $path /a *>$null
icacls $path /grant *S-1-5-32-544:F /t /q *>$null

# ==============================
# JSON modification
# ==============================
$json = type $path -Raw | ConvertFrom-Json
$blockList = "SubscriptionCard", "SubscriptionCard_Enterprise", "CopilotSubscriptionCard",
             "CopilotSubscriptionCard_Enterprise", "XboxSubscriptionCard", "XboxSubscriptionCard_Enterprise",
             "SignedOutCard", "SignedOutCard_SecondPlace", "SignedOutCard_Enterprise_Local",
             "SignedOutCard_Enterprise_AAD", "SettingsPageGroupAccounts"

$json.addedHomeCards = $json.addedHomeCards | ? {$blockList -notcontains $_.cardId}

$json.hiddenPages = $json.hiddenPages | % { 
    if ($_.pageGroupId -eq 'SettingsPageGroupAccounts' -and $_.conditions.velocityKey) {
        $_.conditions.velocityKey.default = 'disabled'
    }
    $_
}

$json.addedPages = $json.addedPages | % {
    if ($_.pageId -eq 'SettingsPageGroupAccounts_Home' -and $_.conditions.velocityKey) {
        $_.conditions.velocityKey.default = 'disabled'
    }
    $_
}

$temp = Join-Path $env:TEMP "SettingsExtensions.json"
$json | ConvertTo-Json -Depth 100 | Set-Content $temp
move $temp $path -Force *>$null

Write-Host "Done." -F Green