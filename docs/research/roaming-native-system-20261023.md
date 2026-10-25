# 五城漫游：桌面卡片与系统分享接口核验

- 核验日期：**2026-10-23**。
- 目标工程：现有 **HarmonyOS 7 / API 26** 原生 ArkTS / ArkUI 工程；不将其等同于 OpenHarmony API 12。
- 本机声明基线：SDK 的 `openharmony/ets/oh-uni-package.json` 实际为 `apiVersion: 26`、`platformVersion: 26.0.0`、`version: 26.0.0.105`、`releaseType: Release`。HMS ShareKit 单独从 `hms/ets` 读取，不误判为 OpenHarmony 基础 SDK 缺少分享接口。
- 范围：普通 2×4 桌面卡片、应用内主动添加、冷 / 热启动路由，以及用户主动分享个人纪行时生成的原生 PNG 与系统分享面板。
- 本文先记录接口与实现研究，随后补充主任务授权的平板定向验证。**第 1—5 节的接口检查不代替设备结果；实际结果与 M5 / M6 / M8 包边界见第 6 节。** 没有把 HDC 命令返回成功改写成 Hypium 用例全通过。

## 1. 官方页面访问与证据边界

本轮尝试直接通过 HTTPS 读取下列华为官方地址。返回均为 HTTP **200**、标题“文档中心”、**1754 字符**的前端应用壳；返回内容没有可核对的文档正文，不能据此声称相关段落已读到。

| 地址 | 本轮取得的内容 | 采用范围 |
|---|---|---|
| [Form Kit 概述入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/formkit-overview) | HTTP 200，前端应用壳，未取得正文 | 留作后续官方正文复核入口；本轮不据此确认模拟器能力。 |
| [SystemShare 官方参考入口](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/share-system-share) | HTTP 200，前端应用壳，未取得正文 | 分享参数以本机 API 26 的 HMS 类型声明逐项核对；页面链接供后续对照。 |

为继续读取实际渲染正文，本轮使用 `cua` 尝试创建隐藏 IAB 页面：`createBrowserTab('iab', 官方 FormKit 地址, { visible: false })`。工具实际返回 **`Browser is not available: iab`**；随后 `cua.listBrowsers()` 返回 **`[]`**。没有转而控制原生桌面，没有绕过浏览器限制，也没有把 HTTP 200 的应用壳当成文档内容。

**因此，“模拟器支持普通卡片、不支持互动卡片预览”在本轮尚未取得可追溯的官方正文证据，不列为官方已核验结论。** 当前实现选用普通 ArkTS 2×4 卡片，没有加入互动卡片参数。后续已在第 6 节指定的 API 26 平板模拟器实际验证普通卡片添加、显示与路由；这个结果不扩展成所有模拟器或互动卡片的支持承诺。接口存在、编译通过和设备服务可用分别记录。

## 2. 已实际读取的 API 26 类型声明

下表路径均以 SDK 的 `default/` 为根，避免在公开材料中记录开发机绝对路径。

