$windir = [Environment]::GetFolderPath('Windows')

# Add RapidOS' PowerShell modules
if (Test-Path "$windir\RapidScripts\Modules") {gci "$windir\RapidScripts\Modules" -Filter *.psm1 | % {Import-Module $_.FullName -Force -Global}}
$modulePath = "$windir\RapidScripts\Modules"
if ($env:PSModulePath -notmatch [regex]::Escape($modulePath)) {$env:PSModulePath = "$modulePath;$env:PSModulePath"}