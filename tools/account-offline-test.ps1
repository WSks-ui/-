param(
    [string]$DevEcoHome = $env:DEVECO_HOME,
    [ValidatePattern('^[\w.:-]+$')][string]$TargetId = '127.0.0.1:5557'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'deveco-path.ps1')
$DevEcoHome = Resolve-YunhejiDevEcoHome -DevEcoHome $DevEcoHome
$workspaceRoot = Split-Path $PSScriptRoot -Parent
$serviceRoot = Join-Path $workspaceRoot '.local/account-sync'
$evidenceRoot = Join-Path $workspaceRoot 'entry/build/test-evidence/account-sync'
New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
$fixture = Get-Content -LiteralPath (Join-Path $serviceRoot 'test-run.json') -Raw -Encoding utf8 | ConvertFrom-Json
$hdcTool = Join-Path $DevEcoHome 'sdk/default/openharmony/toolchains/hdc.exe'
$phaseScript = Join-Path $PSScriptRoot 'device-test.ps1'
$shellPath = (Get-Process -Id $PID).Path
$phaseOutput = Join-Path $evidenceRoot 'offline-phase.stdout.log'
$phaseError = Join-Path $evidenceRoot 'offline-phase.stderr.log'
$phase = Start-Process -FilePath $shellPath -ArgumentList @('-NoProfile','-File',('"' + $phaseScript + '"'),'-TargetId',$TargetId,
    '-TestClass','AccountSyncTest#device_b_offline_note_is_saved_locally','-ExpectedTests','1','-SkipInstall') -WorkingDirectory $workspaceRoot -WindowStyle Hidden -RedirectStandardOutput $phaseOutput -RedirectStandardError $phaseError -PassThru
$stopped = $false
$marker = 'ACCOUNT_OFFLINE_READY:' + $fixture.run
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(180)
    while ([DateTime]::UtcNow -lt $deadline) {
        $phase.Refresh()
        if ($phase.HasExited) { throw '离线阶段在准备标记之前结束，未停止账号服务。' }
        $ready = @(& $hdcTool -t $TargetId shell hilog -x | Select-String -SimpleMatch $marker)
        if ($ready.Count -gt 0) { break }
        Start-Sleep -Milliseconds 750
    }
    if ($ready.Count -eq 0) { throw '未收到本轮离线准备标记，未停止账号服务。' }
    $serviceProcessId = [int](Get-Content -LiteralPath (Join-Path $serviceRoot 'server.pid') -Raw)
    $ownedService = Get-CimInstance Win32_Process -Filter "ProcessId=$serviceProcessId"
    if (-not $ownedService -or $ownedService.Name -ne 'node.exe' -or
        $ownedService.CommandLine -notlike '*server*account-service.mjs*' -or
        $ownedService.CommandLine -notlike ('*' + $serviceRoot + '*')) {
        throw '账号服务进程身份不匹配，未停止任何进程。'
    }
    Stop-Process -Id $serviceProcessId
    $stopped = $true
    $disconnectTime = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow,
        [TimeZoneInfo]::FindSystemTimeZoneById('China Standard Time')).ToString('yyyy-MM-dd HH:mm:ss')
    Write-Output ('已停止本任务账号服务以验证离线本机保存：' + $disconnectTime)
    while (-not $phase.HasExited) { Start-Sleep -Seconds 1; $phase.Refresh() }
    Get-Content -LiteralPath $phaseOutput -Encoding utf8
    if ($phase.ExitCode -ne 0) {
        Get-Content -LiteralPath $phaseError -Encoding utf8
        throw '离线阶段未通过，已保留原始报告。'
    }
} finally {
    if ($stopped) {
        & (Join-Path $PSScriptRoot 'start-account-server.ps1') -DevEcoHome $DevEcoHome -TargetIds @($TargetId)
        Write-Output '已恢复同一数据库与 TLS 证书的账号服务。'
    }
}
