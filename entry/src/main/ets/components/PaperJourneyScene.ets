import { systemDateTime } from '@kit.BasicServicesKit';
import { PaperFold, PaperJudgment, PaperPoint, PaperWorkV1, PAPER_COLUMNS, PAPER_ROWS, createPaperWork,
  copyPaperWork, cutPaperStroke, paperCells, paperMaskFromCells, stampPaperSegment, judgePaper } from '../domain/PaperJourney';
import { PaperJourneyTheme as P } from './PaperJourneyTheme';

interface PaperSceneRect { x: number; y: number; width: number; height: number; }
interface PaperSceneView { left: number; top: number; columns: number; rows: number; rect: PaperSceneRect; }
interface PaperSceneEdge { start: PaperPoint; end: PaperPoint; used: boolean; }
interface PaperSceneTiming { count: number; p50: number; p95: number; }
interface PaperScenePerfReport {
  phase: string; inputs: number; frames: number; coalesced: number; maxPending: number;
  segments: number; geometryBuilds: number; staticBuilds: number; previewMatchesCommit: boolean;
  previewMs: PaperSceneTiming; drawIssueMs: PaperSceneTiming; judgeMs: PaperSceneTiming;
  cacheMs: PaperSceneTiming; inputWaitMs: PaperSceneTiming;
}

// 纸面始终以展开后的 40×48 空间解释。绘制时把相邻剪口合成轮廓，不把领域网格画给玩家。
// 折叠只改变当前可见的那一层与坐标映射；领域动作负责镜像，展开后才看见完整对称结果。
// 本组件不写存储：拖动预览在本地生成，抬手才一次 onStroke，由父页确认保存。
@Component
export struct PaperJourneyScene {
  @Prop @Watch('workChanged') work: PaperWorkV1 = createPaperWork('paper-smx', 0);
  @Prop @Watch('redraw') cityId: string = 'paper-smx';
  @Prop interactive: boolean = false;
  @Prop @Watch('presentationChanged') unfolded: boolean = true;
  @Prop @Watch('motionChanged') reducedMotion: boolean = false;
  @Prop brushRadius: number = 1.15;
  @Prop @Watch('redraw') showGuide: boolean = true;
  @Prop @Watch('observationChanged') observationMode: boolean = false;
  onStroke: (points: PaperPoint[]) => void = () => {};
  // 复杂底景、纸材面与轻动态分层。移光不重画背景/纸材，也不重建轮廓或重新判定。
  private backdropContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private underContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private faceContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private overlayContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private context: CanvasRenderer = this.overlayContext;
  private ready: boolean = false;
  private readyMask: number = 0;
  private visible: boolean = true;
  private widthVp: number = 360;
  private heightVp: number = 432;
  private points: PaperPoint[] = [];
  private preview: PaperWorkV1 | undefined = undefined;
  private previewCells: number[] = [];
  private previewBaseMask: string = '';
  private previewIndex: number = 0;
  private previewFold: PaperFold = 'none';
  private previewRadius: number = 1.15;
  private active: boolean = false;
  private frameTimer: number = -1;
  private lastFrameAt: number = 0;
  private scheduledAt: number = 0;
  private animating: boolean = false;
  private animationStarted: number = 0;
  private animationFromX: number = 1;
  private animationFromY: number = 1;
  private visualScaleX: number = 1;
  private visualScaleY: number = 1;
  private visualWidth: number = 780;
  private visualHeight: number = 936;
  private lastFold: string = 'none';
  // 光的位置属于当前观看方式，不进 work/schema，也不改变任何已冻结记忆。
  private lightX: number = 295;
  private lightY: number = 330;
  private lightDragging: boolean = false;
  private geometryMask: string = '';
  private geometryView: string = '';
  private cutPaths: PaperPoint[][] = [];
  private cutShape: Path2D = new Path2D();
  private paperShape: Path2D = new Path2D();
  private brokenShape: Path2D = new Path2D();
  private judgmentMask: string = '';
  private judgmentCity: string = '';
  private judgmentView: string = '';
  private cachedJudgment: PaperJudgment | undefined = undefined;
  private lastPreviewJudgmentAt: number = 0;
  private backdropImage: ImageBitmap | undefined = undefined;
  private deckImage: ImageBitmap | undefined = undefined;
  private artworkImage: ImageBitmap | undefined = undefined;
  private materialImage: ImageBitmap | undefined = undefined;
  private detailImage: ImageBitmap | undefined = undefined;
  private shadowImage: ImageBitmap | undefined = undefined;
  private backdropKey: string = '';
  private materialKey: string = '';
  private shadowKey: string = '';
  private faceDrawKey: string = '';
  private underDrawKey: string = '';
  // 用 AppStorage 临时开关采集，默认关闭；只在手势结束/销毁汇总，不逐帧打日志。
  @StorageProp('paperScenePerfEnabled') private debugPerf: boolean = false;
  private perfInputs: number = 0;
  private perfFrames: number = 0;
  private perfCoalesced: number = 0;
  private perfMaxPending: number = 0;
  private perfSegments: number = 0;
  private perfGeometry: number = 0;
  private perfStatic: number = 0;
  private perfPreviewMatch: boolean = true;
  private perfPreview: number[] = [];
  private perfDraw: number[] = [];
  private perfJudge: number[] = [];
  private perfCache: number[] = [];
  private perfWait: number[] = [];
  private perfReportPending: string = '';
  private readonly ART_WIDTH: number = 1000;
  private readonly ART_HEIGHT: number = 1200;
  private readonly SHEET_X: number = 110;
  private readonly SHEET_Y: number = 105;
  private readonly SHEET_WIDTH: number = 780;
  private readonly SHEET_HEIGHT: number = 936;

  aboutToAppear(): void {
    this.visible = true;
    this.lastFold = this.work.fold;
    this.visualWidth = this.view().rect.width; this.visualHeight = this.view().rect.height;
    this.draw();
  }
  aboutToDisappear(): void {
    this.visible = false; this.cancelFrame(); this.stopAnimation();
    this.active = false; this.lightDragging = false; this.points = []; this.previewCells = []; this.preview = undefined;
    this.reportPerformance('disappear'); this.releaseImages();
  }
  private stopAnimation(): void {
    this.animating = false; this.cancelFrame();
  }
  private workChanged(): void {
    // 父页回包替换作品时不能让旧预览继续往新 mask 上追加；已提交的 onStroke 仍只在抬手发一次。
    // 同一已存mask的时间确认不打断正在画的下一笔；真正换纸/新版本/折法变化才取消旧预览。
    const preview = this.preview;
    if (this.active && preview && preview.cityId === this.work.cityId &&
      this.work.mask === this.previewBaseMask && this.work.fold === this.previewFold) {
      preview.paper = this.work.paper; preview.light = this.work.light;
      this.draw(); return;
    }
    this.active = false; this.points = []; this.previewCells = []; this.previewIndex = 0; this.preview = undefined;
    if (this.lastFold !== this.work.fold) { this.lastFold = this.work.fold; this.presentationChanged(); }
    else this.redraw();
  }
  private observationChanged(): void {
    // 模式切换不能把尚未抬手的笔迹转交为剪口；移动光源与剪纸是互斥手势。
    this.cancelFrame(); this.active = false; this.points = []; this.previewCells = []; this.preview = undefined;
    this.lightDragging = false; this.draw();
  }
  private motionChanged(): void {
    if (this.reducedMotion) {
      this.stopAnimation(); this.visualScaleX = 1; this.visualScaleY = 1;
      this.visualWidth = this.view().rect.width; this.visualHeight = this.view().rect.height; this.draw();
    }
  }
  // 300ms 的折面收展只属于视觉：动画先取消未提交的手势，结束前不接受剪切。
  // mask 与折法由父页持有，不用动画中间帧写 progress，也不按压缩后的画面误映射剪口。
  private presentationChanged(): void {
    const rect = this.view().rect;
    const fromX = this.visualWidth / rect.width; const fromY = this.visualHeight / rect.height;
    this.cancelFrame(); this.stopAnimation(); this.active = false; this.points = []; this.previewCells = [];
    this.preview = undefined; this.lightDragging = false;
    if (!this.ready || this.reducedMotion) {
      this.visualScaleX = 1; this.visualScaleY = 1;
      this.visualWidth = rect.width; this.visualHeight = rect.height; this.draw(); return;
    }
    this.visualScaleX = fromX === 1 && fromY === 1 ? 0.96 : fromX;
    this.visualScaleY = fromY;
    this.animationFromX = this.visualScaleX; this.animationFromY = this.visualScaleY;
    this.animationStarted = Date.now(); this.animating = true; this.draw();
  }
  private redraw(): void { this.draw(); }
  private unit(): number { return Math.min(this.widthVp / this.ART_WIDTH, this.heightVp / this.ART_HEIGHT); }
  private offsetX(): number { return (this.widthVp - this.ART_WIDTH * this.unit()) * 0.5; }
  private offsetY(): number { return (this.heightVp - this.ART_HEIGHT * this.unit()) * 0.5; }
  private current(): PaperWorkV1 { return this.preview || this.work; }

