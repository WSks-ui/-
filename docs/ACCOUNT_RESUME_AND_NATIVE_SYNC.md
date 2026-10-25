# 账号冷启动恢复与鸿蒙设备同步

更新日期：2026-10-21。目标环境：HarmonyOS 7 / API 26 手机模拟器，工程 `targetSdkVersion` 与 `compatibleSdkVersion` 均为 `26.0.0`。

当前可演示的是自建账号的离线冷启动与 HTTPS 同账号同步。原生分布式 KV 已接入本机读写、版本合并与可信设备查询；A/B 真实授权后的可用可信设备数均实测为 **0**，尚未完成原生跨端传输。用户当前使用模拟器、没有腾讯云域名，本机演示可继续，不以购买域名或上云为前置条件。

本文补充此前 [账号同步说明](ACCOUNT_SYNC.md) 中“会话只在进程内”和“原生 KV 尚未接入”的历史状态。华为账号登录仍未接入；自建账号 ID、安装实例 `deviceId` 与鸿蒙可信设备身份是不同概念。

## 1. 账号身份与网络会话分开恢复

[AccountWorkspaceStore](../entry/src/main/ets/data/AccountWorkspaceStore.ets) 将数据分为两部分：

| 部分 | 保存位置 | 内容与用途 |
|---|---|---|
| 本机身份指针 | `<基础库名>_identity_v1` Preferences 的 `workspace` 键 | `version: 1`、真实认证所得的 `accountId`、`username`；定位原账号本机档案 |
| 网络会话 | 系统 ASSET，alias 使用上述身份库名 | 会话的账号、用户名、token 与到期时间；token 不写入 Preferences、快照、备份或日志 |

ASSET 写入使用 `DEVICE_FIRST_UNLOCKED` 与 `SyncType.NEVER`，凭据留在当前设备。读取时校验会话格式、到期时间及其与身份指针的一致性，不把本机指针当成服务端认证凭据。

冷启动先读取身份指针，再打开对应账号 Preferences；会话有效时恢复网络同步。ASSET 不支持、暂不可读、没有有效凭据或会话已过期时，仍可打开身份指向的离线档案，继续浏览与编辑，重新登录后再恢复网络同步和 AI 请求；不回退到明文保存 token。

自建服务的 token 有效期为 **12 小时**，见 [account-service.mjs](../server/account-service.mjs)。客户端没有刷新 token 接口，到期或服务端返回 `ACCOUNT_SESSION_EXPIRED` 后需重新登录；账号本机记录与身份指针继续保留。读取快照期间恰好到期也只降级为离线会话。

首次真实登录新账号时打开空账号工作区，再合并服务端已有记录。游客库 `yunheji_archive_v1` 与账号库 `yunheji_account_v1_<accountId>` 分开保存；不自动把游客记录上传到账号。主动退出清除当前身份指针和 ASSET 会话，回到游客入口，账号快照仍保留。

## 2. Preferences 与原生版本库各自负责什么

[LocalArchiveRepository](../entry/src/main/ets/data/LocalArchiveRepository.ets) 的 Preferences 仍是页面已确认快照：先校验并完成本机落盘，再发布保存成功。原有 `previous_snapshot`、损坏时停止读取的保护继续保留，没有用空快照覆盖损坏数据。

[DistributedArchiveChannel](../entry/src/main/ets/sync/DistributedArchiveChannel.ets) 新增并行的原生 KV 通道，没有替代或删除旧 Preferences，也没有修改收藏、笔记与手账的 **schema v1**。身份指针是独立资源，不是快照 schema 升级；旧记录无需补造字段或迁移到新格式。

- 原生库 ID 按 `scope + ':' + accountId` 的 SHA-256 派生；正式使用空 scope，独立设备测试使用受校验的 `yunheji_test_ui_*` scope。
- 每条记录以 `record_v1_<SHA-256(JSON.stringify(record))>` 为不可变版本键，值为原记录 JSON；修改产生新键，已有版本不按逻辑 ID 覆盖。
- 删除仍产生带 `deleted: true` 的墓碑。正文、标签、手账视角、纸色、印章及 AI 冻结事实随各版本保存，当前实现不清理旧版本键。
- 读回每个版本先通过正式 v1 解析器，再以既有 `compareVersions` / `mergeRecords` 合并逻辑 ID，将结果并入当前快照并落盘；没有新增历史版本查看或用户恢复界面。
- KV 配置为加密、`SINGLE_VERSION`、`SecurityLevel.S1`、`autoSync: false`。本机 KV 写入和重开成功只证明本机能力，不表示发生跨端传输，也不表示已交付完整备份恢复流程。

## 3. 交换、确认与前台轮询

[Index.ets](../entry/src/main/ets/pages/Index.ets) 前台每 **5 秒**尝试账号交换并驱动原生通道，确认保存后也会主动尝试；保存锁、身份切换及在途请求会让本次尝试跳过。后台停止新的定时尝试，回前台后继续。当前没有注册 `dataChange` 监听来实时更新页面。

