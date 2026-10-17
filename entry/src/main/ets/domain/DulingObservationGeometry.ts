import type { ObjectMesh, ObjectPoint, SiteObjectShape } from './SiteObjectGeometry';

interface SquareRing { half: number; y: number; }
interface LegRing { radius: number; y: number; }
interface EarPoint { z: number; y: number; }

const BODY_LOW: number = -0.16;
const BODY_HIGH: number = 0.5;
const FLOOR_Y: number = -0.085;
const WALL: number = 0.065;
const MARK_LOW: number = 0.265;
const MARK_HIGH: number = 0.435;
const MARK_LIFT: number = 0.023;

function mesh(name: string, color: string): ObjectMesh {
  return { name, color, vertices: [], normals: [], indices: [], faces: [], tone: 1 };
}

function face(target: ObjectMesh, points: ObjectPoint[], reverse: boolean = false, tone: number = 1): void {
  const corners = reverse ? points.slice().reverse() : points;
  const a = corners[0], b = corners[1], c = corners[2];
  const ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
  const vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
  const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
  const length = Math.hypot(nx, ny, nz);
  if (length < 1e-9) return;
  const start = target.vertices.length;
  corners.forEach(point => {
    target.vertices.push(point);
    target.normals.push({ x: nx / length, y: ny / length, z: nz / length });
  });
  const indices = corners.map((_point, index) => start + index);
  target.faces.push({ indices, tone });
  for (let index = 1; index < indices.length - 1; index++) target.indices.push(start, start + index, start + index + 1);
}

function halfAt(y: number): number {
  // 方腹只保留轻微收分，不能把这些阅读比例解释成二号鼎局部测绘尺寸。
  return 0.55 + (y - BODY_LOW) / (BODY_HIGH - BODY_LOW) * 0.08;
}

function wallPoint(side: number, u: number, y: number, lift: number = 0): ObjectPoint {
  const half = halfAt(y) + lift;
  if (side === 0) return { x: u, y, z: half };
  if (side === 1) return { x: half, y, z: -u };
  if (side === 2) return { x: -u, y, z: -half };
  return { x: -half, y, z: u };
}

function squarePoint(side: number, fraction: number, ring: SquareRing): ObjectPoint {
  if (side === 0) return { x: fraction * ring.half, y: ring.y, z: ring.half };
  if (side === 1) return { x: ring.half, y: ring.y, z: -fraction * ring.half };
  if (side === 2) return { x: -fraction * ring.half, y: ring.y, z: -ring.half };
  return { x: -ring.half, y: ring.y, z: fraction * ring.half };
}

function ringSurface(target: ObjectMesh, low: SquareRing, high: SquareRing): void {
  for (let side = 0; side < 4; side++) {
    face(target, [squarePoint(side, -1, low), squarePoint(side, 1, low),
      squarePoint(side, 1, high), squarePoint(side, -1, high)]);
  }
}

function squareFace(target: ObjectMesh, half: number, y: number, up: boolean): void {
  face(target, [{ x: -half, y, z: half }, { x: half, y, z: half },
    { x: half, y, z: -half }, { x: -half, y, z: -half }], !up);
}

