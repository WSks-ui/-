import { ArchiveRecord, HeritageSite } from '../domain/ArchiveDomain';
import { cultureGraphData } from '../domain/CultureGraphData';
import { GraphLayout, GraphNodeState } from '../domain/CultureGraphLayout';
import { GraphSpace, ProjectedNode } from '../domain/CultureGraphSpace';
import { ArchiveTheme as T } from './ArchiveTheme';

@Component
export struct CultureGraphNative {
  @Prop @Watch('updateGraph') sites: HeritageSite[] = [];
  @Prop @Watch('updateGraph') selectedId: string = '';
  @Prop @Watch('updateGraph') records: ArchiveRecord[] = [];
  @Prop @Watch('updateGraph') reducedMotion: boolean = false;
  @Prop @Watch('motion') active: boolean = true;
  @Prop @Watch('resize') graphHeight: number = 448;
  @LocalStorageProp('appForeground') @Watch('motion') private appForeground: boolean = true;
  onSelect: (id: string) => void = () => {};
  onReady: () => void = () => {};
  @State private points: ProjectedNode[] = [];
  @State private widthVp: number = 320;
  private layout: GraphLayout = new GraphLayout();
  private space: GraphSpace = new GraphSpace();
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private canvasReady: boolean = false;
  private timer: number = -1;
  private themeTimer: number = -1;
  private steps: number = 0;
  private phase: number = 0;
  private rotating: boolean = false;
  private rotationX: number = 0;
  private rotationY: number = 0;
  private dragNode: GraphNodeState | undefined = undefined;
  private dragWorldX: number = 0;
  private dragWorldY: number = 0;
  private dragScreenX: number = 0;
  private dragScreenY: number = 0;
  private emptyPoint: ProjectedNode = { id: '', label: '', city: '', era: '', accent: '#C4647C',
    x: 0, y: 0, z: 0, scale: 1, depth: 0, perspective: 1, pinned: false, width: 84, boxHeight: 52, centerY: 26 };

