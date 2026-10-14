import { HeritageSite, ArchiveRecord } from '../domain/ArchiveDomain';
import { cultureConnections } from '../domain/CultureConnections';
import { siteIllustration } from './SiteRow';
import { ArchiveTheme as T } from './ArchiveTheme';

interface GraphPoint { x: number; y: number; }

@Component
export struct CultureGraph {
  @Prop @Watch('draw') sites: HeritageSite[] = [];
  @Prop @Watch('draw') selectedId: string = '';
  @Prop @Watch('draw') records: ArchiveRecord[] = [];
  @Prop reducedMotion: boolean = false;
  onSelect: (id: string) => void = () => {};
  @State graphWidth: number = 320;
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private canvasReady: boolean = false;

  private nodeHeight(): number {
    return Math.max(120, this.getUIContext().fp2px(104) / this.getUIContext().vp2px(1) + 16);
  }

  private graphHeight(): number {
    return this.sites.length <= 2 ? this.nodeHeight() + 48
      : this.sites.length <= 4 ? this.nodeHeight() * 2 + 80 : this.nodeHeight() * 3 + 60;
  }

  private point(index: number): GraphPoint {
    // 五城种子内容采用稳定的两翼布局；节点有固定点击范围，换标签和选中状态不挤动其他节点。
    // 这是一张关联图，不是地理地图。正式内容扩充时可按专题分页，避免在手机上堆满小节点。
    const positions: GraphPoint[] = this.sites.length === 1 ? [{ x: 0.5, y: 0.5 }]
      : this.sites.length === 2 ? [{ x: 0.23, y: 0.5 }, { x: 0.77, y: 0.5 }]
      : this.sites.length === 3 ? [{ x: 0.2, y: 0.22 }, { x: 0.8, y: 0.22 }, { x: 0.5, y: 0.78 }]
      : this.sites.length === 4 ? [{ x: 0.2, y: 0.22 }, { x: 0.8, y: 0.22 }, { x: 0.2, y: 0.78 }, { x: 0.8, y: 0.78 }]
      : [{ x: 0.2, y: 0.17 }, { x: 0.8, y: 0.17 }, { x: 0.5, y: 0.5 }, { x: 0.2, y: 0.83 }, { x: 0.8, y: 0.83 }];
    const point = positions[index] || positions[0];
    return { x: point.x * this.graphWidth, y: point.y * this.graphHeight() };
  }

  private draw(): void {
    if (!this.canvasReady) return;
    this.context.clearRect(0, 0, this.graphWidth, this.graphHeight());
    const anchorIndex = this.sites.findIndex((site: HeritageSite) => site.id === this.selectedId);
    if (anchorIndex < 0) return;
    const start = this.point(anchorIndex);
    const connected = cultureConnections(this.sites, this.selectedId, this.records);
    this.context.strokeStyle = '#C4647C';
    this.context.lineWidth = 2;
    connected.forEach((connection) => {
      const end = this.point(this.sites.findIndex((site: HeritageSite) => site.id === connection.site.id));
      const middleX = (start.x + end.x) / 2;
      this.context.beginPath();
      this.context.moveTo(start.x, start.y);
      this.context.bezierCurveTo(middleX, start.y, middleX, end.y, end.x, end.y);
      this.context.stroke();
      this.context.beginPath();
      this.context.arc(middleX, (start.y + end.y) / 2, 3, 0, Math.PI * 2);
      this.context.fillStyle = '#C4647C';
      this.context.fill();
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.context).width('100%').height('100%').hitTestBehavior(HitTestMode.None)
        .onReady(() => { this.canvasReady = true; this.draw(); })
      ForEach(this.sites, (site: HeritageSite, index: number) => {
        Button({ type: ButtonType.Normal }) {
          Column({ space: 4 }) {
            Image(siteIllustration(site)).width(42).height(42).objectFit(ImageFit.Contain).borderRadius(8)
            Text(site.name).fontSize(13).fontWeight(FontWeight.Bold).fontColor(T.ink)
              .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center)
            Text(`${site.city} · ${site.era}`).fontSize(10).fontColor(T.muted).maxLines(2).textAlign(TextAlign.Center)
          }.width('100%').height('100%').justifyContent(FlexAlign.Center).padding(8)
        }.width(106).height(this.nodeHeight()).padding(0).borderRadius(16)
          .backgroundColor(this.selectedId === site.id ? T.accentSoft : T.surface)
          .border({ width: this.selectedId === site.id ? 2 : 1,
            color: this.selectedId === site.id ? T.accent : T.line, radius: 16 })
          .scale({ x: this.selectedId === site.id ? 1.03 : 1, y: this.selectedId === site.id ? 1.03 : 1 })
          .animation({ duration: this.reducedMotion ? 0 : 180, curve: Curve.EaseInOut })
          .position({ x: this.point(index).x - 53, y: this.point(index).y - this.nodeHeight() / 2 })
          .onClick(() => this.onSelect(site.id)).id(`culture-node-${site.id}`)
          .accessibilityText(`${site.name}，${site.era}，查看关联线索`)
      // 五城切换为个人专题时，节点数量和原索引都会变化；重建布局，避免复用旧位置。
      }, (site: HeritageSite, index: number) => `${site.id}:${this.sites.length}:${index}`)
    }.width('100%').height(this.graphHeight()).id('culture-graph')
      .onAreaChange((_old: Area, area: Area) => { this.graphWidth = Number(area.width); this.draw(); })
  }
}
