param(
    [string]$DevEcoHome = $env:DEVECO_HOME,
    [ValidateRange(1024,65535)][int]$Port = 18443,
    [string[]]$TargetIds = @()
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'deveco-path.ps1')
$DevEcoHome = Resolve-YunhejiDevEcoHome -DevEcoHome $DevEcoHome
$workspaceRoot = Split-Path $PSScriptRoot -Parent
$serviceRoot = Join-Path $workspaceRoot '.local/account-sync'
New-Item -ItemType Directory -Path $serviceRoot -Force | Out-Null
$certificate = Join-Path $serviceRoot 'server.pem'
$privateKey = Join-Path $serviceRoot 'server.key'
$nodePath = Join-Path $DevEcoHome 'tools/node/node.exe'
$hdcPath = Join-Path $DevEcoHome 'sdk/default/openharmony/toolchains/hdc.exe'
if (-not (Test-Path -LiteralPath $certificate)) {
    # 本机演示的私钥只留在被忽略目录。客户端仅信任这个公开 CA，并保持
    # HTTPS 主机名与证书校验；不关闭 TLS 校验，也不覆盖用户签名证书。
    $opensslPath = (Get-Command openssl -ErrorAction Stop).Source
    & $opensslPath req -x509 -newkey rsa:3072 -nodes -keyout $privateKey -out $certificate -days 30 -subj '/CN=Yunheji Local Account Service' -addext 'subjectAltName=IP:127.0.0.1,DNS:localhost' -addext 'basicConstraints=critical,CA:TRUE' -addext 'extendedKeyUsage=serverAuth' 2> (Join-Path $serviceRoot 'certificate-generation.log')
    if ($LASTEXITCODE -ne 0) { throw '本地 HTTPS 证书生成失败。' }
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
Write-ConfigurationIfChanged $configurationPath (@{ port = $Port } | ConvertTo-Json)
$rawDirectory = Join-Path $workspaceRoot 'entry/src/main/resources/rawfile'
New-Item -ItemType Directory -Path $rawDirectory -Force | Out-Null
Write-ConfigurationIfChanged (Join-Path $rawDirectory 'account-sync-dev.json') (@{
    endpoint = "https://127.0.0.1:$Port"; caData = [IO.File]::ReadAllText($certificate)
} | ConvertTo-Json)
$listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if (-not $listener) {
    $serverScript = Join-Path $workspaceRoot 'server/account-service.mjs'
    $serviceProcess = Start-Process -FilePath $nodePath -ArgumentList @('--experimental-strip-types', ('"' + $serverScript + '"'), '--root', ('"' + $serviceRoot + '"')) -WorkingDirectory $workspaceRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $serviceRoot 'server.stdout.log') -RedirectStandardError (Join-Path $serviceRoot 'server.stderr.log') -PassThru
    $serviceProcess.Id | Set-Content -LiteralPath (Join-Path $serviceRoot 'server.pid') -Encoding utf8
    Write-Output ('账号服务已后台启动，端口：' + $Port)
} else {
    Write-Output ('端口已有监听，保留当前进程；请核对 /health 是否为云河纪服务。端口：' + $Port)
}
foreach ($targetId in $TargetIds) {
    if ($targetId -notmatch '^[\w.:-]+$') { throw '设备参数格式错误。' }
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
