# 《开封三夜》：资料依据、机制与原生能力核对

记录日期：2026-10-26。目标环境：HarmonyOS 7 / API 26 原生 ArkTS / ArkUI。

**当前状态：实现已落盘，设备结果以[测试报告第37节](../TEST_REPORT.md#three-nights-20261026)和[最终交接](../THREE_NIGHTS_HANDOVER_20261026.md)为准。** 本文记录本轮实际读取的文化材料、本机 SDK 声明核对和实现边界，不预填设备通过数、帧率、真人趣味性或五分钟完成率。前一轮结果仍属于[2026-10-25经营样板](../RIVER_MARKET_HANDOVER_20261025.md)，不自动继承为本轮证据。

## 1. 本轮实际读取的文献

2026-10-26 使用 Python 标准库网络请求实际读取以下三页，HTTP 状态均为 200。保存的是页面 HTML 与提取文字，没有下载或打包网页配图。原始响应、提取文本、命中短引、字节数和 SHA-256 位于本机被忽略的 `.local/three-nights-20261026/research/`；`sources.json` 记录访问日期，没有记录精确时分，本文不补造时间。

| 实际读取页面 | 核对到的短引 | 在三夜中的用途与约束 |
|---|---|---|
| [《东京梦华录》卷二·州桥夜市](https://zh.wikisource.org/zh-hans/東京夢華錄/卷二) | “自州桥南去，当街水饭、爊肉、干脯。” | 第一夜以饮食种类启发铺位与人手分配。原句没有给出六铺地图、当前游戏钱价、需求配额或人手产能，不能把这些游戏参数解释成史料数字。 |
| [《东京梦华录》卷三·马行街北诸医铺](https://zh.wikisource.org/zh-hans/東京夢華錄/卷三) | “至三更方有提瓶卖茶者。盖都人公私荣干，夜深方归也。”；同段可见“夜市直至三更尽，才五更又复开张。” | 第二夜从夜归人与移动卖茶展开固定茶铺和巡茶的取舍。巡茶区、占用一名伙计、每批服务上限、批次与库存消耗均为原创规则。四段不是对宋代更次的等时还原。 |
| [《东京梦华录》卷六·元宵](https://zh.wikisource.org/zh-hans/東京夢華錄/卷六) | “游人已集御街两廊下”；另一处为“诸坊巷、马行，诸香药铺席、茶坊酒肆，灯烛各出新奇。” | 第三夜用不同空间的观灯与街巷生活启发人流、灯棚和消费的关系。两条短引来自不同位置，来源快照明确标出“另一处短引”，不拼成连续原文。游戏没有复原宣德楼或原文山棚形制。 |

本轮保存响应的指纹：

| 页面 | 响应字节 | SHA-256 |
|---|---:|---|
| 卷二 | 75,836 | `b79629c7038caa0ca7f5f59158dafa72a7c945c8ce64a9dbe738fe11343dde7e` |
| 卷三 | 79,032 | `a80b8a3da4ab4996a792ca6ee2909378649361614b6b6f87d1f2cc4915a35099` |
| 卷六 | 75,454 | `839468b46b1aa44ed1a2884076727542329042ba3dc288548e1f76d9cb453c06` |

维基文库是本轮实际使用的公开电子转录入口。读取成功与短引命中说明引用可回查，不能替代版本校勘、考古证据或馆方逐句校审。三篇统一保留“初稿待校审”，年代为“孟元老南宋追记北宋”。

## 2. 参考链接与本轮核对范围

2026-10-26 本轮实际重新请求并读取以下两页，HTTP 状态均为 200。响应原文、提取文本与精确访问时间保存在被忽略的 `.local/three-nights-20261026/research/`，对应清单为 `reference-access.json`；以下字节数和 SHA-256 指向保存的 HTML 响应，不是搜索摘要或网页图片。

| 参考链接 | 本轮实际核对 | 采用理由与证据边界 |
|---|---|---|
| [中国历史研究院·北宋东京城州桥重见天日](http://hrczh.cass.cn/ywdt/dt/202502/t20250228_5849988.shtml) | 2026-10-26 06:01:53 UTC 读取，HTTP 200，23,271字节。正文署明来源为“河南考古”微信公众号、时间为 **2022-09-28**；核对到“是北宋东京城中轴线御街与大运河(汴河段)交叉点上的标志性建筑”。 | 用于说明州桥、御街与汴河交会的城市文化关联，为将河岸生活作为开封文献阅读入口提供语境。它不支持原创六铺地图、当前道路、街坊、铺位或桥体是考古复原。URL目录含 `202502`，不能据此把正文的2022年成果报道改记为2025年新考古发现。 |
| [Mini Motorways 开发者页面](https://dinopoloclub.com/games/mini-motorways/) | 2026-10-26 06:01:53 UTC 读取，HTTP 200，53,655字节。开发者“About the game”介绍原文包含：“Redesign your city to keep the traffic flowing, and carefully manage upgrades to meet the changing demands.” | 原文直接描述重新设计城市、维持交通与管理升级以应对变化需求，因而采用“看见瓶颈—安排资源—观察结果变化”作为机制设计参考。云河纪将这一讨论方向用于铺位、人手、库存和街区通行，未复制其道路系统或美术。本轮读取了官方介绍，没有亲自试玩；这些文字不能证明已复现其体验，也不能证明云河纪已经有趣。 |

本轮保存响应的指纹：

| 页面 | 响应字节 | SHA-256 |
|---|---:|---|
| Mini Motorways 开发者页面 | 53,655 | `cfbf0957b406d7d2865eb7f0486b2eb5446b9894604cbd210ca5f224056ea1bd` |
| 中国历史研究院州桥页面 | 23,271 | `13e21bd3dd11eb0ae4d34d42e109ae708deb7d556fca118b34caa725d7980a8a` |

本轮没有用搜索摘要补出未读原文，没有引入未经授权的机构网页图片，也没有把外部游戏名称当作本作趣味性已经得到验证的证据。

## 3. 从生活材料到原创规则

三夜使用同一条原创河岸和六处铺位，继承的是前一夜真实保存的布局，后夜预算、食材、客人数、账本和目标重新开始。它们改变玩家的决策对象：

| 夜次 | 文献入口 | 主要决策变化 | 当前原创目标 |
|---|---|---|---|
| 第一夜·州桥初市 | 卷二州桥夜市 | 饭、肉、茶的店位与人手；需求、补货和通行的取舍 | 接待至少65客，余钱至少20 |
| 第二夜·夜深归人 | 卷三提瓶卖茶 | 固定茶铺之外，腾出一名伙计派往一街巡茶；茶需求更高 | 同上，另累计服务至少30茶客 |
| 第三夜·元夜灯市 | 卷六元宵 | 灯棚、人手、亮街与通行共同影响观灯后消费 | 同上，另完成至少24次观灯后消费 |

每段分三批，前两批后可应急；每段最多两次应急，和开段前两趟常规补货分别计数。急送价格为常规补货价的1.5倍向上取整。已用的人手接待次数、通行、前批来客和收入不会因为调度而清零或重算。逐客回放读取当批真实结算结果，动画不推进经营。

可解释的第一夜实例是第二段缺肉：在“三街均来”、西街上铺肉食2人、中街上铺水饭2人、东街上铺茶饮2人、前两段熄灯的安排下，第二段第二批后肉为0。继续第三批只接待6客；在同一暂停版本急送一包肉，花15钱，第三批可接待9客。过去两批不变，改善来自补足当下缺货。该对照于2026-10-26通过纯领域公开动作重放核对；设备上是否按同样操作得到结果，以第37节原始报告为准。

“灯棚”在游戏中是功能性称呼。卷六的山棚、御街、坊巷灯烛与后世、当代灯会不能直接合并为同一种空间、灯具或经营制度。本轮没有核定后世灯谜、许愿或放灯习俗的谱系，不把这些内容倒填成卷六所述事实。当前灯棚容量、供油、观灯后再消费及达标数字均为原创编排；不主张它们是宋代仪式程序或现代非遗工序教学。

## 4. 三篇文献、22处遗址与个人记忆

新增三篇生活文献的稳定 ID 分别为 `culture-kf-night-market`、`culture-kf-bottle-tea`、`culture-kf-lantern-festival`，内容修订均为1。它们不加入 `HERITAGE_SITES`，旧22处遗址的 ID、顺序与计数保持；文化库分别显示“处档案”和“篇文献”，可按正文、年代、类型、收藏分类检索。

阅读、收藏、笔记和经营分别表达。真实阅读标记为 `progress:<文化ID>` 且正文是 `opened`；经营 progress 不计作读过文献。资料可自由打开、收藏分类、跨段选摘和写笔记，不需要先通关。推荐只取真实阅读、收藏与用户笔记标签，缺少个人锚点时按目录继续读。

用户明确确认保存后，经营记忆通过 `marketContext v1` 冻结夜次、内容与图景修订、来客路线、段与批、铺位与伙计、三街灯位、巡茶区、累计摘要、摘录及完整出处。它没有保存整个经营 state 或逐客轨迹。保存后继续经营、新局和来源修订都不替换这一页；编辑只改个人文字与标签，删除保留墓碑。没有经营上下文的文化笔记沿普通 note 路径保存来源，不虚构一夜成绩。

外层继续 `schemaVersion: 1`，新增字段为可选扩展。旧 note 不补值、不改稳定 ID 和时间。深拷贝、严格解析、固定字段顺序的版本比较及备份 JSON 沿既有链路贯穿；扩展损坏时拒绝读取并保留原记录给既有存储保护，不能静默丢弃上下文后覆盖。

## 5. 本机 API26 声明核对

核对日期为2026-10-26，使用当前本机 HarmonyOS 7 / API26 SDK 类型声明。表中路径相对于 SDK 的 `ets/` 目录，不记录机器安装绝对路径。声明存在与构建成功只证明接口可选用，实际操作以设备原始结果为准；API26不等同于已验证 OpenHarmony API≥12 兼容。

| 能力 | 本轮实际核对的声明与签名 | 实现采用方式 |
|---|---|---|
| 跨 Text 选摘 | `api/@ohos.arkui.components.SelectionContainer.d.ts`：`SelectionContainer({ controller })`、`SelectionContainerAttribute`、`textJoinStyle(SelectionContainerTextJoinStyle.NEWLINE)`、`onTextSelectionChange(Callback<Array<string>>)`、`editMenuOptions(SelectionContainerEditMenuOptions)`；控制器 `closeSelectionMenu()`；该组件标注 since 26.0.0。 | 阅读区聚合真实 Text；原生选中文字后生成摘录卡。编译器展开链式属性仍需显式导入 `SelectionContainerAttribute`，该导入已保留。 |
| UDMF 拖卡 | `api/@ohos.data.unifiedDataChannel.d.ts`：`PlainText.textContent`、可选 `abstract`、`new UnifiedData(record)`、`getRecords()`；`component/common.d.ts`：`DragEvent.setData(UnifiedData)`、`getData(): UnifiedData`、`onDragStart`、`onDrop`。 | 卡片 `draggable` 发出本篇摘录，接收端核对版本、内容ID和当前真实卡片；不会把外来任意文本自动标成此篇文献。UDMF用于此页拖放，不据此宣称完成多设备同步。 |
| 手机键盘与草稿 | `component/common.d.ts`：`SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL`；`api/@ohos.window.d.ts`：`getWindowAvoidArea(AvoidAreaType.TYPE_KEYBOARD)`。 | 手机使用明确底部 Sheet 与可滚动草稿；测试拟核对真实键盘避让区和可滚达保存按钮。平板以真实宽度进入资料/草稿并列布局。 |
| FormKit 普通桌面卡片 | `api/@ohos.arkui.advanced.FormMenu.d.ets`：`AddFormMenuItem(want, componentId, options?)`、`AddFormOptions.formBindingData`、`callback?: AsyncCallback<string>`；`api/@ohos.app.form.formProvider.d.ts`：`getPublishedRunningFormInfoById(formId): Promise<RunningFormInfo>`。 | 用户主动添加，真实回调给出 formId 后才报告已添加。继续经营卡来自已确认夜次/批次缓存；点击只恢复，不代推进。结束Ability后冷路由与仍运行时热路由分别记录，不能写作整进程强停测试。 |
| ShareKit 系统分享 | HMS `api/@hms.collaboration.systemShare.d.ts`：`new SharedData(record)`、`addRecord`、`new ShareController(data)`、`show(UIAbilityContext, ShareControllerOptions): Promise<void>`、`on/off('dismiss', callback)`。 | 只有用户点分享才生成冻结图景明信片及完整文字出处并调起系统面板。打开或取消不回写 note/progress；`show()`完成不代表第三方收到。系统面板可能出现联系人，测试不截图、不选择收件人。 |

当前原生实现仍是 ArkUI/Canvas、FormKit 与 ShareKit，不是网页包装。没有将普通本地拖放、桌面卡片或调用系统面板宣传成华为账号、鸿蒙可信设备传输或云同步已完成。

## 6. 验证交接

本轮新增 `tools/market-memory.test.mjs`，专项实际执行7/7通过，覆盖冻结与深拷贝、旧 note 不补字段、JSON回读、确定性版本比较、编辑与墓碑、损坏保护、独立文化计数和真实阅读推荐语义。该结果属于纯领域与目录验证。

`MarketNightsCultureTest` 已实现平板选摘/UDMF、手机收藏分类/键盘保存、冻结记忆主动分享取消、继续经营卡实际添加及Ability冷热批次路由四条专项；测试从独立游客库和公开经营动作开始，不注入通关，不清空用户档案。测试代码存在不等于设备通过。

后续在[测试报告第37节](../TEST_REPORT.md#three-nights-20261026)与[最终交接](../THREE_NIGHTS_HANDOVER_20261026.md)中绑定实际主包/测试包、设备类型、API、Pass/Failure/Error、保留失败和原始报告。真人趣味、理解程度与五分钟时长另行排练；自动化耗时、领域数值或SDK签名不能代替这些结论。
