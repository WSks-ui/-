# 云河纪

河南黄河文化探索与个人文化记忆，第三届河南省高等学校信息技术应用创新大赛赛题一。

**产品定位：** 面向日常文化浏览、出游与研学的个人应用，不是工作协作工具。“跨端延续”指同一账号登录两台或多台设备后，同步收藏、分类、笔记、标签、浏览记录及阅读状态等个人信息；不要求用户在多台设备同时编辑或整理专题。个人图谱是已有数据的展示，同账号数据同步是应用整体能力，二者不绑定。

**当前版本：0.1.0，原生开发版，尚未完成参赛交付。**

2026-10-17 Step 1+2 核心更新：五城内容扩充到 **20 条初稿，每城 4 条**，保留原 15 个 ID 与顺序；详情提供四个主题的显式探索进度，每项 25%，不表示掌握度或真实考古地层。首页、详情与文明图谱共用四场景文化视口。用户已取消 HarmonyOS 6 降级，工程继续保持 HarmonyOS 7 / API 26，`targetSdkVersion` 与 `compatibleSdkVersion` 均为 26.0.0。当前本地 **81/81**、报告解析 **9/9**，主包与测试包构建成功。按场景绑定三版包的设备六项 **6/6**，Failure / Error / Ignore 均为 0：首页 / 图谱、进度 / 模型、外观 / 笔记各两项分别对应按钮样式调整的三个阶段。21 张实际原图及减少动态 / 旋转像素核对见 [真实图集](docs/design/engine/README.md)。包对应关系及保留失败见测试报告第 17 节。详见 [文化引擎与验证范围](docs/CULTURAL_ENGINE.md) 和 [文化目录与进度](docs/EXPLORATION_DATA.md)。

2026-10-16 形态光照更新：按更新后的 2c 接入逐面 Lambert 与 22 次幂定向高光、背面剔除、陶器三道纹带、有厚度的城垣及柔化的地面阴影；消除此前三角剖分的对角接缝。`SiteObject3D` 统一接收整个 `site`。本地 **60/60**、报告解析 **9/9**，当前包形态 / 外观三组设备回归 **3/3**。实际为 ArkUI Canvas 软件绘制，11 张原图与新旧对照见 [光照图集](docs/design/lighting/README.md)，实现与限制见 [说明](docs/OBJECT_LIGHTING.md) 和测试报告第 16 节。

2026-10-16 年代空间 / 形态更新：文明连线增加年代深度、透视、双指旋转、节点拖动与复位，详情加入陶器、城台、城垣、层塔和封土等可旋转几何示意。当前模拟器实际使用 **ArkUI Canvas**，保留 GPU / Web 路径待支持设备验收。本轮本地 **54/54**、报告解析 **9/9**、设备七项 **7/7**；22 张原图、两版包的场景关系及保留失败见 [空间体验说明](docs/SPATIAL_EXPERIENCE.md)、[真实图集](docs/design/spatial/README.md) 和测试报告第 15 节。

2026-10-16 内容与图谱更新：五城扩充至 **15 条初稿**，保留原有档案 ID。文明连线改用离线 ArkWeb 交互画布，包含力导向布局、节点拖动、选中高亮和原生档案索引；Three.js 随包携带，当前模拟器因 WebGL 被禁用实际使用 Canvas 2D 降级。页面、导航和账号保持 ArkUI 原生实现。见 [内容与图谱说明](docs/CONTENT_GRAPH.md)，本轮本地 **48/48**、报告解析 **9/9**，设备七组共 **13/13** 通过，13 张真实原图已检查；详见测试报告第 14 节与 [图集](docs/design/graph/README.md)。

2026-10-16 页面结构更新：启动先显示独立登录 / 注册页，大学与学号作为教育计划的选填占位；右下角通过 HDS 原生独立 miniBar 打开“我的”，与三项 Dock 分开。账号 / 同步 / 阅读偏好移入“我的”，“档案”保留本地档案与离线资源。原未登录记录从登录页的明确“离线浏览”入口访问。页面 / 账号专项 **4/4**、存储 / 浏览 **6/6**、未登录与收藏笔记回归 **2/2**，12 张真实原图已检查。详见 [页面说明](docs/LOGIN_PROFILE.md)、[截图](docs/design/profile/README.md) 与测试报告第 13 节。

2026-10-14 用户已明确比赛演示设备规则：使用团队自有鸿蒙设备，模拟器与实机均可，举办方不提供或指定运行平台。项目继续采用现有 HarmonyOS 7 / API 26 工程；设备参赛资格已确认，后续直接验证两端的实际分布式能力，无需等待组委会的平台答复。

