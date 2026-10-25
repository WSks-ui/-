# 云河纪五城漫游交接（2026-10-23）

本文件汇总本轮当前实现、实际验证与接手约束，避免历史文档中的“当前”覆盖新结果。先读 [README](../README.md)、[总交接](HANDOVER.md)、[测试报告第 34 节](TEST_REPORT.md#roaming-20261023)和[本轮机器清单](test-results/2026-10-23-roaming.json)。产品已冻结 **M12**；最后一条定向测试使用 **T15**。各项成功分属不同包，不能描述为 M12 / T15 一次全套通过。

## 当前实现与产品定位

云河纪是个人文化探索与记忆应用。跨端延续指同一账号在自己的设备间同步个人信息；安装实例 `deviceId` 是记录来源，不是账号，也不代表多人协作。继续现有 HarmonyOS 7 / API 26 原生 ArkTS / ArkUI 工程，不能以网页包装或浏览器预览替代鸿蒙运行证据。比赛已确认可用团队自有鸿蒙模拟器或实机，开发不再等待举办方指定平台；API 26 与 OpenHarmony API ≥12 的兼容仍需具体核验。

本轮已接入五城、15 条线索和 11 条来源：三门峡的热点／地坑院／剪纸，洛阳的两岸／诗句／水席，郑州的城门／诗句／相会，开封的街河／时间层次／灯事，濮阳的蚌塑／传说／庙会。操作和明确选择推进真实线索；进入、收藏、自由阅读不自动完成，也不代表到访。内容保持“初稿待校审”，图景保持原创叙事示意。

漫游、文化库、记忆为主要入口。文化库可检索新资料、加收藏标签并自由读具体线索；个人记忆有正文、标签、冻结摘录和出处，可读取、编辑和删除。亲笔正文从空白开始，必须确认保存；不把资料自动写作个人感想。平板按真实内容区宽度分栏，跨 Text 原生选摘生成卡片，以 UDMF 拖入草稿，真实旋转后保留同一草稿或选中记忆。

普通桌面卡片有“继续这段漫游”和“最近一页”，支持已验证旧包上的真实添加、冷／热路由与诚实空态。分享使用原生绘图生成 PNG 并打开 ShareKit；没有选择外部接收者，不显示第三方已收到。按需登录恢复最新已记录线索，未保存正文先保存；“仅登录”隔离游客，“复制漫游”才带入规定记录并保留原游客副本。

## 数据与源码入口

| 职责 | 入口 | 接手边界 |
|---|---|---|
| 线索、进度、冻结上下文 | [Roaming.ts](../entry/src/main/ets/domain/Roaming.ts) | 纯领域模块不导入 `@kit.*`、UI 或平台存储；五城独立，城内连续前缀解锁。 |
| 篇章与来源目录 | [RoamingCatalog.ts](../entry/src/main/ets/data/RoamingCatalog.ts) | `ROAM_CONTENT_REVISION=1`；修改文化事实需逐条核实来源，修订与图景版本分开。 |
| 新旧内容解析 | [CulturalContentIndex.ts](../entry/src/main/ets/data/CulturalContentIndex.ts) | 保留旧 22 条稳定 ID，新篇章／线索用新 ID，延伸阅读不等于考古传承关系。 |
| 漫游、选摘和草稿 | [RoamingChapterPage.ets](../entry/src/main/ets/components/RoamingChapterPage.ets) | 原生 SelectionContainer、摘录卡、UDMF、真实栏宽／Sheet；保存前不创建 note。 |
| 路由、事务与身份切换 | [Index.ets](../entry/src/main/ets/pages/Index.ets) | `commit` 保存成功才发布快照；按需登录用同篇章最新位置；恢复路由不暗中合入游客检查点。 |
| 记忆全文与个人长卷 | [RoamingMemoryDetail.ets](../entry/src/main/ets/components/RoamingMemoryDetail.ets)、[RoamingScrollPage.ets](../entry/src/main/ets/components/RoamingScrollPage.ets) | 按稳定 ID 取当前已落盘版本；编辑只改正文／标签／版本，删除保留墓碑与冻结字段。 |
| 原生系统入口 | [RoamingSystem.ets](../entry/src/main/ets/platform/RoamingSystem.ets)、[roamingform](../entry/src/main/ets/roamingform) | 桌面缓存是派生显示，不替代档案；启动意图不能伪造登录或同步。 |
| 本机保存与账号通道 | [LocalArchiveRepository.ets](../entry/src/main/ets/data/LocalArchiveRepository.ets)、[AccountSyncClient.ets](../entry/src/main/ets/sync/AccountSyncClient.ets) | Preferences 损坏不静默清空；真实账号由服务认证，token 仅入 ASSET，游客与账号库分开。 |

总快照继续 `schemaVersion:1`，采用可选 `roamingContext` 扩展，没有批量迁移或清空旧档案。上下文冻结结构版本、篇章／线索／选择、图景修订、可选资料修订、摘录、篇名、城市及完整来源对象。旧缺省 `contentRevision` 继续缺省；未知图景修订保留文字和来源，不拿当前图景替代旧保存。旧 pose、AI 依据、装饰和墓碑不改写。完整格式、LWW 与故障保护见 [ROAMING_DATA](ROAMING_DATA.md)。

M12 的具体产品修复是目的页通过同一 `NavPathStack.pop()` 明确返回并消费事件；它解决平板目录保存后默认 Back 退出 App 的实际问题。不要因为旧失败扩大修改导航模式或焦点：M12 目录已通过切换和旋转。详情旧正文问题已在 M10 修复，接手不应退回读取旧路由记录副本的方式。

## 已完成的验证及其版本

本地最终必跑 `tools/test.ps1` 为 **141/141**，报告解析器另 **9/9**，失败／取消／跳过 0。此前领域 + Repository + HTTPS 三文件 **123/123** 是独立范围，不与 141 或 9 相加。主包 M12、测试 T14／T15 均构建成功；本轮只围绕启动、正常字号核心操作、原生画面和必要构建，没有扩展完整历史 UI、大字体、泛化安全或压力套件。

| 已验证路径 | 实际包与结果 | 证据 |
|---|---|---|
| 五城入口不自动完成或生成记忆 | M12 / T15，最终独立 Pass 1，113555ms | [原始报告](test-results/2026-10-23-042159-b485408f-device.log) |
| 开封三线索与亲笔记忆读改删，旧普通手账保留 | M10 / T8，Pass 1，295506ms | [原始报告](test-results/2026-10-23-025926-e4e71c7f-device.log) |
| 其余四城各三条真实互动 | M11 / T9；濮阳为 T10，四例各 Pass 1 | [四城图集与清单](design/roaming/four-cities/README.md) |
| 原生跨 Text 摘录、真实拖放、旋转和保存 | M11 / T11，Pass 1，113514ms | [平板图集与清单](design/roaming/tablet/README.md) |
| 开封／洛阳左目录切换、旋转后保留洛阳 | M12 / T12，Pass 1，209582ms | [平板图集与清单](design/roaming/tablet/README.md) |
| A 注册保存 → B 接收续读编辑 → 原 A 接收新版本 | M11/T11 → M12/T13 → M12/T14，三阶段各 Pass 1 | [同账号图集](design/roaming/sync/README.md)、[10 项逐字段比较](design/roaming/sync/comparison.json) |
| 空白登录页离线返回与“仅登录”隔离 | M12 / T14，Pass 1，95405ms | [原始报告](test-results/2026-10-23-040454-b217a99a-device.log)、[登录图集](design/roaming/login/README.md) |
| “复制漫游”返回第 2 条、同一 note／上下文／进度，游客原副本逐字保留 | M12 / T15，Pass 1，116259ms | [原始报告](test-results/2026-10-23-041142-2c32989f-device.log)、[登录图集](design/roaming/login/README.md) |
| 桌面卡片、冷／热启动、分享取消、删除后空卡 | M5 / M6 / M8 手工原生定向记录，非 Hypium 统计 | [系统入口图集](design/roaming/system/README.md) |
| 账号服务不可达条件下的单端完整演示 | M12，383 条命令、结果 completed | [演示证据](design/roaming/demo/README.md) |

上表单例成功报告的 Failure／Error／Ignore 均为 0。早期六例报告中的入口子例虽通过，整份仍有 5 个 Error；最终独立入口通过不覆盖这些原始失败。本轮机器清单收录 23 份设备原始报告，其中 13 份完整成功、10 份失败或中断；入口子用例、重试、手工操作和报告解析器不混加为一次全套通过。完整失败清单与每份原始结果保留在 [TEST_REPORT 第 34 节](TEST_REPORT.md#roaming-20261023)，当前原生入口画面见[总览图集](design/roaming/overview/README.md)。同账号图集另含测试后原 A 复阅的两份原图／布局，不增加 Hypium 用例数。

当前产品 M12 为 **7,629,427 字节**，SHA-256 `FD6E7B3C89A155528FC9166B012AF96DB029DFE8AA379EC4ED669FBECD517094`。最后定向测试包 T15 为 **7,010,799 字节**，SHA-256 `62730D071E2AAABC53F74D91D8C73F7A1689921B9A6365A9DE4D15CBAD0A2558`。T15 只增加登录复制输入后的两次真实收键盘操作；不能把此前 M10、M11、T12—T14 的结果重标为 T15。所有包版本及报告关联见[本轮机器清单](test-results/2026-10-23-roaming.json)。

## 同账号复现与隐私约束

`RoamingSyncTest` 依次执行 A 注册保存、B 登录接收／继续／编辑、原 A 再登录接收。三阶段使用同一测试 feature 私有 `roaming-sync-test.json`，原 A 返程必须复用原测试库。不能为方便重试更换 note、清空 A、注入 progress 或先启动自动同步再补取“旧版本”。

本轮原 A 启动前只读基线为 6530 字节，同一 note、原正文、1 条已完成线索和第 2 条位置；B 修改同一 note 后，原 A 收到新正文与三条完成记录。10 项比较均为 true。初次 B 打开第 2 条后合法更新位置检查点，重试检查点正文相同但版本变化，不能据此伪称所有原记录字节始终未变。

`RoamingLoginTest` 必须在上述 A/B/A 之后，先“仅登录”再“复制漫游”。复制向该测试账号新增洛阳记忆，不能先复制后仍用单条 note 的旧 A 基线验收。两例分别使用独立游客库，实际读原始 snapshot 字符串验证游客副本未被重新保存；身份页不截图，错误先脱敏。ASSET、账号身份 XML、凭据和 HAP 不入公开材料。

`RoamingTest` 六例与 `RoamingTabletTest` 两例使用独立游客库，不依赖账号阶段。设备定向单例参数为 `ExpectedTests=1`、`TestTimeoutMs=600000`，按完整 Pass／Failure／Error／Ignore 和实际包判断，不能只看 `aa test` 退出码。

按需复现命令示例（由接手者确认当前包和目标设备后执行，本交接整理过程没有运行设备命令）：

```powershell
.\tools\test.ps1
.\tools\build.ps1
.\tools\build.ps1 -Target ohosTest
.\tools\device-test.ps1 -TargetId <实际目标> -TestClass 'RoamingTabletTest#native_memory_directory_keeps_selected_note_after_orientation_changes' -ExpectedTests 1 -TestTimeoutMs 600000
```

不要并行对同一台设备调用 UiTest；旧超时的 `scrollSearch` 尚在运行时创建新 Driver 会污染后续用例。键盘收起步骤只用于已知真实输入后的场景，不能无条件增加 Back。用户停止界面控制时立即停止，不能换控制通道绕过。

## 演示与系统入口的实际边界

M12 的连续单端演示记录 `completed`、383 条命令，覆盖开封三线索、点灯、亲笔保存、最近记忆全文／出处、系统分享和取消。执行时仅任务账号服务不可达，其他网络未被证明全部断开；没有登录、AI 或同步动作。取消前后独立档案 6705 字节、完整 SHA-256 相同。383 条命令不能换算真人演示用时，也不代表已生成备用录像。

桌面普通卡片添加与四条冷／热路径使用 M6，空卡修复复验使用 M8，原生分享取消另有 M6 整份 3374 字节档案一致的证据。这些是各自旧包上的实际结果，不转写为 M12 全部系统入口重新验收。接口声明、官方网页只取得应用壳的限制及原生图集均保留。

## 剩余证据与后续操作

- **实机与原生可信跨端：** 当前验证来自手机／平板模拟器和自建 HTTPS 同账号服务。华为账号、可信设备组网、原生 KV 两端传输、系统应用接续、完整冲突恢复和生产服务部署没有因本轮完成。
- **比赛演示：** 真人演示计时、备用视频、最终比赛压缩包和提交平台结果需要各自真实文件与验收。没有将自动化耗时或命令数冒充真人计时。
- **Word／PDF已完成：** [新版可编辑说明](deliverables/云河纪-省赛五城漫游说明-20261023.docx)与[同源PDF](deliverables/云河纪-省赛五城漫游说明-20261023.pdf)均12页，定稿12页经140DPI渲染后逐页实际查看，16张原生截图原字节嵌入。Word 7,071,635字节 / SHA256 `303C98CA648FA64D40DBB02964CD05EB9201F096A281D8A112384FE5D9528B46`；PDF 1,472,765字节 / `2AD25F8EAA713B3A530DF0BF25A1523CD787B8C33ED62ADF91E1DC38008C9B17`。材料核验见[清单](test-results/2026-10-23-roaming-materials.json)。实际尝试内置DOCX渲染器缺少soffice后，以独立隐藏Word进程只读导出并用Poppler检查；旧材料保持不变。
- **本机场包入口：** 新包固定名“云河纪-省赛五城现场包-20261023”，保留既有20261021现场包；本机编排在`.local/defense-20261023-fivecity/`。最终复制、ZIP与桌面副本的实际完成状态和哈希以该目录`package-result.json`为准。包内采用M12主包、新说明和本轮公共原生证据，不含测试HAP、私有XML、账号凭据或签名配置，也不冒称已提交比赛平台；完整源码仍在当前工程。
- **设备、服务与数据收尾：** 定向测试均已结束，两路本轮ROAMING业务日志读者已停止；手机和真实平板模拟器保留独立演示/文化库首页，18443本机HTTPS服务和双端反向端口可用。原A及复现所需独立测试数据保留，不清空正式档案，不关闭用户既有服务。
- **Git 与工作区：** 接手时本轮仍基于 `main`、`910324679288e23f5c20d4803210e1c798c6ca03` 及大量既有未提交修改。[产品源码指纹](test-results/2026-10-23-roaming-source.json)为 156 文件、汇总 SHA-256 `468DC77FA82AFA7C563EC8541B4B929976377947955F28B5DBC690F5CA779124`，不等于新增提交。不要回退他人文件，不覆盖本机签名、证书或用户数据；没有授权不提交、推送或发布。复杂规则写必要中文注释，获授权后的提交说明使用中文。

根 README、总交接与下一步优先级由根任务维护；本文件以代码、原始报告和明确包版本为事实入口。后续只针对实际演示问题定向修复，不为全量生产化治理扩大范围。
