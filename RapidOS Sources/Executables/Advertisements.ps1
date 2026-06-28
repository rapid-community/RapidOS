#Requires -RunAsAdministrator

param ([switch]$undo)

$file = 'SettingsExtensions.json'
$path = gci "$env:SystemRoot\SystemApps" -Filter $file -Recurse -EA 0 | Select -First 1 -Expand FullName

if (!$path) {
    Write-Host "User is likely on Windows 10. Exiting..."
    exit
}

$bakdir = "$env:SystemRoot\RapidScripts"
$bak = "$bakdir\$file"

# ==============================
# Undo / Restore
# ==============================
if ($undo) {
    Unregister-ScheduledTask -TaskName 'Advertising' -Confirm:$false -EA 0
    if (Test-Path $bak) {
        takeown /f $path /a *>$null
        icacls $path /grant *S-1-5-32-544:F /t /q *>$null
        copy $bak $path -Force
        Write-Host "Restored original files."
    } else {
        Write-Host "Backup not found."
    }
    exit
}

if (!(Test-Path "$env:SystemRoot\System32\Tasks\Advertising")) {
    $task = "$env:SystemRoot\RapidScripts\Playbook\Advertisements.ps1"
    $act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoP -EP Bypass -WindowStyle Hidden -File `"$task`""
    $trig = New-ScheduledTaskTrigger -AtStartup
    $prin = New-ScheduledTaskPrincipal -UserId S-1-5-18 -LogonType Service -RunLevel Highest
    Register-ScheduledTask -TaskName 'Advertising' -Action $act -Trigger $trig -Principal $prin -Force
}

# ==============================
# Disable advertisements
# ==============================
mkdir $bakdir -Force *>$null
if (!(Test-Path $bak)) {copy $path $bak -Force}

'SystemSettings.exe', 'ShellExperienceHost.exe' | % {taskkill /f /im $_ *>$null}

takeown /f $path /a *>$null
icacls $path /grant *S-1-5-32-544:F /t /q *>$null

$json = [IO.File]::ReadAllText($path) | ConvertFrom-Json
$ids = @(
    'SubscriptionCard', 'SubscriptionCard_Enterprise', 'CopilotSubscriptionCard',
    'CopilotSubscriptionCard_Enterprise', 'XboxSubscriptionCard',
    'XboxSubscriptionCard_Enterprise', 'SignedOutCard', 'SignedOutCard_SecondPlace',
    'SignedOutCard_Enterprise_AAD', 'HomeSubscriptionHigherRankedCard',
    'SettingsPageYourMicrosoftAccount', 'SettingsPageAccountsPicture', 'SettingsPageGroupAccounts',
    'SettingsPageGroupAccounts_Home', 'SettingsPageGroupHome', 'SettingsPageHome'
)

if ($json.addedHomeCards) {
    $json.addedHomeCards = $json.addedHomeCards | ? {$ids -notcontains $_.cardId}
}

if ($json.hiddenPages) {
    foreach ($page in $json.hiddenPages) {
        if ($page.pageGroupId -eq 'SettingsPageGroupAccounts' -and $page.conditions.velocityKey) {
            $page.conditions.velocityKey.default = 'disabled'
        }
    }
}

if ($json.addedPages) {
    foreach ($page in $json.addedPages) {
        if ($page.pageId -eq 'SettingsPageGroupAccounts_Home' -and $page.conditions.velocityKey) {
            $page.conditions.velocityKey.default = 'disabled'
        }
    }
}

del $path -Force
[IO.File]::WriteAllText($path, ($json | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))

Write-Host "Done." -F Green