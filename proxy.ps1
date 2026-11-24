# Set-GatewayProxy.ps1

# 1. Получаем IP-адрес основного шлюза (Default Gateway)
$gateway = Get-NetIPConfiguration | 
    Where-Object { $_.IPv4DefaultGateway -ne $null } | 
    Select-Object -First 1 -ExpandProperty IPv4DefaultGateway | 
    Select-Object -ExpandProperty NextHop

if (-not $gateway) {
    Write-EventLog -LogName Application -Source "GatewayProxyScript" -EntryType Warning -EventId 100 -Message "Не удалось определить основной шлюз. Прокси не изменен."
    exit
}

$proxyServer = "${gateway}:10809"

# 2. Путь к ветке реестра с настройками прокси текущего пользователя
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

# 3. Устанавливаем адрес и порт прокси, включаем его
Set-ItemProperty -Path $regPath -Name ProxyServer -Value $proxyServer -Force
Set-ItemProperty -Path $regPath -Name ProxyEnable -Value 1 -Force

# 4. (Опционально) Список исключений, чтобы локальные адреса шли напрямую
$bypassList = "localhost;127.0.0.1;<local>"
Set-ItemProperty -Path $regPath -Name ProxyOverride -Value $bypassList -Force

# 5. Уведомляем систему об изменении настроек, чтобы они применились сразу
$signature = @"
[DllImport("wininet.dll", SetLastError = true, CharSet=CharSet.Auto)]
public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
"@
$winInet = Add-Type -MemberDefinition $signature -Name WinInet -Namespace WinInet -PassThru

# 39 = INTERNET_OPTION_SETTINGS_CHANGED, 37 = INTERNET_OPTION_REFRESH
$winInet::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0) | Out-Null
$winInet::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0) | Out-Null

Write-EventLog -LogName Application -Source "GatewayProxyScript" -EntryType Information -EventId 101 -Message "Прокси успешно обновлен на $proxyServer"