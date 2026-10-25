# 五城漫游数据与旧档案兼容

本文记录 2026-10-23 这一轮的实际数据约定、源码调用链和本地验证。它不代表新漫游设备用例、手机与平板双端路径或鸿蒙原生跨端传输已经通过；这些结果须另附实际包、截图和原始 Pass / Failure / Error。

## 1. 兼容范围与迁移方式

总快照继续使用 `schemaVersion: 1`。旧 22 条文化档案的稳定 ID、旧收藏、普通手账、装饰、时间戳、`snapshot3DPose`、`aiAssist` 和删除墓碑不改写。新版读取旧记录时不补造漫游上下文，不重写 `updatedAt`，也不把旧浏览记录换算成通关。

本轮采用可选字段扩展，不运行批量迁移脚本：

1. 读取旧快照时沿用 [ArchiveDomain.ts](../entry/src/main/ets/domain/ArchiveDomain.ts) 的 v1 校验。
2. 只有用户明确确认保存漫游记忆，才新建 `note` 并写入 `roamingContext`。
3. 只有用户明确确认一条探索线索，才写入对应的漫游 `progress`。
4. 编辑与删除复制当前完整快照后操作原记录，删除保留墓碑及其冻结上下文。
5. 旧漫游上下文如果缺少后来增加的可选 `contentRevision`，读取、复制、落盘、同步均保留缺省，不用当前目录版本倒填历史版本。

这里保证的是新版读取和继续保存旧档案。尚未实现漫游字段的旧程序，其 `copySnapshot` 可能不会保留新可选字段，因此不能据此宣称可将新档案任意降级回旧程序继续编辑。演示两端与本机 HTTPS 服务应使用包含本轮领域实现的版本；回退前保留已确认快照。

## 2. 内容身份与进度命名

内容目录位于 [RoamingCatalog.ts](../entry/src/main/ets/data/RoamingCatalog.ts)，包含五个篇章、十五条线索和十一条来源。篇章、线索均使用新的稳定 ID，不复用旧遗址或器物 ID。`relatedSiteIds` 只提供延伸阅读，不表达考古传承关系。

| 数据 | 逻辑 ID / `siteId` | 解释 |
|---|---|---|
| 旧详情浏览 | `progress:<旧档案ID>` / 旧档案 ID | 正文为 `opened`，只表示打开过。 |
| 旧四主题阅读 | `progress:<旧档案ID>:<主题ID>` / 旧档案 ID | 沿用概览、考古、历史、诗文与出行的阅读语义。 |
| 新漫游线索 | `progress:roam:v1:<chapterId>:<clueId>` / 篇章 ID | 每条线索独立合并，保存实际确认的选择。 |
| 当前阅读位置 | `progress:roaming-position:v1` / 篇章 ID | 保存 `version`、`chapterId`、`clueId`，用于继续入口；不表示线索已完成。 |
| 新漫游手账 | 沿用 `note:<安装实例>:<时间戳>` / 线索 ID | 亲笔正文与 `roamingContext` 分别保存。 |
| 新文化收藏 | `favorite:<内容ID>` / 新内容 ID | 与旧收藏共用版本信封，内容解析使用独立新 ID。 |

漫游线索正文为以下结构，仍放在现有 `ArchiveRecord.body` 中：

```json
{
  "version": 1,
  "chapterId": "roam-kf-night",
  "clueId": "roam-kf-crossing",
  "choiceId": "kf-street-river",
  "completed": true
}
```

[Roaming.ts](../entry/src/main/ets/domain/Roaming.ts) 的规则如下：

- `roamProgress` 先按 `mergeRecords` 归一版本，再识别本篇章连续完成的线索前缀。五城相互独立，城内按三条线索逐步展开。
- `completeRoamClue` 验证线索、选择及顺序。重复确认相同选择返回原版本，不制造新时间戳；改变选择或重新完成已删除线索需要更新的时间戳。
- `roamChoice` 只解释有效的新命名空间记录，墓碑和未知正文返回空选择。
- 旧 `opened`、四主题阅读、收藏、普通手账和位置检查点均不计入漫游通关，也不据此生成个人感想或真实到访。