  private view(): PaperSceneView {
    const fold = this.work.fold;
    const folded = !this.unfolded && fold !== 'none';
    const columns = folded ? PAPER_COLUMNS / 2 : PAPER_COLUMNS;
    const rows = folded && fold === 'quarter' ? PAPER_ROWS / 2 : PAPER_ROWS;
    const width = this.SHEET_WIDTH * columns / PAPER_COLUMNS;
    const height = this.SHEET_HEIGHT * rows / PAPER_ROWS;
    return { left: folded ? PAPER_COLUMNS / 2 : 0, top: folded && fold === 'quarter' ? PAPER_ROWS / 2 : 0,
      columns, rows, rect: { x: (this.ART_WIDTH - width) * 0.5,
        y: this.SHEET_Y + (this.SHEET_HEIGHT - height) * 0.5, width, height } };
  }

  // 手势和画面共用同一套 contain 缩放、居中偏移与折面映射，不能拿整屏宽度换算剪口。
  private pointAt(event: GestureEvent): PaperPoint | undefined {
    if (event.fingerList.length === 0 || this.unit() <= 0) return undefined;
    const finger = event.fingerList[0];
    const x = (finger.localX - this.offsetX()) / this.unit();
    const y = (finger.localY - this.offsetY()) / this.unit();
    const view = this.view(); const rect = view.rect;
    if (x < rect.x || x > rect.x + rect.width || y < rect.y || y > rect.y + rect.height) return undefined;
    // 领域以格心 0..39 / 0..47 插值，画面以格边 0..40 / 0..48 铺纸；
    // 这里减半格再归一，避免越靠右下剪口越偏离手指一格。
    return { x: Math.max(0, Math.min(1,
      (view.left + (x - rect.x) / rect.width * view.columns - 0.5) / (PAPER_COLUMNS - 1))),
      y: Math.max(0, Math.min(1,
        (view.top + (y - rect.y) / rect.height * view.rows - 0.5) / (PAPER_ROWS - 1))) };
  }

  private start(event: GestureEvent): void {
    if (!this.interactive || this.animating) return;
    this.beginPerformance();
    if (this.observationMode) { this.lightDragging = true; this.moveLight(event); return; }
    const point = this.pointAt(event);
    this.active = point !== undefined;
    this.points = point ? [point] : [];
    this.previewCells = point ? paperCells(this.work.mask) : [];
    this.previewBaseMask = this.work.mask;
    this.previewIndex = 0; this.previewFold = this.work.fold; this.previewRadius = this.brushRadius;
    this.preview = point ? copyPaperWork(this.work) : undefined;
    this.updatePreview();
  }

  private move(event: GestureEvent): void {
    if (!this.interactive || this.animating) return;
    if (this.observationMode) { if (this.lightDragging) this.moveLight(event); return; }
    if (!this.active) return;
    const point = this.pointAt(event);
    if (!point) {
      // 手指已划出纸面：这一笔到此为止，已划过的部分先按原领域动作提交。
      // 若只忽略纸外采样点，从纸外回来时会把前后两个纸内点连成没有划过的直线剪口。
      this.endStroke();
      return;
    }
    const previous = this.points[this.points.length - 1];
    if (previous && Math.abs(point.x - previous.x) + Math.abs(point.y - previous.y) < 0.003) return;
    this.points.push(point);
    this.updatePreview();
  }

  private updatePreview(): void {
    // 原始点仍完整留给抬手提交；帧内仅处理尚未落下的新段，不重放前面全部点。
    if (this.debugPerf) this.perfInputs++;
    this.draw();
  }

  private advancePreview(): void {
    if (!this.active || this.previewCells.length === 0 || this.previewIndex >= this.points.length) return;
    const started = this.perfNow();
    while (this.previewIndex < this.points.length) {
      const index = this.previewIndex++;
      stampPaperSegment(this.previewCells, index === 0 ? undefined : this.points[index - 1],
        this.points[index], this.previewRadius, this.previewFold);
      if (this.debugPerf) this.perfSegments++;
    }
    if (!this.preview) this.preview = copyPaperWork(this.work);
    this.preview.mask = paperMaskFromCells(this.previewCells);
    this.sample(this.perfPreview, started);
  }

  // 结束并提交当前笔迹：抬手、划出纸面共用；结束后不接受后续 move，直到新手势落下。
  private endStroke(): void {
    if (!this.active) return;
    // 收尾先消费最后未出帧的输入，调试时对照正式动作；不是把一个未绘制尾段漏掉。
    this.advancePreview();
    const points = this.points.slice();
    if (this.debugPerf && this.preview) {
      this.perfPreviewMatch = cutPaperStroke(this.work, points, this.previewRadius, this.work.updatedAt).work.mask === this.preview.mask;
    }
    this.active = false; this.points = []; this.previewCells = []; this.preview = undefined;
    if (points.length > 0) this.onStroke(points);
    this.perfReportPending = 'cut';
    this.draw();
  }

  private finish(event: GestureEvent | undefined = undefined): void {
    if (event) this.move(event);
    if (this.observationMode || this.lightDragging) {
      this.lightDragging = false; this.active = false; this.points = []; this.preview = undefined;
      this.perfReportPending = 'light'; this.draw(); return;
    }
    this.endStroke();
  }

  private tap(event: GestureEvent): void {
    if (!this.interactive || this.animating) return;
    if (this.observationMode) { this.moveLight(event); return; }
    const point = this.pointAt(event);
    if (point) this.onStroke([point]);
  }

  private cancel(): void {
    // 取消后不留下一次旧帧/动画继续绘制；恢复父页作品只同步画一次，不排新任务。
    this.cancelFrame(); this.stopAnimation(); this.active = false; this.points = []; this.previewCells = [];
    this.preview = undefined; this.lightDragging = false; this.visualScaleX = 1; this.visualScaleY = 1;
    this.visualWidth = this.view().rect.width; this.visualHeight = this.view().rect.height;
    this.renderFrame(); this.reportPerformance('cancel');
  }

  private moveLight(event: GestureEvent): void {
    if (event.fingerList.length === 0 || this.unit() <= 0) return;
    const finger = event.fingerList[0];
    this.lightX = Math.max(90, Math.min(910, (finger.localX - this.offsetX()) / this.unit()));
    this.lightY = Math.max(120, Math.min(1060, (finger.localY - this.offsetY()) / this.unit()));
    if (this.debugPerf) this.perfInputs++;
    // 只覆盖最新光位；同一待绘帧合并后只画一次，绝不排队回放已经过时的光点。
    this.draw();
  }

  private ellipse(x: number, y: number, rx: number, ry: number, color: string): void {
    const c = this.context; c.beginPath(); c.ellipse(x, y, rx, ry, 0, 0, Math.PI * 2); c.fillStyle = color; c.fill();
  }

  private line(x1: number, y1: number, x2: number, y2: number, color: string, width: number = 2): void {
    const c = this.context; c.beginPath(); c.moveTo(x1, y1); c.lineTo(x2, y2);
    c.strokeStyle = color; c.lineWidth = width; c.lineCap = 'round'; c.stroke();
  }

  private polygon(points: PaperPoint[], fill: string, stroke: string = ''): void {
    if (points.length === 0) return;
    const c = this.context; c.beginPath(); c.moveTo(points[0].x, points[0].y);
    for (let i = 1; i < points.length; i++) c.lineTo(points[i].x, points[i].y);
    c.closePath(); c.fillStyle = fill; c.fill();
    if (stroke) { c.strokeStyle = stroke; c.lineWidth = 2; c.stroke(); }
  }

  private ridge(y: number, rise: number, color: string, phase: number): void {
    const c = this.context; c.beginPath(); c.moveTo(-100, y + 100);
    c.bezierCurveTo(80, y - rise * 0.3, 130 + phase, y - rise, 300 + phase, y - rise * 0.5);
    c.bezierCurveTo(480, y + rise * 0.2, 630, y - rise * 0.9, 790, y - rise * 0.3);
    c.bezierCurveTo(880, y - rise * 0.5, 980, y + 40, 1100, y - 50);
    c.lineTo(1100, 1250); c.lineTo(-100, 1250); c.closePath(); c.fillStyle = color; c.fill();
  }

