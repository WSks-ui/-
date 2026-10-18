# 三处重点观察与带画面手账

记录日期：2026-10-17。目标工程：HarmonyOS 7 / API 26，ArkUI 原生页面。本说明记录当前代码行为，不登记设备、画面一致性或双端通过结果；实际验收由[测试报告](TEST_REPORT.md)另行记录。

从大河村 `zz-dahecun` 的彩陶双连壶样板扩展到庙底沟和杜岭二号方鼎，三处共用一条体验路径：观察具体部位、阅读对应事实、转动取景、保存个人文字与画面参数，再从手账重返同一观察。精细场景均显式使用 `sceneRevision: 2`，采用原生 ArkUI Canvas 绘制各自独立的程序化几何；其他档案仍沿用原详情。

## 庙底沟：看见共存的西部

核心问题是“陶窑和居住遗存分别在哪里？”。`smx-miaodigou / miaodigou_pottery / revision 2` 使用方位沙盘，页面模式名为“空间观察”。居住符号跨西部和中部，陶色陶窑符号穿插在西部，东西两侧为开放沟槽。原点的 `+X` 为东、`-X` 为西；沙盘内方位标识随模型转动，不能把旋转后的屏幕左侧始终理解为西。

| 部位 | 当前观察内容 | 对应事实 ID |
|---|---|---|
| `living` · 居住遗存 | 西部与中部均有居住符号，强调分布范围 | `miaodigou-living` |
| `kilns` · 西部陶窑 | 观察西部陶窑与居住符号共存，不能读作互斥功能区 | `miaodigou-kilns` |
| `ditches` · 东西壕沟 | 观察东西两侧开放沟槽，不延伸成完整围墙或闭合边界 | `miaodigou-ditches` |

配置见[MiaodigouObservation](../entry/src/main/ets/domain/MiaodigouObservation.ts)，几何见[MiaodigouObservationGeometry](../entry/src/main/ets/domain/MiaodigouObservationGeometry.ts)。房形、陶窑和沟槽只作为阅读符号，其数量、间距、轮廓、深度和各部比例没有测绘、地层或年代含义。依据与原图边界沿用[庙底沟资料记录](research/core-experience/miaodigou.md)。

## 杜岭二号方鼎：四加四的八组位置

核心问题是“四面方鼎，为什么有八组上腹兽面纹？”。`zz-duling-fangding / duling_fangding / revision 2` 表达敞开的方口、内壁与器底、外折口沿、双立耳和四根上粗下细的柱足。玫瑰色位置标记位于四壁正中，陶色折片跨过四个棱角，分别高亮后可看清两组位置关系。

| 部位 | 当前观察内容 | 对应事实 ID |
|---|---|---|
| `centers` · 壁面正中 | 四壁正中的玫瑰色位置标记 | `duling-eight` |
| `corners` · 四个折角 | 跨相邻两壁的陶色折角标记，和四壁正中合为上腹八组 | `duling-eight` |
| `frame` · 乳钉边框 | 每壁两侧边与腹部近底端的点状边框，与上腹位置标记区分 | `duling-eight` |

配置见[DulingObservation](../entry/src/main/ets/domain/DulingObservation.ts)，几何见[DulingObservationGeometry](../entry/src/main/ets/domain/DulingObservationGeometry.ts)。位置标记不是兽面纹拓本；乳钉数量、排数和局部比例不代表实测值，足部纹饰不计入上腹八组。依据与素材边界沿用[二号方鼎资料记录](research/core-experience/duling.md)，不能套用一号鼎数据。

## 大河村：两壶内部怎样相通

核心问题是“两只并排的壶，怎样成为一件内部相通的器物？”。对象特指河南博物院藏彩陶双连壶，不能把它的特征推广到大河村全部彩陶。事实正文与来源见[内容数据](../entry/src/main/ets/data/MaterialStudyCatalog.ts)及[对象研究记录](research/core-experience/dahecun.md)。

| 部位 | 当前观察内容 | 对应事实 ID |
|---|---|---|
| `mouth` · 两只壶口 | 并列壶体各有自己的器口；正文先说明具体器物的身份、出土与现藏信息 | `dahecun-object` |
| `opening` · 腹部通口 | 用剖开示意解释腹部接合处的椭圆形通口及内部相通关系 | `dahecun-opening` |
| `paint` · 红衣黑彩 | 观察红衣上的黑彩横带，以及其间竖向、斜向短线的变化 | `dahecun-lines` |

[MaterialObservation](../entry/src/main/ets/domain/MaterialObservation.ts)统一提供热点 ID、标签、事实键、局部位置和推荐镜头；详情的部位按钮、画布热点与手账恢复使用同一份定义。[原创几何](../entry/src/main/ets/domain/MaterialObservationGeometry.ts)表达双口、壶体、内部通道和简化纹线。比例、壁厚、通口尺寸与纹线排布都是学习示意参数，不是实物测绘、扫描模型或纹样摹本；剖开显示属于解释手段，不是器物原有状态。

选择部位后，详情显示“正在观察”的具体名称及相应事实正文。用户仍可主动旋转取景。点击“留住此刻”时，保存的是当时实际相机参数及已选部位，编辑器的默认私人摘录取自当前部位的事实正文。正文和标签由用户填写，印章、纸色仍沿用既有手账选项；这些装饰不改变器物年代或事实状态。

## 保存原虚拟画幅并在本机重建

带画面的手账沿用原 `note` 和 `MemoryPose.version: 1`。除了角度、缩放、热点与主题等原字段，本轮按需保存以下信息：

