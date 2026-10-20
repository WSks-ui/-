param(
    [string]$DevEcoHome = $env:DEVECO_HOME,
    # 双端演示默认需要两台；只做单机走查时传 1，纯服务检查可传 0。
    [ValidateRange(0, 10)][int]$RequireDevices = 2
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false) } catch { }
. (Join-Path $PSScriptRoot 'deveco-path.ps1')
$DevEcoHome = Resolve-YunhejiDevEcoHome -DevEcoHome $DevEcoHome
$workspace = Split-Path $PSScriptRoot -Parent
$hdcTool = Join-Path $DevEcoHome 'sdk\default\openharmony\toolchains\hdc.exe'
$mainPackage = Join-Path $workspace 'entry\build\default\outputs\default\entry-default-unsigned.hap'
$configPath = Join-Path $workspace 'entry\src\main\resources\rawfile\account-sync-dev.json'
$aiConfigPath = Join-Path $workspace '.local\ai-observation\config.json'

$failures = 0
$warnings = 0
function Write-Check([string]$Level, [string]$Message) {
    switch ($Level) {
        'PASS' { Write-Output ('[通过] ' + $Message) }
        'WARN' { $script:warnings++; Write-Output ('[警告] ' + $Message) }
        default { $script:failures++; Write-Output ('[失败] ' + $Message) }
    }
}

Write-Output '云河纪演示自检（本地 / 局域网账号服务，模拟器双端）'
Write-Output ('工程：' + $workspace)

# 1. 主包是否存在；配置在构建时会被打进 HAP，因此必须核对包内副本。
if (-not (Test-Path -LiteralPath $mainPackage)) {
    Write-Check 'FAIL' '缺少主包，请先运行 .\tools\build.ps1'
    Write-Output '结论：演示未就绪。'
    exit 1
}
$package = Get-Item -LiteralPath $mainPackage
Write-Check 'PASS' ('主包存在：' + $package.Name + '，' + $package.Length + ' 字节，' + $package.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))

$config = $null
if (-not (Test-Path -LiteralPath $configPath)) {
    Write-Check 'FAIL' '缺少 account-sync-dev.json，请先运行 .\tools\start-account-server.ps1'
} else {
    try {
        $config = [IO.File]::ReadAllText($configPath) | ConvertFrom-Json
        Write-Check 'PASS' ('工作区服务端点：' + $config.endpoint)
    } catch {
        Write-Check 'FAIL' 'account-sync-dev.json 无法解析'
    }
}

# 2. 包内端点与工作区是否一致：改地址后不重新构建，安装包仍会连旧地址。
if ($config) {
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($mainPackage)
        try {
            $entry = $archive.Entries | Where-Object { $_.FullName -like '*account-sync-dev.json' } | Select-Object -First 1
            if (-not $entry) {
                Write-Check 'FAIL' '主包内未找到 account-sync-dev.json（配置没有随包构建）'
            } else {
                $reader = New-Object IO.StreamReader($entry.Open())
                try { $embedded = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
                if ($embedded.endpoint -ceq $config.endpoint) {
                    Write-Check 'PASS' '主包内端点与工作区配置一致'
                } else {
                    Write-Check 'FAIL' ('主包内端点为 ' + $embedded.endpoint + '，与工作区 ' + $config.endpoint + ' 不一致；请重新构建并安装')
                }
            }
        } finally { $archive.Dispose() }
    } catch {
        Write-Check 'WARN' ('无法读取主包内配置：' + $_.Exception.Message)
    }
}

