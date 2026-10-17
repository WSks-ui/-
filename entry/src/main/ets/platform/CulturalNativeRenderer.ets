import { CulturalEnginePayload, CulturalSceneType } from '../domain/CulturalEngineContract';
import { NativeCulturalScene, nativeCulturalScene } from '../domain/CulturalNativeScene';
import { ObjectPoint } from '../domain/SiteObjectGeometry';
import { objectRasterFrame, rotateObjectPoint } from '../domain/SiteObjectRaster';

export interface CulturalHitTarget { id: string; type: string; x: number; y: number; radius: number; }

export class CulturalNativeRenderer {
  // 一帧真正画出模型面 / 图谱节点后才为 true，恢复视角与卡片预览据此报告成功。
  public hasFrame: boolean = false;
  private scene: NativeCulturalScene | undefined = undefined;
  private key: string = '';

  draw(context: CanvasRenderingContext2D, type: CulturalSceneType, payload: CulturalEnginePayload,
    width: number, height: number, yaw: number, pitch: number, zoom: number, dark: boolean,
    phase: number, textDensity: number = 1): CulturalHitTarget[] {
    this.hasFrame = false;
    context.clearRect(0, 0, width, height);
    if (width <= 24 || height <= 46) return [];
    if (type === 'constellation_graph') return this.graph(context, payload, width, height, yaw, pitch, zoom, dark, phase, textDensity);
    const key = JSON.stringify([type, payload.itemId, payload.proceduralPreset, payload.sceneRevision,
      payload.selectedId, payload.nodes, payload.layers]);
    if (this.key !== key) { this.scene = nativeCulturalScene(type, payload); this.key = key; }
    if (!this.scene) return [];
    const frame = objectRasterFrame(this.scene.shape, '#B66B4A', width, height, yaw, pitch);
    const targets: CulturalHitTarget[] = [];
    context.save();
    try {
      context.translate(width / 2, height / 2);
      context.scale(zoom, zoom);
      context.translate(-width / 2, -height / 2);
      context.fillStyle = dark ? 'rgba(0,0,0,0.22)' : 'rgba(65,38,25,0.08)';
      context.beginPath(); context.ellipse(width / 2, frame.shadowY, frame.shadowRadius, 8, 0, 0, Math.PI * 2); context.fill();
      frame.faces.forEach(face => {
        context.globalAlpha = face.opacity;
        context.beginPath();
        context.moveTo(face.points[0].x, face.points[0].y);
        face.points.slice(1).forEach(point => context.lineTo(point.x, point.y));
        context.closePath(); context.fillStyle = face.color; context.fill();
        context.strokeStyle = dark ? 'rgba(255,255,255,0.045)' : 'rgba(70,42,23,0.07)';
        context.lineWidth = 0.4; context.stroke();
      });
      context.globalAlpha = 1;
      this.scene.anchors.forEach(anchor => {
        const point = rotateObjectPoint(anchor.point, yaw, pitch);
        const factor = height * 1.8 / (3.3 - point.z);
        const rawX = point.x * factor * frame.scale + frame.offsetX;
        const rawY = -point.y * factor * frame.scale + frame.offsetY;
        const x = width / 2 + (rawX - width / 2) * zoom;
        const y = height / 2 + (rawY - height / 2) * zoom;
        targets.push({ id: anchor.id, type: anchor.type, x, y, radius: type === 'river_sandbox' ? 30 : 22 });
        const selected = payload.selectedId === anchor.id;
        context.beginPath(); context.arc(rawX, rawY, selected ? 7 : 5, 0, Math.PI * 2);
        context.fillStyle = selected ? '#C45A6A' : '#C88A4B'; context.fill();
        if (type === 'relic_inspector' && payload.sceneRevision === 2) {
          // 精细观察只给当前部位加注释牌，其余热点保留可点击圆点；三行标签同时压在器表会遮住纹饰。
          // 标签的宽高仍按原虚拟画幅计算，详情和手账等比重建时使用相同位置，不另做卡片排版。
          context.strokeStyle = dark ? '#342A25' : '#FFF9F3'; context.lineWidth = 1.3; context.stroke();
          if (selected) {
            const labelWidth = anchor.label.length * 11 + 18;
            const labelHeight = 24;
            const labelLeft = Math.max(5, Math.min(width - labelWidth - 5, rawX - labelWidth / 2));
            const labelTop = Math.max(5, rawY - labelHeight - 13);
            const labelRight = labelLeft + labelWidth;
            const labelBottom = labelTop + labelHeight;
            const radius = 6;
            context.beginPath(); context.moveTo(labelLeft + radius, labelTop);
            context.lineTo(labelRight - radius, labelTop);
            context.quadraticCurveTo(labelRight, labelTop, labelRight, labelTop + radius);
            context.lineTo(labelRight, labelBottom - radius);
            context.quadraticCurveTo(labelRight, labelBottom, labelRight - radius, labelBottom);
            context.lineTo(labelLeft + radius, labelBottom);
            context.quadraticCurveTo(labelLeft, labelBottom, labelLeft, labelBottom - radius);
            context.lineTo(labelLeft, labelTop + radius);
            context.quadraticCurveTo(labelLeft, labelTop, labelLeft + radius, labelTop);
            context.closePath();
            context.fillStyle = dark ? 'rgba(46,36,32,0.97)' : 'rgba(255,249,243,0.97)'; context.fill();
            context.strokeStyle = dark ? '#8F6C61' : '#DFC9B8'; context.lineWidth = 0.7; context.stroke();
            context.font = `${11 * textDensity}px sans-serif`; context.textAlign = 'center'; context.textBaseline = 'middle';
            context.fillStyle = dark ? '#F5ECE6' : '#704139';
            context.fillText(anchor.label, labelLeft + labelWidth / 2, labelTop + labelHeight / 2);
            context.textBaseline = 'alphabetic';
          }
          return;
        }
        if (type === 'river_sandbox') {
          // 流光仅来自可见动画相位，减少动态时 phase 不推进；没有传输或同步含义。
          context.beginPath(); context.arc(rawX, rawY, 9 + Math.sin(phase) * 2, 0, Math.PI * 2);
          context.strokeStyle = 'rgba(196,90,106,0.28)'; context.lineWidth = 1; context.stroke();
        }
        // 原生 Canvas 字体字符串使用物理 px；坐标以 vp 布局，字体需单独按设备密度与 fp 放大。
        context.font = `${11 * textDensity}px sans-serif`; context.textAlign = 'center';
        context.fillStyle = dark ? '#F5ECE6' : '#5C4D46';
        context.fillText(type === 'stratum_slice' ? `${anchor.label}` : anchor.label, rawX, rawY - 14);
      });
      this.hasFrame = frame.faces.length > 0;
    } finally {
      // 详情与手账缩略图会在外层设置取景 / 裁剪，即使某一帧绘制失败也必须归还自己的状态层。
      context.restore();
    }
    return targets;
  }

