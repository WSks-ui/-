// 这些程序化形态仅用于探索交互，不对应出土文物、测绘数据或遗址复原。
// 网格保持平台无关，ArkGraphics3D 的材质、生命周期与 GPU 资源由 platform 层负责。
export interface ObjectPoint { x: number; y: number; z: number; }
export interface ObjectProfile { radius: number; y: number; tone?: number; }
// 保留原始多边形，软件光照 / 描边不能把 GPU 三角剖分的对角线当成结构棱线。
// tone 只改变当前面的装饰色，不叠加共面的网格，避免纹带闪烁或遮盖顺序不稳定。
export interface ObjectFace { indices: number[]; tone: number; }
export interface ObjectMesh {
  name: string;
  vertices: ObjectPoint[];
  normals: ObjectPoint[];
  indices: number[];
  faces: ObjectFace[];
  tone: number;
  color?: string;
  opacity?: number;
}
export interface SiteObjectShape { title: string; meshes: ObjectMesh[]; }

function mesh(name: string, tone: number = 1): ObjectMesh {
  return { name, vertices: [], normals: [], indices: [], faces: [], tone };
}

function addFace(target: ObjectMesh, indices: number[], tone: number = 1): void {
  const corners: number[] = [];
  const samePoint = (a: number, b: number): boolean => {
    const p = target.vertices[a], q = target.vertices[b];
    return Math.hypot(p.x - q.x, p.y - q.y, p.z - q.z) < 1e-10;
  };
  indices.forEach(index => {
    if (!corners.length || !samePoint(index, corners[corners.length - 1])) corners.push(index);
  });
  if (corners.length > 1 && samePoint(corners[0], corners[corners.length - 1])) corners.pop();
  if (corners.length < 3) return;
  target.faces.push({ indices: corners, tone });
  for (let index = 1; index < corners.length - 1; index++) {
    target.indices.push(corners[0], corners[index], corners[index + 1]);
  }
}

function lathe(name: string, profile: ObjectProfile[], segments: number = 16,
  offsetY: number = 0, tone: number = 1): ObjectMesh {
  const result = mesh(name, tone);
  profile.forEach((point: ObjectProfile, row: number) => {
    const before = profile[Math.max(0, row - 1)];
    const after = profile[Math.min(profile.length - 1, row + 1)];
    const dr = after.radius - before.radius, dy = after.y - before.y;
    const length = Math.hypot(dr, dy) || 1;
    for (let column = 0; column <= segments; column++) {
      const angle = column / segments * Math.PI * 2;
      const cos = Math.cos(angle), sin = Math.sin(angle);
      result.vertices.push({ x: point.radius * cos, y: point.y + offsetY, z: point.radius * sin });
      result.normals.push({ x: dy * cos / length, y: -dr / length, z: dy * sin / length });
    }
  });
  // 先完成顶点，再引用下一圈的点做去重，不能在生成当前圈时读取尚未创建的顶点。
  for (let row = 0; row < profile.length - 1; row++) {
    for (let column = 0; column < segments; column++) {
      const a = row * (segments + 1) + column, b = a + segments + 1;
      // 统一外向绕序；轴上的重复顶点在 addFace 中合为三角面，防止零法线。
      addFace(result, [a, b, b + 1, a + 1], profile[row].tone ?? 1);
    }
  }
  return result;
}