2026-10-13 第二轮已推进 T02 手机核心回归：修正搜索自动化、笔记键盘遮挡和完整标签编辑，增加长笔记摘要/展开与独立 UI 测试库。最新实测与保留的失败记录见测试报告第 8 节。

随后按用户指定的 Yi_Da 设计语言重做原生界面：暖白与玫瑰配色、粉彩首页纸片、五城图标索引、双列文化卡片、分组详情和笔记弹层。设计依据与真实截图见 [设计说明](docs/DESIGN.md)，本轮验证与失败修复见测试报告第 9 节。

2026-10-14 进一步接入 Yi_Da 的官方 HDS 导航通道：顶部 `HdsNavigation` 标题栏的原生材质与渐变模糊，底部 `HdsTabs` 的整条悬浮 Dock。原生导航截图见 [顶部与 Dock](docs/design/immersive/README.md)，对应包的验证与保留记录见测试报告第 10 节。

2026-10-14 已完成本轮可见创新 **文明连线**：首页进入可交互五城图谱，点击节点查看关联，打开双遗址对照；真实收藏和笔记标签生成“我的图谱”及个人专题。真实页面见 [文明连线图集](docs/design/culture/README.md)，现场操作见 [90 秒演示路径](docs/DEMO.md)，本轮结果见测试报告第 11 节。

2026-10-14 已跑通 **独立账号与同账号双设备网络同步**：在“档案”注册 / 登录，收藏、分类、笔记、标签和浏览记录经 HTTPS 同步；离线修改本机保存，恢复服务后另一端接收，删除墓碑不会被旧记录复活。已创建第二台 `YunhejiSyncB` 模拟器，8 项账号 / 双端场景和两端独立库清理均通过。当前使用本机自建账号服务，正式公网部署及华为账号 / 鸿蒙分布式数据库尚未接入。见 [账号说明](docs/ACCOUNT_SYNC.md)、[真实双端图集](docs/design/account/README.md) 和测试报告第 12 节。

## 接手入口

- [完整开发任务书与交接](docs/HANDOVER.md)：范围、架构、优先级、任务依赖、验收与风险。
- [鸿蒙 7 技术核验](docs/HARMONY_RESEARCH.md)：2026-10-13 官方资料核验、API 26 光感与 OpenHarmony 边界。
- [测试报告与验收清单](docs/TEST_REPORT.md)：实测结果与未验证项，不能把构建成功等同于全部功能通过。
- [设计语言与页面截图](docs/DESIGN.md)：Yi_Da 参考规则、原生实现与视觉验收范围。
- [文明连线演示](docs/DEMO.md)：图谱、档案对照、真实笔记与个人专题的短展示路径。
- [独立账号与双端同步](docs/ACCOUNT_SYNC.md)：启动服务、双模拟器验证、身份隔离与当前范围。
- [登录与“我的”](docs/LOGIN_PROFILE.md)：启动登录页、Dock 外独立入口、教育计划占位与数据边界。
- [内容与交互图谱](docs/CONTENT_GRAPH.md)：15 条五城初稿、离线画布、真实关联和设备降级边界。
- [文化目录与进度](docs/EXPLORATION_DATA.md)：20 条档案、预设元数据、四主题进度与旧记录兼容。
- [文化引擎与验证范围](docs/CULTURAL_ENGINE.md)：四场景视口、平台回退、Step 1+2 状态与设备验收边界。
- [项目协作约定](AGENTS.md)。

## 当前能力

- ArkTS / ArkUI 原生应用，HdsNavigation / NavDestination 和 HdsTabs 原生浮动页签。
- 五城市 20 条初稿档案（每城 4 条），关键词与城市、年代、类型组合筛选，离线读取；原 15 个档案 ID 与顺序保留。
- 详情四个学习主题分别显式标记完成并记录 0%–100% 探索进度；旧版仅表示“打开过”的记录不折算为已读比例。
- 首页、详情与文明图谱复用四场景文化视口：五城沙盘、器物形态示意、四主题学习示意和图谱；当前模拟器实际使用 ArkUI Canvas 软件绘制。
- 离线 WebGL2 / GLB 静态几何预览代码随包提供；没有真实授权模型随包提供，WebGL2 / GPU 路径尚无设备验收，且不声称与原生 Canvas 像素一致。
- 收藏、收藏分类、笔记新增/修改/删除、时间戳与笔记标签。
- Preferences 本地快照、串行落盘、前一版本保留、数据校验和读取失败保护。
- 本地可解释推荐；统一记录格式、确定性版本合并和删除墓碑。
- 文明连线：按城市、年代与主题展开的空间图谱、旋转缩放与选中高亮、原生档案索引、可解释关联、双档案对照，以及由真实收藏/笔记标签生成的个人专题。
- 独立启动登录 / 注册页、Dock 外“我的”入口；账号 / 偏好与档案分开，教育资料仅作本次展示。
- 独立账号注册 / 登录 / 退出，按账号隔离本机档案；原未登录记录保留，不自动上传。
- 实际 HTTPS 个人数据交换、前台自动重试、删除墓碑与服务端冲突版本留存；状态来自真实响应与本机保存结果。
- API 26 沉浸光感适配边界、能力探测、关闭开关与减少动态效果选项。
- 浅/深色颜色与插画、响应字体大小的首页卡片，以及宽屏左右栏代码。当前手机已检查浅/深色和 1.5 倍字体，宽屏待验收。