  private graph(context: CanvasRenderingContext2D, payload: CulturalEnginePayload, width: number,
    height: number, yaw: number, pitch: number, zoom: number, dark: boolean, phase: number, textDensity: number): CulturalHitTarget[] {
    const cities = ['三门峡', '洛阳', '郑州', '开封', '濮阳'];
    const eras = ['仰韶', '龙山', '夏商', '周', '汉唐', '宋'];
    const types = ['聚落遗址', '都城遗址', '城址', '墓葬群', '窑址', '古建筑'];
    const targets: CulturalHitTarget[] = [];
    (payload.nodes || []).forEach((node, index) => {
      const era = eras.indexOf(node.era || '');
      const point: ObjectPoint = { x: (Math.max(0, cities.indexOf(node.city || '')) - 2) * 0.46,
        y: (2.5 - Math.max(0, types.indexOf(node.type || ''))) * 0.22 + (index % 3) * 0.09,
        z: era < 0 ? 0 : (era - 2.5) * 0.24 };
      const rotated = rotateObjectPoint(point, yaw, pitch);
      const scale = Math.min(width * 0.38, height * 0.38) * zoom / (1.1 - rotated.z * 0.15);
      let x = width / 2 + rotated.x * scale, y = height / 2 - rotated.y * scale;
      x = Math.max(34, Math.min(width - 34, x));
      y = Math.max(34, Math.min(height - 34, y));
      // 标签在画布内避让，城市 / 类型 / 年代仍提供初始三维位置；不使用绝对定位正文控件。
      for (let attempt = 0; attempt < 14; attempt++) {
        if (!targets.some(target => Math.abs(target.x - x) < 62 && Math.abs(target.y - y) < 29)) break;
        y = 34 + ((y - 34 + 31) % (height - 68));
      }
      targets.push({ id: node.id, type: 'site', x, y, radius: 22 });
    });
    (payload.edges || []).forEach(edge => {
      const a = targets.find(node => node.id === edge.source), b = targets.find(node => node.id === edge.target);
      if (!a || !b) return;
      context.beginPath(); context.moveTo(a.x, a.y); context.quadraticCurveTo((a.x + b.x) / 2, (a.y + b.y) / 2 - 12, b.x, b.y);
      context.strokeStyle = edge.highlighted ? '#C88A4B' : (dark ? 'rgba(91,142,138,0.25)' : 'rgba(91,142,138,0.18)');
      context.lineWidth = edge.highlighted ? 2.5 : (payload.selectedId === a.id || payload.selectedId === b.id ? 1.3 : 0.6); context.stroke();
    });
    targets.forEach((target, index) => {
      const node = (payload.nodes || [])[index], selected = payload.selectedId === target.id;
      context.beginPath(); context.arc(target.x, target.y, selected ? 10 : 6, 0, Math.PI * 2);
      context.fillStyle = node.explored ? '#C88A4B' : (selected || node.highlighted ? '#C45A6A' : '#5B8E8A'); context.fill();
      if (selected || node.explored || node.highlighted) {
        context.beginPath(); context.arc(target.x, target.y, 13 + Math.sin(phase) * 1.5, 0, Math.PI * 2);
        context.strokeStyle = node.highlighted ? '#C88A4B' : 'rgba(200,138,75,0.4)';
        context.lineWidth = node.highlighted ? 2.3 : 1; context.stroke();
      }
      context.font = `${10 * textDensity}px sans-serif`; context.textAlign = 'center';
      context.fillStyle = dark ? '#F5ECE6' : '#5C4D46';
      context.fillText(node.label.length > 7 ? node.label.slice(0, 6) + '…' : node.label, target.x, target.y + 22);
    });
    this.hasFrame = targets.length > 0;
    return targets;
  }
}