| 能力 | 实际读取的 SDK 文件 | 已核对的接口 / 约束 | 本轮采用方式 |
|---|---|---|---|
| FormKit 导出 | `openharmony/ets/kits/@kit.FormKit.d.ts` | 导出 `FormExtensionAbility`、`formBindingData`、`formInfo`、`formProvider` | 使用普通 FormExtensionAbility，不自行模拟桌面卡片。 |
| 卡片生命周期 | `openharmony/ets/api/@ohos.app.form.FormExtensionAbility.d.ts` | `onAddForm(want): FormBindingData`；`onUpdateForm(formId, wantParams?)`；`onRemoveForm(formId)`；`onAcquireFormState(want)` | 系统新增时登记真实字符串 formId，刷新时推送缓存，移除时删除登记。 |
| 卡片绑定 | `openharmony/ets/api/@ohos.app.form.formBindingData.d.ts` | `createFormBindingData(obj?: Object \| string)` | 仅传标题、摘要、章节 / note 路由和真实进度显示。 |
| 卡片刷新 | `openharmony/ets/api/@ohos.app.form.formProvider.d.ts` | `updateForm(formId, binding): Promise<void>`，可因宿主 / 服务 / formId 状态失败 | 真实保存后主动更新已登记卡片；失败保留缓存与 formId，后续重试，不回滚手账。 |
| 2×4 规格与 Want 参数 | `openharmony/ets/api/@ohos.app.form.formInfo.d.ts` | `FormDimension.Dimension_2_4 = 3`；`FormParam.IDENTITY_KEY`、`NAME_KEY`、`MODULE_NAME_KEY` 等 | 发布 Want 明确指定 `entry`、模板名、2×4、非临时卡片。formId 不转换成 number。 |
| 卡片配置 schema | `openharmony/toolchains/modulecheck/forms.json` | `uiSyntax: arkts`；`supportDimensions` / `defaultDimension` 支持 `2*4`；`updateDuration` 以 30 分钟为单位 | 两模板均仅开放普通 2×4；系统周期刷新 30 分钟，另在真实保存后主动刷新。 |
| 主动添加菜单 | `openharmony/ets/api/@ohos.arkui.advanced.FormMenu.d.ets`；`openharmony/ets/kits/@kit.ArkUI.d.ts` | `@Builder AddFormMenuItem(want: Want, componentId: string, options?: AddFormOptions)`；`componentId` 用于取得真实组件截图；选项含 `formBindingData`、返回 formId 的 callback 和菜单样式 | 页内先展示实际缓存预览，再由用户点添加菜单和系统确认。不能在普通按钮点击后伪造“已添加”。 |
| 卡片启动动作 | `openharmony/ets/component/common.d.ts` | `postCardAction(component: Object, action: Object)` 标记 `@form` | 卡片点击发送 `router` 与篇章 / 记忆 ID，主 Ability 转交窗口级路由。 |
| ShareKit 导出 | `hms/ets/kits/@kit.ShareKit.d.ts` | 导出 `systemShare`，来源是 `@hms.collaboration.systemShare` | `@kit.ShareKit` 必须按本机 HMS 声明核对，不能只搜索 OpenHarmony API 文件。 |
| 系统分享 | `hms/ets/api/@hms.collaboration.systemShare.d.ts` | `SharedData(record)`、`addRecord(record)`；`SharedRecord` 可用 `utd`、`uri`、`content`、`title`、`description`；`ShareController.show(context: common.UIAbilityContext, options): Promise<void>` | 传真实 PNG file URI，另提供完整文字；用户主动调用后才显示系统面板。`show` 返回不能作为第三方收到内容的证明。 |
| 分享预览与锚点 | 同上 | `SharePreviewMode.DETAIL`；`SelectionMode.SINGLE`；`anchor?: ShareControllerAnchor \| string`，字符串是关联控件 ID | 原生图片详细预览；用户选择图片或文字；平板可传分享按钮 ID 定位。 |
| 原生绘图 | `openharmony/ets/api/@ohos.graphics.drawing.d.ts`；`@ohos.graphics.common2D.d.ts` | `new drawing.Canvas(pixelMap)`、Path、Brush、Pen；物理像素绘制 | 现场生成原创河流装饰图景，不使用浏览器画图，不冒称旧 pose 截图。 |
| 原生文字排版 | `openharmony/ets/api/@ohos.graphics.text.d.ts` | `ParagraphBuilder`、`FontCollection.getGlobalInstance()`、`Paragraph.layout(width): Promise<void>`、`getHeight()`、`paint(canvas, x, y)` | 先排版测高，再创建足够高的 PNG；正文、摘录与出处均不按固定行数截断。 |
| 原生 PNG | `openharmony/ets/api/@ohos.multimedia.image.d.ts` | API 26 `createPixelMapFromPixels`；`ImagePacker.packToFile(pixelMap, fd, options)` | 图片写入应用 `cacheDir`，格式 `image/png`，释放 PixelMap 与 ImagePacker。 |
| 应用文件 URI | `openharmony/ets/api/@ohos.file.fileuri.d.ts`；`@ohos.file.fs.d.ts` | `getUriFromPath(path)`；应用沙箱文件的 open / close | 将实际生成文件转换为应用文件 URI，交由系统分享，不伪造网络图片地址。 |
| 派生显示缓存 | `openharmony/ets/api/@ohos.data.preferences.d.ts` | `getPreferencesSync`、`getSync`、`putSync`、`deleteSync`、`flushSync`、`removePreferencesFromCacheSync` | 独立缓存，不接管正式账号档案；跨 Ability 读取前更新此库的进程缓存。 |

