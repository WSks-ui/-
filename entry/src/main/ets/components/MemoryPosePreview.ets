import { MemoryPose } from '../domain/ArchiveDomain';
import { EXPLORATION_SECTIONS } from '../domain/CulturalContent';
import { CulturalEngineLayer, CulturalEnginePayload, CulturalSceneType } from '../domain/CulturalEngineContract';
import { resolveMemoryReplay } from '../domain/MemoryReplay';
import { CulturalNativeRenderer } from '../platform/CulturalNativeRenderer';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';

// 手账预览只重建已保存的原生取景：没有动画、手势或 Web，也不为旧笔记补造观察画面。
@Component
export struct MemoryPosePreview {
  @Prop @Watch('reload') siteId: string = '';
  @Prop @Watch('reload') poseJson: string = '';
  @Prop previewHeight: number = 200;
  @Prop previewId: string = 'memory-pose-preview';
  onOpen: () => void = () => {};
  @State private sourceReady: boolean = false;
  @State private frameReady: boolean = false;
  @State private frameDark: boolean = false;
  @State private emptyTitle: string = '这页保留文字记忆';
  @State private statusMessage: string = '没有保存观察画面，文字手账仍可阅读';
  private pose: MemoryPose | undefined = undefined;
  private payload: CulturalEnginePayload = { version: 1 };
  private painter: CulturalNativeRenderer = new CulturalNativeRenderer();
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private canvasReady: boolean = false;
  private disposed: boolean = false;
  private canvasWidth: number = 0;
  private canvasHeight: number = 0;
  private sourceWidth: number = 0;
  private sourceHeight: number = 0;
  private sourceTextDensity: number = 0;

  aboutToAppear(): void { this.disposed = false; this.reload(); }
  aboutToDisappear(): void { this.disposed = true; this.canvasReady = false; }

  private unavailable(title: string, message: string): void {
    this.sourceReady = false; this.frameReady = false; this.canvasReady = false;
    this.pose = undefined; this.emptyTitle = title; this.statusMessage = message;
  }

  private reload(): void {
    this.frameReady = false;
    try {
      const pose: MemoryPose | undefined = this.poseJson.trim() ? JSON.parse(this.poseJson) as MemoryPose : undefined;
      const resolution = resolveMemoryReplay(this.siteId, pose);
      if (!pose) {
        this.unavailable('这页保留文字记忆', resolution.message);
        return;
      }
      if (resolution.state !== 'ready' || !resolution.canReplay) {
        this.unavailable(resolution.state === 'legacy' ? '旧版手账未留原取景' : '保存的画面暂不能恢复', resolution.message);
        return;
      }
      const frame = resolution.viewFrame;
      // ready 必须包含原字体密度和深浅色。不能用当前设备偏好替代，否则另一端会把新画面当成旧取景。
      if (!frame || frame.textDensity === undefined || frame.dark === undefined) {
        this.unavailable('原取景信息不完整', '原取景的字体或配色未记录，文字手账仍可阅读');
        return;
      }
      this.pose = pose; this.sourceWidth = frame.width; this.sourceHeight = frame.height;
      this.sourceTextDensity = frame.textDensity; this.frameDark = frame.dark;
      this.payload = {
        version: 1, itemId: this.siteId, proceduralPreset: resolution.proceduralPreset,
        sceneRevision: resolution.sceneRevision,
        selectedId: pose.sceneType === 'stratum_slice' ? pose.sectionId : pose.hotspotId,
        layers: EXPLORATION_SECTIONS.map((section): CulturalEngineLayer => ({ id: section.id, label: section.title }))
      };
      this.statusMessage = '正在重建保存画面'; this.sourceReady = true;
      this.draw();
    } catch {
      this.unavailable('保存的视角数据无法读取', '这条记录的观察画面暂不能恢复，文字手账仍可阅读');
    }
  }

  private draw(): void {
    const pose = this.pose;
    if (this.disposed || !this.canvasReady || !this.sourceReady || !pose ||
      this.canvasWidth <= 0 || this.canvasHeight <= 0) return;
    let rendered: boolean = false;
    this.context.save();
    try {
      // 2026-10-17 已核对本机 API 26 Canvas 声明。先回到画布坐标清掉整个旧帧和留白，
      // 再将原虚拟画布等比 contain；draw 的内部 clearRect 也在同一变换和裁切内执行。
      // Raster 的边距、投影和热点依赖原宽高，不能把卡片尺寸传进去重新取景。
      this.context.setTransform(1, 0, 0, 1, 0, 0);
      this.context.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
      const scale = Math.min(this.canvasWidth / this.sourceWidth, this.canvasHeight / this.sourceHeight);
      this.context.translate((this.canvasWidth - this.sourceWidth * scale) / 2,
        (this.canvasHeight - this.sourceHeight * scale) / 2);
      this.context.scale(scale, scale);
      this.context.beginPath(); this.context.rect(0, 0, this.sourceWidth, this.sourceHeight); this.context.clip();
      this.painter.draw(this.context, pose.sceneType as CulturalSceneType, this.payload,
        this.sourceWidth, this.sourceHeight, pose.yaw, pose.pitch, pose.zoom, this.frameDark, 0, this.sourceTextDensity);
      rendered = this.painter.hasFrame;
    } catch {
      rendered = false;
    } finally {
      // 组件可被列表复用；任何绘制失败都必须归还变换、裁切及颜色状态，避免下一条手账继承旧取景。
      this.context.restore();
    }
    this.frameReady = rendered;
    this.statusMessage = rendered ? '已重建保存画面' : '保存画面暂不能重建，文字手账仍可阅读';
  }

  build() {
    Column({ space: 8 }) {
      if (this.sourceReady) {
        Stack() {
          Canvas(this.context).width('100%').height('100%').id(`${this.previewId}-canvas`)
            .onReady(() => { this.canvasReady = true; this.draw(); })
            .onAreaChange((_old: Area, area: Area) => {
              this.canvasWidth = Number(area.width); this.canvasHeight = Number(area.height); this.draw();
            })
          if (!this.frameReady) {
            Text('保存的观察画面').fontSize(F.small).fontColor(T.muted)
              .padding({ left: 14, right: 14, top: 8, bottom: 8 }).backgroundColor(T.soft).borderRadius(10)
          }
        }.width('100%').height(this.previewHeight).borderRadius(14).clip(true)
          // 保存时的主题属于画面的一部分；Canvas 内部清屏与 contain 留白都透出同一底色。
          .backgroundColor(this.frameDark ? '#171311' : '#FAF6F0')
          .accessibilityText('打开这条手账保存的观察视角').onClick(() => this.onOpen())
        Row({ space: 8 }) {
          Text(this.statusMessage).id(`${this.previewId}-status`).fontSize(F.caption).fontColor(T.muted)
            .layoutWeight(1)
          Text('程序化学习示意').fontSize(F.caption).fontColor(T.tertiary)
        }.width('100%').alignItems(VerticalAlign.Top)
      } else {
        Column({ space: 4 }) {
          Text(this.emptyTitle).fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.muted)
          Text(this.statusMessage).id(`${this.previewId}-status`).fontSize(F.caption).fontColor(T.muted).lineHeight(19)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(12)
          .backgroundColor(T.soft).borderRadius(12)
      }
    }.width('100%').id(this.previewId)
  }
}
