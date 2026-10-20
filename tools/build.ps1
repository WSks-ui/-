param(
    [string]$DevEcoHome = $env:DEVECO_HOME,
    [string]$Task = 'assembleHap',
    [string]$Target = 'default'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'deveco-path.ps1')
# 先清理大小写重复的代理变量，否则下面的 Start-Process 会直接抛字典重复键。
Remove-DuplicateProxyEnvironment
$DevEcoHome = Resolve-YunhejiDevEcoHome -DevEcoHome $DevEcoHome
$node = Join-Path $DevEcoHome 'tools\node\node.exe'
$hvigor = Join-Path $DevEcoHome 'tools\hvigor\bin\hvigorw.js'
if (-not (Test-Path -LiteralPath $node) -or -not (Test-Path -LiteralPath $hvigor)) {
    throw 'DevEco tools not found. Pass -DevEcoHome or set DEVECO_HOME.'
}

# 仅修改当前构建进程环境，不改用户或系统环境变量；退出时恢复原值。
$previousSdk = $env:DEVECO_SDK_HOME
$previousJava = $env:JAVA_HOME
$previousErrorAction = $ErrorActionPreference
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    $env:DEVECO_SDK_HOME = Join-Path $DevEcoHome 'sdk'
    $env:JAVA_HOME = Join-Path $DevEcoHome 'jbr'
    # Windows PowerShell 5.1 会把原生程序的 stderr（包括 ArkTS 警告）当成 ErrorRecord，
    # 在 Stop 模式下“构建成功但有警告”会被误判为失败。改用 Start-Process 分别接住
    # stdout / stderr，构建结果只看真实退出码，不吞掉任何编译错误。
    $logBase = Join-Path $env:TEMP ('yunheji-build-' + [Guid]::NewGuid().ToString('N'))
    $stdoutLog = $logBase + '.out.log'
    $stderrLog = $logBase + '.err.log'
    try {
        $arguments = @('"' + $hvigor + '"', '--mode', 'module', '-p', 'product=default',
            '-p', "module=entry@$Target", $Task, '--no-daemon')
        $process = Start-Process -FilePath $node -ArgumentList $arguments -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog
        Get-Content -LiteralPath $stdoutLog | ForEach-Object { Write-Output $_ }
        Get-Content -LiteralPath $stderrLog | ForEach-Object { Write-Output $_ }
        $buildExit = $process.ExitCode
    } finally {
        foreach ($log in @($stdoutLog, $stderrLog)) {
            if ($log -and (Test-Path -LiteralPath $log)) { Remove-Item -LiteralPath $log -Force }
        }
    }
    if ($buildExit -ne 0) { throw "Hvigor failed: $buildExit" }
} finally {
    $ErrorActionPreference = $previousErrorAction
    $env:DEVECO_SDK_HOME = $previousSdk
    $env:JAVA_HOME = $previousJava
    Pop-Location
}
