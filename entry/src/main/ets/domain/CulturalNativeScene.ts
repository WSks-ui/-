import { siteObjectShape } from './SiteObjectGeometry';
import type { ObjectMesh, ObjectPoint, SiteObjectShape } from './SiteObjectGeometry';
import type { CulturalEnginePayload, CulturalSceneType } from './CulturalEngineContract';
import { materialObservationForPreset } from './MaterialObservation';
import { dahecunObservationShape } from './MaterialObservationGeometry';

export interface NativeEngineAnchor { id: string; label: string; type: string; point: ObjectPoint; }
export interface NativeCulturalScene { shape: SiteObjectShape; anchors: NativeEngineAnchor[]; }

function polygonMesh(name: string, color: string): ObjectMesh {
  return { name, color, vertices: [], normals: [], indices: [], faces: [], tone: 1 };
}
function face(mesh: ObjectMesh, points: ObjectPoint[]): void {
  const start = mesh.vertices.length;
  const a = points[0], b = points[1], c = points[2];
  const ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
  const vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
  const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
  const length = Math.hypot(nx, ny, nz) || 1;
  points.forEach(point => { mesh.vertices.push(point); mesh.normals.push({ x: nx / length, y: ny / length, z: nz / length }); });
  const indices = points.map((_point, index) => start + index);
  mesh.faces.push({ indices, tone: 1 });
  for (let i = 1; i < indices.length - 1; i++) mesh.indices.push(start, start + i, start + i + 1);
}
function box(name: string, x: number, y: number, z: number, sx: number, sy: number, sz: number, color: string): ObjectMesh {
  const mesh = polygonMesh(name, color);
  const points = [
    { x: x - sx, y: y - sy, z: z - sz }, { x: x + sx, y: y - sy, z: z - sz },
    { x: x + sx, y: y + sy, z: z - sz }, { x: x - sx, y: y + sy, z: z - sz },
    { x: x - sx, y: y - sy, z: z + sz }, { x: x + sx, y: y - sy, z: z + sz },
    { x: x + sx, y: y + sy, z: z + sz }, { x: x - sx, y: y + sy, z: z + sz }
  ];
  [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [3, 7, 6, 2], [0, 1, 5, 4]]
    .forEach(indices => face(mesh, indices.map(index => points[index])));
  return mesh;
}
function transform(source: ObjectMesh, name: string, x: number, y: number, z: number,
  scale: number, color: string): ObjectMesh {
  return { name, color, vertices: source.vertices.map(point => ({ x: point.x * scale + x,
    y: point.y * scale + y, z: point.z * scale + z })), normals: source.normals,
    indices: source.indices, faces: source.faces, tone: source.tone };
}
function frustum(name: string, radius: number, topRadius: number, low: number, high: number,
  color: string, sides: number = 8): ObjectMesh {
  const mesh = polygonMesh(name, color);
  const lower: ObjectPoint[] = [], upper: ObjectPoint[] = [];
  for (let i = 0; i < sides; i++) {
    const angle = i / sides * Math.PI * 2;
    lower.push({ x: radius * Math.cos(angle), y: low, z: radius * Math.sin(angle) });
    upper.push({ x: topRadius * Math.cos(angle), y: high, z: topRadius * Math.sin(angle) });
  }
  for (let i = 0; i < sides; i++) face(mesh, [lower[i], upper[i], upper[(i + 1) % sides], lower[(i + 1) % sides]]);
  face(mesh, upper.slice().reverse());
  face(mesh, lower);
  return mesh;
}
function relic(preset: string): SiteObjectShape {
  if (preset.includes('ding')) {
    const meshes: ObjectMesh[] = [box('body', 0, 0.12, 0, 0.58, 0.31, 0.4, '#5B8E8A')];
    [-1, 1].forEach(x => [-1, 1].forEach(z => meshes.push(box('leg', x * 0.44, -0.47, z * 0.29,
      0.08, 0.31, 0.08, '#426E67'))));
    [-1, 1].forEach(x => {
      meshes.push(box('handle', x * 0.43, 0.69, 0, 0.055, 0.055, 0.2, '#C88A4B'));
      [-1, 1].forEach(z => meshes.push(box('ear', x * 0.43, 0.56, z * 0.15, 0.055, 0.16, 0.05, '#C88A4B')));
    });
    return { title: '方鼎几何示意', meshes };
  }
  if (preset.includes('bronze')) {
    const meshes: ObjectMesh[] = [frustum('vessel', 0.4, 0.5, -0.04, 0.48, '#5B8E8A', 16)];
    for (let i = 0; i < 3; i++) {
      const angle = i / 3 * Math.PI * 2;
      meshes.push(box('foot', Math.cos(angle) * 0.28, -0.39, Math.sin(angle) * 0.28, 0.055, 0.38, 0.055, '#C88A4B'));
    }
    meshes.push(box('spout', 0.51, 0.49, 0, 0.3, 0.035, 0.13, '#688D7B'));
    meshes.push(box('tail', -0.48, 0.49, 0, 0.21, 0.035, 0.09, '#688D7B'));
    return { title: '三足礼器几何示意', meshes };
  }
  if (preset.includes('dragon') || preset.includes('xishuipo')) {
    const meshes = [box('excavation', 0, -0.4, 0, 0.9, 0.14, 0.6, '#C88A4B')];
    // 小贝壳使用低面数独立几何；避免把整座封土网格复制三十次，使模拟器持续绘制过重。
    const shell = frustum('shell', 0.75, 0.24, 0, 0.4, '#F3E6CF', 8);
    for (let i = 0; i < 30; i++) {
      const x = -0.77 + i / 29 * 1.54;
      meshes.push(transform(shell, 'shell', x, -0.21, Math.sin(i / 29 * Math.PI * 3) * 0.25, 0.065, '#F3E6CF'));
    }
    return { title: '蚌壳曲线几何示意', meshes };
  }
  if (preset.includes('pagoda')) {
    const meshes: ObjectMesh[] = [];
    for (let tier = 0; tier < 13; tier++) {
      const radius = 0.58 - tier * 0.033;
      const y = -0.78 + tier * 0.13;
      meshes.push(frustum(`tier-${tier}`, radius, radius * 0.78, y, y + 0.105, '#986F52'));
    }
    return { title: '层塔比例示意', meshes };
  }
  if (preset.includes('bridge')) {
    return { title: '桥梁空间示意', meshes: [
      box('bridge-deck', 0, 0.18, 0, 1.0, 0.12, 0.38, '#C88A4B'),
      box('bridge-pier-left', -0.7, -0.22, 0, 0.15, 0.34, 0.32, '#B48E67'),
      box('bridge-pier-right', 0.7, -0.22, 0, 0.15, 0.34, 0.32, '#B48E67'),
      box('water', 0, -0.58, 0, 1.13, 0.025, 0.6, '#5B8E8A')
    ] };
  }
  if (preset.includes('cliff')) {
    const meshes = [box('cliff', 0, 0, -0.17, 0.85, 0.65, 0.3, '#A88D6D')];
    for (let index = 0; index < 3; index++) {
      meshes.push(box('opening', -0.53 + index * 0.53, -0.03, 0.15, 0.17, 0.3, 0.025, '#5C4D46'));
    }
    return { title: '石窟崖面空间示意', meshes };
  }
  if (preset.includes('memorial')) {
    return { title: '纪念空间示意', meshes: [
      box('memorial-ground', 0, -0.52, 0, 0.82, 0.13, 0.6, '#C88A4B'),
      box('memorial-stele', 0, 0.05, 0, 0.35, 0.55, 0.12, '#5B8E8A'),
      box('memorial-cap', 0, 0.61, 0, 0.4, 0.06, 0.16, '#C45A6A')
    ] };
  }
  const type = preset.includes('mound') || preset.includes('guoguo') ? '墓葬群' :
    preset.includes('wall') || preset.includes('altar') || preset.includes('qicheng') ? '城址' :
    preset.includes('palace') || preset.includes('base') || preset.includes('city') || preset.includes('yingtianmen') ? '都城遗址' : '聚落遗址';
  return siteObjectShape(type);
}