[CulturalContentIndex.ts](../entry/src/main/ets/data/CulturalContentIndex.ts) 统一解析旧档案、新篇章与新线索，供列表、收藏与检索使用；它不修改记录保存的 ID，也不把新非遗材料交给旧器物观察器或扩大在线 AI 白名单。

## 3. 记忆上下文与三个版本号

`ArchiveRecord.roamingContext` 是可选字段。当前新建上下文包含：

| 字段 | 含义与保存规则 |
|---|---|
| `version` | 上下文结构版本，当前为 1。 |
| `chapterId`、`clueId`、`choiceId` | 保存时篇章、线索和用户明确选择的稳定身份。 |
| `sceneRevision` | 原创图景修订，当前生成 1；不复用旧 `snapshot3DPose`。 |
| `contentRevision?` | 保存时的资料修订，首发显式生成 1；历史上下文缺省表示未记录，继续保留缺省。 |
| `excerpt` | 保存时的资料与选择解释，或用户通过原生选摘加入的文字。 |
| `title`、`city` | 保存时篇名与城市文字，不从未来目录回填。 |
| `sources` | 保存时来源对象数组，逐项冻结 `id`、`title`、`url`、`accessedAt`。 |

`version`、`sceneRevision` 和 `contentRevision` 分别约束结构、图景与资料，不能互相替代。[RoamingCatalog.ts](../entry/src/main/ets/data/RoamingCatalog.ts) 当前 `ROAM_CONTENT_REVISION=1`，内容仍为“初稿待校审”。目录以后调整资料时应增加这个常量，并由调用方传给 builder：

```ts
makeRoamingMemoryContext(chapter, clue, choiceId, ROAM_SOURCES, ROAM_CONTENT_REVISION)
```

末尾参数可选，默认 1，以兼容本轮早期调用；领域层不反向导入数据目录。明确传入的修订号必须是正安全整数，并参与深拷贝、记录版本比较、落盘与 HTTPS 往返。

[RoamingChapterPage.ets](../entry/src/main/ets/components/RoamingChapterPage.ets) 在开始写记忆时冻结当前依据。未手动摘录时，依据由当前线索正文与用户选择组成，亲笔正文仍从空白开始。手动选摘先生成卡片，再加入草稿；宽屏 UDMF 拖拽传递的是这张摘录卡的上下文。卡片加入、拖入和“恢复完整资料依据”的路径均保留来源及资料修订，历史缺省不自动补值。后续切换线索不改写已经冻结的草稿依据。

新手账同时将摘录写入 `quotedPoemOrFact`，供既有记忆功能兼容读取；完整来源与版本以 `roamingContext` 为准。资料目录更新不会重写已经保存的摘录或来源。旧 `aiAssist` 仍冻结原问题、事实正文、来源 ID 和 AI 资料修订；它不因新增漫游功能而变化。

## 4. 实际保存、读取与同步调用链