## 3. 用户动作与实现关系

| 用户的具体动作 | 当前对应实现 | 数据边界 |
|---|---|---|
| 在漫游中完成一个小目标或保存探索位置 | 上层成功保存共享 snapshot 后调用 `publishRoamingCard(context, state)`；继续卡只显示该快照派生的标题、摘要与已完成 / 总线索数 | 卡片点击本身不完成线索，不根据打开次数填充进度。无效比例不显示进度。 |
| 保存、编辑一篇个人记忆 | 上层保存成功后以 `mode: memory` 发布真实 noteId、标题与正文摘要 | 不创建第二条 note，不改变原正文、出处、时间戳、pose 或墓碑。 |
| 删除最后一篇个人记忆 | 上层调用 `clearRoamingCard(context, 'memory')` | 最近页回到诚实空态，继续卡保持原有漫游显示。 |
| 退出或切换账号 | 上层清理两类派生缓存，再按当前可读档案重新发布 | 不清空用户档案；宿主刷新失败不改变已发生的身份切换。 |
| 打开“我的 → 桌面卡片” | `RoamingSystemPage` 只读缓存，展示“继续这段漫游”与“最近一页”的原生预览和添加说明 | 页内不接收 / 保存正式 snapshot；手机单列，宽容器双列。缓存读取失败时不启用添加按钮。 |
| 点“添加到桌面” | 以真实预览组件 ID 调用 `AddFormMenuItem`，由用户选择菜单项并按系统提示确认 | 只有返回真实 formId 才显示“已添加”；打开菜单不当作添加成功。 |
| 从桌面点继续卡或最近页 | `postCardAction` 的 `router` 动作 → `EntryAbility.onCreate` 或 `onNewWant` → 窗口级 `roamingLaunchRoute` | 使用章节 / note ID 恢复当前档案中实际存在的对象；不切换账号，不复制旧账号内容。 |
| 在已保存的个人纪行页点分享 | `shareRoamingMemory` 先用原生 API 生成 PNG，再调用系统 ShareController | 只有这次主动操作才启动系统分享。生成图片和取消面板均不保存 / 修改任何 note。 |
| 在系统面板选择或取消分享 | 系统负责选择目标；应用仅保持面板对象生命周期 | 不添加“分享成功”“对方已收到”或伪同步计数。 |

两张卡片与分享图片均明确标注**原创河流图景**。其用途是装饰个人文化记忆，不对应某处遗址的地形复原，不是实景照片，也不是 `snapshot3DPose` 的原取景截图。

## 4. 可审阅的集成接口

实现文件：

- [RoamingSystem](../../entry/src/main/ets/platform/RoamingSystem.ets)：平台接口与原生分享。
- [RoamingCardData](../../entry/src/main/ets/roamingform/RoamingCardData.ets)：独立派生缓存、formId 登记、路由解析。
- [RoamingFormAbility](../../entry/src/main/ets/roamingform/RoamingFormAbility.ets)：卡片生命周期。
- [普通卡片页面](../../entry/src/main/ets/roamingform/pages/RoamingCard.ets)与[两模板配置](../../entry/src/main/resources/base/profile/roaming_forms.json)。
- [RoamingSystemPage](../../entry/src/main/ets/components/RoamingSystemPage.ets)：原生预览、用户主动添加、操作说明。
- [EntryAbility](../../entry/src/main/ets/entryability/EntryAbility.ets)：冷 / 热启动路由。

`RoamingSystemPage` 的接口为：

```ts
@Prop cacheRevision: number = 0; // 可选；页面常驻时递增，重新读取派生缓存
onBack: () => void;
```

建议路由名为 `roam-system`，页面自身以 `NavDestination` 为根并隐藏系统标题栏，保留自绘返回。页面只读 `readRoamingCardPreview(context, 'chapter' | 'memory')`；不读取或改写正式 note。

