import type { ObjectMesh, ObjectPoint, SiteObjectShape } from './SiteObjectGeometry';

interface PlanPoint { x: number; z: number; }
interface LivingSymbol { x: number; z: number; west: boolean; }

const TOP: number = -0.16;
const GROOVE_DEPTH: number = 0.055;
const SAND: string = '#EBD7B6';
const EDGE: string = '#BE9F7B';
const ROSE: string = '#B46F7C';
const ROSE_SELECTED: string = '#D17C88';

// 坐标只组织阅读：+X 东、-X 西；Z 轴不解释为南北。符号不对应真实房址、窑址或地层。
// 西部的两种符号必须交错保留，不能为“分区清楚”移走西部居住符号。
// 改排布时同步核对 MiaodigouObservation.ts 的热点；沟槽始终只在东西两侧开放。
const LIVING: LivingSymbol[] = [
  { x: -0.67, z: -0.34, west: true }, { x: -0.36, z: 0.32, west: true },
  { x: 0.13, z: -0.27, west: false }, { x: 0.42, z: 0.20, west: false }
];
const KILNS: PlanPoint[] = [
  { x: -0.72, z: 0.12 }, { x: -0.38, z: -0.10 }, { x: -0.76, z: 0.43 }
];

function mesh(name: string, color: string): ObjectMesh {
  return { name, color, vertices: [], normals: [], indices: [], faces: [], tone: 1 };
}

function face(target: ObjectMesh, points: ObjectPoint[]): void {
  const a = points[0], b = points[1], c = points[2];
  const ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
  const vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
  const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
  const length = Math.hypot(nx, ny, nz);
  if (length < 1e-9) return;
  const start = target.vertices.length;
  points.forEach(point => {
    target.vertices.push(point);
    target.normals.push({ x: nx / length, y: ny / length, z: nz / length });
  });
  const indices = points.map((_point, index) => start + index);
  target.faces.push({ indices, tone: 1 });
  for (let index = 1; index < indices.length - 1; index++) target.indices.push(start, start + index, start + index + 1);
}

function plane(target: ObjectMesh, left: number, right: number, far: number, near: number, y: number): void {
  face(target, [{ x: left, y, z: far }, { x: left, y, z: near },
    { x: right, y, z: near }, { x: right, y, z: far }]);
}

function surfaceBand(target: ObjectMesh, farLeft: number, farRight: number, nearLeft: number,
  nearRight: number, far: number, near: number, columns: number): void {
  for (let column = 0; column < columns; column++) {
    const low = column / columns, high = (column + 1) / columns;
    face(target, [{ x: farLeft + (farRight - farLeft) * low, y: TOP, z: far },
      { x: nearLeft + (nearRight - nearLeft) * low, y: TOP, z: near },
      { x: nearLeft + (nearRight - nearLeft) * high, y: TOP, z: near },
      { x: farLeft + (farRight - farLeft) * high, y: TOP, z: far }]);
  }
}

function polygonPrism(target: ObjectMesh, plan: PlanPoint[], low: number, high: number): void {
  // plan 在 XZ 平面取逆时针；顶面须反转才能朝 +Y。每个面复制法线，保留硬边受光。
  const lower = plan.map(point => ({ x: point.x, y: low, z: point.z }));
  const upper = plan.map(point => ({ x: point.x, y: high, z: point.z }));
  face(target, lower);
  face(target, upper.slice().reverse());
  for (let index = 0; index < plan.length; index++) {
    const next = (index + 1) % plan.length;
    face(target, [lower[index], upper[index], upper[next], lower[next]]);
  }
}

function rectangle(target: ObjectMesh, x: number, z: number, sx: number, sz: number,
  low: number, high: number): void {
  polygonPrism(target, [{ x: x - sx, z: z - sz }, { x: x + sx, z: z - sz },
    { x: x + sx, z: z + sz }, { x: x - sx, z: z + sz }], low, high);
}