export function nativeCulturalScene(type: CulturalSceneType, payload: CulturalEnginePayload): NativeCulturalScene {
  if (type === 'stratum_slice') {
    const meshes: ObjectMesh[] = [];
    const anchors: NativeEngineAnchor[] = [];
    const layers = payload.layers || [];
    const colors = ['#C45A6A', '#C88A4B', '#5B8E8A', '#B66B4A'];
    layers.forEach((layer, index) => {
      const selected = layer.id === payload.selectedId;
      const y = 0.65 - index * 0.42 + (selected ? 0.12 : 0);
      const mesh = box(layer.id, selected ? -0.14 : 0.05, y, selected ? 0.15 : 0,
        0.78, 0.12, 0.58, colors[index % colors.length]);
      mesh.opacity = selected ? 1 : 0.68;
      meshes.push(mesh);
      anchors.push({ id: layer.id, label: layer.label, type: 'layer', point: { x: 0.92, y, z: 0.38 } });
      const symbol = index === 0 || index === 2 ? siteObjectShape('都城遗址').meshes[2] : siteObjectShape('聚落遗址').meshes[0];
      meshes.push(transform(symbol, `${layer.id}-symbol`, -0.15, y + 0.22, 0, 0.18, '#F4D4AA'));
    });
    return { shape: { title: '四个阅读主题 · 空间示意', meshes }, anchors };
  }
  if (type === 'river_sandbox') {
    const terrain = polygonMesh('river-valley', '#D4B18B');
    const water = polygonMesh('river-water', '#C88A4B');
    const meshes = [terrain, water];
    const anchors: NativeEngineAnchor[] = [];
    const curve = (x: number): number => Math.sin(x * 2.4) * 0.24;
    // 河流只表达五城从西向东的浏览次序；高度和河湾是程序化沙盘，非测绘地形。
    for (let i = 0; i < 36; i++) {
      const left = -1.3 + i / 36 * 2.6, right = -1.3 + (i + 1) / 36 * 2.6;
      for (let row = 0; row < 8; row++) {
        const near = -0.7 + row / 8 * 1.4, far = -0.7 + (row + 1) / 8 * 1.4;
        const point = (x: number, z: number): ObjectPoint => ({ x, y: -0.32 + Math.abs(z) * 0.22 + Math.sin(x * 4 + z * 3) * 0.035, z: z + curve(x) });
        face(terrain, [point(left, near), point(left, far), point(right, far), point(right, near)]);
      }
      face(water, [{ x: left, y: -0.27, z: curve(left) - 0.075 }, { x: left, y: -0.27, z: curve(left) + 0.075 },
        { x: right, y: -0.27, z: curve(right) + 0.075 }, { x: right, y: -0.27, z: curve(right) - 0.075 }]);
    }
    (payload.nodes || []).forEach((node, index) => {
      const x = -1.06 + index * 0.53, z = curve(x) + (index % 2 ? -0.24 : 0.24);
      const selected = node.id === payload.selectedId;
      meshes.push(box(node.id, x, -0.05, z, 0.045, selected ? 0.27 : 0.17, 0.045, selected ? '#C45A6A' : '#5B8E8A'));
      anchors.push({ id: node.id, label: node.label, type: 'city', point: { x, y: selected ? 0.4 : 0.23, z } });
    });
    return { shape: { title: '五城河洛 · 程序化沙盘', meshes }, anchors };
  }
  // 仅明确的第 2 版双连壶启用新的观察模型；缺省 / 第 1 版仍保留旧单壶及旧热点供手账回放。
  const observation = type === 'relic_inspector' ? materialObservationForPreset(payload.proceduralPreset || '',
    payload.sceneRevision === undefined ? 1 : payload.sceneRevision) : undefined;
  if (observation) {
    return { shape: dahecunObservationShape(payload.selectedId || ''), anchors: observation.hotspots.map(hotspot => ({
      id: hotspot.id, label: hotspot.label, type: 'hotspot', point: hotspot.point
    })) };
  }
  return { shape: relic(payload.proceduralPreset || 'yangshao_pottery'), anchors: [
    { id: 'form', label: '形', type: 'hotspot', point: { x: -0.75, y: 0.2, z: 0.2 } },
    { id: 'pattern', label: '纹', type: 'hotspot', point: { x: 0.7, y: 0.1, z: 0.2 } },
    { id: 'story', label: '史', type: 'hotspot', point: { x: 0.3, y: -0.65, z: 0.3 } }
  ] };
}