**尚未完成：正式服务部署 / release 配置、登录会话的安全持久化和离线冷启动恢复、华为账号及鸿蒙分布式传输、冲突历史查看 / 恢复、20 条内容逐条校审、授权实景图片、完整专题知识库、Step 3 的拾遗手账卡与漫游路线、Step 4 的分布式 KV / 冲突裁决 / 一键备份恢复。** 当前四主题进度是用户显式标记的探索比例，不代表掌握程度或完整阅读计量；所有文化条目仍为初稿待校审。当前个人图谱是已有档案与用户记录的关联视图；`deviceId` 仍是安装实例 ID，账号身份由真实认证服务提供。材质和减少动态偏好留在本机。

当前封面是项目原创 SVG 主题示意，不是文物照片或考古复原。条目均标注“初稿待校审”；官方机构入口不等于条目级证据。

## 本机运行

2026-10-17 当前汇总：本地 **81/81**、报告解析 **9/9**，主包与测试包构建成功。设备按场景六项 **6/6**，Failure / Error / Ignore 均为 0；三版包、原图与保留失败见测试报告第 17 节。用户已明确后续以比赛演示为准，不再主动开展大字体、泛化安全或边界测试，验证围绕核心演示路径收敛。

2026-10-16 内容 / 图谱基线：本地 **48/48**、报告解析 **9/9**；新增四项专项分组 **4/4**、原有图谱 **2/2**、组合筛选 **1/1**、存储 / 浏览 **6/6**。主包构建与三版测试包均成功，版本、原图与保留失败见测试报告第 14 节。

登录 / 个人页改版时（图谱扩充前）：本地代码测试 **43/43**、设备报告解析 **9/9**，主包和测试包构建成功。`ProfileLoginTest` **4/4**、存储 / 浏览 **6/6**、未登录与收藏笔记 CRUD / Ability 重建 **2/2**，Failure/Error/Ignore 均为 0；12 张原图已查看。当前包哈希、失败修复和边界见测试报告第 13 节。

2026-10-14 账号同步版本的 HTTPS / SQLite 服务综合 **1/1**、账号双端 **8/8**、两端清理 **2/2**、文明连线 **2/2** 等证据保留在第 12 节。本轮没有重复该双端完整套件，不能把旧包结果计作当前包的新验证。

上一版原生导航包按 **6/6 + 4/4 + 2/2** 分组完成原有 12 项功能回归，原生导航专项另有 **2/2**；保留在第 10 节。本轮围绕新增演示路径验证，没有把上一版的全量回归直接算作新包结果。

上一轮 T02 的进程强停两阶段 **2/2** 为改版前包的历史证据，保留在第 8 节；本轮没有重复强停验证，不能将旧结果直接套用到新包。

使用现有 DevEco Studio 打开本目录，等待 Sync，选择 `entry` 与 HarmonyOS 7 模拟器运行。

工程保留原包名 `com.chr.myapplication`，避免无意改变现有安装身份。正式签名前由团队确认包名。

```powershell
.\tools\start-account-server.ps1 -TargetIds @('127.0.0.1:5555','127.0.0.1:5557')
.\tools\build.ps1
.\tools\test.ps1
.\tools\build.ps1 -Target ohosTest
.\tools\account-test.ps1 -DeviceA 127.0.0.1:5555 -DeviceB 127.0.0.1:5557
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass CultureAtlasTest -ExpectedTests 2
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass ArchiveDeviceTest -ExpectedTests 6
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass 'ArchiveUiTest#native_sync_panel_reports_unavailable,ArchiveUiTest#native_combined_filters_and_reset,ArchiveUiTest#native_favorite_note_crud_and_ability_restart,ArchiveUiTest#native_unsaved_draft_close_back_and_keep_editing' -ExpectedTests 4 -SkipInstall
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass 'ArchiveUiTest#native_maximum_note_and_tags_are_saved,ArchiveUiTest#native_maximum_tags_survive_edit_and_expansion' -ExpectedTests 2 -SkipInstall
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass ArchiveImmersiveTest -ExpectedTests 2 -SkipInstall
.\tools\restart-test.ps1 -TargetId 127.0.0.1:5555
```

