# 云河纪前端设计优化交接

**2026-10-23 用户纠偏：核心任务是游戏化玩法创新。** 请优先阅读[核心玩法重构交接](GAMEPLAY_REDESIGN_HANDOVER_2026-10-23.md)。当前版本多数机制仍是滑条阈值、任意片段选择和确认，功能走通不等于创新成立；本文件保留源码地图、画面和数据约束，视觉美化排在可玩核心样板之后。用户本次只要求改交接，下面的新玩法尚未实现。

更新日期：2026-10-23。用途：交给新的开发对话，继续优化**原生视觉、交互表现和完整使用体验**。

当前五城功能与演示路径已有实现和原生证据。下一轮应在此基础上提高设计完成度、文化辨识度和功能可感知性。本交接只整理设计工作，不修改产品，不重新安装应用，不重跑设备，也不覆盖已冻结的省赛材料或现场包。

## 1. 接手目标与用户反馈

用户希望作品有精美的原生页面、能亲手参与的创新交互和完整的文化探索体验。校赛已通过；评委的反馈是“功能没有体现出来，创新不够惊艳”。**这个反馈是下一轮优化的动机，不表示当前五城版本没有功能，也不表示已做过的改进获得了新的评委认可。**

产品定位已经明确：

> 云河纪是一款可以在家参与的黄河文化漫游应用：沿河走进五座城市，通过寻找、拨动、选择和收集，理解文化故事，再留下自己的记忆。

体验主线为：**沿河选城 → 看懂一个具体目标 → 亲手发现 → 得到简短解释 → 选择文化片段 → 确认保存自己的文字 → 在另一台自己的设备继续。**

继续原生 ArkTS / ArkUI，目标工程为 HarmonyOS 7 / API 26。产品不是网页包装、多人协作工作台或生产化治理项目。三项主导航是**漫游 / 文化库 / 记忆**，“我的”为独立入口。可以优化页面结构和表现，但不要丢失这条主线及历史内容入口。

## 2. 先读什么，哪些旧结论不能照搬

建议依次阅读，避免从几千行历史报告重新审查整个工程：

