param(
    [string]$DevEcoHome = $env:DEVECO_HOME,
    [ValidatePattern('^[\w.:-]+$')][string]$DeviceA = '127.0.0.1:5555',
    [ValidatePattern('^[\w.:-]+$')][string]$DeviceB = '127.0.0.1:5557',
    [switch]$UsePreparedPackages
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'deveco-path.ps1')
$DevEcoHome = Resolve-YunhejiDevEcoHome -DevEcoHome $DevEcoHome
if ($DeviceA -eq $DeviceB) { throw '双端验证必须使用两个不同的在线设备。' }
$workspaceRoot = Split-Path $PSScriptRoot -Parent
$hdcTool = Join-Path $DevEcoHome 'sdk/default/openharmony/toolchains/hdc.exe'
$nodePath = Join-Path $DevEcoHome 'tools/node/node.exe'
Push-Location $workspaceRoot
$phases = [System.Collections.Generic.List[object]]::new()
function Run-AccountPhase([string]$Device, [string]$Case, [switch]$Install) {
    & (Join-Path $PSScriptRoot 'device-test.ps1') -DevEcoHome $DevEcoHome -TargetId $Device `
        -TestClass ('AccountSyncTest#' + $Case) -ExpectedTests 1 -SkipInstall:(-not $Install)
    $report = Get-ChildItem -LiteralPath (Join-Path $workspaceRoot 'docs/test-results') -Filter '*-device.log' |
        Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}-\d{6}-device\.log$' } |
        Sort-Object Name | Select-Object -Last 1
    $phases.Add([ordered]@{ device = $Device; case = $Case; report = $report.Name; passed = 1; total = 1 })
    $phases | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $workspaceRoot '.local/account-sync/device-phases.json') -Encoding utf8
}
try {
    & (Join-Path $PSScriptRoot 'start-account-server.ps1') -DevEcoHome $DevEcoHome -TargetIds @($DeviceA,$DeviceB)
    if (-not $UsePreparedPackages) {
        & $nodePath (Join-Path $PSScriptRoot 'prepare-account-test.mjs')
        if ($LASTEXITCODE -ne 0) { throw '独立测试凭证生成失败。' }
        & (Join-Path $PSScriptRoot 'build.ps1') -DevEcoHome $DevEcoHome
        & (Join-Path $PSScriptRoot 'build.ps1') -DevEcoHome $DevEcoHome -Target ohosTest
    }
    foreach ($device in @($DeviceA,$DeviceB)) {
        & $hdcTool -t $device shell power-shell wakeup
        & $hdcTool -t $device shell uitest uiInput swipe 620 2350 620 750 850
        & $hdcTool -t $device shell power-shell timeout -o 1800000
    }
    Run-AccountPhase $DeviceA 'account_entry_dark_and_large_text_without_private_fields' -Install
    Run-AccountPhase $DeviceA 'device_a_register_publish_and_guest_isolation'
    Run-AccountPhase $DeviceB 'device_b_receive_and_edit_from_real_ui' -Install
    Run-AccountPhase $DeviceA 'device_a_receive_edit_and_logout_preserves_guest'
    & (Join-Path $PSScriptRoot 'account-offline-test.ps1') -DevEcoHome $DevEcoHome -TargetId $DeviceB
    $offlineReport = Get-ChildItem -LiteralPath (Join-Path $workspaceRoot 'docs/test-results') -Filter '*-device.log' |
        Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}-\d{6}-device\.log$' } |
        Sort-Object Name | Select-Object -Last 1
    $phases.Add([ordered]@{ device = $DeviceB; case = 'device_b_offline_note_is_saved_locally'; report = $offlineReport.Name; passed = 1; total = 1 })
    Run-AccountPhase $DeviceB 'device_b_upload_pending_offline_note'
    Run-AccountPhase $DeviceA 'device_a_receive_reconnected_note_and_delete'
    Run-AccountPhase $DeviceB 'device_b_receive_tombstone_without_resurrection'
    Run-AccountPhase $DeviceA 'cleanup_only_this_run_test_preferences'
    Run-AccountPhase $DeviceB 'cleanup_only_this_run_test_preferences'
    Write-Output '8 项账号 / 双端路径与 2 项独立库清理通过；原始报告已逐阶段保存。'
} finally {
    foreach ($device in @($DeviceA,$DeviceB)) { & $hdcTool -t $device shell power-shell timeout -r }
    Pop-Location
}
