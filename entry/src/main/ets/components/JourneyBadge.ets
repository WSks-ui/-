import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

interface BadgeVertex { x: number; y: number; z: number; }
interface BadgeFace { points: BadgeVertex[]; depth: number; color: string; }

// 十二边柱、凸起内圈与逐面光照组成真正有厚度的低面数纪念章。
// 原生 Canvas 按需投影绘制，不依赖 PNG、ArkWeb 或持续旋转定时器。
@Component
export struct JourneyBadge {
  @Prop title: string = '';
  @Prop stamp: string = '';
  @Prop @Watch('draw') unlocked: boolean = false;
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private ready: boolean = false;
  private canvasWidth: number = 104;
  private canvasHeight: number = 96;

  private rotateVertex(point: BadgeVertex): BadgeVertex {
    const yaw = -0.42;
    const pitch = -0.24;
    const x = point.x * Math.cos(yaw) + point.z * Math.sin(yaw);
    const z = -point.x * Math.sin(yaw) + point.z * Math.cos(yaw);
    return {
      x,
      y: point.y * Math.cos(pitch) - z * Math.sin(pitch),
      z: point.y * Math.sin(pitch) + z * Math.cos(pitch)
    };
  }

  private ring(radius: number, depth: number): BadgeVertex[] {
    const points: BadgeVertex[] = [];
    for (let index = 0; index < 12; index++) {
      const angle = Math.PI / 12 + index * Math.PI / 6;
      points.push({ x: Math.cos(angle) * radius, y: Math.sin(angle) * radius, z: depth });
    }
    return points;
  }

  private addFace(faces: BadgeFace[], points: BadgeVertex[], base: number[], variation: number = 0): void {
    const rotated = points.map((point: BadgeVertex) => this.rotateVertex(point));
    const a = rotated[0]; const b = rotated[1]; const c = rotated[2];
    const ux = b.x - a.x; const uy = b.y - a.y; const uz = b.z - a.z;
    const vx = c.x - a.x; const vy = c.y - a.y; const vz = c.z - a.z;
    const nx = uy * vz - uz * vy; const ny = uz * vx - ux * vz; const nz = ux * vy - uy * vx;
    const length = Math.sqrt(nx * nx + ny * ny + nz * nz);
    if (length === 0 || nz <= 0) return;
    const light = Math.max(0, (-0.5 * nx + 0.7 * ny + nz) / (length * Math.sqrt(1.74)));
    const intensity = 0.55 + light * 0.45 + variation;
    const channels = base.map((channel: number) => Math.round(Math.max(0, Math.min(255, channel * intensity))));
    faces.push({
      points: rotated,
      depth: rotated.reduce((sum: number, point: BadgeVertex) => sum + point.z, 0) / rotated.length,
      color: `rgb(${channels[0]},${channels[1]},${channels[2]})`
    });
  }

  private draw(): void {
    if (!this.ready || this.canvasWidth <= 0 || this.canvasHeight <= 0) return;
    const context = this.context;
    const width = this.canvasWidth; const height = this.canvasHeight;
    context.clearRect(0, 0, width, height);
    const scale = Math.min(width / 104, height / 96);
    const outerFront = this.ring(39, 6);
    const outerBack = this.ring(39, -10);
    const innerFront = this.ring(30, 12);
    const faces: BadgeFace[] = [];
    const rim = this.unlocked ? [230, 177, 130] : [191, 190, 194];
    const side = this.unlocked ? [193, 132, 101] : [156, 155, 164];
    const face = this.unlocked ? [250, 217, 206] : [226, 224, 225];
    for (let index = 0; index < 12; index++) {
      const next = (index + 1) % 12;
      this.addFace(faces, [outerFront[index], outerBack[index], outerBack[next], outerFront[next]], side);
      this.addFace(faces, [outerFront[index], outerFront[next], innerFront[next], innerFront[index]], rim);
      this.addFace(faces, [{ x: 0, y: 0, z: 12 }, innerFront[index], innerFront[next]], face,
        index % 3 === 0 ? 0.025 : 0);
    }
    context.save();
    context.translate(width * 0.5, height * 0.91);
    context.scale(scale, scale * 0.16);
    const shadow = context.createRadialGradient(0, 0, 0, 0, 0, 33);
    shadow.addColorStop(0, 'rgba(91,56,58,0.17)');
    shadow.addColorStop(1, 'rgba(91,56,58,0)');
    context.fillStyle = shadow;
    context.beginPath(); context.arc(0, 0, 33, 0, Math.PI * 2); context.fill();
    context.restore();
    faces.sort((a: BadgeFace, b: BadgeFace) => a.depth - b.depth).forEach((item: BadgeFace) => {
      context.beginPath();
      item.points.forEach((point: BadgeVertex, index: number) => {
        const perspective = 240 / (240 - point.z);
        const x = width / 2 + point.x * perspective * scale;
        const y = height * 0.48 - point.y * perspective * scale;
        if (index === 0) context.moveTo(x, y); else context.lineTo(x, y);
      });
      context.closePath(); context.fillStyle = item.color; context.fill();
      context.strokeStyle = 'rgba(92,57,56,0.08)'; context.lineWidth = 0.5 * scale; context.stroke();
    });
  }

  build() {
    Column({ space: 2 }) {
      Stack() {
        Canvas(this.context).width(104).height(96).hitTestBehavior(HitTestMode.None)
          .onReady(() => { this.ready = true; this.draw(); })
          .onAreaChange((_old: Area, area: Area) => {
            this.canvasWidth = Number(area.width); this.canvasHeight = Number(area.height); this.draw();
          })
        Text(this.stamp).fontSize(25).fontWeight(FontWeight.Bold)
          .fontColor(this.unlocked ? '#A25B66' : '#89838C')
          .rotate({ angle: -7 }).scale({ x: 0.9, y: 0.96 }).translate({ x: -5, y: -4 })
          .hitTestBehavior(HitTestMode.None)
      }.width(104).height(96)
      Text(this.unlocked ? '已收入记忆' : '完成路线点亮').fontSize(F.caption)
        .fontColor(this.unlocked ? T.accent : T.muted).textAlign(TextAlign.Center)
    }.width(104).accessibilityText(`${this.title}纪念章，${this.unlocked ? '已点亮' : '尚未点亮'}`)
      .id(`journey-badge-${this.stamp}`)
  }
}
