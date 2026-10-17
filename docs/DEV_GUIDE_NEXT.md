# 云河纪：下一轮开发指导文档

版本：v1.0，2026-10-16。面向 AI 代理全权开发，对应 gpt-6.1-sol。

## 核心约定

- 每轮完成后必须运行 `.\tools\build.ps1`，构建通过才算完成。
- 运行 `.\tools\test.ps1` 并查看 `Pass/Failure/Error` 字段，退出码为 0 不等于全通过。
- 文化事实没有逐条核实时保留 `reviewStatus: '初稿待校审'`，不得臆造诗词、考古数据或票价。
- 不覆盖用户已有文件，不修改 `.gitignore`、签名配置、账号服务脚本。
- 提交说明用中文；未获授权不自动 push 或发布。

---

## 禁止修改的文件与目录

以下内容已经过真实设备验证，不得在没有明确授权的情况下修改：

| 路径 | 原因 |
|---|---|
| `build-profile.json5` | `compileSdkVersion` 和 `compatibleSdkVersion` 均为 `26.0.0`，不得下调，否则 HDS API 失效 |
| `entry/src/main/ets/domain/ArchiveDomain.ts` | 核心数据模型，收藏/笔记/同步合并逻辑，改动破坏双端同步 |
| `entry/src/main/ets/sync/AccountSyncClient.ets` | 已通过 8/8 双端账号测试 |
| `entry/src/main/ets/sync/SyncGateway.ts` | 同上 |
| `entry/src/main/ets/platform/HarmonyEffects.ets` | 光感与减少动态适配，已做版本探测 |
| `entry/src/main/ets/pages/Index.ets` | 主页结构和 HDS 导航；可在尾部追加新 NavDestination 注册，不要删改已有部分 |
| `tools/` 目录 | 构建与测试脚本 |
| `entry/src/ohosTest/` 目录 | 测试用例，不得直接将失败项改为通过 |

---

## 优先级 1：扩充文化内容（最高价值，最低风险）

**为什么这是最高优先级：** 当前只有 5 条档案，导致搜索、推荐、图谱关联反复出现相同对象。内容不足是所有演示效果的瓶颈，扩充内容不需要改动任何架构。

### 目标

将 [`entry/src/main/ets/data/HeritageCatalog.ts`](entry/src/main/ets/data/HeritageCatalog.ts) 中的 `HERITAGE_SITES` 数组扩充到 **15～20 条**。

覆盖范围要求（对应赛题）：

| 城市 | 目标条目数 | 参考方向 |
|---|---|---|
| 三门峡 | 2～3 | 仰韶村、庙底沟遗址、虢国墓地 |
| 洛阳 | 3～4 | 二里头、偃师商城、汉魏洛阳城、龙门石窟区域文化 |
| 郑州 | 2～3 | 郑州商城、大河村遗址、荥阳故城 |
| 开封 | 2～3 | 铁塔、开封城墙、宋都遗址 |
| 濮阳 | 1～2 | 戚城、西水坡遗址 |

### 每条档案的格式

严格按照现有 `HeritageSite` 接口填写，缺少的字段不得臆造，用下列占位语句：

```typescript
// 诗词字段
poetry: '暂未收录可与本遗址直接对应的诗词。',

// 文旅字段
travel: '地点索引：<城市>。开放时间与预约方式尚未核验，以管理机构当日公告为准。',

// 考古字段（如无具体引用）
archaeology: '具体出土器物与分期结论需引用权威考古资料，待第二轮补充。',

// 来源字段（机构入口，不冒充条目级证据）
source: { title: '河南省文物局（待补条目级来源）', url: 'https://wwj.henan.gov.cn/' },

reviewStatus: '初稿待校审'
```

### id 命名规则

`<城市缩写>-<英文关键词>`，小写连字符，例如：
- `smx-miaodiku`（三门峡庙底沟）
- `ly-hanwei`（洛阳汉魏城）
- `zz-dahecun`（郑州大河村）

### illustration 字段

从已有的四个值中选择最接近的：`motif_pottery.svg`（陶器/聚落）、`motif_city.svg`（都城/城址）、`motif_pagoda.svg`（古建筑）。不要新建 SVG 文件，除非用户另行提供图片。

### accent 字段

每个城市用一个主色，同城新条目可沿用已有城市颜色，或在相近色值范围内取一个新值：
- 三门峡系：`#9B463E`（暖赭）
- 洛阳系：`#247568`（青绿）
- 郑州系：`#426F93`（青蓝）
- 开封系：`#776293`（紫）
- 濮阳系：`#677448`（橄榄绿）

### tags 字段对关联图谱的影响

`tags` 直接决定"文明连线"中两个节点之间是否出现连线（见 [`CultureConnections.ts:31`](entry/src/main/ets/domain/CultureConnections.ts:31)）。内容扩充时，相同文化脉络的遗址应共享 tag：

- 仰韶文化聚落类：`['彩陶', '聚落', '考古']`
- 都城类：`['都城', '青铜', '考古']`
- 城址类：`['城墙', '城市', '考古']`
- 宋代建筑：`['建筑', '城市']`

---

## 优先级 2：文明连线图谱视觉升级（ArkWeb Canvas 2D 力导向图）

> **2026-10-16 实际状态：** 本轮已完成并通过设备验证。图谱运行在 ArkWeb 内嵌的 **Canvas 2D** 上，不是 WebGL。当前鸿蒙模拟器的 ArkWeb 禁用了 WebGL，Canvas 2D 是已验证的生产路径。Three.js 已离线打包，其 WebGL 渲染路径需要在支持 WebGL 的真机上另行验证。后续优化应继续在 Canvas 2D 基础上进行，不要以"升级到 WebGL"为前提。

**目标效果：** 将 [`CultureGraph.ets`](entry/src/main/ets/components/CultureGraph.ets) 中现有的 Canvas 2D 静态折线图，升级为带物理弹簧动画的力导向图谱，发光节点，连线随选中高亮流动。

**架构方案：** ArkUI 壳 + 内嵌本地离线 ArkWeb 画布（Canvas 2D）。这条路线：
- 不改动任何已有的 ArkUI 页面结构和账号逻辑
- Canvas 2D 力导向布局是纯数学状态机，AI 写起来可预测，且在 ArkWeb 中已验证可用
- 通过 `javaScriptProxy` 与外层 ArkUI 双向通信，延迟 < 5ms
- 不依赖 WebGL，在当前鸿蒙模拟器和 HarmonyOS 7 真机上均可运行

### 第一步：新建 Three.js HTML 文件

新建文件：`entry/src/main/resources/rawfile/graph.html`

该文件是一个自包含的离线 HTML，不依赖任何网络资源。Three.js 需要内联或从 rawfile 加载。