  aboutToAppear(): void { this.updateGraph(); }
  aboutToDisappear(): void { this.stop(); if (this.themeTimer !== -1) clearTimeout(this.themeTimer); }
  onWillApplyTheme(_theme: Theme): void {
    if (this.themeTimer !== -1) clearTimeout(this.themeTimer);
    this.themeTimer = setTimeout(() => { this.themeTimer = -1; this.draw(); }, 0);
  }
  private fontScale(): number {
    return Math.max(1, Math.min(1.5, this.getUIContext().fp2px(10) / this.getUIContext().vp2px(10)));
  }
  private color(name: string, fallback: string): string {
    try {
      const value = this.getUIContext().getHostContext()?.resourceManager.getColorByNameSync(name);
      return value === undefined ? fallback : `#${(value & 0xFFFFFF).toString(16).padStart(6, '0')}`;
    } catch { return fallback; }
  }
  private updateGraph(): void {
    this.layout.width = this.widthVp; this.layout.height = this.graphHeight;
    this.layout.setData(cultureGraphData(this.sites, this.selectedId, this.records), this.fontScale());
    if (this.reducedMotion) this.layout.settle();
    this.steps = 0; this.project(); this.motion();
  }
  private resize(): void {
    this.layout.resize(this.widthVp, this.graphHeight);
    if (this.reducedMotion) this.layout.settle();
    this.steps = 0; this.project(); this.motion();
  }
  private project(): void {
    this.points = this.space.frame(this.layout.nodes, this.widthVp, this.graphHeight,
      this.layout.nodeWidth, this.fontScale());
    this.draw();
  }
  private stop(): void { if (this.timer !== -1) clearInterval(this.timer); this.timer = -1; }
  private motion(): void {
    this.stop();
    if (!this.canvasReady || !this.active || !this.appForeground || this.reducedMotion) return;
    this.timer = setInterval(() => {
      if (this.steps < 180) { this.layout.step(); this.steps++; this.project(); }
      else this.draw();
      this.phase = (this.phase + 0.008) % 1;
    }, 40);
  }
  private draw(): void {
    if (!this.canvasReady) return;
    const c = this.context;
    const accent = this.color('accent', '#C4647C'), muted = this.color('muted', '#7A6C70');
    c.clearRect(0, 0, this.widthVp, this.graphHeight);
    c.fillStyle = this.color('line', '#EFE3E0');
    for (let x = 10; x < this.widthVp; x += 20) {
      for (let y = 58; y < this.graphHeight - 24; y += 20) {
        c.beginPath(); c.arc(x, y, 0.6, 0, Math.PI * 2); c.fill();
      }
    }
    this.layout.edges.forEach((edge, index) => {
      const a = this.points.find(point => point.id === edge.source), b = this.points.find(point => point.id === edge.target);
      if (!a || !b) return;
      const selected = a.id === this.selectedId || b.id === this.selectedId;
      const mx = (a.x + b.x) / 2 + (a.y - b.y) * 0.06, my = (a.y + b.y) / 2 + (b.x - a.x) * 0.06;
      c.beginPath(); c.moveTo(a.x, a.y); c.quadraticCurveTo(mx, my, b.x, b.y);
      c.strokeStyle = selected ? accent : muted;
      c.globalAlpha = selected ? 0.65 : 0.14; c.lineWidth = selected ? 1.5 : 0.8; c.stroke();
      if (selected && !this.reducedMotion) {
        const t = (this.phase + index * 0.17) % 1, u = 1 - t;
        c.beginPath(); c.arc(u * u * a.x + 2 * u * t * mx + t * t * b.x,
          u * u * a.y + 2 * u * t * my + t * t * b.y, 2, 0, Math.PI * 2);
        c.globalAlpha = 0.8; c.fillStyle = accent; c.fill();
      }
    });
    this.points.forEach(point => {
      const selected = point.id === this.selectedId;
      c.fillStyle = accent; c.globalAlpha = selected ? 0.13 : 0.04;
      c.beginPath(); c.arc(point.x, point.y, (selected ? 29 : 20) * point.scale, 0, Math.PI * 2); c.fill();
      c.globalAlpha = 1; c.fillStyle = this.color('surface', '#FFFFFF');
      c.beginPath(); c.arc(point.x, point.y, 15 * point.scale, 0, Math.PI * 2); c.fill();
      c.fillStyle = selected ? accent : point.accent;
      c.beginPath(); c.arc(point.x, point.y, (selected ? 11 : 8) * point.scale, 0, Math.PI * 2); c.fill();
    });
    c.globalAlpha = 1;
  }
  private startRotation(twoFingers: boolean = false): void {
    if (this.dragNode && !twoFingers) return;
    if (twoFingers) this.endDrag();
    this.rotating = true; this.rotationX = 0; this.rotationY = 0;
  }
  private handleRotation(event: GestureEvent): void {
    if (!this.rotating) return;
    this.space.rotate(event.offsetX - this.rotationX, event.offsetY - this.rotationY);
    this.rotationX = event.offsetX; this.rotationY = event.offsetY; this.project();
  }
  private startDrag(point: ProjectedNode): void {
    this.rotating = false;
    const node = this.layout.nodes.find(item => item.id === point.id);
    this.dragNode = node;
    this.dragWorldX = node?.x || 0; this.dragWorldY = node?.y || 0;
    this.dragScreenX = point.x; this.dragScreenY = point.y;
  }
  private drag(event: GestureEvent): void {
    if (!this.dragNode || this.reducedMotion || this.rotating) return;
    const origin = this.space.unproject(this.dragScreenX, this.dragScreenY, this.dragNode.era, this.widthVp, this.graphHeight);
    const target = this.space.unproject(this.dragScreenX + event.offsetX, this.dragScreenY + event.offsetY,
      this.dragNode.era, this.widthVp, this.graphHeight);
    if (!origin || !target) return;
    this.layout.drag(this.dragNode.id, this.dragWorldX + target.x - origin.x, this.dragWorldY + target.y - origin.y, true);
    this.project();
  }
  private endDrag(): void {
    if (this.dragNode) {
      this.dragNode.pinned = false; this.dragNode.anchorX = this.dragNode.x; this.dragNode.anchorY = this.dragNode.y;
    }
    this.dragNode = undefined; this.steps = 0;
  }

  private node(id: string): ProjectedNode { return this.points.find(point => point.id === id) || this.emptyPoint; }