1. [AGENTS.md](../AGENTS.md)：协作、原生与数据边界。
2. 本文，以及 [README 当前状态](../README.md)。
3. [五城体验与文化素材](ROAMING_EXPERIENCE.md)、[五城最终交接](ROAMING_HANDOVER_20261023.md)。
4. [原生图集总入口](design/roaming/README.md)，必须实际打开下面列出的截图。
5. [测试报告第34节](TEST_REPORT.md#roaming-20261023)；涉及旧AI、pose、账号时，再按问题查第30—33节。
6. [数据兼容约定](ROAMING_DATA.md)、[完整演示说明](ROAMING_DEMO.md)。

[优先开发交接](DEVELOPMENT_HANDOVER_2026-10-23.md)和[总交接](HANDOVER.md)顶部已更新；其下历史“下一步先做平板”“只有旧河迹首页”等描述不代表当前状态。[DESIGN.md](DESIGN.md)主要记录10月13日的Yi_Da与玫瑰色阶段，**只作历史参考，不能当作当前五城设计规范**。当前颜色以实际代码为准。

M12的功能与定向验证已完成，核心玩法创新仍需重构；当前工作区在此之后另有前端修改，不能按M12历史包推定当前源码完全相同。不应重新从旧审查列功能清单，也不要因为见到旧组件就把它重新放回首页。

## 3. 当前基线与真实完成范围

| 项目 | 当前事实 |
|---|---|
| 工程 | 本机 `D:\Open_of\yuenheji`，包名 `com.yunheji.archive`，主Ability为`EntryAbility` |
| 当前主包 | M12，版本号0.1.0，7,629,427字节，SHA256 `FD6E7B3C89A155528FC9166B012AF96DB029DFE8AA379EC4ED669FBECD517094` |
| 源码状态 | `main`，HEAD `910324679288e23f5c20d4803210e1c798c6ca03`，大量既有修改未提交；最新成果在工作区 |
| 内容 | 旧22条档案保留；新增五城篇章、15条线索、11条来源，新旧内容各有稳定身份 |
| 游客 | 首次直接漫游，离线材料可读，无需账号或在线AI即可完成探索 |
| 记忆 | 用户输入正文并确认才保存；摘录、来源和图景修订冻结；可读、改、删，删除保留墓碑 |
| 平板 | 真正tablet类型API26模拟器，已验选摘、UDMF拖卡、横竖屏、两篇记忆目录切换 |
| 系统入口 | 普通桌面卡片冷/热启动及空态有原生记录；ShareKit实际打开，取消不改档案 |
| 同账号延续 | 自建账号HTTPS，已验原手机A保存→平板B接收/继续/编辑→原A收到新版本 |
| 按需登录 | 仅登录/明确复制漫游分别验证，返回原线索，游客副本保持不变 |

五城各自已有不同动作，不需要重新设计成统一的三张热点卡：

| 城市篇章 | 已有操作 | 视觉优化应表达的关系 |
|---|---|---|
| 三门峡《黄土里的家》 | 找制作与居住、拖开地表、选原创窗花 | 聚落生活、地下院落与纸页装点；不同年代分开说明 |
| 洛阳《这一城春色，为谁而开》 | 移动伊河景窗、拨出赏花文字、开汤羹线索 | 山水相对位置、赏花日常与相聚 |
| 郑州《溱洧河边，去赴一次相会》 | 水陆门选择、沿诗句找水与人、相会片段 | 进入路径、诗句含义与人的交往 |
| 开封《点亮汴京的一夜》 | 街河交会、时间层次、选愿并点灯 | 水线和街路、多期遗存、夜间灯景的变化 |
| 濮阳《龙乡的故事，怎样留到今天》 | 蚌塑观察窗、传说/纪念空间、庙会回声 | 考古、地方传说与当代民俗的不同身份 |

三门峡首条已从早期方案的“衣食”收敛为有材料支持的**制作与居住**。不要为丰富插画再补未经核实的具体服饰、食物或纺织发现。

## 4. 必看的原生画面

这些是已留存的真实画面。本次整理重新查看了手机首页、开封交互/点灯、平板选摘草稿、文化库与记忆目录、手机个人长卷；它们不是本次新运行的界面结果。

| 画面 | 文件 | 观察重点 |
|---|---|---|
| 手机漫游首页，M12 | [01-native-home.png](design/roaming/demo/01-native-home.png) | 标题、河卷、城市选择、当前目标、开始按钮与浮动导航的层级 |
| 平板完整五城首页，M12 | [tablet-roaming-home-m12.png](design/roaming/overview/tablet-roaming-home-m12.png) | 全河段构图、选中题签、首屏目标和宽屏空间使用 |
| 开封操作后，M12 | [03-kaifeng-interaction.png](design/roaming/demo/03-kaifeng-interaction.png) | 场景、滑条、选项、反馈、确认与次要入口的竞争 |
| 开封点灯后，M12 | [06-lantern-lit.png](design/roaming/demo/06-lantern-lit.png) | 与白天的变化是否明确，完成感与下一步是否连贯 |
| 平板三栏草稿，M11/T11 | [excerpt-landscape-draft.png](design/roaming/tablet/excerpt/excerpt-landscape-draft.png) | 左根页与右三栏并存，场景/资料/摘录卡/亲笔是否各有主次 |
| 手机式写作半模态，平板竖屏，M11/T11 | [excerpt-portrait-writing-sheet.png](design/roaming/tablet/excerpt/excerpt-portrait-writing-sheet.png) | 输入、键盘、资料和保存之间的连续性 |
| 平板文化库，M12 | [tablet-library-peony-m12.png](design/roaming/overview/tablet-library-peony-m12.png) | 筛选占比、正文层级、篇章身份与收藏操作 |
| 平板记忆目录与详情，M12/T12 | [directory-luoyang-selected.png](design/roaming/tablet/memory/directory-luoyang-selected.png) | 选中反馈、正文和出处、图景比例 |
| 手机个人长卷，M12 | [10-top-recent-note.png](design/roaming/demo/10-top-recent-note.png) | 标题重复、最近内容、五城分组与空城占位的节奏 |

其余四城见[四城图集](design/roaming/four-cities/README.md)，卡片与分享见[系统入口图集](design/roaming/system/README.md)。每个目录的`evidence.json`保留真实包归属。不能把M11截图写成M12，也不要把本机`.local`中的近似文件名当作已核准截图；早先`tablet-home-m12.png`实际是启动图。

## 5. 前端源码地图

路径从工程根目录起算；优先局部修改，不需要为了美化先全局重构。

| 设计职责 | 主要文件 | 修改时注意 |
|---|---|---|
| 根导航、三个Tab、账号与快照编排 | [Index.ets](../entry/src/main/ets/pages/Index.ets) | 实际漫游Tab挂`RoamingHome`；`device()`是文化库，`archive()`是记忆，旧方法名不能按字面误判 |
| 河流首页、题签、选城、目标入口 | [RoamingHome.ets](../entry/src/main/ets/components/RoamingHome.ets) | 横向原生Scroll+Canvas+原生题签按钮；选城位置与当前目标必须对应 |
| 五城图景、光照、遮罩和局部手势 | [RoamingScene.ets](../entry/src/main/ets/components/RoamingScene.ets) | `homeScene/springScene/meetingScene/nightScene/dragonScene`各自绘制；检查画幅变换、热点与拖动坐标一起调整 |
| 篇章节奏、目标、选项、读城/写作 | [RoamingChapterPage.ets](../entry/src/main/ets/components/RoamingChapterPage.ets) | 包含原生选区、摘录卡、拖放、草稿和Sheet；不能只移动UI而丢失其状态 |
| 文化篇章列表 | [RoamingLibrarySection.ets](../entry/src/main/ets/components/RoamingLibrarySection.ets) | 关键词、城市、年代、类型由根传入；自由阅读与游戏解锁不同 |
| 新文化内容的收藏列表 | [RoamingFavoritesSection.ets](../entry/src/main/ets/components/RoamingFavoritesSection.ets) | 收藏分类与旧档案共存，不能退回只支持旧siteId |
| 记忆页列表、管理与筛选 | [Index.ets](../entry/src/main/ets/pages/Index.ets)、[MemoryPostcardItem.ets](../entry/src/main/ets/components/MemoryPostcardItem.ets)、[MemoryFilterPage.ets](../entry/src/main/ets/components/MemoryFilterPage.ets) | 保留排序、标签、全文、管理、多选和新建路径 |
| 新漫游记忆全文与编辑 | [RoamingMemoryDetail.ets](../entry/src/main/ets/components/RoamingMemoryDetail.ets) | 按noteId读取当前快照，`id:updatedAt`刷新，冻结依据与正文分开 |
| 个人黄河长卷 | [RoamingScrollPage.ets](../entry/src/main/ets/components/RoamingScrollPage.ets) | 最近真实记忆优先，五城分组，保留旧“泥火成器”入口 |
| 旧手账、器物与AI延伸 | [MemoryDetailPage.ets](../entry/src/main/ets/components/MemoryDetailPage.ets)、[SiteDetail.ets](../entry/src/main/ets/components/SiteDetail.ets)、[AiObservationPanel.ets](../entry/src/main/ets/components/AiObservationPanel.ets) | 新视觉应接回旧内容，保留pose回放与AI冻结依据 |
| 我的、账号与登录 | [ProfilePage.ets](../entry/src/main/ets/components/ProfilePage.ets)、[AccountPanel.ets](../entry/src/main/ets/components/AccountPanel.ets)、[LoginPage.ets](../entry/src/main/ets/components/LoginPage.ets) | 按需登录与返回触发位置，不把账号重新变成首次门禁 |
| 卡片预览与系统分享 | [RoamingSystemPage.ets](../entry/src/main/ets/components/RoamingSystemPage.ets)、[RoamingSystem.ets](../entry/src/main/ets/platform/RoamingSystem.ets)、[roamingform](../entry/src/main/ets/roamingform) | 桌面卡片和纪行PNG有自己的绘制路径，改页面不会自动改变它们 |
| 五城主题与资源 | [RoamingTheme.ets](../entry/src/main/ets/components/RoamingTheme.ets)、[ArchiveTheme.ets](../entry/src/main/ets/components/ArchiveTheme.ets)、[base颜色](../entry/src/main/resources/base/element/color.json)、[dark颜色](../entry/src/main/resources/dark/element/color.json) | 两套主题入口已经存在，主色已接近一致；需要统一的是具体规则与用法，不能笼统称旧页面仍全是玫瑰色 |
| 系统导航材质 | [HarmonyEffects.ets](../entry/src/main/ets/platform/HarmonyEffects.ets) | 只在SDK支持区域使用，不用任意阴影/渐变冒称鸿蒙材质 |

`Index.explore()`等旧首页builder仍在代码里，当前`mainPage()`的漫游Tab实际调用`RoamingHome`。做首页设计先确认渲染入口，避免只改未展示的旧函数。

## 6. 表现层优化候选（核心玩法之后）

以下是基于现有原图和代码的设计判断，**不等于新用户测试结论或已确认的功能缺陷**。接手后用原生试玩确认优先级；不需要把所有候选同时实施。

下表的优先级只在表现层内比较。总任务的P0是[新交接](GAMEPLAY_REDESIGN_HANDOVER_2026-10-23.md)中的规则、尝试、因果反馈与个人结果，不能把下表完成当作玩法创新达成。

| 优先级 | 当前观察 | 建议改善的体验 | 完成判断 |
|---|---|---|---|
| P0 | 手机主线已通，但多个大圆角块、选项和按钮连续排列；场景与控制区仍有表单感 | 让“我正在做什么”与场景动作靠近；当前目标、发现反馈、继续动作形成明确顺序 | 用户能找到可操作处，操作后看见变化并知道下一步，不靠长说明解释 |
| P0 | 五城共享几何山水、建筑符号与大面积低饱和色；故事不同，绘画语言仍偏相近 | 加强各城构图、局部工艺细节、前中后景、昼夜及材质差异；用证据支持的文化元素建立辨识度 | 能从画面与动作识别这一城，图景仍诚实标为原创示意 |
| P0 | 手机宽度下河卷以局部展示为主，图内题签与下方五城按钮同时存在 | 保留易用的选城方式，调整主次与横拖暗示，题签展开篇章时延续空间关系 | 不丢选中城市/河段；当前目标与所见城市一致，开始入口可见 |
| P1 | 平板左侧根页加右侧三栏，实际可同时看到四个区域；信息完整但较密 | 区分目录、主场景、资料与写作的视觉权重，按可用空间选择合适密度 | 场景仍能操作，摘录仍能拖，输入和保存不被键盘或裁切遮挡 |
| P1 | 文化库首部多行筛选，下方资料仍是相似文字卡 | 将发现与自由阅读组织得更像文化目录；筛选、全文、出处和收藏有清楚层次 | 不通关也能读完整资料，原22条档案及新增15条线索都可检索 |
| P1 | 个人长卷顶部导航题名与内容标题重复；空城占位与已有记忆交替出现 | 让用户自己的正文、摘录和画面成为长卷主体，弱化重复题名和大块空态 | 有记录时先看到自己的内容，无记录时给一个具体可做的动作 |
| P2 | 新漫游、旧档案、我的与系统卡片由不同组件组织 | 统一字号、间距、按钮等级、圆角、图标和状态文案；保留各页合理差异 | 从探索进资料、存记忆、回我的时感觉属于同一应用 |

不要把“再加一个入口、统计数或技术名称”当作创新升级。每个保留的动效都应说明用户改变了什么，例如船与桥相交、地表被揭开、灯由暗到亮、文字变成有出处的摘录笺。

现有主视觉方向是**青绿河流、暖纸阅读、少量朱砂**，可以在这一基础上优化，不把以下颜色当不可调整的最终设计：

| 语义 | 当前RoamingTheme |
|---|---|
| 页面暖纸 / 内容纸页 | `#F5F0E4` / `#FCF8ED` |
| 正文 / 次要文字 | `#233D35` / `#6C786A` |
| 河流 / 青绿强调 | `#28695A` / `#3E806C` |
| 浅青绿 / 分隔线 | `#DCE5D4` / `#D7D8C5` |
| 朱砂 / 金色 / 夜色 | `#AD543E` / `#BC984F` / `#173E3D` |

先整理语义规则，再同步主题入口及页面局部常量。不要只替换一套色值就宣称全应用设计已统一；当前五城部分颜色直接写在组件里，旧页面则通过资源取色。深色资源存在不等于新图景已完成全部深色设计验收。

## 7. 响应式与交互必须保留的约束

**当前断点是代码事实，不是不能调整的产品要求。** 修改后要按真实容器宽度验证：

- 根`Index`：整页宽度≥840vp且有目的页时使用Split；首页无目的页时使用完整画幅。左栏32%，约束280—360vp，最小内容420vp。
- `RoamingHome`：自身容器≥900vp使用宽版尺寸；横向Canvas基准宽1120，不能拿物理像素直接替代vp。
- `RoamingChapterPage`：内容区<900vp为主场景+原生Sheet；900—999vp为两栏，资料/写作在右；≥1000vp为场景、阅读、写作三栏。
- `RoamingScene`：绘画和点击/拖动映射要一起检查；改变视觉锚点不能留下旧热点位置。

保留已验证的状态链：

1. **返回：** M12用同一`NavPathStack.pop()`并消费Back事件；Sheet先关闭，保存忙时保护。不要退回平板最后一层Back直接退出Ability的旧行为。
2. **保存：** UI展示已保存应以`onCommit`成功为依据；探索完成不等于note保存，保存后的按钮状态与全文版本必须对应。
3. **选摘：** API26的`SelectionContainer`支持跨Text；保留系统全选。选中文字本身不能直接拖，因此先生成带来源卡片，再用UDMF拖卡。
4. **旋转：** 同一份正文、标签、摘录和所选记忆保留；从Sheet变侧栏时不重新初始化草稿。
5. **同步到达：** 提供继续入口，不强行覆盖正在写的内容或抢走当前页；本机保存、服务器确认、本端实际收到分别表达。
6. **登录：** 记录触发时的篇章和最新线索，离线返回也恢复；仅登录不导入游客数据，明确复制才带入，原副本保留。
7. **动效：** 尊重`reducedMotion`；城市题签共享元素标识与篇章对应。接口存在不代替实际转场观感验证。
8. **键盘：** 已发生两次测试因键盘遮挡标签而失败；优化要真实输入、收键盘并滚动查找保存，不能只看静态空白图。

## 8. 本轮前端设计不能突破的数据与内容边界

- 保持schema v1、旧稳定ID、时间戳、装饰、`snapshot3DPose`原语义、AI冻结依据和删除墓碑；旧普通笔记不自动补漫游字段。
- 新漫游note的可选`roamingContext`保存篇章、线索、选择、图景/内容修订、冻结摘录和来源。改显示不能把当前资料覆盖到保存时依据；需要新格式时先给兼容方案。
- 原创图景承担叙事，授权照片承担真实观察；不得把生成插画、官网图片或泛化建筑符号称为遗址复原。新增素材记录来源、作者、许可、离线打包范围。
- 文化资料继续“初稿待校审”。传说、考古、不同年代的节庆/饮食和编辑叙述分别标注，不能为页面好看新增未经核实的文史结论。
- 在线AI仍只允许**杜岭二号方鼎与大河村双连壶**；新诗文/民俗材料不能因有新入口就标成在线AI可用。
- 实际跨端仍为自建同账号HTTPS；华为账号、鸿蒙可信原生跨端、系统应用接续和完整文件备份恢复未完成。不要为宣传卡片补“鸿蒙原生同步成功”。
- `domain/*.ts`保持纯领域，不导入`@kit.*`、UI或平台存储；平台能力放`platform/`、`data/`、`sync/`。

## 9. 建议的下一轮实施顺序

用户已纠偏，下一轮先按[玩法重构交接](GAMEPLAY_REDESIGN_HANDOVER_2026-10-23.md)实现开封的可玩核心样板：摆放关系、具体错误反馈、资料叠合与原创制灯，验证“观察→尝试→结果→调整”的闭环，再做首页与全应用视觉统一。下面五步仅作为该玩法落地时的表现层工作方式，不能先绕过规则设计做全站换皮。

1. 先看现有代码和原图，再在手机/平板试玩。记录少量可复现的设计问题，区分已有功能、视觉问题和新需求。
2. 写清这轮的字体/留白/按钮/场景层次及动效原则，列明会改哪些组件，随即实现首条完整原生路径。常规可逆设计调整不需要额外设置审批门禁；真正缺少偏好或材料时再简短询问。
3. 改好开封的开始、发现、读故事、点灯、写作、保存与全文，再把可复用规则带到其余四城；每城保留自己的构图与动作。
4. 接上文化库、记忆、我的与旧档案，收敛风格。局部抽取`Index`视图即可，不先重写账号/同步编排。
5. 用最终原生画面检查，再更新演示定位和新一轮说明。旧M12证据、Word/PDF、ZIP按历史保留，新结果另命名。

## 10. 持续参考与鸿蒙能力调研

用户要求持续找参考和灵感。调研应跟随这轮具体问题，不是技术关键词罗列。每次记录**访问日期、实际读到的内容、借鉴点、落到哪个用户动作、SDK/设备验证状态**。

已有资料入口：

- [文化参与方式与短引复核](research/roaming-culture-20261023.md)：记录实际取得的官方文本、取舍与未完成的底本校勘。
- [鸿蒙系统能力核验](research/roaming-native-system-20261023.md)：区分官方正文、HTTP应用壳、本机SDK声明与模拟器实跑，不能把200响应当全文已读。
- [故宫主题与故事游览](https://young.dpm.org.cn/?i=routeopen)：问题驱动的故事路线参考。
- [非遗参与体验案例](https://www.ihchina.cn/news_1_details/31666.html)：理解参与动作怎样产生个人选择。
- [地坑院营造](https://www.ihchina.cn/project_details/14687.html)、[洛阳牡丹花会](https://www.ihchina.cn/project_details/15243.html)、[汴京灯笼张](https://www.ihchina.cn/project_details/14067.html)：文化事实与材料身份参考。

上述链接沿用已有调研，本次写交接没有重新访问，不宣称其正文刚完成核验。新鸿蒙API优先查华为官方、OpenHarmony官方仓库和本机API26类型声明；新增能力要有可体验的用途和真实运行结果。

## 11. 本机运行与本轮验证方式

本机环境、服务与旧桌面入口见[本机操作补充](../.local/handover-20261023/本机操作补充.md)。这份文件仅供本机，不复制里面的私有配置或账号材料到公共包。

上一轮结束时手机为`YunhejiSyncB / 127.0.0.1:5555`，平板为`YunhejiRoamingPad / 127.0.0.1:5557`；平板横屏2880×1920、density320。那是收尾快照，接手先查询是否仍在线，不直接假定设备/18443服务仍在运行。不要通过改手机密度冒充平板。

前端优化后必须运行：

```powershell
.\tools\test.ps1
.\tools\build.ps1
# 需要运行设备用例时，先重建包含当前主源码的测试包
.\tools\build.ps1 -Target ohosTest
```

设备测试按修改范围选择，使用独立Preferences，不清空正式档案。真实样例：

```powershell
.\tools\device-test.ps1 -TargetId '<实际手机ID>' -TestClass 'RoamingTest#native_guest_five_city_entries_do_not_auto_complete' -ExpectedTests 1 -TestTimeoutMs 600000
.\tools\device-test.ps1 -TargetId '<实际平板ID>' -TestClass 'RoamingTabletTest#native_excerpt_drag_survives_portrait_and_landscape_before_save' -ExpectedTests 1 -TestTimeoutMs 600000
.\tools\device-test.ps1 -TargetId '<实际平板ID>' -TestClass 'RoamingTabletTest#native_memory_directory_keeps_selected_note_after_orientation_changes' -ExpectedTests 1 -TestTimeoutMs 600000
```

完整交互样板另用[roaming-demo.py](../tools/roaming-demo.py)走开封路径；每轮使用新的独立库，Ctrl+C或该轮输出目录的STOP停止。测试和人工控制不要同时占用同一设备，用户要求停止界面控制时立即停。

验证交付至少包含：

- 修改后的手机首屏、同一篇章操作前后、真实写作/保存/全文、平板横竖屏原图；按问题收集，不为凑数量重复拍。
- 记忆/目录相关改动核对选中正文、出处和保存状态；场景改动核对热点、手势和完成条件；系统入口改动才重验对应卡片/分享路径。
- 主包/测试包SHA256、构建结果、原始Pass/Failure/Error/Ignore；退出码0不能替代用例通过。
- 页面结构或文案调整后，同步修正失效测试定位，不能通过放宽断言或注入progress冒充走通。

上一轮本地141/141、解析9/9，两包构建成功，设备报告23份中13完整成功、10失败/中断；这是M12及历史对应包的事实，**新设计修改后不能直接继承为本轮验收**。不扩展大字体、压力、泛化安全或完整历史UI套件；以比赛路径和具体问题为准。

## 12. 已有交付与工作区保护

- [12页Word](deliverables/云河纪-省赛五城漫游说明-20261023.docx)、[同源PDF](deliverables/云河纪-省赛五城漫游说明-20261023.pdf)和[材料核验](test-results/2026-10-23-roaming-materials.json)已完成。
- 桌面“云河纪-省赛五城现场包-20261023”及ZIP已完成；[交付核验](test-results/2026-10-23-roaming-delivery.json)记录243文件与ZIP哈希。它是明确白名单的本机现场包，不包含整个工作区源码，也没有正式平台提交。
- 旧20261021材料和桌面入口也保留。旧自动演示入口走旧路线，不能不检查就当新版五城演示。
- 不reset/clean脏工作区，不覆盖签名、证书或用户文件；`YIda/`和`pelican-bicycle.html`不属于这轮设计整理范围。
- 未获用户要求不提交、推送或发布；复杂/易调整逻辑写必要中文注释，Git说明用中文。当前不默认启用子代理；若后续用户授权，按用户指定`gpt-6.1-sol max`执行，不可用时不悄悄换模型。
- 新版设计应另留前后原图与说明；本交接新增在工程中，没有改写冻结的M12现场包。

## 13. 可直接粘贴给新对话的任务

```text
继续开发原生鸿蒙比赛项目“云河纪”，工程在 D:\Open_of\yuenheji。本轮优先游戏化核心玩法重构，前端视觉服务玩法。

先完整阅读 AGENTS.md、docs/GAMEPLAY_REDESIGN_HANDOVER_2026-10-23.md，再读docs/FRONTEND_DESIGN_HANDOVER_2026-10-23.md、当前README、五城交接与实际原生截图。已经有M12五城功能底座，但它不能证明玩法创新成立；当前工作区另有后续前端修改，先看代码保留他人工作。不要从旧审查重新开发功能，也不要把旧DESIGN.md的玫瑰色方案当作当前规范。

本轮重点是有规则、可试错、有因果反馈和个人结果的玩法。推荐先做开封“叠城寻路”：摆放和转向桥片让街水双路径成立，错误尝试显示具体断点，用资料叠合联系同址不同时间，再制作和摆放自己的原创灯。文化知识要影响判断，不能只在通关后读卡片；禁止继续用滑满阈值、任选片段加确认包装创新。先实现一城完整可玩样板，再将其他四城发展为不同机制，视觉同步精修，真人试玩后再判断是否有效。

保持ArkTS/ArkUI、HarmonyOS 7/API26与个人文化探索定位；主导航漫游/文化库/记忆、独立我的。保留旧22条内容、两对象AI、schema v1、稳定ID、pose、冻结依据、装饰、墓碑和账号隔离。探索完成不自动生成感想或到访；游客资料明确选择后才复制，原副本保留。实际双端是自建账号HTTPS，华为账号/原生可信跨端/完整文件恢复仍未完成，暂不扩展云部署和实机工作。

优先局部改前端组件，按真实容器宽度设计手机/平板，保留原生选摘→卡片→UDMF拖放、Sheet、返回及旋转状态。运行必要test/build与定向原生设备检查，保存修改后的实际截图和原始Pass/Failure/Error。保留旧材料与现场包，不清空正式数据，不自动提交推送。交付时说明设计变化、用户得到的改善、实际验证与未完成边界。
```
