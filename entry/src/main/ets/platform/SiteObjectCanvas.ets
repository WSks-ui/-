import { deviceInfo } from '@kit.BasicServicesKit';
import { SiteObjectShape, siteObjectShape } from '../domain/SiteObjectGeometry';
import { objectRasterFrame } from '../domain/SiteObjectRaster';

// 本轮模拟器实测原生 GPU 视口空白，并出现 DGLES / EGL 空指针。
// 当前 API 26 工程的 emulator 实例统一选择 CPU 兼容显示；不能把 canIUse=true
// 当成渲染已通过。升级镜像后，先补 GPU 证据再调整此条件。
// 真机仍走 Component3D；创建失败时也能复用同一网格进行原生 Canvas 绘制。
export function needsObjectCanvas(): boolean {
  return deviceInfo.displayVersion.toLowerCase().startsWith('emulator ') ||
    deviceInfo.productModel.trim().toLowerCase() === 'emulator';
}

export class SiteObjectCanvas {
  private shape: SiteObjectShape;
  private accent: string;

  constructor(type: string, accent: string) {
    this.shape = siteObjectShape(type);
    this.accent = accent;
  }

  draw(context: CanvasRenderingContext2D, width: number, height: number,
    yaw: number, pitch: number, dark: boolean): void {
    if (width <= 0 || height <= 0) return;
    context.clearRect(0, 0, width, height);
    const frame = objectRasterFrame(this.shape, this.accent, width, height, yaw, pitch);
    if (!frame.faces.length) return;
    // 阴影先于几何体绘制，并随取景后的模型底边定位。它仅表达示意光照，
    // 与 HDS 沉浸材质无关；用压扁的径向渐变避免实心椭圆造成贴纸外观。
    context.save();
    context.translate(width / 2, frame.shadowY);
    context.scale(1, 0.19);
    const shadow = context.createRadialGradient(0, 0, 0, 0, 0, frame.shadowRadius);
    shadow.addColorStop(0, dark ? 'rgba(0,0,0,0.30)' : 'rgba(45,25,20,0.16)');
    shadow.addColorStop(1, 'rgba(0,0,0,0)');
    context.fillStyle = shadow;
    context.beginPath();
    context.arc(0, 0, frame.shadowRadius, 0, Math.PI * 2);
    context.fill();
    context.restore();
    frame.faces.forEach(face => {
      context.beginPath();
      context.moveTo(face.points[0].x, face.points[0].y);
      for (let index = 1; index < face.points.length; index++) context.lineTo(face.points[index].x, face.points[index].y);
      context.closePath();
      context.fillStyle = face.color;
      context.strokeStyle = dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.08)';
      context.lineWidth = 0.5;
      context.fill();
      context.stroke();
    });
  }
}