  private glow(x: number, y: number, radius: number, strength: number = 1): void {
    const c = this.context; const gradient = c.createRadialGradient(x, y, 0, x, y, radius);
    gradient.addColorStop(0, `rgba(247,181,87,${0.38 * strength})`);
    gradient.addColorStop(0.45, `rgba(211,140,60,${0.16 * strength})`);
    gradient.addColorStop(1, 'rgba(211,140,60,0)');
    c.fillStyle = gradient; c.fillRect(x - radius, y - radius, radius * 2, radius * 2);
  }

  private backdrop(): void {
    const c = this.context; const sky = c.createLinearGradient(0, 0, 1000, 1200);
    sky.addColorStop(0, '#0C1B29'); sky.addColorStop(0.57, '#163730'); sky.addColorStop(1, '#091B23');
    c.fillStyle = sky; c.fillRect(0, 0, 1000, 1200);
    this.glow(775, 230, 320, 0.48);
    this.ellipse(821, 154, 42, 42, '#E4C99B'); this.ellipse(807, 145, 42, 42, '#122C2B');
    for (let i = 0; i < 26; i++) {
      const x = 38 + (i * 137) % 923; const y = 42 + (i * 89) % 410;
      this.ellipse(x, y, i % 5 === 0 ? 2.2 : 1.1, i % 5 === 0 ? 2.2 : 1.1, 'rgba(239,213,164,0.52)');
    }
    this.ridge(390, 130, '#22473E', -45); this.ridge(580, 120, '#193A32', 15);
    this.ridge(900, 140, '#0D2629', 50);
    // 场景边缘有真实可辨的纸景，中央剪口则透出同一主题的另一层光色。
    c.save(); c.globalAlpha = 0.75; this.cityArtwork(false); c.restore();
    const water = c.createLinearGradient(0, 1040, 1000, 1200);
    water.addColorStop(0, 'rgba(50,105,96,0)'); water.addColorStop(1, 'rgba(22,72,68,0.75)');
    c.fillStyle = water; c.fillRect(0, 1000, 1000, 200);
    for (let i = 0; i < 7; i++) this.line(130 + i * 66, 1115 + i * 9,
      230 + i * 66, 1115 + i * 9, 'rgba(164,177,135,0.16)', 2);
  }

  private tree(x: number, y: number, scale: number, color: string): void {
    this.line(x, y, x, y - 80 * scale, '#476553', 6 * scale);
    this.polygon([{ x: x - 45 * scale, y: y - 24 * scale }, { x, y: y - 128 * scale },
      { x: x + 45 * scale, y: y - 24 * scale }], color);
    this.polygon([{ x: x - 38 * scale, y: y - 60 * scale }, { x, y: y - 151 * scale },
      { x: x + 38 * scale, y: y - 60 * scale }], color);
  }

  private roof(x: number, y: number, width: number, color: string): void {
    this.polygon([{ x: x - width * 0.6, y: y + 10 }, { x: x - width * 0.4, y: y - 17 },
      { x, y: y - 48 }, { x: x + width * 0.4, y: y - 17 }, { x: x + width * 0.6, y: y + 10 },
      { x: x + width * 0.34, y }, { x: x - width * 0.34, y }], color);
  }

  private courtyard(ink: boolean): void {
    const c = this.context;
    // 原创纸雕的地表与天井：外圈只有水平地表，四面内壁收向较小的庭心。
    // 不画向外垂下的盒体侧面；门洞落在内壁，台阶由地表下降，比例不作民居测绘。
    const ground: PaperPoint[] = [{ x: 156, y: 518 }, { x: 510, y: 329 },
      { x: 870, y: 509 }, { x: 502, y: 835 }];
    this.polygon(ground, ink ? '#E3D7B9' : '#A78D61');
    this.line(156, 518, 510, 329, ink ? '#FBF3DA' : '#D4BA83', 5);
    this.line(510, 329, 870, 509, ink ? '#F6E7C5' : '#C8A570', 4);
    const west: PaperPoint = { x: 237, y: 540 }; const north: PaperPoint = { x: 510, y: 405 };
    const east: PaperPoint = { x: 795, y: 536 }; const south: PaperPoint = { x: 503, y: 756 };
    const floorW: PaperPoint = { x: 340, y: 629 }; const floorN: PaperPoint = { x: 510, y: 550 };
    const floorE: PaperPoint = { x: 676, y: 625 }; const floorS: PaperPoint = { x: 503, y: 705 };
    this.polygon([west, north, east, south], ink ? '#786C51' : '#253E32');
    this.polygon([west, north, floorN, floorW], ink ? '#AF9470' : '#725F42');
    this.polygon([north, east, floorE, floorN], ink ? '#CFB58A' : '#997845');
    this.polygon([west, floorW, floorS, south], ink ? '#D8C59D' : '#B0915E');
    this.polygon([east, south, floorS, floorE], ink ? '#E8D8B5' : '#C19D64');
    this.polygon([floorW, floorN, floorE, floorS], ink ? '#F3E5C3' : '#D4AC6A');
    const shade = c.createLinearGradient(440, 542, 530, 719);
    shade.addColorStop(0, 'rgba(63,49,26,0.24)'); shade.addColorStop(0.65, 'rgba(73,51,28,0)');
    c.save(); c.beginPath(); c.moveTo(floorW.x, floorW.y); c.lineTo(floorN.x, floorN.y);
    c.lineTo(floorE.x, floorE.y); c.lineTo(floorS.x, floorS.y); c.closePath(); c.clip();
    c.fillStyle = shade; c.fillRect(325, 530, 380, 200);
    for (let i = 0; i < 5; i++) this.line(371 + i * 33, 654 - i * 15,
      526 + i * 24, 718 - i * 20, ink ? 'rgba(152,122,76,0.2)' : 'rgba(137,99,47,0.3)', 1.2);
    c.restore();
    for (let i = 0; i < 3; i++) {
      this.caveDoor(379 + i * 51, 610 - i * 24, -0.46, i === 1, ink);
      this.caveDoor(550 + i * 47, 568 + i * 21, 0.45, i === 0, ink);
    }
    // 前侧窄阶由地表伸入院心，每一级都有踏面与明边，避免误读为盒外装饰线。
    this.polygon([{ x: 270, y: 564 }, { x: 294, y: 548 }, { x: 402, y: 652 }, { x: 365, y: 670 }],
      ink ? '#C2AB80' : '#9A7F4F');
    for (let i = 0; i < 9; i++) {
      const t = i / 8; this.line(271 + t * 94, 565 + t * 104, 295 + t * 108, 550 + t * 102,
        ink ? '#F2E2BC' : '#D7B47A', 2.6);
    }
    this.line(west.x, west.y, north.x, north.y, ink ? '#F4E6C4' : '#D7B582', 5);
    this.line(north.x, north.y, east.x, east.y, ink ? '#FFF2D3' : '#E3C38A', 5);
    this.line(east.x, east.y, south.x, south.y, ink ? '#C7AF83' : '#A18150', 3);
    this.line(south.x, south.y, west.x, west.y, ink ? '#BFA47B' : '#8F7049', 3);
    this.paperTree(748, 467, 1.05, ink); this.paperTree(258, 438, 0.68, ink);
    this.ellipse(544, 662, 17, 5, ink ? 'rgba(124,100,57,0.23)' : 'rgba(44,45,27,0.26)');
    this.ellipse(540, 632, 6, 7, ink ? '#7F755B' : '#3B5140');
    this.polygon([{ x: 535, y: 642 }, { x: 545, y: 641 }, { x: 550, y: 662 }, { x: 532, y: 662 }],
      ink ? '#9C7F59' : '#527158');
    this.line(535, 664, 533, 675, ink ? '#85714E' : '#415B46', 2);
    this.line(546, 663, 550, 672, ink ? '#85714E' : '#415B46', 2);
    this.ellipse(609, 630, 13, 9, ink ? '#B18558' : '#9F6237');
    this.ellipse(609, 622, 7, 3, ink ? '#7D674A' : '#553E2B');
    this.line(705, 491, 759, 516, ink ? '#BCAD87' : '#8E865A', 2);
  }

