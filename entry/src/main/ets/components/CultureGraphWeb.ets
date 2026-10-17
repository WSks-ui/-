import { webview } from '@kit.ArkWeb';
import { ArchiveRecord, HeritageSite } from '../domain/ArchiveDomain';
import { cultureGraphData, CultureGraphEdge, CultureGraphNode } from '../domain/CultureGraphData';
import { ArchiveTheme as T, ArchiveType as F } from './ArchiveTheme';
import { needsObjectCanvas } from '../platform/SiteObjectCanvas';
import { CultureGraphNative } from './CultureGraphNative';

interface GraphPalette {
  bg: string;
  surface: string;
  ink: string;
  muted: string;
  accent: string;
  line: string;
  soft: string;
}

interface GraphPayload {
  nodes: CultureGraphNode[];
  edges: CultureGraphEdge[];
  selectedId: string;
  palette: GraphPalette;
  fontScale: number;
  reducedMotion: boolean;
  active: boolean;
}

// 桥只接受当前目录里的节点 ID 和已知渲染器状态，不暴露存储、网络或任意脚本执行。
class CultureGraphBridge {
  private select: (id: string) => void;
  private ready: (mode: string) => void;
  constructor(select: (id: string) => void, ready: (mode: string) => void) {
    this.select = select;
    this.ready = ready;
  }
  onNodeSelect(id: string): void { this.select(id); }
  onReady(mode: string): void { this.ready(mode); }
}

@Component
export struct CultureGraphWeb {
  @Prop @Watch('pushData') sites: HeritageSite[] = [];
  @Prop @Watch('pushData') selectedId: string = '';
  @Prop @Watch('pushData') records: ArchiveRecord[] = [];
  @Prop @Watch('pushData') reducedMotion: boolean = false;
  @Prop @Watch('syncVisibility') active: boolean = true;
  onSelect: (id: string) => void = () => {};
  @State private ready: boolean = false;
  @State private failed: boolean = false;
  @State private expanded: boolean = false;
  @State private widthVp: number = 320;
  private loaded: boolean = false;
  private visible: boolean = true;
  private themeTimer: number = -1;
  private controller: webview.WebviewController = new webview.WebviewController();
  private nativeCanvas: boolean = needsObjectCanvas();
  private bridge: CultureGraphBridge = new CultureGraphBridge((id: string) => this.selectNode(id), (mode: string) => {
    if (mode !== 'webgl' && mode !== 'canvas2d') return;
    if (!this.ready) console.info(`CULTURE_GRAPH_RENDERER_READY:${mode}`);
    this.ready = true;
  });

  onWillApplyTheme(_theme: Theme): void {
    // lightEnabled 是材质开关，不是深浅主题。等资源配置应用后再读取语义颜色，
    // 避免用户关闭光感后，图谱错误变成深色；不修改全局配色或持久化主题。
    if (this.themeTimer !== -1) clearTimeout(this.themeTimer);
    this.themeTimer = setTimeout(() => { this.themeTimer = -1; this.pushData(); }, 0);
  }

  aboutToDisappear(): void {
    if (this.themeTimer !== -1) clearTimeout(this.themeTimer);
    if (this.loaded) this.controller.runJavaScript('window.yunhejiGraph?.setActive(false)').catch(() => {});
    this.loaded = false;
  }

  private fontScale(): number {
    return Math.max(1, Math.min(1.5, this.getUIContext().fp2px(10) / this.getUIContext().vp2px(10)));
  }

  private graphHeight(): number {
    const columns = this.sites.length <= 2 ? Math.max(1, this.sites.length) : (this.widthVp >= 560 ? 4 : 3);
    return Math.max(200, Math.ceil(this.sites.length / columns) * 84 * this.fontScale() + 28);
  }

  private color(name: string, fallback: string): string {
    try {
      const value = this.getUIContext().getHostContext()?.resourceManager.getColorByNameSync(name);
      return value === undefined ? fallback : `#${(value & 0xFFFFFF).toString(16).padStart(6, '0')}`;
    } catch { return fallback; }
  }

  private palette(): GraphPalette {
    return {
      bg: this.color('canvas', '#FDF8F6'), surface: this.color('surface', '#FFFFFF'),
      ink: this.color('ink', '#2B2225'), muted: this.color('muted', '#7A6C70'),
      accent: this.color('accent', '#C4647C'), line: this.color('line', '#EFE3E0'), soft: this.color('accent_soft', '#FBEAF0')
    };
  }

  private selectNode(id: string): void {
    if (typeof id !== 'string' || !this.sites.some((site: HeritageSite) => site.id === id)) return;
    this.onSelect(id);
  }

  private pushData(): void {
    if (!this.loaded || this.failed) return;
    const graph = cultureGraphData(this.sites, this.selectedId, this.records);
    const payload: GraphPayload = {
      nodes: graph.nodes, edges: graph.edges, selectedId: graph.selectedId,
      palette: this.palette(), fontScale: this.fontScale(), reducedMotion: this.reducedMotion,
      active: this.active && this.visible
    };
    // JSON 作为函数参数传入，不拼接标签或笔记内容到 HTML。JS 的异常进入可操作的原生降级索引。
    this.controller.runJavaScript(`window.yunhejiGraph.update(${JSON.stringify(payload)})`).catch(() => {
      this.failed = true;
    });
  }