| 环节 | 实际实现 | 新字段如何保留 |
|---|---|---|
| 创建依据 | `RoamingChapterPage.context` → `makeRoamingMemoryContext` | 新建上下文及来源对象；手动选摘只替换本次摘录，保留保存时的来源和版本。 |
| 新建手账 | `Index.saveRoaming` | 亲笔正文单独写入 `body`，以 `copyRoamingMemoryContext` 写入上下文。 |
| 页面提交 | `Index.commit` | 先 `repository.save`，成功后才发布新 `snapshot`；失败保留草稿，不宣布已落盘。 |
| 深拷贝 | `copySnapshot` → `copyRoamingMemoryContext` | 字符串与来源逐项复制；`contentRevision` 仅在原来存在时复制。旧 pose、AI 与装饰仍走原复制函数。 |
| 解析 | `parseSnapshot` → `isValidRoamingMemoryContext` | v1 信封不变；校验上下文、来源、可选资料修订。损坏扩展拒绝整份快照，不删字段后继续保存。 |
| 版本裁决 | `recordContent` → `compareVersions` → `mergeRecords` | 漫游上下文所有字段与来源内容进入规范比较；属性插入顺序不影响相等判断。 |
| Preferences | `LocalArchiveRepository.save/load` | 保存前深拷贝并校验 JSON；读取后用正式解析器，完整上下文随快照保存。 |
| 客户端 HTTPS | `Index.syncAccount` → `AccountSyncClient.exchange/mergedSnapshot` | 发起时复制快照；响应检查账号与正式 v1 内容，使用收到响应时的当前快照合并，再经同一提交事务保存。 |
| 服务端 HTTPS / SQLite | `account-service.mjs` 的 `/sync` | 正式 `parseSnapshot` 校验，事务内读最新账号记录并 `mergeRecords`，完整记录 JSON 写 SQLite。 |
| 原生 KV 版本库 | `DistributedArchiveChannel.exchange` | 完整记录 JSON 作为不可变版本，读取仍用正式 v1 校验器；代码路径保留字段，本轮未据此宣称完成原生跨端传输。 |
| 编辑、删除 | `RoamingMemoryDetail` 与根页面批量删除 | 复制完整当前快照，只修改正文、标签或墓碑与版本信封；冻结依据继续保留。 |

以上对应源码分别见 [ArchiveDomain.ts](../entry/src/main/ets/domain/ArchiveDomain.ts)、[LocalArchiveRepository.ets](../entry/src/main/ets/data/LocalArchiveRepository.ets)、[AccountSyncClient.ets](../entry/src/main/ets/sync/AccountSyncClient.ets)、[account-service.mjs](../server/account-service.mjs)、[DistributedArchiveChannel.ets](../entry/src/main/ets/sync/DistributedArchiveChannel.ets) 和 [Index.ets](../entry/src/main/ets/pages/Index.ets)。

LWW 沿用更新时间、同时间删除优先、设备 ID 和完整规范内容的确定性顺序。迟到的旧活跃记录不能复活较新的墓碑；规范内容也用于服务器版本确认，所以只有更新时间相同、但摘录或来源不同的响应不能确认本机新版本。这里的服务器确认不表示另一台设备已经落盘。

## 5. 账号隔离与明确带入

安装实例 `deviceId` 继续表示记录来源及版本裁决所需的设备身份，不作为账号身份。账号库由真实认证返回的 `accountId` 选择；正式库名为 `yunheji_account_v1_<accountId>`，游客库与各账号库分别保留。独立测试使用 `yunheji_test_ui_*` 及其账号子库，不清空正式档案。

按需登录成功后，[Index.authenticateAccount](../entry/src/main/ets/pages/Index.ets) 先读取目标账号库。游客存在漫游记录时，会显示“仅登录／复制漫游”的明确选择：

- “仅登录”不把游客记录合入账号。
- “复制漫游”才通过 `mergeRecords` 合入新漫游进度、位置、新文化收藏和带 `roamingContext` 的记忆，包含这些记录的墓碑；原游客副本保留。
- 旧器物普通手账不因一次按需登录自动批量复制到另一个身份。

[RoamingChapterPage.ets](../entry/src/main/ets/components/RoamingChapterPage.ets) 的 `roam-account-continue` 是漫游内的按需登录入口。亲笔正文非空且本页尚未确认保存时，该入口禁用并显示“先确认保存这一页，再到另一端继续”；正文为空或已保存时才可进入。这个约束作用于该入口，不表示未保存草稿已经持久化，也不表示草稿会随身份切换自动复制。当前账号会话有效时，入口打开账号页；游客或需要重新认证时才进入登录页。

