param(
    [string]$DevEcoHome = $env:DEVECO_HOME,
    [string]$DeviceA = '127.0.0.1:5555',
    [string]$DeviceB = '127.0.0.1:5557',
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'deveco-path.ps1')
$DevEcoHome = Resolve-YunhejiDevEcoHome -DevEcoHome $DevEcoHome
$stageRoot = Split-Path $PSScriptRoot -Parent
$stageHdc = Join-Path $DevEcoHome 'sdk/default/openharmony/toolchains/hdc.exe'
$serviceRoot = Join-Path $stageRoot '.local/account-sync'

function Invoke-ResumePhase([string]$Target, [string]$Case) {
    & (Join-Path $PSScriptRoot 'device-test.ps1') -DevEcoHome $DevEcoHome -TargetId $Target `
        -TestClass ('AccountResumeTest#' + $Case) -ExpectedTests 1
}

& (Join-Path $PSScriptRoot 'start-account-server.ps1') -DevEcoHome $DevEcoHome -TargetIds @($DeviceA, $DeviceB)
if (-not $SkipBuild) {
    & (Join-Path $DevEcoHome 'tools/node/node.exe') (Join-Path $PSScriptRoot 'prepare-account-test.mjs')
    if ($LASTEXITCODE -ne 0) { throw '测试账号准备失败。' }
    & (Join-Path $PSScriptRoot 'build.ps1') -DevEcoHome $DevEcoHome
    & (Join-Path $PSScriptRoot 'build.ps1') -DevEcoHome $DevEcoHome -Target ohosTest
}

Invoke-ResumePhase $DeviceA 'prepare_authenticated_memory'
$stoppedService = $false
try {
    # 只结束本任务的回环服务，核对进程和完整服务目录；不结束未知 Node 进程。
    $stageServicePid = [int](Get-Content -LiteralPath (Join-Path $serviceRoot 'server.pid') -Raw)
    $ownedService = Get-CimInstance Win32_Process -Filter "ProcessId=$stageServicePid"
    if (-not $ownedService -or $ownedService.Name -ne 'node.exe' -or
        $ownedService.CommandLine -notlike '*server*account-service.mjs*' -or
        $ownedService.CommandLine -notlike ('*' + $serviceRoot + '*')) {
        throw '账号服务进程身份不匹配，未结束任何进程。'
    }
    & $stageHdc -t $DeviceA shell 'aa force-stop com.yunheji.archive'
    Stop-Process -Id $stageServicePid
    $stoppedService = $true
    Write-Output '已结束应用进程并停止本任务服务，开始离线冷启动。'
    Invoke-ResumePhase $DeviceA 'cold_start_while_service_unavailable_edit_same_memory'
} finally {
    if ($stoppedService) {
        & (Join-Path $PSScriptRoot 'start-account-server.ps1') -DevEcoHome $DevEcoHome -TargetIds @($DeviceA, $DeviceB)
    }
}
& $stageHdc -t $DeviceA shell 'aa force-stop com.yunheji.archive'
Invoke-ResumePhase $DeviceA 'cold_start_reconnect_without_login'
Invoke-ResumePhase $DeviceB 'other_device_receives_offline_edit'
Invoke-ResumePhase $DeviceA 'cleanup_a_and_forget_session'
Write-Output '账号离线冷启动、原记录编辑、恢复连接免重复登录和 B 端接收均已完成；见各阶段原始报告。'
