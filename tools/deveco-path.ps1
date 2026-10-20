function Resolve-YunhejiDevEcoHome {
    param([string]$DevEcoHome)

    # 工具安装目录属于本机配置，不写入公开仓库。显式参数 / 环境变量优先；
    # 当前工作区可在已忽略的 .local/deveco-home.txt 中保留原来的运行路径。
    # 新克隆只需配置 DEVECO_HOME，不修改系统变量或用户的签名文件。
    if (-not $DevEcoHome) { $DevEcoHome = $env:DEVECO_HOME }
    if (-not $DevEcoHome) {
        $configuration = Join-Path (Split-Path $PSScriptRoot -Parent) '.local/deveco-home.txt'
        if (Test-Path -LiteralPath $configuration) {
            $DevEcoHome = [IO.File]::ReadAllText($configuration).Trim()
        }
    }
    if (-not $DevEcoHome) { throw '请设置 DEVECO_HOME 或传入 -DevEcoHome 指定 DevEco Studio 安装目录。' }
    if (-not (Test-Path -LiteralPath $DevEcoHome -PathType Container)) { throw '指定的 DevEco Studio 安装目录不存在。' }
    return $DevEcoHome
}

function Remove-DuplicateProxyEnvironment {
    # Windows PowerShell 5.1 的 Start-Process 会把当前环境装进不区分大小写的字典。
    # 同一变量同时存在 HTTP_PROXY 与 http_proxy（常见于 IDE / 终端注入）时，
    # 会直接抛“字典中的关键字重复”，构建与服务启动都会失败。
    # 这里只在脚本进程内移除已有大写副本的小写项，不修改系统或用户环境变量；
    # 若只有小写项则保留，避免影响依赖小写代理变量的命令行工具。
    foreach ($name in @('http_proxy', 'https_proxy', 'no_proxy', 'all_proxy')) {
        $upper = $name.ToUpperInvariant()
        if ((Test-Path ('Env:' + $name)) -and (Test-Path ('Env:' + $upper))) {
            Remove-Item ('Env:' + $name) -ErrorAction SilentlyContinue
        }
    }
}