HTTPS 响应到达后，与此刻的快照合并，避免把发送时的旧快照回写到新编辑上；若正在保存则留到下一轮处理。身份代次变化后，旧响应不能写入新账号工作区。

网络响应校验和必要本机落盘完成后，更新最近交换时间；“已同步”还要求当前记录版本与服务端回包版本一致。`pendingCount` 统计未确认版本，单篇手账也按实际版本确认，不再用“响应时间晚于编辑时间”推断该编辑已经上传；发现本轮未确认的新编辑时会补传。

原生通道先查询真实 `ohos.permission.DISTRIBUTED_DATASYNC` 授权，再读取系统可用可信设备列表；有对端时才调用 `sync(..., PUSH_PULL)`。仅在真实 `syncComplete` 回调返回非空结果且全部状态码为 0 时，更新 `lastSuccessfulSync`。无对端、写库成功、发起调用或 20 秒超时都不会生成新的平台成功时间。

## 4. 两台模拟器的实际边界

当前使用两台 HarmonyOS 7 / API 26 手机模拟器。A/B 经真实系统“允许”弹窗授予权限后，可用可信设备数均为 **0**，通道保持“等待可信设备”，最近平台传输显示“尚无跨端确认”。两台模拟器都在线、使用同一自建账号，不会自动产生鸿蒙可信关系。原始状态见 [A 平台事件](test-results/2026-10-21-stage-native-a-events.log)与 [B 平台事件](test-results/2026-10-21-stage-native-b-events.log)。

因此当前可说明“已接入原生 KV 本机版本库和真实授权、设备查询入口”，不能说明“已经完成鸿蒙分布式双端同步”。HTTPS A/B 接收离线编辑仍可继续演示；账号服务的在线设备统计也不能代替系统可信设备列表。

原生测试覆盖本机版本写入、关闭重开、较新版本合并、墓碑不复活，以及真实授权后的设备清单。它们没有证明设备发现认证、原生 A/B 记录传输、自动重连或真机能力已完成。

## 5. 本机复现

从仓库根目录运行 PowerShell，先启动并解锁两台模拟器。需要 DevEco 自带 Node/HDC 与本机 OpenSSL；DevEco 路径通过 `DEVECO_HOME`、`-DevEcoHome` 或已有本机忽略配置提供，不改签名文件。

```powershell
.\tools\test.ps1
.\tools\resume-test.ps1 -DeviceA 127.0.0.1:5555 -DeviceB 127.0.0.1:5557
```

[resume-test.ps1](../tools/resume-test.ps1) 默认启动或复用本机回环 HTTPS 服务，生成一组新 fixture，构建主包和测试包，再依次执行下表五阶段。默认服务为 `https://127.0.0.1:18443`，通过两端各自 HDC 反向端口访问同一数据库。

| 阶段 | 设备与真实操作 | 当前证据边界 |
|---|---|---|
| `prepare_authenticated_memory` | A 经 UI 注册、保存手账，回读账号库和 ASSET 会话 | [最终主包 1/1](test-results/2026-10-21-002145-da29bbdd-device.log) |
| `cold_start_while_service_unavailable_edit_same_memory` | 停止本任务服务并强停应用，A 冷启动不重复登录，编辑同一条记录并读盘 | [最终主包 1/1](test-results/2026-10-21-002337-2eeda69c-device.log) |
| `cold_start_reconnect_without_login` | 恢复同一服务，A 再次冷启动，恢复会话并确认网络交换 | [最终主包 1/1](test-results/2026-10-21-002438-5d092c91-device.log) |
| `other_device_receives_offline_edit` | B 同账号登录，等待真实首轮交换落盘，检查离线修改全文 | [最终主包 1/1](test-results/2026-10-21-002503-ab751608-device.log) |
| `cleanup_a_and_forget_session` | 清理 A 本轮独立账号档案与会话，检查身份已清除 | [最终主包 1/1](test-results/2026-10-21-002630-8c16bcd3-device.log) |