function vessel(outer: ObjectMesh, inner: ObjectMesh, rim: ObjectMesh): void {
  // 外壁分区与位置片的范围相近，使软件逐面排序时不让一整面大墙盖住远侧的小标记。
  // 分区不代表铸造拼缝；它们共用同一平面和色阶，不能额外描成考古结构线。
  const rows = [BODY_LOW, -0.105, -0.025, 0.075, 0.175, MARK_LOW, MARK_HIGH, BODY_HIGH];
  const columns = [-1, -0.78, -0.27, 0.27, 0.78, 1];
  for (let side = 0; side < 4; side++) {
    for (let row = 0; row < rows.length - 1; row++) {
      const low = rows[row], high = rows[row + 1];
      for (let column = 0; column < columns.length - 1; column++) {
        face(outer, [wallPoint(side, columns[column] * halfAt(low), low),
          wallPoint(side, columns[column + 1] * halfAt(low), low),
          wallPoint(side, columns[column + 1] * halfAt(high), high),
          wallPoint(side, columns[column] * halfAt(high), high)], false,
          low >= MARK_LOW && high <= MARK_HIGH ? 0.94 : 1);
      }
    }
    // 内壁也按上腹位置片和器底分区，避免平均深度排序把远侧外饰漏画到空腔内。
    // 法线朝内腔，不能使用双面透明表皮来掩盖遮挡；俯视时真实看见后内壁与平底。
    const innerRows = [FLOOR_Y, 0.105, MARK_LOW, MARK_HIGH, BODY_HIGH];
    for (let row = 0; row < innerRows.length - 1; row++) {
      const low = innerRows[row], high = innerRows[row + 1];
      for (let column = 0; column < columns.length - 1; column++) {
        face(inner, [wallPoint(side, columns[column] * (halfAt(low) - WALL), low, -WALL),
          wallPoint(side, columns[column + 1] * (halfAt(low) - WALL), low, -WALL),
          wallPoint(side, columns[column + 1] * (halfAt(high) - WALL), high, -WALL),
          wallPoint(side, columns[column] * (halfAt(high) - WALL), high, -WALL)], true);
      }
    }
  }
  const floorHalf = halfAt(FLOOR_Y) - WALL;
  for (let row = 0; row < 4; row++) {
    for (let column = 0; column < 4; column++) {
      const left = -floorHalf + column / 4 * floorHalf * 2, right = -floorHalf + (column + 1) / 4 * floorHalf * 2;
      const near = -floorHalf + row / 4 * floorHalf * 2, far = -floorHalf + (row + 1) / 4 * floorHalf * 2;
      face(inner, [{ x: left, y: FLOOR_Y, z: far }, { x: right, y: FLOOR_Y, z: far },
        { x: right, y: FLOOR_Y, z: near }, { x: left, y: FLOOR_Y, z: near }], false, 1.1);
    }
  }
  squareFace(outer, halfAt(BODY_LOW), BODY_LOW, false);

  // 截面沿“外壁 → 外折口沿 → 方唇顶面 → 内壁”连续绕行，中央始终不封顶。
  // 厚度和斜切只是让空口在演示画幅内可辨，不补造真实口沿尺寸。
  const lip: SquareRing[] = [
    { half: halfAt(BODY_HIGH), y: BODY_HIGH }, { half: 0.695, y: 0.512 },
    { half: 0.695, y: 0.553 }, { half: 0.68, y: 0.568 },
    { half: halfAt(BODY_HIGH) - WALL, y: 0.568 },
    { half: halfAt(BODY_HIGH) - WALL, y: BODY_HIGH }
  ];
  for (let index = 0; index < lip.length - 1; index++) ringSurface(rim, lip[index], lip[index + 1]);
}

function centerMarkers(target: ObjectMesh): void {
  const low = MARK_LOW + 0.015, high = MARK_HIGH - 0.015;
  const outline: EarPoint[] = [
    { z: -0.14, y: low }, { z: 0.14, y: low }, { z: 0.164, y: low + 0.024 },
    { z: 0.164, y: high - 0.024 }, { z: 0.14, y: high }, { z: -0.14, y: high },
    { z: -0.164, y: high - 0.024 }, { z: -0.164, y: low + 0.024 }
  ];
  for (let side = 0; side < 4; side++) {
    const front = outline.map(point => wallPoint(side, point.z, point.y, MARK_LIFT));
    const back = outline.map(point => wallPoint(side, point.z, point.y, 0.003));
    // 原创八边位置片每壁只设一枚；没有眼、角、口等兽面细节，也不摹拓本。
    face(target, front);
    for (let index = 0; index < outline.length; index++) {
      const next = (index + 1) % outline.length;
      face(target, [back[index], back[next], front[next], front[index]]);
    }
  }
}