  private caveDoor(x: number, y: number, slope: number, lit: boolean, ink: boolean): void {
    const c = this.context; c.save(); c.translate(x, y); c.transform(1, slope, 0, 1, 0, 0);
    c.beginPath(); c.moveTo(-17, 0); c.lineTo(-17, -34);
    c.bezierCurveTo(-17, -61, 17, -61, 17, -34); c.lineTo(17, 0); c.closePath();
    c.fillStyle = ink ? '#6B6750' : '#203C30'; c.fill();
    c.strokeStyle = ink ? '#D5BD91' : '#BA955E'; c.lineWidth = 3; c.stroke();
    if (lit) {
      c.beginPath(); c.rect(-9, -34, 18, 31); c.fillStyle = ink ? '#D5B67B' : '#E9BD73'; c.fill();
      this.line(0, -34, 0, -3, ink ? '#A48B5E' : '#A77B42', 2);
      this.line(-9, -20, 9, -20, ink ? '#A48B5E' : '#A77B42', 1.4);
    }
    this.line(-18, 2, 19, 2, ink ? '#F0DDB6' : '#B99C66', 3); c.restore();
  }

  private paperTree(x: number, y: number, scale: number, ink: boolean): void {
    const c = this.context; c.save(); c.translate(x, y); c.scale(scale, scale);
    this.ellipse(8, 8, 49, 11, ink ? 'rgba(101,103,68,0.14)' : 'rgba(3,23,24,0.25)');
    this.line(0, 0, -4, -80, ink ? '#9F9570' : '#526448', 6);
    this.line(-3, -43, -28, -82, ink ? '#9F9570' : '#526448', 3);
    this.line(-3, -57, 25, -96, ink ? '#9F9570' : '#526448', 3);
    for (let i = 0; i < 9; i++) {
      const angle = i * 2.4; const radius = 14 + i % 3 * 8;
      this.ellipse(Math.cos(angle) * radius, -94 + Math.sin(angle) * 22,
        27 - i % 3 * 3, 22 + i % 2 * 3, ink ? i % 2 === 0 ? '#9DA278' : '#BAC19A' :
          i % 2 === 0 ? '#57745A' : '#79906C');
    }
    this.line(-2, -45, -3, -94, ink ? 'rgba(114,116,76,0.4)' : 'rgba(51,76,50,0.6)', 2); c.restore();
  }

  private riverCliffs(ink: boolean): void {
    const c = this.context;
    this.polygon([{ x: 98, y: 880 }, { x: 150, y: 365 }, { x: 235, y: 298 },
      { x: 305, y: 454 }, { x: 380, y: 505 }, { x: 330, y: 1010 }], ink ? '#989A77' : '#3E6958');
    this.polygon([{ x: 633, y: 1009 }, { x: 664, y: 482 }, { x: 750, y: 342 },
      { x: 817, y: 441 }, { x: 902, y: 787 }, { x: 922, y: 1000 }], ink ? '#B5A57A' : '#345749');
    c.beginPath(); c.moveTo(467, 255); c.bezierCurveTo(382, 478, 615, 635, 437, 1050);
    c.lineTo(591, 1050); c.bezierCurveTo(725, 684, 451, 460, 528, 255); c.closePath();
    c.fillStyle = ink ? '#B3C0A3' : '#5A9C8C'; c.fill();
    for (let i = 0; i < 11; i++) {
      const x = i % 2 === 0 ? 217 + (i % 3) * 28 : 716 + (i % 3) * 21;
      const y = 472 + Math.floor(i / 2) * 72;
      c.beginPath(); c.moveTo(x - 15, y + 36); c.lineTo(x - 15, y);
      c.quadraticCurveTo(x, y - 26, x + 15, y); c.lineTo(x + 15, y + 36); c.closePath();
      c.fillStyle = ink ? '#6B7860' : '#173D35'; c.fill();
      this.ellipse(x, y + 9, 4, 6, ink ? '#D9C298' : '#CFA56A');
    }
    this.roof(253, 387, 94, ink ? '#7E8765' : '#263E35');
    this.tree(841, 909, 1.08, ink ? '#7E8C68' : '#214E42');
  }

  private twinVessel(ink: boolean): void {
    const c = this.context;
    for (let side = 0; side < 2; side++) {
      const x = side === 0 ? 362 : 638;
      c.beginPath(); c.moveTo(x - 65, 353); c.lineTo(x - 56, 463);
      c.bezierCurveTo(x - 151, 550, x - 157, 730, x - 83, 852);
      c.quadraticCurveTo(x, 888, x + 83, 852);
      c.bezierCurveTo(x + 157, 730, x + 151, 550, x + 56, 463);
      c.lineTo(x + 65, 353); c.closePath(); c.fillStyle = ink ? '#CB9575' : '#B67A54'; c.fill();
      this.ellipse(x, 353, 65, 16, ink ? '#92775D' : '#684D3A');
      this.ellipse(x, 350, 50, 9, ink ? '#EBD7B4' : '#263F35');
      for (let band = 0; band < 5; band++) {
        const y = 577 + band * 42;
        this.line(x - 101, y, x + 101, y, ink ? '#71644F' : '#433E32', 7);
        for (let i = 0; i < 4; i++) this.line(x - 75 + i * 48, y + 12,
          x - 75 + i * 48 + (side === 0 ? 0 : 13), y + 27, ink ? '#807056' : '#514531', 4);
      }
    }
    c.fillStyle = ink ? '#CB9575' : '#B67A54'; c.fillRect(439, 639, 122, 149);
    this.line(465, 677, 535, 677, ink ? '#7E6C50' : '#69533B', 5);
    this.line(465, 719, 535, 719, ink ? '#7E6C50' : '#69533B', 5);
    this.ellipse(500, 928, 263, 22, ink ? 'rgba(143,120,83,0.13)' : 'rgba(0,16,20,0.35)');
  }

  private lantern(x: number, y: number, radius: number, ink: boolean): void {
    const c = this.context; if (!ink) this.glow(x, y, radius * 3.5, 0.8);
    this.line(x, y - radius * 1.45, x, y - radius * 3.2, ink ? '#B7A274' : '#788365', 2);
    this.ellipse(x, y, radius * 0.78, radius, ink ? '#D5AF78' : '#E6AE63');
    for (let i = -1; i <= 1; i++) {
      c.beginPath(); c.moveTo(x + i * radius * 0.14, y - radius);
      c.quadraticCurveTo(x + i * radius * 0.68, y, x + i * radius * 0.14, y + radius);
      c.strokeStyle = ink ? '#AB8058' : '#B77C42'; c.lineWidth = 2; c.stroke();
    }
    this.line(x - radius * 0.3, y - radius, x + radius * 0.3, y - radius, ink ? '#8E7954' : '#CD9757', 5);
    this.line(x - radius * 0.3, y + radius, x + radius * 0.3, y + radius, ink ? '#8E7954' : '#CD9757', 5);
    this.line(x, y + radius, x, y + radius * 1.6, ink ? '#B89B68' : '#DBAD6A', 3);
    this.line(x - 8, y + radius * 1.6, x + 8, y + radius * 1.6, ink ? '#B89B68' : '#DBAD6A', 3);
  }

  private nightLanterns(ink: boolean): void {
    this.lantern(290, 361, 69, ink); this.lantern(715, 505, 97, ink); this.lantern(471, 699, 62, ink);
    const c = this.context;
    for (let i = 0; i < 5; i++) {
      const x = 157 + i * 175; const y = 1039 - (i % 2) * 55;
      c.fillStyle = ink ? '#C4B18D' : '#203D34'; c.fillRect(x - 64, y - 94, 128, 94);
      this.roof(x, y - 94, 130, ink ? '#8C9271' : '#304D3D');
      this.ellipse(x, y - 42, 11, 14, ink ? '#B9925E' : '#E1B16E');
    }
  }

  private shell(x: number, y: number, scale: number, angle: number, ink: boolean): void {
    const c = this.context; c.save(); c.translate(x, y); c.rotate(angle);
    c.beginPath(); c.moveTo(0, 9 * scale); c.bezierCurveTo(-19 * scale, -11 * scale,
      -12 * scale, -24 * scale, 0, -23 * scale);
    c.bezierCurveTo(12 * scale, -24 * scale, 19 * scale, -11 * scale, 0, 9 * scale);
    c.closePath(); c.fillStyle = ink ? '#D5C39D' : '#E6D7AE'; c.fill();
    this.line(0, 7 * scale, -6 * scale, -15 * scale, ink ? '#B7A178' : '#ACAA7F', scale);
    this.line(0, 7 * scale, 6 * scale, -15 * scale, ink ? '#B7A178' : '#ACAA7F', scale); c.restore();
  }

  private shellImage(ink: boolean): void {
    // 原创散片曲线，只借“离散材料形成整体”的关系，不摹写考古蚌塑形制与片数。
    for (let i = 0; i < 30; i++) {
      const t = i / 29; const x = 187 + t * 625; const y = 660 - Math.sin(t * Math.PI * 2.2) * 127;
      this.shell(x, y, 0.9 + i % 3 * 0.08, t * 2.5 - 0.9, ink);
    }
    for (let i = 0; i < 12; i++) {
      const t = i / 11; this.shell(232 + t * 495, 843 - Math.sin(t * Math.PI) * 74,
        0.65, -0.5 + t, ink);
    }
    this.shell(818, 612, 1.4, 0.8, ink); this.shell(839, 582, 0.8, 1.2, ink);
    this.tree(177, 958, 0.5, ink ? '#8F9A76' : '#355C4B');
  }

