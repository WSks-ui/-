param(
    [string]$DevEcoHome = $env:DEVECO_HOME,
    [string]$Task = 'assembleHap',
    [string]$Target = 'default'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'deveco-path.ps1')
$DevEcoHome = Resolve-YunhejiDevEcoHome -DevEcoHome $DevEcoHome
$node = Join-Path $DevEcoHome 'tools\node\node.exe'
$hvigor = Join-Path $DevEcoHome 'tools\hvigor\bin\hvigorw.js'
if (-not (Test-Path -LiteralPath $node) -or -not (Test-Path -LiteralPath $hvigor)) {
    throw 'DevEco tools not found. Pass -DevEcoHome or set DEVECO_HOME.'
}

# 仅修改当前构建进程环境，不改用户或系统环境变量；退出时恢复原值。
$previousSdk = $env:DEVECO_SDK_HOME
$previousJava = $env:JAVA_HOME
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    $env:DEVECO_SDK_HOME = Join-Path $DevEcoHome 'sdk'
    $env:JAVA_HOME = Join-Path $DevEcoHome 'jbr'
    & $node $hvigor --mode module -p product=default -p "module=entry@$Target" $Task --no-daemon
    if ($LASTEXITCODE -ne 0) { throw "Hvigor failed: $LASTEXITCODE" }
} finally {
    $env:DEVECO_SDK_HOME = $previousSdk
    $env:JAVA_HOME = $previousJava
    Pop-Location
}