运行脚本前设置 `DEVECO_HOME` 或传入 `-DevEcoHome` 指定 DevEco Studio 安装目录；当前工作区可使用已忽略的 `.local/deveco-home.txt` 保存本机配置。
构建脚本只临时设置当前进程的 SDK/JDK 路径，不修改系统配置。
设备脚本仅连接在线设备，保存原始报告并核对用例数量与 Pass/Failure/Error/Ignore；UI 测试使用独立库，不清空正式档案。请用 `hdc list targets` 的实际返回值替换设备参数。启动与操作模拟器使用 HDC/命令行，无需控制桌面。

新版目录与详情需要更多滚动操作。推荐按 6 + 4 + 2 三个功能组分别运行，完整覆盖原来的 12 项；原生导航专项另列 2 项，不把一次总超时或仅有截图记成通过。最大长度的两项共用专属测试库，须在同次调用中按准备 / 编辑顺序运行。

双端账号脚本每轮生成随机独立测试账号、重新构建并顺序验证两个设备，不能直接运行整个 `AccountSyncTest` suite。离线阶段暂停本任务账号服务，结束后恢复同一数据库与证书；不是整机断网测试。当前会话只在进程内，应用进程退出后需重新登录。账号服务和两台模拟器可用于手动演示，操作顺序见 [双端记忆展示](docs/DEMO.md)。

运行 UI 套件前确认模拟器已解锁。官方悬浮栏会覆盖部分内容，测试已按实际标题 / Dock 范围调整滚动手势与点击位置；锁屏、缺节点或超时仍按失败处理。长回归可临时使用模拟器 `power-shell timeout -o` 覆盖熄屏时间，结束后用 `-r` 恢复，本轮未修改电脑电源设置。

- DevEco Studio：26.0.0.821
- SDK：26.0.0.105 / API 26
- Node：24.14.1（DevEco 自带）
- `runtimeOS`：HarmonyOS
- `compatibleSdkVersion` / `targetSdkVersion`：26.0.0
- 主包：`entry/build/default/outputs/default/entry-default-unsigned.hap`

**项目没有签名配置，未签名包已能在本机模拟器安装，不意味着能在任意真机安装。不要提交私钥、证书密码或设备标识。**

项目已初始化 Git 仓库，远端为 [WSks-ui/-](https://github.com/WSks-ui/-)，主分支为 `main`。依赖、构建包、本机数据库、私钥和测试凭证不纳入版本管理；公开测试记录中的本机绝对路径已脱敏，原始记录保留在本地忽略目录。

## 目录

```text
entry/src/main/ets/
  pages/Index.ets                 应用状态、导航、检索/收藏/设备视图
  components/SiteRow.ets          可复用档案行
  components/SiteDetail.ets       详情与笔记编辑
  components/CultureAtlas.ets     五城/个人图谱与双档案对照
  components/CulturalEngineViewport.ets 首页、详情、图谱共用的四场景视口
  components/CultureGraphNative.ets 原生年代空间画布与可访问节点
  components/SiteObject3D.ets      详情形态交互与生命周期
  domain/CultureGraphLayout.ts    原生 / Web 共用力导向布局
  domain/CultureGraphSpace.ts     年代深度、投影与标签避让
  domain/SiteObjectGeometry.ts    平台无关的程序化网格
  domain/ArchiveDomain.ts         不依赖平台的纯数据与规则
  domain/CultureConnections.ts    文化属性、真实笔记标签与个人专题规则
  domain/AccountSync.ts           账号状态、身份与网络响应校验规则
  domain/CulturalContent.ts       预设元数据与四个阅读主题
  domain/ExplorationProgress.ts   向后兼容的主题探索进度规则
  data/HeritageCatalog.ts         五城 20 条离线初稿
  resources/rawfile/engine/       离线 WebGL2 / Canvas 与 GLB 静态几何预览
  data/LocalArchiveRepository.ets 鸿蒙本地持久化适配
  platform/HarmonyEffects.ets     API 26 光感隔离层
  sync/SyncGateway.ts             同步契约与明确不可用的默认实现
  sync/AccountSyncClient.ets       原生 HTTPS 注册、登录与真实账号交换
entry/src/ohosTest/               真正的设备端 Hypium 测试
server/                          本机独立账号服务与 HTTPS / SQLite 综合测试
tools/                           可重复构建与领域测试
docs/                            研究、验收与交接
```

