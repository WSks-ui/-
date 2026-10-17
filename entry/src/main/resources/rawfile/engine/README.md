# 离线文化交互视口

这是 ArkUI 原生页面内的局部内容视口，入口为 `engine/index.html`，所有脚本随包携带，无 CDN、遥测、在线解码器和网络文化内容。页面导航、正文、可访问按钮和个人档案仍由原生组件管理。当前已知 EGL 不可用的模拟器应使用原生 ArkUI Canvas，不能因为 JavaScript 有 try/catch 就重新创建 WebGL 上下文。

`core.js` 生成相同的三维网格、相机、热点和分层比例。`renderer.js` 的 WebGL2 分支执行自定义 GLSL 光照、地形等高线、陶胎纹带、青铜色泽与水面流线；Canvas 分支做软件透视、深度排序、逐面光照与装饰粒子。软件兼容模式没有真实 shader、深度缓冲或完整 PBR。两条路径都不等于鸿蒙系统沉浸光感。WebGL2 / GLSL 的可见设备验收仍需支持设备；本地 Node 验证不能替代。

`?renderer=canvas2d` 会跳过 WebGL 上下文创建。颜色使用任务指定的浅色 `#FAF6F0`、深色 `#171311` 等令牌；视口与原生页面需要同时切换主题。

## ArkUI 调用

```js
engineSetTheme(true);
engineSetReducedMotion(true);
engineSetActive(true);
engineLoadScene('stratum_slice', JSON.stringify({
  version: 1,
  itemId: 'ly-erlitou',
  title: '二里头 · 文化主题探索',
  layers: [
    { id: 'overview', label: '概览' },
    { id: 'archaeology', label: '考古' },
    { id: 'history', label: '器物与故事' },
    { id: 'poetry-travel', label: '诗词与在地' }
  ],
  exploredIds: ['overview']
}));
engineFocusHotspot('archaeology');
```

四种 `sceneType` 为 `river_sandbox`、`relic_inspector`、`stratum_slice`、`constellation_graph`。完整纯数据类型见 `ets/domain/CulturalEngineContract.ts`。河道可传 `nodes`，省略则使用地理顺序的五城；器物读取 `proceduralPreset`，热点 id 为 `form/pattern/story`；图谱读取已有 `nodes/edges/selectedId`，节点可补 `type/explored` 或显式 `x/y/z`。节点最大 64、有效边最大 160、主题层最大 12；非法数据保留已有场景并经状态回调说明。

`engineFocusHotspot(id)` 与直接点击只选择，不增加进度。必须在用户明确按下原生“标记此主题已探索”后调用 `engineCompleteExploration(id)` 或 `engineCommand('complete', id)`。同一条目内去重后回调 0—100 的主题探索比例；原生层负责实际落盘、账号隔离与重载。已完成 id 从 `exploredIds` 重新传入。这个比例不代表内容校审、知识掌握或完整阅读。

当前在库 20 个 `CULTURAL_SITE_METADATA` 预设有明确映射：城址/都城用城墙或城台，桥梁用桥面/桥墩，龙门用无造像的崖壁轮廓，墓葬用中性观察框，聚落用学习布局，纪念空间用无铭文台基；西水坡使用中性蚌壳点列。它们不会因为与最初任务书中的别名不同而统一落到陶罐。所有轮廓均不宣称测绘复原。

四个默认切片是阅读主题的学习示意，始终显示“非实际考古地层复原”。不是把每个遗址编造为同一套实际四层。正式条目分期、层序与复原形态仍需来源校审。

其他命令：

- `engineCommand('turn', 1)`：向右转约 20 度，负数反向。
- `engineCommand('zoom', 1)`：缩短相机距离，负数拉远。
- `engineCommand('reset')`：当前场景复位。
- `engineCommand('capture')` / `engineCaptureSnapshot()`：导出 PNG 数据 URL。
- `engineSetView(json)`：指定 `yaw/pitch/distance/panX/panY`；有限值与范围校验后设置。
- `engineGetState()`：返回 JSON 状态，适合设备调试，不包含账号数据。
- `engineSetAutomatic(boolean)`：暂停或继续装饰动态及器物自动缓转，保留手动操作和聚焦运镜。减少动态仍优先。
- `engineDispose()`：退出时释放资源；释放后需要重建 Web 组件。

## 原生代理回调

代理名为 `EngineBridge`。必须提供 `onNodeSelected(id, type)`、`onProgressUnlocked(itemId, progress)`、`onCaptureSnapshot(dataUrl)`；可选提供 `onReady(renderer)`、`onStatus(statusJson)`、`onInteraction()`。手动拖动、缩放或旋转会通知原生同步暂停状态，原生“自动”按钮可恢复。选择类型为 `city/hotspot/layer/site`。原生层通过安全 JSON 字符串构建脚本，不拼接未经转义的文化正文。截图会把示意限定语直接写进像素。

页面隐藏、视口滚出、应用后台都需要原生传入 `engineSetActive(false)`。引擎另外监听文档可见性与 IntersectionObserver；暂停会取消帧、丢弃手势，模型异步旧响应不会覆盖新场景。减少动态会收敛相机并仅按输入、主题和尺寸变化绘制；软件静态网格有缓存，不为呼吸点重算全部三角面。GPU 动态帧上限约 30 FPS，软件装饰上限约 20 FPS，这只是调度限制，不是已测量的性能承诺。

## 本地 GLB

没有对应模型时程序化示意立即可见，随后只检查 `../models/<itemId>.glb`；可用 `modelPath` 指向同目录的其他本地安全文件名。拒绝外网 URL、路径穿越、外部缓冲与必要但未支持的压缩扩展。只在二进制解析、有效网格构造和 GPU/软件资源重建后发布 `modelState: loaded`。

`glb.js` 是真实 GLB 2.0 静态几何解析器，支持内嵌 BIN、未压缩三角面、索引、法线、节点矩阵/TRS、基础材质色和居中缩放；不依赖裁剪版 Three.js，也不伪称拥有未打包的 GLTFLoader。限制 16 MiB、60,000 三角面。纹理、动画、蒙皮、形态动画、Draco、Meshopt 和完整 PBR 尚未接入；已加载模型仍明确显示“本地 GLB 几何预览 · 纹理与动画尚未接入”。模型缺失、损坏或不支持时继续显示程序化示意并报告真实原因。

## 本地验证

```powershell
node --check entry/src/main/resources/rawfile/engine/core.js
node --check entry/src/main/resources/rawfile/engine/glb.js
node --check entry/src/main/resources/rawfile/engine/renderer.js
node --check entry/src/main/resources/rawfile/engine/engine.js
node --test entry/src/main/resources/rawfile/engine/engine.test.cjs
```

测试覆盖任务书预设与当前在库 20 个元数据预设的有限网格/法线及非陶器对应形态、CPU 与 GPU 投影矩阵的一致性、真实二进制 GLB 的变换与越界保护、选择和显式完成的差别、后台取消、减少动态、暂停/继续、缓存、异步旧模型丢弃与截图桥接。DOM/Canvas 用测试替身，不是可见像素或 GPU shader 编译验证。
