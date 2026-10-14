# 文明连线外观测试期间的模拟器渲染服务崩溃

日期：2026-10-14。原始文件为 `cppcrash-render_service-1003-20261014174400948.log`，完整转储留在被忽略的 `entry/build/test-evidence/culture/render-service-crash.log`。这里只保留无用户档案、账号或设备标识的诊断摘要。

```text
Device info: emulator
Build info: emulator 7.0.0.107(SP8DEVC00E999R4P11)
Module name: render_service
Timestamp: 2026-10-14 17:44:00.948
Pid: 774
Process name: /system/bin/render_service
Reason: Signal:SIGSEGV(SEGV_MAPERR)@0x00007f2a2f176000
Fault thread: Tid 880, RSUniRenderThre
```

原始故障线程栈顶部含 `ld-musl-x86_64.so.1` 与 `libsec_shared.z.so(memcpy_s+71)`；后续含 `libdgles.z.so(send_to_host)`、`glDrawRangeElements`、`libskia_canvaskit.z.so(GrGLOpsRenderPass::onDrawIndexed)` 和 `librender_service_base.z.so(RSPaintFilterCanvasBase::Restore)`。转储明确提示 #03 起可能为不可靠回溯，不作完整调用因果结论。

对应 `174205-device.log`：第一项图谱/个人专题已通过，第二项外观场景开始后中断，最终缺结束摘要并超时。查询时应用和 UiTest 进程已不在，模拟器系统已恢复到锁屏；HDC 仍在线。

尚未确认具体触发原因，不能由系统故障栈认定 Canvas、HDS 或应用本身是根因。修正深色测试时序并恢复模拟器交互状态后，最终 `175431-device.log` 为 2/2，通过不代表此系统崩溃的根因已经修复。
