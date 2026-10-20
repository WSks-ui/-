param(
    [string]$DevEcoHome = $env:DEVECO_HOME,
    [ValidateRange(1024,65535)][int]$Port = 18443,
    # 默认本机回环（模拟器经 HDC 反向端口访问）。服务跑在同网段另一台电脑时，
    # 传入那台电脑的私有 IPv4，证书 SAN 与客户端端点会一起切到该地址。
    [string]$HostAddress = '127.0.0.1',
    [string[]]$TargetIds = @()
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'deveco-path.ps1')
# 与构建脚本同一处理：代理变量大小写重复会让 Start-Process 抛重复键。
Remove-DuplicateProxyEnvironment
$DevEcoHome = Resolve-YunhejiDevEcoHome -DevEcoHome $DevEcoHome
$workspaceRoot = Split-Path $PSScriptRoot -Parent
$serviceRoot = Join-Path $workspaceRoot '.local/account-sync'
New-Item -ItemType Directory -Path $serviceRoot -Force | Out-Null
$certificate = Join-Path $serviceRoot 'server.pem'
$privateKey = Join-Path $serviceRoot 'server.key'
$nodePath = Join-Path $DevEcoHome 'tools/node/node.exe'
$hdcPath = Join-Path $DevEcoHome 'sdk/default/openharmony/toolchains/hdc.exe'
function Test-DemoHost([string]$Address) {
    # 与服务端、客户端保持同一条边界：只接受 localhost、回环和私有 IPv4。
    # 公网域名必须在正式发布配置中另配受信任证书，不能靠调试脚本放行。
    if ($Address -eq 'localhost') { return $true }
    $parts = $Address.Split('.')
    if ($parts.Length -ne 4) { return $false }
    foreach ($part in $parts) {
        $value = 0
        if (-not [int]::TryParse($part, [ref]$value) -or $value -lt 0 -or $value -gt 255) { return $false }
    }
    $first = [int]$parts[0]; $second = [int]$parts[1]
    if ($first -eq 127 -or $first -eq 10) { return $true }
    if ($first -eq 192 -and $second -eq 168) { return $true }
    if ($first -eq 172 -and $second -ge 16 -and $second -le 31) { return $true }
    return $false
}
if (-not (Test-DemoHost $HostAddress)) { throw 'HostAddress 只支持 localhost、127.0.0.0/8 或私有 IPv4。' }
$sanIp = if ($HostAddress -eq 'localhost') { '127.0.0.1' } else { $HostAddress }
function Test-CertificateCovers([string]$Path, [string]$Address, [string]$SanAddress) {
    $opensslPath = (Get-Command openssl -ErrorAction Stop).Source
    $details = & $opensslPath x509 -in $Path -noout -ext subjectAltName 2>$null
    if ($LASTEXITCODE -ne 0) { return $false }
    $joined = $details -join ' '
    return $joined -match ('IP Address:' + [regex]::Escape($SanAddress)) -or
        $joined -match ('DNS:' + [regex]::Escape($Address))
}
$certificateCoversHost = (Test-Path -LiteralPath $certificate) -and (Test-Path -LiteralPath $privateKey) -and
    (Test-CertificateCovers $certificate $HostAddress $sanIp)