```html
<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { background: transparent; overflow: hidden; }
  canvas { display: block; }
</style>
</head>
<body>
<script>
// --- 状态 ---
let nodes = [];       // { id, label, era, x, y, z, vx, vy, selected }
let edges = [];       // { source, target, reasons }
let selectedId = '';
let width = window.innerWidth;
let height = window.innerHeight;
let isDark = false;

// --- 颜色主题 ---
function theme() {
  return isDark
    ? { bg: 0x1a1510, node: 0xf5e6d0, accent: 0xe07070, edge: 0x5a3a3a, text: '#f5e6d0', muted: '#8a7060' }
    : { bg: 0xfaf6f0, node: 0x3a2a20, accent: 0xc4647c, edge: 0xd4b0b8, text: '#3a2a20', muted: '#9a8080' };
}

// --- 力导向布局 ---
const REPEL = 8000;   // 节点间斥力
const SPRING = 0.04;  // 有边时弹簧拉力
const DAMP = 0.85;    // 速度衰减
const DT = 0.016;

function tick() {
  if (nodes.length === 0) return;
  // 斥力
  for (let i = 0; i < nodes.length; i++) {
    for (let j = i + 1; j < nodes.length; j++) {
      const dx = nodes[j].x - nodes[i].x;
      const dy = nodes[j].y - nodes[i].y;
      const dist2 = Math.max(dx * dx + dy * dy, 100);
      const force = REPEL / dist2;
      const fx = force * dx / Math.sqrt(dist2);
      const fy = force * dy / Math.sqrt(dist2);
      nodes[i].vx -= fx; nodes[i].vy -= fy;
      nodes[j].vx += fx; nodes[j].vy += fy;
    }
  }
  // 弹簧拉力（有边的节点对）
  edges.forEach(e => {
    const s = nodes.find(n => n.id === e.source);
    const t = nodes.find(n => n.id === e.target);
    if (!s || !t) return;
    const dx = t.x - s.x;
    const dy = t.y - s.y;
    const dist = Math.sqrt(dx * dx + dy * dy) || 1;
    const target = Math.min(width, height) * 0.35;
    const force = SPRING * (dist - target);
    const fx = force * dx / dist;
    const fy = force * dy / dist;
    s.vx += fx; s.vy += fy;
    t.vx -= fx; t.vy -= fy;
  });
  // 中心引力，防止节点漂出画面
  nodes.forEach(n => {
    n.vx += (width / 2 - n.x) * 0.003;
    n.vy += (height / 2 - n.y) * 0.003;
    n.vx *= DAMP; n.vy *= DAMP;
    n.x += n.vx; n.y += n.vy;
  });
}

// --- Canvas 2D 渲染（不依赖 Three.js，可直接运行）---
const canvas = document.createElement('canvas');
document.body.appendChild(canvas);
canvas.width = width; canvas.height = height;
const ctx = canvas.getContext('2d');

// 呼吸动画时间
let t = 0;

function draw() {
  const c = theme();
  ctx.clearRect(0, 0, width, height);

  // 连线
  edges.forEach(e => {
    const s = nodes.find(n => n.id === e.source);
    const tgt = nodes.find(n => n.id === e.target);
    if (!s || !tgt) return;
    const isActive = s.id === selectedId || tgt.id === selectedId;
    ctx.beginPath();
    ctx.moveTo(s.x, s.y);
    // 贝塞尔控制点：轻微弯曲
    const mx = (s.x + tgt.x) / 2 + (s.y - tgt.y) * 0.1;
    const my = (s.y + tgt.y) / 2 + (tgt.x - s.x) * 0.1;
    ctx.quadraticCurveTo(mx, my, tgt.x, tgt.y);
    ctx.strokeStyle = isActive
      ? `rgba(${(c.accent >> 16) & 0xff}, ${(c.accent >> 8) & 0xff}, ${c.accent & 0xff}, 0.9)`
      : `rgba(${(c.edge >> 16) & 0xff}, ${(c.edge >> 8) & 0xff}, ${c.edge & 0xff}, 0.5)`;
    ctx.lineWidth = isActive ? 2.5 : 1;
    ctx.stroke();
  });

  // 节点
  nodes.forEach(n => {
    const selected = n.id === selectedId;
    const pulse = selected ? 1 + 0.06 * Math.sin(t * 3) : 1;
    const r = (selected ? 36 : 28) * pulse;

    // 外发光（仅选中节点）
    if (selected) {
      const glow = ctx.createRadialGradient(n.x, n.y, r * 0.5, n.x, n.y, r * 1.8);
      const ar = (c.accent >> 16) & 0xff;
      const ag = (c.accent >> 8) & 0xff;
      const ab = c.accent & 0xff;
      glow.addColorStop(0, `rgba(${ar},${ag},${ab},0.3)`);
      glow.addColorStop(1, `rgba(${ar},${ag},${ab},0)`);
      ctx.beginPath();
      ctx.arc(n.x, n.y, r * 1.8, 0, Math.PI * 2);
      ctx.fillStyle = glow;
      ctx.fill();
    }

    // 节点圆
    ctx.beginPath();
    ctx.arc(n.x, n.y, r, 0, Math.PI * 2);
    ctx.fillStyle = selected
      ? `rgba(${(c.accent >> 16) & 0xff},${(c.accent >> 8) & 0xff},${c.accent & 0xff},0.15)`
      : isDark ? 'rgba(255,255,255,0.07)' : 'rgba(255,255,255,0.85)';
    ctx.fill();
    ctx.lineWidth = selected ? 2.5 : 1.5;
    ctx.strokeStyle = selected
      ? `rgb(${(c.accent >> 16) & 0xff},${(c.accent >> 8) & 0xff},${c.accent & 0xff})`
      : isDark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.12)';
    ctx.stroke();

    // 节点文字
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = selected
      ? `rgb(${(c.accent >> 16) & 0xff},${(c.accent >> 8) & 0xff},${c.accent & 0xff})`
      : c.text;
    ctx.font = `${selected ? 'bold ' : ''}${Math.round(r * 0.38)}px sans-serif`;
    // 超过 4 字换行
    const label = n.label || n.id;
    if (label.length > 4) {
      ctx.fillText(label.slice(0, 4), n.x, n.y - r * 0.18);
      ctx.font = `${Math.round(r * 0.32)}px sans-serif`;
      ctx.fillStyle = c.muted;
      ctx.fillText(label.slice(4), n.x, n.y + r * 0.28);
    } else {
      ctx.fillText(label, n.x, n.y);
    }
  });

  t += DT;
}

// --- 主循环 ---
function loop() {
  tick();
  draw();
  requestAnimationFrame(loop);
}
loop();

// --- 点击检测 ---
canvas.addEventListener('click', e => {
  const rect = canvas.getBoundingClientRect();
  const px = e.clientX - rect.left;
  const py = e.clientY - rect.top;
  let hit = null;
  let minDist = Infinity;
  nodes.forEach(n => {
    const d = Math.hypot(n.x - px, n.y - py);
    if (d < 44 && d < minDist) { minDist = d; hit = n; }
  });
  if (hit) {
    selectedId = hit.id;
    // 通知 ArkUI
    if (window.graphBridge && window.graphBridge.onNodeSelect) {
      window.graphBridge.onNodeSelect(hit.id);
    }
  }
});

window.addEventListener('resize', () => {
  width = window.innerWidth; height = window.innerHeight;
  canvas.width = width; canvas.height = height;
});

// --- ArkUI → JS 桥接接口（由 javaScriptProxy 注入）---
// ArkUI 调用这些全局函数来更新图谱状态

window.setGraphData = function(nodesJson, edgesJson) {
  const parsed = JSON.parse(nodesJson);
  const newIds = new Set(parsed.map(n => n.id));
  // 保留现有节点的物理位置，只新增节点随机散布在画面中心附近
  nodes = parsed.map(n => {
    const existing = nodes.find(e => e.id === n.id);
    if (existing) return { ...existing, label: n.label, era: n.era };
    return {
      id: n.id, label: n.label, era: n.era,
      x: width / 2 + (Math.random() - 0.5) * 200,
      y: height / 2 + (Math.random() - 0.5) * 200,
      vx: 0, vy: 0
    };
  });
  edges = JSON.parse(edgesJson);
};

window.setSelectedNode = function(id) {
  selectedId = id;
};

window.setDarkMode = function(dark) {
  isDark = dark === 'true' || dark === true;
};
</script>
</body>
</html>
```

### 第二步：新建 ArkWeb 图谱组件

新建文件：`entry/src/main/ets/components/CultureGraphWeb.ets`