  private syncVisibility(): void {
    if (!this.loaded || this.failed) return;
    this.controller.runJavaScript(`window.yunhejiGraph?.setActive(${this.active && this.visible})`).catch(() => {});
  }

  private indexSites(): HeritageSite[] {
    return this.expanded || this.failed ? this.sites : this.sites.slice(0, 6);
  }

  @Builder
  indexButton(site: HeritageSite) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 7 }) {
        Circle().width(7).height(7).fill(site.accent)
        Text(site.name).fontSize(F.caption).fontColor(this.selectedId === site.id ? T.accent : T.ink)
          .fontWeight(this.selectedId === site.id ? FontWeight.Bold : FontWeight.Regular)
          .maxLines(2).layoutWeight(1).textAlign(TextAlign.Start)
      }.width('100%').padding({ left: 10, right: 10, top: 10, bottom: 10 })
    }.width('48%').constraintSize({ minHeight: 44 }).padding(0).borderRadius(10)
      .backgroundColor(this.selectedId === site.id ? T.accentSoft : T.surface)
      .id(`culture-node-${site.id}`).accessibilityText(`${site.name}，${site.city}，${site.era}，查看关联线索`)
      .onClick(() => this.selectNode(site.id))
  }

  build() {
    Column({ space: 12 }) {
      if (!this.failed) {
        Stack({ alignContent: Alignment.Center }) {
          if (this.nativeCanvas) {
            CultureGraphNative({ sites: this.sites, selectedId: this.selectedId, records: this.records,
              reducedMotion: this.reducedMotion, active: this.active && this.visible, graphHeight: this.graphHeight(),
              onSelect: (id: string) => this.selectNode(id), onReady: () => { this.ready = true; } })
              .id('culture-native-canvas')
          } else {
          Web({ src: $rawfile('graph.html'), controller: this.controller })
            .width('100%').height('100%').backgroundColor(T.canvas)
            .javaScriptAccess(true).javaScriptProxy({ object: this.bridge, name: 'graphBridge',
              methodList: ['onNodeSelect', 'onReady'], controller: this.controller })
            .domStorageAccess(false).databaseAccess(false).fileAccess(false).onlineImageAccess(false)
            .geolocationAccess(false).mixedMode(MixedMode.None).zoomAccess(false)
            .darkMode(WebDarkMode.Auto).forceDarkAccess(false).textAutosizing(false)
            .onOverrideUrlLoading((request: WebResourceRequest): boolean => {
              // 仅允许本包 rawfile 主文档，桥不会被带到远程站点。
              return !request.getRequestUrl().startsWith('resource://rawfile/graph.html');
            })
            .onPageEnd(() => { this.loaded = true; this.pushData(); })
            .onErrorReceive((event: OnErrorReceiveEvent) => {
              if (event.request.isMainFrame()) this.failed = true;
            })
            .onRenderExited(() => { this.failed = true; this.loaded = false; })
          }
          if (!this.ready) {
            Text('正在展开文化线索').fontSize(F.small).fontColor(T.muted).hitTestBehavior(HitTestMode.None)
          }
        }.width('100%').height(this.graphHeight()).borderRadius(T.cardRadius).clip(true)
          .id('culture-web-canvas')
          .onVisibleAreaChange([0, 0.1], (visible: boolean, ratio: number) => {
            this.visible = visible && ratio > 0; this.syncVisibility();
          })
      }
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.link')).fontSize(14).fontColor([T.accent])
        Text(this.failed ? '图形暂不可用，可从下方选择档案' : (this.ready
          ? (this.reducedMotion ? '点选节点查看关联 · 已减少动态' : '拖动节点 · 点选查看关联') : '正在准备图谱'))
          .fontSize(F.caption).fontColor(T.muted).layoutWeight(1).id('culture-graph-status')
      }.width('100%')
      Column({ space: 8 }) {
        Row() {
          Text('档案索引').fontSize(F.small).fontWeight(FontWeight.Medium).fontColor(T.ink).layoutWeight(1)
          if (this.sites.length > 6 && !this.failed) {
            Button(this.expanded ? '收起' : `展开 ${this.sites.length} 处`, { type: ButtonType.Normal })
              .fontSize(F.caption).fontColor(T.accent).backgroundColor(Color.Transparent)
              .padding({ top: 8, bottom: 8, left: 10, right: 4 }).id('culture-index-expand')
              .onClick(() => { this.expanded = !this.expanded; })
          }
        }.width('100%')
        ForEach(this.indexSites().filter((_site: HeritageSite, index: number) => index % 2 === 0),
          (_site: HeritageSite, row: number) => {
            Row() {
              this.indexButton(this.indexSites()[row * 2])
              if (row * 2 + 1 < this.indexSites().length) this.indexButton(this.indexSites()[row * 2 + 1])
            }.width('100%').justifyContent(FlexAlign.SpaceBetween).alignItems(VerticalAlign.Top)
          }, (site: HeritageSite) => site.id)
      }.width('100%')
    }.width('100%').id('culture-graph')
      .onAreaChange((_old: Area, area: Area) => { this.widthVp = Number(area.width); })
  }
}