if (-not $certificateCoversHost) {
    # 本机演示的私钥只留在被忽略目录。客户端仅信任这个公开 CA，并保持
    # HTTPS 主机名与证书校验；不关闭 TLS 校验，也不覆盖用户签名证书。
    # 切换 HostAddress 会更换证书，已安装的旧 HAP 必须重新构建安装。
    if (Test-Path -LiteralPath $certificate) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        Move-Item -LiteralPath $certificate -Destination ($certificate + '.' + $stamp + '.bak') -Force
        if (Test-Path -LiteralPath $privateKey) {
            Move-Item -LiteralPath $privateKey -Destination ($privateKey + '.' + $stamp + '.bak') -Force
        }
        Write-Output ('服务地址已变更，旧证书已备份并重新生成：' + $HostAddress)
    }
    $opensslPath = (Get-Command openssl -ErrorAction Stop).Source
    # openssl 把进度点写到 stderr。PowerShell 5.1 在 Stop 模式下会把“已重定向到文件”
    # 的原生 stderr 仍当成终止错误，导致证书已生成但脚本中断、配置没落盘。
    # 仅在这一条命令期间放宽错误策略，退出码仍由 $LASTEXITCODE 严格判断。
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $opensslPath req -x509 -newkey rsa:3072 -nodes -keyout $privateKey -out $certificate -days 30 -subj '/CN=Yunheji Local Account Service' -addext ('subjectAltName=IP:' + $sanIp + ',DNS:localhost') -addext 'basicConstraints=critical,CA:TRUE' -addext 'extendedKeyUsage=serverAuth' 2> (Join-Path $serviceRoot 'certificate-generation.log')
        $generationExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($generationExit -ne 0) { throw '本地 HTTPS 证书生成失败。' }
}
function Write-ConfigurationIfChanged([string]$Path, [string]$Content) {
    # 重启服务不能让同内容资源变成“比 HAP 更新”，否则设备脚本会正确拒绝旧包。
    if (Test-Path -LiteralPath $Path) {
        try {
            $existing = [IO.File]::ReadAllText($Path) | ConvertFrom-Json -AsHashtable
            $requested = $Content | ConvertFrom-Json -AsHashtable
            $equal = $existing.Count -eq $requested.Count
            foreach ($property in $requested.Keys) {
                if (-not $existing.ContainsKey($property) -or $existing[$property] -cne $requested[$property]) { $equal = $false }
            }
            if ($equal) { return }
        } catch { }
    }
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}
$configurationPath = Join-Path $serviceRoot 'service.json'
# host 一并落盘：服务进程按同一地址监听，避免“客户端写局域网、服务仍只绑回环”。
Write-ConfigurationIfChanged $configurationPath (@{ port = $Port; host = $HostAddress } | ConvertTo-Json)
$rawDirectory = Join-Path $workspaceRoot 'entry/src/main/resources/rawfile'
New-Item -ItemType Directory -Path $rawDirectory -Force | Out-Null
Write-ConfigurationIfChanged (Join-Path $rawDirectory 'account-sync-dev.json') (@{
    endpoint = "https://${HostAddress}:$Port"; caData = [IO.File]::ReadAllText($certificate)
} | ConvertTo-Json)
$listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($listener) {
    # 端口已被监听时不能静默保留：绑定地址与请求不一致会让“局域网模式”名不副实。
    # 不擅自结束未知进程，交给使用者确认后重启服务。
    $expectedBind = if ($HostAddress -eq 'localhost') { '127.0.0.1' } else { $HostAddress }
    $boundAddresses = @($listener | ForEach-Object { $_.LocalAddress } | Select-Object -Unique)
    $matchesRequested = $boundAddresses -contains $expectedBind
    if (-not $matchesRequested -and $expectedBind -eq '127.0.0.1' -and $boundAddresses -contains '::1') { $matchesRequested = $true }
    if (-not $matchesRequested) {
        throw ('端口 ' + $Port + ' 已被 ' + ($boundAddresses -join ', ') + ' 监听，与请求的 ' + $expectedBind + ' 不一致。请先停止现有账号服务，再以新地址启动。')
    }
}
if (-not $listener) {
    $serverScript = Join-Path $workspaceRoot 'server/account-service.mjs'
    $serviceProcess = Start-Process -FilePath $nodePath -ArgumentList @('--experimental-strip-types', ('"' + $serverScript + '"'), '--root', ('"' + $serviceRoot + '"')) -WorkingDirectory $workspaceRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $serviceRoot 'server.stdout.log') -RedirectStandardError (Join-Path $serviceRoot 'server.stderr.log') -PassThru
    $serviceProcess.Id | Set-Content -LiteralPath (Join-Path $serviceRoot 'server.pid') -Encoding utf8
    Write-Output ('账号服务已后台启动，端口：' + $Port)
} else {
    Write-Output ('端口已有监听，保留当前进程；请核对 /health 是否为云河纪服务。端口：' + $Port)
}
$loopbackHost = ($HostAddress -eq 'localhost') -or ($HostAddress -like '127.*')
if (-not $loopbackHost) {
    # 局域网模式下设备直接访问该 IPv4，反向端口既不需要也无法跨机器建立。
    Write-Output ('服务端点为局域网地址 ' + $HostAddress + '，模拟器经网络直接访问，跳过 HDC 反向端口。')
}
foreach ($targetId in $TargetIds) {
    if ($targetId -notmatch '^[\w.:-]+$') { throw '设备参数格式错误。' }
    if (-not $loopbackHost) { continue }
    $forwarding = & $hdcPath -t $targetId fport ls
    $existingPattern = '(?m)^' + [regex]::Escape($targetId) + '\s+tcp:' + $Port + '\s+tcp:' + $Port + '\s+\[Reverse\]'
    if (($forwarding -join "`n") -match $existingPattern) {
        Write-Output ('保留已有设备反向端口：' + $targetId)
    } else {
        $connection = & $hdcPath -t $targetId rport "tcp:$Port" "tcp:$Port"
        $connection
        if ($LASTEXITCODE -ne 0 -or ($connection -join "`n") -notmatch 'Forwardport result:OK') {
            throw ('设备反向端口连接失败：' + $targetId)
        }
    }
}
Write-Output '本地服务配置只用于 debug 包；release 不读取该证书或地址。'