# 3. 服务健康检查。这里只在自检探针上临时跳过证书校验；
#    应用本身仍用包内 CA 校验证书与主机名，不能用本脚本的放宽代替应用行为。
if ($config) {
    $healthUrl = $config.endpoint.TrimEnd('/') + '/health'
    # 优先用系统 curl：Windows PowerShell 5.1 的 Invoke-WebRequest 走 Schannel，
    # 在本机自签证书 + 代理变量的组合下可能直接断开连接，给出误导性的“不可达”。
    # 这里 -k 只用于自检探针；应用仍以包内 CA 校验证书与主机名。
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    $healthBody = $null
    if ($curl) {
        $healthBody = & $curl.Source --noproxy '*' -k -sS --max-time 5 $healthUrl 2>&1
        if ($LASTEXITCODE -ne 0) { $healthBody = $null }
    }
    if (-not $healthBody) {
        $previousCallback = [Net.ServicePointManager]::ServerCertificateValidationCallback
        $previousProtocol = [Net.ServicePointManager]::SecurityProtocol
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            $healthBody = (Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 5).Content
        } catch {
            $healthBody = $null
        } finally {
            [Net.ServicePointManager]::ServerCertificateValidationCallback = $previousCallback
            [Net.ServicePointManager]::SecurityProtocol = $previousProtocol
        }
    }
    if ($healthBody) {
        try {
            $health = $healthBody | ConvertFrom-Json
            if ($health.service -eq 'yunheji-account') {
                Write-Check 'PASS' ('账号服务可用：' + $health.service + ' v' + $health.version)
            } else {
                Write-Check 'FAIL' ('端口返回的不是云河纪服务：' + $healthBody)
            }
        } catch {
            Write-Check 'FAIL' ('健康检查响应无法解析：' + $healthBody)
        }
    } else {
        Write-Check 'FAIL' ('账号服务不可达：' + $healthUrl + '（请运行 .\tools\start-account-server.ps1）')
    }
}

# 4. 在线模拟器数量与反向端口。
$targets = @()
if (Test-Path -LiteralPath $hdcTool) {
    $targets = @(& $hdcTool list targets 2>$null | Where-Object { $_ -and $_ -notmatch '\[Empty\]' } | ForEach-Object { $_.Trim() })
} else {
    Write-Check 'FAIL' '未找到 HDC，请设置 DEVECO_HOME'
}
if ($targets.Count -ge $RequireDevices) {
    Write-Check 'PASS' ('在线模拟器 ' + $targets.Count + ' 台：' + ($targets -join ', '))
} else {
    Write-Check 'FAIL' ('在线模拟器 ' + $targets.Count + ' 台，少于演示所需的 ' + $RequireDevices + ' 台')
}

$loopback = $config -and ($config.endpoint -match '^https://(127\.|localhost)')
if ($config -and $loopback) {
    foreach ($target in $targets) {
        $port = ([Uri]$config.endpoint).Port
        $forwarding = & $hdcTool -t $target fport ls 2>$null
        $pattern = 'tcp:' + $port + '\s+tcp:' + $port + '\s+\[Reverse\]'
        if (($forwarding -join "`n") -match $pattern) {
            Write-Check 'PASS' ('设备反向端口已建立：' + $target)
        } else {
            Write-Check 'FAIL' ('设备缺少 tcp:' + $port + ' 反向端口：' + $target + '（重启账号服务脚本并传入该 TargetId）')
        }
    }
} elseif ($config) {
    Write-Output '[提示] 局域网端点模式不需要 HDC 反向端口；请确认模拟器与开发机在同一网段。'
}

# 5. AI 配置只报告可用性，不读取或输出密钥内容。
if (Test-Path -LiteralPath $aiConfigPath) {
    try {
        $ai = [IO.File]::ReadAllText($aiConfigPath) | ConvertFrom-Json
        if ($ai.apiKey -and $ai.provider -and $ai.model) {
            Write-Check 'PASS' ('AI 配置：' + $ai.provider + '/' + $ai.model + '（密钥存在，未输出）')
        } else {
            Write-Check 'FAIL' 'AI 配置缺少 provider / model / apiKey'
        }
    } catch {
        Write-Check 'FAIL' 'AI 配置无法解析'
    }
} else {
    Write-Check 'WARN' '未找到 .local/ai-observation/config.json；AI 观察会返回未配置'
}

Write-Output ('结论：' + $(if ($failures -eq 0) { '演示就绪' } else { '存在 ' + $failures + ' 项阻塞' }) + $(if ($warnings -gt 0) { '，' + $warnings + ' 项警告' } else { '' }))
if ($failures -gt 0) { exit 1 }