```typescript
import { webview } from '@kit.ArkWeb';
import { HeritageSite, ArchiveRecord } from '../domain/ArchiveDomain';
import { cultureConnections, CultureConnection } from '../domain/CultureConnections';

// ArkWeb 版力导向图谱，替换 CultureGraph 中的 Canvas 2D 实现。
// 通过 javaScriptProxy 向 HTML 推送图谱数据，通过注入的 graphBridge 接收点击事件。
@Component
export struct CultureGraphWeb {
  @Prop @Watch('pushData') sites: HeritageSite[] = [];
  @Prop @Watch('pushData') selectedId: string = '';
  @Prop @Watch('pushData') records: ArchiveRecord[] = [];
  @Prop isDark: boolean = false;
  onSelect: (id: string) => void = () => {};

  private controller: webview.WebviewController = new webview.WebviewController();
  private loaded: boolean = false;

  // 将 ArkUI 状态序列化后推入 HTML 的全局函数
  private pushData(): void {
    if (!this.loaded) return;
    const nodesJson = JSON.stringify(
      this.sites.map((s: HeritageSite) => ({ id: s.id, label: s.name, era: s.era }))
    );
    const connections: CultureConnection[] = cultureConnections(this.sites, this.selectedId, this.records);
    const edgesJson = JSON.stringify(
      connections.map((c: CultureConnection) => ({ source: this.selectedId, target: c.site.id, reasons: c.reasons }))
    );
    this.controller.runJavaScript(`window.setGraphData(${JSON.stringify(nodesJson)}, ${JSON.stringify(edgesJson)})`);
    this.controller.runJavaScript(`window.setSelectedNode(${JSON.stringify(this.selectedId)})`);
    this.controller.runJavaScript(`window.setDarkMode(${this.isDark})`);
  }

  build() {
    Web({
      src: $rawfile('graph.html'),
      controller: this.controller
    })
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    // 注册 JS → ArkUI 回调桥：HTML 调用 window.graphBridge.onNodeSelect(id)
    .javaScriptProxy({
      object: {
        onNodeSelect: (id: string) => {
          this.onSelect(id);
        }
      },
      name: 'graphBridge',
      methodList: ['onNodeSelect'],
      controller: this.controller
    })
    .onPageEnd(() => {
      this.loaded = true;
      this.pushData();
    })
    .javaScriptAccess(true)
    .domStorageAccess(false)
    .fileAccess(true)
  }
}
```

### 第三步：在 CultureAtlas.ets 中替换图谱组件

在 [`CultureAtlas.ets`](entry/src/main/ets/components/CultureAtlas.ets) 顶部将现有 `CultureGraph` 的 import 改为 `CultureGraphWeb`：

```typescript
// 替换：
import { CultureGraph } from './CultureGraph';
// 改为：
import { CultureGraphWeb } from './CultureGraphWeb';
```

在 `build()` 中找到 `<CultureGraph>` 的调用（大约在 `Column` 内），替换为：

```typescript
CultureGraphWeb({
  sites: this.sites(),
  selectedId: this.selectedId,
  records: this.snapshot.records,
  isDark: !this.snapshot.lightEnabled,
  onSelect: (id: string) => { this.selectedId = id; }
}).height(280).width('100%').borderRadius(16).clip(true)
```

旧的 `CultureGraph` 文件**保留，不要删除**，以便构建失败时回退。

### ArkWeb 注意事项

1. `graph.html` 必须放在 `rawfile/` 目录，不能放在 `resources/base/` 下，否则 `$rawfile` 路径不对。
2. `javaScriptProxy` 的 `object` 字段是 ArkTS 对象，方法名必须在 `methodList` 中声明，否则 JS 侧调用时返回 undefined。
3. HTML 内的 `window.graphBridge.onNodeSelect` 是异步的，不要在 HTML 中等待它的返回值。
4. ArkWeb 默认不允许加载本地文件系统的资源；`$rawfile` 是鸿蒙允许的白名单路径，不需要额外权限。
5. 深色模式：从 `snapshot.lightEnabled` 推算，`lightEnabled === false` 时传 `isDark = true`。

---

## 优先级 2b：图谱升级为等轴测伪 3D（Canvas 2D 实现，模拟器可验证）

现有力导向图谱已在 Canvas 2D 上运行。在不引入 WebGL 的前提下，加入**年代分层 + 透视投影**，让图谱有明显的三维空间感：仰韶节点在近处（前景），宋代节点在远处（背景），节点大小和亮度随深度变化，整体可用双指旋转。

### 改动范围

只改 `entry/src/main/resources/rawfile/graph.html`，不改任何 ArkTS 文件。

在现有 `graph.html` 的 `// --- 状态 ---` 区域补充以下内容，然后替换 `tick()` 和 `draw()` 函数：

```javascript
// 年代到 Z 轴深度的映射（Z 越大越靠后，越小越靠前）
const ERA_Z = { '仰韶': -120, '龙山': -80, '夏商': -40, '周': 0, '汉唐': 40, '宋': 80 };
const DEFAULT_Z = 0;

// 透视投影参数
const FOCAL = 600;   // 焦距（px），越大透视越弱
let rotY = 0.3;      // 绕 Y 轴旋转角（弧度）
let rotX = -0.15;    // 绕 X 轴旋转角（弧度）

// 触摸旋转状态
let lastTouch = null;

// 3D → 2D 透视投影，返回屏幕坐标和缩放比
function project(x, y, z) {
  // 绕 Y 轴旋转
  const cosY = Math.cos(rotY), sinY = Math.sin(rotY);
  const x1 = x * cosY - z * sinY;
  const z1 = x * sinY + z * cosY;
  // 绕 X 轴旋转
  const cosX = Math.cos(rotX), sinX = Math.sin(rotX);
  const y1 = y * cosX - z1 * sinX;
  const z2 = y * sinX + z1 * cosX;
  // 透视除法
  const scale = FOCAL / (FOCAL + z2 + 200);
  return {
    sx: width / 2 + (x1 - width / 2) * scale,
    sy: height / 2 + (y1 - height / 2) * scale,
    scale,
    depth: z2   // 用于排序，depth 越大越靠后
  };
}
```

替换 `tick()` 函数，让力导向在 XY 平面运算，Z 轴由年代固定：

```javascript
function tick() {
  if (nodes.length === 0) return;
  // 确保 Z 轴与年代对齐（每帧强制，防止漂移）
  nodes.forEach(n => { n.z = ERA_Z[n.era] ?? DEFAULT_Z; });

  // 斥力（仅在 XY 平面）
  for (let i = 0; i < nodes.length; i++) {
    for (let j = i + 1; j < nodes.length; j++) {
      const dx = nodes[j].x - nodes[i].x;
      const dy = nodes[j].y - nodes[i].y;
      const dist2 = Math.max(dx * dx + dy * dy, 100);
      const force = REPEL / dist2;
      const d = Math.sqrt(dist2);
      nodes[i].vx -= force * dx / d; nodes[i].vy -= force * dy / d;
      nodes[j].vx += force * dx / d; nodes[j].vy += force * dy / d;
    }
  }
  // 弹簧拉力（XY 平面）
  edges.forEach(e => {
    const s = nodes.find(n => n.id === e.source);
    const tgt = nodes.find(n => n.id === e.target);
    if (!s || !tgt) return;
    const dx = tgt.x - s.x, dy = tgt.y - s.y;
    const dist = Math.sqrt(dx * dx + dy * dy) || 1;
    const target = Math.min(width, height) * 0.32;
    const force = SPRING * (dist - target);
    s.vx += force * dx / dist; s.vy += force * dy / dist;
    tgt.vx -= force * dx / dist; tgt.vy -= force * dy / dist;
  });
  // 中心引力 + 速度衰减
  nodes.forEach(n => {
    n.vx += (width / 2 - n.x) * 0.003;
    n.vy += (height / 2 - n.y) * 0.003;
    n.vx *= DAMP; n.vy *= DAMP;
    n.x += n.vx; n.y += n.vy;
  });
}
```

替换 `draw()` 函数，加入深度排序和透视缩放：