function box(name: string, halfW: number, halfD: number, yBottom: number, yTop: number, tone: number): ObjectMesh {
  // 宽深分离，方便城台每层做不同比例；chamfer 斜角通过两圈顶点实现。
  const result = mesh(name, tone);
  const ch = 0.025; // 斜切宽度，消除硬直角
  const corners: ObjectPoint[] = [
    // 底面四角（yBottom）
    { x: -halfW,    y: yBottom, z: -halfD    }, { x: halfW,    y: yBottom, z: -halfD    },
    { x: halfW,     y: yBottom, z: halfD     }, { x: -halfW,   y: yBottom, z: halfD     },
    // 斜角下环（yBottom + ch）
    { x: -(halfW-ch), y: yBottom+ch, z: -(halfD-ch) }, { x: (halfW-ch), y: yBottom+ch, z: -(halfD-ch) },
    { x: (halfW-ch),  y: yBottom+ch, z: (halfD-ch)  }, { x: -(halfW-ch), y: yBottom+ch, z: (halfD-ch) },
    // 斜角上环（yTop - ch）
    { x: -(halfW-ch), y: yTop-ch, z: -(halfD-ch) }, { x: (halfW-ch), y: yTop-ch, z: -(halfD-ch) },
    { x: (halfW-ch),  y: yTop-ch, z: (halfD-ch)  }, { x: -(halfW-ch), y: yTop-ch, z: (halfD-ch) },
    // 顶面四角（yTop）
    { x: -halfW,    y: yTop, z: -halfD    }, { x: halfW,    y: yTop, z: -halfD    },
    { x: halfW,     y: yTop, z: halfD     }, { x: -halfW,   y: yTop, z: halfD     }
  ];
  corners.forEach(c => { result.vertices.push(c); result.normals.push({ x: 0, y: 1, z: 0 }); });
  // 顶面
  addFace(result, [12, 13, 14, 15]);
  // 四个主侧面（环 1→2 之间，主视面）
  addFace(result, [4, 5, 9, 8]);   // 前
  addFace(result, [6, 7, 11, 10]); // 后
  addFace(result, [7, 4, 8, 11]);  // 左
  addFace(result, [5, 6, 10, 9]);  // 右
  // 顶部斜切面
  addFace(result, [8, 9, 13, 12]);
  addFace(result, [10, 11, 15, 14]);
  addFace(result, [11, 8, 12, 15]);
  addFace(result, [9, 10, 14, 13]);
  // 底部斜切面
  addFace(result, [0, 1, 5, 4]);
  addFace(result, [2, 3, 7, 6]);
  addFace(result, [3, 0, 4, 7]);
  addFace(result, [1, 2, 6, 5]);
  // 上方轮廓按绕 Y 轴的原顺序连接时法线朝内。启用背面剔除后会丢失外壁，
  // 因此统一反转，并为每个硬面复制顶点生成真实法线，避免 GPU 仍将所有面当顶面受光。
  addFace(result, [0, 3, 2, 1]);
  const outward = mesh(name, tone);
  result.faces.forEach(polygon => {
    const points = polygon.indices.slice().reverse().map(index => result.vertices[index]);
    const a = points[0], b = points[1], c = points[2];
    const ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
    const vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
    const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
    const length = Math.hypot(nx, ny, nz) || 1;
    const start = outward.vertices.length;
    points.forEach(point => { outward.vertices.push(point); outward.normals.push({ x: nx / length, y: ny / length, z: nz / length }); });
    addFace(outward, points.map((_point, index) => start + index));
  });
  return outward;
}

function ring(): ObjectMesh {
  // 城垣采用有厚度的环形截面，外壁 / 内壁的绕序相反，顶部独立受光。
  // 这是类型示意，不将圆环解释为具体遗址的平面形制。
  return lathe('wall-ring', [
    { radius: 0.78, y: -0.275 }, { radius: 0.78, y: 0.275 },
    { radius: 0.52, y: 0.275 }, { radius: 0.52, y: -0.275 },
    { radius: 0.78, y: -0.275 }
  ], 24);
}

function pottery(): ObjectMesh {
  const profile: ObjectProfile[] = [
    { radius: 0, y: -0.62 }, { radius: 0.29, y: -0.62 }, { radius: 0.39, y: -0.52 },
    { radius: 0.54, y: -0.34 }, { radius: 0.63, y: -0.1 }, { radius: 0.61, y: 0.12 },
    { radius: 0.49, y: 0.32 }, { radius: 0.32, y: 0.45 }, { radius: 0.28, y: 0.55 },
    { radius: 0.28, y: 0.65 }, { radius: 0.35, y: 0.69 }, { radius: 0.23, y: 0.69 },
    { radius: 0.23, y: 0.49 }, { radius: 0, y: 0.34 }
  ];
  const decorated: ObjectProfile[] = [];
  profile.forEach((point, row) => {
    decorated.push(point);
    if (row < 3 || row > 5) return;
    const next = profile[row + 1];
    // 三道窄纹带与器身共用顶点和面；它们只属于本应用的几何装饰，不引用考古纹样。
    [0.32, 0.52].forEach((ratio, index) => decorated.push({
      radius: point.radius + (next.radius - point.radius) * ratio,
      y: point.y + (next.y - point.y) * ratio, tone: index === 0 ? 0.62 : 1
    }));
  });
  return lathe('pottery', decorated, 24);
}

