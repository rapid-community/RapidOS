@echo off

>nul fltmc || (
    powershell -c "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -c "$f='%~f0'; $lines=Get-Content $f; $idx=$lines.IndexOf(':PS'); iex ($lines[($idx+1)..($lines.Length-1)] -join [Environment]::NewLine)"
exit /b

:PS
$downloads = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
$zipPath = Join-Path $downloads "Windows7Games_for_Windows_11_10_8.zip"
$extractPath = Join-Path $downloads "Windows7Games"

Write-Host "Downloading package"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($Host.Version.Major -eq 5) {$Script:ProgressPreference = "SilentlyContinue"}
$headers = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0 Safari/537.36"
    "Referer"    = "https://win7games.com/"
    "Accept"     = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    "Accept-Language" = "en-US,en;q=0.9"
}
try {
    Invoke-WebRequest -Uri "https://win7games.com/download/Windows7Games_for_Windows_11_10_8.zip" -OutFile $zipPath -Headers $headers -MaximumRedirection 5
} catch {
    try {
        Start-BitsTransfer -Source "https://win7games.com/download/Windows7Games_for_Windows_11_10_8.zip" -Destination $zipPath -RetryInterval 2 -Description "Win7Games"
    } catch {}
}
if (!(Test-Path $zipPath) -or ((Get-Item $zipPath).Length -lt 1024)) {
    Write-Host "Downloading package"
    $client = New-Object System.Net.Http.HttpClient
    $client.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    $client.DefaultRequestHeaders.Add("Referer","https://win7games.com/")
    $client.DefaultRequestHeaders.Add("Accept","application/zip,*/*")
    $resp = $client.GetAsync("https://win7games.com/download/Windows7Games_for_Windows_11_10_8.zip").Result
    if ($resp.IsSuccessStatusCode) {
        [IO.File]::WriteAllBytes($zipPath, $resp.Content.ReadAsByteArrayAsync().Result)
    }
}

Write-Host "Extracting..."
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

Write-Host "Starting..."
$exe = Get-ChildItem -Path $extractPath -Filter *.exe -Recurse | Select-Object -First 1
Start-Process $exe.FullName

Write-Host "Done."
pause
exit
