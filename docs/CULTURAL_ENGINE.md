# 文化视口与本轮验证范围

日期：2026-10-17。当前交付范围为文化目录与交互视口的 Step 1、Step 2 核心：20 条五城内容、独立预设元数据、四主题显式探索进度，以及可复用的四场景视口。内容与进度记录边界另见 [EXPLORATION_DATA.md](EXPLORATION_DATA.md)。

用户在本轮明确后续以比赛演示为准，不再主动开展大字体、泛化安全或边界测试；验证围绕能启动、核心操作、实际页面与必要构建收敛。下文已执行的大字测试仅为历史记录，不是后续每轮必跑项。

## SDK 与工程边界

当前工程继续使用 **HarmonyOS 7 / API 26**。用户已取消 HarmonyOS 6 降级要求，`build-profile.json5` 保持 `targetSdkVersion: 26.0.0` 与 `compatibleSdkVersion: 26.0.0`；本轮不宣称 HarmonyOS 6 或 OpenHarmony API 12 兼容，也没有把降级设为后续开发前置条件。

页面、交互按钮、档案正文与存储仍由 ArkUI 管理。`CulturalEngineViewport` 在首页沙盘、档案详情与文明图谱复用，支持 `river_sandbox`、`relic_inspector`、`stratum_slice`、`constellation_graph` 四种纯数据场景。形态、地形、热点与主题层均为学习用示意，不能当作实物复原、测绘结果、考古地层或用户知识掌握程度。

## Web 与原生绘制

离线 Web 引擎位于 `entry/src/main/resources/rawfile/engine/`。WebGL2 路径使用随包脚本、局部 GLSL 着色和静态几何解析；Web 环境另有 Canvas 2D 软件路径。资源没有 CDN、远程内容或在线模型解码器。实现与本地验证命令见该目录的 [README.md](../entry/src/main/resources/rawfile/engine/README.md)。

当前模拟器已知会在 ArkWeb 初始化时发生 EGL 原生崩溃，所以 `needsObjectCanvas()` 会在创建 Web 组件之前选择原生 ArkUI Canvas。该分支使用 `CulturalNativeRenderer` 的软件透视、深度排序和逐面光照，不创建 WebGL 上下文；本轮已核对该原生分支的实际画面与交互；Web Canvas fallback 不能据此称为已通过设备验收。Web 与 ArkUI Canvas 是独立实现，模型轮廓、材质和像素不保证一致。

原生软件视口包含五城顺序沙盘、四个阅读主题的展开示意、`form` / `pattern` / `story` 三个热点，以及陶器、城台、环形城垣、塔、墓丘、窑体等程序化类型示意。它们只用于浏览与交互，不将西水坡的图像解释成确定的“龙”复原，也不把统一阅读主题包装成具体遗址层序。

本轮另补齐三种非器物模型：**桥梁、无造像的崖壁／洞窟、无铭文的纪念空间**，分别承接州桥、龙门与纪念类条目的学习主题；墓葬观察框、聚落布局和中性蚌壳点列也有明确预设。当前 20 条元数据使用的预设名均已对齐，非陶器条目不会因为别名不同而统一落到陶罐。几何轮廓不提供未经核实的桥梁结构、洞窟造像、碑文或出土平面。

新增硬面几何修正面绕序与法线，按真实面边参与背面剔除和逐面光照，避免城台、桥梁、崖壁与纪念台基的直面出现光照方向或剔除错误。该修正属于示意网格绘制，不表示物理材质、真实阴影映射或完整 PBR；面数变化不能换算为未经测量的帧率提升。

本地尚无获得正式授权并随包提供的 `.glb` 文物模型。`glb.js` 可预览符合限制的本地 GLB 2.0 静态几何，支持内嵌缓冲、非压缩三角面、节点变换与基础材质色，但不支持纹理、动画、蒙皮、压缩扩展或完整 PBR；加载成功只表示几何预览可用。二进制夹具的本地解析测试不等于随包真实文物模型已加载验收。当前也没有 WebGL2 着色器编译通过或设备 GPU 可见画面的证据，因此不称真实 GLB 随包展示或 Shader / GPU 设备验收通过。

## 本轮变更文件清单

以下路径相对工程根目录，按 Step 1、Step 2 的主要职责列出；其他既有未提交工作不因此被回退或归为本轮新增能力。