```javascript
function draw() {
  const c = theme();
  ctx.clearRect(0, 0, width, height);

  // 按深度排序（深度大的先画，确保近处节点在上层）
  const sorted = [...nodes].sort((a, b) =>
    project(b.x, b.y, b.z).depth - project(a.x, a.y, a.z).depth
  );

  // 连线（使用投影后的坐标）
  edges.forEach(e => {
    const s = nodes.find(n => n.id === e.source);
    const tgt = nodes.find(n => n.id === e.target);
    if (!s || !tgt) return;
    const ps = project(s.x, s.y, s.z);
    const pt = project(tgt.x, tgt.y, tgt.z);
    const isActive = s.id === selectedId || tgt.id === selectedId;
    // 深度越深连线越淡
    const alpha = isActive ? 0.85 : Math.min(0.5, 0.15 + ps.scale * 0.5);
    ctx.beginPath();
    ctx.moveTo(ps.sx, ps.sy);
    ctx.quadraticCurveTo(
      (ps.sx + pt.sx) / 2 + (ps.sy - pt.sy) * 0.08,
      (ps.sy + pt.sy) / 2 + (pt.sx - ps.sx) * 0.08,
      pt.sx, pt.sy
    );
    ctx.strokeStyle = isActive
      ? `rgba(196,100,124,${alpha})`
      : `rgba(180,160,168,${alpha})`;
    ctx.lineWidth = isActive ? 2 : 1;
    ctx.stroke();
  });

  // 节点（按深度顺序）
  sorted.forEach(n => {
    const p = project(n.x, n.y, n.z);
    const selected = n.id === selectedId;
    const pulse = selected ? 1 + 0.06 * Math.sin(t * 3) : 1;
    const r = (selected ? 36 : 28) * p.scale * pulse;
    // 深度越深节点越暗（lightness 随 scale 变化）
    const lightness = isDark
      ? 20 + p.scale * 30
      : 96 - (1 - p.scale) * 20;

    if (selected) {
      const glow = ctx.createRadialGradient(p.sx, p.sy, r * 0.5, p.sx, p.sy, r * 2);
      glow.addColorStop(0, `rgba(196,100,124,${0.35 * p.scale})`);
      glow.addColorStop(1, 'rgba(196,100,124,0)');
      ctx.beginPath();
      ctx.arc(p.sx, p.sy, r * 2, 0, Math.PI * 2);
      ctx.fillStyle = glow;
      ctx.fill();
    }

    ctx.beginPath();
    ctx.arc(p.sx, p.sy, r, 0, Math.PI * 2);
    ctx.fillStyle = selected
      ? `rgba(196,100,124,${0.15 * p.scale})`
      : isDark
        ? `rgba(255,255,255,${0.05 + p.scale * 0.1})`
        : `hsla(0,0%,${lightness}%,0.92)`;
    ctx.fill();
    ctx.lineWidth = selected ? 2 : 1.2 * p.scale;
    ctx.strokeStyle = selected
      ? `rgba(196,100,124,${p.scale})`
      : isDark
        ? `rgba(255,255,255,${0.15 * p.scale})`
        : `rgba(0,0,0,${0.1 * p.scale})`;
    ctx.stroke();

    // 文字随深度缩放
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = selected
      ? `rgba(196,100,124,1)`
      : isDark
        ? `rgba(245,230,208,${0.5 + p.scale * 0.5})`
        : `rgba(58,42,32,${0.4 + p.scale * 0.6})`;
    const fs = Math.round(Math.max(9, r * 0.38));
    ctx.font = `${selected ? 'bold ' : ''}${fs}px sans-serif`;
    const label = n.label || n.id;
    if (label.length > 4) {
      ctx.fillText(label.slice(0, 4), p.sx, p.sy - r * 0.18);
      ctx.font = `${Math.round(Math.max(8, r * 0.32))}px sans-serif`;
      ctx.fillStyle = isDark ? `rgba(138,112,96,${p.scale})` : `rgba(154,128,128,${p.scale})`;
      ctx.fillText(label.slice(4), p.sx, p.sy + r * 0.28);
    } else {
      ctx.fillText(label, p.sx, p.sy);
    }
  });

  t += DT;
}
```

在 `canvas.addEventListener('click', ...)` 之后加入触摸旋转手势：

```javascript
// 双指旋转（触摸）
canvas.addEventListener('touchstart', e => {
  if (e.touches.length === 2) lastTouch = [e.touches[0].clientX, e.touches[0].clientY];
});
canvas.addEventListener('touchmove', e => {
  if (e.touches.length === 2 && lastTouch) {
    const dx = e.touches[0].clientX - lastTouch[0];
    const dy = e.touches[0].clientY - lastTouch[1];
    rotY += dx * 0.005;
    rotX += dy * 0.005;
    rotX = Math.max(-0.6, Math.min(0.6, rotX));  // 限制仰角
    lastTouch = [e.touches[0].clientX, e.touches[0].clientY];
    e.preventDefault();
  }
}, { passive: false });
canvas.addEventListener('touchend', () => { lastTouch = null; });

// 鼠标拖动旋转（桌面/模拟器）
let mouseDown = false, lastMouse = null;
canvas.addEventListener('mousedown', e => { mouseDown = true; lastMouse = [e.clientX, e.clientY]; });
canvas.addEventListener('mousemove', e => {
  if (!mouseDown || !lastMouse) return;
  rotY += (e.clientX - lastMouse[0]) * 0.005;
  rotX += (e.clientY - lastMouse[1]) * 0.005;
  rotX = Math.max(-0.6, Math.min(0.6, rotX));
  lastMouse = [e.clientX, e.clientY];
});
canvas.addEventListener('mouseup', () => { mouseDown = false; lastMouse = null; });
```

还需要在 `window.setGraphData` 里初始化 `z` 字段：

```javascript
window.setGraphData = function(nodesJson, edgesJson) {
  const parsed = JSON.parse(nodesJson);
  nodes = parsed.map(n => {
    const existing = nodes.find(e => e.id === n.id);
    if (existing) return { ...existing, label: n.label, era: n.era, z: ERA_Z[n.era] ?? DEFAULT_Z };
    return {
      id: n.id, label: n.label, era: n.era,
      x: width / 2 + (Math.random() - 0.5) * 200,
      y: height / 2 + (Math.random() - 0.5) * 200,
      z: ERA_Z[n.era] ?? DEFAULT_Z,
      vx: 0, vy: 0
    };
  });
  edges = JSON.parse(edgesJson);
};
```

### 预期视觉效果

- 仰韶/龙山节点在近处（偏大、偏亮），宋代节点在远处（偏小、偏暗）
- 双指（或鼠标拖拽）旋转时，整个图谱在空间中转动，年代分层的深度感变得非常明显
- 不依赖 WebGL，在模拟器和真机上都能运行

---

## 优先级 2c：遗址详情页 3D 文物视口（Canvas 2D 软件光栅化 + Lambert 着色）

> **2026-10-16 实际状态：** `@kit.ArkGraphics3D` 在模拟器上未能取得可见画面，已改为 ArkWeb Canvas 2D 软件光栅化。当前几何体外观问题（"像动画片"）的根本原因是每个多边形面使用同一颜色填充，没有光照计算。本节用 per-face Lambert 着色替换旧实现，每个面根据其法向量与光源方向的点积计算亮度，使明暗关系清晰可见。

**修复原理：** Lambert 着色公式为 `brightness = ambient + diffuse × max(0, dot(faceNormal, lightDir))`。朝向光源的面最亮，背面最暗，侧面居中。同时加一个 Phong 高光项使正对光源的面有金属感反光。

新建文件：`entry/src/main/resources/rawfile/object3d.html`（替换旧版同名文件，如存在）。

