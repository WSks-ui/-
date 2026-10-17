import type { ObjectMesh, ObjectPoint, SiteObjectShape } from './SiteObjectGeometry';

interface VesselProfile { y: number; radius: number; }

const RED_SLIP: string = '#B85E45';
const BLACK_PAINT: string = '#261B18';
const INNER_CLAY: string = '#BD805D';
const CUT_CLAY: string = '#E5BA87';
const CHANNEL_CLAY: string = '#78958A';
const CENTER_X: number = 0.48;
const OPENING_Y: number = -0.035;
const OUTER_OPENING_Y: number = 0.225;
const OUTER_OPENING_Z: number = 0.215;
const INNER_OPENING_Y: number = 0.19;
const INNER_OPENING_Z: number = 0.18;
const WALL: number = 0.043;

// 只依据“敞口、缩颈、鼓腹、平底”组织轮廓，没有把馆方总高换算成未核实的各部尺寸。
// 纹带、壁厚和通道尺寸均为阅读所需的简化参数；调整时须连同热点局部坐标核对。
const PROFILE: VesselProfile[] = [
  { y: -0.64, radius: 0.205 }, { y: -0.58, radius: 0.25 },
  { y: -0.5, radius: 0.33 }, { y: -0.4, radius: 0.395 },
  { y: -0.31, radius: 0.444 }, { y: -0.265, radius: 0.455 },
  { y: -0.23, radius: 0.46 }, { y: -0.15, radius: 0.469 },
  { y: -0.075, radius: 0.47 }, { y: -0.035, radius: 0.47 },
  { y: 0.01, radius: 0.465 }, { y: 0.05, radius: 0.46 },
  { y: 0.12, radius: 0.44 }, { y: 0.195, radius: 0.413 },
  { y: 0.23, radius: 0.395 }, { y: 0.275, radius: 0.37 },
  { y: 0.33, radius: 0.325 }, { y: 0.4, radius: 0.265 },
  { y: 0.49, radius: 0.205 }, { y: 0.59, radius: 0.195 },
  { y: 0.66, radius: 0.212 }, { y: 0.74, radius: 0.27 }
];

function mesh(name: string, color: string): ObjectMesh {
  return { name, color, vertices: [], normals: [], indices: [], faces: [], tone: 1 };
}

function samePoint(a: ObjectPoint, b: ObjectPoint): boolean {
  return Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z) < 1e-9;
}

function cutAtFront(points: ObjectPoint[]): ObjectPoint[] {
  const clipped: ObjectPoint[] = [];
  points.forEach((point, index) => {
    const before = points[(index + points.length - 1) % points.length];
    const inside = point.z <= 1e-9, beforeInside = before.z <= 1e-9;
    if (inside !== beforeInside) {
      const ratio = -before.z / (point.z - before.z);
      clipped.push({ x: before.x + (point.x - before.x) * ratio,
        y: before.y + (point.y - before.y) * ratio, z: 0 });
    }
    if (inside) clipped.push(point);
  });
  return clipped;
}

function face(target: ObjectMesh, points: ObjectPoint[], cutaway: boolean = false, reverse: boolean = false): void {
  const raw = cutaway ? cutAtFront(points) : points;
  const corners: ObjectPoint[] = [];
  raw.forEach(point => { if (!corners.length || !samePoint(corners[corners.length - 1], point)) corners.push(point); });
  if (corners.length > 1 && samePoint(corners[0], corners[corners.length - 1])) corners.pop();
  if (corners.length < 3) return;
  if (reverse) corners.reverse();
  const a = corners[0], b = corners[1], c = corners[2];
  const ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
  const vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
  const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
  const length = Math.hypot(nx, ny, nz);
  if (length < 1e-9) return;
  const start = target.vertices.length;
  corners.forEach(point => {
    target.vertices.push(point); target.normals.push({ x: nx / length, y: ny / length, z: nz / length });
  });
  const indices = corners.map((_point, index) => start + index);
  target.faces.push({ indices, tone: 1 });
  for (let index = 1; index < indices.length - 1; index++) target.indices.push(start, start + index, start + index + 1);
}

function radiusAt(y: number, inner: boolean = false): number {
  let radius = PROFILE[PROFILE.length - 1].radius;
  for (let row = 0; row < PROFILE.length - 1; row++) {
    const low = PROFILE[row], high = PROFILE[row + 1];
    if (y < low.y || y > high.y) continue;
    const ratio = (y - low.y) / (high.y - low.y);
    radius = low.radius + (high.radius - low.radius) * ratio;
    break;
  }
  return radius - (inner ? WALL : 0);
}

