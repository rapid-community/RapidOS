# Ensure administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) { Write-Host "Restarting script with administrator privileges..." -ForegroundColor Yellow; $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"{0}`" -MyArgument {1}" -f $PSCommandPath, $MyArgument; Start-Process PowerShell.exe -ArgumentList $arguments -Verb RunAs; exit }

$frameworkPath = "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319"
$env:PATH = "$frameworkPath;" + $env:PATH

$allAssemblies = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object {$_.Location} | ForEach-Object {$_.Location}

foreach ($assemblyPath in $allAssemblies) {
    Write-Host "Generating Native Image for: $(Split-Path $assemblyPath -Leaf)" -ForegroundColor Magenta
    Start-Process -FilePath "$frameworkPath\ngen.exe" -ArgumentList "install", $assemblyPath -NoNewWindow -Wait
}

Start-Job -ScriptBlock {
    $tasks = @("\Microsoft\Windows\.NET Framework\.NET Framework NGEN v4.0.30319", "\Microsoft\Windows\.NET Framework\.NET Framework NGEN v4.0.30319 64")
    foreach ($task in $tasks) {
        Start-Process -FilePath "schtasks.exe" -ArgumentList "/Run", "/TN", $task -PassThru | Out-Null
    }
} -Name "NGENTasks"