  @Builder
  nodeButton(id: string) {
    // V1 ForEach 按 ID 复用节点。绑定必须读取当前 @State points，而不能闭包持有
    // 某一帧的 point 对象，否则连线已移动、按钮与文字却仍留在旧坐标。
    Button({ type: ButtonType.Normal }) {
      Column({ space: 3 }) {
        Row().height(26 * this.node(id).scale).width(1)
        Text(this.node(id).label).fontSize(10 * this.node(id).scale)
          .lineHeight(13.5 * this.fontScale() * this.node(id).scale)
          .fontWeight(id === this.selectedId ? FontWeight.Bold : FontWeight.Regular)
          .fontColor(id === this.selectedId ? T.accent : T.ink).textAlign(TextAlign.Center)
          .padding({ left: 3, right: 3, top: 2, bottom: 2 }).backgroundColor(id === this.selectedId ? T.accentSoft : T.surface)
          .border({ width: id === this.selectedId ? 1 : 0, color: T.accent, radius: 8 }).borderRadius(8).width('100%')
        Text(`${this.node(id).city} · ${this.node(id).era}`).fontSize(8 * this.node(id).scale)
          .lineHeight(11.2 * this.fontScale() * this.node(id).scale).fontColor(T.muted).textAlign(TextAlign.Center).maxLines(1)
      }.width('100%').height('100%').alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Start)
    }.width(this.node(id).width).height(this.node(id).boxHeight).padding(0).backgroundColor(Color.Transparent).borderRadius(10)
      .position({ x: this.node(id).x - this.node(id).width / 2, y: this.node(id).y - 16 * this.node(id).scale })
      .zIndex(200 - this.node(id).depth)
      .id(`graph-canvas-node-${id}`).accessibilityText(`${this.node(id).label}，${this.node(id).city}，${this.node(id).era}，查看关联`)
      .onClick(() => this.onSelect(id))
      .priorityGesture(PanGesture({ fingers: 1, direction: PanDirection.All, distance: 7 })
        .onActionStart(() => this.startDrag(this.node(id))).onActionUpdate((event: GestureEvent) => this.drag(event))
        .onActionEnd(() => this.endDrag()).onActionCancel(() => this.endDrag()))
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.context).width('100%').height('100%').hitTestBehavior(HitTestMode.None)
        .onReady(() => {
          this.canvasReady = true; this.draw(); this.motion(); this.onReady();
          console.info('CULTURE_GRAPH_RENDERER_READY:arkui-canvas2d');
        })
      ForEach(this.sites, (site: HeritageSite) => { this.nodeButton(site.id); }, (site: HeritageSite) => site.id)
      Row({ space: 6 }) {
        Column({ space: 3 }) {
          Text('年代空间').fontSize(11).fontWeight(FontWeight.Bold).fontColor(T.ink)
          Text('前景早期 · 远景晚期').fontSize(8).fontColor(T.muted)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button('旋转 ↻', { type: ButtonType.Normal }).height(34).padding({ left: 10, right: 10 })
          .fontSize(10).fontColor(T.accent).backgroundColor(T.surface).borderRadius(12)
          .id('graph-turn').accessibilityText('向右旋转图谱').onClick(() => { this.space.rotate(48, 0); this.project(); })
        Button('复位', { type: ButtonType.Normal }).height(34).padding({ left: 10, right: 10 })
          .fontSize(10).fontColor(T.accent).backgroundColor(T.surface).borderRadius(12)
          .id('graph-reset').accessibilityText('重置图谱视角').onClick(() => { this.space.reset(); this.project(); })
      }.width('100%').padding({ left: 12, right: 12 }).position({ x: 0, y: 10 }).zIndex(500)
      Text('仰韶 / 龙山             夏商 · 周 · 汉唐 · 宋').fontSize(8).fontColor(T.muted)
        .width('100%').textAlign(TextAlign.Center).position({ x: 0, y: this.graphHeight - 22 })
    }.width('100%').height(this.graphHeight).backgroundColor(T.canvas)
      .onAreaChange((_old: Area, area: Area) => {
        const width = Number(area.width);
        if (width > 0 && width !== this.widthVp) { this.widthVp = width; this.resize(); }
      })
      .gesture(PanGesture({ fingers: 1, direction: PanDirection.All, distance: 7 })
        .onActionStart(() => this.startRotation()).onActionUpdate((event: GestureEvent) => this.handleRotation(event))
        .onActionEnd(() => { this.rotating = false; }).onActionCancel(() => { this.rotating = false; }))
      .parallelGesture(PanGesture({ fingers: 2, direction: PanDirection.All, distance: 5 })
        .onActionStart(() => this.startRotation(true)).onActionUpdate((event: GestureEvent) => this.handleRotation(event))
        .onActionEnd(() => { this.rotating = false; }).onActionCancel(() => { this.rotating = false; }))
  }
}