五阶段在同一最终主包与测试包 T1 上连续通过，Failure / Error / Ignore 均为 0；脚本实际复跑使用本轮新生成且已构建的 fixture。最终主包 SHA-256 `9AF0483A63AA0425B70253A33B02EC832E8C1B3BABB66B8E42ABF9F5B7AB6AD6`，两版测试包及授权等待失败的边界见[测试报告第 30 节](TEST_REPORT.md#30-账号离线冷启动与原生分布式通道基础2026-10-21)。[四张原生画面](design/stage-foundation/README.md)保留了 A 离线编辑、B 接收、真实状态卡和最终页面复验中的 AI 手账依据。

`-SkipBuild` 会沿用已有 fixture 与包，不生成新账号；仅用于已核对包和前置状态的分阶段排查。不能把同一 fixture 的重复注册失败当成新一轮冷启动结果，也不要在 A/B 阶段之间重新生成 fixture。

原生专项在当前主包和测试包构建完成后运行：

```powershell
.\tools\build.ps1
.\tools\build.ps1 -Target ohosTest
.\tools\device-test.ps1 -TargetId 127.0.0.1:5557 -TestClass NativeArchiveTest -ExpectedTests 2
```

`NativeArchiveTest` 两项定义见 [StageFoundation.test.ets](../entry/src/ohosTest/ets/test/StageFoundation.test.ets)，使用真实权限弹窗和平台 KV。当前无对端场景要求成功时间保持 0；若环境后来建立真实可信关系，应另做双端传输验收，不把本机用例的历史结果沿用为跨端证据。

设备结果核对完整结束摘要及 `Pass / Failure / Error / Ignore`；`aa test` 退出码为 0 不能独立证明通过。原始日志位于 `docs/test-results/*-device.log`。停止服务只影响本任务端点，不代表整机断网，也不代表离线完成服务端账号认证。

## 6. 可选公网配置与调试回退

[ServiceConfiguration.ets](../entry/src/main/ets/sync/ServiceConfiguration.ets) 为账号、AI 与水情客户端统一读取配置，顺序如下：

1. 优先读取 `entry/src/main/resources/rawfile/account-service.json`。对象的 `endpoint` 必须是完整 HTTPS origin：域名及可选端口，不含路径、查询、片段或结尾斜杠；不接受数字 IP、`.local`、`.localhost`。端口可省略，指定时为 1—65535。
2. 公网配置不提供自定义 CA，返回值仅含 endpoint，网络请求使用系统受信任证书。若文件存在但格式或校验失败，返回未配置，不继续回退到调试服务。
3. 仅当公网文件不存在且 `DEBUG` 为真时，读取 `account-sync-dev.json`，校验回环或私有 IPv4 / localhost、1024—65535 端口及 PEM 公开 CA；release 不读取调试自签配置。

公网文件是可选的，当前没有已部署域名就保持缺省。端点加载支持不等于完成服务部署或公网验收；应用不会自行猜测域名。配置源文件已被 Git 忽略，不向其中加入 token 或私钥。

[start-account-server.ps1](../tools/start-account-server.ps1) 负责生成本机自签证书、调试资源及反向端口，HTTPS 继续校验证书和主机名。若改服务地址或证书，重新构建并安装两包，确保 HAP 中配置对应当前服务；可选局域网用法见 [账号同步说明](ACCOUNT_SYNC.md)。

## 7. 独立测试与清理范围

UI 测试只通过 debug 启动参数使用校验后的 `yunheji_test_ui_*` 名称，不枚举或清空正式档案。fixture 随机凭证仅在被忽略的测试 rawfile 和 `.local/account-sync/`，不进主包或公开报告。

[ArchiveUiSession.dispose()](../entry/src/ohosTest/ets/test/ArchiveUiSession.ets) 先终止真实窗口，再根据当前工作区清理其本轮账号 Preferences、原生 KV、ASSET 与身份指针，最后删除本轮游客库。原生删除入口还会拒绝空测试 scope；清理失败必须保留在结果中。

这只覆盖本轮单账号 Foundation 的当前工作区。旧的“同一 scope 先登录 A、退出后登录 B”可能已失去 A 的身份指针；旧 `MemorySync` 清理也尚未全部适配身份与原生库，不能宣称历史多账号 scope 均已清理。中断后只按已知运行编号和账号处理残留，不扩展为正式用户库清空。

## 8. 源码与 SDK 核验

核验日期：**2026-10-21**；目标为本机 **API 26** SDK 声明与上述模拟器范围，不推断 OpenHarmony API 12 或所有真机均具备同等能力。

| 本机 SDK 声明 | 核验用途 |
|---|---|
| `ets/api/@ohos.security.asset.d.ts` | ASSET 的 add/query/remove、`DEVICE_FIRST_UNLOCKED`、`SyncType.NEVER` |
| `ets/api/@ohos.data.distributedKVStore.d.ts` | KV 选项、`sync(PUSH_PULL)`、`syncComplete`；声明同时提供 `dataChange`，当前代码未订阅 |
| `ets/api/@ohos.distributedDeviceManager.d.ts` | `createDeviceManager`、`getAvailableDeviceListSync` 与设备管理器释放 |

SDK 声明位于本机 DevEco 的 `sdk/default/openharmony/` 下。领域校验与账号库名见 [AccountSync.ts](../entry/src/main/ets/domain/AccountSync.ts)，原生状态标签见 [DistributedArchive.ts](../entry/src/main/ets/domain/DistributedArchive.ts)，完整设备结论以 [TEST_REPORT.md](TEST_REPORT.md) 的对应版本记录为准。