平台同时提供 `roamingFormWant(mode)` 和 `roamingFormAddData(context, mode)`，可用于其他原生添加入口。Want 明确指向 `com.yunheji.archive / RoamingFormAbility`，模板为 `RoamingContinue` 或 `RoamingMemory`。

窗口级路由键为 `roamingLaunchRoute`，JSON 内容为：

```ts
interface RoamingLaunchRoute {
  action: 'chapter' | 'memory' | 'home';
  chapterId: string;
  noteId: string;
  requestId: string;
}
```

每次启动都有不同的 requestId；Index 消费后置空。空漫游卡片发出 `home`，空“最近一页”发出 `memory` 与空 noteId，回到记忆入口。Index 消费空对象路由时清理旧 NavDestination，避免只切 Tab 却保留上次正文。

独立设备验收另使用可选的 `RoamingCardState.testStoreName`：只有 Debug 构建且匹配 `^yunheji_test_ui_[a-z0-9_]{1,80}$` 才进入卡片绑定；Release 不携带对应 router 参数。卡片冷启动仍由 EntryAbility 原有 `archiveStoreForLaunch` 再次核验，热启动不切换当前库或身份。删除最后一页保留已核验的测试上下文，但清除正文与对象 ID；退出账号的全量清理仍移除两类缓存。这里没有给任意账号库名增加通路。

本轮没有新增华为账号授权、可信设备接续、自动跨端打开或系统已同步的宣称。

## 5. 接口检查与设备验收清单

已经实际执行：

- 读取上述 SDK 26 类型与卡片配置 schema。
- 真实 `RoamingCardData.ets` 经本机 SDK TypeScript 转译后，以 SDK 替身执行 **8 类隔离检查，通过**：重复路由 requestId、按类型刷新、精确字符串 formId 与注册恢复、最后一页单类清理、不显示无效进度、宿主失败后保留缓存并可重试、退出清理、仅访问独立派生缓存。输出为 `RoamingCardData isolated SDK-stub checks: 8 scenarios passed (...)`。这不是设备或系统宿主结果。
- 两模板 JSON、独立字符串资源 JSON 可解析；已跟踪修改的 `git diff --check` 通过。
- 主任务首轮统一构建指出的 route 类型与 catch 重抛类型问题已修；第二轮指出的 Flex 属性位置问题已修。卡片补显式 LocalStorage；添加页补 NavDestination 根与显式 Area 参数。修复后的最终构建状态以主任务原始构建日志为准，不在这里提前登记“通过”。

以下是设备验证前定义的定向验收清单。**后续实际结果见第 6 节，未覆盖项继续待验证**，不由接口检查或旧轮次结果代替：

| 验收路径 | 应观察的实际结果 | 需要保留的证据 |
|---|---|---|
| 主动添加两种普通 2×4 卡片 | 系统确认后桌面真实出现对应卡片，标题、摘要与当前缓存一致 | 系统添加过程与桌面原图、实际包版本；不能只记录菜单打开。 |
| 真实完成线索后返回桌面 | 对应继续卡显示真实完成数；没有完成的线索不会点亮 | 保存前后记录与卡片画面。 |
| 停止应用后点击卡片 | 冷启动直达指定城市篇章或真实 note | 冷启动操作与实际目的页。 |
| 应用已在后台时点击卡片 | 热启动同样到达目标；连续点击同一卡片可再次消费 | onNewWant 路径与实际目的页。 |
| 编辑 / 删除最近页 | 编辑后摘要变化；删除最后一篇后回到空态，不留下已删除正文 | 原 note、墓碑及卡片画面。 |
| 退出账号 | 旧账号正文从派生显示清除；正式账号 / 游客档案不被清空 | 切换前后卡片与档案核对，截图避免账号私人信息。 |
| 系统分享与取消 | 真实生成 PNG，图片包含选摘、正文和出处；显示系统面板；取消后原 note 逐字段保持 | PNG 原文件、面板原图、取消前后记录核对。 |
| 手机 / 平板添加页 | 手机单列；足够宽的实际容器并排显示两个预览，添加菜单关联正确预览 | 原生画面与容器宽度。 |