function cornerPoint(side: number, edge: number, y: number, lift: number): ObjectPoint {
  // 先沿墙面法向抬起，再让切向终点到达同一外扩折角；两个壁片由此共用一条实际棱。
  return wallPoint(side, halfAt(y) + lift - edge, y, lift);
}

function cornerMarkers(target: ObjectMesh): void {
  const low = MARK_LOW + 0.015, high = MARK_HIGH - 0.015;
  const length = 0.185, backLift = 0.003;
  for (let side = 0; side < 4; side++) {
    const adjacent = (side + 1) % 4;
    const arm = (wall: number, sign: number): void => {
      const at = (edge: number, y: number, lift: number): ObjectPoint => {
        const point = cornerPoint(wall, edge, y, lift);
        return sign === 1 ? point : wallPoint(wall, -(halfAt(y) + lift - edge), y, lift);
      };
      const a = at(length, low, MARK_LIFT), b = at(0, low, MARK_LIFT);
      const c = at(0, high, MARK_LIFT), d = at(length, high, MARK_LIFT);
      const ba = at(length, low, backLift), bb = at(0, low, backLift);
      const bc = at(0, high, backLift), bd = at(length, high, backLift);
      face(target, [a, b, c, d], sign < 0);
      face(target, [ba, bb, b, a], sign < 0);
      face(target, [d, c, bc, bd], sign < 0);
      face(target, [ba, a, d, bd], sign < 0);
    };
    // 一个角仅一组：当前壁的右端与下一壁的左端跨棱连接，不能把两条臂重复计数。
    arm(side, 1);
    arm(adjacent, -1);
  }
}

function stud(target: ObjectMesh, side: number, u: number, y: number): void {
  const segments = 6, radius = 0.019;
  const tip = wallPoint(side, u, y, 0.024);
  for (let index = 0; index < segments; index++) {
    const a = index / segments * Math.PI * 2, b = (index + 1) / segments * Math.PI * 2;
    face(target, [wallPoint(side, u + radius * Math.cos(a), y + radius * Math.sin(a), 0.004),
      wallPoint(side, u + radius * Math.cos(b), y + radius * Math.sin(b), 0.004), tip]);
  }
}

function borderStuds(target: ObjectMesh): void {
  // 只以稀疏点状带说明“两侧边、近底端”，采样点数与排数均不对应二号鼎实物。
  // 乳钉独立于上腹八组位置片；足部不添加计数标记，避免把足部纹饰混进八组。
  for (let side = 0; side < 4; side++) {
    [-0.075, 0.025, 0.125, 0.225].forEach(y => {
      [-1, 1].forEach(sign => stud(target, side, sign * (halfAt(y) - 0.055), y));
    });
    [-0.6, -0.3, 0, 0.3, 0.6].forEach(fraction => stud(target, side, fraction * halfAt(-0.105), -0.105));
  }
}

function ear(target: ObjectMesh, side: number): void {
  const outer: EarPoint[] = [
    { z: -0.225, y: 0.548 }, { z: -0.225, y: 0.865 }, { z: -0.155, y: 0.955 },
    { z: 0.155, y: 0.955 }, { z: 0.225, y: 0.865 }, { z: 0.225, y: 0.548 }
  ];
  const inner: EarPoint[] = [
    { z: -0.135, y: 0.548 }, { z: -0.135, y: 0.835 }, { z: -0.105, y: 0.872 },
    { z: 0.105, y: 0.872 }, { z: 0.135, y: 0.835 }, { z: 0.135, y: 0.548 }
  ];
  const at = (point: EarPoint, outward: boolean): ObjectPoint => ({
    x: side * (0.616 + (outward ? 0.038 : -0.038)), y: point.y, z: point.z });
  // 两枚立耳各为有厚度的 U 形带，中央和下端保留空隙，不以实心横块冒充开口。
  // 局部轮廓已概括，不宣称复原立耳槽部的精确剖面。
  for (let index = 0; index < outer.length - 1; index++) {
    const next = index + 1;
    face(target, [at(outer[index], true), at(outer[next], true), at(inner[next], true), at(inner[index], true)], side < 0);
    face(target, [at(outer[index], false), at(inner[index], false), at(inner[next], false), at(outer[next], false)], side < 0);
    face(target, [at(outer[index], false), at(outer[next], false), at(outer[next], true), at(outer[index], true)], side < 0);
    face(target, [at(inner[index], false), at(inner[index], true), at(inner[next], true), at(inner[next], false)], side < 0);
  }
  face(target, [at(outer[0], false), at(outer[0], true), at(inner[0], true), at(inner[0], false)], side < 0);
  const last = outer.length - 1;
  face(target, [at(outer[last], false), at(inner[last], false), at(inner[last], true), at(outer[last], true)], side < 0);
}