function openingHalfAngle(y: number, radius: number, inner: boolean): number {
  const ry = inner ? INNER_OPENING_Y : OUTER_OPENING_Y;
  const rz = inner ? INNER_OPENING_Z : OUTER_OPENING_Z;
  const height = (y - OPENING_Y) / ry;
  if (Math.abs(height) >= 1) return 0;
  return Math.asin(Math.min(0.95, rz * Math.sqrt(1 - height * height) / radius));
}

function strokeDrift(side: number, y: number): number {
  if (side < 0) return 0;
  if (y >= -0.23 && y <= -0.075) return (y + 0.23) / 0.155 * 0.18;
  if (y >= 0.05 && y <= 0.195) return (y - 0.05) / 0.145 * 0.18;
  return 0;
}

function ringPoint(side: number, y: number, fraction: number, inner: boolean): ObjectPoint {
  const radius = radiusAt(y, inner);
  const gap = openingHalfAngle(y, radius, inner);
  const inward = side < 0 ? 0 : Math.PI;
  // 每圈在朝向另一壶的侧面留出真孔；起止边与椭圆通道的端环使用同一计算。
  const around = fraction * Math.PI * 2 + (inner ? 0 : strokeDrift(side, y) * Math.sin(fraction * Math.PI));
  const angle = inward + Math.max(gap, Math.min(Math.PI * 2 - gap, around));
  return { x: side * CENTER_X + radius * Math.cos(angle), y, z: radius * Math.sin(angle) };
}

function isBand(y: number): boolean {
  return (y >= -0.31 && y < -0.265) || (y >= -0.035 && y < 0.01) || (y >= 0.23 && y < 0.275);
}

function shell(side: number, inner: boolean, cutaway: boolean, red: ObjectMesh, black: ObjectMesh): void {
  const segments = inner ? 24 : 36;
  const rows = inner ? [-0.57, -0.4, -0.26, -0.225, -0.18, -0.13, -0.08, OPENING_Y,
    0.01, 0.06, 0.11, 0.155, 0.19, 0.33, 0.49, 0.59, 0.66, 0.74] :
    PROFILE.map(point => point.y).concat([-0.26, -0.225, -0.185, -0.11, 0.085, 0.155, 0.19])
      .sort((a, b) => a - b);
  for (let row = 0; row < rows.length - 1; row++) {
    const low = rows[row], high = rows[row + 1];
    const middleY = (low + high) / 2;
    for (let column = 0; column < segments; column++) {
      // 每组角度拆成红面 / 窄黑彩 / 红面，纹线直接属于器壁，不以共面贴片依赖绘制顺序。
      // 左壶保持竖向，右壶每一行缓慢转角，形成连续斜短线；排布不是原纹样摹本。
      const fractionAt = (index: number): number => inner ? index / segments :
        (Math.floor(index / 3) + [0, 0.4, 0.49][index % 3]) / 12;
      const a = ringPoint(side, low, fractionAt(column), inner);
      const b = ringPoint(side, high, fractionAt(column), inner);
      const c = ringPoint(side, high, fractionAt(column + 1), inner);
      const d = ringPoint(side, low, fractionAt(column + 1), inner);
      const shortLine = column % 3 === 1 && ((middleY >= -0.23 && middleY < -0.075) ||
        (middleY >= 0.05 && middleY < 0.195));
      face(!inner && (isBand(middleY) || shortLine) ? black : red, [a, b, c, d], cutaway, inner);
    }
  }
}

function vesselEnds(side: number, cutaway: boolean, target: ObjectMesh): void {
  const segments = 32;
  const outerBottom: ObjectPoint[] = [], innerFloor: ObjectPoint[] = [];
  for (let column = 0; column < segments; column++) {
    const a = column / segments * Math.PI * 2, b = (column + 1) / segments * Math.PI * 2;
    const at = (radius: number, y: number, angle: number): ObjectPoint => ({
      x: side * CENTER_X + radius * Math.cos(angle), y, z: radius * Math.sin(angle) });
    face(target, [at(radiusAt(0.74), 0.74, a), at(radiusAt(0.74), 0.74, b),
      at(radiusAt(0.74, true), 0.74, b), at(radiusAt(0.74, true), 0.74, a)], cutaway, true);
    outerBottom.push(at(radiusAt(-0.64), -0.64, a));
    innerFloor.push(at(radiusAt(-0.57, true), -0.57, a));
  }
  // 双口均保留环形口沿，绝不补一个盖住内腔的实心顶面。
  face(target, outerBottom, cutaway);
  face(target, innerFloor, cutaway, true);
}