  private cityArtwork(ink: boolean): void {
    if (this.cityId === 'paper-ly') this.riverCliffs(ink);
    else if (this.cityId === 'paper-zz') this.twinVessel(ink);
    else if (this.cityId === 'paper-kf') this.nightLanterns(ink);
    else if (this.cityId === 'paper-py') this.shellImage(ink);
    else this.courtyard(ink);
  }

  private cellKey(point: PaperPoint): string { return `${point.x}:${point.y}`; }

  // 每个剪掉的格子只贡献接触留纸/外界的边，再按边的连接关系合成闭合轮廓。
  // 画面用曲线软化格点转角，领域判定仍使用原始 mask，视觉平滑不能反向改动实际剪口。
  private contours(cells: number[], view: PaperSceneView): PaperPoint[][] {
    const edges: PaperSceneEdge[] = []; const starts: Map<string, number[]> = new Map<string, number[]>();
    const cut = (x: number, y: number): boolean => x >= view.left && x < view.left + view.columns &&
      y >= view.top && y < view.top + view.rows && cells[y * PAPER_COLUMNS + x] === 1;
    const add = (x1: number, y1: number, x2: number, y2: number): void => {
      const edge: PaperSceneEdge = { start: { x: x1, y: y1 }, end: { x: x2, y: y2 }, used: false };
      const key = this.cellKey(edge.start); const indices = starts.get(key) || [];
      indices.push(edges.length); starts.set(key, indices); edges.push(edge);
    };
    for (let y = view.top; y < view.top + view.rows; y++) {
      for (let x = view.left; x < view.left + view.columns; x++) {
        if (!cut(x, y)) continue;
        if (!cut(x, y - 1)) add(x, y, x + 1, y);
        if (!cut(x + 1, y)) add(x + 1, y, x + 1, y + 1);
        if (!cut(x, y + 1)) add(x + 1, y + 1, x, y + 1);
        if (!cut(x - 1, y)) add(x, y + 1, x, y);
      }
    }
    const paths: PaperPoint[][] = [];
    for (let i = 0; i < edges.length; i++) {
      if (edges[i].used) continue;
      const path: PaperPoint[] = []; let current = i;
      for (let safety = 0; safety <= edges.length; safety++) {
        const edge = edges[current]; if (edge.used) break;
        edge.used = true; path.push(edge.start);
        const next = (starts.get(this.cellKey(edge.end)) || []).find((index: number) => !edges[index].used);
        if (next === undefined) break; current = next;
      }
      if (path.length > 2) paths.push(path);
    }
    return paths;
  }

  private traceContour(points: PaperPoint[], target: CanvasPath = this.context): void {
    if (points.length < 3) return;
    const c = target; const last = points[points.length - 1]; const first = points[0];
    c.moveTo((last.x + first.x) * 0.5, (last.y + first.y) * 0.5);
    for (let i = 0; i < points.length; i++) {
      const point = points[i]; const next = points[(i + 1) % points.length];
      c.quadraticCurveTo(point.x, point.y, (point.x + next.x) * 0.5, (point.y + next.y) * 0.5);
    }
    c.closePath();
  }

  private paperPath(paths: PaperPoint[][], view: PaperSceneView): Path2D {
    const c = new Path2D(); const x = view.left; const y = view.top;
    const w = view.columns; const h = view.rows;
    // 毛边幅度小于四分之一格，保留完整操作夹持框；只改变纸材轮廓，不补造任何剪口。
    c.moveTo(x + 0.12, y + 0.05);
    c.lineTo(x + w * 0.3, y + 0.09); c.lineTo(x + w * 0.63, y + 0.02);
    c.lineTo(x + w - 0.09, y + 0.1); c.lineTo(x + w - 0.03, y + h * 0.36);
    c.lineTo(x + w - 0.12, y + h * 0.7); c.lineTo(x + w - 0.05, y + h - 0.1);
    c.lineTo(x + w * 0.61, y + h - 0.04); c.lineTo(x + w * 0.27, y + h - 0.12);
    c.lineTo(x + 0.07, y + h - 0.03); c.lineTo(x + 0.13, y + h * 0.63);
    c.lineTo(x + 0.02, y + h * 0.3); c.closePath();
    paths.forEach((path: PaperPoint[]) => this.traceContour(path, c));
    return c;
  }

  private guide(): void {
    if (!this.showGuide) return;
    const c = this.context; c.save(); c.strokeStyle = 'rgba(126,109,67,0.34)'; c.lineWidth = 1.25;
    c.setLineDash([5, 9]); c.beginPath();
    if (this.cityId === 'paper-ly') {
      c.moveTo(497, 235); c.bezierCurveTo(407, 465, 605, 704, 493, 914);
    } else if (this.cityId === 'paper-zz') {
      c.moveTo(365, 276); c.bezierCurveTo(323, 465, 380, 757, 500, 743);
      c.moveTo(637, 276); c.bezierCurveTo(675, 465, 620, 757, 500, 743);
    } else if (this.cityId === 'paper-smx') {
      // 扫去中央纸面，而非沿一圈描边；闭环会制造与纸骨分离的纸岛。
      c.moveTo(405, 538); c.quadraticCurveTo(469, 526, 557, 540);
      c.moveTo(554, 582); c.quadraticCurveTo(473, 570, 403, 586);
      c.moveTo(411, 627); c.quadraticCurveTo(477, 615, 553, 629);
    } else if (this.cityId === 'paper-py') {
      for (let i = 0; i < 8; i++) {
        const t = i / 7; const x = 270 + t * 460; const y = 635 - Math.sin(t * Math.PI * 2) * 105;
        c.moveTo(x - 10, y + 4); c.quadraticCurveTo(x, y - 5, x + 10, y - 4);
      }
    } else {
      c.moveTo(327, 435); c.quadraticCurveTo(348, 414, 375, 432);
      c.moveTo(625, 550); c.quadraticCurveTo(646, 527, 674, 542);
      c.moveTo(421, 771); c.quadraticCurveTo(443, 750, 470, 768);
    }
    c.stroke(); c.setLineDash([]);
    if (this.cityId === 'paper-smx') {
      this.line(548, 533, 558, 540, 'rgba(126,109,67,0.45)', 1.6);
      this.line(558, 540, 547, 546, 'rgba(126,109,67,0.45)', 1.6);
      this.line(412, 578, 402, 586, 'rgba(126,109,67,0.45)', 1.6);
      this.line(402, 586, 415, 590, 'rgba(126,109,67,0.45)', 1.6);
    }
    c.restore();
  }

  private maskProjection(paths: PaperPoint[][], view: PaperSceneView): void {
    if (!this.observationMode || paths.length === 0) return;
    const c = this.context; const cell = this.SHEET_WIDTH / PAPER_COLUMNS;
    const dx = (500 - this.lightX) * 0.15;
    const dy = 48 + (573 - this.lightY) * 0.13;
    // 投影只重用这一张纸的真实剪口闭合轮廓：位移、轻微放大与光源方向对应。
    // 不预置文化图案或成功光纹；没剪的纸没有镂光投影，断纸反馈也不因此改写。
    c.save(); c.translate(view.rect.x + dx, view.rect.y + dy); c.scale(cell, cell);
    c.translate(-view.left, -view.top);
    const light = c.createRadialGradient((this.lightX - view.rect.x) / cell + view.left,
      (this.lightY - view.rect.y) / cell + view.top, 0,
      (this.lightX - view.rect.x) / cell + view.left,
      (this.lightY - view.rect.y) / cell + view.top, 49);
    light.addColorStop(0, 'rgba(255,224,152,0.88)');
    light.addColorStop(0.45, 'rgba(248,187,91,0.65)'); light.addColorStop(1, 'rgba(226,149,61,0.12)');
    c.shadowColor = 'rgba(239,166,67,0.66)'; c.shadowBlur = 0.9;
    c.fillStyle = light; c.fill(this.cutShape, 'evenodd'); c.shadowBlur = 0;
    c.strokeStyle = 'rgba(255,230,177,0.35)'; c.lineWidth = 0.13; c.stroke(this.cutShape); c.restore();
  }