function octagon(x: number, z: number, sx: number, sz: number, cut: number): PlanPoint[] {
  return [{ x: x - sx + cut, z: z - sz }, { x: x + sx - cut, z: z - sz },
    { x: x + sx, z: z - sz + cut }, { x: x + sx, z: z + sz - cut },
    { x: x + sx - cut, z: z + sz }, { x: x - sx + cut, z: z + sz },
    { x: x - sx, z: z + sz - cut }, { x: x - sx, z: z - sz + cut }];
}

function terrain(surface: ObjectMesh, edge: ObjectMesh, banks: ObjectMesh, beds: ObjectMesh): void {
  const top = octagon(0, 0, 1.27, 0.83, 0.13);
  const shoulder = octagon(0, 0, 1.30, 0.86, 0.13);
  const bottom = octagon(0, 0, 1.27, 0.83, 0.13);
  // 单块沙盘的倒角和底厚只让符号落地，不画叠层，不暗示考古地层或实际地貌。
  for (let index = 0; index < top.length; index++) {
    const next = (index + 1) % top.length;
    face(edge, [{ x: shoulder[index].x, y: TOP - 0.045, z: shoulder[index].z },
      { x: top[index].x, y: TOP, z: top[index].z },
      { x: top[next].x, y: TOP, z: top[next].z },
      { x: shoulder[next].x, y: TOP - 0.045, z: shoulder[next].z }]);
    face(edge, [{ x: bottom[index].x, y: TOP - 0.15, z: bottom[index].z },
      { x: shoulder[index].x, y: TOP - 0.045, z: shoulder[index].z },
      { x: shoulder[next].x, y: TOP - 0.045, z: shoulder[next].z },
      { x: bottom[next].x, y: TOP - 0.15, z: bottom[next].z }]);
  }
  face(edge, bottom.map(point => ({ x: point.x, y: TOP - 0.15, z: point.z })));
  // Canvas 以面的平均深度排序：整块大顶面会盖住后排低矮符号。
  // 细分仅用于正确遮挡，不能向用户解释为探方网格；近缘加密是为了保住方位笔画。
  const rows = [-0.70, -0.56, -0.42, -0.28, -0.14, 0, 0.14, 0.28, 0.42, 0.52, 0.58, 0.64, 0.70];
  for (let row = 0; row < rows.length - 1; row++) {
    surfaceBand(surface, -0.96, 0.96, -0.96, 0.96, rows[row], rows[row + 1], 10);
    surfaceBand(surface, -1.27, -1.14, -1.27, -1.14, rows[row], rows[row + 1], 1);
    surfaceBand(surface, 1.14, 1.27, 1.14, 1.27, rows[row], rows[row + 1], 1);
  }
  [-1, 1].forEach(side => {
    for (let row = 0; row < 3; row++) {
      const far = side < 0 ? -0.83 + row / 3 * 0.13 : 0.70 + row / 3 * 0.13;
      const near = far + 0.13 / 3;
      const farWidth = 1.27 - Math.max(0, Math.abs(far) - 0.70);
      const nearWidth = 1.27 - Math.max(0, Math.abs(near) - 0.70);
      surfaceBand(surface, -farWidth, farWidth, -nearWidth, nearWidth, far, near, 10);
    }
  });
  [-1, 1].forEach(side => {
    const left = side < 0 ? -1.14 : 0.96;
    const right = side < 0 ? -0.96 : 1.14;
    plane(surface, left, right, -0.70, -0.58, TOP);
    plane(surface, left, right, 0.58, 0.70, TOP);
    const xs = [left, left + 0.055, right - 0.055, right];
    const zs = [-0.58, -0.49, 0.49, 0.58];
    const depthAt = (column: number, row: number): number =>
      column > 0 && column < 3 && row > 0 && row < 3 ? GROOVE_DEPTH : 0;
    // 地面没有覆盖沟槽：横断面有下凹沟底和斜坡，端部回到地表；两侧之间不补任何连线。
    // 长度、宽度和深度是阅读参数，不能拿它们换算真实遗迹尺度。
    for (let column = 0; column < 3; column++) {
      for (let row = 0; row < 3; row++) {
        const at = (col: number, line: number): ObjectPoint => ({
          x: xs[col], y: TOP - depthAt(col, line), z: zs[line] });
        const corners = [at(column, row), at(column, row + 1),
          at(column + 1, row + 1), at(column + 1, row)];
        if (column !== 1 && row !== 1) {
          // 沟端四角并不共面，拆为真实平面，不能用单一法线覆盖扭曲四边形。
          face(banks, [corners[0], corners[1], corners[2]]);
          face(banks, [corners[0], corners[2], corners[3]]);
        } else {
          face(column === 1 ? beds : banks, corners);
        }
      }
    }
  });
}

