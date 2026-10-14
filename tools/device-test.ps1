param(
    [string]$DevEcoHome = $env:DEVECO_HOME,
    [ValidatePattern('^[\w.:-]+$')][string]$TargetId = '',
    [ValidatePattern('^[A-Za-z][\w#,.]*$')][string]$TestClass = '',
    [ValidateRange(0, 10000)][int]$ExpectedTests = 0,
    [ValidatePattern('^yunheji_test_ui_restart_[a-z0-9_]{1,60}$')][string]$RestartStore = '',
    [ValidatePattern('^yunheji_test_ui_[0-9]+_maximum$')][string]$MaximumStore = '',
    [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'deveco-path.ps1')
$DevEcoHome = Resolve-YunhejiDevEcoHome -DevEcoHome $DevEcoHome
$hdcTool = Join-Path $DevEcoHome 'sdk\default\openharmony\toolchains\hdc.exe'
if (-not (Test-Path -LiteralPath $hdcTool)) { throw '未找到 HDC，请设置 DEVECO_HOME 或传入 -DevEcoHome。' }
$workspace = Split-Path $PSScriptRoot -Parent
$resultDirectory = Join-Path $workspace 'docs\test-results'
New-Item -ItemType Directory -Path $resultDirectory -Force | Out-Null

# 防止构建失败后误装上一版遗留 HAP。两个包都须晚于各自源文件，
# 主包源文件也属于测试包的输入；存在较新源码时先构建，不运行旧包冒充当前验证。
$mainPackage = Join-Path $workspace 'entry\build\default\outputs\default\entry-default-unsigned.hap'
$testPackage = Join-Path $workspace 'entry\build\default\outputs\ohosTest\entry-ohosTest-unsigned.hap'
foreach ($package in @($mainPackage, $testPackage)) {
    if (-not (Test-Path -LiteralPath $package)) { throw '缺少主包或测试包，请先运行构建脚本。' }
}
$mainInputs = @(& rg --files (Join-Path $workspace 'entry\src\main') (Join-Path $workspace 'AppScope'))
$testInputs = @(& rg --files (Join-Path $workspace 'entry\src\ohosTest'))
foreach ($sourcePath in $mainInputs) {
    if ((Get-Item -LiteralPath $sourcePath).LastWriteTimeUtc -gt (Get-Item -LiteralPath $mainPackage).LastWriteTimeUtc) {
        throw '主包早于最新源码，请先运行 tools/build.ps1。'
    }
}
foreach ($sourcePath in @($mainInputs) + @($testInputs)) {
    if ((Get-Item -LiteralPath $sourcePath).LastWriteTimeUtc -gt (Get-Item -LiteralPath $testPackage).LastWriteTimeUtc) {
        throw '测试包早于最新源码，请先运行 tools/build.ps1 -Target ohosTest。'
    }
}

# 只操作实际在线的指定设备；多个设备时要求显式选择，避免安装到用户的其他设备。
$targets = @(& $hdcTool list targets | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -ne '[Empty]' })
if ($LASTEXITCODE -ne 0) { throw 'HDC 设备查询失败。' }
if (-not $TargetId) {
    if ($targets.Count -ne 1) { throw '须有且仅有一个在线设备，或使用 -TargetId 指定设备。' }
    $TargetId = $targets[0]
}
if ($TargetId -notin $targets) { throw '指定设备不在线，未执行安装或测试。' }

if (-not $SkipInstall) {
    $packages = @(
        (Join-Path $workspace 'entry\build\default\outputs\default\entry-default-unsigned.hap'),
        (Join-Path $workspace 'entry\build\default\outputs\ohosTest\entry-ohosTest-unsigned.hap')
    )
    foreach ($package in $packages) {
        if (-not (Test-Path -LiteralPath $package)) { throw '缺少主包或测试包，请先运行构建脚本。' }
    }
    foreach ($package in $packages) {
        $installation = & $hdcTool -t $TargetId install $package
        $installation
        if ($LASTEXITCODE -ne 0 -or ($installation -join "`n") -notmatch 'install bundle successfully') {
            throw 'HAP 安装失败。未继续运行测试。'
        }
    }
}

$timestamp = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow,
    [TimeZoneInfo]::FindSystemTimeZoneById('China Standard Time')).ToString('yyyy-MM-dd-HHmmss')
$logPath = Join-Path $resultDirectory "$timestamp-device.log"
$testCommand = 'aa test -b com.chr.myapplication -m entry_test -s unittest OpenHarmonyTestRunner -s timeout 240000 -w 600'
if ($TestClass) { $testCommand += " -s class $TestClass" }
if ($RestartStore) { $testCommand += " -s archiveRestartStore $RestartStore" }
if ($MaximumStore) { $testCommand += " -s archiveMaximumStore $MaximumStore" }
$reportLines = [System.Collections.Generic.List[string]]::new()
& $hdcTool -t $TargetId shell $testCommand 2>&1 | ForEach-Object {
    $reportLines.Add($_.ToString())
    $_
} | Tee-Object -FilePath $logPath
$processExitCode = $LASTEXITCODE
$report = $reportLines -join "`n"

# aa test 即使有 Error 也可能返回 0。必须核对原始摘要、声明的用例数和实际通过数；
# 超时、缺摘要、被过滤成 0 项或被忽略的用例均不能作为一次完整回归通过。
. (Join-Path $PSScriptRoot 'device-report.ps1')
try { $result = Read-HypiumReport -Report $report -ProcessExitCode $processExitCode -ExpectedTests $ExpectedTests }
catch { throw "$($_.Exception.Message) 原始结果：$logPath" }
Write-Host "设备测试 $($result.Passed)/$($result.Total) 通过。原始结果：$logPath"