| 信息 | 用途 |
|---|---|
| `proceduralPreset` | 明确保存哪一种程序化对象，避免打开错误档案的模型 |
| `sceneRevision` | 明确几何和热点修订；三处新观察均为 `2` |
| `rendererProfile` | 明确绘制配置；当前完整支持 `native-raster-v1` |
| `viewFrame.width / height` | 保存当时实际参与投影的虚拟画布尺寸 |
| `viewFrame.textDensity / dark` | 保存当时标签文字密度与明暗配色，避免改用当前设备偏好冒充原画面 |

这是一份可重建的参数记录，不附带实物照片或截图文件。[MemoryPosePreview](../entry/src/main/ets/components/MemoryPosePreview.ets)在手账编辑器和卡片中复用同一[原生绘制器](../entry/src/main/ets/platform/CulturalNativeRenderer.ets)。预览固定使用保存的相机、热点、场景修订、明暗模式和文字密度，没有自动旋转或拖动交互。

原绘制中的边距、投影与热点位置依赖虚拟画布宽高，因此预览先在保存的宽高下重建，再按 `min(预览宽 / 原宽, 预览高 / 原高)` 等比居中适配，必要时保留留白。它不会直接把卡片宽高代入投影重新取景。详情回放也按相同原画幅适配当前视口。编辑器和卡片的预览因此可以共享一份记录，但实际不同尺寸下的可见画面仍须由设备截图核对，代码路径本身不等同于画面一致性验收。

## 参数核对与实际绘制分开确认

[resolveMemoryReplay](../entry/src/main/ets/domain/MemoryReplay.ts)先核对档案、视角格式、模式、预设、场景修订、渲染配置、热点或主题及相机取值。`ready` 只表示这些信息完整且受支持；仅通过核对不会显示恢复成功。完整预览还要求原取景同时记录了文字密度和明暗模式。

[文化视口](../entry/src/main/ets/components/CulturalEngineViewport.ets)在回放请求通过后暂停自动动态、恢复参数并等待实际 `draw`。只有绘制器报告已产生模型画面，才显示“已回到手账视角”，并把成功结果交回详情。画布尚未就绪时保持重建状态；实际绘制失败时显示不可绘制原因。预览组件同样在实际绘制完成后才显示“已重建保存画面”。

这些状态用于避免把参数已解析、回调已调用或空画布当成成功。它们不能代替人工查看模型结构、画面完整性及保存前后的像素对照。

## 旧记录和不可用记录

旧普通笔记保持原正文、标签和时间戳，不自动补上视角或新元信息。合法旧视角缺少完整元信息时为 `legacy`，显示“旧版视角，原取景未记录”；卡片保留文字说明，不补造声称等同原画面的预览。可以恢复的旧视角按原 revision 1 打开，三处仍为各自原形态和 `form / pattern / story` 热点，不被 revision 2 静默替换；大河村旧记录因此仍显示原单壶示意。

未知档案、预设失配、不支持的版本或渲染配置、无对应热点、超出当前相机范围等情况为 `unavailable`。页面说明具体原因并保留手账文字，不代入首个档案，不截断角度或缩放后宣称恢复成功。已打开档案中的失败回放可通过“开始新的观察”进入当前场景，这次操作不改写原手账。

归档层仍保留形状合法的未知正场景修订和渲染配置；播放支持名单与保存能力分开。损坏扩展不能悄悄删除，须沿用既有读取失败保护。新字段及原取景参与深拷贝和规范冲突比较，删除仍保留墓碑。详细格式、旧客户端与服务重新加载的兼容边界见[手账迁移说明](MEMORY_MIGRATION.md)。

## 本轮范围与后续验收

精细观察登记三处 revision 2，正文和事实来源沿用已经核对的内容目录；详情、预览与正式回放使用同一场景分发。首页主题优先级与入口调整另按 T09 / T10 推进。

新手账的本机保存、预览和回放与同账号双端完整性是不同验收项。现有账号传输继续使用 HTTPS，不能因本机能够重建画面，就宣称新元信息已到达另一端或另一端画面已经一致。本轮双端尚未验收，不称为分布式 KV。

限定的[ObservationMemoryTest](../entry/src/ohosTest/ets/test/ObservationMemory.test.ets)提供大河村核心路径，[ExpandedObservationTest](../entry/src/ohosTest/ets/test/ExpandedObservation.test.ets)分两条提供庙底沟与二号方鼎核心路径：三部位、主动右转、真实保存后移除缓存回读、画廊和正式回放；只有明确选择对应测试类才启用。用例保留画布布局供实际画面核对。此处只说明验证入口，不记录其执行或通过结果。阶段任务仍以[核心体验执行规范](CORE_EXPERIENCE.md)为准。

## AI 观察导览（2026-10-18）

方鼎详情在原生视口和三个热点按钮之后增加可收起的 `AiObservationPanel`。面板请求真实 DeepSeek 模型，但只使用本对象的三条事实和 `centers / corners / frame` 三个热点；回答中的聚焦动作通过 `focusRequestJson` 独立序号交给 `CulturalEngineViewport`，同一热点连续请求也会再次聚焦，不复用“已回到手账视角”的回放文案。

回答到达不自动转动镜头、不自动保存；用户点击聚焦后仍可继续手动旋转。依据在面板内原地展开，事实、来源名称与核验日期由应用资料生成，不使用模型生成的 URL。用户写一句自己的观察后请求 AI 草稿；采纳后由视口回传当时实际相机和原画幅，再打开既有手账编辑器。只有确认保存才写入 `aiAssist`，见[AI 观察说明](AI_OBSERVATION.md)与[手账兼容说明](MEMORY_MIGRATION.md)。

AI 面板不改变方鼎的原生几何、热点含义和“位置标记非兽面纹摹本”的边界。实际设备路径、真实模型小样和保留失败见[测试报告第 25 节](TEST_REPORT.md)与[AI 观察图集](design/ai-observation/README.md)。