export function siteObjectShape(siteType: string): SiteObjectShape {
  if (siteType === '都城遗址') {
    // 城台：三层宽深略有差异，每层有斜切棱角，侧面明暗清晰。
    // tone 值让下层偏暗（压实感），上层偏亮（光照顶面）。
    return { title: '城台形态', meshes: [
      box('terrace-base', 0.78, 0.62, -0.72, -0.30, 0.78),
      box('terrace-mid',  0.56, 0.44, -0.30,  0.12, 0.92),
      box('terrace-top',  0.34, 0.28,  0.12,  0.52, 1.08)
    ]};
  }
  if (siteType === '城址') return { title: '环形城垣', meshes: [ring()] };
  if (siteType === '古建筑') {
    // 层塔：16 段旋成体，每层用完整轮廓（底盘边缘 → 收分顶 → 挑檐 → 脊线），
    // 消除层间缝隙，檐口水平面受光最亮，形成典型的塔层节奏。
    const tiers: ObjectMesh[] = [];
    const tierData = [
      { r: 0.70, eave: 0.10, y: -0.58, h: 0.30 },
      { r: 0.57, eave: 0.08, y: -0.24, h: 0.28 },
      { r: 0.45, eave: 0.07, y:  0.08, h: 0.26 },
      { r: 0.34, eave: 0.06, y:  0.38, h: 0.24 },
      { r: 0.24, eave: 0.05, y:  0.65, h: 0.22 }
    ];
    tierData.forEach(({ r, eave, y, h }, i) => {
      // 每层轮廓：底边 → 身柱内收 → 檐口外挑 → 屋脊收尖
      const profile: ObjectProfile[] = [
        { radius: 0,       y: y },
        { radius: r,       y: y },
        { radius: r * 0.88, y: y + h * 0.55 },
        { radius: r + eave, y: y + h * 0.72 },  // 挑檐，水平面受光
        { radius: r * 0.30, y: y + h * 0.92 },
        { radius: 0,       y: y + h }
      ];
      tiers.push(lathe(`tower-${i}`, profile, 16, 0, 0.88 + i * 0.028));
    });
    // 顶部宝顶（细长圆柱）
    tiers.push(lathe('finial', [
      { radius: 0, y: 0.87 }, { radius: 0.055, y: 0.87 },
      { radius: 0.055, y: 1.08 }, { radius: 0.025, y: 1.14 }, { radius: 0, y: 1.14 }
    ], 12, 0, 1.15));
    return { title: '层塔形态', meshes: tiers };
  }
  if (siteType === '墓葬群') {
    // 封土堆：半球 + 底部圆形台基，更有"坟丘"的落地感。
    const profile: ObjectProfile[] = [{ radius: 0, y: -0.24 }, { radius: 0.80, y: -0.24 }];
    for (let step = 1; step <= 14; step++) {
      const angle = step / 14 * Math.PI / 2;
      profile.push({ radius: 0.80 * Math.cos(angle), y: -0.24 + 0.72 * Math.sin(angle) });
    }
    profile.push({ radius: 0, y: 0.48 });
    return { title: '封土形态', meshes: [lathe('mound', profile, 20)] };
  }
  if (siteType === '窑址') {
    // 窑体：略带弧度的圆筒，顶部有收口，底部有底盘。
    return { title: '窑体形态', meshes: [lathe('kiln', [
      { radius: 0,    y: -0.38 },
      { radius: 0.72, y: -0.38 },
      { radius: 0.76, y: -0.18 },
      { radius: 0.76, y:  0.14 },
      { radius: 0.64, y:  0.32 },
      { radius: 0.38, y:  0.42 },
      { radius: 0.18, y:  0.48 },
      { radius: 0,    y:  0.48 }
    ], 20)] };
  }
  // 聚落遗址等其余类型 → 陶器
  return { title: '陶器形态', meshes: [pottery()] };
}
