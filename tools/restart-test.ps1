param(
    [string]$DevEcoHome = $env:DEVECO_HOME,
    [Parameter(Mandatory=$true)][ValidatePattern('^[\w.:-]+$')][string]$TargetId
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'deveco-path.ps1')
$DevEcoHome = Resolve-YunhejiDevEcoHome -DevEcoHome $DevEcoHome
$hdcTool = Join-Path $DevEcoHome 'sdk\default\openharmony\toolchains\hdc.exe'
$stamp = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow,
    [TimeZoneInfo]::FindSystemTimeZoneById('China Standard Time')).ToString('yyyyMMdd_HHmmss')
$storeName = "yunheji_test_ui_restart_$stamp"
$resultLog = Join-Path (Split-Path $PSScriptRoot -Parent) "docs\test-results\$stamp-restart.log"

& (Join-Path $PSScriptRoot 'device-test.ps1') -DevEcoHome $DevEcoHome -TargetId $TargetId `
    -TestClass 'ArchiveRestartTest#prepare_process_restart' -ExpectedTests 1 -RestartStore $storeName

# 启动已保存的测试档案，让真实 EntryAbility 处于运行状态，再由 HDC 强停进程。
# 不使用 bm clear、卸载或用户档案清理；只终止本应用，独立测试库由验证阶段清理。
$started = & $hdcTool -t $TargetId shell "aa start -a EntryAbility -b com.chr.myapplication --ps yunhejiTestStore $storeName"
if ($LASTEXITCODE -ne 0 -or ($started -join "`n") -notmatch 'start ability successfully') { throw '重启测试准备后的应用启动失败。' }
$beforePid = ''
for ($attempt = 0; $attempt -lt 40; $attempt++) {
    $beforePid = (& $hdcTool -t $TargetId shell 'pidof com.chr.myapplication' | Out-String).Trim()
    if ($beforePid -match '^\d+$') { break }
    Start-Sleep -Milliseconds 250
}
if ($beforePid -notmatch '^\d+$') { throw '无法确认应用进程，未执行强停。' }
$stopped = & $hdcTool -t $TargetId shell 'aa force-stop com.chr.myapplication'
if ($LASTEXITCODE -ne 0) { throw '应用强停失败。' }
$remainingPid = ''
for ($attempt = 0; $attempt -lt 40; $attempt++) {
    $remainingPid = (& $hdcTool -t $TargetId shell 'pidof com.chr.myapplication' | Out-String).Trim()
    if (-not $remainingPid) { break }
    Start-Sleep -Milliseconds 250
}
@("store=$storeName", "beforePid=$beforePid", $stopped, "afterForceStopPid=$remainingPid") | Set-Content -LiteralPath $resultLog -Encoding UTF8
if ($remainingPid) { throw "强停后进程仍存在，原始记录：$resultLog" }

& (Join-Path $PSScriptRoot 'device-test.ps1') -DevEcoHome $DevEcoHome -TargetId $TargetId `
    -TestClass 'ArchiveRestartTest#verify_after_process_restart' -ExpectedTests 1 -RestartStore $storeName -SkipInstall
Write-Host "进程强停与重启回读通过。原始记录：$resultLog"
