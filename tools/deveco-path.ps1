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
