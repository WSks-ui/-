function Read-HypiumReport {
    param([string]$Report, [int]$ProcessExitCode, [int]$ExpectedTests = 0)
    $summaries = [regex]::Matches($Report, 'Tests run:\s*(\d+),\s*Failure:\s*(\d+),\s*Error:\s*(\d+),\s*Pass:\s*(\d+),\s*Ignore:\s*(\d+)')
    $suites = [regex]::Matches($Report, '(?m)^OHOS_REPORT_SUM:\s*(\d+)\s*$')
    if ($ProcessExitCode -ne 0 -or $summaries.Count -ne 1 -or $suites.Count -eq 0 -or
        $Report -notmatch '(?m)^TestFinished-ResultCode:\s*0\s*$' -or $Report -match 'Timeout:') {
        throw '设备测试缺少完整且唯一的结束报告，或进程异常/超时。'
    }
    $summary = $summaries[0]
    $total = [int]$summary.Groups[1].Value
    $failed = [int]$summary.Groups[2].Value
    $errors = [int]$summary.Groups[3].Value
    $passed = [int]$summary.Groups[4].Value
    $ignored = [int]$summary.Groups[5].Value
    # OHOS_REPORT_SUM 是每个 suite 的数量；多 suite 要求和，不能只读取第一项。
    $declaredTotal = 0
    foreach ($suite in $suites) { $declaredTotal += [int]$suite.Groups[1].Value }
    $starts = [regex]::Matches($Report, '(?m)^OHOS_REPORT_STATUS_CODE:\s*1\s*$').Count
    $successes = [regex]::Matches($Report, '(?m)^OHOS_REPORT_STATUS_CODE:\s*0\s*$').Count
    if ($total -le 0 -or $total -ne $declaredTotal -or $starts -ne $total -or $successes -ne $total -or
        ($ExpectedTests -gt 0 -and $total -ne $ExpectedTests) -or
        $failed -ne 0 -or $errors -ne 0 -or $ignored -ne 0 -or $passed -ne $total) {
        throw "设备测试未全部通过或数量不完整：Pass=$passed / Total=$total，Failure=$failed，Error=$errors，Ignore=$ignored。"
    }
    return [PSCustomObject]@{ Total = $total; Passed = $passed }
}
