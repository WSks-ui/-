$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'device-report.ps1')
$validReport = @'
OHOS_REPORT_SUM: 1
OHOS_REPORT_STATUS_CODE: 1
OHOS_REPORT_STATUS_CODE: 0
OHOS_REPORT_SUM: 2
OHOS_REPORT_STATUS_CODE: 1
OHOS_REPORT_STATUS_CODE: 0
OHOS_REPORT_STATUS_CODE: 1
OHOS_REPORT_STATUS_CODE: 0
OHOS_REPORT_RESULT: stream=Tests run: 3, Failure: 0, Error: 0, Pass: 3, Ignore: 0
TestFinished-ResultCode: 0
'@
$cases = @(
    [PSCustomObject]@{ Name='多 suite 完整通过'; Report=$validReport; Exit=0; Expected=3; Reject=$false },
    [PSCustomObject]@{ Name='单 suite 完整通过'; Report=$validReport.Replace("OHOS_REPORT_SUM: 1`n", '').Replace('OHOS_REPORT_SUM: 2','OHOS_REPORT_SUM: 3'); Exit=0; Expected=3; Reject=$false },
    [PSCustomObject]@{ Name='退出码非零'; Report=$validReport; Exit=1; Expected=3; Reject=$true },
    [PSCustomObject]@{ Name='退出码零但有 Error'; Report=$validReport.Replace('Error: 0, Pass: 3','Error: 1, Pass: 2'); Exit=0; Expected=3; Reject=$true },
    [PSCustomObject]@{ Name='超时缺少摘要'; Report='Timeout: user test is not completed within the specified time.'; Exit=0; Expected=3; Reject=$true },
    [PSCustomObject]@{ Name='suite 数量与摘要不符'; Report=$validReport.Replace('OHOS_REPORT_SUM: 2','OHOS_REPORT_SUM: 4'); Exit=0; Expected=3; Reject=$true },
    [PSCustomObject]@{ Name='忽略用例不能当完整通过'; Report=$validReport.Replace('Pass: 3, Ignore: 0','Pass: 2, Ignore: 1'); Exit=0; Expected=3; Reject=$true },
    [PSCustomObject]@{ Name='旧包用例数量不足'; Report=$validReport; Exit=0; Expected=10; Reject=$true },
    [PSCustomObject]@{ Name='缺少原生结束标记'; Report=$validReport.Replace('TestFinished-ResultCode: 0',''); Exit=0; Expected=3; Reject=$true }
)
foreach ($case in $cases) {
    $rejected = $false
    try { $result = Read-HypiumReport -Report $case.Report -ProcessExitCode $case.Exit -ExpectedTests $case.Expected }
    catch { $rejected = $true }
    if ($rejected -ne $case.Reject) { throw "设备报告解析测试失败：$($case.Name)" }
    if (-not $rejected -and ($result.Total -ne 3 -or $result.Passed -ne 3)) { throw '完整报告的解析数量错误。' }
}
Write-Host "设备报告解析测试：$($cases.Count)/$($cases.Count) 通过。"