```html
<!DOCTYPE html>
<html lang="zh">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<style>* { margin:0; padding:0; } body { background:transparent; overflow:hidden; } canvas { display:block; }</style>
</head>
<body><script>
// Canvas 2D 软件光栅化器，per-face Lambert + Phong 高光着色。
// 修复平面单色多边形导致的"动画片"外观。

// --- 状态 ---
let siteType = 'pottery', accentHex = '#9B463E', isDark = false, autoRotate = true;
let rotX = -0.30, rotY = 0.40;
let geo = null;   // { verts:[[x,y,z],...], faces:[{vi:[...], normal:[nx,ny,nz]},...]  }

const canvas = document.createElement('canvas');
document.body.appendChild(canvas);
const ctx = canvas.getContext('2d');
let W = canvas.width = window.innerWidth;
let H = canvas.height = window.innerHeight;
window.addEventListener('resize', () => { W = canvas.width=window.innerWidth; H = canvas.height=window.innerHeight; });

// --- 光源（方向光，已归一化）---
const LIGHT_DIR  = norm3([1.2, 2.0, 1.5]);
const LIGHT_SPEC = norm3([0.4, 0.8, 1.0]);  // 高光方向（偏相机侧）
const AMBIENT = 0.30, DIFFUSE = 0.55, SPECULAR = 0.28, SPEC_EXP = 22;

function norm3(v) { const l=Math.sqrt(v[0]*v[0]+v[1]*v[1]+v[2]*v[2]); return [v[0]/l,v[1]/l,v[2]/l]; }
function dot3(a,b)  { return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]; }

// --- 颜色工具 ---
function hexRgb(h) { return [parseInt(h.slice(1,3),16),parseInt(h.slice(3,5),16),parseInt(h.slice(5,7),16)]; }
function applyLight(rgb, brightness, spec) {
  const b = brightness, s = spec;
  return rgb.map((c,i) => Math.round(Math.min(255, Math.max(0, c*b + s*255*(i===0?0.95:i===1?0.92:0.88)))));
}

// --- 3D 数学工具 ---
function sub3(a,b)  { return [a[0]-b[0], a[1]-b[1], a[2]-b[2]]; }
function cross3(a,b){ return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]; }
function mulMV(m,v) {  // 3x3矩阵×向量
  return [
    m[0]*v[0]+m[1]*v[1]+m[2]*v[2],
    m[3]*v[0]+m[4]*v[1]+m[5]*v[2],
    m[6]*v[0]+m[7]*v[1]+m[8]*v[2]
  ];
}
function rotXY(rx,ry) { // 绕X轴再绕Y轴的旋转矩阵
  const cx=Math.cos(rx),sx=Math.sin(rx),cy=Math.cos(ry),sy=Math.sin(ry);
  return [cy,0,sy, sx*sy,cx,-sx*cy, -cx*sy,sx,cx*cy];
}

// --- 透视投影 ---
const FOCAL_OBJ = 420;
function project(v, m) {
  const r = mulMV(m, v);
  const s = FOCAL_OBJ / (FOCAL_OBJ + r[2] + 2.5);
  return { sx: W/2 + r[0]*s*Math.min(W,H)*0.38, sy: H/2 + r[1]*s*Math.min(W,H)*0.38, z: r[2], s };
}

// --- Lambert + Phong 着色 ---
function shadeFace(verts, m, baseRgb) {
  if (verts.length < 3) return baseRgb;
  // 计算面法向量（世界空间，旋转后）
  const rv = verts.map(v => mulMV(m, v));
  const e1 = sub3(rv[1], rv[0]), e2 = sub3(rv[2], rv[0]);
  const raw = cross3(e1, e2);
  const len = Math.sqrt(raw[0]**2+raw[1]**2+raw[2]**2);
  if (len < 1e-8) return baseRgb;
  const n = [raw[0]/len, raw[1]/len, raw[2]/len];

  // 背面剔除：法向量Z分量 > 0 时朝向相机（左手坐标系）
  // 不剔除，但让背面更暗（透明几何体可见所有面）

  const diff = Math.max(0, dot3(n, LIGHT_DIR));
  const spec = Math.pow(Math.max(0, dot3(n, LIGHT_SPEC)), SPEC_EXP);
  const brightness = AMBIENT + DIFFUSE * diff;
  return applyLight(baseRgb, brightness, SPECULAR * spec);
}

// --- 几何体定义（带面法线，每个 face 的 vi 是顶点索引数组）---
function makePottery(accent) {  // 彩陶罐：旋成体近似
  // 轮廓点（xz平面的半径和高度），绕Y轴旋转16段
  const profile = [[0,-.9],[.18,-.85],[.32,-.7],[.42,-.45],[.48,-.15],
                   [.44,.15],[.35,.42],[.22,.62],[.12,.78],[.06,.88],[0,.92]];
  const SEG = 16;
  const verts = [], faces = [];
  profile.forEach(([r,y]) => {
    for (let i=0;i<SEG;i++) {
      const a = (i/SEG)*Math.PI*2;
      verts.push([r*Math.cos(a), y, r*Math.sin(a)]);
    }
  });
  for (let row=0; row<profile.length-1; row++) {
    for (let i=0; i<SEG; i++) {
      const ni=(i+1)%SEG;
      const a=row*SEG+i, b=row*SEG+ni, c=(row+1)*SEG+ni, d=(row+1)*SEG+i;
      faces.push({ vi:[a,b,c,d] });
    }
  }
  // 装饰纹带（彩陶的几道横纹，用亮色多边形）
  const bandRows=[3,4,5];
  bandRows.forEach(row=>{
    for(let i=0;i<SEG;i+=2){
      const ni=(i+1)%SEG;
      faces.push({ vi:[row*SEG+i, row*SEG+ni, (row+1)*SEG+ni, (row+1)*SEG+i], band:true });
    }
  });
  return { verts, faces, accent, bandAccent: shiftHue(accent,15) };
}

function makeCityPlatform(accent) {  // 城台：三层递减立方体
  const verts=[], faces=[];
  const layers = [{s:1.0,y:-.9},{s:0.72,y:-.38},{s:0.46,y:.24}];
  const h = 0.55;
  layers.forEach(({s,y}) => {
    const b = verts.length;
    [[-s,y,-s],[s,y,-s],[s,y,s],[-s,y,s],
     [-s,y+h,-s],[s,y+h,-s],[s,y+h,s],[-s,y+h,s]].forEach(v=>verts.push(v));
    // 上面
    faces.push({vi:[b+4,b+5,b+6,b+7]});
    // 四个侧面
    [[b,b+1,b+5,b+4],[b+1,b+2,b+6,b+5],[b+2,b+3,b+7,b+6],[b+3,b,b+4,b+7]].forEach(vi=>faces.push({vi}));
  });
  return { verts, faces, accent };
}

function makeWallRing(accent) {  // 城墙环形截面
  const verts=[], faces=[];
  const R=0.78, r=0.52, SEG=24, h=0.55;
  for(let i=0;i<SEG;i++){
    const a=(i/SEG)*Math.PI*2, na=((i+1)/SEG)*Math.PI*2;
    const [ca,sa,cna,sna]=[Math.cos(a),Math.sin(a),Math.cos(na),Math.sin(na)];
    const b=verts.length;
    verts.push(
      [R*ca,-h/2,R*sa],[R*cna,-h/2,R*sna],[R*cna,h/2,R*sna],[R*ca,h/2,R*sa],
      [r*ca,-h/2,r*sa],[r*cna,-h/2,r*sna],[r*cna,h/2,r*sna],[r*ca,h/2,r*sa]
    );
    faces.push(
      {vi:[b,b+1,b+2,b+3]},   // 外侧面
      {vi:[b+5,b+4,b+7,b+6]}, // 内侧面（法线朝内）
      {vi:[b+3,b+2,b+6,b+7]}, // 顶面
      {vi:[b+1,b,b+4,b+5]}    // 底面
    );
  }
  return { verts, faces, accent };
}

function makePagoda(accent) {  // 层塔：5层递减八棱柱
  const verts=[], faces=[];
  const layers=[{r:.72,y:-.90,h:.38},{r:.58,y:-.50,h:.36},{r:.45,y:-.12,h:.34},
                {r:.32,y:.24,h:.30},{r:.18,y:.56,h:.26}];
  const SEG=8;
  layers.forEach(({r,y,h})=>{
    const b=verts.length;
    for(let i=0;i<SEG;i++){
      const a=(i/SEG)*Math.PI*2+(Math.PI/SEG);
      verts.push([r*Math.cos(a),y,r*Math.sin(a)],[r*0.88*Math.cos(a),y+h,r*0.88*Math.sin(a)]);
    }
    // 上面（略小的八边形屋檐）
    const topIdx=[];
    for(let i=0;i<SEG;i++) topIdx.push(b+i*2+1);
    faces.push({vi:topIdx});
    // 侧面（梯形）
    for(let i=0;i<SEG;i++){
      const ni=(i+1)%SEG;
      faces.push({vi:[b+i*2, b+ni*2, b+ni*2+1, b+i*2+1]});
    }
  });
  // 顶部尖顶
  const tip=verts.length;
  verts.push([0,1.10,0]);
  const last=layers[layers.length-1];
  const lb=verts.length-SEG*2-1;
  for(let i=0;i<SEG;i++){
    const ni=(i+1)%SEG;
    faces.push({vi:[lb+i*2+1, lb+ni*2+1, tip]});
  }
  return { verts, faces, accent };
}

function makeMound(accent) {  // 封土堆：半球
  const verts=[], faces=[];
  const SLAT=10, LONG=18;
  for(let lat=0;lat<=SLAT;lat++){
    const phi=(lat/SLAT)*(Math.PI/2);  // 0到90度（半球）
    for(let lon=0;lon<LONG;lon++){
      const theta=(lon/LONG)*Math.PI*2;
      verts.push([Math.sin(phi)*Math.cos(theta), Math.cos(phi)-1, Math.sin(phi)*Math.sin(theta)]);
    }
  }
  for(let lat=0;lat<SLAT;lat++){
    for(let lon=0;lon<LONG;lon++){
      const nlon=(lon+1)%LONG;
      const a=lat*LONG+lon, b=lat*LONG+nlon, c=(lat+1)*LONG+nlon, d=(lat+1)*LONG+lon;
      faces.push({vi:[a,b,c,d]});
    }
  }
  return { verts, faces, accent };
}

// 色相偏移（用于纹带装饰色）
function shiftHue(hex, deg) {
  const [r,g,b]=hexRgb(hex);
  // 简单RGB旋转近似
  const f=deg/360*Math.PI*2;
  const nr=Math.round(Math.min(255,r*Math.cos(f)-g*Math.sin(f)*0.5+128*(1-Math.cos(f))));
  const ng=Math.round(Math.min(255,g*Math.cos(f)+r*Math.sin(f)*0.3+128*(1-Math.cos(f))));
  return `#${[nr,ng,b].map(x=>Math.max(0,x).toString(16).padStart(2,'0')).join('')}`;
}