[Index.openLogin](../entry/src/main/ets/pages/Index.ets) 保存可恢复目的地和参数。对漫游目的地，它额外读取当前快照的 `progress:roaming-position:v1`：仅当检查点篇章与当前篇章一致且能解析时，用其最新 `clueId` 替换最初入篇时的旧路由参数。因此完成首条后触发登录，恢复目标是当前第 2 条，不会退回最初第 1 条。不能解析或篇章不匹配的检查点保留原参数；这里恢复的是已记录的线索位置，不包含滑条中间值、滚动偏移或未保存输入。

认证切换会清理旧路由，再由 `restoreLoginDestination` 恢复触发登录的目的地；空白登录页选择 `login-offline` 也通过同一恢复方法返回。恢复方法只重新打开保存的路由，不调用写位置的 `openRoaming`，也不把游客检查点隐式写入账号。所以“仅登录”后可以读回触发登录时的第 2 条，同时账号原有检查点仍由账号数据决定；是否合入游客数据只由前述明确选择控制。

“复制漫游”发生在目标账号库读取后、首次账号同步前，保留原记录 ID、时间戳、来源设备、墓碑及完整冻结上下文，再按现有 LWW 规则与账号记录合并；不会把游客整个快照改名为账号快照。后续提交使用目标账号 `repository`，原游客库继续保留。退出账号先确认游客库可读，再切回原游客快照。身份指针与网络会话仍分离：Preferences 保存已认证的离线身份，访问令牌只进入系统 ASSET；会话过期不清空原账号档案。

账号库命名、身份恢复和会话边界见 [AccountSync.ts](../entry/src/main/ets/domain/AccountSync.ts) 与 [AccountWorkspaceStore.ets](../entry/src/main/ets/data/AccountWorkspaceStore.ets)。本地 HTTPS 测试证明本轮字段可以通过真实网络与临时 SQLite 保存，不替代两台鸿蒙设备同账号收发的现场证据。

## 6. 损坏保护、回放边界与本轮审阅

本机读取失败继续保护原始数据：当前键损坏、类型不符、未知 schema 或存在孤立备份时不初始化为空库。保存使用串行队列，保留 `previous_snapshot`；`flush` 失败回滚缓存到上次确认版本。`roamingContext` 或可选资料修订损坏时，同样不能删除扩展后以“成功读取”覆盖原档案。

本轮定向审阅发现并修复了两处修订语义缺口：

1. **资料修订未冻结。** 原目录只有 `ROAM_CONTENT_REVISION` 常量，上下文没有对应字段。现已增加可选 `contentRevision`，贯穿 builder、校验、复制、规范比较、Preferences、HTTPS 及摘录卡副本。旧缺省上下文仍可读取且不补值。
2. **图景修订未核对。** 原记忆组件仅按当前目录查找图景。现 [RoamingMemoryDetail.ets](../entry/src/main/ets/components/RoamingMemoryDetail.ets) 与 [MemoryPostcardItem.ets](../entry/src/main/ets/components/MemoryPostcardItem.ets) 只在 `sceneRevision===1`，且篇章、线索、选择均能解析时绘制当前支持的图景。未知修订或失效身份保留亲笔文字、冻结摘录与来源；全文显示暂不能恢复的提示。

当前漫游预览恢复的是保存的文化片段与明确选择，使用支持版本的完成态原创图景。它不表示保存了滑条每一个中间位置，也不替代旧器物手账的精确 `snapshot3DPose`。本轮没有发现已声明漫游字段在上述解析、复制、Preferences 和 HTTPS JSON 链路中被丢弃；这项结论限定于列出的源码和本地测试。

## 7. 本地验证与设备定向清单

各轮数量对应各自源码与执行范围，不能相加作为当前全应用通过数。下表的 `123/123`、`141/141` 和报告解析 `9/9` 分别说明不同命令或子阶段的结果，不能合并计成一个总通过数。

