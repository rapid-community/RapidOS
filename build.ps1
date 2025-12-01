#config
$output7z = "RapidOS.7z"
$outputApbx = "RapidOS.apbx"
$zipExe = "C:\Program Files\7-Zip\7z.exe"

if (-not (Test-Path $zipExe)) {
    Write-Host "7z.exe not found!. Setup 7-Zip do it again" -ForegroundColor Red
    exit
}

$items = Get-ChildItem "RapidOS Sources" | ForEach-Object { $_.FullName }

& "$zipExe" a -t7z $output7z $items -p"malte" -mhe=on

if (Test-Path $outputApbx) {
    Remove-Item $outputApbx -Force
}

if (Test-Path $output7z) {
    Rename-Item $output7z $outputApbx -Force
    Write-Host "Created file: $outputApbx" -ForegroundColor Green
} else {
    Write-Host "Compression failed — output file not found." -ForegroundColor Red
}