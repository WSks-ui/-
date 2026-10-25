# 测试报告与验收清单

**2026-10-25后续最新阶段：《汴京开市》经营样板及纸景手势热路径修复。** 主包 **M3**、最终定向测试包 **T4**，本地252/252、报告解析9/9。手机默认四段失败、手机/平板策略成功及亲笔记忆/重开、两端连续划剪/移光按各自原始报告通过，保留首轮平板键盘缺陷和原生Alert定位Error。设备采样没有被写成FPS结论。先读[第36节](#river-market-20261025)、[最新交接](RIVER_MARKET_HANDOVER_20261025.md)和[机器清单](test-results/2026-10-25-river-market.json)。下方纸景M14/T15为前一阶段，不代表用户认可其趣味性或手势性能。

**2026-10-25 前一阶段：纸上生城。** 当前主包为本轮纸景 **M14**，最后定向测试包 **T15**；本地 **241/241**、报告解析 **9/9**、服务 **2/2**。首轮手机 `PaperJourneyTest` 2/2，自建账号 HTTPS 的 A 保存、B 接收续剪与原 A 回收新版本各 1/1；纸景 M12/T12 的移光、平板选摘/UDMF、桌面卡片分别 1/1，M14/T14 分享 1/1。手机保存/撤销/冷重开/旧收藏用例在 T14、入口单例在 T15 分别 **1/1**；原 M14/T14 整套 **Tests 2 / Pass 1 / Failure 0 / Error 1 / Ignore 0** 保留，不改写成 T15 同次 2/2。M14/T15 原 A 接收另复跑 **1/1**，最终分片还原深比较仍为 PASS，冻结 note/三条来源与新 mask 准确。本任务服务停止后的五城手势、M14 平板两张真实桌面卡的整进程强停后冷路由与热路由另存人工记录，不加 Hypium Pass；四次人工路由和本轮两张新卡移除均已完成，试玩库/模拟器数据有意保留，18443 服务恢复后 health 200，M14 图集及 layout 已归档。六份含 Error 的原始报告及真实 Sheet 缺陷均保留。详见[第 35 节](#paper-journey-20261025)、[机器清单](test-results/2026-10-25-paper-journey.json)和[交接](PAPER_JOURNEY_HANDOVER_20261025.md)。不同包阶段不相加为最终包全套通过，下方旧轮次的“最新”保留历史含义。

2026-10-14 用户已明确演示使用团队自有鸿蒙设备，模拟器与实机均可，举办方不提供或指定运行平台。此项设备规则已确认，不要求额外的赛事平台兼容验收；实际安装、分布式能力和多端交互继续按本报告测试。规则澄清不新增任何设备测试通过结果，以下历史证据保持原样。

最新测试日期：2026-10-20。本轮全面审查、页面复跑、原生图谱、水情与 HTTPS 双端手账见第 29 节。所有“通过”仅覆盖明确列出的内容；各节历史结果只对应该轮实际包，不累计为最新包覆盖。

**本轮摘要（2026-10-20）：本地 113/113、报告解析 9/9、服务 13/13，两包构建成功。页面首轮 4/5（Error=1），修正失效 Widget 等待后该项单独 1/1；水情、当前原生图谱、普通手账 HTTPS A/B 保存接收回放各 1/1，独立库清理 2/2。主包业务未改，测试工具修正与原始失败完整保留。全量历史 UI、原生分布式、华为账号、平板实机、双连壶 AI 双端和真人计时仍未因此通过。详见第 29 节。下方 2026-10-18 的“最新”是历史阶段标题。**

**最新档案正文与实景图补齐（2026-10-18）：本地 103/103、报告解析 9/9，主包构建成功；17 条骨架档案按官方公开页面重写，20 条均有条目级来源，五城增加简介，档案卡增加摘要，16 条接入 Wikimedia Commons 授权实景图并标注许可。主包 SHA-256 `EF9FCADB10275DE2438486D6766B8E88FB68B17523EA17C60165649D53488F84`。实机核对档案卡摘要、城市简介、二里头照片卡与正文；未重跑长 UI 回归，内容仍标注“初稿待校审”。来源与许可见[图片与内容来源](IMAGE_CREDITS.md)。**

**前一轮页面功能、层级与 AI 重访（2026-10-18）：本地 103/103、报告解析 9/9、AI 服务 10/10，主包与测试包构建成功；最终包档案 / 记忆分区 / 我的二级页及真实 AI 路径 2/2（92641ms、176619ms），Failure / Error / Ignore 均为 0；手账全文编辑 / 搜索 / 回放 / 删除墓碑在本轮修复包 1/1（99713ms）。修复了编辑返回的旧正文与延迟焦点异常；逐次失败、版本差异及未覆盖范围见第 27 节，[实际页面](design/page-hierarchy/README.md)已检查。**

**最新 UI/UX 改版（2026-10-18）：首页、五城河洛、详情、记忆、档案、我的和登录页完成一轮结构性清理；本地 103/103、报告解析 9/9，主包与测试包构建成功。首页核心路径 1/1、233042ms，方鼎观察 / 保存 / 回放 1/1、190017ms，Failure / Error / Ignore 均为 0；两条用例在最终包上通过。详见第 26 节与[UI/UX 改版图集](design/ui-refresh/README.md)。**

**最新双端手账闭环：本地95/95、报告解析9/9，主包与最终测试包构建成功。A 端经真实登录页注册独立空账号，在庙底沟“西部陶窑”主动右转后真实保存并回读磁盘；B 端同账号经 HTTPS 收到同一条 note，首页显示真实 1/4 与原画幅预览，点击后正式回放实际绘制。A 端 1/1、159100ms，B 端 1/1、104368ms，Failure / Error / Ignore 均为 0；两端整幅 Canvas 1032×1050 零像素差异，模型 390753 像素一致，两端首页预览也逐像素相同。主线排练 A 段设备路径 1/1，但自动化分段合计 207663ms，不能当作真人三分钟计时；录像按用户本轮指示不由代理录制。详见第 23 节。[阶段清单](test-results/2026-10-17-memory-sync-phases.json)与[双端图集](design/memory-sync/README.md)。**

**随后同日按用户要求改版首页：恢复五城沙盘、纸页入口、城市索引与检索分区的丰富结构，并保留主题直达与最近真实记忆。改版后本地 95/95、报告解析 9/9，主包与测试包构建成功；首页核心路径 1/1、203638ms，Failure / Error / Ignore 均为 0。详见第 24 节与[首页改版图集](design/home-redesign/README.md)。T11 双端结果为改版前首页布局，本轮未重跑双端。**

**最新三处观察扩展：本地95/95、报告解析9/9，两包构建成功。庙底沟与杜岭二号方鼎的独立revision 2场景及手账 / 回放已接入，新增两处最终同包核心路径2/2，Failure / Error / Ignore均为0，耗时155058ms、155787ms。12张原图齐备，两处保存前与正式回放的1032×1050整幅Canvas逐像素完全一致；画廊按原画幅适配核对通过。中间失败、旧包通过、日志补采及两次超时均按实际版本保留，最终测试优化保留全部业务断言、六图与240000ms上限。T04/T07/T08的三处样板扩展可按本轮范围验收，当前实现、证据与Git状态见第21节。该里程碑之后的T09/T10首页与T11双端手账已在后续节验收；T13三分钟录像仍未完成。**

**内容 / 图谱历史版本：本地 48/48、报告解析 9/9，主包与三版测试包构建成功；新增内容与画布专项分组 4/4，原有图谱 2/2、组合筛选 1/1、存储 / 浏览 6/6，七份完整设备报告 Failure/Error/Ignore 为 0。13 张真实原图已检查。该轮模拟器实际使用 Canvas 2D 降级，WebGL 未验证；见第 14 节。**

**登录 / 个人页历史版本：本地 43/43、报告解析 9/9，主包 / 测试包构建成功；ProfileLoginTest 4/4、存储 / 浏览 6/6、未登录与收藏笔记 CRUD / Ability 重建 2/2，Failure/Error/Ignore 均为 0。12 张截图已检查。独立启动登录、Dock 外原生“我的”、页面拆分和教育计划占位已验证，证据及失败见第 13 节。**

**账号双端历史版本：本地 43/43、报告解析 9/9、HTTPS / SQLite 服务综合 1/1，主包与两版测试包构建成功；8/8 账号 / 双端场景、2/2 独立库清理、存储 / 浏览 6/6、未登录状态 1/1、文明连线 2/2，Failure/Error/Ignore 为 0。10 张账号原图已检查，证据、两版测试包与保留的失败见第 12 节。该轮为本机自建账号的真实网络同步，未将其称为华为账号或鸿蒙分布式数据库；这些旧包结果不覆盖本轮三处新手账在另一端的接收、预览或回放。早期 12 项全量回归、失败、超时和工具崩溃仍按对应旧包保留。**

## 1. 环境

| 项目 | 实测环境 |
|---|---|
| 工程 | ArkTS Stage，entry HAP |
| 工具 | DevEco Studio 26.0.0.821，Hvigor 6.26.4 |
| SDK | HarmonyOS 26.0.0.105 / API 26 |
| Node | 24.14.1 |
| 模拟器 | Pura 90 Pro 配置，HarmonyOS 7.0.0.107 |
| 屏幕配置 | 1256×2760，density 560 |
| 安装包 | entry-default-unsigned.hap |
| 包名 | com.chr.myapplication |
| 签名 | 未配置；当前模拟器可安装 unsigned 包 |

本节环境及下方第 2—7 节为第一轮历史记录，当时没有验证 OpenHarmony 真机、API 12、平板或真实双端同步。最新第二台实例及真实网络同步证据见第 12 节。

## 2. 执行结果

| 验证项 | 结果 | 范围 |
|---|---|---|
| 主 HAP ArkTS 构建 | 通过 | 完整 assembleHap；无签名配置警告属于已知状态 |
| 测试 HAP 构建 | 通过 | 包含真实 TestAbility 和 Hypium Runner |
| 本地领域自动化 | 26/26 通过 | 检索、排序、推荐、模型、合并、资源与主题 |
| Repository 故障注入 | 9/9 通过 | 真实源文件内存转译，平台替身不进入应用 |
| 模拟器安装/启动 | 通过 | HDC install 与 aa start 返回成功，实际看到原生首屏 |
| 手机首屏目视 | 通过 | 标题、五城索引、检索、筛选、档案行、底部导航可见 |
| 设备端持久化 | 通过 | 写入后清除 Preferences 缓存，再打开可读到中文与安装 ID |
| 设备端损坏保护 | 通过 | 损坏 JSON 读取被拒绝，原值未覆盖 |
| 设备端串行保存 | 通过 | 并发提交按序落盘，最终状态与前一快照正确 |
| 设备端完整 UI 用例 | 未通过，待复验 | 在“1 处文化遗产”的可见节点断言失败 |
| 后续界面控制 | 用户停止 | 原生控制工具报告用户按 Esc；此后未继续界面操作 |

**第一轮最近一次实际设备测试汇总：Tests run: 4, Failure: 0, Error: 1, Pass: 3, Ignore: 0。**

该次命令本身返回 0，但用例有错误，所以不能标为全通过。

最终本地测试汇总：**35 项，通过 35 项，失败 0 项**。主包和测试包最后一次构建均成功。
测试包仍有 TestRunner 错误结束路径调用 `finishTest` 的异常处理提示，另有无签名配置提示；不影响本次编译，但正式交付前应清理。
最后的源码硬化后没有再次安装到模拟器；用户停止界面控制前的运行观察不代表最终包已完成全量运行回归。

## 3. 自动化覆盖说明

### 本地域测试

- 五城覆盖、稳定 ID 唯一、未校审状态和离线插图存在。
- 空检索、纯空白、多关键词和三维 AND 筛选、无结果。
- 收藏/笔记活跃记录过滤、墓碑隐藏、最新排序。
- 单机时钟回拨时的单调时间戳。
- 新时间覆盖、同时间设备决策、同时间删除优先。
- 旧离线版本不能复活删除记录。
- 合并幂等与交换、规范字段比较不受属性插入顺序影响。
- 快照深拷贝、中文往返、损坏/未来版本/非法记录拒绝。
- 推荐理由、冷启动稳定、收藏/浏览作为输入、排除已浏览重复。
- 未接入同步必定拒绝，不声称设备连接或成功时间。
- 浅深色资源键一致。

### Repository 本地故障注入

测试直接转译 `LocalArchiveRepository.ets`，只将平台 Preferences 和随机 ID 换为内存替身。
用于验证初始化、已有空值/错类型/损坏数据保护、孤立备份保护、flush失败回滚、失败后恢复队列、入参复制、串行保存和非法 schema 阻断。

这不能替代真实 Preferences 的平台与磁盘测试；故障注入和设备测试是互补关系。

### 设备测试

`entry/src/ohosTest/ets/test/Archive.test.ets`：

1. `preferences_round_trip_after_cache_eviction`：通过。
2. `corrupt_snapshot_is_not_overwritten`：通过。
3. `queued_saves_keep_latest_and_previous_snapshot`：通过。
4. `native_search_detail_and_note_validation`：失败，最后停在检索计数可见性断言，尚未跑到详情和笔记校验。

测试创建的 Preferences 使用 `yunheji_test_*` 独立名称，不清空主应用用户档案。

## 4. 已发现与修正

- 修正 ArkTS 不允许构造器参数直接声明字段、任意类型 throw 等编译问题。
- 修正组件状态名与内置 `tabIndex` 方法冲突。
- 按 SDK 实际符号表替换不存在的系统图标名。
- 设备测试先创建 TestAbility 获得有效上下文，解决最初四项均报错的启动方式。
- 修正同时间版本比较对 JSON 对象属性插入顺序的依赖。
- 推荐排除已浏览项，避免首页自我推荐重复。
- 标题/说明使用响应式输入，避免复用档案行时推荐理由不更新。
- `Preferences.get` 在值类型不匹配时会返回默认值，最终代码已改为先检查键存在，防止误判首次安装后清空数据。
- UI 用例已补充明确清空搜索、重新获取控件、收起键盘再断言和等待结果；**这只是候选测试修正，没有设备复跑结果，不能断定根因已经排除。**

设备测试通过的是最终硬化前的存储实现；最后的存在性保护由本地故障注入补充验证，仍需在设备回归。

## 5. 可重复命令

```powershell
.\tools\test.ps1
.\tools\build.ps1
.\tools\build.ps1 -Target ohosTest
```

在获得继续设备控制的授权后，可按以下流程执行。连接目标需用 `hdc list targets` 实际返回值替换：

```powershell
$hdc = '<DEVECO_HOME>\sdk\default\openharmony\toolchains\hdc.exe'
& $hdc list targets
& $hdc -t 127.0.0.1:5555 install '<PROJECT_ROOT>\entry\build\default\outputs\default\entry-default-unsigned.hap'
& $hdc -t 127.0.0.1:5555 install '<PROJECT_ROOT>\entry\build\default\outputs\ohosTest\entry-ohosTest-unsigned.hap'
& $hdc -t 127.0.0.1:5555 shell aa start -a EntryAbility -b com.chr.myapplication
& $hdc -t 127.0.0.1:5555 shell aa test -b com.chr.myapplication -m entry_test -s unittest OpenHarmonyTestRunner -s timeout 60000 -w 120
```

本机 HDC 的 Windows 本地文件参数需使用反斜杠绝对路径，否则曾出现路径被重复拼接而无法打开的问题。

## 6. 下一轮验收矩阵

| 编号 | 场景 | 预期结果 | 状态 |
|---|---|---|---|
| U01 | 关键词、城市、年代、类型组合 | 结果为条件交集；重置恢复；无结果提示 | 领域与当前手机模拟器 UI 通过 |
| U02 | 遗址详情与返回 | 正确条目；手机栈返回；平板主从联动 | 手机详情与返回通过，平板待测 |
| U03 | 收藏、取消、分类、重启 | 状态一致，分类可查，重启保留 | 当前包分类、取消与 Ability 重建通过；进程强停仅有第 8 节旧包证据 |
| U04 | 笔记新建/修改/删除 | 时间戳更新，标签保存，删除确认有效 | 当前手机模拟器通过，取消删除与墓碑均核对 |
| U05 | 空白、4000字、中文标签 | 边界正确，校验清晰，不截断既有数据 | 空白、4000 字、20 个完整标签及编辑保留均通过 |
| U06 | 草稿关闭/返回/下拉遮罩 | 提醒未保存，不静默丢稿 | 关闭、返回、继续编辑与放弃通过；下拉/遮罩仍待测 |
| U07 | 落盘失败和连续点击 | 不重复保存，不显示假成功，草稿保留 | 故障注入覆盖，UI待测 |
| U08 | 正常退出、强杀重启 | 已确认保存内容完整 | 当前包缓存回读与 Ability 重建通过；进程强停仅有第 8 节旧包证据 |
| U09 | 无网冷启动 | 全部正式内容和图片可读 | 资源预置，整机断网待测 |
| U10 | 深色、大字、360vp、横屏、平板、分屏 | 无重叠、遮挡、按钮跳动 | 当前手机浅/深色、1.5 倍字体与键盘已检查；其他窗口、横屏、平板、分屏待测 |
| U11 | 光感支持/不支持、关闭、减少动态 | 按设备降级，正文可读，交互无异常 | 当前支持 IMMERSIVE 的手机模拟器能力、开关落盘、关闭 / 减少动态与日夜图通过；无能力设备、真机动态性能待测 |
| U12 | A新增/B可见、双端离线编辑、重连 | 真正最终一致，冲突可追溯 | 未接入 |
| U13 | 删除传播、迟到数据、时钟偏差 | 不复活，异常有记录，结果可解释 | 领域规则通过，双端未测 |
| U14 | 备份恢复、旧数据迁移 | 不丢记录，不复制安装身份 | 未实现 |
| U15 | 所有资料、图片与文旅信息 | 正确出处、授权、核验日期 | 待校审 |

## 7. 交付准则

第一轮可作为后续开发基线；不能作为已完成的参赛作品提交。
正式演示前必须清零核心路径未通过项，完成所选自有鸿蒙设备上的真实同步，并将本报告更新为对应版本的实测证据。

## 8. 第二轮 T02：2026-10-13 实测

用户重新授权模拟器安装与 UI 回归，同时要求不控制电脑桌面。本轮使用 HDC 直连、Hypium/UiTest 与模拟器命令行；没有使用桌面点击控制或浏览器预览。

目标仍为第 1 节的 Pura 90 Pro / HarmonyOS 7 手机模拟器，SDK API 26。包名与 `schemaVersion=1` 保持原值，未更改用户签名配置，未清空正式 `yunheji_archive_v1` 档案。

### 8.1 最终构建与自动化结果

| 验证 | 结果 | 原始证据 |
|---|---|---|
| 代码与 Repository 本地测试 | 37/37 通过：28 项领域/启动规则等测试，9 项 Repository 故障注入 | [本地测试输出](test-results/2026-10-13-t02-local-tests.log) |
| 设备报告解析器 | 9/9 通过：检查错误、超时、忽略、用例数不足和多 suite 汇总 | 同上 |
| 主 HAP 构建 | 通过，已安装并完成当前设备回归 | [主包构建输出](test-results/2026-10-13-t02-main-build.log) |
| 测试 HAP 构建 | 通过 | [测试包构建输出](test-results/2026-10-13-t02-test-build.log) |
| 设备完整回归 | **12/12 通过，Failure=0，Error=0，Ignore=0** | [最终设备报告](test-results/2026-10-13-171556-device.log) |
| 进程强停与新进程回读 | **准备 1/1、验证 1/1 通过，均无 Failure/Error/Ignore**；原进程 PID 15242 已消失 | [准备](test-results/2026-10-13-172950-device.log)、[强停 PID 记录](test-results/20261013_172949-restart.log)、[新进程验证](test-results/2026-10-13-173025-device.log) |

所测包的 SHA-256。完整回归之后，测试代码修正了自定义 aa test 参数的原始键名读取，最新测试包追加完成两阶段强停验证；主包没有变化，分别保留两次测试包哈希：

```text
entry-default-unsigned.hap
040158BD5953137B00A5DD9910E73111B2EAF1134FCB521C500A0C3578B75570

entry-ohosTest-unsigned.hap（12 项完整回归）
F0CEA9F1D21679EE2495EDB43CE81CF0D5C91FE681D41A484BE3E0D616F13400

entry-ohosTest-unsigned.hap（最终构建、两阶段强停回归）
39542447490C618270BFDA4A845381E5499DE8BC865CBEBB1AA55B1BA80938F3
```

构建仍有未配置签名提示，以及 TextAreaController/TextInputController 系统能力覆盖提示。当前模拟器上的成功不能代替所有设备的能力验证，也不能证明 OpenHarmony API 12 兼容。

### 8.2 十二项设备用例的范围

五项真实存储用例覆盖中文回读、损坏值保护、串行保存、既有空值/错类型保护、孤立前一快照保护；全部使用独立测试 Preferences。

七项 UI 用例覆盖：

1. 空结果、单条搜索、详情、空笔记校验和返回，复验第一轮失败项。
2. 同步未接入面板，不把常量设备数或保存时间显示成真实同步状态。
3. 城市/年代/类型/多关键词交集、重置与无结果。
4. 收藏分类、新增笔记、结束并重建 EntryAbility、修改笔记、取消/确认删除、删除墓碑与取消收藏。
5. 未保存草稿的关闭/返回、继续编辑、放弃与重新打开空草稿。
6. 空白、41 字标签、21 个标签的校验；实际输入 4001 字后存为 4000 字；20 个各 40 字标签的完整保存与磁盘回读。
7. 在新的 EntryAbility 中打开上一用例经 UI 保存的最大记录，展开/收起长正文、修改正文，再回读确认完整标签未丢失。

最后两项是两个独立超时边界的连续场景，共用专属测试库；完整默认回归会按顺序运行。单独复跑编辑场景必须提供已由准备场景实际保存的测试库，不能将缺少前置数据的运行记为通过。

### 8.3 修正与已知工具边界

- Search 是复合控件，当前 SDK 的实际编辑节点为 SearchField。第一轮用例假定输入后必有键盘、无条件按返回；在本机曾直接退出应用。现在核对实际输入、点击原生检索按钮并等待可见结果。
- Select 的原生菜单项是 Option，系统 AlertDialog 的操作文字是 Text。测试按实际节点操作，并等待导航/弹层坐标稳定；节点存在不等于可以立即点击。
- 笔记弹层增加可滚动输入区、原生键盘避让与固定关闭/保存区。保存期间锁定输入，避免等待 flush 时的新草稿被成功回调清空。
- 标签输入上限由 300 对齐到合法最大值 819，领域校验复用 20 个/40 字规则。只修正编辑容量，未改变 v1 存储格式；旧记录直接加载，未迁移或重置用户档案。
- 长笔记先显示摘要，可展开/收起；编辑/删除在笔记顶部。显示折叠不改变保存内容。
- 一次传递长文本的旧 UiTest 路径曾在 `libuitest.z.so` 中 SIGABRT，参见 [崩溃摘要](test-results/t02-uitest-crash-summary.txt)。改用 SDK 的分段追加粘贴，并以实际落盘数据核对。直接 Ctrl+V 在本机没有输入内容，相关失败运行保留。
- 旧 `inputText` 清空既有 4000 字时会逐字退格，曾使用例超时。修改场景使用原生全选/删除，核对 `0 / 4000` 后输入；不是跳过修改或只提高超时。
- `tools/device-test.ps1` 检查安装结果、源码与 HAP 时间、完整结束标记、每个 suite 的数量及 Pass/Failure/Error/Ignore，退出码 0 不能绕过失败。
- 原始 AbilityDelegator 参数键包含 `-s ` 前缀，Hypium 内部配置才去掉。最初重启分组因读取错键没有注册用例，报告为 0 项；脚本如实拒绝，修正后两阶段各 1/1 通过。没有把零用例报告作为恢复成功。

进程验证先经 UI 收藏、保存中文笔记与两个标签，再启动该专属测试档案，通过 `aa force-stop` 核实进程消失，最后用新的测试进程和 EntryAbility 回读、进入收藏详情并打开笔记编辑器核对正文与标签。未使用清库或卸载。

### 8.4 本轮复现命令

先构建两个包，再连接已有模拟器；多设备时必须指定 `-TargetId`。

```powershell
.\tools\test.ps1
.\tools\build.ps1
.\tools\build.ps1 -Target ohosTest
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -ExpectedTests 12
.\tools\restart-test.ps1 -TargetId 127.0.0.1:5555
```

`device-test.ps1` 保存所有原始输出并在缺摘要、超时、错误或数量不足时失败。它只选择真实在线设备，UI 启动只在 debug 构建接受受限 `yunheji_test_ui_*` 库名，release 使用正式档案。测试页面和窗口只存在于 ohosTest。

本轮尚未验证：下拉/遮罩退出、真实磁盘写入故障时的 UI、连续点击、整机断网、深色/大字/平板/横屏/分屏、光效帧率/功耗、真实双端同步、OpenHarmony 目标与正式文化内容。

## 9. Yi_Da 参考界面改版：2026-10-13 实测

用户指定 Yi_Da 的前端设计语言。本轮实际查看其首页、衣橱和个人页截图并阅读主题、配色、首页纸片与底纹实现，重做云河纪的原生 ArkUI 首页、目录、收藏、设备、详情和编辑弹层。设计依据见 [DESIGN.md](DESIGN.md)，真实页面见 [六页图集](design/overview.png) 和 [原始截图说明](design/README.md)。

环境保持第 1 节的手机模拟器与 HarmonyOS API 26。全过程经 HDC、Hypium/UiTest 直连模拟器；没有控制电脑桌面或以浏览器画面代替原生结果。正式用户档案与签名配置未更改。

### 9.1 最终结果与证据

| 验证 | 结果 | 原始证据 |
|---|---|---|
| 本地代码与 Repository | 37/37 通过，Failure=0 | [本地输出](test-results/2026-10-13-design-local-tests.log) |
| 设备报告解析 | 9/9 通过 | 同上 |
| 主 HAP 构建 | 成功，已安装当前模拟器 | [主包构建](test-results/2026-10-13-design-main-build.log) |
| 测试 HAP 构建 | 成功 | [测试包构建](test-results/2026-10-13-design-test-build.log) |
| ArchiveDeviceTest | **6/6**，Failure=0、Error=0、Ignore=0；5 项存储保护 + 检索/详情/空笔记/返回 | [存储与检索套件](test-results/2026-10-13-201419-device.log) |
| ArchiveUiTest | **6/6**，Failure=0、Error=0、Ignore=0；同步状态、实际卡片筛选、收藏/笔记操作、重建、草稿与最大边界 | [UI 套件](test-results/2026-10-13-201600-device.log) |
| ArchiveAppearanceTest | **1/1**，Failure=0、Error=0、Ignore=0；入口、统计、控件/纸片范围与外观切换 | [外观审查](test-results/2026-10-13-201122-device.log) |
| 人工视觉检查 | 查看当前浅色六页、深色首页/详情、1.5 倍字体首页、带键盘编辑弹层；修正统计旧值和大字溢出 | [原图与哈希](design/captures.json) |

两套功能用例使用同一对包，覆盖原有全部 12 项，分组运行共 12/12；没有将重复运行的同一用例累计成新增用例。原生操作耗时：ArchiveDeviceTest 约 100 秒，ArchiveUiTest 约 544 秒，外观审查约 131 秒。新版目录增加滚动距离，推荐按 suite 分开运行，避免全部 12 项叠加超出外部 600 秒限额；单条用例超时与断言未放宽。

对应包 SHA-256：

```text
entry-default-unsigned.hap
26C0B50CDA0D8926211EC8112726163C721B82C7434E97E87C2FB2E8F60F8E60

entry-ohosTest-unsigned.hap
3A5F89CA5DBC239890DB2DF78441F964BC276EA32AFDCF8D3A08E6FBB22A5808
```

构建仍提示未配置签名与输入控制器的系统能力覆盖范围；外观测试辅助函数有异常传播检查提示，由场景与 finally 负责报告和恢复。本机 unsigned 安装成功不代表真机签名或 OpenHarmony 兼容性已验证。

### 9.2 本轮发现与修复

- 首次 Select 使用 Text 的 `fontSize`，SDK 明确拒绝编译；改为 `font({ size })` 后构建成功。失败日志保留为 [首次构建](test-results/2026-10-13-design-build-attempt1.log)。
- 初版目录的结果数量与实际双列卡片不一致。数组参数与旧 ForEach 配对被复用后留下旧卡片；改为 `SiteGrid @Prop`，行 key 同时含左右条目，新增真实可见卡片断言。最终组合筛选显示二里头，排除目录中的仰韶与郑州商城。
- 原返回用例假设搜索框在首屏，改版保留滚动位置后该断言失败。测试先确认目录容器，再滚到真实 SearchField；启动也不再用搜索框是否可见作为档案加载标志。
- 初版改版全量运行中，返回断言失败，后续又触发外部总超时，原始 [195209-device.log](test-results/2026-10-13-195209-device.log) 保留为失败/不完整运行，未改称通过。
- 首次外观审查自动化 1/1 后，人工查看发现收藏统计仍为旧数字、大字纸片的内容超出背景、底栏文字空间不足。该 [200357-device.log](test-results/2026-10-13-200357-device.log) 不作为最终视觉验收；随后统计/状态改成可观察组件，背景依据真实内容测量，页签按 fp/vp 留空间，新增统计与纸片范围断言并复跑。
- 最终外观截图中收藏、笔记与浏览数均为经真实 UI 保存的 1；放大字体下文字处于纸片背景内，编辑弹层打开键盘后保存、关闭可见。截图由应用当前实际状态取得，图集只缩放与排列，没有补画页面。

### 9.3 复现与范围

```powershell
.\tools\test.ps1
.\tools\build.ps1
.\tools\build.ps1 -Target ohosTest
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass ArchiveDeviceTest -ExpectedTests 6
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass ArchiveUiTest -ExpectedTests 6 -SkipInstall
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass ArchiveAppearanceTest -ExpectedTests 1 -SkipInstall
```

外观场景只在显式 class 时注册，使用独立测试 Preferences，最后恢复应用字体倍率与跟随系统的外观配置。没有修改系统全局设置，未清空正式 `yunheji_archive_v1`。

视觉验收仅覆盖当前手机窗口、浅/深色以及 1.5 倍应用字体；不代表任意字体倍率、360vp 固定规格、横屏、平板或分屏都已通过。截图不能证明触摸光效、帧率或功耗。

本轮未复跑进程强停两阶段，上轮对应旧包的真实证据仍在第 8 节；当前包验证了 EntryAbility 结束/重建，二者不能等同。下拉/遮罩退出、写入故障时的 UI、连续点击、整机断网、其他窗口、真机光效、真实双端同步与比赛 OpenHarmony 目标仍待验证。文化内容仍为五条初稿待校审，插画仍标注主题示意。

## 10. 原生沉浸光感顶部与 Dock：2026-10-14 实测

用户要求顶部与底部 Dock 参考 Yi_Da 的鸿蒙原生沉浸光感案例。参考工程保持只读，本轮改动限定于原生导航、材质适配、日夜着色资源和设备回归，正文设计与 v1 数据格式保持既有版本。

### 10.1 最终构建与功能回归

| 验证 | 结果 | 原始证据 |
|---|---|---|
| 本地代码与 Repository | 37/37，通过 37、失败 0 | [本地输出](test-results/2026-10-14-immersive-local-tests.log) |
| 设备报告解析 | 9/9 通过 | 同上 |
| 主 HAP 构建 | 成功，已安装本机模拟器 | [主包构建](test-results/2026-10-14-immersive-main-build.log) |
| 最终测试 HAP 构建 | 成功，包含滚动稳定性与专项采图 / 开关操作修正 | [测试包构建](test-results/2026-10-14-immersive-test-build.log) |
| ArchiveDeviceTest | **6/6**；五项真实存储保护，另有检索、详情、空笔记和返回 | [存储 / 检索组](test-results/2026-10-14-132006-device.log) |
| ArchiveUiTest 通用四项 | **4/4**；同步未接入、组合筛选、收藏 / 笔记 CRUD 和 Ability 重建、草稿退出 | [通用 UI 组](test-results/2026-10-14-132122-device.log) |
| ArchiveUiTest 最大长度两项 | **2/2**；实际输入 4001 字后保存 4000 字、20 个各 40 字标签，展开 / 收起与再次编辑后回读完整 | [最大长度组](test-results/2026-10-14-132624-device.log) |
| ArchiveImmersiveTest | **2/2**；顶部收藏、页签、开关真实状态与落盘、日夜、大字、详情返回、正确页尾采图 | [最终原生专项](test-results/2026-10-14-134918-device.log) |
| 实际设备能力 | HDS `types=[101]`（IMMERSIVE），底层 `uiMaterial=true` | [原始能力输出](test-results/2026-10-14-immersive-capability.log) |
| 人工视觉检查 | 查看全部 9 张最终原图；确认滚动模糊、日夜文字、顶部 / Dock 范围、大字、页尾净空与关闭后的基础底色 | [截图清单与哈希](design/immersive/captures.json)、[比较图](design/immersive/overview.png) |

三组功能使用同一主包与功能测试包，覆盖既有全部 **12 项，Failure=0、Error=0、Ignore=0**。随后仅修改 `ArchiveImmersive.test.ets` 的采图场景与原生开关触摸 / 等待条件，最终专项另有 **2/2，Failure=0、Error=0、Ignore=0**；主应用、既有功能测试和共用定位助手未再改变。单独筛选复验和专项重试没有累计为新增用例。设备环境为第 1 节的 HarmonyOS API 26 手机模拟器。

对应包 SHA-256：

```text
entry-default-unsigned.hap
FC41940FEBD00BCEDA22F9D357C4DAAA181F03FD1531D1688751C3E9984BE9F9

entry-ohosTest-unsigned.hap（12 项功能回归）
9073A6778AB4DD2B951E856E7755D4FB5D13AB5EFFED70F70D39C52899585E41

entry-ohosTest-unsigned.hap（最终构建、2 项原生导航专项与全部最终截图）
3310CAE993F6D53E73C9A3B40310E3D9D61B21F0FD555A14EB50062296BB7B9B
```

主包在最终功能回归与原生导航专项之间没有变化。`113957` 与 `130550` 使用较早测试包 `DB14F1239B22E2B37AC4EE0E627393C21461373C14525D718AB8536401C14BD1`，`110252` 阶段性专项使用测试包 `6F847A7A450C4C3056ED41E7E6914C33280D1F14B4328078991A85134F2408F8`；它们保留为排查过程，不替代上表的最终包结果。

构建仍有输入控制器系统能力覆盖、未配置签名和设备测试辅助函数异常传播提示。当前模拟器可安装 unsigned 包，不能据此宣布真机安装、低版本兼容或所有设备能力通过。

### 10.2 原生接入与降级

顶部由 `HdsNavigation.titleBar` 承载，使用官方 `systemMaterialEffect` 与 `IMMERSIVE_GRADIENT_BLUR`，绑定河迹、记忆、档案三个真实 Scroller。品牌和收藏胶囊在官方标题栏内使用 `uiMaterial.ImmersiveMaterial`，底色透明，材质按日夜语义色着色。状态栏文字从实际颜色资源取得，避免浅色背景白字。

底部由 `HdsTabs`、`BottomTabBarStyle` 和 `barFloatingStyle` 提供整条原生悬浮胶囊、页签与选中反馈。三个旧自绘页签已经移除，原稳定 ID、快捷入口和页签状态继续使用；浮动栏采用官方自适应宽度，正文预留随字号增长的顶部与底部净空。

HDS 能力查询与材质选择集中在 `platform/HarmonyEffects.ets`：支持时使用 `IMMERSIVE`，强度用 `ADAPTIVE` 随系统；否则由系统自适应材质接管。关闭光感或开启减少动态时使用 `NONE`，停止标题栏滚动材质与切页动画，标题胶囊回退到语义底色。HDS 没有单独关闭触点形变的公开选项，因此减少动态需要关闭这一层材质。

接口与最小版本依据为本机 SDK 26.0.0.105 的类型声明，详细核查见 [技术报告第 9 节](HARMONY_RESEARCH.md)。HarmonyOS API 26 的接入不等于比赛 OpenHarmony API 12 兼容。

### 10.3 测试修正与保留记录

- 浮动栏覆盖部分内容，UiTest 默认滚动起点会落进 Dock；`scrollSearch` 按实际标题 / 页签范围设置 offset，真实手势在无遮挡区内执行。
- 部分可见卡片的中心仍可能落在 Dock 后面，找到节点不能证明可点击。定位辅助方法先把目标中心滚入无遮挡区，再执行真实点击。
- 首次曝光修正采用整屏手势，未等惯性滚动停止便读取坐标；组合筛选组出现 `UI_SCROLL_TARGET_COVERED_BY_NATIVE_BAR`。最终辅助方法每次取稳定的新节点，按中心差小步滚动，并在最后一次手势后再次检查。单独复验 [131813-device.log](test-results/2026-10-14-131813-device.log) 为 1/1。
- 开关手势返回早于 Preferences flush；专项等控件重新稳定且可用，再清缓存回读实际落盘。没有注入假数据或放宽保存断言。
- 人工检查 [132932-device.log](test-results/2026-10-14-132932-device.log) 的 2/2 输出后，发现其“页尾”截图误切到了记忆页。默认 `scrollToBottom` 手势仍会落入 Dock；最终专项定位实际页尾文字、核对当前河迹容器，并使用无遮挡手势返回标题。误切页图与当时清单保留在被忽略的 `entry/build/test-evidence/immersive/132932-captures/`，不作为最终图集。
- 随后 [133609-device.log](test-results/2026-10-14-133609-device.log) 为 1/2，重新开启光感后实际仍关闭；[134414-device.log](test-results/2026-10-14-134414-device.log) 为 1/2，新增 checked 条件后明确检出组件中心点击没有翻转开关。最终使用真实稳定 bounds 内的滑块中心执行一次 `Driver.click`，等待原生 `checked` 翻转且保存锁释放，再读真实磁盘；所有四次开关变化与落盘均在最终专项通过。此调整只在 ohosTest 中，不修改应用偏好或注入值。
- 原生浮动栏曾用百分比宽度，当前 SDK 的材质底板发生偏移；撤回该参数，使用官方三入口自适应宽度。
- `104503`、`105410` 为专项失败，`110817` 为部分卡片点击失败，`130902` 为组合筛选定位失败，均保留原始结果。`110252` 的阶段性专项 2/2 使用较早测试辅助代码，最终包另行验证。
- `112707` 因模拟器重启后锁屏触发总超时；`114155` 在长文本回归中断连，缺少完整结束摘要。两者都不能算通过，本轮未确认断连原因。10 月 13 日既有 UiTest 原生崩溃记录不能作为本轮 HDS 崩溃证据。

全过程仅通过 HDC / Hypium / 模拟器命令行直连已授权的手机模拟器，没有控制电脑桌面。独立测试库与应用外观配置在场景结束时清理 / 恢复；长测试临时覆盖设备熄屏时间，命令结束在 finally 恢复。正式用户档案、墓碑和签名未更改。

### 10.4 本轮复现与范围

```powershell
.\tools\test.ps1
.\tools\build.ps1
.\tools\build.ps1 -Target ohosTest
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass ArchiveDeviceTest -ExpectedTests 6
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass 'ArchiveUiTest#native_sync_panel_reports_unavailable,ArchiveUiTest#native_combined_filters_and_reset,ArchiveUiTest#native_favorite_note_crud_and_ability_restart,ArchiveUiTest#native_unsaved_draft_close_back_and_keep_editing' -ExpectedTests 4 -SkipInstall
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass 'ArchiveUiTest#native_maximum_note_and_tags_are_saved,ArchiveUiTest#native_maximum_tags_survive_edit_and_expansion' -ExpectedTests 2 -SkipInstall
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass ArchiveImmersiveTest -ExpectedTests 2 -SkipInstall
```

先确认模拟器在线且解锁。分组完整覆盖既有 12 项功能，并单列 2 项原生导航专项；最大长度的两项按准备 / 编辑顺序在同次调用运行，不将缺前置数据或零用例记为通过。每次需核对报告的 Pass / Failure / Error / Ignore 和结束摘要。

截图由当前原生 ArkUI 窗口采集，静态图可检查悬浮形态、滚动模糊、日夜对比度与大字范围。真机触点光效的动态性能与功耗、横屏、平板、分屏、其他字体倍率和无 IMMERSIVE 能力设备仍需另行验证；本轮没有复跑进程强停两阶段。真实同步继续显示“尚未接入”，文化内容保持“初稿待校审”。

## 11. 文明连线与个人专题：2026-10-14 实测

本轮按用户“精美演示、可见创新优先”的要求实现五城图谱、双档案对照和个人专题。沿用既有 HarmonyOS 7 / API 26 工程、HDS 导航、正式数据格式和详情/笔记流程；未新增跨端传输或伪造同步状态。

### 11.1 最终结果

| 验证 | 结果 | 原始证据 |
|---|---|---|
| 本地代码与 Repository | **40/40**，失败 0；增加 3 项关联/个人专题规则测试 | [本地输出](test-results/2026-10-14-culture-local-tests.log) |
| 设备报告解析 | **9/9** | 同上 |
| 主 HAP 构建 | 成功，已安装当前模拟器 | [主包构建](test-results/2026-10-14-culture-main-build.log) |
| 最终测试 HAP 构建 | 成功，包含外观切换时序及实际资源/字体断言 | [测试包构建](test-results/2026-10-14-culture-test-build.log) |
| CultureAtlasTest | **2/2**，Failure=0、Error=0、Ignore=0；约 114 秒 | [最终设备报告](test-results/2026-10-14-175431-device.log) |
| 人工视觉检查 | 7 张原图已查看：入口、图谱、普通/个人对照、个人观察、深色、1.5 倍字体 | [原图与说明](design/culture/README.md)、[哈希清单](design/culture/captures.json) |

设备环境与第 1 节相同。两个最终包 SHA-256：

```text
entry-default-unsigned.hap
322505022BD558E3625BB6EAB865C5E9BFB12DA4DBFC328743E18DC9B61916E5

entry-ohosTest-unsigned.hap
7DD06708BFFFC0FEAE066CD4F773481B61C703C9EFEE1B42BBB98BE0E1347160
```

构建保留未配置签名与既有测试辅助函数异常传播提示。当前模拟器安装成功不代表真机签名和任意设备能力已验证。

### 11.2 实际路径与修正

第一项用例经真实 UI 进入图谱、选择仰韶/二里头、打开郑州商城对照并核对共同年代；继续进入原有详情，收藏二里头并写笔记，在郑州商城也写一条“都城研学”笔记。清除 Preferences 缓存后回读实际记录，再切“我的图谱”筛选该专题，核对 **2 处档案、1 条关联线索**，以及个人对照中的“我的专题：都城研学”。

第二项在窗口启动后切换深色，核对实际 `canvas` 资源为深色值后采图；再重建 EntryAbility，核对真实 1.5 倍字体及两侧节点在屏幕范围内且不重叠。图片人工检查发现文字可换行、节点高度增加，下方内容仍通过 Scroll 阅读。未宣称全部字号、横屏或平板已验收。

视觉收尾修正了节点的显式边框圆角、对照 Sheet 顶端对齐与语义背景；节点 key 纳入数量和索引，避免个人专题复用五城布局的旧位置。关联规则只取活跃收藏/笔记，不把删除记录或阅读访问当作个人专题；笔记删除后标签连线消失由本地规则测试覆盖。

### 11.3 保留的失败与中断

- [171830-device.log](test-results/2026-10-14-171830-device.log) 为早期版本的 2/2，后续仍修正了圆角、对照留白、个人图谱位置及演示的第二条笔记，不以此替代最终版本。
- [174205-device.log](test-results/2026-10-14-174205-device.log) 第一项通过，第二项开始后没有完整结束报告，最终总超时；**不是 2/2 通过**。同一时间段模拟器 `render_service` 有 SIGSEGV 原始崩溃日志，应用/UiTest 进程已不在；[崩溃摘要](test-results/culture-render-service-crash-summary.md)保留时间与栈范围。尚未确认触发原因，不能据此认定 Canvas、HDS 或应用是根因，也不能保证不会复现。
- 中断前的 `dark` 截图实际为浅色：EntryAbility 启动时恢复跟随系统，覆盖了启动前的测试设置。旧图保留在 `design/culture/initial/dark-before-timing-fix.png`。最终测试改为窗口就绪后切换，并断言实际颜色资源；没有修改应用外观逻辑。
- [首次修正构建](test-results/2026-10-14-culture-build-attempt1.log)因通用 `Context` 没有 `config` 字段失败，改为读取真实顶层 UIAbility 的字体配置后构建成功，未放宽断言。
- 最终复跑前仅通过 HDC 唤醒并解锁模拟器，临时覆盖设备熄屏时间，命令结束在 finally 恢复；未控制电脑桌面或修改电脑电源设置。

### 11.4 复现与边界

```powershell
.\tools\test.ps1
.\tools\build.ps1
.\tools\build.ps1 -Target ohosTest
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass CultureAtlasTest -ExpectedTests 2
```

先确认设备在线且解锁。专项只在显式选择 `CultureAtlasTest` 时注册，默认功能套件数量不变；使用独立 `yunheji_test_ui_*` 库，不清理或预填正式档案。结束后删除测试库并恢复应用字体与跟随系统外观。所有截图来自原生窗口，图集仅等比缩放和排列。

本轮没有复跑旧的 12 项全量回归或进程强停两阶段，也没有验证真实双端传输、实机动态光效、功耗、横屏、平板或分屏。图谱是属性/个人标签关联示意，不是历史因果或完整知识库；文化内容仍为五条初稿、插画仍为主题示意。现场操作见 [90 秒演示路径](DEMO.md)。

## 12. 独立账号与双设备网络同步：2026-10-14 实测

用户允许在没有华为开发者应用记录的情况下先用独立登录方案跑通，并创建第二台模拟器。本轮实现原生账号 UI、自建 HTTPS / SQLite 服务和真实双端交换；沿用 Yi_Da 的配色与 HDS 导航。当前结果是同账号个人数据的网络同步，华为账号授权、鸿蒙分布式数据库和可信设备组网尚未接入。

### 12.1 环境、构建与本地测试

设备 A 为既有 Pura 90 Pro（HDC `127.0.0.1:5555`），B 为本轮新建 YunhejiSyncB（`127.0.0.1:5557`）。两者均为 HarmonyOS 7.0.0.107 / API 26、1256×2760、density 560；B 为 4GB 配置，保留了调整前的配置备份。通过 HDC / Hypium / 模拟器 CLI 直连，不控制电脑桌面。工具 / SDK、包名和 unsigned 安装方式沿用第 1 节。

账号服务以 Node.js 24.14.1 在本机回环地址监听 HTTPS 18443，两台设备使用各自 reverse port。原生客户端信任本任务公开 TLS 证书，保持主机名 / 证书校验；没有关闭验证。服务端数据库、私钥及随机测试凭证都位于忽略目录。

| 验证 | 结果 | 原始证据 |
|---|---|---|
| 本地代码 / Repository | **43/43**，失败 0；含账号响应、输入与库名隔离规则 | [本地输出](test-results/2026-10-14-account-local-tests.log) |
| 设备报告解析 | **9/9** | 同上 |
| 真实 HTTPS / SQLite 服务综合 | **1/1**；错误密码、账号隔离、在线统计、版本合并、离线旧值、墓碑、冲突、注销失效与持久化 / 哈希存储 | [服务测试](test-results/2026-10-14-account-service-tests.log) |
| 主 HAP | 构建成功；下方全部实测主包不变 | [主包构建](test-results/2026-10-14-account-main-build.log) |
| 双端测试 HAP | 构建成功；运行 8 个账号场景、两端清理及存储组 | [初次最终测试包](test-results/2026-10-14-account-test-build.log) |
| 跟进测试 HAP | 仅更新旧未登录状态检查及离线注释，构建成功；运行未登录与文明连线复验 | [跟进测试包](test-results/2026-10-14-account-test-build-final.log) |

对应 SHA-256：

```text
entry-default-unsigned.hap（全部本轮设备验证）
54F5003C8C5EBEC7E9C3FDC7E405221233D818F62B682AA8AE01A63CBD5DCEF3

entry-ohosTest-unsigned.hap（双端账号、清理、存储组与账号截图）
864616965178985C2CA067BBE4A556C49ED03D47FA4D315BDBA769CEC70C2D8A

entry-ohosTest-unsigned.hap（当前跟进测试包：未登录与文明连线）
266CB9221471B993677F076CFB84DEA1CA75CC90FA6B0B57E64E77E3D4FDA8BD
```

构建仍有无签名配置、输入控制器系统能力覆盖与测试辅助函数异常传播提示。Node 内置 SQLite 当前有实验性接口提示。本机模拟器安装 unsigned 包成功，不能据此宣称正式真机签名或任意设备能力已验证。

### 12.2 同一轮真实双端路径

以下使用全新随机测试账号按两设备顺序执行，每个原始报告均为 **Tests run: 1, Failure: 0, Error: 0, Pass: 1, Ignore: 0** 且有完整结束标记。

| 阶段 | 实际验证 | 设备报告 |
|---|---|---|
| 1 · A | 空白账号入口、实际深色资源、1.5 倍字体与按钮范围 | [205206](test-results/2026-10-14-205206-device.log) |
| 2 · A | 经 UI 注册；游客浏览记录不进入新账号；收藏、中文笔记 / 标签真实落盘，退出回读游客记录 | [205236](test-results/2026-10-14-205236-device.log) |
| 3 · B | 同账号登录，接收 A 的收藏 / 笔记 / 浏览记录；UI 统计为 1 / 1 / 1，并在原生编辑器修改笔记 | [205531](test-results/2026-10-14-205531-device.log) |
| 4 · A | 收到 B 修改与原标签；退出恢复游客库；另一个账号经 UI 注册后本机 / 远端档案为空且隔离 | [205652](test-results/2026-10-14-205652-device.log) |
| 5 · B | 停止本任务服务；已登录窗口经 UI 保存离线修改，清 Preferences 缓存后读取实际磁盘 | [205913](test-results/2026-10-14-205913-device.log) |
| 6 · B | 恢复同一服务后重新登录，上传未交换的本机修改并得到真实同步成功反馈 | [210053](test-results/2026-10-14-210053-device.log) |
| 7 · A | 接收 B 的离线正文；经原生确认删除，回读本机删除墓碑 | [210129](test-results/2026-10-14-210129-device.log) |
| 8 · B | 收到墓碑，旧笔记不复活；实际 UI 笔记数为 0，收藏 / 浏览保留 | [210250](test-results/2026-10-14-210250-device.log) |

账号 / 双端场景共 **8/8**。后续 A / B 各 **1/1** 清理，仅删除本轮已知的独立测试 Preferences：[A 清理](test-results/2026-10-14-210327-device.log)、[B 清理](test-results/2026-10-14-210334-device.log)。两项清理与 8 项功能场景分开计数，重试不累计为新场景。

[汇总输出](test-results/2026-10-14-account-dual-device.log)保留阶段执行顺序、服务暂停 / 恢复和两端熄屏设置恢复。脚本旧版的阶段索引曾误选该汇总文件，最终已按每份原始日志的用例名、摘要与结束标记重新核对并生成 [正确阶段清单](test-results/2026-10-14-account-phases.json)，未靠旧索引推断通过。

离线用例停止的是本任务账号服务，结束后恢复同一 SQLite 数据库与 TLS 证书，影响两设备到该服务的连接。它验证服务不可达时的已登录本机保存与恢复交换，不是整机断网、离线登录或离线冷启动测试。

### 12.3 当前主包的原有路径复验与图片

| 验证 | 结果 | 原始证据 |
|---|---|---|
| ArchiveDeviceTest | **6/6**；实际 Preferences 往返、损坏 / 既有非法值 / 孤立备份保护、串行保存、搜索 / 详情 / 空笔记 / 返回 | [211551](test-results/2026-10-14-211551-device.log) |
| ArchiveUiTest 未登录状态 | **1/1**；登录入口存在，未显示登录后成功状态；滚到真实连接区核对无设备数或成功时间 | [212839](test-results/2026-10-14-212839-device.log) |
| CultureAtlasTest | **2/2**；节点 / 对照、两处真实笔记 / 个人专题、实际深色与 1.5 倍字体 | [212921](test-results/2026-10-14-212921-device.log) |
| 账号人工视觉检查 | 10 张原图逐张查看；浅 / 深色、大字、另一端接收、修改、离线重连与删除 | [账号图集](design/account/README.md)、[原图哈希](design/account/captures.json) |

三组设备报告 Failure/Error/Ignore 均为 0，覆盖明确列出的当前主包路径。未重跑旧的完整 12 项、原生导航专项或进程强停两阶段，不沿用旧包结果宣称本轮全量通过。

账号截图字段为空，笔记为合成示例，未包括账号、密码、token 或正式私人记录。图集只等比缩放和排列，原始页面像素未补画。截图不能证明传输延迟、动态帧率或功耗；传输 / 落盘依靠对应真实 UI 操作与回读断言。

### 12.4 修复与保留的失败

- [首次构建](test-results/2026-10-14-account-build-attempt1.log)因 ArkTS 不支持对象展开失败，改为显式发布完整账号状态。
- [194316](test-results/2026-10-14-194316-device.log)读取测试 rawfile 的模块范围错误；之后显式通过 `createModuleContext(..., 'entry_test')` 读取，随机凭证没有移入主包。
- `194929`、`200450`、`201315`、`201854` 是 B 端首次输入法向导遮挡后的节点定位失败。部分早期主错误又被退出清理覆盖，已改为保留主断言错误并单独记录清理问题；系统向导按基本模式完成后 B 的真实接收 / 编辑在最终轮次通过。
- [195258](test-results/2026-10-14-195258-device.log)缺少完整结束摘要，期间 B 的测试 / 应用进程丢失且锁屏，不能记为通过；未将进程丢失原因归结为应用根因。B 原配置曾有可用内存低提示，保留配置后调整到 4GB。
- [202519](test-results/2026-10-14-202519-device.log)在第二账号注册后，标题已在屏幕外，旧等待失败；改为滚到实际账号标题，最终 205652 完成账号隔离场景。
- [首次汇总尝试](test-results/2026-10-14-account-dual-attempt1.log)因配置属性顺序改变而更新资源时间戳，设备脚本正确拒绝过期包；启动脚本改为按 JSON 语义比较，同配置重启不再改资源时间。
- [204855](test-results/2026-10-14-204855-device.log)及[第二次汇总尝试](test-results/2026-10-14-account-dual-attempt2.log)在外观场景中 HDC 断连，缺少完整摘要。模拟器进程仍存在，连接随后恢复；未确认断连根因，不计为通过。
- [211712](test-results/2026-10-14-211712-device.log)为 **0/1、Error=1**：旧未登录状态用例仍查找接入前文案，且没有滚到新增登录卡片下方状态区。随后仅更新测试定位与文案前提，保留“未登录不得显示同步成功”的断言，212839 为最终 1/1。
- `194631`、`202322` 为阶段性 1/1，验证较早包和测试前提，保留但不替代本节同一轮 8 个场景的最终结果。

所有失败、阶段性通过与不完整报告保留在 `test-results/`，没有改称通过。设备日志不记录密码 / token / 正文请求；服务日志仅记录服务启动与错误类别。

### 12.5 复现与当前限制

```powershell
.\tools\start-account-server.ps1 -TargetIds @('127.0.0.1:5555','127.0.0.1:5557')
.\tools\test.ps1
& '<DevEco目录>\tools\node\node.exe' --experimental-strip-types --test server/account-service.test.mjs
.\tools\account-test.ps1 -DeviceA 127.0.0.1:5555 -DeviceB 127.0.0.1:5557
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass ArchiveDeviceTest -ExpectedTests 6 -SkipInstall
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass 'ArchiveUiTest#native_sync_panel_reports_unavailable' -ExpectedTests 1 -SkipInstall
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass CultureAtlasTest -ExpectedTests 2 -SkipInstall
```

先确认两个不同设备在线且解锁。`account-test.ps1` 默认生成新随机账号并构建两包，按两端前后依赖运行，不可直接运行完整 AccountSyncTest suite。随机凭证只在忽略的测试资源与本机文件，清理不枚举正式账号库。长测试在 finally 恢复熄屏覆盖，外观场景恢复应用字体与颜色模式。

收尾两台应用按无测试库参数正常启动，账号服务 `/health` 返回本任务标识，两端 HDC 在线。重复调用熄屏恢复命令曾返回失败，随后直接回读电源服务，确认两台的 `ScreenOffTime: Timeout=30000ms`，已没有测试用 20 / 30 分钟覆盖；[收尾原始状态](test-results/2026-10-14-account-ready.log)保留实际返回值，不以重复恢复命令推断状态。

当前账号档案与游客档案分库，schema v1、字段、墓碑和保存流程不变，无格式迁移。会话仅在进程内，进程退出后需重新登录；离线已登录窗口可保存，但离线冷启动会话恢复未实现。前台每 5 秒自动交换，未做专门延迟测量或承诺 3 秒以内。材质 / 减少动态偏好留在本机，阅读状态仅 `opened`。服务端已保留冲突版本，用户查看 / 恢复页面待实现。

当前是 debug 本机服务，正式公网部署 / release 服务配置未交付，发布前需移除开发 rawfile 并接入正式配置。完整阅读进度、正式内容 / 图片授权、实机签名、平板 / 分屏 / 横屏与真机光效性能仍未验收；五条文化内容继续初稿待校审。运行实现与 API 依据见 [ACCOUNT_SYNC.md](ACCOUNT_SYNC.md)，现场路径见 [DEMO.md](DEMO.md)。

## 13. 独立启动登录与“我的”：2026-10-16 实测

按用户要求拆分档案与个人页，新增独立启动登录 / 注册页，以及在三项 Dock 右侧独立显示的原生“我的”入口。大学、学号为教育计划选填占位，只在本次成功登录后展示，不保存、上传、参与认证或生成计划。

### 13.1 最终结果与包版本

设备为 YunhejiSyncB，HarmonyOS 7.0.0.107 / API 26，1256×2760、density 560；SDK 与工具沿用既有工程。过程中模拟器中断后保留数据恢复启动，HDC 地址从 `127.0.0.1:5557` 变为 `127.0.0.1:5555`，最终三组报告均在恢复后的同一实例运行。全程使用 HDC / Hypium / 模拟器 CLI，没有控制电脑桌面。

| 验证 | 结果 | 原始证据 |
|---|---|---|
| 本地规则与 Repository | **43/43**，失败 0；本轮没有修改领域规则或存储格式 | [本地输出](test-results/2026-10-16-profile-local-tests.log) |
| 设备报告解析 | **9/9** | 同上 |
| 主包构建 | 成功，已安装模拟器 | [最终主包](test-results/2026-10-16-profile-main-build-stable.log) |
| 测试包构建 | 成功 | [最终测试包](test-results/2026-10-16-profile-test-build-stable.log) |
| ProfileLoginTest | **4/4**；约 232 秒，启动页 / 选填 / 失败停留、独立入口 / 页面拆分 / 偏好保存、深色 / 大字、真实注册 / 退出 / 错误密码 / 再登录 | [172404](test-results/2026-10-16-172404-device.log) |
| ArchiveDeviceTest | **6/6**；真实 Preferences 往返、串行保存、非法 / 损坏 / 孤立备份保护、检索 / 详情 / 空笔记 / 返回 | [172759](test-results/2026-10-16-172759-device.log) |
| ArchiveUiTest 选定两项 | **2/2**；未登录状态在个人页、收藏分类与笔记增改删、删除墓碑与 Ability 重建 | [172906](test-results/2026-10-16-172906-device.log) |
| 人工视觉检查 | 12 张原图已查看，含浅 / 深色、大字、档案、个人页、设置与教育占位 | [真实图集](design/profile/README.md)、[原图哈希](design/profile/captures.json) |

三组最终设备报告均为 Failure=0、Error=0、Ignore=0，逐条索引见 [阶段清单](test-results/2026-10-16-profile-phases.json)。不累计重复运行作为新增用例，未将旧包的双端或完整 12 项历史回归算作当前包结果。

```text
entry-default-unsigned.hap
51C89E54C812EB7AEEE4E25F3C421C348A86F856DD0AFCC944BEBC40C49B4E1A

entry-ohosTest-unsigned.hap
0CCA2B756A9180A75CB155D92FD76A7B95638399769E3AE14589CCE823D53741
```

构建保留未签名、输入控制器系统能力覆盖与测试辅助函数异常传播提示；本机 unsigned 安装成功不代表正式真机签名或所有设备能力通过。

### 13.2 实际操作与数据断言

启动时断言登录页存在、主内容 / Dock 不存在；展开大学 / 学号并确认空值，提交空账号仍停在登录页。离线浏览也必须通过真实按钮进入。独立入口以实际 bounds 核对处于第三页签右侧、与其分开且在屏幕内，没有 `tab-3`；大字时还核对标签范围处于原生入口内。

档案页不再包含账号卡片或偏好开关；从其右下角进入个人页，可读到教育计划占位、真实同步状态与阅读偏好。原生开关变更后清除 Preferences 缓存回读实际落盘，返回仍处于原档案页；从个人页的登录操作再次进入独立启动表单。

真实账号场景通过 UI 生成随机独立账号，填写合成大学 / 学号并注册，进入详情收藏。个人页只展示学号已填写；实际账号快照含收藏，且不含教育资料。退出回到登录页，未登录档案与退出前一致。错误密码由真实服务拒绝，主内容仍未出现；再用正确密码登录，收藏恢复，未重新填写的教育字段为空。学校 / 学号不进入认证请求或持久化。

深色场景断言真实颜色资源，再采登录 / 首页 / 个人页；大字场景实际设为 1.5 倍并重建 Ability，表单和正文可滚动，提交按钮处于横向边界内。12 张原图仅空表单与本机模式，真实账号流程不采身份截图。图集只等比缩放 / 排列，不补画页面。

schema v1、游客 / 账号库规则、统一记录和删除墓碑不变，无格式迁移、清空正式档案或预填演示数据。成功场景结束后清理本轮独立库并恢复应用外观 / 字号，长回归在 finally 恢复熄屏覆盖。

### 13.3 保留的失败与修正

- [163444](test-results/2026-10-16-163444-device.log)为早期页面专项 **3/3**，人工看图仍发现大字“我的”图标 / 标签挤满固定圆形入口。之后改为 vp 图标与导航文字缩放上限，并增加标签在入口范围内的断言；不以早期 3/3 替代最终视觉结果。
- [164013](test-results/2026-10-16-164013-device.log)为 **3/4、Error=1**，真实注册在软键盘展开后未找到下方选填操作。测试改为输入后通过真实返回收起键盘再滚动，没有注入注册结果。较早包的账号路径随后 [170405](test-results/2026-10-16-170405-device.log) **1/1**，最终包另由 172404 完整验证。
- [164619](test-results/2026-10-16-164619-device.log)没有完整结束摘要。第二项有开关等待失败，第三项通过，第四项开始后 HDC 中断；随后查不到在线模拟器。没有确认中断根因，不把该运行算作通过；使用 CLI 保留数据恢复启动，没有通过其他手段绕过用户停止操作。
- [170628](test-results/2026-10-16-170628-device.log)为 **2/3、Error=1**，开关点按后 checked=false 没有出现。测试补充个人页完整可见区域处理，并改用原生拖动手势核对状态 / 落盘；[171434](test-results/2026-10-16-171434-device.log)隔离场景 **1/1**。
- [171743](test-results/2026-10-16-171743-device.log)仍为 **2/3、Error=1**，开关 checked 条件出现后未稳定。个人页对保存中 / 相同值回调加入防重保护，避免共享状态回写导致重复提交；最终连续四项在 172404 全部通过。没有将隔离重试直接当作连续场景已通过。
- 调整过程中所有构建日志保留。失败诊断图 / 布局及最初大字截图在忽略的 `entry/build/test-evidence/profile/`，最终图集只使用 172404 对应原图。

### 13.4 复现与未验证范围

```powershell
.\tools\start-account-server.ps1 -TargetIds @('127.0.0.1:5555')
.\tools\test.ps1
.\tools\build.ps1
.\tools\build.ps1 -Target ohosTest
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass ProfileLoginTest -ExpectedTests 4
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass ArchiveDeviceTest -ExpectedTests 6 -SkipInstall
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass 'ArchiveUiTest#native_sync_panel_reports_unavailable,ArchiveUiTest#native_favorite_note_crud_and_ability_restart' -ExpectedTests 2 -SkipInstall
```

先按 `hdc list targets` 核对实际地址。账号专项需要本机 HTTPS 服务；前三项页面 / 外观路径仍可离线验证。教育资料不是实际教育计划或学籍认证；会话仍只在进程内，重启需重新登录。正式服务 / release 配置、华为账号 / 分布式数据库边界沿用第 12 节。

本轮没有重跑旧双端 8 场景、全量长度 / 草稿边界、进程强停、文明连线或原生导航全部专项，也未验证横屏 / 平板 / 分屏、任意字体倍率与真机动态性能。文化内容仍为初稿待校审。新页面行为见 [LOGIN_PROFILE.md](LOGIN_PROFILE.md)。

## 14. 五城内容扩充与离线交互图谱：2026-10-16 实测

按 [下一轮开发任务书](DEV_GUIDE_NEXT.md) 实施优先级 1 与 2：由 5 条扩充到 15 条初稿，文明连线采用包内 ArkWeb 交互画布、力导向布局、节点拖动、高亮与原生档案索引。首页可选改版、阅读进度、备份恢复不计入本轮完成范围。用户另行明确允许必要的内容数量与图谱测试适配，既有业务断言保留。

### 14.1 最终结果与对应包

设备为 YunhejiSyncB，HarmonyOS 7.0.0.107 / API 26，1256×2760、density 560，HDC 为 `127.0.0.1:5555`。全程使用 HDC / Hypium / 模拟器命令行，未控制电脑桌面。主包与测试包均构建成功，当前设备包 SHA-256：

```text
entry-default-unsigned.hap
25BF1EAD4F3136C751C7F6F701BD21D82D2250E34A5E7AAF562A219EA7D31D39

测试包：四项新增内容与画布专项
86191DAA298FA819CD1B7139970478CA68CD77D237F9C441952CCC2DF2295B53

测试包：旧图谱滚动适配后的两项回归
1DC37641796007416CB27D690541C7C1F602F59B82849BDE39976C2B8DC780B5

测试包：筛选可见性与精确条目助手适配后的两组回归
B66A0414152296A0AF5E9DC698083A89FF78541604936A747DB07EB06C294376
```

| 验证 | 结果 | 原始证据 |
|---|---|---|
| 本地规则与 Repository | **48/48**；失败 0 | [本地输出](test-results/2026-10-16-graph-local-tests.log) |
| 设备报告解析 | **9/9** | 同上 |
| 主 HAP 构建 | 成功；同一主包覆盖以下七组 | [主包构建](test-results/2026-10-16-graph-build-attempt2.log) |
| 测试 HAP 构建 | 三版成功，分别绑定场景 | [新增专项版](test-results/2026-10-16-graph-test-build-attempt4.log)、[图谱适配版](test-results/2026-10-16-graph-test-build-attempt6.log)、[筛选适配版](test-results/2026-10-16-graph-test-build-attempt7.log) |
| 三门峡与洛阳新增内容 | **1/1** | [195422](test-results/2026-10-16-195422-device.log) |
| 郑州开封濮阳新增内容 | **1/1** | [195806](test-results/2026-10-16-195806-device.log) |
| 画布桥接与减少动态 | **1/1** | [200200](test-results/2026-10-16-200200-device.log) |
| 真实画布点击与拖动 | **1/1** | [200347](test-results/2026-10-16-200347-device.log) |
| 对照、个人专题、深色与大字 | **2/2** | [201711](test-results/2026-10-16-201711-device.log) |
| 组合筛选与重置 | **1/1** | [202642](test-results/2026-10-16-202642-device.log) |
| 存储与原有浏览 | **6/6** | [202824](test-results/2026-10-16-202824-device.log) |

七份最终设备报告分别核对完整摘要、声明 / 实际用例数与成功结束标记；Failure=0、Error=0、Ignore=0，共 13 项独立用例。主包始终相同；第一版测试包用于新增内容 / 画布专项，第二版适配旧图谱滚动定位、画布外留白手势和等待就绪，第三版适配筛选控件可见性与仰韶村精确名称助手。各组逐份绑定实际测试包哈希。重试和中断中的单项状态不累计为新增通过，旧版本账号双端、登录专项或完整 UI 回归不计入本轮新验证。截图、原始报告、包版本与 SHA-256 见 [阶段清单](test-results/2026-10-16-graph-phases.json) 和 [截图清单](design/graph/captures.json)。

### 14.2 实际操作与断言

两个新增内容场景通过真实 SearchField 搜索、提交和列表点击，依次打开庙底沟、虢国墓地、偃师商城、汉魏洛阳城、龙门石窟、大河村、郑韩故城、繁塔、州桥及附近汴河遗址、西水坡。每一项核对实际详情摘要、来源入口与“初稿待校审”，并清除 Preferences 缓存回读对应 `progress` 记录。回到目录后清空搜索，结果为 15 条。

画布专项通过 ArkWeb 可访问树中的实际 `toggleButton` 点击仰韶村节点，核对 ArkUI 选中档案改变；启用减少动态与关闭光感时仍保持浅色资源和可操作索引，展开后可以选择西水坡。另一场景在正常动态模式下真实点击并拖动 HTML 节点，核对节点位置变化、边界范围与选中档案保持一致。没有通过测试注入图谱选择结果。

文明连线原有两项保留对照、两处真实笔记 / 标签、个人图谱与专题过滤、实际深色资源、1.5 倍字体和原生按钮横向边界。组合筛选适配为洛阳两处夏商都城，仍逐项核对真实卡片、排除其他城市、重置为 15 条以及不可能组合为 0。存储 / 浏览六项继续验证真实 Preferences、并发保存、损坏 / 非法值 / 孤立备份保护、检索 / 详情和空笔记拒绝。

本地由 43 项扩展到 48 项：补充内容范围、合法分类、原始 ID / 顺序、精确搜索、真实连线与去重、个人图谱空选择、窄屏 / 大字布局收敛、位置保留及拖动 / 缩放边界。既有推荐与关联断言按新增条目实际排序调整，仍保留郑州商城的夏商关联检查。

### 14.3 WebGL 限制与截图范围

Three.js 0.180.0 已随包携带，WebGL 不可用时改用 Canvas 2D，同一份布局和交互逻辑不依赖网络。当前模拟器的 ArkWeb 控制台明确返回 `A WebGL context could not be created ... disabled by enterprise policy or commandline switch`，应用回报 `CULTURE_GRAPH_RENDERER_READY:canvas2d`，证据见 [绘图能力记录](test-results/2026-10-16-graph-renderer.log)。未修改系统参数或全局安全策略强开 GPU。

本轮真实画面与交互均属于 **Canvas 2D 降级**。不能将 Three.js 打包、构建成功或静态截图称为 WebGL / GPU 实测通过，也没有测量帧率、功耗或宣称桥接延迟低于 5ms。光晕和流动粒子为图谱装饰，不是原生沉浸光感、同步状态或历史传播方向。

13 张原图仅含文化初稿和独立库内的合成笔记，不含账号、密码、大学或学号。图集只等比缩放、排列并在画面外加标题，未补画 UI。已检查图谱、拖动后位置、减少动态、对照 / 个人专题、深色、大字和新增内容提示。见 [图集说明](design/graph/README.md)。

### 14.4 保留的失败与修正

- `graph-build-attempt1.log`：ArkTS 拒绝构造函数参数中的字段声明；改为显式字段与赋值后主包构建成功，见 `graph-build-attempt2.log`。
- `graph-local-attempt1.log`：**47/48**，1.5 倍字体下节点标签水平范围重叠；按实际列宽约束标签与碰撞范围后，`graph-local-tests.log` 为 **48/48**，报告解析另 **9/9**。
- [192847](test-results/2026-10-16-192847-device.log)：安装后测试宿主停滞，未进入用例且没有图谱初始化记录；主动停止该进程后原始输出为 `App died`，没有完整摘要。不解释为已确认的应用崩溃，也不计通过。后续安装后显式结束旧进程再发起回归。
- [193242](test-results/2026-10-16-193242-device.log)：**0/1、Error=1**，测试设置减少动态时，新建 Repository 未先 `load()` 即保存，返回 `ARCHIVE_NOT_READY`；仅修正测试准备顺序。
- [193438](test-results/2026-10-16-193438-device.log)：**0/1、Error=1**，图谱已就绪但查询了 HTML 节点的 `description`。实际 ArkWeb 将 `aria-label` 暴露为 `toggleButton.text`，按实际属性修正；桥接断言保留。
- [193805](test-results/2026-10-16-193805-device.log)：长详情来源定位反复小幅滚动，主动停止停滞运行，原始输出缺完整摘要。来源检查改为有次数上限的实际滚动，保留来源与初稿断言。
- [194234](test-results/2026-10-16-194234-device.log)：内容两项和减少动态单项有成功状态，但第四项期间触及 `aa test -w 600` 总时限，缺完整结束摘要，不能记为 4/4。随后将四项拆开取得完整报告，主包保持相同；旧图谱适配只更新测试包。
- [200543](test-results/2026-10-16-200543-device.log)：旧图谱两项为 **1/2、Error=1**，外观场景通过，但第一项仍直接在首屏查询位于新画布 / 索引下方的选中档案标题。仅将相关定位改为真实滚动，并在采图前等待画布就绪；测试包重新构建后复验，不删除对照与个人专题断言。
- [201003](test-results/2026-10-16-201003-device.log)：**0/2、Error=2**。第一项仍用通用 `scrollSearch` 在可拖动的画布区域发起手势，反复拖节点而未滚动，触及单用例 240 秒时限；未结束的调用又使第二项 `Driver.create` 被 UiTest 拒绝并发。之后图谱定位改为从原生左侧留白发起有次数上限的实际手势，保留全部业务断言，结束旧测试进程后重新运行。
- [202233](test-results/2026-10-16-202233-device.log)：**0/1、Error=1**，筛选控件还在 Dock 覆盖区域，直接点击未出现原生菜单。改为先滚到无遮挡区域再选择；没有修改选项或业务过滤结果。另将专用于打开仰韶村的助手由宽泛“仰韶”改为完整遗址名，并先滚到写笔记按钮；扩充后“仰韶”本来就会命中多处档案，不能继续断言只有一处。

`graph-device-attempt1.log`、`graph-device-attempt2.log` 保留停滞 / 超时执行顺序，`graph-device-attempt3.log` 保留新增四项完整通过与旧定位失败；`graph-device-tail-attempt1.log` 保留通用滚动调用超时，`graph-device-tail.log` 保留旧图谱最终通过与筛选定位失败，`graph-device-core.log` 保留最终筛选 / 存储回归及熄屏恢复。最终采用的七份报告由 `graph-phases.json` 逐条索引。公开日志副本中的本机路径已脱敏，原件在忽略的 `.local/publication-originals/`；断言与摘要未改写。失败诊断保留在忽略的 `.local/graph-development/`，不混入最终图集。

### 14.5 复现与边界

```powershell
.\tools\test.ps1
.\tools\build.ps1
.\tools\build.ps1 -Target ohosTest
# 安装两包后结束旧进程，避免沿用安装前的测试宿主。
. .\tools\deveco-path.ps1
$devEcoPath = Resolve-YunhejiDevEcoHome
$hdcTool = Join-Path $devEcoPath 'sdk/default/openharmony/toolchains/hdc.exe'
& $hdcTool -t 127.0.0.1:5555 install entry/build/default/outputs/default/entry-default-unsigned.hap
& $hdcTool -t 127.0.0.1:5555 install entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap
& $hdcTool -t 127.0.0.1:5555 shell 'aa force-stop com.chr.myapplication'
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass 'CatalogGraphTest#new_smx_and_luoyang_sites_open_from_real_search' -ExpectedTests 1 -SkipInstall
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass 'CatalogGraphTest#new_zhengzhou_kaifeng_puyang_sites_open_from_real_search' -ExpectedTests 1 -SkipInstall
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass 'CatalogGraphTest#offline_web_graph_bridge_and_reduced_motion' -ExpectedTests 1 -SkipInstall
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass 'CatalogGraphTest#animated_web_nodes_accept_real_click_and_drag' -ExpectedTests 1 -SkipInstall
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass CultureAtlasTest -ExpectedTests 2 -SkipInstall
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass 'ArchiveUiTest#native_combined_filters_and_reset' -ExpectedTests 1 -SkipInstall
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass ArchiveDeviceTest -ExpectedTests 6 -SkipInstall
```

按实际 HDC 地址替换参数。四项 CatalogGraphTest 合跑可能超过 600 秒总时限，使用上面的分组命令。测试只使用独立 Preferences，完成的场景按本轮库名清理；主动中断不证明退出清理已完成，不枚举或删除正式档案。长回归在 finally 恢复熄屏设置，收尾直接回读确认没有测试时长覆盖，并以正常无测试参数启动应用。

本轮未改 `ArchiveDomain.ts`、账号客户端 / 同步 Gateway、`HarmonyEffects.ets`、`Index.ets`、SDK 配置、`.gitignore` 或服务脚本；八个保护文件与本轮开始时哈希一致。原有五个 ID 与顺序、schema v1、账号库和游客库规则、记录字段及墓碑不变，无格式迁移。15 条均为初稿，仍缺条目级校审与授权实景图。未验证 WebGL 真机、任意字体倍率、平板 / 横屏 / 分屏、进程强停或旧完整双端套件；登录会话仍仅在进程内。API 与实现边界见 [技术核验第 12 节](HARMONY_RESEARCH.md) 和 [内容说明](CONTENT_GRAPH.md)。

## 15. 年代空间与详情形态：2026-10-16 实测

对应 `DEV_GUIDE_NEXT.md` 新增的 2b、2c。本轮交付可旋转的年代空间图谱与详情页形态观察。当前手机模拟器实际使用 **ArkUI Canvas**：图谱复用同一份力导向 / 透视数学，形态使用程序化三维网格的 CPU 投影和法线光照。**ArkWeb 本轮发生 EGL 原生崩溃，ArkGraphics3D 原生 GPU 未通过渲染验收，均不计为已完成的 GPU / 桥接能力。**

### 15.1 构建、本地测试与设备结果

- `tools/test.ps1`：本地 **54/54**、报告解析 **9/9**，Fail=0，无取消或跳过。
- 主包与测试包构建成功；构建仍保留既有签名和部分设备能力警告，没有降低 SDK 或添加伪造依赖。
- 七份完整设备报告共 **7/7**，Failure/Error/Ignore 全部为 0；不累计重试、旧包全量回归或初期只通过按钮的 GPU 空白场景。
- 22 张真实截图、逐图哈希和报告见 [图集](design/spatial/README.md)。原图自动定位的模型区域在减少动态时前后帧完全一致，转动前后像素变化，见 [像素核对](design/spatial/pixel-checks.json)。

| 范围 | 原始报告 | 结果 | 包版本 |
|---|---|---|---|
| 年代深度、旋转、复位、双指、拖动与选择 | [2026-10-16-223430-device.log](test-results/2026-10-16-223430-device.log) | 1/1 | 图谱包 |
| 减少动态时保持稳定、主动旋转与选择 | [2026-10-16-223535-device.log](test-results/2026-10-16-223535-device.log) | 1/1 | 图谱包 |
| 陶器 / 城台 / 城垣，旋转、拖动和复位 | [2026-10-16-224302-device.log](test-results/2026-10-16-224302-device.log) | 1/1 | 最终包 |
| 层塔 / 封土与连续进入返回 | [2026-10-16-224504-device.log](test-results/2026-10-16-224504-device.log) | 1/1 | 最终包 |
| 形态深色 / 1.5 倍字 / 减少动态 | [2026-10-16-224630-device.log](test-results/2026-10-16-224630-device.log) | 1/1 | 最终包 |
| 真实收藏笔记、个人专题与双档案对照 | [2026-10-16-224839-device.log](test-results/2026-10-16-224839-device.log) | 1/1 | 最终包 |
| 图谱深色与 1.5 倍字 | [2026-10-16-225155-device.log](test-results/2026-10-16-225155-device.log) | 1/1 | 最终包 |

图谱两项对应主包 `2249C2CED6347CDB7B5D7612BFC89B104C4FFE5FDD66A846ED6384022EFFC256`、测试包 `FBEB24D8F2B32B7809A253DBE48D22AA69F1281610BD66A681430E856D5ECCB7`。随后仅调整形态视口的自动取景，并移除已完成的单次诊断库清理代码，再构建最终两包并完成形态三项与原有图谱两项回归；图谱源保持不变。对应关系逐项写在 [阶段清单](test-results/2026-10-16-spatial-phases.json)，没有把两版包混成同一包的新验收。

当前主包 SHA-256：`94BB7BC75D645C54FBFBE6386E54B0DF7801FFDDFF6B15285442B183079B7D13`。

当前测试包 SHA-256：`CC6CCC6658463886A0CCE66D3794002EEB52CA339507F8BD621BDE3BDC473093`。

最终构建 / 本地输出：`2026-10-16-spatial-main-build-fitted.log`、`spatial-test-build-fitted.log`、`spatial-local-tests-final.log`。公开报告只脱敏本机路径，原始输出保留在本地忽略目录。

### 15.2 实际验证的操作

- 仰韶节点比宋代节点的点击框更大；旋转后位置改变，复位恢复原坐标。通过真实 PointerMatrix 双指输入和实际单节点拖动，再点击选择检查下方档案名。按钮、文字与 Canvas 点 / 线使用相同投影，不拿原生下方索引替代画布交互。
- 减少动态通过独立 Preferences 落盘、Ability 重建后测试；节点等待后保持相同范围，主动旋转仍生效，材质偏好和减少动态分别回读。
- 五个实际档案类型分别打开详情，左右转动、陶器拖动、复位及连续返回均完成。窑体没有当前目录条目，只计本地网格验证，不计第六种设备形态。
- 原生形态检查深色与 1.5 倍字，关闭持续旋转仍允许主动操作。像素核对从原图定位上半屏暖色模型最大连通区域，取前后范围并集比较，排除时钟 / 文字干扰；要求存在足够大的可见模型，避免把空白图算作稳定画面。
- 原有收藏与两条真实中文笔记 / 标签生成个人专题，双档案对照和个人专题对照继续使用原生页面。图谱外观专项核对实际深色资源和当前 Ability 的 1.5 倍字号。
- 测试使用独立 `yunheji_test_ui_*` 库，不枚举 / 清空正式档案。单次 HDC 诊断库已在阶段用例中显式清理。图形崩溃阶段的异常退出不等于已完成清理，不据此扫描删除未知库。

### 15.3 保留的失败与修正

- `214147` 和 `215202`：按钮 / 状态用例 Pass=1，但 GPU 视口截图为空白；不作为视觉通过。`214914`：原生 Scene 引用改为非状态字段后，条件短路未触发控件创建，Error=1；随后以 phase 驱动创建。
- `214435`、`214715`、`215440`、`220524`、`220927`、`221146`：ArkWeb 进程死亡，无完整成功报告。故障栈为 `Chrome_InProcGp → eglCreateImageKHR → d_eglCreateImage_special`；移除 CSS 动态合成、CPU Canvas 提示、同步嵌入和应用内禁用 WebGL 均未消除该镜像问题。最终使用原生 Canvas，并移除无效配置；未修改设备图形参数或强开 WebGL。
- `221923`：原生按钮闭包持有旧帧坐标，Error=1；改为绑定当前投影状态。`222257`：复位比较发生在力导向收敛前，Error=1；等待真实 180 次布局迭代后再比较。
- `222511`：高密度屏幕上双指行程太短，位置变化 5px 未达断言；根据 PointerMatrix 的屏幕 px 与手势 vp 区别增加真实行程。`222727`：排齐标签的回退覆盖了手动拖动，Error=1；手动锚点优先，周围标签避让，同时区分父层旋转与子节点拖动。
- `223050` 是修复后的核心图谱阶段 1/1。取景调整前形态三项通过保留在阶段清单的 historyReports，不重复累计。最终轮在已完成五项后发现城台近侧底边取景不足，调整后源文件新于包，脚本按设计拒绝继续；重建后完成剩余相关回归。
- 早期编译错误、标签投影测试失败和原始执行日志均保留。本轮未把 App died、缺完整摘要、Error=1 或仅有截图的场景改成通过。

### 15.4 复现与边界

先运行 `tools/build.ps1`、`tools/build.ps1 -Target ohosTest` 和 `tools/test.ps1`。设备先看 `hdc list targets`，以实际地址调用 `tools/device-test.ps1 -TestClass 'SpatialExperienceTest#具体方法名' -ExpectedTests 1`；方法名见阶段清单。原有两项使用相同方式单独指定 `CultureAtlasTest#方法名`，避免长套件总时限。每次重新安装后结束旧进程，再启动测试；原始 Pass/Failure/Error/Ignore 和唯一结束报告均须检查。

数学源修改后用 Node.js 24 运行 `node entry/scripts/compile-graph.mjs` 更新离线 Web 产物；测试核对源哈希。当前模拟器不创建 Web 控件，旧 `CatalogGraphTest` 的 Web 桥接 / HTML 拖动专项未在本轮计作通过。真机 GPU / WebGL、图形帧率与功耗、平板 / 横屏 / 分屏均待验证。旧双端账号、强停恢复和全量存储结果仍属于此前对应包，不直接计入本轮。

代码、包与设备边界详见 [空间体验说明](SPATIAL_EXPERIENCE.md)。本轮没有改核心数据格式、账号 / 同步客户端、主导航、HDS 材质、SDK 或签名。全部文化初稿与几何示意标识保留，未新增未经核验的文化结论。

## 16. 详情形态逐面光照：2026-10-16 实测

按更新后的 DEV_GUIDE_NEXT 优先级 2c 接入逐面 Lambert、22 次幂定向高光、背面剔除与多边形整面描边，并改善陶器纹带、城垣厚度、塔层及地面阴影。当前模拟器实际使用原生 ArkUI Canvas，没有重新启用已知会发生 EGL 崩溃的 ArkWeb 控件。`SiteObject3D` 与详情页改传整个 `site`；系统主题继续独立读取，不使用 `!lightEnabled` 推断深色。

### 16.1 当前包结果

- `tools/test.ps1`：本地 **60/60**，Failure=0、取消 / 跳过=0；设备报告解析 **9/9**。相比上一轮增加六项光照、几何和多视角取景检查。
- `tools/build.ps1` 与 `tools/build.ps1 -Target ohosTest` 均成功；原有签名 / 设备能力警告继续保留，没有改变 SDK 或签名配置。
- 同一对最终包的三组设备专项 **3/3**，Failure / Error / Ignore 均为 0；没有把五种形态算成五个测试，也没有累计旧包图谱 / 账号套件。
- 11 张实际模拟器原图、对照图与像素核对见 [光照图集](design/lighting/README.md)。截图、报告、包哈希绑定在 [阶段清单](test-results/2026-10-16-lighting-phases.json)。

| 场景 | 原始报告 | 结果 |
|---|---|---|
| 陶器、城台、城垣；旋转、拖动、复位 | [233843-device.log](test-results/2026-10-16-233843-device.log) | 1/1，Failure=0，Error=0，Ignore=0 |
| 层塔、封土；连续进入与返回 | [234039-device.log](test-results/2026-10-16-234039-device.log) | 1/1，Failure=0，Error=0，Ignore=0 |
| 深色、1.5 倍字、减少动态与主动转动 | [234200-device.log](test-results/2026-10-16-234200-device.log) | 1/1，Failure=0，Error=0，Ignore=0 |

主包 SHA-256：`08C731A251C7B5C6CC954959A7BA59DCCA992931482126676B91593D2AB8E835`。

测试包 SHA-256：`1DF158A6625F1A0214C66E6504C1CFD177EF14387DCE986FA03357BF55F147DB`。

最终输出：[本地测试](test-results/2026-10-16-object-lighting-local.log)、[主包构建](test-results/2026-10-16-object-lighting-main-build.log)、[测试包构建](test-results/2026-10-16-object-lighting-test-build.log)。公开构建 / 本地日志只替换本机工程路径，原始输出保留在本地忽略目录。

### 16.2 核对内容与修正记录

逐面法线由旋转后的边叉乘得到；背面剔除使用实际相机和屏幕坐标约定，避免把任务书另一套坐标的符号直接照搬。测试核对 GPU 三角索引与原多边形一致、全部面非退化、内外壁法线相反、纹带不叠加共面网格，以及全目录在两种宽度、三种俯仰与十六个转角下保持有效取景。方向光 / 高光检查覆盖亮暗排序、背光环境项和高光峰值。

首轮本地测试 **55/60**：回转体在生成当前圈顶点时就对下一圈做去重，读到了未创建的点，导致五项失败。改为先生成全部顶点，再生成和去重面；最终 60/60。保留 [首轮原始失败](test-results/2026-10-16-object-lighting-local-attempt1.log)，未删除失败断言或将其标记为通过。本轮设备三组没有重试或失败报告。

已核对五种形态的实际画面与图集。减少动态前后模型区域逐像素一致；旋转前后该区域的 RGB 平均绝对差约为 16.15 / 11.81 / 11.29，见 [像素记录](design/lighting/pixel-checks.json)。定位先要求有足够大的可见暖色模型，再排除时钟、状态文字、按钮和下方插画，不把空白图算作稳定。

所有操作通过 HDC / Hypium 直接连接既有模拟器，未控制电脑桌面。沿用独立测试 Preferences，测试结束清理各自场景库；没有枚举、清空或预填正式用户档案。临时熄屏覆盖在 finally 恢复，回读为 30000ms；字体和颜色模式由原有用例恢复，最后正常启动应用。

### 16.3 范围

初始视角剔除约 48%—58.6% 的多边形，详见 [面数量](design/lighting/culling-counts.json)。这不是耗时、帧率或“效率提升约 40%”的实测，当前软件绘制仍使用平均面深度排序，没有像素深度缓冲或真实阴影映射。

GPU / WebGL 可见画面、真机性能、平板 / 横屏仍未验证。本轮未重跑账号双端、图谱、全量存储或强停套件；此前报告继续对应此前包。核心数据模型、账号 / 同步、主导航、材质层、SDK、签名、服务和构建 / 设备脚本与本轮开始时保持一致；仅在既有授权范围内补充必要领域测试。实现和坐标边界见 [逐面光照说明](OBJECT_LIGHTING.md)。

## 17. 五城目录、探索进度与统一文化视口：2026-10-17 实测

参考新计划先交付 Step 1、Step 2。用户已明确取消 HarmonyOS 6，工程维持 **HarmonyOS 7 / API 26**，没有新增低版本页面或 SDK 降级。目录为五城各四条、共 20 条初稿；原 15 个 ID 与顺序保留。首页沙盘、详情器物、四主题切片与星河图谱复用统一视口，页面、HDS 导航、独立“我的”、正文与存储均仍为 ArkUI 原生实现。

用户在本轮明确将后续验证收敛为比赛演示：不再主动跑大字体、泛化安全或边界测试，不为生产化治理扩展工作。以下大字与完整回归只记录本轮已执行的历史，不是后续每轮门禁；后续围绕实际演示路径和具体问题做必要验证。

### 17.1 本地、构建与设备结果

- `tools/test.ps1`：本地 **81/81**，Fail / Cancel / Skip 均为 0；设备报告解析 **9/9**。
- `tools/build.ps1`、`tools/build.ps1 -Target ohosTest` 均成功；测试等待拆分后又成功构建 `ohosTest`。保留既有签名与设备能力警告，未更改 SDK 或签名。
- 按场景绑定三版包的设备六项 **6/6**，Failure / Error / Ignore 均为 0。首页与图谱为初始页面包；进度与模型为热点配色包；外观与原收藏笔记为大字修正后的当前包。三个版本只有详情按钮样式和必要的测试可见性适配变化，首页、图谱、领域与共用绘制源未改。未重复累计同一场景的重试，未将缺摘要、超时或有视觉问题的旧截图计为最终通过。
- 21 张实际模拟器原图、包与源码 SHA-256 绑定在 [阶段清单](test-results/2026-10-17-engine-phases.json)。[真实图集](design/engine/README.md) 包含总览和逐图证据。

| 范围 | 原始报告 | 结果 | 包版本 |
|---|---|---|---|
| 首页五城沙盘；五城各四条实际筛选结果 | [2026-10-17-140850-device.log](test-results/2026-10-17-140850-device.log) | 1/1 | 初始页面包 |
| 星河图谱五城索引与二里头 / 郑州商城对照 | [2026-10-17-141023-device.log](test-results/2026-10-17-141023-device.log) | 1/1 | 初始页面包 |
| 明确四主题 0→25→50→75→100；磁盘回读与 Ability 重建 | [2026-10-17-142036-device.log](test-results/2026-10-17-142036-device.log) | 1/1 | 热点配色包 |
| 陶器、方鼎、层塔、蚌壳点列、城台；旋转、复位与热点 | [2026-10-17-142251-device.log](test-results/2026-10-17-142251-device.log) | 1/1 | 热点配色包 |
| 深色、1.5 倍字、真实减少动态与主动转动 | [2026-10-17-143541-device.log](test-results/2026-10-17-143541-device.log) | 1/1 | 大字修正后包 |
| 原有收藏、笔记增删改、墓碑与 Ability 重建 | [2026-10-17-143804-device.log](test-results/2026-10-17-143804-device.log) | 1/1 | 大字修正后包 |

主包 SHA-256：`0649C11401A7C67F4CB4366A61252ACF1BF5D4333873FBF5EEA2D178551937AF`。

测试包 SHA-256：`77BA1E8B5E636DF3767AC1B6F9A5635D82CE76FCFFAA41F32FA52E888F1B8CA8`。

最终输出：[本地测试](test-results/2026-10-17-engine-local.log)、[主包构建](test-results/2026-10-17-engine-main-build-padding.log)、[测试包构建](test-results/2026-10-17-engine-test-build-padding.log)。此前测试包构建和失败仍保留，公开副本只替换本机路径。

### 17.2 实际交互与像素核对

五城各四张卡片逐一核对，图谱通过原生索引选择五城代表档案并打开实际双档案对照。五种详情形态均核对可见视口、主动转动、复位；仰韶三热点正文对应实际资料。切片的四层是内容主题的空间示意，不是具体遗址的考古层序。

打开详情、旋转、复位、切换模式和热点均不增加进度。只有明确标记一个主题并完成本机提交后才增加 25%；页面发布状态后再回读实际 Preferences，四项到达 100%，Ability 结束重建后仍恢复。旧 `opened` 记录仅表示打开过，不能折算进度。主题各一条 `progress:<siteId>:<sectionId>`，沿用 schema v1、现有墓碑与同步合并，不改笔记格式。

减少动态通过真实 Switch 开启并磁盘回读；深色资源与 1.5 倍字体实际检查。对齐原图中的 Canvas 布局范围后，减少动态前后区域逐像素一致，且先要求存在充分可见的场景；五模型转动前后均有像素变化。详见 [像素核对](design/engine/pixel-checks.json)，不把文字状态或空白截图当成绘制通过。

所有设备操作只通过 HDC / Hypium 直接连接模拟器，未控制电脑桌面。每个成功用例使用独立随机 Preferences 并由 `session.run` 清理；没有枚举、删除或预填正式档案。收尾恢复本应用字体与颜色模式、熄屏覆盖，并正常无测试参数启动。

### 17.3 保留的失败与修正

- `134700`：冷启动锁屏导致应用快速后台 / 销毁，无完整摘要，未计通过；通过模拟器输入解除锁屏后继续。
- `135110`：已有部分页面证据，但人工发现 Canvas 标签使用物理像素导致过小，主动停止本次验证。改用当前 UIContext 的 `fp2px` 后重建两包并重新运行；该次无完整摘要，未计通过。
- `135416`：首个合并 river＋graph 用例 **240000ms 超时，Pass=0、Error=1**。保留完整原始报告和旧包哈希。将五城与图谱拆为独立场景，并减少已稳定 Scroll 的重复等待，保留 20 张卡片、五次选择与双档案全部断言，没有提高超时上限。
- `140226` 五城阶段 1/1 后，`140425` 图谱阶段因整屏自动化手势跳过短入口而 **Pass=0、Error=1**。实际失败截图停在全部列表底部；调整搜索滚动的位移与惯性后重建测试包，之后按场景完成最终六项。首轮分组两包哈希与原始结果另保留在 `2026-10-17-engine-phases-river-first.json`，未重复累计首轮通过数。
- 小步长版本的五城、图谱、进度和五种形态通过后，人工查看原图发现三个热点按钮仍用系统蓝色。补齐暖白 / 玫瑰配色、等分宽度与当前热点选中状态，再构建两包复验详情。首页、图谱及共用引擎源哈希未变，保留其初始包结果；配色前阶段及图片保存在 `engine-phases-before-detail-style.json`。
- `142511` 外观原始用例 Pass=1，但人工查看 1.5 倍字原图发现热点按钮被系统默认内边距挤出省略号，未计最终大字视觉通过。显式设为左右 4vp 内边距，保留字体缩放，重建两包后定向完成外观复验。旧图片与包保存在 `engine-phases-before-large-text-padding.json`。
- `142802` 原收藏笔记回归 **Pass=0、Error=1**，等待“已收藏”失败；失败布局显示新增视口下方的收藏区尚未滚出。修正旧用例对详情页的有界可见性检查，从留白小步滚动后点击，并保留真实分类、笔记增删改、磁盘、墓碑与重建断言，未改存储逻辑或超时上限。
- 首轮本地失败来自旧网格数量 / 段数断言、来源标题与复位浮点比较；适配新网格且保留断言语义。早期构建的 ArkTS 类型限制与已撤回低版本页面引用均保留原始输出。详见 `engine-local-attempt1.log`、`engine-build-attempt1.log`、`engine-build-attempt2.log`。

主动中断或超时不能证明当次独立库已经完成清理，不据此扫描删除未知库。成功的最终六项与早期未完成尝试分别记录。

### 17.4 实现与验收边界

当前模拟器在创建 ArkWeb 之前选择 **ArkUI Canvas 软件透视与逐面光照**，避免已知 EGL 原生崩溃。离线 WebGL2 / GLSL 与 Web Canvas 代码已接入，矩阵、预设、生命周期及静态 GLB 解析有本地检查；本轮没有 WebGL2 / GPU 可见设备画面或着色器编译证据。没有随包真实文物 GLB；解析器限非压缩静态几何、基础色与节点变换，纹理、动画、蒙皮和完整 PBR 未完成。

全部内容与程序化模型继续标示初稿 / 学习示意，没有授权实景图或真实复原。Step 3 手账卡 / 漫游，Step 4 分布式 KV / 冲突裁决 / 备份恢复尚未实施。留影接口保留但入口默认关闭，避免尚无手账接收者时丢弃结果。本轮没有重跑完整账号双端、进程强停或旧全量存储套件，不把历史结果套到当前包。实现与变更文件清单见 [CULTURAL_ENGINE.md](CULTURAL_ENGINE.md)。


## 18. 拾遗手账与主题漫游：2026-10-17 核心演示

本轮先按用户要求用中文提交并推送既有版本到 `origin/main`（`0bdb35d`），然后实现 Step 3。三个指定模型子代理分别处理手账领域、原生卡片、主题漫游，主代理接通编辑器、列表 / 画廊和视角回放。Step 3 的源码与验证材料按用户后续指令纳入本次 Git 提交。

主包及测试包构建成功，本地 **89/89**、报告解析 **9/9**。设备只验证 **1 条**实际演示路径，结果 **1/1**，Failure / Error / Ignore 均为 0，原始报告为 [2026-10-17-152242-device.log](test-results/2026-10-17-152242-device.log)：仰韶凝视 → 留住此刻 → 选择印章 / 青玉笺并写中文手账 → 实际 Preferences 回读四项元数据 → 记忆画廊 → 恢复保存视角 → 寻夏记节点点亮、1 / 5 → 打开主题路线图谱。四张原图见 [图集](design/memory/README.md)，对应包见 [阶段记录](test-results/2026-10-17-memory-phases.json)。没有新增大字、泛化安全或无关边界套件。

首轮构建的 ArkTS 嵌套类型、对象展开、回调返回类型和组件方法名冲突已修正，原始输出保留在 `2026-10-17-memory-build-attempt1.log`。首轮设备 [2026-10-17-150705-device.log](test-results/2026-10-17-150705-device.log) 已实际保存并回放，到路线断言因不支持嵌套 `within` 定位而 **Pass=0 / Error=1**；修正后重建并完成同一核心路径。根据原图另修正卡片时间、时令和保存状态横向挤压，并把手账区前置到收藏之前。最终两包与四张截图绑定本次展示修正后的同一核心演示，未增加用例范围。失败包信息见 [首轮记录](test-results/2026-10-17-memory-attempt1.json)，不计通过。

三个路线均只用现有目录 ID，75% 显式进度或有效活跃手账点亮节点；全路线纪念章由真实完成状态派生。旧普通笔记缺省不补字段、不自动打卡，schema v1 按需增加四项可选元数据，迁移边界见 [兼容说明](MEMORY_MIGRATION.md)。删除仍保留墓碑；路线连线只表达主题阅读顺序。当前设备使用原生 ArkUI Canvas；完整路线逐点完成、Web/GPU 回放与双端手账同步未在本轮实测，Step 4 尚未实施。

最终构建 / 本地日志为 `2026-10-17-memory-main-build.log`、`memory-test-build.log`、`memory-local.log`。设备只经 HDC / Hypium 直接控制模拟器，使用随机独立库；正常结束清理后恢复熄屏覆盖并正常启动应用。后续按 [手账与漫游说明](MEMORY_JOURNEY.md) 的展示路径继续，不扩大为全套生产验收。

## 19. 核心体验成型阶段 T01—T03：2026-10-17

本里程碑先完成三处内容与素材核验，再将具体问题、原创分析图、九条事实及来源入口接入详情；不将后续热点、手账画面或双端阶段登记为已完成。资料和许可清单见[研究索引](research/core-experience/README.md)，阶段任务见[执行规范](CORE_EXPERIENCE.md)。

本地 **89/89**、设备报告解析 **9/9**，主包和测试包均 `BUILD SUCCESSFUL`。设备唯一核心用例 `CoreContentTest#native_three_material_studies_questions_visuals_facts_and_sources` **1/1**，Failure / Error / Ignore均为0，原始报告为 [2026-10-17-160042-device.log](test-results/2026-10-17-160042-device.log)，耗时239150ms。实际搜索庙底沟、大河村、杜岭二号方鼎，逐处检查问题、Image、发现文案、三条事实正文，点击展开并读取主来源。三张截图均人工检查，问题、图示与解释可见。对应两包及截图见[阶段记录](test-results/2026-10-17-core-content-phases.json)和[图集](design/core-content/README.md)。

首轮本地 **88/89**，失败为旧内容断言要求所有诗文非空；三处无可核诗文时不再留“将来补充”占位，测试仅允许已精做对象的诗文为空，其余字段、身份与初稿状态断言保留。失败输出 `2026-10-17-core-content-local-attempt1.log` 保留，修正后本地89/89。主包、测试包与最终本地日志为 `core-content-main-build.log`、`core-content-test-build.log`、`core-content-local.log`，均以2026-10-17为文件名前缀。本轮没有编译或设备失败，不追加大字、安全及无关边界套件。

三份研究记录由指定模型子代理独立核对官方条目，照片与图库未取得应用分发许可；随包素材是依据文字事实独立绘制的三张SVG，不含外部图片、拓本或贴图。已核对九条事实不等于整个档案已人工校审，三处仍保留初稿状态。T03锁定双连壶/方鼎三维度内容，但原对照UI尚未升级；T04—T13仍待后续实现。全部设备操作只使用HDC/Hypium与独立库，成功结束后清理并恢复模拟器熄屏覆盖，正式档案未清空。

## 20. 核心体验 T04—T08 大河村样板与 T06 对照：2026-10-17

先按用户指令把内容核验版本中文提交并推送到 `origin/main`，提交 `37bfbf0`，再开发这一轮样板。本节新实现与验证材料随本次中文提交交付。三个指定模型子代理分别处理对象几何、视角兼容和卡片 / 对照页，主代理合并原生路由、实际绘制回调和设备验证。

大河村 `zz-dahecun / dahecun_pottery / revision 2` 已有两个敞口、内壁、腹部连接通道和红衣黑彩示意；三部位各自对应具体观察提示、推荐取景及有出处事实。腹部通口通过剖开前壁表现内部关系。仅大河村启用这一级观察，庙底沟和杜岭未登记为 T04 完成。T05 将非考古层序的模式改名“文化切片”、无音频的“听故事”改为“读线索”。T06 新增双连壶 / 方鼎三维对照，每维有双方事实、来源和推断边界，并完整展示两张原创分析图。

### 20.1 本地、构建与最终设备结果

`tools/test.ps1` **93/93**，报告解析 **9/9**；`tools/build.ps1` 和 `tools/build.ps1 -Target ohosTest` 均 `BUILD SUCCESSFUL`。最终日志为 [本地](test-results/2026-10-17-observation-local.log)、[主包](test-results/2026-10-17-observation-main-build.log)和[测试包](test-results/2026-10-17-observation-test-build.log)。保留既有 SDK / 签名警告，未改签名或目标平台。公开构建日志仅替换本机路径，原始输出留在本机忽略目录。

| 最终核心路径 | 原始报告 | 结果 | 耗时 |
|---|---|---|---|
| 三部位与观察提示 → 主动右转 → 草稿画面 → 真实保存 / 磁盘回读 → 画廊 → 点击预览正式回放 | [2026-10-17-170500-device.log](test-results/2026-10-17-170500-device.log) | 1/1，Failure / Error / Ignore = 0 | 146382ms |
| 三组对照的左右事实 / 推断边界 → 双方来源 → 两张完整 Image / 图注 → 返回大河村实际详情 | [2026-10-17-165119-device.log](test-results/2026-10-17-165119-device.log) | 1/1，Failure / Error / Ignore = 0 | 74204ms |

两条最终路径共 **2/2**，主包 SHA-256 `7B52CAC9ECBCC4C09199AFEC3F91D10BEA751BD6FDB1E8185BFEE89B5E321127`，测试包 SHA-256 `B24958475C8FF3F302A8C17E7780193EB5550B13AD1E4E3B88739AC17F55115F`；九张原图与相关源码哈希绑定在[阶段记录](test-results/2026-10-17-observation-phases.json)，实际页面见[图集](design/observation/README.md)。未将先前两次样板通过重复累计为当前包数量。

### 20.2 保存、画面与回放

手账沿用 schema v1 / MemoryPose v1，新增可选的预设、场景修订、渲染配置与原虚拟画幅（含字体密度和明暗模式）。本次经实际页面输入中文正文和标签，保存后移除 Preferences 缓存回读，核对正文、标签、当前事实摘录和完整相机参数。原取景为 `294.85714285714283 × 300`，yaw=0.7326990816987242、pitch=0.14、zoom=0.98、热点 opening。预览通过同一 NativeRenderer 按原虚拟画幅等比重建，没有上传截图或依赖本机图片路径；回放只在实际绘出有效场景后提示成功。

用真实布局定位 Canvas，去掉四侧 12px 后，整片内部有 **1** 个像素不同，最大通道差 **1**。该点在近圆角的浅色背景，源 RGB 为253/251/247、回放为252/250/247；暖色模型区域没有差异。首次像素脚本的严格整片相等断言因此停止，随后保留原裁切与原图，如实记录差异，并分别检查模型与整体误差，没有重录或移动裁切来消除这个点。先检查充分可见的陶器模型，避免空白相等。画廊按原画幅去掉 contain 留白并与等比缩放的源视口比较，RGB 相关系数 **0.999190**；缩放抗锯齿误差见[像素记录](design/observation/pixel-checks.json)。当前仅证明本次模拟器画面与构图，不代替另一端实际显示 / 回放验证。

旧普通笔记保持可读；旧视角显示“旧版视角，原取景未记录”，不补造预览。未知档案、预设 / 修订 / 配置不可用或相机超出支持范围时明确提示，不静默换到首条档案或截断参数后宣称恢复。合法未知扩展仍可归档，深拷贝 / 冲突比较 / 墓碑保留，详见[迁移说明](MEMORY_MIGRATION.md)。

### 20.3 实际修正与范围

首轮样板 [164410](test-results/2026-10-17-164410-device.log) 1/1 后，人工发现三处热点字覆在器表且较暗；只给当前部位加浅底注释牌，其余保留圆点。标注版 [164722](test-results/2026-10-17-164722-device.log) 再次 1/1，并通过画面核对；随后补充每个部位的短观察提示，最终以本节第一条结果为准。两个中间版本包和原因见[中间记录](test-results/2026-10-17-observation-intermediate.json)，没有把“文案存在”或截图命令成功直接当成模型画面通过。

用户中断后设备离线，使用 Emulator CLI 以保留数据的 coldboot / noWindow 重新启动已存在实例，HDC 列表确认在线后经模拟器输入解除锁屏，继续唯一核心路径；没有重建、清空模拟器或操作电脑桌面。每条成功路径使用随机独立 Preferences 并按原 session.run 清理；收尾恢复熄屏覆盖并正常启动应用。没有新增大字、泛化安全、无关边界或全量账号套件。

T07 / T08 当前为大河村样板及通用 Native 参数预览机制；另外两处精细观察尚未扩展。T09 / T10 首页与主题直达、T11 新手账双端及 T13 三分钟脚本 / 备用录像仍待实施。现有账号传输仍为 HTTPS，没有本轮跨端结果、WebGL 可见结果或授权实物模型。三处完整文化内容继续标注初稿待校审。当前可演示路径与代码行为见[观察手账说明](OBSERVATION_MEMORY.md)。

## 21. 三处独立观察与画面手账扩展：2026-10-17

本轮在大河村样板基础上，为庙底沟与杜岭二号方鼎接入独立的 revision 2 原生观察场景，并沿用同一套带画面手账、原虚拟画幅重建与实际绘制确认。庙底沟的三个部位解释中西部居住、西部陶窑共存及东西开放壕沟；方鼎的三个部位区分四壁正中、四个折角与乳钉边框。三处均连接具体观察提示及已核事实，档案仍为初稿，几何均为学习示意。

Git基线为 `89c18c1406dcb7b42193fc512ffd85ee9e2f42cd`，本轮开始时已按用户要求中文提交并推送到 `origin/main`；后续新开发尚未二次提交或推送。本节与第20节分别对应各自包，不把大河村与对照页的旧报告累计到本轮设备结果。

### 21.1 本地、构建与当前设备状态

`tools/test.ps1` 本地 **95/95**、报告解析 **9/9**，原始输出见[本地日志](test-results/2026-10-17-expanded-observation-local.log)；[主包构建](test-results/2026-10-17-expanded-observation-main-build.log)与[测试包构建](test-results/2026-10-17-expanded-observation-test-build.log)均为 `BUILD SUCCESSFUL`。下表为最终同一对包上的两条核心路径，合计 **2/2**，Failure / Error / Ignore均为0。

| 核心路径 | 当前结果 | 原始报告 |
|---|---|---|
| 庙底沟：三部位 → 主动右转 → 真实保存 / 磁盘回读 → 画廊 → 正式回放 | 1/1，Failure / Error / Ignore=0；155058ms | [2026-10-17-182114-device.log](test-results/2026-10-17-182114-device.log) |
| 二号方鼎：三部位 → 主动右转 → 真实保存 / 磁盘回读 → 画廊 → 正式回放 | 1/1，Failure / Error / Ignore=0；155787ms | [2026-10-17-182413-device.log](test-results/2026-10-17-182413-device.log) |

最终主包 SHA-256：`4AF9FF393DE9124852AC52BF4F519188912F1AAADFBC627477E48B8CD3D725EA`。最终测试包 SHA-256：`B6BBDDCD556A832907106B020FC6D97417EFA863D810BD3CE2E6F0029BA7ACC3`。报告、源码及12张原图的版本绑定见[阶段清单](test-results/2026-10-17-expanded-observation-phases.json)。本轮T04/T07/T08三处样板扩展可验收，T09/T10、T11与T13不包含在这两条结果中。

### 21.2 保存、画面与回放的核对范围

本轮复用 `CulturalNativeRenderer.draw → nativeCulturalScene → objectRasterFrame`，没有新增字段或 schema 变更。测试入口 `ExpandedObservationTest` 按两条核心路径分别选择精确方法，使用独立 Preferences；真实输入正文和标签、保存后移除缓存回读，核对事实摘录、预设、场景修订、热点、相机和原虚拟画幅。由画廊点击预览进入正式回放，实际画布完成绘制后才显示成功。

最终逐处保存三部位、保存前取景、画廊预览与正式回放的六张原图，合计12张，公开于[本轮图集](design/expanded-observation/README.md)。保存前 / 正式回放依据真实布局的Canvas边界裁切比较，先确认有充分可见的模型；画廊依据连续JSAPP日志中保存的原虚拟画幅去除contain留白，再以LANCZOS等比适配比较完整内容画幅。两处三个热点的画面两两均有实际差异，核对不以文字状态或截图命令成功代替实际模型。

| 对象 | 保存前 / 正式回放完整Canvas | 模型像素核对 | 画廊RGB相关系数 / 平均绝对通道差 | 公开核对资料 |
|---|---|---|---|---|
| 庙底沟 | 1032×1050，共1083600像素；变化0，最大通道差0，含背景完全一致 | 361117像素，变化0 | 0.9990419448426008 / 0.50065997 | [数值](design/expanded-observation/miaodigou/pixel-checks.json)、[三部位与预览](design/expanded-observation/miaodigou/overview.png)、[回放对照](design/expanded-observation/miaodigou/replay-comparison.png) |
| 杜岭二号方鼎 | 1032×1050，共1083600像素；变化0，最大通道差0，含背景完全一致 | 270837像素，变化0 | 0.9995216989110912 / 0.47611242 | [数值](design/expanded-observation/duling/pixel-checks.json)、[三部位与预览](design/expanded-observation/duling/overview.png)、[回放对照](design/expanded-observation/duling/replay-comparison.png) |

最终庙底沟实际保存 `kilns`，yaw为0.5726990816987241、pitch为0.77、zoom为0.99；方鼎保存 `corners`，yaw为1.1726990816987242、pitch为0.58、zoom为0.98，均是主动转动后的取景。两处保存与实际绘制的回放相机均按原规则核对，原虚拟画幅为294.85714285714283×300，textDensity为3.5、dark为false。此结果覆盖本机保存、画廊与正式回放，不代替T11另一端接收新记录后的验收。

### 21.3 保留的失败与修正

首轮本地测试在新的 Node 领域模块装载器中失败：嵌套 `data:` URI 使用单引号导入时，百分号编码没有处理嵌入的单引号，触发 `SyntaxError: Unexpected token '%'`。改为 base64 编码的模块 URI 后，最终本地95/95、报告解析9/9。失败原始输出已归档为[本地首轮诊断](test-results/2026-10-17-expanded-observation-local-attempt1.log)，没有放宽业务断言。

以下七条中间设备记录与实际包对应关系保留在[中间清单](test-results/2026-10-17-expanded-observation-intermediate.json)，均不累计到最终2/2。

首轮庙底沟 [173438](test-results/2026-10-17-173438-device.log) 为 **0/1、Failure=0、Error=1、Ignore=0，73955ms**。读完较长常驻说明后，Canvas 已滚到上方；新用例的 `frameCanvas` 缺少真实画布锚点时仍默认向下搜索，最终停在档案概览并报 `EXPANDED_OBSERVATION_CANVAS_NOT_FRAMED`。只修正新增用例的真实锚点与滚动方向，不改产品、业务断言或超时上限。失败截图和布局留在本机忽略目录；失败测试包 SHA-256 为 `E3823FD7CD13157E1E95FE8107543613D448014D5E86657DEAB70B85C0BC2239`，不能与修正后的测试包混称同一版本。

第二次庙底沟 [173903](test-results/2026-10-17-173903-device.log) 为 **0/1、Failure=0、Error=1、Ignore=0，78893ms**。已采到清晰的 `living` 中间画面，切到 `kilns` 的标签、短提示与事实也已通过，但角度状态仍为“初始视角”，原“已聚焦”断言失败。原因是部位按钮经 payload 更新后与 Canvas 直接点热点走了不同的手动选择状态：`reload` 原先调用 `focus(..., manual=false)`。产品修正为区分初载和后续部位选择，后续选择清除旧回放画幅并正确显示已聚焦；保持原业务断言与超时，重建两包后复跑。中间画面和报告不作为本轮最终视觉证据。

第三次庙底沟 [174713](test-results/2026-10-17-174713-device.log) 为 **0/1、Failure=0、Error=1、Ignore=0，182305ms**。已实际走到保存、画廊和正式回放，但新增用例精确预期“已回到手账视角”，实际完整提示为“已回到手账视角 · 拖动旋转 · 双指缩放”，因此格式匹配断言失败。只修正测试匹配方式，保留恢复 yaw 等业务验证，产品不变。该次不记作整条路径通过，也不将它的中间截图累计为最终原图。

第四次庙底沟 [175144](test-results/2026-10-17-175144-device.log) 为 **1/1、Failure / Error / Ignore=0，238745ms**，六张原图齐备；但结束后的hilog环缓冲只保留最后约45秒，较早的保存与回放取景日志缺失，像素比较未开始。因此只登记该次设备通过，不把证据缺失描述为已经测得像素相等或不相等，随后同包连续采集JSAPP日志补采。

旧阶段包二号方鼎 [175609](test-results/2026-10-17-175609-device.log) 为 **1/1、Failure / Error / Ignore=0，225125ms**，连续日志、原环缓冲及六张图齐备。1032×1050画布的270837个模型像素零差异，背景1像素最大通道差1，画廊相关系数0.9995216989110912、平均绝对通道差0.4761124。上述两份通过的主包为 `4AF9FF393DE9124852AC52BF4F519188912F1AAADFBC627477E48B8CD3D725EA`，测试包为 `DC5A3F160D6DF6BA93E1F725334524DF58052888928F529D2A4B893FF0E9B0A4`，仅保留为旧测试包阶段通过。

连续日志补采庙底沟 [180030](test-results/2026-10-17-180030-device.log) 为 **0/1、Failure=0、Error=1、Ignore=0，240001ms**，超过单用例240000ms时限。六张原图和保存 / 回放日志虽已齐，独立图像核对得到361117个模型像素零差异、背景1像素最大通道差1，画廊相关系数0.9990419448426008、平均绝对通道差0.50066；图像结果不改变整条设备用例超时失败的结论。

随后首次合并文案查询的定位优化 [181514](test-results/2026-10-17-181514-device.log) 仍为 **0/1、Failure=0、Error=1、Ignore=0，240110ms**；长说明与页首间的试探滑动成本尚未消除，不能记作优化成功。该次测试包为 `C25ADE5F793278247E07CAA813CF1CE09C1174C021E0F4B1E7277A0405F7AC30`，产品主包仍为最终的4AF9FF版本。

最终只调整测试定位：详情的 `frameCanvas` 使用真实Scroll的 `scrollToTop(40000)`，之后继续核对实际模式锚点与完整画布；未知后续目标先向下寻找，主动转动前先取景。全部业务 / 角度断言、每处六张截图与240000ms上限均保留，产品主包不变，仅重建测试包。最终两处统一到21.1的同一对包后各1/1，庙底沟由旧通过记录的238745ms降至155058ms，方鼎为155787ms。中间失败、旧包通过和最终通过分别保留，不累计重复次数。

### 21.4 复现入口与边界

```powershell
.\tools\test.ps1
.\tools\build.ps1
.\tools\build.ps1 -Target ohosTest
.\tools\device-test.ps1 -TargetId <实际在线设备> -TestClass 'ExpandedObservationTest#native_miaodigou_observe_save_gallery_replay' -ExpectedTests 1
.\tools\device-test.ps1 -TargetId <实际在线设备> -TestClass 'ExpandedObservationTest#native_duling_observe_save_gallery_replay' -ExpectedTests 1
```

设备操作继续通过 HDC / Hypium 直接连接既有模拟器，使用独立测试库，不清空正式档案；每份完整报告须核对声明 / 实际数量与 Pass / Failure / Error / Ignore。实际页面仍为 HarmonyOS 7 / API 26 的原生 ArkUI Canvas，不计 WebGL / GPU 可见设备通过，也没有新增授权实景图或真实扫描模型。

三处旧 revision 1 几何及 `form / pattern / story` 热点保留，旧记录不补造原画面，删除墓碑与损坏保护不变。T09/T10 首页与主题入口、T11 同账号另一端的新手账接收 / 预览 / 回放、T13 三分钟脚本与录像仍未完成。当前传输继续称为 HTTPS，不称分布式 KV；不扩大大字、泛化安全或生产治理测试。

## 22. 首页主题与最近真实记忆（2026-10-17）

T09/T10沿用HarmonyOS7/API26与ArkUI原生页面；范围为首页单张主题、最近真实记忆 / 空态、主题直接打开内容、首页画面正式回放及完整路线。本轮先将三处观察扩展以中文提交并推送到 `origin/main`，提交为 `99328acc41457a280d5b2a4233920e1fdf9578f7`；本节T09/T10首页开发、必要测试和验证材料尚未二次提交或推送。

本地 **95/95**、设备报告解析 **9/9**，主包与测试包均 `BUILD SUCCESSFUL`。唯一首页核心设备路径 **1/1**，Failure / Error / Ignore 均为 0，耗时 **161021ms**，原始报告为 [2026-10-17-200742-device.log](test-results/2026-10-17-200742-device.log)。通过真实离线入口进入独立随机档案库，确认首页主题直接打开庙底沟、仅打开仍为0/4；选择西部陶窑并主动右转后，通过编辑器真实保存正文、标签、事实摘录和视角，清 Preferences 缓存后从磁盘回读。回首页后显示真实最新手账、预览及1/4，下一处变为大河村；点击首页画面正式回放，选中热点与实际绘制相机一致，并核对个人页完整四节点仅庙底沟点亮。

实际五组原图及配套 dumpLayout 已归档，保存前 / 正式回放的 **1032×1050整幅Canvas**，变化像素为 **0**，最大通道差为 **0**，模型区域 **361127像素**无差异。首页124vp预览依据磁盘原虚拟画幅去除contain留白后，与保存画面等比核对的RGB相关系数为 **0.997163169**，平均绝对通道差为 **1.023252**。完整值见[像素核对](design/home-experience/pixel-checks.json)，包、源码与原图绑定见[阶段清单](test-results/2026-10-17-home-experience-phases.json)，实际页面见[本轮图集](design/home-experience/README.md)。

| 构建 / 验证 | 实际结果 | 原始输出 |
|---|---|---|
| 本地逻辑 / 仓库与报告解析 | 95/95、9/9 | [本地](test-results/2026-10-17-home-experience-local-test.log) |
| 主包 | BUILD SUCCESSFUL | [构建](test-results/2026-10-17-home-experience-main-build.log) |
| 测试包 | BUILD SUCCESSFUL | [构建](test-results/2026-10-17-home-experience-test-build.log) |
| 首页唯一核心路径 | 1/1，Failure=0，Error=0，Ignore=0，161021ms | [2026-10-17-200742-device.log](test-results/2026-10-17-200742-device.log) |

主包 SHA-256：`00B1774C2D4F858C7F5F52738C16AC02FE5B39660A3C33B4672FE44263791D94`。

测试包 SHA-256：`485CE18969CF307465C15E7F7263E72C65A33F382A06709197C45C3A36F1BD18`。

五条中间记录保留，未累计到最终1/1：[194229](test-results/2026-10-17-194229-device.log) 因冷启动仍处锁屏，SceneBoard对测试宿主和正式Ability报 `handleForegroundTimeout` 并销毁进程；确认进程消失后结束本轮HDC测试客户端，无结束摘要、无截图，不补造Hypium失败计数。[启动诊断摘录](test-results/2026-10-17-home-experience-startup-diagnostic.log)保留相关原始行，完整系统日志在本机忽略目录。[194648](test-results/2026-10-17-194648-device.log) 为0/1、Failure=0、Error=1、Ignore=0、65560ms，已进入真实首页与庙底沟；新用例误把导航标题限制在 `detail-scroll` 内，只修正标题作用域并增加目标诊断。[195320](test-results/2026-10-17-195320-device.log) 为0/1、Failure=0、Error=1、Ignore=0、83889ms；已完成热点、右转与保存前取景，编辑器Canvas实际完整显示且已重建，但新增检查要求额外80px余白，错误判为剪裁。最终只改用真实Scroll及导航可见边界核对画布四边，手势安全区和全部业务断言、截图、240000ms上限均保留。[195716](test-results/2026-10-17-195716-device.log) 为0/1、Failure=0、Error=1、Ignore=0、125604ms，已通过编辑器预览、正文和标签输入；新测试把固定底部保存按钮错误限制在滚动区域，改为等待稳定的真实页脚后点击，并复核其余目标。[200155](test-results/2026-10-17-200155-device.log) 为0/1、Failure=0、Error=1、Ignore=0、91545ms，真实保存及磁盘回读完整，首页已显示新卡和预览，但主题仍0/4和庙底沟，捕获实际产品刷新缺陷。修正首页主题卡对当前snapshot.records的显式依赖后重建两包；保留1/4及下一处大河村的业务断言复验。这五条中间记录的旧产品主包相同，最终包另行绑定；中间测试包及原图保留在[中间清单](test-results/2026-10-17-home-experience-intermediate.json)。

本轮设备只运行这条独立随机库的核心路径；结束后清理该库、恢复熄屏覆盖并正常启动应用。没有重跑大字、泛化安全、旧全量存储或双端套件。旧笔记与格式规则沿用既有实现，本轮没有schema或字段变更。T11新手账同账号B端实际接收 / 画面 / 视角与T13三分钟录像仍待验收；本轮原生Canvas结果不覆盖GPU / WebGL2或真机性能。

## 23. 双端新手账同账号闭环与主线排练（2026-10-17）

本轮范围是任务书 T11 的最小完整样板、T12 的定向修复与 T13.1 主线排练：**庙底沟西部陶窑 → A 端真实保存 → B 端同账号 HTTPS 接收 → B 端首页预览 → B 端正式回放**。录像（T13.2）按用户本轮指示不由代理录制，T13 整体仍未完成。

### 23.1 环境、服务与版本

| 项目 | 实测事实 |
|---|---|
| A 端 | `Pura 90 Pro`，HDC `127.0.0.1:5555`，HarmonyOS 7.0.0.107 / API 26，1256×2760、density 560 |
| B 端 | `YunhejiSyncB`，HDC `127.0.0.1:5557`，同一系统 / API / 分辨率 / 密度，保留原数据 coldboot |
| 实例映射 | 用模拟器进程实际监听的 HDC 端口核对实例名，不按历史 5555 / 5557 推断；两台均通过模拟器 CLI 启动，未控制电脑桌面 |
| 账号服务 | 本机自建 HTTPS / SQLite，端口 18443；两端各有一条 HDC reverse port，访问同一证书与数据库 |
| 服务规则 | 服务直接导入工程 `ArchiveDomain.ts`、`AccountSync.ts` 的当前源码；本轮启动于 22:09，未再修改领域代码 |
| 测试账号 | `prepare-account-test.mjs` 生成一次随机 fixture，运行编号 `1792247956642_b761c44d`，A/B 共用；凭证只在忽略目录与测试资源，不写入文档、截图或主包 |
| 主包 | SHA-256 `C6CB8C4B467958E59C84460983D1DC5489548DF4108F30087FDF347313510AD2`（本轮未改主包源码，重新构建后的实际安装包；不沿用第22节旧哈希） |
| 测试包 | SHA-256 `1B1E9B548D29B9E19B2DD4B19A3582E6E0C4E32A4E3E5B9F99A772C8A59514FD`，包含 `MemorySync.test.ets` 与 `DemoRehearsal.test.ets` |
| 测试源码 | `MemorySync.test.ets` SHA-256 `700239081B9019016362175856D6EFDCBB95CDEC6F6B332980A73688DE81694F` |

两包先构建、再安装到两端；`device-test.ps1` 的源码更新时间检查通过，设备结果绑定上表实际安装包。A/B 各用独立测试库 `yunheji_test_ui_<run>_a` 与 `_b` 派生自己的账号库；A 阶段结束保留库，B 完成后才清理。

实际执行顺序（串行，同一 fixture）：`MemorySyncTest#device_a_publish_kiln_memory`（A，5555）→ `MemorySyncTest#device_b_receive_preview_and_replay`（B，5557）→ `DemoRehearsalTest#rehearsal_a_main_line`（A）→ 两端 `MemorySyncTest#cleanup_only_this_run_test_preferences`。A 阶段 `session.run(action, true)` 只 stop 不 dispose，保留账号库供 B 读取；B 阶段同样保留到排练结束后统一清理，避免 A 结束时删除 B 的前置记录。

更早一轮测试包与旧 fixture 上的 A/B 通过（[222134](test-results/2026-10-17-222134-device.log)、[222402](test-results/2026-10-17-222402-device.log)）和排练通过（[223433](test-results/2026-10-17-223433-device.log)）保留为旧包阶段结论，不与最终同包结果累计；最终结果均来自上表实际安装包。

### 23.2 A 端真实发布

| 验证 | 结果 |
|---|---|
| A 端核心路径 | **1/1**，Failure=0，Error=0，Ignore=0，159100ms，[2026-10-17-223959-device.log](test-results/2026-10-17-223959-device.log) |
| 初始账号 | 真实登录页注册后回读身份，账号库为 0 条；游客记录未混入 |
| 首页主题 | 0/4、“从庙底沟遗址开始”；主题直达详情，仅打开不点亮路线 |
| 观察选择 | 点击“西部陶窑”，部位名、事实正文与画布一致；主动右转后显示“视角 33°” |
| 保存 | 编辑器预览“已重建保存画面”；正文、标签、事实摘录，以及非默认印章“河洛拾遗”、纸色“ochre”真实输入并保存 |
| 磁盘回读 | 清 Preferences 缓存后读到同一条 note，全部字段如下；`note.id` 与 `deviceId` 均为 A 端实际值 |
| 首页刷新 | 最近记忆显示正文与“已重建保存画面”，主题为 1/4，下一处“大河村遗址” |
| 同步 | A 端账号面板显示“上次同步已完成”；未生成固定时延或“秒传”文案 |

A 端保存并回读的 note（原始 hilog `T11_A_SAVED`）：

```
id=note:1680f34b-549d-4c45-bf90-42814c9e1079:1792248130205
kind=note, siteId=smx-miaodigou, updatedAt=1792248130205, deviceId=1680f34b-…
deleted=false
body=在陶窑与居住遗存之间，记下我对庙底沟西部空间关系的观察。
tags=[庙底沟, 陶窑, 空间观察, 跨端样板1792247956642_b761c44d]
quotedPoemOrFact=制作陶器的陶窑集中分布在遗址西部。居住遗存与陶窑都涉及西部，不能把它们画成互不重叠的两个功能区。
stampType=河洛拾遗, paperTheme=ochre
snapshot3DPose={version:1, sceneType:relic_inspector, yaw:0.5726990816987241, pitch:0.77, zoom:0.99,
  hotspotId:kilns, sectionId:'', label:西部陶窑 · 33°, proceduralPreset:miaodigou_pottery,
  sceneRevision:2, rendererProfile:native-raster-v1,
  viewFrame:{width:294.85714285714283, height:300, textDensity:3.5, dark:false}}
```

### 23.3 B 端接收、预览与回放

| 验证 | 结果 |
|---|---|
| B 端核心路径 | **1/1**，Failure=0，Error=0，Ignore=0，104368ms，[2026-10-17-224249-device.log](test-results/2026-10-17-224249-device.log) |
| 接收前 | 登录前按服务端身份定位 B 自己的独立库，确认为 0 条（`T11_B_PRECONDITION`）；不是本地已有或测试注入 |
| 接收 | 真实登录触发的首次交换后，测试首次回读磁盘即已可见同一条 note；`T11_B_TIMING` 的 3ms 是测试回读差值，不是传输耗时，也不代表整个演示链路时延 |
| 记录身份 | 与 A 完全相同的 note ID 和 `updatedAt`；`record.deviceId` 保留 A 的 `1680f34b-…`，B 快照自身为 `cde58b28-…` |
| 用户内容 / 装饰 | 正文、四个标签、事实摘录、印章、纸色逐字段一致；标签中的本轮标记只用于区分合成记录 |
| 视角与场景 | `kilns / '' / 西部陶窑 · 33° / miaodigou_pottery / 2 / native-raster-v1` 与 A 一致 |
| 相机 | 磁盘值 `yaw=0.5726990816987241, pitch=0.77, zoom=0.99`；`MEMORY_REPLAY_FRAME` 中实际绘制值相同，未被默认镜头或自动转动覆盖 |
| 原取景 | `viewFrame` 两端完全一致；B 首页 124vp 预览按该画幅 contain，状态“已重建保存画面” |
| 首页 | 真实 1/4、“下一处 · 大河村遗址”、同一正文与预览 |
| 正式回放 | 点击预览 Canvas 进入详情，等待实际绘制回调后显示“已回到手账视角”；选中部位仍为“西部陶窑”，事实正文一致；再右转一步得到保存角度 +45°（55°） |
| 回读确认 | 回放后再次从 B 独立库读到同一 note ID；记录数 2（note + 浏览记录） |

### 23.4 跨端画面与字段核对

同次 `dumpLayout` 的真实 Canvas 边界：A 保存前为 `[112,865]–[1144,1915]`，B 回放为 `[112,1071]–[1144,2121]`，均为 **1032×1050**。逐像素结果：

| 核对 | 结果 |
|---|---|
| 整幅 Canvas 变化像素 | **0** / 1083600 |
| 最大通道差 / 平均绝对通道差 | **0 / 0** |
| 模型区域 | 两端均为 **390753 像素**且完全一致（以 `#FAF6F0` 为背景、最大通道差大于 10 计为模型区域） |
| 两端首页 124vp 预览 | 1054×434，**0 像素差异** |
| 预览按原画幅 contain 后与保存画面重建比较 | RGB 相关系数 **0.9884491801945107**，平均绝对通道差 **0.7763191645024294**（缩放重采样差异） |

完整数值见[像素核对](design/memory-sync/pixel-checks.json)，差异图全白即零差异；原图、布局与包绑定见[双端图集](design/memory-sync/README.md)及[阶段清单](test-results/2026-10-17-memory-sync-phases.json)。

### 23.5 T12：本轮主线未发现产品级阻塞

本轮沿 T11 路径逐项核对任务书列出的风险，**没有修改任何主包源码**：

- 账号服务未加载新解析规则：服务启动时直接导入工程当前领域源码，B 端完整收到手账可选字段，未观察到字段丢失。
- 同步响应未落盘 / 合并省略元数据：B 端磁盘回读与 A 端逐字段一致，记录身份和装饰字段保留。
- 首页未刷新：A/B 首页均显示真实 1/4、正文和原画幅预览。
- 跳转丢失 pose / B 端场景版本失配 / 预览空白：B 端实际绘制值为保存值，预览与回放均非空。
- 相机被默认镜头覆盖：回放后再次右转得到保存角度 +45°，说明恢复值参与后续操作。

三次中间失败均属**测试定位或调用顺序**，已按实际版本保留，不累计为通过：`221626` 在 UI 注册前调用账号 API 回读身份（`ACCOUNT_INVALID_CREDENTIALS`）；`221707` 个人页“最近账号同步”明细行位于三条路线之后，滚动未暴露（改为读取同页顶部账号面板“上次同步已完成”）；`223154` 对照维度按钮不在 `material-comparison-scroll` 滚动内容内（改为直接点击固定头部）。记录见[中间清单](test-results/2026-10-17-memory-sync-intermediate.json)。

### 23.6 T13.1 主线排练与录像状态

设备排练 `DemoRehearsalTest#rehearsal_a_main_line` **1/1**，Failure / Error / Ignore 均为 0，219088ms，[2026-10-17-224447-device.log](test-results/2026-10-17-224447-device.log)。用例只操作正式页面：主题直达、西部陶窑、主动右转、文明连线对照并展开一处馆方依据、返回庙底沟保存手账、首页最新记忆、A 端正式回放。分段累计（原始 `DEMO_SEGMENT`）：

| 分段 | 累计耗时 | 段内耗时 |
|---|---|---|
| 首页就绪 | 2551ms | 2.6s |
| 观察（主题 → 陶窑 → 右转 → 取景截图） | 32587ms | 30.0s |
| 对照（返回 → 文明连线 → 对照 → 展开依据 → 返回首页） | 72215ms | 39.6s |
| 保存（再入庙底沟 → 陶窑右转 → 输入 → 保存 → 回读） | 170342ms | 98.1s |
| 首页最新记忆与 A 端正式回放 | 207663ms | 37.3s |

这 **207.7 秒**是 UiTest 逐步定位、稳定等待、截图与 `dumpLayout` 的自动化操作耗时，**不能当作真人三分钟计时**。真人演示的观察与对照更短，保存输入也由人直接完成；但本轮没有真人讲述排练，不能据此宣布“完整主线不超过 180 秒”。T13.1 只交付脚本与实测操作记录，T13 整体不标完成。

录像方面用户已明确本轮不需要代理录制。此前对本机 `media.createAVScreenCaptureRecorder` 的短探针能创建、初始化并调用开始录制，但随后出现系统隐私授权窗口，未取得内容（输出文件为 0 字节），因此没有继续用于交付；探针文件与日志只留在忽略目录，不作为录像或截图证据。

### 23.7 清理与边界

两端 `MemorySyncTest#cleanup_only_this_run_test_preferences` 各 **1/1**（[A](test-results/2026-10-17-224846-device.log)、[B](test-results/2026-10-17-224859-device.log)），只删除本轮 `yunheji_test_ui_*` 独立库，未枚举正式档案或清空服务数据库；两台模拟器保留原数据，结束后正常启动应用并恢复熄屏覆盖。旧尝试的测试库按精确运行编号在设备侧删除，未触及其他轮次或正式库。

本轮结论只覆盖这一条双端样板与 A 段主线排练：不覆盖三处对象全部组合、旧账号八阶段、真机、GPU / WebGL2、冷启动会话恢复、双向编辑或生产治理。传输继续称 HTTPS 同账号同步，不称华为账号、鸿蒙分布式 KV 或多人协作；模型为程序化学习示意，文化内容仍为“初稿待校审”。

## 24. 首页 UI 与布局改版（2026-10-17）

用户明确表示此前版本更满意，要求恢复并整体优化首页；本轮据此改回“沙盘 / 纸页入口 / 城市索引 / 检索分区”的丰富结构，同时保留主题直达与最近真实记忆。没有新增字段、schema、平台材质或伪同步逻辑。

### 24.1 改版内容

- 标题区恢复大标题、河迹眉题与一句副题。
- “此刻主题”收敛为一张主题卡：四节点真实进度圆点、进度文字、下一处内容与“去观察”；插画用两层实色纸片，不使用阴影或渐变冒充官方材质。
- 最近记忆：有手账时显示遗址、印章、时令、原画幅预览、正文、最多三个标签与“重返观察 / 阅读全文”；无记录时改为紧凑引导行，不再用大空卡占据首屏。
- 恢复五城河洛沙盘、文明连线、黄河寻迹漫游、纸质入口（从彩陶读起 / 河流记忆 / 随身档案，含贴纸与真实跳转）与五城索引。
- 纸页入口强化层次：贴纸改为白色厚描边、彩色贴纸、轻微旋转并半凸出卡片边缘；三张纸卡下垫 `surface_sunken` 暖灰底纸，只露右下边缘。全部使用实色叠放，不使用阴影或渐变。
- 配色收紧：主玫瑰色 `#C45A6A → #B24C5E`，小字灰棕 `#96847B → #7D6A60`，深色 `tertiary` `#85756C → #A08E83`，提高按钮白字与小字说明的对比度；暖白纸感、玫瑰主色与浅蓝 / 浅绿 / 浅黄分区色保留。
- 检索、城市 / 年代 / 类型筛选、结果数与重置收进同一张“检索档案”卡片；档案网格与“循迹而行”保留。
- 所有既有自动化 id 保留；`memory-entry`、`featured-site` 随卡片下移，相关旧用例改为在真实 Scroll 中滚动定位后再点击，业务断言未删改。

### 24.2 验证结果

| 验证 | 结果 | 原始输出 |
|---|---|---|
| 本地逻辑 / 仓库与报告解析 | **95/95、9/9** | [本地](test-results/2026-10-17-home-redesign-local-test.log) |
| 主包 | BUILD SUCCESSFUL | [构建](test-results/2026-10-17-home-redesign-main-build.log) |
| 测试包 | BUILD SUCCESSFUL | [构建](test-results/2026-10-17-home-redesign-test-build.log) |
| 改版后首页核心路径 | **1/1**，Failure / Error / Ignore=0，203638ms | [2026-10-17-234825-device.log](test-results/2026-10-17-234825-device.log) |

核心路径覆盖主题直达、空态、真实保存、首页最新记忆与 1/4、124vp 原画幅预览、点击正式回放和完整四节点。截图与布局见[首页改版图集](design/home-redesign/README.md)，包 / 源码 / 报告绑定见[阶段清单](test-results/2026-10-17-home-redesign-phases.json)。

主包 SHA-256：`935E945F1A438ECD4454328B95D7A8683FC048647E4CD24EF94643AC1E735BAE`；测试包：`13222779FBE8945F6473A198736A238B7934B7C2C947E90087A159EF30798BA4`。

### 24.3 中间记录与边界

[中间清单](test-results/2026-10-17-home-redesign-intermediate.json)保留首版改版通过及旧套件的失败，均不累计到最终 1/1：

- `231128` 首版改版首页 **1/1**，213669ms；之后又调整卡片高度、纸页入口和检索文案，不绑定最终包。
- `231555`、`231809`、`232051` 为外观套件在改版后暴露的旧假设：入口移出首屏、详情首写手账在首屏外、记忆页筛选在首屏外。分别改为按真实 Scroll 定位后复跑，断言不变。
- `232416` 外观套件超时 **0/1 Error=1，execute timeout 240000ms**：外观 / 深色 / 大字 / 重启与新增滚动合计超过单用例上限。未提高超时、未删除断言，也不再作为本轮验收。
- `232846` 登录 / 注册套件 **0/1 Error=1**：大学资料按产品设计仅保留本次会话，退出重登后个人页不再显示该行，旧用例仍期待其存在。未改产品，不计通过。

本轮首页截图来自实际设备；深色模式已查看，但深色截图为贴纸 / 底纸强化前拍摄，强化沿用 `surface / sunken` 语义令牌、没有新增硬编码颜色。大字模式未完成同套件复验。T11 双端同步结果为改版前首页布局，账号同步与 B 端接收逻辑未改，本轮没有重跑双端；因此不把“T11 新包双端复验”写成已完成。

## 25. AI 观察导览与 AI 辅助手账（2026-10-18）

用户提供 DeepSeek 密钥与 `https://api.deepseek.com` 后，本轮把真实模型接入杜岭二号方鼎观察路径，完成服务端 `/ai/observe`、原生 AI 面板、聚焦 / 依据、AI 草稿与 `aiAssist` 元数据，以及同账号 A/B 手工重访。实现和配置见[AI_OBSERVATION.md](AI_OBSERVATION.md)，图集见[design/ai-observation](design/ai-observation/README.md)，小样见[评估记录](test-results/2026-10-18-ai-observation-evaluation.md)。

### 25.1 实现范围

- 对象 / 场景：只对 `zz-duling-fangding / duling_fangding / revision 2` 开放，热点 `centers / corners / frame`；事实继续读 `MaterialStudyCatalog` 的三条方鼎条目。
- 模型：DeepSeek `deepseek-flash`，OpenAI 兼容 `POST /chat/completions`，强制函数调用 `submit_observation`，关闭思考模式，服务端超时 20 秒。
- 客户端：AI 请求读超时 25 秒；停止等待时销毁真实 HTTP 请求；迟到回复按请求 ID、对象、场景修订和资料修订拦截。
- 数据：`kind: 'note'` 上新增可选 `aiAssist`，冻结 `question / factIds / contentRevision / facts`；旧普通笔记不补字段，编辑保留，删除保留墓碑。
- 首页：新增“本期观察 · AI 导览”入口；原主题下一节点、最近记忆、普通手账和路线点亮规则保留。
- 首页进入方鼎后自动把 AI 面板带入视野；回答到达不自动转镜头、不自动保存。

### 25.2 本地、服务与构建

| 验证 | 结果 | 原始输出 |
|---|---|---|
| 本地逻辑 / 仓库 / AI 领域测试 | **103/103** | [2026-10-18-ai-observation-local-test.log](test-results/2026-10-18-ai-observation-local-test.log) |
| 设备报告解析 | **9/9** | 同一本地输出 |
| 主包构建 | `BUILD SUCCESSFUL` | [2026-10-18-ai-observation-main-build.log](test-results/2026-10-18-ai-observation-main-build.log) |
| 测试包构建 | `BUILD SUCCESSFUL` | [2026-10-18-ai-observation-test-build.log](test-results/2026-10-18-ai-observation-test-build.log) |
| AI 服务契约测试 | **9/9** | [2026-10-18-ai-observation-service-test.log](test-results/2026-10-18-ai-observation-service-test.log) |
| 账号 / 同步服务回归 | **1/1** | [2026-10-18-ai-account-service-test.log](test-results/2026-10-18-ai-account-service-test.log) |

AI 服务测试覆盖：未配置时 `AI_NOT_CONFIGURED`、草稿空观察不调用模型、函数调用参数与系统资料、非法事实 / 动作整条拒绝、超时 / 429 / 供应商错误、跨对象请求拒绝、提示词包含三条事实和资料边界。账号服务回归确认新增 `/ai/observe` 路由后原有注册、登录、同步、冲突、墓碑和会话撤销仍通过。

主包 SHA-256：`C8E2BF6CE8F251E55D4BFB9357D42529CF8A37CAB76606708FB3D9DB67ADDA21`（2,641,712 字节）。设备回归所用测试包：`B6437F95CBD42192D0109F411207276C9168DC608CB5535852582F50DAA4D6EF`（2,902,002 字节），与最终主包同轮重建。A 端手工截图拍摄于重新打包前的主包 `C132F7FB…`；源码差异仅为一次注释增删回退，功能与最终主包相同。

### 25.3 真实模型固定小样

9 条固定问法全部 HTTP 200 且通过应用契约校验，单次 1883—2409 ms。逐条输入、回答、引用、动作、草稿和人工判定见[评估记录](test-results/2026-10-18-ai-observation-evaluation.md)，原始响应见[JSON](test-results/2026-10-18-ai-observation-evaluation.json)。

人工核对结论：9/9 未发现资料事实被改写、来源被编造或动作越界；第 5、6、9 条在资料不足时如实说明；第 3 条使用前文语境；第 7 条草稿保留用户原意。第 6 条“简单说：不知道”措辞偏硬，但未增加新事实，登记为文案可改进项。

保留失败：第一版 JSON 文本模式在多轮追问上连续 6 次返回空白；关闭 `thinking` 字段后仍 2/4 空白。改为强制函数调用后同一问法 4/4、固定小样 9/9。应用仍对函数参数做完整校验，不把“结构可解析”当成语义正确。

### 25.4 A 端手工主线

设备 A `Pura 90 Pro`（`127.0.0.1:5555`），HarmonyOS 7.0.0.107 / API 26，1256×2760，density 560。只使用 HDC / UiTest / 模拟器 CLI，不控制电脑桌面。一次性随机测试账号，已退出；报告不写账号、密码或密钥。

实际步骤与结果：

1. 首页出现“本期观察 · AI 导览”卡；点击“陪我观察”打开方鼎，面板自动进入视野，模型和原热点按钮保留。
2. 输入“我只看到四个，带我看看另外几个。”，约 2 秒内显示“AI 参考解读”，引用 `duling-eight`。
3. 点击“看四个折角”，原生模型转到折角视角，标签显示“四个折角”，状态“已聚焦 · 四个折角”；随后点击“看乳钉边框”也实际转到 `frame`。
4. 点击“查看依据”，原地展开“四面正中，加上四个折角”事实、河南博物院来源和核验日期 `2026-10-17`。
5. 写一句“我先数到四个正面的兽面，转到折角才明白另外四组在哪里。”，请求草稿；草稿保留原意并给出 3 个标签。
6. 点击“采纳并编辑”，视口回传 `hotspotId=frame / yaw=0.5 / pitch=0.42 / zoom=1 / label=乳钉边框 · 29° / sceneRevision=2 / viewFrame=294.857…×300 / textDensity=3.5 / dark=false`，编辑器显示 AI 草稿徽标和资料摘录。
7. 保存后，服务端数据库回读到 `aiAssist.version=1`、`question=我只看到四个，带我看看另外几个。`、`factIds=["duling-eight"]`、`contentRevision=1`、冻结事实 `duling-eight`、来源 `museum-duling-two`，以及上述实际相机和原画幅。

A/B 字段映射、包哈希和复现记录见[AB 记录](test-results/2026-10-18-ai-observation-ab-record.json)。

### 25.5 B 端同账号重访

设备 B `YunhejiSyncB`（`127.0.0.1:5557`），同系统 / 分辨率 / density，重新安装最终主包 `C8E2BF6C…` 后登录。B 使用同一随机测试账号，未重新请求模型；通过 HTTPS 收到 A 的记录后：

- 首页“最近记忆”显示杜岭二号方鼎、预览“乳钉边框”视角、“AI 辅助整理 · 依据资料 v1”、三个标签和“重返观察 / 阅读全文”。
- 点击“重返观察”后详情显示“已回到手账视角”，模型回到乳钉边框视角，热点标签和页面文案一致。
- 本轮没有做整屏像素对比；AI 文本区不属于 Canvas，只核对了保存参数、页面文案和实际画面观感。

A/B 图集见[design/ai-observation](design/ai-observation/README.md)。B 端字段、预览和回放来自真实记录，不是页面内预置示例。

### 25.6 方鼎观察回归

`ExpandedObservationTest#native_duling_observe_save_gallery_replay` 在最终主包和回归测试包上 **1/1**，Failure / Error / Ignore 均为 0，**219882 ms**，原始报告 [2026-10-18-013028-device.log](test-results/2026-10-18-013028-device.log)。该用例覆盖方鼎三部位、主动右转、真实保存、磁盘回读、画廊预览和正式回放，用来确认新增 AI 面板没有破坏原观察 / 手账路径。它不是 AI 面板自动化。

### 25.7 保留失败与工具修正

- **JSON 文本模式空内容**：多轮追问连续 6 次空白，关闭 `thinking` 后仍 2/4 空白；改为强制函数调用。最终 9/9 不能写成首次成功。
- **首次 AI 固定小样**：第 3、6 条因空内容 502，第 7 条因测试脚本把空回答放入 `turns` 被 400 拒绝；修正调用方式和脚本后重跑。早期失败未写入最终 JSON 的 `results`，在评估记录中单独保留。
- **ArkTS 编译错误**：`AccountSyncClient` 的 `throw error` 触发 `arkts-limited-throw`；改为只抛出规范化后的 `Error`。
- **手工操作偏差**：一次按错坐标点到“看乳钉边框”而非“查看依据”，一次点到保存按钮下缘；按真实 bounds 重新操作。不是产品断言，也不计入通过数。
- **重新打包**：更早一次方鼎回归在重新打包前主包 `C132F7FB…` 上 **1/1**（[011716](test-results/2026-10-18-011716-device.log)，219773ms）；最终主包 `C8E2BF…` 再次 **1/1**（[013028](test-results/2026-10-18-013028-device.log)，219882ms）。两次不累计为两项；A 端手工截图对应前者，B 端接收 / 回放对应最终主包，源码差异仅为一次注释增删回退。
- **`tools/build.ps1`**：Windows PowerShell 5.1 把 hvigor 的 ArkTS 警告 stderr 当成终止错误，导致“构建成功但有警告”被误判；改为 `Start-Process` 分别接住 stdout / stderr 并只看真实退出码。编译错误仍会以非 0 退出码失败。
- **`tools/device-test.ps1`**：原先依赖外部 `rg`，且编辑后缺少 UTF-8 BOM 会被 5.1 误读；改为 `Get-ChildItem` 枚举源文件并保存为带 BOM 的 UTF-8。两处只修正工具可执行性，没有改应用业务断言。

### 25.8 边界与未完成

- 只有方鼎一个对象；没有扩展大河村、庙底沟或其他条目。
- A/B 是手工设备路径；没有新增 AI 专用 Hypium 自动化，也没有跑完整双端账号八阶段。
- 没有在设备上注入未配置、超时、供应商 500 / 429、余额不足等故障；这些状态由服务测试和代码路径覆盖。
- 没有真人三分钟计时与录像；模型单次耗时不能替代现场总时长。T13 录像继续未完成。
- 没有公网 / release 配置、华为账号、分布式 KV/RDB、真机 / 平板 / 横屏 / 分屏 / 大字矩阵验收。
- 文化内容仍为“初稿待校审”；AI 不替代馆方原文、人工校审或实物测绘。不能把本轮 9/9 宣传成“零幻觉”或全目录可靠。

## 26. UI/UX 改版：减少臃肿与开发残文（2026-10-18）

用户反馈：首页内容多但尚可，其他页面毛坯、功能不明确；仍有“演示 / 示例 / 预留 / 主题示意 / 时令近似”等开发文案；视角按钮多余；五城河洛沙盘粗糙、卡顿且点击无反馈。本轮据此做结构性清理，不改数据格式、不扩展城市与路线、不换引擎。

### 26.1 主要改动

- **首页**：去掉常驻“初稿待校审”徽标；纸页入口保持三张纸片 + 贴纸；移除“循迹而行”推荐列表；“最近记忆”改为左侧缩略画面 + 右侧摘要，只保留一个主操作；旧文字手记不再显示空预览。
- **五城河洛**：地形从 36×8 网格降到 24×4 + 24×2，去掉五根城市细柱，增加河岸和水线；河谷默认不自动重绘；画布内不再排文字标签，城市选择改为下方五个原生按钮；点击城市后标题、选中圆点、按钮、档案数量、“查看档案”入口和提示同步变化。沙盘不再放左转 / 右转 / 复位 / 自动按钮，拖动和双指缩放是唯一视角操作；画布底部加一条很轻的“西—东”方位线。
- **详情**：四个整行视角按钮改为画布右下角小图标胶囊；初始提示只保留“拖动旋转 · 双指缩放”；位置关系说明缩短；完整图注 / 资料边界 / 审核状态收进行内“资料说明”；游客 AI 面板默认收起。
- **AI 面板**：有 `show_evidence` 动作时隐藏重复的“查看本次依据”按钮；移除“本次已进行 N 轮”和长免责声明；草稿提示缩短。
- **记忆**：手账卡去掉空白视角占位、重复按钮和“留在个人记忆里”等开发文案；AI 辅助缩成标题旁小标记；正文 / 摘录限制行数；默认改为列表，画廊保留大画面。
- **档案**：把本地存储 / 数据格式 / 已浏览的技术状态页改为真正的“文化档案”库：离线状态、城市筛选、20 处档案网格；技术项移到“我的”。
- **我的**：账号卡文案缩短，时间改为 24 小时制；去掉冲突版本、原生开发版、内容状态等开发行；新增顶部“资料说明”入口和统一说明卡；账号同步 / 显示效果仍保留必要状态。
- **登录**：删除“学习档案 / 选填·预留 / 教育计划尚未开放”整段占位；不再收集学校或学号。
- **统一文案**：新增“资料说明”集中承载文化内容状态、图像 / 模型边界、AI 参考解读和数据边界；主页面不再重复“初稿待校审 / 主题示意 / 非实物复原 / 时令近似”。

### 26.2 性能与交互修正

- 河谷网格从约 354 个面（含城市方柱）降到 216 个面，并取消河谷自动 20fps 重绘；主页不再为静态沙盘持续刷新。
- `rememberView` 不再要求画布当前完全可见；用户滚到“留住此刻”时，即使画布只剩一部分，仍能读取当前相机并打开编辑器。此前该条件会导致按钮点击后无反应。
- 城市点击增加原生反馈：选中节点放大变玫瑰色、城市按钮高亮、标题显示城市、显示档案数量和“查看档案”按钮，并显示轻提示。
- 修复详情第二个 `bindSheet` 覆盖手账编辑器的问题：资料说明改为行内展开，不再与编辑器 Sheet 竞争。

### 26.3 验证

| 验证 | 结果 | 原始输出 |
|---|---|---|
| 本地逻辑 / 仓库 / AI 领域测试 | **103/103** | `.\tools\test.ps1` |
| 设备报告解析 | **9/9** | 同上 |
| 主包构建 | `BUILD SUCCESSFUL` | 本轮两次重打包 |
| 测试包构建 | `BUILD SUCCESSFUL` | 本轮 |
| 首页核心路径 | **1/1**，Failure / Error / Ignore 0，**233042ms** | [2026-10-18-085335-device.log](test-results/2026-10-18-085335-device.log) |
| 方鼎观察 / 保存 / 回放 | **1/1**，Failure / Error / Ignore 0，**190017ms** | [2026-10-18-085741-device.log](test-results/2026-10-18-085741-device.log) |

两条设备用例在最终包上通过；未重跑完整 UI 套件，不能把这两条结果说成全量复验。

最终主包 SHA-256：`0E8561656A2B326BF0E6A4626A88D3C0E094896C71E6D21B3977CD04CA374BA7`（2,616,537 字节）；测试包：`78191312FAB0C42145D93E07DEE67FE1B108CC9D8CDA6A4EEEC141D7F17B8021`（2,896,518 字节）。

### 26.4 测试适配与保留失败

- `HomeExperience` 首次重跑失败于 `note-editor-scroll`：并非编辑器缺失，而是新增第二个 `bindSheet` 覆盖了手账编辑器；改为行内资料说明后复跑通过。第二次失败于首页正文不在可视树，原因是最近记忆卡过高；改为横向摘要后通过。两次失败日志保留在 `docs/test-results/2026-10-18-022630-device.log`、`2026-10-18-022845-device.log`、`2026-10-18-023055-device.log`，不计通过。
- `ProfileLogin` 测试删除教育占位引用；`ArchiveImmersive` 页尾断言改为新的“— 五城二十处 · 沿河而读 —”；`ExpandedObservation` / `HomeExperience` / `MemorySync` / `DemoRehearsal` / `ObservationMemory` 的手账预览状态文案由“已重建保存画面”改为“已恢复当时视角”。
- 本地 `memory-journal.test.mjs` 的时令标签期望由“寒露 · 时令近似”改为“寒露”。
- 未重跑：`ProfileLogin`、`ArchiveImmersive`、`ArchiveAppearance`、`MaterialComparison`、`CoreContent`、`MemoryJourney` 等完整套件；本轮只跑首页与方鼎两条核心路径，不能宣称全套通过。

### 26.5 边界与未完成

- “我的”页三张主题路线卡仍然很长；详情事实正文仍占较多纵向空间；档案页城市筛选、深色 / 大字 / 真机 / 平板矩阵未重跑。
- 五城沙盘仍为程序化 Canvas 示意，不是测绘地形；城市点击反馈已做，但未补整屏像素对比或真实地图参照。
- 资料说明集中化后，仍保留“初稿待校审”与图像边界；没有删除必要的内容合规说明，也没有把 AI 回答升级为馆方原文。
- 本轮没有 Git 提交 / 推送、没有更换签名、没有改数据格式或清空用户档案。

## 27. 页面功能、层级与 AI 重访（2026-10-18）

用户要求检查各页面功能和层级，重点改善记忆、档案、我的，以及 AI 在页面中的体现。本轮按实际操作路径重整上述页面，完成原生设备定向验证。各页职责、下一阶段任务见[PAGE_HIERARCHY.md](PAGE_HIERARCHY.md)，15 张原生画面见[页面图集](design/page-hierarchy/README.md)。

### 27.1 主要实现

- **记忆**：手账 / 收藏分区；搜索手账正文、标签与曾经的问题，AI 手账筛选、列表 / 画廊；明确区分读手账、重温与问 AI。
- **手账详情**：按记录 ID 读取当前快照；显示全文、标签、保存视角、资料摘录、原问题和保存时冻结的事实；支持编辑、回放、原档案和带墓碑删除。编辑返回时按更新时间重建内容，修复已落盘但仍显示旧正文的问题。
- **档案**：关键词、城市、年代、类型的组合筛选、结果数、重置、空状态；“可 AI 观察”只返回当前真实支持的方鼎；入口直接打开其观察面板。
- **我的**：只显示账号概况、真实手账数、AI 手账数和菜单；主题漫游、账号与同步、阅读偏好、关于进入二级页；去掉关于页的重复标题。
- **AI 重访**：从本篇手账预填问题与个人观察；超过 300 字时提示范围，原文完整保留；用户提交后才发送，本次请求不包含整库记录。服务端明确区分个人表达与资料事实。
- **AI 动作反馈**：聚焦后模型和反馈可见；继续追问回到当前面板；捕获延迟焦点请求的系统异常，避免快速离开时进程退出。增加个人观察输入框高度。

### 27.2 本地测试与构建

| 检查 | 结果 | 原始输出 |
|---|---|---|
| `.\tools\test.ps1` | **103/103** | [本地测试](test-results/2026-10-18-page-hierarchy-local-test.log) |
| 设备报告解析 | **9/9** | 同上 |
| `node --test server/ai-observation.test.mjs` | **10/10** | [AI 服务测试](test-results/2026-10-18-page-hierarchy-ai-service-test.log) |
| `.\tools\build.ps1` | `BUILD SUCCESSFUL` | [主包构建](test-results/2026-10-18-page-hierarchy-main-build.log) |
| `.\tools\build.ps1 -Target ohosTest` | `BUILD SUCCESSFUL` | [测试包构建](test-results/2026-10-18-page-hierarchy-test-build.log) |

本地 103 项包括现有领域、存储仓库和 AI 规则；服务 10 项包括新增的“重访只带入本篇个人观察”契约。服务测试使用受控模型替身；真实供应商调用由下述设备路径完成。仍有既有 ArkTS 能力 / 异常提示及未配置签名警告，构建成功不等于真机签名已配置。

日志范围：本地测试文件保存 Node 的标准输出；报告解析 **9/9** 为同次脚本的 `Write-Host` 控制台结果，没有收进该文件。两份构建输出仅把本机工程路径替换为 `<PROJECT_ROOT>`，其余结果保持原样，原始日志另存本机忽略目录。

### 27.3 原生设备结果与包边界

目标：`127.0.0.1:5555`，HarmonyOS 7.0.0.107 / API 26 手机模拟器，1256×2760、density 560。测试使用独立 Preferences，AI 用例通过真实注册页创建合成账号；未清空正式用户档案。

| 用例 | 结果 | 原始报告与版本范围 |
|---|---|---|
| `PageHierarchyTest#library_filters_memory_tabs_and_profile_navigation` | **1/1**，**92641ms** | 最终包，与下一项合组；[114604](test-results/2026-10-18-114604-device.log) |
| `PageHierarchyTest#real_ai_focus_save_and_resume_from_memory` | **1/1**，**176619ms** | 最终包；同一份报告合计 **2/2**、269260ms |
| `PageHierarchyTest#memory_fulltext_edit_replay_search_and_tombstone` | **1/1**，**99713ms** | 本轮手账修复包；[111850](test-results/2026-10-18-111850-device.log)；之后仅调整关于标题、AI 观察输入框高度和延迟焦点异常保护，未在最终包重跑此条 |

以上完整报告的 **Failure / Error / Ignore 均为 0**。同项中间通过与最终复验不累计为新增用例数。

第一项覆盖记忆空态与收藏分区、20 / 1 / 0 处筛选结果、重置、关键词检索、游客 AI 状态、返回保留筛选、我的概览 / 二级页、偏好实际落盘及 AI 手账筛选入口。第二项调用已配置的真实 DeepSeek 服务，覆盖回答、四个折角聚焦、完整画布可见、继续追问、个人观察 → AI 草稿 → 用户采纳 → 真实落盘，核对 `aiAssist` 与 `corners` 相机参数；随后在记忆中展开保存时依据、带入原问题和本篇正文，核对进入时没有伪造回答。

重访用例验证到问题 / 正文预填并可提交，没有自动再发一次重访请求；该请求拼装另由服务契约测试验证。不能把它写成已完成另一轮自由追问的设备验收。第三项核对长正文全文、同 ID 全文替换、磁盘与返回后的显示一致、原视角不丢、正式回放、空搜索恢复、删除墓碑及相机参数保留。

最终主包 SHA-256：`B88D1ACA32FFD56ECC35CA7EA93FB405CC206EC1CFA1C927DBFCCC593CB4ABC4`（2,787,007 字节）；最终测试包：`4059EA160F9F589471273F08A2F390FE3C114CA5B37B7CB3C5CB8E0A0A8E5FAA`（2,937,284 字节）。最终包复验前后哈希一致。[阶段清单](test-results/2026-10-18-page-hierarchy-phases.json)绑定当前源码、报告和截图；没有补造早期通过包未采集的哈希。

### 27.4 失败与修复记录

| 报告 | 当时结果 | 原因与处理 |
|---|---|---|
| [104654](test-results/2026-10-18-104654-device.log) | 页面层级阶段 **1/1**，80835ms | 后续修改后在最终包复验为 92641ms；不重复计数 |
| [104925](test-results/2026-10-18-104925-device.log) | **0/1**，Error 1，49850ms | 输入后按返回再保存，编辑器未关闭；用例改为直接点击固定保存按钮，覆盖键盘仍显示的保存路径；当时截图保留 |
| [105404](test-results/2026-10-18-105404-device.log) | **0/1**，Error 1，83925ms | 检出编辑返回的旧正文；同时普通 `inputText` 只改写前段。改用真实键盘全选删除，并明确断言全正文替换 |
| [110251](test-results/2026-10-18-110251-device.log) | **0/1**，Error 1，62132ms | 全选清空辅助方法等待屏外“0 / 4000”不可达；改为核对输入框本身为空 |
| [110722](test-results/2026-10-18-110722-device.log) / [111337](test-results/2026-10-18-111337-device.log) | 各 **0/1**，Error 1，69394 / 76986ms | 已取到最新记录，但 ArkUI Builder 仍保留旧内容；以 `id:updatedAt` 重建内容区域。111850 完整路径随后通过 |
| [112234](test-results/2026-10-18-112234-device.log) | **无完整结束摘要，App died** | 延迟 `requestFocus` 抛出 150002“祖先不可聚焦”。对便捷焦点请求捕获异常并检查页面状态；[崩溃摘要](test-results/2026-10-18-page-hierarchy-crash-summary.txt)保留关键堆栈 |
| [112950](test-results/2026-10-18-112950-device.log) | 真实 AI **1/1**，171226ms | 焦点修复后通过；后续增高观察输入框后在最终包再次通过（114604），不累计为两项 |

用于定位正文旧值的临时日志已从源码删除；未在业务日志输出个人手账正文。失败 JSON / PNG 保留为定位证据，不混入最终图集。

### 27.5 截图与覆盖限制

- 最终图集 12 张来自 114604 两项专项：记忆空态、档案、档案空态、游客 AI、我的、主题漫游、偏好、关于、AI 聚焦、AI 手账筛选、冻结依据与预填重访；另 3 张手账全文 / 列表 / 回放来自 111850 手账修复包。均已目视检查。总览只缩放排列原图，不补画页面。
- 当前包未重跑首页、图谱、对照、完整账号双端及其他全部历史 UI 套件；它们的历史通过不自动成为本轮覆盖。没有开展大字、泛化安全、无关边界或全设备矩阵。
- AI 仍只支持杜岭二号方鼎；尚未覆盖其余 19 处。当前记忆搜索是本地文本匹配，个人统计是数据派生，不称为 AI 语义检索或总结。
- 本轮没有做当前包的双端 AI Hypium、设备端供应商故障注入、真人三分钟计时或录像；此前手工双端记录保持原版本边界。
- 三条主题漫游仍是较长二级页，文化详情的正文仍有压缩空间；已在 PX01—PX05 任务中记录下一阶段建议。
- 未改变笔记 schema、签名配置或文化事实；保留墓碑及旧记录。未提交、推送或发布。

## 28. GitHub 交付前验证（2026-10-18）

用户更新档案正文、实景图片与校赛设计文档后，明确要求提交并推送最终工程。本轮只整理交付、补必要验证及忽略 Office 临时目录，没有改应用功能或签名配置。

- 本地 **103/103**、设备报告解析 **9/9**：[完整输出](test-results/2026-10-18-github-final-local-test.log)，本次收录 `Write-Host` 结果。
- 账号与 AI 服务 **11/11**：[输出](test-results/2026-10-18-github-final-service-test.log)。AI 契约使用受控模型替身，没有重新请求真实供应商。
- 主包与测试包均 `BUILD SUCCESSFUL`：[主包](test-results/2026-10-18-github-final-main-build.log)、[测试包](test-results/2026-10-18-github-final-test-build.log)。保留既有 ArkTS 与未配置签名警告；公开日志只脱敏本机路径。
- 最新内容包 `PageHierarchyTest#library_filters_memory_tabs_and_profile_navigation` **1/1**、**94704ms**，Failure / Error / Ignore 均为 0：[原始报告](test-results/2026-10-18-132037-device.log)。使用手机模拟器和独立 Preferences，覆盖档案筛选、记忆分区、我的层级及偏好落盘。

主包 SHA-256 `EF9FCADB10275DE2438486D6766B8E88FB68B17523EA17C60165649D53488F84`（6,112,301 字节），测试包 `3E52F597A80CFCA6DA81F3E739FEE49724C1C470AC1E08B30F247F8EB1802C5F`（6,252,339 字节）。[快照](test-results/2026-10-18-github-final-snapshot.json)绑定本次包、当前源码及报告；历史阶段清单仍保留各自旧值。

本轮没有重跑完整历史 UI、当前包真实 AI / 双端、真人三分钟计时或录像。完整交付范围见[GitHub 交付记录](GITHUB_DELIVERY.md)。各节“未提交 / 未推送”继续作为对应阶段历史，实际提交状态以 Git 历史为准。

## 29. 全面审查与最新包复核（2026-10-20）

本轮依据用户提供的赛题最低要求，从内容、原生页面、AI、个人记忆、账号传输、离线、推荐、恢复与演示交付全面审查。交付[完整报告](reviews/2026-10-20-competition-audit.md)、[11 项下一阶段任务书](COMPETITION_NEXT_STAGE.md)、[14 张原生画面](reviews/2026-10-20-assets/README.md)与[包/原始结果清单](test-results/2026-10-20-competition-audit.json)。

### 29.1 版本

- 应用业务源码基线 `9103246`，主包 6,395,153 字节，SHA-256 `D7BAEF8FC882E15C21405CC14C577187ABB0D5257222CC393AD237EC5A66CA6C`，整轮未改变。
- 原测试包 6,295,099 字节，SHA-256 `2DE022D4948712BF4B0B3A044DDA5E25BDC8BEAFB58C7B3FB9114C4813C1F333`；修正测试包 6,296,025 字节，SHA-256 `B7F8194E1492F7B165A4AB0A081AED1112B272D2B5C26466656C55323B61B825`。
- 两台 HarmonyOS 7.0.0.107 / API 26 手机模拟器，1256×2760。保留数据 coldboot，使用独立测试库，清理只针对本轮库。

### 29.2 构建与本地

`tools/test.ps1` 113/113、设备报告解析 9/9；账号与 AI 服务契约 13/13。主包与最终测试包均 `BUILD SUCCESSFUL`，仍有 ArkTS 警告与未配置签名提示；未改签名配置。

真实页面 AI 调用 DeepSeek `deepseek-flash`，本轮观察请求 1888ms、草稿 2205ms；只代表这两次实际请求。13 项服务契约含受控模型替身，不把契约结果当成 13 次真实模型调用。

本地完整日志保存在忽略目录 `.local/competition-review-20261020/`，包含首轮和最终构建，不在公开报告附入本机配置、凭证或密钥。

### 29.3 原始设备结果

| 场景 | 结果 | 原始报告 |
|---|---|---|
| 页面首轮 5 项 | **4/5，Failure=0，Error=1，Ignore=0**，473564ms | [224139](test-results/2026-10-20-224139-device.log) |
| 页面层级失败项单独复跑 | **1/1**，113602ms | [225531](test-results/2026-10-20-225531-device.log) |
| 水情入口/页面 | **1/1**，51696ms | [224825](test-results/2026-10-20-224825-device.log) |
| 原生图谱：五城索引选择、对照、返回 | **1/1**，95866ms | [225728](test-results/2026-10-20-225728-3f77b0a3-device.log) |
| A 端新手账：真实注册保存、落盘、预览 | **1/1**，149123ms | [225756](test-results/2026-10-20-225756-dc9971bf-device.log) |
| B 端同账号接收、预览、正式回放 | **1/1**，86843ms | [230112](test-results/2026-10-20-230112-02351f49-device.log) |
| 本轮 A 独立库清理 | **1/1**，10162ms | [230543](test-results/2026-10-20-230543-95807c66-device.log) |
| 本轮 B 独立库清理 | **1/1**，10617ms | [230544](test-results/2026-10-20-230544-f3010eac-device.log) |

表中 1/1 报告的 Failure / Error / Ignore 均为 0。首轮四项通过分别覆盖手账全文/编辑/回放/搜索/墓碑、方鼎真实 AI 聚焦/草稿/保存/重访、双连壶对象化入口及记忆管理/档案状态/我的统计与数据页。原失败项随后单独通过，不改写首轮为整组 5/5。

A/B 仍走独立账号 HTTPS，不代表原生分布式服务。用例核对正文、标签、摘录、印章纸色、部位及相机参数；实际 1032×1050 视口全区域共 1,083,600 像素，4 像素不同、最大通道差 1，位于工具胶囊边缘。见[像素记录](reviews/2026-10-20-assets/memory-pixel-check.json)，不描述为全幅零差异。

### 29.4 失败、定位与验证工具修正

1. 页面首轮第 1 项在“关于”页面切换中复用失效 Widget，报 `NoCandidates`；修正 `ArchiveUiSession.wait()` 为每次采样重新定位，仅重试该瞬态，稳定条件与 30 次上限不变。业务断言保留，单项复跑通过。
2. [旧 CultureAtlas 用例](test-results/2026-10-20-224921-device.log) 为 **0/1、Error=1、40273ms**，仍查询旧 `culture-graph` 和 `culture-node-*`。当前原生图谱由已有 EngineExperience 对应用例复核通过；旧用例与个人专题完整路径仍待适配复验，未改成通过。
3. 首次并行设备测试同秒生成相同日志名，一端文件占用、没有完整报告。该次不计通过；`device-test.ps1` 增加 8 位运行标识，继续保留 `*-device.log` 后缀。之后两端各自有完整原始报告。
4. 双端手账用例的旧同步提示改为固定 `account-sync-state` 与当前“已同步”共同等待；真实磁盘与相机断言不变。
5. 辅助函数初版重抛任意类型触发 ArkTS 编译限制；改为构造 `Error` 后最终测试包构建成功。两次构建记录保留；最终设备复跑使用表中修正测试包。

### 29.5 范围

本轮没有修改业务界面、文化内容与数据格式。尚未验证原生分布式 KV/DataObject、华为账号、账号离线冷启动、完整恢复、平板实机、双连壶 AI 保存与跨端、个人专题最新完整设备路径，以及真人三分钟计时/录像；没有扩展大字体、泛化安全或压力套件。

审查发现龙山/窑址筛选无实际条目、服务只接受调试私有端点、记忆/档案首屏密度与同步语义问题，均作为下一阶段任务，未以本轮验证宣称已修复。未提交、推送或上传比赛平台。

## 30. 账号离线冷启动与原生分布式通道基础（2026-10-21）

用户要求开始下一阶段，并明确没有腾讯云 HTTPS 域名，使用模拟器演示。本轮落实 C01—C03 的首批基础及 C05 的状态准确性，不将整份任务书或原生跨端写成已完成。实现与兼容见[账号恢复与原生通道](ACCOUNT_RESUME_AND_NATIVE_SYNC.md)，实际画面见[四张原生图](design/stage-foundation/README.md)，[阶段清单](test-results/2026-10-21-stage-foundation.json)绑定包、源码、结果与截图。

### 30.1 包与环境

- 主包 **M**：6,462,573 字节，SHA-256 `9AF0483A63AA0425B70253A33B02EC832E8C1B3BABB66B8E42ABF9F5B7AB6AD6`。本节最终冷启动、页面与原生专项共用此主包。
- 测试包 **T1**：6,376,555 字节，SHA-256 `2F4A355DBF27DAAD4AF6AC659BB9CF19831FFA98D933612F014EA94C49F71541`。覆盖五阶段冷启动、B 原生专项、A 首次授权失败轮及后来中断的页面轮。
- 测试包 **T2**：6,377,002 字节，SHA-256 `96844581F8F7E8DF655A7A6E38C3CFE011065E7149401ABBBBED1B2BE6F95A9D`。仅修正真实权限弹窗销毁时的失效节点等待；主包不变，用于 A 原生专项复跑及页面五项分组复验。
- 本节 A/B 依照测试逻辑的目标端口命名：A 为 `127.0.0.1:5555`，B 为 `127.0.0.1:5557`。本轮实际进程/监听端口核对为 A=`YunhejiSyncB`、B=`Pura 90 Pro`，与起始交接摘要中的实例名称对应相反；不要按实例名猜端口。两者均为 HarmonyOS 7.0.0.107 / API 26 手机模拟器、1256×2760、density 560，保留数据启动，不重置系统或正式档案。
- 本机账号 / AI / 水情服务为开发机 HTTPS，经两端 HDC 反向端口访问。没有腾讯云部署、受信任公网域名或平板设备验收。设备报告使用北京时间命名；系统截图时钟并非报告计时来源。

### 30.2 实现与数据边界

1. 本机身份指针与网络会话分离，身份写独立 Preferences，token 只进系统 ASSET。启动按身份打开原账号库；网络授权过期、恢复瞬间到期或重新认证失败不会清除本机档案。服务端 token 仍为 12 小时，到期需要重新登录再使用网络同步及 AI。
2. 新增真实 `distributedKVStore.SingleKVStore` 与 `distributedDeviceManager` 适配，声明并请求 `DISTRIBUTED_DATASYNC`。不可变版本键保存记录各版本，领域 LWW 继续处理时间戳、并列裁决与墓碑；视角、纸色、印章及 AI 冻结事实沿用原记录。
3. Preferences 仍为已确认快照与旧数据回退，不删除旧库，不变更 schema。读取旧快照校验后增量写入 KV；当前没有将新库切换成唯一存储，也没有交付整库迁移或一键恢复。新库失败时旧档案仍可继续。
4. 账号 HTTPS 与原生设备通道分别展示实际状态。HTTPS 的单篇徽标和未确认数量按真实回包版本判断，修复“旧请求晚到，提前把新编辑标成已同步”；原生只有非空且全部成功的 `syncComplete` 更新平台成功时间。
5. 账号、AI、水情统一读取服务配置，支持可选公网受信任 HTTPS origin；不存在公网配置时 debug 继续用本机公开 CA，错误公网配置不静默回退。没有实际域名，本轮未做公网部署验收。

本机 SDK 声明核验日期 2026-10-21，目标 API 26，范围与接口清单见上述实现文档。当前原生页面更新采用前台 5 秒轮询，未订阅 `dataChange`；不能称为已完成实时监听。

### 30.3 本地与构建

| 检查 | 结果 | 原始输出 |
|---|---|---|
| `tools/test.ps1` | **116/116**，失败 / 忽略 0 | [本地测试](test-results/2026-10-21-stage-local-test.log) |
| 设备报告解析 | **9/9** | 同一份完整输出 |
| 账号与 AI 服务契约 | **13/13** | [服务测试](test-results/2026-10-21-stage-service-test.log) |
| 主包构建 | `BUILD SUCCESSFUL` | [M 构建](test-results/2026-10-21-stage-main-build.log) |
| 测试包构建 | 两版均 `BUILD SUCCESSFUL` | [T1](test-results/2026-10-21-stage-test-build-t1.log)、[T2](test-results/2026-10-21-stage-test-build-t2.log) |

新增本地断言覆盖工作区身份、公网端点和晚到响应的版本确认，包含同时间不同内容与删除墓碑。服务契约使用受控模型替身，不能作为 13 次真实供应商调用。构建仍有既有 ArkTS 能力 / 异常 / 重复 ID 提示与未配置签名警告；没有修改用户签名配置。公开构建日志仅替换本机路径与移除终端颜色，完整输出保留在忽略目录 `.local/stage-one-20261020/`。

### 30.4 最终主包设备结果

| 场景 | 主包 / 测试包 | 结果、耗时 | 原始报告 |
|---|---|---|---|
| A 真实注册、保存手账、回读 ASSET 会话 | M / T1 | **1/1**，106953ms | [002145](test-results/2026-10-21-002145-da29bbdd-device.log) |
| 停止本任务服务、强停进程，A 冷启动并编辑同一手账 | M / T1 | **1/1**，54885ms | [002337](test-results/2026-10-21-002337-2eeda69c-device.log) |
| 恢复同一服务、再次强停进程，A 免重新登录交换 | M / T1 | **1/1**，20585ms | [002438](test-results/2026-10-21-002438-5d092c91-device.log) |
| B 同账号接收离线修改、显示全文与收尾清理 | M / T1 | **1/1**，83576ms | [002503](test-results/2026-10-21-002503-ab751608-device.log) |
| A 清理本轮独立库、身份与会话 | M / T1 | **1/1**，6093ms | [002630](test-results/2026-10-21-002630-8c16bcd3-device.log) |
| B 原生授权状态 / 可信查询、KV 重开 / 版本合并 / 墓碑 | M / T1 | **2/2**，18184ms | [002131](test-results/2026-10-21-002131-5c0e4c94-device.log) |
| A 原生同两项专项复跑 | M / T2 | **2/2**，18235ms | [002921](test-results/2026-10-21-002921-2e9cbd13-device.log) |
| 档案 / 我的层级、手账读改回放、真实 AI 保存重访 | M / T2 | **3/3**，478657ms | [003649](test-results/2026-10-21-003649-7eca4082-device.log) |
| 双连壶对象化入口、记忆排序 / 标签 / 批量管理及统计 | M / T2 | **2/2**，177358ms | [003827](test-results/2026-10-21-003827-641cf01f-device.log) |

上述完整报告的 Failure / Error / Ignore 均为 0；同两项原生用例在 A/B 各执行一次，不累计成四项不同能力。五个页面核心用例按互不依赖的 3 项 / 2 项在两端复验通过，未将中断轮改写为一次整组 5/5。

页面三项分组逐项耗时为 125044ms、118513ms、235100ms，后两项分组为 63186ms、114172ms。真实 AI 为 DeepSeek `deepseek-flash`，最终复验观察 1867ms、草稿 2068ms，见[原始模型事件](test-results/2026-10-21-stage-real-ai-events.log)；只代表本次两次请求。保存路径核对真实落盘的 `aiAssist`、`corners` 视角、冻结事实与重访预填；重访验证到带入原问题和本篇正文，没有自动再发一轮重访追问。双连壶本轮只核对对象化入口与起始问题，不宣称已完成其真实模型保存 / 跨端。

五阶段用同一新 fixture 连续执行，真实停止并核对本任务服务进程，`finally` 恢复同一数据库、证书与反向端口；断开的是本任务服务，不代表整机断网。编辑检查记录 ID 和可选视角字段保持一致、新正文磁盘回读一致；该 fixture 经“写手账”入口保存普通手账，没有主动保存观察视角，不能据此宣称完成视角跨端验收。B 登录后等待真实首轮交换完成再读盘，没有用固定延时或预填结果；正式观察视角由页面回归中的独立路径核对。

A/B 的真实系统可信设备查询均为 **0**；`lastSuccessfulSync=0`，状态为 `waiting`。[A 平台事件](test-results/2026-10-21-stage-native-a-events.log)、[B 平台事件](test-results/2026-10-21-stage-native-b-events.log)保留原始状态，未输出账号、手账正文或网络设备标识。**原生双端传输没有完成，不能将上述 HTTPS 接收或本机 KV 通过视作鸿蒙跨端成功。**

### 30.5 失败、工具调整与早期包

- [首次主包构建失败](test-results/2026-10-21-stage-first-build-failure.log)：将 SDK 的 `AssetMap` 误当普通对象；按本机声明改为 `Map<Tag, Value>` 后构建成功，未删除原失败记录。
- A 首次真实权限授权轮为 **1/2、Failure=0、Error=1、Ignore=0**，20709ms，见 [002716](test-results/2026-10-21-002716-a8fb1e79-device.log)。系统已完成“允许”，用例在弹窗销毁与授权 Promise 返回之间再次点击旧 Widget，产生 `NoCandidates`。T2 仅容忍该已知瞬态，其他错误仍失败，最后仍断言系统真实授权与可信设备数；复跑时系统已保留授权，不将复跑称为重新出现弹窗并完成的首授权路径。
- 更早 B 首次授权定位仍使用 `Button`，按实际布局手工辅助点了系统 `Text`“允许”；该早期通过记录 [000959](test-results/2026-10-21-000959-f7098a5c-device.log)保留为有手工辅助的阶段，最终 B 专项 T1 与 A T2 为授权已存在后的完整自动回归。没有通过 shell 注入授权或伪造可信设备。
- 页面整组首轮 [002650](test-results/2026-10-21-002650-8be7014c-device.log) 在第 4 项时被代理误关模拟器中断，没有完整结束摘要，不能记为 5/5。原因是沿用了交接摘要中相反的实例名/端口对应，关闭了仍运行页面回归的 `Pura 90 Pro`；随后依据实际进程与监听端口重新核对，保留数据重启，在两端按互不依赖的 3 项 / 2 项重新验收。该中断不改写为产品崩溃或通过。
- 早期主包 SHA-256 为 `ECFECE9A6E6D1890E6132B9A75A7E68982F295997528978103DD97D635DDDEF4`。其冷启动五阶段分别通过，但在上述状态与清理修复后已在 M 重新执行，不重复累计早期数量；未知中间测试包哈希不补造。
- `ArchiveUiSession.dispose()` 先停止窗口，再清理当前工作区的独立账号 Preferences、native KV、ASSET 与身份指针。该清理覆盖本轮单账号；旧多账号 scope 退出后已失去的身份、历史 `MemorySync` 清理尚未全部适配，未宣称它们也已清干净。

### 30.6 未完成与下一批

原生可信设备组网、真实 A/B 原生传输与冲突场景、华为账号授权、对端落盘方向可视化、冲突历史页面、完整备份恢复仍待完成。没有因本轮补上龙山 / 窑址内容、重构记忆 / 档案首屏、完成双连壶 AI 保存和跨端、平板布局、真人三分钟计时或录像；没有扩展大字体、泛化安全和压力套件。

下一批优先 C04 内容维度与 C07 首屏收敛，再完成 C08 双对象完整主线，沿真实“问→看→证→记→另一端重访”组织演示。验收后两台模拟器保留数据关闭，恢复本轮开始前均未运行的状态；本机服务保留可用。未提交、推送、上传比赛平台或覆盖用户 Word、视频和既有压缩包。


## 31. 内容维度与记忆首屏（2026-10-21）

### 31.1 范围与实现

本轮承接任务书 **C04 与 C07**，使用两台 API 26 手机模拟器；继续原生 ArkUI / Canvas，不以浏览器画面代替设备。工作区基线 `910324679288e23f5c20d4803210e1c798c6ca03`，`main` 上未提交改动；首批账号 / KV 的未提交修改继续保留。实施与原图见[内容与记忆交接](design/content-memory/README.md)，分版本清单见[本轮 JSON](test-results/2026-10-21-content-memory.json)。

- 追加 `zz-wangchenggang`（郑州 / 龙山 / 城址）与 `zz-huangye-kiln`（郑州 / 汉唐 / 窑址），目录共 22 条，五城计数 4 / 4 / 6 / 4 / 4。原 20 条的内容、稳定 ID 与顺序保留。官方条目原页、访问日期与事实边界见[内容研究](research/content-coverage-20261021.md)；黄冶正文保留隋末唐初至金的多期遗存，“汉唐”为唐三彩主线检索组。没有补造诗词、预约或票价，全部保持“初稿待校审”。
- 两条使用已预置原创插画与显式 `generic_site_study` 三张抽象资料卡，原生和兼容分发一致；界面显示“通用资料学习示意，不表示本遗址平面、窑炉结构或出土器物。”热点为概览、遗存、线索，不借用其他遗址模型，未加入 AI 白名单。
- 记忆默认列表收敛统计、重复装饰与常驻控件；排序 / AI / 全部真实标签 / 视图归入独立 `MemoryFilterPage`。分区数量、结果数与条件摘要来自真实记录。纸面、主色、印章、打孔保留；管理时隐藏卡片导航与编辑操作。
- “写一页”从真实最近浏览或全部档案选择，选定后替换选择页并复用正式编辑器；关闭编辑器后一次返回记忆。只有选定档案才清理会隐藏新普通手账的条件；取消仍保留原筛选。未改变 note 信封或 schema，删除继续保存墓碑。
- 首页保留既有主题、AI、最近记忆、纸页入口、沙盘、水情和图谱顺序；五城索引直达对应档案，一个总目录入口承接完整浏览。完整关键词与三维筛选集中到档案页，沙盘状态与库城市仍独立。旧检索用例随真实入口迁移，未据此宣称全部旧套件通过。

### 31.2 本地与包绑定

| 检查 | 结果 | 原始输出 |
|---|---|---|
| `tools/test.ps1` | **119/119**，失败 / 忽略 0 | [最终本地](test-results/2026-10-21-content-memory-local.log) |
| 设备报告解析 | **9/9** | 同一份完整输出 |
| 主包构建 | `BUILD SUCCESSFUL` | [M4 构建](test-results/2026-10-21-content-memory-main-build.log) |
| 测试包构建 | `BUILD SUCCESSFUL` | [T9 构建](test-results/2026-10-21-content-memory-test-build.log) |

本轮没有修改服务实现，账号 / AI 服务契约沿用第 30 节的 13/13，不计为本轮新跑。主包仍有既有平台能力 / 异常处理提示、首页重复 ID 提示和未配置签名警告；未修改用户签名。公开日志只替换本机路径、移除终端颜色，完整输出在忽略目录 `.local/content-memory-20261021/`。

| 代号 | 字节 | SHA-256 | 使用范围 |
|---|---:|---|---|
| M1 | 6,518,415 | `86A2CCD9E3C28111162E6CCF8AD2E5F3233015E6F65250B133A85A8B9EEF364E` | 首轮新增内容与五城入口 |
| T2 | 6,443,727 | `C1B6850C3216ECE81C460175DC8310FEF6B7DD62538DBCE57C04BB609356C0E6` | 对应 M1 的测试 |
| M2 | 6,520,169 | `BBBC83A68A1475F23641E91702EB63DF42A71EF29329C350557CC32E60131AC6` | 资料热点名称修正后的内容、排序与真实 AI |
| T4 | 6,448,707 | `FD499714A790491DC75331DDCDF179CEC8CF48EB3DD376A503995A0F1C64F398` | M2 设备结果 |
| **M4（当前）** | **6,525,915** | `14F0F5A7443C0FE137911A9977E5360C81CB4F97D9F3B53FF0ECDAE530676E86` | 动态空态与视图高亮修复后 |
| T7 | 6,451,051 | `82ABCCBBB1D1565CA6A6BFB7D413AD1FEDBFED4852CBEF22B5D45A4FF5E639B9` | M4 真实 AI；描述字段断言失败 |
| T8 | 6,453,903 | `BAC1027CBEF1B15B939CB11AF4F106DF36267EC511B10727D81C6A330C5770CF` | 三篇排序通过；测试宿主读取额外颜色证据失败 |
| **T9（当前）** | **6,449,868** | `DC656BD011025B8DBD0D657A0089D88E042A750F4EF90C46BF4D575FC68F39BF` | 全部功能断言与截图保留，颜色互换改由主机核对同次原始布局 |

没有安装的中间构建不作为设备通过证据。M4 与 T7 / T8 / T9 搭配时主包完全相同，后两版测试包未改应用实现。两端均为 HarmonyOS 7.0.0.107 / API 26，1256×2760、density 560；本轮实际进程监听对应 A=`Pura 90 Pro` / 5555 / PID 5772，B=`YunhejiSyncB` / 5557 / PID 19368，以真实监听查询核对，未沿用上一批相反的对应。

### 31.3 实际设备结果

| 场景 | 包 | 结果与耗时 | 原始报告 |
|---|---|---|---|
| 首轮新增两条组合筛选、资料阅读、来源与真实收藏 | M1 / T2，A | **1/1**，220171ms | [011652](test-results/2026-10-21-011652-ae1b2c5d-device.log) |
| 五城入口逐城命中全部真实档案、返回沙盘状态与总目录 | M1 / T2，B | **1/1**，225161ms | [011648](test-results/2026-10-21-011648-53aa4e85-device.log) |
| 资料热点名称修正后，停止服务再验新增两条图文与收藏 | M2 / T4，B | **1/1**，212629ms | [012319](test-results/2026-10-21-012319-b7756e5f-device.log) |
| 三篇真实新建、最近 / 最早实际首条、标签 2/3、全文返回与清除 | M2 / T4，A | 该项 **1/1**，202983ms；同轮下一项有 Error | [012315](test-results/2026-10-21-012315-37bca604-device.log) |
| 首轮真实方鼎 AI 聚焦、草稿、保存、冻结依据与单篇重访 | M2 / T4，B | **1/1**，222762ms | [012720](test-results/2026-10-21-012720-327a9dbc-device.log) |
| 当前主包真实方鼎 AI 同一路径，首屏直接坐标核对 | M4 / T7，B | **1/1**，185444ms | [013154](test-results/2026-10-21-013154-c9fc8ba5-device.log) |
| 当前主包三篇真实手账、实际排序、标签与全文返回 | M4 / T8，B | **1/1**，186767ms | [013719](test-results/2026-10-21-013719-719f9348-device.log) |
| 当前主包 AI 空态新建 / 取消、画廊 / 重置、管理与两条真实墓碑 | M4 / T9，A | **1/1**，251153ms | [014217](test-results/2026-10-21-014217-92c77727-device.log) |

当前主包的三项记忆与 AI 定向路径均各自 **1/1**，分别使用 T7 / T8 / T9，未写成一次同测试包 3/3。上述完整通过报告的 Failure / Error / Ignore 均为 0，未把同一场景的复跑累计成不同能力。

新增内容的两轮均核对停止的是完整命令行匹配的本任务 HTTPS 服务，端口无监听后开始；`finally` 恢复原数据库、证书、配置与两端反向端口。**这是本任务服务不可达验证，不是整机断网。** 本地插画、正文、来源与真实收藏可用，不要求外部网站当时在线。

新建与管理使用独立 `yunheji_test_ui_*` 工作区，所有记录经真实编辑器保存；清 Preferences 缓存后从磁盘回读，不注入样例记录或伪造 AI。真实 AI 使用 DeepSeek `deepseek-flash`，M2 观察 / 草稿分别 2001 / 1722ms，M4 分别 1614 / 1633ms；只代表本轮四次真实请求。重访核对到带回原问题和本篇正文，没有自动再发新一轮追问；没有双连壶 AI 保存 / 跨端验收。

### 31.4 首屏与原图

不调用滚动补救，进入记忆后回顶直接读取控件 bounds：M2 普通首卡档案标题底部 1486px、正文底部 1602px、“读手账”底部 1942px；最早排序后底部分别 1542 / 1658 / 1998px。HDS 顶部内容底部为 311px，Dock 上缘 2529px，三者均在实际可见区域内。对应原始坐标见[阶段事件](test-results/2026-10-21-content-memory-m2-events.log)。M4 三篇手账复验同样完整通过；王城岗从 AI 空态新建后，正文底部 1683px、主要动作底部 2019px。最终坐标与实际保存事件见[最终事件](test-results/2026-10-21-content-memory-final-events.log)。

M4 的真实 AI 卡另有来源标识与保存视角，AI 标记底部 1482px、档案标题 1646px、正文摘要 1927px、“读手账”2267px，仍全部在 Dock 上方。不是仅以总卡高度或源码行数推断。实际界面见[图集](design/content-memory/README.md)，真实请求日志见[模型事件](test-results/2026-10-21-content-memory-real-ai-events.log)。自动化耗时包含定位、稳定等待、截图和回读，不作为真人操作计时。

### 31.5 首次失败与修复

1. 首次本地为 **117/119，失败 2**，见[完整输出](test-results/2026-10-21-content-memory-first-local.log)。新增 22 节点使窄图谱出现戚城 / 偃师商城重叠，垂直碰撞响应从 0.08 调到 0.25，保持原节点尺寸、边界、迭代数和断言，按脚本重新生成兼容产物；另一项为测试误查兼容场景不存在的 `title`，按实际契约检查 preset、三张资料卡、热点与有限几何。之后同一必跑本地脚本 119/119。
2. M2 的两项记忆分组为 **1/2，Failure=0、Error=1、Ignore=0**，236835ms，见 [012315](test-results/2026-10-21-012315-37bca604-device.log)。三篇手账排序标签项通过；AI 空态项 33852ms 在等待“还没有 AI 辅助手账”失败。真实截图的条件已是“最近 · AI 辅助”，标题却保留“还没有留下手账”。已将动态空态改为内部直接读取状态，并修复列表 / 画廊 Builder 值参数的选中外观刷新；[首次原图](design/content-memory/first-ai-empty-failure.png)保留。
3. M4 / T7 的管理项 **0/1，Failure=0、Error=1、Ignore=0**，187526ms，见 [013154](test-results/2026-10-21-013154-fcfa426a-device.log)。新建与 AI 空态已走过，停在测试误把 `accessibilityText` 等同 UiTest `description` 的断言。实际布局画廊背景 `#FFFBEAF0`、列表 `#FFF4ECE4`，高亮已正确；T8 改读实际布局颜色，要求重置后两项背景真实互换，同时保留视图结果、管理与墓碑断言。该失败不改写为通过，也不作为又一次产品高亮缺陷。
4. M4 / T8 的管理项 **0/1，Failure=0、Error=1、Ignore=0**，178241ms，见 [013719](test-results/2026-10-21-013719-6b2edccc-device.log)。额外证据读取步骤 `cat` 在测试宿主返回 `exitCode=-1`，此时截图和布局文件已实际生成；该返回原因未另行定位。T9 保留截图 / 布局、视图、重置、管理与墓碑断言，将布局颜色读取放到主机按本次文件核对，不要求设备测试宿主执行额外文件读取。应用主包保持 M4。T9 最终 **1/1**、251153ms，完整摘要见上表；同次布局在主机核对画廊 / 列表背景由 `#FFF4ECE4 / #FFFBEAF0` 在重置后实际互换为 `#FFFBEAF0 / #FFF4ECE4`，见[原始颜色核对](test-results/2026-10-21-content-memory-view-colors.json)。批量删除两篇后活跃 note 为 0，原 ID、正文、标签、更新时间与删除墓碑经磁盘回读保持正确。

### 31.6 剩余范围

C04 的检索维度与 C07 的演示路径已落地并完成本轮定向验收；本轮仅围绕正常字号演示路径验收，没有扩展大字体、泛化安全或压力测试，也未将迁移了入口的历史套件自动标为当前包通过。完整旧 UI、当前包 HTTPS 双端、平板布局、真实鸿蒙可信组网、华为账号与完整恢复没有因本轮完成。

下一批优先 C08：双连壶真实问答、部位定位、依据、个人观察、确认保存与同账号另一端重访，再将方鼎 / 双连壶做成可讲清的双对象演示。此后推进 C09 真实记录驱动的文化漫游与个人长卷。用户 Word、视频与既有比赛压缩包未更新，未提交、推送或上传比赛平台。

本轮两台模拟器已保留数据关闭：先以实例命令行和真实监听核对，再调用停止并再次确认无进程 / 端口；本机同一 HTTPS 服务保留可用，使用原本机 CA 请求 `/health` 返回 `yunheji-account` / version 1。

## 32. 双对象 AI 与同账号记忆重访（2026-10-21）

本轮执行 C08，基于 `910324679288e23f5c20d4803210e1c798c6ca03` 及工作区此前未提交内容继续；不覆盖原有变更。目标是双连壶的真实问答、主动聚焦、依据、个人观察、草稿、确认保存与同账号另一端重访，并回归方鼎。范围为 HarmonyOS 7 / API 26 原生路径，自建账号 HTTPS 通道；华为账号、系统可信组网与原生跨端传输仍未完成。图集见[本轮原生画面](design/ai-dual-memory/README.md)。

### 32.1 应用修改与数据边界

1. 新增契约首先捕获真实缺陷：`focus_hotspot` 原只检查合法热点，双连壶 `opening` 可夹带方鼎 `duling-eight`。领域规则现要求非空 `factIds` 全部属于当前对象且不重复；合法空引用的定位动作继续支持。客户端与服务端共用校验，不在快照解析中新增对象白名单。
2. 编辑器草稿与既有 AI 手账的依据摘要显示冻结事实的中文标题，不再把内部事实 ID 当作产品文案。事实 ID、内容修订号与冻结正文继续完整保存。
3. 沿用原 schema、稳定档案 ID、装饰、视角和墓碑，无正式档案迁移或清空。采纳草稿先向原生视口取得真实相机与原画幅，确认保存才创建 note。再问只预填该篇问题与正文，点击提问才请求；未改写原 note。

### 32.2 本地、服务与构建

- 修复前两项对象隔离契约实际 **0/2，失败 2，退出码 1**。完整输出从当时工具会话原样转存，见[首次红灯](test-results/2026-10-21-ai-dual-contracts-first-red.log)；不是撤销修复后重新制造的失败。
- 两份 AI 契约联合 **26/26，失败 / 跳过 0**，203.0625ms，见[绿灯输出](test-results/2026-10-21-ai-dual-contracts-green.log)。工具侧测试计入本地总数，服务侧计入服务总数，存在重叠，不累加成额外用例。
- `tools/test.ps1` 最新 **122/122，失败 / 跳过 0**；设备报告解析 **9/9**，见[最终本地结果](test-results/2026-10-21-ai-dual-local-final.log)。首轮同脚本也是 122/122，见[首轮输出](test-results/2026-10-21-ai-dual-local.log)。
- 账号与 AI 服务 **15/15，失败 / 跳过 0**，593.4126ms，见[服务契约](test-results/2026-10-21-ai-dual-service.log)。服务替身测试不冒充供应商调用。
- 主包及各测试包均 `BUILD SUCCESSFUL`。当前应用主包 M2 的[构建日志](test-results/2026-10-21-ai-dual-main-build-m2.log)保留既有平台能力 / 异常处理、重复 ID 与未配置签名提示，未修改用户签名配置。公开构建日志只替换本机路径并移除终端颜色，原输出保留在忽略目录。

| 代号 | 字节 | SHA-256 | 设备范围 |
|---|---:|---|---|
| M1 | 6,526,186 | `6473CAE6585884BFCC5F6096BEEF04EAB8D337A179701F9E30E21E31B5C858E2` | 已补引用隔离；首次 T2、T4 失败路径 |
| **M2（当前）** | **6,526,994** | `2D1815955405B3CA354B83871B9E0A7598996FD892C47A6FE7C67EC2695BB7FE` | 中文事实标题；单端双连壶、方鼎与 A/B 均用同一主包 |
| T1 | 6,559,896 | `6DDC8F8987918F90328163FDCF832CC2A5DD9F0F05732CBED4FFCD4407E446FB` | 新鲜度检查拒绝，未安装或执行用例 |
| T2 | 6,560,198 | `C14BE8FCA69A9D12B3E55905586D54F9080DDB4DB32F29CAB11D06AAA8FE61BD` | 首次双连壶、A 保存失败 |
| T3 | 6,560,631 | `1F51528D0D357F7A99C8D2C994101072C3B0B198EA52DD7FE3DEE377470293B1` | 第一组旧 fixture 两端清理 |
| T4 | 6,560,631 | `8B4861DFFEC7164C0604053DAAD6DE4C19BB5685FCEF49C2E7D608F7397647B2` | 第二组失败及其清理 |
| T5 | 6,564,943 | `66E76882522F82925AE2F0DA1DDD0FB5AAA861C979106279000736C16696D6F1` | 双连壶单端通过；A 登录步骤失败 |
| T6 | 6,562,934 | `DEBE33BA5DCB56B78E3C4D390289D9721ACE20C0C26755016B2DACBDFFB3984E` | A 保存、方鼎真实路径通过 |
| T7 | 6,563,170 | `538920A5CDB665B9008BADBF7E59514DED92F642E066EEB55ADBF3A5A487F424` | B 从空库接收 / 回放通过；首次 B 再问定位失败 |
| **T8（当前）** | **6,563,300** | `075BFB3D4CCC07804D9B164E5FE9E3C3CD55A23336B120CF5DD3BCE86BBB1198` | 同 fixture 的 B 再问与两端清理通过 |

T3/T4 源码相同，fixture 不同；T5 后应用主包保持 M2。T6/T7/T8 只修正测试定位，后两版沿用 A 成功保存时的同一 fixture、同账号与原 note，没有重新注入或替换记录。两端实际为 A=`YunhejiSyncB` / `127.0.0.1:5555` / PID 5464，B=`Pura 90 Pro` / `127.0.0.1:5557` / PID 6972，均 HarmonyOS 7.0.0.107 / API 26、1256×2760、density 560；启动时按进程完整命令与监听核对。

### 32.3 实际设备结果

| 场景 | 包 / 设备 | 结果 / 耗时 | 原始报告 |
|---|---|---|---|
| 双连壶真实起始问题、定位、依据、个人观察、草稿、确认保存、冻结事实与再问预填 | M2 / T5，B | **1/1**，221626ms | [021508](test-results/2026-10-21-021508-363b57cb-device.log) |
| A 新注册空账号、自由提问、非默认装饰与唯一标签、实际编辑器保存、磁盘和服务端完整版本确认 | M2 / T6，A | **1/1**，170508ms | [022049-A](test-results/2026-10-21-022049-faba9975-device.log) |
| 方鼎真实问答、四个折角聚焦、草稿、保存、AI 首卡可见与冻结依据重访 | M2 / T6，B | **1/1**，191320ms | [022049-方鼎](test-results/2026-10-21-022049-c2ad4fa3-device.log) |
| B 独立空库登录、HTTPS 接收唯一标签 note、冻结依据与实际原生回放 | M2 / T7，B | **1/1**，91583ms | [022456](test-results/2026-10-21-022456-cde2c928-device.log) |
| B 从原工作区恢复、预填问题 / 正文 / 相机、停留无自动请求、显式再问、原 note 未改写 | M2 / T8，B | **1/1**，68354ms | [022939](test-results/2026-10-21-022939-cf4f6a60-device.log) |
| 最终清理本 run 的账号库、ASSET、KV、身份指针与测试基础库 | M2 / T8，A | **1/1**，5055ms | [023138](test-results/2026-10-21-023138-a481aa5e-device.log) |
| 最终清理同一 run 的 B 测试数据 | M2 / T8，B | **1/1**，5164ms | [023137](test-results/2026-10-21-023137-8a73ac97-device.log) |

上述完整通过报告的 Failure / Error / Ignore 均为 0，分别绑定各自测试包，不写成一次同测试包全套通过。两端只清理本 run 的测试数据，不清空正式用户档案；主机服务仍保留本轮测试账号与远端数据。

### 32.4 真实记录与画面核对

A 只经真实编辑器保存，清 Preferences 缓存后回读，再以同设备 ID、空 `records` 的真实 `/sync` 探测核对服务端已经接收的版本；探测不会上传 note 补救正式同步。B 登录前读取本 run 独立账号库并确认空，后续唯一 note 只能由正式 App HTTPS 同步进入。两端安装身份不同，记录保持 A 的来源 deviceId。

完整记录采用 HiLog 分片，先核对片数和字符数，再还原 JSON、深比较全部顶层与嵌套字段。`tools/compare-ai-memory.mjs` 的摘要哈希逐层排序对象键、保留数组顺序，全部事实、来源、镜头与画幅参与计算，不使用会筛掉嵌套字段的 replacer。

本次 A、B 与 B 主动再问后的记录均为 **4 片、1220 字符**，实际运行比较工具通过：**13 个顶层字段和所有嵌套内容一致**。正文、标签、非默认印章与纸色、摘录、原问题、两条冻结事实及其来源、ID、时间戳、来源设备、实际相机与原画幅全部保持，见[A 事件](test-results/2026-10-21-ai-dual-a-events.log)、[B 接收事件](test-results/2026-10-21-ai-dual-b-receive-events.log)、[B 再问事件](test-results/2026-10-21-ai-dual-b-ask-events.log)与[完整比较摘要](test-results/2026-10-21-ai-memory-compare.json)。不把进入详情时合法更新的 progress 记录当作“整个快照未写入”。

真实保存参数为 `zz-dahecun / relic_inspector / dahecun_pottery / revision 2 / opening`，相机 yaw=0.34、pitch=0.14、zoom=0.98，原画幅约 294.857×300vp、density=3.5。A 聚焦与 B 正式回放均截取同次原始 layout 的 Canvas bounds，按整数坐标裁切，未缩放或屏蔽像素：**1032×1050，共 1,083,600 像素，仅 4 个像素不同，最大单通道差值 1**。没有称为零像素差异；原图与[完整比较结果](test-results/2026-10-21-ai-dual-canvas-compare.json)保留。整体截图纵向位置不同，比较仅限真实画布区域。

真实供应商为 DeepSeek `deepseek-flash`。领域修复后重启同一服务，整轮记录 **12 次成功模型请求**，含失败阶段已发出的请求，不能全称最终主线。最终成功主线对应 7 次：单端双连壶观察 / 草稿 1671 / 1900ms，A 双连壶观察 / 草稿 1473 / 1706ms，方鼎观察 / 草稿 1610 / 1693ms，B 显式再问 1616ms。B 接收前 / 后服务成功请求数均为 11，显式再问后为 12；结合设备的无请求停留窗口和显式发送事件，未出现打开手账就自动调用模型。原始[供应商事件](test-results/2026-10-21-ai-dual-provider-events.log)只含对象、用途、数量和耗时，没有凭证或账号正文。

### 32.5 保留的设备失败与修正

1. T2 双连壶 **0/1，Error=1，49352ms**，[020152-双连壶](test-results/2026-10-21-020152-714af8d8-device.log)：直接等待屏外 `observation-selected-detail`。实际画布已经聚焦，改为先核对可见 Canvas，再真实滚动读说明。
2. T2 A **0/1，Error=1，99733ms**，[020152-A](test-results/2026-10-21-020152-467b2828-device.log)：`ai-continue` 后测试无条件 Back，在键盘未打开时退回档案页，后续找不到 `detail-scroll`。移除该处返回。
3. T4 双连壶 **0/1，Error=1，117782ms**，[020851](test-results/2026-10-21-020851-8ceecb70-device.log)：编辑器已显示真实草稿，测试却把稳定档案名“大河村遗址”与器物名比较。改按目录档案名断言，器物与热点继续核对完整记录。
4. T4 A **0/1，Error=1，148540ms**，[020850](test-results/2026-10-21-020850-a788acbb-device.log)：专用搜索助手在目标仍位于下方时反向回到模型顶部。详情搜索改复用已有带真实锚点的 `session.inScroll`，保留所有实质断言。
5. T5 A **0/1，Error=1，52515ms**，[021508-A](test-results/2026-10-21-021508-a85816e9-device.log)：新增键盘收起方法影响此前已通过的登录，未进入 `A_FRESH`，没有本阶段模型请求；具体登录节点未由当轮错误记录区分。回退这部分测试改动，登录与首次发送恢复已成功的输入后返回，其余位置不添加返回或键盘操作。
6. T7 B 再问 **0/1，Error=1，59212ms**，[022655](test-results/2026-10-21-022655-957e2c13-device.log)：AI 入口已自动滚到面板，测试从中部向下寻找上方的镜头回放说明。T8 先真实回顶并露出完整 Canvas，再核对同一文案；未修改主包或原手账，没有增加模型等待与阶段超时。

旧 fixture 清理原始报告分别为：第一组 A [020742-A](test-results/2026-10-21-020742-b443f520-device.log) / B [020742-B](test-results/2026-10-21-020742-eadcf33d-device.log)，第二组 A [021157-A](test-results/2026-10-21-021157-86c59549-device.log) / B [021157-B](test-results/2026-10-21-021157-77ba95c9-device.log)，第三组 A [021713](test-results/2026-10-21-021713-38bc6ad1-device.log) / B [021914](test-results/2026-10-21-021914-79d27490-device.log)，均各自 1/1。包新鲜度拒绝没有执行 aa，不列为设备用例失败。

上述失败的 Failure / Ignore 均为 0；原始 Error 均保留。登录中失败未截取账号画面，其他[失败原图](design/ai-dual-memory/README.md#保留的首次失败)按阶段保留。前三组 fixture 的清理均先用旧 fixture 完成后才生成新账号；成功 A 之后不再更换 fixture。

### 32.6 本轮收尾与下一步

本轮只围绕正常字号演示路径做必要验证，没有扩展历史全套 UI、大字体、泛化安全或压力测试。AI 在线白名单仍为两件，目录其余 20 条保留已有离线、手动观察与手写手账。自动化耗时包含定位、输入、稳定等待、截图和落盘核对，不等于真人三分钟；用户 Word、视频和比赛压缩包未更新，未自动提交或推送。

C08 的本轮演示路径已完成，包、源文件、原始报告、原图和比较结果见[机器可读清单](test-results/2026-10-21-ai-dual-memory.json)。下一步 C09 先做“泥火成器”一个主题的个人长卷：由真实手账、收藏和有效探索记录派生，点击画幅复用现有 note 回放；四步路线显示阅读理由与来源，改标签和删除后重算。不新增文化事实、持久化格式或 AI 主题生成，原生跨端与华为账号继续按各自任务推进。

全部设备测试结束、原图取回并清理后，先按实例完整命令与实际端口核对，再通过模拟器停止命令保留数据关闭。停止请求后的首次复核中 A 仍在退出、B 已退出；再次复核确认两端 PID 和 5555 / 5557 监听均消失，未把停止命令返回成功直接当作退出完成。本机 HTTPS 服务保留原数据库和证书，原 CA 请求 `/health` 返回 `yunheji-account` / version 1。

## 33. 泥火成器个人长卷（2026-10-21）

本轮推进 C09 首批，基于 `910324679288e23f5c20d4803210e1c798c6ca03` 及工作区此前未提交成果继续，保留其他文件。范围为一个主题、现有四处档案、原生长卷与已有手账回放。未新增文化事实或模型请求；华为账号、原生可信传输、平板布局和完整恢复仍按各自任务记录。实现与原图见[长卷图集](design/journey-scroll/README.md)，交接见[JOURNEY_SCROLL](JOURNEY_SCROLL.md)。

### 33.1 实现与数据规则

新增纯领域模块 `JourneyScroll.ts`：先按既有确定性版本规则合并，再以 `earth-and-fire` 四个稳定档案派生四步阅读、城市分组、个人记录与关联理由。普通笔记、收藏及有效 section 进度可形成个人线索；路线点亮仍复用原 `journeyProgress`，只有有效画面手账或 75% 探索符合该条件。旧 `opened` 不等于学习完成或到访，墓碑不会因旧版本再次到达而复活。

新增原生 `JourneyScrollPage`：纸页头部、真实计数与进度、可展开理由 / 来源的四步竖轴，以及按城市组织的个人长卷。来源直接读取现有 `site.source`；共同标签以“我的专题”表达，属性理由复用 `connectionReasons`。每篇手账保留真实正文、标签与画幅，点击预览和回放使用原 note，全文入口复用现有页面。AI 仅显示已有元数据标识。

`Index` 集中路由与记忆页常驻入口；`SiteDetail` 在路线内新建 note 确认落盘后显示“展开我的泥火长卷”，不自动跳转。编辑旧 note 不触发新建分支。长卷只派生当前共享快照，编辑、删除或同步后按记录版本重建；沿用 schema、旧 ID、来源、装饰、镜头和墓碑，**无新持久化字段，无正式档案迁移或清空**。

### 33.2 本地与构建

- `tools/test.ps1` **127/127，失败 / 跳过 / 取消 0**，2849.1259ms；设备报告解析 **9/9**，见[本地原始输出](test-results/2026-10-21-journey-scroll-local.log)。新增长卷五项计入总数，覆盖空态出处、普通笔记与完成分离、标签更新和墓碑、收藏与 section 保留、路线外排除、确定排序与输入不变。
- 主包与测试包均 `BUILD SUCCESSFUL`。M1 / T1 为初次设备包；M2 修正无界滚动页的竖轴膨胀，T2 将待核对的实际叶节点滚入视口，保留全部功能断言。M2 主包构建 15s982ms、T2 测试包 14s212ms；[主包日志](test-results/2026-10-21-journey-scroll-main-build-m2.log)与[测试包日志](test-results/2026-10-21-journey-scroll-test-build-t2.log)保留既有平台能力 / 异常处理、重复 ID 和未配置签名提示，未修改用户签名配置。
- 公开日志仅替换本机路径并去除终端颜色，原始输出保留在忽略目录；没有把 C08 服务 / 真实模型结果计作本轮新跑，本轮不需要账号或模型请求。

| 代号 | 字节 | SHA-256 | 范围 |
|---|---:|---|---|
| M1 | 6,672,936 | `9A6F049AF20A10C2757B9EB9FC5019967378429AC17D9CBFBFC7DA11947D6DC6` | 初次长卷页面，设备发现竖轴膨胀 |
| T1 | 6,649,124 | `84BBB1057D526E7AC6BCA83677EBA0980DA7719F0EE26920E9D9CB0108D8489C` | 初次空态失败 |
| M2 | 6,673,241 | `D579804478FFC63E37FA0E00120D981CD5C0758B3A1790341D13EF1929135316` | 路线竖轴改明确高度 |
| T2 | 6,647,657 | `EF8ABD31CB57A27606EC1C39C50BCF8AC7ABEBC63A3AA15F89AAF522D8A70CA7` | 实际叶节点定位，空态通过；首次整段主线超时 |
| **M3（当前）** | **6,676,399** | `E5F7439669F32F111D63105BD39B3E97398F0DC9318AA5EF608EA3294C72FDC4` | 页首直达个人长卷，进度文案改为主题路线进度 |
| T3 | 6,670,235 | `58FF6E679A20645B583A924C0ED672F8105CED85A9F3A435A3BAD737EB597E8E` | 同一显式离线库分段，阶段日志、个人区落点和回放画布同屏核对 |
| **T4（当前）** | **6,680,585** | `7E7DC33CE236B4A626E0CF82DFD34AADE9AC39D0E9B18BCCDF94808D65F3C454` | 编辑与删除独立成段；已知页尾先真实滚动再定位，原断言保留 |

M3 主包 **16s228ms**、T3 测试包 **13s166ms** 构建成功，见[主包 M3](test-results/2026-10-21-journey-scroll-main-build-m3.log)和[测试包 T3](test-results/2026-10-21-journey-scroll-test-build-t3.log)。T3 首次构建因三个日志对象缺少 ArkTS 显式接口而失败，见[首次编译原始输出](test-results/2026-10-21-journey-scroll-test-build-t3-first-failure.log)；没有生成可用 T3，随后设备脚本按新鲜度拒绝旧 T2，**未安装或运行 aa**。补日志专用类型后重建成功，没有删除功能断言或改应用数据。

T4 构建 **14s474ms** 成功，见[测试包 T4](test-results/2026-10-21-journey-scroll-test-build-t4.log)。主包始终为同一 M3；T4 只拆测试和已知位置的原生滚动定位，继续使用 T3 真实保存的原库、原 note、收藏与探索记录，未把整条主线重新预制或换库。

本轮只启动一台保留数据的手机模拟器 `YunhejiSyncB`，实际 target `127.0.0.1:5555`、PID 17200、1256×2760、density 560。本轮实际 `param` 返回发行名称 `HarmonyOS` / `7.0.0`、软件版本 `emulator 7.0.0.107(SP8DEVC00E999R4P11)`、底层 fullname `OpenHarmony-7.0.0.105`、API `26`，各字段分别保留，不混为一项版本。按实例完整命令与监听核对，coldboot 保留已有数据，再依据真实锁屏 layout 解锁。测试通过正常“离线浏览”进入各自 `yunheji_test_ui_*` 独立库；不登录、不请求模型、不注入样例记录。

### 33.3 原生设备结果

| 场景 | 包 | 结果 / 耗时 | 原始报告 |
|---|---|---|---|
| 空库记忆入口、0/4、真实四步与出处、建议打开庙底沟，无笔记 / 收藏 / section 完成 | M2 / T2 | **1/1**，115614ms，Failure / Error / Ignore 0 | [105625](test-results/2026-10-21-105625-ec13d7c4-device.log) |
| 旧整段超时库定向清理，随后只读确认该 Preferences 已不存在 | M3 / T3 | **1/1**，10143ms，Failure / Error / Ignore 0 | [112023](test-results/2026-10-21-112023-87a69f41-device.log) |
| 真实 UI 保存双连壶 opening、方鼎 corners 两篇及共同标签；方鼎收藏 / overview 基线；保存后入口与 2/4 | M3 / T3 | **1/1**，245178ms，Failure / Error / Ignore 0 | [112102](test-results/2026-10-21-112102-8cb21ee4-device.log) |
| 重开同一离线库，出处 / 个人区真实跳转 / 城市专题与正文 / 点击 Canvas 回放；四条原记录版本未变 | M3 / T3 | **1/1**，251409ms，Failure / Error / Ignore 0 | [112551](test-results/2026-10-21-112551-e0c4e941-device.log) |
| 沿用原库，经真实编辑器还原标签后再完整修改；两侧专题即时更新，原镜头 / 装饰及其他记录保持 | M3 / T4 | **1/1**，134961ms，Failure / Error / Ignore 0 | [114112](test-results/2026-10-21-114112-7a1d8a62-device.log) |
| 正式全文删除；墓碑保留原字段，另一篇 / 收藏 / overview 版本不变；1/4、剩余线索与记忆首卡 / 固定入口 | M3 / T4 | **1/1**，69541ms，Failure / Error / Ignore 0 | [114410](test-results/2026-10-21-114410-1514f6af-device.log) |
| 当前包独立空态复核，0/4 / 真实出处与建议，打开档案不生成个人线索或学习完成 | M3 / T4 | **1/1**，117575ms，Failure / Error / Ignore 0 | [114602](test-results/2026-10-21-114602-3f80c636-device.log) |
| 最终同一连续测试库定向清理，随后只读确认旧库 / 连续库 / 空态库均无残留 | M3 / T4 | **1/1**，9314ms，Failure / Error / Ignore 0 | [114916](test-results/2026-10-21-114916-e6222c3b-device.log) |

M2 / T2 首次整段主线达到 600000ms 上限，见 [105847 原始 AA 输出](test-results/2026-10-21-105847-3dd82e77-device.log)。AA 只有开始和超时，缺少结束摘要，报告解析正确拒绝；另存的[原始 HiLog](test-results/2026-10-21-journey-scroll-main-timeout-events.log)明确记录 `Tests run: 1, Failure: 0, Error: 1, Pass: 0, Ignore: 0`。两种输出分别保留，不能合成为完整 AA 报告或记为通过。

当轮超时前已真实保存两篇、核对 2/4、下一处、出处、共同专题及 opening 回放，但未完成编辑与删除。随后按同一独立离线库分阶段保留全部实质断言，最终结果如上表：同一 M3 主包，保存及读取 / 回放绑定 T3，编辑、删除 / 首卡和最终空态绑定 T4，五条业务路径分别各 1/1；旧库与最终库清理分别各 1/1。历史 M2 空态单列，不累加成当前包业务结果，不描述为一次同测试包全套通过。自动化耗时包含输入、定位、截图与磁盘回读，不作为真人操作计时。

### 33.4 首次失败与针对性修复

M1 / T1 的空态 **0/1，Failure=0、Error=1、Ignore=0，130200ms**，见[104354](test-results/2026-10-21-104354-acf60286-device.log)。测试只把 `journey-empty` 大容器的边缘滚进视口，随后直接等待仍在下方的标题，报 `UI_COMPONENT_NOT_FOUND journey-empty-title`。T2 改为真实滚入标题等要核对的叶节点；主线正文、预览状态与进度同类等待也按该原则修正，不增加超时或删除功能断言。

同次[失败原图](design/journey-scroll/first-empty-title-failure.png)还揭露真实布局问题：左侧序号列 `Stretch` 配合 `Blank.layoutWeight(1)` 在 Scroll 纵轴把装饰线撑大。原始 Blank 未裁切 bounds `[141,-283][145,1697]`，高度 1980px，左列高 2120px，第四步前出现整屏空白。M2 去除该无界伸展，线明确为 48vp，序号列为 88vp / 最后一项 32vp，右侧仍按实际内容决定整步高度。出处、理由与所有实际操作保持；测试定位问题与应用排版问题分别记录，不能互相替代。

M3 / T3 第三段 `edit_delete_preserve_records_and_memory_entry` 达到 360000ms 上限，完整报告 [113017](test-results/2026-10-21-113017-4d3a7dc6-device.log)为 **0/1，Failure=0、Error=1、Ignore=0，359993ms**。日志中已完成真实标签保存和两侧专题刷新；随后长页面的原生 `scrollSearch` 耗时，第二次进入全文约 80 秒，到 `memory-detail-delete` 前后用完本段时间，未完成删除与剩余断言，不能登记为通过。超时后的[画面](design/journey-scroll/first-edit-delete-timeout.png)与 layout 只是已回到系统桌面的状态，不能据此诊断应用自身崩溃。

停止旧测试后，只读复制精确独立测试库并解析 XML 当前快照，确认方鼎 note 仍活跃、标签为“青铜折角”，双连壶 / 收藏 / overview 的版本仍为原值，见[超时后只读摘要](test-results/2026-10-21-journey-scroll-t3-timeout-snapshot-summary.json)。未直接写入或注入记录。T4 将编辑 / 删除拆开，已知最后一篇手账与全文操作采用原生 `scrollToBottom` 后定位实际按钮，专题按个人区锚点与真实页尾分别核对；没有扩展通用滚动助手或提高上限，原字段、镜头、墓碑和首卡断言均保留。

T4 编辑复验先经真实编辑器把原 note 的“青铜折角”改回“泥火观察”，清缓存回读后作为该次基线，再完整改为“青铜折角”并核对两侧专题消失，正文、pose、装饰与其他三条基线不变。删除复验继续使用同一 note；墓碑保留新标签、正文、pose、纸色、印章和摘录，其他 note / 收藏 / section 不变，剩余一篇、方鼎收藏与 25% 探索，路线为 1/4。没有换库、预制 note 或把前次超时改写为通过。

### 33.5 原图、交接与收尾

正常字号的[实际原生图集](design/journey-scroll/README.md)包含长卷 2/4、出处、共同专题、Canvas 与回放成功文案同屏、标签刷新、删除后保留线索、记忆首卡及最终空态；全幅 PNG 与同名 layout 分别保存。图集总览只等比例缩略拼接，不重绘应用内容。记忆首卡标题范围 `[117,1602][397,1668]`、正文 `[117,1787][1139,1949]`、读手账 `[525,2156][905,2289]`，位于页首内容下边 311 与 Dock 上边 2529 之间。

正式清理接口完成后，额外只读确认旧超时库、连续测试库和本轮自动空态库均无残留，见[清理核对](test-results/2026-10-21-journey-scroll-cleanup.json)。所有设备测试结束并取回原图后，按实例完整启动命令与端口确认所有者，再正常停止 `YunhejiSyncB`；复核 PID 17200、5555 监听和该 HDC target 均已消失，保留用户数据，没有 reset。见[收尾核对](test-results/2026-10-21-journey-scroll-shutdown.json)。

收尾发现原本机 HTTPS 服务未监听，按原配置恢复，证书与客户端资源内容均未变化；最终 `/health` 返回 `yunheji-account` / version 1。只恢复既有服务，没有新增模型请求、服务契约套件或同步验收，见[服务健康核对](test-results/2026-10-21-journey-scroll-service-health.json)。本轮仅围绕正常字号离线主线，未扩展完整历史 UI、大字体或压力测试。

包、当前源文件、原始报告、保留失败、原图与收尾绑定见[机器清单](test-results/2026-10-21-journey-scroll.json)，交接链接和实际文件哈希核对见[交付检查](test-results/2026-10-21-journey-scroll-delivery-check.json)。C09 首批已完成，下一步 C10 从实际平板主从导航开始，再按业务页真实宽度布置观察 / 依据 / 正文。华为账号、原生可信传输、完整恢复、真人计时与最终材料继续待完成；本轮未自动提交、推送或更新用户 Word、视频和比赛压缩包。

<a id="roaming-20261023"></a>

## 34. 五城漫游、原生平板与同账号延续（2026-10-23）

本轮在现有 HarmonyOS 7 / API 26 原生工程中完成五城漫游、亲笔记忆、平板选摘拖放、按需登录和同账号 HTTPS 延续的定向闭环。当前产品冻结为 **M12**；最后定向测试包为 **T15**，复制漫游与最终独立五城入口在该包通过，其余成功结果分别绑定 M5—M12 及对应测试包，不能改写为一次 M12 / T15 全套通过。实际设备为手机和平板模拟器；比赛允许自有设备的确认不等于已完成实机或 OpenHarmony API 12 兼容验证。

本节保留逐次失败、成功和未覆盖范围。总索引见[本轮机器清单](test-results/2026-10-23-roaming.json)，数据约定见 [ROAMING_DATA](ROAMING_DATA.md)，专用交接见 [ROAMING_HANDOVER_20261023](ROAMING_HANDOVER_20261023.md)。公开图集分别为[原生总览](design/roaming/overview/README.md)、[四城](design/roaming/four-cities/README.md)、[平板](design/roaming/tablet/README.md)、[同账号 A/B/A](design/roaming/sync/README.md)、[按需登录](design/roaming/login/README.md)、[系统入口](design/roaming/system/README.md)和[单端演示](design/roaming/demo/README.md)。

代码基线为 `910324679288e23f5c20d4803210e1c798c6ca03` 加本轮未提交产品修改；[产品源码指纹](test-results/2026-10-23-roaming-source.json)包含 156 个文件，汇总 SHA-256 为 `468DC77FA82AFA7C563EC8541B4B929976377947955F28B5DBC690F5CA779124`。这是工作区源码快照指纹，不是新增 Git 提交。

### 34.1 实现与数据边界

1. 漫游首页连接三门峡、洛阳、郑州、开封、濮阳五个原创叙事篇章，共 15 条线索、11 条来源。场景操作、明确片段选择和确认完成共同推进真实进度；打开、自由阅读、收藏不等于通关或真实到访。文化内容继续标“初稿待校审”，图景继续标原创叙事示意。
2. 亲笔正文从空白开始，保存时才创建 note。资料、选择和来源冻结在可选 `roamingContext`，与正文分开；`sceneRevision`、可选 `contentRevision` 和结构版本分别保留。旧 22 条档案、普通手账、装饰、旧 pose、AI 依据、时间戳与墓碑继续沿用 schema v1；没有清空正式档案或执行批量格式迁移。
3. 平板按真实内容区宽度显示场景、阅读和写作栏；竖屏通过真实写作 Sheet 继续同一草稿。原生 SelectionContainer 跨 Text 选区先生成有出处的摘录卡，再通过 UDMF 拖入草稿，不用按钮替代所要求的拖拽。M12 将漫游、记忆、长卷和个人页的返回明确交给同一 `NavPathStack.pop()` 并消费事件，修复分栏最后一页默认 Back 退出 App 的具体演示问题。
4. 按需登录读取同篇章最新位置检查点，恢复当前线索而非最初入篇参数；离线返回使用同一恢复路径。未保存的非空亲笔正文先确认保存，漫游内登录入口才可用。恢复路由本身不改写账号检查点；“仅登录”保持游客隔离，“复制漫游”才合入规定记录且保留游客原副本。当前有效账号会话的继续入口打开账号页。
5. 记忆详情按稳定 note ID 读取当前已落盘版本，编辑后刷新显示与磁盘一致；只改亲笔正文、标签和版本信封，冻结摘录与来源不随编辑重写。无法恢复的图景修订保留文字与来源，不拿当前图景冒充旧版本。

### 34.2 本地验证、构建与包绑定

本轮最终 `tools/test.ps1` 为 **141/141，失败 / 取消 / 跳过 0**，1289.6555ms；设备报告解析器另 **9/9**。原始输出位于忽略目录 `.local/roaming-rebuild-20261023/local-tests-final-domain.log`。M11 与 M12 阶段同脚本也各为 141/141、解析 9/9，分别记录在 `local-tests-m11.log`、`local-tests-m12.log`；它们是重复批次，不累加为新增用例。

前期领域 + Repository + HTTPS 账号服务三文件 **123/123** 的独立结果仍保留在 `.local/roaming-data-review-check-20261023.log`。三文件命令额外包含 `server/account-service.test.mjs`，必跑脚本的 141 项没有自动包含该文件；123、141 和解析器 9 分属不同范围，不能相加成当前应用总通过数。

主包 M12、测试包 T14、T15 均 `BUILD SUCCESSFUL`，对应 9s428ms、6s776ms、6s971ms。原始日志分别为忽略目录中的 `main-build-m12.log`、`test-build-t14.log`、`test-build-t15.log`。保留既有 API 能力、异常处理和未配置签名等编译提示，未改用户签名。T15 只在登录复制测试中增加两次真实 `pressBack` 收起软键盘，产品继续为同一 M12。

| 包 | 字节数 | SHA-256 | 本节实际范围 |
|---|---:|---|---|
| M10 | 7,618,873 | `597FF85659599EDB39C378C1DBAB4EFBFF76B2FD5166E646A67DFECB83F4D30F` | 开封三线索与完整记忆 CRUD 成功 |
| T8 | 6,887,198 | `10D73AD406139F9B37DB723455466F6264FB84412BBF422FE45BBF5AD2BCCAB9` | 上述开封核心单例 |
| M11 | 7,625,477 | `E5C170AE1393E15DD2D4A77F638E583BCE5E23FADB4405A56FC6EE03499A5338` | 四城、平板摘录、A 首次保存 |
| T9 | 7,008,942 | `459E17E9DC8980556647A4D84637D23FEDF4078D1BACAF1D70ADD12D92F49039` | 三门峡、洛阳、郑州；早期平板失败另列 |
| T10 | 7,010,748 | `7EAC6C1F72F530D5D54750073A39BB2AA95A4BB45AF3C824E8AACE87F29355C2` | 濮阳成功；平板键盘失败另列 |
| T11 | 7,011,271 | `3E4A471529E95EAC157D22D69BA79760BF1C86AB6DF042672CC8908648A7DBAA` | 平板摘录、A 保存成功；目录返回失败另列 |
| **M12（产品冻结）** | **7,629,427** | `FD6E7B3C89A155528FC9166B012AF96DB029DFE8AA379EC4ED669FBECD517094` | 显式导航返回修复；目录、B / A 返程、登录、独立五城入口、单端演示 |
| T12 | 7,011,271 | `80414E8A33898028010BA17D50EA1EB5DECB58303A57B6B1796037D87FDF0E32` | 平板目录成功；B 首次测试定位失败 |
| T13 | 7,011,738 | `64E0750E6983EFDD7DFD01BF1EBAB167EE23F5F7B9561E834C67DB326D4D4E88` | B 接收、续读和编辑成功；A 返程基线助手错误 |
| T14 | 7,010,525 | `22AB32F72DDAF2DD5203026245212471F4882C71D6BFBADDCD8C03BCC3EE5F58` | 原 A 返程、仅登录成功；复制首轮失败 |
| **T15（最后定向测试包）** | **7,010,799** | `62730D071E2AAABC53F74D91D8C73F7A1689921B9A6365A9DE4D15CBAD0A2558` | 复制漫游与最终独立五城入口复验成功，产品未改 |

包字节与 SHA-256 按留存 HAP 和各批清单核对；不发布二进制、凭据或本机开发目录。系统入口的 M5 / M6 / M8 单独见其[证据清单](design/roaming/system/evidence.json)，没有将旧包手工操作归为 M12 复验。

### 34.3 五城与平板的实际设备结果

后续单例均使用 `ExpectedTests=1`、`TestTimeoutMs=600000`，按完整原始摘要判断。

| 场景 | 包 / 设备 | 原始结果与耗时 | 原始报告 |
|---|---|---|---|
| 五城入口不自动完成、不自动生成亲笔记忆 | M12 / T15，手机，最终独立复验 | **Pass 1 / Failure 0 / Error 0 / Ignore 0**，113555ms | [042159](test-results/2026-10-23-042159-b485408f-device.log) |
| 开封三线索、离线出处、亲笔保存／全文读取／编辑／删除墓碑、旧普通手账保留 | M10 / T8，手机 | **Pass 1 / Failure 0 / Error 0 / Ignore 0**，295506ms | [025926](test-results/2026-10-23-025926-e4e71c7f-device.log) |
| 三门峡热点、院落展开和剪纸选择，三条进度落盘 | M11 / T9，手机 | **1/1**，153682ms，Failure / Error / Ignore 0 | [031951](test-results/2026-10-23-031951-3fa6e759-device.log) |
| 洛阳两岸观察、诗句展开和水席片段，三条进度落盘 | M11 / T9，手机 | **1/1**，155725ms，Failure / Error / Ignore 0 | [032333](test-results/2026-10-23-032333-d47f032d-device.log) |
| 郑州城门路径、诗句和相会选择，三条进度落盘 | M11 / T9，手机 | **1/1**，156440ms，Failure / Error / Ignore 0 | [032642](test-results/2026-10-23-032642-f1270743-device.log) |
| 濮阳蚌塑、传说与庙会选择，三条进度落盘 | M11 / T10，手机 | **1/1**，154821ms，Failure / Error / Ignore 0 | [032958](test-results/2026-10-23-032958-f5b393d9-device.log) |
| 原生跨 Text 全选、摘录卡拖入草稿、竖屏 Sheet 再回横屏、正文／标签／摘录保留后正常保存 | M11 / T11，平板 | **1/1**，113514ms，Failure / Error / Ignore 0 | [033111](test-results/2026-10-23-033111-9a3c9460-device.log) |
| UI 创建开封与洛阳记忆，左目录切换正文与出处，旋转后不重选仍保留洛阳 | M12 / T12，平板 | **1/1**，209582ms，Failure / Error / Ignore 0 | [034327](test-results/2026-10-23-034327-a4e2774e-device.log) |

最终入口复验单独绑定 M12 / T15；早期 M7 / T4 的入口子用例虽通过，其六例报告仍为 Pass 1 / Error 5，原始错误保留在 34.7，不由最终复验覆盖。本轮机器清单共收录 23 份设备原始报告，其中 13 份完整成功、10 份失败或中断；这是报告数量，不是同一最终包整套通过数。

四城合计 12 条真实确认线索，0 条自动亲笔记忆、0 条自动收藏，32 个原图／布局文件与各步选择见[四城清单](design/roaming/four-cities/evidence.json)。该批仅临时移除手机到任务账号服务的反向端口，未整机断网。HDC 删除同规则时实际全局移除了映射，平板映射曾短暂受影响，随后立即恢复；四城结束两端原映射均恢复。端口原始返回和边界保留在清单中，不把当时无网络断言的平板游客用例当作同步验收。

平板有 11 张原 PNG、11 份布局，逐字节和 SHA-256 与原件一致，均已实际查看。两次成功会话均真实调用主窗口方向接口，实际尺寸从 2880×1920 转为 1920×2880，再回 2880×1920；未用改页面宽度模拟。横屏漫游目的页 bounds 为 `[721,86][2880,1920]`。摘录精确为线索正文、单换行、所选片段解释，冻结出处随 note 落盘。目录两条记忆的原始 JSON 在切换、旋转前后逐字相同，洛阳保持选中。完整值见[平板清单](design/roaming/tablet/evidence.json)。摘录仍属于 M11 / T11，目录属于 M12 / T12。

### 34.4 同一账号 A → B → 原 A 的实际闭环

| 阶段 | 包 / 设备 | 完整结果与耗时 | 原始报告 |
|---|---|---|---|
| A 真实注册本轮空账号，完成开封首条、UI 保存亲笔记忆，回第 2 条并等服务器确认 | M11 / T11，手机 A | **Pass 1 / Failure 0 / Error 0 / Ignore 0**，146497ms | [033345](test-results/2026-10-23-033345-efb6a745-device.log) |
| B 实际登录同账号，从空测试工作区接收，继续第 2、3 条并编辑同一篇记忆 | M12 / T13，平板 B | **1/1**，151558ms，Failure / Error / Ignore 0 | [035302](test-results/2026-10-23-035302-a6ad74dc-device.log) |
| 原 A 库保留旧版本，重新认证后接收 B 的新正文、同一 note 和三条进度 | M12 / T14，原手机 A | **1/1**，81620ms，Failure / Error / Ignore 0 | [040257](test-results/2026-10-23-040257-eac09c66-device.log) |

本轮实际使用自建同账号 HTTPS / SQLite 服务，经本机 HDC 反向端口连接，没有部署云服务，也没有将其写成鸿蒙原生可信设备传输。A、B 使用不同安装实例，note 保持 A 创建时的 ID；B 经正常 UI 编辑后更新正文、版本时间和来源设备，冻结摘录、来源与修订不变，原 A 收到的新版本与 B 相同。

[逐字段比较](design/roaming/sync/comparison.json)的 10 项检查均为 true：初次 B 完整接收 A；重试 B 的 note／上下文／已完成进度仍同 A，检查点正文相同；原 A 启动前仍为 A 原版本；B 编辑同一 note、正文和版本确有更新、冻结上下文不变、原首条进度保留并完成三条；原 A 返程完整收到 B。初次 B 已正常打开第 2 条，正式页面更新了同一位置检查点的时间和设备，因此重试检查点版本可变，不能把该合法变化误判为接收丢字段。

原 A 的更新前基线在启动 EntryAbility、触发自动同步之前由主机只读取得，原档案 **6530 字节**、SHA-256 `24C4AEF1EA98481F77FC6FEE675516C1BCF3CBDADE3D8BEFDC091D4D64ECD3ED`，当时仅 1 条已完成线索、位置为第 2 条、正文仍为原文。它与返程的新正文、三条线索形成真实前后对照，没有先同步再伪称取到旧版本。公开清单不包含身份 XML、账号凭据或 ASSET 内容。

同账号图集的 18 个原始文件包含 Hypium 完成后再次从原 A 阅读记忆的两份原图／布局；后续复阅不是新增 Hypium 用例，不增加上述三阶段通过数。

### 34.5 按需登录与游客原副本

| 场景 | 包 / 设备 | 完整结果与耗时 | 原始报告 |
|---|---|---|---|
| 游客开封首条第二选择完成后进入第 2 条；空白登录页离线返回；实际登录选择“仅登录” | M12 / T14，平板 | **Pass 1 / Failure 0 / Error 0 / Ignore 0**，95405ms | [040454](test-results/2026-10-23-040454-b217a99a-device.log) |
| 游客洛阳首条亲笔记忆经 UI 保存并完成首条；选择“复制漫游”后回第 2 条、账号读回同一记忆与出处 | M12 / T15，平板 | **1/1**，116259ms，Failure / Error / Ignore 0 | [041142](test-results/2026-10-23-041142-2c32989f-device.log) |

“仅登录”后页面恢复触发登录时的第 2 条，而账号保持 A/B/A 留下的开封三条进度及第 3 条检查点，没有游客来源设备的记录混入；游客原始 snapshot 字符串逐字不变。“复制漫游”后，账号有同 ID、版本、正文、标签和完整冻结上下文的洛阳记忆及首条进度，游客原副本仍逐字不变，原账号开封记录继续保留。测试依次运行在 A/B/A 之后，复制会向本轮测试账号增加洛阳记录，因此不能反过来以新增数据后的状态验收原 A 的单条记忆基线。

身份字段只从测试 feature 的私有 fixture 读取；两例没有截图身份页或凭据，错误在输出前脱敏。它们证明当前具体登录入口、隔离和明确复制路径，不代替华为账号、所有身份恢复或实机验证。

两条路径的 14 个原始截图／布局见[按需登录图集](design/roaming/login/README.md)；它们是上述用例的画面证据，不额外计作新用例。

### 34.6 系统入口、自由文化库与单端演示

[系统入口清单](design/roaming/system/evidence.json)包含 **10 条已通过手工原生操作记录和 1 条原始失败**，不是 11 条 Hypium 用例，也不合并进上表设备用例数：

- M5 经实际输入、选择和确认保存一篇游客记忆，探索仍为 0/3。
- M6 在真实桌面添加“继续这段漫游”“最近一页”两张普通 2×4 卡片；继续卡、最近页卡分别冷／热启动四条路径到达正确篇章或原 note。原生 ShareKit 面板与实际 PNG 明信片已查看，未选择外部接收者；取消后原独立 Preferences 全部 3374 字节一致。
- M6 删除最后一页保留墓碑和其他进度，桌面记忆卡清除旧正文；首次空卡点击仍留旧篇章的错误保留。M8 修复空路由清理后，空卡冷／热启动均回记忆空态，未生成默认正式档案。

上述旧包结果只绑定 M5 / M6 / M8。接口核验日期、API 26 声明与官方网页仅取得应用壳的限制见[系统接口记录](research/roaming-native-system-20261023.md)；不把接口存在或普通卡片可用扩展成互动卡片、所有设备或可信接续已完成。

M12 另做原生文化库定向操作：检索“牡丹”，找到 `roam-ly-peony`，真实收藏并加“研究资料”标签，再自由打开第 2 条；磁盘为 1 条该文化收藏、0 条 note、0 条完成线索。它是手工检查，不增加 Hypium 通过数，也不把自由阅读写成通关。

M12 单端演示[结果](design/roaming/demo/result.json)为 `completed`、**383 条命令**，完成五城入口、开封三条真实互动、点灯、空白亲笔输入、正常保存、最近记忆全文与冻结出处、系统分享和取消。执行时仅任务账号服务不可达，未执行账号登录、AI 或网络同步；不称为整机完全断网。两次旧演示尝试的灯事定位／输入问题继续留在本机原始过程，最终以 `demo-m12-r3` 的连续结果为准。

取消分享前后精确独立档案 **6705 字节**，SHA-256 均为 `D215232CB8E443D887D43E320FC6321473BF761C81FB092056FBA18D1D283A86`，[完整档案比较](design/roaming/demo/share-cancel-comparison.json)为 `wholePreferencesIdentical=true`。取消不解释为第三方收到内容。383 条命令是自动化执行计数，不能当作真人演示用时或已录制备用视频。

### 34.7 保留的失败与修正

| 批次 | 原始结果 | 定位与处理 | 原始报告 |
|---|---|---|---|
| 手机初轮六例 | Pass 1 / Failure 0 / Error 5 / Ignore 0 | 测试直接查询未滚入的目标或确认控件；入口子例通过，其他错误保留，改为真实滚动定位 | [020820](test-results/2026-10-23-020820-55d612d0-device.log) |
| 手机第二轮六例，M7 / T4 | Pass 1 / Failure 0 / Error 5 / Ignore 0 | 开封已经完成三条并保存 note，随后深层长卷搜索达到 240000ms 上限；未结束的 `scrollSearch` 导致后四例 Driver 并发错误，不能据此判为四城业务均失败 | [023435](test-results/2026-10-23-023435-7a9a7e05-device.log) |
| 开封修复前单例 | Pass 0 / Failure 0 / Error 1 / Ignore 0，325713ms | `roam-memory-scroll` 目标未找到；实际编辑已落盘而详情仍显示旧正文。M10 以当前记录解析、快照与版本键刷新修复，T8 核对全文和磁盘通过 | [024811](test-results/2026-10-23-024811-cd1fff44-device.log) |
| 平板摘录 R1，M11 / T9 | 无完整结束摘要 | 锁屏启动中断，停止原测试后重新准备；不登记通过或伪造结束计数 | [031733](test-results/2026-10-23-031733-a05d3004-device.log) |
| 平板摘录 R2，M11 / T9 | Pass 0 / Error 1，30011ms | 未先滑动就以已观察后的解释作为测试前提，实际仍为操作提示；T10 加入所需真实滑动 | [032542](test-results/2026-10-23-032542-1769855c-device.log) |
| 平板摘录 R3，M11 / T10 | Pass 0 / Error 1，77842ms | 软键盘遮住标签，`roam-writing-column` 目标未露出；T11 在两次输入后真实收键盘，原摘录和落盘断言保留 | [032803](test-results/2026-10-23-032803-1f721c4b-device.log) |
| 平板目录首轮，M11 / T11 | Pass 0 / Error 1，74376ms | 保存开封后默认 Back 退出 App，找不到 `roaming-home`；M12 明确同栈 pop 并消费返回，T12 复验通过。未将焦点或 HdsTabs 猜测写成已证实根因 | [033344](test-results/2026-10-23-033344-faf41c43-device.log) |
| B 首轮，M12 / T12 | Pass 0 / Error 1，50812ms | A 数据已接收，但测试把登录恢复后的后方首页当作已返回，后续误找 `roam-chapter-scroll`；T13 经真实 Back 回完整首页后继续 | [034753](test-results/2026-10-23-034753-5376528e-device.log) |
| 原 A 返程首轮，M12 / T13 | Pass 0 / Error 1，599ms | 测试 feature 的 `createModuleContext` 未切换实际 Preferences 数据目录，误报旧身份指针缺失；不是 A 原库丢失。改为启动前主机只读取精确原库，启动后使用实际 EntryAbility Context | [035906](test-results/2026-10-23-035906-f35194c2-device.log) |
| 复制漫游首轮，M12 / T14 | Pass 0 / Error 1，54027ms | 正文输入后键盘遮住标签，报 `roam-writing-column` 目标未找到；T15 只增加两次真实收键盘操作，M12 产品不变，重试通过 | [040848](test-results/2026-10-23-040848-d690452a-device.log) |

表中未逐项重复的 Failure / Ignore 均为 0；无摘要的平板 R1 除外，不能补造计数。早期未留完整包摘要的失败按原报告和阶段描述保留，不追填无法核实的哈希。测试定位、平台返回行为和详情刷新分别记录，修复后通过不覆盖原始失败。

### 34.8 仍未完成的范围与交接

本轮结果限定于所列模拟器、包版本和实际演示路径，没有运行完整历史 UI、大字体、压力或泛化安全套件。缺少实机、华为账号、鸿蒙原生可信设备传输／系统应用接续、完整冲突恢复与生产服务部署的当前证据；原生 KV 的字段保留和接口基础不等于两端可信组网已通过。HarmonyOS 7 / API 26 不等于比赛的 OpenHarmony API ≥12 兼容承诺。

新版[Word](deliverables/云河纪-省赛五城漫游说明-20261023.docx)和[PDF](deliverables/云河纪-省赛五城漫游说明-20261023.pdf)已同源生成12页，最终12页全部实际渲染打开检查，16张原生截图以原字节嵌入，旧材料保持不变；最终字节/哈希与独立Word导出、缺soffice诊断见[材料核验](test-results/2026-10-23-roaming-materials.json)。真人演示计时、备用视频和实际比赛提交结果仍需各自验收，本节不宣称已录制视频或已发布、上传、提交Git。工程与正式用户数据继续保留，测试账号、私有fixture和复现所需原A库按当前约定保留；本轮业务日志读取已停止，双端18443反向端口已恢复，设备保留首页供原生试玩。完整事实、现场包与复现依赖见[ROAMING_HANDOVER_20261023](ROAMING_HANDOVER_20261023.md)。

<a id="paper-journey-20261025"></a>

## 35. 纸上生城、原生四页签与同账号作品延续（2026-10-25）

### 35.1 实现范围与赛题口径

新主玩法为原生 Canvas 纸景：五城各有不同空间关系，支持平纸/对折/四折、真实笔迹剪口、展开、透光、独立移光、四步撤销、断纸反馈、换新纸与用户确认存入记忆。移光投影使用实际 mask 并跟随手指，本地光位不写进度；达成目标不会自动保存 note。首页、文化库、记忆和我的统一为四页签。文化库保留 22 条档案、原文全文检索、多维筛选、收藏分类和篇章阅读入口；旧 note、pose、AI/漫游冻结信息与墓碑继续保留。具体机制、文件与文化依据边界见[本轮交接](PAPER_JOURNEY_HANDOVER_20261025.md)。

原题第 4 页允许本地离线存储，并把云端存储、多设备同步列为创新加分项、不强制；第 5 页仍列出华为账号/分布式/状态等详细目标。本轮已验的是自建账号 HTTPS，不能据此宣称华为账号或鸿蒙原生可信组网已完成。复核来源见[研究第 1 节](research/cultural-game-20261025.md#1-原比赛-pdf-的真实边界)。工程仍为 HarmonyOS 7 / API 26，不自动代表 OpenHarmony API ≥12 兼容。

### 35.2 本地、服务与包绑定

| 项目 | 当前记录 | 证据与边界 |
|---|---|---|
| `tools/test.ps1` 本地测试 | **241/241 通过，fail 0** | [最终完整日志](test-results/2026-10-25-paper-final-local.log)。含纸景多解、断纸与撤销、codec/损坏保护、冻结字段、语义合并与回包确认；不与旧轮次相加。 |
| 设备报告解析器 | **9/9 通过** | [独立解析日志](test-results/2026-10-25-paper-report-parser.log)，最终本地日志也保留同次摘要。 |
| 账号 HTTPS 服务测试 | **2/2 通过，fail 0** | [服务日志](test-results/2026-10-25-paper-service.log)。服务用例不代替下面的原生双端 UI 结果。 |
| 最终主包 | **纸景 M14 构建成功** | [主包构建日志](test-results/2026-10-25-paper-main-m14-build.log)，9,047,917 字节，SHA-256 `92A5872A056618C643DF4B2125F82F6244A9F916CAD2A32DF2632C794B2560B3`。 |
| T14 保存/分享阶段测试包 | **构建成功** | [T14 构建日志](test-results/2026-10-25-paper-test-t14-build.log)，7,660,553 字节，SHA-256 `B5DAFD990AC78282932816C6611D7CAB257AAD21D6543783A0F9A6ABE92CE772`。保留手机整套 1/2、Error 1 与分享 1/1 的实际包归属。 |
| 最后定向测试包 T15 | **构建成功** | [T15 构建日志](test-results/2026-10-25-paper-test-t15-build.log)，7,660,422 字节，SHA-256 `30D9A9144AD55071DB06171B4C70CFA4D7E2A81E857667E957F3C813A66635DA`。入口单例与最终原 A 接收各 1/1；测试 fixture 不进入现场主包。 |

当前最终绑定为 **2026-10-25 纸景 M14/T15**，T14 阶段另行保留。[机器清单](test-results/2026-10-25-paper-journey.json)登记冻结路径及各阶段 HAP 哈希、源码摘要和原始报告绑定。M14 主包保持不变，T15 仅修正入口用例最后的页签访问。下文纸景 M12/T12 同属 2026-10-25，不是第 34 节的 2026-10-23 漫游 M12。构建成功与本地通过不扩大原生设备覆盖范围。

### 35.3 已完成的原生设备阶段

本轮使用 HarmonyOS 7 / API 26 原生手机与真实 tablet 类型模拟器；不是浏览器预览。以下直接按原始 `Tests run / Failure / Error / Pass / Ignore` 摘要登记。

| 阶段 | 真实操作与核对 | 包绑定 | 原始结果 | 耗时 / 原始报告 |
|---|---|---|---|---|
| 手机首轮 `PaperJourneyTest` | 五城真实入口、文化库查找与我的；独立游客库剪纸、撤销、透光、确认存纸景、冷重开、原收藏保持 | 首次可运行主包/测试包，未固化 HAP 哈希 | Tests 2 / Pass 2 / Failure 0 / Error 0 / Ignore 0 | suite 260239 ms；[175839](test-results/2026-10-25-175839-d3c8a851-device.log) |
| 手机 A `device_a_register_cut_and_save_frozen_paper_memory` | 独立空库 UI 注册临时账号、剪三处纸窗、输入并保存；落盘和服务端实际版本确认 | 纸景 **M5/T4** | Tests 1 / Pass 1 / Failure 0 / Error 0 / Ignore 0 | 115261 ms；[184037](test-results/2026-10-25-184037-28083ff3-device.log) |
| 平板 B `device_b_receive_exact_mask_note_sources_and_continue_by_ui` | 同一临时账号、独立空库接收真实 mask/note/完整 sources；从原 note 继续 UI 剪纸，冻结原 note 不变 | 纸景 **M6/T5** | Tests 1 / Pass 1 / Failure 0 / Error 0 / Ignore 0 | 94554 ms；[184732](test-results/2026-10-25-184732-911d4d70-device.log) |
| 原手机 A `device_a_receive_b_new_version_in_original_scope_and_keep_frozen_memory` | 复用原 A scope 恢复身份、重新认证，接收 B 的新版本；重新打开原记忆核对冻结作品与来源 | 纸景 **M8/T6** | Tests 1 / Pass 1 / Failure 0 / Error 0 / Ignore 0 | 93583 ms；[185312](test-results/2026-10-25-185312-f252f99b-device.log) |
| M14 手机 `PaperJourneyTest` 整套复跑 | 保存/撤销/冷重开/旧收藏用例通过；入口用例先走过五城/文化库，最后访问已删除的 `paper-home-profile` 旧重复入口，报 NoCandidates，不将整项记通过 | 纸景 **M14/T14** | **Tests 2 / Pass 1 / Failure 0 / Error 1 / Ignore 0** | suite 264976 ms；保存用例 101283 ms、入口用例 163693 ms；[194540](test-results/2026-10-25-194540-78673705-device.log) |
| 入口单例修正后复跑 | 只将测试最后入口改为真实“我的”页签 `tab-3`，主包 M14 不变；五城、文化库与我的入口整项重新验证 | 纸景 **M14/T15** | Tests 1 / Pass 1 / Failure 0 / Error 0 / Ignore 0 | 152598 ms；[195908](test-results/2026-10-25-195908-50c4ff34-device.log)，不与 T14 保存用例混记为同次 2/2。 |
| 最终原手机 A 接收复跑 | 原 A 身份与 scope 重新接收 B 的实际续剪版本，当前作品与冻结 note/完整来源再次深比较 | 纸景 **M14/T15** | Tests 1 / Pass 1 / Failure 0 / Error 0 / Ignore 0 | 97001 ms；[200417](test-results/2026-10-25-200417-ebfb8482-device.log)、[最终回 A 事件](test-results/2026-10-25-paper-sync-final-return-events.log) |

三段 HTTPS 结果与最终回 A 复跑分别保留各自 1/1；手机保存用例在 T14、入口单例在 T15 分阶段通过。不能将它们相加写成“一份最终测试包全套通过”或“T15 同次 2/2”。`aa test` 返回码为 0 不单独作为用例通过依据。

[初轮完整分片还原比较](test-results/2026-10-25-paper-sync-comparison.json)以 220 字符 HiLog 分片完整还原 JSON，再深比较字段和实际 mask、逻辑版本，结果为 PASS：A 保存和 B 收到的作品一致，B 续剪和原 A 回收到的新作品一致；冻结 note 在 `a-saved / b-received / b-continued / a-return` 四阶段全部一致。M14/T15 原 A 再次接收后，[最终完整比较](test-results/2026-10-25-paper-sync-final-comparison.json)仍为 PASS，作品与 note 的三组哈希同下表。比较覆盖 `body/deleted/deviceId/id/kind/paperContext/paperTheme/siteId/stampType/tags/updatedAt`，`paperContext` 内含实际作品和三条完整来源，不只核对数量或屏幕文案。

| 比较对象 | SHA-256 |
|---|---|
| 四阶段相同的冻结 note | `7858845A892CBFD86343E3C9B05B5103586AEBA244351896D5557A15D6151E0D` |
| A 原作品 / B 刚收到作品 | `13FC389FEC17DC6F2B6F8BD2A8D32EA484C3311C125BDAFCAFBA7BF2BA43E061` |
| B 续剪作品 / 原 A 收到新作品 | `EAD193981EC45B00EC2BA7A883C718869FEF35FB8954C2E6B92A2A2FF795486E` |

### 35.4 持久化、语义合并和冻结记忆

- 档案仍为 `schemaVersion=1`；纸景当前状态保存为 `progress:paper-journey:v1:<cityId>`，阅读位置为独立的 `progress:paper-position:v1`。旧漫游、开封城、探方 progress 不改 ID、不互相冒充。
- `PaperWorkV1` 保存展开纸面 40×48 mask、最多四步历史、折法、纸色、透光、时间与完成快照。通用 `mergeRecords` 实际调用纸景适配：当前编辑整条 LWW，完成快照独立保留，不按位叠加两端剪口。墓碑仍走原版本比较，未知/损坏正文保留原文，不能补为空纸。
- `paperWorkIsUnreadable(records, cityId)` 区分不存在与损坏：已有 active 记录的 kind、siteId、正文或城市错误时，Index 在排队提交前拒绝写入并提示，保留原 body/快照且不写最近位置；页面禁用剪纸并显示不可读说明。不能把既有损坏作品当作空白纸覆盖。
- 用户明确确认后新建普通 note；达成目标不自动保存。`paperContext` 冻结城市、题名、文化说明、实际作品、可选 excerpt 与三条完整来源（含 URL、quote、年代和查阅日期）；正文由用户输入，来源不自动改写成亲笔感想。此可选字段与原镜头/AI/漫游上下文分别复制、校验和比较，缺省旧 note 不补值、不改时间戳。
- 独立移光模式只改变本地光位，投影来自实际 mask；观察期间原 raw/body/mask/更新时间均保持，切回剪纸后才按真实剪口写进度。它与作品的透光开关分别处理，不能把观察动作算作剪纸或完成。
- 保存队列按动作串行提交，Index 在真正提交时重新取当前快照和逻辑时钟；成功排空后补处理最新 records，失败使用未保存状态。M14 已包含最新保护和队列修复，本轮最终本地结果为 241/241；T14 保存/撤销/冷重开用例、T15 入口单例及原 A 接收分别通过，按各自阶段保留覆盖范围。

### 35.5 移光、原生选摘与系统入口

| 专项 / 原生用例 | 实际核对 | 包绑定 | 原始摘要 | 耗时 / 证据 |
|---|---|---|---|---|
| 首轮 ShareKit `native_paper_share_cancel_preserves_note_and_png_contains_real_cut_pixels` | 真实剪口生成 PNG 并调起系统分享；取消后原 note 保持。与未剪图相比 RGBA 差异 3,144 像素 | 纸景 **M8/T6** | Tests 1 / Pass 1 / Failure 0 / Error 0 / Ignore 0 | 54086 ms；[185816 原始报告](test-results/2026-10-25-185816-c2aa6b93-device.log)、[分享事件](test-results/2026-10-25-paper-share-events.log) |
| 移光 `native_light_pan_changes_mask_projection_without_editing_work_then_cut_resumes` | 投影区域 66,444 像素内 13,921 像素改变；原 raw/body/mask/时间戳保持，随后恢复剪纸并保存 | 纸景 **M12/T12** | Tests 1 / Pass 1 / Failure 0 / Error 0 / Ignore 0 | 42178 ms；[193617 Light](test-results/2026-10-25-193617-176248fd-device.log)、[移光事件](test-results/2026-10-25-paper-light-events.log) |
| 选摘 `native_tablet_selection_udmf_drag_and_explicit_save_freeze_excerpt` | 原生 SelectionContainer 跨 Text 选择，UDMF 拖入草稿；完整 292 字摘录、三条来源、真实 mask 在明确保存与落盘重读后保持，草稿不自动生成 note | 纸景 **M12/T12** | Tests 1 / Pass 1 / Failure 0 / Error 0 / Ignore 0 | 79785 ms；[193617 Excerpt](test-results/2026-10-25-193617-3c104dc7-device.log)、[摘录事件](test-results/2026-10-25-paper-excerpt-events.log) |
| 桌面卡片 `native_desktop_forms_reopen_paper_city_and_exact_note_cold_and_hot` | 两张卡片各核对 Ability 冷 onCreate / 热 onNewWant，共四次精确城市与 note 路由；mask 和冻结 note 保持 | 纸景 **M12/T12** | Tests 1 / Pass 1 / Failure 0 / Error 0 / Ignore 0 | 162757 ms；[193737 Forms](test-results/2026-10-25-193737-ade3eb47-device.log)、[卡片事件](test-results/2026-10-25-paper-forms-events.log) |
| M14 ShareKit 定向复跑 | 1080×1968 PNG 的真实剪口区域改变 2,988 像素，文字区域 0 差异；调起系统分享，取消后完整快照与 note 版本一致，未选择接收方 | 纸景 **M14/T14** | Tests 1 / Pass 1 / Failure 0 / Error 0 / Ignore 0 | 56806 ms；[194541 原始报告](test-results/2026-10-25-194541-1c838f41-device.log)、[最终分享事件](test-results/2026-10-25-paper-share-final-events.log) |

M12/T12 自动桌面专项覆盖的是两张普通卡片的 Ability 冷/热路由，该次自动用例未做外部整个进程强停。M14 平板另完成**人工定向**四次路由：经 HDC 真正 force-stop 并确认 `pidof` 为空后，点击真实桌面 Continue 卡 `1711419616` 打开 `paper-py` 已存作品，Memory 卡 `77642583` 打开独立视觉测试库中同一篇唯一三门峡 note；两卡热 onNewWant 路由也均实际走通。见[四次人工路由摘要](test-results/2026-10-25-paper-desktop-process.json)，不计入 Hypium Tests/Pass，也没有在人工步骤新增整库深比较。之后只移除本轮新增这两张卡，逐卡菜单与系统明确确认均已完成，其他既有卡保留；独立视觉库有意保留供用户试玩，不清空。实际原图与相邻 layout 已归档到[画面索引](design/paper-journey/README.md)，公开图集不引用露出既有卡的清理图。

上述结果均属于新纸景本轮实际包；2026-10-23 的旧漫游选摘、分享与卡片结果继续保留在第 34 节，不作替代。

### 35.6 五城真实手势与离线边界

[五城手势 JSONL](test-results/2026-10-25-paper-five-city-gestures.jsonl)记录纸景 M8 阶段真实 tablet 模拟器逐城操作：三门峡、洛阳、郑州、开封、濮阳均为 `nativeGesturesOnly:true / passed:true`，目标由真实原生手势达成，未注入 mask，分别留有 `pad-five-<city>-complete.jpeg`。这是逐城原始手势记录，不登记成 Hypium 5/5。

[服务停止记录](test-results/2026-10-25-paper-offline-service.json)确认本任务本机 18443 HTTPS 服务监听为 0。准确结论是本任务服务停止后可完成五城本地操作，不能称整台设备断开全部网络。真人试玩的趣味、可理解性与实际 4—6 分钟单城时长仍未校准。

### 35.7 保留的失败与修复

下列前五份设备原始报告均为 **Tests 1 / Pass 0 / Failure 0 / Error 1 / Ignore 0**；第六份 M14/T14 手机整套为 **Tests 2 / Pass 1 / Failure 0 / Error 1 / Ignore 0**。原始 Error 不因后续通过而删除。

| 原始报告 | 包绑定 / 耗时 | 问题与修复边界 |
|---|---|---|
| [190026 Forms](test-results/2026-10-25-190026-e137cb41-device.log) | 纸景 **M8/T6** / 68013 ms | 自动滚动碰到 Dock 后切换页签，原 `paper-profile` 节点失效/缺失；后续约束实际滚动位置。 |
| [191326 Forms](test-results/2026-10-25-191326-d1300703-device.log) | 纸景 **M10/T8** / 81725 ms | 同类 Dock/滚动导致切页，缺失 `paper-profile`；不把该 Error 改写为通过。 |
| [191327 Excerpt](test-results/2026-10-25-191327-f3c6ceeb-device.log) | 纸景 **M10/T8** / 91666 ms | 长摘录在窄平板 Sheet 中叠加键盘后遮挡正文，属于真实产品布局缺陷。 |
| [193002 Excerpt](test-results/2026-10-25-193002-696d1c56-device.log) | 纸景 **M11/T11** / 71173 ms | 同一 Sheet 问题仍可复现，缺失 `paper-memory-body`。改为 **680vp 底部 Sheet**，并调整键盘抬升与滚动后，M12/T12 摘录独立 1/1。 |
| [193002 Forms](test-results/2026-10-25-193002-f15b5a31-device.log) | 纸景 **M11/T11** / 144219 ms | 终止冷 Ability 后可能返回桌面，预期 Hypium 宿主节点不存在；按实际冷返回生命周期调整后，M12/T12 卡片独立 1/1。未据此宣称外部进程强停通过。 |
| [194540 手机整套](test-results/2026-10-25-194540-78673705-device.log) | 纸景 **M14/T14** / suite 264976 ms | 保存/撤销/冷重开/旧收藏用例 101283 ms 通过；入口用例 163693 ms，最后访问已删除的旧 `paper-home-profile` 后报 NoCandidates，原始流表现为 `paper-journey-home` 不存在。仅改测试走 `tab-3` 后，M14/T15 [入口单例](test-results/2026-10-25-195908-50c4ff34-device.log) 1/1、152598 ms，原整套 Error 保留。 |

两次摘录 Error 反映实际 Sheet 缺陷，不能把六次都归为测试误差。专项与入口单例复跑分别保留在 35.3、35.5 节，既不覆盖原 Error，也不累加为最终包套件通过。

本地和构建失败另存：

- [首轮主包构建失败](test-results/2026-10-25-paper-first-main-failure.log)保留 ArkTS 编译诊断，包括未声明类型的对象字面量、未初始化回调、组件 `width` 名称冲突、`FontWeight.Light` 不存在及筛选 symbol 资源不存在；这些属于构建失败，不是设备 Failure/Error。最终 M14 构建成功日志见 35.2 节。
- [首轮本地失败](test-results/2026-10-25-paper-first-local-failure.log)为 **38 项 / pass 37 / fail 1**：Node 无法解析 `ArchiveDomain.ts` 引入的 `GameProgressMerge`，报 `ERR_MODULE_NOT_FOUND`；最终本地 241/241 另有完整日志，不隐藏原失败。
- [T9 编译失败](test-results/2026-10-25-paper-t9-compile-failure.log)保留 ArkTS 对任意类型 `throw` 的拒绝；随后以 `as Error` 保留原错误栈，T14 测试包构建成功日志见 35.2 节。
- 返 A 的一次过期 HAP 在安装/`aa test` 之前被新鲜度保护拒绝，没有开始设备用例；见[机器清单说明](test-results/2026-10-25-paper-journey.json)。它既不是设备 Failure/Error，也不是通过；重建后原 A 独立结果为 M8/T6 的 1/1。

### 35.8 交付状态与覆盖边界

T15 字节、SHA-256、构建日志、入口单例 1/1、最终原 A 接收 1/1 及完整比较 PASS 已登记，M14/T14 保存用例和分享用例的包归属保持。[机器清单](test-results/2026-10-25-paper-journey.json)最新绑定已为 `m14-t15`，逐次收录 17 份设备原始报告，其中 6 份含 Error；这是报告数量，不是同一最终包的用例通过数。

人工四次桌面路由与本轮两张新卡移除已完成，独立试玩库和现有模拟器数据有意保留。M14 原生截图及相邻 layout 已归档到[画面索引](design/paper-journey/README.md)，包含回读先前五城实际作品、移光、四页签和记忆；`images.json` 对应文件哈希，`overview.jpeg` 为真实截图等比拼图。回读画面不称为五城重做或新增 Hypium 用例。主任务已实际查看 M14 平板浅纸记忆页及“我的”页系统栏深字正常；公开图像表与图片隐私检查由主任务维护，露出既有卡的清理图不公开。

源位置的原 fixture 已保护恢复，纸景 fixture 与不可变 T15 HAP 只留在私有 `.local/`。下次设备测试需明确重新准备 fixture，再按对应源码与 fixture 构建测试包；不修改原 HAP 时间绕过新鲜度保护。产品主包 M14 未改。[18443 服务恢复记录](test-results/2026-10-25-paper-service-restored.json)为 health 200，现有模拟器与独立试玩库保留。

本轮没有取得华为账号、鸿蒙可信设备双端传输/系统应用接续、公网云部署、完整备份恢复回退、实体设备或全历史 UI 的新通过结论。新纸景“复制漫游”没有独立设备验收，不能借 UI 内先注册再剪纸的 HTTPS 结果代替。旧 Word/PDF、视频与赛事 RAR 未更新，真人试玩与时长尚未校准。后续只围绕当前演示出现的具体问题定向验证，不把大字体、泛化安全或压力套件扩为本轮门禁。

本轮按所列定向结果交付，不称为同一 T15 测试包全套通过；原六份 Error 和未覆盖能力继续保留。正式账号与用户数据继续保留；测试凭据只在被忽略的 `.local/` 和测试 rawfile，不能进入公开截图、日志或主 HAP。

<a id="river-market-20261025"></a>

## 36. 汴京开市经营样板与纸景手势热路径（2026-10-25）

用户反馈“没有看出来游戏性、很卡”，并明确选择“有策略和反馈的经营模拟”。本轮先实现一个开封经营样板，不继续把未获真人认可的纸景机制复制到五城。首页切为《汴京开市》，原五城纸景保留次级入口；22条档案、文化库、记忆、我的和历史观察路线继续保留。原生画面见[本轮图集](design/river-market/README.md)，交接见[经营交接](RIVER_MARKET_HANDOVER_20261025.md)，实际参考与文化边界见[研究](research/river-market-20261025.md)。本节的M/T从本轮重新命名，不是第35节的纸景M14/T15。

### 36.1 可玩循环与数据

六铺位、六伙计、四段公开客流共100客；建铺/拆铺、调人、每段两趟补货、街灯与油量共同决定接待结果。原生Canvas回放领域真实逐客结果，不随机演出成功；回放本身不推进经济。主画面提供目标、库存、需求、三区通行与灯火、主要流失原因，完整账本提供缺货/人手/拥挤/暗街/无对应铺子的分别计数。

水饭、肉食、夜深提瓶卖茶与灯烛有《东京梦华录》卷二/三依据，孟元老南宋追记的语境和“初稿待校审”集中呈现。四段节奏、地图、客流、钱价、库存、人手和灯油消耗是原创游戏参数，不是北宋复原。没有打包未经授权的参考网页配图。

外层schema v1保持，经营独立记录 `progress:river-market:v1:kaifeng`，完整库存账目按确定性LWW选一个版本，不能跨端相加。每次安排按队列从最新Root快照写入，真实flush后确认；损坏正文不覆盖，墓碑到达后普通动作不复活，明确重新开市才允许创建新局。旧ID、时间、pose、装饰、AI冻结依据与其他墓碑保持。只有用户确认自己的文字才新建普通note，冻结眼前已确认收市版本的成绩与原文出处，不因另一端新局替换成绩。新经营HTTPS接线已实现，本轮未跑经营A→B→A设备专项。

### 36.2 本地、构建与包关系

`tools/test.ps1` **252/252，fail/cancel/skip=0**，报告解析 **9/9**，见[本地完整输出](test-results/2026-10-25-market-local.log)。经营领域11项纳入总数；旧pose、AI来源、schema兼容和墓碑的原断言保留。本轮没有修改服务实现或把旧服务结果计为新执行。

主包M3与最终测试包T4均 `BUILD SUCCESSFUL`，见[主包构建](test-results/2026-10-25-market-main-m3-build.log)和[测试构建](test-results/2026-10-25-market-test-t4-build.log)。保留既有能力/异常提示、重复memory-search ID和未配置签名警告，没有修改用户签名。公开构建输出仅移除颜色与替换本机路径，完整日志留在私有目录。

| 包 | 字节 | SHA-256 | 范围 |
|---|---:|---|---|
| M2 | 9,501,941 | `E97B59FD5A51586E1D513E8585F796954FFBF38B03AC5E3190EB931028B423D9` | 首轮完整经营及第一次纸景缓存，设备暴露剪切柔影重烘和键盘遮挡。 |
| T2 | 7,837,036 | `0FBB19CD96DE69B0360DA8460177499379256415D1CA6A53CD264191400F590E` | M2首轮设备。 |
| **M3 当前** | **9,503,075** | `ED1748CCD65A1C2B72F4D3C7BE3E8E36F0A6F0C6B36CCEA07D7F4BE3574F16D5` | 连续剪切轻量阴影/抬手一次柔影、三位统计、平板键盘避让修复；此后产品未改。 |
| T3 | 7,837,036 | `8FBD3E814A6960E635CDCFAC1608F4BD52F257B338185834F74A4F400CFC23C5` | 两端经营至重开确认前；手机连续手势通过。 |
| **T4 当前** | **7,837,149** | `BBA48B2F600B4F2E629E6BE2362C9A1104468D719DAF85D1EADE201EBAD23430` | 仅将原生Alert确认匹配改为实际Text后代，全部实质断言保留。 |

M3/T4不可变副本位于私有 `.local/market-20261025/packages/m3-t4/`；当前正常输出HAP的哈希与其一致。两台为API26真实手机/平板模拟器，phone1256×2760、tablet2880×1920，按实际容器宽度排版；不是拉宽手机截图。

### 36.3 最终原生路径

| 路径 | 包 | 原始结果与耗时 | 报告 |
|---|---|---|---|
| 手机不调整四段，真实回放中双击禁用开段按钮4次，34客/134钱未达目标，0 note | M3/T4 | **Tests1 / Pass1 / Failure0 / Error0 / Ignore0**，40468ms | [225032](test-results/2026-10-25-225032-31cf7181-device.log) |
| 手机真实旧收藏→建茶铺/2伙计→六次补货/街灯→71客209钱→手输note/冻结出处→结束并重开Ability→读同一全文→确认新局保留note/收藏 | M3/T4 | **1/1，Failure/Error/Ignore0**，149134ms | [221925](test-results/2026-10-25-221925-3a278288-device.log) |
| 平板同一完整策略、个人记忆、重开与旧收藏保持 | M3/T4 | **1/1，Failure/Error/Ignore0**，157751ms | [221926](test-results/2026-10-25-221926-e543ef57-device.log) |
| 手机4笔48点原生连续曲线、4笔64点移光、移光全原始snapshot不变、恢复剪切/重进回读、无自动note | M3/T3 | **1/1，Failure/Error/Ignore0**，66713ms | [221520](test-results/2026-10-25-221520-030528b0-device.log) |
| 平板相同连续手势与实际落盘路径 | M3/T4 | **1/1，Failure/Error/Ignore0**，67228ms | [224123](test-results/2026-10-25-224123-a3c71166-device.log) |

测试从独立空游客Preferences开始，所有收藏、经营动作、感想和作品由真实UI产生；清缓存后用严格解析器与正式Repository交叉回读。结束并重开Ability不等于系统进程强停。本轮不登录、不请求AI；测试不会触及正式账号库。自动化时长含定位、键盘、截图和存储回读，不作为真人游戏时长。上表不是同一次整套结果，手机手势保留其真实T3包归属。

### 36.4 跟手问题与设备统计

第一版把整笔重复计算改为增量盖印、绘制分层与静态缓存，但实际M2采样仍显示剪切在每次mask变化重做离屏柔影，绘制命令CPU p95有 **78.9–374.3ms** 的完整样本，另有首笔198.8ms。主机命令计数无法发现原生离屏光栅/位图转移成本；M2功能通过没有被写成性能通过。

M3在手指划剪期间只绘制当前真实纸形的轻量实色影，抬手再烘焙一次完整柔影；移光复用已缓存纸形。设备`PAPER_SCENE_PERF`只在debug独立测试库显式开启，默认正式启动关闭。

| M3实际手势样本 | 绘制命令CPU p50（每笔范围） | p95（每笔范围） | 其他 |
|---|---:|---:|---|
| 手机4笔连续剪切 | 1.547–2.230ms | **6.358–8.832ms** | maxPending=1，预览/正式mask均一致。 |
| 手机4笔移光 | 0.786–0.881ms | **2.119–3.230ms** | geometry/static/judge均0次新增。 |
| 平板4笔连续剪切 | 1.422–3.455ms | **8.041–20.952ms** | maxPending=1，预览/正式mask均一致。 |
| 平板4笔移光 | 0.925–1.299ms | **2.493–5.062ms** | geometry/static/judge均0次新增。 |

完整原始[手机统计](test-results/2026-10-25-market-phone-perf-events.log)、[平板统计](test-results/2026-10-25-market-tablet-perf-events.log)及[结构化汇总](test-results/2026-10-25-market-native-perf.json)保留输入排队、缓存和生命周期样本。M2长小数有一条HiLog截断，保留原行且不拿不完整JSON算结论；M3改三位小数后无截断。

**上述不是GPU耗时、实际FPS或端到端触摸延迟。** 首次离屏缓存和抬手柔影仍有一次成本：原始生命周期里手机首次静态构建发出命令可到约275ms，平板首笔统计也含6次静态构建。不能只摘低p95宣称全程不卡。组件会保留其收到的完整笔迹，系统触摸合并使实际inputs数量不一定等于注入矩阵点数；最终作品依然按真实收到的轨迹正式判定。

### 36.5 保留失败与修复

- [首次主包编译失败](test-results/2026-10-25-market-first-main-failure.log)：未显式类型的ForEach参数与自定义`scale`名称冲突。改为MarketLot显式类型和marketScale后构建成功。
- [首次测试编译失败](test-results/2026-10-25-market-first-test-failure.log)：三处catch的任意类型throw。显式Error变量保留原对象与stack后构建成功。
- M2/T2平板 **Tests2 / Pass1 / Failure0 / Error1 / Ignore0**，164865ms，[220204](test-results/2026-10-25-220204-1c48c3b9-device.log)。默认失败用例通过；策略已到71/209，输入后键盘遮住TextArea，无法回读。修复Sheet的系统键盘平移/缩放和顶部对齐，未删除输入保存断言。
- M3/T3平板 **0/1、Error1**，165120ms，[221004-pad](test-results/2026-10-25-221004-4a7561b6-device.log)；手机整套 **1/2、Error1**，196876ms，[221004-phone](test-results/2026-10-25-221004-a1a69d84-device.log)。两端策略已完成note保存、重开、全文和出处验证，最后原生Alert操作文字实际是Text，用例错误限定Button导致找不到。T4按真实AlertDialog后代匹配后，策略在两端分别1/1；没有修改产品确认逻辑或注入新局。
- M2/T2手机连续手势功能 **1/1**，68217ms，[220203](test-results/2026-10-25-220203-eb7291d7-device.log)，同时暴露上述柔影CPU成本；M3修复后另行采样，不把首轮功能Pass等同于流畅。

对应[键盘失败图](design/river-market/first-tablet-keyboard-failure.png)、[Alert定位失败图](design/river-market/first-alert-selector-failure.png)保留。HDC日志采集首条正则未对远端管道符转义，启动后发现shell解释为管道并报错，随后改为每个前缀独立采集；这是采集命令修正，不是应用Failure或设备通过。

### 36.6 未完成与收尾

本轮交付一个完整经营样板，尚未完成五城经营、真人趣味性与时长校准、新经营HTTPS A→B→A专项、经营专用系统卡片/分享、华为账号、鸿蒙可信原生传输、完整备份恢复、实体设备或FPS测量。原两对象在线AI和旧系统入口维持原有边界，没有把新增离线经营写成在线AI或原生分布式能力。

正式账号、用户档案和其他工作区文件保留。全部专用测试库通过各自清理路径结束，手工review库有意保留供试玩；两台模拟器保持运行，日志采样客户端已停止。旧Word/PDF、录像与现场包未覆盖，未提交、推送或发布。包、源码指纹、原始报告、图片和资料访问记录见[完整机器清单](test-results/2026-10-25-river-market.json)。
