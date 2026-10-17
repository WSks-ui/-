import type { CultureGraphNode } from './CultureGraphData';
import type { GraphNodeState } from './CultureGraphLayout';

export interface SpatialNode { x: number; y: number; era: string; }
export interface WorldPoint { x: number; y: number; }
export interface SpatialPoint extends WorldPoint { z: number; scale: number; depth: number; perspective: number; }
export interface ProjectedNode extends CultureGraphNode, SpatialPoint {
  pinned: boolean; width: number; boxHeight: number; centerY: number;
}

function spaceClamp(value: number, min: number, max: number): number { return Math.max(min, Math.min(max, value)); }

export class GraphSpace {
  yaw: number = 0.24;
  pitch: number = -0.13;
  reset(): void { this.yaw = 0.24; this.pitch = -0.13; }
  rotate(dx: number, dy: number): void {
    this.yaw = spaceClamp(this.yaw + dx * 0.005, -1.05, 1.05);
    this.pitch = spaceClamp(this.pitch + dy * 0.005, -0.48, 0.48);
  }
  depth(era: string): number {
    if (era === '仰韶') return -120;
    if (era === '龙山') return -80;
    if (era === '夏商') return -40;
    if (era === '汉唐') return 40;
    if (era === '宋') return 80;
    return 0;
  }
  project(node: SpatialNode, width: number, height: number, nodeWidth: number = 84, fontScale: number = 1): SpatialPoint {
    const x = (node.x - width / 2) * 0.88, y = (node.y - height / 2) * 0.76, z = this.depth(node.era);
    const cy = Math.cos(this.yaw), sy = Math.sin(this.yaw), cx = Math.cos(this.pitch), sx = Math.sin(this.pitch);
    const rx = x * cy - z * sy, rz = x * sy + z * cy;
    const ry = y * cx - rz * sx, depth = y * sx + rz * cx;
    const focal = Math.max(680, height * 1.5, width * 1.7);
    const perspective = focal / Math.max(focal * 0.4, focal + depth);
    const scale = spaceClamp(perspective, 0.78, 1.22), half = nodeWidth * scale / 2 + 6;
    return { x: spaceClamp(width / 2 + rx * perspective, half, width - half),
      y: spaceClamp(height / 2 + ry * perspective, 52 + 14 * scale, height - 40 - 40 * fontScale * scale),
      scale, depth, z, perspective };
  }
  unproject(screenX: number, screenY: number, era: string, width: number, height: number): WorldPoint | null {
    const focal = Math.max(680, height * 1.5, width * 1.7);
    const u = (screenX - width / 2) / focal, v = (screenY - height / 2) / focal;
    const cy = Math.cos(this.yaw), sy = Math.sin(this.yaw), cx = Math.cos(this.pitch), sx = Math.sin(this.pitch), z = this.depth(era);
    const a = cy - u * sy * cx, b = -u * sx, c = -sy * sx - v * sy * cx, d = cx - v * sx;
    const e = z * sy + u * (focal + z * cy * cx), f = z * cy * sx + v * (focal + z * cy * cx);
    const determinant = a * d - b * c;
    if (Math.abs(determinant) < 0.05) return null;
    return { x: width / 2 + (e * d - b * f) / determinant / 0.88,
      y: height / 2 + (a * f - e * c) / determinant / 0.76 };
  }
  private bound(point: ProjectedNode, width: number, height: number): void {
    point.x = spaceClamp(point.x, point.width / 2 + 5, width - point.width / 2 - 5);
    point.centerY = spaceClamp(point.centerY, 52 + point.boxHeight / 2, height - 30 - point.boxHeight / 2);
  }
  frame(nodes: GraphNodeState[], width: number, height: number, nodeWidth: number, fontScale: number): ProjectedNode[] {
    const columns = nodes.length <= 2 ? Math.max(1, nodes.length) : (width >= 560 ? 4 : 3);
    const points = nodes.map((node: GraphNodeState): ProjectedNode => {
      const p = this.project(node, width, height, nodeWidth, fontScale);
      const boxWidth = Math.min(nodeWidth * p.scale, (width - 16) / columns - 5);
      const rows = Math.ceil(node.label.length * 10 * fontScale * p.scale / (boxWidth - 14)) || 1;
      const boxHeight = Math.max(52, 26 * p.scale + 10 + rows * 13.5 * fontScale * p.scale + 11.2 * fontScale * p.scale);
      return { id: node.id, label: node.label, city: node.city, era: node.era, accent: node.accent,
        x: p.x, y: p.y, scale: p.scale, depth: p.depth, z: p.z, perspective: p.perspective,
        pinned: node.pinned || node.dragged, width: boxWidth, boxHeight, centerY: p.y - 16 * p.scale + boxHeight / 2 };
    });
    for (let step = 0; step < 160; step++) {
      let overlap = false;
      for (let i = 0; i < points.length; i++) {
        const a = points[i];
        for (let j = i + 1; j < points.length; j++) {
          const b = points[j], dx = b.x - a.x, dy = b.centerY - a.centerY;
          const ox = (a.width + b.width) / 2 + 5 - Math.abs(dx), oy = (a.boxHeight + b.boxHeight) / 2 + 5 - Math.abs(dy);
          if (ox <= 0 || oy <= 0) continue;
          overlap = true;
          const shareA = a.pinned ? 0 : (b.pinned ? 1 : 0.5), shareB = 1 - shareA;
          const directionX = Math.sign(dx || (i % 2 ? -1 : 1));
          const roomX = directionX > 0 ? a.x - a.width / 2 - 5 + width - b.width / 2 - 5 - b.x
            : b.x - b.width / 2 - 5 + width - a.width / 2 - 5 - a.x;
          if (ox < oy && roomX >= ox) {
            const push = directionX * (ox + 0.1); a.x -= push * shareA; b.x += push * shareB;
          } else {
            const push = Math.sign(dy || 1) * (oy + 0.1); a.centerY -= push * shareA; b.centerY += push * shareB;
          }
          this.bound(a, width, height); this.bound(b, width, height);
        }
      }
      if (!overlap) break;
    }
    const overlaps = points.some((a, index) => points.slice(index + 1).some(b =>
      Math.abs(a.x - b.x) < (a.width + b.width) / 2 - 0.5 && Math.abs(a.centerY - b.centerY) < (a.boxHeight + b.boxHeight) / 2 - 0.5));
    // 用户主动移动的节点优先保持手势位置；不能为排齐标签把节点送回固定行。
    // 此时由其余标签避让并保留边界限制，拖动状态只在当前图谱会话内使用。
    if (overlaps && !points.some(point => point.pinned)) this.packRows(points, columns, width, height);
    points.forEach(point => { this.bound(point, width, height); point.y = point.centerY - point.boxHeight / 2 + 16 * point.scale; });
    return points.sort((a, b) => b.depth - a.depth);
  }
  private packRows(points: ProjectedNode[], columns: number, width: number, height: number): void {
    // 稠密视角下以投影顺序安排可读行，避免局部碰撞约束在边界反复挤压。
    const ordered = points.slice().sort((a, b) => a.centerY - b.centerY || a.x - b.x);
    const rows: ProjectedNode[][] = [];
    for (let start = 0; start < ordered.length; start += columns) rows.push(ordered.slice(start, start + columns).sort((a, b) => a.x - b.x));
    let rowHeights = rows.map(row => Math.max(...row.map(point => point.boxHeight)));
    const available = height - 82, needed = rowHeights.reduce((sum, value) => sum + value, 0) + (rows.length - 1) * 4;
    if (needed > available) {
      const factor = (available - (rows.length - 1) * 4) / (needed - (rows.length - 1) * 4);
      points.forEach(point => { point.boxHeight *= factor; point.scale *= factor; point.width *= factor; });
      rowHeights = rowHeights.map(value => value * factor);
    }
    const gapY = rows.length > 1 ? Math.max(4, (available - rowHeights.reduce((sum, value) => sum + value, 0)) / (rows.length - 1)) : 0;
    let top = 52;
    rows.forEach((row: ProjectedNode[], index: number) => {
      const gapX = (width - row.reduce((sum, point) => sum + point.width, 0)) / (row.length + 1);
      let left = gapX;
      row.forEach(point => { point.x = left + point.width / 2; point.centerY = top + rowHeights[index] / 2; left += point.width + gapX; });
      top += rowHeights[index] + gapY;
    });
  }
}