| 实际执行 | 结果 | 证据和边界 |
|---|---|---|
| 初始漫游领域套件 `tools/roaming.test.mjs` | 12/12 通过 | 顺序解锁、五城隔离、幂等、LWW 墓碑、旧进度隔离、来源冻结、新旧可选字段及规范比较。 |
| 初始领域 + Repository + HTTPS 三文件 | 122/122 通过，失败 0 | 本机原始日志 `.local/roaming-domain-check-20261023.log`；真实 HTTPS 与独立临时 SQLite，不操作正式账号。 |
| 增加可选资料修订后的同一三文件范围 | 123/123 通过，失败 0 | 本机原始日志 `.local/roaming-data-review-check-20261023.log`；新增显式资料修订冻结、旧上下文缺省不补，以及新旧上下文落盘／HTTPS 保留断言。 |
| 本轮最终 `tools/test.ps1` 的本地逻辑与仓库范围 | 141/141 通过 | 按最终本地源码执行必跑脚本，覆盖领域、Repository、AI 观察、个人长卷与水情服务的脚本范围；详细批次和日志以 [TEST_REPORT.md](TEST_REPORT.md) 第 34 节为准。 |
| 同次必跑脚本的设备报告解析器 | 9/9 通过 | 检查报告的通过、失败、错误、超时、忽略和用例数等解析规则；是报告工具验证，不是 9 条设备业务用例通过。 |

三文件检查实际命令为：

```powershell
node --experimental-strip-types --test tools/domain.test.mjs tools/repository.test.mjs server/account-service.test.mjs
```

执行使用 DevEco 附带 Node，并设置本机 SDK TypeScript 路径供 Repository 源转译；日志中的实验特性提示不计为测试失败。测试实现见 [roaming.test.mjs](../tools/roaming.test.mjs)、[repository.test.mjs](../tools/repository.test.mjs) 和 [account-service.test.mjs](../server/account-service.test.mjs)。`tools/domain.test.mjs` 已引入漫游套件，因此本轮最终 `tools/test.ps1` 的 141 项会覆盖其领域部分；该脚本没有自动包含 HTTPS 账号服务测试，后者仍是上述三文件命令的独立覆盖。

设备定向源码现包含以下 13 项。这个数量是用例清单，不是已通过数；各套件在 [List.test.ets](../entry/src/ohosTest/ets/test/List.test.ets) 注册并只响应各自显式类名。

| 类 / 用例 | 实际验证职责 |
|---|---|
| `RoamingTest#native_guest_five_city_entries_do_not_auto_complete` | 独立游客库进入五城，确认进入和阅读不自动通关、不自动生成亲笔记忆。 |
| `RoamingTest#kaifeng_real_three_clues_memory_crud_and_plain_note_preserved` | 开封三条真实互动、来源读取、亲笔记忆保存／全文读取／编辑／删除墓碑，以及既有普通手账版本保留。 |
| `RoamingTest#sanmenxia_real_hotspots_pit_house_and_paper_cut` | 三门峡热点发现、地坑院展开与剪纸选择，逐条核对磁盘进度。 |
| `RoamingTest#luoyang_real_window_poem_and_water_banquet` | 洛阳两岸观察、诗句展开与水席片段选择，逐条核对磁盘进度。 |
| `RoamingTest#zhengzhou_real_gate_poem_and_meeting` | 郑州城门路径、诗句阅读与相会选择，逐条核对磁盘进度。 |
| `RoamingTest#puyang_real_shell_legend_and_fair` | 濮阳蚌塑观察、传说辨读与庙会选择，逐条核对磁盘进度。 |
| `RoamingSyncTest#device_a_register_save_memory_and_first_clue` | A 端通过真实注册 UI 建立本轮空账号，完成开封首条并保存亲笔记忆，明确停在第 2 条，等服务端确认。 |
| `RoamingSyncTest#device_b_receive_continue_and_edit_same_memory` | B 端登录同一账号，经 HTTPS 接收 A 的进度、检查点、同一记忆与冻结来源，从第 2 条继续完成并编辑原记忆。 |
| `RoamingSyncTest#device_a_receive_new_version_with_all_progress_and_frozen_context` | 重用 A 原账号库，启动前读取旧版本，再经真实认证接收 B 的新正文和全部三条进度；读取不改写记录及冻结上下文。 |
| `RoamingTabletTest#native_excerpt_drag_survives_portrait_and_landscape_before_save` | 真实窗口横屏下跨两个 Text 全选，经原生“做成摘录笺”与 `Component.dragTo` 拖入草稿；竖屏写作 Sheet、再回横屏后正文／标签／摘录／选择保留，最后正常保存并读盘。 |
| `RoamingTabletTest#native_memory_directory_keeps_selected_note_after_orientation_changes` | 通过 UI 分别保存开封、洛阳记忆，从系统分栏的左目录切换正文和冻结出处；竖屏再回横屏后保持洛阳选择，记录版本不变。 |
| `RoamingLoginTest#current_clue_returns_after_offline_cancel_and_login_only_keeps_guest_isolated` | 游客完成开封首条进入第 2 条，空白登录页离线返回仍在第 2 条，再实际登录选择“仅登录”；核对账号既有数据隔离及游客原始快照逐字不变。 |
| `RoamingLoginTest#copy_roaming_keeps_guest_source_and_restores_second_clue_with_same_memory` | 游客通过 UI 保存洛阳亲笔记忆并完成首条，登录选择“复制漫游”后回到第 2 条；账号包含相同 ID、版本、完整上下文和进度，游客原始快照逐字不变。 |