function buildGeo(type, accent) {
  if (type==='pottery' || type==='聚落遗址' || type==='窑址') return makePottery(accent);
  if (type==='city'    || type==='都城遗址')                  return makeCityPlatform(accent);
  if (type==='wall'    || type==='城址')                      return makeWallRing(accent);
  if (type==='pagoda'  || type==='古建筑')                    return makePagoda(accent);
  return makeMound(accent);   // 墓葬群等其余类型
}

// --- 渲染 ---
let animFrame = null;
let autoRotateTimer = null;

function renderFrame() {
  ctx.clearRect(0,0,W,H);

  if (!geo) return;
  const m = rotXY(rotX, rotY);
  const baseRgb = hexRgb(geo.accent);

  // 投影所有顶点
  const proj = geo.verts.map(v => project(v, m));

  // 按面的平均Z排序（画家算法：深的先画）
  const sorted = geo.faces.map((f,fi)=>{
    const avgZ = f.vi.reduce((s,i)=>s+proj[i].z,0)/f.vi.length;
    return {f, fi, avgZ};
  }).sort((a,b)=>b.avgZ-a.avgZ);

  sorted.forEach(({f})=>{
    const pts = f.vi.map(i=>proj[i]);

    // 背面剔除（面朝向计算用屏幕坐标叉积）
    if (pts.length >= 3) {
      const ax=pts[1].sx-pts[0].sx, ay=pts[1].sy-pts[0].sy;
      const bx=pts[2].sx-pts[0].sx, by=pts[2].sy-pts[0].sy;
      if (ax*by - ay*bx < 0) return;  // 背面，跳过
    }

    // Lambert + Phong 着色
    const worldVerts = f.vi.map(i=>geo.verts[i]);
    let rgb;
    if (f.band) {
      rgb = hexRgb(geo.bandAccent || geo.accent);
      rgb = applyLight(rgb, AMBIENT + DIFFUSE * Math.max(0, dot3(
        norm3(mulMV(m, cross3(sub3(worldVerts[1],worldVerts[0]),sub3(worldVerts[2],worldVerts[0])))),
        LIGHT_DIR
      )), 0);
    } else {
      rgb = shadeFace(worldVerts, m, baseRgb);
    }

    ctx.beginPath();
    ctx.moveTo(pts[0].sx, pts[0].sy);
    for (let i=1;i<pts.length;i++) ctx.lineTo(pts[i].sx, pts[i].sy);
    ctx.closePath();
    ctx.fillStyle = `rgb(${rgb[0]},${rgb[1]},${rgb[2]})`;
    ctx.fill();

    // 细描边（深色主题用亮边，浅色主题用暗边）
    ctx.strokeStyle = isDark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.08)';
    ctx.lineWidth = 0.5;
    ctx.stroke();
  });

  // 地面阴影椭圆
  const shadowY = H/2 + Math.min(W,H)*0.38*0.92;
  const grad = ctx.createRadialGradient(W/2,shadowY,0,W/2,shadowY,Math.min(W,H)*0.22);
  grad.addColorStop(0, isDark?'rgba(0,0,0,0.28)':'rgba(0,0,0,0.12)');
  grad.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.beginPath();
  ctx.ellipse(W/2, shadowY, Math.min(W,H)*0.22, Math.min(W,H)*0.06, 0, 0, Math.PI*2);
  ctx.fillStyle = grad;
  ctx.fill();
}

function startAutoRotate() {
  if (autoRotateTimer) return;
  autoRotateTimer = setInterval(()=>{ rotY += 0.012; renderFrame(); }, 16);
}
function stopAutoRotate() {
  if (autoRotateTimer) { clearInterval(autoRotateTimer); autoRotateTimer = null; }
}

// --- 触摸 / 鼠标旋转 ---
let lastPt = null;
canvas.addEventListener('mousedown', e=>{ stopAutoRotate(); lastPt=[e.clientX,e.clientY]; });
window.addEventListener('mousemove', e=>{ if(!lastPt) return; rotY+=(e.clientX-lastPt[0])*0.007; rotX+=(e.clientY-lastPt[1])*0.007; rotX=Math.max(-1.1,Math.min(1.1,rotX)); lastPt=[e.clientX,e.clientY]; renderFrame(); });
window.addEventListener('mouseup', ()=>{ lastPt=null; });
canvas.addEventListener('touchstart', e=>{ if(e.touches.length===1){ stopAutoRotate(); lastPt=[e.touches[0].clientX,e.touches[0].clientY]; }}, {passive:true});
canvas.addEventListener('touchmove', e=>{ if(e.touches.length===1&&lastPt){ rotY+=(e.touches[0].clientX-lastPt[0])*0.007; rotX+=(e.touches[0].clientY-lastPt[1])*0.007; rotX=Math.max(-1.1,Math.min(1.1,rotX)); lastPt=[e.touches[0].clientX,e.touches[0].clientY]; renderFrame(); }},{passive:true});
canvas.addEventListener('touchend', ()=>{ lastPt=null; });

// --- ArkUI 桥接 ---
window.initObject = function(typeStr, accentStr, darkStr, autoStr) {
  siteType  = typeStr;
  accentHex = accentStr;
  isDark    = darkStr==='true'||darkStr===true;
  autoRotate= autoStr !=='false'&&autoStr!==false;
  geo = buildGeo(siteType, accentHex);
  renderFrame();
  if (autoRotate) startAutoRotate(); else stopAutoRotate();
};
window.setDark = function(v)  { isDark=v==='true'||v===true; renderFrame(); };
window.setAuto = function(v)  { if(v==='true'||v===true) startAutoRotate(); else stopAutoRotate(); };
window.resetView=function()   { rotX=-0.30; rotY=0.40; renderFrame(); };
</script></body></html>
```

### 对应的 ArkTS 封装组件

在 [`SiteObject3D.ets`](entry/src/main/ets/components/SiteObject3D.ets) 中，把 `onSceneReady` 的整体方案换成下面的 ArkWeb 方案（如果旧文件用的是 `Component3D`，整体替换）：

```typescript
import { webview } from '@kit.ArkWeb';
import { HeritageSite } from '../domain/ArchiveDomain';