验证范围仅围绕上述比赛演示路径与必要构建，不扩展大字体、泛化安全或生产化治理。当前不以旧轮次的 API 26 设备测试、HTTPS 双端测试或 `aa test` 退出码替代本轮系统卡片与分享验收。

## 6. 本轮平板原生定向结果

主任务随后授权独占 `127.0.0.1:5557` 的新平板模拟器进行系统入口验证，结束后已明确交回主任务。本节是 **HDC + 实际原生 UI 定向检查**，没有运行或拼造一份 `aa test` / Hypium 报告，也不从 HDC 的 `No Error` 推导 Pass / Failure / Error 数量。

### 6.1 设备、包与测试数据

实际设备参数为：`tablet`、**2880×1920**、API **26**；`const.product.software.version` 为 `emulator 7.0.0.107(SP8DEVC00E16R1P1)`，`const.ohos.fullname` 为 `OpenHarmony-7.0.0.105`。两字段分别保留，不混写为一个版本。

| 包 | 字节数 | SHA-256 | 本节范围 |
|---|---:|---|---|
| M5 | 7,582,788 | `E710E8E33EBCA026B3D503DD681A05FAABA89CE615B75664469F67C498A6A3B6` | 初次继续卡添加与热启动；通过实际选片段、输入和确认保存建立一页独立测试记忆。 |
| M6 | 7,610,407 | `16D78945095B48D5DD4D718223D328D039048B2A4D6E02EB147DDC4EB816A053` | 四条有内容卡片冷 / 热启动、最近页添加、真实系统分享 / PNG / 取消、删除与空态显示；保留空卡目的页错误。 |
| M8 | 7,613,206 | `81165C3C3C68FD8068E9D24EB83EE3CC9CD8B748F2B49AF6CAED2D0561D44963` | 修复后空“最近一页”的冷 / 热启动，仅复验必要的失败路径。 |

M6、M8 均覆盖安装并保留数据。冷启动先 `aa force-stop com.yunheji.archive`，再实际点桌面卡片；没有把带参数的 `aa start` 冒充卡片启动。初始化与刷新使用明确的独立 Debug 库 `yunheji_test_ui_roaming_system`，没有写入其他测试库或正式库，也没有注入 Preferences。

新模拟器首次唤起小艺输入法出现隐私选择。原图与实际文案已记录；本轮按基本离线输入准备选择**“同意基本模式”**，其实际说明为“提供基本输入服务，不收集任何个人数据即可使用文字、符号基本打字服务”，未选择全量 / 云 / 语音模式。之前返回 `No Error` 但文本框仍空的输入尝试没有算作输入成功。基本模式完成后，才从实际 TextArea 逐字确认测试文本、选择文化片段并点击保存。本次文字是预定义测试文本，不是用户研究或真人体验感想。

### 6.2 已观察到的行为