function livingSymbol(symbol: LivingSymbol, index: number, selected: boolean): ObjectMesh[] {
  const name = `miaodigou-living-${symbol.west ? 'west' : 'middle'}-${index}`;
  const walls = mesh(`${name}-abstract-house`, selected ? '#E4B5AA' : '#D8B5A6');
  const roof = mesh(`${name}-rose-roof`, selected ? ROSE_SELECTED : ROSE);
  const x = symbol.x, z = symbol.z;
  rectangle(walls, x, z, 0.115, 0.085, TOP + 0.004, TOP + 0.125);
  // 房形是“居住”图例，不复原庙底沟房屋；双坡的厚屋顶让低面数符号在旋转中仍易辨认。
  const far = z - 0.11, near = z + 0.11;
  const left = x - 0.15, right = x + 0.15;
  const eave = TOP + 0.125, lower = eave - 0.018, ridge = TOP + 0.245;
  face(roof, [{ x: left, y: eave, z: near }, { x, y: ridge, z: near },
    { x, y: ridge, z: far }, { x: left, y: eave, z: far }]);
  face(roof, [{ x, y: ridge, z: near }, { x: right, y: eave, z: near },
    { x: right, y: eave, z: far }, { x, y: ridge, z: far }]);
  face(roof, [{ x: left, y: lower, z: near }, { x: right, y: lower, z: near },
    { x: right, y: eave, z: near }, { x, y: ridge, z: near }, { x: left, y: eave, z: near }]);
  face(roof, [{ x: right, y: lower, z: far }, { x: left, y: lower, z: far },
    { x: left, y: eave, z: far }, { x, y: ridge, z: far }, { x: right, y: eave, z: far }]);
  face(roof, [{ x: left, y: lower, z: near }, { x: left, y: eave, z: near },
    { x: left, y: eave, z: far }, { x: left, y: lower, z: far }]);
  face(roof, [{ x: right, y: lower, z: far }, { x: right, y: eave, z: far },
    { x: right, y: eave, z: near }, { x: right, y: lower, z: near }]);
  face(roof, [{ x: left, y: lower, z: far }, { x: right, y: lower, z: far },
    { x: right, y: lower, z: near }, { x: left, y: lower, z: near }]);
  return [walls, roof];
}

function kilnSymbol(center: PlanPoint, index: number, selected: boolean): ObjectMesh[] {
  const outer = mesh(`miaodigou-kilns-west-${index}-clay-ring`, selected ? '#CD8757' : '#B97550');
  const rim = mesh(`miaodigou-kilns-west-${index}-rim`, selected ? '#F0BF88' : '#DEA76F');
  const inner = mesh(`miaodigou-kilns-west-${index}-open-interior`, '#77544C');
  const floor = mesh(`miaodigou-kilns-west-${index}-dark-floor`, '#554A43');
  const segments = 12;
  const low = TOP + 0.012, high = TOP + 0.135;
  const at = (radius: number, y: number, angle: number): ObjectPoint => ({
    x: center.x + radius * Math.cos(angle), y, z: center.z + radius * Math.sin(angle) });
  const floorPoints: ObjectPoint[] = [], bottomPoints: ObjectPoint[] = [];
  // 陶色圆环只标记西部制陶遗存；环径、壁厚、开口和数量没有窑炉类型或实测含义。
  for (let index = 0; index < segments; index++) {
    const a = index / segments * Math.PI * 2, b = (index + 1) / segments * Math.PI * 2;
    face(outer, [at(0.12, low, a), at(0.105, high, a), at(0.105, high, b), at(0.12, low, b)]);
    face(rim, [at(0.105, high, a), at(0.066, high, a), at(0.066, high, b), at(0.105, high, b)]);
    face(inner, [at(0.066, high, a), at(0.055, low + 0.025, a),
      at(0.055, low + 0.025, b), at(0.066, high, b)]);
    floorPoints.push(at(0.055, low + 0.025, a));
    bottomPoints.push(at(0.12, low, a));
  }
  face(floor, floorPoints.reverse());
  face(outer, bottomPoints);
  return [outer, rim, inner, floor];
}