  private lightHandle(): void {
    if (!this.observationMode) return;
    const c = this.context;
    this.glow(this.lightX, this.lightY, 102, 1.1);
    c.beginPath(); c.arc(this.lightX, this.lightY, 18, 0, Math.PI * 2);
    c.strokeStyle = '#FFF0C0'; c.lineWidth = 2; c.stroke();
    this.ellipse(this.lightX, this.lightY, 6, 6, '#FFF6D9');
    this.line(this.lightX - 29, this.lightY, this.lightX - 23, this.lightY, '#E8B879', 2);
    this.line(this.lightX + 23, this.lightY, this.lightX + 29, this.lightY, '#E8B879', 2);
    this.line(this.lightX, this.lightY - 29, this.lightX, this.lightY - 23, '#E8B879', 2);
    this.line(this.lightX, this.lightY + 23, this.lightX, this.lightY + 29, '#E8B879', 2);
  }

  private projectionGround(paths: PaperPoint[][], view: PaperSceneView): void {
    if (!this.observationMode || paths.length === 0) return;
    const c = this.context;
    // 下方是一块可见的承光面。完整 mask 投影压到地面透视里，避免中部剪口的
    // 投影全被纸面遮住而只剩换色；投影仍逐条使用实际轮廓，没有内置结果图案。
    c.save(); c.translate(500 + (500 - this.lightX) * 0.18, 1098 + (573 - this.lightY) * 0.035);
    c.transform(1, -0.035, 0.24, 0.16, 0, 0);
    c.beginPath(); c.rect(-338, -335, 676, 670);
    c.fillStyle = 'rgba(13,31,35,0.8)'; c.fill();
    c.strokeStyle = 'rgba(184,157,104,0.18)'; c.lineWidth = 2; c.stroke();
    c.scale(this.SHEET_WIDTH / PAPER_COLUMNS * 0.78, this.SHEET_WIDTH / PAPER_COLUMNS * 0.78);
    c.translate(-view.left - view.columns * 0.5, -view.top - view.rows * 0.5);
    c.fillStyle = '#F1C67F'; c.shadowColor = 'rgba(235,168,69,0.78)'; c.shadowBlur = 0.9;
    c.fill(this.cutShape, 'evenodd'); c.shadowBlur = 0;
    c.strokeStyle = 'rgba(255,239,199,0.74)'; c.lineWidth = 0.18; c.stroke(this.cutShape); c.restore();
  }

  private perfNow(): number {
    return this.debugPerf ? systemDateTime.getUptime(systemDateTime.TimeType.STARTUP, true) / 1000000 : 0;
  }

  private sample(values: number[], started: number): void {
    if (!this.debugPerf) return;
    values.push(this.perfNow() - started);
    if (values.length > 512) values.shift();
  }

  private timing(values: number[]): PaperSceneTiming {
    const sorted = values.slice().sort((a: number, b: number) => a - b);
    // 毫秒保留三位已足够区分本轮阻塞；长浮点会让整条HiLog在最后一组统计处截断。
    return { count: sorted.length,
      p50: sorted.length > 0 ? Math.round(sorted[Math.floor(sorted.length * 0.5)] * 1000) / 1000 : 0,
      p95: sorted.length > 0 ? Math.round(sorted[Math.min(sorted.length - 1,
        Math.floor(sorted.length * 0.95))] * 1000) / 1000 : 0 };
  }

  private beginPerformance(): void {
    if (!this.debugPerf) return;
    this.perfInputs = 0; this.perfFrames = 0; this.perfCoalesced = 0; this.perfMaxPending = 0;
    this.perfSegments = 0; this.perfGeometry = 0; this.perfStatic = 0; this.perfPreviewMatch = true;
    this.perfPreview = []; this.perfDraw = []; this.perfJudge = []; this.perfCache = []; this.perfWait = [];
    this.perfReportPending = '';
  }

  private reportPerformance(phase: string): void {
    if (!this.debugPerf || (this.perfInputs === 0 && this.perfFrames === 0)) {
      this.perfReportPending = ''; return;
    }
    const report: PaperScenePerfReport = { phase, inputs: this.perfInputs, frames: this.perfFrames,
      coalesced: this.perfCoalesced, maxPending: this.perfMaxPending, segments: this.perfSegments,
      geometryBuilds: this.perfGeometry, staticBuilds: this.perfStatic, previewMatchesCommit: this.perfPreviewMatch,
      previewMs: this.timing(this.perfPreview), drawIssueMs: this.timing(this.perfDraw),
      judgeMs: this.timing(this.perfJudge), cacheMs: this.timing(this.perfCache), inputWaitMs: this.timing(this.perfWait) };
    // drawIssueMs 是发出原生绘制命令的CPU耗时，不冒充GPU完成或实际掉帧统计。
    console.info(`PAPER_SCENE_PERF:${JSON.stringify(report)}`);
    this.perfReportPending = '';
  }

  private cancelFrame(): void {
    if (this.frameTimer >= 0) clearTimeout(this.frameTimer);
    this.frameTimer = -1;
  }

  private draw(): void {
    if (!this.ready || !this.visible || this.widthVp <= 0 || this.heightVp <= 0) return;
    if (this.frameTimer >= 0) { if (this.debugPerf) this.perfCoalesced++; return; }
    this.scheduledAt = this.perfNow();
    // 只保留一个待绘任务。点列完整保留以保证曲线，光位覆盖为最新值；不排每次move的旧画面。
    this.frameTimer = setTimeout(() => {
      this.frameTimer = -1;
      if (!this.visible) return;
      this.sample(this.perfWait, this.scheduledAt); this.renderFrame();
    }, Math.max(0, 16 - (Date.now() - this.lastFrameAt)));
    if (this.debugPerf) this.perfMaxPending = Math.max(this.perfMaxPending, 1);
  }

  private viewKey(view: PaperSceneView): string {
    return `${view.left}:${view.top}:${view.columns}:${view.rows}`;
  }

  private geometry(work: PaperWorkV1, view: PaperSceneView): void {
    const key = this.viewKey(view);
    if (this.geometryMask === work.mask && this.geometryView === key) return;
    const cells = this.active && this.preview ? this.previewCells : paperCells(work.mask);
    this.cutPaths = this.contours(cells, view);
    this.cutShape = new Path2D();
    this.cutPaths.forEach((path: PaperPoint[]) => this.traceContour(path, this.cutShape));
    this.paperShape = this.paperPath(this.cutPaths, view);
    this.geometryMask = work.mask; this.geometryView = key;
    if (this.debugPerf) this.perfGeometry++;
  }

  private judgment(work: PaperWorkV1, view: PaperSceneView): void {
    const now = Date.now();
    const same = this.judgmentMask === work.mask && this.judgmentCity === work.cityId;
    // 连续划剪只在合帧后最多约10次/秒更新断纸提示；结束后按正式mask立即更新。
    // 不在原始move或绘制各图层里做全纸连通判定，移光更不会重新judge。
    if (!same && (!this.active || !this.cachedJudgment || now - this.lastPreviewJudgmentAt >= 96)) {
      const started = this.perfNow();
      this.cachedJudgment = judgePaper(work); this.judgmentMask = work.mask; this.judgmentCity = work.cityId;
      this.lastPreviewJudgmentAt = now; this.judgmentView = ''; this.sample(this.perfJudge, started);
    }
    const key = this.viewKey(view);
    if (this.judgmentView === key) return;
    this.brokenShape = new Path2D();
    const broken = this.cachedJudgment?.brokenCells || [];
    if (broken.length > 0) {
      const cells: number[] = new Array<number>(PAPER_COLUMNS * PAPER_ROWS).fill(0);
      broken.forEach((index: number) => { cells[index] = 1; });
      this.contours(cells, view).forEach((path: PaperPoint[]) => this.traceContour(path, this.brokenShape));
    }
    this.judgmentView = key;
  }

  private artContext(context: CanvasRenderer, pose: boolean): void {
    context.clearRect(0, 0, this.widthVp, this.heightVp); context.save();
    context.translate(this.offsetX(), this.offsetY()); context.scale(this.unit(), this.unit());
    if (pose) {
      context.translate(500, this.SHEET_Y + this.SHEET_HEIGHT * 0.5);
      context.scale(this.visualScaleX, this.visualScaleY);
      context.translate(-500, -this.SHEET_Y - this.SHEET_HEIGHT * 0.5);
    }
  }

  private sheetContext(view: PaperSceneView): void {
    this.context.translate(view.rect.x, view.rect.y);
    this.context.scale(this.SHEET_WIDTH / PAPER_COLUMNS, this.SHEET_WIDTH / PAPER_COLUMNS);
    this.context.translate(-view.left, -view.top);
  }

  private sheetToArt(view: PaperSceneView): void {
    this.context.translate(view.left, view.top);
    this.context.scale(PAPER_COLUMNS / this.SHEET_WIDTH, PAPER_COLUMNS / this.SHEET_WIDTH);
    this.context.translate(-view.rect.x, -view.rect.y);
  }

