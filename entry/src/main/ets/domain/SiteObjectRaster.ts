import type { ObjectPoint, SiteObjectShape } from './SiteObjectGeometry';

export interface ObjectFaceLight { normal: ObjectPoint; brightness: number; specular: number; }
export interface ObjectPaintedFace {
  points: ObjectPoint[];
  depth: number;
  color: string;
  light: ObjectFaceLight;
  opacity: number;
}
export interface ObjectRasterFrame {
  faces: ObjectPaintedFace[];
  totalFaces: number;
  culledFaces: number;
  shadowY: number;
  shadowRadius: number;
  scale: number;
  offsetX: number;
  offsetY: number;
}

function normalized(point: ObjectPoint): ObjectPoint {
  const length = Math.hypot(point.x, point.y, point.z) || 1;
  return { x: point.x / length, y: point.y / length, z: point.z / length };
}

const LIGHT = normalized({ x: 1.2, y: 2, z: 1.5 });
const HIGHLIGHT = normalized({ x: 0.4, y: 0.8, z: 1 });

export function rotateObjectPoint(point: ObjectPoint, yaw: number, pitch: number): ObjectPoint {
  const y = point.y * Math.cos(pitch) - point.z * Math.sin(pitch);
  const z = point.y * Math.sin(pitch) + point.z * Math.cos(pitch);
  return { x: point.x * Math.cos(yaw) + z * Math.sin(yaw), y,
    z: -point.x * Math.sin(yaw) + z * Math.cos(yaw) };
}

export function objectFaceLight(points: ObjectPoint[]): ObjectFaceLight {
  const a = points[0], b = points[1], c = points[2];
  const ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
  const vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
  // 法线来自旋转后的真实面边，不用插值顶点法线跨越城台 / 城墙的硬棱角。
  const normal = normalized({ x: uy * vz - uz * vy, y: uz * vx - ux * vz, z: ux * vy - uy * vx });
  const diffuse = Math.max(0, normal.x * LIGHT.x + normal.y * LIGHT.y + normal.z * LIGHT.z);
  const highlight = Math.max(0, normal.x * HIGHLIGHT.x + normal.y * HIGHLIGHT.y + normal.z * HIGHLIGHT.z);
  // 按任务书的定向高光公式实现；n·H 是 Blinn-Phong 形式的近似，非物理釉面材质。
  // 光源固定在观察空间，旋转几何体时面法线随之变化，亮斑不能贴在某一块面上。
  return { normal, brightness: 0.3 + 0.55 * diffuse, specular: 0.28 * Math.pow(highlight, 22) };
}

function faceColor(accent: string, tone: number, light: ObjectFaceLight): string {
  const hex = /^#[0-9a-fA-F]{6}$/.test(accent) ? accent : '#9B463E';
  const red = parseInt(hex.slice(1, 3), 16), green = parseInt(hex.slice(3, 5), 16), blue = parseInt(hex.slice(5, 7), 16);
  const channel = (value: number, warmth: number): number => Math.round(Math.min(255,
    Math.max(0, value * tone * light.brightness + light.specular * 255 * warmth)));
  return `rgb(${channel(red, 0.95)},${channel(green, 0.92)},${channel(blue, 0.88)})`;
}

export function objectRasterFrame(shape: SiteObjectShape, accent: string, width: number, height: number,
  yaw: number, pitch: number): ObjectRasterFrame {
  const frame: ObjectRasterFrame = { faces: [], totalFaces: 0, culledFaces: 0, shadowY: 0, shadowRadius: 0,
    scale: 1, offsetX: width / 2, offsetY: height / 2 };
  if (width <= 24 || height <= 46 || !Number.isFinite(width + height + yaw + pitch)) return frame;
  let minX = Number.POSITIVE_INFINITY, minY = Number.POSITIVE_INFINITY;
  let maxX = Number.NEGATIVE_INFINITY, maxY = Number.NEGATIVE_INFINITY;
  const focal = height * 1.8;
  shape.meshes.forEach(part => {
    const rotated = part.vertices.map(point => rotateObjectPoint(point, yaw, pitch));
    const projected = rotated.map((point: ObjectPoint): ObjectPoint => {
      const factor = focal / (3.3 - point.z);
      const result = { x: point.x * factor, y: -point.y * factor, z: point.z };
      minX = Math.min(minX, result.x); maxX = Math.max(maxX, result.x);
      minY = Math.min(minY, result.y); maxY = Math.max(maxY, result.y);
      return result;
    });
    part.faces.forEach(face => {
      frame.totalFaces++;
      const points = face.indices.map(index => projected[index]);
      const a = points[0], b = points[1], c = points[2];
      const winding = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
      // 相机在 +Z，投影将 Y 翻转为屏幕向下，因此正面为负绕序。
      // 剔除符号不能照抄 Y 向上 / 相机在 -Z 的示例，否则只剩内壁或背面。
      if (winding >= -1e-8) { frame.culledFaces++; return; }
      const light = objectFaceLight(face.indices.map(index => rotated[index]));
      frame.faces.push({ points, depth: points.reduce((sum, point) => sum + point.z, 0) / points.length,
        color: faceColor(part.color || accent, part.tone * face.tone, light), light, opacity: part.opacity ?? 1 });
    });
  });
  if (!frame.faces.length) return frame;
  frame.faces.sort((a, b) => a.depth - b.depth);
  // 取景使用完整网格边界，背面剔除前后与装饰纹带均不改变模型尺寸。
  const fit = Math.min(1, (width - 24) / Math.max(1, maxX - minX), (height - 46) / Math.max(1, maxY - minY));
  const centerX = (minX + maxX) / 2, centerY = (minY + maxY) / 2;
  frame.scale = fit;
  frame.offsetX = width / 2 - centerX * fit;
  frame.offsetY = height / 2 - 7 - centerY * fit;
  frame.faces.forEach(face => {
    face.points = face.points.map(point => ({ x: width / 2 + (point.x - centerX) * fit,
      y: height / 2 - 7 + (point.y - centerY) * fit, z: point.z }));
  });
  frame.shadowY = Math.min(height - 12, height / 2 - 7 + (maxY - centerY) * fit + 5);
  frame.shadowRadius = Math.min(width * 0.28, (maxX - minX) * fit * 0.48);
  return frame;
}