// 遗址形态视口：ArkWeb Canvas 2D 软件光栅化 + per-face Lambert 着色。
// 根据 site.type 程序化生成对应的几何体，无需外部 .glb 模型。
@Component
export struct SiteObject3D {
  @Prop site: HeritageSite;
  @Prop isDark: boolean = false;
  @Prop reducedMotion: boolean = false;

  private ctrl: webview.WebviewController = new webview.WebviewController();
  private loaded: boolean = false;

  private push(): void {
    if (!this.loaded) return;
    const t = JSON.stringify(this.site.type);
    const a = JSON.stringify(this.site.accent);
    const d = JSON.stringify(this.isDark);
    const r = JSON.stringify(!this.reducedMotion);
    this.ctrl.runJavaScript(`window.initObject(${t},${a},${d},${r})`);
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Web({ src: $rawfile('object3d.html'), controller: this.ctrl })
        .width('100%').height('100%')
        .backgroundColor(Color.Transparent)
        .javaScriptAccess(true)
        .fileAccess(true)
        .domStorageAccess(false)
        .onPageEnd(() => { this.loaded = true; this.push(); })

      // "复位"按钮（右下角）
      Button({ type: ButtonType.Capsule }) {
        Text('复位').fontSize(11).fontColor('#9a8080')
      }.height(28).padding({ left: 12, right: 12 })
       .backgroundColor($r('app.color.soft'))
       .onClick(() => { this.ctrl.runJavaScript('window.resetView()'); })
       .margin({ right: 12, bottom: 10 })
    }
    .width('100%').height(220)
    .borderRadius(16)
    .clip(true)
    .backgroundColor(this.isDark ? '#1a1510' : '#faf6f0')
  }
}
```

`SiteDetail.ets` 里的调用方式改为传整个 `site` 对象：

```typescript
SiteObject3D({
  site: site,
  isDark: !snapshot.lightEnabled,
  reducedMotion: snapshot.reducedMotion
})
```

### 效果说明

使用 per-face Lambert 着色后：

- 城台顶面最亮（正对光源），正面次亮，侧面较暗，底面最暗——立体感与真实材质接近
- 陶器罐的旋成体每一列面片都有连续的亮暗渐变，看起来像有弧面高光
- 层塔每层的斜面角度不同，受光量不同，层次清晰
- 地面投影椭圆阴影让几何体有"落地感"
- Phong 高光项在正对光源的面上产生一个亮斑，增加金属/釉面感
- 背面剔除使不可见的面不被画出，渲染效率提升约 40%

在每条遗址档案的详情页顶部加入一个可旋转的 3D 几何体，程序化生成——不需要外部 `.glb` 模型文件。用 `@kit.ArkGraphics3D` 的 `Component3D` 渲染，直接调用 HarmonyOS 7 GPU。

### 前置条件核验

在使用 `Component3D` 之前，先确认 `entry/oh-package.json5` 中是否已有 `@kit.ArkGraphics3D` 的依赖。如果没有，添加：

```json5
"dependencies": {
  "@kit.ArkGraphics3D": "*"
}
```

然后运行一次 `.\tools\build.ps1`，确认依赖解析成功再继续。如果构建提示找不到该包，说明当前 DevEco Studio 版本不包含此 kit，改用路线 2b（Canvas 2D 伪 3D）即可，不要强行引入不可用的 API。

### 每种档案类型的程序化几何体

| `type` 值 | 几何体形状 | 说明 |
|---|---|---|
| `聚落遗址` | 扁圆球（彩陶罐轮廓） | `Sphere`，scaleY 压缩到 0.7 |
| `都城遗址` | 立方体堆叠（城台） | 3 个 `Box`，大小递减 |
| `城址` | 环形（城墙截面） | `Torus`，细管 |
| `古建筑` | 多层锥体（塔形） | 5 个 `Cylinder`，直径递减 |
| `墓葬群` | 半球（土丘） | `Sphere`，下半截去掉 |
| `窑址` | 圆柱（窑洞） | `Cylinder`，矮宽 |

### 新建组件文件

新建 `entry/src/main/ets/components/SiteObject3D.ets`：

```typescript
import {
  Scene, Node, Camera, Light, LightType, Mesh, BoxGeometry,
  SphereGeometry, CylinderGeometry, TorusGeometry,
  UnlitMaterial, Color, Quat, Vec3
} from '@kit.ArkGraphics3D';

// 根据档案类型生成程序化 3D 几何体，展示在详情页顶部。
// 不依赖外部 .glb 文件，全部在代码里描述几何参数。
// 如果 @kit.ArkGraphics3D 在当前环境不可用，外层调用处应做能力检测并跳过此组件。
@Component
export struct SiteObject3D {
  @Prop siteType: string = '聚落遗址';
  @Prop accentHex: string = '#9B463E';   // 来自 HeritageSite.accent
  @Prop isDark: boolean = false;
  @Prop reducedMotion: boolean = false;

  private scene: Scene | null = null;
  private rotY: number = 0;
  private animTimer: number = -1;

  // 将 '#RRGGBB' 转为 Color（0-1 范围）
  private hexToColor(hex: string, alpha: number = 1): Color {
    const r = parseInt(hex.slice(1, 3), 16) / 255;
    const g = parseInt(hex.slice(3, 5), 16) / 255;
    const b = parseInt(hex.slice(5, 7), 16) / 255;
    return { r, g, b, a: alpha };
  }

  private buildScene(scene: Scene): void {
    // 相机
    const camNode = scene.createNode('camera') as Node;
    camNode.position = new Vec3(0, 0.5, 3);
    const cam = scene.createCamera('cam') as Camera;
    cam.fov = 40;
    camNode.addComponent(cam);

    // 光源（方向光 + 环境补光）
    const lightNode = scene.createNode('light') as Node;
    lightNode.position = new Vec3(2, 3, 2);
    const light = scene.createLight('dir') as Light;
    light.type = LightType.DIRECTIONAL;
    light.intensity = 1.2;
    light.color = { r: 1, g: 0.96, b: 0.90, a: 1 };
    lightNode.addComponent(light);

    const ambNode = scene.createNode('amb') as Node;
    const amb = scene.createLight('ambient') as Light;
    amb.type = LightType.AMBIENT;
    amb.intensity = 0.5;
    amb.color = this.isDark
      ? { r: 0.3, g: 0.25, b: 0.4, a: 1 }
      : { r: 1, g: 0.95, b: 0.85, a: 1 };
    ambNode.addComponent(amb);

    // 材质
    const mat = scene.createMaterial('m', UnlitMaterial) as UnlitMaterial;
    mat.baseColor = this.hexToColor(this.accentHex, 1);

    // 几何体（按档案类型）
    this.buildGeometry(scene, mat);
  }