  private blit(image: ImageBitmap | undefined): void {
    if (!image) return;
    // 缓存按实际组件vp尺寸生成，使用同一contain矩阵还原；没有降低分辨率或更换手势映射。
    const unit = this.unit();
    this.context.drawImage(image, -this.offsetX() / unit, -this.offsetY() / unit,
      this.widthVp / unit, this.heightVp / unit);
  }

  private image(paint: () => void): ImageBitmap {
    const started = this.perfNow(); const previous = this.context;
    const surface = new OffscreenCanvas(this.widthVp, this.heightVp);
    const context = surface.getContext('2d', new RenderingContextSettings(true));
    this.context = context;
    this.artContext(context, false);
    paint(); context.restore();
    const result = surface.transferToImageBitmap();
    this.context = previous;
    if (this.debugPerf) this.perfStatic++;
    this.sample(this.perfCache, started); return result;
  }

  private releaseImages(): void {
    this.backdropImage?.close(); this.deckImage?.close(); this.artworkImage?.close();
    this.materialImage?.close(); this.detailImage?.close(); this.shadowImage?.close();
    this.backdropImage = undefined; this.deckImage = undefined; this.artworkImage = undefined;
    this.materialImage = undefined; this.detailImage = undefined; this.shadowImage = undefined;
    this.backdropKey = ''; this.materialKey = ''; this.shadowKey = ''; this.faceDrawKey = ''; this.underDrawKey = '';
  }

  private paintDeck(view: PaperSceneView): void {
    const c = this.context; const rect = view.rect;
    c.fillStyle = '#B4A88A'; c.fillRect(rect.x - 7, rect.y + 10, rect.width + 3, rect.height);
    c.fillStyle = '#DACDAE'; c.fillRect(rect.x + 3, rect.y + 5, rect.width, rect.height + 2);
    this.line(rect.x + 7, rect.y + rect.height + 9, rect.x + rect.width - 12,
      rect.y + rect.height + 9, 'rgba(252,235,195,0.45)', 1.5);
    if (!this.unfolded && this.work.fold !== 'none') {
      const layers = this.work.fold === 'quarter' ? 4 : 2;
      for (let i = layers; i > 0; i--) {
        c.fillStyle = i % 2 === 0 ? '#BBAE90' : '#D9C8A4';
        c.fillRect(rect.x - i * 4, rect.y + i * 5, rect.width, rect.height);
      }
    }
  }

  private paintArtwork(view: PaperSceneView, illuminated: boolean): void {
    const c = this.context; const rect = view.rect;
    c.save(); c.beginPath(); c.rect(rect.x, rect.y, rect.width, rect.height); c.clip();
    const glow = c.createLinearGradient(rect.x, rect.y, rect.x + rect.width, rect.y + rect.height);
    glow.addColorStop(0, illuminated ? '#F5CF8E' : '#355F53');
    glow.addColorStop(0.5, illuminated ? '#D8964B' : '#214D45');
    glow.addColorStop(1, illuminated ? '#89643F' : '#112E32');
    c.fillStyle = glow; c.fillRect(rect.x, rect.y, rect.width, rect.height);
    c.globalAlpha = illuminated ? 0.93 : 0.65; this.cityArtwork(false); c.restore();
  }

  private paintMaterial(work: PaperWorkV1, view: PaperSceneView, illuminated: boolean): void {
    const c = this.context; c.save(); this.sheetContext(view);
    const paper = c.createLinearGradient(0, 0, PAPER_COLUMNS, PAPER_ROWS);
    paper.addColorStop(0, '#FCF4E0'); paper.addColorStop(0.5, P.paper); paper.addColorStop(1, '#DDCFB0');
    c.fillStyle = paper; c.fillRect(view.left, view.top, view.columns, view.rows);
    c.globalAlpha = 0.13; c.fillStyle = work.paper; c.fillRect(0, 0, PAPER_COLUMNS, PAPER_ROWS); c.globalAlpha = 1;
    c.scale(PAPER_COLUMNS / this.SHEET_WIDTH, PAPER_COLUMNS / this.SHEET_WIDTH);
    c.translate(-this.SHEET_X, -this.SHEET_Y);
    c.globalAlpha = this.cityId === 'paper-smx' ? 0.9 : illuminated ? 0.38 : 0.53;
    this.cityArtwork(true); c.globalAlpha = 1;
    if (!this.observationMode) this.guide(); c.restore();
  }

  private paintDetails(view: PaperSceneView): void {
    const c = this.context; c.save(); this.sheetContext(view);
    if (this.unfolded) {
      this.polygon([{ x: 37.7, y: 0.1 }, { x: 39.9, y: 2.8 }, { x: 37.6, y: 2.6 }], '#D8CAAA');
      this.line(37.7, 0.15, 37.6, 2.6, '#FDF6E5', 0.055);
    }
    c.strokeStyle = 'rgba(156,135,96,0.13)'; c.lineWidth = 0.025;
    for (let i = 0; i < 175; i++) {
      const x = ((i * 137) % 397) / 10; const y = ((i * 193) % 479) / 10;
      c.beginPath(); c.moveTo(x, y); c.lineTo(x + 0.12 + i % 3 * 0.035, y - 0.05); c.stroke();
    }
    if (this.unfolded && this.work.fold !== 'none') {
      c.strokeStyle = 'rgba(126,109,72,0.18)'; c.lineWidth = 0.11;
      c.beginPath(); c.moveTo(20, 0); c.lineTo(20, 48);
      if (this.work.fold === 'quarter') { c.moveTo(0, 24); c.lineTo(40, 24); } c.stroke();
      c.strokeStyle = 'rgba(255,251,234,0.7)'; c.lineWidth = 0.04;
      c.beginPath(); c.moveTo(20.12, 0); c.lineTo(20.12, 48); c.stroke();
    }
    c.restore();
  }

  private paintShadow(view: PaperSceneView): void {
    const c = this.context; c.save(); this.sheetContext(view);
    c.fillStyle = '#000000'; c.shadowColor = 'rgba(0,10,14,0.5)'; c.shadowBlur = 1.2;
    c.fill(this.paperShape, 'evenodd'); c.shadowBlur = 0;
    // 只缓存实际纸边阴影，去掉实体填色。移光时平移此图，不在每个move重新做模糊。
    c.globalCompositeOperation = 'destination-out'; c.fill(this.paperShape, 'evenodd');
    c.globalCompositeOperation = 'source-over'; c.restore();
  }

  private images(work: PaperWorkV1, view: PaperSceneView): void {
    const size = `${this.widthVp}:${this.heightVp}`;
    const backdropKey = `${size}:${this.cityId}`;
    if (this.backdropKey !== backdropKey) {
      this.backdropImage?.close(); this.backdropImage = this.image(() => this.backdrop());
      this.backdropKey = backdropKey;
      this.context = this.backdropContext; this.artContext(this.context, false);
      this.context.fillStyle = P.night;
      this.context.fillRect(-this.offsetX() / this.unit(), -this.offsetY() / this.unit(),
        this.widthVp / this.unit(), this.heightVp / this.unit());
      this.blit(this.backdropImage); this.context.restore();
    }
    const illuminated = work.light || this.observationMode;
    const materialKey = `${backdropKey}:${this.viewKey(view)}:${work.fold}:${this.unfolded}:` +
      `${work.paper}:${illuminated}:${this.showGuide}:${this.observationMode}`;
    // 材质失效不依赖mask/光位：连续切割只换clip，175条纸纹、城市曲线与色层只烘焙一次。
    if (this.materialKey !== materialKey) {
      this.deckImage?.close(); this.artworkImage?.close(); this.materialImage?.close(); this.detailImage?.close();
      this.deckImage = this.image(() => this.paintDeck(view));
      this.artworkImage = this.image(() => this.paintArtwork(view, illuminated));
      this.materialImage = this.image(() => this.paintMaterial(work, view, illuminated));
      this.detailImage = this.image(() => this.paintDetails(view)); this.materialKey = materialKey;
    }
    const shadowKey = `${size}:${this.geometryView}:${work.mask}`;
    // API26原生设备采样确认离屏模糊/位图转移是CPU光栅重活，不能随每个预览mask烘焙。
    // 划剪期间直接画当前真实纸形的实色偏移影；保留旧柔影缓存但不显示它，抬手后
    // 才为最终正式mask重建一次。光位变化仍仅平移该缓存，不触发新烘焙。
    if (!this.active && this.shadowKey !== shadowKey) {
      this.shadowImage?.close(); this.shadowImage = this.image(() => this.paintShadow(view)); this.shadowKey = shadowKey;
    }
  }