function stroke(target: ObjectMesh, x: number, z: number, ax: number, az: number,
  bx: number, bz: number): void {
  const length = Math.hypot(bx - ax, bz - az);
  const dx = -(bz - az) / length * 0.008, dz = (bx - ax) / length * 0.008;
  polygonPrism(target, [{ x: x + ax + dx, z: z + az + dz }, { x: x + ax - dx, z: z + az - dz },
    { x: x + bx - dx, z: z + bz - dz }, { x: x + bx + dx, z: z + bz + dz }], TOP + 0.02, TOP + 0.06);
}

function directionMarks(): ObjectMesh {
  const target = mesh('miaodigou-world-direction-west-middle-east', '#6A6557');
  const z = 0.665;
  // 方位字由有厚度的笔画组成，随模型旋转；不用固定屏幕“左西右东”误导转动后的阅读。
  // 只标西、中、东，不添加资料未确认的南北向或比例尺。笔画间距仅为小画幅的识别服务。
  const west = -0.79;
  stroke(target, west, z, -0.105, -0.105, 0.105, -0.105);
  stroke(target, west, z, -0.09, -0.055, 0.09, -0.055);
  stroke(target, west, z, -0.09, -0.055, -0.09, 0.095);
  stroke(target, west, z, 0.09, -0.055, 0.09, 0.095);
  stroke(target, west, z, -0.09, 0.095, 0.09, 0.095);
  stroke(target, west, z, -0.032, -0.105, -0.032, 0.025);
  stroke(target, west, z, -0.032, 0.025, -0.065, 0.05);
  stroke(target, west, z, 0.032, -0.105, 0.032, 0.045);
  stroke(target, west, z, 0.032, 0.045, 0.064, 0.045);
  stroke(target, 0, z, -0.085, -0.06, 0.085, -0.06);
  stroke(target, 0, z, -0.085, -0.06, -0.085, 0.06);
  stroke(target, 0, z, 0.085, -0.06, 0.085, 0.06);
  stroke(target, 0, z, -0.085, 0.06, 0.085, 0.06);
  stroke(target, 0, z, 0, -0.105, 0, 0.105);
  const east = 0.79;
  stroke(target, east, z, -0.10, -0.07, 0.10, -0.07);
  stroke(target, east, z, 0.012, -0.11, -0.08, 0.025);
  stroke(target, east, z, -0.08, 0.025, 0.09, 0.025);
  stroke(target, east, z, 0, -0.015, 0, 0.105);
  stroke(target, east, z, -0.035, 0.048, -0.09, 0.096);
  stroke(target, east, z, 0.035, 0.048, 0.095, 0.096);
  return target;
}

export function miaodigouObservationShape(selectedId: string = ''): SiteObjectShape {
  const surface = mesh('miaodigou-single-sandbox-surface', SAND);
  const edge = mesh('miaodigou-single-sandbox-bevel-and-base', EDGE);
  const banks = mesh('miaodigou-ditches-east-west-sloping-banks', selectedId === 'ditches' ? '#A6C2AF' : '#B8BAA2');
  const beds = mesh('miaodigou-ditches-east-west-open-beds', selectedId === 'ditches' ? '#548F87' : '#718F83');
  terrain(surface, edge, banks, beds);
  const meshes: ObjectMesh[] = [surface, edge, banks, beds];
  LIVING.forEach((symbol, index) => meshes.push(...livingSymbol(symbol, index, selectedId === 'living')));
  KILNS.forEach((symbol, index) => meshes.push(...kilnSymbol(symbol, index, selectedId === 'kilns')));
  meshes.push(directionMarks());
  return { title: '庙底沟聚落方位 · 原创学习沙盘（非实测平面）', meshes };
}