四套实现分别见 [Roaming.test.ets](../entry/src/ohosTest/ets/test/Roaming.test.ets)、[RoamingSync.test.ets](../entry/src/ohosTest/ets/test/RoamingSync.test.ets)、[RoamingTablet.test.ets](../entry/src/ohosTest/ets/test/RoamingTablet.test.ets) 与 [RoamingLogin.test.ets](../entry/src/ohosTest/ets/test/RoamingLogin.test.ets)。它们使用独立 `yunheji_test_ui_*` 游客库及账号子库，通关、保存、编辑和登录均通过正式 UI 完成，不预填 progress 或 note。记忆断言读取实际 Preferences，截图不代替磁盘验证。

执行依赖如下：

1. `RoamingTest` 六例和 `RoamingTabletTest` 两例各自使用独立游客库，不依赖账号阶段。平板用例必须在实际设备窗口上调用 `setPreferredOrientation`，等待真实 `windowRect` 和分栏／Sheet 分支；不以改页面宽度模拟方向，结束时恢复原方向。
2. `RoamingSyncTest` 必须按 **A 注册保存 → B 接收续读编辑 → 原 A 接收新版本** 顺序分阶段执行，沿用本轮同一私有 `roaming-sync-test.json`，返程保留并复用 A 的原测试库。该套件验证自建账号的真实 HTTPS 收发，不把网络结果命名为鸿蒙原生 KV 跨端成功。
3. `RoamingLoginTest` 必须排在上述 A/B/A 三阶段之后，先运行“仅登录”，再运行“复制漫游”。前者以账号已有开封三条进度和第 3 条检查点为隔离基线；后者会把新增洛阳记忆和进度合入该测试账号，因此不能提前执行后再拿 A 返程的单条记忆断言验收。
4. 每条定向设备用例单独执行，使用 `ExpectedTests=1`、`TestTimeoutMs=600000`，按完整原始 `Pass / Failure / Error / Ignore` 与实际包版本判断。`aa test` 进程退出码 0 不等于业务用例全部通过。

同步与登录凭据只在测试 feature 的私有 fixture 中读取，不进入主包或公开日志。登录专项对身份页跳过截图，并在错误输出前脱敏；其他截图也排除账号及个人资料页面。

本文件只登记上述本地执行结果和设备测试职责。**设备具体通过数、失败、重试、包版本、截图及尚未完成的阶段统一见 [TEST_REPORT.md](TEST_REPORT.md) 第 34 节**；根任务仍在执行的阶段不提前标为通过。华为账号与鸿蒙原生可信跨端仍保持各自未完成边界，不能由本地 141 项、报告解析 9 项或 HTTPS 字段往返推导为已完成。
