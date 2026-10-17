# 年代空间图谱与形态观察

开发日期：2026-10-16。对应 `DEV_GUIDE_NEXT.md` 新增的优先级 2b、2c，延续 Yi_Da 的暖白、玫瑰、城市主色与系统深色资源。

## 年代空间

五城和个人图谱共用原有文化关联数据。力导向继续在 XY 平面布局，年代提供固定深度：仰韶 -120、龙山 -80、夏商 -40、周 0、汉唐 40、宋 80，未知年代回到中层。这些数值是阅读导航层次，不是历史时间比例、地理距离或文化传播方向。

- 绕画布中心旋转后做透视除法；远处节点较小、较淡，近处节点覆盖在前面。连线、视觉节点与 HTML 按钮使用同一投影。
- 拖动节点时，将屏幕位移逆投影到该节点的年代平面，保留原有节点拖动能力；空白处单指 / 鼠标拖动、双指平移可以转动整个图谱。
- 右上角提供“旋转”和“复位”，兼顾无障碍激活和不能同时操作双指的场景。视角不写入个人档案。
- 减少动态仍允许用户主动调整视角，不启动惯性和持续动画。页面隐藏或离开后沿用原有暂停 / 释放机制。
- 布局与投影只有一份 TypeScript 数学源：`CultureGraphLayout.ts` / `CultureGraphSpace.ts`。ArkUI 直接使用，ArkWeb 使用擦除类型后的离线产物，测试核对来源哈希，避免两套规则分叉。
- 模拟器使用新增的 `CultureGraphNative.ets`，通过原生 Canvas、原生可访问按钮和 ArkUI 手势呈现同一图谱。Web 路径保留用于其他设备验证；下方档案索引、个人专题与双档案对照仍为原有 ArkUI。
- 初始标签发生投影重叠时先避让，再按投影顺序安排可读行。用户主动拖动后优先保留手势位置，由周围标签避让，不为排齐标签把节点送回原行；位置只在本次图谱会话内保留。
- 本轮没有修改受保护的主导航、账号客户端、核心数据模型或材质适配。

当前模拟器的 ArkWeb 在 `Chrome_InProcGp → eglCreateImageKHR → d_eglCreateImage_special` 出现原生空指针。移除动态 CSS 变换、直接选择软件 Canvas、同步嵌入及应用内禁用 WebGL 均未消除该崩溃，因此没有继续把 Web 就绪或 DOM 节点存在当成可见画面。最终自动选择原生 Canvas；没有改设备图形参数、改签名或强开 WebGL。测试中的“画布选择”验证实际原生节点和回调，不称为本轮 Web 桥接通过。

图谱的 GPU / WebGL 渲染仍需要支持设备另行验证，不能把透视数学称为 WebGL 或鸿蒙原生光感。Three.js 随包保留，运行默认使用 Canvas 2D，不在启动时创建 WebGL 上下文。

修改数学源后，在项目根目录用 Node.js 24 执行 `node entry/scripts/compile-graph.mjs` 更新 rawfile 产物，再运行项目测试。产物头部保存经过换行归一化的源文件 SHA-256，构建不依赖网络。

## 详情页形态观察

`SiteObject3D.ets` 在详情顶部提供形态视口。支持设备上的场景和材质通过 `SiteObjectScene.ets` / `Component3D` 创建；当前模拟器自动使用 `SiteObjectCanvas.ets`，将同一份三维网格按透视、法线光照和面深度绘制到原生 Canvas。程序化网格来自纯 TypeScript 的 `SiteObjectGeometry.ts`，不下载模型、不加载外部 glTF、不访问网络或用户存储。

| 档案类型 | 几何示意 |
|---|---|
| 聚落遗址 | 带陶口的回转体 |
| 都城遗址 | 三层递减城台 |
| 城址 | 环形城垣 |
| 古建筑 | 五层递减的八角塔形 |
| 墓葬群 | 带底面的半球封土 |
| 窑址 | 矮宽窑体 |

当前目录没有窑址条目，窑体只覆盖几何规则验证。每种形态代表档案类型的交互示意，不代表该遗址实际形制。页面始终显示“按档案类型生成的几何示意，非文物或遗址复原”，原有内容继续保留初稿待校审。

视口支持左右转动、水平拖动和复位，正常模式可自动缓慢转动 / 暂停。减少动态关闭自动旋转，仍保留主动操作。滚出视口、打开笔记、跳转其他页面、应用进入后台时停用定时器；GPU 路径离开时释放 Scene，异步创建的过期结果只销毁自身。兼容路径根据完整投影包围范围自动取景，避免城台等较宽形态在旋转时裁掉底边。

不具备系统能力、已知为模拟器或 Scene 创建失败时使用兼容视口，保留原有主题插画和完整档案阅读路径。当前真机 GPU 路径已按本机 SDK 编译，但未通过本轮设备渲染验收；`canIUse` 为真、Scene 创建成功和按钮状态变化不能证明三维画面已经呈现。

## API 核验

核验日期：2026-10-16，目标 HarmonyOS 7，SDK 26.0.0.105 / API 26。依据本机 SDK 声明与 OpenHarmony 官方文档：

- [场景搭建与管理](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/graphics3d/arkgraphics3D-scene.md)
- [Scene 与资源工厂](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkgraphics3d/js-apis-inner-scene.md)
- [场景节点](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkgraphics3d/js-apis-inner-scene-nodes.md)
- [Component3D](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/ts-basic-components-component3d.md)

`@kit.ArkGraphics3D` 已由 SDK 提供，不添加同名 ohpm 依赖。`Scene.load()` 和 `factory.create*()` 均为异步；`Vec3` / `Quaternion` 是结构类型。实际提供 `CubeGeometry` / `CustomGeometry`，没有任务书示例中的 `BoxGeometry`、`TorusGeometry`、`Quat.fromEuler` 或 `LightType.AMBIENT`。`Component3D` 接收既有 Scene，没有 `onSceneReady`；相机 fov 使用弧度。当前使用 `CustomGeometry` 自行生成环形、回转体、半球与塔层，并统一挂到可旋转父节点。

深色背景读取 `surface_soft` 语义资源，独立于材质偏好 `lightEnabled`。Scene 保留原始原生引用，以状态字段驱动组件创建，避免状态代理包裹引擎句柄。当前不修改 SDK 配置、HDS 材质适配或核心数据格式。

## 验证记录

本轮本地 54/54、报告解析 9/9。设备七项 7/7，22 张真实原图已保存，图集与关键原图已检查；静止与旋转模型区域另有像素核对。逐场景包哈希、保留的失败和真实截图以 `TEST_REPORT.md` 第 15 节为准。场景创建或按钮断言通过不能替代可见渲染验收。

## 2c 逐面光照后续更新

同日按新版任务书改进软件路径：增加 `SiteObjectRaster.ts`，从多边形边计算旋转后的真实面法线；接入 0.30 环境光、0.55 漫反射和 0.28 × 22 次幂定向高光；剔除背面，整面填色 / 描边，避免 GPU 三角剖分的对角线出现在软件画面。三道陶器纹带与器身共面分区，城垣改为有厚度的内外壁，塔层收分有所区别，阴影改为模型下方的渐变椭圆。组件改传整个 `site`，主题仍来自真实语义资源。

本次最终本地 60/60、报告解析 9/9，形态三组设备 3/3，11 张原图和像素比较均已保存。原来的图谱七项属于上一对包的证据，本次未重新计入。详情、原图与性能边界见 [逐面光照说明](OBJECT_LIGHTING.md)、[新旧对照](design/lighting/README.md) 和测试报告第 16 节。
