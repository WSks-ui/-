# 泥火成器 · 我的文化长卷

更新日期：2026-10-21。C09 首批实现与正常字号离线主线验收已完成，仅包含“泥火成器”一个主题。目标工程为 HarmonyOS 7 / API 26 原生 ArkTS / ArkUI；同一主包 M3 下，准备与阅读回放在 T3、独立编辑 / 删除 / 空态在 T4 分别通过。最终测试库清理和保留数据关闭设备均已核对完成；不将分段结果写成一次同测试包全套通过。包、原始报告与最终结果以[测试报告第 33 节](TEST_REPORT.md#33-泥火成器个人长卷2026-10-21)为准，实际画面见[本轮图集](design/journey-scroll/README.md)。

## 1. 交付范围与入口

个人长卷把当前账号或离线档案已有的收藏、手账和有效阅读进度组织为阅读视图，不另建一套示例记录。入口有两处：

- 在“泥火成器”路线内新建手账并确认保存成功后，详情页出现“这一页，已写入长卷 / 展开我的泥火长卷”。入口只在对应活跃 note 仍存在时显示；不会因保存失败而出现，也不在编辑旧 note 时冒充新建。
- 记忆页提供固定的“泥火成器 · 我的文化长卷”入口；管理多选时隐藏此入口，避免打断批量操作。

长卷上方显示真实手账数、个人线索数与现有路线点亮状态。四步阅读顺序沿用 `earth-and-fire`：庙底沟遗址、大河村遗址、杜岭二号方鼎、开封铁塔。各步可展开阅读理由和原档案出处；下一处使用现有 `journeyProgress.nextSiteId`，全部点亮后转向自己的长卷回顾。顺序表示主题阅读编排，不表示历史先后、交通路线或材料技术传播。

M3 在页首增加个人记录直达：仍有下一处且已存在个人线索时，显示“看我的 N 页手账”或“看我的 N 处线索”（`journey-personal-open`），点击滚到“我的观察长卷”标题（`journey-personal-title`）。保存后进入长卷即可直接查看自己的记录，无需逐一滚过四步路线；全部点亮后，页首原主按钮继续用于回顾。进度文案改为“主题路线进度”，保持既有点亮规则，避免把保存手账触发的点亮说成已完成阅读 section。

下方按路线中城市首次出现的顺序整理个人条目：三门峡、郑州、开封；没有个人记录的城市不生成空分组。城市内按路线顺序排列档案，每处保留全部活跃普通笔记与画面手账，按更新时间从新到旧、同时间按稳定 ID 升序排列。

## 2. 纯派生数据与完成语义

领域入口为 `buildJourneyScroll(sites: HeritageSite[], records: ArchiveRecord[]): JourneyScrollModel`，固定读取 `journeyForId('earth-and-fire')`，不导入 `@kit.*`、UI 或平台存储。

| 输出 | 含义 |
|---|---|
| `route` / `progress` | 现有 `JourneyRoute` / `JourneyProgress`；路线完成不另设规则或缓存 |
| `steps` | 四步档案、1 起始序号、阅读理由、收藏状态、手账数、有效探索百分比与完成状态 |
| `groups` | 按城市组织的个人条目；每条含原档案、完整活跃 notes、收藏、探索比例与关联理由 |
| `noteCount` | 当前路线、当前目录中个人条目的全部活跃 note 数量 |
| `personalSiteCount` | 当前路线中实际进入个人长卷的档案数量 |

先使用 `mergeRecords([], records)` 归一，再按路线过滤、派生个人条目。墓碑按既有版本规则胜出，迟到的旧活跃版本不会让已删除手账重新出现；路线外记录不参与数量、条目或专题关联。

三种状态分别保留：

- **进入个人卷**：某处有活跃普通笔记或画面手账、活跃收藏，或至少一个有效 section 阅读记录，即有效探索进度大于 0。
- **点亮路线节点**：直接复用 `journeyProgress`，由现有 `isMemoryPostcard` 识别的活跃手账卡，或至少 75% 的有效主题阅读进度触发。普通文字笔记和收藏本身不自动点亮路线。
- **打开过详情**：旧版 `progress:<siteId>` / `opened` 仅保留浏览语义，不折算为 section、学习百分比、个人长卷条目或到访经历。

所以删除某处唯一手账后，如果该处仍有收藏或有效 section，个人条目继续保留对应状态；手账卡与其共同标签关联消失，路线完成按当前剩余记录重算。收藏、笔记、阅读与路线点亮不混作一个计数。

无个人记录时，个人区显示“长卷，等你落下第一笔”，同时保留四步真实阅读入口和第一处建议。点击建议只进入对应档案；打开档案产生的旧浏览标记不会虚构一页手账或学习进度。

## 3. 阅读理由、出处与 AI 边界

四步理由只引导阅读已有内容：庙底沟陶窑与聚落布局、双连壶腹部相通、方鼎壁面正中与折角、铁塔琉璃构件。来源直接读取各自 `site.source` 的标题和 URL，不新增文化事实、来源副本、诗词、票价或预约信息；目录继续保持“初稿待校审”。

个人条目只与同一路线中其他真实个人条目比较，复用 `connectionReasons` 的档案属性理由和活跃笔记共同标签。共同标签显示“我的专题”，重复理由去重；同标签、同城或同属性不被解释为考古传承、因果或用户到访。

已有 note 带 `aiAssist` 时，长卷可显示“AI 辅助整理”标记；正文、冻结事实和保存视角继续来自该 note。长卷不新增 AI 请求、主题短序或自动生成记录，打开页面、展开步骤、回放和查看出处都不调用模型。本轮设备用例通过离线浏览操作，不登录账号，也不请求真实或替身模型。

## 4. 回放、编辑、删除与刷新

画面手账使用现有 `MemoryPosePreview` 按原 `snapshot3DPose` 显示预览。点击实际画布或“回到保存视角”，通过既有 `Index.openMemory(note, true)` 打开正式详情回放；不会按地点拼装默认相机替代保存记录。普通文字笔记通过“读手账全文”进入原全文页，不补造画面。

从长卷打开全文后，编辑和删除继续使用现有流程。编辑标签后按已知导航层级返回长卷；删除写入墓碑并返回原长卷。正文、相机、画幅、AI 依据等字段仍由原保存与删除规则维护，长卷自身不写记录。

`Index` 向长卷传递当前 `$snapshot`，路由不携带 records 副本。页面每次从 Link 的当前 `snapshot.records` 派生模型，显式监听快照变化；分组、条目和手账的渲染键包含版本及对应展示状态，避免编辑、删除或同步返回后继续复用旧正文和旧专题。步骤与来源的展开状态只属于页面，不进入归档。

详情页接续卡同样只记录页面内的 `savedJourneyNoteId`。原保存流程先取得相机和原画幅、完成落盘，再显示接续卡并回到页首；新增卡片及其滚动不改写保存时的 pose。

## 5. 文件职责与数据兼容

| 文件 | 本轮职责 |
|---|---|
| [JourneyScroll.ts](../entry/src/main/ets/domain/JourneyScroll.ts) | 纯派生模型、路线内个人条目、城市分组及关联理由 |
| [JourneyScrollPage.ets](../entry/src/main/ets/components/JourneyScrollPage.ets) | 原生长卷、空态、步骤与出处展开、个人记录预览及操作回调 |
| [Index.ets](../entry/src/main/ets/pages/Index.ets) | 记忆固定入口、`journey-scroll` 路由、共享快照及已有全文 / 回放接线 |
| [SiteDetail.ets](../entry/src/main/ets/components/SiteDetail.ets) | 路线内新手账成功保存后的轻量接续卡 |
| [journey-scroll.test.mjs](../tools/journey-scroll.test.mjs) | 五项必要领域契约；执行应用同一份源码，不镜像实现 |
| [test.ps1](../tools/test.ps1) | 在既有本地检查列表中加入新领域测试 |
| [JourneyScroll.test.ets](../entry/src/ohosTest/ets/test/JourneyScroll.test.ets) | 显式独立库的准备、阅读回放、标签编辑、删除保留四个阶段，以及定向清理与独立空态用例 |
| [List.test.ets](../entry/src/ohosTest/ets/test/List.test.ets) | 注册新设备测试套件 |

沿用 `schemaVersion=1`、稳定档案 ID、记录身份、收藏 / note / progress 信封、装饰、`snapshot3DPose`、`aiAssist` 和删除墓碑，没有新增持久化字段或存储格式，因此本轮无需数据迁移。现有记录不因打开长卷而改写、补标或更改时间戳。

## 6. 本轮结果与保留失败

| 检查 | 当前实测状态 |
|---|---|
| 本地检查 `tools/test.ps1` | **127/127**；包含新增五项长卷领域检查，不再额外累加 |
| 设备报告解析 | **9/9** |
| 当前构建包 | **M3 / T4 构建成功**；M3 主包耗时 **16s228ms**、T4 测试包耗时 **14s474ms**；M3 冻结不变 |
| M1 首次空态 | **0/1，Failure=0、Error=1、Ignore=0，130200ms**，保留原始失败 |
| M2 / T2 空态复验 | **1/1，Failure=0、Error=0、Ignore=0，115614ms**，仅覆盖该空态用例 |
| M2 / T2 保存、回放、编辑与删除主线 | **首次达到 600000ms 上限超时，保留为历史失败**；AA 输出缺结束摘要，报告解析拒绝；原始 HiLog 为 Tests run=1、Failure=0、Error=1、Pass=0、Ignore=0 |
| M3 / T3 旧超时库定向清理 | **1/1，10143ms**，仅清理指定的旧测试库；[112023](test-results/2026-10-21-112023-87a69f41-device.log) |
| M3 / T3 准备真实记录 | **1/1，245178ms**；[112102](test-results/2026-10-21-112102-8cb21ee4-device.log) |
| M3 / T3 阅读、专题、出处与保存视角回放 | **1/1，251409ms**；[112551](test-results/2026-10-21-112551-e0c4e941-device.log) |
| M3 / T3 编辑删除合并段 | **0/1，Error=1，359993ms**，达到 360000ms 上限超时；已真实编辑并刷新两侧专题，删除未完成；[113017](test-results/2026-10-21-113017-4d3a7dc6-device.log) |
| M3 / T4 独立编辑与专题刷新 | **1/1，134961ms**；[114112](test-results/2026-10-21-114112-7a1d8a62-device.log) |
| M3 / T4 删除、剩余线索与记忆首卡 | **1/1，69541ms**；[114410](test-results/2026-10-21-114410-1514f6af-device.log) |
| M3 / T4 空态独立复核 | **1/1，117575ms**；[114602](test-results/2026-10-21-114602-3f80c636-device.log)，不继承 M2 / T2 的空态结果 |
| M3 / T4 最终测试库清理 | **1/1，9314ms**；[114916](test-results/2026-10-21-114916-e6222c3b-device.log)，只读确认旧库 / 连续库 / 空态库无残留 |
| 本轮设备关闭 | 已按实例命令与端口确认所有者后正常关闭；PID、监听和 HDC target 均已消失，保留数据、没有 reset |

| 已构建包 | 字节 | SHA-256 |
|---|---:|---|
| M3 主包 | 6,676,399 | `E5F7439669F32F111D63105BD39B3E97398F0DC9318AA5EF608EA3294C72FDC4` |
| T3 测试包 | 6,670,235 | `58FF6E679A20645B583A924C0ED672F8105CED85A9F3A435A3BAD737EB597E8E` |
| T4 测试包（当前） | 6,680,585 | `7E7DC33CE236B4A626E0CF82DFD34AADE9AC39D0E9B18BCCDF94808D65F3C454` |

空态首轮原始报告为 [2026-10-21-104354-acf60286-device.log](test-results/2026-10-21-104354-acf60286-device.log)，[失败原图](design/journey-scroll/first-empty-title-failure.png)保持原样。该轮暴露两个需要分开记录的问题：

1. **测试定位问题**：空态大容器露出一小截后，测试直接等待仍在屏外的标题；改为把实际核对的标题叶节点滚入视口，保留原断言。
2. **实际产品排版问题**：路线步骤左列的纵向 `Blank().layoutWeight(1)` 配合 `Stretch`，在 Scroll 中膨胀。原始 layout 中 Blank 未裁切范围为 `[141,-283][145,1697]`，高 1980px。M2 对应用步骤连接线采用有限高度，避免弹性空白把路线拉到近整屏；不能把测试定位修正当成产品布局已修复的证据。

两项分别定向修正后，空态复验原始报告为 [2026-10-21-105625-ec13d7c4-device.log](test-results/2026-10-21-105625-ec13d7c4-device.log)。该次验证固定入口、0/4、真实下一处与出处、空态标题、建议进入真实档案，以及返回后仍不虚构个人记录。此结果不代表保存 / 回放 / 编辑 / 删除主线已通过，也不继承历史 AI、HTTPS 或全部旧 UI 结果。

M2 / T2 的 `JourneyScrollTest#native_records_replay_edit_and_delete_update_scroll` 首次整段运行达到 600000ms 上限后超时。原始 [AA 输出](test-results/2026-10-21-105847-3dd82e77-device.log)缺少结束摘要，报告解析明确拒绝，不能按命令退出或已有截图登记通过。本机忽略目录 `.local/journey-scroll-20261021/main-timeout-events.log` 保留原始 HiLog，实际结束摘要为 **Tests run: 1、Failure: 0、Error: 1、Pass: 0、Ignore: 0**。

该轮真实 UI 已保存双连壶与方鼎两篇，显示 **2 / 4 已点亮**，已核对既有出处与共同专题，并完成双连壶 `opening` 的原生回放；当轮标签编辑和删除尚未完成。这些已发生步骤作为过程证据保留，不构成整段用例通过。后续改为分段复验，其各段实际结果分别登记，不修改此次超时结论。

T3 首次构建时，测试日志中的对象字面量缺少显式声明的 class / interface，触发 ArkTS 编译拒绝。原始失败输出保留在本机忽略目录 `.local/journey-scroll-20261021/test-build-t3-first-failure.log`。随后设备脚本的新鲜度检查拒绝继续，**没有执行 aa 或设备用例**，不能将该次拒绝计作设备失败或通过。日志对象补充显式类型后重新构建成功，当时使用上表 M3 / T3；设备结果继续依据各段原始报告，不依据构建成功推定通过。

M3 / T3 随后实际通过旧超时库定向清理、准备与阅读回放三项，各自结果见上表，不合并为一次整套通过。准备阶段经真实 UI 保存两篇，阅读回放阶段核对既有出处、个人记录按钮的实际滚动落点、共同专题与正文、Canvas 回放成功状态同屏，并确认两篇 note、收藏和 section 共四条基线记录的版本未改变。

第三段 `JourneyScrollTest#edit_delete_preserve_records_and_memory_entry` 的完整 [113017 报告](test-results/2026-10-21-113017-4d3a7dc6-device.log)记录 **0/1、Error=1、359993ms**，不因前两段通过而改写结论。该段已经通过正式编辑器把方鼎标签改为“青铜折角”，两侧专题也已刷新；删除尚未完成。随后只读复制已明确指定的独立测试 Preferences 核对，方鼎仍是带新标签的活跃 note，双连壶 note、收藏和 section 基线未改变，见[超时快照摘要](test-results/2026-10-21-journey-scroll-t3-timeout-snapshot-summary.json)。该证据来自实际落盘读取，不写入或注入记录，也不替代尚未完成的删除验证。旧进程已 force-stop，原库保留供后续阶段复验。

T4 将编辑与删除再次分开，主包 M3 不改。新的编辑阶段发现同一方鼎 note 已带“青铜折角”，先经真实编辑器改回共同标签“泥火观察”，清缓存回读作为本次编辑基线，再完整编辑回“青铜折角”并核对两侧刷新；不重建原记录、不注入状态。已知位于页底的全文、编辑和删除入口改用原生 `scrollToBottom` 定位，实质断言保留，未改通用搜索助手。

`JourneyScrollTest#edit_topic_and_refresh_scroll` 实际 **1/1，134961ms**。除完成上述真实 UI 标签恢复与再次编辑外，还核对方鼎正文、pose 和装饰不变；双连壶与方鼎两侧的共同“我的专题”均消失，各自标签仍正确；双连壶 note、收藏与 section 版本未变。原始报告见 [114112](test-results/2026-10-21-114112-7a1d8a62-device.log)，编辑后的[原生画面](design/journey-scroll/edited-topic-refresh.png)与[原始 layout](design/journey-scroll/edited-topic-refresh.json)保留。

`JourneyScrollTest#delete_verified_note_and_preserve_memory_entry` 实际 **1/1，69541ms**。通过正式全文页删除后，方鼎写入墓碑，正文、pose、纸色、印章、摘录与新标签保留；另一篇 note、收藏和 overview section 的版本均未变。剩余状态为 **1 篇活跃 note、方鼎收藏与 25% 探索**，方鼎仍留作个人线索但不再由该手账点亮，路线变为 **1 / 4**。回到记忆页，首卡标题、正文和主要操作的真实 bounds 在可视区域内，固定长卷入口仍可进入并显示当前进度。原始报告见 [114410](test-results/2026-10-21-114410-1514f6af-device.log)，墓碑后[原生画面](design/journey-scroll/tombstone-preserves-other-records.png) / [layout](design/journey-scroll/tombstone-preserves-other-records.json)、记忆首卡[原生画面](design/journey-scroll/memory-entry-first-card.png) / [layout](design/journey-scroll/memory-entry-first-card.json)均保留。

上述四个主线阶段使用**同一个 M3 主包**：保存和读取检查绑定 T3，编辑和删除绑定 T4，沿用同一显式测试库和实际记录；没有把结果描述为一次同测试包全套通过。双连壶回放的 [Canvas 与成功状态同屏原图](design/journey-scroll/opening-replay.png)及[原始 layout](design/journey-scroll/opening-replay.json)对应阅读回放阶段。M3 / T4 空态已独立通过，最终清理及设备关闭已完成；[清理核对](test-results/2026-10-21-journey-scroll-cleanup.json)与[关闭核对](test-results/2026-10-21-journey-scroll-shutdown.json)分别保留。

本轮五条正常字号离线业务路径均已定向完成。收尾按原配置恢复未监听的本机 HTTPS 服务，证书与客户端配置不变，最终健康检查通过；本轮没有请求模型或把健康检查当作 AI / 同步新验收。完整证据与当前源 / 包绑定见[机器清单](test-results/2026-10-21-journey-scroll.json)及[测试报告第 33 节](TEST_REPORT.md#33-泥火成器个人长卷2026-10-21)。下一步按任务书的 C10 从实际平板主从导航开始。

## 7. 定向复现

先配置本机 `DEVECO_HOME`，在已启动的 HarmonyOS 7 / API 26 设备或模拟器上确认实际 HDC target。主包和测试包应晚于对应源码；构建工具的新鲜度检查会拒绝安装旧包。必要构建与本地检查使用项目原命令：

```powershell
.\tools\test.ps1
.\tools\build.ps1
.\tools\build.ps1 -Target ohosTest
```

将 `$journeyTarget` 设为 `hdc list targets` 实际返回的目标。空态使用自身独立测试库，不传主线库名：

```powershell
$journeyTarget = '<实际在线 HDC target>'

.\tools\device-test.ps1 -TargetId $journeyTarget -TestClass 'JourneyScrollTest#empty_scroll_entry_and_real_suggestion' -ExpectedTests 1 -TestTimeoutMs 180000
```

当前主线为四个 `JourneyScrollTest` 阶段：准备与阅读回放保留 **360000ms** 上限，编辑与删除各采用 **300000ms** 上限，最后以 **120000ms** 上限单独清理。以下命令中的 `$journeyStore` 只生成一次，四个阶段和最终清理必须使用同一个显式库名；每次新的完整运行使用新的 run 标识，不可用换库或注入记录代替前一阶段的真实操作。执行前应确认所用主包与测试包均成功生成且晚于对应源码；本轮已通过阶段的实际包绑定见上节。

```powershell
$journeyRun = Get-Date -Format 'yyyyMMdd_HHmmss'
$journeyStore = "yunheji_test_ui_journey_$journeyRun"

.\tools\device-test.ps1 -TargetId $journeyTarget -TestClass 'JourneyScrollTest#prepare_real_observation_records' -JourneyStore $journeyStore -ExpectedTests 1 -TestTimeoutMs 360000

.\tools\device-test.ps1 -TargetId $journeyTarget -TestClass 'JourneyScrollTest#inspect_topics_sources_and_saved_replay' -JourneyStore $journeyStore -ExpectedTests 1 -TestTimeoutMs 360000

.\tools\device-test.ps1 -TargetId $journeyTarget -TestClass 'JourneyScrollTest#edit_topic_and_refresh_scroll' -JourneyStore $journeyStore -ExpectedTests 1 -TestTimeoutMs 300000

.\tools\device-test.ps1 -TargetId $journeyTarget -TestClass 'JourneyScrollTest#delete_verified_note_and_preserve_memory_entry' -JourneyStore $journeyStore -ExpectedTests 1 -TestTimeoutMs 300000

.\tools\device-test.ps1 -TargetId $journeyTarget -TestClass 'JourneyScrollTest#cleanup_only_requested_journey_store' -JourneyStore $journeyStore -ExpectedTests 1 -TestTimeoutMs 120000
```

四个主线阶段各自通过真实“离线浏览”进入同一指定库，`ArchiveUiSession.run(..., true)` 保留实际落盘记录，结束阶段窗口时不清库。准备阶段从空库真实创建双连壶和方鼎手账，并通过正式入口记录收藏和 section；后续阶段重新打开原库，核对同一 note 的版本、相机、专题与删除后状态。缺少或不合法的 `-JourneyStore` 会直接拒绝，不能回落正式库或随机新库。接续本轮已准备的实际库时应保留其原 `$journeyStore`，不重新执行空库准备；编辑阶段依照上节的真实 UI 标签恢复流程建立本次基线。

定向清理用例不枚举 Preferences，不要求前一阶段成功，只清理由参数明确指定的本次独立库及其测试扩展；不清空正式用户档案。脚本兼容旧的 `yunheji_test_ui_<数字>_journey_scroll_main` 库名，仅用于清理本轮已确认的整段超时残留，四个新阶段一律使用 `yunheji_test_ui_journey_<run>`，不能把旧残留当成新准备结果。空态用例仍在结束时自行清理它的独立库。

首次整段历史命令为 `JourneyScrollTest#native_records_replay_edit_and_delete_update_scroll -ExpectedTests 1 -TestTimeoutMs 600000`，只对应前述 M2 / T2 超时记录。T3 曾采用 `JourneyScrollTest#edit_delete_preserve_records_and_memory_entry -ExpectedTests 1 -TestTimeoutMs 360000`，对应已保留的第三段超时；T4 改用上述独立编辑与删除名称，不将旧超时改写为通过，也不通过调高上限或删除实质断言替代验收。

分段主线预期核对两处真实保存镜头、共同“我的专题”、既有出处、点击原生预览后的正式回放、M3 页首直达个人区、修改标签返回刷新、删除墓碑及剩余收藏 / section 保留，并查看新增固定入口后记忆首卡仍露出正文与主要操作。清 Preferences 缓存后的回读用于核对实际落盘；此段描述用例目的，各段是否通过以实际原始设备报告的 Pass / Failure / Error / Ignore 为准。

## 8. 仍保留的范围

本轮只有一个主题，没有 AI 主题生成、新文化事实、备份恢复或新持久化格式；本轮设备用例验证离线个人路径，不作为同账号 HTTPS、华为账号或鸿蒙原生跨端的新结果。既有 AI 白名单仍为方鼎与双连壶两件，目录仍为 22 条。

设备自动化耗时含输入、滚动、等待、截图和回读，不等于真人三分钟演示计时。平板、完整历史 UI、大字体、泛化安全或压力未扩展为本轮验收范围；用户 Word、视频和比赛压缩包不随本交接文档自动更新，也未据此提交或推送。