function cutEdges(side: number, target: ObjectMesh): void {
  const rows = PROFILE.map(point => point.y).filter(y => y >= -0.57).concat([-0.57, -0.26, 0.19]).sort((a, b) => a - b);
  [-1, 1].forEach(direction => {
    for (let row = 0; row < rows.length - 1; row++) {
      const low = rows[row], high = rows[row + 1], middle = (low + high) / 2;
      // 朝内的孔洞处不补切边；否则会重新封住刚打开的腹间连通关系。
      if (direction === -side && Math.abs(middle - OPENING_Y) < OUTER_OPENING_Y) continue;
      const a: ObjectPoint = { x: side * CENTER_X + direction * radiusAt(low), y: low, z: 0 };
      const b: ObjectPoint = { x: side * CENTER_X + direction * radiusAt(high), y: high, z: 0 };
      const c: ObjectPoint = { x: side * CENTER_X + direction * radiusAt(high, true), y: high, z: 0 };
      const d: ObjectPoint = { x: side * CENTER_X + direction * radiusAt(low, true), y: low, z: 0 };
      face(target, [a, b, c, d], false, direction < 0);
    }
  });
  face(target, [{ x: side * CENTER_X - radiusAt(-0.64), y: -0.64, z: 0 },
    { x: side * CENTER_X + radiusAt(-0.64), y: -0.64, z: 0 },
    { x: side * CENTER_X + radiusAt(-0.57), y: -0.57, z: 0 },
    { x: side * CENTER_X - radiusAt(-0.57), y: -0.57, z: 0 }]);
}

function channelPoint(side: number, angle: number, inner: boolean): ObjectPoint {
  const y = OPENING_Y + (inner ? INNER_OPENING_Y : OUTER_OPENING_Y) * Math.cos(angle);
  const z = (inner ? INNER_OPENING_Z : OUTER_OPENING_Z) * Math.sin(angle);
  const radius = radiusAt(y, inner);
  const x = side * (CENTER_X - Math.sqrt(Math.max(0.001, radius * radius - z * z)));
  return { x, y, z };
}

function connection(cutaway: boolean, outer: ObjectMesh, inner: ObjectMesh, edge: ObjectMesh): void {
  const segments = 32;
  for (let index = 0; index < segments; index++) {
    const a = index / segments * Math.PI * 2, b = (index + 1) / segments * Math.PI * 2;
    const loA = channelPoint(-1, a, false), roA = channelPoint(1, a, false);
    const loB = channelPoint(-1, b, false), roB = channelPoint(1, b, false);
    const liA = channelPoint(-1, a, true), riA = channelPoint(1, a, true);
    const liB = channelPoint(-1, b, true), riB = channelPoint(1, b, true);
    face(outer, [loA, roA, roB, loB], cutaway, true);
    face(inner, [liA, liB, riB, riA], cutaway, true);
    face(edge, [loA, loB, liB, liA], cutaway, true);
    face(edge, [roA, riA, riB, roB], cutaway, true);
  }
  if (cutaway) {
    // 通道也沿 z=0 实际剖去前半，不以透明壶或贴在表面的绿色圆片冒充内部结构。
    // 浅绿只帮助区分通道内壁；两端均开放，没有横跨通口的封口多边形。
    [0, Math.PI].forEach(angle => {
      face(edge, [channelPoint(-1, angle, false), channelPoint(1, angle, false),
        channelPoint(1, angle, true), channelPoint(-1, angle, true)], false, angle === 0);
    });
  }
}

export function dahecunObservationShape(selectedId: string = ''): SiteObjectShape {
  const cutaway = selectedId === 'opening';
  const outer = mesh('dahecun-red-slip', RED_SLIP);
  const black = mesh('dahecun-black-parallel-bands-and-strokes', BLACK_PAINT);
  const inner = mesh('dahecun-open-vessel-interiors', INNER_CLAY);
  const rim = mesh('dahecun-mouth-rims-and-floors', CUT_CLAY);
  const channelOuter = mesh('dahecun-elliptical-connection-outer', RED_SLIP);
  const channelInner = mesh('dahecun-elliptical-passage-inner', cutaway ? CHANNEL_CLAY : INNER_CLAY);
  const channelRim = mesh('dahecun-elliptical-passage-rims', CUT_CLAY);
  const cut = mesh('dahecun-section-clay-thickness', CUT_CLAY);
  [-1, 1].forEach(side => {
    shell(side, false, cutaway, outer, black);
    shell(side, true, cutaway, inner, black);
    vesselEnds(side, cutaway, rim);
    if (cutaway) cutEdges(side, cut);
  });
  connection(cutaway, channelOuter, channelInner, channelRim);
  return { title: cutaway ? '双连壶腹部相通 · 剖开解释示意' : '大河村彩陶双连壶 · 原创结构示意',
    meshes: [outer, black, inner, rim, channelOuter, channelInner, channelRim, cut].filter(part => part.faces.length > 0) };
}
