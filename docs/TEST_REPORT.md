# 测试报告与验收清单

2026-10-14 用户已明确演示使用团队自有鸿蒙设备，模拟器与实机均可，举办方不提供或指定运行平台。此项设备规则已确认，不要求额外的赛事平台兼容验收；实际安装、分布式能力和多端交互继续按本报告测试。规则澄清不新增任何设备测试通过结果，以下历史证据保持原样。

最新测试日期：2026-10-18。所有“通过”仅覆盖表中明确列出的内容；各节历史结果只对应该轮实际包，不累计为最新包覆盖。

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