| 范围 | 文件 | 本轮职责 |
|---|---|---|
| 领域与内容 | `entry/src/main/ets/data/HeritageCatalog.ts`；`entry/src/main/ets/domain/CulturalContent.ts`；`entry/src/main/ets/domain/ExplorationProgress.ts`；`entry/src/main/ets/domain/ArchiveDomain.ts`（只扩展筛选枚举） | 五城 20 条内容与预设元数据，四个学习主题和独立进度记录；保留原档案 ID 与内容校审边界。 |
| 领域与几何契约 | `entry/src/main/ets/domain/CulturalEngineContract.ts`；`entry/src/main/ets/domain/CulturalNativeScene.ts`；`entry/src/main/ets/domain/SiteObjectGeometry.ts`；`entry/src/main/ets/domain/SiteObjectRaster.ts` | 纯数据场景契约、中性学习几何、硬面法线及逐面软件绘制规则。领域文件不导入平台 API。 |
| 原生视口 | `entry/src/main/ets/components/CulturalEngineViewport.ets`；`entry/src/main/ets/platform/CulturalNativeRenderer.ets` | 创建 Web 前选择模拟器软件分支；手势与可访问按钮、场景镜头、主题、暂停／恢复、可见性与桥接边界。 |
| Web 引擎 | `entry/src/main/resources/rawfile/engine/index.html`；`engine.css`；`core.js`；`renderer.js`；`glb.js`；`engine.js`；同目录 `README.md` | 离线入口、共用数学核、自定义 WebGL2 shader 与软件投影、本地静态 GLB 解析、原生通信与生命周期。后续短文件名均位于同一 `engine/` 目录。 |
| 页面与资源 | `entry/src/main/ets/pages/Index.ets`；`entry/src/main/ets/components/SiteDetail.ets`；`entry/src/main/ets/components/CultureAtlas.ets`；`entry/src/main/ets/components/ArchiveTheme.ets`；`entry/src/main/resources/base/element/` 与 `entry/src/main/resources/dark/element/` 内的主题颜色资源 | 首页五城沙盘、详情器物／主题切片、文明图谱的原生接入，以及浅深色配色对齐。页面正文与交互布局保持 ArkUI 标准容器。 |
| 测试 | `tools/domain.test.mjs`；`tools/cultural-content.test.mjs`；`entry/src/main/resources/rawfile/engine/engine.test.cjs`；`entry/src/ohosTest/ets/test/EngineExperience.test.ets`；`entry/src/ohosTest/ets/test/List.test.ets` | 内容与进度规则、20 个在库预设对应形态、网格／矩阵／GLB／生命周期专项，以及设备用例注册和分阶段回归。最终设备方法名与包对应关系以阶段清单为准。 |

## 实现状态

- 内容扩至五城各 4 条，共 20 条；原 15 个档案 ID 与相对顺序不变，新增 5 条追加到末尾。新增来源与文化事实校审限制见 [EXPLORATION_DATA.md](EXPLORATION_DATA.md)。
- 详情页四个学习主题为 `overview`、`archaeology`、`history`、`poetry-travel`，每个主题分别记录 25% 探索进度。只有用户明确点击“标记此主题已探索”，并在存储提交成功后才发布完成状态；聚焦、打开详情、拖动、点击热点或播放动态均不会自动增加进度。主题是阅读导航，不是考古层序或学会程度。
- 手动旋转、缩放或聚焦会暂停自动动态，可用“自动”恢复；减少动态开启时隐藏暂停／自动入口并保持按需静态绘制。应用后台或视口不可见时停止定时器／动画帧，恢复可见后补绘当前数据；主题切换不重载 Web 场景，因此不重置用户镜头。
- 截图 API 仅按需生成 PNG 并回调，不写入笔记正文、Preferences 或同步请求。当前没有 Step 3 手账接收者，`captureEnabled` 默认关闭并隐藏留影入口，不向用户提供点击后结果消失的按钮。
- Step 3 的拾遗手账卡与漫游路线尚未实施；Step 4 的分布式 KV、冲突裁决与备份恢复尚未实施。
- 原生 Canvas 网格和离线 Web 引擎各有实现与本地逻辑检查；这不代表视觉像素一致，也不替代支持设备上的 WebGL2/GPU 画面核验。

## 复现与当前结果

本轮本地测试 **81/81**、设备报告解析测试 **9/9**，主包与 `ohosTest` 测试包均构建成功。按场景绑定三版包的设备六项 **6/6**，Failure / Error / Ignore 均为 0：首页 / 图谱使用初始包，进度 / 模型使用热点配色包，外观 / 笔记使用大字修正后的当前包。21 张原图、减少动态静帧与五模型旋转像素比较见 [真实图集](design/engine/README.md)。每项报告与包 / 源码哈希见 [阶段清单](test-results/2026-10-17-engine-phases.json)，详细修正与限制见 [测试报告第17节](TEST_REPORT.md)。

首项合并的 river＋graph 设备阶段因 **240000 ms 超时**结束，原始报告为 **Pass=0、Error=1**，未计为通过。随后将五城筛选与图谱拆为独立场景，减少重复等待；首轮拆组图谱还暴露整屏滚动跳过短入口，改为有重叠的小步长搜索后，之后完成最终六项。全部失败与旧包阶段保留，不累计重试通过数。

在 PowerShell 项目根目录依次执行：

```powershell
.\tools\test.ps1
.\tools\build.ps1
.\tools\build.ps1 -Target ohosTest
hdc list targets
.\tools\device-test.ps1 -TargetId '<hdc 实际返回的设备 ID>' -TestClass '<阶段清单中的单项用例>' -ExpectedTests 1
```

设备复现应按最终阶段清单逐项运行，每次使用 **`-ExpectedTests 1`**，设备五项引擎场景与一项原收藏笔记回归分别运行，避免长套件总时限。上面的两个尖括号参数是待替换项，不是可直接复制的真实设备标识或最终方法名。

设备测试命令仅在恰好一台设备在线时可省略 `-TargetId`；多设备时须传入 `hdc list targets` 输出中的实际 ID。脚本在构建包缺失或旧于源文件时会停止，设备报告保存在 `docs/test-results/`；判定结果时查看 `Pass/Failure/Error`，并保留原始日志、对应包与重试记录。截图和布局文件仍需人工检查，不能把断言通过或截图生成等同于 GPU 画面验收。