function leg(target: ObjectMesh, x: number, z: number): void {
  const rings: LegRing[] = [
    { radius: 0.062, y: -0.93 }, { radius: 0.067, y: -0.895 },
    { radius: 0.09, y: -0.5 }, { radius: 0.112, y: -0.135 }
  ];
  const segments = 16;
  const at = (ring: LegRing, index: number): ObjectPoint => ({
    x: x + ring.radius * Math.cos(index / segments * Math.PI * 2), y: ring.y,
    z: z + ring.radius * Math.sin(index / segments * Math.PI * 2) });
  for (let row = 0; row < rings.length - 1; row++) {
    for (let index = 0; index < segments; index++) {
      face(target, [at(rings[row], index), at(rings[row + 1], index),
        at(rings[row + 1], index + 1), at(rings[row], index + 1)]);
    }
  }
  const lower: ObjectPoint[] = [], upper: ObjectPoint[] = [];
  for (let index = 0; index < segments; index++) {
    lower.push(at(rings[0], index)); upper.push(at(rings[rings.length - 1], index));
  }
  face(target, lower);
  face(target, upper, true);
}

export function dulingObservationShape(selectedId: string = ''): SiteObjectShape {
  const outer = mesh('duling-square-belly-exterior', '#789C90');
  const inner = mesh('duling-open-mouth-interior-and-floor', '#536C61');
  const rim = mesh('duling-outfolded-square-lip', '#A7B9A2');
  const ears = mesh('duling-two-open-upright-ears', '#8EA697');
  const legs = mesh('duling-four-tapered-round-column-legs', '#6D8D7E');
  const centers = mesh('duling-four-wall-center-position-markers', selectedId === 'centers' ? '#F0A3B5' : '#CF7A8E');
  const corners = mesh('duling-four-cross-corner-position-markers', selectedId === 'corners' ? '#F1BC7B' : '#C79363');
  const frame = mesh('duling-side-and-lower-stud-position-bands', selectedId === 'frame' ? '#EFDAAB' : '#A9B69B');
  // 固定光源下，俯视会使前腹壁较暗；仅给原创说明标记加阅读色阶，保持形体逐面明暗。
  // 色阶不是青铜合金、原始色彩或真实纹饰材质的判断，不随选中改变模型外形与取景边界。
  outer.tone = 1.2; inner.tone = 1.1; ears.tone = 1.15; legs.tone = 1.15;
  centers.tone = 1.65; corners.tone = 1.5; frame.tone = 1.35;
  vessel(outer, inner, rim);
  centerMarkers(centers);
  cornerMarkers(corners);
  borderStuds(frame);
  [-1, 1].forEach(side => ear(ears, side));
  [-1, 1].forEach(x => [-1, 1].forEach(z => leg(legs, x * 0.438, z * 0.438)));
  return { title: '杜岭二号方鼎 · 原创位置关系示意', meshes: [outer, inner, rim, ears, legs, centers, corners, frame] };
}
