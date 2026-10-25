param([string]$DevEcoHome = $env:DEVECO_HOME)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'deveco-path.ps1')
$DevEcoHome = Resolve-YunhejiDevEcoHome -DevEcoHome $DevEcoHome
$node = Join-Path $DevEcoHome 'tools\node\node.exe'
if (-not (Test-Path -LiteralPath $node)) { throw 'Set DEVECO_HOME or pass -DevEcoHome.' }
Push-Location (Split-Path $PSScriptRoot -Parent)
$previousTs = $env:YUNHEJI_TYPESCRIPT
try {
    $env:YUNHEJI_TYPESCRIPT = Join-Path $DevEcoHome 'sdk\default\openharmony\ets\build-tools\ets-loader\node_modules\typescript\lib\typescript.js'
    & $node --experimental-strip-types --test tools/domain.test.mjs tools/repository.test.mjs tools/ai-observation.test.mjs tools/journey-scroll.test.mjs server/water-situation.test.mjs server/kaifeng-ai.test.mjs server/kaifeng-route.test.mjs
    if ($LASTEXITCODE -ne 0) { throw "Tests failed: $LASTEXITCODE" }
    & (Join-Path $PSScriptRoot 'device-report.test.ps1')
} finally {
    $env:YUNHEJI_TYPESCRIPT = $previousTs
    Pop-Location
}