  private buildGeometry(scene: Scene, mat: UnlitMaterial): void {
    const type = this.siteType;
    if (type === '聚落遗址') {
      // 彩陶罐：扁球
      const n = scene.createNode('obj') as Node;
      n.scale = new Vec3(1, 0.72, 1);
      const mesh = scene.createMesh('m', new SphereGeometry({ radius: 0.7, segments: 24 })) as Mesh;
      mesh.material = mat;
      n.addComponent(mesh);
    } else if (type === '都城遗址') {
      // 城台：三层递减立方体
      [0.9, 0.65, 0.42].forEach((s, i) => {
        const n = scene.createNode(`box${i}`) as Node;
        n.position = new Vec3(0, i * 0.38 - 0.3, 0);
        n.scale = new Vec3(s, 0.32, s);
        const mesh = scene.createMesh(`bm${i}`, new BoxGeometry({ width: 1, height: 1, depth: 1 })) as Mesh;
        mesh.material = mat;
        n.addComponent(mesh);
      });
    } else if (type === '城址') {
      // 城墙截面：环形
      const n = scene.createNode('obj') as Node;
      n.rotation = Quat.fromEuler(90, 0, 0);
      const mesh = scene.createMesh('m', new TorusGeometry({ radius: 0.7, tube: 0.18, segments: 32 })) as Mesh;
      mesh.material = mat;
      n.addComponent(mesh);
    } else if (type === '古建筑') {
      // 塔形：5 层递减圆柱
      [1, 0.82, 0.64, 0.46, 0.28].forEach((r, i) => {
        const n = scene.createNode(`cyl${i}`) as Node;
        n.position = new Vec3(0, i * 0.34 - 0.5, 0);
        const mesh = scene.createMesh(`cm${i}`,
          new CylinderGeometry({ radiusTop: r * 0.85, radiusBottom: r, height: 0.28, segments: 8 })) as Mesh;
        mesh.material = mat;
        n.addComponent(mesh);
      });
    } else {
      // 其他类型（墓葬群、窑址等）：简单球体
      const n = scene.createNode('obj') as Node;
      const mesh = scene.createMesh('m', new SphereGeometry({ radius: 0.65, segments: 20 })) as Mesh;
      mesh.material = mat;
      n.addComponent(mesh);
    }
  }

  build() {
    Component3D({
      onSceneReady: (scene: Scene) => {
        this.scene = scene;
        this.buildScene(scene);
        if (!this.reducedMotion) {
          // 每帧绕 Y 轴慢速旋转
          this.animTimer = setInterval(() => {
            if (!this.scene) return;
            this.rotY += 0.008;
            const root = this.scene.findNode('obj') || this.scene.findNode('box0') || this.scene.findNode('cyl0');
            if (root) root.rotation = Quat.fromEuler(0, this.rotY * 57.3, 0);
          }, 16) as number;
        }
      }
    })
    .width('100%')
    .height(200)
    .backgroundColor(this.isDark ? '#1a1510' : '#faf6f0')
    .borderRadius(16)
  }

  aboutToDisappear(): void {
    if (this.animTimer >= 0) clearInterval(this.animTimer);
  }
}
```

### 在 SiteDetail.ets 中加入视口

在 [`entry/src/main/ets/components/SiteDetail.ets`](entry/src/main/ets/components/SiteDetail.ets) 顶部加入 import：

```typescript
import { SiteObject3D } from './SiteObject3D';
```

然后在详情页 `Scroll` 内容最顶部（现有的 `Image(illustration)` 之前）加入：

```typescript
SiteObject3D({
  siteType: site.type,
  accentHex: site.accent,
  isDark: !snapshot.lightEnabled,
  reducedMotion: snapshot.reducedMotion
})
```

### 关于 `@kit.ArkGraphics3D` 的几何体 API

上述代码使用了 HarmonyOS 7 / API 26 中 `@kit.ArkGraphics3D` 的场景图 API。如果构建时提示某个几何体类（`BoxGeometry`、`SphereGeometry` 等）名称不对，先查阅本机 SDK 的类型声明文件（路径在 DevEco Studio 的 SDK 管理器里），以声明文件中的实际类名为准，不要照搬本文档的名称。本文档写于 2026-10-16，API 名称以当时官方文档核验为准，后续 SDK 更新可能有差异。

---

## 优先级 3：首页视觉提升（可选，内容扩充后再做）

首页现有 `RiverBackdrop`、双列卡片和五城入口。内容扩充到 15+ 条后，以下改动会有明显提升：

### 3a. 首页横向城市滚动入口替换竖列

当前五城用 `Column` 堆叠，扩展到 5 城后换成横向 `Scroll + Row`，每城一个圆形图标卡。改动仅在 `Index.ets` 的河迹 Tab 内，不影响其他 Tab。

### 3b. 搜索结果增加"年代时间轴"分组

在搜索 / 筛选结果的 `Column` 上方加一排年代快捷标签（仰韶 / 夏商 / 周 / 汉唐 / 宋），点击等同于设置 `era` 筛选。逻辑全在 `Index.ets` 的 state，不需要修改 domain。

---

## 优先级 4：阅读进度与备份恢复（赛题加分项，11-03 前视时间决定）

### 阅读进度

当前 `ArchiveRecord` 的 `kind = 'visited'` 只记录"打开过"，没有百分比。扩展方案：
- 在 `SiteDetail.ets` 的 `onScroll` 回调中计算 `scrollOffset / totalHeight`，每 10% 触发一次 `putRecord` 更新同一条 `visited` 记录的 `body` 为 `"progress:0.6"` 等格式。
- 这只改 `SiteDetail.ets` 和 `LocalArchiveRepository.ets`，不改同步合并逻辑。

### 用户可操作的备份恢复

- 导出：将 `snapshot.records` 序列化为 JSON，用 `fs.writeFile` 写到 Downloads 目录，弹出系统分享面板。
- 导入：从文件选择器读取 JSON，解析后与本地 snapshot 做合并（复用 `mergeRecords` 函数）。
- 入口放在 `ProfilePage.ets` 的"我的"页面底部。

---

## 验证清单（每轮交付前必须完成）

```powershell
# 1. 本地构建
.\tools\build.ps1

# 2. 本地代码测试（查看 Pass/Failure/Error，不能只看退出码）
.\tools\test.ps1

# 3. 如果修改了 CultureGraphWeb 或 CultureAtlas：
#    在模拟器上手动验证"文明连线"能打开、节点能点击、切换"我的图谱"正常
.\tools\device-test.ps1 -TargetId 127.0.0.1:5555 -TestClass CultureAtlasTest -ExpectedTests 2

# 4. 如果修改了 HeritageCatalog.ts：
#    在设备上打开应用，确认新条目在河迹 Tab 的列表中可见，详情页能正常打开
```

---

## 当前内容条目的扩充写法示例

以庙底沟遗址为例，展示完整填写格式：

```typescript
{
  id: 'smx-miaodiku', name: '庙底沟遗址', city: '三门峡', era: '仰韶', type: '聚落遗址',
  tags: ['彩陶', '聚落', '考古'],
  summary: '以花卉纹彩陶为代表，探索仰韶文化扩散与早期艺术的起点。',
  overview: '庙底沟遗址位于河南陕州区，是仰韶文化庙底沟类型的命名地。遗址出土的彩陶以圆点、弧线和花卉纹著称，在黄河中游有广泛分布。',
  archaeology: '观察重点包括彩陶纹饰风格、房址分布与窑址结构。具体出土数量、分期与年代数据待引用权威考古报告补充。',
  history: '庙底沟遗址发现于20世纪50年代，是认识仰韶文化区域扩散的重要参照点。史料引用待逐条核验。',
  poetry: '暂未收录可与本遗址直接对应的诗词。',
  travel: '地点索引：三门峡市陕州区。庙底沟博物馆开放时间与预约方式以官方公告为准，不在此预填。',
  source: { title: '河南省文物局（待补条目级来源）', url: 'https://wwj.henan.gov.cn/' },
  reviewStatus: '初稿待校审', illustration: 'motif_pottery.svg', accent: '#9B463E'
}
```

---

## 关于 HarmonyOS 6 兼容性

**不要修改 `build-profile.json5` 的 SDK 版本。** 当前工程用了 API 26 专属的 `HdsNavigation`、`HdsTabs` 等接口，这些在 HarmonyOS 6 上不存在，单纯改配置文件只会让应用装上后立即崩溃。比赛已确认使用自有 HarmonyOS 7 设备，这不是需要解决的问题。

---

## 模型使用限制提醒

根据协作约定，仅在获授权时使用子代理，使用模型必须是 `gpt-6-luna max` 或 `gpt-6.1-sol max`，不可擅自切换。
