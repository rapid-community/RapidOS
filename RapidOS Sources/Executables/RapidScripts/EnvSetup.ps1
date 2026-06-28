# Add RapidOS' PowerShell modules
$modulepath = "$env:SystemRoot\RapidScripts\Modules"
gci $modulepath -Filter *.psm1 -EA 0 | % {Import-Module $_.FullName -Force -Global}
if ($env:PSModulePath -notmatch [regex]::Escape($modulepath)) {$env:PSModulePath = "$modulepath;$env:PSModulePath"}