| 路径 | 实际结果 | 包边界 |
|---|---|---|
| 原生主动添加 | `AddFormMenuItem` 菜单选择后桌面真实出现卡片；该模拟器没有另弹第二个确认页。继续卡最初在 M5 添加，M6 保留并刷新；最近页在 M6 添加。两张卡片的标题、正文摘要、0/3 与原创图景均实际可见。 | M5 / M6 分别记录；不虚构额外确认弹窗。 |
| 继续卡冷 / 热启动 | 停止应用后点击和运行于后台时点击，都到开封《点亮汴京的一夜》。 | M6，各自有命令序列、原图与 layout。 |
| 最近页冷 / 热启动 | 两种启动均打开同一条已保存 note，正文、摘录与出处一致；真实 noteId 为 `note:94729185-465e-4ad5-b7dc-e6303ce2307e:1792693657021`。 | M6；测试记忆由 M5 UI 创建，M6 读取原条目。 |
| 保存与探索语义 | 个人长卷出现 1 页，文化片段与正文可重读，探索仍为 0/3。保存一页没有虚增线索完成。 | M5 创建，M6 继续读取。 |
| 系统分享 | 实际显示 ShareKit 系统面板，含图片记录和系统操作；未选择外部接收方。 | M6。 |
| 原生 PNG | 从设备取回实际生成文件，**1080×1365、245,441 字节**；完整正文、摘录、来源标题及 URL 可读，底部明确原创图景身份。 | M6。 |
| 取消不改记录 | 系统面板 Back 取消后回原记忆。取消前后独立库文件均为 **3374 字节**，整文件字节相同，SHA-256 同为 `56E54D751A7A6B254B878188C92BB6FD272F136EE33D036B09148BEBE7D055F8`。 | M6；比对区间仅为这次分享前后。 |
| 删除唯一测试 note | 通过原生删除确认，只删除本轮独立库的该 note；保留墓碑、正文、摘录、装饰与漫游上下文，除 deleted / updatedAt 外字段一致；另 1 条 progress 逐字段不变，活跃 note 变 0。桌面最近页没有残留原标题 / 摘要。 | M6。 |
| 空最近页目的地 | M6 原始行为会保留此前已打开的开封页，**该项未通过**。修复后 M8 的冷 / 热点击均到记忆 Tab 的 0 篇 / “还没有留下手账”，没有旧 NavDestination。 | 原始 M6 失败与 M8 两次复验分别保留。 |
| Debug 空卡冷启动隔离 | M8 空缓存只保留白名单测试上下文，没有正文或对象 ID；冷启动后默认正式库文件仍不存在。 | M8；未通过任意库名进入账号档案。 |
| 平板添加页 | 实际宽容器并排显示两张原生卡片预览，按钮与对应预览一致。 | M6；本子任务不把它扩展为手机页面验收。 |

原生 PNG 的 SHA-256 为 `186B4FDF675133710EBB1143573C12B77EC9A7752975551A8A2DA0645ED441BB`。图片由本次用户动作调用原生绘图和 ImagePacker 生成，没有浏览器合成、外部图片生成或截图替换。

### 6.3 空卡失败与修复边界

M6 删除后的卡片显示已经清空，但其空态 action 为 `home`；主页面当时只切 Tab，未清此前路径，所以实际仍看见原开封页。修复将空“最近一页”改为 `memory` + 空 noteId，同时由 Index 对不存在 note / home 入口显式清路径。单类缓存清理保留经过 Debug 白名单核验的测试库上下文，默认退出清理仍清两类全部缓存。

修复后的源文件还经 **4 类 SDK 替身检查**：清内容并保留 Debug scope、从 M6 已删除的单类缓存恢复 scope、Release 移除 scope、退出移除两类 scope。该结果是隔离逻辑检查，与 M8 的两条原生复验分别记录。没有重跑已通过的无关套件，也没有把 M6 与 M8 合写为“同一包全部通过”。

### 6.4 原始证据与交还

完整证据保留在本机忽略目录 [`.local/roaming-system-20261023/`](../../.local/roaming-system-20261023/)：

- [机器可读清单 results.json](../../.local/roaming-system-20261023/results.json)：包哈希、逐项结果、原始 M6 失败、图片 / layout / 日志文件哈希与设备交还状态。
- [只读记录比较](../../.local/roaming-system-20261023/record-comparison.json)：取消前后整文件相同、唯一 note 墓碑与其他 progress 保留。
- [两张真实桌面卡片](../../.local/roaming-system-20261023/two-desktop-cards-m6.png)、[真实系统分享面板](../../.local/roaming-system-20261023/system-share-sheet-m6.png)、[实际原生 PNG](../../.local/roaming-system-20261023/native-postcard-m6.png)。
- [M6 原始空卡目的页](../../.local/roaming-system-20261023/empty-memory-destination-m6.png)、[M8 热启动空记忆](../../.local/roaming-system-20261023/hot-empty-memory-m8.png)、[M8 冷启动空记忆](../../.local/roaming-system-20261023/cold-empty-memory-m8.png)。

设备已交回主任务继续 Sync / UDMF 定向验证，本子任务交还后未再操作设备。测试 note 已按授权通过 UI 删除并保留墓碑，其他测试库、正式数据及签名配置未修改。**没有验证外部第三方收到分享、账号退出后的卡片清理、华为账号或鸿蒙可信设备接续；这些项目不能因上述结果变为通过。**