  private paintFace(view: PaperSceneView): void {
    const c = this.faceContext; this.context = c; this.artContext(c, true);
    c.save(); this.sheetContext(view); c.clip(this.paperShape, 'evenodd'); this.sheetToArt(view);
    this.blit(this.materialImage);
    if (!this.observationMode) this.blit(this.detailImage);
    c.restore(); c.restore();
  }

  private paintUnder(work: PaperWorkV1, view: PaperSceneView): void {
    const c = this.underContext; this.context = c; this.artContext(c, true);
    const illuminated = work.light || this.observationMode; const rect = view.rect;
    if (illuminated) this.glow(this.observationMode ? this.lightX : 500,
      this.observationMode ? this.lightY : 592, this.observationMode ? 440 : 645, 1.6);
    this.blit(this.deckImage); this.maskProjection(this.cutPaths, view); this.blit(this.artworkImage);
    c.save(); c.beginPath(); c.rect(rect.x, rect.y, rect.width, rect.height); c.clip();
    this.maskProjection(this.cutPaths, view);
    if (illuminated && !this.observationMode) {
      this.cutPaths.slice(0, 14).forEach((path: PaperPoint[]) => {
        let x = 0; let y = 0;
        path.forEach((point: PaperPoint) => { x += point.x; y += point.y; });
        this.glow(rect.x + (x / path.length - view.left) * this.SHEET_WIDTH / PAPER_COLUMNS,
          rect.y + (y / path.length - view.top) * this.SHEET_WIDTH / PAPER_COLUMNS, 100, 1.25);
      });
    }
    c.restore(); c.save();
    const cell = this.SHEET_WIDTH / PAPER_COLUMNS;
    c.translate((this.observationMode ? (500 - this.lightX) / 310 : 0.05) * cell,
      (this.observationMode ? (573 - this.lightY) / 310 : 0.4) * cell);
    if (this.active) {
      this.sheetContext(view); c.shadowBlur = 0; c.fillStyle = 'rgba(0,10,14,0.38)';
      c.fill(this.paperShape, 'evenodd');
    } else this.blit(this.shadowImage);
    c.restore(); c.restore();
  }

  private paintOverlay(work: PaperWorkV1, view: PaperSceneView): void {
    const c = this.overlayContext; this.context = c; this.artContext(c, true);
    const rect = view.rect; const cell = this.SHEET_WIDTH / PAPER_COLUMNS;
    if (this.observationMode) {
      c.save(); this.sheetContext(view); c.clip(this.paperShape, 'evenodd');
      const lx = view.left + (this.lightX - rect.x) / cell; const ly = view.top + (this.lightY - rect.y) / cell;
      const pool = c.createRadialGradient(lx, ly, 0, lx, ly, 29);
      pool.addColorStop(0, 'rgba(255,242,196,0.44)');
      pool.addColorStop(0.4, 'rgba(249,209,130,0.12)'); pool.addColorStop(1, 'rgba(9,24,30,0.35)');
      c.fillStyle = pool; c.fillRect(view.left, view.top, view.columns, view.rows);
      this.sheetToArt(view); this.blit(this.detailImage); c.restore();
    }
    c.save(); this.sheetContext(view);
    const illuminated = work.light || this.observationMode;
    if (illuminated) { c.shadowColor = '#F0BB6B'; c.shadowBlur = 0.65; }
    if (this.observationMode) {
      const edge = c.createRadialGradient(view.left + (this.lightX - rect.x) / cell,
        view.top + (this.lightY - rect.y) / cell, 0,
        view.left + (this.lightX - rect.x) / cell, view.top + (this.lightY - rect.y) / cell, 48);
      edge.addColorStop(0, '#FFF0BE'); edge.addColorStop(0.5, '#D7AD6A'); edge.addColorStop(1, '#8B6C45');
      c.strokeStyle = edge;
    } else c.strokeStyle = illuminated ? 'rgba(120,76,35,0.45)' : 'rgba(84,81,60,0.36)';
    c.lineWidth = 0.1; c.stroke(this.cutShape); c.shadowBlur = 0;
    if ((this.cachedJudgment?.brokenCells.length || 0) > 0) {
      c.fillStyle = 'rgba(174,75,48,0.27)'; c.fill(this.brokenShape);
      c.strokeStyle = '#BD7056'; c.lineWidth = 0.15; c.stroke(this.brokenShape);
    }
    c.restore();
    this.line(rect.x + 13, rect.y + rect.height + 16, rect.x + rect.width - 13,
      rect.y + rect.height + 16, 'rgba(220,201,159,0.16)', 1);
    this.projectionGround(this.cutPaths, view); this.lightHandle();
    if (this.active && this.points.length > 0) {
      const last = this.points[this.points.length - 1];
      const x = rect.x + (last.x * (PAPER_COLUMNS - 1) + 0.5 - view.left) * cell;
      const y = rect.y + (last.y * (PAPER_ROWS - 1) + 0.5 - view.top) * cell;
      this.ellipse(x, y, 8, 8, '#F9DF9D'); this.ellipse(x, y, 3, 3, '#FFF9E5');
    }
    c.restore();
  }

  private renderFrame(): void {
    if (!this.ready || !this.visible || this.widthVp <= 0 || this.heightVp <= 0) return;
    const started = this.perfNow(); this.lastFrameAt = Date.now();
    this.advancePreview();
    const work = this.current(); const view = this.view();
    if (this.animating) {
      const progress = Math.min(1, (Date.now() - this.animationStarted) / 300);
      const eased = 1 - Math.pow(1 - progress, 3);
      this.visualScaleX = this.animationFromX + (1 - this.animationFromX) * eased;
      this.visualScaleY = this.animationFromY + (1 - this.animationFromY) * eased;
      this.visualWidth = view.rect.width * this.visualScaleX; this.visualHeight = view.rect.height * this.visualScaleY;
      if (progress >= 1) this.stopAnimation();
    }
    this.geometry(work, view); this.judgment(work, view); this.images(work, view);
    const pose = `${this.visualScaleX}:${this.visualScaleY}`;
    const faceKey = `${this.materialKey}:${work.mask}:${pose}`;
    if (this.faceDrawKey !== faceKey) { this.paintFace(view); this.faceDrawKey = faceKey; }
    // 预览柔影key有意不变，底层仍须按当前mask重画实色影；结束时切回最终柔影。
    const shadowDrawKey = this.active ? `preview:${work.mask}` : this.shadowKey;
    const underKey = `${this.materialKey}:${shadowDrawKey}:${this.lightX}:${this.lightY}:${pose}`;
    if (this.underDrawKey !== underKey) { this.paintUnder(work, view); this.underDrawKey = underKey; }
    this.paintOverlay(work, view);
    if (this.debugPerf) this.perfFrames++;
    this.sample(this.perfDraw, started);
    if (this.perfReportPending) this.reportPerformance(this.perfReportPending);
    if (this.animating) this.draw();
  }

  private layerReady(layer: number): void {
    this.readyMask |= layer; this.ready = this.readyMask === 15; this.draw();
  }

  build() {
    Stack() {
      Canvas(this.backdropContext).width('100%').height('100%').onReady(() => this.layerReady(1))
        .hitTestBehavior(HitTestMode.None)
      Canvas(this.underContext).width('100%').height('100%').onReady(() => this.layerReady(2))
        .hitTestBehavior(HitTestMode.None)
      Canvas(this.faceContext).width('100%').height('100%').onReady(() => this.layerReady(4))
        .hitTestBehavior(HitTestMode.None)
      Canvas(this.overlayContext).width('100%').height('100%').onReady(() => this.layerReady(8))
        .hitTestBehavior(HitTestMode.None)
    }.width('100%').height('100%').id('paper-journey-scene')
      .onAreaChange((_old: Area, area: Area) => {
        this.widthVp = Number(area.width); this.heightVp = Number(area.height); this.draw();
      })
      .accessibilityText(`${this.observationMode ? '移光观察，拖动不剪纸' : this.interactive ? '可剪切' : '原创'}纸景，${this.unfolded ? '展开纸面' : '折叠纸面'}，${this.work.light || this.observationMode ? '正在透光' : '纸面'}。`)
      .gesture(GestureGroup(GestureMode.Exclusive,
        PanGesture({ fingers: 1, distance: 2 })
          .onActionStart((event: GestureEvent) => this.start(event))
          .onActionUpdate((event: GestureEvent) => this.move(event))
          .onActionEnd((event: GestureEvent) => this.finish(event)).onActionCancel(() => this.cancel()),
        TapGesture().onAction((event: GestureEvent) => this.tap(event))))
  }
}
