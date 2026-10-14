# 测试报告与验收清单

2026-10-14 用户已明确演示使用团队自有鸿蒙设备，模拟器与实机均可，举办方不提供或指定运行平台。此项设备规则已确认，不要求额外的赛事平台兼容验收；实际安装、分布式能力和多端交互继续按本报告测试。规则澄清不新增任何设备测试通过结果，以下历史证据保持原样。

最新测试日期：2026-10-14。所有“通过”仅覆盖表中明确列出的内容。

**最新账号双端：本地 43/43、报告解析 9/9、HTTPS / SQLite 服务综合 1/1，主包与两版测试包构建成功；8/8 账号 / 双端场景、2/2 独立库清理、存储 / 浏览 6/6、未登录状态 1/1、文明连线 2/2，Failure/Error/Ignore 为 0。10 张账号原图已检查，证据、两版测试包与保留的失败见第 12 节。当前为本机自建账号的真实网络同步；未将其称为华为账号或鸿蒙分布式数据库。早期 12 项全量回归、失败、超时和工具崩溃仍按对应旧包保留。**

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
